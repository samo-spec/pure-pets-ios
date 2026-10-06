import SwiftUI
import UIKit

private struct HomeProductInformationHeightEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

enum HomeProductInformationRegion: Hashable {
    case identity
    case metadata
}

struct HomeProductInformationRegionsKey: PreferenceKey, EnvironmentKey {
    static let defaultValue: [HomeProductInformationRegion: CGFloat] = [:]

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: max)
    }
}

extension EnvironmentValues {
    var homeProductInformationHeight: CGFloat? {
        get { self[HomeProductInformationHeightEnvironmentKey.self] }
        set { self[HomeProductInformationHeightEnvironmentKey.self] = newValue }
    }

    var homeProductInformationRegions: [HomeProductInformationRegion: CGFloat] {
        get { self[HomeProductInformationRegionsKey.self] }
        set { self[HomeProductInformationRegionsKey.self] = newValue }
    }
}

struct HomeProductInformationHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    func homeProductInformationRegion(_ region: HomeProductInformationRegion, enabled: Bool) -> some View {
        modifier(HomeProductInformationRegionModifier(region: region, enabled: enabled))
    }

    @ViewBuilder
    func homeProductInformationMeasurement(enabled: Bool) -> some View {
        if enabled {
            self
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: HomeProductInformationHeightPreferenceKey.self,
                            value: geometry.size.height
                        )
                    }
                }
        } else {
            self
        }
    }
}

/// Measure the natural content before applying the rail's shared height. This
/// aligns the metadata and action baselines without a Spacer or a feedback loop
/// that could inflate the card on each layout pass.
private struct HomeProductInformationRegionModifier: ViewModifier {
    let region: HomeProductInformationRegion
    let enabled: Bool
    @Environment(\.homeProductInformationRegions) private var heights

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: HomeProductInformationRegionsKey.self,
                            value: [region: geometry.size.height]
                        )
                    }
                }
                .frame(minHeight: heights[region], alignment: .topLeading)
        } else {
            content
        }
    }
}

/// Loaded product rails share the tallest intrinsic information stack. Media
/// stays stable; long titles, larger text and quantity controls grow the rail.
struct HomeUniversalCardSizing: DynamicProperty {
    static let productMediaHeight: CGFloat = 144
    static let advertisementMediaHeight: CGFloat = 124
    // Renderer inset (4), card inset (8), information padding (24).
    private static let productInformationInsets: CGFloat = 36

    @Environment(\.homeProductInformationHeight) private var measuredInformationHeight
    @ScaledMetric(relativeTo: .body) private var productInformationHeight: CGFloat = 186
    @ScaledMetric(relativeTo: .body) private var advertisementInformationHeight: CGFloat = 136

    func height(isAdvertisement: Bool, measuredProductInformationHeight: CGFloat? = nil) -> CGFloat {
        if isAdvertisement {
            return Self.advertisementMediaHeight + advertisementInformationHeight
        }
        let measured = measuredProductInformationHeight ?? measuredInformationHeight
        let informationHeight = measured.map { ceil($0) + Self.productInformationInsets }
            ?? productInformationHeight
        return Self.productMediaHeight + informationHeight
    }
}

struct HomeUniversalCard: View {
    let card: HomeCardModel
    let delegate: PPUniversalCellDelegate?
    let onTap: () -> Void
    let onQuantityChange: (Int) -> Void
    let entrancePresented: Bool
    let entranceOrdinal: Int

    private var cardSizing = HomeUniversalCardSizing()

    init(
        card: HomeCardModel,
        delegate: PPUniversalCellDelegate?,
        onTap: @escaping () -> Void,
        onQuantityChange: @escaping (Int) -> Void,
        entrancePresented: Bool,
        entranceOrdinal: Int
    ) {
        self.card = card
        self.delegate = delegate
        self.onTap = onTap
        self.onQuantityChange = onQuantityChange
        self.entrancePresented = entrancePresented
        self.entranceOrdinal = entranceOrdinal
    }

    private var isAdsCard: Bool {
        card.kind == .advertisement ||
            card.context == .forAds ||
            card.context == .forHomeAds
    }

    private var cardHeight: CGFloat {
        cardSizing.height(isAdvertisement: isAdsCard)
    }

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                HomeUniversalDirectCard(
                    card: card,
                    delegate: delegate,
                    onQuantityChange: onQuantityChange
                )
            } else {
                HomeUniversalCompatibilityCard(
                    card: card,
                    onTap: onTap,
                    onQuantityChange: onQuantityChange
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
    }
}

@available(iOS 16.0, *)
private struct HomeUniversalDirectCard: View {
    let card: HomeCardModel
    let delegate: PPUniversalCellDelegate?
    let onQuantityChange: (Int) -> Void

