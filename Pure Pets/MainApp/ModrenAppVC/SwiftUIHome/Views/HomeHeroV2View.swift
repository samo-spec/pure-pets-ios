import SwiftUI
import UIKit

// MARK: - Home Hero V2
//
// V1 remains preserved behind `PPHomeHeroFlags.UseHeroV2`. V2 re-composes the
// same page and action contract as a compact editorial card: copy owns the
// semantic leading side while the selected category portrait and the preserved
// `PPHomeHeroLivingBlobView` form one optical object on the trailing side.
//
// The plate is deliberately contained rather than full-bleed. Its living edge,
// feeding bubbles, portrait, halo and card tint now share one visual centre, so
// the animal feels mounted in the plate instead of pasted over a giant circle.

/// Mirrors `homeHeroShowsSelectedMainKindArtwork` in V1: the marketplace hero
/// presents the selected main-kind portrait instead of the generic shop scene.
private let homeHeroV2ShowsSelectedMainKindArtwork = true

private enum HomeHeroV2Metrics {
    /// The reference hero is edge-to-edge; the living plate supplies the visual
    /// boundary instead of an additional horizontal card inset.
    static let outerInset: CGFloat = 0
    static let referenceStageHeight: CGFloat = 246
    static let stageHeight: CGFloat = 216
    static let dockHeight: CGFloat = 78
    static let height: CGFloat = 294
    static let maximumHeight: CGFloat = 326
    static let accessibilityPlateHeight: CGFloat = 184

    static let cardRadius: CGFloat = 0
    static let cardContentInset: CGFloat = PPSpace.base
    static let copyLeadingInset: CGFloat = PPSpace.xl
    /// Top anchor inset for the leading strings group, anchoring the eyebrow
    /// safely and cleanly below the hero card's top rounded border.
    static let copyTopInset: CGFloat = 18
    /// Vertical spacing rhythm within the leading strings group.
    static let copyEyebrowToTitleSpacing: CGFloat = 6
    static let copyTitleToSubtitleSpacing: CGFloat = 4
    static let copySubtitleToPrimarySpacing: CGFloat = 10
    static let copyPrimaryToSecondarySpacing: CGFloat = 6
    static let contentGap: CGFloat = PPSpace.sm
    static let copyWidthRatio: CGFloat = 0.45
    static let minimumCopyWidth: CGFloat = 150

    /// `PPHomeHeroLivingBlobShape` draws at 0.94 of its frame. The reference
    /// composition intentionally lets the plate travel beyond the physical
    /// leading/trailing edge while keeping the artwork fully inside the arc.
    static let blobInkRatio: CGFloat = 0.94
    static let plateInk: CGFloat = 226
    /// The living plate reads as a lens rather than a ball: its height is 15%
    /// shorter than its width. Only the membrane, halo, and their shared centre
    /// change — `plateInk` and `artworkSide` stay exactly as they were, so the
    /// category portrait keeps its established size and position.
    static let plateHeightRatio: CGFloat = 0.85
    static let artworkSide: CGFloat = 180
    static let artworkVerticalShift: CGFloat = 3
    /// Hero-specific category artwork grows downward while its established top
    /// edge, plate frame, and living-blob geometry remain unchanged.
    static let heroImageScale: CGFloat = 1.18
    /// Visual plate touches and sticks to the screen edge.
    static let plateHorizontalOverflow: CGFloat = 24
    static let maximumPlateOverflowRatio: CGFloat = 0.10
    static let skeletonPlateInk: CGFloat = 156
    /// Keeps the V2 liquid form branded without letting the primary hue compete
    /// with the category portrait or the full-strength primary CTA.
    static let blobAccentOpacity: Double = 0.72
    /// Vertical offset to position the living plate and category artwork stage
    /// as one unified group comfortably down inside the hero card.
    static let plateArtworkGroupVerticalOffset: CGFloat = 18

    /// Quiet edge affordance for horizontal paging.
    static let gripWidth: CGFloat = 14
    static let gripHeight: CGFloat = 42
    static let gripEdgeInset: CGFloat = PPSpace.sm
    static let gripBarWidth: CGFloat = 1.5
    static let gripBarHeight: CGFloat = 11
    static let gripBarSpacing: CGFloat = 2

    static let primaryHeight: CGFloat = 44
    static let primaryRadius: CGFloat = 14
    static let primaryHorizontalPadding: CGFloat = PPSpace.base
    static let primaryContentSpacing: CGFloat = PPSpace.sm

    static let secondaryHorizontalPadding: CGFloat = PPSpace.sm
    static let secondaryVerticalPadding: CGFloat = PPSpace.sm

    static let eyebrowSize: CGFloat = 10.5
    static let titleSize: CGFloat = 23
    static let primaryLabelSize: CGFloat = 14
    static let secondaryLabelSize: CGFloat = 12.5
}

@available(iOS 15.0, *)
private enum HomeHeroSpeciesDockMetrics {
    static func height(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        if dynamicTypeSize >= .accessibility3 { return 144 }
        if dynamicTypeSize.isAccessibilitySize { return 124 }
        if dynamicTypeSize >= .xxLarge { return 96 }
        return HomeHeroV2Metrics.dockHeight
    }

    static let seamHeight: CGFloat = 5
    static let headerHorizontalInset: CGFloat = PPSpace.base
    static let railHorizontalInset: CGFloat = PPSpace.sm
    static let itemSpacing: CGFloat = 8
    static let identitySeedFrame: CGFloat = 20
    static let minimumItemWidth: CGFloat = 58
    static let minimumItemHeight: CGFloat = 40
}

@available(iOS 15.0, *)
private struct HeroCopyHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

