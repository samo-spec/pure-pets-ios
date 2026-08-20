import UIKit

// MARK: - Home species scope

/// The production UIKit renderer for Home's species scope.
///
/// The cell owns presentation, interaction feedback, image-request hygiene,
/// accessibility semantics, and environment adaptation. Home continues to own
/// ordering, selection persistence, routing, Firebase state, and haptics.
@objc(PPMainKindsCell)
public final class PPMainKindsCell: UICollectionViewCell {
    @objc public class var reuseIdentifier: String { "PPMainKindsCell" }

    /// Preserved bridge contract. After finite tap feedback, the original model
    /// instance and All flag return unchanged to Home's selection owner.
    @objc public var onSelect: ((NSObject?, Bool) -> Void)?
    @objc public var boundCellID: String?

    // MARK: View graph

    private let actionButton = UIButton(type: .custom)
    private let surfaceView = UIView()
    private let canvasView = UIView()
    private let atmosphereView = UIView()
    private let artworkGroupView = UIView()
    private let groundShadowView = UIView()
    private let portraitGroupView = UIView()
    private let artworkHaloView = UIView()
    private let artworkView = UIImageView()
    private let previewImageViews: [UIImageView] = (0..<3).map { _ in UIImageView() }
    private let tapHaloView = UIView()
    private let tapEchoView = UIView()
    private let selectionIndicatorView = UIView()
    private let titleLabel = UILabel()

    private let baseFieldLayer = CAGradientLayer()
    private let livingLightLayer = CAGradientLayer()
    private let artworkHaloLayer = CAGradientLayer()

    // MARK: Content state

    private var content: PPMainKindsContent?
    private var previewContents = [PPMainKindsContent?](repeating: nil, count: 3)
    private var previewAvailability = Array(repeating: false, count: 3)
    private var previewSignature = ""
    private var isKindSelected = false
    private var usesRestoredSelectionAppearance = false
    private var hasConfigured = false
    private var lastActivationTime: CFTimeInterval = 0

    // MARK: Async and motion state

    private var primaryImageGeneration = 0
    private var stateAnimator: UIViewPropertyAnimator?
    private var pressAnimator: UIViewPropertyAnimator?
    private var activationAnimator: UIViewPropertyAnimator?
    private var motionGeneration = 0
    private var pressGeneration = 0
    private var activationGeneration = 0
    private var activationInFlight = false
    private var activationPortraitBaseTransform: CGAffineTransform = .identity
    private var observers: [NSObjectProtocol] = []

    /// The animation owner makes the accessibility policy explicit: Reduce
    /// Motion keeps every selected/pressed state, applied without animation.
    private var reduceMotion: Bool {
        if UIAccessibility.isReduceMotionEnabled {
            return true
        }
        return false
    }

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
        stopAllMotion(settle: false)
        cancelAllImageRequests()
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        cancelAllImageRequests()
        stopAllMotion(settle: false)

        onSelect = nil
        boundCellID = nil
        content = nil
        previewContents = [PPMainKindsContent?](repeating: nil, count: 3)
        previewSignature = ""
        previewAvailability = Array(repeating: false, count: 3)
        isKindSelected = false
        usesRestoredSelectionAppearance = false
        hasConfigured = false
        lastActivationTime = 0

        artworkView.image = nil
        artworkView.isHidden = false
        artworkHaloView.alpha = 0
        artworkHaloView.transform = .identity
        for previewView in previewImageViews {
            previewView.image = nil
            previewView.isHidden = true
        }
        titleLabel.text = nil
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

        let geometry = PPMainKindsGeometry(
            bounds: actionButton.bounds,
            usesExpandedText: usesExpandedTextLayout,
            isRightToLeft: effectiveUserInterfaceLayoutDirection == .rightToLeft,
            titleFont: titleLabel.font
        )
        setLayoutRect(geometry.cardFrame, on: surfaceView)
        canvasView.frame = surfaceView.bounds
        atmosphereView.frame = canvasView.bounds
        setLayoutRect(geometry.artworkGroupFrame, on: artworkGroupView)
        groundShadowView.frame = geometry.groundShadowFrame
        portraitGroupView.frame = artworkGroupView.bounds
        if content?.isAll ?? false {
            let reducedWidth = (geometry.primaryArtworkFrame.width * 0.60).rounded()
            let reducedHeight = (geometry.primaryArtworkFrame.height * 0.60).rounded()
            artworkView.frame = CGRect(
                x: (geometry.primaryArtworkFrame.minX + (geometry.primaryArtworkFrame.width - reducedWidth) / 2).rounded(),
                y: (geometry.primaryArtworkFrame.minY + (geometry.primaryArtworkFrame.height - reducedHeight) / 2).rounded(),
                width: reducedWidth,
                height: reducedHeight
            ).integral
        } else {
            artworkView.frame = geometry.primaryArtworkFrame
        }
        applySymbolConfiguration(
            to: artworkView,
            frame: geometry.primaryArtworkFrame,
            isAll: content?.isAll ?? false
        )
        let haloSide = max(geometry.primaryArtworkFrame.width, geometry.primaryArtworkFrame.height) * 1.40
        artworkHaloView.bounds = CGRect(x: 0, y: 0, width: haloSide, height: haloSide)
        artworkHaloView.center = CGPoint(
            x: geometry.primaryArtworkFrame.midX,
            y: geometry.primaryArtworkFrame.midY
        )
        artworkHaloView.layer.cornerRadius = haloSide / 2
        artworkHaloLayer.frame = artworkHaloView.bounds
        artworkHaloLayer.cornerRadius = haloSide / 2

