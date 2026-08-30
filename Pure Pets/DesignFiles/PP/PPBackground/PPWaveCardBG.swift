//
//  PPWaveCardBG.swift
//  Pure Pets
//
//  Reusable background-only Living Care Pulse material shared by premium surfaces.
//

import SwiftUI
import UIKit

@objc public enum PPWaveCardBGShape: Int {
    case rounded = 0
    case capsule = 1
    case circle = 2
}

private struct PPWaveCardInteractionSnapshot {
    var point = CGPoint(x: 0.5, y: 0.5)
    var velocity = CGVector.zero
    var pressure: CGFloat = 0.0
    var isActive = false

    static let idle = PPWaveCardInteractionSnapshot()
}

private final class PPWaveCardInteractionModel: ObservableObject {
    @Published private(set) var snapshot = PPWaveCardInteractionSnapshot.idle

    private var pendingSnapshot: PPWaveCardInteractionSnapshot?
    private var publishesOnNextRunLoop = false
    private var previousPoint: CGPoint?
    private var previousTimestamp: TimeInterval?
    private var smoothedVelocity = CGVector.zero

    func stage(
        point: CGPoint,
        pressure: CGFloat,
        timestamp: TimeInterval,
        isActive: Bool
    ) {
        let safePoint = CGPoint(
            x: point.x.isFinite ? min(max(point.x, 0.0), 1.0) : 0.5,
            y: point.y.isFinite ? min(max(point.y, 0.0), 1.0) : 0.5
        )

        if isActive,
           let previousPoint,
           let previousTimestamp,
           timestamp > previousTimestamp {
            let interval = max(1.0 / 240.0, timestamp - previousTimestamp)
            let measured = CGVector(
                dx: (safePoint.x - previousPoint.x) / interval,
                dy: (safePoint.y - previousPoint.y) / interval
            )
            smoothedVelocity = CGVector(
                dx: (smoothedVelocity.dx * 0.68) + (measured.dx * 0.32),
                dy: (smoothedVelocity.dy * 0.68) + (measured.dy * 0.32)
            )
        } else if !isActive {
            smoothedVelocity = CGVector(
                dx: smoothedVelocity.dx * 0.30,
                dy: smoothedVelocity.dy * 0.30
            )
        }

        previousPoint = isActive ? safePoint : nil
        previousTimestamp = isActive ? timestamp : nil
        pendingSnapshot = PPWaveCardInteractionSnapshot(
            point: safePoint,
            velocity: smoothedVelocity,
            pressure: isActive && pressure.isFinite
                ? min(max(pressure, 0.0), 1.0)
                : 0.0,
            isActive: isActive
        )
        schedulePublication()
    }

    func reset() {
        previousPoint = nil
        previousTimestamp = nil
        smoothedVelocity = .zero
        pendingSnapshot = .idle
        schedulePublication()
    }

    private func schedulePublication() {
        guard !publishesOnNextRunLoop else { return }
        publishesOnNextRunLoop = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.publishesOnNextRunLoop = false
            guard let pendingSnapshot = self.pendingSnapshot else { return }
            self.pendingSnapshot = nil
            self.snapshot = pendingSnapshot
        }
    }
}

@available(iOS 15.0, *)
public struct PPWaveCardBG: View {
    public var animationEnabled: Bool
    public var shape: PPWaveCardBGShape
    public var cornerRadius: CGFloat
    public var accentColorOverride: UIColor?
    public var borderWidth: CGFloat

    private let interaction: PPWaveCardInteractionSnapshot
    private let sceneActivityOverride: Bool?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    public init(
        animationEnabled: Bool = true,
        shape: PPWaveCardBGShape = .rounded,
        cornerRadius: CGFloat = 28.0,
        accentColorOverride: UIColor? = nil,
        borderWidth: CGFloat = 0.125
    ) {
        self.animationEnabled = animationEnabled
        self.shape = shape
        self.cornerRadius = cornerRadius
        self.accentColorOverride = accentColorOverride
        self.borderWidth = borderWidth
        interaction = .idle
        sceneActivityOverride = nil
    }

    fileprivate init(
        animationEnabled: Bool,
        shape: PPWaveCardBGShape,
        cornerRadius: CGFloat,
        accentColorOverride: UIColor?,
        borderWidth: CGFloat,
        interaction: PPWaveCardInteractionSnapshot,
        sceneActivityOverride: Bool?
    ) {
        self.animationEnabled = animationEnabled
        self.shape = shape
        self.cornerRadius = cornerRadius
        self.accentColorOverride = accentColorOverride
        self.borderWidth = borderWidth
        self.interaction = interaction
        self.sceneActivityOverride = sceneActivityOverride
    }

