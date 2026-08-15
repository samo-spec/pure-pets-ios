//
//  PPCommerceCartHolder.swift
//  Pure Pets
//
//  Production-ready, Arabic-first SwiftUI implementation of the approved
//  compact commerce holder (Option 2).
//
//  Minimum deployment target: iOS 16.0
//
//  Integration contract
//  --------------------
//  1. The parent remains the source of truth for `quantity`.
//  2. Inject cancellation-aware, idempotent cart/payment operations.
//  3. Inject your existing cached image view through `thumbnail`.
//  4. Install at screen level with `.safeAreaInset(edge: .bottom)` so content
//     never sits behind the holder.
//
//  Example placement:
//
//  .safeAreaInset(edge: .bottom, spacing: 0) {
//      PPCommerceCartHolder(
//          item: item,
//          quantity: $cartQuantity,
//          actions: cartActions
//      ) {
//          ProductRemoteImage(url: item.thumbnailURL)
//      }
//      .padding(.horizontal, 14)
//      .padding(.bottom, 8)
//  }
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Public contracts

public struct PPCommerceCartItem: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let unitPrice: Decimal
    public let currencyCode: String
    public let availabilityText: String
    public let maximumQuantity: Int

    public init(
        id: String,
        title: String,
        unitPrice: Decimal,
        currencyCode: String = "QAR",
        availabilityText: String = "متوفر",
        maximumQuantity: Int = 5
    ) {
        self.id = id
        self.title = title
        self.unitPrice = unitPrice < 0 ? 0 : unitPrice
        let normalizedCurrencyCode = currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        self.currencyCode = normalizedCurrencyCode.isEmpty ? "QAR" : normalizedCurrencyCode
        self.availabilityText = availabilityText
        self.maximumQuantity = max(1, maximumQuantity)
    }
}

public enum PPCommerceOperation: String, Equatable, Sendable {
    case add
    case quantity
    case payment
}

public enum PPCommerceCartEvent: Equatable, Sendable {
    case addTapped(productID: String)
    case addSucceeded(productID: String, quantity: Int)
    case quantityChanged(productID: String, quantity: Int)
    case quantitySynced(productID: String, quantity: Int)
    case payTapped(productID: String, quantity: Int)
    case paymentSucceeded(productID: String, quantity: Int)
    case cartTapped(quantity: Int)
    case operationFailed(productID: String, operation: PPCommerceOperation)
}

public struct PPCommerceCartActions: Sendable {
    /// Returns the server-confirmed quantity after adding the item.
    public let add: @MainActor @Sendable () async throws -> Int

    /// Accepts an absolute quantity and returns the server-confirmed quantity.
    /// Make this endpoint idempotent; the component coalesces rapid taps.
    public let updateQuantity: @MainActor @Sendable (Int) async throws -> Int

    /// Starts the existing checkout/payment flow for the confirmed quantity.
    public let pay: @MainActor @Sendable (Int) async throws -> Void

    /// Routes to the existing cart screen. Navigation remains parent-owned.
    public let openCart: @MainActor @Sendable () -> Void

    /// Optional analytics bridge. No analytics SDK is coupled to this view.
    public let track: @MainActor @Sendable (PPCommerceCartEvent) -> Void

    public init(
        add: @escaping @MainActor @Sendable () async throws -> Int,
        updateQuantity: @escaping @MainActor @Sendable (Int) async throws -> Int,
        pay: @escaping @MainActor @Sendable (Int) async throws -> Void,
        openCart: @escaping @MainActor @Sendable () -> Void,
        track: @escaping @MainActor @Sendable (PPCommerceCartEvent) -> Void = { _ in }
    ) {
        self.add = add
        self.updateQuantity = updateQuantity
        self.pay = pay
        self.openCart = openCart
        self.track = track
    }
}

