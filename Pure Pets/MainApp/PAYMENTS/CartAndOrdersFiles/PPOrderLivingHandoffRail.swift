//
//  PPOrderLivingHandoffRail.swift
//  Pure Pets
//
//  Standalone presentation component for local integration.
//  IMPORTANT: This file does not own order lifecycle state.
//  Feed it the canonical customer-facing statusKey from the local app.
//

import SwiftUI

@available(iOS 17.0, *)
struct PPOrderLivingHandoffRail: View {
    enum Presentation {
        case hero
        case compact

        var railHeight: CGFloat {
            switch self {
            case .hero: return 72
            case .compact: return 58
            }
        }

        var activeDiameter: CGFloat {
            switch self {
            case .hero: return 50
            case .compact: return 42
            }
        }

        var neighborDiameter: CGFloat {
            switch self {
            case .hero: return 31
            case .compact: return 27
            }
        }

    }

    struct JourneyStep: Identifiable, Hashable {
        let key: String
        let symbol: String
        let fallbackTitle: String

        var id: String { key }
    }

    let statusKey: String
    let statusTitle: String
    let statusHint: String
    let updatedAtText: String
    let fallbackStatusSymbol: String
    let accent: Color
    let presentation: Presentation
    private let layoutDirectionOverride: LayoutDirection?

