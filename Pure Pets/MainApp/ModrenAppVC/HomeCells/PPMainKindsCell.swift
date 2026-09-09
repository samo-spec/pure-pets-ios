import UIKit

// MARK: - Home animal gallery

/// Home's UIKit species selector. The animal and its caption form one
/// native button; selection, persistence, routing, and haptics belong to Home.
@objc(PPMainKindsCell)
public final class PPMainKindsCell: UICollectionViewCell {
    @objc public class var reuseIdentifier: String { "PPMainKindsCell" }

    @objc public var onSelect: ((NSObject?, Bool) -> Void)? {
        didSet {
            if onSelect == nil { stopActivationMotion() }
            updateInteractionAvailability()
        }
    }
    @objc public var boundCellID: String?

    // MARK: Presentation

    private let actionButton = UIButton(type: .custom)
    private let selectionSurface = UIView()
    private let portraitContainer = UIView()
    private let artworkView = UIImageView()
    private let allArtworkViews = (0..<3).map { _ in UIImageView() }
    private let titleLabel = UILabel()

    // MARK: Content and lifecycle

    private var content: PPMainKindsContent?
    private var isKindSelected = false
    private var usesRestoredSelectionAppearance = false
    private var hasConfigured = false
    private var primaryImageGeneration = 0
    private var primaryImageRequestView: UIImageView?
    private var allPreviewContents: [PPMainKindsContent] = []
    private var allPreviewGeneration = 0
    private var allPreviewRequestViews: [UIImageView?] = Array(repeating: nil, count: 3)
    private var observers: [NSObjectProtocol] = []