public struct PPCommerceCartCopy: Equatable, Sendable {
    public var addToCart = "أضف إلى السلة"
    public var adding = "تتم الإضافة"
    public var payNow = "اشترِ الآن"
    public var paying = "لحظة"
    public var paid = "تم"
    public var quantity = "الكمية"
    public var updatingQuantity = "جارٍ تحديث الكمية"
    public var increaseQuantity = "زيادة الكمية"
    public var decreaseQuantity = "تقليل الكمية"
    public var cartEmpty = "السلة فارغة"
    public var cartItemsFormat = "السلة، %@ منتج"
    public var retry = "إعادة المحاولة"
    public var dismiss = "إغلاق"
    public var addSucceeded = "أُضيف المنتج إلى السلة"
    public var paymentSucceeded = "تم تأكيد الدفع"
    public var addFailed = "تعذرت إضافة المنتج. حاول مرة أخرى."
    public var quantityFailed = "تعذر تحديث الكمية. حاول مرة أخرى."
    public var paymentFailed = "تعذر إكمال الدفع. حاول مرة أخرى."

    public init() {}

    public static let arabic = PPCommerceCartCopy()
}

public struct PPCommerceCartTheme: Sendable {
    public var brand: Color
    public var brandPressed: Color
    public var success: Color
    public var surface: Color
    public var primaryText: Color
    public var secondaryText: Color
    public var outline: Color
    public var addToCartBackground: Color?
    public var addToCartForeground: Color?
    public var addToCartBorder: Color?

    public init(
        brand: Color,
        brandPressed: Color,
        success: Color,
        surface: Color,
        primaryText: Color,
        secondaryText: Color,
        outline: Color,
        addToCartBackground: Color? = nil,
        addToCartForeground: Color? = nil,
        addToCartBorder: Color? = nil
    ) {
        self.brand = brand
        self.brandPressed = brandPressed
        self.success = success
        self.surface = surface
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.outline = outline
        self.addToCartBackground = addToCartBackground
        self.addToCartForeground = addToCartForeground
        self.addToCartBorder = addToCartBorder
    }

    public static let purePets = PPCommerceCartTheme(
        brand: Color(red: 203 / 255, green: 38 / 255, blue: 84 / 255),
        brandPressed: Color(red: 171 / 255, green: 23 / 255, blue: 63 / 255),
        success: Color(red: 50 / 255, green: 184 / 255, blue: 107 / 255),
        surface: Color(uiColor: .secondarySystemBackground),
        primaryText: Color(uiColor: .label),
        secondaryText: Color(uiColor: .secondaryLabel),
        outline: Color(uiColor: .separator)
    )
}

// MARK: - Commerce holder

private enum PPCommerceCartMetrics {
    // Fixed two-row geometry; accessibility reflows through `expandedLayout`.
    static let controlHeight: CGFloat =
        PPBottomDecisionBarGeometry.controlHeight - PPSpace.sm
    static let controlRadius: CGFloat =
        PPBottomDecisionBarGeometry.controlRadius
    static let spacing: CGFloat = PPBottomDecisionBarGeometry.controlSpacing
    static let verticalSpacing: CGFloat = PPSpace.sm
    static let holderPadding: CGFloat = PPSpace.md
    static let holderHeight: CGFloat =
        (controlHeight * 2) + verticalSpacing + (holderPadding * 2)
    static let holderRadius: CGFloat =
        PPBottomDecisionBarGeometry.surfaceRadius
    static let quantityWidth: CGFloat =
        (PPBottomDecisionBarGeometry.utilityControlSize * 2) + PPSpace.sm
    static let quantityButtonWidth: CGFloat = 40
    static let quantityValueWidth: CGFloat =
        quantityWidth - (quantityButtonWidth * 2)
    static let payWidth: CGFloat = PPSpace.xxxxl * 2
    static let thumbnailSize: CGFloat = controlHeight - PPSpace.sm
    static let minimumStandardWidth: CGFloat = 356
    static let summaryHorizontalPadding: CGFloat = PPSpace.xs
    /// The parent preserves its safe-area contract; this modest expansion uses
    /// part of that existing inset to give the holder more visual authority.
    static let widthExpansion: CGFloat = PPSpace.sm
}