    /// Optional title resolver. Use this to keep localization owned by the local app.
    let titleForStep: ((String, String) -> String)?

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        statusKey: String,
        statusTitle: String,
        statusHint: String = "",
        updatedAtText: String = "",
        fallbackStatusSymbol: String = "clock.fill",
        accent: Color,
        isRightToLeft: Bool? = nil,
        presentation: Presentation = .hero,
        titleForStep: ((String, String) -> String)? = nil
    ) {
        self.statusKey = statusKey
        self.statusTitle = statusTitle
        self.statusHint = statusHint
        self.updatedAtText = updatedAtText
        self.fallbackStatusSymbol = fallbackStatusSymbol
        self.accent = accent
        self.presentation = presentation
        self.layoutDirectionOverride = isRightToLeft.map {
            $0 ? .rightToLeft : .leftToRight
        }
        self.titleForStep = titleForStep
    }

    private static let journeySteps: [JourneyStep] = [
        .init(
            key: "pending",
            symbol: "bag.badge.plus",
            fallbackTitle: "Order placed"
        ),
        .init(
            key: "preparing_for_shipment",
            symbol: "shippingbox",
            fallbackTitle: "Preparing"
        ),
        .init(
            key: "ready_for_delivery",
            symbol: "shippingbox.fill",
            fallbackTitle: "Ready"
        ),
        .init(
            key: "delivery_partner_assigned",
            symbol: "person.crop.circle.badge.checkmark",
            fallbackTitle: "Partner assigned"
        ),
        .init(
            key: "on_the_way",
            symbol: "location.fill",
            fallbackTitle: "On the way"
        ),
        .init(
            key: "delivered",
            symbol: "house.fill",
            fallbackTitle: "Delivered"
        ),
        .init(
            key: "completed",
            symbol: "checkmark.seal.fill",
            fallbackTitle: "Completed"
        )
    ]

    private var normalizedStatusKey: String {
        statusKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    private var currentIndex: Int? {
        Self.journeySteps.firstIndex { $0.key == normalizedStatusKey }
    }

    private var isRTL: Bool {
        if let layoutDirectionOverride {
            return layoutDirectionOverride == .rightToLeft
        }
        return Language.isRTL() || layoutDirection == .rightToLeft
    }

    private var resolvedLayoutDirection: LayoutDirection {
        isRTL ? .rightToLeft : .leftToRight
    }

    private var footerNextStatusFont: Font {
        .custom("Beiruti-Bold", size: presentation == .hero ? 14 : 12.5, relativeTo: .caption)
    }

    private var footerTimeFont: Font {
        .custom("Beiruti-Medium", size: presentation == .hero ? 13 : 11.5, relativeTo: .caption)
    }

    var body: some View {
        Group {
            if let currentIndex {
                canonicalRail(currentIndex: currentIndex)
            } else {
                exceptionRail
            }
        }
        .environment(\.layoutDirection, resolvedLayoutDirection)
    }

    private func canonicalRail(currentIndex: Int) -> some View {
        VStack(spacing: presentation == .hero ? 8 : 5) {
            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                let geometry = RailGeometry(
                    width: width,
                    presentation: presentation,
                    layoutDirection: resolvedLayoutDirection
                )
                let lineY = presentation.railHeight * 0.42
                let lastIndex = Self.journeySteps.count - 1
                let visibleStart = max(0, currentIndex - 2)
                let visibleEnd = min(
                    lastIndex,
                    currentIndex + geometry.visibleFutureCount
                )
                let visibleIndices = Array(visibleStart...visibleEnd)
                let hasCollapsedHistory = visibleStart > 0
                let hasCollapsedFuture = visibleEnd < lastIndex

                ZStack {
                    // The marker-to-marker spine is deliberately continuous across the card width.
                    Capsule()
                        .fill(Color.ppSeparator.opacity(0.35))
                        .frame(
                            width: max(1, geometry.halfJourneyWidth * 1.94),
                            height: 1.5
                        )
                        .position(x: geometry.centerX, y: lineY)
                        .accessibilityHidden(true)

                    if hasCollapsedHistory {
                        connector(
                            from: geometry.collapsedX(isFuture: false),
                            to: geometry.nodeX(
                                index: visibleStart,
                                currentIndex: currentIndex
                            ),
                            y: lineY,
                            color: accent.opacity(0.18),
                            height: 2.0
                        )
                    }

                    ForEach(visibleIndices.dropLast(), id: \.self) { index in
                        let isCurrentToNext = index == currentIndex
                        let connectorStart = geometry.nodeX(
                            index: index,
                            currentIndex: currentIndex
                        )
                        let connectorEnd = geometry.nodeX(
                            index: index + 1,
                            currentIndex: currentIndex
                        )
                        let connectorTint = connectorColor(
                            after: index,
                            currentIndex: currentIndex
                        )
                        let connectorHeight: CGFloat = isCurrentToNext
                            ? (presentation == .hero ? 4 : 3)
                            : (index < currentIndex ? 2.25 : 1.5)

                        connector(
                            from: connectorStart,
                            to: connectorEnd,
                            y: lineY,
                            color: connectorTint,
                            height: connectorHeight
                        )
                    }

                    if hasCollapsedFuture {
                        connector(
                            from: geometry.nodeX(
                                index: visibleEnd,
                                currentIndex: currentIndex
                            ),
                            to: geometry.collapsedX(isFuture: true),
                            y: lineY,
                            color: Color.ppSeparator.opacity(0.62),
                            height: 1.5
                        )
                    }

                    if !reduceMotion,
                       currentIndex < visibleEnd {
                        travelPulse(
                            from: geometry.nodeX(
                                index: currentIndex,
                                currentIndex: currentIndex
                            ),
                            to: geometry.nodeX(
                                index: currentIndex + 1,
                                currentIndex: currentIndex
                            ),
                            y: lineY
                        )
                    }

                    ForEach(visibleIndices, id: \.self) { stepIndex in
                        node(
                            step: Self.journeySteps[stepIndex],
                            isActive: stepIndex == currentIndex,
                            isCompleted: stepIndex < currentIndex,
                            visualDistance: abs(stepIndex - currentIndex)
                        )
                        .position(
                            x: geometry.nodeX(
                                index: stepIndex,
                                currentIndex: currentIndex
                            ),
                            y: lineY
                        )
                        .zIndex(stepIndex == currentIndex ? 5 : 2)
                    }

                    if hasCollapsedHistory {
                        clusterMarker
                            .position(
                                x: geometry.collapsedX(isFuture: false),
                                y: lineY
                            )
                    }

                    if hasCollapsedFuture {
                        clusterMarker
                            .position(
                                x: geometry.collapsedX(isFuture: true),
                                y: lineY
                            )
                    }
                }
                // Absolute placement must resolve in a physical coordinate
                // space. `RailGeometry.futureDirection` is the single owner of
                // journey direction, so this canvas stays left-to-right and RTL
                // is expressed by the geometry vector alone. Without this pin,
                // SwiftUI also mirrors every `position(x:)`, the two flips
                // cancel, and Arabic renders identically to English.
                .environment(\.layoutDirection, .leftToRight)
            }
            .frame(height: presentation.railHeight)

            footer(currentIndex: currentIndex)
        }
        .animation(
            reduceMotion
                ? nil
                : .spring(response: 0.58, dampingFraction: 0.84),
            value: currentIndex
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statusTitle)
        .accessibilityValue(
            "\(currentIndex + 1) of \(Self.journeySteps.count)"
        )
        .accessibilityHint(statusHint)
    }

    @ViewBuilder
    private func footer(currentIndex: Int) -> some View {
        if !updatedAtText.isEmpty || currentIndex < Self.journeySteps.count - 1 {
            HStack(spacing: 8) {
                if !updatedAtText.isEmpty {
                    Label(
                        updatedAtText,
                        systemImage: "clock.arrow.circlepath"
                    )
                    .font(footerTimeFont)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if currentIndex < Self.journeySteps.count - 1 {
                    let next = Self.journeySteps[currentIndex + 1]

                    HStack(spacing: 5) {
                        Text(resolvedTitle(for: next))
                            .font(footerNextStatusFont)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Image(systemName: isRTL ? "arrow.left" : "arrow.forward")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(accent)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
        }
    }

    private var exceptionRail: some View {
        VStack(spacing: 7) {
            GeometryReader { proxy in
                let centerX = proxy.size.width / 2
                let lineY = presentation.railHeight * 0.42

                ZStack {
                    Capsule()
                        .fill(Color.secondary.opacity(0.20))
                        .frame(height: 2)
                        .position(
                            x: proxy.size.width / 2,
                            y: lineY
                        )

                    activeNode(symbol: fallbackStatusSymbol)
                        .position(x: centerX, y: lineY)
                }
            }
            .frame(height: presentation.railHeight)

            if !updatedAtText.isEmpty {
                Label(
                    updatedAtText,
                    systemImage: "clock.arrow.circlepath"
                )
                .font(footerTimeFont)
                .foregroundStyle(.secondary)
                // `.leading` already resolves to the right edge under the
                // resolved RTL environment. Selecting `.trailing` for Arabic
                // mirrored an already-mirrored alignment and pushed the
                // timestamp to the physical left.
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statusTitle)
        .accessibilityValue(statusHint)
    }

    private func connectorColor(
        after index: Int,
        currentIndex: Int
    ) -> Color {
        if index == currentIndex {
            return accent.opacity(0.28)
        }

        if index < currentIndex {
            return accent.opacity(index == currentIndex - 1 ? 0.26 : 0.15)
        }

        return Color.ppSeparator.opacity(0.78)
    }

    private func connector(
        from: CGFloat,
        to: CGFloat,
        y: CGFloat,
        color: Color,
        height: CGFloat
    ) -> some View {
        Capsule()
            .fill(color)
            .frame(
                width: max(1, abs(to - from)),
                height: height
            )
            .position(
                x: (from + to) / 2,
                y: y
            )
            .accessibilityHidden(true)
    }

    private func travelPulse(
        from: CGFloat,
        to: CGFloat,
        y: CGFloat
    ) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let totalPeriod: Double = 3.8
            let travelDuration: Double = 1.35
            let t = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: totalPeriod)

            let isTraveling = t < travelDuration
            let u = isTraveling ? t / travelDuration : 0.0

            // Smooth ease in-out curve for travel
            let smoothU = isTraveling
                ? (1.0 - cos(u * .pi)) / 2.0
                : 0.0

            let posX: CGFloat = isTraveling
                ? from + (to - from) * CGFloat(smoothU)
                : from

            let opacity: CGFloat = {
                guard isTraveling else { return 0.0 }
                if u < 0.15 {
                    return CGFloat(u / 0.15) * 0.92
                } else if u > 0.82 {
                    return CGFloat((1.0 - u) / 0.18) * 0.92
                } else {
                    return 0.92
                }
            }()

            let scale: CGFloat = {
                guard isTraveling else { return 0.7 }
                if u < 0.15 {
                    return 0.7 + CGFloat(u / 0.15) * 0.3
                } else if u > 0.82 {
                    return 1.0 - CGFloat((u - 0.82) / 0.18) * 0.3
                } else {
                    return 1.0
                }
            }()

            Circle()
                .fill(accent)
                .frame(
                    width: presentation == .hero ? 7 : 6,
                    height: presentation == .hero ? 7 : 6
                )
                .scaleEffect(scale)
                .opacity(opacity)
                .position(x: posX, y: y)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func node(
        step: JourneyStep,
        isActive: Bool,
        isCompleted: Bool,
        visualDistance: Int
    ) -> some View {
        if isActive {
            activeNode(symbol: step.symbol)
        } else {
            let diameter = compressedNodeDiameter(
                isCompleted: isCompleted,
                visualDistance: visualDistance
            )
            let iconSize = max(
                presentation == .hero ? 8 : 7.5,
                diameter * (isCompleted ? 0.40 : 0.36)
            )

            ZStack {
                Circle()
                    .fill(
                        isCompleted
                            ? accent.opacity(visualDistance == 1 ? 0.60 : 0.34)
                            : Color.ppSurfaceElevated.opacity(0.80)
                    )

                Circle()
                    .stroke(
                        isCompleted
                            ? accent.opacity(visualDistance == 1 ? 0.28 : 0.16)
                            : Color.ppSeparator.opacity(0.82),
                        lineWidth: 1
                    )

                Image(systemName: step.symbol)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(
                        isCompleted
                            ? Color.white.opacity(visualDistance == 1 ? 0.94 : 0.72)
                            : Color.ppTextSecondary.opacity(
                                visualDistance == 1 ? 0.68 : 0.46
                            )
                    )
                    // The canvas is pinned left-to-right for placement only.
                    // Glyphs keep the language direction so badge-bearing
                    // symbols still mirror in Arabic.
                    .environment(\.layoutDirection, resolvedLayoutDirection)
            }
            .frame(width: diameter, height: diameter)
            .opacity(isCompleted ? 1 : (visualDistance == 1 ? 0.72 : 0.52))
            .accessibilityHidden(true)
        }
    }

    private func compressedNodeDiameter(
        isCompleted: Bool,
        visualDistance: Int
    ) -> CGFloat {
        let scale: CGFloat

        if isCompleted {
            scale = visualDistance == 1 ? 0.78 : 0.56
        } else {
            scale = visualDistance == 1 ? 0.86 : 0.62
        }

        return presentation.neighborDiameter * scale
    }

    @ViewBuilder
    private func activeNode(symbol: String) -> some View {
        if reduceMotion {
            activeMembrane(symbol: symbol, phase: 0)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let phase = CGFloat(
                    t.truncatingRemainder(dividingBy: 3.6) / 3.6
                )

                activeMembrane(
                    symbol: symbol,
                    phase: phase
                )
            }
        }
    }

    private func activeMembrane(
        symbol: String,
        phase: CGFloat
    ) -> some View {
        ZStack {
            // Fill and stroke are drawn from one generated path, so the active
            // state has one true, center-locked membrane perimeter.
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let perimeter = OrderHandoffMembrane(phase: phase).path(in: rect)

                context.fill(
                    perimeter,
                    with: .color(accent.opacity(0.16))
                )
                context.stroke(
                    perimeter,
                    with: .color(accent.opacity(0.62)),
                    lineWidth: 1.25
                )
            }

            Image(systemName: symbol)
                .font(
                    .system(
                        size: presentation == .hero ? 17 : 14.5,
                        weight: .bold
                    )
                )
                .foregroundStyle(accent)
                // See `node(step:...)`: placement is pinned, glyphs are not.
                .environment(\.layoutDirection, resolvedLayoutDirection)
        }
        .frame(
            width: presentation.activeDiameter,
            height: presentation.activeDiameter
        )
        .shadow(
            color: accent.opacity(0.10),
            radius: 8,
            y: 3
        )
        .accessibilityHidden(true)
    }

    private var clusterMarker: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(Color.ppTextSecondary.opacity(0.42))
                    .frame(width: 3, height: 3)
            }
        }
        .padding(.horizontal, 3)
        .frame(
            width: presentation == .hero ? 18 : 16,
            height: presentation == .hero ? 18 : 16
        )
        .background(
            Color.ppSurfaceElevated.opacity(0.88),
            in: Circle()
        )
        .accessibilityHidden(true)
    }

    private func resolvedTitle(
        for step: JourneyStep
    ) -> String {
        titleForStep?(
            step.key,
            step.fallbackTitle
        ) ?? step.fallbackTitle
    }

    /// All physical x-coordinates derive from the inherited layout direction.
    /// The active index always resolves to `centerX`; RTL changes the sign of
    /// the journey vector rather than applying a mirrored transform to the view.
    private struct RailGeometry {
        let centerX: CGFloat
        let futureDirection: CGFloat
        let halfJourneyWidth: CGFloat
        let presentation: Presentation
        let visibleFutureCount: Int

        init(
            width: CGFloat,
            presentation: Presentation,
            layoutDirection: LayoutDirection
        ) {
            self.presentation = presentation
            self.futureDirection = layoutDirection == .rightToLeft ? -1 : 1
            self.centerX = width / 2

            let edgeMargin: CGFloat = presentation == .hero ? 12 : 8
            self.halfJourneyWidth = max(20, self.centerX - edgeMargin)
            self.visibleFutureCount = 2
        }

        func nodeX(index: Int, currentIndex: Int) -> CGFloat {
            if index == currentIndex {
                return centerX
            }

            if index < currentIndex {
                let historyDelta = currentIndex - index
                let offsetRatio: CGFloat
                if currentIndex == 1 {
                    // Single finished status: anchor it towards the outer history edge of the line
                    offsetRatio = 0.78
                } else if historyDelta == 1 {
                    // Immediate predecessor (most recent finished)
                    offsetRatio = 0.44
                } else if historyDelta == 2 {
                    // Prior finished step: anchors towards the outer history edge
                    offsetRatio = 0.82
                } else {
                    offsetRatio = 0.94
                }
                let offset = halfJourneyWidth * offsetRatio
                return centerX - futureDirection * min(offset, halfJourneyWidth)
            } else {
                let futureDelta = index - currentIndex
                let offsetRatio: CGFloat
                if futureDelta == 1 {
                    // Next waiting/upcoming target
                    offsetRatio = 0.50
                } else if futureDelta == 2 {
                    // Second waiting step: stretches towards the outer future edge
                    offsetRatio = 0.84
                } else {
                    offsetRatio = 0.94
                }
                let offset = halfJourneyWidth * offsetRatio
                return centerX + futureDirection * min(offset, halfJourneyWidth)
            }
        }

        func collapsedX(isFuture: Bool) -> CGFloat {
            let direction = isFuture ? futureDirection : -futureDirection
            return centerX + direction * (halfJourneyWidth * 0.96)
        }
    }
}

