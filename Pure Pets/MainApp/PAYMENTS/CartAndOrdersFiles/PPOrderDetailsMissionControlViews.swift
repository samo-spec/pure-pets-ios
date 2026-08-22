//
//  PPOrderDetailsMissionControlViews.swift
//  Pure Pets
//

import MapKit
import SwiftUI

private enum PPOrderMissionColorRole {
    static var journeyHistory: Color { .ppTextSecondary }
    static var commerce: Color { .ppQuickActionShopping }
    static var financialMetadata: Color { .ppTextSecondary }
    static var location: Color { .ppInfo }
    static var fulfillmentOperations: Color { .ppQuickActionServices }
    static var support: Color { .ppQuickActionCommunity }
    static var primaryAction: Color { .ppPrimary }

    static func action(
        kind: String,
        isDestructive: Bool,
        fallback: Color
    ) -> Color {
        if isDestructive { return .ppError }
        switch kind {
        case "track":
            return .ppInfo
        case "requests":
            return .ppQuickActionCommunity
        case "support":
            return .ppQuickActionServices
        case "return", "replacement":
            return commerce
        case "refund", "complaint":
            return .ppWarning
        case "cancel":
            return .ppError
        default:
            return fallback
        }
    }
}

@available(iOS 17.0, *)
struct PPOrderDetailsMissionControlScreen: View {
    @ObservedObject var store: PPOrderDetailsMissionControlStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack {
            Color.ppBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                navigationHeader
                    .padding(.horizontal, contentInset)
                    .padding(.top, PPSpace.sm)
                    .padding(.bottom, PPSpace.md)
                    .zIndex(1)

                ScrollView {
                    VStack(spacing: PPSpace.lg) {
                    if store.state.isInitialLoading {
                        PPOrderMissionLoadingView()
                    } else if !store.state.errorMessage.isEmpty &&
                                store.state.orderID.isEmpty {
                        PPOrderMissionFatalErrorView(
                            message: store.state.errorMessage,
                            retry: store.refresh
                        )
                    } else {
                        if !store.state.errorMessage.isEmpty || store.state.isOffline {
                            connectivityBanner
                        }
                        adaptiveMissionLayout
                    }
                    }
                    .padding(.horizontal, contentInset)
                    .padding(.top, PPSpace.base)
                    .padding(.bottom, 128)
                }
                .refreshable { store.refresh() }
            }

