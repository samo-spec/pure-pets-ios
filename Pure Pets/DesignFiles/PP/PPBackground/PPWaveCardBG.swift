//
//  PPWaveCardBG.swift
//  Pure Pets
//
//  Reusable background-only living material shared by premium UIKit surfaces.
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
    }

    fileprivate init(
        animationEnabled: Bool,
        shape: PPWaveCardBGShape,
        cornerRadius: CGFloat,
        accentColorOverride: UIColor?,
        borderWidth: CGFloat,
        interaction: PPWaveCardInteractionSnapshot
    ) {
        self.animationEnabled = animationEnabled
        self.shape = shape
        self.cornerRadius = cornerRadius
        self.accentColorOverride = accentColorOverride
        self.borderWidth = borderWidth
        self.interaction = interaction
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
            cardShape.fill(baseMaterial)

            cardShape.fill(
                Color.ppSurfaceRaised.opacity(
                    reduceTransparency
                        ? 1.0
                        : (colorScheme == .dark ? 0.72 : 0.58)
                )
            )

            PPWaveCardLivingField(
                accent: resolvedAccent,
                interaction: interaction,
                allowsAmbientMotion: allowsAmbientMotion,
                allowsInteractiveResponse: allowsInteractiveResponse,
                isRightToLeft: layoutDirection == .rightToLeft,
                isDark: colorScheme == .dark,
                increasedContrast: contrast == .increased,
                reduceMotion: reduceMotion,
                reduceTransparency: reduceTransparency
            )
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

    private var baseMaterial: AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(Color.ppSurfaceRaised)
        }
        return AnyShapeStyle(.thinMaterial)
    }

    private var allowsAmbientMotion: Bool {
        animationEnabled
            && !reduceMotion
            && contrast != .increased
            && scenePhase == .active
    }

    private var allowsInteractiveResponse: Bool {
        animationEnabled && scenePhase == .active
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
        return Color.white.opacity(0.88)
    }
}

@available(iOS 15.0, *)
private struct PPWaveCardLivingField: View {
    let accent: Color
    let interaction: PPWaveCardInteractionSnapshot
    let allowsAmbientMotion: Bool
    let allowsInteractiveResponse: Bool
    let isRightToLeft: Bool
    let isDark: Bool
    let increasedContrast: Bool
    let reduceMotion: Bool
    let reduceTransparency: Bool

    @State private var interactionStrength: CGFloat = 0.0
    @State private var wakeAmount: CGFloat = 0.0

    var body: some View {
        GeometryReader { proxy in
            Canvas(rendersAsynchronously: true) { context, size in
                renderField(in: &context, size: size)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .opacity(increasedContrast ? 0.48 : 1.0)
        .onAppear {
            updateInteractionStrength(animated: false)
        }
        .onChange(of: interaction.isActive) { _ in
            updateInteractionStrength(animated: true)
        }
        .onChange(of: allowsInteractiveResponse) { _ in
            updateInteractionStrength(animated: false)
        }
        .onChange(of: reduceMotion) { _ in
            updateInteractionStrength(animated: false)
        }
        .task(id: allowsAmbientMotion) {
            await runBoundedWakeMotion()
        }
    }

    @MainActor
    private func updateInteractionStrength(animated: Bool) {
        let target: CGFloat = allowsInteractiveResponse && interaction.isActive
            ? (reduceMotion ? 0.46 : 1.0)
            : 0.0

        guard animated && !reduceMotion else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                interactionStrength = target
            }
            return
        }

        if target > interactionStrength {
            withAnimation(.easeOut(duration: 0.12)) {
                interactionStrength = target
            }
        } else {
            withAnimation(.interactiveSpring(response: 0.54, dampingFraction: 0.90)) {
                interactionStrength = target
            }
        }
    }

    @MainActor
    private func runBoundedWakeMotion() async {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            wakeAmount = 0.0
        }

        guard allowsAmbientMotion else { return }
        guard await pause(seconds: 0.14) else { return }

        withAnimation(.easeOut(duration: 0.72)) {
            wakeAmount = 1.0
        }
        guard await pause(seconds: 0.72) else { return }

