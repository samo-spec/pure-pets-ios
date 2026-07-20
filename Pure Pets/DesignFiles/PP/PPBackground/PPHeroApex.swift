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

    private struct Palette {
        let accent: UIColor
        let surfaceHighlight: UIColor
        let surfaceMiddle: UIColor
        let surfaceTail: UIColor
        let depth: UIColor
        let aurora: [UIColor]
        let particle: [UIColor]
        let reactiveLight: UIColor
        let stroke: UIColor
        let shadowOpacity: Float
    }

    // MARK: - Objective-C compatibility surface

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
    public var overrideSurfureColor: UIColor? {
        didSet {
            if oldValue == nil && overrideSurfureColor == nil {
                return
            }
            if let oldValue,
               let overrideSurfureColor,
               oldValue.isEqual(overrideSurfureColor) {
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

    public var accentStyle: Int {
        get { storedAccentMode.rawValue }
        set {
            let resolvedMode = AccentMode(rawValue: newValue) ?? .bar
            guard resolvedMode != storedAccentMode else { return }
            storedAccentMode = resolvedMode
            setNeedsLayout()
            applyAccentMode(animated: shouldAnimateVisualStateChange)
        }
    }

    public var cornerGlowOpacityMultiplier: CGFloat {
        get { storedCornerGlowOpacityMultiplier }
        set {
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
    public var useUnderFingerMotion: Bool = false {
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
            return effectiveUserInterfaceLayoutDirection == .leftToRight
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
    private let auroraLayers = (0..<3).map { _ in CAGradientLayer() }
    private let particleLayers = (0..<3).map { _ in CAShapeLayer() }
    private let reactiveLightLayer = CAGradientLayer()
    private let touchLensLayer = CAGradientLayer()
    private let touchCoreLayer = CAGradientLayer()
    private let signatureSweepLayer = CAGradientLayer()
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

    private var parallaxMotionEffect: UIMotionEffectGroup?
    private weak var touchHost: UIView?
    private var touchRecognizer: PPHeroPassiveTouchRecognizer?
    private var touchResponseActive = false
    private var previousTouchPoint: CGPoint?
    private var previousTouchTimestamp: TimeInterval?
    private var touchVelocity = CGVector.zero

    // MARK: - Stable visual state

    private var storedAccentMode: AccentMode = .bar
    private var storedCornerGlowOpacityMultiplier: CGFloat = 1
    private var storedCornerRadius: CGFloat = 30
    private var lastLayoutSize: CGSize = .zero

    private let auroraAnimationKey = "pp.hero.apex.aurora"
    private let fieldDriftAnimationKey = "pp.hero.apex.field-drift"
    private let particleAnimationKey = "pp.hero.apex.particle"
    private let reactiveLightAnimationKey = "pp.hero.apex.reactive-light"
    private let signatureSweepAnimationKey = "pp.hero.apex.signature-sweep"
    private let auroraColorTransitionKey = "pp.hero.apex.aurora-color-transition"
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
            layer.contentsScale = UIScreen.main.scale
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
        touchLensView.alpha = 0

        signatureSweepLayer.startPoint = CGPoint(x: 0, y: 0.5)
        signatureSweepLayer.endPoint = CGPoint(x: 1, y: 0.5)
        signatureSweepLayer.locations = [0, 0.18, 0.35, 0.50, 0.64, 0.82, 1]
        signatureSweepLayer.opacity = 0
        signatureSweepLayer.drawsAsynchronously = true
        overlayView.layer.addSublayer(signatureSweepLayer)

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
        innerStrokeLayer.contentsScale = UIScreen.main.scale
        overlayView.layer.addSublayer(innerStrokeLayer)
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

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        materialView.frame = bounds
        baseView.frame = materialView.contentView.bounds
        ambientView.frame = materialView.contentView.bounds
        ambientContentView.frame = ambientView.bounds
        overlayView.frame = materialView.contentView.bounds

        let materialBounds = baseView.bounds
        baseGradientLayer.frame = materialBounds
        depthGradientLayer.frame = materialBounds
        vignetteLayer.frame = materialBounds

        layoutAuroraLayers(in: ambientContentView.bounds)
        layoutParticleLayers(in: ambientContentView.bounds)
        layoutReactiveLight(in: overlayView.bounds)
        layoutSignatureSweep(in: overlayView.bounds)
        layoutAccentLayers(in: overlayView.bounds)
        updateCornerGeometry()

        CATransaction.commit()

        let didChangeSize = lastLayoutSize != .zero && lastLayoutSize != bounds.size
        lastLayoutSize = bounds.size
        if didChangeSize && ambientTimelineInstalled {
            installSignatureSweepAnimation()
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

    private func layoutParticleLayers(in bounds: CGRect) {
        guard !bounds.isEmpty else { return }

        let displayScale = max(UIScreen.main.scale, 1)
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
        let useFlippedLayout = resolvesToFlippedLayout
        let reactiveCenterX = useFlippedLayout ? (1.0 - defaultReactiveLightCenter.x) : defaultReactiveLightCenter.x
        reactiveLightView.center = CGPoint(
            x: bounds.width * reactiveCenterX,
            y: bounds.height * defaultReactiveLightCenter.y
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
        let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled

        materialView.effect = reduceTransparency
            ? nil
            : UIBlurEffect(style: .systemUltraThinMaterial)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        backgroundColor = .clear
        materialView.backgroundColor = .clear
        materialView.contentView.backgroundColor = .clear

        baseGradientLayer.colors = [
            palette.surfaceHighlight.cgColor,
            palette.surfaceMiddle.cgColor,
            palette.surfaceTail.cgColor
        ]
        baseGradientLayer.startPoint = effectiveUserInterfaceLayoutDirection == .rightToLeft
            ? CGPoint(x: 1, y: 0)
            : CGPoint(x: 0, y: 0)
        baseGradientLayer.endPoint = effectiveUserInterfaceLayoutDirection == .rightToLeft
            ? CGPoint(x: 0, y: 1)
            : CGPoint(x: 1, y: 1)

        depthGradientLayer.colors = [
            UIColor.clear.cgColor,
            palette.depth.withAlphaComponent(isDark ? 0.055 : 0.018).cgColor,
            palette.depth.withAlphaComponent(isDark ? 0.16 : 0.055).cgColor
        ]

        vignetteLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(isDark ? 0.13 : 0.032).cgColor
        ]

        for (index, layer) in auroraLayers.enumerated() {
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
            setAuroraColors(
                targetColors,
                on: layer,
                animated: shouldAnimateVisualStateChange &&
                    !shouldRefreshAmbientAuroraTimelineForPalette
            )
            layer.opacity = restingOpacity
        }

        for (index, layer) in particleLayers.enumerated() {
            let color = palette.particle[index % palette.particle.count]
            layer.fillColor = color.cgColor
            layer.opacity = isDark ? 0.31 : 0.24
            layer.shadowOpacity = 0
            layer.shadowRadius = 0
            layer.shadowOffset = .zero
        }

        reactiveLightLayer.colors = [
            palette.reactiveLight.withAlphaComponent(isDark ? 0.20 : 0.27).cgColor,
            palette.reactiveLight.withAlphaComponent(isDark ? 0.06 : 0.08).cgColor,
            UIColor.clear.cgColor
        ]
        reactiveLightLayer.opacity = 0.84

        touchLensLayer.colors = [
            palette.reactiveLight.withAlphaComponent(isDark ? 0.28 : 0.34).cgColor,
            palette.reactiveLight.withAlphaComponent(isDark ? 0.12 : 0.16).cgColor,
            palette.accent.withAlphaComponent(isDark ? 0.045 : 0.035).cgColor,
            UIColor.clear.cgColor
        ]
        touchCoreLayer.colors = [
            UIColor.white.withAlphaComponent(isDark ? 0.24 : 0.36).cgColor,
            palette.reactiveLight.withAlphaComponent(isDark ? 0.08 : 0.12).cgColor,
            UIColor.clear.cgColor
        ]

        signatureSweepLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(isDark ? 0.025 : 0.05).cgColor,
            UIColor.white.withAlphaComponent(isDark ? 0.26 : 0.38).cgColor,
            UIColor.white.withAlphaComponent(isDark ? 0.07 : 0.12).cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor
        ]
        signatureSweepLayer.opacity = 0

        accentBarLayer.colors = [
            palette.accent.withAlphaComponent(0.38).cgColor,
            palette.accent.withAlphaComponent(0.82).cgColor,
            palette.accent.withAlphaComponent(0.22).cgColor
        ]

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

        accentGlowLayer.colors = [
            palette.accent.withAlphaComponent((isDark ? 0.17 : 0.115) * glowStrength).cgColor,
            middleGlowColor.withAlphaComponent(middleGlowAlpha).cgColor,
            UIColor.clear.cgColor
        ]

        innerStrokeLayer.strokeColor = palette.stroke.cgColor
        layer.shadowOpacity = palette.shadowOpacity

        CATransaction.commit()

        applyAccentMode(animated: false)
        setNeedsLayout()
        refreshAmbientAuroraTimelineAfterPaletteIfNeeded()
    }

    private func makePalette() -> Palette {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let strongerContrast = UIAccessibility.isDarkerSystemColorsEnabled

        let fallbackAccent = UIColor(
            displayP3Red: 201.0 / 255.0,
            green: 48.0 / 255.0,
            blue: 82.0 / 255.0,
            alpha: 1
        )
        let explicitAccent = accentColorOverride.map { resolvedColor($0) }
        let accent = explicitAccent ?? resolvedColor(UIColor(named: "AppPrimaryColor") ?? fallbackAccent)

        let surfaceFallback = isDark
            ? UIColor(white: 0.105, alpha: 1)
            : UIColor(red: 0.992, green: 0.989, blue: 0.991, alpha: 1)

        let surfaceBase: UIColor
        if let surfaceOverride = overrideSurfureColor ?? overrideSurfaceColor {
            surfaceBase = resolvedColor(surfaceOverride)
        } else {
            surfaceBase = resolvedColor(
                UIColor(named: "AppForegroundColor") ?? surfaceFallback
            )
        }

        let polishedSurfaceBase = isDark
            ? surfaceBase
            : blend(surfaceBase, with: .white, amount: 0.30)
        let highlight = blend(
            polishedSurfaceBase,
            with: .white,
            amount: isDark ? 0.075 : 0.34
        )
        let middle = blend(
            polishedSurfaceBase,
            with: accent,
            amount: isDark ? 0.068 : 0.012
        )
        let tail = blend(
            polishedSurfaceBase,
            with: accent,
            amount: isDark ? 0.043 : 0.008
        )

        let twilight = blend(accent, with: resolvedColor(.systemIndigo), amount: 0.44)
        let shine = explicitAccent ?? resolvedColor(UIColor(named: "AppPrimaryColorShainer") ?? twilight)

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
            bottomTrailingGlow = blend(
                shine,
                with: accent,
                amount: explicitAccent == nil ? 0.34 : 0.72
            )
        }
        let middleGlow: UIColor
        if let centerGlowOverride = overrideCenterGlowColor {
            middleGlow = resolvedColor(centerGlowOverride)
        } else {
            middleGlow = blend(
                accent,
                with: shine,
                amount: explicitAccent == nil ? 0.52 : 0.18
            )
        }
        let particlePrimary = blend(accent, with: .white, amount: isDark ? 0.66 : 0.52)
        let particleSecondary = blend(bottomTrailingGlow, with: .white, amount: isDark ? 0.56 : 0.66)

        return Palette(
            accent: accent,
            surfaceHighlight: highlight,
            surfaceMiddle: middle,
            surfaceTail: tail,
            depth: blend(polishedSurfaceBase, with: .black, amount: isDark ? 0.30 : 0.07),
            aurora: storedAccentMode == .fullScreen ? [
                topGlow,
                blend(topGlow, with: .systemPink, amount: 0.5),
                blend(topGlow, with: .systemIndigo, amount: 0.6),
                blend(topGlow, with: .systemTeal, amount: 0.7),
                UIColor(red: 255.0/255.0, green: 198.0/255.0, blue: 84.0/255.0, alpha: 1.0),
                bottomTrailingGlow,
                middleGlow
            ] : [
                topGlow,
                bottomTrailingGlow,
                middleGlow
            ],
            particle: [particlePrimary, particleSecondary, UIColor.white],
            reactiveLight: blend(accent, with: .white, amount: isDark ? 0.76 : 0.86),
            stroke: UIColor.white.withAlphaComponent(
                strongerContrast ? (isDark ? 0.24 : 0.92) : (isDark ? 0.13 : 0.76)
            ),
            shadowOpacity: isDark ? 0.22 : 0.085
        )
    }

    private func setAuroraColors(
        _ colors: [CGColor],
        on layer: CAGradientLayer,
        animated: Bool
    ) {
        let sourceColors = layer.presentation()?.colors ?? layer.colors
        let targetColors = colors.map { $0 as Any }

        layer.removeAnimation(forKey: auroraColorTransitionKey)
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
        layer.add(transition, forKey: auroraColorTransitionKey)
    }

    private func auroraLeadingAlpha(
        isDark: Bool,
        reduceTransparency: Bool
    ) -> CGFloat {
        if storedAccentMode == .fullScreen {
            return reduceTransparency
                ? (isDark ? 0.24 : 0.18)
                : (isDark ? 0.38 : 0.26)
        }
        return reduceTransparency
            ? (isDark ? 0.19 : 0.14)
            : (isDark ? 0.28 : 0.19)
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
        let bottomIndex = storedAccentMode == .fullScreen ? 5 : 1
        let middleIndex = storedAccentMode == .fullScreen ? 6 : 2
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

    private func makeAuroraColorCycleAnimation(
        for index: Int,
        palette: Palette
    ) -> CAKeyframeAnimation? {
        let route = auroraColorRoute(for: index, palette: palette)
        guard route.count > 1 else { return nil }

        let isDark = traitCollection.userInterfaceStyle == .dark
        let leadingAlpha = auroraLeadingAlpha(
            isDark: isDark,
            reduceTransparency: UIAccessibility.isReduceTransparencyEnabled
        )
        let values: [[Any]] = route.map { color in
            auroraGradientColors(
                for: color,
                palette: palette,
                index: index,
                leadingAlpha: leadingAlpha,
                isDark: isDark
            ).map { $0 as Any }
        }

        let colorCycle = CAKeyframeAnimation(keyPath: "colors")
        colorCycle.values = values
        colorCycle.keyTimes = [0, 0.24, 0.50, 0.76, 1]
        colorCycle.calculationMode = .linear
        colorCycle.timingFunctions = Array(
            repeating: PPHeroApexMotionTokens.paletteTimingFunction,
            count: values.count - 1
        )
        return colorCycle
    }

    private func auroraColorRoute(for index: Int, palette: Palette) -> [UIColor] {
        let roles = auroraRoleColors(from: palette)
        switch AuroraRole(rawValue: index) {
        case .leading:
            return [
                roles.top,
                roles.middle,
                roles.bottom,
                roles.middle,
                roles.top
            ]
        case .bottomTrailing:
            return [
                roles.bottom,
                roles.top,
                roles.middle,
                roles.top,
                roles.bottom
            ]
        case .middle:
            return [
                roles.middle,
                roles.bottom,
                roles.top,
                roles.bottom,
                roles.middle
            ]
        case .none:
            let base = auroraBaseColor(for: index, palette: palette)
            return [base, base, base, base, base]
        }
    }

    private var shouldRefreshAmbientAuroraTimelineForPalette: Bool {
        guard ambientTimelineInstalled,
              !ambientTimelinePaused,
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

    private func refreshAmbientAuroraTimelineAfterPaletteIfNeeded() {
        guard shouldRefreshAmbientAuroraTimelineForPalette else { return }
        auroraLayers.forEach { layer in
            layer.removeAnimation(forKey: auroraColorTransitionKey)
            layer.removeAnimation(forKey: auroraAnimationKey)
        }
        installAuroraAnimations()
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

        return UIColor(
            red: baseRed * (1 - t) + overlayRed * t,
            green: baseGreen * (1 - t) + overlayGreen * t,
            blue: baseBlue * (1 - t) + overlayBlue * t,
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
            hasValidGeometry: bounds.width > 1 && bounds.height > 1,
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
            installFieldDriftAnimation()
            installAuroraAnimations()
            installParticleAnimations()
            installLightAnimations()
            ambientTimelineInstalled = true
        }
        resumeAmbientTimeline()
    }

    private func installFieldDriftAnimation() {
        let drift = CAKeyframeAnimation(keyPath: "sublayerTransform")
        drift.values = [
            NSValue(caTransform3D: ambientTransform(x: -18, y: 11, scale: 1.022)),
            NSValue(caTransform3D: ambientTransform(x: 32, y: -20, scale: 1.095)),
            NSValue(caTransform3D: ambientTransform(x: -28, y: 24, scale: 1.046)),
            NSValue(caTransform3D: ambientTransform(x: 12, y: -8, scale: 1.064)),
            NSValue(caTransform3D: ambientTransform(x: -18, y: 11, scale: 1.022))
        ]
        drift.keyTimes = [0, 0.28, 0.58, 0.82, 1]
        drift.calculationMode = .cubic
        drift.timingFunctions = Array(
            repeating: PPHeroApexMotionTokens.ambientTimingFunction,
            count: 4
        )

        let group = makeRepeatingAnimationGroup(
            animations: [drift],
            duration: PPHeroApexMotionTokens.fieldDriftCycleDuration,
            phase: 0.7
        )
        ambientContentView.layer.add(group, forKey: fieldDriftAnimationKey)
    }

    private func installAuroraAnimations() {
        let palette = makePalette()

        for (index, layer) in auroraLayers.enumerated() where index < auroraSpecs.count {
            let spec = auroraSpecs[index]

            let transform: CAKeyframeAnimation
            let opacity: CAKeyframeAnimation

            if storedAccentMode == .fullScreen {
                transform = CAKeyframeAnimation(keyPath: "transform")
                let rotationDirection: CGFloat = index == AuroraRole.middle.rawValue ? -1 : 1
                transform.values = [
                    NSValue(caTransform3D: ambientTransform(
                        x: -spec.travel.width * 0.54,
                        y: spec.travel.height * 0.34,
                        scale: spec.scaleRange.lowerBound,
                        angle: 0
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: spec.travel.width * 0.78,
                        y: -spec.travel.height * 0.58,
                        scale: 1.038,
                        angle: rotationDirection * CGFloat.pi * 0.5
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: spec.travel.width * 1.12,
                        y: spec.travel.height * 0.46,
                        scale: spec.scaleRange.upperBound,
                        angle: rotationDirection * CGFloat.pi
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: -spec.travel.width * 0.36,
                        y: -spec.travel.height * 0.40,
                        scale: 1.020,
                        angle: rotationDirection * CGFloat.pi * 1.5
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: -spec.travel.width * 0.54,
                        y: spec.travel.height * 0.34,
                        scale: spec.scaleRange.lowerBound,
                        angle: rotationDirection * CGFloat.pi * 2.0
                    ))
                ]
                transform.keyTimes = [0, 0.25, 0.50, 0.75, 1]
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
                    lowOpacity + (highOpacity - lowOpacity) * 0.65,
                    highOpacity,
                    lowOpacity + (highOpacity - lowOpacity) * 0.45,
                    lowOpacity
                ]
                opacity.keyTimes = [0, 0.25, 0.50, 0.75, 1]
                opacity.calculationMode = .cubic
                opacity.timingFunctions = transform.timingFunctions
            } else if index == AuroraRole.bottomTrailing.rawValue {
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

            var animations: [CAAnimation] = [transform, opacity]
            if let colorCycle = makeAuroraColorCycleAnimation(
                for: index,
                palette: palette
            ) {
                animations.append(colorCycle)
            }

            let group = makeRepeatingAnimationGroup(
                animations: animations,
                duration: spec.duration,
                phase: spec.phase
            )
            layer.add(group, forKey: auroraAnimationKey)
        }
    }

    private func installParticleAnimations() {
        for (index, layer) in particleLayers.enumerated() {
            let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let travelX = direction * (12 + CGFloat(index) * 4)
            let travelY = 9 + CGFloat(index) * 2.5

            let transform = CAKeyframeAnimation(keyPath: "transform")
            transform.values = [
                NSValue(caTransform3D: ambientTransform(x: 0, y: 0, scale: 1)),
                NSValue(caTransform3D: ambientTransform(
                    x: travelX,
                    y: -travelY,
                    scale: 1.08
                )),
                NSValue(caTransform3D: ambientTransform(
                    x: -travelX * 0.62,
                    y: travelY,
                    scale: 0.94
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
                baseOpacity * 0.40,
                min(baseOpacity + 0.18, 0.58),
                baseOpacity * 0.62,
                baseOpacity * 0.40
            ]
            opacity.keyTimes = [0, 0.36, 0.74, 1]
            opacity.calculationMode = .cubic
            opacity.timingFunctions = Array(
                repeating: PPHeroApexMotionTokens.ambientTimingFunction,
                count: 3
            )

            let duration = 5.4 + CFTimeInterval(index) * 1.7
            let group = makeRepeatingAnimationGroup(
                animations: [transform, opacity],
                duration: duration,
                phase: 1.3 + CFTimeInterval(index) * 2.2
            )
            layer.add(group, forKey: particleAnimationKey)
        }
    }

    private func installLightAnimations() {
        let reactiveBreath = CAKeyframeAnimation(keyPath: "opacity")
        reactiveBreath.values = [0.42, 0.84, 0.55, 0.42]
        reactiveBreath.keyTimes = [0, 0.38, 0.74, 1]
        reactiveBreath.calculationMode = .cubic
        reactiveBreath.timingFunctions = Array(
            repeating: PPHeroApexMotionTokens.ambientTimingFunction,
            count: 3
        )

        let reactiveTravel = CAKeyframeAnimation(keyPath: "transform")
        reactiveTravel.values = [
            NSValue(caTransform3D: ambientTransform(x: -11, y: 5, scale: 0.97)),
            NSValue(caTransform3D: ambientTransform(x: 17, y: -9, scale: 1.055)),
            NSValue(caTransform3D: ambientTransform(x: -14, y: 11, scale: 1.015)),
            NSValue(caTransform3D: ambientTransform(x: -11, y: 5, scale: 0.97))
        ]
        reactiveTravel.keyTimes = [0, 0.38, 0.74, 1]
        reactiveTravel.calculationMode = .cubic
        reactiveTravel.timingFunctions = Array(
            repeating: PPHeroApexMotionTokens.ambientTimingFunction,
            count: 3
        )

        let reactiveGroup = makeRepeatingAnimationGroup(
            animations: [reactiveBreath, reactiveTravel],
            duration: 5.4,
            phase: 1.1
        )
        reactiveLightLayer.add(reactiveGroup, forKey: reactiveLightAnimationKey)

        syncSignatureSweepTimeline()
    }

    private func installSignatureSweepAnimation() {
        guard useShimmer, !overlayView.bounds.isEmpty else {
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
        travel.keyTimes = [0, 0.06, 0.46, 1]
        travel.timingFunctions = [
            CAMediaTimingFunction(name: .linear),
            PPHeroApexMotionTokens.signatureSweepTimingFunction,
            CAMediaTimingFunction(name: .linear)
        ]

        let verticalTravel = CAKeyframeAnimation(keyPath: "position.y")
        verticalTravel.values = [startY, startY, endY, endY]
        verticalTravel.keyTimes = [0, 0.06, 0.46, 1]
        verticalTravel.timingFunctions = travel.timingFunctions

        let visibility = CAKeyframeAnimation(keyPath: "opacity")
        visibility.values = [0, 0, 1, 0.72, 0, 0]
        visibility.keyTimes = [0, 0.06, 0.16, 0.36, 0.46, 1]
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
        // CAAnimationGroup does not propagate its duration to child animations.
        animations.forEach { animation in
            animation.beginTime = 0
            animation.duration = duration
        }

        let group = CAAnimationGroup()
        group.animations = animations
        group.duration = duration
        group.timeOffset = max(phase, 0).truncatingRemainder(dividingBy: duration)
        group.repeatCount = .greatestFiniteMagnitude
        group.isRemovedOnCompletion = true
        return group
    }

    private func removeAmbientTimeline() {
        resetTimelineLayerTiming(ambientContentView.layer)
        resetTimelineLayerTiming(overlayView.layer)

        ambientContentView.layer.removeAnimation(forKey: fieldDriftAnimationKey)
        auroraLayers.forEach { $0.removeAnimation(forKey: auroraAnimationKey) }
        particleLayers.forEach { $0.removeAnimation(forKey: particleAnimationKey) }
        reactiveLightLayer.removeAnimation(forKey: reactiveLightAnimationKey)
        signatureSweepLayer.removeAnimation(forKey: signatureSweepAnimationKey)

        ambientTimelineInstalled = false
        ambientTimelinePaused = false
    }

    private func pauseAmbientTimeline() {
        guard ambientTimelineInstalled, !ambientTimelinePaused else { return }
        pauseTimelineLayer(ambientContentView.layer)
        pauseTimelineLayer(overlayView.layer)
        ambientTimelinePaused = true
    }

    private func resumeAmbientTimeline() {
        guard ambientTimelineInstalled, ambientTimelinePaused else { return }
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
        guard touchRecognizer == nil else { return }

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
        touchHost = host
        touchRecognizer = recognizer
    }

    private func detachTouchTracker() {
        if let touchRecognizer {
            touchRecognizer.onUpdate = nil
            touchRecognizer.onTrackingCancelled = nil
            touchHost?.removeGestureRecognizer(touchRecognizer)
        }
        touchRecognizer = nil
        touchHost = nil
        touchResponseActive = false
        previousTouchPoint = nil
        previousTouchTimestamp = nil
        touchVelocity = .zero
    }

    private var isTouchTrackingEligible: Bool {
        guard useUnderFingerMotion,
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
        guard touchResponseActive else { return }
        touchResponseActive = false
        previousTouchPoint = nil
        previousTouchTimestamp = nil
        touchVelocity = .zero
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
            sendMotionEvent(.interactionBegan)
            guard motionStateMachine.state == .interactive else { return }
            touchResponseActive = true
            previousTouchPoint = localPoint
            previousTouchTimestamp = timestamp
            touchVelocity = .zero
            applyReactiveDepth(at: localPoint)

        case .changed:
            guard touchResponseActive else { return }
            updateTouchKinetics(at: localPoint, timestamp: timestamp)
            applyReactiveDepth(at: localPoint)

        case .ended, .cancelled, .failed:
            guard touchResponseActive else { return }
            updateTouchKinetics(at: localPoint, timestamp: timestamp)
            touchResponseActive = false
            previousTouchPoint = nil
            previousTouchTimestamp = nil
            sendMotionEvent(.interactionEnded)

        default:
            break
        }
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

    private func applyReactiveDepth(at localPoint: CGPoint) {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let normalized = CGPoint(
            x: min(max(localPoint.x / bounds.width, 0), 1),
            y: min(max(localPoint.y / bounds.height, 0), 1)
        )
        let centeredX = normalized.x - 0.5
        let centeredY = normalized.y - 0.5

        var depthTransform = CATransform3DIdentity
        depthTransform.m34 = -1 / 1100
        depthTransform = CATransform3DScale(
            depthTransform,
            PPHeroApexMotionTokens.touchDepthScale,
            PPHeroApexMotionTokens.touchDepthScale,
            1
        )
        depthTransform = CATransform3DTranslate(
            depthTransform,
            centeredX * PPHeroApexMotionTokens.maximumTouchTranslationX * 2,
            centeredY * PPHeroApexMotionTokens.maximumTouchTranslationY * 2,
            0
        )
        depthTransform = CATransform3DRotate(
            depthTransform,
            centeredY * PPHeroApexMotionTokens.maximumTouchRotation * 2,
            1,
            0,
            0
        )
        depthTransform = CATransform3DRotate(
            depthTransform,
            -centeredX * PPHeroApexMotionTokens.maximumTouchRotation * 2,
            0,
            1,
            0
        )

        let lightTranslation = CGAffineTransform(
            translationX: (normalized.x - defaultReactiveLightCenter.x)
                * bounds.width
                * PPHeroApexMotionTokens.reactiveLightTravelRatio,
            y: (normalized.y - defaultReactiveLightCenter.y)
                * bounds.height
                * PPHeroApexMotionTokens.reactiveLightTravelRatio
        ).scaledBy(
            x: PPHeroApexMotionTokens.touchLightScale,
            y: PPHeroApexMotionTokens.touchLightScale
        )

        let defaultLightCenter = CGPoint(
            x: bounds.width * defaultReactiveLightCenter.x,
            y: bounds.height * defaultReactiveLightCenter.y
        )
        let touchSpeed = hypot(touchVelocity.dx, touchVelocity.dy)
        let velocityBloom = min(
            touchSpeed / PPHeroApexMotionTokens.touchVelocityForMaximumBloom,
            1
        )
        let lensScale = PPHeroApexMotionTokens.touchLensBaseScale
            + velocityBloom * PPHeroApexMotionTokens.touchLensVelocityBloom
        let lensTranslation = CGAffineTransform(
            translationX: localPoint.x - defaultLightCenter.x,
            y: localPoint.y - defaultLightCenter.y
        ).scaledBy(x: lensScale, y: lensScale)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ambientView.layer.transform = depthTransform
        CATransaction.commit()
        UIView.performWithoutAnimation {
            reactiveLightView.transform = lightTranslation
            touchLensView.transform = lensTranslation
            touchLensView.alpha = PPHeroApexMotionTokens.touchLensActiveAlpha
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
        previousTouchPoint = nil
        previousTouchTimestamp = nil
        touchVelocity = .zero
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
        guard motionStateMachine.state == .ambient ||
                motionStateMachine.state == .settling else {
            return false
        }
        let localPoint = touch.location(in: self)
        return bounds.insetBy(dx: -4, dy: -4).contains(localPoint)
    }

    // MARK: - Accent continuity

    private var shouldAnimateVisualStateChange: Bool {
        guard window != nil,
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
        reactiveLightLayer.opacity = reduced ? 0.70 : 0.78
        signatureSweepLayer.opacity = 0
        CATransaction.commit()

        applyAccentMode(animated: false)
    }

    private func restoreFullMotionModelState() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        reactiveLightLayer.opacity = 0.84
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

        if previousTraitCollection == nil ||
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

    private var auroraSpecs: [AuroraSpec] {
        [
            AuroraSpec(
                center: CGPoint(x: 0.88, y: -0.08),
                size: CGSize(width: 1.04, height: 1.62),
                travel: CGSize(width: 86, height: 62),
                scaleRange: 0.93...1.12,
                opacityRange: 0.52...1,
                duration: 18.6,
                phase: 4.9
            ),
            AuroraSpec(
                center: CGPoint(x: 0.12, y: 1.02),
                size: CGSize(width: 1.20, height: 1.14),
                travel: CGSize(width: 76, height: 58),
                scaleRange: 0.965...1.095,
                opacityRange: 0.44...0.90,
                duration: 24.8,
                phase: 10.6
            ),
            AuroraSpec(
                center: CGPoint(x: 0.50, y: 0.48),
                size: CGSize(width: 0.94, height: 1.26),
                travel: CGSize(width: 64, height: 48),
                scaleRange: 0.97...1.075,
                opacityRange: 0.36...0.72,
                duration: 22.4,
                phase: 7.3
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





















//
//  PPHeroApex.swift
//  Pure Pets
//
//  Flagship-grade, background-only hero material. The Objective-C
//  PPBackgroundView contract stays stable while this view owns
//  rendering, accessibility, interaction, and motion lifecycle.
//
/*
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

    private struct Palette {
        let accent: UIColor
        let surfaceHighlight: UIColor
        let surfaceMiddle: UIColor
        let surfaceTail: UIColor
        let depth: UIColor
        let aurora: [UIColor]
        let particle: [UIColor]
        let reactiveLight: UIColor
        let stroke: UIColor
    }

    private static func marketplaceAllColor(_ hex: UInt32, alpha: CGFloat = 1) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// Mirrors the Home marketplace hero's `All` selected color source.
    private static func marketplaceAllAccentColor() -> UIColor {
        UIColor(named: "AppPrimaryColor") ?? marketplaceAllColor(0xC93052)
    }

    private static func marketplaceAllShineColor() -> UIColor {
        UIColor(named: "AppPrimaryColorShainer") ?? marketplaceAllColor(0xF43F6A)
    }

    private static func marketplaceAllSurfaceBaseColor(isDark: Bool) -> UIColor {
        let fallback = isDark
            ? UIColor(white: 0.104, alpha: 1)
            : UIColor(red: 0.992, green: 0.989, blue: 0.991, alpha: 1)
        return UIColor(named: "AppForegroundColor") ?? fallback
    }

    // MARK: - Objective-C compatibility surface

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
            updatePalette(animated: shouldAnimateVisualStateChange)
        }
    }

    public var accentStyle: Int {
        get { storedAccentMode.rawValue }
        set {
            let resolvedMode = AccentMode(rawValue: newValue) ?? .bar
            guard resolvedMode != storedAccentMode else { return }
            storedAccentMode = resolvedMode
            setNeedsLayout()
            applyAccentMode(animated: shouldAnimateVisualStateChange)
        }
    }

    public var cornerGlowOpacityMultiplier: CGFloat {
        get { storedCornerGlowOpacityMultiplier }
        set {
            let clamped = min(max(newValue, 0), 1)
            guard abs(clamped - storedCornerGlowOpacityMultiplier) > 0.001 else { return }
            storedCornerGlowOpacityMultiplier = clamped
            updatePalette(animated: shouldAnimateVisualStateChange)
        }
    }

    /// Synchronized by the Objective-C adapter from the owning hero surface.
    public var heroCornerRadius: CGFloat {
        get { storedCornerRadius }
        set {
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
    private let auroraLayers = (0..<2).map { _ in CAGradientLayer() }
    private let particleLayers = (0..<3).map { _ in CAShapeLayer() }
    private let reactiveLightLayer = CAGradientLayer()
    private let touchLensLayer = CAGradientLayer()
    private let touchCoreLayer = CAGradientLayer()
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

    private var parallaxMotionEffect: UIMotionEffectGroup?
    private weak var touchHost: UIView?
    private var touchRecognizer: PPHeroPassiveTouchRecognizer?
    private var touchResponseActive = false
    private var previousTouchPoint: CGPoint?
    private var previousTouchTimestamp: TimeInterval?
    private var touchVelocity = CGVector.zero

    // MARK: - Stable visual state

    private var storedAccentMode: AccentMode = .bar
    private var storedCornerGlowOpacityMultiplier: CGFloat = 1
    private var storedCornerRadius: CGFloat = 30

    private let auroraAnimationKey = "pp.hero.apex.aurora"
    private let fieldDriftAnimationKey = "pp.hero.apex.field-drift"
    private let particleAnimationKey = "pp.hero.apex.particle"
    private let reactiveLightAnimationKey = "pp.hero.apex.reactive-light"
    private let accentBarTransitionKey = "pp.hero.apex.accent-bar-transition"
    private let accentGlowTransitionKey = "pp.hero.apex.accent-glow-transition"
    private let paletteTransitionKey = "pp.hero.apex.palette-transition"

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
        layer.shadowOpacity = 0

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

        auroraLayers.forEach { layer in
            layer.type = .radial
            layer.startPoint = CGPoint(x: 0.5, y: 0.5)
            layer.endPoint = CGPoint(x: 1, y: 1)
            layer.locations = [0, 0.42, 1]
            layer.drawsAsynchronously = true
            ambientContentView.layer.addSublayer(layer)
        }

        particleLayers.forEach { layer in
            layer.fillColor = UIColor.clear.cgColor
            layer.lineWidth = 0
            layer.contentsScale = UIScreen.main.scale
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
        touchLensView.alpha = 0

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
        innerStrokeLayer.contentsScale = UIScreen.main.scale
        overlayView.layer.addSublayer(innerStrokeLayer)
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

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        materialView.frame = bounds
        baseView.frame = materialView.contentView.bounds
        ambientView.frame = materialView.contentView.bounds
        ambientContentView.frame = ambientView.bounds
        overlayView.frame = materialView.contentView.bounds

        let materialBounds = baseView.bounds
        baseGradientLayer.frame = materialBounds
        depthGradientLayer.frame = materialBounds
        vignetteLayer.frame = materialBounds

        layoutAuroraLayers(in: ambientContentView.bounds)
        layoutParticleLayers(in: ambientContentView.bounds)
        layoutReactiveLight(in: overlayView.bounds)
        layoutAccentLayers(in: overlayView.bounds)
        updateCornerGeometry()

        CATransaction.commit()
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

        layer.shadowPath = nil
    }

    private func layoutAuroraLayers(in bounds: CGRect) {
        guard !bounds.isEmpty else { return }

        for (index, layer) in auroraLayers.enumerated() where index < auroraSpecs.count {
            let spec = auroraSpecs[index]
            let size = CGSize(
                width: max(bounds.width * spec.size.width, 180),
                height: max(bounds.height * spec.size.height, 150)
            )
            layer.bounds = CGRect(origin: .zero, size: size)
            layer.position = CGPoint(
                x: bounds.width * spec.center.x,
                y: bounds.height * spec.center.y
            )
            layer.cornerRadius = min(size.width, size.height) * 0.5
        }
    }

    private func layoutParticleLayers(in bounds: CGRect) {
        guard !bounds.isEmpty else { return }

        let displayScale = max(UIScreen.main.scale, 1)

        for (groupIndex, layer) in particleLayers.enumerated() {
            layer.frame = bounds
            let path = UIBezierPath()
            guard groupIndex < normalizedParticlePointGroups.count else {
                layer.path = path.cgPath
                continue
            }

            for (pointIndex, normalizedPoint) in
                normalizedParticlePointGroups[groupIndex].enumerated() {
                let x = (bounds.width * normalizedPoint.x * displayScale).rounded() / displayScale
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
        reactiveLightView.center = CGPoint(
            x: bounds.width * defaultReactiveLightCenter.x,
            y: bounds.height * defaultReactiveLightCenter.y
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
    }

    private func layoutAccentLayers(in bounds: CGRect) {
        guard !bounds.isEmpty else { return }

        let isRTL = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let barWidth: CGFloat = 44
        let barLeading: CGFloat = 38
        let barX = isRTL ? bounds.width - barLeading - barWidth : barLeading
        accentBarLayer.frame = CGRect(x: barX, y: 0, width: barWidth, height: 3)

        let glowDiameter = max(min(bounds.width * 0.74, 230), 168)
        accentGlowLayer.frame = CGRect(
            x: bounds.width - glowDiameter * 0.62,
            y: -glowDiameter * 0.30,
            width: glowDiameter,
            height: glowDiameter
        )
    }

    // MARK: - Palette

    public func reapplyPalette() {
        updatePalette(animated: false)
    }

    private func updatePalette(animated: Bool) {
        applyPalette(makePalette(), animated: animated)
    }

    private func applyPalette(_ palette: Palette, animated: Bool) {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled
        let animateColors = animated && shouldAnimateVisualStateChange

        if !animated {
            materialView.effect = reduceTransparency
                ? nil
                : UIBlurEffect(style: .systemUltraThinMaterial)
        }

        if !animateColors {
            removePaletteTransitionAnimations()
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        backgroundColor = .clear
        materialView.backgroundColor = .clear
        materialView.contentView.backgroundColor = .clear

        vignetteLayer.colors = [
            UIColor.white.withAlphaComponent(isDark ? 0.035 : 0.10).cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor
        ]

        layer.shadowOpacity = 0

        CATransaction.commit()
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        setGradientColors([
            palette.surfaceHighlight.cgColor,
            palette.surfaceMiddle.cgColor,
            palette.surfaceTail.cgColor
        ], on: baseGradientLayer, animated: animateColors)
        baseGradientLayer.startPoint = effectiveUserInterfaceLayoutDirection == .rightToLeft
            ? CGPoint(x: 1, y: 0)
            : CGPoint(x: 0, y: 0)
        baseGradientLayer.endPoint = effectiveUserInterfaceLayoutDirection == .rightToLeft
            ? CGPoint(x: 0, y: 1)
            : CGPoint(x: 1, y: 1)

        setGradientColors([
            UIColor.clear.cgColor,
            palette.depth.withAlphaComponent(isDark ? 0.055 : 0.018).cgColor,
            palette.depth.withAlphaComponent(isDark ? 0.16 : 0.055).cgColor
        ], on: depthGradientLayer, animated: animateColors)

        for (index, layer) in auroraLayers.enumerated() {
            let color = palette.aurora[index % palette.aurora.count]
            let restingOpacity = index < auroraSpecs.count
                ? auroraSpecs[index].opacityRange.upperBound
                : 1
            let leadingAlpha: CGFloat
            if storedAccentMode == .fullScreen {
                leadingAlpha = reduceTransparency
                    ? (isDark ? 0.24 : 0.18)
                    : (isDark ? 0.38 : 0.26)
            } else {
                leadingAlpha = reduceTransparency
                    ? (isDark ? 0.19 : 0.14)
                    : (isDark ? 0.28 : 0.19)
            }
            setGradientColors([
                color.withAlphaComponent(leadingAlpha).cgColor,
                color.withAlphaComponent(leadingAlpha * 0.32).cgColor,
                UIColor.clear.cgColor
            ], on: layer, animated: animateColors)
            layer.opacity = restingOpacity
        }

        for (index, layer) in particleLayers.enumerated() {
            let color = palette.particle[index % palette.particle.count]
            setLayerColor(
                color.cgColor,
                on: layer,
                keyPath: "fillColor",
                modelColor: layer.fillColor,
                animated: animateColors
            ) {
                layer.fillColor = color.cgColor
            }
            layer.opacity = isDark ? 0.31 : 0.24
            layer.shadowOpacity = 0
            layer.shadowRadius = 0
            layer.shadowOffset = .zero
        }

        setGradientColors([
            palette.reactiveLight.withAlphaComponent(isDark ? 0.20 : 0.27).cgColor,
            palette.reactiveLight.withAlphaComponent(isDark ? 0.06 : 0.08).cgColor,
            UIColor.clear.cgColor
        ], on: reactiveLightLayer, animated: animateColors)
        reactiveLightLayer.opacity = 0.84

        setGradientColors([
            palette.reactiveLight.withAlphaComponent(isDark ? 0.28 : 0.34).cgColor,
            palette.reactiveLight.withAlphaComponent(isDark ? 0.12 : 0.16).cgColor,
            palette.accent.withAlphaComponent(isDark ? 0.045 : 0.035).cgColor,
            UIColor.clear.cgColor
        ], on: touchLensLayer, animated: animateColors)
        setGradientColors([
            UIColor.white.withAlphaComponent(isDark ? 0.24 : 0.36).cgColor,
            palette.reactiveLight.withAlphaComponent(isDark ? 0.08 : 0.12).cgColor,
            UIColor.clear.cgColor
        ], on: touchCoreLayer, animated: animateColors)

        setGradientColors([
            palette.accent.withAlphaComponent(0.38).cgColor,
            palette.accent.withAlphaComponent(0.82).cgColor,
            palette.accent.withAlphaComponent(0.22).cgColor
        ], on: accentBarLayer, animated: animateColors)

        let glowStrength = storedCornerGlowOpacityMultiplier
        setGradientColors([
            palette.accent.withAlphaComponent((isDark ? 0.17 : 0.115) * glowStrength).cgColor,
            palette.accent.withAlphaComponent((isDark ? 0.055 : 0.034) * glowStrength).cgColor,
            UIColor.clear.cgColor
        ], on: accentGlowLayer, animated: animateColors)

        setLayerColor(
            palette.stroke.cgColor,
            on: innerStrokeLayer,
            keyPath: "strokeColor",
            modelColor: innerStrokeLayer.strokeColor,
            animated: animateColors
        ) {
            innerStrokeLayer.strokeColor = palette.stroke.cgColor
        }

        CATransaction.commit()
        applyAccentMode(animated: false)
        setNeedsLayout()
    }

    private func makePalette() -> Palette {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let strongerContrast = UIAccessibility.isDarkerSystemColorsEnabled
        let marketplaceAllAccent = resolvedColor(Self.marketplaceAllAccentColor())
        let explicitAccent = accentColorOverride.map { resolvedColor($0) }
        let usesMarketplaceAllPalette = explicitAccent.map {
            colorsApproximatelyMatch($0, marketplaceAllAccent)
        } ?? true
        let accent = explicitAccent ?? marketplaceAllAccent
        let surfaceBase = resolvedColor(Self.marketplaceAllSurfaceBaseColor(isDark: isDark))

        let highlight: UIColor
        let middle: UIColor
        let tail: UIColor
        let aurora: [UIColor]
        let particlePrimary: UIColor
        let particleSecondary: UIColor
        let reactiveLight: UIColor
        let depth: UIColor

        if usesMarketplaceAllPalette {
            let surfaceTint = blend(
                surfaceBase,
                with: accent,
                amount: isDark ? 0.11 : 0.045
            )
            let backgroundAccent = blend(
                accent,
                with: surfaceBase,
                amount: isDark ? 0.12 : 0.18
            )
            let shine = blend(
                accent,
                with: resolvedColor(Self.marketplaceAllShineColor()),
                amount: isDark ? 0.10 : 0.16
            )
            let supportGlow = blend(
                backgroundAccent,
                with: Self.marketplaceAllColor(0x00F5D4),
                amount: isDark ? 0.18 : 0.22
            )

            highlight = blend(
                surfaceBase,
                with: .white,
                amount: isDark ? 0.08 : 0.20
            )
            middle = surfaceTint
            tail = blend(
                surfaceTint,
                with: accent,
                amount: isDark ? 0.08 : 0.03
            )

            aurora = [accent, UIColor(named: "AppBage") ?? shine]
            particlePrimary = blend(shine, with: surfaceBase, amount: isDark ? 0.40 : 0.52)
            particleSecondary = blend(
                supportGlow,
                with: surfaceBase,
                amount: isDark ? 0.42 : 0.58
            )
            reactiveLight = supportGlow
            depth = backgroundAccent
        } else {
            let seaGlass = blend(accent, with: resolvedColor(.systemTeal), amount: 0.58)
            let twilight = blend(accent, with: resolvedColor(.systemIndigo), amount: 0.44)
            let warmLight = blend(accent, with: resolvedColor(.systemOrange), amount: 0.32)

            highlight = blend(
                surfaceBase,
                with: .white,
                amount: isDark ? 0.075 : 0.18
            )
            middle = blend(
                surfaceBase,
                with: accent,
                amount: isDark ? 0.068 : 0.026
            )
            tail = blend(
                middle,
                with: accent,
                amount: isDark ? 0.043 : 0.016
            )

            aurora = [warmLight, UIColor(named: "AppBage") ?? seaGlass]
            particlePrimary = blend(accent, with: .white, amount: isDark ? 0.66 : 0.52)
            particleSecondary = blend(
                seaGlass,
                with: .white,
                amount: isDark ? 0.62 : 0.68
            )
            reactiveLight = blend(accent, with: .white, amount: isDark ? 0.76 : 0.86)
            depth = blend(surfaceBase, with: accent, amount: isDark ? 0.12 : 0.045)
        }

        return Palette(
            accent: accent,
            surfaceHighlight: highlight,
            surfaceMiddle: middle,
            surfaceTail: tail,
            depth: depth,
            aurora: aurora,
            particle: [
                particlePrimary,
                particleSecondary,
                surfaceBase
            ],
            reactiveLight: reactiveLight,
            stroke: UIColor.white.withAlphaComponent(
                strongerContrast ? (isDark ? 0.24 : 0.92) : (isDark ? 0.12 : 0.78)
            )
        )
    }

    private func setGradientColors(
        _ colors: [CGColor],
        on layer: CAGradientLayer,
        animated: Bool
    ) {
        let sourceColors = layer.presentation()?.colors ?? layer.colors
        let targetColors = colors.map { $0 as Any }

        layer.removeAnimation(forKey: paletteTransitionKey)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.colors = targetColors
        CATransaction.commit()

        guard animated,
              let sourceColors,
              !gradientColorsMatch(sourceColors, targetColors) else {
            return
        }

        let transition = CABasicAnimation(keyPath: "colors")
        transition.fromValue = sourceColors
        transition.toValue = targetColors
        transition.duration = PPHeroApexMotionTokens.paletteTransitionDuration
        transition.timingFunction = PPHeroApexMotionTokens.paletteTimingFunction
        transition.isRemovedOnCompletion = true
        layer.add(transition, forKey: paletteTransitionKey)
    }

    private func setLayerColor(
        _ color: CGColor,
        on layer: CALayer,
        keyPath: String,
        modelColor: CGColor?,
        animated: Bool,
        updateModel: () -> Void
    ) {
        let sourceColor: Any?
        if let presentationColor = layer.presentation()?.value(forKeyPath: keyPath) {
            sourceColor = presentationColor
        } else {
            sourceColor = modelColor
        }

        layer.removeAnimation(forKey: paletteTransitionKey)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updateModel()
        CATransaction.commit()

        guard animated, let sourceColor else { return }
        if CFEqual(sourceColor as CFTypeRef, color) {
            return
        }

        let transition = CABasicAnimation(keyPath: keyPath)
        transition.fromValue = sourceColor
        transition.toValue = color
        transition.duration = PPHeroApexMotionTokens.paletteTransitionDuration
        transition.timingFunction = PPHeroApexMotionTokens.paletteTimingFunction
        transition.isRemovedOnCompletion = true
        layer.add(transition, forKey: paletteTransitionKey)
    }

    private func gradientColorsMatch(_ first: [Any], _ second: [Any]) -> Bool {
        guard first.count == second.count else { return false }
        return zip(first, second).allSatisfy { firstValue, secondValue in
            CFEqual(firstValue as CFTypeRef, secondValue as CFTypeRef)
        }
    }

    private func removePaletteTransitionAnimations() {
        baseGradientLayer.removeAnimation(forKey: paletteTransitionKey)
        depthGradientLayer.removeAnimation(forKey: paletteTransitionKey)
        auroraLayers.forEach { $0.removeAnimation(forKey: paletteTransitionKey) }
        particleLayers.forEach { $0.removeAnimation(forKey: paletteTransitionKey) }
        reactiveLightLayer.removeAnimation(forKey: paletteTransitionKey)
        touchLensLayer.removeAnimation(forKey: paletteTransitionKey)
        touchCoreLayer.removeAnimation(forKey: paletteTransitionKey)
        accentBarLayer.removeAnimation(forKey: paletteTransitionKey)
        accentGlowLayer.removeAnimation(forKey: paletteTransitionKey)
        innerStrokeLayer.removeAnimation(forKey: paletteTransitionKey)
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

        return UIColor(
            red: baseRed * (1 - t) + overlayRed * t,
            green: baseGreen * (1 - t) + overlayGreen * t,
            blue: baseBlue * (1 - t) + overlayBlue * t,
            alpha: baseAlpha * (1 - t) + overlayAlpha * t
        )
    }

    private func colorsApproximatelyMatch(_ first: UIColor, _ second: UIColor) -> Bool {
        let lhs = resolvedColor(first)
        let rhs = resolvedColor(second)

        var lhsRed: CGFloat = 0
        var lhsGreen: CGFloat = 0
        var lhsBlue: CGFloat = 0
        var lhsAlpha: CGFloat = 0
        var rhsRed: CGFloat = 0
        var rhsGreen: CGFloat = 0
        var rhsBlue: CGFloat = 0
        var rhsAlpha: CGFloat = 0

        guard lhs.getRed(&lhsRed, green: &lhsGreen, blue: &lhsBlue, alpha: &lhsAlpha),
              rhs.getRed(&rhsRed, green: &rhsGreen, blue: &rhsBlue, alpha: &rhsAlpha) else {
            return lhs.isEqual(rhs)
        }

        let tolerance: CGFloat = 0.003
        return abs(lhsRed - rhsRed) <= tolerance &&
            abs(lhsGreen - rhsGreen) <= tolerance &&
            abs(lhsBlue - rhsBlue) <= tolerance &&
            abs(lhsAlpha - rhsAlpha) <= tolerance
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
            hasValidGeometry: bounds.width > 1 && bounds.height > 1,
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
            installFieldDriftAnimation()
            installAuroraAnimations()
            installParticleAnimations()
            installLightAnimations()
            ambientTimelineInstalled = true
        }
        resumeAmbientTimeline()
    }

    private func installFieldDriftAnimation() {
        let drift = CAKeyframeAnimation(keyPath: "sublayerTransform")
        drift.values = [
            NSValue(caTransform3D: ambientTransform(x: -2.0, y: 1.4, scale: 1.002)),
            NSValue(caTransform3D: ambientTransform(x: 3.2, y: -2.1, scale: 1.008)),
            NSValue(caTransform3D: ambientTransform(x: -2.6, y: 2.4, scale: 1.004)),
            NSValue(caTransform3D: ambientTransform(x: -2.0, y: 1.4, scale: 1.002))
        ]
        drift.keyTimes = [0, 0.30, 0.68, 1]
        drift.calculationMode = .cubic
        drift.timingFunctions = Array(
            repeating: PPHeroApexMotionTokens.ambientTimingFunction,
            count: 3
        )

        let group = makeRepeatingAnimationGroup(
            animations: [drift],
            duration: PPHeroApexMotionTokens.fieldDriftCycleDuration,
            phase: 0.7
        )
        ambientContentView.layer.add(group, forKey: fieldDriftAnimationKey)
    }

    private func installAuroraAnimations() {
        for (index, layer) in auroraLayers.enumerated() where index < auroraSpecs.count {
            let spec = auroraSpecs[index]

            let transform: CAKeyframeAnimation
            let opacity: CAKeyframeAnimation

            if index == 2 {
                transform = CAKeyframeAnimation(keyPath: "transform")
                transform.values = [
                    NSValue(caTransform3D: ambientTransform(x: 0, y: 0, scale: 1.0)),
                    NSValue(caTransform3D: ambientTransform(
                        x: -spec.travel.width * 0.72,
                        y: spec.travel.height * 0.22,
                        scale: spec.scaleRange.lowerBound
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: spec.travel.width * 0.78,
                        y: -spec.travel.height * 0.28,
                        scale: spec.scaleRange.upperBound
                    )),
                    NSValue(caTransform3D: ambientTransform(x: 0, y: 0, scale: 1.0)),
                    NSValue(caTransform3D: ambientTransform(x: 0, y: 0, scale: 1.0)),
                    NSValue(caTransform3D: ambientTransform(x: 0, y: 0, scale: 1.0))
                ]
                transform.keyTimes = [0, 0.22, 0.48, 0.68, 0.82, 1.0]
                transform.calculationMode = .cubic
                transform.timingFunctions = [
                    PPHeroApexMotionTokens.ambientTimingFunction,
                    PPHeroApexMotionTokens.ambientTimingFunction,
                    PPHeroApexMotionTokens.ambientTimingFunction,
                    CAMediaTimingFunction(name: .easeOut),
                    CAMediaTimingFunction(name: .linear)
                ]

                let lowOpacity = spec.opacityRange.lowerBound
                let midOpacity = lowOpacity + (spec.opacityRange.upperBound - lowOpacity) * 0.55
                opacity = CAKeyframeAnimation(keyPath: "opacity")
                opacity.values = [lowOpacity, midOpacity, midOpacity, lowOpacity, lowOpacity, lowOpacity]
                opacity.keyTimes = [0, 0.22, 0.48, 0.68, 0.82, 1.0]
                opacity.calculationMode = .cubic
                opacity.timingFunctions = [
                    PPHeroApexMotionTokens.ambientTimingFunction,
                    PPHeroApexMotionTokens.ambientTimingFunction,
                    CAMediaTimingFunction(name: .easeOut),
                    CAMediaTimingFunction(name: .linear),
                    CAMediaTimingFunction(name: .linear)
                ]
            } else {
                transform = CAKeyframeAnimation(keyPath: "transform")
                transform.values = [
                    NSValue(caTransform3D: ambientTransform(
                        x: -spec.travel.width * 0.18,
                        y: spec.travel.height * 0.12,
                        scale: spec.scaleRange.lowerBound
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: spec.travel.width,
                        y: -spec.travel.height * 0.46,
                        scale: spec.scaleRange.upperBound
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: -spec.travel.width * 0.54,
                        y: spec.travel.height,
                        scale: 0.992
                    )),
                    NSValue(caTransform3D: ambientTransform(
                        x: -spec.travel.width * 0.18,
                        y: spec.travel.height * 0.12,
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

    private func installParticleAnimations() {
        for (index, layer) in particleLayers.enumerated() {
            let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let travelX = direction * (2.1 + CGFloat(index) * 0.7)
            let travelY = 1.8 + CGFloat(index) * 0.55

            let transform = CAKeyframeAnimation(keyPath: "transform")
            transform.values = [
                NSValue(caTransform3D: ambientTransform(x: 0, y: 0, scale: 1)),
                NSValue(caTransform3D: ambientTransform(
                    x: travelX,
                    y: -travelY,
                    scale: 1.012
                )),
                NSValue(caTransform3D: ambientTransform(
                    x: -travelX * 0.62,
                    y: travelY,
                    scale: 0.994
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
                baseOpacity * 0.74,
                min(baseOpacity + 0.045, 0.32),
                baseOpacity * 0.84,
                baseOpacity * 0.74
            ]
            opacity.keyTimes = [0, 0.36, 0.74, 1]
            opacity.calculationMode = .cubic
            opacity.timingFunctions = Array(
                repeating: PPHeroApexMotionTokens.ambientTimingFunction,
                count: 3
            )

            let duration = 19 + CFTimeInterval(index) * 6.4
            let group = makeRepeatingAnimationGroup(
                animations: [transform, opacity],
                duration: duration,
                phase: 4.7 + CFTimeInterval(index) * 7.1
            )
            layer.add(group, forKey: particleAnimationKey)
        }
    }

    private func installLightAnimations() {
        let reactiveBreath = CAKeyframeAnimation(keyPath: "opacity")
        reactiveBreath.values = [0.72, 0.94, 0.80, 0.72]
        reactiveBreath.keyTimes = [0, 0.38, 0.74, 1]
        reactiveBreath.calculationMode = .cubic
        reactiveBreath.timingFunctions = Array(
            repeating: PPHeroApexMotionTokens.ambientTimingFunction,
            count: 3
        )

        let reactiveTravel = CAKeyframeAnimation(keyPath: "transform")
        reactiveTravel.values = [
            NSValue(caTransform3D: ambientTransform(x: -4.0, y: 2.0, scale: 0.992)),
            NSValue(caTransform3D: ambientTransform(x: 6.0, y: -3.2, scale: 1.018)),
            NSValue(caTransform3D: ambientTransform(x: -4.8, y: 3.8, scale: 1.006)),
            NSValue(caTransform3D: ambientTransform(x: -4.0, y: 2.0, scale: 0.992))
        ]
        reactiveTravel.keyTimes = [0, 0.38, 0.74, 1]
        reactiveTravel.calculationMode = .cubic
        reactiveTravel.timingFunctions = Array(
            repeating: PPHeroApexMotionTokens.ambientTimingFunction,
            count: 3
        )

        let reactiveGroup = makeRepeatingAnimationGroup(
            animations: [reactiveBreath, reactiveTravel],
            duration: 13.4,
            phase: 3.2
        )
        reactiveLightLayer.add(reactiveGroup, forKey: reactiveLightAnimationKey)
    }

    private func makeRepeatingAnimationGroup(
        animations: [CAAnimation],
        duration: CFTimeInterval,
        phase: CFTimeInterval
    ) -> CAAnimationGroup {
        // CAAnimationGroup does not propagate its duration to child animations.
        animations.forEach { animation in
            animation.beginTime = 0
            animation.duration = duration
        }

        let group = CAAnimationGroup()
        group.animations = animations
        group.duration = duration
        group.timeOffset = max(phase, 0).truncatingRemainder(dividingBy: duration)
        group.repeatCount = .greatestFiniteMagnitude
        group.isRemovedOnCompletion = true
        return group
    }

    private func removeAmbientTimeline() {
        resetTimelineLayerTiming(ambientContentView.layer)
        resetTimelineLayerTiming(overlayView.layer)

        ambientContentView.layer.removeAnimation(forKey: fieldDriftAnimationKey)
        auroraLayers.forEach { $0.removeAnimation(forKey: auroraAnimationKey) }
        particleLayers.forEach { $0.removeAnimation(forKey: particleAnimationKey) }
        reactiveLightLayer.removeAnimation(forKey: reactiveLightAnimationKey)

        ambientTimelineInstalled = false
        ambientTimelinePaused = false
    }

    private func pauseAmbientTimeline() {
        guard ambientTimelineInstalled, !ambientTimelinePaused else { return }
        pauseTimelineLayer(ambientContentView.layer)
        pauseTimelineLayer(overlayView.layer)
        ambientTimelinePaused = true
    }

    private func resumeAmbientTimeline() {
        guard ambientTimelineInstalled, ambientTimelinePaused else { return }
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

    private func ambientTransform(x: CGFloat, y: CGFloat, scale: CGFloat) -> CATransform3D {
        var transform = CATransform3DIdentity
        transform = CATransform3DTranslate(transform, x, y, 0)
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
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        var candidate = superview
        while let current = candidate, !current.isUserInteractionEnabled {
            candidate = current.superview
        }

        guard let host = candidate, host.window != nil else { return }

        if touchHost !== host {
            detachTouchTracker()
        }
        guard touchRecognizer == nil else { return }

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
        touchHost = host
        touchRecognizer = recognizer
    }

    private func detachTouchTracker() {
        if let touchRecognizer {
            touchRecognizer.onUpdate = nil
            touchRecognizer.onTrackingCancelled = nil
            touchHost?.removeGestureRecognizer(touchRecognizer)
        }
        touchRecognizer = nil
        touchHost = nil
        touchResponseActive = false
        previousTouchPoint = nil
        previousTouchTimestamp = nil
        touchVelocity = .zero
    }

    private func cancelActiveTouchResponse() {
        guard touchResponseActive else { return }
        touchResponseActive = false
        previousTouchPoint = nil
        previousTouchTimestamp = nil
        touchVelocity = .zero
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
            sendMotionEvent(.interactionBegan)
            guard motionStateMachine.state == .interactive else { return }
            touchResponseActive = true
            previousTouchPoint = localPoint
            previousTouchTimestamp = timestamp
            touchVelocity = .zero
            applyReactiveDepth(at: localPoint)

        case .changed:
            guard touchResponseActive else { return }
            updateTouchKinetics(at: localPoint, timestamp: timestamp)
            applyReactiveDepth(at: localPoint)

        case .ended, .cancelled, .failed:
            guard touchResponseActive else { return }
            updateTouchKinetics(at: localPoint, timestamp: timestamp)
            touchResponseActive = false
            previousTouchPoint = nil
            previousTouchTimestamp = nil
            sendMotionEvent(.interactionEnded)

        default:
            break
        }
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

    private func applyReactiveDepth(at localPoint: CGPoint) {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let normalized = CGPoint(
            x: min(max(localPoint.x / bounds.width, 0), 1),
            y: min(max(localPoint.y / bounds.height, 0), 1)
        )
        let centeredX = normalized.x - 0.5
        let centeredY = normalized.y - 0.5

        var depthTransform = CATransform3DIdentity
        depthTransform.m34 = -1 / 1100
        depthTransform = CATransform3DScale(
            depthTransform,
            PPHeroApexMotionTokens.touchDepthScale,
            PPHeroApexMotionTokens.touchDepthScale,
            1
        )
        depthTransform = CATransform3DTranslate(
            depthTransform,
            centeredX * PPHeroApexMotionTokens.maximumTouchTranslationX * 2,
            centeredY * PPHeroApexMotionTokens.maximumTouchTranslationY * 2,
            0
        )
        depthTransform = CATransform3DRotate(
            depthTransform,
            centeredY * PPHeroApexMotionTokens.maximumTouchRotation * 2,
            1,
            0,
            0
        )
        depthTransform = CATransform3DRotate(
            depthTransform,
            -centeredX * PPHeroApexMotionTokens.maximumTouchRotation * 2,
            0,
            1,
            0
        )

        let lightTranslation = CGAffineTransform(
            translationX: (normalized.x - defaultReactiveLightCenter.x)
                * bounds.width
                * PPHeroApexMotionTokens.reactiveLightTravelRatio,
            y: (normalized.y - defaultReactiveLightCenter.y)
                * bounds.height
                * PPHeroApexMotionTokens.reactiveLightTravelRatio
        ).scaledBy(
            x: PPHeroApexMotionTokens.touchLightScale,
            y: PPHeroApexMotionTokens.touchLightScale
        )

        let defaultLightCenter = CGPoint(
            x: bounds.width * defaultReactiveLightCenter.x,
            y: bounds.height * defaultReactiveLightCenter.y
        )
        let touchSpeed = hypot(touchVelocity.dx, touchVelocity.dy)
        let velocityBloom = min(
            touchSpeed / PPHeroApexMotionTokens.touchVelocityForMaximumBloom,
            1
        )
        let lensScale = PPHeroApexMotionTokens.touchLensBaseScale
            + velocityBloom * PPHeroApexMotionTokens.touchLensVelocityBloom
        let lensTranslation = CGAffineTransform(
            translationX: localPoint.x - defaultLightCenter.x,
            y: localPoint.y - defaultLightCenter.y
        ).scaledBy(x: lensScale, y: lensScale)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ambientView.layer.transform = depthTransform
        CATransaction.commit()
        UIView.performWithoutAnimation {
            reactiveLightView.transform = lightTranslation
            touchLensView.transform = lensTranslation
            touchLensView.alpha = PPHeroApexMotionTokens.touchLensActiveAlpha
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
        previousTouchPoint = nil
        previousTouchTimestamp = nil
        touchVelocity = .zero
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
        guard motionStateMachine.state == .ambient ||
                motionStateMachine.state == .settling else {
            return false
        }
        let localPoint = touch.location(in: self)
        return bounds.insetBy(dx: -4, dy: -4).contains(localPoint)
    }

    // MARK: - Accent continuity

    private var shouldAnimateVisualStateChange: Bool {
        guard window != nil,
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
        reactiveLightLayer.opacity = reduced ? 0.70 : 0.78
        CATransaction.commit()

        applyAccentMode(animated: false)
    }

    private func restoreFullMotionModelState() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        reactiveLightLayer.opacity = 0.84
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

        if previousTraitCollection == nil ||
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

    private var auroraSpecs: [AuroraSpec] {
        [
            AuroraSpec(
                center: CGPoint(x: 0.90, y: -0.02),
                size: CGSize(width: 0.92, height: 1.42),
                travel: CGSize(width: 7.5, height: 5.0),
                scaleRange: 0.992...1.036,
                opacityRange: 0.78...1,
                duration: 29,
                phase: 7.4
            ),
            AuroraSpec(
                center: CGPoint(x: 0.12, y: 0.90),
                size: CGSize(width: 0.86, height: 1.28),
                travel: CGSize(width: 6.5, height: 5.8),
                scaleRange: 0.988...1.030,
                opacityRange: 0.76...0.96,
                duration: 37,
                phase: 13.2
            ),

        ]
    }

    private var normalizedParticlePointGroups: [[CGPoint]] {
        [
            [
                CGPoint(x: 0.08, y: 0.31),
                CGPoint(x: 0.23, y: 0.72),
                CGPoint(x: 0.47, y: 0.17),
                CGPoint(x: 0.71, y: 0.58),
                CGPoint(x: 0.91, y: 0.27)
            ],
            [
                CGPoint(x: 0.14, y: 0.84),
                CGPoint(x: 0.34, y: 0.43),
                CGPoint(x: 0.58, y: 0.81),
                CGPoint(x: 0.77, y: 0.22),
                CGPoint(x: 0.86, y: 0.68)
            ],
            [
                CGPoint(x: 0.05, y: 0.57),
                CGPoint(x: 0.29, y: 0.12),
                CGPoint(x: 0.53, y: 0.52),
                CGPoint(x: 0.67, y: 0.91),
                CGPoint(x: 0.96, y: 0.48)
            ]
        ]
    }
}
*/