@available(iOS 15.0, *)
struct HomeHeroV2View: View {
    let pages: [HomeHeroPage]
    let selectedIndex: Int
    var categories: [HomeCategoryModel] = []
    var selectedCategoryID: Int? = nil
    let onSelect: (Int) -> Void
    let onPrimaryAction: () -> Void
    let onSecondaryAction: () -> Void
    let onInteractionChanged: (Bool) -> Void
    var onSelectCategory: ((HomeCategoryModel?) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @ScaledMetric(relativeTo: .title) private var scaledHeight: CGFloat =
        HomeHeroV2Metrics.height

    @State private var measuredCopyHeights: [String: CGFloat] = [:]

    private var selectedPage: HomeHeroPage? {
        guard pages.indices.contains(selectedIndex) else { return nil }
        return pages[selectedIndex]
    }

    private var resolvedHeight: CGFloat {
        min(scaledHeight, HomeHeroV2Metrics.maximumHeight)
    }

    private func shouldEndHeightAfterSubtitle(for page: HomeHeroPage) -> Bool {
        if page.endsHeightAfterSubtitle { return true }
        if page.isPromotionSpark {
            if let index = pages.firstIndex(where: { $0.id == page.id }) {
                return index < 4
            }
            return true
        }
        return false
    }

    private func stageHeight(for page: HomeHeroPage) -> CGFloat {
        if shouldEndHeightAfterSubtitle(for: page) {
            let measured = measuredCopyHeights[page.id] ?? 88
            return HomeHeroV2Metrics.copyTopInset + measured + HomeHeroPage.subtitleBottomClearance
        }
        return HomeHeroV2Metrics.stageHeight
    }

    /// `HomeView` publishes `HomeStore.state.isRightToLeft` into the SwiftUI
    /// environment. Consume that single live owner here; querying `Language`
    /// again would create a second direction source during a locale transition.
    private var isRightToLeft: Bool {
        layoutDirection == .rightToLeft
    }

    private var allowsPaging: Bool {
        pages.count > 1
    }

    var body: some View {
        Group {
            if let page = selectedPage {
                hero(page)
            } else {
                HomeHeroV2Skeleton(height: resolvedHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, HomeHeroV2Metrics.outerInset)
        .accessibilityElement(children: .contain)
    }

    // MARK: Composition

    private func hero(_ page: HomeHeroPage) -> some View {
        // The hero now carries the live category identity: marketplace pages
        // publish the selected MainKind color in `accentHex`, so V2's eyebrow,
        // CTA, plate halo, living membrane, and secondary action all shift with
        // the species the rail is scoping. The value passes through a contrast
        // ladder first, so a pale MainKind color can never produce an
        // illegible eyebrow or a washed-out CTA.
        let accent = heroAccent(for: page)

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                stackedHero(page, accent: accent)
            } else {
                unifiedHero(page, accent: accent)
            }
        }
        .background {
            cardSurface(accent: accent)
        }
        .clipShape(cardShape)
        .overlay {
            cardShape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            accent.opacity(
                                contrast == .increased
                                    ? 0.50
                                    : (colorScheme == .dark ? 0.22 : 0.12)
                            ),
                            accent.opacity(
                                contrast == .increased
                                    ? 0.25
                                    : (colorScheme == .dark ? 0.10 : 0.05)
                            ),
                            Color.clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    lineWidth: contrast == .increased ? 1.5 : 0.8
                )
        }
        .shadow(
            color: Color.black.opacity(
                contrast == .increased
                    ? 0
                    : (colorScheme == .dark ? 0.26 : 0.07)
            ),
            radius: contrast == .increased ? 0 : 16,
            y: contrast == .increased ? 0 : 7
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.28),
            value: page.accentHex
        )
        .id(page.id)
        .transition(pageTransition)
        .modifier(
            HomeHeroV2PageMotionModifier(
                pageID: AnyHashable(page.id),
                reduceMotion: reduceMotion
            )
        )
        .contentShape(Rectangle())
        .modifier(
            HomeHeroV2PagingGestureModifier(
                isEnabled: allowsPaging,
                selectedIndex: selectedIndex,
                pageCount: pages.count,
                layoutDirection: layoutDirection,
                onSelect: onSelect,
                onInteractionChanged: onInteractionChanged
            )
        )
        .accessibilityLabel(
            page.accessibilityLabel ?? [page.eyebrow, page.title, page.subtitle]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        )
        .modifier(
            HomeHeroV2PagingAccessibilityModifier(
                isEnabled: allowsPaging,
                selectedIndex: selectedIndex,
                pageCount: pages.count,
                onSelect: onSelect
            )
        )
        .onTapGesture {
            if shouldEndHeightAfterSubtitle(for: page) {
                onPrimaryAction()
            }
        }
        .onPreferenceChange(HeroCopyHeightPreferenceKey.self) { height in
            if height > 0 {
                let current = measuredCopyHeights[page.id] ?? 0
                if abs(current - height) > 0.5 {
                    measuredCopyHeights[page.id] = height
                }
            }
        }
    }

    @ViewBuilder
    private func unifiedHero(
        _ page: HomeHeroPage,
        accent: Color
    ) -> some View {
        VStack(spacing: 0) {
            splitHero(page, accent: accent)
                .frame(height: stageHeight(for: page))
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.22),
                    value: stageHeight(for: page)
                )

            if !categories.isEmpty, let onSelectCategory {
                // Categories Section Strip
                HomeHeroSpeciesDock(
                    categories: categories,
                    selectedCategoryID: selectedCategoryID,
                    accent: accent,
                    isRightToLeft: isRightToLeft,
                    onSelect: onSelectCategory
                )
                .frame(
                    height: HomeHeroSpeciesDockMetrics.height(
                        for: dynamicTypeSize
                    )
                )
            }
        }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: HomeHeroV2Metrics.cardRadius,
            style: .continuous
        )
    }

    private func cardSurface(accent: Color) -> some View {
        ZStack {
            Color.homeSurface

            if contrast != .increased && !reduceTransparency {
                RadialGradient(
                    colors: [
                        accent.opacity(colorScheme == .dark ? 0.16 : 0.08),
                        Color.clear
                    ],
                    center: isRightToLeft ? .topLeading : .topTrailing,
                    startRadius: 0,
                    endRadius: 360
                )
            }
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.5),
                    .init(color: .black, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    /// Compact semantic split: copy owns the leading lane; the living plate and
    /// category portrait own the trailing lane. Positions are resolved from the
    /// canonical app language as well as SwiftUI's environment so Arabic cannot
    /// accidentally retain the old left-copy/right-plate arrangement.
    private func splitHero(
        _ page: HomeHeroPage,
        accent: Color
    ) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let isCompact = shouldEndHeightAfterSubtitle(for: page)
            let plateInk = isCompact
                ? min(max(height - 12, 60), 120)
                : min(
                    HomeHeroV2Metrics.plateInk,
                    HomeHeroV2Metrics.referenceStageHeight - (HomeHeroV2Metrics.cardContentInset * 2)
                )
            let plateFrame = plateInk / HomeHeroV2Metrics.blobInkRatio
            let plateOverflow = isCompact
                ? 10
                : min(
                    HomeHeroV2Metrics.plateHorizontalOverflow,
                    plateFrame * HomeHeroV2Metrics.maximumPlateOverflowRatio
                )
            let visiblePlateWidth = plateFrame - plateOverflow
            let availableCopyWidth = width
                - visiblePlateWidth
                - HomeHeroV2Metrics.copyLeadingInset
                - HomeHeroV2Metrics.contentGap
            let copyWidth = max(
                HomeHeroV2Metrics.minimumCopyWidth,
                min(width * HomeHeroV2Metrics.copyWidthRatio, availableCopyWidth)
            )

            // SwiftUI mirrors explicit child placement when the environment is
            // RTL. Express each center once in semantic leading/trailing terms;
            // branching on `isRightToLeft` here would mirror the composition a
            // second time and leave Arabic visually identical to English.
            let copyCenterX = HomeHeroV2Metrics.copyLeadingInset
                + (copyWidth / 2)
            let plateInsetCenter = max((plateFrame / 2) - plateOverflow, 0)
            let plateCenterX = width - plateInsetCenter
            let gripCenterX = width
                - HomeHeroV2Metrics.gripEdgeInset
                - (HomeHeroV2Metrics.gripWidth / 2)

            let artworkSide = isCompact
                ? min(plateInk - 6, 96)
                : min(HomeHeroV2Metrics.artworkSide, plateInk - PPSpace.base)
            let blobCenterX = isCompact ? (plateCenterX + 20) : (plateCenterX + 80)
            let contentCenterY = isCompact
                ? (height / 2)
                : (height - (HomeHeroV2Metrics.referenceStageHeight / 2))
            let plateArtworkCenterY = isCompact
                ? (height / 2)
                : (contentCenterY + HomeHeroV2Metrics.plateArtworkGroupVerticalOffset)
            ZStack(alignment: .topLeading) {
                // Living blob plate shifted trailing by +80
                plateStage(
                    page,
                    accent: accent,
                    plateFrame: plateFrame,
                    plateInk: plateInk,
                    artworkSide: artworkSide
                )
                .position(x: blobCenterX, y: plateArtworkCenterY)
                .zIndex(0)

                // Category image in front of the living blob on hero card (preserved position)
                artworkStage(
                    asset: heroArtworkAsset(for: page),
                    accent: accent,
                    plateFrame: plateFrame,
                    artworkSide: artworkSide
                )
                .position(x: plateCenterX, y: plateArtworkCenterY)
                .zIndex(1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                heroCopy(page, accent: accent)
                    .frame(width: copyWidth, alignment: .leading)
                    .padding(.leading, HomeHeroV2Metrics.copyLeadingInset)
                    .padding(.top, HomeHeroV2Metrics.copyTopInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .zIndex(2)

                if allowsPaging {
                    HomeHeroV2SwipeGrip(
                        accent: accent,
                        reduceTransparency: reduceTransparency
                            || contrast == .increased
                    )
                    .position(x: gripCenterX, y: contentCenterY)
                    .zIndex(3)
                }
            }
            .frame(width: width, height: height, alignment: .topLeading)
        }
    }

    /// Accessibility sizes retain the card language but move the plate beneath
    /// the copy so neither text nor artwork is compressed.
    private func stackedHero(
        _ page: HomeHeroPage,
        accent: Color
    ) -> some View {
        let plateInk = HomeHeroV2Metrics.accessibilityPlateHeight
        let plateFrame = plateInk / HomeHeroV2Metrics.blobInkRatio
        let artworkSide = plateInk - PPSpace.xl

        return VStack(alignment: .leading, spacing: PPSpace.base) {
            heroCopy(page, accent: accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(
                    .leading,
                    HomeHeroV2Metrics.copyLeadingInset
                        - HomeHeroV2Metrics.cardContentInset
                )

            ZStack {
                plateStage(
                    page,
                    accent: accent,
                    plateFrame: plateFrame,
                    plateInk: plateInk,
                    artworkSide: artworkSide
                )
                artworkStage(
                    asset: heroArtworkAsset(for: page),
                    accent: accent,
                    plateFrame: plateFrame,
                    artworkSide: artworkSide
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            if !categories.isEmpty, let onSelectCategory {
                HomeHeroSpeciesDock(
                    categories: categories,
                    selectedCategoryID: selectedCategoryID,
                    accent: accent,
                    isRightToLeft: isRightToLeft,
                    onSelect: onSelectCategory
                )
                .frame(
                    height: HomeHeroSpeciesDockMetrics.height(
                        for: dynamicTypeSize
                    )
                )
            }
        }
        .padding(HomeHeroV2Metrics.cardContentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Plate bubble + artwork

    /// The preserved living plate is now one contained object. The tint halo,
    /// animated blob and portrait share a centre; the portrait is deliberately
    /// smaller than the ink boundary so ears, feathers and fur never read as a
    /// separate oversized crop.
    private func plateStage(
        _ page: HomeHeroPage,
        accent: Color,
        plateFrame: CGFloat,
        plateInk: CGFloat,
        artworkSide: CGFloat
    ) -> some View {
        let blobAccent = accent.opacity(HomeHeroV2Metrics.blobAccentOpacity)
        let plateHeight = plateFrame * HomeHeroV2Metrics.plateHeightRatio

        return ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(colorScheme == .dark ? 0.14 : 0.07),
                            accent.opacity(0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: plateFrame * 0.54
                    )
                )
                .frame(
                    width: plateFrame + PPSpace.lg,
                    height: plateHeight + PPSpace.lg
                )

            PPHomeHeroLivingBlobView(
                fillGradient: plateGradient(accent: accent),
                accent: blobAccent,
                isDark: colorScheme == .dark,
                contentOverlay: nil
            )
            .frame(width: plateFrame, height: plateHeight)
            .shadow(
                color: accent.opacity(
                    contrast == .increased
                        ? 0
                        : (colorScheme == .dark ? 0.18 : 0.08)
                ),
                radius: 16,
                y: 8
            )
        }
        .frame(width: plateFrame, height: plateFrame)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Keeps the existing artwork top edge fixed. Only a genuine
    /// `HeroImageUrl` scales to 120%, so the added twenty percent resolves below
    /// that anchor; category fallbacks retain their established size.
    private func artworkStage(
        asset: HomeHeroV2ArtworkAsset,
        accent: Color,
        plateFrame: CGFloat,
        artworkSide: CGFloat
    ) -> some View {
        let plateHeight = plateFrame * HomeHeroV2Metrics.plateHeightRatio
        return ZStack(alignment: .trailing) {
            Ellipse()
                .fill(accent.opacity(colorScheme == .dark ? 0.13 : 0.05))
                .frame(width: artworkSide * 0.70, height: 12)
                .blur(radius: 6)
                .offset(y: artworkSide * 0.32)

            HomeHeroV2Artwork(
                asset: asset,
                accent: accent,
                side: artworkSide
            )
            .frame(width: artworkSide, height: artworkSide)
            .scaleEffect(
                asset.extendsFromTopAnchor
                    ? HomeHeroV2Metrics.heroImageScale
                    : 1,
                anchor: .trailing
            )
        }
        .frame(width: plateFrame, height: plateHeight, alignment: .trailing)
    }

    /// Reference plate is a low-saturation wash of the live category identity,
    /// so switching species visibly re-tints the membrane instead of leaving one
    /// fixed lilac plate behind every category. Built from shipped palette
    /// tokens plus the resolved accent so it stays correct in dark mode, and the
    /// increased-contrast/reduced-transparency path keeps its flat opaque
    /// surface rather than adding tint behind the portrait.
    private func plateGradient(accent: Color) -> LinearGradient {
        if contrast == .increased || reduceTransparency {
            return LinearGradient(
                colors: [Color.ppSecondarySurface, Color.ppSecondarySurface],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.ppSurfaceRaised,
                    accent.opacity(0.26),
                    accent.opacity(0.14),
                ],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                accent.opacity(0.26),
                accent.opacity(0.13),
                Color.ppSurfaceRaised,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: Identity accent

    private var isCategoryAccentEnabled: Bool {
        UserDefaults.standard.bool(
            forKey: "pp.marketplace.usesMainKindAccentColors"
        )
    }

    /// Resolves the page's category color into an accent that is legible in the
    /// roles V2 gives it: eyebrow text on the card surface, a filled CTA behind
    /// a white label, and the plate's tint. Falls back through the brand ladder
    /// rather than accepting a low-contrast category value.
    private func heroAccent(for page: HomeHeroPage) -> Color {
        guard isCategoryAccentEnabled else {
            return Color.ppPrimary
        }
        let candidate = UIColor(Color(hex: page.accentHex))
        return Color(
            uiColor: HomeHeroV2Palette.identityAccent(
                candidate,
                traits: resolvedTraits
            )
        )
    }

    /// SwiftUI environment is the single source for appearance here; the traits
    /// object exists only so the shipped UIColor tokens resolve against the
    /// same appearance the view is rendering in.
    private var resolvedTraits: UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(
                userInterfaceStyle: colorScheme == .dark ? .dark : .light
            ),
            UITraitCollection(
                accessibilityContrast: contrast == .increased ? .high : .normal
            ),
        ])
    }

    // MARK: Copy column — every string block is leading aligned

    private func heroCopy(
        _ page: HomeHeroPage,
        accent: Color
    ) -> some View {
        let isCompact = shouldEndHeightAfterSubtitle(for: page)
        return VStack(alignment: .leading, spacing: 0) {
            Text(page.eyebrow)
                .font(HomeFont.bold(HomeHeroV2Metrics.eyebrowSize))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(page.title)
                .font(HomeFont.bold(HomeHeroV2Metrics.titleSize))
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, HomeHeroV2Metrics.copyEyebrowToTitleSpacing)
                .accessibilityAddTraits(.isHeader)

            Text(page.subtitle)
                .font(HomeFont.subheadline())
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 6 : 2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, HomeHeroV2Metrics.copyTitleToSubtitleSpacing)

            if !isCompact {
                ZStack(alignment: .leading) {
                    primaryButton(page, accent: accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, HomeHeroV2Metrics.copySubtitleToPrimarySpacing)

                if let secondaryTitle = page.secondaryTitle,
                   !secondaryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty {
                    ZStack(alignment: .leading) {
                        secondaryButton(secondaryTitle, accent: accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, HomeHeroV2Metrics.copyPrimaryToSecondarySpacing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { copyProxy in
                Color.clear.preference(
                    key: HeroCopyHeightPreferenceKey.self,
                    value: copyProxy.size.height
                )
            }
        )
    }

    private func primaryButton(
        _ page: HomeHeroPage,
        accent: Color
    ) -> some View {
        Button(action: onPrimaryAction) {
            HStack(
                alignment: .center,
                spacing: HomeHeroV2Metrics.primaryContentSpacing
            ) {
                Text(page.primaryTitle)
                    .font(HomeFont.bold(HomeHeroV2Metrics.primaryLabelSize))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, HomeHeroV2Metrics.primaryHorizontalPadding)
            .frame(
                minHeight: HomeHeroV2Metrics.primaryHeight,
                alignment: .center
            )
            .background(
                LinearGradient(
                    colors: [accent, accent.opacity(0.88)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(
                    cornerRadius: HomeHeroV2Metrics.primaryRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: HomeHeroV2Metrics.primaryRadius,
                    style: .continuous
                )
                .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.8)
            }
            .shadow(
                color: accent.opacity(
                    contrast == .increased
                        ? 0
                        : (colorScheme == .dark ? 0.34 : 0.20)
                ),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(
            HomeHeroV2PressStyle(reduceMotion: reduceMotion)
        )
        .accessibilityHint(
            HomeModelAdapter.localized(
                "home_pulse_opens_destination_a11y",
                fallback: "Opens this destination"
            )
        )
    }

    /// Secondary copy shares the exact leading axis of the eyebrow, title and
    /// subtitle while its transparent frame preserves a 44pt touch target.
    private func secondaryButton(
        _ title: String,
        accent: Color
    ) -> some View {
        Button(action: onSecondaryAction) {
            Text(title)
                .font(HomeFont.bold(HomeHeroV2Metrics.secondaryLabelSize))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(
            HomeHeroV2PressStyle(reduceMotion: reduceMotion)
        )
    }

    // MARK: Motion

    private var pageTransition: AnyTransition {
        let incomingX: CGFloat = isRightToLeft ? -34 : 34
        let outgoingX: CGFloat = isRightToLeft ? 24 : -24
        return .asymmetric(
            insertion: .modifier(
                active: HomeHeroV2PagePhase(opacity: 0, offsetX: incomingX),
                identity: HomeHeroV2PagePhase.identity
            ),
            removal: .modifier(
                active: HomeHeroV2PagePhase(opacity: 0, offsetX: outgoingX),
                identity: HomeHeroV2PagePhase.identity
            )
        )
    }

    // MARK: Artwork resolution (unchanged contract from V1)

    private func heroArtworkAsset(
        for page: HomeHeroPage
    ) -> HomeHeroV2ArtworkAsset {
        switch page.kind {
        case .pet:
            if let imageURL = normalizedHeroImageURL(page.imageURL) {
                return HomeHeroV2ArtworkAsset(
                    remoteImageURL: imageURL
                )
            }
            return HomeHeroV2ArtworkAsset(
                animationName: "Profile.lottie",
                loadsFromFirebase: true
            )
        case .reminder:
            return HomeHeroV2ArtworkAsset(
                animationName: "Caretiming",
                loadsFromFirebase: true
            )
        case .promotion:
            let remoteURL = normalizedHeroImageURL(page.imageURL)
            return HomeHeroV2ArtworkAsset(
                animationName: remoteURL == nil ? "HomePromotionSpark" : nil,
                remoteImageURL: remoteURL
            )
        case .marketplace:
            let allKindsHeroImageURL = "https://firebasestorage.googleapis.com/v0/b/pure-pets-49199.firebasestorage.app/o/AppData%2FMainCategories%2FallkindsHeroImage.png?alt=media&token=91308ed0-acbb-465e-b53a-14432f5073e0"
            let selectedCategoryID: Int?
            if case let .openMarketplace(mainKind) = page.action,
               let mainKind {
                selectedCategoryID = HomeModelAdapter.mainKindID(mainKind)
            } else {
                selectedCategoryID = nil
            }
            let resolvedImageURL = normalizedHeroImageURL(page.imageURL)
                ?? (selectedCategoryID == nil ? allKindsHeroImageURL : nil)
            let hasSelectedCategory = selectedCategoryID != nil
            let hasPageArtwork = page.localImage != nil
                || resolvedImageURL != nil
            if homeHeroV2ShowsSelectedMainKindArtwork
                && (hasSelectedCategory || hasPageArtwork) {
                let categoryImage = page.localImage
                let fallbackImage = categoryImage
                return HomeHeroV2ArtworkAsset(
                    imageName: nil,
                    localImage: fallbackImage,
                    // Match `PPMainKindsCell`: show the resolved local artwork
                    // first, then let the shared image loader replace it with
                    // the category's current remote image when available.
                    remoteImageURL: resolvedImageURL,
                    usesCategoryArtworkTreatment: true,
                    extendsFromTopAnchor: page.usesHeroImageURL || selectedCategoryID == nil,
                    categoryID: selectedCategoryID
                )
            }
            // Preserve the Lottie file reference (`Shop2.json`) and temporarily hide it for "All Categories".
            return HomeHeroV2ArtworkAsset(
                animationName: "Shop2.json",
                isHidden: true
            )
        case .petOnboarding:
            return HomeHeroV2ArtworkAsset(
                animationName:
                    "LottieAnimations/Boy Giving Food To Rabbit New.json",
                loadsFromFirebase: true
            )
        case .pharmacy:
            return HomeHeroV2ArtworkAsset(animationName: "PetMedicine")
        }
    }

    private func normalizedHeroImageURL(_ imageURL: String?) -> String? {
        guard let imageURL else { return nil }
        let trimmed = imageURL.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Artwork

struct HomeHeroV2ArtworkAsset {
    var animationName: String?
    var imageName: String?
    var localImage: UIImage?
    var remoteImageURL: String?
    var usesCategoryArtworkTreatment: Bool
    var extendsFromTopAnchor: Bool
    var categoryID: Int?
    var loadsFromFirebase: Bool
    var isHidden: Bool

    /// True only for the marketplace All-categories scope: category artwork is
    /// resolved but no single `categoryID` is selected. That artwork is a
    /// composite illustration, so the hero presents it unmasked.
    var presentsAllCategoriesScope: Bool {
        usesCategoryArtworkTreatment && categoryID == nil
    }

    init(
        animationName: String? = nil,
        imageName: String? = nil,
        localImage: UIImage? = nil,
        remoteImageURL: String? = nil,
        usesCategoryArtworkTreatment: Bool = false,
        extendsFromTopAnchor: Bool = false,
        categoryID: Int? = nil,
        loadsFromFirebase: Bool = false,
        isHidden: Bool = false
    ) {
        self.animationName = animationName
        self.imageName = imageName
        self.localImage = localImage
        self.remoteImageURL = remoteImageURL
        self.usesCategoryArtworkTreatment = usesCategoryArtworkTreatment
        self.extendsFromTopAnchor = extendsFromTopAnchor
        self.categoryID = categoryID
        self.loadsFromFirebase = loadsFromFirebase
        self.isHidden = isHidden
    }
}

/// SwiftUI bridge for the exact category-artwork pipeline owned by
/// `PPMainKindsCell`. It reuses `PPImageLoaderManager`'s SDWebImage cache,
/// retry/scale-down policy, request cancellation, and no-transition behavior.
@available(iOS 15.0, *)
private struct HomeHeroV2MainKindArtwork: UIViewRepresentable {
    let urlString: String
    let placeholder: UIImage?

    final class Coordinator {
        weak var imageView: UIImageView?
        var boundURL: String?
        var generation: UInt = 0
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = true
        container.isUserInteractionEnabled = false

        let imageView = UIImageView()
        imageView.backgroundColor = .clear
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isAccessibilityElement = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        context.coordinator.imageView = imageView
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let imageView = context.coordinator.imageView else { return }
        container.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit

        let resolvedPlaceholder = placeholder?.withRenderingMode(.alwaysOriginal)
        guard context.coordinator.boundURL != urlString else {
            if imageView.image == nil {
                imageView.image = resolvedPlaceholder
            }
            return
        }

        context.coordinator.generation &+= 1
        let expectedGeneration = context.coordinator.generation
        context.coordinator.boundURL = urlString

        PPImageLoaderManager.shared().setImage(
            on: imageView,
            url: urlString,
            placeholder: resolvedPlaceholder,
            transitionStyle: .none
        ) { [weak imageView, weak coordinator = context.coordinator] image, _ in
            guard let imageView,
                  let coordinator,
                  coordinator.generation == expectedGeneration,
                  coordinator.boundURL == urlString,
                  let image else {
                return
            }
            imageView.image = image.withRenderingMode(.alwaysOriginal)
        }
    }

    static func dismantleUIView(
        _ container: UIView,
        coordinator: Coordinator
    ) {
        coordinator.generation &+= 1
        coordinator.boundURL = nil
        if let imageView = coordinator.imageView {
            PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
            imageView.image = nil
        }
        coordinator.imageView = nil
    }
}

@available(iOS 15.0, *)
private struct HomeHeroV2Artwork: View {
    let asset: HomeHeroV2ArtworkAsset
    let accent: Color
    let side: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.scenePhase) private var scenePhase
    @State private var presented = false

    var body: some View {
        content
            .frame(width: side, height: side)
            .scaleEffect(speciesScale)
            .offset(
                x: layoutDirection == .leftToRight ? -speciesOffset.width : speciesOffset.width,
                y: speciesOffset.height
            )
            .scaleEffect(
                x: layoutDirection == .leftToRight ? -1 : 1,
                y: 1
            )
            .scaleEffect(presented ? 1 : 0.96)
            .opacity(presented ? 1 : 0)
            .animation(
                reduceMotion
                    ? nil
                    : .interactiveSpring(
                        response: 0.52,
                        dampingFraction: 0.84,
                        blendDuration: 0.10
                    )
                    .delay(0.04),
                value: presented
            )
            .onAppear { presented = true }
            .onDisappear { presented = false }
            .accessibilityHidden(true)
    }

    private var speciesScale: CGFloat {
        guard asset.usesCategoryArtworkTreatment else { return 1 }
        return HomeSpeciesArtworkTreatment.resolved(
            for: asset.categoryID ?? 0
        ).scale
    }

    private var speciesOffset: CGSize {
        guard asset.usesCategoryArtworkTreatment else { return .zero }
        return HomeSpeciesArtworkTreatment.resolved(
            for: asset.categoryID ?? 0
        ).offset(for: side)
    }

    @ViewBuilder
    private var content: some View {
        if asset.isHidden {
            Color.clear
        } else if let remoteImageURL = asset.remoteImageURL,
           asset.usesCategoryArtworkTreatment {
            HomeHeroV2MainKindArtwork(
                urlString: remoteImageURL,
                placeholder: asset.localImage
            )
            .frame(width: side, height: side)
            .clipped()
        } else if let remoteImageURL = asset.remoteImageURL {
            HomeRemoteImage(
                urlString: remoteImageURL,
                placeholder: asset.localImage,
                contentMode: .scaleToFill
            )
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.85)
            }
        } else if let localImage = asset.localImage {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFit()
        } else if let imageName = asset.imageName {
            Image(imageName)
                .resizable()
                .scaledToFit()
        } else if let animationName = asset.animationName {
            HomeHeroLottieRepresentable(
                animationName: animationName,
                loadsFromFirebase: asset.loadsFromFirebase,
                playbackEnabled: scenePhase == .active,
                tintColor: lottieTintColor(for: animationName)
            )
            .scaleEffect(lottieScale(for: animationName))
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if let localImage = asset.localImage {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFit()
        } else {
            Color.clear
        }
    }

    private func lottieScale(for animationName: String) -> CGFloat {
        if animationName == "Shop2.json" { return 0.78 }
        return animationName == "petstore" ? 0.68 : 0.82
    }

    /// Marketplace artwork is a commerce identity mark, not body content, so
    /// its baked Lottie fills and strokes follow the canonical marketplace
    /// commerce accent (`ppQuickActionShopping`) instead of primary text ink.
    /// This matches the marketplace destination tint used across Home and the
    /// V1 hero, keeps the mark inside the brand rose family rather than reading
    /// as flat black, and adapts automatically in dark mode. Other hero
    /// animations retain the stable V2 primary accent.
    private func lottieTintColor(for animationName: String) -> UIColor {
        let assetName = animationName
            .split(separator: "/")
            .last
            .map(String.init)?
            .lowercased()
        if assetName == "shop2.json" || assetName == "bag2.json" {
            return .ppQuickActionShopping
        }
        return UIColor(accent)
    }
}

// MARK: - Swipe grip

/// Quiet paging affordance attached to the card edge. It remains decorative;
/// the entire card owns the swipe gesture and adjustable accessibility action.
@available(iOS 15.0, *)
private struct HomeHeroV2SwipeGrip: View {
    let accent: Color
    let reduceTransparency: Bool

    var body: some View {
        HStack(spacing: HomeHeroV2Metrics.gripBarSpacing) {
            ForEach(0..<3, id: \.self) { _ in
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.52))
                    .frame(
                        width: HomeHeroV2Metrics.gripBarWidth,
                        height: HomeHeroV2Metrics.gripBarHeight
                    )
            }
        }
        .frame(
            width: HomeHeroV2Metrics.gripWidth,
            height: HomeHeroV2Metrics.gripHeight
        )
        .background {
            Capsule(style: .continuous)
                .fill(
                    reduceTransparency
                        ? Color.ppSurfaceRaised
                        : accent.opacity(0.08)
                )
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(accent.opacity(0.20), lineWidth: 0.7)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Skeleton

@available(iOS 15.0, *)
private struct HomeHeroV2Skeleton: View {
    let height: CGFloat

    var body: some View {
        HStack(spacing: PPSpace.lg) {
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    Capsule().fill(Color.ppSeparator).frame(width: 78, height: 10)
                    Capsule().fill(Color.ppSeparator).frame(width: 150, height: 22)
                    Capsule().fill(Color.ppSeparator).frame(width: 164, height: 13)
                    Capsule().fill(Color.ppSeparator).frame(width: 126, height: 13)
                    Capsule()
                        .fill(Color.ppPrimary.opacity(0.16))
                        .frame(width: 140, height: HomeHeroV2Metrics.primaryHeight)
                }

                Spacer(minLength: 0)

                // Matches the live plate's lens proportion so the loading state
                // does not settle into a shorter shape once content arrives.
                Ellipse()
                    .fill(Color.ppSecondarySurface)
                    .frame(
                        width: HomeHeroV2Metrics.skeletonPlateInk,
                        height: HomeHeroV2Metrics.skeletonPlateInk
                            * HomeHeroV2Metrics.plateHeightRatio
                    )
        }
        .padding(HomeHeroV2Metrics.cardContentInset)
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            HomeModelAdapter.localized(
                "home_pulse_loading",
                fallback: "Loading Home"
            )
        )
    }
}

// MARK: - Motion + interaction modifiers

private struct HomeHeroV2PressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.035 : 0)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.14),
                value: configuration.isPressed
            )
    }
}

private struct HomeHeroV2PagePhase: ViewModifier {
    let opacity: Double
    let offsetX: CGFloat

    static let identity = HomeHeroV2PagePhase(opacity: 1, offsetX: 0)

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .offset(x: offsetX)
    }
}

private struct HomeHeroV2PageMotionModifier: ViewModifier {
    let pageID: AnyHashable
    let reduceMotion: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceMotion {
            content.animation(nil, value: pageID)
        } else {
            content.animation(
                .interactiveSpring(
                    response: 0.52,
                    dampingFraction: 0.84,
                    blendDuration: 0.10
                ),
                value: pageID
            )
        }
    }
}

private struct HomeHeroV2PagingGestureModifier: ViewModifier {
    let isEnabled: Bool
    let selectedIndex: Int
    let pageCount: Int
    let layoutDirection: LayoutDirection
    let onSelect: (Int) -> Void
    let onInteractionChanged: (Bool) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled && pageCount > 1 {
            content.simultaneousGesture(
                DragGesture(minimumDistance: 16)
                    .onChanged { value in
                        let dx = abs(value.translation.width)
                        let dy = abs(value.translation.height)
                        if dx > 10 && dx > dy * 1.35 {
                            onInteractionChanged(true)
                        }
                    }
                    .onEnded { value in
                        defer { onInteractionChanged(false) }
                        let dx = abs(value.translation.width)
                        let dy = abs(value.translation.height)
                        guard dx > 44, dx > dy * 1.35 else { return }
                        let physicalDirection =
                            value.translation.width < 0 ? 1 : -1
                        let logicalDirection =
                            layoutDirection == .rightToLeft
                            ? -physicalDirection
                            : physicalDirection
                        let next =
                            (selectedIndex + logicalDirection + pageCount)
                            % pageCount
                        onSelect(next)
                    }
            )
        } else {
            content
        }
    }
}

private struct HomeHeroV2PagingAccessibilityModifier: ViewModifier {
    let isEnabled: Bool
    let selectedIndex: Int
    let pageCount: Int
    let onSelect: (Int) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .accessibilityValue(
                    String(
                        format: HomeModelAdapter.localized(
                            "home_pulse_page_position_a11y",
                            fallback: "%1$d of %2$d"
                        ),
                        selectedIndex + 1,
                        pageCount
                    )
                )
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        onSelect((selectedIndex + 1) % max(pageCount, 1))
                    case .decrement:
                        onSelect(
                            (selectedIndex - 1 + max(pageCount, 1))
                                % max(pageCount, 1)
                        )
                    @unknown default:
                        break
                    }
                }
        } else {
            content
        }
    }
}


