import SwiftUI
import UIKit

/// Home-only image preparation. Source assets and the shared network cache are
/// untouched. Work is bounded, serialized off-main, and reused across shelves.
enum HomeProductImagePreparation {
    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.purepets.home.product-images"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 48
        cache.totalCostLimit = 24 * 1_024 * 1_024
        return cache
    }()

    @discardableResult
    static func prepare(_ image: UIImage, key: String, completion: @escaping (UIImage) -> Void) -> Operation? {
        if let prepared = cache.object(forKey: key as NSString) {
            completion(prepared)
            return nil
        }
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation] in
            guard let operation, !operation.isCancelled else { return }
            let prepared = autoreleasepool {
                cache.object(forKey: key as NSString) ?? normalize(image)
            }
            guard !operation.isCancelled else { return }
            cache.setObject(prepared, forKey: key as NSString,
                            cost: Int(prepared.size.width * prepared.size.height * 4))
            DispatchQueue.main.async {
                guard !operation.isCancelled else { return }
                completion(prepared)
            }
        }
        queue.addOperation(operation)
        return operation
    }

    private static func normalize(_ source: UIImage) -> UIImage {
        guard source.size.width > 0, source.size.height > 0 else { return source }
        let side: CGFloat = 480
        let ratio = min(1, side / max(source.size.width, source.size.height))
        let size = CGSize(width: max(1, (source.size.width * ratio).rounded()),
                          height: max(1, (source.size.height * ratio).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let scaled = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let original = scaled.cgImage else { return source }
        let width = original.width, height = original.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let prepared: CGImage? = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                                            CGBitmapInfo.byteOrder32Big.rawValue),
                  let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self)
            else { return nil }
            context.draw(original, in: CGRect(x: 0, y: 0, width: width, height: height))
            let corners = [0, width - 1, (height - 1) * width, width * height - 1]
            let background = (0..<3).map { channel in
                corners.reduce(0) { $0 + Int(bytes[$1 * 4 + channel]) } / 4
            }
            func matches(_ pixel: Int) -> Bool {
                bytes[pixel * 4 + 3] >= 250 && (0..<3).allSatisfy {
                    abs(Int(bytes[pixel * 4 + $0]) - background[$0]) <= 10
                }
            }
            var boundary: [Int] = []
            for x in 0..<width { boundary += [x, (height - 1) * width + x] }
            for y in 0..<height { boundary += [y * width, y * width + width - 1] }
            // Never flood-fill packaging: the product itself may be white,
            // black, or the same colour as the photographed background. Only
            // trim verified outer margins; all interior source pixels survive.
            let hasFlatBackground = boundary.allSatisfy(matches)
            var minX = width, minY = height, maxX = -1, maxY = -1, contentCount = 0
            for y in 0..<height {
                for x in 0..<width {
                    let pixel = y * width + x
                    guard bytes[pixel * 4 + 3] > 20,
                          !hasFlatBackground || !matches(pixel) else { continue }
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                    contentCount += 1
                }
            }
            guard contentCount > width * height / 40,
                  maxX - minX > width / 12, maxY - minY > height / 12 else { return original }
            // Transparent margins are explicit. An opaque photograph is more
            // ambiguous, so never trim more than 12% from any source edge.
            let maxTrimX = hasFlatBackground ? Int(Double(width) * 0.12) : width
            let maxTrimY = hasFlatBackground ? Int(Double(height) * 0.12) : height
            let left = min(maxTrimX, max(0, minX - 6))
            let top = min(maxTrimY, max(0, minY - 6))
            let right = max(width - maxTrimX, min(width, maxX + 7))
            let bottom = max(height - maxTrimY, min(height, maxY + 7))
            let crop = CGRect(x: left, y: top, width: right - left, height: bottom - top)
            let result = original
            return result.cropping(to: crop) ?? original
        }
        guard let prepared else { return scaled }
        let subject = UIImage(cgImage: prepared)
        let fit = side * 0.88 / max(subject.size.width, subject.size.height)
        let fitted = CGSize(width: subject.size.width * fit, height: subject.size.height * fit)
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            subject.draw(in: CGRect(x: (side - fitted.width) / 2, y: (side - fitted.height) / 2,
                                    width: fitted.width, height: fitted.height))
        }
    }
}

