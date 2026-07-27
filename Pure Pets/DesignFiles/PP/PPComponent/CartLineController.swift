//
//  CartLineController.swift
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/27/26.
//


import SwiftUI
import Observation

// MARK: - Cart State

@available(iOS 17.0, *)
@MainActor
@Observable
final class CartLineController {

    typealias SyncQuantityAction = (Int) async throws -> Void

    private(set) var quantity: Int
    private(set) var isSyncing = false
    private(set) var errorMessage: String?

    let unitPrice: Decimal
    let maximumQuantity: Int

    private var lastSyncedQuantity: Int
    private var syncTask: Task<Void, Never>?

    private let syncQuantityAction: SyncQuantityAction

    init(
        quantity: Int = 0,
        unitPrice: Decimal,
        maximumQuantity: Int = 99,
        syncQuantity: @escaping SyncQuantityAction = { _ in }
    ) {
        let safeMaximum = Swift.max(1, maximumQuantity)
        let safeQuantity = Swift.min(
            Swift.max(quantity, 0),
            safeMaximum
        )

        self.quantity = safeQuantity
        self.lastSyncedQuantity = safeQuantity
        self.unitPrice = unitPrice
        self.maximumQuantity = safeMaximum
        self.syncQuantityAction = syncQuantity
    }

    var totalPrice: Decimal {
        unitPrice * Decimal(quantity)
    }

    var canIncrement: Bool {
        quantity < maximumQuantity
    }

    func addToCart() {
        setQuantity(Swift.max(quantity, 1))
    }

    func increment() {
        setQuantity(quantity + 1)
    }

    func decrement() {
        setQuantity(quantity - 1)
    }

    func setQuantity(_ proposedQuantity: Int) {
        let newQuantity = Swift.min(
            Swift.max(proposedQuantity, 0),
            maximumQuantity
        )

        guard newQuantity != quantity else {
            return
        }

        quantity = newQuantity
        errorMessage = nil

        startSyncLoopIfNeeded()
    }

    func clearError() {
        errorMessage = nil
    }

    private func startSyncLoopIfNeeded() {
        guard syncTask == nil else {
            return
        }

        syncTask = Task { [weak self] in
            await self?.runSyncLoop()
        }
    }

    /// Serializes rapid user actions.
    ///
    /// For example, if the user quickly changes:
    /// 0 → 1 → 2 → 3 → 4
    ///
    /// the controller finishes the active request and then synchronizes
    /// the newest required quantity without launching overlapping requests.
    private func runSyncLoop() async {
        while !Task.isCancelled,
              lastSyncedQuantity != quantity {

            let targetQuantity = quantity
            isSyncing = true

            do {
                try await syncQuantityAction(targetQuantity)

                guard !Task.isCancelled else {
                    break
                }

                lastSyncedQuantity = targetQuantity
            } catch is CancellationError {
                break
            } catch {
                quantity = lastSyncedQuantity
                errorMessage = error.localizedDescription
                break
            }
        }

        isSyncing = false
        syncTask = nil

        // Catch a state change that happened while the task was finishing.
        if lastSyncedQuantity != quantity {
            startSyncLoopIfNeeded()
        }
    }
}

// MARK: - Localized Copy
@available(iOS 16.0, *)
struct AliveCartCopy {

    var addToCart: LocalizedStringResource = "Add to Cart"
    var cart: LocalizedStringResource = "Cart"
    var quantity: LocalizedStringResource = "Quantity"
    var increaseQuantity: LocalizedStringResource = "Increase quantity"
    var decreaseQuantity: LocalizedStringResource = "Decrease quantity"
    var each: LocalizedStringResource = "Each"
    var updating: LocalizedStringResource = "Updating cart"
    var unavailable: LocalizedStringResource = "Maximum quantity reached"
}

// MARK: - Main Cart Bar
@available(iOS 17.0, *)
struct AliveCartBar: View {

    let controller: CartLineController
    let currencyCode: String
    let copy: AliveCartCopy
    let onOpenCart: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    init(
        controller: CartLineController,
        currencyCode: String,
        copy: AliveCartCopy = .init(),
        onOpenCart: @escaping () -> Void
    ) {
        self.controller = controller
        self.currencyCode = currencyCode
        self.copy = copy
        self.onOpenCart = onOpenCart
    }

    private var stateAnimation: Animation? {
        reduceMotion
            ? nil
            : .snappy(duration: 0.42, extraBounce: 0.08)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                horizontalLayout
                compactLayout
            }

            errorMessage
        }
        .animation(stateAnimation, value: controller.quantity)
        .animation(stateAnimation, value: controller.errorMessage)
        .sensoryFeedback(
            .selection,
            trigger: controller.quantity
        )
        .sensoryFeedback(
            .error,
            trigger: controller.errorMessage
        )
    }

    private var horizontalLayout: some View {
        HStack(spacing: 14) {
            PriceView(
                controller: controller,
                currencyCode: currencyCode,
                copy: copy
            )

            Spacer(minLength: 8)

            AliveQuantityControl(
                controller: controller,
                copy: copy
            )
            .frame(maxWidth: 230)

            AnimatedCartButton(
                quantity: controller.quantity,
                isSyncing: controller.isSyncing,
                copy: copy,
                action: onOpenCart
            )
        }
    }

    private var compactLayout: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                PriceView(
                    controller: controller,
                    currencyCode: currencyCode,
                    copy: copy
                )

                Spacer(minLength: 8)

                AnimatedCartButton(
                    quantity: controller.quantity,
                    isSyncing: controller.isSyncing,
                    copy: copy,
                    action: onOpenCart
                )
            }

            AliveQuantityControl(
                controller: controller,
                copy: copy
            )
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let errorMessage = controller.errorMessage {
            Button {
                controller.clearError()
            } label: {
                Label {
                    Text(errorMessage)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                } icon: {
                    Image(systemName: "exclamationmark.circle.fill")
                }
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .transition(
                .move(edge: .top)
                .combined(with: .opacity)
            )
        }
    }
}

