import SwiftUI
import UIKit

private enum AddToCartFlightAnchor: Hashable {
    case addIcon
    case cart
    case quantityIncrease
    case quantityStatus
    case quantityDecrease
}

private enum CartQuantityDirection: Equatable {
    case none
    case increase
    case decrease
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
/// visually lands in the cart. Supplying ``QuantityMode`` turns the same owner into
/// the signature add → confirmation → quantity control while preserving the
/// caller's cart state and business logic.
public struct AnimatedAddToCartButton: View {
    /// Optional externally-owned quantity state for the signature one-control flow.
    ///
    /// The component never mutates cart or inventory state directly. Each action
    /// emits an intent, and the caller updates `quantity` from its authoritative
    /// store. A value of zero shows the add state; a positive value shows the
    /// quantity state.
    public struct QuantityMode {
        fileprivate let quantity: Binding<Int>
        fileprivate let minimumQuantity: Int
        fileprivate let maximumQuantity: Int
        fileprivate let inCartTitle: String
        fileprivate let quantityAccessibilityValue: (Int) -> String
        fileprivate let increaseAccessibilityLabel: String
        fileprivate let decreaseAccessibilityLabel: String
        fileprivate let removeAccessibilityLabel: String
        fileprivate let isEnabled: Bool
        fileprivate let canRemove: Bool
        fileprivate let controlHeight: CGFloat
        fileprivate let onIncrement: @MainActor () -> Void
        fileprivate let onDecrement: @MainActor () -> Void
        fileprivate let onRemove: @MainActor () -> Void

        public init(
            quantity: Binding<Int>,
            minimumQuantity: Int = 1,
            maximumQuantity: Int = 99,
            inCartTitle: String,
            quantityAccessibilityValue: @escaping (Int) -> String,
            increaseAccessibilityLabel: String,
            decreaseAccessibilityLabel: String,
            removeAccessibilityLabel: String,
            isEnabled: Bool = true,
            canRemove: Bool = true,
            controlHeight: CGFloat = 44,
            onIncrement: @escaping @MainActor () -> Void,
            onDecrement: @escaping @MainActor () -> Void,
            onRemove: @escaping @MainActor () -> Void
        ) {
            let safeMinimum = max(1, minimumQuantity)

            self.quantity = quantity
            self.minimumQuantity = safeMinimum
            self.maximumQuantity = max(safeMinimum, maximumQuantity)
            self.inCartTitle = inCartTitle
            self.quantityAccessibilityValue = quantityAccessibilityValue
            self.increaseAccessibilityLabel = increaseAccessibilityLabel
            self.decreaseAccessibilityLabel = decreaseAccessibilityLabel
            self.removeAccessibilityLabel = removeAccessibilityLabel
            self.isEnabled = isEnabled
            self.canRemove = canRemove
            self.controlHeight = max(36, controlHeight)
            self.onIncrement = onIncrement
            self.onDecrement = onDecrement
            self.onRemove = onRemove
        }
    }

    @Binding private var cartCount: Int

    private let title: String
    private let addingTitle: String
    private let addedTitle: String
    private let retryTitle: String
    private let tint: Color
    private let itemSymbol: String
    private let isEnabled: Bool
    private let onCartTap: (() -> Void)?
    private let quantityMode: QuantityMode?
    private let onAdd: @MainActor () async throws -> AnimatedAddToCartOutcome

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var phase: Phase = .idle
    @State private var displayedCount: Int
    @State private var flightProgress: CGFloat = 0
    @State private var cartImpact: CGFloat = 0
    @State private var badgeScale: CGFloat = 1
    @State private var lastAddedQuantity = 0
    @State private var actionTask: Task<Void, Never>?
    @State private var displayedQuantity: Int
    @State private var quantityDirection: CartQuantityDirection = .none
    @State private var quantityFlightProgress: CGFloat = 0
    @State private var quantityImpact: CGFloat = 0
    @State private var quantityImpulseID = 0
    @State private var showsQuantityFlight = false
    @State private var quantityMotionTask: Task<Void, Never>?

    private let cornerRadius: CGFloat