@available(iOS 16.0, *)
@MainActor
public struct PPCommerceCartHolder<Thumbnail: View>: View {
    private enum CriticalPhase: Equatable {
        case adding
        case paying
        case paid
    }

    private enum RetryIntent: Equatable {
        case add
        case quantity(Int)
        case payment
    }

    private enum FeedbackKind: Equatable {
        case success
        case failure
    }

    private struct Feedback: Equatable, Identifiable {
        let id = UUID()
        let kind: FeedbackKind
        let message: String
        let retryIntent: RetryIntent?
    }

    private typealias Metrics = PPCommerceCartMetrics

    private let item: PPCommerceCartItem
    @Binding private var quantity: Int
    private let actions: PPCommerceCartActions
    private let copy: PPCommerceCartCopy
    private let theme: PPCommerceCartTheme
    private let thumbnail: Thumbnail

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var accessibilityContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var criticalPhase: CriticalPhase?
    @State private var feedback: Feedback?
    @State private var confirmedQuantity: Int
    @State private var isSyncingQuantity = false
    @State private var quantityRevision = 0
    @State private var criticalTask: Task<Void, Never>?
    @State private var quantityTask: Task<Void, Never>?

    public init(
        item: PPCommerceCartItem,
        quantity: Binding<Int>,
        actions: PPCommerceCartActions,
        copy: PPCommerceCartCopy = .arabic,
        theme: PPCommerceCartTheme = .purePets,
        @ViewBuilder thumbnail: () -> Thumbnail
    ) {
        self.item = item
        self._quantity = quantity
        self.actions = actions
        self.copy = copy
        self.theme = theme
        self.thumbnail = thumbnail()

        let initialQuantity = min(
            item.maximumQuantity,
            max(0, quantity.wrappedValue)
        )
        self._confirmedQuantity = State(initialValue: initialQuantity)
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Group {
                if needsExpandedLayout {
                    expandedLayout
                } else {
                    ViewThatFits(in: .horizontal) {
                        standardLayout
                        expandedLayout
                    }
                }
            }
            .animation(stateAnimation, value: displayQuantity)
            .animation(stateAnimation, value: criticalPhase)

            if let feedback {
                feedbackBanner(feedback)
                    .offset(y: needsExpandedLayout ? -64 : -52)
                    .transition(feedbackTransition)
                    .zIndex(10)
            }
        }
        .animation(stateAnimation, value: feedback?.id)
        .task(id: feedback?.id) {
            guard feedback?.kind == .success else { return }
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(stateAnimation) {
                    feedback = nil
                }
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
        .onChange(of: quantity) { newValue in
            guard !isSyncingQuantity, criticalPhase != .adding else { return }
            confirmedQuantity = clamped(newValue)
        }
        .onChange(of: item.id) { _ in
            cancelOperations(restoreConfirmedQuantity: false)
            confirmedQuantity = clamped(quantity)
            feedback = nil
        }
        .onDisappear {
            cancelOperations(restoreConfirmedQuantity: true)
        }
        .padding(.horizontal, -Metrics.widthExpansion)
        .accessibilityIdentifier("pp.commerce.holder")
    }
}

// MARK: - Layout

@available(iOS 16.0, *)
private extension PPCommerceCartHolder {
    @ViewBuilder
    private var standardLayout: some View {
        holderSurface {
            VStack(spacing: Metrics.verticalSpacing) {
                summaryRow
                standardActionRow
            }
            .padding(Metrics.holderPadding)
            .frame(height: Metrics.holderHeight)
        }
        .frame(minWidth: Metrics.minimumStandardWidth, maxWidth: .infinity)
    }