/// The same image treatment on the iOS 15 Home compatibility renderer.
struct HomePreparedProductImage: UIViewRepresentable {
    let url: String?
    let placeholder: UIImage?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.isAccessibilityElement = false
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        guard !context.coordinator.loaded || context.coordinator.url != url else { return }
        context.coordinator.loaded = true
        context.coordinator.url = url
        context.coordinator.task?.cancel()
        context.coordinator.preparation?.cancel()
        view.image = placeholder ?? UIImage(systemName: "shippingbox")
        view.tintColor = .secondaryLabel
        guard let url, !url.isEmpty else { return }
        let coordinator = context.coordinator
        coordinator.task = AppRemoteImagePipeline.load(
            urlString: url, cacheKey: url, displaySize: CGSize(width: 240, height: 144)
        ) { [weak view, weak coordinator] image in
            guard let image, coordinator?.url == url else { return }
            coordinator?.preparation = HomeProductImagePreparation.prepare(image, key: "home-product-v2|\(url)") { [weak view, weak coordinator] prepared in
                guard coordinator?.url == url else { return }
                view?.image = prepared
            }
        }
    }

    static func dismantleUIView(_ view: UIImageView, coordinator: Coordinator) {
        coordinator.url = nil
        coordinator.task?.cancel()
        coordinator.preparation?.cancel()
    }

    final class Coordinator {
        var loaded = false
        var url: String?
        var task: AppRemoteImageTask?
        var preparation: Operation?
    }
}

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
    static let productMediaHeight: CGFloat = 184
    static let advertisementMediaHeight: CGFloat = 160
    // Renderer inset (4), card inset (8), information padding (16).
    private static let productInformationInsets: CGFloat = 28

    @Environment(\.homeProductInformationHeight) private var measuredInformationHeight
    @ScaledMetric(relativeTo: .body) private var productInformationHeight: CGFloat = 156
    @ScaledMetric(relativeTo: .body) private var advertisementInformationHeight: CGFloat = 140

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
                Group {
                    if usesQuantity {
                        HomePreparedProductImage(url: viewModel.imageURL, placeholder: viewModel.image ?? viewModel.placeholder)
                    } else {
                        HomeRemoteImage(
                            urlString: viewModel.imageURL,
                            placeholder: viewModel.image ?? viewModel.placeholder,
                            contentMode: .scaleAspectFit,
                            cacheKey: card.id,
                            displaySize: CGSize(width: 240, height: mediaHeight)
                        )
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .frame(height: mediaHeight)
                .background(Color.ppSecondarySurface)
                .clipShape(PPUniversalMediaRoundedShape(topRadius: max(0, HomeVisualTokens.universalCardCorner - 4), bottomRadius: 12))

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

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.title)
                        .font(HomeFont.headline())
                        .foregroundStyle(Color.ppTextPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                        .frame(maxWidth: .infinity, minHeight: isAdvertisement ? titleMinimumHeight : nil, alignment: .topLeading)

                    if !viewModel.subtitle.isEmpty {
                        Text(viewModel.subtitle)
                            .font(HomeFont.caption1())
                            .foregroundStyle(Color.ppTextSecondary)
                            .lineLimit(1)
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
                        .padding(.bottom, 8)
                } else {
                    HStack(alignment: .bottom, spacing: 6) {
                        availability
                            .frame(maxWidth: .infinity, alignment: .leading)
                        action
                            .padding(.bottom, 8)
                    }
                }
            }
            .homeProductInformationMeasurement(enabled: !isAdvertisement)
            .padding(10)
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
        HStack(alignment: .center, spacing: 5) {
            if !viewModel.availabilityText.isEmpty {
                Text(viewModel.availabilityText)
                    .lineLimit(1)
            }
            if !viewModel.availabilityText.isEmpty, let variantInfo = viewModel.variantInfoText, !variantInfo.isEmpty {
                Text("•")
                    .foregroundStyle(Color.ppTextSecondary.opacity(0.45))
            }
            if let variantInfo = viewModel.variantInfoText, !variantInfo.isEmpty {
                Text(variantInfo)
                    .lineLimit(1)
            }
        }
        .font(HomeFont.caption1())
        .foregroundStyle(Color.ppTextSecondary)
        .lineLimit(1)
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
                    Text(quantity.formatted(.number.locale(Locale(identifier: Language.isRTL() ? "ar" : "en"))))
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
