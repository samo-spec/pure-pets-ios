import UIKit

// MARK: - Home species portraits

/// Home's UIKit species selector. The portrait field and caption form one
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
    private let portraitContainer = UIView()
    private let fieldLayer = CAShapeLayer()
    private let artworkView = UIImageView()
    private let selectionSeal = UIView()
    private let checkmarkView = UIImageView()
    private let titleLabel = UILabel()

    // MARK: Content and lifecycle

    private var content: PPMainKindsContent?
    private var isKindSelected = false
    private var usesRestoredSelectionAppearance = false
    private var hasConfigured = false
    private var primaryImageGeneration = 0
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
        stopAllMotion()
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        cancelPrimaryImageRequest()
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

        let geometry = PPMainKindsGeometry(
            bounds: actionButton.bounds,
            titleFont: titleLabel.font,
            expandedText: usesExpandedTextLayout,
            isRightToLeft: effectiveUserInterfaceLayoutDirection == .rightToLeft
        )
        portraitContainer.bounds = CGRect(origin: .zero, size: geometry.portraitFrame.size)
        portraitContainer.center = CGPoint(
            x: geometry.portraitFrame.midX, y: geometry.portraitFrame.midY
        )
        titleLabel.frame = geometry.titleFrame
        selectionSeal.bounds = CGRect(origin: .zero, size: geometry.sealFrame.size)
        selectionSeal.center = CGPoint(x: geometry.sealFrame.midX, y: geometry.sealFrame.midY)
        selectionSeal.layer.cornerRadius = geometry.sealFrame.height / 2
        checkmarkView.frame = selectionSeal.bounds.insetBy(dx: 5, dy: 5)

        let artworkCanvas = CGRect(
            x: PPSpace.sm, y: PPSpace.sm,
            width: max(0, portraitContainer.bounds.width - PPSpace.sm * 2),
            height: max(0, portraitContainer.bounds.height - PPSpace.sm * 2)
        )
        if content?.isAll == true {
            let side = min(artworkCanvas.width, artworkCanvas.height) * 0.48
            artworkView.frame = CGRect(
                x: artworkCanvas.midX - side / 2,
                y: artworkCanvas.midY - side / 2,
                width: side, height: side
            ).integral
        } else {
            // The field has a silhouette, the artwork has no mask. Optical
            // profiles remain shared with Home; animal images never reflect.
            artworkView.frame = HomeSpeciesArtworkTreatment
                .resolved(for: content?.numericID ?? 0)
                .frame(in: artworkCanvas)
        }
        artworkView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: max(20, min(artworkView.bounds.width, artworkView.bounds.height) * 0.70),
            weight: .medium
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fieldLayer.frame = portraitContainer.bounds
        let fieldPath = PPMainKindsGeometry.portraitPath(in: portraitContainer.bounds)
        fieldLayer.path = fieldPath.cgPath
        portraitContainer.layer.shadowPath = fieldPath.cgPath
        CATransaction.commit()
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

    /// All retains its single approved menugrid symbol and original callback.
    /// Home still supplies this hook; it creates no extra requests or state.
    public func configureAllPreview(withMainKinds kinds: [NSObject]) {
        guard content?.isAll == true else { return }
        updateLargeContentImage()
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

        portraitContainer.isUserInteractionEnabled = false
        portraitContainer.isAccessibilityElement = false
        portraitContainer.clipsToBounds = false
        fieldLayer.name = "PPMainKindsPortraitField"
        portraitContainer.layer.addSublayer(fieldLayer)
        actionButton.addSubview(portraitContainer)

        artworkView.contentMode = .scaleAspectFit
        artworkView.clipsToBounds = false
        artworkView.isAccessibilityElement = false
        artworkView.accessibilityIgnoresInvertColors = true
        portraitContainer.addSubview(artworkView)

        selectionSeal.isUserInteractionEnabled = false
        selectionSeal.isAccessibilityElement = false
        selectionSeal.layer.cornerCurve = .continuous
        checkmarkView.image = UIImage(
            systemName: "checkmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        )
        checkmarkView.contentMode = .scaleAspectFit
        checkmarkView.isAccessibilityElement = false
        selectionSeal.addSubview(checkmarkView)
        portraitContainer.addSubview(selectionSeal)

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
        // Only the seal's logical trailing position changes. The subject's
        // pose and any text inside an image are preserved in both languages.
        portraitContainer.semanticContentAttribute = .forceLeftToRight
        artworkView.semanticContentAttribute = .forceLeftToRight
        artworkView.transform = .identity
    }

    private func updateTypography() {
        let bold = isKindSelected || UIAccessibility.isBoldTextEnabled
        let baseFont = UIFont(name: bold ? "Beiruti-Bold" : "Beiruti-Medium", size: 15)
            ?? UIFont.systemFont(ofSize: 15, weight: bold ? .bold : .medium)
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
        let surface = UIColor.ppSurfaceRaised.resolvedColor(with: traitCollection)
        let text = UIColor.ppTextPrimary.resolvedColor(with: traitCollection)
        let border = UIColor.ppSurfaceBorder.resolvedColor(with: traitCollection)
        let kindColor = content?.accent.resolvedColor(with: traitCollection).ppMainKindOpaque
            ?? UIColor.ppPrimary.resolvedColor(with: traitCollection)
        let accent = resolvedAccent
        let highContrast = traitCollection.accessibilityContrast == .high
        let isDark = traitCollection.userInterfaceStyle == .dark

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Opaque, token-derived fields keep the same hierarchy with Reduce
        // Transparency. Only the chosen species receives its identity color.
        fieldLayer.fillColor = (isKindSelected
            ? kindColor.ppMainKindMixed(with: surface, amountOfSelf: isDark ? 0.18 : 0.09)
            : surface).cgColor
        fieldLayer.strokeColor = (isKindSelected ? accent : border)
            .withAlphaComponent(highContrast ? 1 : (isKindSelected ? 0.55 : 0.65)).cgColor
        fieldLayer.lineWidth = highContrast ? 1.5 : 0.75
        portraitContainer.layer.shadowColor = UIColor.black.cgColor
        portraitContainer.layer.shadowOpacity = highContrast ? 0 : (isDark ? 0.08 : 0.035)
        portraitContainer.layer.shadowRadius = PPSpace.sm
        portraitContainer.layer.shadowOffset = CGSize(width: 0, height: PPSpace.xxs)
        selectionSeal.layer.borderWidth = highContrast ? 2 : 1.5
        selectionSeal.layer.borderColor = surface.cgColor
        CATransaction.commit()

        selectionSeal.backgroundColor = accent
        checkmarkView.tintColor = UIColor.white.ppMainKindContrastRatio(against: accent)
            >= UIColor.black.ppMainKindContrastRatio(against: accent) ? .white : .black
        selectionSeal.alpha = isKindSelected ? 1 : 0
        titleLabel.textColor = text
        artworkView.tintColor = content?.isAll == true && !isKindSelected
            ? .ppTextSecondary : accent
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
        PPImageLoaderManager.shared().setImage(
            on: artworkView, url: expectedURL,
            placeholder: artworkView.image, transitionStyle: .none
        ) { [weak self] image, _ in
            let applyResult = {
                guard let self,
                      self.primaryImageGeneration == generation,
                      self.boundCellID == expectedCellID,
                      self.content?.imageURL == expectedURL,
                      let image else { return }
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
        if let image = content.localImage { return (image, false) }
        if !content.assetName.isEmpty, let image = UIImage(named: content.assetName) { return (image, false) }
        if !content.iconName.isEmpty, let image = UIImage(named: content.iconName) { return (image, false) }
        if !content.iconName.isEmpty, let image = UIImage(systemName: content.iconName) { return (image, true) }
        return (UIImage(systemName: "pawprint.fill"), true)
    }

    private func updateLargeContentImage() { actionButton.largeContentImage = artworkView.image }

    private func cancelPrimaryImageRequest() {
        primaryImageGeneration &+= 1
        PPImageLoaderManager.shared().cancelImageLoad(for: artworkView)
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
        guard !reduceMotion, window != nil else {
            updateAppearance()
            return
        }
        stateGeneration &+= 1
        let generation = stateGeneration
        let animator = UIViewPropertyAnimator(duration: restored ? 0.12 : 0.18, curve: .easeOut) { [weak self] in
            self?.updateAppearance()
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
        selectionSeal.layer.removeAllAnimations()
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

// MARK: - Adaptive portrait geometry

private struct PPMainKindsGeometry {
    let portraitFrame: CGRect
    let titleFrame: CGRect
    let sealFrame: CGRect

    init(bounds: CGRect, titleFont: UIFont, expandedText: Bool, isRightToLeft: Bool) {
        let inset = PPSpace.xs
        let captionHeight = ceil(titleFont.lineHeight) * (expandedText ? 3 : 2)
        let gap = PPSpace.md
        let availableHeight = max(0, bounds.height - captionHeight - gap - inset * 2)
        let width = min(max(0, bounds.width - inset * 2), expandedText ? 124 : 144)
        let height = min(availableHeight, width * 0.98)
        portraitFrame = CGRect(
            x: bounds.midX - width / 2, y: inset, width: width, height: height
        ).integral
        titleFrame = CGRect(
            x: inset,
            y: portraitFrame.maxY + gap,
            width: max(0, bounds.width - inset * 2),
            height: max(0, bounds.maxY - portraitFrame.maxY - gap - inset)
        ).integral

        let sealSide: CGFloat = 22
        // Its lower trailing position leaves ears, horns, and wings untouched.
        sealFrame = CGRect(
            x: isRightToLeft ? 0 : max(0, width - sealSide),
            y: max(0, height - sealSide + inset),
            width: sealSide, height: sealSide
        ).integral
    }

    /// A soft shoulder above a grounded base. This shapes the background only.
    static func portraitPath(in bounds: CGRect) -> UIBezierPath {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        guard rect.width > 0, rect.height > 0 else { return UIBezierPath() }
        let shoulder = min(rect.width * 0.5, rect.height * 0.54)
        let foot = min(PPCorner.card, rect.height * 0.22)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + shoulder))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + shoulder, y: rect.minY),
            controlPoint: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - shoulder, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + shoulder),
            controlPoint: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - foot))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - foot, y: rect.maxY),
            controlPoint: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + foot, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - foot),
            controlPoint: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.close()
        return path
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