    public init(
        cartCount: Binding<Int>,
        title: String = "Add to Cart",
        addingTitle: String = "Adding…",
        addedTitle: String = "Added",
        retryTitle: String = "Try Again",
        tint: Color = .ppPrimary,
        itemSymbol: String = "shippingbox.fill",
        isEnabled: Bool = true,
        cornerRadius: CGFloat = 13,
        onCartTap: (() -> Void)? = nil,
        quantityMode: QuantityMode? = nil,
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
        self.cornerRadius = cornerRadius
        self.onCartTap = onCartTap
        self.quantityMode = quantityMode
        self.onAdd = onAdd
        self._displayedCount = State(initialValue: max(0, cartCount.wrappedValue))
        self._displayedQuantity = State(
            initialValue: max(0, quantityMode?.quantity.wrappedValue ?? 0)
        )
    }

    private var buttonShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: cornerRadius,
            style: .continuous
        )
    }

    public var body: some View {
        ZStack {
            if quantityMode != nil {
                signatureQuantityAction
            } else {
                legacyAddControl
            }
        }
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.16)
                : .interpolatingSpring(
                    mass: 0.72,
                    stiffness: 230,
                    damping: 22,
                    initialVelocity: 0
                ),
            value: showsQuantityControl
        )
        .overlayPreferenceValue(AddToCartFlightAnchorPreferenceKey.self) { anchors in
            GeometryReader { proxy in
                ZStack {
                    flightLayer(
                        in: proxy.size,
                        anchors: anchors,
                        proxy: proxy
                    )

                    quantityFlightLayer(
                        in: proxy.size,
                        anchors: anchors,
                        proxy: proxy
                    )
                }
            }
            .allowsHitTesting(false)
        }
        .onChange(of: cartCount) { newCount in
            guard !phase.locksInteraction else { return }
            displayedCount = max(0, newCount)
        }
        .onChange(of: authoritativeQuantity) { newQuantity in
            handleQuantityChange(newQuantity)
        }
        .onAppear {
            displayedQuantity = authoritativeQuantity
        }
        .onDisappear {
            actionTask?.cancel()
            actionTask = nil
            quantityMotionTask?.cancel()
            quantityMotionTask = nil
        }
    }

    private var signatureQuantityAction: some View {
        ZStack {
            primaryAddButton(signature: true)
                .opacity(showsQuantityControl ? 0 : 1)
                .allowsHitTesting(!showsQuantityControl)
                .accessibilityHidden(showsQuantityControl)
                .zIndex(showsQuantityControl ? 0 : 1)

            quantityControl
                .opacity(showsQuantityControl ? 1 : 0)
                .allowsHitTesting(showsQuantityControl)
                .accessibilityHidden(!showsQuantityControl)
                .zIndex(showsQuantityControl ? 1 : 0)
        }
    }

    private var legacyAddControl: some View {
        HStack(spacing: 10) {
            primaryAddButton(signature: false)

            cartButton
        }
        .padding(.trailing, 2)
    }

    private func primaryAddButton(signature: Bool) -> some View {
        Button(action: beginAdd) {
            ZStack {
                buttonShape
                    .fill(buttonColor)

                buttonShape
                    .strokeBorder(
                        buttonForeground.opacity(isEnabled ? 0.16 : 0.08),
                        lineWidth: 1
                    )

                HStack(spacing: PPSpace.md) {
                    leadingStatus

                    Text(currentTitle)
                        .font(PPAccessoryTypography.bodyBold)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .layoutPriority(1)

                    if !signature {
                        Spacer(minLength: PPSpace.sm)
                    }
                }
                .foregroundStyle(buttonForeground)
                .padding(.horizontal, signature ? PPSpace.lg : 14)
            }
            .frame(
                maxWidth: signature ? .infinity : nil,
                minHeight: signature ? signatureControlHeight : 52
            )
            .contentShape(buttonShape)
        }
        .buttonStyle(CartPressStyle(reduceMotion: reduceMotion))
        .disabled(!isEnabled || phase.locksInteraction)
        .shadow(
            color: signature && isEnabled
                ? tint.opacity(colorScheme == .dark ? 0.22 : 0.18)
                : .clear,
            radius: signature
                ? (usesCompactSignatureControl ? 8 : 15)
                : 0,
            y: signature
                ? (usesCompactSignatureControl ? 4 : 8)
                : 0
        )
        .accessibilityLabel(currentTitle)
        .accessibilityHint(accessibilityHint)
    }

    private var authoritativeQuantity: Int {
        max(0, quantityMode?.quantity.wrappedValue ?? 0)
    }

    private var showsQuantityControl: Bool {
        quantityMode != nil &&
            authoritativeQuantity > 0 &&
            phase == .idle
    }

    private var signatureControlHeight: CGFloat {
        let preferredHeight = quantityMode?.controlHeight ?? 44
        let accessibilityMinimum: CGFloat = dynamicTypeSize.isAccessibilitySize
            ? 52
            : 36

        return max(preferredHeight, accessibilityMinimum)
    }

    private var quantityActionSize: CGFloat {
        signatureControlHeight
    }

    private var usesCompactSignatureControl: Bool {
        signatureControlHeight < 58
    }

    @ViewBuilder
    private var quantityControl: some View {
        if let quantityMode {
            let shape = RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )

            HStack(spacing: 0) {
                quantityActionButton(
                    isIncrease: true,
                    mode: quantityMode
                )

                quantityStatus(mode: quantityMode)

                quantityActionButton(
                    isIncrease: false,
                    mode: quantityMode
                )
            }
            .environment(\.layoutDirection, .leftToRight)
            .frame(maxWidth: .infinity, minHeight: signatureControlHeight)
            .background {
                ZStack {
                    shape.fill(Color.ppForeground)
                    shape.fill(
                        tint.opacity(colorScheme == .dark ? 0.16 : 0.075)
                    )
                }
            }
            .overlay {
                shape.strokeBorder(
                    tint.opacity(colorScheme == .dark ? 0.34 : 0.20),
                    lineWidth: 1.5
                )
            }
            .shadow(
                color: tint.opacity(colorScheme == .dark ? 0.14 : 0.11),
                radius: usesCompactSignatureControl ? 8 : 14,
                y: usesCompactSignatureControl ? 4 : 7
            )
            .contentShape(shape)
            .opacity(quantityMode.isEnabled ? 1 : 0.62)
        }
    }

    private func quantityActionButton(
        isIncrease: Bool,
        mode: QuantityMode
    ) -> some View {
        let isRemove = !isIncrease &&
            displayedQuantity <= mode.minimumQuantity
        let canIncrement = displayedQuantity < mode.maximumQuantity
        let canDecrease = displayedQuantity > mode.minimumQuantity ||
            mode.canRemove
        let isActionEnabled = mode.isEnabled &&
            (isIncrease ? canIncrement : canDecrease)
        let symbol = isIncrease
            ? "plus"
            : (isRemove ? "trash" : "minus")
        let accessibilityLabel = isIncrease
            ? mode.increaseAccessibilityLabel
            : (
                isRemove
                    ? mode.removeAccessibilityLabel
                    : mode.decreaseAccessibilityLabel
            )
        let anchorKey: AddToCartFlightAnchor = isIncrease
            ? .quantityIncrease
            : .quantityDecrease

        return Button {
            if isIncrease {
                performQuantityAction(
                    direction: .increase,
                    action: mode.onIncrement
                )
            } else if isRemove {
                performQuantityAction(
                    direction: .decrease,
                    action: mode.onRemove
                )
            } else {
                performQuantityAction(
                    direction: .decrease,
                    action: mode.onDecrement
                )
            }
        } label: {
            ZStack {
                Image(systemName: symbol)
                    .font(.system(size: isRemove ? 21 : 23, weight: .bold))
                    .id(symbol)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.5).combined(with: .opacity)
                    )
            }
            .frame(width: quantityActionSize, height: quantityActionSize)
            .foregroundStyle(isRemove ? Color.ppError : tint)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
            )
        }
        .buttonStyle(
            QuantityActionPressStyle(
                tint: isRemove ? Color.ppError : tint,
                reduceMotion: reduceMotion
            )
        )
        .disabled(!isActionEnabled)
        .opacity(isActionEnabled ? 1 : 0.38)
        .animation(
            reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.24),
            value: symbol
        )
        .anchorPreference(
            key: AddToCartFlightAnchorPreferenceKey.self,
            value: .bounds
        ) { anchor in
            [anchorKey: anchor]
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilitySortPriority(
            isRightToLeft
                ? (isIncrease ? 1 : 3)
                : (isIncrease ? 3 : 1)
        )
    }

    private func quantityStatus(mode: QuantityMode) -> some View {
        Group {
            if onCartTap != nil {
                Button {
                    onCartTap?()
                } label: {
                    quantityStatusLabel(mode: mode)
                }
                .buttonStyle(CartPressStyle(reduceMotion: reduceMotion))
            } else {
                quantityStatusLabel(mode: mode)
            }
        }
        .frame(maxWidth: .infinity, minHeight: quantityActionSize)
        .contentShape(Rectangle())
        .anchorPreference(
            key: AddToCartFlightAnchorPreferenceKey.self,
            value: .bounds
        ) { anchor in
            [.quantityStatus: anchor]
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mode.inCartTitle)
        .accessibilityValue(
            mode.quantityAccessibilityValue(displayedQuantity)
        )
        .accessibilitySortPriority(2)
        .accessibilityAdjustableAction { adjustment in
            guard mode.isEnabled else { return }

            switch adjustment {
            case .increment where displayedQuantity < mode.maximumQuantity:
                performQuantityAction(
                    direction: .increase,
                    action: mode.onIncrement
                )
            case .decrement where displayedQuantity > mode.minimumQuantity:
                performQuantityAction(
                    direction: .decrease,
                    action: mode.onDecrement
                )
            case .decrement where mode.canRemove:
                performQuantityAction(
                    direction: .decrease,
                    action: mode.onRemove
                )
            default:
                break
            }
        }
    }

    private func quantityStatusLabel(mode: QuantityMode) -> some View {
        ZStack {
            Text(PPAccessoryViewerL10n.integer(displayedQuantity))
                .font(
                    .custom(
                        "Beiruti-Bold",
                        size: 16,
                        relativeTo: .callout
                    )
                )
                .monospacedDigit()
                .id(displayedQuantity)
                .transition(quantityNumberTransition)
        }
        .padding(.horizontal, 8)
        .frame(minWidth: 28, minHeight: max(22, signatureControlHeight - 16))
        .background(
            Color.ppForeground,
            in: RoundedRectangle(
                cornerRadius: PPCorner.small,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PPCorner.small,
                style: .continuous
            )
            .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        }
        .clipped()
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(quantityNumberAnimation, value: displayedQuantity)
        .accessibilityHidden(true)
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
            if phase != .idle {
                Circle()
                    .fill(buttonForeground.opacity(isEnabled ? 0.15 : 0.08))
            }

            switch phase {
            case .idle:
                Image(systemName: quantityMode == nil ? "plus" : "cart")
                    .font(.system(size: 13, weight: .bold))

            case .processing, .flying:
                ProgressView()
                    .controlSize(.small)
                    .tint(buttonForeground)

            case .success:
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))

            case .failure:
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .bold))
            }
        }
        .frame(width: phase == .idle ? 20 : 32, height: phase == .idle ? 20 : 32)
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

    @ViewBuilder
    private func quantityFlightLayer(
        in size: CGSize,
        anchors: [AddToCartFlightAnchor: Anchor<CGRect>],
        proxy: GeometryProxy
    ) -> some View {
        if showsQuantityFlight,
           !reduceMotion,
           quantityDirection != .none {
            let progress = max(0, min(1, quantityFlightProgress))
            let isIncrease = quantityDirection == .increase
            let startAnchor = isIncrease
                ? anchors[.quantityIncrease]
                : anchors[.quantityStatus]
            let endAnchor = isIncrease
                ? anchors[.quantityStatus]
                : anchors[.quantityDecrease]
            let startFallback = CGPoint(
                x: isIncrease ? 31 : size.width / 2,
                y: size.height / 2
            )
            let endFallback = CGPoint(
                x: isIncrease ? size.width / 2 : size.width - 31,
                y: size.height / 2
            )
            let startPoint = flightPoint(
                for: startAnchor,
                fallback: startFallback,
                proxy: proxy
            )
            let endPoint = flightPoint(
                for: endAnchor,
                fallback: endFallback,
                proxy: proxy
            )
            let x = startPoint.x + ((endPoint.x - startPoint.x) * progress)
            let baselineY = startPoint.y +
                ((endPoint.y - startPoint.y) * progress)
            let arc = CGFloat(sin(Double(progress) * .pi)) * 24
            let y = baselineY + (isIncrease ? -arc : arc)
            let fade = progress < 0.78
                ? CGFloat(1)
                : max(0, 1 - ((progress - 0.78) / 0.22))

            RoundedRectangle(
                cornerRadius: 4,
                style: .continuous
            )
            .fill(isIncrease ? tint : Color.ppError)
            .overlay {
                RoundedRectangle(
                    cornerRadius: 4,
                    style: .continuous
                )
                .strokeBorder(Color.white.opacity(0.92), lineWidth: 2)
            }
            .frame(width: 13, height: 13)
            .shadow(
                color: (isIncrease ? tint : Color.ppError).opacity(0.24),
                radius: 5,
                y: 3
            )
            .scaleEffect(
                isIncrease
                    ? max(
                        0.12,
                        0.50 + (
                            0.50 *
                                CGFloat(sin(Double(progress) * .pi))
                        )
                    )
                    : max(0.12, 0.82 - (0.64 * progress))
            )
            .rotationEffect(
                .degrees(Double((isIncrease ? 90 : -70) * progress))
            )
            .id(quantityImpulseID)
            .position(x: x, y: y)
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

    private var quantityNumberAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .timingCurve(0.22, 1, 0.36, 1, duration: 0.32)
    }

    private var quantityNumberTransition: AnyTransition {
        guard !reduceMotion else {
            return .opacity
        }

        let sign: CGFloat = quantityDirection == .decrease ? -1 : 1

        return .asymmetric(
            insertion: .modifier(
                active: QuantityNumberTransitionModifier(
                    offset: 24 * sign,
                    angle: 40 * Double(sign),
                    opacity: 0,
                    blur: 3.5
                ),
                identity: QuantityNumberTransitionModifier(
                    offset: 0,
                    angle: 0,
                    opacity: 1,
                    blur: 0
                )
            ),
            removal: .modifier(
                active: QuantityNumberTransitionModifier(
                    offset: -24 * sign,
                    angle: -40 * Double(sign),
                    opacity: 0,
                    blur: 3.5
                ),
                identity: QuantityNumberTransitionModifier(
                    offset: 0,
                    angle: 0,
                    opacity: 1,
                    blur: 0
                )
            )
        )
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

    @MainActor
    private func performQuantityAction(
        direction: CartQuantityDirection,
        action: @MainActor () -> Void
    ) {
        quantityMotionTask?.cancel()
        quantityDirection = direction
        quantityImpulseID += 1

        guard !reduceMotion else {
            action()
            return
        }

        showsQuantityFlight = true
        quantityFlightProgress = 0
        quantityImpact = 0

        action()

        withAnimation(
            .timingCurve(0.30, 0.70, 0.20, 1, duration: 0.48)
        ) {
            quantityFlightProgress = 1
        }

        withAnimation(.easeOut(duration: 0.12)) {
            quantityImpact = 1
        }

        quantityMotionTask = Task { @MainActor in
            do {
                try await sleep(milliseconds: 120)

                withAnimation(
                    .interpolatingSpring(
                        mass: 0.64,
                        stiffness: 260,
                        damping: 18,
                        initialVelocity: 0
                    )
                ) {
                    quantityImpact = 0
                }

                try await sleep(milliseconds: 360)
                showsQuantityFlight = false
                quantityFlightProgress = 0
            } catch {
                showsQuantityFlight = false
                quantityFlightProgress = 0
                quantityImpact = 0
            }
        }
    }

    private func handleQuantityChange(_ newQuantity: Int) {
        let safeQuantity = max(0, newQuantity)
        guard safeQuantity != displayedQuantity else { return }

        quantityDirection = safeQuantity > displayedQuantity
            ? .increase
            : .decrease

        withAnimation(quantityNumberAnimation) {
            displayedQuantity = safeQuantity
        }
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
                } else if quantityMode != nil {
                    try await playSignatureSuccess(outcome: outcome)
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
    private func playSignatureSuccess(
        outcome: AnimatedAddToCartOutcome
    ) async throws {
        let newCount = outcome.cartCount
        cartCount = newCount

        withAnimation(
            .interpolatingSpring(
                mass: 0.72,
                stiffness: 240,
                damping: 19,
                initialVelocity: 0
            )
        ) {
            displayedCount = newCount
            phase = .success
        }

        announceSuccess(outcome: outcome)

        try await sleep(milliseconds: 620)

        withAnimation(.easeOut(duration: 0.24)) {
            displayedCount = max(0, cartCount)
            phase = .idle
        }

        PPAddToCartSuccessToast.show(
            title: PPAccessoryViewerL10n.text("AddedToCart")
        )
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

        PPAddToCartSuccessToast.show(
            title: PPAccessoryViewerL10n.text("AddedToCart")
        )
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

        PPAddToCartSuccessToast.show(
            title: PPAccessoryViewerL10n.text("AddedToCart")
        )
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

private struct QuantityNumberTransitionModifier: ViewModifier {
    let offset: CGFloat
    let angle: Double
    let opacity: Double
    let blur: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 1, y: 0, z: 0)
            )
            .opacity(opacity)
            .blur(radius: blur)
    }
}

private struct QuantityActionPressStyle: ButtonStyle {
    let tint: Color
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                tint.opacity(configuration.isPressed ? 0.08 : 0),
                in: RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
            )
            .scaleEffect(
                configuration.isPressed && !reduceMotion ? 0.88 : 1
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
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
