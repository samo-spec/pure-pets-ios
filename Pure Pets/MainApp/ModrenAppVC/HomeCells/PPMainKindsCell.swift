import UIKit

// MARK: - Production contract

/// A category is not decorative content on Home. It is the scope that changes
/// every marketplace rail below it. This cell therefore presents one strong,
/// non-colour-only selection truth while leaving ordering, persistence,
/// routing, Firebase state, and haptics with Home's existing owners.
@objc(PPMainKindsCell)
public final class PPMainKindsCell: UICollectionViewCell {
    @objc public class var reuseIdentifier: String { "PPMainKindsCell" }

    /// Preserved Objective-C/Swift integration seam. The callback remains an
    /// identity-preserving handoff of the original model and the All flag.
    @objc public var onSelect: ((NSObject?, Bool) -> Void)?
    @objc public var boundCellID: String?

    // MARK: View graph

    private let actionButton = UIButton(type: .custom)
    private let surfaceView = UIView()
    private let canvasView = UIView()
    private let canopyView = UIView()
    private let portalView = UIView()
    private let artworkView = UIImageView()
    private let horizonView = UIView()
    private let titleLabel = UILabel()
    private let scopeMarkView = UIView()
    private let scopeMarkImageView = UIImageView()

    private let canopyLayer = CAGradientLayer()
    private let portalWashLayer = CAGradientLayer()

    // MARK: State

    private var content: PPMainKindsContent?
    private var isKindSelected = false
    private var usesRestoredSelectionAppearance = false
    private var hasConfigured = false
    private var imageGeneration = 0
    private var lastActivationTime: CFTimeInterval = 0

    /// Every motion entry point consults this value before constructing an
    /// animator, and the accessibility notification settles in-flight motion.
    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    private var stateAnimator: UIViewAnimating?
    private var pressAnimator: UIViewAnimating?
    private var motionGeneration = 0
    private var pressGeneration = 0
    private var observers: [NSObjectProtocol] = []

    // MARK: Lifecycle

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
        PPImageLoaderManager.shared().cancelImageLoad(for: artworkView)
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        cancelImageRequest()
        stopAllMotion(settle: false)

        onSelect = nil
        boundCellID = nil
        content = nil
        isKindSelected = false
        usesRestoredSelectionAppearance = false
        hasConfigured = false
        lastActivationTime = 0

        titleLabel.text = nil
        artworkView.image = nil
        actionButton.accessibilityLabel = nil
        actionButton.accessibilityIdentifier = nil
        actionButton.accessibilityTraits = .button
        actionButton.largeContentTitle = nil
        actionButton.largeContentImage = nil

        updateTypography()
        updatePalette()
        applyCurrentVisualState()
        setNeedsLayout()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopAllMotion(settle: true)
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        setLayoutRect(contentView.bounds, on: actionButton)
        setLayoutRect(actionButton.bounds, on: surfaceView)
        canvasView.frame = surfaceView.bounds

        let geometry = PPMainKindsGeometry(
            bounds: canvasView.bounds,
            usesExpandedText: usesExpandedTextLayout,
            isRightToLeft: effectiveUserInterfaceLayoutDirection == .rightToLeft
        )
        canopyView.frame = geometry.canopyFrame
        setLayoutRect(geometry.portalFrame, on: portalView)
        setLayoutRect(geometry.artworkFrame, on: artworkView)
        setLayoutRect(geometry.horizonFrame, on: horizonView)
        titleLabel.frame = geometry.titleFrame
        setLayoutRect(geometry.scopeMarkFrame, on: scopeMarkView)
        scopeMarkImageView.frame = scopeMarkView.bounds.insetBy(
            dx: PPMainKindsMetrics.scopeMarkGlyphInset,
            dy: PPMainKindsMetrics.scopeMarkGlyphInset
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        canopyLayer.frame = canopyView.bounds
        portalWashLayer.frame = portalView.bounds
        portalWashLayer.cornerRadius = portalView.bounds.height / 2
        portalView.layer.cornerRadius = portalView.bounds.height / 2
        horizonView.layer.cornerRadius = horizonView.bounds.height / 2
        scopeMarkView.layer.cornerRadius = scopeMarkView.bounds.height / 2
        surfaceView.layer.shadowPath = UIBezierPath(
            roundedRect: surfaceView.bounds,
            cornerRadius: PPMainKindsMetrics.cardRadius
        ).cgPath
        CATransaction.commit()
    }