    private var stateAnimator: UIViewPropertyAnimator?
    private var pressAnimator: UIViewPropertyAnimator?
    private var activationAnimator: UIViewPropertyAnimator?
    private var stateGeneration = 0
    private var pressGeneration = 0
    private var activationGeneration = 0
    private var activationInFlight = false
    private var lastActivationTime: CFTimeInterval = 0

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }
    private var usesExpandedTextLayout: Bool {
        let category = traitCollection.preferredContentSizeCategory
        return category.isAccessibilityCategory || category == .extraExtraExtraLarge
    }
    private var resolvedAccent: UIColor {
        PPMainKindsPalette.identityAccent(
            content?.accent ?? .ppPrimary,
            on: .ppSurfaceRaised,
            traits: traitCollection
        )
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        buildViewGraph()
        registerForEnvironmentChanges()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("PPMainKindsCell supports code-only UIKit.")
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        cancelPrimaryImageRequest()
        cancelAllPreviewRequests()
        stopAllMotion()
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        cancelPrimaryImageRequest()
        resetAllPreview()
        stopAllMotion()
        onSelect = nil
        content = nil
        boundCellID = nil
        hasConfigured = false
        isKindSelected = false
        usesRestoredSelectionAppearance = false
        lastActivationTime = 0
        artworkView.image = nil
        titleLabel.text = nil
        actionButton.accessibilityLabel = nil
        actionButton.accessibilityIdentifier = nil
        actionButton.largeContentTitle = nil
        actionButton.largeContentImage = nil
        updateTypography()
        updateAppearance()
        updateInteractionAvailability()
        setNeedsLayout()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stopAllMotion() }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard contentView.bounds.width > 0, contentView.bounds.height > 0 else { return }
        // Bounds/center keep the layout stable while press feedback is active.
        actionButton.bounds = CGRect(origin: .zero, size: contentView.bounds.size)
        actionButton.center = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)

        let geometry = PPMainKindsGalleryLayout(
            bounds: actionButton.bounds,
            title: titleLabel.text ?? "",
            titleFont: titleLabel.font,
            expandedText: usesExpandedTextLayout
        )
        portraitContainer.bounds = CGRect(origin: .zero, size: geometry.portraitFrame.size)
        portraitContainer.center = CGPoint(
            x: geometry.portraitFrame.midX, y: geometry.portraitFrame.midY
        )
        titleLabel.frame = geometry.titleFrame
        selectionSurface.bounds = CGRect(origin: .zero, size: geometry.selectionFrame.size)
        selectionSurface.center = CGPoint(
            x: geometry.selectionFrame.midX, y: geometry.selectionFrame.midY
        )

        let artworkCanvas = CGRect(
            x: PPSpace.xxs, y: PPSpace.xxs,
            width: max(0, portraitContainer.bounds.width - PPSpace.xs),
            height: max(0, portraitContainer.bounds.height - PPSpace.xs)
        )
        if content?.isAll == true {
            let side = min(artworkCanvas.width, artworkCanvas.height) * 0.42
            artworkView.frame = CGRect(
                x: artworkCanvas.midX - side / 2,
                y: artworkCanvas.midY - side / 2,
                width: side, height: side
            ).integral
            layoutAllArtwork(in: artworkCanvas)
        } else {
            // Optical profiles normalize the real artwork. Bottom-align the
            // image canvas so an enlarged silhouette cannot cover its caption.
            var frame = HomeSpeciesArtworkTreatment
                .resolved(for: content?.numericID ?? 0)
                .frame(in: artworkCanvas)
            frame.origin.y = min(frame.minY, artworkCanvas.maxY - frame.height)
            artworkView.frame = frame
        }
        artworkView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: max(20, min(artworkView.bounds.width, artworkView.bounds.height) * 0.70),
            weight: .medium
        )
    }

    public override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if previous?.hasDifferentColorAppearance(comparedTo: traitCollection) == true
            || previous?.accessibilityContrast != traitCollection.accessibilityContrast
            || previous?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory
            || previous?.layoutDirection != traitCollection.layoutDirection {
            environmentDidChange(refreshLocalizedContent: false)
        }
    }

    // MARK: Preserved Objective-C / SwiftUI bridge

    @objc(configureWithMainKind:isAll:selected:)
    public func configure(withMainKind kind: NSObject?, isAll: Bool, selected: Bool) {
        configure(
            withMainKind: kind, isAll: isAll, selected: selected,
            restoredSelectionAppearance: false
        )
    }

    @objc(configureWithMainKind:isAll:selected:restoredSelectionAppearance:)
    public func configure(
        withMainKind kind: NSObject?,
        isAll: Bool,
        selected: Bool,
        restoredSelectionAppearance: Bool
    ) {
        let next = PPMainKindsContent(kind: kind, isAll: isAll)
        let bindingChanged = boundCellID != next.cellID
        let selectionChanged = hasConfigured && isKindSelected != selected
        if bindingChanged {
            cancelPrimaryImageRequest()
            resetAllPreview()
            stopAllMotion()
            lastActivationTime = 0
        }
        content = next
        boundCellID = next.cellID
        isKindSelected = selected
        usesRestoredSelectionAppearance = selected && restoredSelectionAppearance
        hasConfigured = true

        applyLayoutDirection()
        updateContent()
        updateTypography()
        if bindingChanged || artworkView.image == nil {
            configurePrimaryArtwork(for: next)
        }
        if selectionChanged && !restoredSelectionAppearance {
            animateSelection(restored: false)
        } else {
            stopStateMotion()
            updateAppearance()
        }
        updateInteractionAvailability()
        setNeedsLayout()
    }

    /// Home already supplies these category models. A small ensemble makes
    /// All part of the same animal gallery without a second asset/data owner.
    public func configureAllPreview(withMainKinds kinds: [NSObject]) {
        guard content?.isAll == true else { return }
        var seen = Set<String>()
        let next = kinds.map { PPMainKindsContent(kind: $0, isAll: false) }
            .filter { seen.insert($0.cellID).inserted }
            .prefix(allArtworkViews.count)
        let nextContents = Array(next)
        let unchanged = nextContents.count == allPreviewContents.count
            && zip(nextContents, allPreviewContents).allSatisfy { next, previous in
                next.cellID == previous.cellID
                    && next.assetName == previous.assetName
                    && next.iconName == previous.iconName
                    && next.localImage === previous.localImage
            }
        guard !unchanged else { return }

        resetAllPreview()
        allPreviewContents = nextContents
        let generation = allPreviewGeneration
        let expectedCellID = boundCellID
        for (index, preview) in nextContents.enumerated() {
            let view = allArtworkViews[index]
            if let local = resolvedLocalArtwork(for: preview) {
                view.image = local.image.withRenderingMode(
                    local.isTemplate ? .alwaysTemplate : .alwaysOriginal
                )
            }
            guard !preview.imageURL.isEmpty else { continue }
            let expectedURL = preview.imageURL
            let requestView = UIImageView()
            allPreviewRequestViews[index] = requestView
            PPImageLoaderManager.shared().setImage(
                on: requestView, url: expectedURL, placeholder: nil,
                transitionStyle: .none
            ) { [weak self] image, _ in
                let applyResult = {
                    guard let self,
                          self.allPreviewGeneration == generation,
                          self.boundCellID == expectedCellID,
                          self.content?.isAll == true,
                          self.allPreviewContents.indices.contains(index),
                          self.allPreviewContents[index].imageURL == expectedURL else { return }
                    self.allPreviewRequestViews[index] = nil
                    guard let image else { return }
                    self.allArtworkViews[index].image = image.withRenderingMode(.alwaysOriginal)
                    self.updateAllArtworkVisibility()
                }
                if Thread.isMainThread { applyResult() }
                else { DispatchQueue.main.async(execute: applyResult) }
            }
        }
        updateAllArtworkVisibility()
    }

    @objc public func playRestoredSelectionAnimation() {
        guard window != nil, isKindSelected, usesRestoredSelectionAppearance else { return }
        animateSelection(restored: true)
    }

    @objc public func playSelectionChangeAnimation() {
        guard window != nil, isKindSelected, !usesRestoredSelectionAppearance else { return }
        animateSelection(restored: false)
    }

    // MARK: Construction and accessibility

    private func buildViewGraph() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = false
        isAccessibilityElement = false
        contentView.isAccessibilityElement = false

        actionButton.backgroundColor = .clear
        actionButton.adjustsImageWhenHighlighted = false
        actionButton.isExclusiveTouch = true
        actionButton.showsLargeContentViewer = true
        actionButton.isAccessibilityElement = true
        actionButton.accessibilityTraits = .button
        if #available(iOS 13.4, *) { actionButton.isPointerInteractionEnabled = true }
        actionButton.addTarget(self, action: #selector(handleTouchDown), for: [.touchDown, .touchDragEnter])
        actionButton.addTarget(
            self, action: #selector(handleTouchRelease),
            for: [.touchUpOutside, .touchCancel, .touchDragExit]
        )
        actionButton.addTarget(self, action: #selector(handleActivation), for: .touchUpInside)
        contentView.addSubview(actionButton)
        accessibilityElements = [actionButton]

        // One low ink surface joins the selected animal to its name. Passive
        // animals sit directly on Home, with no repeated enclosing chrome.
        selectionSurface.isUserInteractionEnabled = false
        selectionSurface.isAccessibilityElement = false
        selectionSurface.layer.cornerRadius = PPSpace.xs + PPSpace.xxs
        selectionSurface.layer.cornerCurve = .continuous
        actionButton.addSubview(selectionSurface)

        portraitContainer.isUserInteractionEnabled = false
        portraitContainer.isAccessibilityElement = false
        portraitContainer.clipsToBounds = false
        actionButton.addSubview(portraitContainer)

        artworkView.contentMode = .scaleAspectFit
        artworkView.clipsToBounds = false
        artworkView.isAccessibilityElement = false
        artworkView.accessibilityIgnoresInvertColors = true
        portraitContainer.addSubview(artworkView)

        for view in allArtworkViews.reversed() {
            view.contentMode = .scaleAspectFit
            view.isAccessibilityElement = false
            view.isUserInteractionEnabled = false
            view.accessibilityIgnoresInvertColors = true
            view.isHidden = true
            portraitContainer.addSubview(view)
        }

        titleLabel.backgroundColor = .clear
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.isAccessibilityElement = false
        actionButton.addSubview(titleLabel)

        applyLayoutDirection()
        updateTypography()
        updateAppearance()
        updateInteractionAvailability()
    }

    private func registerForEnvironmentChanges() {
        let center = NotificationCenter.default
        for name in [
            UIAccessibility.reduceMotionStatusDidChangeNotification,
            UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            UIAccessibility.boldTextStatusDidChangeNotification,
            UIContentSizeCategory.didChangeNotification
        ] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.environmentDidChange(refreshLocalizedContent: false)
            })
        }
        for rawName in ["LanguageDidChangeNotification", "PPLanguageDidChangeNotification"] {
            observers.append(
                center.addObserver(forName: Notification.Name(rawName), object: nil, queue: .main) { [weak self] _ in
                    self?.environmentDidChange(refreshLocalizedContent: true)
                }
            )
        }
        observers.append(
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                self?.stopAllMotion()
            }
        )
    }

    private func environmentDidChange(refreshLocalizedContent: Bool) {
        stopAllMotion()
        if refreshLocalizedContent, let current = content {
            content = PPMainKindsContent(kind: current.kind, isAll: current.isAll)
            boundCellID = content?.cellID
        }
        applyLayoutDirection()
        updateContent()
        updateTypography()
        updateAppearance()
        setNeedsLayout()
    }

    private func applyLayoutDirection() {
        let semantic = Language.semanticAttributeForCurrentLanguage()
        semanticContentAttribute = semantic
        contentView.semanticContentAttribute = semantic
        actionButton.semanticContentAttribute = semantic
        titleLabel.semanticContentAttribute = semantic
        // This centered gallery preserves every subject's pose in both
        // languages; the rail continues to own logical order and scrolling.
        portraitContainer.semanticContentAttribute = .forceLeftToRight
        artworkView.semanticContentAttribute = .forceLeftToRight
        artworkView.transform = .identity
        allArtworkViews.forEach { $0.semanticContentAttribute = .forceLeftToRight }
    }

    private func updateTypography() {
        let bold = isKindSelected || UIAccessibility.isBoldTextEnabled
        let baseFont = PPMainKindsGalleryLayout.captionFont(
            size: PPMainKindsGalleryLayout.captionPointSize, bold: bold
        )
        titleLabel.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
            for: baseFont, compatibleWith: traitCollection
        )
        titleLabel.numberOfLines = usesExpandedTextLayout ? 3 : 2
    }

    private func updateContent() {
        guard let content else { return }
        titleLabel.text = content.title
        actionButton.accessibilityLabel = content.title
        actionButton.accessibilityIdentifier = content.isAll
            ? "home.mainKinds.all" : "home.mainKinds.\(content.numericID)"
        actionButton.largeContentTitle = content.title
        updateLargeContentImage()
    }

    private func updateInteractionAvailability() {
        actionButton.isEnabled = hasConfigured && onSelect != nil
        actionButton.isUserInteractionEnabled = !activationInFlight
        var traits: UIAccessibilityTraits = .button
        if isKindSelected { traits.insert(.selected) }
        if !actionButton.isEnabled { traits.insert(.notEnabled) }
        actionButton.accessibilityTraits = traits
        actionButton.alpha = actionButton.isEnabled ? 1 : 0.55
    }

    private func updateAppearance() {
        let text = UIColor.ppTextPrimary.resolvedColor(with: traitCollection)
        let accent = resolvedAccent
        let selectedText: UIColor = UIColor.white.ppMainKindContrastRatio(against: accent)
            >= UIColor.black.ppMainKindContrastRatio(against: accent) ? .white : .black
        selectionSurface.backgroundColor = accent
        selectionSurface.alpha = isKindSelected ? 1 : 0
        titleLabel.textColor = isKindSelected ? selectedText : text
        artworkView.tintColor = content?.isAll == true && !isKindSelected
            ? .ppTextSecondary : accent
        allArtworkViews.forEach { $0.tintColor = accent }
    }

    // MARK: Existing image ownership

    private func configurePrimaryArtwork(for content: PPMainKindsContent) {
        cancelPrimaryImageRequest()
        let placeholder = resolvedPlaceholder(for: content)
        artworkView.image = placeholder.image?.withRenderingMode(
            placeholder.isTemplate ? .alwaysTemplate : .alwaysOriginal
        )
        updateLargeContentImage()
        guard !content.isAll, !content.imageURL.isEmpty else { return }

        primaryImageGeneration &+= 1
        let generation = primaryImageGeneration
        let expectedCellID = content.cellID
        let expectedURL = content.imageURL
        // The shared loader applies before invoking its completion. A detached
        // request view keeps that write away from the live cell until all
        // identity guards pass, including a completion queued before reuse.
        let requestView = UIImageView()
        primaryImageRequestView = requestView
        PPImageLoaderManager.shared().setImage(
            on: requestView, url: expectedURL,
            placeholder: nil, transitionStyle: .none
        ) { [weak self] image, _ in
            let applyResult = {
                guard let self,
                      self.primaryImageGeneration == generation,
                      self.boundCellID == expectedCellID,
                      self.content?.imageURL == expectedURL else { return }
                self.primaryImageRequestView = nil
                guard let image else { return }
                self.artworkView.image = image.withRenderingMode(.alwaysOriginal)
                self.updateLargeContentImage()
            }
            if Thread.isMainThread { applyResult() }
            else { DispatchQueue.main.async(execute: applyResult) }
        }
    }

    private func resolvedPlaceholder(for content: PPMainKindsContent) -> (image: UIImage?, isTemplate: Bool) {
        if content.isAll {
            return (UIImage(named: "menugrid") ?? UIImage(systemName: "line.3.horizontal"), true)
        }
        if let local = resolvedLocalArtwork(for: content) { return local }
        return (UIImage(systemName: "pawprint.fill"), true)
    }

    private func resolvedLocalArtwork(for content: PPMainKindsContent) -> (image: UIImage, isTemplate: Bool)? {
        if let image = content.localImage { return (image, false) }
        if !content.assetName.isEmpty, let image = UIImage(named: content.assetName) { return (image, false) }
        if !content.iconName.isEmpty, let image = UIImage(named: content.iconName) { return (image, false) }
        if !content.iconName.isEmpty, let image = UIImage(systemName: content.iconName) { return (image, true) }
        return nil
    }

    private func updateLargeContentImage() { actionButton.largeContentImage = artworkView.image }

    private func cancelPrimaryImageRequest() {
        primaryImageGeneration &+= 1
        if let requestView = primaryImageRequestView {
            PPImageLoaderManager.shared().cancelImageLoad(for: requestView)
        }
        primaryImageRequestView = nil
    }

    private func cancelAllPreviewRequests() {
        allPreviewGeneration &+= 1
        allPreviewRequestViews.compactMap { $0 }.forEach {
            PPImageLoaderManager.shared().cancelImageLoad(for: $0)
        }
        allPreviewRequestViews = Array(repeating: nil, count: allArtworkViews.count)
    }

    private func resetAllPreview() {
        cancelAllPreviewRequests()
        allPreviewContents.removeAll()
        allArtworkViews.forEach {
            $0.image = nil
            $0.isHidden = true
        }
        artworkView.isHidden = false
    }

    private func updateAllArtworkVisibility() {
        guard content?.isAll == true else { return }
        // Keep the existing All glyph until a real ensemble is available.
        // Partial/failed loads never manufacture extra animals or blank All.
        let hasEnsemble = allArtworkViews.filter { $0.image != nil }.count >= 2
        artworkView.isHidden = hasEnsemble
        allArtworkViews.forEach { $0.isHidden = !hasEnsemble || $0.image == nil }
        setNeedsLayout()
    }

    private func layoutAllArtwork(in canvas: CGRect) {
        let visibleViews = allArtworkViews.filter { !$0.isHidden }
        for (index, view) in visibleViews.enumerated() {
            let normalized: CGRect
            if visibleViews.count == 2 {
                normalized = index == 0
                    ? CGRect(x: -0.02, y: 0.03, width: 0.68, height: 0.94)
                    : CGRect(x: 0.36, y: 0, width: 0.66, height: 0.90)
            } else {
                // The front portrait stays upright; two smaller subjects
                // emerge behind it. Only existing category artwork is used.
                switch index {
                case 0: normalized = CGRect(x: 0.15, y: 0.18, width: 0.70, height: 0.82)
                case 1: normalized = CGRect(x: -0.02, y: 0.01, width: 0.62, height: 0.76)
                default: normalized = CGRect(x: 0.42, y: 0, width: 0.60, height: 0.76)
                }
            }
            view.frame = CGRect(
                x: canvas.minX + normalized.minX * canvas.width,
                y: canvas.minY + normalized.minY * canvas.height,
                width: normalized.width * canvas.width,
                height: normalized.height * canvas.height
            ).integral
        }
    }

    // MARK: Finite, cancellable feedback

    @objc private func handleTouchDown() {
        guard !activationInFlight else { return }
        animatePress(pressed: true)
    }

    @objc private func handleTouchRelease() {
        guard !activationInFlight else { return }
        animatePress(pressed: false)
    }

    @objc private func handleActivation() {
        let now = CACurrentMediaTime()
        guard !activationInFlight,
              now - lastActivationTime >= 0.30,
              let content, let expectedCellID = boundCellID,
              onSelect != nil, window != nil else {
            // A debounced touchUpInside still ends its touchDown state. An
            // accepted activation owns its release until completion instead.
            if !activationInFlight { animatePress(pressed: false) }
            return
        }
        lastActivationTime = now
        stopPressMotion()

        guard !reduceMotion else {
            portraitContainer.transform = .identity
            portraitContainer.alpha = 1
            onSelect?(content.kind, content.isAll)
            return
        }

        activationInFlight = true
        updateInteractionAvailability()
        activationGeneration &+= 1
        let generation = activationGeneration
        // A release acknowledges the touch; it does not launch a second
        // spectacle or move the caption. Home receives the intent once settled.
        let animator = UIViewPropertyAnimator(duration: 0.18, dampingRatio: 0.90) { [weak self] in
            self?.portraitContainer.transform = .identity
            self?.portraitContainer.alpha = 1
        }
        animator.addCompletion { [weak self] position in
            guard let self, position == .end,
                  self.activationGeneration == generation,
                  self.boundCellID == expectedCellID,
                  self.window != nil else { return }
            self.activationAnimator = nil
            self.activationInFlight = false
            self.updateInteractionAvailability()
            self.onSelect?(content.kind, content.isAll)
        }
        activationAnimator = animator
        animator.startAnimation()
    }

    private func animatePress(pressed: Bool) {
        stopPressMotion()
        let target = pressed && !reduceMotion
            ? CGAffineTransform(scaleX: 0.974, y: 0.974) : .identity
        let alpha: CGFloat = pressed ? 0.86 : 1
        guard !reduceMotion, window != nil else {
            portraitContainer.transform = .identity
            portraitContainer.alpha = alpha
            return
        }
        pressGeneration &+= 1
        let generation = pressGeneration
        let animator = UIViewPropertyAnimator(duration: pressed ? 0.09 : 0.18, curve: .easeOut) { [weak self] in
            self?.portraitContainer.transform = target
            self?.portraitContainer.alpha = alpha
        }
        animator.addCompletion { [weak self] _ in
            guard let self, self.pressGeneration == generation else { return }
            self.pressAnimator = nil
        }
        pressAnimator = animator
        animator.startAnimation()
    }

    private func animateSelection(restored: Bool) {
        stopStateMotion()
        // Reverse text and its ink arrive together at full contrast. Settle
        // only the low surface; never fade white text through a clear field.
        updateAppearance()
        guard isKindSelected, !reduceMotion, window != nil else { return }
        stateGeneration &+= 1
        let generation = stateGeneration
        selectionSurface.transform = CGAffineTransform(translationX: 0, y: 3)
        let animator = UIViewPropertyAnimator(duration: restored ? 0.12 : 0.18, curve: .easeOut) { [weak self] in
            self?.selectionSurface.transform = .identity
        }
        animator.addCompletion { [weak self] _ in
            guard let self, self.stateGeneration == generation else { return }
            self.stateAnimator = nil
        }
        stateAnimator = animator
        animator.startAnimation()
    }

    private func stopStateMotion() {
        stateGeneration &+= 1
        stateAnimator?.stopAnimation(true)
        stateAnimator = nil
        selectionSurface.transform = .identity
    }

    private func stopPressMotion() {
        pressGeneration &+= 1
        if let animator = pressAnimator {
            animator.stopAnimation(false)
            animator.finishAnimation(at: .current)
        }
        pressAnimator = nil
    }

    private func stopActivationMotion() {
        activationGeneration &+= 1
        activationAnimator?.stopAnimation(true)
        activationAnimator = nil
        activationInFlight = false
        portraitContainer.transform = .identity
        portraitContainer.alpha = 1
        updateInteractionAvailability()
    }

    private func stopAllMotion() {
        stopStateMotion()
        stopPressMotion()
        stopActivationMotion()
        portraitContainer.layer.removeAllAnimations()
        selectionSurface.layer.removeAllAnimations()
        titleLabel.layer.removeAllAnimations()
        updateAppearance()
    }
}