            if store.isCommandRunning {
                PPOrderMissionCommandOverlay()
            }
        }
        .environment(
            \.layoutDirection,
            store.isRightToLeft ? .rightToLeft : .leftToRight
        )
        .environment(\.locale, Locale(identifier: store.languageCode))
        .sheet(item: $store.activeSheet, onDismiss: store.sheetDidDismiss) {
            PPOrderMissionSheetRoot(sheet: $0, store: store)
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(PPCorner.hero)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("LanguageDidChangeNotification")
            )
        ) { _ in store.updateLanguage() }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("PPLanguageDidChangeNotification")
            )
        ) { _ in store.updateLanguage() }
    }

    private var accent: Color {
        Color(uiColor: store.state.statusColor)
    }

    private enum HeroMetric {
        static let statusEmblem: CGFloat = 60
        static let statusSymbol: CGFloat = 22
        static let statusRail: CGFloat = 3
    }

    private var contentInset: CGFloat {
        horizontalSizeClass == .regular ? PPSpace.xl : PPSpace.base
    }

    private var navigationHeader: some View {
        HStack(spacing: PPSpace.sm) {
            Button(action: store.close) {
                Image(systemName: store.closeSymbol)
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Color.ppSurfaceElevated, in: Circle())
                    .overlay(Circle().stroke(Color.ppSurfaceBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(closeAccessibilityLabel)

            VStack(alignment: .leading, spacing: 1) {
                Text(store.state.screenTitle.isEmpty
                     ? PPOrderMissionText("order_details_title")
                     : store.state.screenTitle)
                    .font(PPOrderMissionTypography.headline())
                    .foregroundStyle(Color.ppTextPrimary)
                HStack(spacing: PPSpace.xs) {
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 6, height: 6)
                    Text(PPOrderMissionText(connectionKey))
                    .font(PPOrderMissionTypography.caption(12))
                    .foregroundStyle(Color.ppTextSecondary)
                }
            }

            Spacer(minLength: PPSpace.sm)

            Button(action: store.share) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Color.ppSurfaceElevated, in: Circle())
                    .overlay(Circle().stroke(Color.ppSurfaceBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PPOrderMissionText("Share"))

            Button {
                store.activeSheet = .support
            } label: {
                Image(systemName: "headphones")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(
                        PPOrderMissionColorRole.support.opacity(0.16),
                        in: Circle()
                    )
                    .overlay(
                        Circle().stroke(
                            PPOrderMissionColorRole.support.opacity(0.32),
                            lineWidth: 1
                        )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PPOrderMissionText("cart_support_menu_title"))
        }
    }

    private var closeAccessibilityLabel: String {
        switch store.closeSymbol {
        case "xmark":
            return PPOrderMissionText("Close")
        case "house.fill":
            return PPOrderMissionText("home")
        default:
            return PPOrderMissionText("Back")
        }
    }

    private var connectionKey: String {
        if store.state.isInitialLoading { return "order_mission_connecting" }
        if !store.state.isAuthorized ||
            (!store.state.errorMessage.isEmpty && !store.state.isOffline) {
            return "order_mission_unavailable"
        }
        return store.state.isOffline
            ? "order_mission_offline"
            : "order_mission_live"
    }

    private var connectionColor: Color {
        if store.state.isInitialLoading { return Color.ppTextTertiary }
        if !store.state.isAuthorized ||
            (!store.state.errorMessage.isEmpty && !store.state.isOffline) {
            return store.state.errorMessage.isEmpty
                ? Color.ppTextTertiary
                : Color.ppError
        }
        return store.state.isOffline ? Color.ppWarning : Color.ppSuccess
    }

    @ViewBuilder
    private var adaptiveMissionLayout: some View {
        if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: PPSpace.lg) {
                VStack(spacing: PPSpace.lg) {
                    hero
                    timelineSection
                    manifestSection
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: PPSpace.lg) {
                    financialSection
                    destinationSection
                    fulfillmentSection
                    supportActivitySection
                    commandDeck
                }
                .frame(width: 390)
            }
        } else {
            VStack(spacing: PPSpace.lg) {
                hero
                timelineSection
                manifestSection
                financialSection
                destinationSection
                fulfillmentSection
                supportActivitySection
                commandDeck
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            heroReferenceStrip
            heroStatusChapter
            heroJourneySurface
        }
        .padding(PPSpace.base)
        .modifier(
            PPOrderMissionGlassCard(
                accent: accent,
                emphasis: true,
                usesAccentBorder: false
            )
        )
    }

    private var heroReferenceStrip: some View {
        Button(action: store.copyReference) {
            HStack(spacing: PPSpace.md) {
                Image(systemName: "doc.text")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.ppTextSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.ppSecondarySurface, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: PPSpace.xxs) {
                    Text(PPOrderMissionText("order_mission_eyebrow"))
                        .font(PPOrderMissionTypography.caption(11))
                        .tracking(store.isRightToLeft ? 0 : 0.9)
                        .foregroundStyle(Color.ppTextTertiary)

                    Text(verbatim: "#\(store.state.reference)")
                        .font(PPOrderMissionTypography.headline(18))
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .environment(\.layoutDirection, .leftToRight)
                }

                Spacer(minLength: PPSpace.sm)

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PPOrderMissionColorRole.primaryAction)
                    .frame(width: 32, height: 32)
                    .background(
                        PPOrderMissionColorRole.primaryAction.opacity(0.10),
                        in: Circle()
                    )
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, PPSpace.xs)
            .padding(.vertical, PPSpace.sm)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.ppSeparator)
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(PPOrderMissionText("OrderID")) \(store.state.reference)"
        )
        .accessibilityHint(
            PPOrderMissionText("order_mission_copy_reference")
        )
    }

    @ViewBuilder
    private var heroStatusChapter: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    heroStatusEmblem
                    heroStatusCopy
                }
            } else {
                HStack(alignment: .center, spacing: PPSpace.base) {
                    heroStatusEmblem
                    heroStatusCopy
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(PPSpace.base)
        .background(
            Color.ppForeground,
            in: RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
            .strokeBorder(Color.ppBorder.opacity(0.65), lineWidth: 0.75)
        }
        .overlay(alignment: .leading) {
            Capsule()
                .fill(accent)
                .frame(width: HeroMetric.statusRail)
                .padding(.vertical, PPSpace.md)
        }
    }

    private var heroStatusEmblem: some View {
        Image(systemName: store.state.statusSymbol)
            .font(.system(size: HeroMetric.statusSymbol, weight: .bold))
            .foregroundStyle(accent)
            .frame(
                width: HeroMetric.statusEmblem,
                height: HeroMetric.statusEmblem
            )
            .background(
                accent.opacity(0.14),
                in: RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
                .stroke(accent.opacity(0.28), lineWidth: 1)
            )
            .symbolEffect(
                .bounce,
                value: reduceMotion ? 0 : store.state.statusRevision
            )
            .accessibilityHidden(true)
    }

    private var heroStatusCopy: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Text(store.state.statusTitle)
                .font(PPOrderMissionTypography.display(31))
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(store.state.statusHint)
                .font(PPOrderMissionTypography.body())
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(store.state.statusTitle). \(store.state.statusHint)"
        )
    }

    private var heroJourneySurface: some View {
        Group {
            if #available(iOS 17.0, *) {
                PPOrderLivingHandoffRail(
                    statusKey: store.state.statusKey,
                    statusTitle: store.state.statusTitle,
                    statusHint: store.state.statusHint,
                    updatedAtText: store.state.updatedAtText,
                    fallbackStatusSymbol: store.state.statusSymbol,
                    accent: accent,
                    isRightToLeft: store.isRightToLeft,
                    presentation: .hero,
                    titleForStep: { key, fallback in
                        Self.stepTitle(for: key, fallback: fallback)
                    }
                )
                .id(store.state.orderID)
            } else {
                VStack(spacing: PPSpace.sm) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.ppSeparator.opacity(0.55))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [accent.opacity(0.72), accent],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: max(
                                        10,
                                        proxy.size.width * store.state.statusProgress
                                    )
                                )
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Label(
                            store.state.updatedAtText,
                            systemImage: "clock.arrow.circlepath"
                        )
                        Spacer()
                        Text(
                            verbatim: "\(Int(store.state.statusProgress * 100))%"
                        )
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    .font(PPOrderMissionTypography.caption())
                    .foregroundStyle(Color.ppTextSecondary)
                }
            }
        }
        .padding(.horizontal, PPSpace.xs)
        .padding(.vertical, PPSpace.xs)
    }

    private var timelineSection: some View {
        PPOrderMissionSection(
            eyebrow: PPOrderMissionText("order_mission_journey_eyebrow"),
            title: PPOrderMissionText("order_tracking_title"),
            symbol: "point.topleft.down.to.point.bottomright.curvepath",
            accent: PPOrderMissionColorRole.journeyHistory
        ) {
            if store.state.timelineLoading && store.state.timeline.isEmpty {
                ProgressView()
                    .tint(PPOrderMissionColorRole.primaryAction)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .accessibilityLabel(PPOrderMissionText("Loading"))
            } else {
                if !store.state.timelineErrorMessage.isEmpty {
                    PPOrderMissionInlineNotice(
                        symbol: "wifi.exclamationmark",
                        text: store.state.timelineErrorMessage,
                        color: Color.ppWarning
                    )
                }
                if store.state.timeline.isEmpty {
                    if store.state.timelineErrorMessage.isEmpty {
                        PPOrderMissionInlineEmpty(
                            symbol: "clock",
                            title: PPOrderMissionText(
                                "order_tracking_empty_subtitle"
                            )
                        )
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(store.state.timeline.suffix(4).enumerated()), id: \.element.id) {
                            index, event in
                            PPOrderMissionTimelineRow(
                                event: event,
                                accent: PPOrderMissionColorRole.journeyHistory,
                                isLast: index == min(3, store.state.timeline.count - 1)
                            )
                        }
                    }
                }
            }

            Button {
                store.activeSheet = .timeline
            } label: {
                PPOrderMissionDisclosureLabel(
                    title: PPOrderMissionText("order_mission_open_timeline"),
                    symbol: "arrow.up.forward"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var manifestSection: some View {
        PPOrderMissionSection(
            eyebrow: PPOrderMissionText("order_mission_manifest_eyebrow"),
            title: PPOrderMissionText("order_items_section_title"),
            symbol: "shippingbox",
            accent: PPOrderMissionColorRole.commerce
        ) {
            if store.state.items.isEmpty {
                PPOrderMissionInlineEmpty(
                    symbol: "shippingbox",
                    title: PPOrderMissionText("order_details_no_items")
                )
            } else {
                LazyVStack(spacing: PPSpace.sm) {
                    ForEach(store.state.items) { item in
                        Button {
                            store.openItem(item)
                        } label: {
                            PPOrderMissionItemRow(
                                item: item,
                                accent: PPOrderMissionColorRole.primaryAction
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!item.canOpen)
                    }
                }
            }
        }
    }

    private var financialSection: some View {
        PPOrderMissionSection(
            eyebrow: PPOrderMissionText("order_mission_finance_eyebrow"),
            title: PPOrderMissionText("order_mission_settlement"),
            symbol: "creditcard",
            accent: PPOrderMissionColorRole.financialMetadata
        ) {
            VStack(spacing: PPSpace.md) {
                PPOrderMissionKeyValue(
                    key: PPOrderMissionText("OrderDate"),
                    value: store.state.createdAtText
                )
                PPOrderMissionKeyValue(
                    key: PPOrderMissionText("PaymentMethod"),
                    value: store.state.paymentText
                )
                Divider().overlay(Color.ppSeparator)
                PPOrderMissionKeyValue(
                    key: PPOrderMissionText("order_subtotal_label"),
                    value: store.state.subtotalText,
                    forceLeftToRight: true
                )
                PPOrderMissionKeyValue(
                    key: PPOrderMissionText("delivery_fee"),
                    value: store.state.shippingText,
                    forceLeftToRight: true
                )
                PPOrderMissionKeyValue(
                    key: PPOrderMissionText("Total"),
                    value: store.state.totalText,
                    emphasized: true,
                    forceLeftToRight: true
                )
            }
        }
    }

    private var destinationSection: some View {
        PPOrderMissionSection(
            eyebrow: PPOrderMissionText("order_mission_destination_eyebrow"),
            title: PPOrderMissionText("DeliveryLocation"),
            symbol: "mappin.and.ellipse",
            accent: PPOrderMissionColorRole.location
        ) {
            if store.state.hasCoordinate {
                PPOrderMissionMap(
                    latitude: store.state.latitude,
                    longitude: store.state.longitude,
                    annotationTitle: PPOrderMissionText("DeliveryLocation")
                )
                .frame(height: 164)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: PPCorner.medium,
                        style: .continuous
                    )
                )
                .overlay(alignment: .bottomTrailing) {
                    Button(action: store.openMap) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(PPSpace.sm)
                    .accessibilityLabel(
                        PPOrderMissionText("order_mission_open_maps")
                    )
                }
            } else {
                PPOrderMissionInlineEmpty(
                    symbol: "location.slash",
                    title: PPOrderMissionText(
                        "order_mission_location_unavailable"
                    )
                )
            }

            Text(store.state.addressText)
                .font(PPOrderMissionTypography.body())
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if store.state.fulfillmentVersion != 1 {
                Button(action: store.presentAddresses) {
                    PPOrderMissionDisclosureLabel(
                        title: PPOrderMissionText("Select Delivery Location"),
                        symbol: store.state.addressEditable ? "pencil" : "lock"
                    )
                    .opacity(store.state.addressEditable ? 1 : 0.64)
                }
                .buttonStyle(.plain)
                .accessibilityHint(store.state.addressEditMessage)
            }
        }
    }

    @ViewBuilder
    private var fulfillmentSection: some View {
        if store.state.hasFulfillmentData {
            PPOrderMissionSection(
                eyebrow: PPOrderMissionText("order_mission_fulfillment_eyebrow"),
                title: PPOrderMissionText("fulfillment_section_title"),
                symbol: "square.3.layers.3d",
                accent: PPOrderMissionColorRole.fulfillmentOperations
            ) {
                PPOrderMissionFulfillmentSummaryView(
                    summary: store.state.fulfillmentSummary
                )

                if store.state.fulfillmentLoading {
                    ProgressView(PPOrderMissionText("fulfillment_loading"))
                        .font(PPOrderMissionTypography.callout())
                        .tint(PPOrderMissionColorRole.primaryAction)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !store.state.fulfillmentErrorMessage.isEmpty ||
                    store.state.fulfillmentSummary.isPartial {
                    PPOrderMissionInlineNotice(
                        symbol: "exclamationmark.triangle",
                        text: store.state.fulfillmentErrorMessage.isEmpty
                            ? PPOrderMissionText("order_mission_partial")
                            : store.state.fulfillmentErrorMessage,
                        color: Color.ppWarning
                    )
                }

                ForEach(store.state.fulfillments) { fulfillment in
                    Button {
                        store.activeSheet = .fulfillment(fulfillment)
                    } label: {
                        PPOrderMissionFulfillmentRow(
                            fulfillment: fulfillment
                        )
                    }
                    .buttonStyle(.plain)
                }

                if store.state.fulfillments.isEmpty &&
                    !store.state.fulfillmentLoading {
                    PPOrderMissionInlineEmpty(
                        symbol: "square.3.layers.3d.slash",
                        title: PPOrderMissionText(
                            "fulfillment_not_available"
                        )
                    )
                }
            }
        }
    }

    private var supportActivitySection: some View {
        PPOrderMissionSection(
            eyebrow: PPOrderMissionText("order_mission_support_eyebrow"),
            title: PPOrderMissionText("order_requests_history_title"),
            symbol: "tray.full",
            accent: PPOrderMissionColorRole.support
        ) {
            if store.state.supportLoading && store.state.requests.isEmpty {
                ProgressView()
                    .tint(PPOrderMissionColorRole.primaryAction)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .accessibilityLabel(PPOrderMissionText("Loading"))
            } else {
                if !store.state.supportErrorMessage.isEmpty {
                    PPOrderMissionInlineNotice(
                        symbol: "wifi.exclamationmark",
                        text: store.state.supportErrorMessage,
                        color: Color.ppWarning
                    )
                }
                if let request = store.state.requests.first {
                    Button {
                        store.presentRequest(request)
                    } label: {
                        PPOrderMissionRequestPreview(request: request)
                    }
                    .buttonStyle(.plain)
                } else if store.state.supportErrorMessage.isEmpty {
                    PPOrderMissionInlineEmpty(
                        symbol: "checkmark.shield",
                        title: PPOrderMissionText(
                            "order_mission_no_support_activity"
                        )
                    )
                }
            }

            Button {
                store.activeSheet = .requests
            } label: {
                PPOrderMissionDisclosureLabel(
                    title: PPOrderMissionText("order_mission_open_requests"),
                    symbol: "arrow.up.forward"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var commandDeck: some View {
        PPOrderMissionCommandOrbit(
            actions: store.state.actions.filter(\.isVisible),
            accent: PPOrderMissionColorRole.primaryAction,
            handle: store.handle
        )
    }

    private var connectivityBanner: some View {
        PPOrderMissionInlineNotice(
            symbol: store.state.isOffline ? "wifi.slash" : "exclamationmark.triangle",
            text: store.state.isOffline
                ? PPOrderMissionText("order_mission_cached_state")
                : store.state.errorMessage,
            color: store.state.isOffline ? Color.ppWarning : Color.ppError
        )
    }

    private static func stepTitle(for key: String, fallback: String) -> String {
        switch key {
        case "pending":
            return PPOrderMissionText("order_placed_title")
        case "preparing_for_shipment":
            return PPOrderMissionText("Preparing for Shipment")
        case "ready_for_delivery":
            return PPOrderMissionText("Ready for Delivery")
        case "delivery_partner_assigned":
            return PPOrderMissionText("Delivery Partner Assigned")
        case "on_the_way":
            return PPOrderMissionText("On the Way")
        case "delivered":
            return PPOrderMissionText("Delivered")
        case "completed":
            return PPOrderMissionText("Completed")
        default:
            let localized = PPOrderMissionText(key)
            return localized == key ? fallback : localized
        }
    }
}

struct PPOrderMissionGlassCard: ViewModifier {
    let accent: Color
    var emphasis = false
    var usesAccentBorder = true

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: emphasis ? PPCorner.hero : PPCorner.card,
            style: .continuous
        )
        let border = contrast == .increased
            ? Color.ppTextPrimary.opacity(0.52)
            : (emphasis && usesAccentBorder
                ? accent.opacity(0.24)
                : Color.ppBorder.opacity(0.80))

        content
            .background(
                Color.ppForeground,
                in: shape
            )
            .overlay {
                shape.strokeBorder(
                    border,
                    lineWidth: contrast == .increased ? 1.5 : 0.75
                )
            }
            .shadow(
                color: contrast == .increased
                    ? .clear
                    : Color.black.opacity(colorScheme == .dark ? 0.16 : 0.04),
                radius: emphasis ? 16 : 10,
                x: 0,
                y: emphasis ? 7 : 3
            )
    }
}

private struct PPOrderMissionInsetSurface: ViewModifier {
    let accent: Color
    var prominence: CGFloat = 0.12

    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: PPCorner.medium,
            style: .continuous
        )
        let border = contrast == .increased
            ? Color.ppTextPrimary.opacity(0.52)
            : Color.ppBorder.opacity(0.80)

        content
            .background(
                Color.ppSecondarySurface,
                in: shape
            )
            .overlay {
                shape.strokeBorder(
                    border,
                    lineWidth: contrast == .increased ? 1.5 : 0.75
                )
            }
    }
}

struct PPOrderMissionSection<Content: View>: View {
    let eyebrow: String
    let title: String
    let symbol: String
    let accent: Color
    @ViewBuilder let content: Content
    @Environment(\.layoutDirection) private var layoutDirection

    init(
        eyebrow: String,
        title: String,
        symbol: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.symbol = symbol
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            HStack(spacing: PPSpace.md) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .background(accent.opacity(0.18), in: Circle())
                    .overlay(Circle().stroke(accent.opacity(0.32), lineWidth: 1))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(eyebrow)
                        .font(PPOrderMissionTypography.caption(11))
                        .tracking(layoutDirection == .rightToLeft ? 0 : 0.9)
                        .foregroundStyle(Color.ppTextTertiary)
                    Text(title)
                        .font(PPOrderMissionTypography.headline())
                        .foregroundStyle(Color.ppTextPrimary)
                }
                Spacer(minLength: 0)
            }
            content
        }
        .padding(PPSpace.base)
        .modifier(PPOrderMissionGlassCard(accent: accent))
    }
}