    /// `frame` is undefined while a view has a non-identity transform. These
    /// views intentionally animate transforms, so geometry is always applied
    /// through their stable layout coordinates instead.
    private func setLayoutRect(_ rect: CGRect, on view: UIView) {
        view.bounds = CGRect(origin: .zero, size: rect.size)
        view.center = CGPoint(x: rect.midX, y: rect.midY)
    }

    public override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)

        let colorChanged = previousTraitCollection?.hasDifferentColorAppearance(
            comparedTo: traitCollection
        ) == true
        let contrastChanged = previousTraitCollection?.accessibilityContrast
            != traitCollection.accessibilityContrast
        let typeChanged = previousTraitCollection?.preferredContentSizeCategory
            != traitCollection.preferredContentSizeCategory
        let directionChanged = previousTraitCollection?.layoutDirection
            != traitCollection.layoutDirection

        guard colorChanged || contrastChanged || typeChanged || directionChanged else {
            return
        }
        stopAllMotion(settle: false)
        applyLayoutDirection()
        updateTypography()
        updatePalette()
        applyCurrentVisualState()
        setNeedsLayout()
    }

    // MARK: Public configuration

    @objc(configureWithMainKind:isAll:selected:)
    public func configure(
        withMainKind kind: NSObject?,
        isAll: Bool,
        selected: Bool
    ) {
        configure(
            withMainKind: kind,
            isAll: isAll,
            selected: selected,
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
        let nextContent = PPMainKindsContent(kind: kind, isAll: isAll)
        let bindingChanged = boundCellID != nextContent.cellID
        let selectionChanged = hasConfigured && isKindSelected != selected
        let shouldAnimateSelection = selectionChanged
            && window != nil
            && !restoredSelectionAppearance

        if bindingChanged {
            stopAllMotion(settle: false)
        }

        content = nextContent
        boundCellID = nextContent.cellID
        isKindSelected = selected
        usesRestoredSelectionAppearance = selected && restoredSelectionAppearance
        hasConfigured = true

        applyLayoutDirection()
        updateContent()
        updateTypography()
        updatePalette()

        if bindingChanged || artworkView.image == nil {
            configureArtwork(for: nextContent)
        } else if nextContent.isAll {
            artworkView.tintColor = resolvedArtworkTint
        }

        if shouldAnimateSelection {
            animateToCurrentState(enteringSelection: selected, restored: false)
        } else {
            applyCurrentVisualState()
        }
        setNeedsLayout()
    }

    /// Preserved lifecycle hook for callers that distinguish a restored Home
    /// scope from a scope explicitly chosen in the current session.
    @objc public func playRestoredSelectionAnimation() {
        guard window != nil,
              isKindSelected,
              usesRestoredSelectionAppearance else {
            return
        }
        animateToCurrentState(enteringSelection: true, restored: true)
    }

    /// Preserved lifecycle hook for the explicit selection transition.
    @objc public func playSelectionChangeAnimation() {
        guard window != nil,
              isKindSelected,
              !usesRestoredSelectionAppearance else {
            return
        }
        animateToCurrentState(enteringSelection: true, restored: false)
    }

    // MARK: Construction

    private func buildViewGraph() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = false
        layer.masksToBounds = false

        actionButton.frame = contentView.bounds
        actionButton.backgroundColor = .clear
        actionButton.adjustsImageWhenHighlighted = false
        actionButton.isExclusiveTouch = true
        actionButton.isAccessibilityElement = true
        actionButton.accessibilityTraits = .button
        actionButton.showsLargeContentViewer = true
        actionButton.addTarget(
            self,
            action: #selector(handleTouchDown),
            for: [.touchDown, .touchDragEnter]
        )
        actionButton.addTarget(
            self,
            action: #selector(handleTouchRelease),
            for: [.touchUpOutside, .touchCancel, .touchDragExit]
        )
        actionButton.addTarget(
            self,
            action: #selector(handleActivation),
            for: .touchUpInside
        )
        contentView.addSubview(actionButton)

        surfaceView.isUserInteractionEnabled = false
        surfaceView.layer.cornerRadius = PPMainKindsMetrics.cardRadius
        surfaceView.layer.cornerCurve = .continuous
        surfaceView.layer.masksToBounds = false
        actionButton.addSubview(surfaceView)

        canvasView.isUserInteractionEnabled = false
        canvasView.clipsToBounds = true
        canvasView.layer.cornerRadius = PPMainKindsMetrics.cardRadius
        canvasView.layer.cornerCurve = .continuous
        surfaceView.addSubview(canvasView)

        canopyView.isUserInteractionEnabled = false
        canopyView.isAccessibilityElement = false
        canopyLayer.name = "PPMainKindsCanopy"
        canopyLayer.startPoint = CGPoint(x: 0.5, y: 0)
        canopyLayer.endPoint = CGPoint(x: 0.5, y: 1)
        canopyView.layer.addSublayer(canopyLayer)
        canvasView.addSubview(canopyView)

        portalView.isUserInteractionEnabled = false
        portalView.isAccessibilityElement = false
        portalView.clipsToBounds = true
        portalView.layer.cornerCurve = .continuous
        portalWashLayer.name = "PPMainKindsPortalWash"
        portalWashLayer.type = .radial
        portalWashLayer.startPoint = CGPoint(x: 0.5, y: 0.44)
        portalWashLayer.endPoint = CGPoint(x: 1, y: 1)
        portalView.layer.addSublayer(portalWashLayer)
        canvasView.addSubview(portalView)

        artworkView.contentMode = .scaleAspectFit
        artworkView.clipsToBounds = false
        artworkView.isAccessibilityElement = false
        artworkView.accessibilityIgnoresInvertColors = true
        portalView.addSubview(artworkView)

        horizonView.isUserInteractionEnabled = false
        horizonView.isAccessibilityElement = false
        canvasView.addSubview(horizonView)

        titleLabel.backgroundColor = .clear
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.allowsDefaultTighteningForTruncation = true
        titleLabel.isAccessibilityElement = false
        canvasView.addSubview(titleLabel)

        scopeMarkView.isUserInteractionEnabled = false
        scopeMarkView.isAccessibilityElement = false
        scopeMarkView.layer.cornerCurve = .continuous
        scopeMarkView.layer.borderWidth = 2
        canvasView.addSubview(scopeMarkView)

        let checkConfiguration = UIImage.SymbolConfiguration(
            pointSize: 10,
            weight: .black,
            scale: .small
        )
        scopeMarkImageView.image = UIImage(
            systemName: "checkmark",
            withConfiguration: checkConfiguration
        )?.withRenderingMode(.alwaysTemplate)
        scopeMarkImageView.contentMode = .scaleAspectFit
        scopeMarkImageView.isAccessibilityElement = false
        scopeMarkView.addSubview(scopeMarkImageView)

        applyLayoutDirection()
        updateTypography()
        updatePalette()
        applyCurrentVisualState()
    }

    private func registerForEnvironmentChanges() {
        let center = NotificationCenter.default
        let environmentNames: [Notification.Name] = [
            UIAccessibility.reduceMotionStatusDidChangeNotification,
            UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            UIContentSizeCategory.didChangeNotification
        ]
        for name in environmentNames {
            observers.append(
                center.addObserver(
                    forName: name,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.environmentDidChange(refreshLocalizedContent: false)
                }
            )
        }

        for rawName in [
            "LanguageDidChangeNotification",
            "PPLanguageDidChangeNotification"
        ] {
            observers.append(
                center.addObserver(
                    forName: Notification.Name(rawName),
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.environmentDidChange(refreshLocalizedContent: true)
                }
            )
        }

        observers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.stopAllMotion(settle: true)
            }
        )
    }

    private func environmentDidChange(refreshLocalizedContent: Bool) {
        stopAllMotion(settle: false)
        if refreshLocalizedContent, let current = content {
            let refreshed = PPMainKindsContent(
                kind: current.kind,
                isAll: current.isAll
            )
            content = refreshed
            boundCellID = refreshed.cellID
        }
        applyLayoutDirection()
        updateContent()
        updateTypography()
        updatePalette()
        applyCurrentVisualState()
        setNeedsLayout()
    }

    // MARK: Content and artwork

    private func updateContent() {
        guard let content else { return }
        titleLabel.text = content.title
        actionButton.accessibilityLabel = content.title
        actionButton.accessibilityTraits = isKindSelected
            ? [.button, .selected]
            : .button
        actionButton.accessibilityIdentifier = content.isAll
            ? "home.mainKinds.all"
            : "home.mainKinds.\(content.numericID)"
        actionButton.largeContentTitle = content.title
        actionButton.largeContentImage = artworkView.image
    }

    private func configureArtwork(for content: PPMainKindsContent) {
        cancelImageRequest()

        let placeholder = resolvedPlaceholder(for: content)
        artworkView.image = placeholder.image?.withRenderingMode(
            placeholder.isTemplate ? .alwaysTemplate : .alwaysOriginal
        )
        artworkView.tintColor = resolvedArtworkTint
        actionButton.largeContentImage = artworkView.image

        guard !content.isAll, !content.imageURL.isEmpty else { return }
        imageGeneration &+= 1
        let expectedGeneration = imageGeneration
        let expectedNumericID = content.numericID
        let expectedURL = content.imageURL

        PPImageLoaderManager.shared().setImage(
            on: artworkView,
            url: expectedURL,
            placeholder: artworkView.image,
            transitionStyle: .none
        ) { [weak self] image, _ in
            let applyResult = {
                guard let self,
                      self.imageGeneration == expectedGeneration,
                      self.content?.numericID == expectedNumericID,
                      self.content?.imageURL == expectedURL,
                      let image else {
                    return
                }
                let resolvedImage = image.withRenderingMode(.alwaysOriginal)
                self.artworkView.image = resolvedImage
                self.actionButton.largeContentImage = resolvedImage
            }
            if Thread.isMainThread {
                applyResult()
            } else {
                DispatchQueue.main.async(execute: applyResult)
            }
        }
    }

    private func resolvedPlaceholder(
        for content: PPMainKindsContent
    ) -> (image: UIImage?, isTemplate: Bool) {
        if content.isAll {
            let configuration = UIImage.SymbolConfiguration(
                pointSize: 25,
                weight: .semibold,
                scale: .medium
            )
            let image = UIImage(
                systemName: "square.grid.2x2.fill",
                withConfiguration: configuration
            ) ?? UIImage(named: "square-layout")
            return (image, true)
        }
        if let localImage = content.localImage {
            return (localImage, false)
        }
        if !content.assetName.isEmpty,
           let image = UIImage(named: content.assetName) {
            return (image, false)
        }
        if !content.iconName.isEmpty,
           let image = UIImage(named: content.iconName) {
            return (image, false)
        }
        if !content.iconName.isEmpty,
           let image = UIImage(systemName: content.iconName) {
            return (image, true)
        }
        return (UIImage(systemName: "pawprint.fill"), true)
    }

    private func cancelImageRequest() {
        imageGeneration &+= 1
        PPImageLoaderManager.shared().cancelImageLoad(for: artworkView)
    }

    // MARK: Visual system

    private func applyLayoutDirection() {
        let semantic = Language.semanticAttributeForCurrentLanguage()
        semanticContentAttribute = semantic
        contentView.semanticContentAttribute = semantic
        actionButton.semanticContentAttribute = semantic
        surfaceView.semanticContentAttribute = semantic
        canvasView.semanticContentAttribute = semantic
        titleLabel.semanticContentAttribute = semantic
    }

    private func updateTypography() {
        let fontName = isKindSelected ? "Beiruti-Bold" : "Beiruti-Medium"
        let baseFont = UIFont(name: fontName, size: 15)
            ?? UIFont.systemFont(
                ofSize: 15,
                weight: isKindSelected ? .bold : .semibold
            )
        titleLabel.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
            for: baseFont,
            maximumPointSize: 24
        )
        titleLabel.numberOfLines = usesExpandedTextLayout ? 3 : 2
    }

    private var usesExpandedTextLayout: Bool {
        let category = traitCollection.preferredContentSizeCategory
        return category.isAccessibilityCategory || category == .extraExtraExtraLarge
    }

    private var resolvedAccent: UIColor {
        PPMainKindsPalette.accessibleAccent(
            content?.accent ?? .ppPrimary,
            on: .ppSurfaceRaised,
            traits: traitCollection
        )
    }

    private var resolvedArtworkTint: UIColor {
        if content?.isAll == true, !isKindSelected {
            return .ppTextSecondary
        }
        return resolvedAccent
    }

    private func updatePalette() {
        let accent = resolvedAccent.resolvedColor(with: traitCollection)
        let surface = UIColor.ppSurfaceRaised.resolvedColor(with: traitCollection)
        let highContrast = traitCollection.accessibilityContrast == .high
        let darkMode = traitCollection.userInterfaceStyle == .dark
        let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        canvasView.backgroundColor = surface
        titleLabel.textColor = .ppTextPrimary
        artworkView.tintColor = resolvedArtworkTint

        canopyLayer.isHidden = reduceTransparency
        canopyView.backgroundColor = reduceTransparency
            ? accent.ppMixed(with: surface, amountOfSelf: highContrast ? 0.22 : 0.14)
            : .clear
        canopyLayer.colors = [
            accent.withAlphaComponent(highContrast ? 0.34 : (darkMode ? 0.27 : 0.20)).cgColor,
            accent.withAlphaComponent(darkMode ? 0.10 : 0.07).cgColor,
            accent.withAlphaComponent(0).cgColor
        ]
        canopyLayer.locations = [0, 0.48, 1]

        portalWashLayer.isHidden = reduceTransparency
        portalView.backgroundColor = reduceTransparency
            ? accent.ppMixed(with: surface, amountOfSelf: highContrast ? 0.22 : 0.14)
            : .clear
        portalWashLayer.colors = [
            accent.withAlphaComponent(highContrast ? 0.30 : (darkMode ? 0.23 : 0.17)).cgColor,
            accent.withAlphaComponent(darkMode ? 0.10 : 0.07).cgColor,
            accent.withAlphaComponent(0.025).cgColor
        ]
        portalWashLayer.locations = [0, 0.68, 1]

        horizonView.backgroundColor = accent
        scopeMarkView.backgroundColor = UIColor.ppPrimary.resolvedColor(
            with: traitCollection
        )
        scopeMarkView.layer.borderColor = surface.cgColor
        scopeMarkImageView.tintColor = .white
        CATransaction.commit()
    }

    private func applyCurrentVisualState() {
        stopStateMotion(settle: false)
        apply(visualStyle: currentVisualStyle)
    }

    private var currentVisualStyle: PPMainKindsVisualStyle {
        let accent = resolvedAccent.resolvedColor(with: traitCollection)
        let surface = UIColor.ppSurfaceRaised.resolvedColor(with: traitCollection)
        let border = UIColor.ppSurfaceBorder.resolvedColor(with: traitCollection)
        let highContrast = traitCollection.accessibilityContrast == .high
        let darkMode = traitCollection.userInterfaceStyle == .dark

        if isKindSelected {
            return PPMainKindsVisualStyle(
                borderColor: accent.withAlphaComponent(highContrast ? 1 : (darkMode ? 0.92 : 0.78)),
                borderWidth: highContrast ? 2.25 : 1.5,
                portalBorderColor: accent.withAlphaComponent(highContrast ? 1 : 0.88),
                portalBorderWidth: highContrast ? 2.5 : 2,
                canopyAlpha: 1,
                scopeMarkAlpha: 1,
                scopeMarkTransform: .identity,
                portalTransform: CGAffineTransform(scaleX: 1.035, y: 1.035),
                horizonAlpha: 1,
                horizonTransform: .identity,
                surfaceTransform: CGAffineTransform(translationX: 0, y: -1),
                shadowOpacity: highContrast ? 0 : (darkMode ? 0.24 : 0.10),
                shadowRadius: darkMode ? 11 : 14,
                shadowOffset: CGSize(width: 0, height: darkMode ? 5 : 7)
            )
        }

        return PPMainKindsVisualStyle(
            borderColor: border.withAlphaComponent(highContrast ? 1 : 0.78),
            borderWidth: highContrast ? 1.5 : 1,
            portalBorderColor: border.withAlphaComponent(highContrast ? 1 : 0.72),
            portalBorderWidth: highContrast ? 1.5 : 1,
            canopyAlpha: 0,
            scopeMarkAlpha: 0,
            scopeMarkTransform: CGAffineTransform(scaleX: 0.82, y: 0.82),
            portalTransform: .identity,
            horizonAlpha: highContrast ? 0.72 : 0.50,
            horizonTransform: CGAffineTransform(scaleX: 0.38, y: 1),
            surfaceTransform: .identity,
            shadowOpacity: highContrast ? 0 : (darkMode ? 0.13 : 0.055),
            shadowRadius: darkMode ? 8 : 10,
            shadowOffset: CGSize(width: 0, height: darkMode ? 3 : 5)
        )
    }

    private func apply(visualStyle style: PPMainKindsVisualStyle) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        surfaceView.layer.borderColor = style.borderColor.cgColor
        surfaceView.layer.borderWidth = style.borderWidth
        surfaceView.layer.shadowColor = UIColor.black.cgColor
        surfaceView.layer.shadowOpacity = Float(style.shadowOpacity)
        surfaceView.layer.shadowRadius = style.shadowRadius
        surfaceView.layer.shadowOffset = style.shadowOffset
        portalView.layer.borderColor = style.portalBorderColor.cgColor
        portalView.layer.borderWidth = style.portalBorderWidth
        CATransaction.commit()

        canopyView.alpha = style.canopyAlpha
        scopeMarkView.alpha = style.scopeMarkAlpha
        scopeMarkView.transform = style.scopeMarkTransform
        portalView.transform = style.portalTransform
        horizonView.alpha = style.horizonAlpha
        horizonView.transform = style.horizonTransform
        surfaceView.transform = style.surfaceTransform
        canvasView.alpha = 1
    }

    // MARK: Interaction and motion

    @objc private func handleTouchDown() {
        animatePressed(true)
    }

    @objc private func handleTouchRelease() {
        animatePressed(false)
    }

    @objc private func handleActivation() {
        animatePressed(false)

        // A bounded immediate debounce prevents accidental duplicate routing.
        // It does not delay the accepted action or compete with Home's haptic.
        let now = CACurrentMediaTime()
        guard now - lastActivationTime >= PPMainKindsMetrics.activationDebounce else {
            return
        }
        lastActivationTime = now
        onSelect?(content?.kind, content?.isAll ?? false)
    }

    private func animatePressed(_ pressed: Bool) {
        stopPressMotion()
        guard !reduceMotion, window != nil else {
            actionButton.transform = .identity
            artworkView.transform = .identity
            canvasView.alpha = pressed ? 0.88 : 1
            return
        }

        let updates = {
            self.actionButton.transform = pressed
                ? CGAffineTransform(
                    scaleX: PPMainKindsMetrics.pressScale,
                    y: PPMainKindsMetrics.pressScale
                )
                : .identity
            self.artworkView.transform = pressed
                ? CGAffineTransform(
                    scaleX: PPMainKindsMetrics.pressArtworkScale,
                    y: PPMainKindsMetrics.pressArtworkScale
                )
                : .identity
            self.canvasView.alpha = pressed ? 0.94 : 1
        }
        let animator = UIViewPropertyAnimator(
            duration: pressed
                ? PPMainKindsMetrics.pressDuration
                : PPMainKindsMetrics.releaseDuration,
            curve: .easeOut,
            animations: updates
        )
        pressGeneration &+= 1
        let generation = pressGeneration
        animator.addCompletion { [weak self] _ in
            guard let self, self.pressGeneration == generation else { return }
            self.pressAnimator = nil
        }
        pressAnimator = animator
        animator.startAnimation()
    }

    private func animateToCurrentState(
        enteringSelection: Bool,
        restored: Bool
    ) {
        stopStateMotion(settle: false)
        updateTypography()

        guard !reduceMotion, window != nil else {
            apply(visualStyle: currentVisualStyle)
            return
        }

        if enteringSelection {
            canopyView.alpha = restored ? 0.52 : 0
            scopeMarkView.alpha = restored ? 0.62 : 0
            scopeMarkView.transform = CGAffineTransform(
                scaleX: restored ? 0.92 : 0.78,
                y: restored ? 0.92 : 0.78
            )
            portalView.transform = CGAffineTransform(
                scaleX: restored ? 0.985 : 0.96,
                y: restored ? 0.985 : 0.96
            )
            horizonView.alpha = restored ? 0.70 : 0.45
            horizonView.transform = CGAffineTransform(scaleX: 0.42, y: 1)
        }

        motionGeneration &+= 1
        let generation = motionGeneration
        let animator = UIViewPropertyAnimator(
            duration: restored
                ? PPMainKindsMetrics.restoredDuration
                : PPMainKindsMetrics.selectionDuration,
            curve: .easeOut
        )
        animator.addAnimations { [weak self] in
            guard let self else { return }
            self.apply(visualStyle: self.currentVisualStyle)
        }
        animator.addCompletion { [weak self] _ in
            guard let self, self.motionGeneration == generation else { return }
            self.stateAnimator = nil
            self.apply(visualStyle: self.currentVisualStyle)
        }
        stateAnimator = animator
        animator.startAnimation()
    }

    private func stopStateMotion(settle: Bool) {
        motionGeneration &+= 1
        if let animator = stateAnimator {
            animator.stopAnimation(false)
            animator.finishAnimation(at: .current)
        }
        stateAnimator = nil
        if settle {
            apply(visualStyle: currentVisualStyle)
        }
    }

    private func stopPressMotion() {
        pressGeneration &+= 1
        if let animator = pressAnimator {
            animator.stopAnimation(false)
            animator.finishAnimation(at: .current)
        }
        pressAnimator = nil
    }

    private func stopAllMotion(settle: Bool) {
        stopStateMotion(settle: false)
        stopPressMotion()
        actionButton.layer.removeAllAnimations()
        artworkView.layer.removeAllAnimations()
        actionButton.transform = .identity
        artworkView.transform = .identity
        canvasView.alpha = 1
        if settle {
            apply(visualStyle: currentVisualStyle)
        }
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
        cellID = [String(numericID), title, imageURL].joined(separator: "|")
    }
}