// MARK: - Model adaptation

private struct PPMainKindsContent {
    let kind: NSObject?
    let isAll: Bool
    let numericID: Int
    let title: String
    let imageURL: String
    let localImage: UIImage?
    let assetName: String
    let iconName: String
    let accent: UIColor
    let cellID: String

    init(kind: NSObject?, isAll: Bool) {
        self.kind = kind
        self.isAll = isAll

        if isAll {
            numericID = 0
            title = Language.get("all", alter: nil) ?? ""
            imageURL = ""
            localImage = nil
            assetName = ""
            iconName = ""
            accent = .ppPrimary
            cellID = "pp-main-kind-all"
            return
        }

        let presentation = kind.map {
            PPHomeDataBridge.categoryPresentation(for: $0)
        } ?? [:]
        let model = kind as? MainKindsModel
        numericID = (presentation["numericID"] as? NSNumber)?.intValue
            ?? model?.id
            ?? 0
        title = (presentation["title"] as? String) ?? model?.kindName ?? ""
        imageURL = (presentation["imageURL"] as? String)
            ?? model?.kindImageUrl
            ?? ""
        localImage = presentation["localImage"] as? UIImage
        assetName = model?.kindImageNamed ?? ""
        iconName = model?.kindIconName ?? ""
        accent = (presentation["accent"] as? UIColor) ?? .ppPrimary
        let documentID = presentation["id"] as? String ?? ""
        let stableIdentity = documentID.isEmpty
            ? "main-kind-\(numericID)"
            : documentID
        cellID = [stableIdentity, imageURL].joined(separator: "|")
    }
}