        for (index, previewView) in previewImageViews.enumerated() {
            previewView.frame = geometry.previewFrames[index]
            previewView.transform = geometry.previewTransforms[index]
        }
        portraitGroupView.bringSubviewToFront(previewImageViews[1])

        setLayoutRect(geometry.tapHaloFrame, on: tapHaloView)
        setLayoutRect(geometry.tapEchoFrame, on: tapEchoView)
        setLayoutRect(geometry.selectionIndicatorFrame, on: selectionIndicatorView)
        selectionIndicatorView.layer.cornerRadius = geometry.selectionIndicatorFrame.height / 2
        titleLabel.frame = geometry.titleFrame

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        baseFieldLayer.frame = atmosphereView.bounds
        livingLightLayer.frame = atmosphereView.bounds
        let lightOriginY = min(
            max(geometry.groundShadowCanvasMidY / max(atmosphereView.bounds.height, 1), 0),
            1
        )
        livingLightLayer.startPoint = CGPoint(x: 0.5, y: lightOriginY)
        livingLightLayer.endPoint = CGPoint(
            x: 1.04,
            y: max(0.02, lightOriginY - 0.68)
        )
        tapHaloView.layer.cornerRadius = tapHaloView.bounds.height / 2
        tapHaloView.layer.shadowPath = UIBezierPath(ovalIn: tapHaloView.bounds).cgPath
        tapEchoView.layer.cornerRadius = tapEchoView.bounds.height / 2
        tapEchoView.layer.shadowPath = UIBezierPath(ovalIn: tapEchoView.bounds).cgPath
        selectionIndicatorView.layer.cornerRadius = selectionIndicatorView.bounds.height / 2
        groundShadowView.layer.cornerRadius = groundShadowView.bounds.height / 2
        groundShadowView.layer.shadowPath = UIBezierPath(
            ovalIn: groundShadowView.bounds.insetBy(dx: -2, dy: -1)
        ).cgPath
        surfaceView.layer.shadowPath = UIBezierPath(
            roundedRect: surfaceView.bounds,
            cornerRadius: PPMainKindsMetrics.cardRadius
        ).cgPath
        CATransaction.commit()
    }

    /// Geometry must remain stable while selection and press transforms are
    /// active, so transformed views are positioned with bounds and center.
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
            cancelAllImageRequests()
            clearPreviewArtwork()
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
            configurePrimaryArtwork(for: nextContent)
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

    /// Preserved bridge contract. The All scope now renders one single brand
    /// symbol; the retired three-portrait family triptych no longer draws, but
    /// the entry point and its call ordering stay exactly as Home expects.
    public func configureAllPreview(withMainKinds kinds: [NSObject]) {
        guard content?.isAll == true else {
            clearPreviewArtwork()
            return
        }

        let nextSignature = kinds.prefix(3).map {
            PPMainKindsContent(kind: $0, isAll: false).cellID
        }.joined(separator: "||")
        guard nextSignature != previewSignature else {
            updateAllArtworkVisibility()
            return
        }

        previewSignature = nextSignature
        clearPreviewArtwork()
        updateAllArtworkVisibility()
        setNeedsLayout()
    }

    /// Preserved hook for a scope restored from Home persistence.
    @objc public func playRestoredSelectionAnimation() {
        guard window != nil,
              isKindSelected,
              usesRestoredSelectionAppearance else {
            return
        }
        animateToCurrentState(enteringSelection: true, restored: true)
    }

    /// Preserved hook for an explicit selection change.
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
        contentView.isAccessibilityElement = false
        layer.masksToBounds = false

        actionButton.backgroundColor = .clear
        actionButton.adjustsImageWhenHighlighted = false
        actionButton.isExclusiveTouch = true
        actionButton.isAccessibilityElement = true
        actionButton.accessibilityTraits = .button
        actionButton.showsLargeContentViewer = true
        if #available(iOS 13.4, *) {
            actionButton.isPointerInteractionEnabled = true
        }
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

        atmosphereView.isUserInteractionEnabled = false
        atmosphereView.isAccessibilityElement = false
        baseFieldLayer.name = "PPMainKindsBaseField"
        baseFieldLayer.startPoint = CGPoint(x: 0.14, y: 0)
        baseFieldLayer.endPoint = CGPoint(x: 0.86, y: 1)
        atmosphereView.layer.addSublayer(baseFieldLayer)

        livingLightLayer.name = "PPMainKindsLivingLight"
        livingLightLayer.type = .radial
        atmosphereView.layer.addSublayer(livingLightLayer)
        canvasView.addSubview(atmosphereView)

        configureActivationHalo(tapHaloView, includesFill: true)
        canvasView.addSubview(tapHaloView)
        configureActivationHalo(tapEchoView, includesFill: false)
        canvasView.addSubview(tapEchoView)

        artworkGroupView.isUserInteractionEnabled = false
        artworkGroupView.isAccessibilityElement = false
        artworkGroupView.clipsToBounds = false
        artworkGroupView.semanticContentAttribute = .forceLeftToRight
        canvasView.addSubview(artworkGroupView)

        groundShadowView.isUserInteractionEnabled = false
        groundShadowView.isAccessibilityElement = false
        groundShadowView.layer.shadowColor = UIColor.black.cgColor
        groundShadowView.layer.shadowRadius = PPMainKindsMetrics.groundBlurRadius
        groundShadowView.layer.shadowOffset = CGSize(width: 0, height: 2)
        canvasView.addSubview(groundShadowView)

        portraitGroupView.isUserInteractionEnabled = false
        portraitGroupView.isAccessibilityElement = false
        portraitGroupView.clipsToBounds = false
        portraitGroupView.semanticContentAttribute = .forceLeftToRight

        artworkHaloView.isUserInteractionEnabled = false
        artworkHaloView.isAccessibilityElement = false
        artworkHaloView.clipsToBounds = false
        artworkHaloView.alpha = 0
        artworkHaloLayer.type = .radial
        artworkHaloLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        artworkHaloLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        artworkHaloLayer.locations = [0, 0.48, 1.0]
        artworkHaloView.layer.addSublayer(artworkHaloLayer)
        artworkGroupView.addSubview(artworkHaloView)
        artworkGroupView.addSubview(portraitGroupView)

        configureImageView(artworkView)
        portraitGroupView.addSubview(artworkView)

        for previewView in previewImageViews {
            configureImageView(previewView)
            previewView.isHidden = true
            previewView.alpha = PPMainKindsMetrics.sidePortraitAlpha
            portraitGroupView.addSubview(previewView)
        }
        previewImageViews[1].alpha = 1

        selectionIndicatorView.isUserInteractionEnabled = false
        selectionIndicatorView.isAccessibilityElement = false
        selectionIndicatorView.layer.cornerCurve = .continuous
        selectionIndicatorView.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMinXMaxYCorner,
            .layerMaxXMaxYCorner
        ]
        actionButton.addSubview(selectionIndicatorView)

        titleLabel.backgroundColor = .clear
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.allowsDefaultTighteningForTruncation = true
        titleLabel.isAccessibilityElement = false
        canvasView.addSubview(titleLabel)

        applyLayoutDirection()
        updateTypography()
        updatePalette()
        applyCurrentVisualState()
    }

    private func configureActivationHalo(
        _ view: UIView,
        includesFill: Bool
    ) {
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.alpha = 0
        view.backgroundColor = includesFill ? .white : .clear
        view.layer.borderWidth = includesFill ? 0.5 : 0.75
        view.layer.shadowOffset = .zero
        view.layer.shadowRadius = includesFill ? 14 : 10
        view.layer.shadowOpacity = 0
        view.layer.masksToBounds = false
    }

    private func configureImageView(_ imageView: UIImageView) {
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = false
        imageView.isAccessibilityElement = false
        imageView.accessibilityIgnoresInvertColors = true
        imageView.semanticContentAttribute = .forceLeftToRight
    }

    /// SF Symbols are the rail's only artwork language, so each glyph is sized
    /// from its resolved frame: crisp at every Dynamic Type step and never
    /// stretched by aspect fitting.
    private func applySymbolConfiguration(
        to imageView: UIImageView,
        frame: CGRect,
        isAll: Bool = false
    ) {
        let side = max(min(frame.width, frame.height), 1)
        let scaleFactor: CGFloat = isAll ? (0.285 * 0.60) : 0.62
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: side * scaleFactor,
            weight: .semibold,
            scale: .medium
        )
    }

    private func registerForEnvironmentChanges() {
        let center = NotificationCenter.default
        let environmentNames: [Notification.Name] = [
            UIAccessibility.reduceMotionStatusDidChangeNotification,
            UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            UIAccessibility.boldTextStatusDidChangeNotification,
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

    // MARK: Content and media

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
        updateLargeContentImage()
    }

    /// Species cards keep their live portrait pipeline: the resolved
    /// placeholder lands first, then the remote artwork replaces it when the
    /// generation and binding still match. The All card short-circuits here —
    /// its glyph and SF-Symbol family previews are owned by
    /// `configureAllPreview`.
    private func configurePrimaryArtwork(for content: PPMainKindsContent) {
        cancelPrimaryImageRequest()

        let placeholder = resolvedPlaceholder(for: content)
        artworkView.image = placeholder.image?.withRenderingMode(
            placeholder.isTemplate ? .alwaysTemplate : .alwaysOriginal
        )
        artworkView.tintColor = resolvedArtworkTint
        artworkView.isHidden = false
        updateAllArtworkVisibility()
        updateLargeContentImage()

        guard !content.isAll, !content.imageURL.isEmpty else { return }
        primaryImageGeneration &+= 1
        let expectedGeneration = primaryImageGeneration
        let expectedCellID = content.cellID
        let expectedURL = content.imageURL

        PPImageLoaderManager.shared().setImage(
            on: artworkView,
            url: expectedURL,
            placeholder: artworkView.image,
            transitionStyle: .none
        ) { [weak self] image, _ in
            let applyResult = {
                guard let self,
                      self.primaryImageGeneration == expectedGeneration,
                      self.boundCellID == expectedCellID,
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
            if let image = UIImage(named: "menugrid") {
                return (image, true)
            }
            let configuration = UIImage.SymbolConfiguration(
                pointSize: 15,
                weight: .semibold,
                scale: .medium
            )
            return (
                UIImage(systemName: "line.3.horizontal", withConfiguration: configuration),
                true
            )
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
        let fallbackConfiguration = UIImage.SymbolConfiguration(
            pointSize: 29,
            weight: .medium,
            scale: .medium
        )
        return (
            UIImage(
                systemName: "pawprint.fill",
                withConfiguration: fallbackConfiguration
            ),
            true
        )
    }

    /// One single symbol speaks for the All scope; the retired three-portrait
    /// family triptych never becomes available, so the primary glyph is the
    /// unmistakable face of the first card in both layout directions.
    private func updateAllArtworkVisibility() {
        artworkView.isHidden = false
        previewImageViews.forEach { $0.isHidden = true }
        if content?.isAll == true {
            updateLargeContentImage()
        }
    }

    private func updateLargeContentImage() {
        actionButton.largeContentImage = artworkView.image
    }

    private func clearPreviewArtwork() {
        previewContents = [PPMainKindsContent?](repeating: nil, count: 3)
        previewSignature = ""
        previewAvailability = Array(repeating: false, count: 3)
        for previewView in previewImageViews {
            previewView.image = nil
            previewView.isHidden = true
        }
        artworkView.isHidden = false
    }

    private func cancelPrimaryImageRequest() {
        primaryImageGeneration &+= 1
        PPImageLoaderManager.shared().cancelImageLoad(for: artworkView)
    }

    private func cancelAllImageRequests() {
        // The All card's family previews are synchronous SF Symbols, so only
        // the primary portrait request can be in flight.
        cancelPrimaryImageRequest()
    }

    // MARK: Environment and visual system

    private func applyLayoutDirection() {
        let semantic = Language.semanticAttributeForCurrentLanguage()
        semanticContentAttribute = semantic
        contentView.semanticContentAttribute = semantic
        actionButton.semanticContentAttribute = semantic
        surfaceView.semanticContentAttribute = semantic
        canvasView.semanticContentAttribute = semantic
        titleLabel.semanticContentAttribute = semantic

        // Animal photography and the family composition are nondirectional.
        artworkGroupView.semanticContentAttribute = .forceLeftToRight
        portraitGroupView.semanticContentAttribute = .forceLeftToRight
        artworkView.semanticContentAttribute = .forceLeftToRight
        previewImageViews.forEach {
            $0.semanticContentAttribute = .forceLeftToRight
        }
    }

    private func updateTypography() {
        let shouldEmphasize = isKindSelected || UIAccessibility.isBoldTextEnabled
        let fontName = shouldEmphasize ? "Beiruti-Bold" : "Beiruti-Medium"
        let pointSize: CGFloat = 15
        let baseFont = UIFont(name: fontName, size: pointSize)
            ?? UIFont.systemFont(
                ofSize: pointSize,
                weight: shouldEmphasize ? .bold : .semibold
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
        PPMainKindsPalette.identityAccent(
            content?.accent ?? .ppPrimary,
            on: .ppSurfaceRaised,
            traits: traitCollection
        )
    }

    /// The model's category color is deliberately not contrast-shifted here.
    /// It is the product identity surface, not a decorative approximation.
    private var resolvedKindColor: UIColor {
        let brand = UIColor.ppPrimary.resolvedColor(with: traitCollection)
        return content?.accent
            .resolvedColor(with: traitCollection)
            .ppMainKindOpaque ?? brand
    }

    private var resolvedArtworkTint: UIColor {
        if content?.isAll == true {
            return isKindSelected ? resolvedAccent : UIColor.ppTextSecondary
        }
        return resolvedAccent
    }

    private func updatePalette() {
        let kindColor = resolvedKindColor
        let accent = resolvedAccent.resolvedColor(with: traitCollection)
        let surface = UIColor.ppSurfaceRaised.resolvedColor(with: traitCollection)
        let highContrast = traitCollection.accessibilityContrast == .high
        let darkMode = traitCollection.userInterfaceStyle == .dark
        let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        canvasView.backgroundColor = surface
        artworkView.tintColor = resolvedArtworkTint
        for (index, previewView) in previewImageViews.enumerated() {
            guard let previewContent = previewContents[index] else { continue }
            previewView.tintColor = PPMainKindsPalette.identityAccent(
                previewContent.accent,
                on: .ppSurfaceRaised,
                traits: traitCollection
            )
        }
        selectionIndicatorView.backgroundColor = kindColor
        artworkHaloView.backgroundColor = .clear
        artworkHaloView.layer.borderColor = nil
        artworkHaloView.layer.borderWidth = 0
        artworkHaloView.layer.shadowOpacity = 0
        artworkHaloLayer.colors = [
            kindColor.withAlphaComponent(darkMode ? 0.35 : 0.22).cgColor,
            kindColor.withAlphaComponent(darkMode ? 0.10 : 0.05).cgColor,
            UIColor.clear.cgColor
        ]
        artworkHaloLayer.locations = [0, 0.50, 1.0]
        tapHaloView.backgroundColor = kindColor.withAlphaComponent(
            darkMode ? 0.09 : 0.05
        )
        tapHaloView.layer.borderColor = kindColor.withAlphaComponent(
            highContrast ? 0.65 : 0.22
        ).cgColor
        tapHaloView.layer.shadowColor = kindColor.cgColor
        tapEchoView.layer.borderColor = kindColor.withAlphaComponent(
            highContrast ? 0.75 : 0.28
        ).cgColor
        tapEchoView.layer.shadowColor = kindColor.cgColor

        if reduceTransparency {
            atmosphereView.backgroundColor = kindColor.ppMainKindMixed(
                with: surface,
                amountOfSelf: highContrast ? 0.18 : 0.11
            )
            baseFieldLayer.isHidden = true
            livingLightLayer.isHidden = true
        } else {
            atmosphereView.backgroundColor = .clear
            baseFieldLayer.isHidden = false
            livingLightLayer.isHidden = false
            baseFieldLayer.colors = [
                accent.withAlphaComponent(highContrast ? 0.24 : (darkMode ? 0.17 : 0.12)).cgColor,
                accent.withAlphaComponent(darkMode ? 0.08 : 0.045).cgColor,
                surface.withAlphaComponent(0).cgColor
            ]
            baseFieldLayer.locations = [0, 0.54, 1]
            livingLightLayer.colors = [
                kindColor.withAlphaComponent(highContrast ? 0.30 : (darkMode ? 0.24 : 0.18)).cgColor,
                kindColor.withAlphaComponent(darkMode ? 0.12 : 0.075).cgColor,
                UIColor.clear.cgColor
            ]
            livingLightLayer.locations = [0, 0.38, 1]
        }

        if isKindSelected {
            groundShadowView.backgroundColor = kindColor
            groundShadowView.layer.shadowColor = kindColor.cgColor
            groundShadowView.layer.shadowOffset = .zero
            groundShadowView.layer.shadowRadius = 4
            groundShadowView.layer.shadowOpacity = highContrast
                ? 0
                : Float(darkMode ? 0.22 : 0.14)
        } else {
            // The idle grounding line is a clean white pedestal: it keeps the
            // portrait anchored without greying the habitat out.
            groundShadowView.backgroundColor = darkMode
                ? UIColor.white.withAlphaComponent(0.92)
                : .white
            groundShadowView.layer.shadowColor = UIColor.black.cgColor
            groundShadowView.layer.shadowOffset = CGSize(width: 0, height: 1)
            groundShadowView.layer.shadowRadius = 2
            groundShadowView.layer.shadowOpacity = highContrast
                ? 0
                : Float(darkMode ? 0.10 : 0.04)
        }
        CATransaction.commit()
    }

    private var currentVisualStyle: PPMainKindsVisualStyle {
        let accent = resolvedAccent.resolvedColor(with: traitCollection)
        let border = UIColor.ppSurfaceBorder.resolvedColor(with: traitCollection)
        let text = UIColor.ppTextPrimary.resolvedColor(with: traitCollection)
        let highContrast = traitCollection.accessibilityContrast == .high
        let darkMode = traitCollection.userInterfaceStyle == .dark

        if isKindSelected {
            return PPMainKindsVisualStyle(
                borderColor: accent.withAlphaComponent(highContrast ? 1 : 0.45),
                borderWidth: highContrast ? 2 : 1,
                atmosphereAlpha: 1,
                livingLightAlpha: 1,
                indicatorAlpha: highContrast ? 0.72 : 0.46,
                indicatorTransform: .identity,
                titleColor: text,
                artworkTransform: CGAffineTransform(translationX: 0, y: 8).scaledBy(x: 1.2, y: 1.2),
                artworkHaloAlpha: 1,
                artworkHaloTransform: CGAffineTransform(scaleX: 1.05, y: 1.05),
                surfaceTransform: CGAffineTransform(translationX: 0, y: -1),
                groundAlpha: 0,
                shadowOpacity: highContrast ? 0 : (darkMode ? 0.12 : 0.04),
                shadowRadius: darkMode ? 6 : 7,
                shadowOffset: CGSize(width: 0, height: darkMode ? 3 : 3)
            )
        }

        return PPMainKindsVisualStyle(
            borderColor: border.withAlphaComponent(highContrast ? 1 : 0.72),
            borderWidth: highContrast ? 1.5 : 0.75,
            atmosphereAlpha: highContrast ? 0.72 : 0.52,
            livingLightAlpha: 0,
            indicatorAlpha: 0,
            indicatorTransform: CGAffineTransform(scaleX: 0.72, y: 0.66),
            titleColor: text,
            artworkTransform: .identity,
            artworkHaloAlpha: 0,
            artworkHaloTransform: CGAffineTransform(scaleX: 0.75, y: 0.75),
            surfaceTransform: .identity,
            groundAlpha: highContrast ? 0 : 1,
            shadowOpacity: highContrast ? 0 : (darkMode ? 0.06 : 0.02),
            shadowRadius: darkMode ? 4 : 5,
            shadowOffset: CGSize(width: 0, height: darkMode ? 2 : 2)
        )
    }

    private func applyCurrentVisualState() {
        stopStateMotion(settle: false)
        apply(visualStyle: currentVisualStyle)
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
        livingLightLayer.opacity = Float(style.livingLightAlpha)
        CATransaction.commit()

        atmosphereView.alpha = style.atmosphereAlpha
        selectionIndicatorView.alpha = style.indicatorAlpha
        selectionIndicatorView.transform = style.indicatorTransform
        titleLabel.textColor = style.titleColor
        artworkGroupView.transform = style.artworkTransform
        artworkHaloView.alpha = style.artworkHaloAlpha
        artworkHaloView.transform = style.artworkHaloTransform
        surfaceView.transform = style.surfaceTransform
        groundShadowView.alpha = style.groundAlpha
        canvasView.alpha = 1

        if let content, content.isAll {
            artworkView.tintColor = resolvedArtworkTint
            let placeholder = resolvedPlaceholder(for: content)
            artworkView.image = placeholder.image?.withRenderingMode(.alwaysTemplate)
        }
    }

    // MARK: Interaction and finite motion

    @objc private func handleTouchDown() {
        animatePressed(true)
    }

    @objc private func handleTouchRelease() {
        animatePressed(false)
    }

    @objc private func handleActivation() {
        animatePressed(false)

        let now = CACurrentMediaTime()
        guard now - lastActivationTime >= PPMainKindsMetrics.activationDebounce,
              !activationInFlight,
              let content,
              let expectedCellID = boundCellID,
              onSelect != nil,
              window != nil else {
            return
        }
        lastActivationTime = now

        if reduceMotion {
            resetActivationVisuals()
            onSelect?(content.kind, content.isAll)
            return
        }

        playActivationHalo(
            expectedCellID: expectedCellID,
            kind: content.kind,
            isAll: content.isAll
        )
    }

    /// A two-stage, single-owner feedback gesture. The first phase gathers the
    /// category color around its portrait; the second releases it through the
    /// card and only then hands the unchanged model to Home's navigation owner.
    private func playActivationHalo(
        expectedCellID: String,
        kind: NSObject?,
        isAll: Bool
    ) {
        guard !reduceMotion else {
            onSelect?(kind, isAll)
            return
        }
        stopActivationMotion()
        stopStateMotion(settle: true)
        activationInFlight = true
        actionButton.isUserInteractionEnabled = false
        activationGeneration &+= 1
        let generation = activationGeneration
        activationPortraitBaseTransform = portraitGroupView.transform

        tapHaloView.alpha = 0
        tapHaloView.transform = CGAffineTransform(scaleX: 0.46, y: 0.46)
        tapEchoView.alpha = 0
        tapEchoView.transform = CGAffineTransform(scaleX: 0.62, y: 0.62)

        let gather = UIViewPropertyAnimator(
            duration: PPMainKindsMetrics.activationGatherDuration,
            curve: .easeOut
        )
        gather.addAnimations { [weak self] in
            guard let self else { return }
            self.tapHaloView.alpha = 0.32
            self.tapHaloView.transform = .identity
            self.tapHaloView.layer.shadowOpacity = 0.15
            self.tapEchoView.alpha = 0.40
            self.tapEchoView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            self.tapEchoView.layer.shadowOpacity = 0.12
            self.portraitGroupView.transform = self.activationPortraitBaseTransform.scaledBy(
                x: 1.015,
                y: 1.015
            )
        }
        gather.addCompletion { [weak self] position in
            guard let self,
                  position == .end,
                  self.activationGeneration == generation,
                  self.boundCellID == expectedCellID,
                  self.window != nil else {
                return
            }
            self.playActivationRelease(
                generation: generation,
                expectedCellID: expectedCellID,
                kind: kind,
                isAll: isAll
            )
        }
        activationAnimator = gather
        gather.startAnimation()
    }

    private func playActivationRelease(
        generation: Int,
        expectedCellID: String,
        kind: NSObject?,
        isAll: Bool
    ) {
        if reduceMotion {
            completeActivation(
                generation: generation,
                expectedCellID: expectedCellID,
                kind: kind,
                isAll: isAll
            )
            return
        }
        let release = UIViewPropertyAnimator(
            duration: PPMainKindsMetrics.activationReleaseDuration,
            curve: .easeOut
        )
        release.addAnimations { [weak self] in
            guard let self else { return }
            self.tapHaloView.alpha = 0
            self.tapHaloView.transform = CGAffineTransform(scaleX: 2.45, y: 2.45)
            self.tapHaloView.layer.shadowOpacity = 0
            self.tapEchoView.alpha = 0
            self.tapEchoView.transform = CGAffineTransform(scaleX: 2.95, y: 2.95)
            self.tapEchoView.layer.shadowOpacity = 0
            self.portraitGroupView.transform = self.activationPortraitBaseTransform
        }
        release.addCompletion { [weak self] position in
            guard let self,
                  position == .end,
                  self.activationGeneration == generation,
                  self.boundCellID == expectedCellID,
                  self.window != nil else {
                return
            }
            self.completeActivation(
                generation: generation,
                expectedCellID: expectedCellID,
                kind: kind,
                isAll: isAll
            )
        }
        activationAnimator = release
        release.startAnimation()
    }

    private func completeActivation(
        generation: Int,
        expectedCellID: String,
        kind: NSObject?,
        isAll: Bool
    ) {
        guard activationGeneration == generation,
              boundCellID == expectedCellID,
              window != nil else {
            return
        }
        activationAnimator = nil
        activationInFlight = false
        actionButton.isUserInteractionEnabled = true
        resetActivationVisuals()
        onSelect?(kind, isAll)
    }

    private func animatePressed(_ pressed: Bool) {
        stopPressMotion()
        let targetTransform = pressed
            ? CGAffineTransform(
                scaleX: PPMainKindsMetrics.pressScale,
                y: PPMainKindsMetrics.pressScale
            )
            : .identity
        let targetAlpha: CGFloat = pressed ? 0.93 : 1

        guard !reduceMotion, window != nil else {
            actionButton.transform = targetTransform
            canvasView.alpha = targetAlpha
            return
        }

        let animator = UIViewPropertyAnimator(
            duration: pressed
                ? PPMainKindsMetrics.pressDuration
                : PPMainKindsMetrics.releaseDuration,
            curve: .easeOut
        ) { [weak self] in
            self?.actionButton.transform = targetTransform
            self?.canvasView.alpha = targetAlpha
        }
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
            atmosphereView.alpha = restored ? 0.76 : 0.52
            groundShadowView.alpha = restored ? 0.82 : 0.58
            selectionIndicatorView.transform = CGAffineTransform(
                scaleX: restored ? 0.96 : 0.86,
                y: restored ? 0.99 : 0.80
            )
            artworkGroupView.transform = CGAffineTransform(
                translationX: 0,
                y: restored ? -1 : 1
            )
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

    private func stopActivationMotion() {
        activationGeneration &+= 1
        activationAnimator?.stopAnimation(true)
        activationAnimator = nil
        activationInFlight = false
        actionButton.isUserInteractionEnabled = true
        resetActivationVisuals()
    }

    private func resetActivationVisuals() {
        tapHaloView.layer.removeAllAnimations()
        tapEchoView.layer.removeAllAnimations()
        artworkHaloView.layer.removeAllAnimations()
        tapHaloView.alpha = 0
        tapHaloView.transform = .identity
        tapHaloView.layer.shadowOpacity = 0
        tapEchoView.alpha = 0
        tapEchoView.transform = .identity
        tapEchoView.layer.shadowOpacity = 0
        artworkHaloView.alpha = currentVisualStyle.artworkHaloAlpha
        artworkHaloView.transform = currentVisualStyle.artworkHaloTransform
        portraitGroupView.transform = .identity
        activationPortraitBaseTransform = .identity
    }

    private func stopAllMotion(settle: Bool) {
        stopStateMotion(settle: false)
        stopPressMotion()
        stopActivationMotion()
        actionButton.layer.removeAllAnimations()
        atmosphereView.layer.removeAllAnimations()
        artworkGroupView.layer.removeAllAnimations()
        artworkHaloView.layer.removeAllAnimations()
        portraitGroupView.layer.removeAllAnimations()
        groundShadowView.layer.removeAllAnimations()
        selectionIndicatorView.layer.removeAllAnimations()
        actionButton.transform = .identity
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
        let documentID = presentation["id"] as? String ?? ""
        let stableIdentity = documentID.isEmpty
            ? "main-kind-\(numericID)"
            : documentID
        cellID = [stableIdentity, imageURL].joined(separator: "|")
    }
}

// MARK: - Adaptive geometry

private enum PPMainKindsMetrics {
    static let cardRadius: CGFloat = PPCorner.card
    static let cardInset: CGFloat = PPSpace.sm
    static let artworkTopInset: CGFloat = PPSpace.sm + 2
    static let titleBottomInset: CGFloat = 6
    static let groundBlurRadius: CGFloat = 7
    static let sidePortraitAlpha: CGFloat = 0.86

    /// The selected category keeps its border and lifted artwork as its two
    /// state signals. This underscored accent is intentionally quiet.
    static let indicatorWidth: CGFloat = 24
    static let indicatorHeight: CGFloat = 2
    static let indicatorTitleSpacing: CGFloat = 4

    static let pressScale: CGFloat = 0.974
    static let pressDuration: TimeInterval = 0.10
    static let releaseDuration: TimeInterval = 0.16
    static let selectionDuration: TimeInterval = 0.20
    static let restoredDuration: TimeInterval = 0.16
    static let activationGatherDuration: TimeInterval = 0.09
    static let activationReleaseDuration: TimeInterval = 0.19
    static let activationDebounce: CFTimeInterval = 0.30
}

private struct PPMainKindsGeometry {
    let cardFrame: CGRect
    let artworkGroupFrame: CGRect
    let primaryArtworkFrame: CGRect
    let groundShadowFrame: CGRect
    let previewFrames: [CGRect]
    let previewTransforms: [CGAffineTransform]
    let tapHaloFrame: CGRect
    let tapEchoFrame: CGRect
    let groundShadowCanvasMidY: CGFloat
    let selectionIndicatorFrame: CGRect
    let titleFrame: CGRect

    init(
        bounds: CGRect,
        usesExpandedText: Bool,
        isRightToLeft: Bool,
        titleFont: UIFont
    ) {
        let width = max(bounds.width, 1)
        let height = max(bounds.height, 1)
        let cardInset = PPMainKindsMetrics.cardInset

        // The selection indicator capsule sits outside at the bottom of the card
        let indicatorHeight = PPMainKindsMetrics.indicatorHeight
        let indicatorBottomSpacing: CGFloat = 2
        let indicatorTopGap: CGFloat = 4
        let cardHeight = max(1, height - indicatorHeight - indicatorTopGap - indicatorBottomSpacing)

        cardFrame = CGRect(
            x: 0,
            y: 0,
            width: width,
            height: cardHeight
        ).integral

        selectionIndicatorFrame = CGRect(
            x: (width - PPMainKindsMetrics.indicatorWidth) / 2,
            y: cardHeight + indicatorTopGap,
            width: PPMainKindsMetrics.indicatorWidth,
            height: indicatorHeight
        ).integral

        // Bottom card footer: Category name & ground line anchored to the bottom of the card
        let titleLines: CGFloat = usesExpandedText ? 3 : 2
        let titleHeight = ceil(titleFont.lineHeight * titleLines)
        let titleBottomPadding: CGFloat = 4
        titleFrame = CGRect(
            x: cardInset,
            y: cardHeight - titleBottomPadding - titleHeight,
            width: max(1, width - (cardInset * 2)),
            height: titleHeight
        ).integral

        let groundWidth = min(max(1, width - (cardInset * 2)) * 0.48, 48)
        let groundHeight: CGFloat = 4
        let groundTitleSpacing: CGFloat = 4
        let groundY = titleFrame.minY - groundTitleSpacing - groundHeight
        groundShadowFrame = CGRect(
            x: (width - groundWidth) / 2,
            y: groundY,
            width: groundWidth,
            height: groundHeight
        ).integral
        groundShadowCanvasMidY = groundShadowFrame.midY

        // Top artwork/disc group: released from ground line, centered gracefully in upper card area
        let groupX = PPSpace.xs
        let groupY = PPMainKindsMetrics.artworkTopInset
        let groupWidth = max(1, width - (groupX * 2))
        let artworkBottomSpacing: CGFloat = 8
        let groupHeight = max(42, groundShadowFrame.minY - groupY - artworkBottomSpacing)
        artworkGroupFrame = CGRect(
            x: groupX,
            y: groupY,
            width: groupWidth,
            height: groupHeight
        ).integral

        let artworkSideInset = max(PPSpace.sm + 2, groupWidth * 0.13)
        let availableArtworkHeight = max(1, groupHeight)
        let availableArtworkWidth = max(1, groupWidth - (artworkSideInset * 2))
        let scaledArtworkWidth = (availableArtworkWidth * 0.85).rounded()
        let scaledArtworkHeight = (availableArtworkHeight * 0.85).rounded()
        let artworkSide = min(scaledArtworkWidth, scaledArtworkHeight)
        primaryArtworkFrame = CGRect(
            x: (groupWidth - artworkSide) / 2,
            y: (availableArtworkHeight - artworkSide) / 2,
            width: artworkSide,
            height: artworkSide
        ).integral

        let artworkCanvasMidY = artworkGroupFrame.minY + primaryArtworkFrame.midY
        let haloSide = min(
            84,
            max(62, min(width * 0.62, groupHeight * 0.78))
        )
        tapHaloFrame = CGRect(
            x: (width - haloSide) / 2,
            y: artworkCanvasMidY - (haloSide / 2),
            width: haloSide,
            height: haloSide
        ).integral
        let echoSide = haloSide * 0.76
        tapEchoFrame = CGRect(
            x: (width - echoSide) / 2,
            y: artworkCanvasMidY - (echoSide / 2),
            width: echoSide,
            height: echoSide
        ).integral

        let sideWidth = min(48, groupWidth * 0.38)
        let sideHeight = min(groupHeight * 0.68, 68)
        let centerWidth = min(60, groupWidth * 0.48)
        let centerHeight = min(groupHeight * 0.82, 82)
        let leadingX: CGFloat = isRightToLeft
            ? groupWidth - sideWidth
            : 0
        let trailingX: CGFloat = isRightToLeft
            ? 0
            : groupWidth - sideWidth
        previewFrames = [
            CGRect(
                x: leadingX,
                y: max(8, groupHeight - sideHeight - 8),
                width: sideWidth,
                height: sideHeight
            ).integral,
            CGRect(
                x: (groupWidth - centerWidth) / 2,
                y: max(0, groupHeight - centerHeight - 7),
                width: centerWidth,
                height: centerHeight
            ).integral,
            CGRect(
                x: trailingX,
                y: max(8, groupHeight - sideHeight - 8),
                width: sideWidth,
                height: sideHeight
            ).integral
        ]

        let semanticSign: CGFloat = isRightToLeft ? -1 : 1
        previewTransforms = [
            CGAffineTransform(rotationAngle: (-5 * semanticSign) * .pi / 180),
            .identity,
            CGAffineTransform(rotationAngle: (5 * semanticSign) * .pi / 180)
        ]
    }
}

// MARK: - Visual state and color safety

private struct PPMainKindsVisualStyle {
    let borderColor: UIColor
    let borderWidth: CGFloat
    let atmosphereAlpha: CGFloat
    let livingLightAlpha: CGFloat
    let indicatorAlpha: CGFloat
    let indicatorTransform: CGAffineTransform
    let titleColor: UIColor
    let artworkTransform: CGAffineTransform
    let artworkHaloAlpha: CGFloat
    let artworkHaloTransform: CGAffineTransform
    let surfaceTransform: CGAffineTransform
    let groundAlpha: CGFloat
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
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
