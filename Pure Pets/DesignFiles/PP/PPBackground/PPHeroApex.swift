//
//  PPHeroApex.swift
//  Pure Pets
//
//  Flagship-grade, background-only hero material. The Objective-C
//  PPBackgroundView contract stays stable while this view owns
//  rendering, accessibility, interaction, and motion lifecycle.
//

import UIKit

/// Samples touches while remaining `.possible`, so controls and scroll views
/// retain full ownership of recognition, highlighting, and navigation.
@MainActor
private final class PPHeroPassiveTouchRecognizer: UIGestureRecognizer {
    var onUpdate: ((CGPoint, UIGestureRecognizer.State, TimeInterval) -> Void)?
    var onTrackingCancelled: (() -> Void)?

    private var trackedTouch: UITouch?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard trackedTouch == nil,
              let view,
              let touch = touches.first else {
            return
        }

        trackedTouch = touch
        onUpdate?(touch.location(in: view), .began, touch.timestamp)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let view,
              let trackedTouch,
              let touch = touches.first(where: { $0 === trackedTouch }) else {
            return
        }

        onUpdate?(touch.location(in: view), .changed, touch.timestamp)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let view,
              let trackedTouch,
              let touch = touches.first(where: { $0 === trackedTouch }) else {
            return
        }

        onUpdate?(touch.location(in: view), .ended, touch.timestamp)
        self.trackedTouch = nil
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let view,
              let trackedTouch else {
            return
        }

        let touch = touches.first(where: { $0 === trackedTouch }) ?? trackedTouch
        onUpdate?(touch.location(in: view), .cancelled, touch.timestamp)
        self.trackedTouch = nil
        state = .failed
    }

    override func reset() {
        let wasTracking = trackedTouch != nil
        super.reset()
        trackedTouch = nil
        if wasTracking {
            onTrackingCancelled?()
        }
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }
}
@objc public enum PPHeroGlowDirection: Int {
    case systemDirection = 0
    case leftDirect = 1
    case rightDirection = 2
}

/// The living visual engine behind shared consumer-app hero surfaces.
///
/// This component remains background-only. Copy, actions, navigation,
/// business state, and truthful action haptics stay with existing callers.
@objcMembers
public final class PPHeroApexView: UIView, UIGestureRecognizerDelegate {
    private enum AccentMode: Int {
        case bar = 0
        case cornerGlow = 1
        case fullScreen = 2
        case solid = 3
        case fullScreenPink = 4
        case fullScreenPage = 5
        case bbBaseBackground = 6

        var isFullScreen: Bool {
            switch self {
            case .fullScreen, .fullScreenPink, .fullScreenPage, .bbBaseBackground:
                return true
            case .bar, .cornerGlow, .solid:
                return false
            }
        }

        var isBaseBackground: Bool {
            self == .bbBaseBackground
        }
    }

    private enum AuroraRole: Int {
        case leading = 0
        case bottomTrailing = 1
        case middle = 2
    }

    private struct AuroraSpec {
        let center: CGPoint
        let size: CGSize
        let travel: CGSize
        let scaleRange: ClosedRange<CGFloat>
        let opacityRange: ClosedRange<Float>
        let duration: CFTimeInterval
        let phase: CFTimeInterval
    }

    /// Full Screen owns a spatial composition rather than the compact hero
    /// drift used by Bar and Corner Glow. Points are semantic and mirrored at
    /// render time so English and Arabic receive the same choreography.
    private struct FullScreenAuroraMotionSpec {
        let normalizedPositions: [CGPoint]
        let scales: [CGFloat]
        let opacities: [Float]
        let keyTimes: [NSNumber]
        let duration: CFTimeInterval
        let phase: CFTimeInterval
    }

    private struct Palette {
        let accent: UIColor
        let surfaceHighlight: UIColor
        let surfaceMiddle: UIColor
        let surfaceTail: UIColor
        let depth: UIColor
        let aurora: [UIColor]
        let particle: [UIColor]
        let reactiveLight: UIColor
        let specularLight: UIColor
        let stroke: UIColor
        let shadowOpacity: Float
    }

    /// The selected palette is intentionally small: one brand signature, one
    /// warm lift, one cool depth note, and neutral surfaces. Opacity and motion
    /// create variation; extra hues do not.
    private enum Chromatics {
        static let signatureRose = UIColor(hex: 0xCB2654)
        static let luminousRose = UIColor(hex: 0xF2A6B9)
        static let warmPearl = UIColor(hex: 0xF3D2B6)
        static let violetDepth = UIColor(hex: 0x8778D7)
        static let lightSurface = UIColor(hex: 0xFFF9F7)
        static let darkSurface = UIColor(hex: 0x15131B)

        // BB Base Background: a warm, opaque light field rather than glass.
        // The dark counterparts avoid absolute black so the palette never
        // produces a travelling grey/black band during appearance changes.
        static let basePearl = UIColor(hex: 0xFFFDFC)
        static let basePorcelain = UIColor(hex: 0xF6F1EC)
        static let baseMineralBeige = UIColor(hex: 0xE8DDD2)
        static let baseBlush = UIColor(hex: 0xF0D9DF)
        static let baseQuietLilac = UIColor(hex: 0xD8D3E4)
        static let baseDarkHighlight = UIColor(hex: 0x2A2325)
        static let baseDarkMiddle = UIColor(hex: 0x221D1F)
        static let baseDarkTail = UIColor(hex: 0x1A1719)
        static let baseDarkWarm = UIColor(hex: 0x352A27)
        static let baseDarkBlush = UIColor(hex: 0x38272E)
        static let baseDarkLilac = UIColor(hex: 0x302B39)
    }

    // MARK: - Objective-C compatibility surface

    /// Integer keys for Objective-C callers using `accentStyle`.
    /// 0 = bar, 1 = corner glow, 2 = adaptive full screen, 3 = solid,
    /// 4 = pink full screen, 5 = warm page full screen,
    /// 6 = BB Base Background.
    @objc public static let accentStyleFullScreenPink: Int = AccentMode.fullScreenPink.rawValue
    @objc public static let accentStyleFullScreenGold: Int = AccentMode.fullScreenPage.rawValue
    @objc public static let accentStyleBBBaseBackground: Int =
        AccentMode.bbBaseBackground.rawValue

    public var accentColorOverride: UIColor? {
        didSet {
            if oldValue == nil && accentColorOverride == nil {
                return
            }
            if let oldValue,
               let accentColorOverride,
               oldValue.isEqual(accentColorOverride) {
                return
            }
            reapplyPalette()
        }
    }

    @objc
    public var overrideCenterGlowColor: UIColor? {
        didSet {
            if oldValue == nil && overrideCenterGlowColor == nil {
                return
            }
            if let oldValue,
               let overrideCenterGlowColor,
               oldValue.isEqual(overrideCenterGlowColor) {
                return
            }
            reapplyPalette()
        }
    }

    @objc
    public var overrideBottomGlowColor: UIColor? {
        didSet {
            if oldValue == nil && overrideBottomGlowColor == nil {
                return
            }
            if let oldValue,
               let overrideBottomGlowColor,
               oldValue.isEqual(overrideBottomGlowColor) {
                return
            }
            reapplyPalette()
        }
    }

    @objc
    public var overrideTopGlowColor: UIColor? {
        didSet {
            if oldValue == nil && overrideTopGlowColor == nil {
                return
            }
            if let oldValue,
               let overrideTopGlowColor,
               oldValue.isEqual(overrideTopGlowColor) {
                return
            }
            reapplyPalette()
        }
    }

    @objc
    public var overrideSurfaceColor: UIColor? {
        didSet {
            if oldValue == nil && overrideSurfaceColor == nil {
                return
            }
            if let oldValue,
               let overrideSurfaceColor,
               oldValue.isEqual(overrideSurfaceColor) {
                return
            }
            reapplyPalette()
        }
    }

    /// Source-compatible alias for the historical misspelling. Both Objective-C
    /// selectors now share one last-writer-wins value.
    @objc
    public var overrideSurfureColor: UIColor? {
        get { overrideSurfaceColor }
        set { overrideSurfaceColor = newValue }
    }

    public var accentStyle: Int {
        get { storedAccentMode.rawValue }
        set {
            let resolvedMode = AccentMode(rawValue: newValue) ?? .bar
            guard resolvedMode != storedAccentMode else { return }
            let previousMode = storedAccentMode
            storedAccentMode = resolvedMode
            setNeedsLayout()
            reapplyPalette()
            if previousMode.isFullScreen && !resolvedMode.isFullScreen {
                restoreCompactAmbientAnimationsIfNeeded()
            }
            reconcileMotionEnvironment()
        }
    }

    public var cornerGlowOpacityMultiplier: CGFloat {
        get { storedCornerGlowOpacityMultiplier }
        set {
            guard newValue.isFinite else { return }
            let clamped = min(max(newValue, 0), 1)
            guard abs(clamped - storedCornerGlowOpacityMultiplier) > 0.001 else { return }
            storedCornerGlowOpacityMultiplier = clamped
            reapplyPalette()
        }
    }

    public var glowDirection: PPHeroGlowDirection = .systemDirection {
        didSet {
            if oldValue != glowDirection {
                setNeedsLayout()
                if !overlayView.bounds.isEmpty {
                    installSignatureSweepAnimation()
                }
                if storedAccentMode.isFullScreen {
                    refreshFullScreenSpatialAnimations()
                }
            }
        }
    }

    @objc(PPHeroApexUseShimmer)
    public var useShimmer: Bool = false {
        didSet {
            guard oldValue != useShimmer else { return }
            syncSignatureSweepTimeline()
        }
    }

    @objc(PPHeroApexUseUnderFingerMotion)
    public var useUnderFingerMotion: Bool = true {
        didSet {
            guard oldValue != useUnderFingerMotion else { return }
            if useUnderFingerMotion {
                installTouchTrackerIfNeeded()
            } else {
                cancelActiveTouchResponse()
                detachTouchTracker()
                resetInteractiveTransforms()
            }
        }
    }

    private var resolvesToFlippedLayout: Bool {
        switch glowDirection {
        case .systemDirection:
            return effectiveUserInterfaceLayoutDirection == .rightToLeft
        case .leftDirect:
            return true
        case .rightDirection:
            return false
        }
    }

    /// Synchronized by the Objective-C adapter from the owning hero surface.
    public var heroCornerRadius: CGFloat {
        get { storedCornerRadius }
        set {
            guard newValue.isFinite else { return }
            let clamped = max(newValue, 0)
            guard abs(clamped - storedCornerRadius) > 0.001 else { return }
            storedCornerRadius = clamped
            setNeedsLayout()
        }
    }

    // MARK: - Material hierarchy

