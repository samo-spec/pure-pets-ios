//
//  PPPremuimChekoutView.swift
//  Pure Pets
//
//  Checkout Signal -- a SwiftUI-backed decision surface exposed through the
//  legacy Objective-C runtime contract used by Cart and Payment.
//

import SwiftUI
import UIKit

// MARK: - Source-bound text, color, and layout

private enum PPCheckoutSignalText {
    static func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private enum PPCheckoutSignalFont {
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: style)
    }

    static func bold(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: style)
    }

    static func medium(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom("Beiruti-Medium", size: size, relativeTo: style)
    }
}

private enum PPCheckoutSignalGeometry {
    static let checkoutMaximumWidth: CGFloat = 236
    static let amountMinimumWidth: CGFloat = 124
    static let sideBySideDecisionMinimumWidth: CGFloat = 680
    static let itemPreviewHeight: CGFloat = 74
    static let accessibilityItemPreviewHeight: CGFloat = 116
    static let collapsedImageSize: CGFloat = 52
    static let expandedImageSize: CGFloat = 60
    static let checkoutTapDebounce: TimeInterval = 0.45
    static let feedbackDuration: TimeInterval = 0.18
    static let receiptVerticalDividerHeight: CGFloat = PPSpace.xxxxl

    @MainActor
    static var hairline: CGFloat {
        let scale = PPPremiumCheckoutScreenScale.current ?? UIScreen.main.scale
        return UIAccessibility.isDarkerSystemColorsEnabled
            ? 1
            : 1 / max(scale, 1)
    }
}

/// `UIScreen.main` is deprecated on iOS 17+. Capture the scale from the active
/// window when available so the hairline keeps resolving under scene-based
/// lifecycle and Stage Manager.
private enum PPPremiumCheckoutScreenScale {
    @MainActor static var current: CGFloat? {
        UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .screen.scale
    }
}

private enum PPCheckoutSignalCurrency {
    static var symbol: String {
        PPCheckoutSignalText.localized("Rials")
    }

    static func number(_ value: CGFloat) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_QA")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: Double(value)))
            ?? String(format: "%.2f", Double(value))
    }

    static func format(_ value: CGFloat) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_QA")
        formatter.currencyCode = "QAR"
        formatter.currencySymbol = symbol
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: Double(value)))
            ?? NSNumber(value: Double(value)).stringValue
    }
}

private func ppCheckoutSignalSemantic() -> UISemanticContentAttribute {
    Language.semanticAttributeForCurrentLanguage()
}

private func ppCheckoutSignalIsRTL() -> Bool {
    ppCheckoutSignalSemantic() == .forceRightToLeft
}

private func ppCheckoutSignalLTRIsolate(_ value: String) -> String {
    "\u{2066}\(value)\u{2069}"
}

private func ppCheckoutSignalItemCount(_ count: Int) -> String {
    let format = PPCheckoutSignalText.localized("checkout_horizon_item_count_format")
    return String.localizedStringWithFormat(
        format,
        ppCheckoutSignalLTRIsolate(String(max(count, 0)))
    )
}

private func ppCheckoutSignalItemMetadata(quantity: Int, amount: CGFloat) -> String {
    let format = PPCheckoutSignalText.localized("checkout_horizon_item_meta_format")
    return String.localizedStringWithFormat(
        format,
        ppCheckoutSignalLTRIsolate("x\(max(quantity, 1))"),
        ppCheckoutSignalLTRIsolate(PPCheckoutSignalCurrency.format(amount))
    )
}

// MARK: - State model

private enum PPCheckoutSignalStatusKind: String {
    case ready
    case loading
    case empty
    case error
    case offline
    case restricted
    case success

    init(rawObjectiveCValue: String?) {
        let normalized = (rawObjectiveCValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        self = PPCheckoutSignalStatusKind(rawValue: normalized) ?? .ready
    }

    var defaultTitleKey: String {
        switch self {
        case .ready:
            return "checkout_summary_ready_title"
        case .loading:
            return "checkout_summary_loading_title"
        case .empty:
            return "checkout_summary_empty_title"
        case .error:
            return "checkout_summary_error_title"
        case .offline:
            return "checkout_summary_offline_title"
        case .restricted:
            return "checkout_summary_restricted_title"
        case .success:
            return "checkout_summary_success_title"
        }
    }

    var defaultSubtitleKey: String {
        switch self {
        case .ready:
            return "checkout_summary_ready_subtitle"
        case .loading:
            return "checkout_summary_loading_subtitle"
        case .empty:
            return "checkout_summary_empty_subtitle"
        case .error:
            return "checkout_summary_error_subtitle"
        case .offline:
            return "checkout_summary_offline_subtitle"
        case .restricted:
            return "checkout_summary_restricted_subtitle"
        case .success:
            return "checkout_summary_success_subtitle"
        }
    }

    var symbolName: String {
        switch self {
        case .ready:
            return "cart.fill"
        case .loading:
            return "hourglass"
        case .empty:
            return "bag"
        case .error:
            return "exclamationmark.triangle.fill"
        case .offline:
            return "wifi.slash"
        case .restricted:
            return "person.crop.circle.badge.exclamationmark"
        case .success:
            return "checkmark.circle.fill"
        }
    }

    var isBlockingAction: Bool {
        switch self {
        case .empty, .offline:
            return true
        case .ready, .loading, .error, .restricted, .success:
            return false
        }
    }

    func tint(protectedActive _: Bool) -> Color {
        switch self {
        case .ready:
            return .ppPrimary
        case .loading:
            return .ppPrimary
        case .empty:
            return .ppTextTertiary
        case .error:
            return .ppError
        case .offline:
            return .ppWarning
        case .restricted:
            return .ppInfo
        case .success:
            return .ppSuccess
        }
    }
}

private struct PPCheckoutSignalStatus {
    let kind: PPCheckoutSignalStatusKind
    let title: String
    let subtitle: String

