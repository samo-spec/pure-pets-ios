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
    static let height: CGFloat = 286
    static let maximumHeight: CGFloat = 304
    static let accessibilityPlateHeight: CGFloat = 184

    static let cardRadius: CGFloat = 30
    static let cardContentInset: CGFloat = PPSpace.base
    static let contentGap: CGFloat = PPSpace.sm
    static let copyWidthRatio: CGFloat = 0.45
    static let minimumCopyWidth: CGFloat = 150

    /// `PPHomeHeroLivingBlobShape` draws at 0.94 of its frame. The reference
    /// composition intentionally lets the plate travel beyond the physical
    /// leading/trailing edge while keeping the artwork fully inside the arc.
    static let blobInkRatio: CGFloat = 0.94
    static let plateInk: CGFloat = 226
    static let artworkSide: CGFloat = 170
    static let artworkVerticalShift: CGFloat = 5
    static let plateHorizontalOverflow: CGFloat = 42
    static let skeletonPlateInk: CGFloat = 156

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
    static let titleSize: CGFloat = 22
    static let primaryLabelSize: CGFloat = 14
    static let secondaryLabelSize: CGFloat = 12.5
}

@available(iOS 15.0, *)
struct HomeHeroV2View: View {
    let pages: [HomeHeroPage]
    let selectedIndex: Int
    let onSelect: (Int) -> Void
    let onPrimaryAction: () -> Void
    let onSecondaryAction: () -> Void
    let onInteractionChanged: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @ScaledMetric(relativeTo: .title) private var scaledHeight: CGFloat =
        HomeHeroV2Metrics.height

    private var selectedPage: HomeHeroPage? {
        guard pages.indices.contains(selectedIndex) else { return nil }
        return pages[selectedIndex]
    }

    private var resolvedHeight: CGFloat {
        min(scaledHeight, HomeHeroV2Metrics.maximumHeight)
    }

