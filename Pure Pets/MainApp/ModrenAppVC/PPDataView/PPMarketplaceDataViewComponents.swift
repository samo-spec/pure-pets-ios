import SwiftUI
import UIKit

@available(iOS 15.0, *)
extension Color {
    static var ppMarketplaceTextPrimary: Color {
        Color(uiColor: UIColor(named: "PrimaryTextColor") ?? .label)
    }

    static var ppMarketplaceTextSecondary: Color {
        Color(uiColor: UIColor(named: "SecondaryTextColor") ?? .secondaryLabel)
    }

    static var ppMarketplaceSurface: Color {
        Color(uiColor: UIColor(named: "AppForegroundColor") ?? .secondarySystemBackground)
    }

    static var ppMarketplaceCanvas: Color {
        Color(uiColor: .systemBackground)
    }

    static var ppMarketplaceSeparator: Color {
        Color(uiColor: .separator)
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceAtmosphere: View {
    let accent: UIColor
    let usesBrandAccent: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        WorldGlassBackground(
            tint: usesBrandAccent ? .worldGlassBerry : Color(accent),
            isFaded: true
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceHeroControlLayoutMetrics: Equatable {
    let spacing: CGFloat
    let searchButtonSize: CGFloat
    let categoryMinimumHeight: CGFloat
    let usesCompactHeader: Bool
}

@available(iOS 15.0, *)
enum PPMarketplaceHeroControlLayoutPolicy {
    static func metrics(
        availableWidth: CGFloat,
        isAccessibilitySize: Bool,
        layoutDirection: LayoutDirection
    ) -> PPMarketplaceHeroControlLayoutMetrics {
        // HStack keeps Category on the semantic leading edge and Search on
        // the semantic trailing edge. RTL therefore mirrors placement while
        // preserving the same independent tap targets and stable geometry.
        _ = layoutDirection
        return PPMarketplaceHeroControlLayoutMetrics(
            spacing: PPSpace.md,
            searchButtonSize: 50,
            categoryMinimumHeight: isAccessibilitySize ? 76 : 58,
            usesCompactHeader: isAccessibilitySize || availableWidth < 360
        )
    }
}

@available(iOS 15.0, *)
enum PPMarketplaceContentGeometry {
    static func mosaicColumnCount(
        availableWidth: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?,
        isAccessibilitySize: Bool
    ) -> Int {
        let perSideInset = horizontalSizeClass == .regular
            ? PPSpace.xxl
            : PPSpace.screenMargin
        let usableWidth = max(0, availableWidth - (perSideInset * 2))
        let minimumCardWidth = isAccessibilitySize ? usableWidth : 168
        let proposedCount = Int(
            (usableWidth + PPSpace.base) /
                (max(1, minimumCardWidth) + PPSpace.base)
        )
        let maximumCount = horizontalSizeClass == .regular ? 4 : 2
        return max(1, min(maximumCount, proposedCount))
    }

    static func focusHeight(isAccessibilitySize: Bool) -> CGFloat {
        isAccessibilitySize ? 820 : 536
    }

    static func listSpacing(for layout: PPMarketplaceLayout) -> CGFloat {
        layout == .showcase ? PPSpace.lg : PPSpace.md
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceHero: View {
    @ObservedObject var store: PPMarketplaceDataViewStore
    let availableWidth: CGFloat
    let showsBackControl: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        // A field guide: orientation first, then the animal and its breed.
        // The taxonomy is the heading itself, with no second selection owner.
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            topContextRail
            browseCommands
        }
        .padding(.horizontal, horizontalInset)
        .padding(.top, PPSpace.xs)
        .padding(.bottom, PPSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
        .accessibilityElement(children: .contain)
    }

    private var topContextRail: some View {
        HStack(alignment: .center, spacing: PPSpace.sm) {
            backControl
            PPMarketplaceSmartContextPill(
                store: store,
                action: store.beginFilterEditing
            )
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private var backControl: some View {
        PPMarketplaceBackControl(
            accent: .ppTextPrimary,
            isRightToLeft: store.isRightToLeft,
            isEmbedded: false,
            action: store.goBack
        )
        .opacity(showsBackControl ? 1 : 0)
        .allowsHitTesting(showsBackControl)
        .accessibilityHidden(!showsBackControl)
    }

    @ViewBuilder
    private var browseCommands: some View {
        if heroControlMetrics.usesCompactHeader || dynamicTypeSize >= .xxLarge {
            VStack(alignment: .leading, spacing: PPSpace.sm) {
                categoryCommand
                searchCommand(expanded: true)
            }
        } else {
            HStack(alignment: .center, spacing: PPSpace.md) {
                categoryCommand
                    .layoutPriority(1)
                searchCommand(expanded: false)
            }
        }
    }

    private var categoryCommand: some View {
        VStack(alignment: .leading, spacing: 2) {
            mainKindMenu
            HStack(alignment: .center, spacing: PPSpace.xs) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary.opacity(0.8))
                    .scaleEffect(x: store.isRightToLeft ? -1 : 1, y: 1)
                    .frame(width: PPSpace.md)
                    .accessibilityHidden(true)
                subKindMenu
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("pp.marketplace.category")
        .disabled(store.isReplacingContext)
        .opacity(store.isReplacingContext ? 0.55 : 1)
    }

    private var mainKindMenu: some View {
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
            categoryMenuLabel(
                text: store.currentMainKindTitle,
                primary: true
            )
        }
        .accessibilityLabel(PPMarketplaceText.formatted(
            "marketplace_category_main_kind_format",
            store.currentMainKindTitle
        ))
        .accessibilityAddTraits(.isHeader)
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_category_main_kind_hint")
        )
        .accessibilityIdentifier("pp.marketplace.category.main-kind")
    }

    private var subKindMenu: some View {
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
            categoryMenuLabel(
                text: store.currentSubKindTitle,
                primary: false
            )
        }
        .accessibilityLabel(PPMarketplaceText.formatted(
            "marketplace_category_subkind_format",
            store.currentSubKindTitle
        ))
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_category_subkind_hint")
        )
        .accessibilityIdentifier("pp.marketplace.category.subkind")
    }

    private func categoryMenuLabel(
        text: String,
        primary: Bool
    ) -> some View {
        HStack(spacing: PPSpace.xs) {
            Text(text)
                .font(primary ? HomeFont.bold(26) : HomeFont.medium(15))
                .foregroundStyle(
                    primary
                        ? Color.ppTextPrimary
                        : Color.ppTextSecondary
                )
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : (primary ? 2 : 1))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Image(systemName: "chevron.down")
                .font(.system(size: primary ? 11 : 9, weight: .bold))
                .foregroundStyle(primary ? Color.ppTextPrimary.opacity(0.7) : Color.ppTextSecondary.opacity(0.8))
                .accessibilityHidden(true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, primary ? 2 : 1)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func searchCommand(expanded: Bool) -> some View {
        Button(action: store.openSearch) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(
                        width: heroControlMetrics.searchButtonSize,
                        height: heroControlMetrics.searchButtonSize
                    )
                    .accessibilityHidden(true)
                if expanded {
                    Text(PPMarketplaceText.localized("marketplace_search_title"))
                        .font(HomeFont.bold(15))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, PPSpace.base)
                        .padding(.vertical, PPSpace.sm)
                }
            }
            .foregroundStyle(Color.white)
            .background(
                Color.ppPrimary,
                in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            }
            .shadow(color: Color.ppPrimary.opacity(0.16), radius: 4, x: 0, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
        }
        .buttonStyle(PPMarketplacePressStyle(
            reduceMotion: reduceMotion || switchControlEnabled || voiceOverEnabled
        ))
        .accessibilityLabel(PPMarketplaceText.localized("marketplace_search_title"))
        .accessibilityHint(PPMarketplaceText.localized("marketplace_search_hint"))
        .accessibilityIdentifier("pp.marketplace.search")
    }

    private var heroControlMetrics: PPMarketplaceHeroControlLayoutMetrics {
        PPMarketplaceHeroControlLayoutPolicy.metrics(
            availableWidth: availableWidth,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
            layoutDirection: store.isRightToLeft ? .rightToLeft : .leftToRight
        )
    }

    private var horizontalInset: CGFloat {
        horizontalSizeClass == .regular ? PPSpace.xxl : PPSpace.screenMargin
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceBackControl: View {
    let accent: UIColor
    let isRightToLeft: Bool
    var isEmbedded = false
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            Image(systemName: isRightToLeft ? "chevron.right" : "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(uiColor: accent))
                .frame(width: 36, height: 36)
                .background(
                    Color.ppSurface,
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .strokeBorder(
                            contrast == .increased ? Color.ppTextPrimary : Color.ppSeparator.opacity(0.5),
                            lineWidth: contrast == .increased ? 1 : 0.5
                        )
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PPMarketplaceText.localized("Back"))
        .accessibilityIdentifier("pp.marketplace.back")
    }
}

// MARK: - Context and field-guide controls

/// The historical identifier and filter action remain stable. Context is a
/// bridge-owned snapshot; changing its words never schedules animation work.
@available(iOS 15.0, *)
private struct PPMarketplaceSmartContextPill: View {
    @ObservedObject var store: PPMarketplaceDataViewStore
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private var context: PPMarketplaceNavigationContext {
        store.navigationContext
    }

    var body: some View {
        Button {
            guard !store.isReplacingContext else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: PPSpace.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.title)
                        .font(HomeFont.bold(14))
                        .foregroundStyle(Color.ppTextPrimary)
                    if !context.subtitle.isEmpty {
                        Text(context.subtitle)
                            .font(HomeFont.medium(12))
                            .foregroundStyle(Color.ppTextSecondary)
                    }
                }
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: PPSpace.xs)

                Image(systemName: context.systemImageName.isEmpty
                      ? store.currentSectionDescriptor.iconName
                      : context.systemImageName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                    .accessibilityHidden(true)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.ppTextSecondary.opacity(0.8))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, PPSpace.md)
            .padding(.vertical, PPSpace.sm)
            .frame(minHeight: 44)
            .background(
                Color.ppSurface,
                in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                    .strokeBorder(
                        contrast == .increased ? Color.ppTextPrimary : Color.ppSeparator.opacity(0.5),
                        lineWidth: contrast == .increased ? 1 : 0.5
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
        }
        .buttonStyle(PPMarketplacePressStyle(reduceMotion: reduceMotion))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            context.accessibilityLabel.isEmpty ? context.title : context.accessibilityLabel
        )
        .accessibilityHint(PPMarketplaceText.localized("marketplace_filters_open_hint"))
        .accessibilityIdentifier("pp.data.filters.smartDockedPill")
        .disabled(store.isReplacingContext)
        .opacity(store.isReplacingContext ? 0.55 : 1)
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceCurrentDock: View {
    @ObservedObject var store: PPMarketplaceDataViewStore
    let showsPinnedBackControl: Bool
    let statusBarHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var sectionSelection

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            sectionRail
            actionRail
        }
        .padding(.bottom, PPSpace.sm)
        .overlay(alignment: .bottom) {
            if showsPinnedBackControl {
                Rectangle()
                    .fill(contrast == .increased ? Color.ppTextSecondary : Color.ppSeparator.opacity(0.6))
                    .frame(height: contrast == .increased ? 2 : 1)
                    .accessibilityHidden(true)
            }
        }
        .background {
            GeometryReader { proxy in
                // Extend only the pinned surface into the system top area.
                // The bottom edge and the screen's existing pin geometry stay fixed.
                let topExtension = showsPinnedBackControl
                    ? max(0, statusBarHeight) + PPCorner.hero
                    : 0
                if showsPinnedBackControl {
                    Group {
                        if reduceTransparency || contrast == .increased {
                            Rectangle().fill(Color.ppSurface)
                        } else {
                            ZStack {
                                Rectangle().fill(.regularMaterial)
                                Rectangle().fill(Color.ppSurface.opacity(0.90))
                            }
                        }
                    }
                    .frame(height: proxy.size.height + topExtension)
                    .offset(y: -topExtension)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
        }
        .zIndex(4)
    }

    private var sectionRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PPSpace.base) {
                ForEach(store.sections) { descriptor in
                    let selected = descriptor.rawValue == store.currentSection.rawValue
                    Button {
                        store.selectSection(descriptor)
                    } label: {
                        HStack(spacing: PPSpace.xs) {
                            Image(systemName: descriptor.iconName)
                                .font(.system(size: 14, weight: .semibold))
                                .accessibilityHidden(true)
                            Text(PPMarketplaceText.localized(descriptor.titleKey))
                                .font(selected ? HomeFont.bold(15) : HomeFont.medium(15))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundStyle(selected ? Color.ppPrimary : Color.ppTextSecondary)
                        .padding(.horizontal, PPSpace.xs)
                        .padding(.vertical, PPSpace.sm)
                        .frame(minHeight: 44)
                        .overlay(alignment: .bottom) {
                            if selected {
                                Capsule(style: .continuous)
                                    .fill(contrast == .increased
                                          ? Color.ppTextPrimary
                                          : Color.ppPrimary)
                                    .frame(height: contrast == .increased ? 3 : 2)
                                    .matchedGeometryEffect(
                                        id: "marketplace.section.selection",
                                        in: sectionSelection
                                    )
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isReplacingContext)
                    .accessibilityLabel(PPMarketplaceText.localized(descriptor.titleKey))
                    .accessibilityHint(PPMarketplaceText.localized("marketplace_section_select_hint"))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("pp.marketplace.section.\(descriptor.rawValue)")
                }
            }
            .padding(.horizontal, horizontalInset)
            // Keep the committed selection response local and gently damped.
            .animation(
                interactionMotionIsDisabled ? nil : .spring(response: 0.28, dampingFraction: 0.90),
                value: store.currentSection.rawValue
            )
            .transaction { transaction in
                if interactionMotionIsDisabled {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
        }
    }

    private var actionRail: some View {
        HStack(spacing: PPSpace.sm) {
            if showsPinnedBackControl {
                PPMarketplaceBackControl(
                    accent: .ppTextPrimary,
                    isRightToLeft: store.isRightToLeft,
                    isEmbedded: false,
                    action: store.goBack
                )
            }

            // Full filters stay reachable while the contextual commands scroll.
            filtersControl

            Rectangle()
                .fill(contrast == .increased ? Color.ppTextSecondary : Color.ppSeparator.opacity(0.8))
                .frame(width: 1, height: 20)
                .accessibilityHidden(true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PPSpace.xs) {
                    ForEach(store.currentFilterState.groups, id: \.filterID) { group in
                        Menu {
                            ForEach(group.options, id: \.value) { option in
                                Button {
                                    store.applyQuickFilter(groupID: group.filterID, value: option.value)
                                } label: {
                                    if option.value == group.selectedValue {
                                        Label(option.title, systemImage: "checkmark")
                                    } else {
                                        Text(option.title)
                                    }
                                }
                            }
                        } label: {
                            PPMarketplaceRefinementLabel(
                                icon: group.chipIconName ?? "slider.horizontal.3",
                                title: filterChipTitle(group),
                                selected: group.isActive()
                            )
                        }
                        .disabled(store.isReplacingContext)
                        .accessibilityLabel(group.title)
                        .accessibilityValue(filterChipTitle(group))
                        .accessibilityIdentifier("pp.marketplace.filter.\(group.filterID)")
                    }

                    if store.bridge.sectionSupportsProviderFilter(store.currentSection),
                       !store.providerOptions.isEmpty {
                        Button(action: store.presentProviderFilter) {
                            PPMarketplaceRefinementLabel(
                                icon: "storefront.fill",
                                title: selectedProviderTitle,
                                selected: store.selectedProviderID != nil
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isReplacingContext)
                        .accessibilityLabel(PPMarketplaceText.localized("dataview_filter_by_provider"))
                        .accessibilityValue(selectedProviderTitle)
                        .accessibilityIdentifier("pp.marketplace.provider")
                    }

                    Menu {
                        ForEach(PPMarketplaceLayout.allCases) { layout in
                            Button {
                                store.selectLayout(layout)
                            } label: {
                                Label(
                                    PPMarketplaceText.localized(layout.titleKey),
                                    systemImage: layout == store.layout ? "checkmark" : layout.iconName
                                )
                            }
                        }
                    } label: {
                        PPMarketplaceRefinementLabel(
                            icon: store.layout.iconName,
                            title: PPMarketplaceText.localized(store.layout.titleKey),
                            selected: false
                        )
                    }
                    .disabled(store.isReplacingContext)
                    .accessibilityIdentifier("pp.marketplace.layout")

                    Text(store.resultCountText)
                        .font(HomeFont.medium(12))
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, PPSpace.md)
                        .frame(minHeight: 40)
                        .accessibilityLabel(store.resultCountText)

                    if store.isRefreshing {
                        ProgressView()
                            .tint(Color.ppPrimary)
                            .frame(width: 40, height: 40)
                            .accessibilityLabel(PPMarketplaceText.localized("marketplace_refreshing"))
                    }
                }
                .padding(.trailing, horizontalInset)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.leading, horizontalInset)
        .frame(minHeight: 44)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(PPMarketplaceText.localized("marketplace_browse_controls"))
    }

    private var filtersControl: some View {
        Button(action: store.beginFilterEditing) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(store.activeFilterCount > 0 ? Color.white : Color.ppTextPrimary)
                .frame(width: 40, height: 40)
                .background(
                    store.activeFilterCount > 0 ? Color.ppPrimary : Color.ppSurface,
                    in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                        .strokeBorder(
                            store.activeFilterCount > 0
                                ? Color.clear
                                : (contrast == .increased ? Color.ppTextPrimary : Color.ppSeparator.opacity(0.5)),
                            lineWidth: contrast == .increased ? 1 : 0.5
                        )
                }
                .overlay(alignment: .topTrailing) {
                    if store.activeFilterCount > 0 {
                        Text("\(store.activeFilterCount)")
                            .font(HomeFont.bold(10))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.ppPrimaryDarker, in: Capsule())
                            .offset(x: store.isRightToLeft ? -2 : 2, y: -2)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
        }
        .buttonStyle(PPMarketplacePressStyle(reduceMotion: interactionMotionIsDisabled))
        .disabled(store.isReplacingContext)
        .opacity(store.isReplacingContext ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PPMarketplaceText.localized("filterPPAction"))
        .accessibilityValue(PPMarketplaceText.formatted(
            "dataview_filters_active_count_accessibility_format",
            store.activeFilterCount
        ))
        .accessibilityHint(PPMarketplaceText.localized("marketplace_filters_open_hint"))
        .accessibilityIdentifier("pp.marketplace.filters")
    }

    private func filterChipTitle(_ group: PPFilterGroup) -> String {
        guard group.isActive(),
              let selected = group.options.first(where: { $0.value == group.selectedValue }) else {
            return group.title
        }
        return selected.title
    }

    private var selectedProviderTitle: String {
        guard let providerID = store.selectedProviderID,
              let provider = store.providerOptions.first(where: { $0.providerID == providerID }) else {
            return PPMarketplaceText.localized("dataview_filter_by_provider")
        }
        return provider.title
    }

    private var horizontalInset: CGFloat {
        horizontalSizeClass == .regular ? PPSpace.xxl : PPSpace.screenMargin
    }

    private var interactionMotionIsDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled || scenePhase != .active
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceRefinementLabel: View {
    let icon: String
    let title: String
    let selected: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: PPSpace.xs) {
            Image(systemName: selected ? "checkmark" : icon)
                .font(.system(size: 11, weight: .semibold))
                .accessibilityHidden(true)
            Text(title)
                .font(selected ? HomeFont.bold(13) : HomeFont.medium(13))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .opacity(0.7)
                .accessibilityHidden(true)
        }
        .foregroundStyle(selected ? Color.ppPrimary : Color.ppTextPrimary)
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 240 : nil)
        .background(
            selected ? Color.ppPrimary.opacity(0.08) : Color.clear,
            in: Capsule(style: .continuous)
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    contrast == .increased
                        ? Color.ppTextPrimary
                        : (selected ? Color.ppPrimary.opacity(0.24) : Color.clear),
                    lineWidth: contrast == .increased ? 1 : 0.5
                )
        }
        .contentShape(Capsule(style: .continuous))
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceUniversalCard: View {
    let record: PPMarketplaceItemRecord
    let section: PPDataSection
    let layout: PPMarketplaceLayout
    let bridge: PPMarketplaceDataViewBridge

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                PPUniversalCardView(
                    viewModel: record.viewModel,
                    delegate: bridge,
                    context: cellContext,
                    layoutMode: universalLayoutMode,
                    discountMode: .badge,
                    imageLoader: nil,
                    hideTopBadge: false,
                    showsSubtitle: true,
                    forceShowsOwnerMenuButton: true,
                    dataViewPresentation: true,
                    isHomePresentation: false,
                    borderMode: .pordersForHomeView,
                    palette: marketplaceCardPalette,
                    onTap: nil,
                    onQuantityChange: nil
                )
            } else {
                PPMarketplaceCompatibilityCard(
                    viewModel: record.viewModel,
                    context: cellContext,
                    layout: layout,
                    bridge: bridge
                )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("pp.marketplace.item.\(record.id)")
    }

    private var universalLayoutMode: PPManagerCellLayoutMode {
        return layout.universalLayoutMode
    }

    private var marketplaceCardPalette: PPUniversalCardPalette {
        let category = PPMarketplaceAccentPalette(accent: bridge.accentColor)
        var palette = PPUniversalCardPalette.purePets
        palette.primary = category.fill
        palette.primaryDarker = category.darker
        palette.primaryShiner = category.brighter
        palette.onPrimary = .white
        palette.accent = category.fill
        return palette
    }

    private var cellContext: PPCellContext {
        record.viewModel.modelContext
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceFocusCarousel: View {
    let records: [PPMarketplaceItemRecord]
    let bridge: PPMarketplaceDataViewBridge
    let loadMore: (PPMarketplaceItemRecord) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedID: String?
    @State private var previousIDs: [String] = []

    var body: some View {
        TabView(selection: $selectedID) {
            ForEach(records) { record in
                PPMarketplaceUniversalCard(
                    record: record,
                    section: record.section,
                    layout: .focus,
                    bridge: bridge
                )
                .padding(.horizontal, PPSpace.xs)
                .tag(Optional(record.id))
                .onAppear {
                    loadMore(record)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(
            height: PPMarketplaceContentGeometry.focusHeight(
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
        )
        .onAppear {
            previousIDs = records.map(\.id)
            if selectedID == nil {
                selectedID = records.first?.id
            }
        }
        .onChange(of: records.map(\.id)) { ids in
            defer { previousIDs = ids }
            if let selectedID, ids.contains(selectedID) {
                return
            }
            guard !ids.isEmpty else {
                self.selectedID = nil
                return
            }
            let previousIndex = selectedID.flatMap {
                previousIDs.firstIndex(of: $0)
            } ?? 0
            self.selectedID = ids[min(previousIndex, ids.count - 1)]
        }
        .accessibilityLabel(
            PPMarketplaceText.localized("marketplace_focus_layout_accessibility")
        )
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceLoadingState: View {
    let layout: PPMarketplaceLayout
    let availableWidth: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            HStack(spacing: PPSpace.sm) {
                ProgressView()
                    .tint(Color(uiColor: UIColor(named: "AppPrimaryColor") ?? .systemPink))
                Text(PPMarketplaceText.localized("marketplace_loading_title"))
                    .font(HomeFont.headline())
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
            }
            .accessibilityElement(children: .combine)

            if layout == .compact || layout == .showcase {
                LazyVStack(
                    spacing: PPMarketplaceContentGeometry.listSpacing(
                        for: layout
                    )
                ) {
                    ForEach(PPMarketplaceSkeletonSlot.allCases.prefix(4)) { _ in
                        PPMarketplaceSkeletonCard(
                            horizontal: layout == .compact
                                && !dynamicTypeSize.isAccessibilitySize,
                            minimumHeight: skeletonMinimumHeight
                        )
                    }
                }
            } else if layout == .mosaic {
                LazyVGrid(
                    columns: skeletonColumns,
                    spacing: PPSpace.base
                ) {
                    ForEach(PPMarketplaceSkeletonSlot.allCases) { _ in
                        PPMarketplaceSkeletonCard(
                            horizontal: false,
                            minimumHeight: skeletonMinimumHeight
                        )
                    }
                }
            } else {
                PPMarketplaceSkeletonCard(
                    horizontal: false,
                    minimumHeight: skeletonMinimumHeight
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PPMarketplaceText.localized("marketplace_loading_title"))
    }

    private var skeletonColumns: [GridItem] {
        let count = PPMarketplaceContentGeometry.mosaicColumnCount(
            availableWidth: availableWidth,
            horizontalSizeClass: horizontalSizeClass,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
        return Array(
            repeating: GridItem(.flexible(), spacing: PPSpace.base),
            count: count
        )
    }

    private var skeletonMinimumHeight: CGFloat {
        switch layout {
        case .compact:
            return dynamicTypeSize.isAccessibilitySize ? 540 : 184
        case .showcase, .mosaic:
            return dynamicTypeSize.isAccessibilitySize ? 520 : 340
        case .focus:
            return PPMarketplaceContentGeometry.focusHeight(
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
        }
    }
}

@available(iOS 15.0, *)
private enum PPMarketplaceSkeletonSlot: String, CaseIterable, Identifiable {
    case primary
    case secondary
    case tertiary
    case quaternary
    case quinary
    case senary

    var id: String { rawValue }
}

@available(iOS 15.0, *)
private struct PPMarketplaceSkeletonCard: View {
    let horizontal: Bool
    let minimumHeight: CGFloat

    var body: some View {
        Group {
            if horizontal {
                HStack(spacing: PPSpace.md) {
                    skeletonMedia
                        .frame(
                            width: 128,
                            height: max(1, minimumHeight - (PPSpace.sm * 2))
                        )
                    skeletonCopy
                }
                .padding(PPSpace.sm)
            } else {
                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    skeletonMedia
                        .frame(height: max(190, minimumHeight * 0.68))
                    skeletonCopy
                        .padding(.horizontal, PPSpace.sm)
                        .padding(.bottom, PPSpace.sm)
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: minimumHeight,
            alignment: .topLeading
        )
        .background(
            Color.ppMarketplaceSurface,
            in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppMarketplaceSeparator.opacity(0.18), lineWidth: 1)
        }
        .redacted(reason: .placeholder)
    }

    private var skeletonMedia: some View {
        RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
            .fill(Color(uiColor: .tertiarySystemFill))
    }

    private var skeletonCopy: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            Text(PPMarketplaceText.localized("marketplace_skeleton_title"))
                .font(HomeFont.bold(16))
            Text(PPMarketplaceText.localized("marketplace_skeleton_subtitle"))
                .font(HomeFont.medium(14))
            Text(PPMarketplaceText.localized("marketplace_skeleton_price"))
                .font(HomeFont.bold(18))
        }
        .foregroundStyle(Color.ppMarketplaceTextSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceEmptyState: View {
    let hasFilters: Bool
    let accent: UIColor
    let clearAction: () -> Void
    let retryAction: () -> Void

    var body: some View {
        PPMarketplaceStateSurface(
            icon: hasFilters ? "line.3.horizontal.decrease.circle" : "pawprint.circle",
            title: PPMarketplaceText.localized(
                hasFilters
                    ? "marketplace_filtered_empty_title"
                    : "marketplace_empty_title"
            ),
            message: PPMarketplaceText.localized(
                hasFilters
                    ? "marketplace_filtered_empty_message"
                    : "marketplace_empty_message"
            ),
            actionTitle: PPMarketplaceText.localized(
                hasFilters
                    ? "marketplace_clear_filters"
                    : "empty_retry_button"
            ),
            accent: accent,
            action: hasFilters ? clearAction : retryAction
        )
    }
}

@available(iOS 15.0, *)
enum PPMarketplaceRecoveryKind: Equatable {
    case offline
    case failed
}

@available(iOS 15.0, *)
struct PPMarketplaceRecoveryState: View {
    let kind: PPMarketplaceRecoveryKind
    let message: String
    let accent: UIColor
    let retryAction: () -> Void

    var body: some View {
        PPMarketplaceStateSurface(
            icon: kind == .offline ? "wifi.slash" : "exclamationmark.arrow.triangle.2.circlepath",
            title: PPMarketplaceText.localized(
                kind == .offline
                    ? "marketplace_offline_title"
                    : "marketplace_error_title"
            ),
            message: message.isEmpty
                ? PPMarketplaceText.localized(
                    kind == .offline
                        ? "marketplace_offline_message"
                        : "marketplace_error_message"
                )
                : message,
            actionTitle: PPMarketplaceText.localized("empty_retry_button"),
            accent: accent,
            action: retryAction
        )
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceStateSurface: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    let accent: UIColor
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    private var accentPalette: PPMarketplaceAccentPalette {
        PPMarketplaceAccentPalette(accent: accent)
    }

    var body: some View {
        VStack(spacing: PPSpace.lg) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: accent).opacity(0.10))
                Image(systemName: icon)
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(Color(uiColor: accent))
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 82, height: 82)
            .accessibilityHidden(true)

            VStack(spacing: PPSpace.sm) {
                Text(title)
                    .font(HomeFont.bold(20))
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(HomeFont.medium(15))
                    .foregroundStyle(Color.ppMarketplaceTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: action) {
                Label(actionTitle, systemImage: "arrow.clockwise")
                    .font(HomeFont.bold(16))
                    .foregroundStyle(accentPalette.onAccent)
                    .padding(.horizontal, PPSpace.xl)
                    .frame(minHeight: 50)
                    .background(
                        accentPalette.fill,
                        in: Capsule(style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PPSpace.xl)
        .padding(.vertical, PPSpace.xxxl)
        .frame(maxWidth: .infinity)
        .background(
            Color.ppMarketplaceSurface,
            in: RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .strokeBorder(
                    contrast == .increased
                        ? Color.ppMarketplaceTextPrimary
                        : Color.ppMarketplaceSeparator.opacity(0.22),
                    lineWidth: contrast == .increased ? 2 : 1
                )
        }
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceUpdateErrorBanner: View {
    let message: String
    let retry: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            HStack(alignment: .top, spacing: PPSpace.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
                    .padding(.top, PPSpace.xs)
                    .accessibilityHidden(true)

                Text(message)
                    .font(HomeFont.medium(14))
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: PPSpace.xs)

                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    PPMarketplaceText.localized("marketplace_dismiss")
                )
            }

            Button(action: retry) {
                Label(
                    PPMarketplaceText.localized("empty_retry_button"),
                    systemImage: "arrow.clockwise"
                )
                .font(HomeFont.bold(14))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    Color.orange.opacity(0.10),
                    in: Capsule(style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(PPSpace.md)
        .background(.regularMaterial, in: RoundedRectangle(
            cornerRadius: PPCorner.medium,
            style: .continuous
        ))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
    }
}

@available(iOS 15.0, *)
private struct PPMarketplacePressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
