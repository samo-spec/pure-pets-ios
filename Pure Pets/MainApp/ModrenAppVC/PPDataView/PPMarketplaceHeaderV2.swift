import SwiftUI
import UIKit

// MARK: - Presentation

@available(iOS 15.0, *)
enum PPMarketplaceHeaderV2Presentation {
    case expanded
    case compact
}

// MARK: - Geometry

/// One geometry table shared by both dock states.
///
/// Every control that exists in both states keeps the same shape family (a
/// continuous capsule) and the same order, so collapsing reads as a change in
/// density rather than a change in layout.
@available(iOS 15.0, *)
enum PPMarketplaceHeaderV2Geometry {
    static let minimumTouchTarget: CGFloat = 44

    static let expandedControlSize: CGFloat = 54
    static let expandedCommandHeight: CGFloat = 60
    static let expandedCategoryHeight: CGFloat = 58
    static let expandedIndicatorHeight: CGFloat = 4
    static let expandedRailItemInset: CGFloat = 14

    static let compactControlSize: CGFloat = 44
    static let compactCommandHeight: CGFloat = 46
    static let compactCategoryHeight: CGFloat = 46
    static let compactIndicatorHeight: CGFloat = 3
    static let compactRailItemInset: CGFloat = 11

    /// Height of the gradient veil under the pinned dock. Content dissolves
    /// into the dock instead of colliding with its bottom edge.
    static let scrollEdgeVeil: CGFloat = 20

    static func commandHeight(isCompact: Bool) -> CGFloat {
        isCompact ? compactCommandHeight : expandedCommandHeight
    }

    static func categoryHeight(isCompact: Bool) -> CGFloat {
        isCompact ? compactCategoryHeight : expandedCategoryHeight
    }

    static func indicatorHeight(isCompact: Bool) -> CGFloat {
        isCompact ? compactIndicatorHeight : expandedIndicatorHeight
    }

    static func railItemInset(isCompact: Bool) -> CGFloat {
        isCompact ? compactRailItemInset : expandedRailItemInset
    }
}

// MARK: - Scroll metrics

@available(iOS 15.0, *)
enum PPMarketplaceHeaderV2ScrollMetrics {
    static let collapseDistance: CGFloat = 148
    static let compactActivationProgress: CGFloat = 0.62

