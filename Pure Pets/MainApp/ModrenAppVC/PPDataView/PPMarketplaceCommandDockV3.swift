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
    static let compactTransitionStartProgress: CGFloat = 0.20
    static let compactActivationProgress: CGFloat = 0.50
    static let compactRepresentationProgress: CGFloat = compactActivationProgress

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
        progress >= compactRepresentationProgress
    }

    static func compactNavigationProgress(progress: CGFloat) -> CGFloat {
        let transitionDistance = compactRepresentationProgress -
            compactTransitionStartProgress
        guard transitionDistance > 0 else {
            return showsCompactNavigation(progress: progress) ? 1 : 0
        }
        return min(
            max(
                (progress - compactTransitionStartProgress) /
                    transitionDistance,
                0
            ),
            1
        )
    }

    static func taxonomyRowHeight(
        expandedHeight: CGFloat,
        progress: CGFloat
    ) -> CGFloat {
        let clampedExpandedHeight = max(expandedHeight, minimumTouchTarget)
        if progress < compactRepresentationProgress {
            return interpolate(
                expanded: clampedExpandedHeight,
                compact: minimumTouchTarget,
                progress: compactNavigationProgress(progress: progress)
            )
        }

        let completionDistance = 1 - compactRepresentationProgress
        guard completionDistance > 0 else { return 0 }
        let completion = min(
            max(
                (progress - compactRepresentationProgress) /
                    completionDistance,
                0
            ),
            1
        )
        return interpolate(
            expanded: minimumTouchTarget,
            compact: 0,
            progress: completion
        )
    }

    static func activeCategoryTargetHeight(
        expandedHeight: CGFloat,
        compactHeight: CGFloat,
        progress: CGFloat
    ) -> CGFloat {
        if showsCompactNavigation(progress: progress) {
            return compactHeight
        }
        return taxonomyRowHeight(
            expandedHeight: expandedHeight,
            progress: progress
        )
    }
}

@available(iOS 15.0, *)
enum PPMarketplaceCommandDockV3Accessibility {
    static let taxonomyIdentifier = "pp.marketplace.header.v2.taxonomy"
    static let compactTaxonomyIdentifier =
        "pp.marketplace.header.v2.taxonomy.compact"
    static let speciesIdentifier = "pp.marketplace.header.v2.species"
    static let breedIdentifier = "pp.marketplace.header.v2.breed"
}

// MARK: - Context identity