// MARK: - Price
@available(iOS 17.0, *)
private struct PriceView: View {

    let controller: CartLineController
    let currencyCode: String
    let copy: AliveCartCopy

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(
                controller.quantity > 0
                    ? controller.totalPrice
                    : controller.unitPrice,
                format: .currency(code: currencyCode)
            )
            .font(.title3.weight(.bold))
            .monospacedDigit()
            .contentTransition(
                .numericText(
                    value: NSDecimalNumber(
                        decimal: controller.quantity > 0
                            ? controller.totalPrice
                            : controller.unitPrice
                    ).doubleValue
                )
            )

            if controller.quantity > 1 {
                HStack(spacing: 4) {
                    Text(copy.each)

                    Text(
                        controller.unitPrice,
                        format: .currency(code: currencyCode)
                    )
                    .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Add-to-Cart / Stepper
@available(iOS 17.0, *)
private struct AliveQuantityControl: View {

    let controller: CartLineController
    let copy: AliveCartCopy

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var stateAnimation: Animation? {
        reduceMotion
            ? nil
            : .snappy(duration: 0.38, extraBounce: 0.12)
    }

    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color.accentColor)

            if controller.quantity == 0 {
                addToCartButton
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.88)
                                .combined(with: .opacity),
                            removal: .scale(scale: 1.08)
                                .combined(with: .opacity)
                        )
                    )
            } else {
                quantityStepper
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.90)
                                .combined(with: .opacity),
                            removal: .scale(scale: 1.06)
                                .combined(with: .opacity)
                        )
                    )
            }
        }
        .frame(minHeight: 56)
        .animation(stateAnimation, value: controller.quantity == 0)
    }

    private var addToCartButton: some View {
        Button {
            withAnimation(stateAnimation) {
                controller.addToCart()
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "cart.badge.plus")
                    .font(.body.weight(.semibold))

                Text(copy.addToCart)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(AlivePressStyle())
        .accessibilityLabel(Text(copy.addToCart))
    }

    private var quantityStepper: some View {
        HStack(spacing: 4) {
            quantityButton(
                systemImage: controller.quantity == 1
                    ? "trash"
                    : "minus",
                accessibilityLabel: copy.decreaseQuantity,
                action: controller.decrement
            )

            Text(controller.quantity.formatted())
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(
                    .numericText(value: Double(controller.quantity))
                )
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            quantityButton(
                systemImage: "plus",
                accessibilityLabel: copy.increaseQuantity,
                disabled: !controller.canIncrement,
                action: controller.increment
            )
        }
        .padding(.horizontal, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(copy.quantity))
        .accessibilityValue(
            Text(controller.quantity.formatted())
        )
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                guard controller.canIncrement else {
                    return
                }

                withAnimation(stateAnimation) {
                    controller.increment()
                }

            case .decrement:
                withAnimation(stateAnimation) {
                    controller.decrement()
                }

            @unknown default:
                break
            }
        }
    }

    private func quantityButton(
        systemImage: String,
        accessibilityLabel: LocalizedStringResource,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(stateAnimation) {
                action()
            }
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(.white.opacity(disabled ? 0.08 : 0.16))
                }
                .contentShape(Circle())
        }
        .buttonStyle(AlivePressStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

// MARK: - Standalone Cart Button
@available(iOS 17.0, *)
private struct AnimatedCartButton: View {

    let quantity: Int
    let isSyncing: Bool
    let copy: AliveCartCopy
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var badgeText: String {
        quantity > 99 ? "99+" : quantity.formatted()
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: quantity > 0 ? "cart.fill" : "cart")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 54, height: 54)
                .background {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                }
                .overlay {
                    Circle()
                        .stroke(
                            Color.accentColor.opacity(0.18),
                            lineWidth: 1
                        )
                }
                .overlay(alignment: .topTrailing) {
                    if quantity > 0 {
                        Text(badgeText)
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .frame(minWidth: 21, minHeight: 21)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.accentColor)
                            )
                            .contentTransition(
                                .numericText(value: Double(quantity))
                            )
                            .transition(
                                .scale(scale: 0.5)
                                .combined(with: .opacity)
                            )
                            .accessibilityHidden(true)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if isSyncing {
                        ProgressView()
                            .controlSize(.mini)
                            .padding(3)
                            .background(.regularMaterial, in: Circle())
                            .transition(.scale.combined(with: .opacity))
                            .accessibilityHidden(true)
                    }
                }
        }
        .buttonStyle(AlivePressStyle())
        .animation(
            reduceMotion
                ? nil
                : .snappy(duration: 0.34, extraBounce: 0.16),
            value: quantity
        )
        .accessibilityLabel(Text(copy.cart))
        .accessibilityValue(
            quantity == 0
                ? Text("0")
                : Text(quantity.formatted())
        )
        .accessibilityHint(
            isSyncing ? Text(copy.updating) : Text("")
        )
    }
}

// MARK: - Press Animation

private struct AlivePressStyle: ButtonStyle {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && !reduceMotion
                    ? 0.955
                    : 1
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: 0.14),
                value: configuration.isPressed
            )
    }
}

 