    public var body: some View {
        switch shape {
        case .capsule:
            renderedSurface(in: Capsule())
        case .circle:
            renderedSurface(in: Circle())
        case .rounded:
            renderedSurface(
                in: RoundedRectangle(
                    cornerRadius: resolvedCornerRadius,
                    style: .continuous
                )
            )
        }
    }

    @ViewBuilder
    private func renderedSurface<S: InsettableShape>(in cardShape: S) -> some View {
        ZStack {
            cardShape.fill(surfaceFoundation)

            if !reduceTransparency {
                cardShape
                    .fill(.ultraThinMaterial)
                    .opacity(materialOpacity)
            }

            cardShape.fill(surfaceLight)
        }
        .clipShape(cardShape)
        .overlay {
            cardShape.strokeBorder(
                borderColor,
                lineWidth: resolvedStrokeWidth
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var surfaceFoundation: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    .ppSurface,
                    .ppSurfaceRaised,
                    .ppSecondarySurface,
                ]
                : [
                    .ppElevatedSurface,
                    .ppSurface,
                    .ppWarmPorcelain,
                ],
            startPoint: layoutDirection == .rightToLeft
                ? .topTrailing
                : .topLeading,
            endPoint: layoutDirection == .rightToLeft
                ? .bottomLeading
                : .bottomTrailing
        )
    }

    private var surfaceLight: LinearGradient {
        LinearGradient(
            stops: [
                .init(
                    color: Color.white.opacity(
                        reduceTransparency ? 0.0 : (colorScheme == .dark ? 0.055 : 0.20)
                    ),
                    location: 0.0
                ),
                .init(color: .clear, location: 0.36),
                .init(
                    color: Color.ppSoftRose.opacity(
                        colorScheme == .dark ? 0.050 : 0.085
                    ),
                    location: 0.72
                ),
                .init(
                    color: resolvedAccent.opacity(
                        colorScheme == .dark ? 0.070 : 0.055
                    ),
                    location: 1.0
                ),
            ],
            startPoint: layoutDirection == .rightToLeft
                ? .topTrailing
                : .topLeading,
            endPoint: layoutDirection == .rightToLeft
                ? .bottomLeading
                : .bottomTrailing
        )
    }

    private var materialOpacity: Double {
        colorScheme == .dark ? 0.34 : 0.22
    }

    private var allowsAmbientMotion: Bool {
        animationEnabled
            && !reduceMotion
            && isSceneActive
    }

    private var allowsInteractiveResponse: Bool {
        animationEnabled
            && !reduceMotion
            && contrast != .increased
            && isSceneActive
    }

    private var isSceneActive: Bool {
        sceneActivityOverride ?? (scenePhase == .active)
    }

    private var resolvedAccent: Color {
        guard let accentColorOverride else {
            return .ppCareAccent
        }
        return Color(uiColor: accentColorOverride)
    }

    private var resolvedCornerRadius: CGFloat {
        guard cornerRadius.isFinite else { return 28.0 }
        return max(0.0, cornerRadius)
    }

    private var resolvedBorderWidth: CGFloat {
        guard borderWidth.isFinite else { return 0.125 }
        return max(0.0, borderWidth)
    }

    private var resolvedStrokeWidth: CGFloat {
        guard resolvedBorderWidth > 0.0 else { return 0.0 }
        if contrast == .increased {
            return max(1.5, resolvedBorderWidth)
        }
        return resolvedBorderWidth
    }

    private var borderColor: Color {
        if contrast == .increased {
            return Color.ppTextPrimary.opacity(0.58)
        }
        if colorScheme == .dark {
            return Color.ppSurfaceBorder.opacity(0.86)
        }
        return Color.ppSurfaceBorder.opacity(0.78)
    }
}