// MARK: - Measured gallery geometry shared with the Home rail

/// The rail and UIKit renderer use the same caption measurement. A short
/// name occupies one actual line, rather than floating in a two-line box.
struct PPMainKindsGalleryLayout {
    static let captionPointSize: CGFloat = 18
    static let captionInset = PPSpace.sm
    static let captionGap = PPSpace.xs
    static let bottomInset = PPSpace.sm

    let portraitFrame: CGRect
    let titleFrame: CGRect
    let selectionFrame: CGRect

    init(bounds: CGRect, title: String, titleFont: UIFont, expandedText: Bool) {
        let inset = PPSpace.xs
        let labelWidth = max(0, bounds.width - Self.captionInset * 2)
        let captionHeight = Self.captionHeight(
            title: title, width: labelWidth, font: titleFont, expandedText: expandedText
        )
        let availableHeight = max(
            0, bounds.height - captionHeight - Self.captionGap - Self.bottomInset - inset
        )
        let width = min(max(0, bounds.width - inset * 2), expandedText ? 124 : 144)
        let height = min(availableHeight, Self.portraitHeight(for: bounds.width, expandedText: expandedText))
        portraitFrame = CGRect(
            x: bounds.midX - width / 2, y: inset, width: width, height: height
        ).integral
        titleFrame = CGRect(
            x: Self.captionInset,
            y: portraitFrame.maxY + Self.captionGap,
            width: labelWidth,
            height: min(captionHeight, max(0, bounds.maxY - portraitFrame.maxY - Self.captionGap - Self.bottomInset))
        ).integral
        let surfaceTop = max(inset, portraitFrame.maxY - PPSpace.base)
        selectionFrame = CGRect(
            x: inset, y: surfaceTop,
            width: max(0, bounds.width - inset * 2),
            height: max(0, titleFrame.maxY + Self.bottomInset - surfaceTop)
        ).integral
    }

