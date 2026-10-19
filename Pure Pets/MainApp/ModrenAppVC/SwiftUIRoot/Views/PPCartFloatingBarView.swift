//
//  PPCartFloatingBarView.swift
//  Pure Pets
//

import SwiftUI

/// Presentation only. PPRootStore owns the quantity, total, six-second collapse,
/// haptics and expand-then-open action; the overlay owns placement and clearance.
public struct PPCartFloatingBarView: View {
    public let state: PPCartFloatingBarState
    public let onTap: () -> Void

    private let copy: PPCartFloatingBarCopy

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.legibilityWeight) private var legibilityWeight
    @ScaledMetric(relativeTo: .callout) private var symbolSize: CGFloat = 18

    public init(state: PPCartFloatingBarState, onTap: @escaping () -> Void) {
        self.state = state
        self.onTap = onTap
        self.copy = PPCartFloatingBarCopy(state: state)
    }

    public var body: some View {
        Button(action: onTap) {
            Group {
                if state.isCollapsed {
                    compactContent
                } else {
                    expandedContent
                }
            }
            .background { surface }
            .contentShape(
                RoundedRectangle(
                    cornerRadius: state.isCollapsed
                        ? PPBottomDecisionBarGeometry.utilityControlSize / 2
                        : PPCorner.card,
                    style: .continuous
                )
            )
        }
        .buttonStyle(PPCartFloatingBarPressStyle())
        .animation(
            reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.88),
            value: state.isCollapsed
        )
        .transaction { transaction in
            if reduceMotion {
                // Also suppress the store's enclosing withAnimation transaction.
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .environment(\.layoutDirection, copy.isRTL ? .rightToLeft : .leftToRight)
        .environment(\.locale, copy.locale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(copy.cartLabel)
        .accessibilityValue(copy.accessibilityValue)
        .accessibilityHint(state.isCollapsed ? copy.expandHint : copy.openHint)
        .accessibilityIdentifier("floating-cart")
    }

    // MARK: - One cart, two levels of detail

    private var compactContent: some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: "cart.fill")
                .font(.system(size: symbolSize, weight: .semibold))

            Text(verbatim: copy.badge)
                .font(.ppBeirutiBold(size: 20, relativeTo: .headline))
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, PPSpace.base)
        .padding(.vertical, PPSpace.md)
        .frame(
            minWidth: PPBottomDecisionBarGeometry.utilityControlSize,
            minHeight: PPBottomDecisionBarGeometry.utilityControlSize
        )
        // Intrinsic width is intentional: the parent reports this exact hit region.
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            contextLine
            amountAndAction
        }
        .padding(.horizontal, PPSpace.lg)
        .padding(.vertical, PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var contextLine: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                quantityLabel
                totalLabel
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: PPSpace.md) {
                totalLabel
                Spacer(minLength: PPSpace.sm)
                quantityLabel
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var quantityLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
            Image(systemName: "cart.fill")
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(accent)

            Text(verbatim: copy.count)
                .font(.ppBeirutiBold(size: 16, relativeTo: .subheadline))
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var totalLabel: some View {
        Text(verbatim: copy.totalLabel)
            .font(contextFont)
            .foregroundStyle(secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var amountAndAction: some View {
        if #available(iOS 16.0, *), dynamicTypeSize < .xxxLarge {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: PPSpace.lg) {
                    // Measure at ideal width: this candidate cannot win by
                    // shrinking the amount before trying the stacked layout.
                    uncompressedAmount
                        .fixedSize(horizontal: true, vertical: true)
                    Spacer(minLength: 0)
                    reviewAction
                        .fixedSize(horizontal: true, vertical: true)
                }
                stackedAmountAndAction
            }
        } else {
            stackedAmountAndAction
        }
    }

    private var stackedAmountAndAction: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            flexibleAmount
            reviewAction
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var uncompressedAmount: some View {
        if let amount = copy.amount {
            HStack(alignment: .firstTextBaseline, spacing: PPSpace.xs) {
                amountText(amount)
                currencyLabel
            }
        } else {
            amountUnavailable
        }
    }

    @ViewBuilder
    private var flexibleAmount: some View {
        if let amount = copy.amount {
            if #available(iOS 16.0, *) {
                ViewThatFits(in: .horizontal) {
                    uncompressedAmount
                        .fixedSize(horizontal: true, vertical: true)
                    stackedCurrency(amount: amount)
                }
            } else {
                stackedCurrency(amount: amount)
            }
        } else {
            amountUnavailable
        }
    }

    private func stackedCurrency(amount: String) -> some View {
        PPCartFloatingBarAmountFit {
            amountText(amount)
        } currency: {
            currencyLabel
        } fallback: {
            amountUnavailable
        }
        // Discard measurements when glyphs or their Dynamic Type scale change.
        // This identity belongs only to the readout, never the cart Button.
        .id(amount)
        .id(dynamicTypeSize)
    }

    private func amountText(_ amount: String) -> some View {
        Text(verbatim: amount)
            .font(.ppBeirutiBold(size: 32, relativeTo: .title))
            .monospacedDigit()
            .foregroundStyle(Color.ppTextPrimary)
            .environment(\.layoutDirection, .leftToRight)
    }

    private var currencyLabel: some View {
        Text(verbatim: copy.currency)
            .font(contextFont)
            .foregroundStyle(secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var amountUnavailable: some View {
        Text(verbatim: copy.reviewTotal)
            .font(.ppBeirutiBold(size: 23, relativeTo: .title3))
            .foregroundStyle(Color.ppTextPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var reviewAction: some View {
        HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
            Text(verbatim: copy.reviewAction)
                .font(.ppBeirutiBold(size: 17, relativeTo: .callout))
                .fixedSize(horizontal: false, vertical: true)

            Image(systemName: "arrow.forward")
                .font(.system(size: symbolSize, weight: .semibold))
                .fixedSize()
        }
        .foregroundStyle(accent)
    }

    // MARK: - Opaque, semantic surfaces

    private var contextFont: Font {
        legibilityWeight == .bold
            ? .ppBeirutiBold(size: 14, relativeTo: .subheadline)
            : .ppBeirutiMedium(size: 14, relativeTo: .subheadline)
    }

    private var accent: Color {
        contrast == .increased ? .ppTextPrimary : .ppAccentText
    }

    private var secondaryInk: Color {
        contrast == .increased ? .ppTextPrimary : .ppTextSecondary
    }

    @ViewBuilder
    private var surface: some View {
        if state.isCollapsed {
            Capsule()
                .fill(contrast == .increased ? Color.ppPrimaryDarker : .ppPrimary)
                .overlay {
                    Capsule().strokeBorder(
                        Color.white.opacity(contrast == .increased ? 0.72 : 0.18),
                        lineWidth: contrast == .increased ? 1.5 : 1
                    )
                }
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12),
                    radius: PPShadow.button.radius,
                    y: PPShadow.button.y
                )
        } else {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .fill(Color.ppSurfaceElevated)
                .overlay {
                    RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                        .strokeBorder(
                            contrast == .increased
                                ? Color.ppTextPrimary.opacity(0.5)
                                : Color.ppSurfaceBorder,
                            lineWidth: contrast == .increased ? 1.5 : 1
                        )
                }
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.30) : PPShadow.card.color,
                    radius: PPShadow.card.radius,
                    y: PPShadow.card.y
                )
        }
    }
}