    /// Collapse progress derived from the **pinned** dock probe.
    ///
    /// The previous driver measured the expanded header's own `minY`. That view
    /// is a row inside a `LazyVStack`, so scrolling far enough destroyed it, the
    /// preference fell back to its default, progress collapsed to `0`, and the
    /// pinned dock vanished together with search, filters, the section rail and
    /// the status-bar protection.
    ///
    /// The pinned section header is retained at every offset, so its `minY` is a
    /// stable monotonic source: it starts at the resting dock offset, decreases
    /// as the user scrolls, and latches at `0` once pinned. Progress therefore
    /// reaches `1` at the pin point and *stays* there.
    static func progress(forDockMinY minY: CGFloat) -> CGFloat {
        guard minY.isFinite, collapseDistance > 0 else { return 0 }
        return min(max(1 - (minY / collapseDistance), 0), 1)
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

// MARK: - Section indicator anchors

/// Publishes the resolved bounds of every section control so a *single*
/// indicator can travel between them.
///
/// The previous rail drew one underline per item and cross-faded opacity, so the
/// selection never moved: it disappeared in one place and reappeared in another,
/// at a different width. One shared indexed anchor lets the indicator animate
/// its position *and* its width continuously, and it resolves correctly in RTL
/// because anchors carry already-resolved frames.
@available(iOS 15.0, *)
struct PPMarketplaceHeaderV2SectionAnchorKey: PreferenceKey {
    static var defaultValue: [Int: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [Int: Anchor<CGRect>],
        nextValue: () -> [Int: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { _, next in next }
    }
}

// MARK: - Dock

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
    private var expandedCommandHeight = PPMarketplaceHeaderV2Geometry.expandedCommandHeight

    var body: some View {
        Group {
            switch presentation {
            case .expanded:
                expandedDock
                    .opacity(expandedVisibility)
                    .scaleEffect(
                        interactionMotionIsDisabled
                            ? 1
                            : 1 - (0.018 * collapseProgress),
                        anchor: .top
                    )

            case .compact:
                compactDock
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

    // MARK: Expanded state

    private var expandedDock: some View {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? PPSpace.base : PPSpace.md) {
            identityRow
            commandCapsule(isCompact: false)
            sectionRail(isCompact: false)
        }
        .frame(maxWidth: resolvedMaximumWidth)
        .padding(.top, PPSpace.sm)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(store.contextAccessibilityLabel)
    }

    /// Title and subtitle are centred against **equal-width side slots**.
    ///
    /// The previous row leaned the whole text block against the leading edge of
    /// a three-item `HStack`, so the title sat visibly off-centre (measured ~38pt
    /// in the shipped build). Reserving the same width on both sides centres the
    /// title mathematically, whatever the control count.
    private var identityRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: PPSpace.sm) {
                backControl(size: resolvedExpandedControlSize, compact: false)
                    .frame(width: identitySlotWidth, alignment: .leading)

                contextControl(compact: false, alignment: .center)

                cartControl(size: resolvedExpandedControlSize, compact: false)
                    .frame(width: identitySlotWidth, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: PPSpace.md) {
                HStack(spacing: PPSpace.sm) {
                    backControl(size: resolvedExpandedControlSize, compact: false)
                    Spacer(minLength: 0)
                    cartControl(size: resolvedExpandedControlSize, compact: false)
                }
                contextControl(compact: false, alignment: .leading)
            }
        }
        .padding(.horizontal, horizontalInset)
    }

    // MARK: Compact state

    private var compactDock: some View {
        VStack(spacing: PPSpace.sm) {
            HStack(spacing: PPSpace.sm) {
                backControl(
                    size: PPMarketplaceHeaderV2Geometry.compactControlSize,
                    compact: true
                )

                commandCapsule(isCompact: true)

                cartControl(
                    size: PPMarketplaceHeaderV2Geometry.compactControlSize,
                    compact: true
                )
            }
            .padding(.horizontal, horizontalInset)

            sectionRail(isCompact: true)
        }
        .frame(maxWidth: resolvedMaximumWidth)
        .padding(.top, max(0, topSafeAreaInset) + PPSpace.xs)
        .padding(.bottom, PPSpace.md)
        .frame(maxWidth: .infinity)
        .ppMarketplaceHeaderV2Glass(
            in: PPMarketplaceHeaderV2DockShape(
                cornerRadius: PPCorner.hero
            ),
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
        // Content dissolves into the dock instead of butting against it. The
        // shipped build left ~0pt between the dock edge and the first product
        // card, so the two layers read as one collided surface.
        .overlay(alignment: .bottom) {
            scrollEdgeVeil
                .offset(y: PPMarketplaceHeaderV2Geometry.scrollEdgeVeil)
        }
        .ignoresSafeArea(.container, edges: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(store.contextAccessibilityLabel)
    }

    private var scrollEdgeVeil: some View {
        LinearGradient(
            colors: [
                Color.ppSurface.opacity(contrast == .increased ? 0 : 0.92),
                Color.ppSurface.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: PPMarketplaceHeaderV2Geometry.scrollEdgeVeil)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Command capsule

    /// The upgraded descendant of the old dock's species/breed container.
    ///
    /// The old dock stacked a species menu over a breed menu inside their own
    /// bordered box, next to a separate search button and a separate filter
    /// button — three containers competing for the same row. This is one
    /// continuous capsule that owns search, species, breed and filters together,
    /// and it is present in **both** dock states, so no capability appears or
    /// disappears with scroll position.
    private func commandCapsule(isCompact: Bool) -> some View {
        let height = resolvedCommandHeight(isCompact: isCompact)

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                searchControl(isCompact: isCompact, showsPlaceholder: !isCompact)
                capsuleDivider(height: height * 0.52)
                taxonomyChip(kind: .species, isCompact: isCompact)
                taxonomyChip(kind: .breed, isCompact: isCompact)
                capsuleDivider(height: height * 0.52)
                filterControl(isCompact: isCompact, height: height)
            }

            // Narrow / large-text fallback keeps the old dock's stacked
            // reading order inside the same single capsule.
            VStack(spacing: PPSpace.xs) {
                HStack(spacing: 0) {
                    searchControl(isCompact: isCompact, showsPlaceholder: true)
                    capsuleDivider(height: height * 0.52)
                    filterControl(isCompact: isCompact, height: height)
                }
                Divider()
                    .overlay(Color.ppSeparator.opacity(0.4))
                HStack(spacing: 0) {
                    taxonomyChip(kind: .species, isCompact: isCompact)
                    taxonomyChip(kind: .breed, isCompact: isCompact)
                }
            }
            .padding(.vertical, PPSpace.xs)
        }
        .frame(minHeight: height)
        .ppMarketplaceHeaderV2Glass(
            in: Capsule(style: .continuous),
            tint: Color.ppPrimary.opacity(colorScheme == .dark ? 0.055 : 0.025),
            fallback: isCompact ? Color.ppSurfaceRaised : Color.ppSurface,
            stroke: Color.ppSurfaceBorder.opacity(contrast == .increased ? 1 : 0.68),
            lineWidth: contrast == .increased ? 2 : 1,
            isInteractive: true
        )
        .shadow(
            color: contrast == .increased || isCompact
                ? .clear
                : Color.black.opacity(0.045),
            radius: 18,
            y: 8
        )
        .accessibilityIdentifier(
            isCompact
                ? "pp.marketplace.header.v2.command.compact"
                : "pp.marketplace.header.v2.command.expanded"
        )
    }

    private func capsuleDivider(height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.ppSeparator.opacity(contrast == .increased ? 0.82 : 0.42))
            .frame(width: contrast == .increased ? 2 : 1, height: height)
            .accessibilityHidden(true)
    }

    private func searchControl(
        isCompact: Bool,
        showsPlaceholder: Bool
    ) -> some View {
        Button(action: store.openSearch) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "magnifyingglass")
                    .font(
                        .system(
                            size: isCompact ? 17 : 21,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(Color.ppPrimary)
                    .accessibilityHidden(true)

                if showsPlaceholder {
                    Text(contextualSearchTitle)
                        .font(isCompact ? HomeFont.subheadline() : HomeFont.callout())
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.leading, isCompact ? PPSpace.md : PPSpace.base)
            .padding(.trailing, showsPlaceholder ? PPSpace.sm : PPSpace.md)
            .frame(
                maxWidth: showsPlaceholder ? .infinity : nil,
                minHeight: PPMarketplaceHeaderV2Geometry.minimumTouchTarget,
                alignment: .leading
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(contextualSearchTitle)
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_search_hint")
        )
        .accessibilityIdentifier(
            isCompact
                ? "pp.marketplace.header.v2.search.compact"
                : "pp.marketplace.header.v2.search.expanded"
        )
    }

    // MARK: Species / breed

    private enum PPMarketplaceHeaderV2TaxonomyKind {
        case species
        case breed
    }

    /// Species and breed as live inline chips.
    ///
    /// They were previously rendered as dead text inside the subtitle
    /// ("Dogs market · All Breed · 25 results"), so the two most-used
    /// refinements in the product looked like decoration. The information stays
    /// on screen — it is now the control.
    @ViewBuilder
    private func taxonomyChip(
        kind: PPMarketplaceHeaderV2TaxonomyKind,
        isCompact: Bool
    ) -> some View {
        let isActive = kind == .species
            ? store.currentMainKindID != 0
            : store.currentSubKindID != 0
        let value = kind == .species ? resolvedSpeciesTitle : resolvedBreedTitle
        let glyph = kind == .species ? "pawprint.fill" : "tag.fill"
        let hintKey = kind == .species
            ? "marketplace_category_main_kind_hint"
            : "marketplace_category_subkind_hint"
        let identifier = kind == .species
            ? "pp.marketplace.header.v2.species"
            : "pp.marketplace.header.v2.breed"

        Menu {
            switch kind {
            case .species:
                ForEach(store.mainKindChoices) { choice in
                    Button {
                        selectTaxonomy { store.applyMainKindShortcut(choice) }
                    } label: {
                        if choice.id == store.currentMainKindID {
                            Label(choice.title, systemImage: "checkmark")
                        } else {
                            Text(choice.title)
                        }
                    }
                }
            case .breed:
                ForEach(store.subKindChoices) { choice in
                    Button {
                        selectTaxonomy { store.applySubKindShortcut(choice) }
                    } label: {
                        if choice.id == store.currentSubKindID {
                            Label(choice.title, systemImage: "checkmark")
                        } else {
                            Text(choice.title)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: PPSpace.xs) {
                if !isCompact {
                    Image(systemName: glyph)
                        .font(.system(size: 11, weight: .semibold))
                        .accessibilityHidden(true)
                }

                Text(value)
                    .font(HomeFont.bold(isCompact ? 12 : 13))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .black))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(isActive ? Color.ppPrimary : Color.ppTextSecondary)
            .padding(.horizontal, isCompact ? PPSpace.sm : PPSpace.md)
            .frame(
                minHeight: PPMarketplaceHeaderV2Geometry.minimumTouchTarget - 12
            )
            .background {
                Capsule(style: .continuous)
                    .fill(
                        Color.ppPrimary.opacity(
                            isActive ? (colorScheme == .dark ? 0.20 : 0.10) : 0
                        )
                    )
            }
            .overlay {
                if isActive && contrast == .increased {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.ppPrimary, lineWidth: 1.5)
                }
            }
            .padding(.horizontal, PPSpace.xxs)
            .frame(
                minHeight: PPMarketplaceHeaderV2Geometry.minimumTouchTarget
            )
            .contentShape(Rectangle())
        }
        .menuOrder(.fixed)
        .disabled(store.isReplacingContext)
        .layoutPriority(-1)
        .accessibilityLabel(taxonomyAccessibilityLabel(kind: kind, value: value))
        .accessibilityHint(PPMarketplaceText.localized(hintKey))
        .accessibilityIdentifier(identifier)
    }

    private func taxonomyAccessibilityLabel(
        kind: PPMarketplaceHeaderV2TaxonomyKind,
        value: String
    ) -> String {
        switch kind {
        case .species:
            return PPMarketplaceText.formatted(
                "marketplace_category_main_kind_format",
                value
            )
        case .breed:
            return PPMarketplaceText.formatted(
                "marketplace_category_subkind_format",
                value
            )
        }
    }

    private var resolvedSpeciesTitle: String {
        let title = store.currentMainKindTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return title.isEmpty
            ? PPMarketplaceText.localized("All")
            : title
    }

    private var resolvedBreedTitle: String {
        let title = store.currentSubKindTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return title.isEmpty
            ? PPMarketplaceText.localized("data_nav_all_breed")
            : title
    }

    private func selectTaxonomy(_ apply: @escaping () -> Void) {
        if interactionMotionIsDisabled {
            apply()
        } else {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                apply()
            }
        }
    }

    // MARK: Shared controls

    private func contextControl(
        compact: Bool,
        alignment: HorizontalAlignment
    ) -> some View {
        let textAlignment: TextAlignment = alignment == .center ? .center : .leading
        let frameAlignment: Alignment = alignment == .center ? .center : .leading

        return Button(action: store.beginCategoryEditing) {
            VStack(alignment: alignment, spacing: PPSpace.xxs) {
                Text(store.navigationContext.title)
                    .font(compact ? HomeFont.headline() : HomeFont.title1())
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(compact ? 1 : 2)
                    .minimumScaleFactor(compact ? 0.82 : 0.9)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)

                if !compact, !contextSubtitle.isEmpty {
                    Text(contextSubtitle)
                        .font(HomeFont.callout())
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: PPMarketplaceHeaderV2Geometry.minimumTouchTarget,
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

    /// Tap opens the full filter sheet; long-press exposes quick refinements and
    /// layout.
    ///
    /// The refinement menu previously lived in a separate `ellipsis` button that
    /// existed **only** in the compact state, so scrolling up silently removed
    /// browse capabilities. Folding it into the filter control's secondary
    /// action makes the same capability reachable from either state through one
    /// control.
    @ViewBuilder
    private func filterControl(isCompact: Bool, height: CGFloat) -> some View {
        let size = max(PPMarketplaceHeaderV2Geometry.minimumTouchTarget, height)

        Menu {
            refinementMenuContent
        } label: {
            filterLabel(isCompact: isCompact, size: size)
        } primaryAction: {
            store.beginFilterEditing()
        }
        .buttonStyle(.plain)
        .disabled(store.isReplacingContext)
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
            isCompact
                ? "pp.marketplace.header.v2.filter.compact"
                : "pp.marketplace.header.v2.filter.expanded"
        )
    }

    private func filterLabel(isCompact: Bool, size: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: isCompact ? 17 : 20, weight: .semibold))
                .foregroundStyle(Color.ppPrimary)
                .frame(width: size, height: size)

            if store.activeFilterCount > 0 {
                Text(String(min(store.activeFilterCount, 99)))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        PPMarketplaceAccentPalette(accent: .ppPrimary).onAccent
                    )
                    .frame(minWidth: 17, minHeight: 17)
                    .background(Color.ppPrimary, in: Capsule(style: .continuous))
                    .offset(x: -2, y: 4)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Circle())
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

    // MARK: Section rail

    /// Edge-to-edge rail with its own content inset.
    ///
    /// The shipped rail inherited the dock's 20pt horizontal inset as its
    /// *viewport*, so an overflowing item was sliced 20pt away from the screen
    /// edge and read as a rendering bug — clearly visible on the trailing
    /// `خدمات` item in Arabic. Letting the rail span the full width and carry
    /// the margin as content inset makes overflow read as scrollable, which is
    /// what it is.
    private func sectionRail(isCompact: Bool) -> some View {
        let indicatorHeight = PPMarketplaceHeaderV2Geometry
            .indicatorHeight(isCompact: isCompact)

        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: isCompact ? PPSpace.xxs : PPSpace.xs) {
                    ForEach(store.sections) { descriptor in
                        sectionControl(descriptor, isCompact: isCompact)
                            .id(descriptor.rawValue)
                    }
                }
                .padding(.horizontal, horizontalInset)
                .overlayPreferenceValue(
                    PPMarketplaceHeaderV2SectionAnchorKey.self
                ) { anchors in
                    sectionIndicator(
                        anchors: anchors,
                        indicatorHeight: indicatorHeight
                    )
                }
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
        .frame(height: PPMarketplaceHeaderV2Geometry.categoryHeight(isCompact: isCompact))
        .padding(.horizontal, -horizontalInset)
        .overlay(alignment: .bottom) {
            sectionRailBaseline
        }
        .accessibilityElement(children: .contain)
    }

    /// One indicator for the whole rail, positioned from the selected item's
    /// resolved bounds so it travels and resizes in a single spring.
    private func sectionIndicator(
        anchors: [Int: Anchor<CGRect>],
        indicatorHeight: CGFloat
    ) -> some View {
        GeometryReader { proxy in
            if let anchor = anchors[store.currentSection.rawValue] {
                let bounds = proxy[anchor]
                Capsule(style: .continuous)
                    .fill(Color.ppPrimary)
                    .frame(
                        width: max(bounds.width, 0),
                        height: indicatorHeight
                    )
                    .position(
                        x: bounds.midX,
                        y: proxy.size.height - (indicatorHeight / 2)
                    )
                    .animation(
                        interactionMotionIsDisabled
                            ? nil
                            : .spring(response: 0.34, dampingFraction: 0.82),
                        value: store.currentSection.rawValue
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var sectionRailBaseline: some View {
        Rectangle()
            .fill(
                Color.ppSeparator.opacity(contrast == .increased ? 0.86 : 0.34)
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
        let indicatorHeight = PPMarketplaceHeaderV2Geometry
            .indicatorHeight(isCompact: isCompact)

        return Button {
            selectSection(descriptor)
        } label: {
            HStack(spacing: PPSpace.xs) {
                Image(systemName: descriptor.iconName)
                    .font(
                        .system(
                            size: isCompact ? 14 : 16,
                            weight: selected ? .semibold : .regular
                        )
                    )
                    .accessibilityHidden(true)

                Text(title)
                    .font(isCompact ? HomeFont.bold(14) : HomeFont.headline())
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(selected ? Color.ppPrimary : Color.ppTextSecondary)
            .padding(
                .horizontal,
                PPMarketplaceHeaderV2Geometry.railItemInset(isCompact: isCompact)
            )
            .frame(
                minHeight: PPMarketplaceHeaderV2Geometry.minimumTouchTarget,
                alignment: .center
            )
            .padding(.bottom, indicatorHeight + PPSpace.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isReplacingContext)
        .anchorPreference(
            key: PPMarketplaceHeaderV2SectionAnchorKey.self,
            value: .bounds
        ) { [descriptor.rawValue: $0] }
        .accessibilityLabel(title)
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_section_select_hint")
        )
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier(
            "pp.marketplace.header.v2.section.\(descriptor.rawValue)"
        )
    }

    private func selectSection(_ descriptor: PPMarketplaceSectionDescriptor) {
        if interactionMotionIsDisabled {
            store.selectSection(descriptor)
        } else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                store.selectSection(descriptor)
            }
        }
    }

    // MARK: Presentation values

    private var contextualSearchTitle: String {
        PPMarketplaceText.formatted(
            "marketplace_header_search_format",
            store.navigationContext.title
        )
    }

    /// Species and breed are deliberately absent here: they are live chips in
    /// the command capsule, so repeating them as text would duplicate the
    /// control it sits above.
    private var contextSubtitle: String {
        var parts: [String] = []

        let mainKind = store.currentMainKindTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if mainKind.isEmpty, !store.navigationContext.subtitle.isEmpty {
            parts.append(store.navigationContext.subtitle)
        }

        parts.append(contextResultCount)

        return parts.reduce(into: [String]()) { unique, value in
            guard !value.isEmpty,
                  !unique.contains(where: {
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

    private var identitySlotWidth: CGFloat {
        resolvedExpandedControlSize
    }

    private var resolvedExpandedControlSize: CGFloat {
        max(
            PPMarketplaceHeaderV2Geometry.minimumTouchTarget,
            min(expandedControlSize, dynamicTypeSize.isAccessibilitySize ? 64 : 56)
        )
    }

    private func resolvedCommandHeight(isCompact: Bool) -> CGFloat {
        if isCompact {
            return PPMarketplaceHeaderV2Geometry.compactCommandHeight
        }
        return max(
            PPMarketplaceHeaderV2Geometry.minimumTouchTarget,
            min(expandedCommandHeight, dynamicTypeSize.isAccessibilitySize ? 82 : 64)
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
        if animated && !interactionMotionIsDisabled {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                update()
            }
        } else {
            update()
        }
    }
}

// MARK: - Dock shape

/// Full-bleed dock surface: square at the top so it reaches under the status
/// bar, rounded at the bottom where it meets the content.
@available(iOS 15.0, *)
private struct PPMarketplaceHeaderV2DockShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(
            UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: [.bottomLeft, .bottomRight],
                cornerRadii: CGSize(
                    width: cornerRadius,
                    height: cornerRadius
                )
            ).cgPath
        )
    }
}

// MARK: - Icon control

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

// MARK: - Material

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
