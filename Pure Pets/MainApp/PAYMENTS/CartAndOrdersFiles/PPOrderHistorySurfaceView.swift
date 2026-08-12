//
//  PPOrderHistorySurfaceView.swift
//  Pure Pets
//

import SwiftUI

@available(iOS 17.0, *)
struct PPOrderHistoryScreen: View {
    @ObservedObject var store: PPOrderHistorySurfaceStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var resolvedLayoutDirection: LayoutDirection {
        Language.isRTL() ? .rightToLeft : .leftToRight
    }

    var body: some View {
        ZStack {
            Color.ppBackground.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: PPSpace.base) {
                    navigationHeader
                    summarySurface
                    discoveryControls
                    operationalState
                }
                .padding(.horizontal, PPSpace.screenMargin)
                .padding(.top, PPSpace.sm)
                .padding(.bottom, 128)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                store.requestRefresh()
            }
        }
        .environment(\.layoutDirection, resolvedLayoutDirection)
        .animation(
            reduceMotion ? nil : .snappy(duration: 0.28, extraBounce: 0.02),
            value: store.selectedFilterID
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.22),
            value: store.visibleItems.map(\.id)
        )
    }

    private var navigationHeader: some View {
        HStack(spacing: PPSpace.md) {
            if store.snapshot.showsBackButton {
                PPOrderHistoryRoundButton(
                    symbol: store.snapshot.navigationSymbol,
                    accessibilityLabel: store.snapshot.navigationAccessibilityLabel,
                    action: store.requestBack
                )
            }

            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(PPOrderHistoryText("order_history_header_eyebrow"))
                    .font(PPOrderHistoryTypography.caption(12))
                    .foregroundStyle(Color.ppAccentText)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Text(PPOrderHistoryText("OrderHistory"))
                    .font(PPOrderHistoryTypography.display())
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: PPSpace.sm) {
                PPOrderHistoryRoundButton(
                    symbol: "arrow.clockwise",
                    accessibilityLabel: PPOrderHistoryText("order_history_refresh_accessibility"),
                    action: store.requestRefresh
                )
                .disabled(store.snapshot.isInitialLoading)

                PPOrderHistoryRoundButton(
                    symbol: "headphones",
                    accessibilityLabel: PPOrderHistoryText("order_history_support_accessibility"),
                    action: store.requestSupport
                )
            }
        }
        .padding(.vertical, PPSpace.xs)
        .accessibilityElement(children: .contain)
    }

    private var summarySurface: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: PPSpace.lg) {
                activeCommandCore
                Divider()
                    .frame(height: 68)
                    .overlay(Color.ppSeparator)
                supportingMetrics
            }

            VStack(alignment: .leading, spacing: PPSpace.base) {
                activeCommandCore
                Divider().overlay(Color.ppSeparator)
                supportingMetrics
            }
        }
        .padding(PPSpace.lg)
        .ppOrderHistorySurface(active: store.snapshot.activeCount > 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summaryAccessibilityLabel)
    }

    private var activeCommandCore: some View {
        HStack(spacing: PPSpace.md) {
            ZStack {
                Circle()
                    .fill(
                        store.snapshot.activeCount > 0
                            ? Color.ppSoftRose
                            : Color.ppSecondarySurface
                    )
                Circle()
                    .strokeBorder(
                        store.snapshot.activeCount > 0
                            ? Color.ppPrimary.opacity(0.34)
                            : Color.ppBorder,
                        lineWidth: 1
                    )
                Text(
                    store.snapshot.activeCount,
                    format: .number.locale(PPOrderHistoryLocale)
                )
                    .font(PPOrderHistoryTypography.display(30))
                    .foregroundStyle(
                        store.snapshot.activeCount > 0
                            ? Color.ppAccentText
                            : Color.ppTextSecondary
                    )
                    .contentTransition(.numericText())
            }
            .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(
                    store.snapshot.activeCount > 0
                        ? PPOrderHistoryText("order_history_active_now")
                        : PPOrderHistoryText("order_history_no_active_shown")
                )
                .font(PPOrderHistoryTypography.headline())
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

                Text(
                    store.snapshot.activeCount > 0
                        ? PPOrderHistoryText("order_history_active_explanation")
                        : PPOrderHistoryText("order_history_no_active_explanation")
                )
                    .font(PPOrderHistoryTypography.caption())
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var supportingMetrics: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: PPSpace.xl) {
                metric(
                    value: store.snapshot.totalCount.formatted(
                        .number.locale(PPOrderHistoryLocale)
                    ),
                    title: PPOrderHistoryText("order_history_metric_orders_loaded")
                )
                metric(
                    value: store.snapshot.totalSpentText,
                    title: PPOrderHistoryText("order_history_metric_loaded_value"),
                    forceLeftToRight: true
                )
            }
            VStack(alignment: .leading, spacing: PPSpace.md) {
                metric(
                    value: store.snapshot.totalCount.formatted(
                        .number.locale(PPOrderHistoryLocale)
                    ),
                    title: PPOrderHistoryText("order_history_metric_orders_loaded")
                )
                metric(
                    value: store.snapshot.totalSpentText,
                    title: PPOrderHistoryText("order_history_metric_loaded_value"),
                    forceLeftToRight: true
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metric(
        value: String,
        title: String,
        forceLeftToRight: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(PPOrderHistoryTypography.headline(19))
                .foregroundStyle(Color.ppTextPrimary)
                .contentTransition(.numericText())
                .environment(
                    \.layoutDirection,
                    forceLeftToRight ? .leftToRight : resolvedLayoutDirection
                )
            Text(title)
                .font(PPOrderHistoryTypography.caption())
                .foregroundStyle(Color.ppTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var discoveryControls: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.ppTextSecondary)
                    .accessibilityHidden(true)

                TextField(
                    PPOrderHistoryText("SearchHere"),
                    text: $store.searchText
                )
                .font(PPOrderHistoryTypography.body())
                .foregroundStyle(Color.ppTextPrimary)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .accessibilityLabel(PPOrderHistoryText("SearchHere"))

                if !store.searchText.isEmpty {
                    Button {
                        store.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.ppTextTertiary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        PPOrderHistoryText("order_history_clear_search_accessibility")
                    )
                }
            }
            .padding(.leading, PPSpace.base)
            .padding(.trailing, PPSpace.xs)
            .frame(minHeight: 52)
            .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.ppBorder.opacity(0.82), lineWidth: 0.75)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PPSpace.sm) {
                    ForEach(store.snapshot.filters) { filter in
                        Button {
                            store.selectFilter(filter.id)
                        } label: {
                            HStack(spacing: 6) {
                                Text(filter.title)
                                    .font(PPOrderHistoryTypography.callout())
                                Text(
                                    filter.count,
                                    format: .number.locale(PPOrderHistoryLocale)
                                )
                                    .font(PPOrderHistoryTypography.caption(12))
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                            }
                            .foregroundStyle(
                                store.selectedFilterID == filter.id
                                    ? Color.white
                                    : Color.ppTextSecondary
                            )
                            .padding(.horizontal, PPSpace.base)
                            .frame(minHeight: 42)
                            .background(
                                store.selectedFilterID == filter.id
                                    ? Color.ppPrimary
                                    : Color.ppSurface,
                                in: Capsule()
                            )
                            .overlay {
                                if store.selectedFilterID != filter.id {
                                    Capsule()
                                        .strokeBorder(Color.ppBorder, lineWidth: 0.75)
                                }
                            }
                        }
                        .buttonStyle(PPOrderHistoryPressStyle())
                        .accessibilityLabel(filter.title)
                        .accessibilityValue(
                            Text(
                                filter.count,
                                format: .number.locale(PPOrderHistoryLocale)
                            )
                        )
                        .accessibilityAddTraits(
                            store.selectedFilterID == filter.id ? .isSelected : []
                        )
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    @ViewBuilder
    private var operationalState: some View {
        if store.snapshot.isInitialLoading && store.snapshot.items.isEmpty {
            loadingState
        } else if let error = store.snapshot.errorMessage,
                  store.snapshot.items.isEmpty {
            errorState(message: error)
        } else if store.snapshot.isShowingCachedData &&
                    store.snapshot.items.isEmpty {
            cachedEmptyState
        } else if store.visibleItems.isEmpty {
            emptyState
        } else {
            orderList
        }
    }

    private var orderList: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            if store.snapshot.isShowingCachedData {
                PPOrderHistoryCacheNotice(retry: store.requestRefresh)
            }

            if let error = store.snapshot.errorMessage {
                PPOrderHistoryInlineNotice(
                    message: error,
                    retry: store.requestRefresh
                )
            }

            HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(PPOrderHistoryText("order_history_list_title"))
                        .font(PPOrderHistoryTypography.title())
                        .foregroundStyle(Color.ppTextPrimary)
                    Text(
                        PPOrderHistoryFormat(
                            "order_history_visible_count_format",
                            store.visibleItems.count
                        )
                    )
                    .font(PPOrderHistoryTypography.caption())
                    .foregroundStyle(Color.ppTextSecondary)
                }

                Spacer(minLength: PPSpace.sm)

                if store.hasActiveQuery {
                    Button(PPOrderHistoryText("ClearFilters")) {
                        store.clearQuery()
                    }
                    .font(PPOrderHistoryTypography.callout())
                    .foregroundStyle(Color.ppAccentText)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                }
            }

            LazyVStack(spacing: PPSpace.md) {
                ForEach(store.visibleItems) { item in
                    PPOrderHistoryJourneyCard(
                        item: item,
                        accessibilitySize: dynamicTypeSize.isAccessibilitySize,
                        open: { store.open(item) }
                    )
                    .onAppear {
                        store.requestMoreIfNeeded(for: item)
                    }
                }
            }

            if store.snapshot.isLoadingMore {
                HStack(spacing: PPSpace.sm) {
                    ProgressView().tint(Color.ppPrimary)
                    Text(PPOrderHistoryText("order_history_loading_more"))
                        .font(PPOrderHistoryTypography.callout())
                        .foregroundStyle(Color.ppTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, PPSpace.base)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: PPSpace.base) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.ppPrimary)
            Text(PPOrderHistoryText("order_history_loading_title"))
                .font(PPOrderHistoryTypography.headline())
                .foregroundStyle(Color.ppTextPrimary)
            Text(PPOrderHistoryText("order_history_loading_subtitle"))
                .font(PPOrderHistoryTypography.body())
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: PPSpace.base) {
            Image(systemName: store.hasActiveQuery ? "line.3.horizontal.decrease.circle" : "shippingbox")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.ppAccentText)
                .frame(width: 66, height: 66)
                .background(Color.ppSoftRose, in: Circle())
                .accessibilityHidden(true)

            Text(
                store.hasActiveQuery
                    ? PPOrderHistoryText("empty_no_results_title")
                    : PPOrderHistoryText("NoOrders")
            )
            .font(PPOrderHistoryTypography.title())
            .foregroundStyle(Color.ppTextPrimary)
            .multilineTextAlignment(.center)

            Text(
                store.hasActiveQuery
                    ? PPOrderHistoryText("orders_empty_filtered")
                    : PPOrderHistoryText("order_history_empty_subtitle")
            )
            .font(PPOrderHistoryTypography.body())
            .foregroundStyle(Color.ppTextSecondary)
            .multilineTextAlignment(.center)

            Button(
                store.hasActiveQuery
                    ? PPOrderHistoryText("ClearFilters")
                    : PPOrderHistoryText("empty_retry_button")
            ) {
                if store.hasActiveQuery {
                    store.clearQuery()
                } else {
                    store.requestRefresh()
                }
            }
            .font(PPOrderHistoryTypography.headline())
            .foregroundStyle(Color.white)
            .padding(.horizontal, PPSpace.xl)
            .frame(minHeight: 50)
            .background(Color.ppPrimary, in: Capsule())
            .buttonStyle(PPOrderHistoryPressStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PPSpace.xl)
        .padding(.vertical, 44)
        .ppOrderHistorySurface(active: false)
    }

    private var cachedEmptyState: some View {
        VStack(spacing: PPSpace.base) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.ppWarning)
                .frame(width: 66, height: 66)
                .background(Color.ppWarning.opacity(0.10), in: Circle())
                .accessibilityHidden(true)
            Text(PPOrderHistoryText("order_history_cached_empty_title"))
                .font(PPOrderHistoryTypography.title())
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.center)
            Text(PPOrderHistoryText("order_history_cached_empty_subtitle"))
                .font(PPOrderHistoryTypography.body())
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.center)
            Button(PPOrderHistoryText("retry"), action: store.requestRefresh)
                .font(PPOrderHistoryTypography.headline())
                .foregroundStyle(Color.white)
                .padding(.horizontal, PPSpace.xl)
                .frame(minHeight: 50)
                .background(Color.ppPrimary, in: Capsule())
                .buttonStyle(PPOrderHistoryPressStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PPSpace.xl)
        .padding(.vertical, 44)
        .ppOrderHistorySurface(active: false)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: PPSpace.base) {
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.ppError)
                .frame(width: 66, height: 66)
                .background(Color.ppError.opacity(0.10), in: Circle())
                .accessibilityHidden(true)
            Text(PPOrderHistoryText("load_error_title"))
                .font(PPOrderHistoryTypography.title())
                .foregroundStyle(Color.ppTextPrimary)
            Text(message)
                .font(PPOrderHistoryTypography.body())
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.center)
            Button(PPOrderHistoryText("retry"), action: store.requestRefresh)
                .font(PPOrderHistoryTypography.headline())
                .foregroundStyle(Color.white)
                .padding(.horizontal, PPSpace.xl)
                .frame(minHeight: 50)
                .background(Color.ppPrimary, in: Capsule())
                .buttonStyle(PPOrderHistoryPressStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PPSpace.xl)
        .padding(.vertical, 44)
        .ppOrderHistorySurface(active: false)
    }

    private var summaryAccessibilityLabel: String {
        PPOrderHistoryFormat(
            "order_history_loaded_summary_accessibility_format",
            store.snapshot.totalCount.formatted(
                .number.locale(PPOrderHistoryLocale)
            ),
            store.snapshot.totalSpentText,
            store.snapshot.activeCount
        )
    }
}

