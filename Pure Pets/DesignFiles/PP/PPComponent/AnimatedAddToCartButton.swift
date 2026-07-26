import SwiftUI
import UIKit

/// A production-ready add-to-cart control with an async-safe, causal success animation.
///
/// The supplied action returns the authoritative cart quantity. The button keeps the
/// previous quantity visible while work is in flight, then updates it when the item
/// visually lands in the cart.
public struct AnimatedAddToCartButton: View {
    @Binding private var cartCount: Int

    private let title: LocalizedStringKey
    private let addingTitle: LocalizedStringKey
    private let addedTitle: LocalizedStringKey
    private let retryTitle: LocalizedStringKey
    private let tint: Color
    private let itemSymbol: String
    private let isEnabled: Bool
    private let onCartTap: (() -> Void)?
    private let onAdd: @MainActor () async throws -> Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var phase: Phase = .idle
    @State private var displayedCount: Int
    @State private var flightProgress: CGFloat = 0
    @State private var cartImpact: CGFloat = 0
    @State private var badgeScale: CGFloat = 1
    @State private var actionTask: Task<Void, Never>?

    public init(
        cartCount: Binding<Int>,
        title: LocalizedStringKey = "Add to Cart",
        addingTitle: LocalizedStringKey = "Adding…",
        addedTitle: LocalizedStringKey = "Added",
        retryTitle: LocalizedStringKey = "Try Again",
        tint: Color = .ppPrimary,
        itemSymbol: String = "shippingbox.fill",
        isEnabled: Bool = true,
        onCartTap: (() -> Void)? = nil,
        onAdd: @escaping @MainActor () async throws -> Int
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
        ZStack {
            buttonShape
                .fill(buttonColor)

            buttonShape
                .strokeBorder(
                    buttonForeground.opacity(isEnabled ? 0.14 : 0.08),
                    lineWidth: 1
                )

            HStack(spacing: 0) {
                Button(action: beginAdd) {
                    HStack(spacing: 12) {
                        leadingStatus

                        Text(currentTitle)
                            .font(PPAccessoryTypography.bodyBold)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .layoutPriority(1)

                        Spacer(minLength: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(CartPressStyle(reduceMotion: reduceMotion))
                .disabled(!isEnabled || phase.locksInteraction)

                if let onCartTap {
                    Button(action: onCartTap) {
                        cartIndicator
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(CartPressStyle(reduceMotion: reduceMotion))
                    .disabled(false)
                    .accessibilityLabel(PPAccessoryViewerL10n.text("accessory_view_open_cart"))
                } else {
                    Button(action: beginAdd) {
                        cartIndicator
                    }
                    .buttonStyle(CartPressStyle(reduceMotion: reduceMotion))
                    .disabled(false)
                }
            }
            .foregroundStyle(buttonForeground)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(minHeight: 62)
        .contentShape(buttonShape)
        .overlay {
            GeometryReader { proxy in
                flightLayer(in: proxy.size)
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
        .accessibilityHidden(true)
    }

    private var cartIndicator: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                Image(systemName: "cart.fill")
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(buttonForeground.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(buttonForeground.opacity(0.28), lineWidth: 1)
            )
            .scaleEffect(
                x: 1 + (0.06 * cartImpact),
                y: 1 - (0.12 * cartImpact),
                anchor: .center
            )
            .rotationEffect(
                .degrees(Double(-3 * direction * cartImpact))
            )
            .offset(x: 3 * direction * cartImpact)

            if displayedCount > 0 {
                Text(String(format: "%d", displayedCount))
                    .font(PPAccessoryTypography.captionBold)
                    .monospacedDigit()
                    .environment(\.locale, Locale(identifier: "en_US"))
                    .foregroundStyle(badgeForeground)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(
                        Capsule(style: .continuous)
                            .fill(badgeBackground)
                    )
                    .scaleEffect(badgeScale)
                    .offset(x: 6, y: -6)
                    .transition(.scale(scale: 0.55).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(PPAccessoryViewerL10n.text("accessory_view_open_cart"))
    }

    @ViewBuilder
    private func flightLayer(in size: CGSize) -> some View {
        if phase == .flying {
            let progress = max(0, min(1, flightProgress))
            let startX: CGFloat = layoutDirection == .rightToLeft
                ? size.width - 34
                : 34
            let endX: CGFloat = layoutDirection == .rightToLeft
                ? 34
                : size.width - 34
            let arc = CGFloat(sin(Double(progress) * .pi)) * min(22, size.height * 0.34)
            let x = startX + ((endX - startX) * progress)
            let y = (size.height / 2) - arc
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
            .position(x: x, y: y)
            .opacity(Double(fade))
            .accessibilityHidden(true)
        }
    }

    private var currentTitle: LocalizedStringKey {
        switch phase {
        case .idle:
            title
        case .processing, .flying:
            addingTitle
        case .success:
            addedTitle
        case .failure:
            retryTitle
        }
    }

    private var accessibilityHint: Text {
        if !isEnabled {
            return Text("This item is currently unavailable.")
        }

        if phase == .failure {
            return Text("Retries adding this item to the cart.")
        }

        return Text("Adds this item to the cart.")
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

    private var direction: CGFloat {
        layoutDirection == .rightToLeft ? -1 : 1
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
                let newCount = max(0, try await onAdd())
                try Task.checkCancellation()

                if reduceMotion {
                    try await playReducedSuccess(newCount: newCount)
                } else {
                    try await playCausalSuccess(newCount: newCount)
                }
            } catch is CancellationError {
                resetMotion()
                phase = .idle
            } catch {
                withAnimation(.easeOut(duration: 0.18)) {
                    phase = .failure
                }

                UINotificationFeedbackGenerator()
                    .notificationOccurred(.error)

                UIAccessibility.post(
                    notification: .announcement,
                    argument: NSLocalizedString(
                        "Couldn’t add this item. Double-tap to retry.",
                        comment: "Add-to-cart failure announcement"
                    )
                )
            }
        }
    }

    @MainActor
    private func playCausalSuccess(newCount: Int) async throws {
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

        announceSuccess(count: newCount)

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
    private func playReducedSuccess(newCount: Int) async throws {
        cartCount = newCount

        withAnimation(.easeOut(duration: 0.16)) {
            displayedCount = newCount
            phase = .success
        }

        announceSuccess(count: newCount)

        try await sleep(milliseconds: 700)

        withAnimation(.easeOut(duration: 0.16)) {
            displayedCount = max(0, cartCount)
            phase = .idle
        }
    }

    @MainActor
    private func announceSuccess(count: Int) {
        UINotificationFeedbackGenerator()
            .notificationOccurred(.success)

        let format = NSLocalizedString(
            "Added to cart. Cart quantity %lld.",
            comment: "Add-to-cart success announcement"
        )

        UIAccessibility.post(
            notification: .announcement,
            argument: String.localizedStringWithFormat(format, Int64(count))
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

#if DEBUG
private struct AnimatedAddToCartButtonDemo: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 18) {
            AnimatedAddToCartButton(cartCount: $count) {
                try await Task<Never, Never>.sleep(
                    nanoseconds: 550_000_000
                )
                return count + 1
            }

            Text("Cart quantity: \(count)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct AnimatedAddToCartButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AnimatedAddToCartButtonDemo()
                .preferredColorScheme(.light)

            AnimatedAddToCartButtonDemo()
                .preferredColorScheme(.dark)

            AnimatedAddToCartButtonDemo()
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
