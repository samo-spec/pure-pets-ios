import SwiftUI
import UIKit

// MARK: - Motion geometry

/// The active marketplace header now has one dock instance. Its scroll-driven
/// progress compresses the same controls in place instead of cross-fading two
/// independent header trees.
@available(iOS 15.0, *)
enum PPMarketplaceCommandDockV3Metrics {
    static let minimumTouchTarget: CGFloat = 44
    // Matches the regular identity header's minimum laid-out height (title,
    // result count, and outer vertical insets). A taller Dynamic Type header
    // remains fully expanded until its final 80 points approach the pin edge.
    static let collapseDistance: CGFloat = 80
    static let compactActivationProgress: CGFloat = 0.64

    static func progress(forDockMinY minY: CGFloat) -> CGFloat {
        guard minY.isFinite, collapseDistance > 0 else { return 0 }
        return min(max(1 - (minY / collapseDistance), 0), 1)
    }

    static func interpolate(
        expanded: CGFloat,
        compact: CGFloat,
        progress: CGFloat
    ) -> CGFloat {
        expanded + ((compact - expanded) * min(max(progress, 0), 1))
    }

    static func showsCompactNavigation(progress: CGFloat) -> Bool {
        progress >= 0.70
    }
}

// MARK: - Context identity

@available(iOS 15.0, *)
struct PPMarketplaceIdentityHeaderV3: View {
    @ObservedObject var store: PPMarketplaceDataViewStore
    let availableWidth: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                stackedIdentity
            } else {
                ViewThatFits(in: .horizontal) {
                    inlineIdentity
                    stackedIdentity
                }
            }
        }
        .frame(maxWidth: maximumWidth)
        .padding(.horizontal, horizontalInset)
        .padding(.top, PPSpace.sm)
        .padding(.bottom, PPSpace.md)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var inlineIdentity: some View {
        HStack(alignment: .center, spacing: PPSpace.sm) {
            backControl
                .frame(width: controlSize, alignment: .leading)

            contextControl(alignment: .center)

            cartControl
                .frame(width: controlSize, alignment: .trailing)
        }
    }

    private var stackedIdentity: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(spacing: PPSpace.sm) {
                backControl
                Spacer(minLength: 0)
                cartControl
            }
            contextControl(alignment: .leading)
        }
    }

    private var backControl: some View {
        PPMarketplaceCommandDockV3IconButton(
            symbol: store.isRightToLeft ? "chevron.right" : "chevron.left",
            size: controlSize,
            badge: 0,
            accessibilityLabel: PPMarketplaceText.localized("Back"),
            accessibilityHint: "",
            accessibilityIdentifier: "pp.marketplace.header.v2.back.expanded",
            action: store.goBack
        )
    }

    private var cartControl: some View {
        PPMarketplaceCommandDockV3IconButton(
            symbol: "bag.fill",
            size: controlSize,
            badge: store.cartItemCount,
            accessibilityLabel: PPMarketplaceText.localized("Cart"),
            accessibilityHint: "",
            accessibilityIdentifier: "pp.marketplace.header.v2.cart.expanded",
            action: store.openCart
        )
    }

    private func contextControl(alignment: HorizontalAlignment) -> some View {
        let textAlignment: TextAlignment = alignment == .center ? .center : .leading
        let frameAlignment: Alignment = alignment == .center ? .center : .leading

        return Button(action: store.beginCategoryEditing) {
            VStack(alignment: alignment, spacing: PPSpace.xxs) {
                Text(store.navigationContext.title)
                    .font(HomeFont.title1())
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    .multilineTextAlignment(textAlignment)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)

                Text(contextResultCount)
                    .font(HomeFont.callout())
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: PPMarketplaceCommandDockV3Metrics.minimumTouchTarget,
                alignment: frameAlignment
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
        .accessibilityIdentifier("pp.marketplace.header.v2.context.expanded")
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

    private var controlSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 58 : 54
    }

    private var maximumWidth: CGFloat {
        min(max(availableWidth, 0), horizontalSizeClass == .regular ? 840 : 620)
    }

    private var horizontalInset: CGFloat {
        horizontalSizeClass == .regular ? PPSpace.xxl : PPSpace.screenMargin
    }
}

// MARK: - Single-instance marketplace dock