@available(iOS 17.0, *)
private struct PPOrderHistoryJourneyCard: View {
    let item: PPOrderHistoryItem
    let accessibilitySize: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            Group {
                if accessibilitySize {
                    VStack(alignment: .leading, spacing: PPSpace.md) {
                        identityBlock
                        detailsBlock
                    }
                } else {
                    HStack(alignment: .top, spacing: PPSpace.md) {
                        preview
                        detailsBlock
                    }
                }
            }
            .padding(PPSpace.base)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .ppOrderHistorySurface(active: item.isActive)
            .overlay(alignment: .leading) {
                if item.isActive {
                    Capsule()
                        .fill(tone)
                        .frame(width: 3, height: 58)
                        .padding(.leading, 1)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(PPOrderHistoryPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(PPOrderHistoryText("order_history_row_accessibility_hint"))
        .accessibilityAddTraits(.isButton)
    }

    private var identityBlock: some View {
        HStack(alignment: .top, spacing: PPSpace.md) {
            preview
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(item.reference)
                    .font(PPOrderHistoryTypography.headline())
                    .foregroundStyle(Color.ppTextPrimary)
                    .environment(\.layoutDirection, .leftToRight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(item.dateText)
                    .font(PPOrderHistoryTypography.caption())
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var preview: some View {
        AppRemoteImage(
            urlString: item.imageURL,
            cacheKey: item.id,
            displaySize: CGSize(width: 66, height: 66),
            contentMode: .fill,
            showsRetryAction: false
        ) {
            PPOrderHistoryImagePlaceholder()
        } failurePlaceholder: {
            PPOrderHistoryImagePlaceholder()
        }
        .frame(width: 66, height: 66)
        .background(Color.ppSecondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.ppBorder.opacity(0.72), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }

    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            if !accessibilitySize {
                HStack(alignment: .top, spacing: PPSpace.sm) {
                    VStack(alignment: .leading, spacing: PPSpace.xs) {
                        Text(item.reference)
                            .font(PPOrderHistoryTypography.headline())
                            .foregroundStyle(Color.ppTextPrimary)
                            .environment(\.layoutDirection, .leftToRight)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.dateText)
                            .font(PPOrderHistoryTypography.caption())
                            .foregroundStyle(Color.ppTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    statusPill
                }
            } else {
                statusPill
            }

            if !item.primaryDescription.isEmpty {
                Text(item.primaryDescription)
                    .font(PPOrderHistoryTypography.body())
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(accessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PPOrderHistoryProgressRail(
                stage: item.progressStage,
                tone: tone,
                terminalFailure: item.filterKey == "failed" ||
                    item.filterKey == "cancelled"
            )

            HStack(alignment: .center, spacing: PPSpace.sm) {
                Text(item.amountText)
                    .font(PPOrderHistoryTypography.headline())
                    .foregroundStyle(Color.ppTextPrimary)
                    .environment(\.layoutDirection, .leftToRight)

                Spacer(minLength: PPSpace.sm)

                if item.quantity > 0 {
                    Text(
                        PPOrderHistoryFormat(
                            "order_history_quantity_format",
                            item.quantity
                        )
                    )
                    .font(PPOrderHistoryTypography.caption())
                    .foregroundStyle(Color.ppTextSecondary)
                }

                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.ppTextTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusPill: some View {
        Label(item.statusTitle, systemImage: statusSymbol)
            .font(PPOrderHistoryTypography.caption())
            .foregroundStyle(tone)
            .lineLimit(2)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tone.opacity(0.10), in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }

    private var tone: Color {
        switch item.filterKey {
        case "delivered": return .ppSuccess
        case "failed": return .ppError
        case "cancelled": return .ppTextSecondary
        case "shipped": return .ppQuickActionServices
        case "processing": return .ppPrimary
        case "paid": return .ppInfo
        default: return .ppWarning
        }
    }

    private var statusSymbol: String {
        switch item.filterKey {
        case "delivered": return "checkmark.circle.fill"
        case "failed": return "exclamationmark.circle.fill"
        case "cancelled": return "xmark.circle.fill"
        case "shipped": return "truck.box.fill"
        case "processing": return "shippingbox.fill"
        case "paid": return "creditcard.fill"
        default: return "clock.fill"
        }
    }

    private var accessibilityLabel: String {
        PPOrderHistoryFormat(
            "order_history_row_accessibility_format",
            item.reference,
            item.statusTitle,
            item.primaryDescription,
            item.amountText,
            item.dateText
        )
    }
}

@available(iOS 17.0, *)
private struct PPOrderHistoryProgressRail: View {
    let stage: Int
    let tone: Color
    let terminalFailure: Bool

    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...4, id: \.self) { index in
                Capsule()
                    .fill(color(for: index))
                    .frame(maxWidth: .infinity)
                    .frame(height: index == min(max(stage, 1), 4) ? 4 : 3)
            }
        }
        .accessibilityHidden(true)
    }

    private func color(for index: Int) -> Color {
        if terminalFailure {
            return index == 1 ? tone.opacity(0.82) : Color.ppBorder.opacity(0.72)
        }
        return index <= stage ? tone.opacity(0.82) : Color.ppBorder.opacity(0.72)
    }
}

@available(iOS 17.0, *)
private struct PPOrderHistoryImagePlaceholder: View {
    var body: some View {
        ZStack {
            Color.ppSecondarySurface
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color.ppAccentText.opacity(0.78))
        }
    }
}

@available(iOS 17.0, *)
private struct PPOrderHistoryInlineNotice: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: PPSpace.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.ppError)
                .accessibilityHidden(true)
            Text(message)
                .font(PPOrderHistoryTypography.callout())
                .foregroundStyle(Color.ppTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(PPOrderHistoryText("retry"), action: retry)
                .font(PPOrderHistoryTypography.callout())
                .foregroundStyle(Color.ppAccentText)
                .buttonStyle(.plain)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, PPSpace.base)
        .padding(.vertical, PPSpace.md)
        .background(Color.ppError.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.ppError.opacity(0.18), lineWidth: 0.75)
        }
        .accessibilityElement(children: .combine)
    }
}

@available(iOS 17.0, *)
private struct PPOrderHistoryCacheNotice: View {
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: PPSpace.md) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.ppWarning)
                .accessibilityHidden(true)
            Text(PPOrderHistoryText("order_history_cached_notice"))
                .font(PPOrderHistoryTypography.callout())
                .foregroundStyle(Color.ppTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(PPOrderHistoryText("retry"), action: retry)
                .font(PPOrderHistoryTypography.callout())
                .foregroundStyle(Color.ppAccentText)
                .buttonStyle(.plain)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, PPSpace.base)
        .padding(.vertical, PPSpace.sm)
        .background(Color.ppWarning.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.ppWarning.opacity(0.22), lineWidth: 0.75)
        }
        .accessibilityElement(children: .combine)
    }
}