// MARK: - Complete monetary readouts, including the iOS 15 fallback

private struct PPCartFloatingBarAmountMeasurement: Equatable {
    var availableWidth: CGFloat = 0
    var numberWidth: CGFloat = 0
}

private struct PPCartFloatingBarAmountMeasurementKey: PreferenceKey {
    static let defaultValue = PPCartFloatingBarAmountMeasurement()

    static func reduce(
        value: inout PPCartFloatingBarAmountMeasurement,
        nextValue: () -> PPCartFloatingBarAmountMeasurement
    ) {
        let next = nextValue()
        value.availableWidth = max(value.availableWidth, next.availableWidth)
        value.numberWidth = max(value.numberWidth, next.numberWidth)
    }
}

/// Geometry is presentation state only. Measure the exact SwiftUI glyphs at
/// their current Dynamic Type size before permitting any numeric fitting.
/// The localized fallback remains readable while a measurement is pending.
private struct PPCartFloatingBarAmountFit<Number: View, Currency: View, Fallback: View>: View {
    private let number: Number
    private let currency: Currency
    private let fallback: Fallback

    @State private var measurement = PPCartFloatingBarAmountMeasurement()

    private let minimumScale: CGFloat = 0.55

    init(
        @ViewBuilder number: () -> Number,
        @ViewBuilder currency: () -> Currency,
        @ViewBuilder fallback: () -> Fallback
    ) {
        self.number = number()
        self.currency = currency()
        self.fallback = fallback()
    }

    private var canShowCompleteNumber: Bool {
        measurement.availableWidth > 0 && measurement.numberWidth > 0
            && measurement.numberWidth * minimumScale + 2 <= measurement.availableWidth
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if canShowCompleteNumber {
                number
                    .lineLimit(1)
                    .minimumScaleFactor(minimumScale)
                currency
            } else {
                fallback
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PPCartFloatingBarAmountMeasurementKey.self,
                    value: PPCartFloatingBarAmountMeasurement(availableWidth: proxy.size.width)
                )
            }
            .allowsHitTesting(false)
        }
        .background(alignment: .leading) {
            number
                .fixedSize(horizontal: true, vertical: true)
                .hidden()
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: PPCartFloatingBarAmountMeasurementKey.self,
                            value: PPCartFloatingBarAmountMeasurement(numberWidth: proxy.size.width)
                        )
                    }
                }
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
        .onPreferenceChange(PPCartFloatingBarAmountMeasurementKey.self) { next in
            guard next != measurement else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                measurement = next
            }
        }
    }
}