// MARK: - Geometry

private enum PPMainKindsMetrics {
    static let cardRadius: CGFloat = PPCorner.card
    static let contentInset: CGFloat = PPSpace.sm
    static let visualToTitleSpacing: CGFloat = 9
    static let titleBottomInset: CGFloat = PPSpace.sm
    static let scopeMarkDiameter: CGFloat = 22
    static let scopeMarkGlyphInset: CGFloat = 5

    static let pressScale: CGFloat = 0.974
    static let pressArtworkScale: CGFloat = 1.018
    static let pressDuration: TimeInterval = 0.10
    static let releaseDuration: TimeInterval = 0.16
    static let selectionDuration: TimeInterval = 0.22
    static let restoredDuration: TimeInterval = 0.18
    static let activationDebounce: CFTimeInterval = 0.22
}

private struct PPMainKindsGeometry {
    let canopyFrame: CGRect
    let portalFrame: CGRect
    let artworkFrame: CGRect
    let horizonFrame: CGRect
    let titleFrame: CGRect
    let scopeMarkFrame: CGRect

    init(bounds: CGRect, usesExpandedText: Bool, isRightToLeft: Bool) {
        let width = max(bounds.width, 1)
        let height = max(bounds.height, 1)
        let inset = PPMainKindsMetrics.contentInset
        let bottomInset = PPMainKindsMetrics.titleBottomInset

        let reservedTitleHeight: CGFloat
        if usesExpandedText {
            reservedTitleHeight = min(62, max(48, height * 0.40))
        } else {
            reservedTitleHeight = min(48, max(42, height * 0.30))
        }

        let availableVisualHeight = max(
            46,
            height
                - inset
                - bottomInset
                - reservedTitleHeight
                - PPMainKindsMetrics.visualToTitleSpacing
        )
        let maximumPortal: CGFloat = height >= 160 ? 96 : 76
        let portalDiameter = max(
            46,
            min(width - (inset * 2.4), availableVisualHeight, maximumPortal)
        )
        let visualLaneHeight = max(portalDiameter, availableVisualHeight)
        let portalOriginY = inset + max(0, (visualLaneHeight - portalDiameter) / 2)
        portalFrame = CGRect(
            x: (width - portalDiameter) / 2,
            y: portalOriginY,
            width: portalDiameter,
            height: portalDiameter
        ).integral

        let artworkInset = max(7, portalDiameter * 0.105)
        artworkFrame = CGRect(
            origin: CGPoint(x: artworkInset, y: artworkInset),
            size: CGSize(
                width: max(1, portalDiameter - (artworkInset * 2)),
                height: max(1, portalDiameter - (artworkInset * 2))
            )
        ).integral

        let horizonWidth = max(30, portalDiameter * 0.76)
        horizonFrame = CGRect(
            x: (width - horizonWidth) / 2,
            y: portalFrame.maxY + 3,
            width: horizonWidth,
            height: 3
        ).integral

        let titleY = horizonFrame.maxY + 5
        titleFrame = CGRect(
            x: inset,
            y: titleY,
            width: max(1, width - (inset * 2)),
            height: max(1, height - bottomInset - titleY)
        ).integral

        canopyFrame = CGRect(
            x: 0,
            y: 0,
            width: width,
            height: max(portalFrame.midY, height * 0.62)
        )

        let markX = isRightToLeft
            ? inset
            : width - inset - PPMainKindsMetrics.scopeMarkDiameter
        scopeMarkFrame = CGRect(
            x: markX,
            y: inset,
            width: PPMainKindsMetrics.scopeMarkDiameter,
            height: PPMainKindsMetrics.scopeMarkDiameter
        ).integral
    }
}

