import UIKit

/// The second-generation Home species selector: an open animal portrait on a
/// small, tactile perch. HomeStore owns selection, persistence, routing and
/// haptics. This cell owns presentation and the bounded release-before-action.
/// PPMainKindsCell remains untouched as the original implementation.
@objc(MainKindsCellV2)
public final class MainKindsCellV2: UICollectionViewCell {
    @objc public class var reuseIdentifier: String { "MainKindsCellV2" }

    @objc public var onSelect: ((NSObject?, Bool) -> Void)? {
        didSet {
            if onSelect == nil { stopAllMotion() }
            updateInteractionAvailability()
        }
    }
    @objc public var boundCellID: String?

    private let actionButton = UIButton(type: .custom)
    private let pressureContainer = UIView()
    private let perchView = UIView()
    private let perchLayer = CAShapeLayer()
    private let portraitContainer = UIView()
    private let artworkView = UIImageView()
    private let allArtworkViews = (0..<3).map { _ in UIImageView() }
    private let titleLabel = UILabel()
    private let selectionKeel = UIView()

    private var content: MainKindsV2Content?
    private var isKindSelected = false
    private var usesRestoredSelectionAppearance = false
    private var hasConfigured = false
    private var primaryImageGeneration = 0
    private var primaryImageRequestView: UIImageView?
    private var allPreviewContents: [MainKindsV2Content] = []
    private var allPreviewGeneration = 0
    private var allPreviewRequestViews: [UIImageView?] = Array(repeating: nil, count: 3)
    private var observers: [NSObjectProtocol] = []

