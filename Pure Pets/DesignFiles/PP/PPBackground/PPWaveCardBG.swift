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

            PPWaveCardHabitatField(
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
private struct PPWaveCardHabitatField: View {
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
                habitatCanvas(size: proxy.size, phase: 0.18)
            } else {
                TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
                    habitatCanvas(
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

    private func habitatCanvas(size: CGSize, phase: CGFloat) -> some View {
        Canvas(
            opaque: false,
            colorMode: .linear,
            rendersAsynchronously: true
        ) { context, canvasSize in
            renderHabitat(
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
            .truncatingRemainder(dividingBy: 6.4)
        return CGFloat(cycle / 6.4)
    }

    private func renderHabitat(
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
        let anchor = habitatAnchor(
            size: size,
            touchPoint: touchPoint,
            response: response,
            theta: theta
        )

        drawCounterweightGlow(
            in: &context,
            size: size,
            theta: theta
        )

        drawHabitatAura(
            in: &context,
            size: size,
            anchor: anchor,
            theta: theta,
            response: response
        )
        drawCareBloom(
            in: &context,
            size: size,
            anchor: anchor,
            touchPoint: touchPoint,
            theta: theta,
            response: response
        )
        drawCompanionSeeds(
            in: &context,
            size: size,
            anchor: anchor,
            theta: theta,
            response: response
        )
        drawCareBeacon(
            in: &context,
            size: size,
            anchor: anchor,
            theta: theta
        )
    }

    private func habitatAnchor(
        size: CGSize,
        touchPoint: CGPoint,
        response: CGFloat,
        theta: CGFloat
    ) -> CGPoint {
        let basis = bloomBasis(in: size)
        let directionSign: CGFloat = isRightToLeft ? -1.0 : 1.0
        let restingAnchor = CGPoint(
            x: (size.width * anchorFraction)
                + (cos(theta) * basis * 0.075 * directionSign),
            y: (size.height * 0.50)
                + (sin(theta) * basis * 0.085)
        )
        let delta = CGVector(
            dx: touchPoint.x - restingAnchor.x,
            dy: touchPoint.y - restingAnchor.y
        )
        let distance = max(1.0, hypot(delta.dx, delta.dy))
        let travel = min(
            basis * 0.20,
            distance * 0.075
        ) * response
        return CGPoint(
            x: restingAnchor.x + ((delta.dx / distance) * travel),
            y: restingAnchor.y + ((delta.dy / distance) * travel)
        )
    }

    private func drawCounterweightGlow(
        in context: inout GraphicsContext,
        size: CGSize,
        theta: CGFloat
    ) {
        let basis = bloomBasis(in: size)
        let directionSign: CGFloat = isRightToLeft ? -1.0 : 1.0
        let center = CGPoint(
            x: (size.width * (isRightToLeft ? 0.78 : 0.22))
                + (cos(theta) * basis * 0.14 * directionSign),
            y: (size.height * 0.32)
                + (sin(theta) * basis * 0.16)
        )
        let radiusX = max(size.width * 0.30, basis * 1.60)
        let radiusY = max(size.height * 0.56, basis * 1.36)
        var glow = Path()
        glow.addEllipse(
            in: CGRect(
                x: center.x - radiusX,
                y: center.y - radiusY,
                width: radiusX * 2.0,
                height: radiusY * 2.0
            )
        )
        let transparencyScale = reduceTransparency ? 0.76 : 1.0
        context.fill(
            glow,
            with: .radialGradient(
                Gradient(colors: [
                    Color.ppPrimary.opacity(
                        (isDark ? 0.095 : 0.105) * Double(transparencyScale)
                    ),
                    Color.ppPremiumAccent.opacity(
                        (isDark ? 0.030 : 0.050) * Double(transparencyScale)
                    ),
                    .clear,
                ]),
                center: center,
                startRadius: 0.0,
                endRadius: max(radiusX, radiusY)
            )
        )
    }

    private func drawHabitatAura(
        in context: inout GraphicsContext,
        size: CGSize,
        anchor: CGPoint,
        theta: CGFloat,
        response: CGFloat
    ) {
        let breath = (sin(theta) + 1.0) * 0.5
        let basis = bloomBasis(in: size)
        let radii = auraRadii(in: size, basis: basis)
        let radiusX = radii.width
        let radiusY = radii.height
        let scale = 1.0 + (0.10 * breath) + (0.055 * response)
        let rect = CGRect(
            x: anchor.x - (radiusX * scale),
            y: anchor.y - (radiusY * scale),
            width: radiusX * scale * 2.0,
            height: radiusY * scale * 2.0
        )
        var aura = Path()
        aura.addEllipse(in: rect)
        let transparencyScale = reduceTransparency ? 0.76 : 1.0
        context.fill(
            aura,
            with: .radialGradient(
                Gradient(colors: [
                    accent.opacity(
                        (isDark ? 0.180 : 0.135) * Double(transparencyScale)
                    ),
                    Color.ppSoftRose.opacity(
                        (isDark ? 0.065 : 0.115) * Double(transparencyScale)
                    ),
                    .clear,
                ]),
                center: anchor,
                startRadius: 0.0,
                endRadius: max(radiusX, radiusY) * scale
            )
        )
    }

    private func drawCareBloom(
        in context: inout GraphicsContext,
        size: CGSize,
        anchor: CGPoint,
        touchPoint: CGPoint,
        theta: CGFloat,
        response: CGFloat
    ) {
        let baseDirection: CGFloat = isRightToLeft ? 0.0 : .pi
        let touchDirection = atan2(
            touchPoint.y - anchor.y,
            touchPoint.x - anchor.x
        )
        let directionSign: CGFloat = isRightToLeft ? -1.0 : 1.0
        let velocityLean = min(
            0.12,
            max(-0.12, interaction.velocity.dy * 0.018)
        ) * response * directionSign
        let basis = bloomBasis(in: size)
        let spreads: [CGFloat] = [-0.92, -0.46, 0.0, 0.46, 0.92]
        let lengths: [CGFloat] = [0.70, 0.88, 1.0, 0.88, 0.70]

        for index in spreads.indices {
            let independentPhase = theta
                - 0.42
                + (CGFloat(index) * 0.20)
            let respiration = sin(independentPhase) * 0.090 * directionSign
            let restingAngle = baseDirection
                + (spreads[index] * directionSign)
                + respiration
            let angle = interpolatedAngle(
                from: restingAngle,
                to: touchDirection,
                amount: response * (index == 2 ? 0.34 : 0.20)
            ) + velocityLean
            let pressure = max(0.35, interaction.pressure)
            let length = basis * lengths[index]
                * (1.0 + (sin(independentPhase + 0.44) * 0.085))
                * (1.0 + (response * pressure * 0.08))
            let width = length * (0.27 + (CGFloat(index % 2) * 0.025))
            let rootOffset = CGFloat(index - 2) * basis * 0.016
            let root = CGPoint(
                x: anchor.x,
                y: anchor.y - rootOffset
            )
            let petal = bloomPetalPath(
                root: root,
                angle: angle,
                length: length,
                width: width,
                curl: sin(
                    (theta * 2.0) + (CGFloat(index) * 1.17) + 0.20
                ) * width * 0.10 * directionSign
            )
            let tip = CGPoint(
                x: root.x + (cos(angle) * length),
                y: root.y + (sin(angle) * length)
            )
            let opacityScale = reduceTransparency ? 0.82 : 1.0
            let prominence = 1.0 - (Double(abs(index - 2)) * 0.065)
            context.fill(
                petal,
                with: .linearGradient(
                    Gradient(colors: [
                        accent.opacity(
                            (isDark ? 0.340 : 0.260)
                                * Double(opacityScale)
                                * prominence
                        ),
                        Color.ppSoftRose.opacity(
                            (isDark ? 0.145 : 0.255)
                                * Double(opacityScale)
                                * prominence
                        ),
                        Color.ppWarmPorcelain.opacity(
                            (isDark ? 0.055 : 0.170)
                                * Double(opacityScale)
                                * prominence
                        ),
                    ]),
                    startPoint: root,
                    endPoint: tip
                )
            )
        }

        drawBloomHeart(
            in: &context,
            anchor: anchor,
            basis: basis,
            theta: theta,
            response: response
        )
    }

    private func drawBloomHeart(
        in context: inout GraphicsContext,
        anchor: CGPoint,
        basis: CGFloat,
        theta: CGFloat,
        response: CGFloat
    ) {
        let breath = 1.0 + (sin(theta) * 0.075) + (response * 0.065)
        let width = basis * 0.42 * breath
        let height = basis * 0.34 * breath
        let rect = CGRect(
            x: anchor.x - (width * 0.5),
            y: anchor.y - (height * 0.5),
            width: width,
            height: height
        )
        var heart = Path()
        heart.addEllipse(in: rect)
        let opacityScale = reduceTransparency ? 0.84 : 1.0
        context.fill(
            heart,
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(
                        (isDark ? 0.22 : 0.72) * Double(opacityScale)
                    ),
                    accent.opacity(
                        (isDark ? 0.30 : 0.22) * Double(opacityScale)
                    ),
                    Color.ppSurfaceRaised.opacity(isDark ? 0.08 : 0.04),
                ]),
                center: CGPoint(
                    x: rect.midX + (width * (isRightToLeft ? 0.16 : -0.16)),
                    y: rect.midY - (height * 0.18)
                ),
                startRadius: 0.0,
                endRadius: max(width, height) * 0.70
            )
        )
    }

    private func drawCompanionSeeds(
        in context: inout GraphicsContext,
        size: CGSize,
        anchor: CGPoint,
        theta: CGFloat,
        response: CGFloat
    ) {
        let basis = bloomBasis(in: size)
        let orbitRadius = companionOrbitRadius(in: size, basis: basis)
        let opacityScale = reduceTransparency ? 0.82 : 1.0

        for index in 0..<3 {
            let baseAngle = CGFloat(index) * ((.pi * 2.0) / 3.0) - 0.74
            let orbitalAngle = baseAngle + theta
            let angle = isRightToLeft
                ? .pi - orbitalAngle
                : orbitalAngle
            let radialPulse = sin(
                (theta * 2.0) + (CGFloat(index) * ((.pi * 2.0) / 3.0))
            ) * 0.055
            let radius = orbitRadius
                * (0.86 + (CGFloat(index) * 0.10) + radialPulse)
            let center = CGPoint(
                x: anchor.x + (cos(angle) * radius),
                y: anchor.y + (sin(angle) * radius * 0.72)
            )
            let baseSeedWidth = max(1.8, basis * 0.070)
            let seedWidth = baseSeedWidth
                * (1.0 + (CGFloat(index) * 0.18))
                + (response * basis * 0.020)
            let seedHeight = seedWidth * 0.62
            var seed = Path()
            seed.addEllipse(
                in: CGRect(
                    x: center.x - (seedWidth * 0.5),
                    y: center.y - (seedHeight * 0.5),
                    width: seedWidth,
                    height: seedHeight
                )
            )
            context.fill(
                seed,
                with: .color(
                    accent.opacity(
                        (isDark ? 0.44 : 0.34) * Double(opacityScale)
                    )
                )
            )
        }
    }

    private func drawCareBeacon(
        in context: inout GraphicsContext,
        size: CGSize,
        anchor: CGPoint,
        theta: CGFloat
    ) {
        let basis = bloomBasis(in: size)
        let orbitRadius = companionOrbitRadius(in: size, basis: basis) * 1.18
        let baseAngle = theta + 0.38
        let angle = isRightToLeft ? .pi - baseAngle : baseAngle
        let center = CGPoint(
            x: anchor.x + (cos(angle) * orbitRadius),
            y: anchor.y + (sin(angle) * orbitRadius * 0.72)
        )
        let pulse = (sin(theta * 2.0) + 1.0) * 0.5
        let opacityScale = reduceTransparency ? 0.84 : 1.0
        let haloDiameter = max(12.0, basis * (0.24 + (0.05 * pulse)))
        let haloRect = CGRect(
            x: center.x - (haloDiameter * 0.5),
            y: center.y - (haloDiameter * 0.5),
            width: haloDiameter,
            height: haloDiameter
        )
        var halo = Path()
        halo.addEllipse(in: haloRect)
        context.fill(
            halo,
            with: .radialGradient(
                Gradient(colors: [
                    accent.opacity(0.38 * Double(opacityScale)),
                    Color.ppPremiumAccent.opacity(0.18 * Double(opacityScale)),
                    .clear,
                ]),
                center: center,
                startRadius: 0.0,
                endRadius: haloDiameter * 0.5
            )
        )

        let coreDiameter = max(3.5, basis * 0.075)
        let coreRect = CGRect(
            x: center.x - (coreDiameter * 0.5),
            y: center.y - (coreDiameter * 0.5),
            width: coreDiameter,
            height: coreDiameter
        )
        var core = Path()
        core.addEllipse(in: coreRect)
        context.fill(
            core,
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(isDark ? 0.72 : 0.92),
                    Color.ppPremiumAccent.opacity(0.76),
                    accent.opacity(0.58),
                ]),
                center: CGPoint(
                    x: coreRect.midX - (coreDiameter * 0.16),
                    y: coreRect.midY - (coreDiameter * 0.16)
                ),
                startRadius: 0.0,
                endRadius: coreDiameter * 0.62
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

    private func bloomBasis(in size: CGSize) -> CGFloat {
        let minimumDimension = min(size.width, size.height)
        switch shape {
        case .rounded:
            return max(8.0, min(size.height * 0.42, size.width * 0.22))
        case .capsule:
            return max(7.0, minimumDimension * 0.34)
        case .circle:
            return max(7.0, minimumDimension * 0.25)
        }
    }

    private func auraRadii(
        in size: CGSize,
        basis: CGFloat
    ) -> CGSize {
        switch shape {
        case .rounded:
            return CGSize(
                width: min(size.width * 0.46, basis * 1.95),
                height: min(size.height * 0.70, basis * 1.35)
            )
        case .capsule:
            return CGSize(
                width: min(size.width * 0.30, basis * 2.05),
                height: min(size.height * 0.46, basis * 1.20)
            )
        case .circle:
            let radius = min(min(size.width, size.height) * 0.42, basis * 1.62)
            return CGSize(width: radius, height: radius)
        }
    }

    private func companionOrbitRadius(
        in size: CGSize,
        basis: CGFloat
    ) -> CGFloat {
        switch shape {
        case .rounded:
            return min(size.height * 0.32, basis * 0.92)
        case .capsule:
            return min(size.height * 0.30, basis * 0.86)
        case .circle:
            return min(min(size.width, size.height) * 0.29, basis * 1.10)
        }
    }

    private func bloomPetalPath(
        root: CGPoint,
        angle: CGFloat,
        length: CGFloat,
        width: CGFloat,
        curl: CGFloat
    ) -> Path {
        let forward = CGVector(dx: cos(angle), dy: sin(angle))
        let normal = CGVector(dx: -forward.dy, dy: forward.dx)
        let leftShoulderProgress: CGFloat = isRightToLeft ? 0.36 : 0.38
        let rightShoulderProgress: CGFloat = isRightToLeft ? 0.38 : 0.36
        let tip = CGPoint(
            x: root.x + (forward.dx * length) + (normal.dx * curl),
            y: root.y + (forward.dy * length) + (normal.dy * curl)
        )
        let leftShoulder = CGPoint(
            x: root.x
                + (forward.dx * length * leftShoulderProgress)
                + (normal.dx * width),
            y: root.y
                + (forward.dy * length * leftShoulderProgress)
                + (normal.dy * width)
        )
        let rightShoulder = CGPoint(
            x: root.x
                + (forward.dx * length * rightShoulderProgress)
                - (normal.dx * width),
            y: root.y
                + (forward.dy * length * rightShoulderProgress)
                - (normal.dy * width)
        )
        let leftTipControl = CGPoint(
            x: tip.x - (forward.dx * length * 0.18) + (normal.dx * width * 0.34),
            y: tip.y - (forward.dy * length * 0.18) + (normal.dy * width * 0.34)
        )
        let rightTipControl = CGPoint(
            x: tip.x - (forward.dx * length * 0.18) - (normal.dx * width * 0.34),
            y: tip.y - (forward.dy * length * 0.18) - (normal.dy * width * 0.34)
        )

        var path = Path()
        path.move(to: root)
        path.addCurve(
            to: tip,
            control1: leftShoulder,
            control2: leftTipControl
        )
        path.addCurve(
            to: root,
            control1: rightTipControl,
            control2: rightShoulder
        )
        path.closeSubpath()
        return path
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
