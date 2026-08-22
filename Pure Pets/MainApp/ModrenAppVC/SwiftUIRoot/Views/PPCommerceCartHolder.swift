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
    public var inCart = "في السلة"
    public var quantityInCartFormat = "%ld في السلة"
    public var updatingQuantity = "جارٍ تحديث الكمية"
    public var increaseQuantity = "زيادة الكمية"
    public var decreaseQuantity = "تقليل الكمية"
    public var removeItem = "حذف المنتج"
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
        brand: .ppPrimary,
        brandPressed: .ppPressedAction,
        success: .ppSuccess,
        surface: .ppSurface,
        primaryText: .ppTextPrimary,
        secondaryText: .ppTextSecondary,
        outline: .ppSurfaceBorder
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
    static let holderRadius: CGFloat = 24
    static let quantityControlRadius: CGFloat = controlRadius
    static let payWidth: CGFloat = PPSpace.xxxxl * 2
    static let thumbnailSize: CGFloat = controlHeight - PPSpace.sm
    static let minimumStandardWidth: CGFloat = 356
    static let summaryHorizontalPadding: CGFloat = PPSpace.xs
    /// Standard screen edge margin for the commerce holder (16pt).
    static let screenEdgePadding: CGFloat = PPSpace.base
    static let widthExpansion: CGFloat = 0
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
    private let showsTopCartShortcut: Bool
    private let copy: PPCommerceCartCopy
    private let theme: PPCommerceCartTheme
    private let thumbnail: Thumbnail

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var accessibilityContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var criticalPhase: CriticalPhase?
    @State private var feedback: Feedback?
    @State private var confirmedQuantity: Int
    @State private var isSyncingQuantity = false
    @State private var pendingQuantity: Int?
    @State private var quantityRevision = 0
    @State private var criticalTask: Task<Void, Never>?
    @State private var quantityTask: Task<Void, Never>?

    public init(
        item: PPCommerceCartItem,
        quantity: Binding<Int>,
        actions: PPCommerceCartActions,
        showsTopCartShortcut: Bool = true,
        copy: PPCommerceCartCopy = .arabic,
        theme: PPCommerceCartTheme = .purePets,
        @ViewBuilder thumbnail: () -> Thumbnail
    ) {
        self.item = item
        self._quantity = quantity
        self.actions = actions
        self.showsTopCartShortcut = showsTopCartShortcut
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
            pendingQuantity = nil
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
            .frame(minHeight: Metrics.holderHeight)
        }
        .frame(minWidth: Metrics.minimumStandardWidth, maxWidth: .infinity)
    }

    @ViewBuilder
    private var expandedLayout: some View {
        holderSurface {
            VStack(spacing: PPSpace.md) {
                HStack(spacing: Metrics.spacing) {
                    productSummary
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if showsTopCartShortcut {
                        cartButton
                    }
                }

                quantityAndPayRow(minimumPayWidth: 120)
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

            if showsTopCartShortcut {
                cartButton
                    .layoutPriority(2)
            }
        }
        .frame(minHeight: Metrics.controlHeight)
    }

    private var standardActionRow: some View {
        quantityAndPayRow(minimumPayWidth: Metrics.payWidth)
    }

    @ViewBuilder
    private func quantityAndPayRow(minimumPayWidth: CGFloat) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Metrics.spacing) {
                quantityControl
                    .frame(maxWidth: .infinity)

                payButton(
                    minimumWidth: minimumPayWidth,
                    maximumWidth: .infinity
                )
            }
        } else {
            HStack(spacing: Metrics.spacing) {
                quantityControl
                    .frame(maxWidth: .infinity)

                payButton(
                    minimumWidth: nil,
                    maximumWidth: nil
                )
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(height: actionControlHeight)
        }
    }

    @ViewBuilder
    private var productSummary: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    HStack(alignment: .top, spacing: Metrics.spacing) {
                        productThumbnail
                        productCopy
                    }
                    productPrice
                }
            } else {
                HStack(spacing: Metrics.spacing) {
                    productThumbnail
                    productCopy
                    productPrice
                }
            }
        }
        .frame(minWidth: 0, minHeight: Metrics.controlHeight)
        .padding(.horizontal, PPSpace.sm)
        .padding(.vertical, PPSpace.xs)
        .background(Color.ppSecondarySurface.opacity(colorScheme == .dark ? 0.70 : 0.58))
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
        .accessibilityLabel(Text(verbatim: item.title))
        .accessibilityValue(
            Text(verbatim: "\(formattedPrice), \(item.availabilityText)")
        )
    }

    private var productThumbnail: some View {
        thumbnail
            .frame(width: Metrics.thumbnailSize, height: Metrics.thumbnailSize)
            .background(Color.ppSurfaceRaised)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PPCorner.small,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PPCorner.small,
                    style: .continuous
                )
                .strokeBorder(
                    theme.outline.opacity(subviewBorderOpacity),
                    lineWidth: borderWidth
                )
            }
            .accessibilityHidden(true)
    }

    private var productCopy: some View {
        VStack(alignment: .leading, spacing: PPSpace.xxs) {
            Text(item.title)
                .font(PPAccessoryTypography.captionBold)
                .foregroundStyle(theme.primaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : (needsExpandedLayout ? 2 : 1))
                .truncationMode(.tail)

            HStack(spacing: PPSpace.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .imageScale(.small)
                    .foregroundStyle(theme.success)
                    .accessibilityHidden(true)

                Text(item.availabilityText)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }
            .font(PPAccessoryTypography.captionBold)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private var productPrice: some View {
        Text(formattedPrice)
            .font(PPAccessoryTypography.title)
            .foregroundStyle(theme.brand)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.82)
            .layoutPriority(1)
            .id(formattedPrice)
            .transition(numberTransition)
    }

    @ViewBuilder
    private var quantityControl: some View {
        AnimatedAddToCartButton(
            cartCount: readOnlyQuantityBinding,
            title: copy.addToCart,
            addingTitle: copy.adding,
            addedTitle: copy.addSucceeded,
            retryTitle: copy.retry,
            tint: theme.brand,
            itemSymbol: "shippingbox.fill",
            isEnabled: animatedCartControlIsEnabled,
            cornerRadius: Metrics.quantityControlRadius,
            presentationStyle: .commerceHolder,
            quantityMode: .init(
                quantity: readOnlyQuantityBinding,
                minimumQuantity: 1,
                maximumQuantity: item.maximumQuantity,
                inCartTitle: copy.inCart,
                quantityAccessibilityValue: quantityAccessibilityValue,
                increaseAccessibilityLabel: copy.increaseQuantity,
                decreaseAccessibilityLabel: copy.decreaseQuantity,
                removeAccessibilityLabel: copy.removeItem,
                increaseAccessibilityIdentifier:
                    "pp.commerce.quantity.increase",
                decreaseAccessibilityIdentifier:
                    "pp.commerce.quantity.decrease",
                removeAccessibilityIdentifier:
                    "pp.commerce.quantity.remove",
                isEnabled: animatedCartControlIsEnabled,
                canRemove: true,
                controlHeight: actionControlHeight,
                onIncrement: {
                    requestQuantity(displayQuantity + 1)
                },
                onDecrement: {
                    requestQuantity(displayQuantity - 1)
                },
                onRemove: {
                    requestQuantity(0)
                }
            ),
            onAdd: addFromAnimatedControl
        )
        .id(item.id)
    }

    @ViewBuilder
    private var cartButton: some View {
        Button {
            guard criticalPhase == nil, !isSyncingQuantity else { return }
            actions.track(.cartTapped(quantity: displayQuantity))
            actions.openCart()
        } label: {
            HStack(spacing: PPSpace.xs) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 17, weight: .semibold))

                if displayQuantity > 0 {
                    Text(formattedQuantity)
                        .font(PPAccessoryTypography.calloutBold)
                        .monospacedDigit()
                        .padding(.horizontal, PPSpace.xs)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(
                            Color(uiColor: .systemBackground).opacity(0.92),
                            in: Capsule()
                        )
                }
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.controlHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(PPCommercePressButtonStyle(reduceMotion: reduceMotion))
        .foregroundStyle(theme.brand)
        .background(theme.brand.opacity(colorScheme == .dark ? 0.18 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                .strokeBorder(
                    theme.brand.opacity(borderOpacity),
                    lineWidth: borderWidth
                )
        }
        .frame(width: Metrics.controlHeight, height: Metrics.controlHeight)
        .disabled(criticalPhase != nil || isSyncingQuantity)
        .accessibilityLabel(Text(verbatim: cartAccessibilityLabel))
        .accessibilityValue(Text(verbatim: formattedQuantity))
        .accessibilityIdentifier("pp.commerce.cart")
    }

    @ViewBuilder
    private func payButton(
        minimumWidth: CGFloat? = nil,
        maximumWidth: CGFloat? = nil
    ) -> some View {
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
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .accessibilityHidden(true)
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
            .frame(minHeight: actionControlHeight)
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
            color: (criticalPhase == .paid ? theme.success : theme.brand).opacity(0.16),
            radius: 8,
            y: 4
        )
        .disabled(criticalPhase != nil || isSyncingQuantity)
        .accessibilityLabel(Text(verbatim: copy.payNow))
        .accessibilityValue(Text(verbatim: paymentAccessibilityValue))
        .accessibilityIdentifier("pp.commerce.pay")
    }

    @ViewBuilder
    private func feedbackBanner(_ feedback: Feedback) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PPSpace.xs) {
                    feedbackMessage(feedback)
                    feedbackActions(feedback)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: Metrics.spacing) {
                    feedbackMessage(feedback)
                    feedbackActions(feedback)
                }
            }
        }
        .padding(.leading, PPSpace.md)
        .padding(.trailing, PPSpace.xs)
        .padding(.vertical, PPSpace.xxs)
        .background(
            Color.ppSurfaceElevated.opacity(reduceTransparency ? 1 : 0.96)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .strokeBorder(Color.ppSurfaceBorder, lineWidth: borderWidth)
        }
        .shadow(
            color: PPShadow.subtle.color,
            radius: PPShadow.subtle.radius,
            x: PPShadow.subtle.x,
            y: PPShadow.subtle.y
        )
        .padding(.horizontal, PPSpace.sm)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pp.commerce.feedback")
    }

    private func feedbackMessage(_ feedback: Feedback) -> some View {
        HStack(alignment: .top, spacing: Metrics.spacing) {
            Image(
                systemName: feedback.kind == .success
                    ? "checkmark.circle.fill"
                    : "exclamationmark.triangle.fill"
            )
            .foregroundStyle(
                feedback.kind == .success ? theme.success : Color.ppError
            )
            .accessibilityHidden(true)

            Text(feedback.message)
                .font(PPAccessoryTypography.caption)
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func feedbackActions(_ feedback: Feedback) -> some View {
        HStack(spacing: PPSpace.xs) {
            if let retryIntent = feedback.retryIntent {
                Button {
                    retry(retryIntent)
                } label: {
                    Text(verbatim: copy.retry)
                        .font(PPAccessoryTypography.captionBold)
                        .foregroundStyle(theme.brand)
                        .frame(minHeight: 44)
                        .padding(.horizontal, PPSpace.xs)
                }
                .buttonStyle(PPCommercePressButtonStyle(reduceMotion: reduceMotion))
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
            .buttonStyle(PPCommercePressButtonStyle(reduceMotion: reduceMotion))
            .foregroundStyle(theme.secondaryText)
            .accessibilityLabel(Text(verbatim: copy.dismiss))
        }
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
                color: colorScheme == .dark ? .clear : PPShadow.card.color,
                radius: colorScheme == .dark ? 0 : PPShadow.card.radius,
                x: PPShadow.card.x,
                y: colorScheme == .dark ? 0 : PPShadow.card.y
            )
    }
}

// MARK: - State and async work

@available(iOS 16.0, *)
private extension PPCommerceCartHolder {
    var displayQuantity: Int {
        clamped(pendingQuantity ?? quantity)
    }

    var totalPrice: Decimal {
        item.unitPrice * Decimal(max(1, displayQuantity))
    }

    var formattedPrice: String {
        totalPrice.formatted(
            .currency(code: item.currencyCode)
                .precision(.fractionLength(0))
                .locale(formattingLocale)
        )
    }

    var formattedQuantity: String {
        displayQuantity.formatted(.number.locale(formattingLocale))
    }

    var formattingLocale: Locale {
        Locale(identifier: layoutDirection == .rightToLeft ? "ar_QA" : "en_QA")
    }

    var readOnlyQuantityBinding: Binding<Int> {
        Binding(
            get: { displayQuantity },
            set: { _ in }
        )
    }

    var animatedCartControlIsEnabled: Bool {
        if isSyncingQuantity && displayQuantity == 0 {
            return false
        }

        switch criticalPhase {
        case .paying, .paid:
            return false
        case .adding, .none:
            return true
        }
    }

    func quantityAccessibilityValue(_ value: Int) -> String {
        let baseValue = String(
            format: copy.quantityInCartFormat,
            locale: quantityAccessibilityLocale,
            value
        )
        return isSyncingQuantity
            ? "\(baseValue)، \(copy.updatingQuantity)"
            : baseValue
    }

    var quantityAccessibilityLocale: Locale {
        formattingLocale
    }

    var actionControlHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? max(Metrics.controlHeight, 52)
            : Metrics.controlHeight
    }

    var cartAccessibilityLabel: String {
        displayQuantity > 0
            ? String(format: copy.cartItemsFormat, formattedQuantity)
            : copy.cartEmpty
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

    func clamped(_ proposedQuantity: Int) -> Int {
        min(item.maximumQuantity, max(0, proposedQuantity))
    }

    func addFromAnimatedControl() async throws -> AnimatedAddToCartOutcome {
        guard displayQuantity == 0,
              criticalPhase == nil,
              !isSyncingQuantity
        else {
            throw CancellationError()
        }

        feedback = nil
        pendingQuantity = nil
        criticalPhase = .adding
        actions.track(.addTapped(productID: item.id))
        PPCommerceHaptics.medium()

        do {
            let returnedQuantity = try await actions.add()
            try Task.checkCancellation()

            let confirmed = max(1, clamped(returnedQuantity))
            confirmedQuantity = confirmed
            withAnimation(stateAnimation) {
                quantity = confirmed
                criticalPhase = nil
            }

            actions.track(
                .addSucceeded(productID: item.id, quantity: confirmed)
            )
            return AnimatedAddToCartOutcome(
                cartCount: confirmed,
                addedQuantity: 1
            )
        } catch is CancellationError {
            criticalPhase = nil
            throw CancellationError()
        } catch {
            criticalPhase = nil
            actions.track(
                .operationFailed(productID: item.id, operation: .add)
            )
            throw error
        }
    }

    func requestQuantity(_ proposedQuantity: Int) {
        guard criticalPhase == nil else { return }

        let requested = clamped(proposedQuantity)
        guard requested != displayQuantity else { return }

        quantityRevision += 1
        pendingQuantity = requested

        withAnimation(stateAnimation) {
            quantity = requested
            feedback = nil
        }

        isSyncingQuantity = true
        actions.track(.quantityChanged(productID: item.id, quantity: requested))
        PPCommerceHaptics.light()

        startQuantitySyncIfNeeded()
    }

    func startQuantitySyncIfNeeded() {
        guard quantityTask == nil else { return }

        quantityTask = Task { @MainActor in
            defer { quantityTask = nil }

            while !Task.isCancelled {
                let revision = quantityRevision

                do {
                    // Coalesce taps that arrive before a write starts. If a
                    // newer intent arrives in flight, serialize it next.
                    try await Task.sleep(nanoseconds: 220_000_000)
                    try Task.checkCancellation()
                    guard revision == quantityRevision else { continue }

                    let requested = clamped(pendingQuantity ?? quantity)
                    let returnedQuantity = try await actions.updateQuantity(
                        requested
                    )
                    try Task.checkCancellation()

                    let confirmed = clamped(returnedQuantity)
                    confirmedQuantity = confirmed
                    guard revision == quantityRevision else { continue }

                    withAnimation(stateAnimation) {
                        quantity = confirmed
                        pendingQuantity = nil
                        isSyncingQuantity = false
                    }
                    actions.track(
                        .quantitySynced(
                            productID: item.id,
                            quantity: confirmed
                        )
                    )
                    return
                } catch is CancellationError {
                    return
                } catch {
                    guard revision == quantityRevision else { continue }
                    let failedQuantity = clamped(
                        pendingQuantity ?? quantity
                    )

                    withAnimation(stateAnimation) {
                        pendingQuantity = nil
                        quantity = confirmedQuantity
                        isSyncingQuantity = false
                    }
                    actions.track(
                        .operationFailed(
                            productID: item.id,
                            operation: .quantity
                        )
                    )
                    presentFailure(
                        copy.quantityFailed,
                        retry: .quantity(failedQuantity)
                    )
                    return
                }
            }
        }
    }

    func beginPayment() {
        guard criticalPhase == nil, !isSyncingQuantity else { return }

        let payingQuantity = max(1, displayQuantity)
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
        pendingQuantity = nil
        isSyncingQuantity = false
    }
}

// MARK: - Adaptive styling

@available(iOS 16.0, *)
private extension PPCommerceCartHolder {
    var needsExpandedLayout: Bool {
        dynamicTypeSize >= .xxLarge
    }

    var stateAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.88)
    }

    var numberTransition: AnyTransition {
        .opacity
    }

    var feedbackTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .scale(scale: 0.98).combined(with: .opacity)
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
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.90 : 1)
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.22, dampingFraction: 0.86),
                value: configuration.isPressed
            )
    }
}

private enum PPCommerceHaptics {
    @MainActor
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.68)
    }

    @MainActor
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 0.78)
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
                .padding(.horizontal, 16)
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