@available(iOS 15.0, *)
struct PPMarketplaceCommandDockV3: View {
    @ObservedObject var store: PPMarketplaceDataViewStore
    let availableWidth: CGFloat
    let collapseProgress: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(spacing: railSpacing) {
            commandContainer
                .padding(.horizontal, horizontalInset)

            sectionRail
        }
        .frame(maxWidth: maximumWidth)
        .padding(.top, verticalInset)
        .padding(.bottom, bottomInset)
        .frame(maxWidth: .infinity)
        .background {
            PPMarketplaceCommandDockV3Background(
                progress: resolvedProgress,
                reduceTransparency: reduceTransparency,
                increasedContrast: contrast == .increased
            )
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(
                    Color.ppSeparator.opacity(
                        contrast == .increased ? 0.86 : (0.18 + 0.22 * resolvedProgress)
                    )
                )
                .frame(height: contrast == .increased ? 2 : 1)
                .accessibilityHidden(true)
        }
        .shadow(
            color: contrast == .increased
                ? .clear
                : Color.black.opacity(0.065 * resolvedProgress),
            radius: 16,
            y: 8
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(store.contextAccessibilityLabel)
    }

    // MARK: Command line

    @ViewBuilder
    private var commandContainer: some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency {
            GlassEffectContainer(spacing: PPSpace.sm) {
                commandLine
            }
        } else {
            commandLine
        }
#else
        commandLine
#endif
    }

    @ViewBuilder
    private var commandLine: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: PPSpace.sm) {
                searchAndNavigationRow

                categoryLauncher
                    .frame(maxWidth: .infinity, minHeight: controlHeight)
            }
        } else {
            HStack(spacing: PPSpace.sm) {
                if compactNavigationIsVisible {
                    compactBackControl
                        .frame(width: controlHeight)
                }

                categoryLauncher
                    .frame(width: categoryControlWidth)
                    .clipped()

                searchControl
                    .frame(maxWidth: .infinity)

                filterControl
                    .frame(width: controlHeight)

                if compactNavigationIsVisible {
                    compactCartControl
                        .frame(width: controlHeight)
                }
            }
            .frame(height: controlHeight)
        }
    }

    private var searchAndNavigationRow: some View {
        HStack(spacing: PPSpace.sm) {
            if compactNavigationIsVisible {
                compactBackControl
                    .frame(width: controlHeight)
            }

            searchControl
                .frame(maxWidth: .infinity)

            filterControl
                .frame(width: controlHeight)

            if compactNavigationIsVisible {
                compactCartControl
                    .frame(width: controlHeight)
            }
        }
        .frame(height: controlHeight)
    }

    private var compactBackControl: some View {
        PPMarketplaceCommandDockV3IconButton(
            symbol: store.isRightToLeft ? "chevron.right" : "chevron.left",
            size: controlHeight,
            badge: 0,
            accessibilityLabel: PPMarketplaceText.localized("Back"),
            accessibilityHint: "",
            accessibilityIdentifier: "pp.marketplace.header.v2.back.compact",
            action: store.goBack
        )
    }

    private var compactCartControl: some View {
        PPMarketplaceCommandDockV3IconButton(
            symbol: "bag.fill",
            size: controlHeight,
            badge: store.cartItemCount,
            accessibilityLabel: PPMarketplaceText.localized("Cart"),
            accessibilityHint: "",
            accessibilityIdentifier: "pp.marketplace.header.v2.cart.compact",
            action: store.openCart
        )
    }

    private var categoryLauncher: some View {
        Menu {
            Menu {
                ForEach(store.mainKindChoices) { choice in
                    Button {
                        store.applyMainKindShortcut(choice)
                    } label: {
                        if choice.id == store.currentMainKindID {
                            Label(choice.title, systemImage: "checkmark")
                        } else {
                            Text(choice.title)
                        }
                    }
                }
            } label: {
                Label(resolvedSpeciesTitle, systemImage: "pawprint.fill")
            }

            Menu {
                ForEach(store.subKindChoices) { choice in
                    Button {
                        store.applySubKindShortcut(choice)
                    } label: {
                        if choice.id == store.currentSubKindID {
                            Label(choice.title, systemImage: "checkmark")
                        } else {
                            Text(choice.title)
                        }
                    }
                }
            } label: {
                Label(resolvedBreedTitle, systemImage: "tag.fill")
            }
        } label: {
            HStack(spacing: PPSpace.xs) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                if categoryLabelVisibility > 0.01 {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(resolvedSpeciesTitle)
                            .font(HomeFont.bold(13))
                            .foregroundStyle(Color.ppTextPrimary)

                        HStack(spacing: PPSpace.xxs) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .accessibilityHidden(true)

                            Text(resolvedBreedTitle)
                                .font(HomeFont.caption1())
                        }
                        .foregroundStyle(Color.ppTextSecondary)
                    }
                    .lineLimit(1)
                    .opacity(categoryLabelVisibility)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, resolvedProgress > 0.86 ? 10 : 12)
            .frame(
                maxWidth: .infinity,
                minHeight: PPMarketplaceCommandDockV3Metrics.minimumTouchTarget,
                alignment: .leading
            )
            .contentShape(RoundedRectangle(cornerRadius: controlRadius, style: .continuous))
        } primaryAction: {
            store.beginCategoryEditing()
        }
        .menuOrder(.fixed)
        .buttonStyle(.plain)
        .disabled(store.isReplacingContext)
        .ppMarketplaceCommandDockV3Surface(
            shape: RoundedRectangle(cornerRadius: controlRadius, style: .continuous),
            tint: Color.ppPrimary.opacity(colorScheme == .dark ? 0.14 : 0.075),
            fallback: Color.ppSurfaceRaised,
            stroke: Color.ppPrimary.opacity(contrast == .increased ? 0.72 : 0.22),
            lineWidth: contrast == .increased ? 2 : 1,
            interactive: true
        )
        .accessibilityLabel(categoryAccessibilityLabel)
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_category_open_hint")
        )
        .accessibilityInputLabels([
            resolvedSpeciesTitle,
            resolvedBreedTitle
        ])
        .accessibilityIdentifier("pp.marketplace.header.v2.taxonomy")
    }

    private var searchControl: some View {
        Button(action: store.openSearch) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: resolvedProgress > 0.72 ? 17 : 19, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                    .accessibilityHidden(true)

                Text(contextualSearchTitle)
                    .font(dynamicTypeSize.isAccessibilitySize ? HomeFont.subheadline() : HomeFont.callout())
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? PPSpace.sm : PPSpace.base)
            .frame(
                maxWidth: .infinity,
                minHeight: PPMarketplaceCommandDockV3Metrics.minimumTouchTarget,
                alignment: .leading
            )
            .contentShape(RoundedRectangle(cornerRadius: controlRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .ppMarketplaceCommandDockV3Surface(
            shape: RoundedRectangle(cornerRadius: controlRadius, style: .continuous),
            tint: Color.ppPrimary.opacity(colorScheme == .dark ? 0.08 : 0.025),
            fallback: Color.ppSurface,
            stroke: Color.ppSurfaceBorder.opacity(contrast == .increased ? 1 : 0.70),
            lineWidth: contrast == .increased ? 2 : 1,
            interactive: true
        )
        .accessibilityLabel(contextualSearchTitle)
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_search_hint")
        )
        .accessibilityIdentifier(
            resolvedProgress >= PPMarketplaceCommandDockV3Metrics.compactActivationProgress
                ? "pp.marketplace.header.v2.search.compact"
                : "pp.marketplace.header.v2.search.expanded"
        )
    }

    private var filterControl: some View {
        Menu {
            refinementMenuContent
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: resolvedProgress > 0.72 ? 17 : 19, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                    .frame(
                        width: controlHeight,
                        height: PPMarketplaceCommandDockV3Metrics.minimumTouchTarget
                    )

                if store.activeFilterCount > 0 {
                    Text(String(min(store.activeFilterCount, 99)))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            PPMarketplaceAccentPalette(accent: .ppPrimary).onAccent
                        )
                        .frame(minWidth: 17, minHeight: 17)
                        .background(Color.ppPrimary, in: Capsule(style: .continuous))
                        .offset(y: 3)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: controlRadius, style: .continuous))
        } primaryAction: {
            store.beginFilterEditing()
        }
        .menuOrder(.fixed)
        .buttonStyle(.plain)
        .disabled(store.isReplacingContext)
        .ppMarketplaceCommandDockV3Surface(
            shape: RoundedRectangle(cornerRadius: controlRadius, style: .continuous),
            tint: Color.ppPrimary.opacity(colorScheme == .dark ? 0.14 : 0.075),
            fallback: Color.ppSurfaceRaised,
            stroke: Color.ppPrimary.opacity(contrast == .increased ? 0.72 : 0.22),
            lineWidth: contrast == .increased ? 2 : 1,
            interactive: true
        )
        .accessibilityLabel(
            PPMarketplaceText.localized("filterPPAction")
        )
        .accessibilityValue(
            store.activeFilterCount > 0 ? "\(store.activeFilterCount)" : ""
        )
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_filters_open_hint")
        )
        .accessibilityIdentifier(
            resolvedProgress >= PPMarketplaceCommandDockV3Metrics.compactActivationProgress
                ? "pp.marketplace.header.v2.filter.compact"
                : "pp.marketplace.header.v2.filter.expanded"
        )
    }

    @ViewBuilder
    private var refinementMenuContent: some View {
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
                Label(resolvedProviderTitle, systemImage: "storefront.fill")
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
    }

    // MARK: Marketplace section route

    private var sectionRail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PPSpace.xs) {
                    ForEach(store.sections) { descriptor in
                        sectionButton(descriptor)
                            .id(descriptor.rawValue)
                    }
                }
                .padding(.horizontal, horizontalInset)
            }
            .onAppear {
                revealCurrentSection(using: proxy)
            }
            .onChange(of: store.currentSection.rawValue) { _, _ in
                revealCurrentSection(using: proxy)
            }
        }
        .frame(height: sectionRailHeight)
        .accessibilityElement(children: .contain)
    }

    private func sectionButton(
        _ descriptor: PPMarketplaceSectionDescriptor
    ) -> some View {
        let selected = descriptor.rawValue == store.currentSection.rawValue
        let title = PPMarketplaceText.localized(descriptor.titleKey)

        return Button(
            action: { store.selectSection(descriptor) },
            label: {
            HStack(spacing: PPSpace.xs) {
                Image(systemName: descriptor.iconName)
                    .font(
                        .system(
                            size: resolvedProgress > 0.72 ? 14 : 16,
                            weight: selected ? .semibold : .regular
                        )
                    )
                    .accessibilityHidden(true)

                Text(title)
                    .font(resolvedProgress > 0.72 ? HomeFont.bold(14) : HomeFont.headline())
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(selected ? Color.ppPrimary : Color.ppTextSecondary)
            .padding(.horizontal, sectionHorizontalInset)
            .frame(minHeight: PPMarketplaceCommandDockV3Metrics.minimumTouchTarget)
            .background {
                if selected {
                    Capsule(style: .continuous)
                        .fill(Color.ppPrimary.opacity(colorScheme == .dark ? 0.20 : 0.10))
                }
            }
            .overlay {
                if selected && contrast == .increased {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.ppPrimary, lineWidth: 2)
                }
            }
            .contentShape(Capsule(style: .continuous))
            }
        )
        .buttonStyle(.plain)
        .disabled(store.isReplacingContext)
        .accessibilityLabel(title)
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_section_select_hint")
        )
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier(
            "pp.marketplace.header.v2.section.\(descriptor.rawValue)"
        )
    }

    private func revealCurrentSection(using proxy: ScrollViewProxy) {
        proxy.scrollTo(
            store.currentSection.rawValue,
            anchor: store.isRightToLeft ? .trailing : .leading
        )
    }

    // MARK: Resolved copy and values

    private var contextualSearchTitle: String {
        PPMarketplaceText.formatted(
            "marketplace_header_search_format",
            store.navigationContext.title
        )
    }

    private var resolvedSpeciesTitle: String {
        let value = store.currentMainKindTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return value.isEmpty ? PPMarketplaceText.localized("All") : value
    }

    private var resolvedBreedTitle: String {
        let value = store.currentSubKindTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return value.isEmpty
            ? PPMarketplaceText.localized("data_nav_all_breed")
            : value
    }

    private var categoryAccessibilityLabel: String {
        [
            PPMarketplaceText.formatted(
                "marketplace_category_main_kind_format",
                resolvedSpeciesTitle
            ),
            PPMarketplaceText.formatted(
                "marketplace_category_subkind_format",
                resolvedBreedTitle
            )
        ]
        .joined(separator: ", ")
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

    // MARK: Responsive geometry

    private var resolvedProgress: CGFloat {
        let value = min(max(collapseProgress, 0), 1)
        if interactionMotionIsDisabled {
            return value >= PPMarketplaceCommandDockV3Metrics.compactActivationProgress
                ? 1
                : 0
        }
        return value
    }

    private var controlHeight: CGFloat {
        PPMarketplaceCommandDockV3Metrics.interpolate(
            expanded: dynamicTypeSize.isAccessibilitySize ? 62 : 56,
            compact: dynamicTypeSize.isAccessibilitySize ? 56 : 48,
            progress: resolvedProgress
        )
    }

    private var categoryControlWidth: CGFloat {
        return PPMarketplaceCommandDockV3Metrics.interpolate(
            expanded: 126,
            compact: controlHeight,
            progress: resolvedProgress
        )
    }

    private var categoryLabelVisibility: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? 1
            : 1 - min(max(resolvedProgress / 0.72, 0), 1)
    }

    private var compactNavigationIsVisible: Bool {
        PPMarketplaceCommandDockV3Metrics.showsCompactNavigation(
            progress: resolvedProgress
        )
    }

    private var controlRadius: CGFloat {
        PPMarketplaceCommandDockV3Metrics.interpolate(
            expanded: 19,
            compact: controlHeight / 2,
            progress: resolvedProgress
        )
    }

    private var railSpacing: CGFloat {
        PPMarketplaceCommandDockV3Metrics.interpolate(
            expanded: PPSpace.sm,
            compact: PPSpace.xs,
            progress: resolvedProgress
        )
    }

    private var sectionRailHeight: CGFloat {
        PPMarketplaceCommandDockV3Metrics.interpolate(
            expanded: 50,
            compact: 46,
            progress: resolvedProgress
        )
    }

    private var sectionHorizontalInset: CGFloat {
        PPMarketplaceCommandDockV3Metrics.interpolate(
            expanded: 14,
            compact: 11,
            progress: resolvedProgress
        )
    }

    private var verticalInset: CGFloat {
        PPMarketplaceCommandDockV3Metrics.interpolate(
            expanded: PPSpace.sm,
            compact: PPSpace.xs,
            progress: resolvedProgress
        )
    }

    private var bottomInset: CGFloat {
        PPMarketplaceCommandDockV3Metrics.interpolate(
            expanded: PPSpace.sm,
            compact: PPSpace.xs,
            progress: resolvedProgress
        )
    }

    private var maximumWidth: CGFloat {
        min(max(availableWidth, 0), horizontalSizeClass == .regular ? 840 : 620)
    }

    private var horizontalInset: CGFloat {
        horizontalSizeClass == .regular ? PPSpace.xxl : PPSpace.screenMargin
    }

    private var interactionMotionIsDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }
}