// MARK: - Living current-state membrane

@available(iOS 17.0, *)
private struct OrderHandoffMembrane: Shape {
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(
            x: rect.midX,
            y: rect.midY
        )

        let baseRadius = min(
            rect.width,
            rect.height
        ) * 0.46

        let samples = 64

        var points: [CGPoint] = []
        points.reserveCapacity(samples)

        for index in 0..<samples {
            let angle = (
                CGFloat(index)
                / CGFloat(samples)
            ) * .pi * 2

            // Organic soap-bubble membrane deformation. These broad lobes are
            // intentionally legible at the rendered 42–50pt active size.
            let waveA = sin(
                angle * 3
                + phase * .pi * 2
            ) * 0.055

            // A smaller counter-wave keeps the single perimeter alive without
            // making the state read as a separate decorative halo.
            let waveB = sin(
                angle * 5
                - phase * .pi * 2 * 0.65
            ) * 0.020

            let radius = baseRadius
                * (1 + waveA + waveB)

            points.append(
                CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
            )
        }

        var path = Path()
        guard points.count > 3 else {
            path.addEllipse(in: rect)
            return path
        }

        // Smooth closed Catmull-Rom-like curve using midpoint quadratic segments.
        let first = midpoint(
            points[0],
            points[1]
        )

        path.move(to: first)

        for index in 1...points.count {
            let current = points[index % points.count]
            let next = points[(index + 1) % points.count]
            let end = midpoint(current, next)

            path.addQuadCurve(
                to: end,
                control: current
            )
        }

        path.closeSubpath()
        return path
    }

    private func midpoint(
        _ a: CGPoint,
        _ b: CGPoint
    ) -> CGPoint {
        CGPoint(
            x: (a.x + b.x) / 2,
            y: (a.y + b.y) / 2
        )
    }
}