    static func automatic(
        kind: PPCheckoutSignalStatusKind,
        title: String? = nil,
        subtitle: String? = nil
    ) -> PPCheckoutSignalStatus {
        let cleanTitle = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSubtitle = (subtitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return PPCheckoutSignalStatus(
            kind: kind,
            title: cleanTitle.isEmpty ? PPCheckoutSignalText.localized(kind.defaultTitleKey) : cleanTitle,
            subtitle: cleanSubtitle.isEmpty ? PPCheckoutSignalText.localized(kind.defaultSubtitleKey) : cleanSubtitle
        )
    }
}

private struct PPCheckoutSignalItemSnapshot: Identifiable {
    let id: String
    let name: String
    let quantity: Int
    let amount: CGFloat
    let imageURL: String
}

private struct PPCheckoutSignalViewState {
    var itemsTotal: CGFloat
    var shippingFee: CGFloat
    var subtotal: CGFloat
    var totalText: String
    var totalNumberText: String
    var currencySymbolText: String
    var itemCountText: String
    var checkoutTitle: String
    var checkoutImage: UIImage?
    var showDetails: Bool
    var showsItemsPreview: Bool
    var collapsible: Bool
    var summaryCollapsed: Bool
    var checkoutLoading: Bool
    var protectedStateIsActive: Bool
    var paymentFeedbackActive: Bool
    var feedbackAccent: UIColor?
    var safeAreaBottom: CGFloat
    var availableWidth: CGFloat
    var isRightToLeft: Bool
    var backgroundImage: UIImage?
    var manualStatus: PPCheckoutSignalStatus?
    var items: [PPCheckoutSignalItemSnapshot]

    var totalQuantity: Int {
        items.reduce(0) { $0 + max($1.quantity, 0) }
    }

    var hasCheckoutContent: Bool {
        totalQuantity > 0 || subtotal > 0.009
    }

    var effectiveStatus: PPCheckoutSignalStatus {
        if checkoutLoading {
            return .automatic(kind: .loading)
        }
        if let manualStatus {
            return manualStatus
        }
        if !hasCheckoutContent {
            return .automatic(kind: .empty)
        }
        return .automatic(kind: .ready)
    }

    var isActionEnabled: Bool {
        !checkoutLoading && hasCheckoutContent && !effectiveStatus.kind.isBlockingAction
    }

    var usesSideBySideDecision: Bool {
        availableWidth >= PPCheckoutSignalGeometry.sideBySideDecisionMinimumWidth
    }
}

// MARK: - Image bridge

private final class PPCheckoutSignalImageHostView: UIView {
    private let imageView = UIImageView()
    private var representedKey = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildView()
    }

    deinit {
        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
    }

    private func buildView() {
        backgroundColor = .clear
        isAccessibilityElement = false
        semanticContentAttribute = .forceLeftToRight

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        imageView.contentMode = .center
        imageView.isAccessibilityElement = false
        imageView.semanticContentAttribute = .forceLeftToRight
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func configure(imageURL: String, placeholderSystemName: String) {
        let trimmedURL = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextKey = "\(trimmedURL)|\(placeholderSystemName)"
        guard representedKey != nextKey else { return }
        representedKey = nextKey

        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
        let configuration = UIImage.SymbolConfiguration(
            pointSize: 17,
            weight: .semibold,
            scale: .medium
        )
        let placeholder = UIImage(systemName: placeholderSystemName, withConfiguration: configuration)
        imageView.image = placeholder
        imageView.tintColor = .ppTextSecondary
        imageView.contentMode = .center

        guard !trimmedURL.isEmpty else { return }
        let expectedKey = nextKey
        PPImageLoaderManager.shared().setImage(
            on: imageView,
            url: trimmedURL,
            placeholder: placeholder,
            transitionStyle: .none
        ) { [weak self] image, _ in
            let apply = {
                guard let self,
                      self.representedKey == expectedKey,
                      let image else {
                    return
                }
                self.imageView.contentMode = .scaleAspectFit
                self.imageView.image = image.withRenderingMode(.alwaysOriginal)
            }
            if Thread.isMainThread {
                apply()
            } else {
                DispatchQueue.main.async(execute: apply)
            }
        }
    }

    func cancelLoad() {
        representedKey = ""
        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
    }
}

private struct PPCheckoutSignalImage: UIViewRepresentable {
    let imageURL: String
    let placeholderSystemName: String

    func makeUIView(context: Context) -> PPCheckoutSignalImageHostView {
        PPCheckoutSignalImageHostView()
    }