// MARK: - Controls and materials

@available(iOS 15.0, *)
private struct PPMarketplaceCommandDockV3IconButton: View {
    let symbol: String
    let size: CGFloat
    let badge: Int
    let accessibilityLabel: String
    let accessibilityHint: String
    let accessibilityIdentifier: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: symbol)
                    .font(.system(size: size >= 52 ? 21 : 17, weight: .semibold))
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
                        .offset(y: -2)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .ppMarketplaceCommandDockV3Surface(
            shape: Circle(),
            tint: Color.ppPrimary.opacity(colorScheme == .dark ? 0.14 : 0.07),
            fallback: Color.ppSurfaceRaised,
            stroke: Color.ppPrimary.opacity(contrast == .increased ? 0.72 : 0.22),
            lineWidth: contrast == .increased ? 2 : 1,
            interactive: true
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(badge > 0 ? "\(badge)" : "")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceCommandDockV3Background: View {
    let progress: CGFloat
    let reduceTransparency: Bool
    let increasedContrast: Bool

    var body: some View {
        Group {
            if reduceTransparency || increasedContrast {
                Color.ppBackground
            } else {
                Rectangle()
                    .fill(.regularMaterial)
                    .overlay {
                        Color.ppBackground.opacity(0.58 + (0.24 * progress))
                    }
            }
        }
        .accessibilityHidden(true)
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceCommandDockV3SurfaceModifier<Surface: Shape>: ViewModifier {
    let shape: Surface
    let tint: Color
    let fallback: Color
    let stroke: Color
    let lineWidth: CGFloat
    let interactive: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency {
            content
                .glassEffect(
                    .regular.tint(tint).interactive(interactive),
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
    func ppMarketplaceCommandDockV3Surface<Surface: Shape>(
        shape: Surface,
        tint: Color,
        fallback: Color,
        stroke: Color,
        lineWidth: CGFloat,
        interactive: Bool
    ) -> some View {
        modifier(
            PPMarketplaceCommandDockV3SurfaceModifier(
                shape: shape,
                tint: tint,
                fallback: fallback,
                stroke: stroke,
                lineWidth: lineWidth,
                interactive: interactive
            )
        )
    }
}