    @ViewBuilder
    private var expandedLayout: some View {
        holderSurface {
            VStack(alignment: .leading, spacing: PPSpace.md) {
                productSummary
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Metrics.spacing) {
                    Spacer(minLength: 0)
                    quantityControl
                }

                VStack(spacing: Metrics.spacing) {
                    addButton

                    payButton(minimumWidth: 120, maximumWidth: .infinity)
                }
            }
            .padding(Metrics.holderPadding)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryRow: some View {
        HStack(spacing: Metrics.spacing) {
            productSummary
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            quantityControl
                .layoutPriority(2)
        }
        .frame(height: Metrics.controlHeight)
    }

    private var standardActionRow: some View {
        HStack(spacing: Metrics.spacing) {
            addButton
                .frame(minWidth: 160, maxWidth: .infinity)
                .layoutPriority(1)

            payButton(
                minimumWidth: Metrics.payWidth,
                maximumWidth: Metrics.payWidth
            )
        }
        .frame(height: Metrics.controlHeight)
    }

    @ViewBuilder
    private var productSummary: some View {
        HStack(spacing: Metrics.spacing) {
            thumbnail
                .frame(width: Metrics.thumbnailSize, height: Metrics.thumbnailSize)
                .background(Color(uiColor: .tertiarySystemFill))
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(
                            theme.outline.opacity(subviewBorderOpacity),
                            lineWidth: borderWidth
                        )
                }
                .shadow(color: Color.black.opacity(0.08), radius: 5, y: 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                Text(item.title)
                    .font(PPAccessoryTypography.captionBold)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: PPSpace.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .imageScale(.small)
                    Text(item.availabilityText)
                        .lineLimit(1)
                }
                .font(PPAccessoryTypography.captionBold)
                .foregroundStyle(theme.success)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Text(formattedPrice)
                .font(PPAccessoryTypography.title)
                .foregroundStyle(theme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.70)
                .layoutPriority(1)
                .id(formattedPrice)
                .transition(numberTransition)
        }
        .frame(minWidth: 0, minHeight: Metrics.controlHeight)
        .padding(.horizontal, Metrics.summaryHorizontalPadding)
        .background(
            Color(uiColor: .systemBackground)
                .opacity(colorScheme == .dark ? 0.72 : 0.86)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: Metrics.controlRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: Metrics.controlRadius,
                style: .continuous
            )
            .strokeBorder(
                theme.outline.opacity(subviewBorderOpacity),
                lineWidth: borderWidth
            )
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(verbatim: "\(item.title)، \(formattedPrice)، \(item.availabilityText)")
        )
    }

    @ViewBuilder
    private var quantityControl: some View {
        HStack(spacing: 0) {
            quantityButton(
                systemName: "minus",
                label: copy.decreaseQuantity,
                identifier: "pp.commerce.quantity.decrease",
                isDisabled: controlsAreLocked || displayQuantity <= 0
            ) {
                requestQuantity(displayQuantity - 1)
            }

            ZStack {
                Text(formattedQuantity)
                    .font(PPAccessoryTypography.headline)
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()
                    .id(displayQuantity)
                    .transition(numberTransition)
            }
            .frame(width: Metrics.quantityValueWidth)
            .accessibilityHidden(true)

            quantityButton(
                systemName: "plus",
                label: copy.increaseQuantity,
                identifier: "pp.commerce.quantity.increase",
                isDisabled: controlsAreLocked || displayQuantity >= item.maximumQuantity
            ) {
                if displayQuantity == 0 {
                    beginAdd()
                } else {
                    requestQuantity(displayQuantity + 1)
                }
            }
        }
        .frame(width: Metrics.quantityWidth, height: Metrics.controlHeight)
        .background(theme.brand.opacity(colorScheme == .dark ? 0.14 : 0.055))
        .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                .strokeBorder(theme.brand.opacity(borderOpacity), lineWidth: borderWidth)
        }
        .overlay(alignment: .bottom) {
            if isSyncingQuantity {
                Capsule()
                    .fill(theme.brand)
                    .frame(width: 18, height: 2)
                    .padding(.bottom, PPSpace.xs)
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: copy.quantity))
        .accessibilityValue(
            Text(
                verbatim: isSyncingQuantity
                    ? "\(formattedQuantity)، \(copy.updatingQuantity)"
                    : formattedQuantity
            )
        )
    }

    @ViewBuilder
    private func quantityButton(
        systemName: String,
        label: String,
        identifier: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .frame(
                    width: Metrics.quantityButtonWidth,
                    height: Metrics.controlHeight
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PPCommercePressButtonStyle(reduceMotion: reduceMotion))
        .foregroundStyle(isDisabled ? theme.secondaryText.opacity(0.45) : theme.brand)
        .background(Color(uiColor: .systemBackground).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .disabled(isDisabled)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityHint(Text(verbatim: "\(copy.quantity): \(formattedQuantity)"))
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var addButton: some View {
        AnimatedAddToCartButton(
            cartCount: $quantity,
            title: copy.addToCart,
            addingTitle: copy.adding,
            addedTitle: copy.addSucceeded,
            retryTitle: copy.retry,
            tint: theme.brand,
            itemSymbol: "cart.badge.plus",
            isEnabled: addButtonIsEnabled,
            cornerRadius: Metrics.controlRadius,
            presentationStyle: .commerceHolder,
            onCartTap: animatedCartTapAction,
            onAdd: performAnimatedAdd
        )
        .accessibilityIdentifier("pp.commerce.add")
    }

    @ViewBuilder
    private func payButton(minimumWidth: CGFloat, maximumWidth: CGFloat) -> some View {
        Button(action: beginPayment) {
            HStack(spacing: PPSpace.xs) {
                switch criticalPhase {
                case .paying:
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                    Text(copy.paying)
                case .paid:
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .black))
                    Text(copy.paid)
                default:
                    Text(copy.payNow)
                }
            }
            .font(PPAccessoryTypography.calloutBold)
            .lineLimit(needsExpandedLayout ? 2 : 1)
            .padding(
                .horizontal,
                maximumWidth == Metrics.payWidth
                    ? Metrics.spacing
                    : PPSpace.md
            )
            .frame(minWidth: minimumWidth, maxWidth: maximumWidth)
            .frame(minHeight: Metrics.controlHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(PPCommercePressButtonStyle(reduceMotion: reduceMotion))
        .foregroundStyle(Color.white)
        .background(criticalPhase == .paid ? theme.success : theme.brand)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(primaryControlBorderOpacity),
                    lineWidth: borderWidth
                )
        }
        .shadow(
            color: (criticalPhase == .paid ? theme.success : theme.brand).opacity(0.20),
            radius: 9,
            y: 5
        )
        .disabled(criticalPhase != nil || isSyncingQuantity || displayQuantity == 0)
        .accessibilityLabel(Text(verbatim: copy.payNow))
        .accessibilityValue(Text(verbatim: paymentAccessibilityValue))
        .accessibilityIdentifier("pp.commerce.pay")
    }

    private func feedbackBanner(_ feedback: Feedback) -> some View {
        HStack(spacing: Metrics.spacing) {
            Image(systemName: feedback.kind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(feedback.kind == .success ? theme.success : Color.orange)

            Text(feedback.message)
                .font(PPAccessoryTypography.caption)
                .foregroundStyle(Color.white)
                .fixedSize(horizontal: false, vertical: true)

            if let retryIntent = feedback.retryIntent {
                Button {
                    retry(retryIntent)
                } label: {
                    Text(verbatim: copy.retry)
                        .font(PPAccessoryTypography.captionBold)
                        .foregroundStyle(Color.white)
                        .frame(minHeight: 44)
                }
                .accessibilityHint(Text(verbatim: feedback.message))
            }

            Button {
                withAnimation(stateAnimation) {
                    self.feedback = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(Color.white.opacity(0.86))
            .accessibilityLabel(Text(verbatim: copy.dismiss))
        }
        .padding(.leading, PPSpace.md)
        .padding(.trailing, PPSpace.xs)
        .background(Color.black.opacity(reduceTransparency ? 1 : 0.92))
        .clipShape(Capsule())
        .overlay {
            Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 12, y: 6)
        .padding(.horizontal, PPSpace.sm)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pp.commerce.feedback")
    }

    private func holderSurface<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: Metrics.holderRadius, style: .continuous)
                    .fill(surfaceColor)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.holderRadius, style: .continuous)
                    .strokeBorder(theme.outline.opacity(holderBorderOpacity), lineWidth: borderWidth)
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.11),
                radius: 20,
                y: 10
            )
            .compositingGroup()
    }
}