    static func captionFont(size: CGFloat, bold: Bool) -> UIFont {
        UIFont(name: bold ? "Beiruti-Bold" : "Beiruti-Medium", size: size)
            ?? UIFont.systemFont(ofSize: size, weight: bold ? .bold : .medium)
    }

    static func portraitHeight(for width: CGFloat, expandedText: Bool) -> CGFloat {
        ceil(min(max(0, width - PPSpace.xs), expandedText ? 124 : 112) * 0.90)
    }

    static func captionHeight(title: String, width: CGFloat, font: UIFont, expandedText: Bool) -> CGFloat {
        let lineHeight = ceil(font.lineHeight)
        guard width > 0 else { return lineHeight }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let measured = (title as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: paragraph], context: nil
        )
        return min(lineHeight * (expandedText ? 3 : 2), max(lineHeight, ceil(measured.height)))
    }

    static func preferredHeight(width: CGFloat, titles: [String], fontSize: CGFloat, expandedText: Bool) -> CGFloat {
        let labelWidth = max(0, width - captionInset * 2)
        let fonts = [captionFont(size: fontSize, bold: false), captionFont(size: fontSize, bold: true)]
        let textHeight = titles.reduce(ceil(fonts[0].lineHeight)) { current, title in
            fonts.reduce(current) { maximum, font in
                max(maximum, captionHeight(title: title, width: labelWidth, font: font, expandedText: expandedText))
            }
        }
        return PPSpace.xs + portraitHeight(for: width, expandedText: expandedText)
            + captionGap + textHeight + bottomInset
    }
}

