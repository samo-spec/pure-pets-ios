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

            PPWaveCardCompanionImprintField(
                accent: resolvedAccent,
                shape: shape,
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

@available(iOS 15.0, *)
private struct PPWaveCardCompanionImprintField: View {
    let accent: Color
    let shape: PPWaveCardBGShape
    let interaction: PPWaveCardInteractionSnapshot
    let allowsAmbientMotion: Bool
    let allowsInteractiveResponse: Bool
    let isRightToLeft: Bool
    let isDark: Bool
    let increasedContrast: Bool
    let reduceMotion: Bool
    let reduceTransparency: Bool

    @State private var interactionStrength: CGFloat = 0.0
    var body: some View {
        GeometryReader { proxy in
            if reduceMotion || !allowsAmbientMotion {
                companionCanvas(size: proxy.size, phase: 0.18)
            } else {
                TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { timeline in
                    companionCanvas(
                        size: proxy.size,
                        phase: phase(for: timeline.date)
                    )
                }
            }
        }
        .opacity(increasedContrast ? 0.62 : 1.0)
        .task(id: targetInteractionStrength) {
            await updateInteractionStrength(animated: allowsInteractiveResponse)
        }
    }

    private var targetInteractionStrength: CGFloat {
        allowsInteractiveResponse && interaction.isActive ? 1.0 : 0.0
    }

    private func companionCanvas(size: CGSize, phase: CGFloat) -> some View {
        Canvas(
            opaque: false,
            colorMode: .linear,
            rendersAsynchronously: true
        ) { context, canvasSize in
            renderCompanionImprint(
                in: &context,
                size: canvasSize,
                phase: phase
            )
        }
        .frame(width: size.width, height: size.height)
    }

    @MainActor
    private func updateInteractionStrength(animated: Bool) {
        let target = targetInteractionStrength

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
            withAnimation(.interactiveSpring(response: 0.48, dampingFraction: 0.92)) {
                interactionStrength = target
            }
        }
    }

    private func phase(for date: Date) -> CGFloat {
        let cycle = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 9.6)
        return CGFloat(cycle / 9.6)
    }

    private func renderCompanionImprint(
        in context: inout GraphicsContext,
        size: CGSize,
        phase: CGFloat
    ) {
        guard size.width > 1.0, size.height > 1.0 else { return }

        let touchPoint = CGPoint(
            x: interaction.point.x * size.width,
            y: interaction.point.y * size.height
        )
        let response = min(max(interactionStrength, 0.0), 1.0)
        let theta = phase * .pi * 2.0
        let basis = imprintBasis(in: size)
        let anchor = companionAnchor(
            size: size,
            touchPoint: touchPoint,
            response: response,
            theta: theta,
            basis: basis
        )
        let breathScale = 1.0
            + (sin(theta) * 0.022)
            + (response * 0.032)
        let directionSign: CGFloat = isRightToLeft ? -1.0 : 1.0
        let velocityLean = min(
            0.035,
            max(-0.035, interaction.velocity.dy * 0.006)
        ) * response
        let rotation = (directionSign * 0.055) + velocityLean

        drawCompanionWash(
            in: &context,
            size: size,
            anchor: anchor,
            basis: basis,
            theta: theta,
            response: response
        )
        drawCompanionImprint(
            in: &context,
            anchor: anchor,
            basis: basis,
            scale: breathScale,
            rotation: rotation,
            theta: theta,
            response: response
        )
    }

    private func companionAnchor(
        size: CGSize,
        touchPoint: CGPoint,
        response: CGFloat,
        theta: CGFloat,
        basis: CGFloat
    ) -> CGPoint {
        let directionSign: CGFloat = isRightToLeft ? -1.0 : 1.0
        let restingAnchor = CGPoint(
            x: (size.width * anchorFraction)
                + (cos(theta) * basis * 0.018 * directionSign),
            y: (size.height * 0.52)
                + (sin(theta) * basis * 0.022)
        )
        let delta = CGVector(
            dx: touchPoint.x - restingAnchor.x,
            dy: touchPoint.y - restingAnchor.y
        )
        let distance = max(1.0, hypot(delta.dx, delta.dy))
        let travel = min(
            basis * 0.09,
            distance * 0.035
        ) * response
        return CGPoint(
            x: restingAnchor.x + ((delta.dx / distance) * travel),
            y: restingAnchor.y + ((delta.dy / distance) * travel)
        )
    }

    /// A quiet tonal bed that stays attached to the pet imprint, without
    /// detached particles or a competing luminous focal point.
    private func drawCompanionWash(
        in context: inout GraphicsContext,
        size: CGSize,
        anchor: CGPoint,
        basis: CGFloat,
        theta: CGFloat,
        response: CGFloat
    ) {
        let directionSign: CGFloat = isRightToLeft ? -1.0 : 1.0
        let center = CGPoint(
            x: anchor.x + (directionSign * basis * 0.06),
            y: anchor.y + (sin(theta) * basis * 0.012)
        )
        let radii = companionWashRadii(in: size, basis: basis)
        let breath = 1.0
            + (((sin(theta) + 1.0) * 0.5) * 0.035)
            + (response * 0.025)
        let rect = CGRect(
            x: center.x - (radii.width * breath),
            y: center.y - (radii.height * breath),
            width: radii.width * breath * 2.0,
            height: radii.height * breath * 2.0
        )
        var wash = Path()
        wash.addEllipse(in: rect)
        let transparencyScale = reduceTransparency ? 0.72 : 1.0
        context.fill(
            wash,
            with: .radialGradient(
                Gradient(colors: [
                    accent.opacity(
                        (isDark ? 0.145 : 0.095)
                            * Double(transparencyScale)
                    ),
                    Color.ppQuickActionAnimals.opacity(
                        (isDark ? 0.075 : 0.050)
                            * Double(transparencyScale)
                    ),
                    Color.ppSoftRose.opacity(
                        (isDark ? 0.030 : 0.045)
                            * Double(transparencyScale)
                    ),
                    .clear,
                ]),
                center: center,
                startRadius: 0,
                endRadius: max(radii.width, radii.height) * breath
            )
        )
    }

    /// The signature visual is one cohesive paw impression: a central care pad
    /// and four attached toe pads. Every part breathes together, so it reads as
    /// a calm companion mark rather than a particle system.
    private func drawCompanionImprint(
        in context: inout GraphicsContext,
        anchor: CGPoint,
        basis: CGFloat,
        scale: CGFloat,
        rotation: CGFloat,
        theta: CGFloat,
        response: CGFloat
    ) {
        let mainCenter = rotatedPoint(
            around: anchor,
            x: 0,
            y: basis * 0.22 * scale,
            angle: rotation
        )
        let mainWidth = basis * 1.02 * scale
        let mainHeight = basis * 0.82 * scale
        let mainPad = companionPadPath(
            center: mainCenter,
            width: mainWidth,
            height: mainHeight,
            rotation: rotation
        )
        let toePads = companionToePads(
            anchor: anchor,
            basis: basis,
            scale: scale,
            rotation: rotation,
            theta: theta,
            response: response
        )
        let shadowOffset = CGSize(
            width: (isRightToLeft ? 1 : -1) * basis * 0.018,
            height: basis * 0.032
        )
        let transparencyScale = reduceTransparency ? 0.80 : 1.0
        let shadowOpacity = (isDark ? 0.075 : 0.030)
            * Double(transparencyScale)
        let outlineOpacity = (isDark ? 0.16 : 0.30)
            * Double(transparencyScale)
        let startPoint = CGPoint(
            x: anchor.x + (isRightToLeft ? basis * 0.50 : -basis * 0.50),
            y: anchor.y - (basis * 0.62)
        )
        let endPoint = CGPoint(
            x: anchor.x + (isRightToLeft ? -basis * 0.42 : basis * 0.42),
            y: anchor.y + (basis * 0.58)
        )

        context.fill(
            mainPad.applying(
                CGAffineTransform(
                    translationX: shadowOffset.width,
                    y: shadowOffset.height
                )
            ),
            with: .color(Color.ppTextPrimary.opacity(shadowOpacity))
        )
        for toe in toePads {
            context.fill(
                ellipsePath(
                    center: CGPoint(
                        x: toe.center.x + shadowOffset.width,
                        y: toe.center.y + shadowOffset.height
                    ),
                    size: toe.size
                ),
                with: .color(Color.ppTextPrimary.opacity(shadowOpacity))
            )
        }

        let imprintGradient = Gradient(colors: [
            Color.white.opacity(
                (isDark ? 0.10 : 0.44) * Double(transparencyScale)
            ),
            accent.opacity(
                (isDark ? 0.28 : 0.18) * Double(transparencyScale)
            ),
            Color.ppQuickActionAnimals.opacity(
                (isDark ? 0.14 : 0.085) * Double(transparencyScale)
            ),
        ])
        context.fill(
            mainPad,
            with: .linearGradient(
                imprintGradient,
                startPoint: startPoint,
                endPoint: endPoint
            )
        )
        context.stroke(
            mainPad,
            with: .color(Color.white.opacity(outlineOpacity)),
            lineWidth: increasedContrast ? 1.0 : 0.7
        )

        for toe in toePads {
            let path = ellipsePath(center: toe.center, size: toe.size)
            context.fill(
                path,
                with: .linearGradient(
                    imprintGradient,
                    startPoint: CGPoint(
                        x: toe.center.x - (toe.size.width * 0.34),
                        y: toe.center.y - (toe.size.height * 0.42)
                    ),
                    endPoint: CGPoint(
                        x: toe.center.x + (toe.size.width * 0.36),
                        y: toe.center.y + (toe.size.height * 0.44)
                    )
                )
            )
            context.stroke(
                path,
                with: .color(Color.white.opacity(outlineOpacity * 0.88)),
                lineWidth: increasedContrast ? 0.9 : 0.6
            )
        }

        context.stroke(
            companionSheenPath(
                center: mainCenter,
                width: mainWidth,
                height: mainHeight,
                rotation: rotation
            ),
            with: .linearGradient(
                Gradient(colors: [
                    Color.white.opacity(
                        (isDark ? 0.16 : 0.48) * Double(transparencyScale)
                    ),
                    Color.white.opacity(0),
                ]),
                startPoint: startPoint,
                endPoint: endPoint
            ),
            style: StrokeStyle(
                lineWidth: max(0.8, basis * 0.012),
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    private var anchorFraction: CGFloat {
        let trailingFraction: CGFloat
        switch shape {
        case .rounded:
            trailingFraction = 0.83
        case .capsule:
            trailingFraction = 0.73
        case .circle:
            trailingFraction = 0.62
        }
        return isRightToLeft ? 1.0 - trailingFraction : trailingFraction
    }

    private func imprintBasis(in size: CGSize) -> CGFloat {
        let minimumDimension = min(size.width, size.height)
        switch shape {
        case .rounded:
            return max(8.0, min(size.height * 0.40, size.width * 0.19))
        case .capsule:
            return max(7.0, min(minimumDimension * 0.36, size.width * 0.18))
        case .circle:
            return max(7.0, minimumDimension * 0.27)
        }
    }

    private func companionWashRadii(
        in size: CGSize,
        basis: CGFloat
    ) -> CGSize {
        switch shape {
        case .rounded:
            return CGSize(
                width: min(size.width * 0.27, basis * 1.55),
                height: min(size.height * 0.48, basis * 1.22)
            )
        case .capsule:
            return CGSize(
                width: min(size.width * 0.22, basis * 1.75),
                height: min(size.height * 0.46, basis * 1.15)
            )
        case .circle:
            let radius = min(minimumDimension(of: size) * 0.40, basis * 1.55)
            return CGSize(width: radius, height: radius)
        }
    }

    private func minimumDimension(of size: CGSize) -> CGFloat {
        min(size.width, size.height)
    }

    private func rotatedPoint(
        around origin: CGPoint,
        x: CGFloat,
        y: CGFloat,
        angle: CGFloat
    ) -> CGPoint {
        let cosine = cos(angle)
        let sine = sin(angle)
        return CGPoint(
            x: origin.x + (x * cosine) - (y * sine),
            y: origin.y + (x * sine) + (y * cosine)
        )
    }

    /// A hand-shaped metacarpal pad with a shallow upper cleft and two soft
    /// lower lobes. It avoids an SF Symbol silhouette while remaining legible
    /// from compact circles through full-width cards.
    private func companionPadPath(
        center: CGPoint,
        width: CGFloat,
        height: CGFloat,
        rotation: CGFloat
    ) -> Path {
        let halfWidth = width * 0.5
        let halfHeight = height * 0.5

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            rotatedPoint(
                around: center,
                x: x * halfWidth,
                y: y * halfHeight,
                angle: rotation
            )
        }

        var path = Path()
        path.move(to: point(0.0, -0.78))
        path.addCurve(
            to: point(0.94, -0.08),
            control1: point(0.30, -0.98),
            control2: point(0.90, -0.74)
        )
        path.addCurve(
            to: point(0.42, 0.88),
            control1: point(1.00, 0.36),
            control2: point(0.74, 0.82)
        )
        path.addCurve(
            to: point(0.0, 0.70),
            control1: point(0.26, 1.02),
            control2: point(0.10, 0.76)
        )
        path.addCurve(
            to: point(-0.42, 0.88),
            control1: point(-0.10, 0.76),
            control2: point(-0.26, 1.02)
        )
        path.addCurve(
            to: point(-0.94, -0.08),
            control1: point(-0.74, 0.82),
            control2: point(-1.00, 0.36)
        )
        path.addCurve(
            to: point(0.0, -0.78),
            control1: point(-0.90, -0.74),
            control2: point(-0.30, -0.98)
        )
        path.closeSubpath()
        return path
    }

    private func companionToePads(
        anchor: CGPoint,
        basis: CGFloat,
        scale: CGFloat,
        rotation: CGFloat,
        theta: CGFloat,
        response: CGFloat
    ) -> [(center: CGPoint, size: CGSize)] {
        let sharedLift = (
            (sin(theta) * basis * 0.006)
                - (response * basis * 0.010)
        ) * scale
        let inwardNuzzle = 1.0 - (response * 0.018)
        let geometry: [(
            x: CGFloat,
            y: CGFloat,
            width: CGFloat,
            height: CGFloat
        )] = [
            (-0.44, -0.33, 0.26, 0.36),
            (-0.16, -0.40, 0.29, 0.42),
            (0.16, -0.40, 0.29, 0.42),
            (0.44, -0.33, 0.26, 0.36),
        ]

        return geometry.map { toe in
            let center = rotatedPoint(
                around: anchor,
                x: toe.x * basis * scale * inwardNuzzle,
                y: (toe.y * basis * scale) + sharedLift,
                angle: rotation
            )
            return (
                center: center,
                size: CGSize(
                    width: toe.width * basis * scale,
                    height: toe.height * basis * scale
                )
            )
        }
    }

    private func ellipsePath(center: CGPoint, size: CGSize) -> Path {
        var path = Path()
        path.addEllipse(
            in: CGRect(
                x: center.x - (size.width * 0.5),
                y: center.y - (size.height * 0.5),
                width: size.width,
                height: size.height
            )
        )
        return path
    }

    private func companionSheenPath(
        center: CGPoint,
        width: CGFloat,
        height: CGFloat,
        rotation: CGFloat
    ) -> Path {
        let halfWidth = width * 0.5
        let halfHeight = height * 0.5

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            rotatedPoint(
                around: center,
                x: x * halfWidth,
                y: y * halfHeight,
                angle: rotation
            )
        }

        var path = Path()
        path.move(to: point(-0.56, -0.12))
        path.addCurve(
            to: point(0.34, -0.58),
            control1: point(-0.42, -0.60),
            control2: point(0.02, -0.78)
        )
        return path
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
    private var isApplicationActive = UIApplication.shared.applicationState == .active

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
                sceneIsActive: isApplicationActive,
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
            selector: #selector(applicationActivityDidChange),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationActivityDidChange),
            name: UIApplication.didEnterBackgroundNotification,
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
        let applicationIsActive = UIApplication.shared.applicationState == .active
        let activityDidChange = isApplicationActive != applicationIsActive
        isApplicationActive = applicationIsActive

        guard isVisible != visible || activityDidChange else {
            if visible { updatePassiveTracking() }
            return
        }
        isVisible = visible
        if !visible || !applicationIsActive {
            interactionModel.reset()
        }
        updateRootView()
        updatePassiveTracking()
    }

    @objc private func accessibilityInteractionModeDidChange() {
        updatePassiveTracking()
    }

    @objc private func applicationActivityDidChange() {
        let isActive = UIApplication.shared.applicationState == .active
        guard isApplicationActive != isActive else { return }
        isApplicationActive = isActive
        if !isActive {
            interactionModel.reset()
        }
        updateRootView()
        updatePassiveTracking()
    }

    private func updatePassiveTracking() {
        guard animationEnabled,
              isVisible,
              isApplicationActive,
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
              isApplicationActive,
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
            animationEnabled: animationEnabled && isVisible && isApplicationActive,
            sceneIsActive: isApplicationActive,
            shape: shape,
            cornerRadius: cornerRadius,
            accentColorOverride: accentColorOverride,
            borderWidth: borderWidth,
            interactionModel: interactionModel
        )
    }
}