struct PPOrderMissionTimelineRow: View {
    let event: PPOrderMissionTimelineEvent
    let accent: Color
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: PPSpace.md) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(accent.opacity(0.18))
                    Image(systemName: event.symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(accent)
                }
                .frame(width: 32, height: 32)
                if !isLast {
                    Rectangle()
                        .fill(accent.opacity(0.32))
                        .frame(width: 1.5, height: 42)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(PPOrderMissionTypography.callout())
                    .foregroundStyle(Color.ppTextPrimary)
                if !event.subtitle.isEmpty {
                    Text(event.subtitle)
                        .font(PPOrderMissionTypography.caption())
                        .foregroundStyle(Color.ppTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(event.dateText)
                    .font(PPOrderMissionTypography.caption(12))
                    .foregroundStyle(Color.ppTextTertiary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PPOrderMissionItemRow: View {
    let item: PPOrderMissionItem
    let accent: Color

    var body: some View {
        HStack(spacing: PPSpace.md) {
            AppRemoteImage(
                urlString: item.imageURL,
                cacheKey: item.itemID,
                displaySize: CGSize(width: 62, height: 62),
                contentMode: .fill,
                showsRetryAction: false
            )
            .frame(width: 62, height: 62)
            .background(Color.ppSecondarySurface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PPCorner.small,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(item.name)
                    .font(PPOrderMissionTypography.callout())
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(2)
                Text(
                    String(
                        format: PPOrderMissionText("order_mission_quantity_format"),
                        item.quantity
                    )
                )
                .font(PPOrderMissionTypography.caption())
                .foregroundStyle(Color.ppTextSecondary)
            }
            Spacer(minLength: PPSpace.sm)
            VStack(alignment: .trailing, spacing: PPSpace.xs) {
                Text(item.lineTotalText)
                    .font(PPOrderMissionTypography.callout())
                    .foregroundStyle(Color.ppTextPrimary)
                    .environment(\.layoutDirection, .leftToRight)
                if item.canOpen {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent)
                }
            }
        }
        .padding(PPSpace.sm)
        .modifier(PPOrderMissionInsetSurface(accent: accent))
        .accessibilityElement(children: .combine)
        .accessibilityHint(
            item.canOpen
                ? PPOrderMissionText("order_mission_open_item")
                : ""
        )
    }
}

private struct PPOrderMissionKeyValue: View {
    let key: String
    let value: String
    var emphasized = false
    var forceLeftToRight = false

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
            Text(key)
                .font(PPOrderMissionTypography.callout())
                .foregroundStyle(Color.ppTextSecondary)
            Spacer(minLength: PPSpace.sm)
            Text(value)
                .font(
                    emphasized
                        ? PPOrderMissionTypography.headline()
                        : PPOrderMissionTypography.callout()
                )
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.trailing)
                .environment(
                    \.layoutDirection,
                    forceLeftToRight ? .leftToRight : layoutDirection
                )
        }
        .accessibilityElement(children: .combine)
    }
}

struct PPOrderMissionDisclosureLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            Text(title)
                .font(PPOrderMissionTypography.callout())
            Spacer(minLength: PPSpace.sm)
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(Color.ppPrimary)
        .frame(minHeight: 44)
    }
}

struct PPOrderMissionInlineEmpty: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: PPSpace.md) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.ppTextTertiary)
                .frame(width: 36, height: 36)
                .background(Color.ppSecondarySurface, in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(PPOrderMissionTypography.callout())
                .foregroundStyle(Color.ppTextSecondary)
            Spacer(minLength: 0)
        }
        .padding(PPSpace.sm)
        .accessibilityElement(children: .combine)
    }
}

struct PPOrderMissionInlineNotice: View {
    let symbol: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: PPSpace.sm) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(text)
                .font(PPOrderMissionTypography.callout())
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(PPSpace.md)
        .background(
            color.opacity(0.14),
            in: RoundedRectangle(
                cornerRadius: PPCorner.small,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                .stroke(color.opacity(0.26), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct PPOrderMissionFulfillmentSummaryView: View {
    let summary: PPOrderMissionFulfillmentSummary

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            summaryMetric(
                value: summary.total,
                title: PPOrderMissionText("order_mission_total_groups"),
                color: .ppInfo
            )
            summaryMetric(
                value: summary.pending,
                title: PPOrderMissionText("fulfillment_summary_pending"),
                color: summary.pending > 0 ? .ppWarning : .ppTextTertiary
            )
            summaryMetric(
                value: summary.completed,
                title: PPOrderMissionText("fulfillment_summary_completed"),
                color: summary.completed > 0 ? .ppSuccess : .ppTextTertiary
            )
        }
    }

    private func summaryMetric(
        value: Int,
        title: String,
        color: Color
    ) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: "\(value)")
                .font(PPOrderMissionTypography.headline(20))
                .foregroundStyle(color)
            Text(title)
                .font(PPOrderMissionTypography.caption(11))
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .modifier(PPOrderMissionInsetSurface(accent: color, prominence: 0.16))
        .accessibilityElement(children: .combine)
    }
}