    private let materialView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemUltraThinMaterial)
    )
    private let baseView = UIView()
    private let ambientView = UIView()
    private let ambientContentView = UIView()
    private let overlayView = UIView()
    private let reactiveLightView = UIView()
    private let touchLensView = UIView()

    private let baseGradientLayer = CAGradientLayer()
    private let depthGradientLayer = CAGradientLayer()
    private let vignetteLayer = CAGradientLayer()
    private let prismLayer = CAGradientLayer()
    private let auroraLayers = (0..<3).map { _ in CAGradientLayer() }
    private let particleLayers = (0..<3).map { _ in CAShapeLayer() }
    private let reactiveLightLayer = CAGradientLayer()
    private let touchLensLayer = CAGradientLayer()
    private let touchCoreLayer = CAGradientLayer()
    private let contactRingLayer = CAShapeLayer()
    private let signatureSweepLayer = CAGradientLayer()
    private let topSpecularLayer = CAGradientLayer()
    private let accentBarLayer = CAGradientLayer()
    private let accentGlowLayer = CAGradientLayer()
    private let innerStrokeLayer = CAShapeLayer()

    // MARK: - Motion ownership

    private var motionStateMachine = PPHeroApexMotionStateMachine()
    private var entranceAnimator: UIViewPropertyAnimator?
    private var overlayEntranceAnimator: UIViewPropertyAnimator?
    private var interactionRecoveryAnimator: UIViewPropertyAnimator?
    private var ambientTimelineInstalled = false
    private var ambientTimelinePaused = false
    private var ambientTimelineEpoch: CFTimeInterval?
    private var ambientTimelinePauseBeganAt: CFTimeInterval?

    private var parallaxMotionEffect: UIMotionEffectGroup?
    private weak var touchHost: UIView?
    private var touchRecognizer: PPHeroPassiveTouchRecognizer?
    private var hoverRecognizer: UIGestureRecognizer?
    private var touchDisplayLink: CADisplayLink?
    private var touchResponseActive = false
    private var hoverResponseActive = false
    private var previousTouchPoint: CGPoint?
    private var previousTouchTimestamp: TimeInterval?
    private var touchVelocity = CGVector.zero
    private var touchTargetPoint: CGPoint?
    private var touchRenderedPoint: CGPoint?
    private var touchStartPoint: CGPoint?
    private var touchStartTimestamp: TimeInterval?
    private var touchMaximumTravel: CGFloat = 0

    // MARK: - Stable visual state

    private var storedAccentMode: AccentMode = .bar
    private var storedCornerGlowOpacityMultiplier: CGFloat = 1
    private var storedCornerRadius: CGFloat = 30
    private var lastLayoutSize: CGSize = .zero
    private var lastLayoutDirection: UIUserInterfaceLayoutDirection?

    private let auroraAnimationKey = "pp.hero.apex.aurora"
    private let fieldDriftAnimationKey = "pp.hero.apex.field-drift"
    private let particleAnimationKey = "pp.hero.apex.particle"
    private let reactiveLightAnimationKey = "pp.hero.apex.reactive-light"
    private let prismAnimationKey = "pp.hero.apex.prism"
    private let fullScreenSurfaceAnimationKey = "pp.hero.apex.full-screen-surface"
    private let signatureSweepAnimationKey = "pp.hero.apex.signature-sweep"
    private let pressHoldAnimationKey = "pp.hero.apex.press-hold"
    private let contactWaveAnimationKey = "pp.hero.apex.contact-wave"
    private let gradientColorTransitionKey = "pp.hero.apex.palette-colors"
    private let accentBarTransitionKey = "pp.hero.apex.accent-bar-transition"
    private let accentGlowTransitionKey = "pp.hero.apex.accent-glow-transition"

    // MARK: - Initialization

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        entranceAnimator?.stopAnimation(true)
        overlayEntranceAnimator?.stopAnimation(true)
        interactionRecoveryAnimator?.stopAnimation(true)
        touchDisplayLink?.invalidate()
        detachTouchTracker()
        removeMotionEffects()
        removeAmbientTimeline()
    }

    private func commonInit() {
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        clipsToBounds = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true

        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 12)
        layer.shadowRadius = 24

        configureViewHierarchy()
        configureLayers()
        registerForLifecycleChanges()
        reapplyPalette()
        prepareEntrancePresentation()
    }

    private func configureViewHierarchy() {
        [materialView, baseView, ambientView, ambientContentView, overlayView, reactiveLightView, touchLensView]
            .forEach { view in
                view.isUserInteractionEnabled = false
                view.isAccessibilityElement = false
                view.accessibilityElementsHidden = true
                view.backgroundColor = .clear
            }

        materialView.clipsToBounds = true
        addSubview(materialView)
        materialView.contentView.addSubview(baseView)
        materialView.contentView.addSubview(ambientView)
        ambientView.addSubview(ambientContentView)
        materialView.contentView.addSubview(overlayView)
        overlayView.addSubview(reactiveLightView)
        overlayView.addSubview(touchLensView)
    }

    private func configureLayers() {
        [baseGradientLayer, depthGradientLayer, vignetteLayer].forEach { layer in
            layer.drawsAsynchronously = true
            baseView.layer.addSublayer(layer)
        }

        baseGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        baseGradientLayer.endPoint = CGPoint(x: 1, y: 1)
        baseGradientLayer.locations = [0, 0.52, 1]

        depthGradientLayer.startPoint = CGPoint(x: 0.15, y: 0)
        depthGradientLayer.endPoint = CGPoint(x: 0.85, y: 1)
        depthGradientLayer.locations = [0, 0.58, 1]

        vignetteLayer.type = .radial
        vignetteLayer.startPoint = CGPoint(x: 0.5, y: 0.38)
        vignetteLayer.endPoint = CGPoint(x: 1, y: 1)
        vignetteLayer.locations = [0, 0.7, 1]

        prismLayer.type = .conic
        prismLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        prismLayer.endPoint = CGPoint(x: 0.5, y: 0)
        prismLayer.locations = [0, 0.20, 0.43, 0.66, 0.84, 1]
        prismLayer.drawsAsynchronously = true
        prismLayer.masksToBounds = true
        ambientContentView.layer.addSublayer(prismLayer)

        for (index, layer) in auroraLayers.enumerated() {
            layer.type = .radial
            layer.startPoint = CGPoint(x: 0.5, y: 0.5)
            layer.endPoint = CGPoint(x: 1, y: 1)
            layer.locations = index == AuroraRole.bottomTrailing.rawValue
                ? [0, 0.24, 0.62, 1]
                : [0, 0.42, 1]
            layer.drawsAsynchronously = true
            ambientContentView.layer.addSublayer(layer)
        }

        particleLayers.forEach { layer in
            layer.fillColor = UIColor.clear.cgColor
            layer.lineWidth = 0
            layer.allowsEdgeAntialiasing = true
            ambientContentView.layer.addSublayer(layer)
        }

        reactiveLightLayer.type = .radial
        reactiveLightLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        reactiveLightLayer.endPoint = CGPoint(x: 1, y: 1)
        reactiveLightLayer.locations = [0, 0.34, 1]
        reactiveLightLayer.drawsAsynchronously = true
        reactiveLightView.layer.addSublayer(reactiveLightLayer)

        touchLensLayer.type = .radial
        touchLensLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        touchLensLayer.endPoint = CGPoint(x: 1, y: 1)
        touchLensLayer.locations = [0, 0.28, 0.62, 1]
        touchLensLayer.drawsAsynchronously = true
        touchLensView.layer.addSublayer(touchLensLayer)

        touchCoreLayer.type = .radial
        touchCoreLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        touchCoreLayer.endPoint = CGPoint(x: 1, y: 1)
        touchCoreLayer.locations = [0, 0.36, 1]
        touchCoreLayer.drawsAsynchronously = true
        touchLensView.layer.addSublayer(touchCoreLayer)

        contactRingLayer.fillColor = UIColor.clear.cgColor
        contactRingLayer.lineWidth = 1
        contactRingLayer.opacity = 0
        touchLensView.layer.addSublayer(contactRingLayer)
        touchLensView.alpha = 0

        signatureSweepLayer.startPoint = CGPoint(x: 0, y: 0.5)
        signatureSweepLayer.endPoint = CGPoint(x: 1, y: 0.5)
        signatureSweepLayer.locations = [0, 0.18, 0.35, 0.50, 0.64, 0.82, 1]
        signatureSweepLayer.opacity = 0
        signatureSweepLayer.drawsAsynchronously = true
        overlayView.layer.addSublayer(signatureSweepLayer)

        topSpecularLayer.startPoint = CGPoint(x: 0.5, y: 0)
        topSpecularLayer.endPoint = CGPoint(x: 0.5, y: 1)
        topSpecularLayer.locations = [0, 0.055, 0.20, 1]
        topSpecularLayer.drawsAsynchronously = true
        overlayView.layer.addSublayer(topSpecularLayer)

        accentGlowLayer.type = .radial
        accentGlowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        accentGlowLayer.endPoint = CGPoint(x: 1, y: 1)
        accentGlowLayer.locations = [0, 0.38, 1]
        overlayView.layer.addSublayer(accentGlowLayer)

        accentBarLayer.startPoint = CGPoint(x: 0, y: 0.5)
        accentBarLayer.endPoint = CGPoint(x: 1, y: 0.5)
        accentBarLayer.locations = [0, 0.52, 1]
        accentBarLayer.cornerRadius = 1.5
        overlayView.layer.addSublayer(accentBarLayer)

        innerStrokeLayer.fillColor = UIColor.clear.cgColor
        innerStrokeLayer.lineWidth = 1
        overlayView.layer.addSublayer(innerStrokeLayer)

        updateLayerContentsScale()
    }

    private var resolvedDisplayScale: CGFloat {
        max(window?.screen.scale ?? traitCollection.displayScale, 1)
    }

    private func updateLayerContentsScale() {
        let scale = resolvedDisplayScale
        particleLayers.forEach { $0.contentsScale = scale }
        contactRingLayer.contentsScale = scale
        innerStrokeLayer.contentsScale = scale
    }

    private func registerForLifecycleChanges() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(reduceMotionStatusDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(transparencyOrContrastStatusDidChange),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(transparencyOrContrastStatusDidChange),
            name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(applicationStateDidChange),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(applicationStateDidChange),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(energyPolicyDidChange),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(energyPolicyDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        updateLayerContentsScale()

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        materialView.frame = bounds
        baseView.frame = materialView.contentView.bounds
        ambientView.frame = materialView.contentView.bounds
        ambientContentView.frame = ambientView.bounds
        overlayView.frame = materialView.contentView.bounds

        let materialBounds = baseView.bounds
        baseGradientLayer.frame = materialBounds
        let layoutDirection = effectiveUserInterfaceLayoutDirection
        baseGradientLayer.startPoint = layoutDirection == .rightToLeft
            ? CGPoint(x: 1, y: 0)
            : CGPoint(x: 0, y: 0)
        baseGradientLayer.endPoint = layoutDirection == .rightToLeft
            ? CGPoint(x: 0, y: 1)
            : CGPoint(x: 1, y: 1)
        depthGradientLayer.frame = materialBounds
        if storedAccentMode.isBaseBackground {
            depthGradientLayer.startPoint = resolvedFullScreenPoint(
                CGPoint(x: 0.20, y: 0.16)
            )
            depthGradientLayer.endPoint = resolvedFullScreenPoint(
                CGPoint(x: 1, y: 1)
            )
        }
        vignetteLayer.frame = materialBounds

        layoutPrismLayer(in: ambientContentView.bounds)
        layoutAuroraLayers(in: ambientContentView.bounds)
        layoutParticleLayers(in: ambientContentView.bounds)
        layoutReactiveLight(in: overlayView.bounds)
        layoutSignatureSweep(in: overlayView.bounds)
        layoutAccentLayers(in: overlayView.bounds)
        topSpecularLayer.frame = overlayView.bounds
        updateCornerGeometry()

        CATransaction.commit()

        let didChangeSize = lastLayoutSize != .zero && lastLayoutSize != bounds.size
        let didChangeDirection = lastLayoutDirection != nil &&
            lastLayoutDirection != layoutDirection
        lastLayoutSize = bounds.size
        lastLayoutDirection = layoutDirection
        if (didChangeSize || didChangeDirection) && ambientTimelineInstalled {
            installSignatureSweepAnimation()
            if storedAccentMode.isFullScreen {
                refreshFullScreenSpatialAnimations()
            }
        }
        reconcileMotionEnvironment()
    }

    private func updateCornerGeometry() {
        let radius = min(
            storedCornerRadius,
            max(min(bounds.width, bounds.height) * 0.5, 0)
        )

        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        materialView.layer.cornerRadius = radius
        materialView.layer.cornerCurve = .continuous

        innerStrokeLayer.frame = overlayView.bounds
        innerStrokeLayer.path = UIBezierPath(
            roundedRect: overlayView.bounds.insetBy(dx: 0.5, dy: 0.5),
            cornerRadius: max(radius - 0.5, 0)
        ).cgPath

        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: radius
        ).cgPath
    }

    private func layoutAuroraLayers(in bounds: CGRect) {
        guard !bounds.isEmpty else { return }

        let useFlippedLayout = resolvesToFlippedLayout
        for (index, layer) in auroraLayers.enumerated() where index < auroraSpecs.count {
            let spec = auroraSpecs[index]
            let size = CGSize(
                width: max(bounds.width * spec.size.width, 180),
                height: max(bounds.height * spec.size.height, 150)
            )
            layer.bounds = CGRect(origin: .zero, size: size)
            let specCenterX = useFlippedLayout ? (1.0 - spec.center.x) : spec.center.x
            layer.position = CGPoint(
                x: bounds.width * specCenterX,
                y: bounds.height * spec.center.y
            )
            layer.cornerRadius = min(size.width, size.height) * 0.5
        }
    }

    private func layoutPrismLayer(in bounds: CGRect) {
        guard !bounds.isEmpty else { return }

        let diameter = max(max(bounds.width, bounds.height) * 1.36, 280)
        prismLayer.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        prismLayer.cornerRadius = diameter * 0.5
        let center = resolvedReactiveLightCenter
        prismLayer.position = CGPoint(
            x: bounds.width * center.x,
            y: bounds.height * (center.y + 0.08)
        )
    }

    private func layoutParticleLayers(in bounds: CGRect) {
        guard !bounds.isEmpty else { return }

        let displayScale = resolvedDisplayScale
        let useFlippedLayout = resolvesToFlippedLayout

        for (groupIndex, layer) in particleLayers.enumerated() {
            layer.frame = bounds
            let path = UIBezierPath()
            guard groupIndex < normalizedParticlePointGroups.count else {
                layer.path = path.cgPath
                continue
            }

            for (pointIndex, normalizedPoint) in
                normalizedParticlePointGroups[groupIndex].enumerated() {
                let resolvedX = useFlippedLayout ? (1.0 - normalizedPoint.x) : normalizedPoint.x
                let x = (bounds.width * resolvedX * displayScale).rounded() / displayScale
                let y = (bounds.height * normalizedPoint.y * displayScale).rounded() / displayScale
                let diameter: CGFloat = (pointIndex + groupIndex).isMultiple(of: 4) ? 2.2 : 1.35
                path.append(
                    UIBezierPath(
                        ovalIn: CGRect(
                            x: x - diameter * 0.5,
                            y: y - diameter * 0.5,
                            width: diameter,
                            height: diameter
                        )
                    )
                )
            }
            layer.path = path.cgPath
        }
    }

    private func layoutReactiveLight(in bounds: CGRect) {
        guard !bounds.isEmpty else { return }

        let diameter = min(
            max(max(bounds.width * 0.92, bounds.height * 1.38), 168),
            270
        )
        reactiveLightView.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        let resolvedCenter = resolvedReactiveLightCenter
        reactiveLightView.center = CGPoint(
            x: bounds.width * resolvedCenter.x,
            y: bounds.height * resolvedCenter.y
        )
        reactiveLightLayer.frame = reactiveLightView.bounds
        reactiveLightLayer.cornerRadius = diameter * 0.5

        let lensDiameter = min(max(min(bounds.width, bounds.height) * 0.64, 92), 138)
        touchLensView.bounds = CGRect(x: 0, y: 0, width: lensDiameter, height: lensDiameter)
        touchLensView.center = reactiveLightView.center
        touchLensLayer.frame = touchLensView.bounds
        touchLensLayer.cornerRadius = lensDiameter * 0.5

        let coreDiameter = lensDiameter * 0.44
        touchCoreLayer.bounds = CGRect(x: 0, y: 0, width: coreDiameter, height: coreDiameter)
        touchCoreLayer.position = CGPoint(x: touchLensView.bounds.midX, y: touchLensView.bounds.midY)
        touchCoreLayer.cornerRadius = coreDiameter * 0.5

        contactRingLayer.frame = touchLensView.bounds
        contactRingLayer.path = UIBezierPath(
            ovalIn: touchLensView.bounds.insetBy(dx: 10, dy: 10)
        ).cgPath
    }

    private func layoutSignatureSweep(in bounds: CGRect) {
        guard !bounds.isEmpty else { return }

        let useFlippedLayout = resolvesToFlippedLayout
        let sweepWidth = max(bounds.width * 0.40, 120)
        let sweepHeight = max(bounds.height * 2.0, 264)
        signatureSweepLayer.bounds = CGRect(
            x: 0,
            y: 0,
            width: sweepWidth,
            height: sweepHeight
        )
        let sweepStartX = useFlippedLayout ? (bounds.width + sweepWidth) : -sweepWidth
        signatureSweepLayer.position = CGPoint(
            x: sweepStartX,
            y: bounds.midY
        )
        let rotationAngle = useFlippedLayout ? 0.24 : -0.24
        signatureSweepLayer.setAffineTransform(
            CGAffineTransform(rotationAngle: rotationAngle)
        )
    }

    private func layoutAccentLayers(in bounds: CGRect) {
        guard !bounds.isEmpty else { return }

        let isRTL = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let barWidth: CGFloat = 44
        let barLeading: CGFloat = 38
        let barX = isRTL ? bounds.width - barLeading - barWidth : barLeading
        accentBarLayer.frame = CGRect(x: barX, y: 0, width: barWidth, height: 3)

        let useFlippedLayout = resolvesToFlippedLayout
        let glowDiameter = max(min(bounds.width * 0.74, 230), 168)
        let glowX = useFlippedLayout ? -glowDiameter * 0.38 : (bounds.width - glowDiameter * 0.62)
        accentGlowLayer.frame = CGRect(
            x: glowX,
            y: -glowDiameter * 0.30,
            width: glowDiameter,
            height: glowDiameter
        )
    }

    // MARK: - Palette

    public func reapplyPalette() {
        let palette = makePalette()
        let isDark = traitCollection.userInterfaceStyle == .dark
        let isBaseBackground = storedAccentMode.isBaseBackground
        let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled
        let strongerContrast = traitCollection.accessibilityContrast == .high ||
            UIAccessibility.isDarkerSystemColorsEnabled
        let animatePalette = shouldAnimateVisualStateChange

        materialView.effect = (reduceTransparency || isBaseBackground)
            ? nil
            : UIBlurEffect(
                style: strongerContrast ? .systemThinMaterial : .systemUltraThinMaterial
            )

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        backgroundColor = .clear
        materialView.backgroundColor = .clear
        materialView.contentView.backgroundColor = .clear

        let surfaceAlpha: CGFloat
        if isBaseBackground {
            // A base surface must never reveal a dark view underneath while
            // its light fields move.
            surfaceAlpha = 1
        } else {
            surfaceAlpha = reduceTransparency
                ? 1
                : (strongerContrast ? 0.91 : (isDark ? 0.82 : 0.76))
        }
        setGradientColors([
            palette.surfaceHighlight.withAlphaComponent(surfaceAlpha).cgColor,
            palette.surfaceMiddle.withAlphaComponent(surfaceAlpha).cgColor,
            palette.surfaceTail.withAlphaComponent(surfaceAlpha).cgColor
        ], on: baseGradientLayer, animated: animatePalette)
        baseGradientLayer.startPoint = effectiveUserInterfaceLayoutDirection == .rightToLeft
            ? CGPoint(x: 1, y: 0)
            : CGPoint(x: 0, y: 0)
        baseGradientLayer.endPoint = effectiveUserInterfaceLayoutDirection == .rightToLeft
            ? CGPoint(x: 0, y: 1)
            : CGPoint(x: 1, y: 1)

        if isBaseBackground {
            depthGradientLayer.type = .radial
            depthGradientLayer.startPoint = resolvedFullScreenPoint(
                CGPoint(x: 0.20, y: 0.16)
            )
            depthGradientLayer.endPoint = resolvedFullScreenPoint(
                CGPoint(x: 1, y: 1)
            )
            depthGradientLayer.locations = [0, 0.62, 1]
            setGradientColors([
                palette.depth.withAlphaComponent(isDark ? 0.052 : 0.036).cgColor,
                palette.depth.withAlphaComponent(isDark ? 0.022 : 0.014).cgColor,
                UIColor.clear.cgColor
            ], on: depthGradientLayer, animated: animatePalette)
            setGradientColors([
                UIColor.clear.cgColor,
                UIColor.clear.cgColor,
                palette.depth.withAlphaComponent(isDark ? 0.026 : 0.010).cgColor
            ], on: vignetteLayer, animated: animatePalette)
        } else {
            depthGradientLayer.type = .axial
            depthGradientLayer.startPoint = CGPoint(x: 0.15, y: 0)
            depthGradientLayer.endPoint = CGPoint(x: 0.85, y: 1)
            depthGradientLayer.locations = [0, 0.58, 1]
            setGradientColors([
                UIColor.clear.cgColor,
                palette.depth.withAlphaComponent(isDark ? 0.055 : 0.018).cgColor,
                palette.depth.withAlphaComponent(isDark ? 0.16 : 0.055).cgColor
            ], on: depthGradientLayer, animated: animatePalette)
            setGradientColors([
                UIColor.clear.cgColor,
                UIColor.clear.cgColor,
                UIColor.black.withAlphaComponent(isDark ? 0.13 : 0.032).cgColor
            ], on: vignetteLayer, animated: animatePalette)
        }

        let prismRoles = auroraRoleColors(from: palette)
        if storedAccentMode.isFullScreen {
            // A radial fourth field removes the conic seam that appeared as a
            // diagonal corner-to-corner line in the Full Screen composition.
            let prismAlpha: CGFloat = isBaseBackground
                ? (isDark ? 0.14 : 0.12)
                : (isDark ? 0.24 : 0.27)
            prismLayer.type = .radial
            prismLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            prismLayer.endPoint = CGPoint(x: 1, y: 1)
            prismLayer.locations = [0, 0.34, 0.70, 1]
            setGradientColors([
                prismRoles.top.withAlphaComponent(prismAlpha).cgColor,
                prismRoles.middle.withAlphaComponent(prismAlpha * 0.52).cgColor,
                prismRoles.bottom.withAlphaComponent(prismAlpha * 0.16).cgColor,
                UIColor.clear.cgColor
            ], on: prismLayer, animated: animatePalette)
        } else {
            let prismAlpha: CGFloat = isDark ? 0.032 : 0.020
            prismLayer.type = .conic
            prismLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            prismLayer.endPoint = CGPoint(x: 0.5, y: 0)
            prismLayer.locations = [0, 0.20, 0.43, 0.66, 0.84, 1]
            setGradientColors([
                UIColor.clear.cgColor,
                prismRoles.top.withAlphaComponent(prismAlpha).cgColor,
                prismRoles.middle.withAlphaComponent(prismAlpha * 0.72).cgColor,
                UIColor.clear.cgColor,
                prismRoles.bottom.withAlphaComponent(prismAlpha * 0.82).cgColor,
                UIColor.clear.cgColor
            ], on: prismLayer, animated: animatePalette)
        }
        prismLayer.opacity = isBaseBackground ? 0.32 : 1

        for (index, layer) in auroraLayers.enumerated() {
            layer.locations = storedAccentMode.isFullScreen
                ? [0, 0.30, 0.66, 1]
                : (index == AuroraRole.bottomTrailing.rawValue
                    ? [0, 0.24, 0.62, 1]
                    : [0, 0.42, 1])
            let color = auroraBaseColor(for: index, palette: palette)
            let restingOpacity = index < auroraSpecs.count
                ? auroraSpecs[index].opacityRange.upperBound
                : 1
            let leadingAlpha = auroraLeadingAlpha(
                isDark: isDark,
                reduceTransparency: reduceTransparency
            )
            let targetColors = auroraGradientColors(
                for: color,
                palette: palette,
                index: index,
                leadingAlpha: leadingAlpha,
                isDark: isDark
            )
            setGradientColors(
                targetColors,
                on: layer,
                animated: animatePalette
            )
            layer.opacity = restingOpacity
        }

        for (index, layer) in particleLayers.enumerated() {
            let color = palette.particle[index % palette.particle.count]
            layer.fillColor = color.cgColor
            layer.opacity = isBaseBackground
                ? (isDark ? 0.075 : 0.042)
                : (isDark ? 0.12 : 0.075)
            layer.shadowOpacity = 0
            layer.shadowRadius = 0
            layer.shadowOffset = .zero
        }

        let reactiveLeadingAlpha: CGFloat = isBaseBackground
            ? (isDark ? 0.085 : 0.11)
            : (isDark ? 0.12 : 0.16)
        let reactiveMiddleAlpha: CGFloat = isBaseBackground
            ? (isDark ? 0.026 : 0.034)
            : (isDark ? 0.034 : 0.048)
        setGradientColors([
            palette.reactiveLight.withAlphaComponent(reactiveLeadingAlpha).cgColor,
            palette.reactiveLight.withAlphaComponent(reactiveMiddleAlpha).cgColor,
            UIColor.clear.cgColor
        ], on: reactiveLightLayer, animated: animatePalette)
        reactiveLightLayer.opacity = isBaseBackground ? 0.54 : 0.64

        setGradientColors([
            palette.specularLight.withAlphaComponent(isDark ? 0.30 : 0.38).cgColor,
            palette.reactiveLight.withAlphaComponent(isDark ? 0.13 : 0.17).cgColor,
            palette.accent.withAlphaComponent(isDark ? 0.040 : 0.030).cgColor,
            UIColor.clear.cgColor
        ], on: touchLensLayer, animated: animatePalette)
        setGradientColors([
            palette.specularLight.withAlphaComponent(isDark ? 0.28 : 0.40).cgColor,
            palette.reactiveLight.withAlphaComponent(isDark ? 0.075 : 0.11).cgColor,
            UIColor.clear.cgColor
        ], on: touchCoreLayer, animated: animatePalette)
        contactRingLayer.strokeColor = palette.specularLight.withAlphaComponent(
            isDark ? 0.52 : 0.68
        ).cgColor

        setGradientColors([
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            palette.specularLight.withAlphaComponent(isDark ? 0.018 : 0.030).cgColor,
            palette.specularLight.withAlphaComponent(isDark ? 0.15 : 0.22).cgColor,
            palette.specularLight.withAlphaComponent(isDark ? 0.038 : 0.062).cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor
        ], on: signatureSweepLayer, animated: animatePalette)
        signatureSweepLayer.opacity = 0

        setGradientColors([
            UIColor.white.withAlphaComponent(isDark ? 0.16 : 0.72).cgColor,
            palette.specularLight.withAlphaComponent(isDark ? 0.075 : 0.22).cgColor,
            palette.specularLight.withAlphaComponent(isDark ? 0.012 : 0.028).cgColor,
            UIColor.clear.cgColor
        ], on: topSpecularLayer, animated: animatePalette)

        setGradientColors([
            palette.accent.withAlphaComponent(0.38).cgColor,
            palette.accent.withAlphaComponent(0.82).cgColor,
            palette.accent.withAlphaComponent(0.22).cgColor
        ], on: accentBarLayer, animated: animatePalette)

        let glowStrength = storedCornerGlowOpacityMultiplier
        let middleGlowColor: UIColor
        let middleGlowAlpha: CGFloat
        if accentColorOverride == nil {
            middleGlowColor = UIColor(red: 255.0 / 255.0, green: 248.0 / 255.0, blue: 245.0 / 255.0, alpha: 1.0)
            middleGlowAlpha = (isDark ? 0.055 : 0.034) * glowStrength
        } else {
            middleGlowColor = palette.accent
            middleGlowAlpha = (isDark ? 0.092 : 0.064) * glowStrength
        }

        setGradientColors([
            palette.accent.withAlphaComponent((isDark ? 0.17 : 0.115) * glowStrength).cgColor,
            middleGlowColor.withAlphaComponent(middleGlowAlpha).cgColor,
            UIColor.clear.cgColor
        ], on: accentGlowLayer, animated: animatePalette)

        innerStrokeLayer.strokeColor = palette.stroke.cgColor
        layer.shadowOpacity = palette.shadowOpacity

        CATransaction.commit()

        applyAccentMode(animated: animatePalette)
        setNeedsLayout()
        refreshModeSpecificAmbientAnimationsIfNeeded()
    }

    private func makePalette() -> Palette {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let strongerContrast = traitCollection.accessibilityContrast == .high ||
            UIAccessibility.isDarkerSystemColorsEnabled

        if storedAccentMode.isBaseBackground {
            return makeBaseBackgroundPalette(
                isDark: isDark,
                strongerContrast: strongerContrast
            )
        }

        if storedAccentMode == .fullScreenPink {
            return makeFixedFullScreenPalette(
                signatureAccent: Chromatics.signatureRose,
                deep: blend(
                    Chromatics.warmPearl,
                    with: Chromatics.signatureRose,
                    amount: 0.34
                ),
                vivid: Chromatics.luminousRose,
                soft: Chromatics.warmPearl,
                light: Chromatics.lightSurface,
                isDark: isDark,
                strongerContrast: strongerContrast
            )
        }

        if storedAccentMode == .fullScreenPage {
            let quietWarm = blend(
                Chromatics.warmPearl,
                with: Chromatics.lightSurface,
                amount: 0.58
            )
            return makeFixedFullScreenPalette(
                signatureAccent: Chromatics.signatureRose,
                deep: Chromatics.warmPearl,
                vivid: quietWarm,
                soft: blend(quietWarm, with: Chromatics.lightSurface, amount: 0.54),
                light: Chromatics.lightSurface,
                isDark: isDark,
                strongerContrast: strongerContrast
            )
        }

        let fallbackAccent = Chromatics.signatureRose
        let explicitAccent = accentColorOverride.map { resolvedColor($0) }
        let accent = explicitAccent ?? resolvedColor(UIColor(named: "AppPrimaryColor") ?? fallbackAccent)

        let surfaceFallback = isDark
            ? Chromatics.darkSurface
            : Chromatics.lightSurface

        let surfaceBase: UIColor
        if let surfaceOverride = overrideSurfaceColor {
            surfaceBase = resolvedColor(surfaceOverride)
        } else {
            surfaceBase = resolvedColor(
                UIColor(named: "AppForegroundColor") ?? surfaceFallback
            )
        }

        let polishedSurfaceBase = isDark
            ? blend(surfaceBase, with: UIColor(red: 0.04, green: 0.045, blue: 0.064, alpha: 1), amount: 0.16)
            : blend(surfaceBase, with: .white, amount: 0.92)
        let highlight = blend(
            polishedSurfaceBase,
            with: .white,
            amount: isDark ? 0.072 : 0.85
        )
        let middle = blend(
            polishedSurfaceBase,
            with: accent,
            amount: isDark ? 0.052 : 0.008
        )
        let tail = blend(
            polishedSurfaceBase,
            with: Chromatics.violetDepth,
            amount: isDark ? 0.064 : 0.006
        )

        let brandShine: UIColor
        if let explicitAccent {
            brandShine = blend(explicitAccent, with: .white, amount: 0.23)
        } else {
            brandShine = resolvedColor(
                UIColor(named: "AppPrimaryColorShainer") ??
                    Chromatics.luminousRose
            )
        }
        let warmBloom = explicitAccent == nil
            ? Chromatics.warmPearl
            : blend(brandShine, with: Chromatics.warmPearl, amount: 0.34)
        let violetBloom = explicitAccent == nil
            ? Chromatics.violetDepth
            : blend(accent, with: Chromatics.violetDepth, amount: 0.28)

        let topGlow: UIColor
        if let topGlowOverride = overrideTopGlowColor {
            topGlow = resolvedColor(topGlowOverride)
        } else {
            topGlow = accent
        }

        let bottomTrailingGlow: UIColor
        if let bottomGlowOverride = overrideBottomGlowColor {
            bottomTrailingGlow = resolvedColor(bottomGlowOverride)
        } else {
            bottomTrailingGlow = warmBloom
        }
        let middleGlow: UIColor
        if let centerGlowOverride = overrideCenterGlowColor {
            middleGlow = resolvedColor(centerGlowOverride)
        } else {
            middleGlow = violetBloom
        }
        let particlePrimary = blend(accent, with: .white, amount: isDark ? 0.74 : 0.58)
        let particleSecondary = blend(bottomTrailingGlow, with: .white, amount: isDark ? 0.68 : 0.74)
        let specular = blend(accent, with: .white, amount: isDark ? 0.86 : 0.94)
        let isFullScreen = storedAccentMode.isFullScreen

        // Full Screen deliberately stays inside the surface's own tonal
        // family. Brand color is a whisper in the material, never a hard
        // pink/blue/orange field painted over the application.
        let fullScreenLift = blend(
            polishedSurfaceBase,
            with: .white,
            amount: isDark ? 0.14 : 0.88
        )
        let fullScreenSoftLift = blend(
            polishedSurfaceBase,
            with: .white,
            amount: isDark ? 0.065 : 0.75
        )
        let fullScreenShade = isDark
            ? blend(polishedSurfaceBase, with: .black, amount: 0.18)
            : blend(polishedSurfaceBase, with: .white, amount: 0.60)
        let fullScreenDeep = isDark
            ? blend(polishedSurfaceBase, with: .black, amount: 0.29)
            : blend(polishedSurfaceBase, with: .white, amount: 0.45)
        let fullScreenBrandWhisper = blend(
            polishedSurfaceBase,
            with: accent,
            amount: isDark ? 0.070 : 0.032
        )
        let fullScreenTop = blend(
            fullScreenLift,
            with: topGlow,
            amount: overrideTopGlowColor == nil
                ? (isDark ? 0.042 : 0.018)
                : (isDark ? 0.12 : 0.080)
        )
        let fullScreenBottom = blend(
            fullScreenShade,
            with: bottomTrailingGlow,
            amount: overrideBottomGlowColor == nil
                ? (isDark ? 0.046 : 0.020)
                : (isDark ? 0.13 : 0.085)
        )
        let fullScreenMiddle = blend(
            fullScreenSoftLift,
            with: middleGlow,
            amount: overrideCenterGlowColor == nil
                ? (isDark ? 0.036 : 0.016)
                : (isDark ? 0.11 : 0.075)
        )
        let fullScreenAurora = [
            fullScreenTop,
            fullScreenLift,
            fullScreenBrandWhisper,
            fullScreenDeep,
            fullScreenSoftLift,
            fullScreenBottom,
            fullScreenMiddle
        ]
        let fullScreenParticles = [
            fullScreenLift,
            fullScreenSoftLift,
            fullScreenBrandWhisper
        ]

        return Palette(
            accent: accent,
            surfaceHighlight: isFullScreen ? fullScreenLift : highlight,
            surfaceMiddle: isFullScreen ? fullScreenBrandWhisper : middle,
            surfaceTail: isFullScreen ? fullScreenShade : tail,
            depth: isFullScreen
                ? fullScreenDeep
                : blend(polishedSurfaceBase, with: .black, amount: isDark ? 0.34 : 0.09),
            aurora: isFullScreen ? fullScreenAurora : [
                topGlow,
                bottomTrailingGlow,
                middleGlow
            ],
            particle: isFullScreen
                ? fullScreenParticles
                : [particlePrimary, particleSecondary, UIColor.white],
            reactiveLight: isFullScreen
                ? blend(fullScreenSoftLift, with: accent, amount: isDark ? 0.055 : 0.024)
                : blend(accent, with: .white, amount: isDark ? 0.80 : 0.89),
            specularLight: isFullScreen
                ? blend(fullScreenLift, with: .white, amount: isDark ? 0.38 : 0.62)
                : specular,
            stroke: UIColor.white.withAlphaComponent(
                strongerContrast ? (isDark ? 0.30 : 0.96) : (isDark ? 0.14 : 0.78)
            ),
            shadowOpacity: isDark ? 0.18 : 0.095
        )
    }

    private func makeBaseBackgroundPalette(
        isDark: Bool,
        strongerContrast: Bool
    ) -> Palette {
        let accent = resolvedColor(accentColorOverride ?? Chromatics.signatureRose)

        if isDark {
            let highlight = resolvedColor(Chromatics.baseDarkHighlight)
            let middle = resolvedColor(Chromatics.baseDarkMiddle)
            let tail = resolvedColor(Chromatics.baseDarkTail)
            let warm = resolvedColor(Chromatics.baseDarkWarm)
            let blush = blend(
                resolvedColor(Chromatics.baseDarkBlush),
                with: accent,
                amount: 0.08
            )
            let lilac = resolvedColor(Chromatics.baseDarkLilac)
            let quiet = blend(middle, with: highlight, amount: 0.44)
            let deepened = blend(tail, with: lilac, amount: 0.30)
            let warmLift = blend(highlight, with: warm, amount: 0.34)

            return Palette(
                accent: accent,
                surfaceHighlight: highlight,
                surfaceMiddle: middle,
                surfaceTail: tail,
                depth: lilac,
                aurora: [
                    warmLift,
                    highlight,
                    quiet,
                    deepened,
                    blush,
                    warm,
                    lilac
                ],
                particle: [
                    blend(highlight, with: .white, amount: 0.16),
                    blush,
                    lilac
                ],
                reactiveLight: blend(highlight, with: blush, amount: 0.28),
                specularLight: blend(highlight, with: .white, amount: 0.42),
                stroke: UIColor.white.withAlphaComponent(
                    strongerContrast ? 0.34 : 0.18
                ),
                shadowOpacity: 0.13
            )
        }

        let pearl = resolvedColor(Chromatics.basePearl)
        let porcelain = resolvedColor(Chromatics.basePorcelain)
        let mineralBeige = resolvedColor(Chromatics.baseMineralBeige)
        let blush = resolvedColor(Chromatics.baseBlush)
        let quietLilac = resolvedColor(Chromatics.baseQuietLilac)
        let warmLift = blend(pearl, with: blush, amount: 0.18)
        let quiet = blend(porcelain, with: pearl, amount: 0.38)
        let mineralLilac = blend(mineralBeige, with: quietLilac, amount: 0.36)
        let roseVeil = blend(blush, with: accent, amount: 0.075)
        let lilacVeil = blend(quietLilac, with: porcelain, amount: 0.60)

        return Palette(
            accent: accent,
            surfaceHighlight: pearl,
            surfaceMiddle: porcelain,
            surfaceTail: blend(porcelain, with: mineralBeige, amount: 0.48),
            depth: mineralLilac,
            aurora: [
                warmLift,
                pearl,
                quiet,
                mineralLilac,
                lilacVeil,
                mineralBeige,
                roseVeil
            ],
            particle: [
                pearl,
                blend(blush, with: .white, amount: 0.42),
                blend(quietLilac, with: .white, amount: 0.48)
            ],
            reactiveLight: blend(pearl, with: roseVeil, amount: 0.14),
            specularLight: .white,
            stroke: UIColor.white.withAlphaComponent(
                strongerContrast ? 0.94 : 0.72
            ),
            shadowOpacity: 0.055
        )
    }

    private func makeFixedFullScreenPalette(
        signatureAccent: UIColor,
        deep: UIColor,
        vivid: UIColor,
        soft: UIColor,
        light: UIColor,
        isDark: Bool,
        strongerContrast: Bool
    ) -> Palette {
        let resolvedAccent = resolvedColor(signatureAccent)
        let resolvedDeep = resolvedColor(deep)
        let resolvedVivid = resolvedColor(vivid)
        let resolvedSoft = resolvedColor(soft)
        let resolvedLight = resolvedColor(light)

        let surfaceHighlight = isDark
            ? blend(resolvedLight, with: .black, amount: 0.68)
            : resolvedLight
        let surfaceMiddle = isDark
            ? blend(resolvedSoft, with: .black, amount: 0.58)
            : resolvedSoft
        let surfaceTail = isDark
            ? blend(resolvedVivid, with: .black, amount: 0.55)
            : blend(resolvedSoft, with: resolvedVivid, amount: 0.38)
        let depth = isDark
            ? blend(resolvedDeep, with: .black, amount: 0.54)
            : resolvedDeep

        let top = isDark
            ? blend(resolvedLight, with: resolvedVivid, amount: 0.34)
            : resolvedLight
        let bottom = isDark
            ? blend(resolvedDeep, with: resolvedVivid, amount: 0.30)
            : resolvedDeep
        let middle = isDark
            ? blend(resolvedSoft, with: resolvedVivid, amount: 0.30)
            : resolvedSoft
        let lifted = blend(surfaceHighlight, with: .white, amount: isDark ? 0.14 : 0.20)
        let quiet = blend(surfaceMiddle, with: surfaceHighlight, amount: 0.44)
        let deepened = blend(surfaceTail, with: depth, amount: isDark ? 0.44 : 0.24)

        return Palette(
            accent: resolvedAccent,
            surfaceHighlight: surfaceHighlight,
            surfaceMiddle: surfaceMiddle,
            surfaceTail: surfaceTail,
            depth: depth,
            aurora: [top, lifted, quiet, deepened, middle, bottom, middle],
            particle: [lifted, resolvedSoft, resolvedVivid],
            reactiveLight: blend(resolvedSoft, with: .white, amount: isDark ? 0.24 : 0.52),
            specularLight: blend(resolvedLight, with: .white, amount: isDark ? 0.30 : 0.68),
            stroke: UIColor.white.withAlphaComponent(
                strongerContrast ? (isDark ? 0.34 : 0.96) : (isDark ? 0.18 : 0.80)
            ),
            shadowOpacity: isDark ? 0.20 : 0.10
        )
    }

    private func setGradientColors(
        _ colors: [CGColor],
        on layer: CAGradientLayer,
        animated: Bool
    ) {
        let sourceColors = layer.presentation()?.colors ?? layer.colors
        let targetColors = colors.map { $0 as Any }

        layer.removeAnimation(forKey: gradientColorTransitionKey)
        layer.colors = targetColors

        guard animated,
              let sourceColors,
              sourceColors.count == targetColors.count,
              !zip(sourceColors, targetColors).allSatisfy({ source, target in
                  CFEqual(source as CFTypeRef, target as CFTypeRef)
              }) else {
            return
        }

        let transition = CABasicAnimation(keyPath: "colors")
        transition.fromValue = sourceColors
        transition.toValue = targetColors
        transition.duration = PPHeroApexMotionTokens.paletteTransitionDuration
        transition.timingFunction = PPHeroApexMotionTokens.paletteTimingFunction
        transition.isRemovedOnCompletion = true
        layer.add(transition, forKey: gradientColorTransitionKey)
    }

    private func auroraLeadingAlpha(
        isDark: Bool,
        reduceTransparency: Bool
    ) -> CGFloat {
        if storedAccentMode.isBaseBackground {
            return reduceTransparency
                ? (isDark ? 0.25 : 0.28)
                : (isDark ? 0.28 : 0.32)
        }
        if storedAccentMode.isFullScreen {
            return reduceTransparency
                ? (isDark ? 0.30 : 0.36)
                : (isDark ? 0.34 : 0.42)
        }
        return reduceTransparency
            ? (isDark ? 0.12 : 0.080)
            : (isDark ? 0.18 : 0.115)
    }

    private func auroraBaseColor(for index: Int, palette: Palette) -> UIColor {
        let roles = auroraRoleColors(from: palette)
        switch AuroraRole(rawValue: index) {
        case .leading:
            return roles.top
        case .bottomTrailing:
            return roles.bottom
        case .middle:
            return roles.middle
        case .none:
            guard !palette.aurora.isEmpty else { return palette.accent }
            return palette.aurora[index % palette.aurora.count]
        }
    }

    private func auroraRoleColors(from palette: Palette) -> (
        top: UIColor,
        bottom: UIColor,
        middle: UIColor
    ) {
        let top = auroraColor(at: 0, in: palette, fallback: palette.accent)
        let bottomIndex = storedAccentMode.isFullScreen ? 5 : 1
        let middleIndex = storedAccentMode.isFullScreen ? 6 : 2
        let bottom = auroraColor(
            at: bottomIndex,
            in: palette,
            fallback: auroraColor(at: 1, in: palette, fallback: palette.accent)
        )
        let middle = auroraColor(
            at: middleIndex,
            in: palette,
            fallback: auroraColor(at: 2, in: palette, fallback: palette.accent)
        )
        return (top, bottom, middle)
    }

    private func auroraColor(
        at index: Int,
        in palette: Palette,
        fallback: UIColor
    ) -> UIColor {
        guard palette.aurora.indices.contains(index) else { return fallback }
        return palette.aurora[index]
    }

    private func auroraGradientColors(
        for color: UIColor,
        palette: Palette,
        index: Int,
        leadingAlpha: CGFloat,
        isDark: Bool
    ) -> [CGColor] {
        if storedAccentMode.isFullScreen {
            let roleStrength: CGFloat
            switch AuroraRole(rawValue: index) {
            case .leading:
                roleStrength = 1
            case .bottomTrailing:
                roleStrength = 0.92
            case .middle:
                roleStrength = 0.84
            case .none:
                roleStrength = 0.88
            }
            let alpha = leadingAlpha * roleStrength
            let brandWhisper = blend(
                color,
                with: palette.accent,
                amount: isDark ? 0.028 : 0.016
            )
            return [
                color.withAlphaComponent(alpha).cgColor,
                brandWhisper.withAlphaComponent(alpha * 0.54).cgColor,
                palette.surfaceMiddle.withAlphaComponent(alpha * 0.18).cgColor,
                UIColor.clear.cgColor
            ]
        }

        if index == AuroraRole.bottomTrailing.rawValue {
            let trailAlpha = leadingAlpha * (isDark ? 0.94 : 0.88)
            return [
                color.withAlphaComponent(trailAlpha).cgColor,
                palette.accent.withAlphaComponent(trailAlpha * 0.46).cgColor,
                color.withAlphaComponent(trailAlpha * 0.12).cgColor,
                UIColor.clear.cgColor
            ]
        }

        if index == AuroraRole.middle.rawValue {
            let middleAlpha = leadingAlpha * (isDark ? 0.80 : 0.74)
            return [
                color.withAlphaComponent(middleAlpha).cgColor,
                palette.accent.withAlphaComponent(middleAlpha * 0.30).cgColor,
                UIColor.clear.cgColor
            ]
        }

        return [
            color.withAlphaComponent(leadingAlpha).cgColor,
            color.withAlphaComponent(leadingAlpha * 0.32).cgColor,
            UIColor.clear.cgColor
        ]
    }

    private func resolvedColor(_ color: UIColor) -> UIColor {
        color.resolvedColor(with: traitCollection)
    }

    private func blend(_ baseColor: UIColor, with overlayColor: UIColor, amount: CGFloat) -> UIColor {
        let base = resolvedColor(baseColor)
        let overlay = resolvedColor(overlayColor)
        let t = min(max(amount, 0), 1)

        var baseRed: CGFloat = 0
        var baseGreen: CGFloat = 0
        var baseBlue: CGFloat = 0
        var baseAlpha: CGFloat = 0
        var overlayRed: CGFloat = 0
        var overlayGreen: CGFloat = 0
        var overlayBlue: CGFloat = 0
        var overlayAlpha: CGFloat = 0

        guard base.getRed(
            &baseRed,
            green: &baseGreen,
            blue: &baseBlue,
            alpha: &baseAlpha
        ), overlay.getRed(
            &overlayRed,
            green: &overlayGreen,
            blue: &overlayBlue,
            alpha: &overlayAlpha
        ) else {
            return base
        }

        func toLinear(_ component: CGFloat) -> CGFloat {
            let value = min(max(component, 0), 1)
            return value <= 0.04045
                ? value / 12.92
                : CGFloat(pow(Double((value + 0.055) / 1.055), 2.4))
        }

        func toSRGB(_ component: CGFloat) -> CGFloat {
            let value = min(max(component, 0), 1)
            return value <= 0.0031308
                ? value * 12.92
                : 1.055 * CGFloat(pow(Double(value), 1.0 / 2.4)) - 0.055
        }

        func mixed(_ first: CGFloat, _ second: CGFloat) -> CGFloat {
            toSRGB(toLinear(first) * (1 - t) + toLinear(second) * t)
        }

        return UIColor(
            red: mixed(baseRed, overlayRed),
            green: mixed(baseGreen, overlayGreen),
            blue: mixed(baseBlue, overlayBlue),
            alpha: baseAlpha * (1 - t) + overlayAlpha * t
        )
    }

    // MARK: - Centralized motion state

    public func startAnimations() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.startAnimations()
            }
            return
        }

        sendMotionEvent(.startRequested)
        reconcileMotionEnvironment()
    }

    public func stopAnimations() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.stopAnimations()
            }
            return
        }

        sendMotionEvent(.stopRequested)
    }

    private func reconcileMotionEnvironment(attachedOverride: Bool? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.reconcileMotionEnvironment(attachedOverride: attachedOverride)
            }
            return
        }

        let thermalState = ProcessInfo.processInfo.thermalState
        let environment = PPHeroApexMotionEnvironment(
            isAttached: attachedOverride ?? (window != nil),
            hasValidGeometry: storedAccentMode != .solid &&
                bounds.width > 1 &&
                bounds.height > 1,
            isApplicationActive: UIApplication.shared.applicationState == .active,
            isReduceMotionEnabled: UIAccessibility.isReduceMotionEnabled,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            isThermallyConstrained: thermalState == .serious || thermalState == .critical
        )
        sendMotionEvent(.environmentChanged(environment))
    }

    private func sendMotionEvent(_ event: PPHeroApexMotionEvent) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.sendMotionEvent(event)
            }
            return
        }

        guard let transition = motionStateMachine.send(event) else { return }
        applyMotionTransition(transition)
    }

    private func applyMotionTransition(_ transition: PPHeroApexMotionTransition) {
        if transition.previous == .entering && transition.current != .entering {
            cancelEntrance(resolveToFinalState: true)
        }

        if transition.previous == .settling && transition.current != .settling {
            cancelInteractionRecovery(
                preservingPresentation: transition.current == .interactive
            )
        }

        switch transition.current {
        case .detached, .suspended:
            detachTouchTracker()
            removeMotionEffects()
            cancelInteractionRecovery(preservingPresentation: false)
            resetInteractiveTransforms()
            applyResolvedEntrancePresentation()
            pauseAmbientTimeline()

        case .idle:
            detachTouchTracker()
            removeMotionEffects()
            cancelInteractionRecovery(preservingPresentation: false)
            removeAmbientTimeline()
            applyStaticPresentation(reduced: false)

        case .reduced:
            detachTouchTracker()
            removeMotionEffects()
            cancelInteractionRecovery(preservingPresentation: false)
            removeAmbientTimeline()
            applyStaticPresentation(reduced: true)

        case .entering:
            restoreFullMotionModelState()
            ensureAmbientTimelineRunning()
            detachTouchTracker()
            removeMotionEffects()
            runEntrance(generation: transition.generation)

        case .ambient:
            applyResolvedEntrancePresentation()
            restoreFullMotionModelState()
            ensureAmbientTimelineRunning()
            installMotionEffectsIfNeeded()
            installTouchTrackerIfNeeded()

        case .interactive:
            restoreFullMotionModelState()
            ensureAmbientTimelineRunning()
            installMotionEffectsIfNeeded()
            installTouchTrackerIfNeeded()
            cancelInteractionRecovery(preservingPresentation: true)

        case .settling:
            restoreFullMotionModelState()
            ensureAmbientTimelineRunning()
            installMotionEffectsIfNeeded()
            installTouchTrackerIfNeeded()
            startInteractionRecovery(generation: transition.generation)
        }
    }

    // MARK: - Entrance choreography

    private func prepareEntrancePresentation() {
        ambientContentView.alpha = 0.18
        ambientContentView.transform = CGAffineTransform(
            translationX: 0,
            y: PPHeroApexMotionTokens.entranceTranslationY
        ).scaledBy(
            x: PPHeroApexMotionTokens.entranceScale,
            y: PPHeroApexMotionTokens.entranceScale
        )
        overlayView.alpha = 0.58
    }

    private func runEntrance(generation: UInt) {
        cancelEntrance(resolveToFinalState: false)
        prepareEntrancePresentation()

        guard UIView.areAnimationsEnabled,
              !UIAccessibility.isReduceMotionEnabled else {
            applyResolvedEntrancePresentation()
            sendMotionEvent(.entranceCompleted(generation: generation))
            return
        }

        let primaryAnimator = UIViewPropertyAnimator(
            duration: PPHeroApexMotionTokens.entranceDuration,
            timingParameters: PPHeroApexMotionTokens.entranceTimingParameters
        )
        primaryAnimator.addAnimations { [weak self] in
            self?.ambientContentView.alpha = 1
            self?.ambientContentView.transform = .identity
        }
        primaryAnimator.addCompletion { [weak self] position in
            guard let self else { return }
            self.entranceAnimator = nil
            guard position == .end else { return }
            self.overlayEntranceAnimator = nil
            self.sendMotionEvent(.entranceCompleted(generation: generation))
        }
        entranceAnimator = primaryAnimator

        let overlayAnimator = UIViewPropertyAnimator(
            duration: PPHeroApexMotionTokens.overlayEntranceDuration,
            timingParameters: PPHeroApexMotionTokens.overlayTimingParameters
        )
        overlayAnimator.addAnimations { [weak self] in
            self?.overlayView.alpha = 1
        }
        overlayEntranceAnimator = overlayAnimator

        primaryAnimator.startAnimation()
        overlayAnimator.startAnimation(
            afterDelay: PPHeroApexMotionTokens.overlayEntranceDelay
        )
    }

    private func cancelEntrance(resolveToFinalState: Bool) {
        entranceAnimator?.stopAnimation(true)
        overlayEntranceAnimator?.stopAnimation(true)
        entranceAnimator = nil
        overlayEntranceAnimator = nil

        if resolveToFinalState {
            applyResolvedEntrancePresentation()
        }
    }

    private func applyResolvedEntrancePresentation() {
        UIView.performWithoutAnimation {
            ambientContentView.alpha = 1
            ambientContentView.transform = .identity
            overlayView.alpha = 1
        }
    }

    // MARK: - Ambient timeline

    private func ensureAmbientTimelineRunning() {
        if !ambientTimelineInstalled {
            ambientTimelineEpoch = CACurrentMediaTime()
            ambientTimelinePauseBeganAt = nil
            ambientTimelineInstalled = true
            installFullScreenSurfaceAnimation()
            installFieldDriftAnimation()
            installPrismAnimation()
            installAuroraAnimations()
            installParticleAnimations()
            installLightAnimations()
        }
        resumeAmbientTimeline()
    }

    /// Full Screen owns a slowly re-orienting tonal base. This is what lets a
    /// light region descend while the darker degree migrates upward instead of
    /// leaving one colored glow parked in the center of the application.
    private func installFullScreenSurfaceAnimation() {
        baseGradientLayer.removeAnimation(forKey: fullScreenSurfaceAnimationKey)
        guard storedAccentMode.isFullScreen,
              !storedAccentMode.isBaseBackground else {
            return
        }
        baseGradientLayer.removeAnimation(forKey: gradientColorTransitionKey)

        let palette = makePalette()
        let isDark = traitCollection.userInterfaceStyle == .dark
        let brightest = blend(
            palette.surfaceHighlight,
            with: .white,
            amount: isDark ? 0.10 : 0.22
        )
        let quiet = blend(
            palette.surfaceMiddle,
            with: palette.surfaceHighlight,
            amount: 0.42
        )
        let deepest = blend(
            palette.surfaceTail,
            with: palette.depth,
            amount: isDark ? 0.46 : 0.30
        )
        let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled
        let strongerContrast = traitCollection.accessibilityContrast == .high ||
            UIAccessibility.isDarkerSystemColorsEnabled
        let surfaceAlpha: CGFloat = reduceTransparency
            ? 1
            : (strongerContrast ? 0.91 : (isDark ? 0.82 : 0.76))
        func animatedSurfaceColor(_ color: UIColor) -> CGColor {
            color.withAlphaComponent(surfaceAlpha).cgColor
        }
        let tonalFrames: [[Any]] = [
            [
                animatedSurfaceColor(brightest),
                animatedSurfaceColor(quiet),
                animatedSurfaceColor(palette.surfaceTail)
            ],
            [
                animatedSurfaceColor(quiet),
                animatedSurfaceColor(brightest),
                animatedSurfaceColor(deepest)
            ],
            [
                animatedSurfaceColor(deepest),
                animatedSurfaceColor(palette.surfaceMiddle),
                animatedSurfaceColor(brightest)
            ],
            [
                animatedSurfaceColor(palette.surfaceTail),
                animatedSurfaceColor(brightest),
                animatedSurfaceColor(quiet)
            ],
            [
                animatedSurfaceColor(brightest),
                animatedSurfaceColor(quiet),
                animatedSurfaceColor(palette.surfaceTail)
            ]
        ]
        let keyTimes: [NSNumber] = [0, 0.23, 0.50, 0.76, 1]

        let colors = CAKeyframeAnimation(keyPath: "colors")
        colors.values = tonalFrames
        colors.keyTimes = keyTimes
        colors.calculationMode = .linear
        colors.timingFunctions = Array(
            repeating: PPHeroApexMotionTokens.paletteTimingFunction,
            count: keyTimes.count - 1
        )

        let startPoint = CAKeyframeAnimation(keyPath: "startPoint")
        startPoint.values = [
            CGPoint(x: 0.08, y: 0.02),
            CGPoint(x: 0.92, y: 0.12),
            CGPoint(x: 0.52, y: 1.00),
            CGPoint(x: 0.14, y: 0.72),
            CGPoint(x: 0.08, y: 0.02)
        ].map {
            NSValue(cgPoint: resolvedFullScreenPoint($0))
        }
        startPoint.keyTimes = keyTimes
        startPoint.calculationMode = .cubic
        startPoint.timingFunctions = Array(
            repeating: PPHeroApexMotionTokens.ambientTimingFunction,
            count: keyTimes.count - 1
        )

        let endPoint = CAKeyframeAnimation(keyPath: "endPoint")
        endPoint.values = [
            CGPoint(x: 0.92, y: 0.98),
            CGPoint(x: 0.12, y: 0.90),
            CGPoint(x: 0.48, y: 0.00),
            CGPoint(x: 0.88, y: 0.20),
            CGPoint(x: 0.92, y: 0.98)
        ].map {
            NSValue(cgPoint: resolvedFullScreenPoint($0))
        }
        endPoint.keyTimes = keyTimes
        endPoint.calculationMode = .cubic
        endPoint.timingFunctions = startPoint.timingFunctions

        let locations = CAKeyframeAnimation(keyPath: "locations")
        locations.values = [
            [0.00, 0.50, 1.00],
            [0.04, 0.42, 1.00],
            [0.00, 0.56, 1.00],
            [0.08, 0.48, 0.96],
            [0.00, 0.50, 1.00]
        ]
        locations.keyTimes = keyTimes
        locations.calculationMode = .cubic
        locations.timingFunctions = startPoint.timingFunctions

        let group = makeRepeatingAnimationGroup(
            animations: [colors, startPoint, endPoint, locations],
            duration: PPHeroApexMotionTokens.fullScreenSurfaceCycleDuration,
            phase: 3.4
        )
        baseGradientLayer.add(group, forKey: fullScreenSurfaceAnimationKey)
    }

    private func installFieldDriftAnimation() {
        let isBaseBackground = storedAccentMode.isBaseBackground
        let drift = CAKeyframeAnimation(keyPath: "sublayerTransform")
        drift.values = isBaseBackground
            ? [
                NSValue(caTransform3D: ambientTransform(x: -1.4, y: 1.0, scale: 1.003)),
                NSValue(caTransform3D: ambientTransform(x: 2.1, y: -1.3, scale: 1.007)),
                NSValue(caTransform3D: ambientTransform(x: -1.8, y: 1.6, scale: 1.005)),
                NSValue(caTransform3D: ambientTransform(x: 1.2, y: -0.8, scale: 1.006)),
                NSValue(caTransform3D: ambientTransform(x: -1.4, y: 1.0, scale: 1.003))
            ]
            : [
                NSValue(caTransform3D: ambientTransform(x: -3, y: 2, scale: 1.006)),
                NSValue(caTransform3D: ambientTransform(x: 5, y: -3, scale: 1.014)),
                NSValue(caTransform3D: ambientTransform(x: -4, y: 3.5, scale: 1.010)),
                NSValue(caTransform3D: ambientTransform(x: 2, y: -1.5, scale: 1.012)),
                NSValue(caTransform3D: ambientTransform(x: -3, y: 2, scale: 1.006))
            ]
        drift.keyTimes = [0, 0.28, 0.58, 0.82, 1]
        drift.calculationMode = .cubic
        drift.timingFunctions = Array(
            repeating: PPHeroApexMotionTokens.ambientTimingFunction,
            count: 4
        )

        let group = makeRepeatingAnimationGroup(
            animations: [drift],
            duration: isBaseBackground
                ? PPHeroApexMotionTokens.baseBackgroundFieldCycleDuration
                : PPHeroApexMotionTokens.fieldDriftCycleDuration,
            phase: isBaseBackground ? 13.7 : 0.7
        )
        ambientContentView.layer.add(group, forKey: fieldDriftAnimationKey)
    }

    private func installPrismAnimation() {
        if storedAccentMode.isFullScreen {
            guard !ambientContentView.bounds.isEmpty else { return }

            let isBaseBackground = storedAccentMode.isBaseBackground
            let normalizedPositions = isBaseBackground
                ? [
                    CGPoint(x: 0.38, y: 0.34),
                    CGPoint(x: 0.62, y: 0.42),
                    CGPoint(x: 0.58, y: 0.64),
                    CGPoint(x: 0.36, y: 0.58),
                    CGPoint(x: 0.38, y: 0.34)
                ]
                : [
                    CGPoint(x: 0.18, y: 0.14),
                    CGPoint(x: 0.78, y: 0.26),
                    CGPoint(x: 0.52, y: 0.74),
                    CGPoint(x: 0.20, y: 0.86),
                    CGPoint(x: 0.18, y: 0.14)
                ]
            let keyTimes: [NSNumber] = [0, 0.24, 0.52, 0.78, 1]

            let position = CAKeyframeAnimation(keyPath: "position")
            position.values = normalizedPositions.map {
                NSValue(
                    cgPoint: fullScreenPosition(
                        from: $0,
                        in: ambientContentView.bounds
                    )
                )
            }
            position.keyTimes = keyTimes
            position.calculationMode = .cubic
            position.timingFunctions = Array(
                repeating: PPHeroApexMotionTokens.ambientTimingFunction,
                count: keyTimes.count - 1
            )

            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = isBaseBackground
                ? [0.97, 1.025, 0.99, 1.02, 0.97]
                : [0.90, 1.06, 0.97, 1.04, 0.90]
            scale.keyTimes = keyTimes
            scale.calculationMode = .cubic
            scale.timingFunctions = position.timingFunctions

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = isBaseBackground
                ? [0.26, 0.38, 0.30, 0.36, 0.26]
                : [0.48, 0.76, 0.58, 0.70, 0.48]
            opacity.keyTimes = keyTimes
            opacity.calculationMode = .cubic
            opacity.timingFunctions = position.timingFunctions

            let palette = makePalette()
            let isDark = traitCollection.userInterfaceStyle == .dark
            let prismAlpha: CGFloat = isBaseBackground
                ? (isDark ? 0.14 : 0.12)
                : (isDark ? 0.24 : 0.27)
            let colorRouteIndexes = isBaseBackground
                ? [1, 2, 6, 4, 1]
                : [1, 3, 4, 5, 1]
            let colorRoute = colorRouteIndexes.map {
                auroraColor(
                    at: $0,
                    in: palette,
                    fallback: palette.surfaceMiddle
                )
            }
            let colors = CAKeyframeAnimation(keyPath: "colors")
            colors.values = colorRoute.map { tone -> Any in
                return [
                    tone.withAlphaComponent(prismAlpha).cgColor,
                    blend(tone, with: palette.surfaceMiddle, amount: 0.46)
                        .withAlphaComponent(prismAlpha * 0.52).cgColor,
                    palette.surfaceTail.withAlphaComponent(prismAlpha * 0.16).cgColor,
                    UIColor.clear.cgColor
                ].map { $0 as Any }
            }
            colors.keyTimes = keyTimes
            colors.calculationMode = .linear
            colors.timingFunctions = Array(
                repeating: PPHeroApexMotionTokens.paletteTimingFunction,
                count: keyTimes.count - 1
            )
            prismLayer.removeAnimation(forKey: gradientColorTransitionKey)

            let group = makeRepeatingAnimationGroup(
                animations: [position, scale, opacity, colors],
                duration: isBaseBackground
                    ? PPHeroApexMotionTokens.baseBackgroundPrismCycleDuration
                    : PPHeroApexMotionTokens.fullScreenPrismCycleDuration,
                phase: isBaseBackground ? 19.4 : 6.2
            )
            prismLayer.add(group, forKey: prismAnimationKey)
            return
        }

        let rotation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        rotation.values = [-0.10, 1.48, 3.04, 4.62, CGFloat.pi * 2 - 0.10]
        rotation.keyTimes = [0, 0.25, 0.50, 0.75, 1]
        rotation.calculationMode = .linear

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.72, 1.0, 0.80, 0.94, 0.72]
        opacity.keyTimes = [0, 0.24, 0.53, 0.78, 1]
        opacity.calculationMode = .cubic
        opacity.timingFunctions = Array(
            repeating: PPHeroApexMotionTokens.ambientTimingFunction,
            count: 4
        )

        let group = makeRepeatingAnimationGroup(
            animations: [rotation, opacity],
            duration: PPHeroApexMotionTokens.compactPrismCycleDuration,
            phase: 11.3
        )
        prismLayer.add(group, forKey: prismAnimationKey)
    }

    private func installAuroraAnimations() {
        for (index, layer) in auroraLayers.enumerated() where index < auroraSpecs.count {
            let spec = auroraSpecs[index]

            if storedAccentMode.isFullScreen {
                installFullScreenAuroraAnimation(on: layer, index: index)
                continue
            }

            let transform: CAKeyframeAnimation
            let opacity: CAKeyframeAnimation

            if index == AuroraRole.bottomTrailing.rawValue {
                transform = CAKeyframeAnimation(keyPath: "transform")
                transform.values = [
                    NSValue(caTransform3D: ambientTransform(
                        x: -spec.travel.width * 0.48,
                        y: spec.travel.height * 0.34,
                        scale: spec.scaleRange.lowerBound
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: spec.travel.width * 0.72,
                        y: -spec.travel.height * 0.54,
                        scale: 1.026
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: spec.travel.width * 1.14,
                        y: -spec.travel.height * 0.86,
                        scale: spec.scaleRange.upperBound
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: -spec.travel.width * 0.24,
                        y: spec.travel.height * 0.22,
                        scale: 1.010
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: -spec.travel.width * 0.48,
                        y: spec.travel.height * 0.34,
                        scale: spec.scaleRange.lowerBound
                    ))
                ]
                transform.keyTimes = [0, 0.24, 0.52, 0.79, 1]
                transform.calculationMode = .cubic
                transform.timingFunctions = Array(
                    repeating: PPHeroApexMotionTokens.ambientTimingFunction,
                    count: 4
                )

                let lowOpacity = spec.opacityRange.lowerBound
                let highOpacity = spec.opacityRange.upperBound
                opacity = CAKeyframeAnimation(keyPath: "opacity")
                opacity.values = [
                    lowOpacity,
                    lowOpacity + (highOpacity - lowOpacity) * 0.58,
                    highOpacity,
                    lowOpacity + (highOpacity - lowOpacity) * 0.38,
                    lowOpacity
                ]
                opacity.keyTimes = [0, 0.24, 0.52, 0.79, 1]
                opacity.calculationMode = .cubic
                opacity.timingFunctions = transform.timingFunctions
            } else if index == AuroraRole.middle.rawValue {
                transform = CAKeyframeAnimation(keyPath: "transform")
                transform.values = [
                    NSValue(caTransform3D: ambientTransform(
                        x: -spec.travel.width * 0.62,
                        y: spec.travel.height * 0.34,
                        scale: spec.scaleRange.lowerBound
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: spec.travel.width * 0.74,
                        y: -spec.travel.height * 0.46,
                        scale: 1.028
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: spec.travel.width * 1.02,
                        y: spec.travel.height * 0.50,
                        scale: spec.scaleRange.upperBound
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: -spec.travel.width * 0.42,
                        y: -spec.travel.height * 0.32,
                        scale: 1.012
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: -spec.travel.width * 0.62,
                        y: spec.travel.height * 0.34,
                        scale: spec.scaleRange.lowerBound
                    ))
                ]
                transform.keyTimes = [0, 0.27, 0.54, 0.80, 1]
                transform.calculationMode = .cubic
                transform.timingFunctions = Array(
                    repeating: PPHeroApexMotionTokens.ambientTimingFunction,
                    count: 4
                )

                let lowOpacity = spec.opacityRange.lowerBound
                let highOpacity = spec.opacityRange.upperBound
                opacity = CAKeyframeAnimation(keyPath: "opacity")
                opacity.values = [
                    lowOpacity,
                    lowOpacity + (highOpacity - lowOpacity) * 0.68,
                    highOpacity,
                    lowOpacity + (highOpacity - lowOpacity) * 0.46,
                    lowOpacity
                ]
                opacity.keyTimes = [0, 0.27, 0.54, 0.80, 1]
                opacity.calculationMode = .cubic
                opacity.timingFunctions = transform.timingFunctions
            } else {
                transform = CAKeyframeAnimation(keyPath: "transform")
                transform.values = [
                    NSValue(caTransform3D: ambientTransform(
                        x: -spec.travel.width * 0.50,
                        y: spec.travel.height * 0.30,
                        scale: spec.scaleRange.lowerBound
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: spec.travel.width * 1.08,
                        y: -spec.travel.height * 0.78,
                        scale: spec.scaleRange.upperBound
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: -spec.travel.width * 0.86,
                        y: spec.travel.height * 1.06,
                        scale: 0.986
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: -spec.travel.width * 0.50,
                        y: spec.travel.height * 0.30,
                        scale: spec.scaleRange.lowerBound
                    ))
                ]
                transform.keyTimes = [0, 0.34, 0.72, 1]
                transform.calculationMode = .cubic
                transform.timingFunctions = Array(
                    repeating: PPHeroApexMotionTokens.ambientTimingFunction,
                    count: 3
                )

                let lowOpacity = spec.opacityRange.lowerBound
                let highOpacity = spec.opacityRange.upperBound
                let returnOpacity = lowOpacity + (highOpacity - lowOpacity) * 0.42
                opacity = CAKeyframeAnimation(keyPath: "opacity")
                opacity.values = [lowOpacity, highOpacity, returnOpacity, lowOpacity]
                opacity.keyTimes = [0, 0.32, 0.72, 1]
                opacity.calculationMode = .cubic
                opacity.timingFunctions = Array(
                    repeating: PPHeroApexMotionTokens.ambientTimingFunction,
                    count: 3
                )
            }

            let group = makeRepeatingAnimationGroup(
                animations: [transform, opacity],
                duration: spec.duration,
                phase: spec.phase
            )
            layer.add(group, forKey: auroraAnimationKey)
        }
    }

    /// Full Screen uses absolute, screen-spanning position choreography. Each
    /// field follows a different loop so the composition keeps reforming: a
    /// top-leading wash descends, a bottom-trailing wash rises, and the middle
    /// wash travels between corners instead of breathing in place.
    private func installFullScreenAuroraAnimation(
        on layer: CAGradientLayer,
        index: Int
    ) {
        let motionSpecs = storedAccentMode.isBaseBackground
            ? baseBackgroundAuroraMotionSpecs
            : fullScreenAuroraMotionSpecs
        guard motionSpecs.indices.contains(index),
              !ambientContentView.bounds.isEmpty else {
            return
        }

        let spec = motionSpecs[index]
        layer.removeAnimation(forKey: gradientColorTransitionKey)
        let position = CAKeyframeAnimation(keyPath: "position")
        position.values = spec.normalizedPositions.map {
            NSValue(
                cgPoint: fullScreenPosition(
                    from: $0,
                    in: ambientContentView.bounds
                )
            )
        }
        position.keyTimes = spec.keyTimes
        position.calculationMode = .cubic
        position.timingFunctions = Array(
            repeating: PPHeroApexMotionTokens.ambientTimingFunction,
            count: max(spec.keyTimes.count - 1, 0)
        )

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = spec.scales.map { NSNumber(value: Double($0)) }
        scale.keyTimes = spec.keyTimes
        scale.calculationMode = .cubic
        scale.timingFunctions = position.timingFunctions

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = spec.opacities.map { NSNumber(value: $0) }
        opacity.keyTimes = spec.keyTimes
        opacity.calculationMode = .cubic
        opacity.timingFunctions = position.timingFunctions

        let palette = makePalette()
        let isDark = traitCollection.userInterfaceStyle == .dark
        let leadingAlpha = auroraLeadingAlpha(
            isDark: isDark,
            reduceTransparency: UIAccessibility.isReduceTransparencyEnabled
        )
        let colors = CAKeyframeAnimation(keyPath: "colors")
        colors.values = fullScreenAuroraColorRoute(
            for: index,
            palette: palette
        ).map { color -> Any in
            return auroraGradientColors(
                for: color,
                palette: palette,
                index: index,
                leadingAlpha: leadingAlpha,
                isDark: isDark
            ).map { $0 as Any }
        }
        colors.keyTimes = spec.keyTimes
        colors.calculationMode = .linear
        colors.timingFunctions = Array(
            repeating: PPHeroApexMotionTokens.paletteTimingFunction,
            count: max(spec.keyTimes.count - 1, 0)
        )

        let group = makeRepeatingAnimationGroup(
            animations: [position, scale, opacity, colors],
            duration: spec.duration,
            phase: spec.phase
        )
        layer.add(group, forKey: auroraAnimationKey)
    }

    private func installParticleAnimations() {
        for (index, layer) in particleLayers.enumerated() {
            let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let travelX = direction * (4.5 + CGFloat(index) * 1.8)
            let travelY = 3.5 + CGFloat(index) * 1.4

            let transform = CAKeyframeAnimation(keyPath: "transform")
            transform.values = [
                NSValue(caTransform3D: ambientTransform(x: 0, y: 0, scale: 1)),
                NSValue(caTransform3D: ambientTransform(
                    x: travelX,
                    y: -travelY,
                    scale: 1.025
                )),
                NSValue(caTransform3D: ambientTransform(
                    x: -travelX * 0.62,
                    y: travelY,
                    scale: 0.982
                )),
                NSValue(caTransform3D: ambientTransform(x: 0, y: 0, scale: 1))
            ]
            transform.keyTimes = [0, 0.30, 0.70, 1]
            transform.calculationMode = .cubic
            transform.timingFunctions = Array(
                repeating: PPHeroApexMotionTokens.ambientTimingFunction,
                count: 3
            )

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            let baseOpacity = layer.opacity
            opacity.values = [
                baseOpacity * 0.58,
                min(baseOpacity + 0.038, 0.16),
                baseOpacity * 0.78,
                baseOpacity * 0.58
            ]
            opacity.keyTimes = [0, 0.36, 0.74, 1]
            opacity.calculationMode = .cubic
            opacity.timingFunctions = Array(
                repeating: PPHeroApexMotionTokens.ambientTimingFunction,
                count: 3
            )

            let duration = PPHeroApexMotionTokens.particleBaseCycleDuration
                + CFTimeInterval(index) * PPHeroApexMotionTokens.particleCycleStep
            let group = makeRepeatingAnimationGroup(
                animations: [transform, opacity],
                duration: duration,
                phase: 3.1 + CFTimeInterval(index) * 5.9
            )
            layer.add(group, forKey: particleAnimationKey)
        }
    }

    private func installLightAnimations() {
        let isBaseBackground = storedAccentMode.isBaseBackground
        let reactiveBreath = CAKeyframeAnimation(keyPath: "opacity")
        reactiveBreath.values = isBaseBackground
            ? [0.46, 0.56, 0.50, 0.46]
            : [0.49, 0.64, 0.56, 0.49]
        reactiveBreath.keyTimes = [0, 0.38, 0.74, 1]
        reactiveBreath.calculationMode = .cubic
        reactiveBreath.timingFunctions = Array(
            repeating: PPHeroApexMotionTokens.ambientTimingFunction,
            count: 3
        )

        let reactiveTravel = CAKeyframeAnimation(keyPath: "transform")
        reactiveTravel.values = isBaseBackground
            ? [
                NSValue(caTransform3D: ambientTransform(x: -1.4, y: 0.8, scale: 0.996)),
                NSValue(caTransform3D: ambientTransform(x: 2.2, y: -1.3, scale: 1.006)),
                NSValue(caTransform3D: ambientTransform(x: -1.8, y: 1.4, scale: 1.002)),
                NSValue(caTransform3D: ambientTransform(x: -1.4, y: 0.8, scale: 0.996))
            ]
            : [
                NSValue(caTransform3D: ambientTransform(x: -3, y: 1.5, scale: 0.992)),
                NSValue(caTransform3D: ambientTransform(x: 5, y: -3, scale: 1.014)),
                NSValue(caTransform3D: ambientTransform(x: -4, y: 3, scale: 1.004)),
                NSValue(caTransform3D: ambientTransform(x: -3, y: 1.5, scale: 0.992))
            ]
        reactiveTravel.keyTimes = [0, 0.38, 0.74, 1]
        reactiveTravel.calculationMode = .cubic
        reactiveTravel.timingFunctions = Array(
            repeating: PPHeroApexMotionTokens.ambientTimingFunction,
            count: 3
        )

        let reactiveGroup = makeRepeatingAnimationGroup(
            animations: [reactiveBreath, reactiveTravel],
            duration: isBaseBackground
                ? PPHeroApexMotionTokens.baseBackgroundReactiveLightCycleDuration
                : PPHeroApexMotionTokens.reactiveLightCycleDuration,
            phase: isBaseBackground ? 8.9 : 2.7
        )
        reactiveLightLayer.add(reactiveGroup, forKey: reactiveLightAnimationKey)

        syncSignatureSweepTimeline()
    }

    private func installSignatureSweepAnimation() {
        guard ambientTimelineInstalled,
              useShimmer,
              !storedAccentMode.isFullScreen,
              !overlayView.bounds.isEmpty else {
            signatureSweepLayer.removeAnimation(forKey: signatureSweepAnimationKey)
            signatureSweepLayer.opacity = 0
            return
        }

        let duration = PPHeroApexMotionTokens.signatureSweepCycleDuration
        let sweepWidth = signatureSweepLayer.bounds.width
        let useFlippedLayout = resolvesToFlippedLayout
        let startX = useFlippedLayout ? (overlayView.bounds.width + sweepWidth) : -sweepWidth
        let endX = useFlippedLayout ? -sweepWidth : (overlayView.bounds.width + sweepWidth)
        let startY = overlayView.bounds.midY + 20
        let endY = overlayView.bounds.midY - 18

        let travel = CAKeyframeAnimation(keyPath: "position.x")
        travel.values = [startX, startX, endX, endX]
        travel.keyTimes = [0, 0.12, 0.34, 1]
        travel.timingFunctions = [
            CAMediaTimingFunction(name: .linear),
            PPHeroApexMotionTokens.signatureSweepTimingFunction,
            CAMediaTimingFunction(name: .linear)
        ]

        let verticalTravel = CAKeyframeAnimation(keyPath: "position.y")
        verticalTravel.values = [startY, startY, endY, endY]
        verticalTravel.keyTimes = travel.keyTimes
        verticalTravel.timingFunctions = travel.timingFunctions

        let visibility = CAKeyframeAnimation(keyPath: "opacity")
        visibility.values = [0, 0, 0.56, 0.34, 0, 0]
        visibility.keyTimes = [0, 0.12, 0.18, 0.29, 0.34, 1]
        visibility.timingFunctions = [
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .linear)
        ]

        let group = makeRepeatingAnimationGroup(
            animations: [travel, verticalTravel, visibility],
            duration: duration,
            phase: 0
        )
        signatureSweepLayer.add(group, forKey: signatureSweepAnimationKey)
    }

    private func syncSignatureSweepTimeline() {
        guard useShimmer else {
            signatureSweepLayer.removeAnimation(forKey: signatureSweepAnimationKey)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            signatureSweepLayer.opacity = 0
            CATransaction.commit()
            return
        }

        guard ambientTimelineInstalled || motionStateMachine.state == .entering ||
                motionStateMachine.state == .ambient ||
                motionStateMachine.state == .interactive ||
                motionStateMachine.state == .settling else {
            return
        }
        installSignatureSweepAnimation()
    }

    private func makeRepeatingAnimationGroup(
        animations: [CAAnimation],
        duration: CFTimeInterval,
        phase: CFTimeInterval
    ) -> CAAnimationGroup {
        let resolvedDuration = max(duration, 1.0 / 60.0)

        // CAAnimationGroup does not propagate its duration to child animations.
        animations.forEach { animation in
            animation.beginTime = 0
            animation.duration = resolvedDuration
        }

        let group = CAAnimationGroup()
        group.animations = animations
        group.duration = resolvedDuration
        group.timeOffset = resolvedAmbientPhase(
            duration: resolvedDuration,
            authoredPhase: phase
        )
        group.repeatCount = .greatestFiniteMagnitude
        group.isRemovedOnCompletion = true
        return group
    }

    /// Reinstalling a size-dependent Core Animation path must not restart its
    /// choreography. A shared epoch keeps every field on the same semantic
    /// timeline through rotation, split view, palette changes, and suspension.
    private func resolvedAmbientPhase(
        duration: CFTimeInterval,
        authoredPhase: CFTimeInterval
    ) -> CFTimeInterval {
        let referenceTime = ambientTimelinePauseBeganAt ?? CACurrentMediaTime()
        let epoch = ambientTimelineEpoch ?? referenceTime
        let elapsed = max(referenceTime - epoch, 0)
        return (elapsed + max(authoredPhase, 0))
            .truncatingRemainder(dividingBy: duration)
    }

    private func refreshModeSpecificAmbientAnimationsIfNeeded() {
        guard ambientTimelineInstalled,
              storedAccentMode.isFullScreen else {
            return
        }
        refreshFullScreenSpatialAnimations()
    }

    private func refreshFullScreenSpatialAnimations() {
        guard ambientTimelineInstalled,
              storedAccentMode.isFullScreen,
              !ambientContentView.bounds.isEmpty else {
            return
        }

        installFullScreenSurfaceAnimation()
        ambientContentView.layer.removeAnimation(forKey: fieldDriftAnimationKey)
        prismLayer.removeAnimation(forKey: prismAnimationKey)
        auroraLayers.forEach { $0.removeAnimation(forKey: auroraAnimationKey) }
        reactiveLightLayer.removeAnimation(forKey: reactiveLightAnimationKey)
        signatureSweepLayer.removeAnimation(forKey: signatureSweepAnimationKey)
        signatureSweepLayer.opacity = 0
        installFieldDriftAnimation()
        installPrismAnimation()
        installAuroraAnimations()
        installLightAnimations()
    }

    private func restoreCompactAmbientAnimationsIfNeeded() {
        baseGradientLayer.removeAnimation(forKey: fullScreenSurfaceAnimationKey)
        guard ambientTimelineInstalled else { return }

        ambientContentView.layer.removeAnimation(forKey: fieldDriftAnimationKey)
        prismLayer.removeAnimation(forKey: prismAnimationKey)
        auroraLayers.forEach { $0.removeAnimation(forKey: auroraAnimationKey) }
        reactiveLightLayer.removeAnimation(forKey: reactiveLightAnimationKey)
        installFieldDriftAnimation()
        installPrismAnimation()
        installAuroraAnimations()
        installLightAnimations()
    }

    private func removeAmbientTimeline() {
        resetTimelineLayerTiming(baseView.layer)
        resetTimelineLayerTiming(ambientContentView.layer)
        resetTimelineLayerTiming(overlayView.layer)

        baseGradientLayer.removeAnimation(forKey: fullScreenSurfaceAnimationKey)
        ambientContentView.layer.removeAnimation(forKey: fieldDriftAnimationKey)
        prismLayer.removeAnimation(forKey: prismAnimationKey)
        auroraLayers.forEach { $0.removeAnimation(forKey: auroraAnimationKey) }
        particleLayers.forEach { $0.removeAnimation(forKey: particleAnimationKey) }
        reactiveLightLayer.removeAnimation(forKey: reactiveLightAnimationKey)
        signatureSweepLayer.removeAnimation(forKey: signatureSweepAnimationKey)

        ambientTimelineInstalled = false
        ambientTimelinePaused = false
        ambientTimelineEpoch = nil
        ambientTimelinePauseBeganAt = nil
    }

    private func pauseAmbientTimeline() {
        guard ambientTimelineInstalled, !ambientTimelinePaused else { return }
        ambientTimelinePauseBeganAt = CACurrentMediaTime()
        pauseTimelineLayer(baseView.layer)
        pauseTimelineLayer(ambientContentView.layer)
        pauseTimelineLayer(overlayView.layer)
        ambientTimelinePaused = true
    }

    private func resumeAmbientTimeline() {
        guard ambientTimelineInstalled, ambientTimelinePaused else { return }
        let resumeTime = CACurrentMediaTime()
        if let pauseBeganAt = ambientTimelinePauseBeganAt,
           let epoch = ambientTimelineEpoch {
            ambientTimelineEpoch = epoch + max(resumeTime - pauseBeganAt, 0)
        }
        ambientTimelinePauseBeganAt = nil
        resumeTimelineLayer(baseView.layer)
        resumeTimelineLayer(ambientContentView.layer)
        resumeTimelineLayer(overlayView.layer)
        ambientTimelinePaused = false
    }

    private func pauseTimelineLayer(_ layer: CALayer) {
        guard layer.speed != 0 else { return }
        let pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0
        layer.timeOffset = pausedTime
    }

    private func resumeTimelineLayer(_ layer: CALayer) {
        let pausedTime = layer.timeOffset
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
        let elapsedSincePause = layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        layer.beginTime = elapsedSincePause
    }

    private func resetTimelineLayerTiming(_ layer: CALayer) {
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
    }

    private func ambientTransform(x: CGFloat, y: CGFloat, scale: CGFloat, angle: CGFloat = 0) -> CATransform3D {
        var transform = CATransform3DIdentity
        transform = CATransform3DTranslate(transform, x, y, 0)
        if angle != 0 {
            transform = CATransform3DRotate(transform, angle, 0, 0, 1)
        }
        transform = CATransform3DScale(transform, scale, scale, 1)
        return transform
    }

    // MARK: - Direct interaction and depth

    private func installMotionEffectsIfNeeded() {
        guard parallaxMotionEffect == nil,
              !UIAccessibility.isReduceMotionEnabled else {
            return
        }

        let horizontal = UIInterpolatingMotionEffect(
            keyPath: "center.x",
            type: .tiltAlongHorizontalAxis
        )
        horizontal.minimumRelativeValue = -PPHeroApexMotionTokens.horizontalParallax
        horizontal.maximumRelativeValue = PPHeroApexMotionTokens.horizontalParallax

        let vertical = UIInterpolatingMotionEffect(
            keyPath: "center.y",
            type: .tiltAlongVerticalAxis
        )
        vertical.minimumRelativeValue = -PPHeroApexMotionTokens.verticalParallax
        vertical.maximumRelativeValue = PPHeroApexMotionTokens.verticalParallax

        let group = UIMotionEffectGroup()
        group.motionEffects = [horizontal, vertical]
        ambientView.addMotionEffect(group)
        parallaxMotionEffect = group
    }

    private func removeMotionEffects() {
        if let parallaxMotionEffect {
            ambientView.removeMotionEffect(parallaxMotionEffect)
        }
        parallaxMotionEffect = nil
    }

    private func installTouchTrackerIfNeeded() {
        guard isTouchTrackingEligible else {
            detachTouchTracker()
            return
        }

        var candidate = superview
        while let current = candidate, !current.isUserInteractionEnabled {
            candidate = current.superview
        }

        guard let host = candidate, host.window != nil else { return }

        if touchHost !== host {
            detachTouchTracker()
        }

        if touchRecognizer == nil {
            let recognizer = PPHeroPassiveTouchRecognizer(target: nil, action: nil)
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = self
            recognizer.onUpdate = { [weak self, weak host] point, state, timestamp in
                guard let self, let host else { return }
                self.handleTouch(
                    at: point,
                    in: host,
                    state: state,
                    timestamp: timestamp
                )
            }
            recognizer.onTrackingCancelled = { [weak self] in
                self?.cancelActiveTouchResponse()
            }
            host.addGestureRecognizer(recognizer)
            touchRecognizer = recognizer
        }

        if #available(iOS 13.4, *), hoverRecognizer == nil {
            let hover = UIHoverGestureRecognizer(
                target: self,
                action: #selector(handleHover(_:))
            )
            hover.cancelsTouchesInView = false
            hover.delegate = self
            host.addGestureRecognizer(hover)
            hoverRecognizer = hover
        }

        touchHost = host
    }

    private func detachTouchTracker() {
        touchResponseActive = false
        hoverResponseActive = false
        if let touchRecognizer {
            touchRecognizer.onUpdate = nil
            touchRecognizer.onTrackingCancelled = nil
            touchHost?.removeGestureRecognizer(touchRecognizer)
        }
        if let hoverRecognizer {
            touchHost?.removeGestureRecognizer(hoverRecognizer)
        }
        stopTouchDisplayLink()
        endFingerPresence()
        touchRecognizer = nil
        hoverRecognizer = nil
        touchHost = nil
        previousTouchPoint = nil
        previousTouchTimestamp = nil
        touchVelocity = .zero
        touchTargetPoint = nil
        touchRenderedPoint = nil
        touchStartPoint = nil
        touchStartTimestamp = nil
        touchMaximumTravel = 0
    }

    private var isTouchTrackingEligible: Bool {
        guard useUnderFingerMotion,
              UIView.areAnimationsEnabled,
              !UIAccessibility.isReduceMotionEnabled,
              window != nil else {
            return false
        }

        switch motionStateMachine.state {
        case .ambient, .interactive, .settling:
            return true
        default:
            return false
        }
    }

    private func cancelActiveTouchResponse() {
        guard touchResponseActive || hoverResponseActive else { return }
        touchResponseActive = false
        hoverResponseActive = false
        stopTouchDisplayLink()
        endFingerPresence()
        previousTouchPoint = nil
        previousTouchTimestamp = nil
        touchTargetPoint = nil
        touchRenderedPoint = nil
        touchStartPoint = nil
        touchStartTimestamp = nil
        touchMaximumTravel = 0
        sendMotionEvent(.interactionEnded)
    }

    private func handleTouch(
        at point: CGPoint,
        in host: UIView,
        state: UIGestureRecognizer.State,
        timestamp: TimeInterval
    ) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        let localPoint = convert(point, from: host)
        let hitBounds = bounds.insetBy(dx: -4, dy: -4)

        switch state {
        case .began:
            guard hitBounds.contains(localPoint) else { return }
            if hoverResponseActive {
                hoverResponseActive = false
            } else {
                sendMotionEvent(.interactionBegan)
            }
            guard motionStateMachine.state == .interactive else { return }
            touchResponseActive = true
            previousTouchPoint = localPoint
            previousTouchTimestamp = timestamp
            touchVelocity = .zero
            touchStartPoint = localPoint
            touchStartTimestamp = timestamp
            touchMaximumTravel = 0
            touchTargetPoint = localPoint
            touchRenderedPoint = localPoint
            beginFingerPresence()
            startTouchDisplayLink()
            applyReactiveDepth(at: localPoint, intensity: 1)

        case .changed:
            guard touchResponseActive else { return }
            updateTouchKinetics(at: localPoint, timestamp: timestamp)
            updateTouchTravel(to: localPoint)
            touchTargetPoint = localPoint
            startTouchDisplayLink()

        case .ended, .cancelled, .failed:
            guard touchResponseActive else { return }
            updateTouchKinetics(at: localPoint, timestamp: timestamp)
            updateTouchTravel(to: localPoint)
            touchTargetPoint = localPoint
            applyReactiveDepth(at: localPoint, intensity: 1)

            let isTap = state == .ended && isTapCandidate(endingAt: timestamp)
            touchResponseActive = false
            stopTouchDisplayLink()
            endFingerPresence()
            if isTap {
                playTapPulse(at: localPoint)
            }
            previousTouchPoint = nil
            previousTouchTimestamp = nil
            touchTargetPoint = nil
            touchRenderedPoint = nil
            touchStartPoint = nil
            touchStartTimestamp = nil
            touchMaximumTravel = 0
            sendMotionEvent(.interactionEnded)

        default:
            break
        }
    }

    @available(iOS 13.4, *)
    @objc private func handleHover(_ recognizer: UIHoverGestureRecognizer) {
        guard let host = touchHost,
              !touchResponseActive,
              isTouchTrackingEligible else {
            return
        }

        let point = recognizer.location(in: host)
        let localPoint = convert(point, from: host)
        let isInside = bounds.insetBy(dx: -4, dy: -4).contains(localPoint)
        let timestamp = CACurrentMediaTime()

        switch recognizer.state {
        case .began, .changed:
            guard isInside else {
                endHoverResponseIfNeeded()
                return
            }
            if !hoverResponseActive {
                sendMotionEvent(.interactionBegan)
                guard motionStateMachine.state == .interactive else { return }
                hoverResponseActive = true
                touchRenderedPoint = localPoint
                previousTouchPoint = localPoint
                previousTouchTimestamp = timestamp
                touchVelocity = .zero
                startTouchDisplayLink()
            } else {
                updateTouchKinetics(at: localPoint, timestamp: timestamp)
            }
            touchTargetPoint = localPoint
            startTouchDisplayLink()

        case .ended, .cancelled, .failed:
            endHoverResponseIfNeeded()

        default:
            break
        }
    }

    private func endHoverResponseIfNeeded() {
        guard hoverResponseActive else { return }
        hoverResponseActive = false
        stopTouchDisplayLink()
        previousTouchPoint = nil
        previousTouchTimestamp = nil
        touchTargetPoint = nil
        touchRenderedPoint = nil
        sendMotionEvent(.interactionEnded)
    }

    private func updateTouchTravel(to point: CGPoint) {
        guard let touchStartPoint else { return }
        touchMaximumTravel = max(
            touchMaximumTravel,
            hypot(point.x - touchStartPoint.x, point.y - touchStartPoint.y)
        )
    }

    private func isTapCandidate(endingAt timestamp: TimeInterval) -> Bool {
        guard let touchStartTimestamp else { return false }
        return timestamp - touchStartTimestamp <= PPHeroApexMotionTokens.tapMaximumDuration &&
            touchMaximumTravel <= PPHeroApexMotionTokens.tapMaximumTravel
    }

    private func updateTouchKinetics(at point: CGPoint, timestamp: TimeInterval) {
        defer {
            previousTouchPoint = point
            previousTouchTimestamp = timestamp
        }

        guard let previousTouchPoint,
              let previousTouchTimestamp else {
            return
        }

        let deltaTime = timestamp - previousTouchTimestamp
        guard deltaTime > 0.001, deltaTime < 0.25 else { return }

        let sample = CGVector(
            dx: (point.x - previousTouchPoint.x) / deltaTime,
            dy: (point.y - previousTouchPoint.y) / deltaTime
        )
        touchVelocity = CGVector(
            dx: touchVelocity.dx * 0.58 + sample.dx * 0.42,
            dy: touchVelocity.dy * 0.58 + sample.dy * 0.42
        )
    }

    private func startTouchDisplayLink() {
        guard touchDisplayLink == nil else { return }

        let displayLink = CADisplayLink(
            target: self,
            selector: #selector(renderTouchFrame(_:))
        )
        if #available(iOS 15.0, *) {
            let maximum = Float(window?.screen.maximumFramesPerSecond ?? UIScreen.main.maximumFramesPerSecond)
            displayLink.preferredFrameRateRange = CAFrameRateRange(
                minimum: min(60, maximum),
                maximum: maximum,
                preferred: maximum
            )
        } else {
            displayLink.preferredFramesPerSecond = UIScreen.main.maximumFramesPerSecond
        }
        displayLink.add(to: .main, forMode: .common)
        touchDisplayLink = displayLink
    }

    private func stopTouchDisplayLink() {
        touchDisplayLink?.invalidate()
        touchDisplayLink = nil
    }

    @objc private func renderTouchFrame(_ displayLink: CADisplayLink) {
        guard let target = touchTargetPoint,
              touchResponseActive || hoverResponseActive else {
            stopTouchDisplayLink()
            return
        }

        let current = touchRenderedPoint ?? target
        let frameDuration = max(displayLink.targetTimestamp - displayLink.timestamp, 1.0 / 120.0)
        let base = PPHeroApexMotionTokens.touchSmoothingResponse
        let response = 1 - CGFloat(
            pow(Double(1 - base), frameDuration * 60)
        )
        var rendered = CGPoint(
            x: current.x + (target.x - current.x) * response,
            y: current.y + (target.y - current.y) * response
        )
        if hypot(target.x - rendered.x, target.y - rendered.y) < 0.08 {
            rendered = target
        }
        let velocityDecay = CGFloat(pow(0.0025, frameDuration))
        touchVelocity = CGVector(
            dx: touchVelocity.dx * velocityDecay,
            dy: touchVelocity.dy * velocityDecay
        )
        touchRenderedPoint = rendered
        applyReactiveDepth(
            at: rendered,
            intensity: touchResponseActive ? 1 : 0.44
        )

        let positionSettled = rendered == target
        let velocitySettled = hypot(touchVelocity.dx, touchVelocity.dy) < 8
        if positionSettled && velocitySettled {
            stopTouchDisplayLink()
        }
    }

    private func applyReactiveDepth(at localPoint: CGPoint, intensity: CGFloat) {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let resolvedIntensity = min(max(intensity, 0), 1)

        let normalized = CGPoint(
            x: min(max(localPoint.x / bounds.width, 0), 1),
            y: min(max(localPoint.y / bounds.height, 0), 1)
        )
        let centeredX = normalized.x - 0.5
        let centeredY = normalized.y - 0.5

        var depthTransform = CATransform3DIdentity
        depthTransform.m34 = -1 / 1100
        let depthScale = 1 +
            (PPHeroApexMotionTokens.touchDepthScale - 1) * resolvedIntensity
        depthTransform = CATransform3DScale(
            depthTransform,
            depthScale,
            depthScale,
            1
        )
        depthTransform = CATransform3DTranslate(
            depthTransform,
            centeredX * PPHeroApexMotionTokens.maximumTouchTranslationX * 2 * resolvedIntensity,
            centeredY * PPHeroApexMotionTokens.maximumTouchTranslationY * 2 * resolvedIntensity,
            0
        )
        depthTransform = CATransform3DRotate(
            depthTransform,
            centeredY * PPHeroApexMotionTokens.maximumTouchRotation * 2 * resolvedIntensity,
            1,
            0,
            0
        )
        depthTransform = CATransform3DRotate(
            depthTransform,
            -centeredX * PPHeroApexMotionTokens.maximumTouchRotation * 2 * resolvedIntensity,
            0,
            1,
            0
        )

        let lightCenter = resolvedReactiveLightCenter
        let lightScale = 1 +
            (PPHeroApexMotionTokens.touchLightScale - 1) * resolvedIntensity
        let lightTranslation = CGAffineTransform(
            translationX: (normalized.x - lightCenter.x)
                * bounds.width
                * PPHeroApexMotionTokens.reactiveLightTravelRatio
                * resolvedIntensity,
            y: (normalized.y - lightCenter.y)
                * bounds.height
                * PPHeroApexMotionTokens.reactiveLightTravelRatio
                * resolvedIntensity
        ).scaledBy(
            x: lightScale,
            y: lightScale
        )

        let defaultLightCenter = CGPoint(
            x: bounds.width * lightCenter.x,
            y: bounds.height * lightCenter.y
        )
        let touchSpeed = hypot(touchVelocity.dx, touchVelocity.dy)
        let velocityBloom = min(
            touchSpeed / PPHeroApexMotionTokens.touchVelocityForMaximumBloom,
            1
        )
        let lensScale = PPHeroApexMotionTokens.touchLensBaseScale
            + velocityBloom * PPHeroApexMotionTokens.touchLensVelocityBloom
        let resolvedLensScale = 1 + (lensScale - 1) * resolvedIntensity
        let lensTranslation = CGAffineTransform(
            translationX: localPoint.x - defaultLightCenter.x,
            y: localPoint.y - defaultLightCenter.y
        ).scaledBy(x: resolvedLensScale, y: resolvedLensScale)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ambientView.layer.transform = depthTransform
        CATransaction.commit()
        UIView.performWithoutAnimation {
            reactiveLightView.transform = lightTranslation
            touchLensView.transform = lensTranslation
            touchLensView.alpha = PPHeroApexMotionTokens.touchLensActiveAlpha *
                resolvedIntensity
        }
    }

    private func beginFingerPresence() {
        touchCoreLayer.removeAnimation(forKey: pressHoldAnimationKey)
        contactRingLayer.removeAnimation(forKey: contactWaveAnimationKey)

        let coreOpacity = CAKeyframeAnimation(keyPath: "opacity")
        coreOpacity.values = [0.42, 0.72, 0.54, 0.42]
        coreOpacity.keyTimes = [0, 0.32, 0.72, 1]
        coreOpacity.duration = PPHeroApexMotionTokens.fingerPresenceCycleDuration

        let coreScale = CAKeyframeAnimation(keyPath: "transform.scale")
        coreScale.values = [0.90, 1.05, 0.98, 0.90]
        coreScale.keyTimes = coreOpacity.keyTimes
        coreScale.duration = coreOpacity.duration

        let hold = CAAnimationGroup()
        hold.animations = [coreOpacity, coreScale]
        hold.duration = coreOpacity.duration
        hold.repeatCount = .greatestFiniteMagnitude
        hold.timingFunction = PPHeroApexMotionTokens.ambientTimingFunction
        touchCoreLayer.add(hold, forKey: pressHoldAnimationKey)

        let contactDuration = PPHeroApexMotionTokens.contactWaveDuration
        let ringOpacity = CAKeyframeAnimation(keyPath: "opacity")
        ringOpacity.values = [0, 0.56, 0.16, 0]
        ringOpacity.keyTimes = [0, 0.12, 0.58, 1]
        ringOpacity.duration = contactDuration

        let ringScale = CAKeyframeAnimation(keyPath: "transform.scale")
        ringScale.values = [0.74, 0.86, 1.04, 1.12]
        ringScale.keyTimes = ringOpacity.keyTimes
        ringScale.duration = contactDuration

        let contact = CAAnimationGroup()
        contact.animations = [ringOpacity, ringScale]
        contact.duration = contactDuration
        contact.timingFunction = PPHeroApexMotionTokens.accentTimingFunction
        contactRingLayer.add(contact, forKey: contactWaveAnimationKey)
    }

    private func endFingerPresence() {
        touchCoreLayer.removeAnimation(forKey: pressHoldAnimationKey)
        contactRingLayer.removeAnimation(forKey: contactWaveAnimationKey)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contactRingLayer.opacity = 0
        CATransaction.commit()
    }

    private func playTapPulse(at point: CGPoint) {
        guard UIView.areAnimationsEnabled,
              !UIAccessibility.isReduceMotionEnabled,
              !overlayView.bounds.isEmpty else {
            return
        }

        let palette = makePalette()
        let isDark = traitCollection.userInterfaceStyle == .dark
        let diameter = min(max(min(bounds.width, bounds.height) * 0.92, 132), 196)
        let pulse = CAGradientLayer()
        pulse.type = .radial
        pulse.startPoint = CGPoint(x: 0.5, y: 0.5)
        pulse.endPoint = CGPoint(x: 1, y: 1)
        pulse.locations = [0, 0.22, 0.58, 1]
        pulse.colors = [
            palette.specularLight.withAlphaComponent(isDark ? 0.20 : 0.27).cgColor,
            palette.reactiveLight.withAlphaComponent(isDark ? 0.10 : 0.13).cgColor,
            palette.accent.withAlphaComponent(isDark ? 0.028 : 0.020).cgColor,
            UIColor.clear.cgColor
        ]
        pulse.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        pulse.position = CGPoint(
            x: min(max(point.x, 0), overlayView.bounds.width),
            y: min(max(point.y, 0), overlayView.bounds.height)
        )
        pulse.cornerRadius = diameter * 0.5
        pulse.opacity = 0
        overlayView.layer.insertSublayer(pulse, below: topSpecularLayer)

        let pulseDuration = PPHeroApexMotionTokens.tapPulseDuration
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.34, 0.74, 1.04, 1.18]
        scale.keyTimes = [0, 0.20, 0.68, 1]
        scale.duration = pulseDuration

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 0.30, 0.12, 0]
        opacity.keyTimes = [0, 0.14, 0.58, 1]
        opacity.duration = pulseDuration

        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.duration = pulseDuration
        group.timingFunction = PPHeroApexMotionTokens.accentTimingFunction
        pulse.add(group, forKey: "pp.hero.apex.tap-pulse")

        DispatchQueue.main.asyncAfter(
            deadline: .now() + pulseDuration + 0.05
        ) { [weak pulse] in
            pulse?.removeFromSuperlayer()
        }
    }

    private func startInteractionRecovery(generation: UInt) {
        cancelInteractionRecovery(preservingPresentation: true)

        let spring = UISpringTimingParameters(
            dampingRatio: 0.90,
            initialVelocity: normalizedSpringVelocity()
        )
        let animator = UIViewPropertyAnimator(
            duration: PPHeroApexMotionTokens.interactionSettleDuration,
            timingParameters: spring
        )
        animator.addAnimations { [weak self] in
            self?.ambientView.layer.transform = CATransform3DIdentity
            self?.reactiveLightView.transform = .identity
            self?.touchLensView.transform = .identity
            self?.touchLensView.alpha = 0
        }
        animator.addCompletion { [weak self] position in
            guard let self else { return }
            self.interactionRecoveryAnimator = nil
            guard position == .end else { return }
            self.sendMotionEvent(.settlingCompleted(generation: generation))
        }
        interactionRecoveryAnimator = animator
        animator.startAnimation()
    }

    private func normalizedSpringVelocity() -> CGVector {
        let transform = reactiveLightView.transform
        let deltaX = -transform.tx
        let deltaY = -transform.ty

        let x = abs(deltaX) > 0.5 ? touchVelocity.dx / deltaX : 0
        let y = abs(deltaY) > 0.5 ? touchVelocity.dy / deltaY : 0
        return CGVector(
            dx: min(max(x, -1.2), 1.2),
            dy: min(max(y, -1.2), 1.2)
        )
    }

    private func cancelInteractionRecovery(preservingPresentation: Bool) {
        guard let animator = interactionRecoveryAnimator else { return }

        let ambientPresentationTransform = ambientView.layer.presentation()?.transform
        let lightPresentationTransform = reactiveLightView.layer.presentation()?.affineTransform()
        let lensPresentationTransform = touchLensView.layer.presentation()?.affineTransform()
        let lensPresentationOpacity = touchLensView.layer.presentation()?.opacity

        animator.stopAnimation(true)
        interactionRecoveryAnimator = nil

        guard preservingPresentation else {
            resetInteractiveTransforms()
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let ambientPresentationTransform {
            ambientView.layer.transform = ambientPresentationTransform
        }
        CATransaction.commit()

        if let lightPresentationTransform {
            UIView.performWithoutAnimation {
                reactiveLightView.transform = lightPresentationTransform
            }
        }
        if let lensPresentationTransform {
            UIView.performWithoutAnimation {
                touchLensView.transform = lensPresentationTransform
                if let lensPresentationOpacity {
                    touchLensView.alpha = CGFloat(lensPresentationOpacity)
                }
            }
        }
    }

    private func resetInteractiveTransforms() {
        stopTouchDisplayLink()
        endFingerPresence()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ambientView.layer.transform = CATransform3DIdentity
        CATransaction.commit()

        UIView.performWithoutAnimation {
            reactiveLightView.transform = .identity
            touchLensView.transform = .identity
            touchLensView.alpha = 0
        }
        touchResponseActive = false
        hoverResponseActive = false
        previousTouchPoint = nil
        previousTouchTimestamp = nil
        touchVelocity = .zero
        touchTargetPoint = nil
        touchRenderedPoint = nil
        touchStartPoint = nil
        touchStartTimestamp = nil
        touchMaximumTravel = 0
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard gestureRecognizer === touchRecognizer else { return true }
        let canBegin: Bool
        switch motionStateMachine.state {
        case .ambient, .settling:
            canBegin = true
        case .interactive:
            canBegin = hoverResponseActive && !touchResponseActive
        default:
            canBegin = false
        }
        guard canBegin else {
            return false
        }
        let localPoint = touch.location(in: self)
        return bounds.insetBy(dx: -4, dy: -4).contains(localPoint)
    }

    // MARK: - Accent continuity

    private var shouldAnimateVisualStateChange: Bool {
        guard window != nil,
              UIView.areAnimationsEnabled,
              !UIAccessibility.isReduceMotionEnabled else {
            return false
        }
        switch motionStateMachine.state {
        case .entering, .ambient, .interactive, .settling:
            return true
        default:
            return false
        }
    }

    private func applyAccentMode(animated: Bool) {
        let barOpacity: Float = storedAccentMode == .bar ? 1 : 0
        let glowOpacity: Float = storedAccentMode == .cornerGlow ? 1 : 0
        let barTransform = storedAccentMode == .bar
            ? CATransform3DIdentity
            : CATransform3DMakeTranslation(0, -1.5, 0)
        let glowTransform = storedAccentMode == .cornerGlow
            ? CATransform3DIdentity
            : CATransform3DMakeScale(0.96, 0.96, 1)

        transition(
            layer: accentBarLayer,
            toOpacity: barOpacity,
            transform: barTransform,
            animated: animated,
            key: accentBarTransitionKey
        )
        transition(
            layer: accentGlowLayer,
            toOpacity: glowOpacity,
            transform: glowTransform,
            animated: animated,
            key: accentGlowTransitionKey
        )
    }

    private func transition(
        layer: CALayer,
        toOpacity: Float,
        transform: CATransform3D,
        animated: Bool,
        key: String
    ) {
        let fromOpacity = layer.presentation()?.opacity ?? layer.opacity
        let fromTransform = layer.presentation()?.transform ?? layer.transform

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.opacity = toOpacity
        layer.transform = transform
        CATransaction.commit()

        layer.removeAnimation(forKey: key)
        guard animated else { return }

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = fromOpacity
        opacity.toValue = toOpacity
        opacity.duration = PPHeroApexMotionTokens.accentTransitionDuration

        let transformAnimation = CABasicAnimation(keyPath: "transform")
        transformAnimation.fromValue = NSValue(caTransform3D: fromTransform)
        transformAnimation.toValue = NSValue(caTransform3D: transform)
        transformAnimation.duration = PPHeroApexMotionTokens.accentTransitionDuration

        let group = CAAnimationGroup()
        group.animations = [opacity, transformAnimation]
        group.duration = PPHeroApexMotionTokens.accentTransitionDuration
        group.timingFunction = PPHeroApexMotionTokens.accentTimingFunction
        group.isRemovedOnCompletion = true
        layer.add(group, forKey: key)
    }

    // MARK: - Static and full-motion presentation

    private func applyStaticPresentation(reduced: Bool) {
        cancelEntrance(resolveToFinalState: true)
        resetInteractiveTransforms()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if storedAccentMode.isBaseBackground {
            reactiveLightLayer.opacity = reduced ? 0.42 : 0.50
            prismLayer.opacity = reduced ? 0.26 : 0.32
        } else {
            reactiveLightLayer.opacity = reduced ? 0.48 : 0.58
            prismLayer.opacity = reduced ? 0.62 : 0.76
        }
        signatureSweepLayer.opacity = 0
        CATransaction.commit()

        applyAccentMode(animated: false)
    }

    private func restoreFullMotionModelState() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        reactiveLightLayer.opacity = storedAccentMode.isBaseBackground ? 0.54 : 0.64
        prismLayer.opacity = storedAccentMode.isBaseBackground ? 0.32 : 1
        signatureSweepLayer.opacity = 0
        CATransaction.commit()
        applyAccentMode(animated: false)
    }

    // MARK: - Lifecycle and accessibility

    public override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            reconcileMotionEnvironment(attachedOverride: false)
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        setNeedsLayout()
        layoutIfNeeded()
        reconcileMotionEnvironment()
    }

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if motionStateMachine.state == .ambient ||
            motionStateMachine.state == .interactive ||
            motionStateMachine.state == .settling {
            detachTouchTracker()
            installTouchTrackerIfNeeded()
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        let contrastChanged = previousTraitCollection?.accessibilityContrast !=
            traitCollection.accessibilityContrast
        if previousTraitCollection == nil || contrastChanged ||
            traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            reapplyPalette()
        }
    }

    @objc private func reduceMotionStatusDidChange() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.reduceMotionStatusDidChange()
            }
            return
        }

        reconcileMotionEnvironment()
    }

    @objc private func transparencyOrContrastStatusDidChange() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.transparencyOrContrastStatusDidChange()
            }
            return
        }

        reapplyPalette()
    }

    @objc private func applicationStateDidChange() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.applicationStateDidChange()
            }
            return
        }

        reconcileMotionEnvironment()
    }

    @objc private func energyPolicyDidChange() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.energyPolicyDidChange()
            }
            return
        }

        reconcileMotionEnvironment()
    }

    // MARK: - Deterministic art direction

    private var defaultReactiveLightCenter: CGPoint {
        CGPoint(x: 0.84, y: 0.10)
    }

    private var resolvedReactiveLightCenter: CGPoint {
        let center = defaultReactiveLightCenter
        return CGPoint(
            x: resolvesToFlippedLayout ? (1 - center.x) : center.x,
            y: center.y
        )
    }

    private func resolvedFullScreenPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: resolvesToFlippedLayout ? (1 - point.x) : point.x,
            y: point.y
        )
    }

    private func fullScreenPosition(
        from normalizedPoint: CGPoint,
        in bounds: CGRect
    ) -> CGPoint {
        let point = resolvedFullScreenPoint(normalizedPoint)
        return CGPoint(
            x: bounds.width * point.x,
            y: bounds.height * point.y
        )
    }

    /// BB Base Background keeps each oversized radial field within its own
    /// region. The eye reads changing light temperature, not a blob or band
    /// travelling from one edge of the screen to the other.
    private var baseBackgroundAuroraMotionSpecs: [FullScreenAuroraMotionSpec] {
        [
            FullScreenAuroraMotionSpec(
                normalizedPositions: [
                    CGPoint(x: 0.18, y: 0.14),
                    CGPoint(x: 0.30, y: 0.22),
                    CGPoint(x: 0.26, y: 0.36),
                    CGPoint(x: 0.12, y: 0.30),
                    CGPoint(x: 0.10, y: 0.18),
                    CGPoint(x: 0.18, y: 0.14)
                ],
                scales: [1.04, 1.075, 1.05, 1.085, 1.055, 1.04],
                opacities: [0.54, 0.66, 0.60, 0.68, 0.58, 0.54],
                keyTimes: [0, 0.20, 0.43, 0.65, 0.83, 1],
                duration: 83.9,
                phase: 11.3
            ),
            FullScreenAuroraMotionSpec(
                normalizedPositions: [
                    CGPoint(x: 0.82, y: 0.86),
                    CGPoint(x: 0.70, y: 0.76),
                    CGPoint(x: 0.74, y: 0.60),
                    CGPoint(x: 0.88, y: 0.66),
                    CGPoint(x: 0.90, y: 0.80),
                    CGPoint(x: 0.82, y: 0.86)
                ],
                scales: [1.06, 1.025, 1.08, 1.04, 1.075, 1.06],
                opacities: [0.50, 0.64, 0.56, 0.66, 0.55, 0.50],
                keyTimes: [0, 0.18, 0.41, 0.64, 0.84, 1],
                duration: 97.7,
                phase: 23.1
            ),
            FullScreenAuroraMotionSpec(
                normalizedPositions: [
                    CGPoint(x: 0.50, y: 0.48),
                    CGPoint(x: 0.60, y: 0.40),
                    CGPoint(x: 0.58, y: 0.56),
                    CGPoint(x: 0.44, y: 0.60),
                    CGPoint(x: 0.40, y: 0.44),
                    CGPoint(x: 0.50, y: 0.48)
                ],
                scales: [0.99, 1.035, 1.01, 1.045, 1.02, 0.99],
                opacities: [0.46, 0.58, 0.64, 0.52, 0.60, 0.46],
                keyTimes: [0, 0.22, 0.45, 0.66, 0.85, 1],
                duration: 109.3,
                phase: 37.4
            )
        ]
    }

    private var fullScreenAuroraMotionSpecs: [FullScreenAuroraMotionSpec] {
        [
            FullScreenAuroraMotionSpec(
                normalizedPositions: [
                    CGPoint(x: 0.90, y: -0.08),
                    CGPoint(x: 0.58, y: 0.16),
                    CGPoint(x: 0.16, y: 0.10),
                    CGPoint(x: 0.34, y: 0.54),
                    CGPoint(x: 0.76, y: 0.36),
                    CGPoint(x: 0.90, y: -0.08)
                ],
                scales: [1.03, 0.96, 1.07, 0.99, 1.05, 1.03],
                opacities: [0.68, 0.84, 0.64, 0.78, 0.70, 0.68],
                keyTimes: [0, 0.20, 0.42, 0.64, 0.82, 1],
                duration: 41.9,
                phase: 2.4
            ),
            FullScreenAuroraMotionSpec(
                normalizedPositions: [
                    CGPoint(x: 0.10, y: 1.06),
                    CGPoint(x: 0.34, y: 0.70),
                    CGPoint(x: 0.82, y: 0.88),
                    CGPoint(x: 0.66, y: 0.40),
                    CGPoint(x: 0.24, y: 0.58),
                    CGPoint(x: 0.10, y: 1.06)
                ],
                scales: [1.06, 0.97, 1.04, 0.95, 1.07, 1.06],
                opacities: [0.62, 0.80, 0.68, 0.77, 0.60, 0.62],
                keyTimes: [0, 0.18, 0.40, 0.62, 0.82, 1],
                duration: 53.3,
                phase: 7.1
            ),
            FullScreenAuroraMotionSpec(
                normalizedPositions: [
                    CGPoint(x: 0.50, y: 0.50),
                    CGPoint(x: 0.80, y: 0.24),
                    CGPoint(x: 0.22, y: 0.34),
                    CGPoint(x: 0.72, y: 0.76),
                    CGPoint(x: 0.30, y: 0.82),
                    CGPoint(x: 0.50, y: 0.50)
                ],
                scales: [0.98, 1.06, 0.96, 1.05, 0.99, 0.98],
                opacities: [0.56, 0.74, 0.82, 0.62, 0.76, 0.56],
                keyTimes: [0, 0.22, 0.44, 0.66, 0.84, 1],
                duration: 67.7,
                phase: 12.8
            )
        ]
    }

    private func fullScreenAuroraColorRoute(
        for index: Int,
        palette: Palette
    ) -> [UIColor] {
        let routes = storedAccentMode.isBaseBackground
            ? [
                [0, 1, 2, 0, 1, 0],
                [5, 3, 4, 5, 3, 5],
                [6, 4, 2, 6, 1, 6]
            ]
            : [
                [0, 1, 4, 2, 3, 0],
                [5, 3, 1, 4, 2, 5],
                [6, 2, 4, 1, 3, 6]
            ]
        let route = routes.indices.contains(index) ? routes[index] : routes[0]
        return route.map {
            auroraColor(at: $0, in: palette, fallback: palette.surfaceMiddle)
        }
    }

    private var auroraSpecs: [AuroraSpec] {
        [
            AuroraSpec(
                center: CGPoint(x: 0.90, y: -0.06),
                size: CGSize(width: 1.02, height: 1.54),
                travel: CGSize(width: 12, height: 9),
                scaleRange: 0.992...1.022,
                opacityRange: 0.66...0.92,
                duration: 37.9,
                phase: 7.4
            ),
            AuroraSpec(
                center: CGPoint(x: 0.10, y: 1.04),
                size: CGSize(width: 1.18, height: 1.18),
                travel: CGSize(width: 10, height: 8),
                scaleRange: 0.993...1.020,
                opacityRange: 0.62...0.86,
                duration: 49.7,
                phase: 13.2
            ),
            AuroraSpec(
                center: CGPoint(x: 0.50, y: 0.48),
                size: CGSize(width: 0.90, height: 1.20),
                travel: CGSize(width: 8, height: 6),
                scaleRange: 0.994...1.018,
                opacityRange: 0.52...0.74,
                duration: 63.1,
                phase: 19.6
            )
        ]
    }

    private var normalizedParticlePointGroups: [[CGPoint]] {
        [
            [
                CGPoint(x: 0.08, y: 0.31),
                CGPoint(x: 0.23, y: 0.72),
                CGPoint(x: 0.47, y: 0.17),
                CGPoint(x: 0.71, y: 0.58),
                CGPoint(x: 0.91, y: 0.27),
                CGPoint(x: 0.38, y: 0.34)
            ],
            [
                CGPoint(x: 0.14, y: 0.84),
                CGPoint(x: 0.34, y: 0.43),
                CGPoint(x: 0.58, y: 0.81),
                CGPoint(x: 0.77, y: 0.22),
                CGPoint(x: 0.86, y: 0.68),
                CGPoint(x: 0.64, y: 0.36)
            ],
            [
                CGPoint(x: 0.05, y: 0.57),
                CGPoint(x: 0.29, y: 0.12),
                CGPoint(x: 0.53, y: 0.52),
                CGPoint(x: 0.67, y: 0.91),
                CGPoint(x: 0.96, y: 0.48),
                CGPoint(x: 0.42, y: 0.68)
            ]
        ]
    }
}


private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