@available(iOS 17.0, *)
private struct PPOrderHistoryRoundButton: View {
    let symbol: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.ppTextPrimary)
                .frame(width: 46, height: 46)
                .background(Color.ppSurface, in: Circle())
                .overlay {
                    Circle().strokeBorder(Color.ppBorder.opacity(0.82), lineWidth: 0.75)
                }
        }
        .buttonStyle(PPOrderHistoryPressStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

@available(iOS 17.0, *)
private struct PPOrderHistoryPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                reduceMotion || !configuration.isPressed || !isEnabled
                    ? 1
                    : 0.98
            )
            .opacity(!isEnabled ? 0.42 : (configuration.isPressed ? 0.78 : 1))
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.22, dampingFraction: 0.88),
                value: configuration.isPressed
            )
    }
}

@available(iOS 17.0, *)
private struct PPOrderHistorySurfaceModifier: ViewModifier {
    let active: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let border = contrast == .increased
            ? Color.ppTextPrimary.opacity(0.52)
            : (active ? Color.ppPrimary.opacity(0.24) : Color.ppBorder.opacity(0.80))

        content
            .background(
                active && !reduceTransparency
                    ? Color.ppSurfaceOverlay.opacity(colorScheme == .dark ? 0.66 : 0.54)
                    : Color.ppSurface,
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
                    : Color.black.opacity(colorScheme == .dark ? 0.14 : 0.045),
                radius: active ? 16 : 11,
                x: 0,
                y: active ? 7 : 4
            )
    }
}

@available(iOS 17.0, *)
private extension View {
    func ppOrderHistorySurface(active: Bool) -> some View {
        modifier(PPOrderHistorySurfaceModifier(active: active))
    }
}