// MARK: - State and async work

@available(iOS 16.0, *)
private extension PPCommerceCartHolder {
    var displayQuantity: Int {
        clamped(quantity)
    }

    var totalPrice: Decimal {
        item.unitPrice * Decimal(max(1, displayQuantity))
    }

    var formattedPrice: String {
        totalPrice.formatted(
            .currency(code: item.currencyCode)
                .precision(.fractionLength(0))
                .locale(locale)
        )
    }

    var formattedQuantity: String {
        displayQuantity.formatted(.number.locale(locale))
    }

    var paymentAccessibilityValue: String {
        switch criticalPhase {
        case .paying:
            return copy.paying
        case .paid:
            return copy.paid
        default:
            return formattedPrice
        }
    }

    var controlsAreLocked: Bool {
        criticalPhase != nil
    }

    var addButtonIsEnabled: Bool {
        criticalPhase == nil &&
            !isSyncingQuantity &&
            displayQuantity < item.maximumQuantity
    }

    var animatedCartTapAction: (() -> Void)? {
        guard criticalPhase == nil, !isSyncingQuantity else { return nil }

        return {
            actions.track(.cartTapped(quantity: displayQuantity))
            actions.openCart()
        }
    }

    func clamped(_ proposedQuantity: Int) -> Int {
        min(item.maximumQuantity, max(0, proposedQuantity))
    }