    var body: some View {
        PPUniversalCardView(
            viewModel: card.viewModel,
            delegate: delegate,
            context: card.context,
            layoutMode: .cellLayoutModeVertical,
            discountMode: .badge,
            imageLoader: nil,
            showsSubtitle: true,
            isHomePresentation: true,
            borderMode: .pordersForHomeView,
            onTap: nil,
            onQuantityChange: onQuantityChange
        )
    }
}

private struct HomeUniversalCompatibilityCard: View {
    let card: HomeCardModel
    let onTap: () -> Void
    let onQuantityChange: (Int) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var titleMinimumHeight: CGFloat = 40

    @State private var quantity = 0
    @State private var notificationLoading = false
    @State private var notificationRegistered = false

    private var viewModel: PPUniversalCellViewModel {
        card.viewModel
    }

    private var usesQuantity: Bool {
        PPUniversalCellSwiftUIBridge.usesQuantityControl(for: viewModel)
    }

    private var stockLimit: Int {
        max(0, PPUniversalCellSwiftUIBridge.stockLimit(for: viewModel))
    }

    private var isUnavailable: Bool {
        usesQuantity && stockLimit == 0
    }

    private var isAdvertisement: Bool {
        card.kind == .advertisement || card.context == .forAds || card.context == .forHomeAds
    }

    private var requiresVariantSelection: Bool {
        PPUniversalCellSwiftUIBridge.requiresVariantSelection(for: viewModel)
    }