    private var pressureAnimator: UIViewPropertyAnimator?
    private var selectionAnimator: UIViewPropertyAnimator?
    private var activationAnimator: UIViewPropertyAnimator?
    private var pressureGeneration = 0
    private var selectionGeneration = 0
    private var activationGeneration = 0
    private var activationInFlight = false
    private var lastActivationTime: CFTimeInterval = 0

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }
    private var usesExpandedTextLayout: Bool {
        let category = traitCollection.preferredContentSizeCategory
        return category.isAccessibilityCategory || category == .extraExtraExtraLarge
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        buildViewGraph()
        registerForEnvironmentChanges()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("MainKindsCellV2 supports code-only UIKit.")
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        cancelPrimaryImageRequest()
        cancelAllPreviewRequests()
        pressureAnimator?.stopAnimation(true)
        selectionAnimator?.stopAnimation(true)
        activationAnimator?.stopAnimation(true)
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        onSelect = nil
        cancelPrimaryImageRequest()
        resetAllPreview()
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
        applySelectionPose()
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
        actionButton.frame = contentView.bounds
        // bounds/center preserve geometry when a spring is interrupted by resize.
        pressureContainer.bounds = CGRect(origin: .zero, size: actionButton.bounds.size)
        pressureContainer.center = CGPoint(x: actionButton.bounds.midX, y: actionButton.bounds.midY)

        let geometry = MainKindsCellV2Layout(
            bounds: pressureContainer.bounds,
            title: titleLabel.text ?? "",
            fontSize: titleLabel.font.pointSize,
            expandedText: usesExpandedTextLayout
        )
        perchView.bounds = CGRect(origin: .zero, size: geometry.perchFrame.size)
        perchView.center = CGPoint(x: geometry.perchFrame.midX, y: geometry.perchFrame.midY)
        portraitContainer.bounds = CGRect(origin: .zero, size: geometry.portraitFrame.size)
        portraitContainer.center = CGPoint(x: geometry.portraitFrame.midX, y: geometry.portraitFrame.midY)
        titleLabel.frame = geometry.titleFrame.offsetBy(
            dx: -geometry.perchFrame.minX, dy: -geometry.perchFrame.minY
        )
        selectionKeel.frame = geometry.keelFrame.offsetBy(
            dx: -geometry.perchFrame.minX, dy: -geometry.perchFrame.minY
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        perchLayer.frame = perchView.bounds
        perchLayer.path = MainKindsCellV2Layout.perchPath(in: perchView.bounds).cgPath
        CATransaction.commit()

        if content?.isAll == true {
            let side = min(portraitContainer.bounds.width, portraitContainer.bounds.height) * 0.5
            artworkView.frame = CGRect(
                x: (portraitContainer.bounds.width - side) / 2,
                y: (portraitContainer.bounds.height - side) / 2,
                width: side, height: side
            ).integral
            layoutAllArtwork()
        } else {
            // Reserve breathing room before applying Home's optical profile.
            // That lets horses/dogs keep their larger relative scale instead of
            // normalizing every scale above 1 back to the same portrait size.
            let opticalCanvas = portraitContainer.bounds.insetBy(dx: PPSpace.xs, dy: PPSpace.xs)
            let treated = HomeSpeciesArtworkTreatment.resolved(for: content?.numericID ?? 0)
                .frame(in: opticalCanvas)
            let room = CGRect(
                x: -PPSpace.xs, y: -PPSpace.xs,
                width: portraitContainer.bounds.width + PPSpace.sm,
                height: portraitContainer.bounds.height + PPSpace.xs
            )
            let scale = min(1, room.width / max(treated.width, 1), room.height / max(treated.height, 1))
            let size = CGSize(width: treated.width * scale, height: treated.height * scale)
            artworkView.frame = CGRect(
                x: min(max(treated.midX - size.width / 2, room.minX), room.maxX - size.width),
                y: min(max(treated.midY - size.height / 2, room.minY), room.maxY - size.height),
                width: size.width, height: size.height
            ).integral
        }
        artworkView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: max(22, min(artworkView.bounds.width, artworkView.bounds.height) * 0.6),
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

    // MARK: - Existing Objective-C and Home bridge contract

    @objc(configureWithMainKind:isAll:selected:)
    public func configure(withMainKind kind: NSObject?, isAll: Bool, selected: Bool) {
        configure(withMainKind: kind, isAll: isAll, selected: selected, restoredSelectionAppearance: false)
    }

    @objc(configureWithMainKind:isAll:selected:restoredSelectionAppearance:)
    public func configure(
        withMainKind kind: NSObject?, isAll: Bool, selected: Bool,
        restoredSelectionAppearance: Bool
    ) {
        let next = MainKindsV2Content(kind: kind, isAll: isAll)
        let bindingChanged = boundCellID != next.cellID
        let artworkChanged = content.map { !$0.hasSameArtwork(as: next) } ?? true
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
        updateTypography()
        updateContent()
        if bindingChanged || artworkChanged || artworkView.image == nil {
            configurePrimaryArtwork(for: next)
        }
        // Ink and opaque fill change atomically; spring only the two planes.
        // This avoids animating text through low-contrast intermediate colors.
        updateAppearance()
        if selectionChanged && !bindingChanged && !restoredSelectionAppearance {
            animateSelection(restored: false)
        } else if bindingChanged || restoredSelectionAppearance {
            stopSelectionMotion()
            applySelectionPose()
        }
        updateInteractionAvailability()
        setNeedsLayout()
    }

    public func configureAllPreview(withMainKinds kinds: [NSObject]) {
        guard content?.isAll == true else { return }
        var seen = Set<String>()
        let next = Array(kinds.map { MainKindsV2Content(kind: $0, isAll: false) }
            .filter { seen.insert($0.cellID).inserted }.prefix(allArtworkViews.count))
        let unchanged = next.count == allPreviewContents.count
            && zip(next, allPreviewContents).allSatisfy { $0.hasSameArtwork(as: $1) }
        guard !unchanged else { return }
        resetAllPreview()
        allPreviewContents = next
        let generation = allPreviewGeneration
        let expectedCellID = boundCellID
        for (index, preview) in next.enumerated() {
            if let local = resolvedLocalArtwork(for: preview) {
                allArtworkViews[index].image = local.image.withRenderingMode(
                    local.isTemplate ? .alwaysTemplate : .alwaysOriginal
                )
            }
            guard !preview.imageURL.isEmpty else { continue }
            let expectedURL = preview.imageURL
            let requestView = UIImageView()
            allPreviewRequestViews[index] = requestView
            PPImageLoaderManager.shared().setImage(
                on: requestView, url: expectedURL, placeholder: nil, transitionStyle: .none
            ) { [weak self] image, _ in
                let applyResult = {
                    guard let self, self.allPreviewGeneration == generation,
                          self.boundCellID == expectedCellID, self.content?.isAll == true,
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

    // MARK: - One native button, two presentation planes

    private func buildViewGraph() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        isAccessibilityElement = false
        contentView.isAccessibilityElement = false
        actionButton.isExclusiveTouch = true
        actionButton.isAccessibilityElement = true
        actionButton.showsLargeContentViewer = true
        actionButton.scalesLargeContentImage = true
        actionButton.addInteraction(UILargeContentViewerInteraction())
        actionButton.isPointerInteractionEnabled = true
        actionButton.addTarget(self, action: #selector(handleTouchDown), for: [.touchDown, .touchDragEnter])
        actionButton.addTarget(self, action: #selector(handleTouchRelease), for: [.touchUpOutside, .touchCancel, .touchDragExit])
        // A single semantic event also handles VoiceOver and keyboard activation.
        actionButton.addTarget(self, action: #selector(handleActivation), for: .primaryActionTriggered)
        contentView.addSubview(actionButton)
        accessibilityElements = [actionButton]

        for view in [pressureContainer, perchView, portraitContainer, titleLabel, selectionKeel] {
            view.isUserInteractionEnabled = false
            view.isAccessibilityElement = false
            view.backgroundColor = .clear
        }
        actionButton.addSubview(pressureContainer)
        pressureContainer.addSubview(perchView)
        perchView.layer.addSublayer(perchLayer)
        perchView.addSubview(titleLabel)
        perchView.addSubview(selectionKeel)
        pressureContainer.addSubview(portraitContainer)
        selectionKeel.layer.cornerRadius = PPSpace.xxs
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = false
        titleLabel.adjustsFontForContentSizeCategory = true

        for view in [artworkView] + allArtworkViews.reversed() {
            view.contentMode = .scaleAspectFit
            view.isUserInteractionEnabled = false
            view.isAccessibilityElement = false
            view.accessibilityIgnoresInvertColors = true
            portraitContainer.addSubview(view)
        }
        allArtworkViews.forEach { $0.isHidden = true }
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
        for name in ["LanguageDidChangeNotification", "PPLanguageDidChangeNotification"] {
            observers.append(center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                self?.environmentDidChange(refreshLocalizedContent: true)
            })
        }
        observers.append(center.addObserver(
            forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.stopAllMotion() })
        observers.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.stopAllMotion() })
    }

    private func environmentDidChange(refreshLocalizedContent: Bool) {
        stopAllMotion()
        if refreshLocalizedContent, let current = content {
            content = MainKindsV2Content(kind: current.kind, isAll: current.isAll)
            boundCellID = content?.cellID
        }
        applyLayoutDirection()
        updateTypography()
        updateContent()
        updateAppearance()
        applySelectionPose()
        setNeedsLayout()
    }

    private func applyLayoutDirection() {
        let semantic = Language.semanticAttributeForCurrentLanguage()
        for view in [self, contentView, actionButton, pressureContainer, perchView, titleLabel] {
            view.semanticContentAttribute = semantic
        }
        // Animal identity is physical content, not a directional UI glyph.
        portraitContainer.semanticContentAttribute = .forceLeftToRight
        ([artworkView] + allArtworkViews).forEach { $0.semanticContentAttribute = .forceLeftToRight }
    }

    private func updateTypography() {
        titleLabel.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
            for: MainKindsCellV2Layout.captionFont(
                size: MainKindsCellV2Layout.captionPointSize,
                bold: isKindSelected || UIAccessibility.isBoldTextEnabled
            ), compatibleWith: traitCollection
        )
        titleLabel.numberOfLines = usesExpandedTextLayout ? 0 : 2
        titleLabel.lineBreakMode = usesExpandedTextLayout ? .byWordWrapping : .byTruncatingTail
    }

    private func updateContent() {
        guard let content else { return }
        titleLabel.text = content.title
        actionButton.accessibilityLabel = content.title
        actionButton.accessibilityIdentifier = content.isAll
            ? "home.mainKinds.all" : "home.mainKinds.\(content.numericID)"
        actionButton.largeContentTitle = content.title
        actionButton.largeContentImage = artworkView.image
    }

    private func updateAppearance() {
        let colors = MainKindsV2Palette.resolve(accent: content?.accent ?? .ppPrimary, traits: traitCollection)
        let ink = isKindSelected ? colors.selectedInk : UIColor.ppTextPrimary.resolvedColor(with: traitCollection)
        titleLabel.textColor = ink
        selectionKeel.backgroundColor = ink
        selectionKeel.isHidden = !isKindSelected
        artworkView.tintColor = colors.accent
        allArtworkViews.forEach { $0.tintColor = colors.accent }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        perchLayer.fillColor = (isKindSelected ? colors.accent : colors.restingSurface).cgColor
        perchLayer.strokeColor = UIColor.ppTextPrimary.resolvedColor(with: traitCollection).cgColor
        perchLayer.lineWidth = traitCollection.accessibilityContrast == .high ? 1.5 : 0
        CATransaction.commit()
    }

    private func updateInteractionAvailability() {
        actionButton.isEnabled = content != nil && onSelect != nil && !activationInFlight
        var traits: UIAccessibilityTraits = .button
        if isKindSelected { traits.insert(.selected) }
        if !actionButton.isEnabled { traits.insert(.notEnabled) }
        actionButton.accessibilityTraits = traits
        pressureContainer.alpha = content != nil && onSelect == nil ? 0.55 : 1
    }

    // MARK: - Reuse-safe shared-loader requests

    private func configurePrimaryArtwork(for content: MainKindsV2Content) {
        cancelPrimaryImageRequest()
        let placeholder = resolvedPlaceholder(for: content)
        artworkView.image = placeholder.image?.withRenderingMode(placeholder.isTemplate ? .alwaysTemplate : .alwaysOriginal)
        actionButton.largeContentImage = artworkView.image
        guard !content.isAll, !content.imageURL.isEmpty else { return }
        let generation = primaryImageGeneration
        let expectedCellID = content.cellID
        let expectedURL = content.imageURL
        // The shared loader writes to its target before calling completion.
        // Only detached request views may receive those unchecked writes.
        let requestView = UIImageView()
        primaryImageRequestView = requestView
        PPImageLoaderManager.shared().setImage(
            on: requestView, url: expectedURL, placeholder: nil, transitionStyle: .none
        ) { [weak self] image, _ in
            let applyResult = {
                guard let self, self.primaryImageGeneration == generation,
                      self.boundCellID == expectedCellID,
                      self.content?.imageURL == expectedURL else { return }
                self.primaryImageRequestView = nil
                guard let image else { return }
                self.artworkView.image = image.withRenderingMode(.alwaysOriginal)
                self.actionButton.largeContentImage = self.artworkView.image
            }
            if Thread.isMainThread { applyResult() }
            else { DispatchQueue.main.async(execute: applyResult) }
        }
    }

    private func resolvedPlaceholder(for content: MainKindsV2Content) -> (image: UIImage?, isTemplate: Bool) {
        if content.isAll { return (UIImage(named: "menugrid") ?? UIImage(systemName: "line.3.horizontal"), true) }
        if let local = resolvedLocalArtwork(for: content) { return (local.image, local.isTemplate) }
        return (UIImage(systemName: "pawprint.fill"), true)
    }

    private func resolvedLocalArtwork(for content: MainKindsV2Content) -> (image: UIImage, isTemplate: Bool)? {
        if let image = content.localImage { return (image, false) }
        if !content.assetName.isEmpty, let image = UIImage(named: content.assetName) { return (image, false) }
        if !content.iconName.isEmpty, let image = UIImage(named: content.iconName) { return (image, false) }
        if !content.iconName.isEmpty, let image = UIImage(systemName: content.iconName) { return (image, true) }
        return nil
    }

    private func cancelPrimaryImageRequest() {
        primaryImageGeneration &+= 1
        if let view = primaryImageRequestView { PPImageLoaderManager.shared().cancelImageLoad(for: view) }
        primaryImageRequestView = nil
    }

    private func cancelAllPreviewRequests() {
        allPreviewGeneration &+= 1
        allPreviewRequestViews.compactMap { $0 }.forEach { PPImageLoaderManager.shared().cancelImageLoad(for: $0) }
        allPreviewRequestViews = Array(repeating: nil, count: allArtworkViews.count)
    }

    private func resetAllPreview() {
        cancelAllPreviewRequests()
        allPreviewContents.removeAll()
        allArtworkViews.forEach { $0.image = nil; $0.isHidden = true }
        artworkView.isHidden = false
    }

    private func updateAllArtworkVisibility() {
        guard content?.isAll == true else { return }
        let hasEnsemble = allArtworkViews.filter { $0.image != nil }.count >= 2
        artworkView.isHidden = hasEnsemble
        allArtworkViews.forEach { $0.isHidden = !hasEnsemble || $0.image == nil }
        setNeedsLayout()
    }

    private func layoutAllArtwork() {
        let canvas = portraitContainer.bounds
        let views = allArtworkViews.filter { !$0.isHidden }
        for (index, view) in views.enumerated() {
            let normalized: CGRect
            if views.count == 2 {
                normalized = index == 0
                    ? CGRect(x: 0.02, y: 0.12, width: 0.64, height: 0.86)
                    : CGRect(x: 0.34, y: 0.04, width: 0.64, height: 0.86)
            } else {
                switch index {
                case 0: normalized = CGRect(x: 0.16, y: 0.18, width: 0.68, height: 0.80)
                case 1: normalized = CGRect(x: 0.00, y: 0.02, width: 0.58, height: 0.76)
                default: normalized = CGRect(x: 0.42, y: 0.02, width: 0.58, height: 0.76)
                }
            }
            view.frame = CGRect(
                x: normalized.minX * canvas.width, y: normalized.minY * canvas.height,
                width: normalized.width * canvas.width, height: normalized.height * canvas.height
            ).integral
        }
    }

    // MARK: - Finite, interruptible touch and selection motion

    @objc private func handleTouchDown() {
        guard !activationInFlight else { return }
        animatePressure(pressed: true)
    }

    @objc private func handleTouchRelease() {
        guard !activationInFlight else { return }
        animatePressure(pressed: false)
    }

    @objc private func handleActivation() {
        let now = CACurrentMediaTime()
        guard !activationInFlight, now - lastActivationTime >= 0.25,
              let content, let expectedCellID = boundCellID,
              onSelect != nil, window != nil else {
            if !activationInFlight { animatePressure(pressed: false) }
            return
        }
        lastActivationTime = now
        stopPressureMotion()
        guard !reduceMotion else {
            pressureContainer.transform = .identity
            onSelect?(content.kind, content.isAll)
            return
        }
        activationInFlight = true
        updateInteractionAvailability()
        activationGeneration &+= 1
        let generation = activationGeneration
        // Preserve the existing 200ms release-before-route contract. No haptic
        // or optimistic selected state here: HomeStore is the sole owner.
        let animator = UIViewPropertyAnimator(duration: 0.20, dampingRatio: 0.86) { [weak self] in
            self?.pressureContainer.transform = .identity
        }
        animator.addCompletion { [weak self] position in
            guard let self, position == .end,
                  self.activationGeneration == generation,
                  self.boundCellID == expectedCellID, self.window != nil else { return }
            self.activationAnimator = nil
            self.activationInFlight = false
            self.updateInteractionAvailability()
            self.onSelect?(content.kind, content.isAll)
        }
        activationAnimator = animator
        animator.startAnimation()
    }

    private func animatePressure(pressed: Bool) {
        stopPressureMotion()
        guard !reduceMotion, window != nil else {
            pressureContainer.transform = .identity
            return
        }
        pressureGeneration &+= 1
        let generation = pressureGeneration
        let animator = UIViewPropertyAnimator(
            duration: pressed ? 0.10 : 0.20, dampingRatio: 0.86
        ) { [weak self] in
            self?.pressureContainer.transform = pressed
                ? CGAffineTransform(translationX: 0, y: PPSpace.xxs).scaledBy(x: 0.975, y: 0.975)
                : .identity
        }
        animator.addCompletion { [weak self] _ in
            guard let self, self.pressureGeneration == generation else { return }
            self.pressureAnimator = nil
        }
        pressureAnimator = animator
        animator.startAnimation()
    }

    private func animateSelection(restored: Bool) {
        stopSelectionMotion()
        guard !reduceMotion, window != nil else { applySelectionPose(); return }
        selectionGeneration &+= 1
        let generation = selectionGeneration
        let animator = UIViewPropertyAnimator(duration: restored ? 0.16 : 0.26, dampingRatio: 0.84) { [weak self] in
            self?.applySelectionPose()
        }
        animator.addCompletion { [weak self] _ in
            guard let self, self.selectionGeneration == generation else { return }
            self.selectionAnimator = nil
        }
        selectionAnimator = animator
        animator.startAnimation()
    }

    private func applySelectionPose() {
        let lifted = isKindSelected && !reduceMotion
        perchView.transform = lifted ? CGAffineTransform(translationX: 0, y: -PPSpace.xxs) : .identity
        portraitContainer.transform = lifted ? CGAffineTransform(translationX: 0, y: -PPSpace.xs) : .identity
    }

    private func stopPressureMotion() {
        pressureGeneration &+= 1
        if let animator = pressureAnimator {
            animator.stopAnimation(false)
            animator.finishAnimation(at: .current)
        }
        pressureAnimator = nil
    }

    private func stopSelectionMotion() {
        selectionGeneration &+= 1
        if let animator = selectionAnimator {
            animator.stopAnimation(false)
            animator.finishAnimation(at: .current)
        }
        selectionAnimator = nil
    }

    private func stopAllMotion() {
        activationGeneration &+= 1
        activationAnimator?.stopAnimation(true)
        activationAnimator = nil
        activationInFlight = false
        stopPressureMotion()
        stopSelectionMotion()
        pressureContainer.transform = .identity
        applySelectionPose()
        updateInteractionAvailability()
    }
}

// MARK: - Shared measured geometry: identical inputs in the cell and Home rail

struct MainKindsCellV2Layout {
    static let captionPointSize: CGFloat = 18
    private static let textInset: CGFloat = PPSpace.sm + PPSpace.xs
    private static let portraitInset: CGFloat = PPSpace.sm
    private static let captionGap: CGFloat = PPSpace.xs
    private static let footerHeight: CGFloat = PPSpace.base

    let portraitFrame: CGRect
    let perchFrame: CGRect
    let titleFrame: CGRect
    let keelFrame: CGRect

    init(bounds: CGRect, title: String, fontSize: CGFloat, expandedText: Bool) {
        let width = max(0, bounds.width)
        let pictureHeight = Self.portraitHeight(width: width, expandedText: expandedText)
        let textHeight = Self.maximumCaptionHeight(width: width, titles: [title], fontSize: fontSize, expandedText: expandedText)
        portraitFrame = CGRect(x: Self.portraitInset, y: PPSpace.sm,
                               width: max(0, width - Self.portraitInset * 2), height: pictureHeight)
        titleFrame = CGRect(x: Self.textInset, y: portraitFrame.maxY + Self.captionGap,
                            width: max(0, width - Self.textInset * 2), height: textHeight)
        // The curved shoulder supports the animal; the footer reserves the same
        // geometry in every state, so the selected keel never steals text width.
        perchFrame = CGRect(x: PPSpace.xs, y: portraitFrame.maxY - PPSpace.md,
                            width: max(0, width - PPSpace.xs * 2),
                            height: PPSpace.md + Self.captionGap + textHeight + Self.footerHeight)
        keelFrame = CGRect(x: (width - PPSpace.lg) / 2, y: titleFrame.maxY + PPSpace.xs,
                           width: PPSpace.lg, height: PPSpace.xs)
    }

    static func captionFont(size: CGFloat, bold: Bool) -> UIFont {
        PPMainKindsGalleryLayout.captionFont(size: size, bold: bold)
    }

    static func preferredHeight(width: CGFloat, titles: [String], fontSize: CGFloat, expandedText: Bool) -> CGFloat {
        max(44, PPSpace.sm + portraitHeight(width: width, expandedText: expandedText)
            + captionGap + maximumCaptionHeight(width: width, titles: titles, fontSize: fontSize, expandedText: expandedText)
            + footerHeight + PPSpace.xs)
    }

    private static func portraitHeight(width: CGFloat, expandedText: Bool) -> CGFloat {
        min(max(0, width - portraitInset * 2), expandedText ? 124 : 100)
    }

    private static func maximumCaptionHeight(width: CGFloat, titles: [String], fontSize: CGFloat, expandedText: Bool) -> CGFloat {
        let labelWidth = max(1, width - textInset * 2)
        let fonts = [captionFont(size: fontSize, bold: false), captionFont(size: fontSize, bold: true)]
        return titles.reduce(ceil(fonts.map(\.lineHeight).max() ?? fontSize)) { maximum, title in
            fonts.reduce(maximum) { current, font in
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byWordWrapping
                let measured = ceil((title as NSString).boundingRect(
                    with: CGSize(width: labelWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font, .paragraphStyle: paragraph], context: nil
                ).height)
                let height = expandedText ? measured : min(measured, ceil(font.lineHeight) * 2)
                return max(current, max(ceil(font.lineHeight), height))
            }
        }
    }

    static func perchPath(in bounds: CGRect) -> UIBezierPath {
        let width = bounds.width, height = bounds.height
        guard width > 0, height > 0 else { return UIBezierPath() }
        let corner = min(PPCorner.small, width / 2, height / 2)
        let shoulder = min(PPSpace.sm, height / 4)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: corner, y: shoulder))
        path.addQuadCurve(to: CGPoint(x: width - corner, y: shoulder), controlPoint: CGPoint(x: width / 2, y: 0))
        path.addQuadCurve(to: CGPoint(x: width, y: shoulder + corner), controlPoint: CGPoint(x: width, y: shoulder))
        path.addLine(to: CGPoint(x: width, y: height - corner))
        path.addQuadCurve(to: CGPoint(x: width - corner, y: height), controlPoint: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: corner, y: height))
        path.addQuadCurve(to: CGPoint(x: 0, y: height - corner), controlPoint: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: shoulder + corner))
        path.addQuadCurve(to: CGPoint(x: corner, y: shoulder), controlPoint: CGPoint(x: 0, y: shoulder))
        path.close()
        return path
    }
}