private enum PPMainKindsPalette {
    static func identityAccent(
        _ candidate: UIColor,
        on surface: UIColor,
        traits: UITraitCollection
    ) -> UIColor {
        let resolvedSurface = surface.resolvedColor(with: traits)
        let text = UIColor.ppTextPrimary.resolvedColor(with: traits)
        let brand = UIColor.ppPrimary.resolvedColor(with: traits)
        let requiredContrast: CGFloat = traits.accessibilityContrast == .high ? 4.5 : 3
        let base = candidate.resolvedColor(with: traits).ppMainKindOpaque ?? brand

        let candidates = [
            base,
            base.ppMainKindMixed(with: text, amountOfSelf: 0.64),
            brand,
            brand.ppMainKindMixed(with: text, amountOfSelf: 0.58),
            text
        ]
        return candidates.first {
            $0.ppMainKindContrastRatio(against: resolvedSurface) >= requiredContrast
        } ?? text
    }
}

private extension UIColor {
    var ppMainKindOpaque: UIColor? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            guard alpha >= 0.12 else { return nil }
            return UIColor(red: red, green: green, blue: blue, alpha: 1)
        }

        var white: CGFloat = 0
        if getWhite(&white, alpha: &alpha) {
            guard alpha >= 0.12 else { return nil }
            return UIColor(white: white, alpha: 1)
        }
        return nil
    }

    func ppMainKindMixed(
        with other: UIColor,
        amountOfSelf: CGFloat
    ) -> UIColor {
        let first = ppMainKindOpaque ?? self
        let second = other.ppMainKindOpaque ?? other
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        guard first.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              second.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else {
            return first
        }
        let amount = min(max(amountOfSelf, 0), 1)
        let inverse = 1 - amount
        return UIColor(
            red: (r1 * amount) + (r2 * inverse),
            green: (g1 * amount) + (g2 * inverse),
            blue: (b1 * amount) + (b2 * inverse),
            alpha: (a1 * amount) + (a2 * inverse)
        )
    }

    func ppMainKindContrastRatio(against other: UIColor) -> CGFloat {
        let lighter = max(ppMainKindRelativeLuminance, other.ppMainKindRelativeLuminance)
        let darker = min(ppMainKindRelativeLuminance, other.ppMainKindRelativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private var ppMainKindRelativeLuminance: CGFloat {
        guard let opaque = ppMainKindOpaque else { return 0 }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard opaque.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return 0
        }

        func linear(_ component: CGFloat) -> CGFloat {
            component <= 0.03928
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return (0.2126 * linear(red))
            + (0.7152 * linear(green))
            + (0.0722 * linear(blue))
    }
}