    private var mediaHeight: CGFloat {
        isAdvertisement
            ? HomeUniversalCardSizing.advertisementMediaHeight
            : HomeUniversalCardSizing.productMediaHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                HomeRemoteImage(
                    urlString: viewModel.imageURL,
                    placeholder: viewModel.image ?? viewModel.placeholder,
                    contentMode: .scaleAspectFit,
                    cacheKey: card.id,
                    displaySize: CGSize(width: 240, height: mediaHeight)
                )
                .padding(8)
                .frame(maxWidth: .infinity)
                .frame(height: mediaHeight)
                .background(Color.ppSecondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if !viewModel.badgeText.isEmpty {
                    Text(viewModel.badgeText)
                        .font(HomeFont.bold(11))
                        .foregroundStyle(Color.ppTextPrimary)
                        .padding(.horizontal, PPSpace.sm)
                        .padding(.vertical, PPSpace.xs)
                        .background(Color.ppSurfaceRaised, in: Capsule())
                        .padding(PPSpace.sm)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.title)
                        .font(HomeFont.headline())
                        .foregroundStyle(Color.ppTextPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                        .frame(maxWidth: .infinity, minHeight: isAdvertisement ? titleMinimumHeight : nil, alignment: .topLeading)

                    if !viewModel.subtitle.isEmpty {
                        Text(viewModel.subtitle)
                            .font(HomeFont.caption1())
                            .foregroundStyle(Color.ppTextSecondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: PPSpace.xs) {
                        Text(viewModel.priceText)
                            .font(HomeFont.bold(20))
                            .foregroundStyle(Color.ppTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if viewModel.hasOffer, !viewModel.discountText.isEmpty {
                            PPDiscountBadge(localizedText: viewModel.discountText, style: .inline)
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    onTap()
                }
                .homeProductInformationRegion(.identity, enabled: !isAdvertisement)

                if isAdvertisement {
                    Spacer(minLength: 0)
                }

                if !isAdvertisement {
                    availability
                        .homeProductInformationRegion(.metadata, enabled: true)
                    action
                } else {
                    HStack(alignment: .bottom, spacing: 8) {
                        availability
                            .frame(maxWidth: .infinity, alignment: .leading)
                        action
                    }
                }
            }
            .homeProductInformationMeasurement(enabled: !isAdvertisement)
            .padding(12)
        }
        .padding(4)
        .background {
            Button(action: onTap) {
                RoundedRectangle(cornerRadius: HomeVisualTokens.universalCardCorner, style: .continuous)
                    .fill(Color.clear)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
        .ppElevation(.raised, cornerRadius: HomeVisualTokens.universalCardCorner)
        .accessibilityElement(children: .contain)
        .onAppear(perform: refreshQuantity)
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name("CartUpdated"))
        ) { _ in
            refreshQuantity()
        }
    }

    private var availability: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !viewModel.availabilityText.isEmpty {
                Text(viewModel.availabilityText)
            }
            if let variantInfo = viewModel.variantInfoText, !variantInfo.isEmpty {
                Text(variantInfo)
            }
        }
        .font(HomeFont.caption1())
        .foregroundStyle(Color.ppTextSecondary)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
    }

    private var actionHeight: CGFloat {
        PPProductCardActionMetrics.height(for: dynamicTypeSize)
    }

    private func actionLabel(title: String, symbol: String, loading: Bool = false) -> some View {
        PPProductCardActionLabel(
            title: title, symbol: symbol, height: actionHeight,
            tint: usesQuantity ? .ppPrimary : .ppTextPrimary,
            isProcessing: loading
        )
    }

    @ViewBuilder
    private var action: some View {
        if requiresVariantSelection {
            // The iOS 15 compatibility card routes to the existing detail flow
            // rather than ever committing the displayed family's default item.
            Button(action: onTap) {
                actionLabel(
                    title: HomeModelAdapter.localized("home_pulse_add_to_cart", fallback: "Add to cart"),
                    symbol: "cart.badge.plus"
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.ppTextPrimary)
            .accessibilityLabel(PPAccessoryViewerL10n.text("accessory_view_options_title"))
        } else if usesQuantity {
            if isUnavailable {
                Button {
                    guard !notificationLoading else { return }
                    notificationLoading = true
                    PPUniversalCellSwiftUIBridge.registerStockNotification(
                        for: viewModel
                    ) { success in
                        DispatchQueue.main.async {
                            notificationLoading = false
                            notificationRegistered = success
                        }
                    }
                } label: {
                    actionLabel(
                        title: notificationRegistered
                            ? HomeModelAdapter.localized("home_pulse_notify_registered", fallback: "You will be notified")
                            : HomeModelAdapter.localized("home_pulse_notify_available", fallback: "Notify me"),
                        symbol: notificationRegistered ? "checkmark" : "bell",
                        loading: notificationLoading
                    )
                }
                .accessibilityLabel(
                    notificationRegistered
                        ? HomeModelAdapter.localized("home_pulse_notify_registered", fallback: "You will be notified")
                        : HomeModelAdapter.localized("home_pulse_notify_available", fallback: "Notify me")
                )
                .buttonStyle(.plain)
                .disabled(notificationLoading || notificationRegistered)
            } else if quantity > 0 {
                HStack(spacing: PPSpace.sm) {
                    quantityButton(
                        symbol: "minus",
                        labelKey: "home_pulse_decrease_quantity_a11y",
                        fallback: "Decrease quantity"
                    ) {
                        mutateQuantity(quantity - 1)
                    }
                    Text("\(quantity)")
                        .font(HomeFont.bold(16))
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(
                            String(
                                format: HomeModelAdapter.localized(
                                    "home_pulse_quantity_a11y",
                                    fallback: "Quantity %d"
                                ),
                                quantity
                            )
                        )
                    quantityButton(
                        symbol: "plus",
                        labelKey: "home_pulse_increase_quantity_a11y",
                        fallback: "Increase quantity"
                    ) {
                        mutateQuantity(min(stockLimit, quantity + 1))
                    }
                    .disabled(quantity >= stockLimit)
                }
                .frame(height: actionHeight)
                .padding(.horizontal, PPSpace.xs)
                .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Button {
                    mutateQuantity(1)
                } label: {
                    actionLabel(
                        title: HomeModelAdapter.localized("home_pulse_add_to_cart", fallback: "Add to cart"),
                        symbol: "cart.badge.plus"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(HomeModelAdapter.localized("home_pulse_add_to_cart", fallback: "Add to cart"))
            }
        } else if !isAdvertisement {
            Button(action: onTap) {
                actionLabel(
                    title: HomeModelAdapter.localized("home_pulse_details", fallback: "Details"),
                    symbol: "arrow.forward"
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(HomeModelAdapter.localized("home_pulse_details", fallback: "Details"))
        }
    }

    private func quantityButton(
        symbol: String,
        labelKey: String,
        fallback: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .frame(width: actionHeight, height: actionHeight)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            HomeModelAdapter.localized(labelKey, fallback: fallback)
        )
    }

    private func mutateQuantity(_ next: Int) {
        let clamped = min(max(0, next), stockLimit)
        quantity = clamped
        onQuantityChange(clamped)
    }

    private func refreshQuantity() {
        quantity = min(
            stockLimit,
            max(
                0,
                PPUniversalCellSwiftUIBridge.cartQuantity(for: viewModel)
            )
        )
    }

    private var accessibilitySummary: String {
        [
            viewModel.title,
            viewModel.priceText,
            viewModel.availabilityText,
            quantity > 0
                ? String(
                    format: HomeModelAdapter.localized(
                        "home_pulse_in_cart_quantity_a11y",
                        fallback: "In cart, quantity %d"
                    ),
                    quantity
                )
                : "",
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }
}