// MARK: - Presentation-only adaptation; no data or navigation ownership

private struct MainKindsV2Content {
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
        let presentation = kind.map { PPHomeDataBridge.categoryPresentation(for: $0) } ?? [:]
        let model = kind as? MainKindsModel
        numericID = (presentation["numericID"] as? NSNumber)?.intValue ?? model?.id ?? 0
        title = (presentation["title"] as? String) ?? model?.kindName ?? ""
        imageURL = (presentation["imageURL"] as? String) ?? model?.kindImageUrl ?? ""
        localImage = presentation["localImage"] as? UIImage
        assetName = model?.kindImageNamed ?? ""
        iconName = model?.kindIconName ?? ""
        accent = (presentation["accent"] as? UIColor) ?? .ppPrimary
        let documentID = presentation["id"] as? String ?? ""
        let stableIdentity = documentID.isEmpty ? "main-kind-\(numericID)" : documentID
        cellID = [stableIdentity, imageURL].joined(separator: "|")
    }

    func hasSameArtwork(as other: Self) -> Bool {
        cellID == other.cellID && assetName == other.assetName
            && iconName == other.iconName && localImage === other.localImage
    }
}

private enum MainKindsV2Palette {
    struct Colors {
        let accent: UIColor
        let selectedInk: UIColor
        let restingSurface: UIColor
    }

