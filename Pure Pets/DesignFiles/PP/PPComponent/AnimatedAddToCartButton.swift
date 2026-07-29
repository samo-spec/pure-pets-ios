import SwiftUI
import UIKit

private enum AddToCartFlightAnchor: Hashable {
    case addIcon
    case cart
}

private struct AddToCartFlightAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [AddToCartFlightAnchor: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [AddToCartFlightAnchor: Anchor<CGRect>],
        nextValue: () -> [AddToCartFlightAnchor: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

public struct AnimatedAddToCartOutcome: Equatable {
    public let cartCount: Int
    public let addedQuantity: Int

    public init(cartCount: Int, addedQuantity: Int) {
        self.cartCount = max(0, cartCount)
        self.addedQuantity = max(0, addedQuantity)
    }
}

/// A production-ready add-to-cart control with an async-safe, causal success animation.
///
/// The supplied action returns the authoritative cart quantity. The button keeps the
/// previous quantity visible while work is in flight, then updates it when the item
/// visually lands in the cart.
public struct AnimatedAddToCartButton: View {
    @Binding private var cartCount: Int

    private let title: String
    private let addingTitle: String
    private let addedTitle: String
    private let retryTitle: String
    private let tint: Color
    private let itemSymbol: String
    private let isEnabled: Bool
    private let onCartTap: (() -> Void)?
    private let onAdd: @MainActor () async throws -> AnimatedAddToCartOutcome

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var phase: Phase = .idle
    @State private var displayedCount: Int
    @State private var flightProgress: CGFloat = 0
    @State private var cartImpact: CGFloat = 0
    @State private var badgeScale: CGFloat = 1
    @State private var lastAddedQuantity = 0
    @State private var actionTask: Task<Void, Never>?

    public init(
        cartCount: Binding<Int>,
        title: String = "Add to Cart",
        addingTitle: String = "Adding…",
        addedTitle: String = "Added",
        retryTitle: String = "Try Again",
        tint: Color = .ppPrimary,
        itemSymbol: String = "shippingbox.fill",
        isEnabled: Bool = true,
        onCartTap: (() -> Void)? = nil,
        onAdd: @escaping @MainActor () async throws -> AnimatedAddToCartOutcome
    ) {
        self._cartCount = cartCount
        self.title = title
        self.addingTitle = addingTitle
        self.addedTitle = addedTitle
        self.retryTitle = retryTitle
        self.tint = tint
        self.itemSymbol = itemSymbol
        self.isEnabled = isEnabled
        self.onCartTap = onCartTap
        self.onAdd = onAdd
        self._displayedCount = State(initialValue: max(0, cartCount.wrappedValue))
    }

    private let buttonShape = RoundedRectangle(
        cornerRadius: 22,
        style: .continuous
    )

    public var body: some View {
        HStack(spacing: 10) {
            Button(action: beginAdd) {
                ZStack {
                    buttonShape
                        .fill(buttonColor)

                    buttonShape
                        .strokeBorder(
                            buttonForeground.opacity(isEnabled ? 0.14 : 0.08),
                            lineWidth: 1
                        )

                    HStack(spacing: 12) {
                        leadingStatus

                        Text(currentTitle)
                            .font(PPAccessoryTypography.bodyBold)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                            .layoutPriority(1)

                        Spacer(minLength: 8)
                    }
                    .foregroundStyle(buttonForeground)
                    .padding(.horizontal, 14)
                }
                .frame(minHeight: 52)
                .contentShape(buttonShape)
            }
            .buttonStyle(CartPressStyle(reduceMotion: reduceMotion))
            .disabled(!isEnabled || phase.locksInteraction)
            .accessibilityLabel(currentTitle)
            .accessibilityHint(accessibilityHint)

            cartButton
        }
        .padding(.trailing, 2)
        .overlayPreferenceValue(AddToCartFlightAnchorPreferenceKey.self) { anchors in
            GeometryReader { proxy in
                flightLayer(
                    in: proxy.size,
                    anchors: anchors,
                    proxy: proxy
                )
            }
            .allowsHitTesting(false)
        }
        .onChange(of: cartCount) { newCount in
            guard !phase.locksInteraction else { return }
            displayedCount = max(0, newCount)
        }
        .onDisappear {
            actionTask?.cancel()
            actionTask = nil
        }
    }

    @ViewBuilder
    private var cartButton: some View {
        if #available(iOS 26.0, *) {
            ZStack(alignment: .topTrailing) {
                PPAccessoryGlassButtonRepresentable(
                    symbol: "cart.fill",
                    tint: isEnabled ? tint : Color.ppTextSecondary,
                    action: { onCartTap?() }
                )
                .frame(width: 52, height: 52)
                .scaleEffect(
                    x: 1 + (0.06 * cartImpact),
                    y: 1 - (0.12 * cartImpact),
                    anchor: .center
                )
                .rotationEffect(
                    .degrees(Double(-3 * direction * cartImpact))
                )
                .offset(x: 3 * direction * cartImpact)
                .anchorPreference(
                    key: AddToCartFlightAnchorPreferenceKey.self,
                    value: .bounds
                ) { anchor in
                    [.cart: anchor]
                }

                if displayedCount > 0 {
                    Text(PPAccessoryViewerL10n.integer(displayedCount))
                        .font(PPAccessoryTypography.captionBold)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(
                            Capsule(style: .continuous)
                                .fill(tint)
                        )
                        .scaleEffect(badgeScale)
                        .offset(x: 6 * direction, y: -6)
                        .transition(.scale(scale: 0.55).combined(with: .opacity))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(PPAccessoryViewerL10n.text("accessory_view_open_cart"))
        } else {
            Button(action: {
                onCartTap?()
            }) {
                cartIndicator
            }
            .buttonStyle(CartPressStyle(reduceMotion: reduceMotion))
            .disabled(!isEnabled && onCartTap == nil)
        }
    }

    private var leadingStatus: some View {
        ZStack {
            Circle()
                .fill(buttonForeground.opacity(isEnabled ? 0.15 : 0.08))

            switch phase {
            case .idle:
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))

            case .processing, .flying:
                ProgressView()
                    .controlSize(.small)
                    .tint(buttonForeground)

            case .success:
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))

            case .failure:
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .bold))
            }
        }
        .frame(width: 32, height: 32)
        .anchorPreference(
            key: AddToCartFlightAnchorPreferenceKey.self,
            value: .bounds
        ) { anchor in
            [.addIcon: anchor]
        }
        .accessibilityHidden(true)
    }

    private var cartIndicator: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                Image(systemName: "cart.fill")
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(width: 52, height: 52)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            .foregroundStyle(isEnabled ? tint : Color.ppTextSecondary)
            .scaleEffect(
                x: 1 + (0.06 * cartImpact),
                y: 1 - (0.12 * cartImpact),
                anchor: .center
            )
            .rotationEffect(
                .degrees(Double(-3 * direction * cartImpact))
            )
            .offset(x: 3 * direction * cartImpact)
            .anchorPreference(
                key: AddToCartFlightAnchorPreferenceKey.self,
                value: .bounds
            ) { anchor in
                [.cart: anchor]
            }

            if displayedCount > 0 {
                Text(PPAccessoryViewerL10n.integer(displayedCount))
                    .font(PPAccessoryTypography.captionBold)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(
                        Capsule(style: .continuous)
                            .fill(tint)
                    )
                    .scaleEffect(badgeScale)
                    .offset(x: 6 * direction, y: -6)
                    .transition(.scale(scale: 0.55).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(PPAccessoryViewerL10n.text("accessory_view_open_cart"))
    }

    @ViewBuilder
    private func flightLayer(
        in size: CGSize,
        anchors: [AddToCartFlightAnchor: Anchor<CGRect>],
        proxy: GeometryProxy
    ) -> some View {
        if phase == .flying {
            let progress = max(0, min(1, flightProgress))
            let startPoint = flightPoint(
                for: anchors[.addIcon],
                fallback: fallbackPoint(leading: 34, vertical: size.height / 2, in: size.width),
                proxy: proxy
            )
            let endPoint = flightPoint(
                for: anchors[.cart],
                fallback: fallbackPoint(leading: size.width - 34, vertical: size.height / 2, in: size.width),
                proxy: proxy
            )

            let startLeading = leadingOffset(for: startPoint, in: size.width)
            let endLeading = leadingOffset(for: endPoint, in: size.width)

            let currentLeading = startLeading + ((endLeading - startLeading) * progress)
            let baselineY = startPoint.y + ((endPoint.y - startPoint.y) * progress)
            let arc = CGFloat(sin(Double(progress) * .pi)) * min(22, size.height * 0.34)
            let y = baselineY - arc

            let currentPoint = pointFromLeading(currentLeading, vertical: y, in: size.width)
            let fade = progress < 0.82
                ? CGFloat(1)
                : max(0, 1 - ((progress - 0.82) / 0.18))

            ZStack {
                Circle()
                    .fill(Color.white)

                Image(systemName: itemSymbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 30, height: 30)
            .scaleEffect(1 - (0.12 * progress))
            .rotationEffect(.degrees(Double(progress * 18 * direction)))
            .position(currentPoint)
            .opacity(Double(fade))
            .accessibilityHidden(true)
        }
    }

    private var currentTitle: String {
        switch phase {
        case .idle:
            title
        case .processing, .flying:
            addingTitle
        case .success:
            lastAddedQuantity > 0
                ? PPAccessoryViewerL10n.formatted(
                    "accessory_view_added_quantity_format",
                    PPAccessoryViewerL10n.integer(lastAddedQuantity)
                )
                : addedTitle
        case .failure:
            retryTitle
        }
    }

    private var accessibilityHint: Text {
        if !isEnabled {
            return Text(
                PPAccessoryViewerL10n.text(
                    "accessory_view_item_unavailable"
                )
            )
        }

        if phase == .failure {
            return Text(
                PPAccessoryViewerL10n.text(
                    "accessory_view_add_retry_hint"
                )
            )
        }

        return Text(
            PPAccessoryViewerL10n.text(
                "accessory_view_add_to_cart_hint"
            )
        )
    }

    private var buttonColor: Color {
        guard isEnabled else {
            return Color.ppTextSecondary.opacity(0.34)
        }

        if phase == .failure {
            return Color.ppError
        }

        return tint
    }

    private var buttonForeground: Color {
        isEnabled ? .white : Color.ppTextSecondary
    }

    private var badgeBackground: Color {
        isEnabled ? .white : Color.ppForeground
    }

    private var badgeForeground: Color {
        isEnabled ? buttonColor : Color.ppTextSecondary
    }

    private var isRightToLeft: Bool {
        layoutDirection == .rightToLeft || Language.isRTL()
    }

    private var direction: CGFloat {
        isRightToLeft ? -1 : 1
    }

    private func leadingOffset(for point: CGPoint, in width: CGFloat) -> CGFloat {
        isRightToLeft ? (width - point.x) : point.x
    }

    private func pointFromLeading(_ leading: CGFloat, vertical: CGFloat, in width: CGFloat) -> CGPoint {
        CGPoint(
            x: isRightToLeft ? (width - leading) : leading,
            y: vertical
        )
    }

    private func fallbackPoint(leading: CGFloat, vertical: CGFloat, in width: CGFloat) -> CGPoint {
        pointFromLeading(leading, vertical: vertical, in: width)
    }

    private func flightPoint(
        for anchor: Anchor<CGRect>?,
        fallback: CGPoint,
        proxy: GeometryProxy
    ) -> CGPoint {
        guard let anchor else {
            return fallback
        }

        let rect = proxy[anchor]
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    private func beginAdd() {
        guard isEnabled, !phase.locksInteraction else { return }

        actionTask?.cancel()
        actionTask = Task { @MainActor in
            resetMotion()

            withAnimation(.easeOut(duration: 0.16)) {
                phase = .processing
            }

            do {
                let outcome = try await onAdd()
                try Task.checkCancellation()
                lastAddedQuantity = outcome.addedQuantity

                if reduceMotion {
                    try await playReducedSuccess(outcome: outcome)
                } else {
                    try await playCausalSuccess(outcome: outcome)
                }
            } catch is CancellationError {
                resetMotion()
                phase = .idle
            } catch {
                withAnimation(
                    reduceMotion ? nil : .easeOut(duration: 0.18)
                ) {
                    phase = .failure
                }

                UIAccessibility.post(
                    notification: .announcement,
                    argument: PPAccessoryViewerL10n.text(
                        "accessory_view_add_failure_announcement"
                    )
                )
            }
        }
    }

    @MainActor
    private func playCausalSuccess(
        outcome: AnimatedAddToCartOutcome
    ) async throws {
        let newCount = outcome.cartCount
        flightProgress = 0
        phase = .flying
        cartCount = newCount

        withAnimation(
            .timingCurve(0.20, 0.78, 0.18, 1, duration: 0.78)
        ) {
            flightProgress = 1
        }

        try await sleep(milliseconds: 620)

        withAnimation(.easeIn(duration: 0.18)) {
            cartImpact = 1
            badgeScale = 0.86
        }

        try await sleep(milliseconds: 160)

        withAnimation(
            .interpolatingSpring(
                mass: 0.75,
                stiffness: 220,
                damping: 18,
                initialVelocity: 0
            )
        ) {
            displayedCount = newCount
            phase = .success
            cartImpact = 0
            badgeScale = 1.18
        }

        announceSuccess(outcome: outcome)

        try await sleep(milliseconds: 240)

        withAnimation(
            .interpolatingSpring(
                mass: 0.65,
                stiffness: 240,
                damping: 20,
                initialVelocity: 0
            )
        ) {
            badgeScale = 1
        }

        try await sleep(milliseconds: 1100)

        withAnimation(.easeOut(duration: 0.32)) {
            displayedCount = max(0, cartCount)
            phase = .idle
        }

        resetMotion()
    }

    @MainActor
    private func playReducedSuccess(
        outcome: AnimatedAddToCartOutcome
    ) async throws {
        let newCount = outcome.cartCount
        cartCount = newCount

        withAnimation(.easeOut(duration: 0.16)) {
            displayedCount = newCount
            phase = .success
        }

        announceSuccess(outcome: outcome)

        try await sleep(milliseconds: 700)

        withAnimation(.easeOut(duration: 0.16)) {
            displayedCount = max(0, cartCount)
            phase = .idle
        }
    }

    @MainActor
    private func announceSuccess(outcome: AnimatedAddToCartOutcome) {
        let announcement = PPAccessoryViewerL10n.formatted(
            "accessory_view_added_announcement_format",
            PPAccessoryViewerL10n.integer(outcome.addedQuantity),
            PPAccessoryViewerL10n.integer(outcome.cartCount)
        )

        UIAccessibility.post(
            notification: .announcement,
            argument: announcement
        )
    }

    @MainActor
    private func resetMotion() {
        flightProgress = 0
        cartImpact = 0
        badgeScale = 1
    }

    private func sleep(milliseconds: UInt64) async throws {
        try await Task<Never, Never>.sleep(
            nanoseconds: milliseconds * 1_000_000
        )
    }

    private enum Phase: Equatable {
        case idle
        case processing
        case flying
        case success
        case failure

        var locksInteraction: Bool {
            switch self {
            case .processing, .flying, .success:
                true
            case .idle, .failure:
                false
            }
        }
    }
}

private struct CartPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && !reduceMotion ? 0.985 : 1
            )
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}