    func updateUIView(_ uiView: PPCheckoutSignalImageHostView, context: Context) {
        uiView.configure(imageURL: imageURL, placeholderSystemName: placeholderSystemName)
    }

    static func dismantleUIView(_ uiView: PPCheckoutSignalImageHostView, coordinator: ()) {
        uiView.cancelLoad()
    }
}

// MARK: - SwiftUI surface

private struct PPCheckoutSignalRootView: View {
    let state: PPCheckoutSignalViewState
    let onDisclosure: () -> Void
    let onCheckout: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var layoutDirection: LayoutDirection {
        state.isRightToLeft ? .rightToLeft : .leftToRight
    }

    private var status: PPCheckoutSignalStatus {
        state.effectiveStatus
    }

    private var statusTint: Color {
        status.kind.tint(protectedActive: state.protectedStateIsActive)
    }

    var body: some View {
        VStack(spacing: 0) {
            surface
        }
        .environment(\.layoutDirection, layoutDirection)
        .padding(.top, PPSpace.xs)
        .padding(.horizontal, PPSpace.md)
        .padding(.bottom, state.safeAreaBottom + PPBottomDecisionBarGeometry.bottomBreathingRoom)
    }

    private var surface: some View {
        VStack(alignment: .leading, spacing: isAccessibilityLayout ? PPSpace.base : PPSpace.md) {
            signalHeader
            decisionCore
            if !state.summaryCollapsed {
                if shouldShowReceipt {
                    receipt
                        .transition(.opacity)
                }
                if shouldShowItemsPreview {
                    itemPreview
                        .transition(.opacity)
                }
            }
        }
        .padding(PPBottomDecisionBarGeometry.contentPadding)
        .background(surfaceBackground)
        .overlay(surfaceBorder)
        .clipShape(RoundedRectangle(
            cornerRadius: PPCorner.card,
            style: .continuous
        ))
        .shadow(
            color: surfaceShadow.color,
            radius: surfaceShadow.radius,
            x: surfaceShadow.x,
            y: surfaceShadow.y
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("checkoutSignal.surface")
        .animation(
            reduceMotion ? nil : .easeOut(duration: PPCheckoutSignalGeometry.feedbackDuration),
            value: state.paymentFeedbackActive
        )
    }

    @ViewBuilder
    private var surfaceBackground: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: PPCorner.card,
                style: .continuous
            )
            .fill(Color.ppSurfaceElevated)

            if let image = state.backgroundImage, !reduceTransparency {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(colorScheme == .dark ? 0.04 : 0.06)
                    .accessibilityHidden(true)
            }
        }
    }

    private var surfaceBorder: some View {
        RoundedRectangle(
            cornerRadius: PPCorner.card,
            style: .continuous
        )
        .stroke(
            colorSchemeContrast == .increased
                ? Color.ppTextPrimary.opacity(0.52)
                : Color.ppSurfaceBorder.opacity(colorScheme == .dark ? 0.82 : 0.70),
            lineWidth: colorSchemeContrast == .increased ? 1.2 : PPCheckoutSignalGeometry.hairline
        )
    }

    /// Centralised shadow so light/dark/increased-contrast all stay aligned with
    /// the `PPShadow.card` design token. Increased contrast kills the shadow to
    /// favour the explicit border.
    private var surfaceShadow: PPShadow {
        guard colorSchemeContrast != .increased else { return .clear }
        return colorScheme == .dark
            ? PPShadow(color: .black.opacity(0.22), radius: PPShadow.card.radius,
                       x: PPShadow.card.x, y: PPShadow.card.y)
            : PPShadow(color: .black.opacity(0.08), radius: PPShadow.card.radius,
                       x: PPShadow.card.x, y: PPShadow.card.y)
    }