    static func resolve(accent: UIColor, traits: UITraitCollection) -> Colors {
        let text = UIColor.ppTextPrimary.resolvedColor(with: traits)
        let surface = UIColor.ppSurface.resolvedColor(with: traits)
        let brand = UIColor.ppPrimary.resolvedColor(with: traits)
        let resting = UIColor.ppWarmPorcelain.resolvedColor(with: traits)
        let background = UIColor.ppBackground.resolvedColor(with: traits)
        let proposed = accent.resolvedColor(with: traits)
        let opaque = proposed.cgColor.alpha >= 0.12 ? proposed.withAlphaComponent(1) : brand
        let choices = [opaque, mix(opaque, with: text), brand, text]
        // Always derive from actual semantic tokens; no assumed light/dark ink.
        let fill = choices.first {
            contrast($0, background) >= 3 && max(contrast($0, text), contrast($0, surface)) >= 4.5
        } ?? text
        let ink = contrast(fill, surface) >= contrast(fill, text) ? surface : text
        return Colors(accent: fill, selectedInk: ink, restingSurface: resting)
    }

    private static func mix(_ color: UIColor, with text: UIColor) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        guard color.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              text.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else { return text }
        return UIColor(red: r1 * 0.64 + r2 * 0.36, green: g1 * 0.64 + g2 * 0.36,
                       blue: b1 * 0.64 + b2 * 0.36, alpha: 1)
    }

    private static func contrast(_ first: UIColor, _ second: UIColor) -> CGFloat {
        let a = luminance(first), b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private static func luminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return 0 }
        func linear(_ value: CGFloat) -> CGFloat {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
