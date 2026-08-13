import SwiftUI
import UIKit

@available(iOS 15.0, *)
enum PPMarketplaceHeaderV2Presentation {
    case expanded
    case compact
}

@available(iOS 15.0, *)
enum PPMarketplaceHeaderV2Geometry {
    static let minimumTouchTarget: CGFloat = 44
    static let expandedControlSize: CGFloat = 54
    static let expandedSearchHeight: CGFloat = 64
    static let compactControlSize: CGFloat = 44
    static let expandedCategoryHeight: CGFloat = 58
    static let compactCategoryHeight: CGFloat = 48
}

@available(iOS 15.0, *)
enum PPMarketplaceHeaderV2ScrollMetrics {
    static let collapseDistance: CGFloat = 148
    static let compactActivationProgress: CGFloat = 0.62

    static func progress(for minY: CGFloat) -> CGFloat {
        guard minY.isFinite else { return 0 }
        return min(max(-minY / collapseDistance, 0), 1)
    }

    static func expandedVisibility(
        for progress: CGFloat,
        reduceMotion: Bool
    ) -> CGFloat {
        let resolved = min(max(progress, 0), 1)
        if reduceMotion {
            return resolved < compactActivationProgress ? 1 : 0
        }
        return 1 - min(max((resolved - 0.08) / 0.70, 0), 1)
    }

    static func compactVisibility(
        for progress: CGFloat,
        reduceMotion: Bool
    ) -> CGFloat {
        let resolved = min(max(progress, 0), 1)
        if reduceMotion {
            return resolved >= compactActivationProgress ? 1 : 0
        }
        return min(max((resolved - 0.30) / 0.56, 0), 1)
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceHeaderV2MinYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceHeaderV2: View {
    @ObservedObject var store: PPMarketplaceDataViewStore
    let availableWidth: CGFloat
    let presentation: PPMarketplaceHeaderV2Presentation
    let collapseProgress: CGFloat
    let isActiveRepresentation: Bool
    var topSafeAreaInset: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ScaledMetric(relativeTo: .body)
    private var expandedControlSize = PPMarketplaceHeaderV2Geometry.expandedControlSize
    @ScaledMetric(relativeTo: .body)
    private var expandedSearchHeight = PPMarketplaceHeaderV2Geometry.expandedSearchHeight

    var body: some View {
        Group {
            switch presentation {
            case .expanded:
                expandedHeader
                    .opacity(expandedVisibility)
                    .scaleEffect(
                        interactionMotionIsDisabled
                            ? 1
                            : 1 - (0.018 * collapseProgress),
                        anchor: .top
                    )

            case .compact:
                compactHeader
                    .opacity(compactVisibility)
                    .offset(
                        y: interactionMotionIsDisabled
                            ? 0
                            : -10 * (1 - compactVisibility)
                    )
            }
        }
        .allowsHitTesting(isActiveRepresentation)
        .accessibilityHidden(!isActiveRepresentation)
    }

    // MARK: - Expanded screenshot composition

    private var expandedHeader: some View {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? PPSpace.lg : PPSpace.base) {
            expandedIdentityRow
            expandedSearchSurface
            sectionRail(isCompact: false)
        }
        .frame(maxWidth: resolvedMaximumWidth)
        .padding(.top, PPSpace.sm)
        .padding(.horizontal, horizontalInset)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            sectionRailBaseline
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(store.contextAccessibilityLabel)
    }

    private var expandedIdentityRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: PPSpace.base) {
                backControl(size: resolvedExpandedControlSize, compact: false)
                contextControl(compact: false)
                cartControl(size: resolvedExpandedControlSize, compact: false)
            }