    private var signalHeader: some View {
        HStack(alignment: .center, spacing: PPSpace.sm) {
            statusSummary
            Spacer(minLength: PPSpace.sm)
            if state.collapsible {
                disclosureButton
                    .accessibilitySortPriority(4)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var statusSummary: some View {
        HStack(alignment: .top, spacing: PPSpace.sm) {
            Image(systemName: status.kind.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(statusTint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(statusTint.opacity(colorScheme == .dark ? 0.16 : 0.10)))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                Text(status.title)
                    .font(PPCheckoutSignalFont.bold(14, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(isAccessibilityLayout ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)

                if shouldShowStatusSubtitle {
                    Text(status.subtitle)
                        .font(PPCheckoutSignalFont.medium(12, relativeTo: .caption))
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(isAccessibilityLayout ? 4 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.title)
        .accessibilityValue(status.subtitle)
        .accessibilitySortPriority(2)
    }

    private var shouldShowStatusSubtitle: Bool {
        !state.summaryCollapsed || status.kind != .ready || isAccessibilityLayout
    }

    private var disclosureButton: some View {
        Button(action: onDisclosure) {
            Image(systemName: state.summaryCollapsed ? "chevron.up" : "chevron.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.ppTextSecondary)
                .frame(width: PPBottomDecisionBarGeometry.utilityControlSize, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PPCheckoutSignalText.localized(
            state.summaryCollapsed ? "cart_summary_expand" : "cart_summary_collapse"
        ))
    }

    private var decisionCore: some View {
        Group {
            if state.usesSideBySideDecision && !isAccessibilityLayout {
                HStack(alignment: .center, spacing: PPSpace.lg) {
                    orderSnapshot
                    primaryAction
                        .frame(width: PPCheckoutSignalGeometry.checkoutMaximumWidth)
                }
            } else {
                VStack(alignment: .leading, spacing: isAccessibilityLayout ? PPSpace.base : PPSpace.md) {
                    orderSnapshot
                    primaryAction
                }
            }
        }
    }

    private var orderSnapshot: some View {
        Group {
            if usesVerticalSnapshot {
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    HStack(alignment: .center, spacing: PPSpace.md) {
                        imageCluster(size: snapshotImageSize)
                        identityContent
                    }
                    amountBlock
                }
            } else {
                HStack(alignment: .center, spacing: PPSpace.md) {
                    imageCluster(size: snapshotImageSize)
                    identityContent
                    Spacer(minLength: PPSpace.sm)
                    amountBlock
                        .frame(
                            minWidth: PPCheckoutSignalGeometry.amountMinimumWidth,
                            alignment: state.isRightToLeft ? .trailing : .leading
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: state.isRightToLeft ? .trailing : .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PPCheckoutSignalText.localized("checkout_summary_total_label"))
        .accessibilityValue([state.totalText, primaryItemTitle, state.itemCountText].joined(separator: ", "))
        .accessibilitySortPriority(3)
    }

    private var usesVerticalSnapshot: Bool {
        isAccessibilityLayout || state.availableWidth < 360
    }

    private var snapshotImageSize: CGFloat {
        state.summaryCollapsed
            ? PPCheckoutSignalGeometry.collapsedImageSize
            : PPCheckoutSignalGeometry.expandedImageSize
    }

    private var identityContent: some View {
        VStack(alignment: .leading, spacing: PPSpace.xxs) {
            Text(primaryItemTitle)
                .font(PPCheckoutSignalFont.bold(
                    state.summaryCollapsed ? 15 : 17,
                    relativeTo: state.summaryCollapsed ? .subheadline : .headline
                ))
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(isAccessibilityLayout ? 3 : (state.summaryCollapsed ? 1 : 2))
                .fixedSize(horizontal: false, vertical: true)

            Text(state.itemCountText)
                .font(PPCheckoutSignalFont.medium(12, relativeTo: .caption))
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(isAccessibilityLayout ? 2 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: PPSpace.xxs) {
            Text(PPCheckoutSignalText.localized("checkout_summary_total_label"))
                .font(PPCheckoutSignalFont.medium(12, relativeTo: .caption))
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(1)

            amountAnchor
        }
        .frame(maxWidth: usesVerticalSnapshot ? .infinity : nil,
               alignment: state.isRightToLeft ? .trailing : .leading)
        .layoutPriority(2)
    }

    private var primaryItemTitle: String {
        guard let first = state.items.first else {
            return state.hasCheckoutContent
                ? PPCheckoutSignalText.localized("checkout_item_fallback")
                : PPCheckoutSignalText.localized("cartTitle")
        }
        return first.name
    }

    private func imageCluster(size: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            PPCheckoutSignalImage(
                imageURL: state.items.first?.imageURL ?? "",
                placeholderSystemName: state.hasCheckoutContent ? "pawprint.fill" : "bag"
            )
            .frame(width: size, height: size)
            .background(Circle().fill(Color.ppSurface))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.ppSurfaceBorder.opacity(0.74), lineWidth: PPCheckoutSignalGeometry.hairline))

            if state.totalQuantity > 0 {
                Text(ppCheckoutSignalLTRIsolate(String(state.totalQuantity)))
                    .font(PPCheckoutSignalFont.bold(10, relativeTo: .caption2))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, PPSpace.xs)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(Capsule().fill(Color.ppPrimary))
                    .overlay(Capsule().stroke(Color.ppSurfaceElevated, lineWidth: 2))
                    .offset(x: state.isRightToLeft ? -PPSpace.xs : PPSpace.xs, y: -PPSpace.xs)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHidden(true)
    }

    private var amountAnchor: some View {
        HStack(alignment: .firstTextBaseline, spacing: PPSpace.xs) {
            if state.isRightToLeft {
                amountNumber
                amountCurrencySymbol
            } else {
                amountCurrencySymbol
                amountNumber
            }
        }
        .frame(maxWidth: usesVerticalSnapshot ? .infinity : nil,
               alignment: state.isRightToLeft ? .trailing : .leading)
        .environment(\.layoutDirection, .leftToRight)
    }

    private var amountNumber: some View {
        Text(state.totalNumberText)
            .font(PPCheckoutSignalFont.display(
                state.summaryCollapsed ? 30 : 34,
                relativeTo: .largeTitle
            ))
            .foregroundStyle(Color.ppTextPrimary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(isAccessibilityLayout ? 0.86 : 0.72)
            .allowsTightening(true)
            .layoutPriority(2)
    }

    private var amountCurrencySymbol: some View {
        Text(state.currencySymbolText)
            .font(PPCheckoutSignalFont.bold(16, relativeTo: .title3))
            .foregroundStyle(Color.ppTextSecondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
    }

    private var primaryAction: some View {
        Button(action: onCheckout) {
            HStack(spacing: PPSpace.sm) {
                if state.checkoutLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.white)
                        .controlSize(.regular)
                        .accessibilityHidden(true)
                }

                Text(state.checkoutTitle)
                    .font(PPCheckoutSignalFont.bold(16, relativeTo: .headline))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if !state.checkoutLoading, let image = state.checkoutImage {
                    Image(uiImage: image)
                        .renderingMode(.template)
                        .font(.system(size: 17, weight: .semibold))
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: PPBottomDecisionBarGeometry.controlHeight)
            .padding(.horizontal, PPSpace.base)
        }
        .buttonStyle(PPCheckoutSignalPrimaryButtonStyle(
            enabled: state.isActionEnabled,
            feedbackActive: state.paymentFeedbackActive,
            feedbackAccent: state.feedbackAccent
        ))
        .disabled(!state.isActionEnabled)
        .accessibilityLabel(state.checkoutTitle)
        .accessibilityHint(PPCheckoutSignalText.localized("a11y_btn_checkout_hint"))
        .accessibilityValue(state.checkoutLoading ? PPCheckoutSignalText.localized("Loading") : "")
        .accessibilitySortPriority(5)
    }

    private var shouldShowReceipt: Bool {
        !state.summaryCollapsed && (state.showDetails || status.kind != .ready)
    }

    private var receipt: some View {
        VStack(spacing: 0) {
            divider
            if isAccessibilityLayout {
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    receiptMetric(
                        title: PPCheckoutSignalText.localized("checkout_summary_items_label"),
                        value: PPCheckoutSignalCurrency.format(state.itemsTotal),
                        symbol: "bag.fill"
                    )
                    divider
                    receiptMetric(
                        title: PPCheckoutSignalText.localized("checkout_summary_delivery_label"),
                        value: deliveryValue,
                        symbol: "shippingbox.fill"
                    )
                }
                .padding(.top, PPSpace.md)
            } else {
                HStack(alignment: .top, spacing: PPSpace.base) {
                    receiptMetric(
                        title: PPCheckoutSignalText.localized("checkout_summary_items_label"),
                        value: PPCheckoutSignalCurrency.format(state.itemsTotal),
                        symbol: "bag.fill"
                    )
                    verticalDivider
                    receiptMetric(
                        title: PPCheckoutSignalText.localized("checkout_summary_delivery_label"),
                        value: deliveryValue,
                        symbol: "shippingbox.fill"
                    )
                }
                .padding(.top, PPSpace.md)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(PPCheckoutSignalText.localized("checkout_summary_receipt_label"))
    }

    private var deliveryValue: String {
        state.shippingFee <= 0.009
            ? PPCheckoutSignalText.localized("Free")
            : PPCheckoutSignalCurrency.format(state.shippingFee)
    }

    private func receiptMetric(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            HStack(spacing: PPSpace.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.ppTextTertiary)
                    .frame(width: 18)
                    .accessibilityHidden(true)

                Text(title)
                    .font(PPCheckoutSignalFont.medium(13, relativeTo: .footnote))
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(isAccessibilityLayout ? 3 : 2)
            }

            Text(value)
                .font(PPCheckoutSignalFont.bold(16, relativeTo: .headline))
                .foregroundStyle(Color.ppTextPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.80)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: state.isRightToLeft ? .trailing : .leading)
                .environment(\.layoutDirection, .leftToRight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.ppSurfaceBorder.opacity(0.58))
            .frame(height: PPCheckoutSignalGeometry.hairline)
            .accessibilityHidden(true)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.ppSurfaceBorder.opacity(0.58))
            .frame(width: PPCheckoutSignalGeometry.hairline, height: 48)
            .accessibilityHidden(true)
    }

    private var shouldShowItemsPreview: Bool {
        !state.summaryCollapsed && state.showsItemsPreview && !state.items.isEmpty
    }

    private var itemPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: PPSpace.sm) {
                ForEach(state.items) { item in
                    itemCell(item)
                }
            }
            .padding(.vertical, PPSpace.xs)
        }
        .frame(height: isAccessibilityLayout
            ? PPCheckoutSignalGeometry.accessibilityItemPreviewHeight
            : PPCheckoutSignalGeometry.itemPreviewHeight)
        .accessibilityElement(children: .contain)
    }

    private func itemCell(_ item: PPCheckoutSignalItemSnapshot) -> some View {
        HStack(spacing: PPSpace.sm) {
            PPCheckoutSignalImage(
                imageURL: item.imageURL,
                placeholderSystemName: "pawprint.fill"
            )
            .frame(width: isAccessibilityLayout ? 52 : 44, height: isAccessibilityLayout ? 52 : 44)
            .background(Circle().fill(Color.ppSurface))
            .clipShape(Circle())
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                Text(item.name)
                    .font(PPCheckoutSignalFont.medium(13, relativeTo: .footnote))
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(isAccessibilityLayout ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(ppCheckoutSignalItemMetadata(quantity: item.quantity, amount: item.amount))
                    .font(PPCheckoutSignalFont.bold(12, relativeTo: .caption))
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(2)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.sm)
        .frame(width: isAccessibilityLayout ? 292 : 220, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .fill(Color.ppSurface.opacity(colorScheme == .dark ? 0.54 : 0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .stroke(Color.ppSurfaceBorder.opacity(colorSchemeContrast == .increased ? 0.92 : 0),
                        lineWidth: colorSchemeContrast == .increased ? 1 : 0)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.name)
        .accessibilityValue(ppCheckoutSignalItemMetadata(quantity: item.quantity, amount: item.amount))
    }
}

private struct PPCheckoutSignalPrimaryButtonStyle: ButtonStyle {
    let enabled: Bool
    let feedbackActive: Bool
    let feedbackAccent: UIColor?

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .background(
                RoundedRectangle(cornerRadius: PPBottomDecisionBarGeometry.controlRadius, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PPBottomDecisionBarGeometry.controlRadius, style: .continuous)
                    .stroke(
                        feedbackActive
                            ? Color(uiColor: feedbackAccent ?? .ppPremiumAccent)
                            : Color.white.opacity(colorSchemeContrast == .increased ? 0.42 : 0),
                        lineWidth: feedbackActive || colorSchemeContrast == .increased ? 2 : 0
                    )
            )
            .opacity(enabled ? 1 : 0.58)
            .contentShape(RoundedRectangle(
                cornerRadius: PPBottomDecisionBarGeometry.controlRadius,
                style: .continuous
            ))
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard enabled else {
            return Color.ppTextTertiary.opacity(0.34)
        }
        return isPressed ? Color.ppPressedAction : Color.ppPrimary
    }
}

// MARK: - Objective-C facade

@objc(PPPremuimChekoutView)
@objcMembers
public final class PPPremuimChekoutView: UIView {
    public var itemsTotal: CGFloat = 0
    public var shippingFee: CGFloat = 0
    public private(set) var subtotal: CGFloat = 0

    public var showDetails: Bool = true {
        didSet { refreshSwiftUISurface(animated: window != nil) }
    }

    public var showsItemsPreview: Bool = false {
        didSet { refreshSwiftUISurface(animated: window != nil) }
    }

    public var onTapCheckOut: (() -> Void)?

    private var hostingController: UIHostingController<PPCheckoutSignalRootView>?
    private var previewItems: [CartItem] = []
    private var checkoutLoading = false
    private var checkoutTapGate = false
    private var checkoutTitle = PPCheckoutSignalText.localized("Checkout")
    private var checkoutImage: UIImage?
    private var usesDefaultCheckoutTitle = true
    private var usesAutomaticCheckoutImage = true
    private var collapsible = false
    private var summaryCollapsed = false
    private var protectedStateIsActive = false
    private var paymentFeedbackActive = false
    private var feedbackAccent: UIColor?
    private var manualStatus: PPCheckoutSignalStatus?
    private var backgroundImage: UIImage?
    private var lastKnownWidth: CGFloat = 0
    private var feedbackResetWorkItem: DispatchWorkItem?

    @objc public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    @objc public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        feedbackResetWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        clipsToBounds = false
        shouldGroupAccessibilityChildren = true
        accessibilityIdentifier = "checkoutSignal"

        installHost()
        installObservers()
        refreshSwiftUISurface(animated: false)
    }

    private func installHost() {
        let controller = UIHostingController(rootView: makeRootView())
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.backgroundColor = .clear
        controller.view.isOpaque = false
        controller.view.accessibilityIdentifier = "checkoutSignal.host"
        hostingController = controller
        addSubview(controller.view)

        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func installObservers() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(accessibilityPreferenceDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(accessibilityPreferenceDidChange),
            name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(accessibilityPreferenceDidChange),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: Notification.Name("LanguageDidChangeNotification"),
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: Notification.Name("PPLanguageDidChangeNotification"),
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopEphemeralFeedback()
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        guard width > 1, abs(width - lastKnownWidth) > 0.5 else { return }
        lastKnownWidth = width
        refreshSwiftUISurface(animated: false)
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #unavailable(iOS 17.0) {
            super.traitCollectionDidChange(previousTraitCollection)
        }

        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory ||
            traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refreshSwiftUISurface(animated: false)
        }
    }

    public override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        refreshSwiftUISurface(animated: false)
    }

    public override var intrinsicContentSize: CGSize {
        let width = bounds.width > 1 ? bounds.width : UIScreen.main.bounds.width
        return CGSize(width: UIView.noIntrinsicMetric, height: measuredHeight(for: width))
    }

    public override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        let width = targetSize.width > 1
            ? targetSize.width
            : (bounds.width > 1 ? bounds.width : UIScreen.main.bounds.width)
        return CGSize(width: width, height: measuredHeight(for: width))
    }

    public override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        let width = targetSize.width > 1
            ? targetSize.width
            : (bounds.width > 1 ? bounds.width : UIScreen.main.bounds.width)
        return CGSize(width: width, height: measuredHeight(for: width))
    }

    private func measuredHeight(for width: CGFloat) -> CGFloat {
        guard let hostingController else { return UIView.noIntrinsicMetric }
        let fittingWidth = max(width, 1)
        let fittingSize = CGSize(width: fittingWidth, height: UIView.layoutFittingExpandedSize.height)
        let size = hostingController.sizeThatFits(in: fittingSize)
        return ceil(max(size.height, PPBottomDecisionBarGeometry.controlHeight + PPSpace.xl))
    }

    private func makeRootView() -> PPCheckoutSignalRootView {
        PPCheckoutSignalRootView(
            state: makeViewState(),
            onDisclosure: { [weak self] in
                self?.didTapSummaryDisclosure()
            },
            onCheckout: { [weak self] in
                self?.didTapCheckout()
            }
        )
    }

    private func makeViewState() -> PPCheckoutSignalViewState {
        let total = itemsTotal + shippingFee
        return PPCheckoutSignalViewState(
            itemsTotal: itemsTotal,
            shippingFee: shippingFee,
            subtotal: total,
            totalText: ppCheckoutSignalLTRIsolate(PPCheckoutSignalCurrency.format(total)),
            totalNumberText: PPCheckoutSignalCurrency.number(total),
            currencySymbolText: PPCheckoutSignalCurrency.symbol,
            itemCountText: ppCheckoutSignalItemCount(totalItemQuantity),
            checkoutTitle: checkoutTitle,
            checkoutImage: checkoutImage,
            showDetails: showDetails,
            showsItemsPreview: showsItemsPreview,
            collapsible: collapsible,
            summaryCollapsed: collapsible && summaryCollapsed,
            checkoutLoading: checkoutLoading,
            protectedStateIsActive: protectedStateIsActive,
            paymentFeedbackActive: paymentFeedbackActive,
            feedbackAccent: feedbackAccent,
            safeAreaBottom: safeAreaInsets.bottom,
            availableWidth: bounds.width > 1
                ? bounds.width
                : (lastKnownWidth > 1 ? lastKnownWidth : UIScreen.main.bounds.width),
            isRightToLeft: ppCheckoutSignalIsRTL(),
            backgroundImage: backgroundImage,
            manualStatus: manualStatus,
            items: itemSnapshots()
        )
    }

    private var totalItemQuantity: Int {
        previewItems.reduce(0) { partial, item in
            partial + max(item.quantity, 0)
        }
    }

    private func itemSnapshots() -> [PPCheckoutSignalItemSnapshot] {
        previewItems.enumerated().map { index, item in
            let rawName = (item.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let name = rawName.isEmpty
                ? PPCheckoutSignalText.localized("checkout_item_fallback")
                : rawName
            let rawID = (item.itemID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let imageURL = (item.imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let quantity = max(item.quantity, 1)
            let lineTotal = item.lineSubtotal > 0
                ? item.lineSubtotal
                : item.price * Double(quantity)
            let stableID = rawID.isEmpty
                ? "checkout-item-\(index)-\(name)-\(imageURL)"
                : rawID
            return PPCheckoutSignalItemSnapshot(
                id: stableID,
                name: name,
                quantity: quantity,
                amount: CGFloat(lineTotal),
                imageURL: imageURL
            )
        }
    }

    private func refreshSwiftUISurface(animated: Bool) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.refreshSwiftUISurface(animated: animated)
            }
            return
        }

        let applySurfaceState = { [weak self] in
            guard let self else { return }
            self.hostingController?.rootView = self.makeRootView()
        }
        let shouldCrossfade = animated && window != nil && UIView.areAnimationsEnabled
        if shouldCrossfade {
            if UIAccessibility.isReduceMotionEnabled {
                applySurfaceState()
            } else if let hostView = hostingController?.view {
                UIView.transition(
                    with: hostView,
                    duration: PPCheckoutSignalGeometry.feedbackDuration,
                    options: [.transitionCrossDissolve, .beginFromCurrentState, .allowUserInteraction],
                    animations: applySurfaceState
                )
            } else {
                applySurfaceState()
            }
        } else {
            applySurfaceState()
        }

        hostingController?.view.invalidateIntrinsicContentSize()
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        superview?.setNeedsLayout()
    }

    private func stopEphemeralFeedback() {
        feedbackResetWorkItem?.cancel()
        feedbackResetWorkItem = nil
        paymentFeedbackActive = false
        feedbackAccent = nil
        hostingController?.view.layer.removeAllAnimations()
        refreshSwiftUISurface(animated: false)
    }

    // MARK: Public Objective-C contract

    @objc(updateTotalsWithItems:shipping:showTitle:)
    public func updateTotalsWithItems(_ itemsTotal: CGFloat, shipping shippingFee: CGFloat, showTitle _: Bool) {
        self.itemsTotal = itemsTotal
        self.shippingFee = shippingFee
        subtotal = itemsTotal + shippingFee
        refreshSwiftUISurface(animated: window != nil)
    }

    @objc(updatePreviewItems:)
    public func updatePreviewItems(_ items: [CartItem]?) {
        previewItems = items ?? []
        refreshSwiftUISurface(animated: window != nil)
    }

    @objc(setCardBackgroundImage:)
    public func setCardBackgroundImage(_ image: UIImage?) {
        backgroundImage = image
        refreshSwiftUISurface(animated: false)
    }

    @objc(setCheckoutBTNTitle:image:)
    public func setCheckoutBTNTitle(_ title: String?, image: UIImage?) {
        let trimmed = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            checkoutTitle = PPCheckoutSignalText.localized("Checkout")
            usesDefaultCheckoutTitle = true
        } else {
            checkoutTitle = title ?? PPCheckoutSignalText.localized("Checkout")
            usesDefaultCheckoutTitle = false
        }

        usesAutomaticCheckoutImage = image == nil
        checkoutImage = image ?? UIImage(
            systemName: ppCheckoutSignalIsRTL() ? "arrow.left" : "arrow.right"
        )
        refreshSwiftUISurface(animated: false)
    }

    @objc(triggerPaymentMethodChangeFeedbackWithAccent:)
    public func triggerPaymentMethodChangeFeedback(accentColor: UIColor?) {
        let feedback = UISelectionFeedbackGenerator()
        feedback.prepare()
        feedback.selectionChanged()

        feedbackResetWorkItem?.cancel()
        feedbackAccent = accentColor
        paymentFeedbackActive = true
        refreshSwiftUISurface(animated: window != nil)

        let reset = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.paymentFeedbackActive = false
            self.feedbackAccent = nil
            self.refreshSwiftUISurface(animated: self.window != nil)
        }
        feedbackResetWorkItem = reset
        DispatchQueue.main.asyncAfter(
            deadline: .now() + PPCheckoutSignalGeometry.feedbackDuration,
            execute: reset
        )
    }

    @objc(triggerPaymentMethodChangeFeedback)
    public func triggerPaymentMethodChangeFeedback() {
        triggerPaymentMethodChangeFeedback(accentColor: nil)
    }

    @objc(setCheckoutLoading:)
    public func setCheckoutLoading(_ loading: Bool) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.setCheckoutLoading(loading)
            }
            return
        }
        checkoutLoading = loading
        if !loading {
            checkoutTapGate = false
        }
        refreshSwiftUISurface(animated: window != nil)
    }

    @objc(setCheckoutSurfaceState:title:subtitle:)
    public func setCheckoutSurfaceState(_ rawState: String?, title: String?, subtitle: String?) {
        let kind = PPCheckoutSignalStatusKind(rawObjectiveCValue: rawState)
        manualStatus = .automatic(kind: kind, title: title, subtitle: subtitle)
        refreshSwiftUISurface(animated: window != nil)
    }

    @objc(clearCheckoutSurfaceState)
    public func clearCheckoutSurfaceState() {
        manualStatus = nil
        refreshSwiftUISurface(animated: window != nil)
    }

    @objc(skipCardEntranceAnimation)
    public func skipCardEntranceAnimation() {
        hostingController?.view.layer.removeAllAnimations()
        transform = .identity
    }

    @objc(pp_startTrustBannerShimmer)
    public func pp_startTrustBannerShimmer() {
        protectedStateIsActive = true
        refreshSwiftUISurface(animated: window != nil)
    }

    @objc(pp_stopTrustBannerShimmer)
    public func pp_stopTrustBannerShimmer() {
        protectedStateIsActive = false
        refreshSwiftUISurface(animated: window != nil)
    }

    @objc(setCollapsible:initiallyCollapsed:)
    public func setCollapsible(_ enabled: Bool, initiallyCollapsed collapsed: Bool) {
        collapsible = enabled
        summaryCollapsed = enabled && collapsed
        refreshSwiftUISurface(animated: false)
    }

    @objc(setSummaryCollapsed:animated:)
    public func setSummaryCollapsed(_ collapsed: Bool, animated: Bool) {
        guard collapsible, summaryCollapsed != collapsed else { return }
        summaryCollapsed = collapsed
        refreshSwiftUISurface(animated: animated)
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .layoutChanged, argument: self)
        }
    }

    // MARK: Actions and environment updates

    @objc private func didTapSummaryDisclosure() {
        guard collapsible else { return }
        let feedback = UISelectionFeedbackGenerator()
        feedback.prepare()
        feedback.selectionChanged()
        setSummaryCollapsed(!summaryCollapsed, animated: true)
    }

    @objc private func didTapCheckout() {
        guard !checkoutLoading, !checkoutTapGate else { return }
        checkoutTapGate = true
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.prepare()
        feedback.impactOccurred()
        onTapCheckOut?()
        DispatchQueue.main.asyncAfter(
            deadline: .now() + PPCheckoutSignalGeometry.checkoutTapDebounce
        ) { [weak self] in
            guard let self, !self.checkoutLoading else { return }
            self.checkoutTapGate = false
            self.refreshSwiftUISurface(animated: false)
        }
    }

    @objc private func accessibilityPreferenceDidChange() {
        stopEphemeralFeedback()
    }

    @objc private func languageDidChange() {
        if usesDefaultCheckoutTitle {
            checkoutTitle = PPCheckoutSignalText.localized("Checkout")
        }
        if usesAutomaticCheckoutImage {
            checkoutImage = UIImage(systemName: ppCheckoutSignalIsRTL() ? "arrow.left" : "arrow.right")
        }
        manualStatus = nil
        stopEphemeralFeedback()
    }

    @objc private func applicationDidEnterBackground() {
        stopEphemeralFeedback()
    }
}