    /// The UIKit host can retain a left-to-right SwiftUI environment briefly
    /// while the app is already displaying Arabic. Resolve against the app's
    /// canonical language owner too, so leading/trailing never drift from the
    /// visible language during a Home refresh.
    private var isRightToLeft: Bool {
        layoutDirection == .rightToLeft || Language.isRTL()
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
        let accent = Color(hex: page.accentHex)

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                stackedHero(page, accent: accent)
            } else {
                splitHero(page, accent: accent)
                    .frame(height: resolvedHeight)
            }
        }
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
            let resolvedDirection: LayoutDirection =
                isRightToLeft ? .rightToLeft : .leftToRight

            let plateInk = min(
                HomeHeroV2Metrics.plateInk,
                height - (HomeHeroV2Metrics.cardContentInset * 2)
            )
            let plateFrame = plateInk / HomeHeroV2Metrics.blobInkRatio
            let plateOverflow = min(
                HomeHeroV2Metrics.plateHorizontalOverflow,
                plateFrame * 0.22
            )
            let visiblePlateWidth = plateFrame - plateOverflow
            let availableCopyWidth = width
                - visiblePlateWidth
                - HomeHeroV2Metrics.cardContentInset
                - HomeHeroV2Metrics.contentGap
            let copyWidth = max(
                HomeHeroV2Metrics.minimumCopyWidth,
                min(width * HomeHeroV2Metrics.copyWidthRatio, availableCopyWidth)
            )

            let copyCenterX = isRightToLeft
                ? width - HomeHeroV2Metrics.cardContentInset - (copyWidth / 2)
                : HomeHeroV2Metrics.cardContentInset + (copyWidth / 2)
            let plateInsetCenter = max((plateFrame / 2) - plateOverflow, 0)
            let plateCenterX = isRightToLeft
                ? plateInsetCenter
                : width - plateInsetCenter
            let gripCenterX = isRightToLeft
                ? HomeHeroV2Metrics.gripEdgeInset
                    + (HomeHeroV2Metrics.gripWidth / 2)
                : width
                    - HomeHeroV2Metrics.gripEdgeInset
                    - (HomeHeroV2Metrics.gripWidth / 2)

            ZStack(alignment: .topLeading) {
                HomeHeroV2CardBackground(
                    accent: accent,
                    plateCenterX: plateCenterX,
                    plateDiameter: plateFrame,
                    isDark: colorScheme == .dark,
                    increasedContrast: contrast == .increased,
                    reduceTransparency: reduceTransparency
                )

                plateStage(
                    page,
                    accent: accent,
                    plateFrame: plateFrame,
                    plateInk: plateInk,
                    artworkSide: min(
                        HomeHeroV2Metrics.artworkSide,
                        plateInk - PPSpace.base
                    )
                )
                .position(x: plateCenterX, y: height / 2)

                heroCopy(page, accent: accent)
                    .environment(\.layoutDirection, resolvedDirection)
                    .frame(width: copyWidth, alignment: .leading)
                    .position(x: copyCenterX, y: height / 2)

                if allowsPaging {
                    HomeHeroV2SwipeGrip(
                        accent: accent,
                        reduceTransparency: reduceTransparency
                            || contrast == .increased
                    )
                    .position(x: gripCenterX, y: height / 2)
                }
            }
            .frame(width: width, height: height, alignment: .topLeading)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: HomeHeroV2Metrics.cardRadius,
                    style: .continuous
                )
            )
            .shadow(
                color: Color.black.opacity(
                    contrast == .increased
                        ? 0
                        : (colorScheme == .dark ? 0.20 : 0.055)
                ),
                radius: 20,
                y: 10
            )
        }
    }

    /// Accessibility sizes retain the card language but move the plate beneath
    /// the copy so neither text nor artwork is compressed.
    private func stackedHero(
        _ page: HomeHeroPage,
        accent: Color
    ) -> some View {
        let resolvedDirection: LayoutDirection =
            isRightToLeft ? .rightToLeft : .leftToRight
        let plateInk = HomeHeroV2Metrics.accessibilityPlateHeight

        return VStack(alignment: .leading, spacing: PPSpace.base) {
            heroCopy(page, accent: accent)
                .environment(\.layoutDirection, resolvedDirection)
                .frame(maxWidth: .infinity, alignment: .leading)

            plateStage(
                page,
                accent: accent,
                plateFrame: plateInk / HomeHeroV2Metrics.blobInkRatio,
                plateInk: plateInk,
                artworkSide: plateInk - PPSpace.xl
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(HomeHeroV2Metrics.cardContentInset)
        .background {
            HomeHeroV2CardBackground(
                accent: accent,
                plateCenterX: 0,
                plateDiameter: plateInk,
                isDark: colorScheme == .dark,
                increasedContrast: contrast == .increased,
                reduceTransparency: reduceTransparency
            )
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: HomeHeroV2Metrics.cardRadius,
                style: .continuous
            )
        )
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
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(colorScheme == .dark ? 0.18 : 0.10),
                            accent.opacity(0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: plateFrame * 0.54
                    )
                )
                .frame(width: plateFrame + PPSpace.lg, height: plateFrame + PPSpace.lg)

            PPHomeHeroLivingBlobView(
                fillGradient: plateGradient(accent: accent),
                accent: accent,
                isDark: colorScheme == .dark
            )
            .frame(width: plateFrame, height: plateFrame)
            .shadow(
                color: accent.opacity(
                    contrast == .increased
                        ? 0
                        : (colorScheme == .dark ? 0.24 : 0.12)
                ),
                radius: 16,
                y: 8
            )

            Ellipse()
                .fill(accent.opacity(colorScheme == .dark ? 0.18 : 0.08))
                .frame(width: artworkSide * 0.70, height: 12)
                .blur(radius: 6)
                .offset(y: artworkSide * 0.32)

            HomeHeroV2Artwork(
                asset: heroArtworkAsset(for: page),
                accent: accent,
                side: artworkSide
            )
            .frame(width: artworkSide, height: artworkSide)
            .offset(y: HomeHeroV2Metrics.artworkVerticalShift)
        }
        .frame(width: plateFrame, height: plateFrame)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Reference plate is a pale, cool, low-saturation wash. Built from shipped
    /// palette tokens so it stays correct in dark mode and increased contrast.
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
                    accent.opacity(0.18),
                    Color.homeBrand.opacity(0.10),
                ],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color.ppQuietLilac,
                Color.ppQuietLilac.opacity(0.62),
                Color.ppSurfaceRaised,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: Copy column — every string block is leading aligned

    private func heroCopy(
        _ page: HomeHeroPage,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
                .padding(.top, PPSpace.sm)
                .accessibilityAddTraits(.isHeader)

            Text(page.subtitle)
                .font(HomeFont.subheadline())
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 6 : 2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, PPSpace.xs)

            primaryButton(page, accent: accent)
                .padding(.top, PPSpace.md)

            if let secondaryTitle = page.secondaryTitle,
               !secondaryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty {
                secondaryButton(secondaryTitle, accent: accent)
                    .padding(.top, PPSpace.sm)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            let hasSelectedCategory: Bool
            if case let .openMarketplace(mainKind) = page.action {
                hasSelectedCategory = mainKind != nil
            } else {
                hasSelectedCategory = false
            }
            let hasPageArtwork = page.localImage != nil
                || normalizedHeroImageURL(page.imageURL) != nil
            if homeHeroV2ShowsSelectedMainKindArtwork
                && (hasSelectedCategory || hasPageArtwork) {
                let categoryImage = page.localImage
                let fallbackImage = categoryImage ?? UIImage(named: "pawprint4")
                return HomeHeroV2ArtworkAsset(
                    imageName: fallbackImage == nil ? "pawprint4" : nil,
                    localImage: fallbackImage,
                    // The category rail and the hero must present the same pet
                    // identity. Prefer the resolved local artwork; fall back to
                    // the remote source only when no local artwork exists.
                    remoteImageURL: categoryImage == nil
                        ? normalizedHeroImageURL(page.imageURL)
                        : nil,
                    usesCategoryArtworkTreatment: true
                )
            }
            return HomeHeroV2ArtworkAsset(animationName: "Shop2.json")
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

// MARK: - Card field

/// A contained editorial field rather than an empty white canvas. The plate
/// gets a local accent atmosphere while the copy lane stays quiet and highly
/// legible. Two hairlines (specular + accent) give the card a physical edge
/// without returning to the heavy V1 card treatment.
@available(iOS 15.0, *)
private struct HomeHeroV2CardBackground: View {
    let accent: Color
    let plateCenterX: CGFloat
    let plateDiameter: CGFloat
    let isDark: Bool
    let increasedContrast: Bool
    let reduceTransparency: Bool

    var body: some View {
        GeometryReader { proxy in
            let shape = RoundedRectangle(
                cornerRadius: HomeHeroV2Metrics.cardRadius,
                style: .continuous
            )
            let focalX = min(max(plateCenterX / max(proxy.size.width, 1), 0), 1)

            ZStack {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.ppSurfaceRaised,
                                Color.ppSurface,
                                accent.opacity(isDark ? 0.10 : 0.035),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if !reduceTransparency && !increasedContrast {
                    RadialGradient(
                        colors: [
                            accent.opacity(isDark ? 0.20 : 0.11),
                            accent.opacity(isDark ? 0.07 : 0.035),
                            Color.clear,
                        ],
                        center: UnitPoint(x: focalX, y: 0.50),
                        startRadius: 0,
                        endRadius: plateDiameter * 0.88
                    )
                    .clipShape(shape)

                    Circle()
                        .stroke(
                            accent.opacity(isDark ? 0.16 : 0.08),
                            style: StrokeStyle(
                                lineWidth: 0.8,
                                lineCap: .round,
                                dash: [2, 6]
                            )
                        )
                        .frame(
                            width: plateDiameter + PPSpace.xxl,
                            height: plateDiameter + PPSpace.xxl
                        )
                        .position(x: plateCenterX, y: proxy.size.height / 2)
                }

                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isDark ? 0.18 : 0.96),
                                accent.opacity(isDark ? 0.24 : 0.16),
                                Color.ppBorder.opacity(0.62),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: increasedContrast ? 1.5 : 0.9
                    )

                shape
                    .inset(by: 3)
                    .stroke(
                        Color.white.opacity(isDark ? 0.04 : 0.34),
                        lineWidth: 0.6
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Artwork

struct HomeHeroV2ArtworkAsset {
    var animationName: String?
    var imageName: String?
    var localImage: UIImage?
    var remoteImageURL: String?
    var usesCategoryArtworkTreatment: Bool
    var loadsFromFirebase: Bool

    init(
        animationName: String? = nil,
        imageName: String? = nil,
        localImage: UIImage? = nil,
        remoteImageURL: String? = nil,
        usesCategoryArtworkTreatment: Bool = false,
        loadsFromFirebase: Bool = false
    ) {
        self.animationName = animationName
        self.imageName = imageName
        self.localImage = localImage
        self.remoteImageURL = remoteImageURL
        self.usesCategoryArtworkTreatment = usesCategoryArtworkTreatment
        self.loadsFromFirebase = loadsFromFirebase
    }
}

@available(iOS 15.0, *)
private struct HomeHeroV2Artwork: View {
    let asset: HomeHeroV2ArtworkAsset
    let accent: Color
    let side: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var presented = false

    var body: some View {
        content
            .frame(width: side, height: side)
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

    @ViewBuilder
    private var content: some View {
        if let remoteImageURL = asset.remoteImageURL,
           asset.usesCategoryArtworkTreatment {
            AppRemoteImage(
                urlString: remoteImageURL,
                displaySize: CGSize(width: side, height: side),
                contentMode: .fit,
                fadeDuration: 0
            ) {
                placeholder
            } failurePlaceholder: {
                placeholder
            }
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

    private func lottieTintColor(for animationName: String) -> UIColor? {
        if animationName == "Shop2.json"
            || animationName == "bag2.json"
            || animationName == "petstore" {
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
        ZStack {
            RoundedRectangle(
                cornerRadius: HomeHeroV2Metrics.cardRadius,
                style: .continuous
            )
            .fill(Color.ppSurfaceRaised)
            .overlay {
                RoundedRectangle(
                    cornerRadius: HomeHeroV2Metrics.cardRadius,
                    style: .continuous
                )
                .strokeBorder(Color.ppBorder.opacity(0.54), lineWidth: 0.8)
            }

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

                Circle()
                    .fill(Color.ppSecondarySurface)
                    .frame(
                        width: HomeHeroV2Metrics.skeletonPlateInk,
                        height: HomeHeroV2Metrics.skeletonPlateInk
                    )
            }
            .padding(HomeHeroV2Metrics.cardContentInset)
        }
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