    func beginAdd() {
        guard displayQuantity == 0, criticalPhase == nil, !isSyncingQuantity else { return }

        feedback = nil
        criticalPhase = .adding
        actions.track(.addTapped(productID: item.id))
        PPCommerceHaptics.impact()

        criticalTask?.cancel()
        criticalTask = Task { @MainActor in
            do {
                let returnedQuantity = try await actions.add()
                try Task.checkCancellation()

                let confirmed = max(1, clamped(returnedQuantity))
                confirmedQuantity = confirmed
                withAnimation(stateAnimation) {
                    quantity = confirmed
                    criticalPhase = nil
                }

                actions.track(.addSucceeded(productID: item.id, quantity: confirmed))
                presentSuccess(copy.addSucceeded)
            } catch is CancellationError {
                criticalPhase = nil
            } catch {
                criticalPhase = nil
                actions.track(.operationFailed(productID: item.id, operation: .add))
                presentFailure(copy.addFailed, retry: .add)
            }

            criticalTask = nil
        }
    }

    func performAnimatedAdd() async throws -> AnimatedAddToCartOutcome {
        guard criticalPhase == nil, !isSyncingQuantity else {
            throw CancellationError()
        }

        feedback = nil
        let priorQuantity = displayQuantity

        if priorQuantity == 0 {
            criticalPhase = .adding
            actions.track(.addTapped(productID: item.id))
            PPCommerceHaptics.impact()

            do {
                let returnedQuantity = try await actions.add()
                try Task.checkCancellation()

                let confirmed = max(1, clamped(returnedQuantity))
                confirmedQuantity = confirmed
                quantity = confirmed
                criticalPhase = nil
                actions.track(
                    .addSucceeded(productID: item.id, quantity: confirmed)
                )

                return AnimatedAddToCartOutcome(
                    cartCount: confirmed,
                    addedQuantity: confirmed
                )
            } catch {
                criticalPhase = nil
                if !(error is CancellationError) {
                    actions.track(
                        .operationFailed(productID: item.id, operation: .add)
                    )
                }
                throw error
            }
        }

        let requested = clamped(priorQuantity + 1)
        guard requested > priorQuantity else {
            throw CancellationError()
        }

        isSyncingQuantity = true
        actions.track(.quantityChanged(productID: item.id, quantity: requested))
        PPCommerceHaptics.selection()

        do {
            // The shared button locks repeat taps while preserving the holder's
            // established brief coalescing window before the cart mutation.
            try await Task.sleep(nanoseconds: 220_000_000)
            let returnedQuantity = try await actions.updateQuantity(requested)
            try Task.checkCancellation()

            let confirmed = clamped(returnedQuantity)
            confirmedQuantity = confirmed
            quantity = confirmed
            isSyncingQuantity = false
            actions.track(
                .quantitySynced(productID: item.id, quantity: confirmed)
            )

            return AnimatedAddToCartOutcome(
                cartCount: confirmed,
                addedQuantity: max(0, confirmed - priorQuantity)
            )
        } catch {
            withAnimation(stateAnimation) {
                quantity = confirmedQuantity
                isSyncingQuantity = false
            }
            if !(error is CancellationError) {
                actions.track(
                    .operationFailed(productID: item.id, operation: .quantity)
                )
            }
            throw error
        }
    }