struct PPOrderMissionFulfillmentRow: View {
    let fulfillment: PPOrderMissionFulfillment

    var body: some View {
        let color = Color(uiColor: fulfillment.statusColor)
        HStack(spacing: PPSpace.md) {
            Text(String(format: "%02d", fulfillment.sequence))
                .font(PPOrderMissionTypography.caption())
                .foregroundStyle(color)
                .environment(\.layoutDirection, .leftToRight)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.18), in: Circle())
                .overlay(Circle().stroke(color.opacity(0.3), lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(fulfillment.ownerTitle)
                    .font(PPOrderMissionTypography.callout())
                    .foregroundStyle(Color.ppTextPrimary)
                Text(
                    verbatim: "\(fulfillment.statusTitle) • \(fulfillment.itemCountText)"
                )
                    .font(PPOrderMissionTypography.caption())
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: PPSpace.sm)
            VStack(alignment: .trailing, spacing: 2) {
                Text(fulfillment.subtotalText)
                    .font(PPOrderMissionTypography.callout())
                    .foregroundStyle(Color.ppTextPrimary)
                    .environment(\.layoutDirection, .leftToRight)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
            }
        }
        .padding(PPSpace.sm)
        .modifier(PPOrderMissionInsetSurface(accent: color))
        .accessibilityElement(children: .combine)
    }
}

