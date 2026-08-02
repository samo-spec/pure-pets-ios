import SwiftUI

/// iOS 15 renderer for the marketplace migration. iOS 16 and newer use the
/// shared production `PPUniversalCardView` directly. This compatibility card
/// forwards every action to the same bridge and manager owners.
@available(iOS 15.0, *)
struct PPMarketplaceCompatibilityCard: View {
    let viewModel: PPUniversalCellViewModel
    let context: PPCellContext
    let layout: PPMarketplaceLayout
    let bridge: PPMarketplaceDataViewBridge

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var quantity = 0
    @State private var notificationLoading = false
    @State private var notificationRegistered = false
    @State private var isSavedForLater = false

    private var usesQuantity: Bool {
        PPUniversalCellSwiftUIBridge.usesQuantityControl(for: viewModel)
    }

    private var stockLimit: Int {
        max(0, PPUniversalCellSwiftUIBridge.stockLimit(for: viewModel))
    }

    private var isUnavailable: Bool {
        usesQuantity && stockLimit == 0
    }

    private var usesContainedMedia: Bool {
        PPUniversalCellSwiftUIBridge.prefersContainedImage(for: viewModel)
    }

    private var showsSaveForLater: Bool {
        context.rawValue == 1 || context.rawValue == 2
    }

    private var accentPalette: PPMarketplaceAccentPalette {
        PPMarketplaceAccentPalette(accent: bridge.accentColor)
    }