            VStack(alignment: .leading, spacing: PPSpace.md) {
                HStack(spacing: PPSpace.base) {
                    backControl(size: resolvedExpandedControlSize, compact: false)
                    cartControl(size: resolvedExpandedControlSize, compact: false)
                    Spacer(minLength: 0)
                }
                contextControl(compact: false)
            }
        }
    }

    private var expandedSearchSurface: some View {
        HStack(spacing: 0) {
            Button(action: store.openSearch) {
                HStack(spacing: PPSpace.md) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.ppPrimary)
                        .accessibilityHidden(true)

                    Text(contextualSearchTitle)
                        .font(HomeFont.callout())
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, PPSpace.lg)
                .frame(
                    maxWidth: .infinity,
                    minHeight: resolvedSearchHeight,
                    alignment: .leading
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(contextualSearchTitle)
            .accessibilityHint(
                PPMarketplaceText.localized("marketplace_search_hint")
            )
            .accessibilityIdentifier("pp.marketplace.header.v2.search.expanded")

            Rectangle()
                .fill(Color.ppSeparator.opacity(contrast == .increased ? 0.82 : 0.48))
                .frame(width: contrast == .increased ? 2 : 1, height: 38)
                .accessibilityHidden(true)

            filterControl(
                size: max(PPMarketplaceHeaderV2Geometry.minimumTouchTarget, resolvedSearchHeight),
                compact: false
            )
        }
        .frame(minHeight: resolvedSearchHeight)
        .ppMarketplaceHeaderV2Glass(
            in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous),
            tint: Color.ppPrimary.opacity(colorScheme == .dark ? 0.055 : 0.025),
            fallback: Color.ppSurface,
            stroke: Color.ppSurfaceBorder.opacity(contrast == .increased ? 1 : 0.68),
            lineWidth: contrast == .increased ? 2 : 1,
            isInteractive: true
        )
        .shadow(
            color: contrast == .increased ? .clear : Color.black.opacity(0.045),
            radius: 18,
            y: 8
        )
    }

    // MARK: - Compact pinned composition

    private var compactHeader: some View {
        VStack(spacing: PPSpace.xs) {
            compactCommandRow
            sectionRail(isCompact: true)
        }
        .frame(maxWidth: resolvedMaximumWidth)
        .padding(.top, max(0, topSafeAreaInset) + PPSpace.xs)
        .padding(.horizontal, horizontalInset)
        .padding(.bottom, PPSpace.sm)
        .frame(maxWidth: .infinity)
        .ppMarketplaceHeaderV2Glass(
            in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous),
            tint: Color.ppPrimary.opacity(colorScheme == .dark ? 0.08 : 0.035),
            fallback: Color.ppSurface,
            stroke: Color.ppSurfaceBorder.opacity(contrast == .increased ? 1 : 0.62),
            lineWidth: contrast == .increased ? 2 : 0.8,
            isInteractive: false
        )
        .shadow(
            color: contrast == .increased ? .clear : Color.black.opacity(0.07),
            radius: 18,
            y: 8
        )
        .ignoresSafeArea(.container, edges: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(store.contextAccessibilityLabel)
    }

    private var compactCommandRow: some View {
        HStack(spacing: PPSpace.sm) {
            backControl(
                size: PPMarketplaceHeaderV2Geometry.compactControlSize,
                compact: true
            )

            compactSearchControl

            filterControl(
                size: PPMarketplaceHeaderV2Geometry.compactControlSize,
                compact: true
            )

            refinementMenu

            cartControl(
                size: PPMarketplaceHeaderV2Geometry.compactControlSize,
                compact: true
            )
        }
        .frame(minHeight: PPMarketplaceHeaderV2Geometry.minimumTouchTarget)
    }

    private var compactSearchControl: some View {
        Button(action: store.openSearch) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                    .accessibilityHidden(true)

                Text(contextualSearchTitle)
                    .font(HomeFont.subheadline())
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, PPSpace.md)
            .frame(
                maxWidth: .infinity,
                minHeight: PPMarketplaceHeaderV2Geometry.compactControlSize
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .ppMarketplaceHeaderV2Glass(
            in: Capsule(style: .continuous),
            tint: Color.ppPrimary.opacity(colorScheme == .dark ? 0.06 : 0.025),
            fallback: Color.ppSurfaceRaised,
            stroke: Color.ppSurfaceBorder.opacity(0.58),
            lineWidth: contrast == .increased ? 2 : 0.8,
            isInteractive: true
        )
        .accessibilityLabel(contextualSearchTitle)
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_search_hint")
        )
        .accessibilityIdentifier("pp.marketplace.header.v2.search.compact")
    }

    // MARK: - Shared controls

    private func contextControl(compact: Bool) -> some View {
        Button(action: store.beginCategoryEditing) {
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(store.navigationContext.title)
                    .font(compact ? HomeFont.headline() : HomeFont.title1())
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(compact ? 1 : 2)
                    .minimumScaleFactor(compact ? 0.82 : 0.92)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !compact {
                    Text(contextSubtitle)
                        .font(HomeFont.callout())
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: PPMarketplaceHeaderV2Geometry.minimumTouchTarget,
                alignment: .leading
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isReplacingContext)
        .accessibilityLabel(store.contextAccessibilityLabel)
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_category_open_hint")
        )
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(
            compact
                ? "pp.marketplace.header.v2.context.compact"
                : "pp.marketplace.header.v2.context.expanded"
        )
    }

    private func backControl(size: CGFloat, compact: Bool) -> some View {
        PPMarketplaceHeaderV2IconControl(
            iconName: store.isRightToLeft ? "chevron.right" : "chevron.left",
            size: size,
            accessibilityLabel: PPMarketplaceText.localized("Back"),
            accessibilityHint: nil,
            accessibilityIdentifier: compact
                ? "pp.marketplace.header.v2.back.compact"
                : "pp.marketplace.header.v2.back.expanded",
            badge: 0,
            action: store.goBack
        )
    }

    private func cartControl(size: CGFloat, compact: Bool) -> some View {
        PPMarketplaceHeaderV2IconControl(
            iconName: "bag.fill",
            size: size,
            accessibilityLabel: PPMarketplaceText.localized("Cart"),
            accessibilityHint: nil,
            accessibilityIdentifier: compact
                ? "pp.marketplace.header.v2.cart.compact"
                : "pp.marketplace.header.v2.cart.expanded",
            badge: store.cartItemCount,
            action: store.openCart
        )
    }

    private func filterControl(size: CGFloat, compact: Bool) -> some View {
        PPMarketplaceHeaderV2IconControl(
            iconName: "slider.horizontal.3",
            size: size,
            accessibilityLabel: PPMarketplaceText.localized("filterPPAction"),
            accessibilityHint: PPMarketplaceText.localized(
                "marketplace_filters_open_hint"
            ),
            accessibilityIdentifier: compact
                ? "pp.marketplace.header.v2.filter.compact"
                : "pp.marketplace.header.v2.filter.expanded",
            badge: store.activeFilterCount,
            drawsSurface: compact,
            action: store.beginFilterEditing
        )
    }

    private var refinementMenu: some View {
        Menu {
            Button(action: store.beginFilterEditing) {
                Label(
                    PPMarketplaceText.localized("filterPPAction"),
                    systemImage: "slider.horizontal.3"
                )
            }

            ForEach(store.currentFilterState.groups, id: \.filterID) { group in
                Menu {
                    ForEach(group.options, id: \.value) { option in
                        Button {
                            store.applyQuickFilter(
                                groupID: group.filterID,
                                value: option.value
                            )
                        } label: {
                            if option.value == group.selectedValue {
                                Label(option.title, systemImage: "checkmark")
                            } else {
                                Text(option.title)
                            }
                        }
                    }
                } label: {
                    Label(
                        resolvedFilterTitle(group),
                        systemImage: group.chipIconName ?? "slider.horizontal.3"
                    )
                }
            }

            if store.bridge.sectionSupportsProviderFilter(store.currentSection),
               !store.providerOptions.isEmpty {
                Button(action: store.presentProviderFilter) {
                    Label(
                        resolvedProviderTitle,
                        systemImage: "storefront.fill"
                    )
                }
            }

            Divider()

            ForEach(PPMarketplaceLayout.allCases) { layout in
                Button {
                    store.selectLayout(layout)
                } label: {
                    if layout == store.layout {
                        Label(
                            PPMarketplaceText.localized(layout.titleKey),
                            systemImage: "checkmark"
                        )
                    } else {
                        Label(
                            PPMarketplaceText.localized(layout.titleKey),
                            systemImage: layout.iconName
                        )
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.ppPrimary)
                .frame(
                    width: PPMarketplaceHeaderV2Geometry.compactControlSize,
                    height: PPMarketplaceHeaderV2Geometry.compactControlSize
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .ppMarketplaceHeaderV2Glass(
            in: Circle(),
            tint: Color.ppPrimary.opacity(colorScheme == .dark ? 0.08 : 0.035),
            fallback: Color.ppSurfaceRaised,
            stroke: Color.ppPrimary.opacity(0.18),
            lineWidth: contrast == .increased ? 2 : 0.8,
            isInteractive: true
        )
        .disabled(store.isReplacingContext)
        .accessibilityLabel(
            PPMarketplaceText.localized("marketplace_browse_controls")
        )
        .accessibilityIdentifier("pp.marketplace.header.v2.more.compact")
    }

    private func sectionRail(isCompact: Bool) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: isCompact ? PPSpace.sm : PPSpace.md) {
                    ForEach(store.sections) { descriptor in
                        sectionControl(descriptor, isCompact: isCompact)
                            .id(descriptor.id)
                    }
                }
                .padding(.horizontal, isCompact ? PPSpace.xs : 0)
            }
            .onAppear {
                revealCurrentSection(using: proxy, animated: false)
            }
            .onChange(of: store.currentSection.rawValue) { _, _ in
                revealCurrentSection(
                    using: proxy,
                    animated: !interactionMotionIsDisabled
                )
            }
        }
        .frame(
            minHeight: isCompact
                ? PPMarketplaceHeaderV2Geometry.compactCategoryHeight
                : PPMarketplaceHeaderV2Geometry.expandedCategoryHeight
        )
        .background(alignment: .bottom) {
            if isCompact {
                sectionRailBaseline
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var sectionRailBaseline: some View {
        Rectangle()
            .fill(
                Color.ppSeparator.opacity(
                    contrast == .increased ? 0.86 : 0.40
                )
            )
            .frame(height: contrast == .increased ? 2 : 1)
            .accessibilityHidden(true)
    }

    private func sectionControl(
        _ descriptor: PPMarketplaceSectionDescriptor,
        isCompact: Bool
    ) -> some View {
        let selected = descriptor.rawValue == store.currentSection.rawValue
        let title = PPMarketplaceText.localized(descriptor.titleKey)

        return Button {
            selectSection(descriptor)
        } label: {
            VStack(spacing: isCompact ? PPSpace.xs : PPSpace.sm) {
                Label {
                    Text(title)
                        .font(isCompact ? HomeFont.bold(14) : HomeFont.headline())
                        .lineLimit(1)
                } icon: {
                    Image(systemName: descriptor.iconName)
                        .font(
                            .system(
                                size: isCompact ? 14 : 17,
                                weight: selected ? .semibold : .regular
                            )
                        )
                        .accessibilityHidden(true)
                }
                .foregroundStyle(
                    selected ? Color.ppPrimary : Color.ppTextSecondary
                )
                .frame(
                    minWidth: isCompact ? 88 : 108,
                    minHeight: PPMarketplaceHeaderV2Geometry.minimumTouchTarget
                )

                ZStack {
                    Color.clear.frame(height: isCompact ? 3 : 4)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.ppPrimary)
                        .frame(height: isCompact ? 3 : 4)
                        .scaleEffect(x: selected ? 1 : 0.72, y: 1)
                        .opacity(selected ? 1 : 0)
                }
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
        }
        .buttonStyle(.plain)
        .disabled(store.isReplacingContext)
        .accessibilityLabel(title)
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_section_select_hint")
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(
            "pp.marketplace.header.v2.section.\(descriptor.rawValue)"
        )
    }

    private func selectSection(_ descriptor: PPMarketplaceSectionDescriptor) {
        if reduceMotion || switchControlEnabled || voiceOverEnabled {
            store.selectSection(descriptor)
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                store.selectSection(descriptor)
            }
        }
    }

    // MARK: - Presentation values

    private var contextualSearchTitle: String {
        PPMarketplaceText.formatted(
            "marketplace_header_search_format",
            store.navigationContext.title
        )
    }

    private var contextSubtitle: String {
        var parts: [String] = []
        let mainKind = store.currentMainKindTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !mainKind.isEmpty {
            parts.append(
                PPMarketplaceText.formatted(
                    "marketplace_header_market_format",
                    mainKind
                )
            )
        } else if !store.navigationContext.subtitle.isEmpty {
            parts.append(store.navigationContext.subtitle)
        }

        let subKind = store.currentSubKindTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !subKind.isEmpty {
            parts.append(subKind)
        }

        parts.append(contextResultCount)

        return parts.reduce(into: [String]()) { unique, value in
            guard !unique.contains(where: {
                $0.localizedCaseInsensitiveCompare(value) == .orderedSame
            }) else { return }
            unique.append(value)
        }
        .joined(separator: " · ")
    }

    private var contextResultCount: String {
        switch store.currentSection.rawValue {
        case 1, 2:
            return PPMarketplaceText.formatted(
                "provider_storefront_items_count_marketplace_format",
                store.records.count
            )
        default:
            return store.resultCountText
        }
    }

    private func resolvedFilterTitle(_ group: PPFilterGroup) -> String {
        guard group.isActive(),
              let selected = group.options.first(where: {
                  $0.value == group.selectedValue
              }) else {
            return group.title
        }
        return selected.title
    }

    private var resolvedProviderTitle: String {
        guard let providerID = store.selectedProviderID,
              let provider = store.providerOptions.first(where: {
                  $0.providerID == providerID
              }) else {
            return PPMarketplaceText.localized("dataview_filter_by_provider")
        }
        return provider.title
    }

    private var resolvedMaximumWidth: CGFloat {
        min(max(availableWidth, 0), horizontalSizeClass == .regular ? 840 : 620)
    }

    private var horizontalInset: CGFloat {
        horizontalSizeClass == .regular ? PPSpace.xxl : PPSpace.screenMargin
    }

    private var resolvedExpandedControlSize: CGFloat {
        max(
            PPMarketplaceHeaderV2Geometry.minimumTouchTarget,
            min(expandedControlSize, dynamicTypeSize.isAccessibilitySize ? 64 : 58)
        )
    }

    private var resolvedSearchHeight: CGFloat {
        max(
            PPMarketplaceHeaderV2Geometry.minimumTouchTarget,
            min(expandedSearchHeight, dynamicTypeSize.isAccessibilitySize ? 82 : 68)
        )
    }

    private var interactionMotionIsDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }

    private var expandedVisibility: CGFloat {
        PPMarketplaceHeaderV2ScrollMetrics.expandedVisibility(
            for: collapseProgress,
            reduceMotion: interactionMotionIsDisabled
        )
    }

    private var compactVisibility: CGFloat {
        PPMarketplaceHeaderV2ScrollMetrics.compactVisibility(
            for: collapseProgress,
            reduceMotion: interactionMotionIsDisabled
        )
    }

    private func revealCurrentSection(
        using proxy: ScrollViewProxy,
        animated: Bool
    ) {
        let update = {
            // Horizontal reveal only. The root remains the sole owner of the
            // user-controlled vertical scroll position.
            proxy.scrollTo(
                store.currentSection.rawValue,
                anchor: store.isRightToLeft ? .trailing : .leading
            )
        }
        if animated &&
            !reduceMotion &&
            !switchControlEnabled &&
            !voiceOverEnabled {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                update()
            }
        } else {
            update()
        }
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceHeaderV2IconControl: View {
    let iconName: String
    let size: CGFloat
    let accessibilityLabel: String
    let accessibilityHint: String?
    let accessibilityIdentifier: String
    let badge: Int
    var drawsSurface = true
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: iconName)
                    .font(.system(size: resolvedIconSize, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                    .frame(width: size, height: size)

                if badge > 0 {
                    Text(String(min(badge, 99)))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            PPMarketplaceAccentPalette(accent: .ppPrimary).onAccent
                        )
                        .frame(minWidth: 17, minHeight: 17)
                        .background(Color.ppPrimary, in: Capsule(style: .continuous))
                        .offset(x: 2, y: -2)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(
            PPMarketplaceHeaderV2OptionalSurfaceModifier(
                drawsSurface: drawsSurface,
                colorScheme: colorScheme,
                contrast: contrast
            )
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint ?? "")
        .accessibilityValue(badge > 0 ? "\(badge)" : "")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var resolvedIconSize: CGFloat {
        size >= 52 ? 22 : 17
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceHeaderV2OptionalSurfaceModifier: ViewModifier {
    let drawsSurface: Bool
    let colorScheme: ColorScheme
    let contrast: ColorSchemeContrast

    @ViewBuilder
    func body(content: Content) -> some View {
        if drawsSurface {
            content.ppMarketplaceHeaderV2Glass(
                in: Circle(),
                tint: Color.ppPrimary.opacity(colorScheme == .dark ? 0.09 : 0.045),
                fallback: Color.ppSurfaceRaised,
                stroke: Color.ppPrimary.opacity(contrast == .increased ? 0.72 : 0.20),
                lineWidth: contrast == .increased ? 2 : 1,
                isInteractive: true
            )
        } else {
            content
        }
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceHeaderV2GlassModifier<Surface: Shape>: ViewModifier {
    let shape: Surface
    let tint: Color
    let fallback: Color
    let stroke: Color
    let lineWidth: CGFloat
    let isInteractive: Bool

    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency {
            content
                .glassEffect(
                    .regular.tint(tint).interactive(isInteractive),
                    in: shape
                )
                .overlay {
                    shape.stroke(stroke, lineWidth: lineWidth)
                }
        } else {
            fallbackBody(content)
        }
#else
        fallbackBody(content)
#endif
    }

    @ViewBuilder
    private func fallbackBody(_ content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    shape.fill(fallback)
                } else {
                    shape
                        .fill(.ultraThinMaterial)
                        .overlay {
                            shape.fill(tint)
                        }
                }
            }
            .overlay {
                shape.stroke(stroke, lineWidth: lineWidth)
            }
    }
}

@available(iOS 15.0, *)
private extension View {
    func ppMarketplaceHeaderV2Glass<Surface: Shape>(
        in shape: Surface,
        tint: Color,
        fallback: Color,
        stroke: Color,
        lineWidth: CGFloat,
        isInteractive: Bool
    ) -> some View {
        modifier(
            PPMarketplaceHeaderV2GlassModifier(
                shape: shape,
                tint: tint,
                fallback: fallback,
                stroke: stroke,
                lineWidth: lineWidth,
                isInteractive: isInteractive
            )
        )
    }
}