private final class PPWaveCardPassiveGestureRecognizer: UIGestureRecognizer {
    var onSample: ((UIView, CGPoint, CGFloat, TimeInterval, Bool) -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let view else {
            state = .failed
            return
        }
        state = .began
        emit(touch: touch, in: view, active: true)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let view else { return }
        state = .changed
        emit(touch: touch, in: view, active: true)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first, let view {
            emit(touch: touch, in: view, active: false)
        }
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first, let view {
            emit(touch: touch, in: view, active: false)
        }
        state = .cancelled
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    private func emit(touch: UITouch, in view: UIView, active: Bool) {
        let normalizedPressure: CGFloat
        if touch.maximumPossibleForce > 0.0 {
            normalizedPressure = min(max(touch.force / touch.maximumPossibleForce, 0.0), 1.0)
        } else {
            normalizedPressure = active ? 0.72 : 0.0
        }
        onSample?(
            view,
            touch.location(in: view),
            active ? normalizedPressure : 0.0,
            touch.timestamp,
            active
        )
    }
}

private final class PPWaveCardContainerView: UIView {
    var windowStateDidChange: ((Bool) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        windowStateDidChange?(window != nil)
    }
}

@available(iOS 15.0, *)
private struct PPWaveCardBGRootView: View {
    let animationEnabled: Bool
    let sceneIsActive: Bool
    let shape: PPWaveCardBGShape
    let cornerRadius: CGFloat
    let accentColorOverride: UIColor?
    let borderWidth: CGFloat
    @ObservedObject var interactionModel: PPWaveCardInteractionModel

    @State private var isRightToLeft = Language.isRTL()

    var body: some View {
        PPWaveCardBG(
            animationEnabled: animationEnabled,
            shape: shape,
            cornerRadius: cornerRadius,
            accentColorOverride: accentColorOverride,
            borderWidth: borderWidth,
            interaction: interactionModel.snapshot,
            sceneActivityOverride: sceneIsActive
        )
        .environment(
            \.layoutDirection,
            isRightToLeft ? .rightToLeft : .leftToRight
        )
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("LanguageDidChangeNotification")
            )
        ) { _ in
            isRightToLeft = Language.isRTL()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("PPLanguageDidChangeNotification")
            )
        ) { _ in
            isRightToLeft = Language.isRTL()
        }
    }
}