// MARK: - Palette and state

private struct PPMainKindsVisualStyle {
    let borderColor: UIColor
    let borderWidth: CGFloat
    let portalBorderColor: UIColor
    let portalBorderWidth: CGFloat
    let canopyAlpha: CGFloat
    let scopeMarkAlpha: CGFloat
    let scopeMarkTransform: CGAffineTransform
    let portalTransform: CGAffineTransform
    let horizonAlpha: CGFloat
    let horizonTransform: CGAffineTransform
    let surfaceTransform: CGAffineTransform
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
}

private enum PPMainKindsPalette {
    static func accessibleAccent(
        _ candidate: UIColor,
        on surface: UIColor,
        traits: UITraitCollection
    ) -> UIColor {
        let resolvedSurface = surface.resolvedColor(with: traits)
        let text = UIColor.ppTextPrimary.resolvedColor(with: traits)
        let brand = UIColor.ppPrimary.resolvedColor(with: traits)
        let requiredContrast: CGFloat = traits.accessibilityContrast == .high ? 4.5 : 3
        let base = candidate.resolvedColor(with: traits).ppOpaque ?? brand

        let candidates = [
            base,
            base.ppMixed(with: text, amountOfSelf: 0.62),
            brand,
            brand.ppMixed(with: text, amountOfSelf: 0.58)
        ]
        return candidates.first {
            $0.ppContrastRatio(against: resolvedSurface) >= requiredContrast
        } ?? text
    }
}

private extension UIColor {
    var ppOpaque: UIColor? {
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

    func ppMixed(with other: UIColor, amountOfSelf: CGFloat) -> UIColor {
        let first = ppOpaque ?? self
        let second = other.ppOpaque ?? other
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

    func ppContrastRatio(against other: UIColor) -> CGFloat {
        let lighter = max(ppRelativeLuminance, other.ppRelativeLuminance)
        let darker = min(ppRelativeLuminance, other.ppRelativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private var ppRelativeLuminance: CGFloat {
        guard let opaque = ppOpaque else { return 0 }
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