private struct PPOrderMissionRequestPreview: View {
    let request: PPOrderMissionRequest

    private var supportColor: Color { PPOrderMissionColorRole.support }

    var body: some View {
        HStack(spacing: PPSpace.md) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(supportColor)
                .frame(width: 38, height: 38)
                .background(supportColor.opacity(0.16), in: Circle())
                .overlay(
                    Circle().stroke(
                        supportColor.opacity(0.30),
                        lineWidth: 1
                    )
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(request.typeTitle)
                    .font(PPOrderMissionTypography.callout())
                    .foregroundStyle(Color.ppTextPrimary)
                Text(
                    verbatim: "\(request.statusTitle) • \(request.createdAtText)"
                )
                    .font(PPOrderMissionTypography.caption())
                    .foregroundStyle(Color.ppTextSecondary)
            }
            Spacer(minLength: PPSpace.sm)
            Image(systemName: "chevron.forward")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(supportColor)
        }
        .padding(PPSpace.sm)
        .modifier(PPOrderMissionInsetSurface(accent: supportColor))
        .accessibilityElement(children: .combine)
    }
}

private struct PPOrderMissionCommandOrbit: View {
    let actions: [PPOrderMissionAction]
    let accent: Color
    let handle: (PPOrderMissionAction) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var visibleActions: [PPOrderMissionAction] {
        actions.filter(\.isVisible)
    }

    private var readyActions: [PPOrderMissionAction] {
        visibleActions.filter(\.isEligible)
    }

    private var lockedActions: [PPOrderMissionAction] {
        visibleActions.filter { !$0.isEligible }
    }

    /// Highest-value next step, derived purely from the bridge action contract.
    /// Return/replacement tiles are only visible for delivered-like orders, so
    /// their presence re-prioritizes the hero toward after-delivery workflows.
    private var heroAction: PPOrderMissionAction? {
        heroRanking.lazy.compactMap { kind in
            readyActions.first { $0.kind == kind }
        }.first
    }

    private var heroRanking: [String] {
        let deliveredLike = visibleActions.contains {
            $0.kind == "return" || $0.kind == "replacement"
        }
        return deliveredLike
            ? ["return", "replacement", "refund", "complaint", "track", "support"]
            : ["cancel", "track", "complaint", "refund", "support"]
    }

    private var gridActions: [PPOrderMissionAction] {
        guard let hero = heroAction else { return readyActions }
        return readyActions.filter { $0.id != hero.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            deckHeader
            if visibleActions.isEmpty {
                emptyDeck
            } else {
                if let hero = heroAction {
                    PPOrderMissionHeroCommand(
                        action: hero,
                        accent: accent,
                        handle: { perform($0) }
                    )
                }
                if !gridActions.isEmpty {
                    readyGrid
                }
                if !lockedActions.isEmpty {
                    lockedSection
                }
                deckFooter
            }
        }
        .padding(PPSpace.base)
        .modifier(PPOrderMissionGlassCard(accent: accent))
        .accessibilityElement(children: .contain)
    }