// MARK: - App-language presentation, never cart arithmetic

private struct PPCartFloatingBarCopy {
    let isRTL: Bool
    let locale: Locale
    let badge: String
    let count: String
    let amount: String?
    let currency: String
    let accessibilityValue: String

    let cartLabel: String
    let totalLabel: String
    let reviewAction: String
    let reviewTotal: String
    let expandHint: String
    let openHint: String

    init(state: PPCartFloatingBarState) {
        cartLabel = Self.localized("a11y_btn_cart")
        totalLabel = Self.localized("Total")
        reviewAction = Self.localized("checkout_review_cart_action")
        reviewTotal = Self.localized("floating_cart_review_total")
        expandHint = Self.localized("cart_summary_expand")
        openHint = Self.localized("a11y_btn_cart_hint")
        isRTL = Language.isRTL()
        locale = Locale(identifier: isRTL ? "ar_QA" : "en_QA")
        let formats = isRTL ? Self.arabicFormats : Self.englishFormats
        let quantity = max(0, state.itemCount)
        let exactCount = formats.count.string(from: NSNumber(value: quantity)) ?? String(quantity)
        let badgeCount = formats.count.string(from: NSNumber(value: min(quantity, 99))) ?? String(min(quantity, 99))
        badge = Self.isolatedNumber(quantity > 99 ? badgeCount + "+" : badgeCount)

        let countKey: String
        switch quantity {
        case 0: countKey = "floating_cart_count_zero"
        case 1: countKey = "floating_cart_count_one"
        case 2: countKey = "floating_cart_count_two"
        default:
            let remainder = quantity % 100
            if isRTL && (3...10).contains(remainder) {
                countKey = "floating_cart_count_few"
            } else if isRTL && (11...99).contains(remainder) {
                countKey = "floating_cart_count_many"
            } else {
                countKey = "floating_cart_count_other"
            }
        }
        count = String(format: Self.localized(countKey), locale: locale, Self.isolatedNumber(exactCount))
        let displayCurrency = Self.localized("Rials")
        currency = displayCurrency

        // Format the supplied finalTotal; never substitute a made-up zero or
        // derive a subtotal. Excessively long values remain available to VoiceOver.
        let formattedAmount = state.totalAmount.isFinite && state.totalAmount >= 0
            ? formats.amount.string(from: NSNumber(value: state.totalAmount)) : nil
        amount = formattedAmount.flatMap { value in
            value.count <= 20 ? Self.isolatedNumber(value) : nil
        }
        let spokenAmount = formattedAmount.map {
            Self.isolatedNumber($0) + " " + displayCurrency
        } ?? reviewTotal
        accessibilityValue = String(
            format: Self.localized("floating_cart_accessibility_value"),
            locale: locale,
            count,
            spokenAmount
        )
    }

    private static func localized(_ key: String) -> String {
        Language.get(key, alter: key) ?? key
    }

    private static func isolatedNumber(_ value: String) -> String {
        "\u{2066}" + value + "\u{2069}"
    }

    /// Construct once per app language. These formatters are never mutated
    /// after construction, and no formatting runs inside the view's body.
    private struct Formats {
        let count: NumberFormatter
        let amount: NumberFormatter

        init(localeIdentifier: String) {
            let locale = Locale(identifier: localeIdentifier)
            count = NumberFormatter()
            count.locale = locale
            count.numberStyle = .decimal
            count.usesGroupingSeparator = false
            count.maximumFractionDigits = 0

            amount = NumberFormatter()
            amount.locale = locale
            amount.numberStyle = .decimal
            amount.minimumFractionDigits = 2
            amount.maximumFractionDigits = 2
            amount.usesGroupingSeparator = true
        }
    }

    private static let arabicFormats = Formats(localeIdentifier: "ar_QA")
    private static let englishFormats = Formats(localeIdentifier: "en_QA")
}

private struct PPCartFloatingBarPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(
            PPCartFloatingBarPressFeedback(isPressed: configuration.isPressed)
        )
    }
}

/// Environment is read by an installed modifier, including Reduce Motion
/// changes made while the cart is visible.
private struct PPCartFloatingBarPressFeedback: ViewModifier {
    let isPressed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .scaleEffect(isEnabled && isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(isEnabled ? (isPressed ? 0.90 : 1) : 0.46)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: isPressed
            )
    }
}