    var body: some View {
        layoutContent
        .background(
            Color.ppMarketplaceSurface,
            in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        )
        .overlay {
            ZStack {
                RoundedRectangle(
                    cornerRadius: PPCorner.card,
                    style: .continuous
                )
                .strokeBorder(
                    Color.ppMarketplaceTextPrimary.opacity(
                        colorScheme == .dark ? 0.18 : 0.08
                    ),
                    lineWidth:
                        colorSchemeContrast == .increased ? 2.5 : 1.75
                )
                RoundedRectangle(
                    cornerRadius: PPCorner.card,
                    style: .continuous
                )
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(
                                colorScheme == .dark ? 0.88 : 0.98
                            ),
                            Color.white.opacity(
                                colorScheme == .dark ? 0.30 : 0.44
                            ),
                            Color.white.opacity(
                                colorScheme == .dark ? 0.74 : 0.92
                            ),
                            Color.white.opacity(
                                colorScheme == .dark ? 0.18 : 0.24
                            )
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth:
                        colorSchemeContrast == .increased ? 2 : 1.15
                )
            }
            .shadow(
                color: Color.white.opacity(
                    colorScheme == .dark ? 0.18 : 0.56
                ),
                radius: 1.5,
                x: -0.5,
                y: -0.5
            )
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.13 : 0.045),
            radius: 13,
            y: 6
        )
        .contentShape(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        )
        .onTapGesture {
            bridge.open(item: viewModel)
        }
        .contextMenu { actionMenu }
        .onAppear(perform: synchronizeState)
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("CartUpdated")
            )
        ) { _ in
            refreshQuantity()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("PPSaveForLaterUpdatedNotification")
            )
        ) { _ in
            refreshSavedForLater()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAction {
            bridge.open(item: viewModel)
        }
        .accessibilityAction(
            named: PPMarketplaceText.localized("Share")
        ) {
            bridge.share(item: viewModel)
        }
    }

    private var layoutContent: AnyView {
        if layout == .compact && !dynamicTypeSize.isAccessibilitySize {
            return AnyView(
                HStack(alignment: .top, spacing: PPSpace.md) {
                    media.frame(width: 138)
                    information
                        .padding(.vertical, PPSpace.md)
                        .padding(.trailing, PPSpace.md)
                }
                .frame(minHeight: 184)
            )
        }
        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                media.frame(height: mediaHeight)
                information.padding(PPSpace.md)
            }
        )
    }

    private var media: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)

            if let image = viewModel.image ?? viewModel.placeholder,
               viewModel.imageURL?.isEmpty != false {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: usesContainedMedia ? .fit : .fill)
                    .padding(usesContainedMedia ? PPSpace.md : 0)
            } else {
                AppRemoteImage(
                    urlString: viewModel.imageURL,
                    cacheKey: viewModel.modelID,
                    displaySize: remoteImageSize,
                    contentMode: usesContainedMedia ? .fit : .fill,
                    showsRetryAction: true
                )
                .padding(usesContainedMedia ? PPSpace.md : 0)
            }
        }
        .clipped()
        .overlay(alignment: .topLeading) {
            if !viewModel.badgeText.isEmpty {
                Text(viewModel.badgeText)
                    .font(HomeFont.bold(11))
                    .foregroundStyle(accentPalette.onAccent)
                    .padding(.horizontal, PPSpace.sm)
                    .padding(.vertical, PPSpace.xs)
                    .background(
                        accentPalette.fill,
                        in: Capsule(style: .continuous)
                    )
                    .padding(PPSpace.sm)
            }
        }
        .overlay(alignment: .topTrailing) {
            leadingAction
                .padding(PPSpace.sm)
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.isVideoMedia {
                Button {
                    bridge.playVideo(for: viewModel)
                } label: {
                    Label(
                        PPMarketplaceText.localized("marketplace_video"),
                        systemImage: "play.fill"
                    )
                    .labelStyle(.iconOnly)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.62), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(PPSpace.sm)
                .accessibilityLabel(
                    PPMarketplaceText.localized("marketplace_play_video")
                )
            }
        }
    }

    @ViewBuilder
    private var leadingAction: some View {
        if showsSaveForLater {
            Button {
                bridge.toggleSaveForLater(for: viewModel)
                isSavedForLater.toggle()
            } label: {
                Image(systemName: isSavedForLater ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(uiColor: bridge.accentColor))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                PPMarketplaceText.localized(
                    isSavedForLater
                        ? "saved_for_later_remove_action"
                        : "saved_for_later_add_action"
                )
            )
        } else if let modelID = viewModel.modelID, !modelID.isEmpty {
            PPMarketplaceCompatibilityFavorite(
                itemID: modelID,
                collection: PPUniversalCellSwiftUIBridge.favoritesCollection(
                    for: context
                ),
                isRightToLeft: PPUniversalCellSwiftUIBridge.isRightToLeft(),
                accentColor: bridge.accentColor
            )
            .frame(width: 44, height: 44)
        }
    }

    private var information: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            Text(viewModel.title)
                .font(HomeFont.headline())
                .foregroundStyle(Color.ppMarketplaceTextPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(layout == .focus ? 3 : 2)
                .fixedSize(horizontal: false, vertical: true)

            if !viewModel.subtitle.isEmpty {
                Text(viewModel.subtitle)
                    .font(HomeFont.subheadline())
                    .foregroundStyle(Color.ppMarketplaceTextSecondary)
                    .lineLimit(layout == .focus ? 3 : 2)
            }

            if !viewModel.location.isEmpty {
                Label(viewModel.location, systemImage: "mappin.and.ellipse")
                    .font(HomeFont.footnote())
                    .foregroundStyle(Color.ppMarketplaceTextSecondary)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: PPSpace.xs) {
                Text(viewModel.priceText)
                    .font(HomeFont.bold(layout == .focus ? 22 : 18))
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if viewModel.hasOffer, !viewModel.discountText.isEmpty {
                    Text(viewModel.discountText)
                        .font(HomeFont.bold(12))
                        .foregroundStyle(Color(uiColor: bridge.accentColor))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            action
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var action: some View {
        if usesQuantity {
            if isUnavailable {
                notifyAction
            } else if quantity > 0 {
                quantityStepper
            } else {
                addToCartAction
            }
        } else {
            Button {
                bridge.open(item: viewModel)
            } label: {
                HStack(spacing: PPSpace.sm) {
                    Text(PPMarketplaceText.localized("marketplace_view_details"))
                    Spacer(minLength: PPSpace.sm)
                    Image(systemName: "arrow.forward")
                        .flipsForRightToLeftLayoutDirection(true)
                        .accessibilityHidden(true)
                }
                .font(HomeFont.bold(14))
                .foregroundStyle(Color(uiColor: bridge.accentColor))
                .padding(.horizontal, PPSpace.md)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(
                    Color(uiColor: bridge.accentColor).opacity(0.10),
                    in: Capsule(style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var notifyAction: some View {
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
            Label(
                PPMarketplaceText.localized(
                    notificationRegistered
                        ? "home_pulse_notify_registered"
                        : "home_pulse_notify_available"
                ),
                systemImage: notificationRegistered
                    ? "checkmark.circle.fill"
                    : "bell.fill"
            )
            .font(HomeFont.bold(14))
            .frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(
                notificationRegistered
                    ? Color.green
                    : Color.ppMarketplaceTextPrimary
            )
            .background(
                Color(uiColor: .tertiarySystemBackground),
                in: Capsule(style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(notificationLoading || notificationRegistered)
    }

    private var addToCartAction: some View {
        Button {
            mutateQuantity(1)
        } label: {
            Label(
                PPMarketplaceText.localized("home_pulse_add_to_cart"),
                systemImage: "cart.badge.plus"
            )
            .font(HomeFont.bold(14))
            .frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(accentPalette.onAccent)
            .background(
                accentPalette.fill,
                in: Capsule(style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private var quantityStepper: some View {
        HStack(spacing: PPSpace.sm) {
            quantityButton(
                symbol: quantity == 1 ? "trash" : "minus",
                accessibilityKey: "home_pulse_decrease_quantity_a11y"
            ) {
                mutateQuantity(quantity - 1)
            }

            Text("\(quantity)")
                .font(HomeFont.bold(17))
                .frame(maxWidth: .infinity)
                .accessibilityLabel(
                    PPMarketplaceText.formatted(
                        "home_pulse_quantity_a11y",
                        quantity
                    )
                )

            quantityButton(
                symbol: "plus",
                accessibilityKey: "home_pulse_increase_quantity_a11y"
            ) {
                mutateQuantity(quantity + 1)
            }
            .disabled(quantity >= stockLimit)
        }
        .frame(height: 46)
        .padding(.horizontal, PPSpace.xs)
        .background(
            Color(uiColor: .tertiarySystemBackground),
            in: Capsule(style: .continuous)
        )
    }

    private func quantityButton(
        symbol: String,
        accessibilityKey: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(uiColor: bridge.accentColor))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PPMarketplaceText.localized(accessibilityKey))
    }

    @ViewBuilder
    private var actionMenu: some View {
        Button {
            bridge.share(item: viewModel)
        } label: {
            Label(PPMarketplaceText.localized("Share"), systemImage: "square.and.arrow.up")
        }

        if viewModel.isOwner {
            Button {
                bridge.edit(item: viewModel)
            } label: {
                Label(PPMarketplaceText.localized("Edit"), systemImage: "pencil")
            }

            Button {
                bridge.toggleVisibility(for: viewModel)
            } label: {
                Label(
                    PPMarketplaceText.localized(
                        viewModel.isPubliclyVisible
                            ? "listing_hide_action"
                            : "listing_show_action"
                    ),
                    systemImage: viewModel.isPubliclyVisible ? "eye.slash" : "eye"
                )
            }

            Button(role: .destructive) {
                bridge.delete(item: viewModel)
            } label: {
                Label(PPMarketplaceText.localized("Delete"), systemImage: "trash")
            }
        } else {
            Button {
                bridge.chat(about: viewModel)
            } label: {
                Label(PPMarketplaceText.localized("Chat"), systemImage: "message")
            }

            Button {
                bridge.report(item: viewModel)
            } label: {
                Label(
                    PPMarketplaceText.localized("report"),
                    systemImage: "exclamationmark.bubble"
                )
            }
        }

        Button {
            bridge.toggleSaveForLater(for: viewModel)
            isSavedForLater.toggle()
        } label: {
            Label(
                PPMarketplaceText.localized(
                    isSavedForLater
                        ? "saved_for_later_remove_action"
                        : "saved_for_later_add_action"
                ),
                systemImage: isSavedForLater ? "bookmark.slash" : "bookmark"
            )
        }
    }

    private func synchronizeState() {
        refreshQuantity()
        refreshSavedForLater()
    }

    private func refreshQuantity() {
        quantity = min(
            stockLimit,
            max(0, PPUniversalCellSwiftUIBridge.cartQuantity(for: viewModel))
        )
    }

    private func refreshSavedForLater() {
        guard let modelID = viewModel.modelID, !modelID.isEmpty else {
            isSavedForLater = false
            return
        }
        isSavedForLater = PPSaveForLaterManager.shared().isItemSaved(modelID)
    }

    private func mutateQuantity(_ proposed: Int) {
        let next = min(max(0, proposed), stockLimit)
        if reduceMotion {
            quantity = next
        } else {
            withAnimation(.easeOut(duration: 0.16)) {
                quantity = next
            }
        }
        bridge.changeQuantity(for: viewModel, quantity: next)
    }

    private var mediaHeight: CGFloat {
        switch layout {
        case .focus: return dynamicTypeSize.isAccessibilitySize ? 320 : 292
        case .mosaic: return dynamicTypeSize.isAccessibilitySize ? 250 : 188
        case .showcase: return dynamicTypeSize.isAccessibilitySize ? 280 : 242
        case .compact: return 190
        }
    }

    private var remoteImageSize: CGSize {
        switch layout {
        case .compact: return CGSize(width: 300, height: 380)
        case .mosaic: return CGSize(width: 420, height: 460)
        case .showcase: return CGSize(width: 760, height: 520)
        case .focus: return CGSize(width: 900, height: 700)
        }
    }

    private var accessibilitySummary: String {
        [
            viewModel.title,
            viewModel.subtitle,
            viewModel.priceText,
            viewModel.availabilityText,
            quantity > 0
                ? PPMarketplaceText.formatted(
                    "home_pulse_in_cart_quantity_a11y",
                    quantity
                )
                : ""
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceCompatibilityFavorite: UIViewRepresentable {
    let itemID: String
    let collection: String
    let isRightToLeft: Bool
    let accentColor: UIColor

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> FavoriteFloatingButton {
        let button = FavoriteFloatingButton(type: .custom)
        button.hidesBackground = false
        return button
    }

    func updateUIView(
        _ button: FavoriteFloatingButton,
        context: Context
    ) {
        button.favoriteAccentColor = accentColor
        button.semanticContentAttribute = isRightToLeft
            ? .forceRightToLeft
            : .forceLeftToRight
        let signature = "\(collection)|\(itemID)"
        guard context.coordinator.signature != signature else { return }
        context.coordinator.signature = signature
        button.adID = itemID
        button.collection = collection
        button.initValue()
    }

    final class Coordinator {
        var signature = ""
    }
}