    private var deckHeader: some View {
        HStack(spacing: PPSpace.md) {
            Image(systemName: "command")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 38, height: 38)
                .background(
                    LinearGradient(
                        colors: [accent.opacity(0.24), accent.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay(Circle().stroke(accent.opacity(0.32), lineWidth: 1))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(PPOrderMissionText("order_mission_command_eyebrow"))
                    .font(PPOrderMissionTypography.caption(11))
                    .tracking(layoutDirection == .rightToLeft ? 0 : 0.9)
                    .foregroundStyle(Color.ppTextTertiary)
                Text(PPOrderMissionText("order_mission_command_deck"))
                    .font(PPOrderMissionTypography.headline())
                    .foregroundStyle(Color.ppTextPrimary)
            }

            Spacer(minLength: PPSpace.sm)

            readinessPill
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: PPOrderMissionText("order_mission_command_ready_a11y"),
                readyActions.count,
                visibleActions.count
            )
        )
    }

    private var readinessPill: some View {
        let count = readyActions.count
        let isReady = count > 0
        let tint = isReady ? accent : Color.ppTextTertiary
        return HStack(spacing: PPSpace.xs) {
            Circle()
                .fill(isReady ? tint : Color.ppTextTertiary)
                .frame(width: 6, height: 6)
            Text(
                isReady
                    ? String(
                        format: PPOrderMissionText("order_mission_command_ready_format"),
                        count
                    )
                    : PPOrderMissionText("order_mission_command_none_ready")
            )
            .font(PPOrderMissionTypography.caption(12))
            .foregroundStyle(Color.ppTextPrimary)
        }
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, 6)
        .background(tint.opacity(0.14), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.30), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var readyGrid: some View {
        LazyVGrid(
            columns: dynamicTypeSize.isAccessibilitySize
                ? [GridItem(.flexible())]
                : [GridItem(.flexible()), GridItem(.flexible())],
            spacing: PPSpace.md
        ) {
            ForEach(gridActions) { action in
                Button {
                    perform(action)
                } label: {
                    PPOrderMissionActionTile(action: action, accent: accent)
                }
                .buttonStyle(PPOrderMissionCommandPressStyle())
                .accessibilityValue(PPOrderMissionText("order_mission_available"))
                .accessibilityHint(action.message)
            }
        }
    }