@available(iOS 15.0, *)
struct PPMarketplaceIdentityHeaderV3: View {
    @ObservedObject var store: PPMarketplaceDataViewStore
    let availableWidth: CGFloat
    let isActiveRepresentation: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                stackedIdentity
            } else {
                if #available(iOS 16.0, *) {
                    ViewThatFits(in: .horizontal) {
                        inlineIdentity
                        stackedIdentity
                    }
                } else {
                    inlineIdentity
                }
            }
        }
        .frame(maxWidth: maximumWidth)
        .padding(.horizontal, horizontalInset)
        .padding(.top, PPSpace.sm)
        .padding(.bottom, PPSpace.md)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .allowsHitTesting(isActiveRepresentation)
        .accessibilityHidden(!isActiveRepresentation)
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
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
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
            accessibilityCommandStack
        } else {
            collapsibleCommandStack
        }
    }

    private var accessibilityCommandStack: some View {
        Group {
            if compactNavigationIsVisible {
                accessibilityCompactCommandStack
            } else {
                accessibilityExpandedCommandStack
            }
        }
    }

    private var accessibilityExpandedCommandStack: some View {
        VStack(spacing: PPSpace.sm) {
            HStack(spacing: PPSpace.sm) {
                searchControl
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)

                filterControl
                    .frame(width: controlHeight)
            }
            .frame(minHeight: controlHeight)

            categoryLauncher
                .frame(maxWidth: .infinity)
        }
    }

    /// Accessibility sizes keep generous controls without retaining the full
    /// three-hundred-point pinned shelf. The handoff is atomic so no active
    /// target is ever clipped below 44 points.
    private var accessibilityCompactCommandStack: some View {
        VStack(spacing: PPSpace.sm) {
            searchControl
                .frame(maxWidth: .infinity)

            HStack(spacing: PPSpace.sm) {
                compactBackControl
                    .frame(width: controlHeight)

                compactCategoryControl
                    .frame(width: controlHeight)

                Spacer(minLength: PPSpace.xs)

                filterControl
                    .frame(width: controlHeight)

                compactCartControl
                    .frame(width: controlHeight)
            }
            .frame(minHeight: controlHeight)
        }
    }

    /// Search owns the expanded first line. Species and Breed receive a full
    /// second line instead of competing for a few truncated points beside it.
    /// As the real pinned-header geometry approaches the top, that taxonomy
    /// line continuously folds into one compact category control while the
    /// same search and filter controls remain on screen.
    private var collapsibleCommandStack: some View {
        VStack(spacing: taxonomyRowSpacing) {
            HStack(spacing: 0) {
                compactBackSlot
                compactNavigationGap
                compactCategorySlot
                compactNavigationGap

                searchControl
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)

                adaptiveCommandGap

                filterControl
                    .frame(width: controlHeight)

                compactNavigationGap
                compactCartSlot
            }
            .frame(height: controlHeight)

            categoryLauncher
                .frame(height: taxonomyRowHeight, alignment: .top)
                .clipped()
                .opacity(compactNavigationIsVisible ? 0 : 1)
                .allowsHitTesting(!compactNavigationIsVisible)
                .accessibilityHidden(compactNavigationIsVisible)
        }
    }

    private var compactBackSlot: some View {
        compactBackControl
            .frame(width: controlHeight)
            .scaleEffect(0.88 + (0.12 * compactNavigationVisibility))
            .opacity(compactNavigationVisibility)
            .frame(width: compactNavigationSlotWidth)
            .clipped()
            .allowsHitTesting(compactNavigationIsVisible)
            .accessibilityHidden(!compactNavigationIsVisible)
    }

    private var compactCartSlot: some View {
        compactCartControl
            .frame(width: controlHeight)
            .scaleEffect(0.88 + (0.12 * compactNavigationVisibility))
            .opacity(compactNavigationVisibility)
            .frame(width: compactNavigationSlotWidth)
            .clipped()
            .allowsHitTesting(compactNavigationIsVisible)
            .accessibilityHidden(!compactNavigationIsVisible)
    }

    private var compactCategorySlot: some View {
        compactCategoryControl
            .frame(width: controlHeight)
            .scaleEffect(0.88 + (0.12 * compactNavigationVisibility))
            .opacity(compactNavigationVisibility)
            .frame(width: compactNavigationSlotWidth)
            .clipped()
            .allowsHitTesting(compactNavigationIsVisible)
            .accessibilityHidden(!compactNavigationIsVisible)
    }

    private var compactNavigationGap: some View {
        Color.clear
            .frame(width: PPSpace.xs * compactNavigationVisibility)
            .accessibilityHidden(true)
    }

    private var adaptiveCommandGap: some View {
        Color.clear
            .frame(
                width: PPMarketplaceCommandDockV3Metrics.interpolate(
                    expanded: PPSpace.sm,
                    compact: PPSpace.xs,
                    progress: compactNavigationVisibility
                )
            )
            .accessibilityHidden(true)
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

    private var compactCategoryControl: some View {
        Menu {
            Menu {
                mainKindMenuItems
            } label: {
                Label(resolvedSpeciesTitle, systemImage: "pawprint.fill")
            }

            Menu {
                subKindMenuItems
            } label: {
                Label(resolvedBreedTitle, systemImage: "tag.fill")
            }
        } label: {
            Image(
                systemName: store.currentMainKindID == 0 &&
                    store.currentSubKindID == 0
                    ? "pawprint"
                    : "pawprint.fill"
            )
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.ppPrimary)
            .frame(width: controlHeight, height: controlHeight)
            .contentShape(Circle())
            .accessibilityIdentifier(
                PPMarketplaceCommandDockV3Accessibility.compactTaxonomyIdentifier
            )
        } primaryAction: {
            store.beginCategoryEditing()
        }
        .menuOrderFixedCompat()
        .buttonStyle(.plain)
        .disabled(store.isReplacingContext)
        .ppMarketplaceCommandDockV3Surface(
            shape: Circle(),
            tint: Color.ppPrimary.opacity(colorScheme == .dark ? 0.14 : 0.07),
            fallback: Color.ppSurfaceRaised,
            stroke: Color.ppPrimary.opacity(contrast == .increased ? 0.72 : 0.22),
            lineWidth: contrast == .increased ? 2 : 1,
            interactive: true
        )
        .accessibilityLabel(categoryAccessibilityValue)
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_category_open_hint")
        )
        .accessibilityInputLabels([
            PPMarketplaceText.localized("marketplace_category_title"),
            resolvedSpeciesTitle,
            resolvedBreedTitle
        ])
        .accessibilityIdentifier(
            PPMarketplaceCommandDockV3Accessibility.taxonomyIdentifier
        )
    }

    private var categoryLauncher: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 0) {
                    mainKindLauncher
                    taxonomyDivider(isVertical: false)
                    subKindLauncher
                }
            } else {
                HStack(spacing: 0) {
                    mainKindLauncher
                    taxonomyDivider(isVertical: true)
                    subKindLauncher
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: taxonomyControlHeight
        )
        .disabled(store.isReplacingContext)
        .ppMarketplaceCommandDockV3Surface(
            shape: RoundedRectangle(cornerRadius: controlRadius, style: .continuous),
            tint: Color.ppPrimary.opacity(colorScheme == .dark ? 0.14 : 0.075),
            fallback: Color.ppSurfaceRaised,
            stroke: Color.ppPrimary.opacity(contrast == .increased ? 0.72 : 0.22),
            lineWidth: contrast == .increased ? 2 : 1,
            interactive: true
        )
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func taxonomyDivider(isVertical: Bool) -> some View {
        let lineWidth: CGFloat = contrast == .increased ? 2 : 1
        Rectangle()
            .fill(
                Color.ppSeparator.opacity(
                    contrast == .increased ? 0.88 : 0.52
                )
            )
            .frame(
                width: isVertical ? lineWidth : nil,
                height: isVertical ? nil : lineWidth
            )
            .padding(
                isVertical ? .vertical : .horizontal,
                PPSpace.sm
            )
            .accessibilityHidden(true)
    }

    private var mainKindLauncher: some View {
        Menu {
            mainKindMenuItems
        } label: {
            taxonomySegment(
                symbol: "pawprint.fill",
                title: resolvedSpeciesTitle,
                roleKey: "data_nav_species",
                emphasized: true
            )
            .accessibilityIdentifier(
                PPMarketplaceCommandDockV3Accessibility.speciesIdentifier
            )
        } primaryAction: {
            store.beginCategoryEditing()
        }
        .menuOrderFixedCompat()
        .buttonStyle(.plain)
        .accessibilityLabel(
            PPMarketplaceText.formatted(
                "marketplace_category_main_kind_format",
                resolvedSpeciesTitle
            )
        )
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_category_open_hint")
        )
        .accessibilityInputLabels([resolvedSpeciesTitle])
        .accessibilityIdentifier(
            PPMarketplaceCommandDockV3Accessibility.taxonomyIdentifier
        )
    }

    private var subKindLauncher: some View {
        Menu {
            subKindMenuItems
        } label: {
            taxonomySegment(
                symbol: "tag.fill",
                title: resolvedBreedTitle,
                roleKey: "data_nav_breed",
                emphasized: false
            )
        } primaryAction: {
            store.beginCategoryEditing()
        }
        .menuOrderFixedCompat()
        .buttonStyle(.plain)
        .accessibilityLabel(
            PPMarketplaceText.formatted(
                "marketplace_category_subkind_format",
                resolvedBreedTitle
            )
        )
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_category_open_hint")
        )
        .accessibilityInputLabels([resolvedBreedTitle])
        .accessibilityIdentifier(
            PPMarketplaceCommandDockV3Accessibility.breedIdentifier
        )
    }

    @ViewBuilder
    private var mainKindMenuItems: some View {
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
    }

    @ViewBuilder
    private var subKindMenuItems: some View {
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
    }

    private func taxonomySegment(
        symbol: String,
        title: String,
        roleKey: String,
        emphasized: Bool
    ) -> some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.ppPrimary)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                Text(PPMarketplaceText.localized(roleKey))
                    .font(HomeFont.caption2())
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(1)

                Text(title)
                    .font(emphasized ? HomeFont.headline() : HomeFont.subheadline())
                    .foregroundStyle(
                        emphasized ? Color.ppTextPrimary : Color.ppTextSecondary
                    )
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.ppTextSecondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, PPSpace.md)
        .frame(maxWidth: .infinity, minHeight: taxonomyControlHeight)
        .contentShape(Rectangle())
    }

    private var searchControl: some View {
        Button(action: store.openSearch) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: resolvedProgress > 0.72 ? 17 : 19, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                    .accessibilityHidden(true)

                if #available(iOS 16.0, *) {
                    ViewThatFits(in: .horizontal) {
                        searchLabel(contextualSearchTitle)
                        searchLabel(PPMarketplaceText.localized("search"))
                        Color.clear
                            .frame(width: 0, height: 1)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    searchLabel(contextualSearchTitle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? PPSpace.sm : PPSpace.base)
            .frame(
                maxWidth: .infinity,
                minHeight: controlHeight,
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
            compactNavigationIsVisible
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
                        height: controlHeight
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
        .menuOrderFixedCompat()
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
            compactNavigationIsVisible
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
            .onChange(of: store.currentSection.rawValue) { _ in
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

                if selected && differentiateWithoutColor {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .accessibilityHidden(true)
                }
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

    private var categoryAccessibilityValue: String {
        PPMarketplaceText.formatted(
            "marketplace_category_accessibility_format",
            resolvedSpeciesTitle,
            resolvedBreedTitle
        )
    }

    private func searchLabel(_ title: String) -> some View {
        Text(title)
            .font(
                dynamicTypeSize.isAccessibilitySize
                    ? HomeFont.subheadline()
                    : HomeFont.callout()
            )
            .foregroundStyle(Color.ppTextSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .fixedSize(horizontal: true, vertical: false)
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

    private var compactNavigationIsVisible: Bool {
        PPMarketplaceCommandDockV3Metrics.showsCompactNavigation(
            progress: resolvedProgress
        )
    }

    private var compactNavigationVisibility: CGFloat {
        PPMarketplaceCommandDockV3Metrics.compactNavigationProgress(
            progress: resolvedProgress
        )
    }

    private var compactNavigationSlotWidth: CGFloat {
        controlHeight * compactNavigationVisibility
    }

    private var expandedTaxonomyVisibility: CGFloat {
        1 - compactNavigationVisibility
    }

    private var taxonomyControlHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 84 : 64
    }

    private var taxonomyRowHeight: CGFloat {
        guard !dynamicTypeSize.isAccessibilitySize else {
            return taxonomyControlHeight * 2
        }
        return PPMarketplaceCommandDockV3Metrics.taxonomyRowHeight(
            expandedHeight: taxonomyControlHeight,
            progress: resolvedProgress
        )
    }

    private var taxonomyRowSpacing: CGFloat {
        guard !dynamicTypeSize.isAccessibilitySize else { return PPSpace.sm }
        return PPSpace.sm * expandedTaxonomyVisibility
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
        if dynamicTypeSize.isAccessibilitySize {
            return 68
        }
        return PPMarketplaceCommandDockV3Metrics.interpolate(
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

    @ViewBuilder
    func menuOrderFixedCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.menuOrder(.fixed)
        } else {
            self
        }
    }
}