        withAnimation(.easeInOut(duration: 1.30)) {
            wakeAmount = 0.0
        }
    }

    private func pause(seconds: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(
                deadline: .now() + max(0.0, seconds)
            ) {
                continuation.resume()
            }
        }
        return !Task.isCancelled
    }

    private func renderField(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        guard size.width > 1.0, size.height > 1.0 else { return }

        let focus = CGPoint(
            x: interaction.point.x * size.width,
            y: interaction.point.y * size.height
        )
        let fieldStrength = min(max(interactionStrength, 0.0), 1.0)

        drawSurfaceVeils(
            in: &context,
            size: size,
            focus: focus,
            strength: fieldStrength
        )
        drawCompanionFilaments(
            in: &context,
            size: size,
            focus: focus,
            strength: fieldStrength
        )
        drawCareLens(
            in: &context,
            size: size,
            focus: focus,
            strength: fieldStrength
        )
    }

    private func drawSurfaceVeils(
        in context: inout GraphicsContext,
        size: CGSize,
        focus: CGPoint,
        strength: CGFloat
    ) {
        let direction: CGFloat = isRightToLeft ? -1.0 : 1.0
        let transparencyScale = reduceTransparency ? 0.56 : 1.0
        let horizontalResponse = (focus.x / size.width - 0.5) * 10.0 * strength
        let verticalResponse = (focus.y / size.height - 0.5) * 6.0 * strength
        let brightOriginX = isRightToLeft ? size.width * 0.68 : size.width * 0.32

        var upperVeil = Path()
        upperVeil.move(to: CGPoint(x: -size.width * 0.08, y: size.height * 0.04))
        upperVeil.addCurve(
            to: CGPoint(x: size.width * 1.08, y: size.height * 0.18),
            control1: CGPoint(
                x: brightOriginX + horizontalResponse,
                y: size.height * (0.24 + (0.05 * wakeAmount)) + verticalResponse
            ),
            control2: CGPoint(
                x: size.width * 0.70 + (direction * horizontalResponse),
                y: -size.height * 0.04
            )
        )
        upperVeil.addLine(to: CGPoint(x: size.width * 1.08, y: -size.height * 0.10))
        upperVeil.addLine(to: CGPoint(x: -size.width * 0.08, y: -size.height * 0.10))
        upperVeil.closeSubpath()
        context.fill(
            upperVeil,
            with: .color(
                Color.white.opacity(
                    (isDark ? 0.028 : 0.20 + (0.025 * Double(wakeAmount)))
                        * Double(transparencyScale)
                )
            )
        )

        var lowerVeil = Path()
        lowerVeil.move(to: CGPoint(x: -size.width * 0.08, y: size.height * 0.82))
        lowerVeil.addCurve(
            to: CGPoint(x: size.width * 1.08, y: size.height * 0.62),
            control1: CGPoint(
                x: size.width * 0.30 - (direction * horizontalResponse),
                y: size.height * 0.98
            ),
            control2: CGPoint(
                x: size.width * 0.72 + horizontalResponse,
                y: size.height * (0.50 - (0.04 * wakeAmount))
            )
        )
        lowerVeil.addLine(to: CGPoint(x: size.width * 1.08, y: size.height * 1.10))
        lowerVeil.addLine(to: CGPoint(x: -size.width * 0.08, y: size.height * 1.10))
        lowerVeil.closeSubpath()
        context.fill(
            lowerVeil,
            with: .color(
                accent.opacity(
                    ((isDark ? 0.026 : 0.018) + (0.022 * Double(strength)))
                        * Double(transparencyScale)
                )
            )
        )
    }

    private func drawCompanionFilaments(
        in context: inout GraphicsContext,
        size: CGSize,
        focus: CGPoint,
        strength: CGFloat
    ) {
        let columns = min(12, max(7, Int(size.width / 38.0)))
        let rows = min(7, max(4, Int(size.height / 34.0)))
        let cellWidth = size.width / CGFloat(columns)
        let cellHeight = size.height / CGFloat(rows)
        let influenceRadius = max(72.0, min(size.width, size.height) * 0.78)
        let baseDirection: CGFloat = isRightToLeft ? .pi : 0.0

        for index in 0..<(columns * rows) {
            let column = index % columns
            let row = index / columns
            let jitterX = (noise(index, salt: 0.17) - 0.5) * cellWidth * 0.56
            let jitterY = (noise(index, salt: 0.63) - 0.5) * cellHeight * 0.54
            let origin = CGPoint(
                x: (CGFloat(column) + 0.5) * cellWidth + jitterX,
                y: (CGFloat(row) + 0.5) * cellHeight + jitterY
            )
            let delta = CGVector(dx: focus.x - origin.x, dy: focus.y - origin.y)
            let distance = hypot(delta.dx, delta.dy)
            let proximity = max(0.0, 1.0 - (distance / influenceRadius))
            let localResponse = proximity * proximity * strength
            let restingAngle = baseDirection
                + ((noise(index, salt: 0.91) - 0.5) * 0.72)
                + ((wakeAmount - 0.5) * 0.10)
            let focusAngle = atan2(delta.dy, delta.dx)
            let angle = interpolatedAngle(
                from: restingAngle,
                to: focusAngle,
                amount: localResponse * 0.88
            )
            let baseLength = 8.0 + (noise(index, salt: 0.39) * 10.0)
            let length = baseLength + (localResponse * 13.0) + (wakeAmount * 1.6)
            let normal = CGVector(dx: -sin(angle), dy: cos(angle))
            let end = CGPoint(
                x: origin.x + (cos(angle) * length),
                y: origin.y + (sin(angle) * length)
            )
            let control = CGPoint(
                x: origin.x + (cos(angle) * length * 0.45) + (normal.dx * 2.2 * localResponse),
                y: origin.y + (sin(angle) * length * 0.45) + (normal.dy * 2.2 * localResponse)
            )

            var filament = Path()
            filament.move(to: origin)
            filament.addQuadCurve(to: end, control: control)
            let opacity = (isDark ? 0.040 : 0.028)
                + (0.092 * Double(localResponse))
                + (0.010 * Double(wakeAmount))
            context.stroke(
                filament,
                with: .color(accent.opacity(opacity)),
                style: StrokeStyle(
                    lineWidth: 0.55 + (localResponse * 0.72),
                    lineCap: .round
                )
            )
        }
    }

    private func drawCareLens(
        in context: inout GraphicsContext,
        size: CGSize,
        focus: CGPoint,
        strength: CGFloat
    ) {
        guard strength > 0.001 else { return }

        let pressure = max(0.62, interaction.pressure)
        let transparencyScale = reduceTransparency ? 0.50 : 1.0
        let baseRadius = min(92.0, max(54.0, min(size.width, size.height) * 0.48))
        let radius = baseRadius * (0.90 + (pressure * 0.10))
        let lensRect = CGRect(
            x: focus.x - radius,
            y: focus.y - radius,
            width: radius * 2.0,
            height: radius * 2.0
        )
        var lens = Path()
        lens.addEllipse(in: lensRect)
        context.fill(
            lens,
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(
                        (isDark ? 0.055 : 0.16)
                            * Double(strength)
                            * Double(transparencyScale)
                    ),
                    accent.opacity(
                        0.060 * Double(strength) * Double(transparencyScale)
                    ),
                    .clear,
                ]),
                center: focus,
                startRadius: 0.0,
                endRadius: radius
            )
        )

        let velocityMagnitude = hypot(interaction.velocity.dx, interaction.velocity.dy)
        let velocityScale = min(1.0, velocityMagnitude / 3.2)
        let direction: CGFloat = velocityMagnitude > 0.04
            ? atan2(interaction.velocity.dy, interaction.velocity.dx)
            : (isRightToLeft ? .pi : 0.0)
        let trailLength = 15.0 + (velocityScale * 31.0)

        for index in 0..<3 {
            let spread = CGFloat(index - 1) * 8.0
            let normal = CGVector(dx: -sin(direction), dy: cos(direction))
            let start = CGPoint(
                x: focus.x + (normal.dx * spread),
                y: focus.y + (normal.dy * spread)
            )
            let end = CGPoint(
                x: start.x - (cos(direction) * (trailLength + CGFloat(index) * 4.0)),
                y: start.y - (sin(direction) * (trailLength + CGFloat(index) * 4.0))
            )
            let control = CGPoint(
                x: (start.x + end.x) * 0.5 + (normal.dx * spread * 0.25),
                y: (start.y + end.y) * 0.5 + (normal.dy * spread * 0.25)
            )
            var trace = Path()
            trace.move(to: start)
            trace.addQuadCurve(to: end, control: control)
            context.stroke(
                trace,
                with: .color(
                    accent.opacity(
                        (0.070 - (Double(index) * 0.014)) * Double(strength)
                    )
                ),
                style: StrokeStyle(
                    lineWidth: index == 1 ? 1.05 : 0.66,
                    lineCap: .round
                )
            )
        }

        let coreRadius = 10.0 + (pressure * 4.0)
        var core = Path()
        core.addEllipse(
            in: CGRect(
                x: focus.x - coreRadius,
                y: focus.y - coreRadius,
                width: coreRadius * 2.0,
                height: coreRadius * 2.0
            )
        )
        context.stroke(
            core,
            with: .color(
                Color.white.opacity(
                    (isDark ? 0.10 : 0.30) * Double(strength)
                )
            ),
            lineWidth: 0.72
        )
    }

    private func noise(_ index: Int, salt: CGFloat) -> CGFloat {
        let raw = sin((Double(index) + Double(salt)) * 12.9898) * 43_758.5453
        return CGFloat(raw - floor(raw))
    }

    private func interpolatedAngle(
        from start: CGFloat,
        to end: CGFloat,
        amount: CGFloat
    ) -> CGFloat {
        var delta = (end - start).truncatingRemainder(dividingBy: .pi * 2.0)
        if delta > .pi { delta -= .pi * 2.0 }
        if delta < -.pi { delta += .pi * 2.0 }
        return start + (delta * min(max(amount, 0.0), 1.0))
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
            interaction: interactionModel.snapshot
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
            selector: #selector(accessibilityInteractionModeDidChange),
            name: UIAccessibility.switchControlStatusDidChangeNotification,
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
        guard isVisible != visible else {
            if visible { updatePassiveTracking() }
            return
        }
        isVisible = visible
        if !visible {
            interactionModel.reset()
        }
        updateRootView()
        updatePassiveTracking()
    }

    @objc private func accessibilityInteractionModeDidChange() {
        updatePassiveTracking()
    }

    private func updatePassiveTracking() {
        guard animationEnabled,
              isVisible,
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
        guard !UIAccessibility.isVoiceOverRunning,
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
            animationEnabled: animationEnabled && isVisible,
            shape: shape,
            cornerRadius: cornerRadius,
            accentColorOverride: accentColorOverride,
            borderWidth: borderWidth,
            interactionModel: interactionModel
        )
    }
}