    private var lockedSection: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.ppTextTertiary)
                    .accessibilityHidden(true)
                Text(PPOrderMissionText("order_mission_command_locked_title"))
                    .font(PPOrderMissionTypography.caption(11.5))
                    .tracking(layoutDirection == .rightToLeft ? 0 : 0.9)
                    .foregroundStyle(Color.ppTextTertiary)
                Spacer(minLength: 0)
                Text(
                    String(
                        format: PPOrderMissionText("order_mission_command_unavailable_format"),
                        lockedActions.count
                    )
                )
                .font(PPOrderMissionTypography.caption(12))
                .foregroundStyle(Color.ppTextSecondary)
                .accessibilityHidden(true)
            }
            ForEach(lockedActions) { action in
                PPOrderMissionLockedRow(action: action)
            }
        }
        .padding(PPSpace.md)
        .background(
            Color.ppSurfaceOverlay,
            in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .strokeBorder(Color.ppBorder.opacity(0.80), lineWidth: 0.75)
        }
        .accessibilityElement(children: .contain)
    }

    private var deckFooter: some View {
        VStack(spacing: PPSpace.sm) {
            Rectangle()
                .fill(Color.ppSeparator)
                .frame(height: 1)
            HStack(spacing: PPSpace.xs) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.ppTextTertiary)
                    .accessibilityHidden(true)
                Text(PPOrderMissionText("order_mission_command_footer"))
                    .font(PPOrderMissionTypography.caption(11.5))
                    .foregroundStyle(Color.ppTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }

    private var emptyDeck: some View {
        HStack(spacing: PPSpace.md) {
            Image(systemName: "command")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.ppTextTertiary)
                .frame(width: 40, height: 40)
                .background(Color.ppSurfaceOverlay, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(PPOrderMissionText("order_mission_command_empty_title"))
                    .font(PPOrderMissionTypography.callout())
                    .foregroundStyle(Color.ppTextPrimary)
                Text(PPOrderMissionText("order_mission_command_empty_message"))
                    .font(PPOrderMissionTypography.caption())
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(PPSpace.md)
        .background(
            Color.ppSurfaceOverlay,
            in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .strokeBorder(Color.ppBorder.opacity(0.80), lineWidth: 0.75)
        }
        .accessibilityElement(children: .combine)
    }

    private func perform(_ action: PPOrderMissionAction) {
        if !reduceMotion {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        handle(action)
    }
}

private struct PPOrderMissionHeroCommand: View {
    let action: PPOrderMissionAction
    let accent: Color
    let handle: (PPOrderMissionAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.colorScheme) private var colorScheme

    private var actionColor: Color {
        PPOrderMissionColorRole.action(
            kind: action.kind,
            isDestructive: action.isDestructive,
            fallback: accent
        )
    }

    var body: some View {
        let color = actionColor
        let shape = RoundedRectangle(
            cornerRadius: PPCorner.medium,
            style: .continuous
        )
        let iconShape = RoundedRectangle(
            cornerRadius: PPCorner.verysmall + 4,
            style: .continuous
        )

        Button {
            if !reduceMotion {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            handle(action)
        } label: {
            HStack(spacing: PPSpace.md) {
                Image(systemName: action.v6Symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 48, height: 48)
                    .background(
                        color.opacity(colorScheme == .dark ? 0.22 : 0.12),
                        in: iconShape
                    )
                    .overlay(
                        iconShape.stroke(color.opacity(colorScheme == .dark ? 0.38 : 0.22), lineWidth: 1)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(PPOrderMissionText("order_mission_command_primary_eyebrow"))
                        .font(PPOrderMissionTypography.caption(10.5))
                        .tracking(layoutDirection == .rightToLeft ? 0 : 1.0)
                        .foregroundStyle(color)
                    Text(action.v6Title)
                        .font(PPOrderMissionTypography.headline(18))
                        .foregroundStyle(Color.ppTextPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                    Text(action.v6Subtitle)
                        .font(PPOrderMissionTypography.caption(12))
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: PPSpace.sm)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12), in: Circle())
                    .overlay(
                        Circle().stroke(color.opacity(0.22), lineWidth: 1)
                    )
                    .accessibilityHidden(true)
            }
            .padding(PPSpace.base)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            .background(
                Color.ppForeground,
                in: shape
            )
            .overlay(
                shape.strokeBorder(
                    color.opacity(colorScheme == .dark ? 0.35 : 0.22),
                    lineWidth: 1.2
                )
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(color)
                    .frame(width: 3.5)
                    .padding(.vertical, PPSpace.md)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.04), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PPOrderMissionCommandPressStyle())
        .accessibilityHint(action.v6Subtitle)
    }
}

private struct PPOrderMissionActionTile: View {
    let action: PPOrderMissionAction
    let accent: Color

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection

    private var actionColor: Color {
        PPOrderMissionColorRole.action(
            kind: action.kind,
            isDestructive: action.isDestructive,
            fallback: accent
        )
    }

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: PPCorner.medium,
            style: .continuous
        )
        let iconShape = RoundedRectangle(
            cornerRadius: PPCorner.verysmall + 3,
            style: .continuous
        )
        let color = actionColor

        HStack(spacing: PPSpace.sm + 2) {
            Image(systemName: action.v6Symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(
                    color.opacity(colorScheme == .dark ? 0.22 : 0.10),
                    in: iconShape
                )
                .overlay(
                    iconShape.stroke(color.opacity(colorScheme == .dark ? 0.38 : 0.22), lineWidth: 1)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.v6Title)
                    .font(PPOrderMissionTypography.headline(14))
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(action.v6Subtitle)
                    .font(PPOrderMissionTypography.caption(11))
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.sm + 2)
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(
            Color.ppForeground,
            in: shape
        )
        .overlay(
            shape.strokeBorder(
                color.opacity(colorScheme == .dark ? 0.30 : 0.18),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.14 : 0.035),
            radius: 8,
            x: 0,
            y: 3
        )
    }
}

private struct PPOrderMissionLockedRow: View {
    let action: PPOrderMissionAction

    var body: some View {
        HStack(alignment: .top, spacing: PPSpace.md) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.ppTextTertiary)
                .frame(width: 24, height: 24)
                .background(Color.ppSurfaceElevated, in: Circle())
                .overlay(
                    Circle().stroke(Color.ppSurfaceBorder, lineWidth: 1)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(PPOrderMissionTypography.callout())
                    .foregroundStyle(Color.ppTextSecondary)
                if !action.message.isEmpty {
                    Text(action.message)
                        .font(PPOrderMissionTypography.caption(11.5))
                        .foregroundStyle(Color.ppTextTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct PPOrderMissionCommandPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && !reduceMotion ? 0.975 : 1
            )
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct PPOrderMissionLoadingView: View {
    var body: some View {
        VStack(spacing: PPSpace.lg) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.ppPrimary)
            Text(PPOrderMissionText("Loading"))
                .font(PPOrderMissionTypography.body())
                .foregroundStyle(Color.ppTextSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 380)
        .accessibilityElement(children: .combine)
    }
}

private struct PPOrderMissionFatalErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: PPSpace.base) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.ppError)
            Text(PPOrderMissionText("order_mission_load_failed_title"))
                .font(PPOrderMissionTypography.title())
                .foregroundStyle(Color.ppTextPrimary)
            Text(message)
                .font(PPOrderMissionTypography.body())
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.center)
            Button(action: retry) {
                Label(
                    PPOrderMissionText("KLang_Retry"),
                    systemImage: "arrow.clockwise"
                )
                .font(PPOrderMissionTypography.headline())
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(PPGradient.hero)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: PPCorner.medium,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(PPSpace.xl)
        .modifier(PPOrderMissionGlassCard(accent: Color.ppError))
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, minHeight: 420)
    }
}

private struct PPOrderMissionCommandOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.16).ignoresSafeArea()
            VStack(spacing: PPSpace.md) {
                ProgressView()
                    .controlSize(.large)
                    .tint(Color.ppPrimary)
                Text(PPOrderMissionText("order_mission_executing_command"))
                    .font(PPOrderMissionTypography.callout())
                    .foregroundStyle(Color.ppTextPrimary)
            }
            .padding(PPSpace.xl)
            .background(.regularMaterial)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PPCorner.card,
                    style: .continuous
                )
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct PPOrderMissionMap: UIViewRepresentable {
    let latitude: Double
    let longitude: Double
    let annotationTitle: String

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.pointOfInterestFilter = .excludingAll
        map.isAccessibilityElement = true
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinate = CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )
        map.removeAnnotations(map.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = annotationTitle
        map.addAnnotation(annotation)
        map.setRegion(
            MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 1_200,
                longitudinalMeters: 1_200
            ),
            animated: false
        )
        map.accessibilityLabel = annotationTitle
    }
}