    func requestQuantity(_ proposedQuantity: Int) {
        guard criticalPhase == nil else { return }

        let requested = clamped(proposedQuantity)
        guard requested != displayQuantity else { return }

        quantityRevision += 1
        let revision = quantityRevision

        withAnimation(stateAnimation) {
            quantity = requested
            feedback = nil
        }

        isSyncingQuantity = true
        actions.track(.quantityChanged(productID: item.id, quantity: requested))
        PPCommerceHaptics.selection()

        quantityTask?.cancel()
        quantityTask = Task { @MainActor in
            do {
                // Coalesce rapid +/- taps before touching the cart service.
                try await Task.sleep(nanoseconds: 220_000_000)
                let returnedQuantity = try await actions.updateQuantity(requested)
                try Task.checkCancellation()
                guard revision == quantityRevision else { return }

                let confirmed = clamped(returnedQuantity)
                confirmedQuantity = confirmed
                withAnimation(stateAnimation) {
                    quantity = confirmed
                    isSyncingQuantity = false
                }
                actions.track(.quantitySynced(productID: item.id, quantity: confirmed))
            } catch is CancellationError {
                if revision == quantityRevision {
                    isSyncingQuantity = false
                }
            } catch {
                guard revision == quantityRevision else { return }

                withAnimation(stateAnimation) {
                    quantity = confirmedQuantity
                    isSyncingQuantity = false
                }
                actions.track(.operationFailed(productID: item.id, operation: .quantity))
                presentFailure(copy.quantityFailed, retry: .quantity(requested))
            }

            if revision == quantityRevision {
                quantityTask = nil
            }
        }
    }

    func beginPayment() {
        guard displayQuantity > 0, criticalPhase == nil, !isSyncingQuantity else { return }

        let payingQuantity = displayQuantity
        feedback = nil
        criticalPhase = .paying
        actions.track(.payTapped(productID: item.id, quantity: payingQuantity))
        PPCommerceHaptics.impact()

        criticalTask?.cancel()
        criticalTask = Task { @MainActor in
            do {
                try await actions.pay(payingQuantity)
                try Task.checkCancellation()

                withAnimation(stateAnimation) {
                    criticalPhase = .paid
                }
                actions.track(.paymentSucceeded(productID: item.id, quantity: payingQuantity))
                presentSuccess("\(copy.paymentSucceeded) \(formattedPrice)")

                try await Task.sleep(nanoseconds: 1_100_000_000)
                try Task.checkCancellation()
                withAnimation(stateAnimation) {
                    criticalPhase = nil
                }
            } catch is CancellationError {
                criticalPhase = nil
            } catch {
                criticalPhase = nil
                actions.track(.operationFailed(productID: item.id, operation: .payment))
                presentFailure(copy.paymentFailed, retry: .payment)
            }

            criticalTask = nil
        }
    }

    private func retry(_ intent: RetryIntent) {
        withAnimation(stateAnimation) {
            feedback = nil
        }

        switch intent {
        case .add:
            beginAdd()
        case .quantity(let requested):
            requestQuantity(requested)
        case .payment:
            beginPayment()
        }
    }