@available(iOS 15.0, *)
@MainActor
@objc(PPWaveCardBGHostingController)
public final class PPWaveCardBGHostingController: UIViewController,
    UIGestureRecognizerDelegate {
    private let interactionModel = PPWaveCardInteractionModel()
    private var hostingController: UIHostingController<PPWaveCardBGRootView>!
    private weak var trackingView: UIView?
    private var trackingRecognizer: PPWaveCardPassiveGestureRecognizer?
    private var isVisible = false
    private var isSceneActive = false

    @objc public var animationEnabled: Bool {
        didSet {
            guard animationEnabled != oldValue else { return }
            updateRootView()
            updatePassiveTracking()
        }
    }

    @objc public var shape: PPWaveCardBGShape {
        didSet {
            guard shape != oldValue else { return }
            updateRootView()
        }
    }

    @objc public var cornerRadius: CGFloat {
        didSet {
            guard cornerRadius != oldValue else { return }
            updateRootView()
        }
    }

    @objc public var accentColorOverride: UIColor? {
        didSet {
            updateRootView()
        }
    }

    @objc public var borderWidth: CGFloat {
        didSet {
            guard borderWidth != oldValue else { return }
            updateRootView()
        }
    }

    @objc public init(
        animationEnabled: Bool,
        shape: PPWaveCardBGShape,
        cornerRadius: CGFloat,
        accentColorOverride: UIColor?
    ) {
        self.animationEnabled = animationEnabled
        self.shape = shape
        self.cornerRadius = cornerRadius
        self.accentColorOverride = accentColorOverride
        borderWidth = 0.75
        super.init(nibName: nil, bundle: nil)
        hostingController = UIHostingController(
            rootView: PPWaveCardBGRootView(
                animationEnabled: false,
                sceneIsActive: isSceneActive,
                shape: shape,
                cornerRadius: cornerRadius,
                accentColorOverride: accentColorOverride,
                borderWidth: borderWidth,
                interactionModel: interactionModel
            )
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PPWaveCardBGHostingController must be created programmatically.")
    }

    public override func loadView() {
        let container = PPWaveCardContainerView()
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = false
        container.windowStateDidChange = { [weak self] isAttached in
            self?.setVisible(isAttached)
        }
        view = container
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityInteractionModeDidChange),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneActivityDidChange(_:)),
            name: UIScene.didActivateNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneActivityDidChange(_:)),
            name: UIScene.willDeactivateNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityInteractionModeDidChange),
            name: UIAccessibility.switchControlStatusDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityInteractionModeDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityInteractionModeDidChange),
            name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil
        )

        addChild(hostingController)
        let hostedView = hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        hostedView.backgroundColor = .clear
        hostedView.isUserInteractionEnabled = false
        view.addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: view.topAnchor),
            hostedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostedView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingController.didMove(toParent: self)
    }

    public override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        guard parent != nil else {
            setVisible(false)
            detachPassiveTracking()
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.setVisible(self.viewIfLoaded?.window != nil)
            self.updatePassiveTracking()
        }
    }

    public override func willMove(toParent parent: UIViewController?) {
        if parent == nil {
            setVisible(false)
            detachPassiveTracking()
        }
        super.willMove(toParent: parent)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setVisible(true)
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        setVisible(false)
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    private func setVisible(_ visible: Bool) {
        let sceneIsActiveNow = currentSceneIsActive
        let activityDidChange = isSceneActive != sceneIsActiveNow
        isSceneActive = sceneIsActiveNow

        guard isVisible != visible || activityDidChange else {
            if visible { updatePassiveTracking() }
            return
        }
        isVisible = visible
        if !visible || !sceneIsActiveNow {
            interactionModel.reset()
        }
        updateRootView()
        updatePassiveTracking()
    }

    private var currentSceneIsActive: Bool {
        guard let windowScene = viewIfLoaded?.window?.windowScene else {
            return false
        }
        return windowScene.activationState == .foregroundActive
    }

    @objc private func accessibilityInteractionModeDidChange() {
        updatePassiveTracking()
    }

    @objc private func sceneActivityDidChange(_ notification: Notification) {
        guard let observedScene = notification.object as? UIWindowScene,
              let windowScene = viewIfLoaded?.window?.windowScene,
              observedScene === windowScene
        else { return }

        let sceneIsActiveNow = notification.name == UIScene.didActivateNotification
        guard isSceneActive != sceneIsActiveNow else { return }
        isSceneActive = sceneIsActiveNow
        if !sceneIsActiveNow {
            interactionModel.reset()
        }
        updateRootView()
        updatePassiveTracking()
    }

    private func updatePassiveTracking() {
        guard animationEnabled,
              isVisible,
              isSceneActive,
              !UIAccessibility.isReduceMotionEnabled,
              !UIAccessibility.isDarkerSystemColorsEnabled,
              !UIAccessibility.isVoiceOverRunning,
              !UIAccessibility.isSwitchControlRunning,
              let ownerView = viewIfLoaded?.superview
        else {
            detachPassiveTracking()
            return
        }

        if trackingView === ownerView, trackingRecognizer != nil {
            return
        }
        detachPassiveTracking()

        let recognizer = PPWaveCardPassiveGestureRecognizer()
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.requiresExclusiveTouchType = false
        recognizer.delegate = self
        recognizer.onSample = { [weak self] sourceView, point, pressure, timestamp, active in
            self?.publishInteraction(
                point,
                from: sourceView,
                pressure: pressure,
                timestamp: timestamp,
                active: active
            )
        }
        guard !UIAccessibility.isReduceMotionEnabled,
              !UIAccessibility.isDarkerSystemColorsEnabled,
              !UIAccessibility.isVoiceOverRunning,
              !UIAccessibility.isSwitchControlRunning
        else { return }
        ownerView.addGestureRecognizer(recognizer)
        trackingView = ownerView
        trackingRecognizer = recognizer
    }

    private func detachPassiveTracking() {
        if let trackingRecognizer {
            trackingView?.removeGestureRecognizer(trackingRecognizer)
            trackingRecognizer.onSample = nil
        }
        trackingRecognizer = nil
        trackingView = nil
        interactionModel.reset()
    }

    private func publishInteraction(
        _ point: CGPoint,
        from sourceView: UIView,
        pressure: CGFloat,
        timestamp: TimeInterval,
        active: Bool
    ) {
        guard isVisible,
              animationEnabled,
              isSceneActive,
              let hostedView = viewIfLoaded,
              hostedView.bounds.width > 1.0,
              hostedView.bounds.height > 1.0
        else {
            interactionModel.reset()
            return
        }

        let localPoint = sourceView.convert(point, to: hostedView)
        let normalizedPoint = CGPoint(
            x: (localPoint.x - hostedView.bounds.minX) / hostedView.bounds.width,
            y: (localPoint.y - hostedView.bounds.minY) / hostedView.bounds.height
        )
        interactionModel.stage(
            point: normalizedPoint,
            pressure: pressure,
            timestamp: timestamp,
            isActive: active
        )
    }

    private func updateRootView() {
        guard hostingController != nil else { return }
        hostingController.rootView = PPWaveCardBGRootView(
            animationEnabled: animationEnabled && isVisible && isSceneActive,
            sceneIsActive: isSceneActive,
            shape: shape,
            cornerRadius: cornerRadius,
            accentColorOverride: accentColorOverride,
            borderWidth: borderWidth,
            interactionModel: interactionModel
        )
    }
}