// MARK: - Identity accent safety

/// Contrast ladder for the hero's live category accent.
///
/// Ported from the same policy the species rail already applies to a MainKind
/// color: keep the authored identity color when it is legible, otherwise walk
/// toward primary text and the brand until it is. Firebase owns the category
/// palette, so the hero cannot assume a usable value.
private enum HomeHeroV2Palette {
    static func identityAccent(
        _ candidate: UIColor,
        traits: UITraitCollection
    ) -> UIColor {
        let surface = UIColor.ppSurfaceRaised.resolvedColor(with: traits)
        let text = UIColor.ppTextPrimary.resolvedColor(with: traits)
        let brand = UIColor.ppPrimary.resolvedColor(with: traits)
        // The accent carries body-weight copy and a white CTA label, so the
        // text threshold applies rather than the graphic-object threshold.
        let required: CGFloat = 4.5

        let base = opaque(candidate.resolvedColor(with: traits)) ?? brand
        let ladder: [UIColor] = [
            base,
            blend(base, with: text, ratio: 0.72),
            blend(base, with: text, ratio: 0.52),
            brand,
            blend(brand, with: text, ratio: 0.58),
        ]
        for color in ladder where contrastRatio(color, surface) >= required {
            return color
        }
        return text
    }

    private static func blend(
        _ first: UIColor,
        with second: UIColor,
        ratio: CGFloat
    ) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        guard first.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              second.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else {
            return first
        }
        let amount = min(max(ratio, 0), 1)
        let inverse = 1 - amount
        return UIColor(
            red: (r1 * amount) + (r2 * inverse),
            green: (g1 * amount) + (g2 * inverse),
            blue: (b1 * amount) + (b2 * inverse),
            alpha: (a1 * amount) + (a2 * inverse)
        )
    }

    private static func opaque(_ color: UIColor) -> UIColor? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        var alpha: CGFloat = 0
        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            guard alpha >= 0.12 else { return nil }
            return UIColor(red: red, green: green, blue: blue, alpha: 1)
        }
        var white: CGFloat = 0
        if color.getWhite(&white, alpha: &alpha) {
            guard alpha >= 0.12 else { return nil }
            return UIColor(white: white, alpha: 1)
        }
        return nil
    }

    private static func contrastRatio(
        _ first: UIColor,
        _ second: UIColor
    ) -> CGFloat {
        let lighter = max(luminance(first), luminance(second))
        let darker = min(luminance(first), luminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func luminance(_ color: UIColor) -> CGFloat {
        guard let opaqueColor = opaque(color) else { return 0 }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard opaqueColor.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        ) else {
            return 0
        }
        func linear(_ component: CGFloat) -> CGFloat {
            component <= 0.03928
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return (0.2126 * linear(red))
            + (0.7152 * linear(green))
            + (0.0722 * linear(blue))
    }
}

// MARK: - Living Species Dock

@available(iOS 15.0, *)
private struct HomeHeroSpeciesPressStyle: ButtonStyle {
    let assistiveMotionIsDisabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed
                    && !reduceMotion
                    && !assistiveMotionIsDisabled
                    ? 0.95
                    : 1
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(
                reduceMotion || assistiveMotionIsDisabled
                    ? nil
                    : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

@available(iOS 15.0, *)
private struct HomeHeroSpeciesDock: View {
    let categories: [HomeCategoryModel]
    let selectedCategoryID: Int?
    let accent: Color
    let isRightToLeft: Bool
    let onSelect: (HomeCategoryModel?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var focusNamespace

    @State private var isBeaconPulsing = false

    private var motionIsDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }

    private var isCategoryAccentEnabled: Bool {
        UserDefaults.standard.bool(
            forKey: "pp.marketplace.usesMainKindAccentColors"
        )
    }

    private var headerTitle: String {
        HomeModelAdapter.localized(
            "home_browse_by_category",
            fallback: isRightToLeft ? "تصفح حسب النوع" : "Browse by category"
        )
    }

    private var allTitle: String {
        Language.get("All", alter: nil) ?? Language.get("all", alter: nil) ?? (isRightToLeft ? "الكل" : "All")
    }

    private var selectedAccessibilityValue: String {
        Language.get("Selected", alter: nil) ?? (isRightToLeft ? "محدد" : "Selected")
    }

    private var resolvedSelectedCategoryID: Int? {
        guard let selectedCategoryID,
              categories.contains(where: {
                  HomeModelAdapter.mainKindID($0.raw) == selectedCategoryID
              }) else {
            return nil
        }
        return selectedCategoryID
    }

    private var resolvedSelectedCategory: HomeCategoryModel? {
        guard let resolvedSelectedCategoryID else { return nil }
        return categories.first {
            HomeModelAdapter.mainKindID($0.raw) == resolvedSelectedCategoryID
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            scopeHeader
            speciesRail
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
        )
        .environment(
            \.layoutDirection,
            isRightToLeft ? .rightToLeft : .leftToRight
        )
        .accessibilityElement(children: .contain)
    }

    private var scopeHeader: some View {
        HStack(spacing: PPSpace.md) {
            HStack(spacing: 7) {
                // Dual-layer Living Jewel Beacon
                ZStack {
                    if !motionIsDisabled && contrast != .increased {
                        Circle()
                            .fill(accent.opacity(isBeaconPulsing ? 0.36 : 0.10))
                            .frame(width: 15, height: 15)
                            .scaleEffect(isBeaconPulsing ? 1.25 : 0.85)
                            .blur(radius: 2.2)
                    }

                    Circle()
                        .stroke(
                            contrast == .increased
                                ? Color.ppTextPrimary
                                : accent.opacity(colorScheme == .dark ? 0.45 : 0.28),
                            lineWidth: contrast == .increased ? 1.5 : 0.85
                        )
                        .frame(width: 11, height: 11)
                        .scaleEffect(!motionIsDisabled && isBeaconPulsing ? 1.06 : 1.0)

                    Circle()
                        .fill(
                            contrast == .increased
                                ? Color.ppTextPrimary
                                : accent
                        )
                        .frame(width: 5.5, height: 5.5)
                        .scaleEffect(!motionIsDisabled && isBeaconPulsing ? 1.15 : 1.0)
                }
                .accessibilityHidden(true)

                Text(headerTitle)
                    .font(HomeFont.bold(dynamicTypeSize.isAccessibilitySize ? 14 : 12.5))
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(1)
            }

            HomeMainKindsScopeThread(
                accent: accent,
                selectedCategoryID: resolvedSelectedCategoryID,
                isRightToLeft: isRightToLeft
            )
        }
        .padding(.horizontal, HomeHeroSpeciesDockMetrics.headerHorizontalInset)
        .padding(.top, dynamicTypeSize.isAccessibilitySize ? PPSpace.xs : 2)
        .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? PPSpace.xs : 2)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .onAppear {
            guard !motionIsDisabled else { return }
            if !isBeaconPulsing {
                withAnimation(
                    .easeInOut(duration: 2.2)
                        .repeatForever(autoreverses: true)
                ) {
                    isBeaconPulsing = true
                }
            }
        }
    }

    private var speciesRail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HomeHeroSpeciesDockMetrics.itemSpacing) {
                    speciesButton(
                        category: nil,
                        title: allTitle,
                        isSelected: resolvedSelectedCategoryID == nil
                    )
                    .id(allScrollID)

                    ForEach(categories) { category in
                        let categoryID = HomeModelAdapter.mainKindID(category.raw)
                        speciesButton(
                            category: category,
                            title: category.title,
                            isSelected: categoryID == resolvedSelectedCategoryID
                        )
                        .id(scrollID(for: category))
                    }
                }
                .padding(.horizontal, HomeHeroSpeciesDockMetrics.railHorizontalInset)
                .padding(.top, 4)
                .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? PPSpace.sm : 6)
                .animation(
                    motionIsDisabled
                        ? nil
                        : .spring(response: 0.36, dampingFraction: 0.82),
                    value: resolvedSelectedCategoryID
                )
            }
            .onAppear {
                scrollToSelection(proxy: proxy, animated: false)
            }
            .onChange(of: selectedCategoryID) { _ in
                scrollToSelection(
                    proxy: proxy,
                    animated: !motionIsDisabled
                )
            }
        }
    }

    private func speciesButton(
        category: HomeCategoryModel?,
        title: String,
        isSelected: Bool
    ) -> some View {
        let itemAccent = isSelected && isCategoryAccentEnabled
            ? accent
            : identityAccent(for: category)

        return Button {
            let feedback = UISelectionFeedbackGenerator()
            feedback.prepare()
            feedback.selectionChanged()

            if motionIsDisabled {
                onSelect(category)
            } else {
                withAnimation(
                    .spring(response: 0.36, dampingFraction: 0.82)
                ) {
                    onSelect(category)
                }
            }
        } label: {
            HStack(spacing: isSelected ? 6 : 5) {
                if isSelected {
                    pawGem(for: category, accent: itemAccent)
                } else {
                    identitySeed(accent: itemAccent)
                }

                Text(title)
                    .font(
                        isSelected
                            ? HomeFont.bold(dynamicTypeSize.isAccessibilitySize ? 17.5 : 15.5)
                            : HomeFont.medium(dynamicTypeSize.isAccessibilitySize ? 16 : 14.5)
                    )
                    .foregroundStyle(
                        isSelected
                            ? (colorScheme == .dark ? Color.white : Color.black)
                            : Color.ppTextSecondary
                    )
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.leading, isSelected ? 12 : 9)
            .padding(.trailing, isSelected ? 22 : 9)
            .frame(
                minWidth: HomeHeroSpeciesDockMetrics.minimumItemWidth,
                minHeight: HomeHeroSpeciesDockMetrics.minimumItemHeight
            )
            .background {
                if isSelected {
                    activeCapsuleBackground(accent: itemAccent)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(
            HomeHeroSpeciesPressStyle(
                assistiveMotionIsDisabled: switchControlEnabled
                    || voiceOverEnabled
            )
        )
        .hoverEffect(.highlight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(
            isSelected ? selectedAccessibilityValue : ""
        )
        .accessibilityAddTraits(
            isSelected ? [.isSelected, .isButton] : [.isButton]
        )
        .accessibilityIdentifier(
            category.map { "home.hero.mainKind.\($0.id)" }
                ?? "home.hero.mainKind.all"
        )
    }

    @ViewBuilder
    private func activeCapsuleBackground(accent: Color) -> some View {
        if motionIsDisabled {
            capsuleSurface(accent: accent)
        } else {
            capsuleSurface(accent: accent)
                .matchedGeometryEffect(
                    id: "home.hero.species.active-capsule",
                    in: focusNamespace
                )
        }
    }

    private func capsuleSurface(accent: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    reduceTransparency
                        ? (colorScheme == .dark ? Color(white: 0.18) : Color.white)
                        : (colorScheme == .dark
                            ? Color.white.opacity(0.14)
                            : Color.white.opacity(0.92))
                )

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    contrast == .increased
                        ? Color.ppTextPrimary
                        : (colorScheme == .dark
                            ? Color.white.opacity(0.20)
                            : accent.opacity(0.28)),
                    lineWidth: contrast == .increased ? 1.5 : 0.75
                )
        }
        .shadow(
            color: reduceTransparency || contrast == .increased
                ? Color.clear
                : (colorScheme == .dark
                    ? Color.black.opacity(0.35)
                    : accent.opacity(0.18)),
            radius: 6,
            x: 0,
            y: 2
        )
    }

    private func pawGem(for category: HomeCategoryModel?, accent: Color) -> some View {
        let symbol = HomeCategoryModel.indicatorSymbol(for: category)
        return Image(systemName: symbol)
            .font(.system(size: 11.5, weight: .bold))
            .foregroundStyle(
                contrast == .increased
                    ? Color.ppTextPrimary
                    : accent
            )
            .frame(width: 14, height: 14)
            .accessibilityHidden(true)
    }

    private func pawGem(accent: Color) -> some View {
        pawGem(for: nil, accent: accent)
    }

    private func identitySeed(accent: Color) -> some View {
        Circle()
            .fill(accent.opacity(colorScheme == .dark ? 0.52 : 0.38))
            .frame(width: 4.5, height: 4.5)
            .frame(
                width: 12,
                height: 12
            )
            .accessibilityHidden(true)
    }

    private func identityAccent(
        for category: HomeCategoryModel?
    ) -> Color {
        guard isCategoryAccentEnabled, let category else {
            return Color.ppPrimary
        }
        return Color(uiColor: category.accent)
    }

    private var allScrollID: String {
        "home-hero-main-kind-all"
    }

    private var selectedScrollID: String {
        guard let selectedCategoryID = resolvedSelectedCategoryID,
              let category = categories.first(where: {
                  HomeModelAdapter.mainKindID($0.raw) == selectedCategoryID
              }) else {
            return allScrollID
        }
        return scrollID(for: category)
    }

    private func scrollID(for category: HomeCategoryModel) -> String {
        "home-hero-main-kind-\(category.id)"
    }

    private func scrollToSelection(
        proxy: ScrollViewProxy,
        animated: Bool
    ) {
        let update = {
            proxy.scrollTo(selectedScrollID, anchor: .center)
        }

        if animated {
            withAnimation(
                .spring(response: 0.36, dampingFraction: 0.82)
            ) {
                update()
            }
        } else {
            update()
        }
    }
}