    private func presentSuccess(_ message: String) {
        withAnimation(stateAnimation) {
            feedback = Feedback(kind: .success, message: message, retryIntent: nil)
        }
        PPCommerceHaptics.success()
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func presentFailure(_ message: String, retry: RetryIntent) {
        withAnimation(stateAnimation) {
            feedback = Feedback(kind: .failure, message: message, retryIntent: retry)
        }
        PPCommerceHaptics.error()
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func cancelOperations(restoreConfirmedQuantity: Bool) {
        quantityRevision += 1
        criticalTask?.cancel()
        quantityTask?.cancel()
        criticalTask = nil
        quantityTask = nil
        criticalPhase = nil

        if restoreConfirmedQuantity, isSyncingQuantity {
            quantity = confirmedQuantity
        }
        isSyncingQuantity = false
    }
}

// MARK: - Adaptive styling

@available(iOS 16.0, *)
private extension PPCommerceCartHolder {
    var needsExpandedLayout: Bool {
        dynamicTypeSize == .xxxLarge || dynamicTypeSize.isAccessibilitySize
    }

    var stateAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.84)
    }

    var actionTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .scale(scale: 0.92).combined(with: .opacity)
    }

    var numberTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
    }

    var feedbackTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .move(edge: .bottom).combined(with: .opacity)
    }

    var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [theme.brand, theme.brandPressed],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var surfaceColor: Color {
        reduceTransparency ? theme.surface : theme.surface.opacity(0.96)
    }

    var borderWidth: CGFloat {
        accessibilityContrast == .increased ? 1.5 : 1
    }

    var borderOpacity: Double {
        if accessibilityContrast == .increased { return 0.50 }
        return colorScheme == .dark ? 0.30 : 0.20
    }

    var primaryControlBorderOpacity: Double {
        accessibilityContrast == .increased ? 0.44 : 0.24
    }

    var subviewBorderOpacity: Double {
        if accessibilityContrast == .increased { return 0.54 }
        return colorScheme == .dark ? 0.34 : 0.22
    }

    var holderBorderOpacity: Double {
        if accessibilityContrast == .increased { return 0.64 }
        return colorScheme == .dark ? 0.42 : 0.30
    }
}

private struct PPCommercePressButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

private enum PPCommerceHaptics {
    @MainActor
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @MainActor
    static func impact() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    @MainActor
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Deterministic previews

#if DEBUG
@available(iOS 16.0, *)
private struct PPCommerceCartHolderPreview: View {
    @State private var quantity: Int

    init(quantity: Int) {
        self._quantity = State(initialValue: quantity)
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack {
                Spacer()

                PPCommerceCartHolder(
                    item: PPCommerceCartItem(
                        id: "preview-falconry-set",
                        title: "مجموعة قفاز صقارة",
                        unitPrice: 190,
                        currencyCode: "QAR",
                        availabilityText: "متوفر",
                        maximumQuantity: 5
                    ),
                    quantity: $quantity,
                    actions: PPCommerceCartActions(
                        add: {
                            try await Task.sleep(nanoseconds: 620_000_000)
                            return 1
                        },
                        updateQuantity: { requested in
                            try await Task.sleep(nanoseconds: 180_000_000)
                            return requested
                        },
                        pay: { _ in
                            try await Task.sleep(nanoseconds: 760_000_000)
                        },
                        openCart: {}
                    )
                ) {
                    ZStack {
                        Color(uiColor: .systemTeal).opacity(0.12)
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(Color(uiColor: .systemTeal))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
        }
    }
}

#Preview("Arabic • Empty") {
    PPCommerceCartHolderPreview(quantity: 0)
        .environment(\.locale, Locale(identifier: "ar_QA"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Arabic • Active") {
    PPCommerceCartHolderPreview(quantity: 1)
        .environment(\.locale, Locale(identifier: "ar_QA"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Arabic • AX5") {
    PPCommerceCartHolderPreview(quantity: 2)
        .environment(\.locale, Locale(identifier: "ar_QA"))
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Dark") {
    PPCommerceCartHolderPreview(quantity: 2)
        .environment(\.locale, Locale(identifier: "ar_QA"))
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
}
#endif
