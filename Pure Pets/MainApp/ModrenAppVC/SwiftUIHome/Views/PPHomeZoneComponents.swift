import SwiftUI
import UIKit

// MARK: - Shared metrics

/// One coherent geometry vocabulary for the Home zone family, so the marketing
/// stage, partner feature, launcher, and gateways share the same rhythm instead
/// of each inventing its own numbers.
enum PPHomeZoneMetrics {
    static let stageMediaHeight: CGFloat = 176
    static let stageMediaAccessibilityHeight: CGFloat = 132
    static let partnerMediaSide: CGFloat = 104
    static let launcherIconPlate: CGFloat = 44
    static let launcherCellHeight: CGFloat = 72
    static let launcherBandIconPlate: CGFloat = 38
    static let launcherBandCellHeight: CGFloat = 108
    static let launcherBandSeparator: CGFloat = 1
    static let minimumTarget: CGFloat = 44
    static let gatewaySymbolPlate: CGFloat = 42
    static let statusSymbolPlate: CGFloat = 46
    static let pageDot: CGFloat = 6
    static let pageDotSelected: CGFloat = 18
}

/// Semantic role → token mapping for the Home zone family. Nothing here
/// introduces a colour: every value resolves through an existing Pure Pets
/// semantic token.
enum PPHomeZoneTone {
    /// Matches the production quick-action tone mapping so the ecosystem
    /// launcher and the legacy grid agree on category meaning.
    static func accent(for actionID: String, fallback: UIColor) -> Color {
        switch actionID {
        case "shop":
            return Color.ppQuickActionShopping
        case "pet", "ads":
            return Color.ppAdoptionAccent
        case "pharmacy", "vet", "services":
            // One care hue for the three care destinations. Colour stays
            // semantic; the destinations separate by glyph and label, not by
            // inventing a fourth hue outside the palette.
            return Color.ppCareAccent
        default:
            return Color(uiColor: fallback)
        }
    }
}

// MARK: - Section heading

/// The single heading treatment for every Home zone.
@available(iOS 15.0, *)
struct PPHomeSectionHeading: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        return Group {
            if stacked {
                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    copy
                    if let actionTitle, let action {
                        actionButton(actionTitle, action)
                    }
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: PPSpace.md) {
                    copy
                    if let actionTitle, let action {
                        actionButton(actionTitle, action)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: PPSpace.xxs) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow)
                    .font(HomeFont.bold(11))
                    .foregroundStyle(Color.ppAccentText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(title)
                .font(HomeFont.title2())
                .foregroundStyle(Color.homeTextPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(HomeFont.footnote())
                    .foregroundStyle(Color.homeTextSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionButton(
        _ title: String,
        _ action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: PPSpace.xxs) {
                Text(title)
                    .font(HomeFont.bold(14))
                Image(systemName: "chevron.forward")
                    .font(.system(size: 11, weight: .bold))
                    .flipsForRightToLeftLayoutDirection(true)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.ppAccentText)
            .padding(.horizontal, PPSpace.sm)
            .frame(minHeight: PPHomeZoneMetrics.minimumTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Marketing stage

/// Zone 2. The single dominant commercial story on Home.
///
/// Composition is deliberately split — a real media band above a semantic copy
/// plate — so every headline, price, CTA, and disclosure is measured against a
/// token surface instead of an unpredictable campaign photograph. That keeps
/// contrast provable in light, dark, and Increased Contrast, and it degrades
/// honestly when campaign artwork is missing, low resolution, or offline.
///
/// Motion: the media, copy, and actions move as one keyed page. Paging state
/// and automatic rotation stay with `HomeStore`, so this presentation surface
/// never owns a second timer during live campaign updates.
@available(iOS 15.0, *)
struct PPHomeMarketingStage: View {
    let pages: [HomeHeroPage]
    let selectedIndex: Int
    let discloseCampaign: Bool
    let onSelect: (Int) -> Void
    let onPrimary: (HomeHeroPage) -> Void
    let onSecondary: (HomeHeroPage) -> Void
    let onInteractionChanged: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection

    private var page: HomeHeroPage? {
        guard pages.indices.contains(selectedIndex) else { return pages.first }
        return pages[selectedIndex]
    }

    private var accent: Color {
        Color(hex: page?.accentHex ?? "CB2654")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
    }

    var body: some View {
        Group {
            if let page {
                stage(page)
            } else {
                PPHomeStagePlaceholder()
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func stage(_ page: HomeHeroPage) -> some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                mediaBand(page)
                copyPlate(page)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(page.id)
            .transition(pageTransition)
        }
        .animation(pageAnimation, value: page.id)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.homeRaisedSurface)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                accent.opacity(
                    contrast == .increased
                        ? 0.62
                        : (colorScheme == .dark ? 0.30 : 0.16)
                ),
                lineWidth: contrast == .increased ? 1.5 : 1
            )
        }
        .shadow(
            color: Color.black.opacity(
                contrast == .increased ? 0 : (colorScheme == .dark ? 0.24 : 0.07)
            ),
            radius: contrast == .increased ? 0 : 18,
            y: contrast == .increased ? 0 : 8
        )
        .modifier(
            PPHomeStagePagingGesture(
                enabled: pages.count > 1,
                isRightToLeft: layoutDirection == .rightToLeft,
                onInteractionChanged: setInteracting,
                onAdvance: advance
            )
        )
        .accessibilityAction(named: Text(nextActionTitle)) { advance(1) }
        .accessibilityAction(named: Text(previousActionTitle)) { advance(-1) }
        .accessibilityScrollAction { edge in
            switch edge {
            case .leading: advance(layoutDirection == .rightToLeft ? 1 : -1)
            case .trailing: advance(layoutDirection == .rightToLeft ? -1 : 1)
            default: break
            }
        }
    }

    // MARK: Media

    private func mediaBand(_ page: HomeHeroPage) -> some View {
        ZStack {
            HomeHeroField(
                accent: accent,
                increasedContrast: contrast == .increased,
                cornerGlowOpacityScale: 0.5
            )

            if presentsSelectedCategoryArtwork(page) {
                PPHomeStageArtwork(page: page, accent: accent)
            } else if let urlString = page.imageURL, !urlString.isEmpty {
                HomeRemoteImage(
                    urlString: urlString,
                    placeholder: page.localImage,
                    contentMode: .scaleAspectFill,
                    cacheKey: page.id,
                    displaySize: CGSize(
                        width: 900,
                        height: PPHomeZoneMetrics.stageMediaHeight * 2
                    )
                )
            } else if let localImage = page.localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                PPHomeStageArtwork(page: page, accent: accent)
            }
        }
        .frame(height: mediaHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(alignment: .topLeading) {
            if discloseCampaign {
                PPHomeDisclosureChip()
                    .padding(PPSpace.md)
            }
        }
        .overlay(alignment: .bottom) {
            // Keeps the media/copy seam readable over bright artwork without
            // ever placing text on top of an unmeasured photograph.
            LinearGradient(
                colors: [
                    Color.homeRaisedSurface.opacity(0),
                    Color.homeRaisedSurface,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: PPSpace.xl)
            .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }

    private var mediaHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? PPHomeZoneMetrics.stageMediaAccessibilityHeight
            : PPHomeZoneMetrics.stageMediaHeight
    }

    /// Marketplace category art is an identity mark, not a background photo.
    /// Keep it on the authored hero plate where the marketplace Lottie lives.
    private func presentsSelectedCategoryArtwork(_ page: HomeHeroPage) -> Bool {
        guard case .marketplace = page.kind else { return false }
        let hasRemoteImage = !(page.imageURL?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ?? true)
        return hasRemoteImage || page.localImage != nil
    }

    // MARK: Copy

    private func copyPlate(_ page: HomeHeroPage) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                if !page.eyebrow.isEmpty {
                    Text(page.eyebrow)
                        .font(HomeFont.bold(11))
                        .foregroundStyle(Color.ppAccentText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(page.title)
                    .font(HomeFont.title1())
                    .foregroundStyle(Color.homeTextPrimary)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)

                if !page.subtitle.isEmpty {
                    Text(page.subtitle)
                        .font(HomeFont.callout())
                        .foregroundStyle(Color.homeTextSecondary)
                        .lineSpacing(1)
                        .multilineTextAlignment(.leading)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // One focusable element that always leads with the disclosure and
            // carries the complete value, even when visible copy is clamped.
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityAddTraits(.isHeader)

            actions(page)

            if pages.count > 1 {
                PPHomePageControl(
                    count: pages.count,
                    selectedIndex: selectedIndex
                )
            }
        }
        .padding(.horizontal, PPSpace.lg)
        .padding(.top, PPSpace.base)
        .padding(.bottom, PPSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func actions(_ page: HomeHeroPage) -> some View {
        let secondary = page.secondaryTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let primary = page.primaryTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: PPSpace.sm) {
                if !primary.isEmpty {
                    PPHomePrimaryAction(
                        title: primary,
                        fillsWidth: true,
                        action: { onPrimary(page) }
                    )
                }
                if !secondary.isEmpty {
                    PPHomeQuietAction(
                        title: secondary,
                        action: { onSecondary(page) }
                    )
                }
            }
        } else {
            HStack(spacing: PPSpace.md) {
                if !primary.isEmpty {
                    PPHomePrimaryAction(
                        title: primary,
                        fillsWidth: false,
                        action: { onPrimary(page) }
                    )
                }
                if !secondary.isEmpty {
                    PPHomeQuietAction(
                        title: secondary,
                        action: { onSecondary(page) }
                    )
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Behaviour

    private func setInteracting(_ active: Bool) {
        onInteractionChanged(active)
    }

    private func advance(_ direction: Int) {
        guard pages.count > 1 else { return }
        let count = pages.count
        let next = ((selectedIndex + direction) % count + count) % count
        guard next != selectedIndex else { return }
        onSelect(next)
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        return .asymmetric(
            insertion: AnyTransition.opacity
                .combined(with: .offset(y: 10))
                .combined(with: .scale(scale: 0.99, anchor: .top)),
            removal: .opacity
        )
    }

    private var pageAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.20)
    }

    private var accessibilitySummary: String {
        guard let page else { return "" }
        var parts: [String] = []
        if discloseCampaign {
            parts.append(PPHomeZoneCopy.campaignDisclosure)
        }
        if !page.eyebrow.isEmpty { parts.append(page.eyebrow) }
        parts.append(page.title)
        if !page.subtitle.isEmpty { parts.append(page.subtitle) }
        if pages.count > 1 {
            parts.append(
                String(
                    format: PPHomeZoneCopy.stagePagePosition,
                    selectedIndex + 1,
                    pages.count
                )
            )
        }
        return parts.joined(separator: ", ")
    }

    private var nextActionTitle: String { PPHomeZoneCopy.stageNext }
    private var previousActionTitle: String { PPHomeZoneCopy.stagePrevious }
}

/// The Marketing Stage's visual artwork owner.
///
/// Marketplace pages use a full-band, finite Living Compass scene. Other page
/// kinds reuse the production Home hero plate verbatim — the same animation
/// files, Firebase-versus-bundle resolution, scale, tint, and existing
/// `PPHomeHeroAnimationView` Objective-C Lottie runtime. No second animation
/// dependency and no new asset is introduced.
///
/// Reduce Motion keeps the artwork and pauses playback, matching the legacy
/// hero rather than swapping in a different image.
@available(iOS 15.0, *)
private struct PPHomeStageArtwork: View {
    let page: HomeHeroPage
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection

    @ViewBuilder
    var body: some View {
        if isMarketplace {
            PPHomeMarketplaceLivingCompass(
                page: page,
                accent: accent,
                marketplaceSymbol: asset.primarySymbol
            )
        } else {
            legacyPlate
        }
    }

    /// Pet, reminder, promotion, onboarding, and pharmacy keep the exact stage
    /// treatment they already shipped with. The marketplace is the only visual
    /// branch authorized to become the Home entry-point scene.
    private var legacyPlate: some View {
        ZStack {
            plateShape.fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.30),
                        Color.ppSurfaceRaised.opacity(0.94),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            if hasSelectedCategoryArtwork {
                selectedCategoryArtwork
            } else {
                HomeHeroLottieRepresentable(
                    animationName: asset.name,
                    loadsFromFirebase: asset.loadsFromFirebase,
                    playbackEnabled: !reduceMotion,
                    tintColor: tintColor
                )
                .scaleEffect(scale)
            }
        }
        .frame(width: side, height: side)
        .clipShape(plateShape)
        .overlay {
            plateShape.strokeBorder(
                contrast == .increased
                    ? Color.ppTextPrimary.opacity(0.62)
                    : Color.white.opacity(colorScheme == .dark ? 0.16 : 0.82),
                lineWidth: contrast == .increased ? 1.5 : 1
            )
        }
        .overlay(alignment: .topTrailing) {
            cornerIcon(symbol: asset.primarySymbol, side: 44)
                .offset(
                    x: layoutDirection == .rightToLeft ? -12 : 12,
                    y: -11
                )
        }
        .overlay(alignment: .bottomLeading) {
            cornerIcon(symbol: asset.secondarySymbol, side: 38)
                .offset(
                    x: layoutDirection == .rightToLeft ? 12 : -12,
                    y: 9
                )
        }
        .accessibilityHidden(true)
    }

    private var isMarketplace: Bool {
        if case .marketplace = page.kind { return true }
        return false
    }

    private var plateShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
    }

    private var side: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 108 : 136
    }

    private var categoryArtworkSide: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 68 : 84
    }

    private var hasSelectedCategoryArtwork: Bool {
        guard case .marketplace = page.kind else { return false }
        return selectedCategoryURL != nil || page.localImage != nil
    }

    private var selectedCategoryURL: String? {
        guard let imageURL = page.imageURL?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !imageURL.isEmpty
        else { return nil }
        return imageURL
    }

    @ViewBuilder
    private var selectedCategoryArtwork: some View {
        if let imageURL = selectedCategoryURL {
            AppRemoteImage(
                urlString: imageURL,
                displaySize: CGSize(
                    width: categoryArtworkSide,
                    height: categoryArtworkSide
                ),
                contentMode: .fit,
                fadeDuration: 0,
                showsRetryAction: false
            ) {
                categoryArtworkPlaceholder
            } failurePlaceholder: {
                categoryArtworkPlaceholder
            }
            .frame(width: categoryArtworkSide, height: categoryArtworkSide)
        } else {
            categoryArtworkPlaceholder
        }
    }

    @ViewBuilder
    private var categoryArtworkPlaceholder: some View {
        if let localImage = page.localImage {
            Image(uiImage: localImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: categoryArtworkSide, height: categoryArtworkSide)
        } else {
            Image(systemName: "pawprint.fill")
                .font(.system(size: categoryArtworkSide * 0.54, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: categoryArtworkSide, height: categoryArtworkSide)
        }
    }

    /// Exactly the animation the production Home hero resolves for this kind.
    private var asset: (
        name: String,
        loadsFromFirebase: Bool,
        primarySymbol: String,
        secondarySymbol: String
    ) {
        switch page.kind {
        case .pet:
            return ("Profile.lottie", true, "heart.fill", "pawprint.fill")
        case .reminder:
            return ("Caretiming", true, "bell.fill", "calendar")
        case .promotion:
            return ("HomePromotionSpark", false, "sparkles", "tag.fill")
        case .marketplace:
            return ("Shop2.json", false, "bag.fill", "shippingbox.fill")
        case .petOnboarding:
            return (
                "LottieAnimations/Boy Giving Food To Rabbit New.json",
                true,
                "plus",
                "pawprint.fill"
            )
        case .pharmacy:
            return ("PetMedicine", false, "pills.fill", "bandage.fill")
        }
    }

    private func cornerIcon(symbol: String, side: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(accent)
            .frame(width: side, height: side)
            .background(
                Color.ppSurfaceRaised.opacity(0.92),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        contrast == .increased
                            ? Color.ppTextPrimary.opacity(0.62)
                            : Color.white.opacity(
                                colorScheme == .dark ? 0.14 : 0.78
                            ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: Color.black.opacity(contrast == .increased ? 0 : 0.08),
                radius: 8,
                y: 4
            )
            .allowsHitTesting(false)
    }

    private var scale: CGFloat {
        if asset.name == "Shop2.json" { return 0.95 }
        return asset.name == "petstore" ? 0.78 : 1.30
    }

    private var tintColor: UIColor? {
        if asset.name == "Shop2.json" { return UIColor(accent) }
        return asset.name == "petstore"
            ? UIColor(Color.ppPrimary)
            : UIColor.white
    }
}

/// The marketplace's opening scene: a selected pet identity connected to the
/// two destinations this Home stage actually owns — marketplace and services.
///
/// The scene is deliberately decorative. The copy plate remains the semantic
/// heading, and its two existing controls remain the only action owners. This
/// lets the first impression explain Pure Pets without duplicating navigation,
/// state, analytics, or accessibility focus inside the artwork.
@available(iOS 15.0, *)
private struct PPHomeMarketplaceLivingCompass: View {
    let page: HomeHeroPage
    let accent: Color
    let marketplaceSymbol: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.scenePhase) private var scenePhase

    @State private var phase: Phase = .staged
    @State private var lastPresentedIdentity: String?

    var body: some View {
        GeometryReader { proxy in
            let geometry = Geometry(
                size: proxy.size,
                accessibilitySize: dynamicTypeSize.isAccessibilitySize,
                isRightToLeft: isRightToLeft
            )

            ZStack {
                compassRoutes

                identityLens(side: geometry.identitySide)
                    .scaleEffect(identityPresented ? 1 : 0.97)
                    .opacity(identityPresented ? 1 : 0.68)
                    .offset(x: identityPresented ? 0 : logicalOffset(-8))
                    .position(
                        x: geometry.identityCenter.x,
                        y: geometry.identityCenter.y
                    )

                landmark(
                    symbol: marketplaceSymbol,
                    side: geometry.marketplaceSide,
                    tone: accent
                )
                .modifier(landmarkPhase)
                .position(
                    x: geometry.marketplaceCenter.x,
                    y: geometry.marketplaceCenter.y
                )

                landmark(
                    symbol: "hands.sparkles.fill",
                    side: geometry.careSide,
                    tone: Color.ppCareAccent
                )
                .modifier(landmarkPhase)
                .position(
                    x: geometry.careCenter.x,
                    y: geometry.careCenter.y
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .task(id: motionKey) { await runEntrance() }
        .onDisappear(perform: settleWithoutAnimation)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Identity

    private func identityLens(side: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.homeRaisedSurface)

            if contrast == .increased {
                Circle().fill(accent.opacity(0.10))
            } else {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(
                                    reduceTransparency
                                        ? 0.20
                                        : (colorScheme == .dark ? 0.34 : 0.26)
                                ),
                                accent.opacity(
                                    reduceTransparency
                                        ? 0.06
                                        : (colorScheme == .dark ? 0.12 : 0.07)
                                ),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: side * 0.58
                        )
                    )
            }

            Circle()
                .trim(from: 0.08, to: 0.78)
                .stroke(
                    accent.opacity(contrast == .increased ? 0.82 : 0.42),
                    style: StrokeStyle(
                        lineWidth: contrast == .increased ? 2 : 1.25,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(isRightToLeft ? 116 : -64))
                .padding(contrast == .increased ? 5 : 7)

            identityArtwork(side: side * 0.72)
        }
        .frame(width: side, height: side)
        .overlay {
            Circle().strokeBorder(
                contrast == .increased
                    ? Color.ppTextPrimary.opacity(0.76)
                    : Color.white.opacity(colorScheme == .dark ? 0.16 : 0.86),
                lineWidth: contrast == .increased ? 1.5 : 1
            )
        }
        .shadow(
            color: Color.black.opacity(contrast == .increased ? 0 : 0.09),
            radius: 14,
            y: 8
        )
    }

    @ViewBuilder
    private func identityArtwork(side: CGFloat) -> some View {
        if let imageURL = selectedCategoryURL {
            AppRemoteImage(
                urlString: imageURL,
                displaySize: CGSize(width: side, height: side),
                contentMode: .fit,
                fadeDuration: 0,
                showsRetryAction: false
            ) {
                categoryArtworkPlaceholder(side: side)
            } failurePlaceholder: {
                categoryArtworkPlaceholder(side: side)
            }
            .frame(width: side, height: side)
        } else if page.localImage != nil {
            categoryArtworkPlaceholder(side: side)
        } else {
            Image(systemName: "storefront.fill")
                .font(.system(size: side * 0.56, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accent)
                .frame(width: side, height: side)
        }
    }

    @ViewBuilder
    private func categoryArtworkPlaceholder(side: CGFloat) -> some View {
        if let localImage = page.localImage {
            Image(uiImage: localImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: side, height: side)
        } else {
            Image(systemName: "pawprint.fill")
                .font(.system(size: side * 0.52, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: side, height: side)
        }
    }

    private var selectedCategoryURL: String? {
        guard let imageURL = page.imageURL?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !imageURL.isEmpty
        else { return nil }
        return imageURL
    }

    // MARK: - Pure Path

    private var compassRoutes: some View {
        ZStack {
            ForEach(PPHomeCompassRoute.Destination.allCases, id: \.self) { destination in
                PPHomeCompassRoute(destination: destination)
                    .stroke(
                        Color.homeSeparator.opacity(
                            contrast == .increased ? 0.92 : 0.58
                        ),
                        style: StrokeStyle(
                            lineWidth: contrast == .increased ? 1.5 : 1,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )

                PPHomeCompassRoute(destination: destination)
                    .trim(from: 0, to: routeProgress)
                    .stroke(
                        routeGradient,
                        style: StrokeStyle(
                            lineWidth: contrast == .increased ? 2.6 : 1.8,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
        }
        .scaleEffect(x: isRightToLeft ? -1 : 1, y: 1)
        .padding(.horizontal, PPSpace.sm)
        .padding(.vertical, PPSpace.xs)
    }

    private var routeGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(contrast == .increased ? 1 : 0.84),
                Color.ppCareAccent.opacity(contrast == .increased ? 1 : 0.82),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Landmarks

    private func landmark(
        symbol: String,
        side: CGFloat,
        tone: Color
    ) -> some View {
        ZStack {
            Circle().fill(Color.homeRaisedSurface)
            Circle().fill(tone.opacity(reduceTransparency ? 0.10 : 0.08))

            Image(systemName: symbol)
                .font(.system(size: side * 0.36, weight: .bold))
                .foregroundStyle(tone)
        }
        .frame(width: side, height: side)
        .overlay {
            Circle().strokeBorder(
                contrast == .increased
                    ? Color.ppTextPrimary.opacity(0.72)
                    : tone.opacity(colorScheme == .dark ? 0.42 : 0.20),
                lineWidth: contrast == .increased ? 1.5 : 1
            )
        }
        .shadow(
            color: Color.black.opacity(contrast == .increased ? 0 : 0.07),
            radius: 8,
            y: 4
        )
    }

    private var landmarkPhase: PPHomeCompassLandmarkPhase {
        PPHomeCompassLandmarkPhase(
            opacity: landmarksPresented ? 1 : 0.34,
            offsetX: landmarksPresented ? 0 : logicalOffset(-9),
            scale: landmarksPresented ? 1 : 0.90
        )
    }

    // MARK: - Finite causal motion

    private struct MotionKey: Equatable {
        let identity: String
        let suppressed: Bool
    }

    private var motionKey: MotionKey {
        MotionKey(identity: artworkIdentity, suppressed: motionSuppressed)
    }

    @MainActor
    private func runEntrance() async {
        guard !motionSuppressed,
              lastPresentedIdentity != artworkIdentity
        else {
            settleWithoutAnimation()
            return
        }

        stageWithoutAnimation()
        await Task.yield()
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.18)) {
            phase = .identity
        }

        do {
            try await Task<Never, Never>.sleep(nanoseconds: 90_000_000)
        } catch {
            return
        }
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.27)) {
            phase = .connected
        }

        do {
            try await Task<Never, Never>.sleep(nanoseconds: 150_000_000)
        } catch {
            return
        }
        guard !Task.isCancelled else { return }

        withAnimation(
            .spring(
                response: 0.28,
                dampingFraction: 0.90,
                blendDuration: 0.03
            )
        ) {
            phase = .settled
        }
        lastPresentedIdentity = artworkIdentity
    }

    private func stageWithoutAnimation() {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            phase = .staged
        }
    }

    private func settleWithoutAnimation() {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            phase = .settled
            lastPresentedIdentity = artworkIdentity
        }
    }

    private var presentationPhase: Phase {
        motionSuppressed ? .settled : phase
    }

    private var identityPresented: Bool {
        presentationPhase.rawValue >= Phase.identity.rawValue
    }

    private var landmarksPresented: Bool {
        presentationPhase == .settled
    }

    private var routeProgress: CGFloat {
        presentationPhase.rawValue >= Phase.connected.rawValue ? 1 : 0.06
    }

    private var motionSuppressed: Bool {
        reduceMotion ||
            voiceOverEnabled ||
            switchControlEnabled ||
            scenePhase != .active
    }

    /// `HomeHeroPage.id` intentionally stays stable for marketplace paging.
    /// This private presentation key retargets only the decorative scene when
    /// the selected MainKind changes.
    private var artworkIdentity: String {
        guard case let .openMarketplace(mainKind) = page.action,
              let mainKind
        else { return "\(page.id):all" }
        return "\(page.id):main-kind-\(HomeModelAdapter.mainKindID(mainKind))"
    }

    private var isRightToLeft: Bool {
        layoutDirection == .rightToLeft
    }

    private func logicalOffset(_ value: CGFloat) -> CGFloat {
        isRightToLeft ? -value : value
    }

    private enum Phase: Int, Equatable {
        case staged
        case identity
        case connected
        case settled
    }

    private struct Geometry {
        let size: CGSize
        let accessibilitySize: Bool
        let isRightToLeft: Bool

        var identitySide: CGFloat {
            min(accessibilitySize ? 88 : 118, size.height - (accessibilitySize ? 18 : 24))
        }

        var marketplaceSide: CGFloat { accessibilitySize ? 34 : 42 }
        var careSide: CGFloat { accessibilitySize ? 38 : 46 }

        var identityCenter: CGPoint { point(logicalX: 0.27, y: 0.50) }
        var marketplaceCenter: CGPoint { point(logicalX: 0.61, y: 0.30) }
        var careCenter: CGPoint { point(logicalX: 0.80, y: 0.64) }

        private func point(logicalX: CGFloat, y: CGFloat) -> CGPoint {
            CGPoint(
                x: size.width * (isRightToLeft ? 1 - logicalX : logicalX),
                y: size.height * y
            )
        }
    }
}

@available(iOS 15.0, *)
private struct PPHomeCompassLandmarkPhase: ViewModifier {
    let opacity: Double
    let offsetX: CGFloat
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .offset(x: offsetX)
            .scaleEffect(scale)
    }
}

/// Two source-bound paths leave the selected identity: one resolves at the
/// marketplace landmark and one at the existing services destination.
@available(iOS 15.0, *)
private struct PPHomeCompassRoute: Shape {
    enum Destination: CaseIterable, Hashable {
        case marketplace
        case care
    }

    let destination: Destination

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let origin = CGPoint(
            x: rect.minX + rect.width * 0.39,
            y: rect.minY + rect.height * 0.50
        )
        path.move(to: origin)

        switch destination {
        case .marketplace:
            path.addCurve(
                to: CGPoint(
                    x: rect.minX + rect.width * 0.61,
                    y: rect.minY + rect.height * 0.30
                ),
                control1: CGPoint(
                    x: rect.minX + rect.width * 0.46,
                    y: rect.minY + rect.height * 0.48
                ),
                control2: CGPoint(
                    x: rect.minX + rect.width * 0.53,
                    y: rect.minY + rect.height * 0.28
                )
            )
        case .care:
            path.addCurve(
                to: CGPoint(
                    x: rect.minX + rect.width * 0.80,
                    y: rect.minY + rect.height * 0.64
                ),
                control1: CGPoint(
                    x: rect.minX + rect.width * 0.52,
                    y: rect.minY + rect.height * 0.54
                ),
                control2: CGPoint(
                    x: rect.minX + rect.width * 0.68,
                    y: rect.minY + rect.height * 0.72
                )
            )
        }
        return path
    }
}

@available(iOS 15.0, *)
private struct PPHomeStagePagingGesture: ViewModifier {
    let enabled: Bool
    let isRightToLeft: Bool
    let onInteractionChanged: (Bool) -> Void
    let onAdvance: (Int) -> Void

    private let threshold: CGFloat = 44

    func body(content: Content) -> some View {
        if enabled {
            content.gesture(
                DragGesture(minimumDistance: 14)
                    .onChanged { value in
                        guard abs(value.translation.width)
                            > abs(value.translation.height)
                        else { return }
                        onInteractionChanged(true)
                    }
                    .onEnded { value in
                        onInteractionChanged(false)
                        let horizontal = value.translation.width
                        guard abs(horizontal) > abs(value.translation.height),
                              abs(horizontal) >= threshold
                        else { return }
                        let forward = isRightToLeft
                            ? horizontal > 0
                            : horizontal < 0
                        onAdvance(forward ? 1 : -1)
                    }
            )
        } else {
            content
        }
    }
}

@available(iOS 15.0, *)
private struct PPHomeStagePlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
            .fill(Color.homeSurface)
            .frame(height: PPHomeZoneMetrics.stageMediaHeight + 132)
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                    .strokeBorder(Color.homeSeparator, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Partner / campaign feature

/// A demoted campaign lane. Smaller than the stage, still media-led, always
/// one feature at a time, and it keeps every configured campaign reachable
/// through its own paging affordance.
@available(iOS 15.0, *)
struct PPHomePartnerFeature: View {
    let pages: [HomeHeroPage]
    let discloseCampaign: Bool
    let onPrimary: (HomeHeroPage) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var index = 0

    private var page: HomeHeroPage? {
        guard pages.indices.contains(index) else { return pages.first }
        return pages[index]
    }

    private var accent: Color {
        Color(hex: page?.accentHex ?? "CB2654")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
    }

    var body: some View {
        Group {
            if let page {
                feature(page)
            } else {
                EmptyView()
            }
        }
        .onChange(of: pages.map(\.id)) { _ in
            index = min(index, max(0, pages.count - 1))
        }
    }

    private func feature(_ page: HomeHeroPage) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            PPHomeSectionHeading(
                eyebrow: discloseCampaign
                    ? PPHomeZoneCopy.campaignDisclosure
                    : nil,
                title: PPHomeZoneCopy.partnerFeatureTitle,
                subtitle: nil
            )

            ZStack {
                Button { onPrimary(page) } label: {
                    content(page)
                }
                .buttonStyle(PPHomeSurfacePressStyle(reduceMotion: reduceMotion))
                .accessibilityLabel(accessibilityLabel(page))
                .accessibilityHint(page.primaryTitle)
                .id(page.id)
                .transition(.opacity)
            }
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.14)
                    : .easeOut(duration: 0.24),
                value: page.id
            )

            if pages.count > 1 {
                PPHomePageControl(
                    count: pages.count,
                    selectedIndex: index
                )
            }
        }
        .modifier(
            PPHomeStagePagingGesture(
                enabled: pages.count > 1,
                isRightToLeft: layoutDirection == .rightToLeft,
                onInteractionChanged: { _ in },
                onAdvance: advance
            )
        )
        .accessibilityAction(named: Text(PPHomeZoneCopy.stageNext)) {
            advance(1)
        }
        .accessibilityAction(named: Text(PPHomeZoneCopy.stagePrevious)) {
            advance(-1)
        }
    }

    @ViewBuilder
    private func content(_ page: HomeHeroPage) -> some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        Group {
            if stacked {
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    media(page)
                        .frame(maxWidth: .infinity)
                        .frame(height: PPHomeZoneMetrics.stageMediaAccessibilityHeight)
                    copy(page)
                }
            } else {
                HStack(alignment: .center, spacing: PPSpace.base) {
                    media(page)
                        .frame(
                            width: PPHomeZoneMetrics.partnerMediaSide,
                            height: PPHomeZoneMetrics.partnerMediaSide
                        )
                    copy(page)
                }
            }
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.homeSurface)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                accent.opacity(
                    contrast == .increased
                        ? 0.58
                        : (colorScheme == .dark ? 0.26 : 0.14)
                ),
                lineWidth: contrast == .increased ? 1.5 : 1
            )
        }
        .contentShape(shape)
    }

    private func media(_ page: HomeHeroPage) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                .fill(accent.opacity(colorScheme == .dark ? 0.20 : 0.10))

            if let urlString = page.imageURL, !urlString.isEmpty {
                HomeRemoteImage(
                    urlString: urlString,
                    placeholder: page.localImage,
                    contentMode: .scaleAspectFill,
                    cacheKey: "partner-\(page.id)",
                    displaySize: CGSize(width: 320, height: 320)
                )
            } else if let localImage = page.localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "tag.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(accent)
            }
        }
        .clipShape(
            RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
        )
        .accessibilityHidden(true)
    }

    private func copy(_ page: HomeHeroPage) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            if !page.eyebrow.isEmpty {
                Text(page.eyebrow)
                    .font(HomeFont.bold(11))
                    .foregroundStyle(Color.ppAccentText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(page.title)
                .font(HomeFont.headline())
                .foregroundStyle(Color.homeTextPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            if !page.subtitle.isEmpty {
                Text(page.subtitle)
                    .font(HomeFont.footnote())
                    .foregroundStyle(Color.homeTextSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: PPSpace.xxs) {
                Text(page.primaryTitle)
                    .font(HomeFont.bold(14))
                Image(systemName: "chevron.forward")
                    .font(.system(size: 11, weight: .bold))
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .foregroundStyle(Color.ppAccentText)
            .padding(.top, PPSpace.xxs)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func advance(_ direction: Int) {
        guard pages.count > 1 else { return }
        let count = pages.count
        index = ((index + direction) % count + count) % count
    }

    private func accessibilityLabel(_ page: HomeHeroPage) -> String {
        var parts: [String] = []
        if discloseCampaign { parts.append(PPHomeZoneCopy.campaignDisclosure) }
        if !page.eyebrow.isEmpty { parts.append(page.eyebrow) }
        parts.append(page.title)
        if !page.subtitle.isEmpty { parts.append(page.subtitle) }
        if pages.count > 1 {
            parts.append(
                String(
                    format: PPHomeZoneCopy.stagePagePosition,
                    index + 1,
                    pages.count
                )
            )
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Ecosystem launcher

/// Zone 3. Bounded, immediate access to the highest-value destinations.
///
/// The launcher is one connected ecosystem surface, not a wall of unrelated
/// cards. The first two configured destinations form a discovery band; up to
/// three remaining destinations form a care band. This preserves server-backed
/// action order and every existing route while giving Arabic and English titles
/// and subtitles enough room to remain visible at normal text sizes.
///
/// One through five actions reflow without placeholders. Accessibility text
/// sizes use the same full-width cells as before, keeping the complete copy and
/// a minimum 44pt target without relying on compressed text.
@available(iOS 15.0, *)
struct PPHomeEcosystemLauncher: View {
    let actions: [HomePriorityAction]
    let onSelect: (HomePriorityAction) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    @ScaledMetric(relativeTo: .body)
    private var bandIconPlate: CGFloat = PPHomeZoneMetrics.launcherBandIconPlate

    private var stacked: Bool { dynamicTypeSize.isAccessibilitySize }
    private var boundedActions: [HomePriorityAction] {
        Array(actions.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            PPHomeSectionHeading(
                title: PPHomeZoneCopy.launcherTitle,
                subtitle: PPHomeZoneCopy.launcherSubtitle
            )

            if stacked {
                VStack(spacing: PPSpace.sm) {
                    ForEach(boundedActions) { action in
                        Button { onSelect(action) } label: {
                            stackedCell(action)
                        }
                        .buttonStyle(
                            PPHomeSurfacePressStyle(reduceMotion: reduceMotion)
                        )
                        .accessibilityLabel(action.title)
                        .accessibilityHint(action.subtitle)
                    }
                }
            } else {
                bandsSurface
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Ecosystem bands

    private var bandsSurface: some View {
        let rows = bands
        let shape = RoundedRectangle(
            cornerRadius: PPCorner.card,
            style: .continuous
        )
        return VStack(spacing: 0) {
            ForEach(rows) { band in
                bandRow(band)

                if band.id != rows.last?.id {
                    horizontalSeparator
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.homeSurface)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                Color.homeSeparator.opacity(
                    contrast == .increased
                        ? 0.9
                        : (colorScheme == .dark ? 0.32 : 0.5)
                ),
                lineWidth: contrast == .increased ? 1.5 : 1
            )
        }
        .shadow(
            color: contrast == .increased
                ? .clear
                : Color.black.opacity(colorScheme == .dark ? 0.10 : 0.04),
            radius: PPShadow.subtle.radius,
            x: PPShadow.subtle.x,
            y: PPShadow.subtle.y
        )
    }

    private var bands: [PPHomeEcosystemBand] {
        let bounded = boundedActions
        guard !bounded.isEmpty else { return [] }
        guard bounded.count > 2 else {
            return [PPHomeEcosystemBand(
                id: "discovery-\(bounded.map(\.id).joined(separator: "-"))",
                tone: .discovery,
                actions: bounded
            )]
        }

        let discovery = Array(bounded.prefix(2))
        let care = Array(bounded.dropFirst(2))
        return [
            PPHomeEcosystemBand(
                id: "discovery-\(discovery.map(\.id).joined(separator: "-"))",
                tone: .discovery,
                actions: discovery
            ),
            PPHomeEcosystemBand(
                id: "care-\(care.map(\.id).joined(separator: "-"))",
                tone: .care,
                actions: care
            ),
        ]
    }

    private func bandRow(_ band: PPHomeEcosystemBand) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(band.actions) { action in
                Button { onSelect(action) } label: {
                    bandCell(action)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .contentShape(Rectangle())
                }
                .buttonStyle(
                    PPHomeLauncherBandPressStyle(
                        accent: PPHomeZoneTone.accent(
                            for: action.id,
                            fallback: action.accent
                        ),
                        reduceMotion: reduceMotion
                    )
                )
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .top)
                .overlay(alignment: .trailing) {
                    if action.id != band.actions.last?.id {
                        verticalSeparator
                    }
                }
                .accessibilityLabel(action.title)
                .accessibilityHint(action.subtitle)
            }
        }
        .background(bandTint(band.tone))
    }

    private var verticalSeparator: some View {
        Rectangle()
            .fill(
                Color.homeSeparator.opacity(
                    contrast == .increased ? 0.85 : 0.4
                )
            )
            .frame(width: PPHomeZoneMetrics.launcherBandSeparator)
            .padding(.vertical, PPSpace.md)
            .accessibilityHidden(true)
    }

    private var horizontalSeparator: some View {
        Rectangle()
            .fill(
                Color.homeSeparator.opacity(
                    contrast == .increased ? 0.85 : 0.46
                )
            )
            .frame(height: PPHomeZoneMetrics.launcherBandSeparator)
            .accessibilityHidden(true)
    }

    private func bandTint(_ tone: PPHomeEcosystemBand.Tone) -> Color {
        switch tone {
        case .discovery:
            return Color.ppPrimary.opacity(colorScheme == .dark ? 0.055 : 0.032)
        case .care:
            return Color.ppCareAccent.opacity(colorScheme == .dark ? 0.075 : 0.045)
        }
    }

    private func bandCell(_ action: HomePriorityAction) -> some View {
        let accent = PPHomeZoneTone.accent(
            for: action.id,
            fallback: action.accent
        )
        let plateShape = RoundedRectangle(
            cornerRadius: PPCorner.small,
            style: .continuous
        )
        return VStack(alignment: .leading, spacing: PPSpace.sm) {
            HStack(spacing: PPSpace.xs) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(
                        width: min(bandIconPlate, 46),
                        height: min(bandIconPlate, 46)
                    )
                    .background(
                        accent.opacity(colorScheme == .dark ? 0.20 : 0.12),
                        in: plateShape
                    )
                    .overlay {
                        if contrast == .increased {
                            plateShape.strokeBorder(
                                accent.opacity(0.9),
                                lineWidth: 1
                            )
                        }
                    }
                    .accessibilityHidden(true)

                Spacer(minLength: 0)

                Image(systemName: "chevron.forward")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accent.opacity(0.84))
                    .flipsForRightToLeftLayoutDirection(true)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                Text(action.title)
                    .font(HomeFont.bold(15))
                    .foregroundStyle(Color.homeTextPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !action.subtitle.isEmpty {
                    Text(action.subtitle)
                        .font(HomeFont.caption1())
                        .foregroundStyle(Color.homeTextSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, PPSpace.sm)
        .padding(.vertical, PPSpace.md)
        .frame(
            maxWidth: .infinity,
            minHeight: PPHomeZoneMetrics.launcherBandCellHeight,
            alignment: .topLeading
        )
    }

    // MARK: Accessibility-size cell

    private func stackedCell(_ action: HomePriorityAction) -> some View {
        let accent = PPHomeZoneTone.accent(
            for: action.id,
            fallback: action.accent
        )
        let shape = RoundedRectangle(
            cornerRadius: PPCorner.card,
            style: .continuous
        )
        return HStack(spacing: PPSpace.md) {
            Image(systemName: action.systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent)
                .frame(
                    width: PPHomeZoneMetrics.launcherIconPlate,
                    height: PPHomeZoneMetrics.launcherIconPlate
                )
                .background(
                    accent.opacity(0.12),
                    in: RoundedRectangle(
                        cornerRadius: PPCorner.small,
                        style: .continuous
                    )
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(action.title)
                    .font(HomeFont.bold(15))
                    .foregroundStyle(Color.homeTextPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if !action.subtitle.isEmpty {
                    Text(action.subtitle)
                        .font(HomeFont.caption1())
                        .foregroundStyle(Color.homeTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.forward")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accent)
                .flipsForRightToLeftLayoutDirection(true)
                .accessibilityHidden(true)
        }
        .padding(PPSpace.md)
        .frame(
            maxWidth: .infinity,
            minHeight: PPHomeZoneMetrics.launcherCellHeight,
            alignment: .leading
        )
        .background(Color.homeSurface)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                accent.opacity(
                    contrast == .increased
                        ? 0.56
                        : (colorScheme == .dark ? 0.24 : 0.14)
                ),
                lineWidth: contrast == .increased ? 1.5 : 1
            )
        }
        .contentShape(shape)
    }
}

private struct PPHomeEcosystemBand: Identifiable {
    enum Tone {
        case discovery
        case care
    }

    let id: String
    let tone: Tone
    let actions: [HomePriorityAction]
}

/// A band destination confirms touch in place; the connected ecosystem surface
/// never scales as one large card and navigation remains immediately available.
@available(iOS 15.0, *)
private struct PPHomeLauncherBandPressStyle: ButtonStyle {
    let accent: Color
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        return configuration.label
            .background(
                Rectangle().fill(
                    accent.opacity(configuration.isPressed ? 0.10 : 0)
                )
            )
            .scaleEffect(
                configuration.isPressed && !reduceMotion ? 0.985 : 1,
                anchor: .center
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.14),
                value: configuration.isPressed
            )
    }
}

// MARK: - Live priority

/// Zone 4. Exactly one contextual state. Never a dashboard.
///
/// The order variant intentionally reuses the production `HomeOrderCard`, so
/// order identity, progress, previews, and routing stay byte-identical. This
/// component owns the care-reminder variant only.
@available(iOS 15.0, *)
struct PPHomeStatusCard: View {
    let page: HomeHeroPage
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: PPSpace.md) {
                        symbol
                        careCopy
                        careCTA
                    }
                } else {
                    HStack(alignment: .center, spacing: PPSpace.base) {
                        symbol
                        careCopy
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.homeTextSecondary)
                            .flipsForRightToLeftLayoutDirection(true)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(PPSpace.base)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.homeSurface)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    Color.homeFocus.opacity(
                        contrast == .increased
                            ? 0.62
                            : (colorScheme == .dark ? 0.30 : 0.18)
                    ),
                    lineWidth: contrast == .increased ? 1.5 : 1
                )
            }
            .contentShape(shape)
        }
        .buttonStyle(PPHomeSurfacePressStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(
            [
                PPHomeZoneCopy.livePriorityTitle,
                page.eyebrow,
                page.title,
                page.subtitle,
            ]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        )
        .accessibilityHint(page.primaryTitle)
    }

    private var symbol: some View {
        Image(systemName: "bell.badge.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Color.homeFocus)
            .frame(
                width: PPHomeZoneMetrics.statusSymbolPlate,
                height: PPHomeZoneMetrics.statusSymbolPlate
            )
            .background(
                Color.homeFocus.opacity(0.12),
                in: RoundedRectangle(
                    cornerRadius: PPCorner.small,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)
    }

    private var careCopy: some View {
        VStack(alignment: .leading, spacing: PPSpace.xxs) {
            Text(
                page.eyebrow.isEmpty
                    ? PPHomeZoneCopy.livePriorityTitle
                    : page.eyebrow
            )
            .font(HomeFont.bold(11))
            .foregroundStyle(Color.ppTextSecondary)
            .fixedSize(horizontal: false, vertical: true)

            Text(page.title)
                .font(HomeFont.headline())
                .foregroundStyle(Color.homeTextPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            if !page.subtitle.isEmpty {
                Text(page.subtitle)
                    .font(HomeFont.footnote())
                    .foregroundStyle(Color.homeTextSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var careCTA: some View {
        HStack(spacing: PPSpace.xxs) {
            Text(page.primaryTitle)
                .font(HomeFont.bold(14))
            Image(systemName: "chevron.forward")
                .font(.system(size: 11, weight: .bold))
                .flipsForRightToLeftLayoutDirection(true)
        }
        .foregroundStyle(Color.ppAccentText)
        .frame(minHeight: PPHomeZoneMetrics.minimumTarget)
        .accessibilityHidden(true)
    }
}

// MARK: - Service gateway

struct PPHomeServiceDestination: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let accent: Color
}

/// The single care/service gateway. Replaces two overlapping legacy care
/// presentations with one coherent treatment that keeps both destinations.
@available(iOS 15.0, *)
struct PPHomeServiceGateway: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    let destinations: [PPHomeServiceDestination]
    let onSelect: (PPHomeServiceDestination) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            PPHomeSectionHeading(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle
            )

            LazyVGrid(columns: columns, spacing: PPSpace.sm) {
                ForEach(destinations) { destination in
                    Button { onSelect(destination) } label: {
                        cell(destination)
                    }
                    .buttonStyle(
                        PPHomeSurfacePressStyle(reduceMotion: reduceMotion)
                    )
                    .accessibilityLabel(destination.title)
                    .accessibilityHint(destination.subtitle)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize
            ? 1
            : max(1, min(destinations.count, 2))
        return Array(
            repeating: GridItem(.flexible(), spacing: PPSpace.sm),
            count: count
        )
    }

    private func cell(_ destination: PPHomeServiceDestination) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: PPCorner.card,
            style: .continuous
        )
        return VStack(alignment: .leading, spacing: PPSpace.sm) {
            Image(systemName: destination.symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(destination.accent)
                .frame(
                    width: PPHomeZoneMetrics.gatewaySymbolPlate,
                    height: PPHomeZoneMetrics.gatewaySymbolPlate
                )
                .background(
                    destination.accent.opacity(0.12),
                    in: RoundedRectangle(
                        cornerRadius: PPCorner.small,
                        style: .continuous
                    )
                )
                .accessibilityHidden(true)

            Text(destination.title)
                .font(HomeFont.headline())
                .foregroundStyle(Color.homeTextPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if !destination.subtitle.isEmpty {
                Text(destination.subtitle)
                    .font(HomeFont.footnote())
                    .foregroundStyle(Color.homeTextSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(PPSpace.base)
        .frame(
            maxWidth: .infinity,
            minHeight: PPHomeZoneMetrics.minimumTarget * 2,
            alignment: .leading
        )
        .background(Color.homeSurface)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                destination.accent.opacity(
                    contrast == .increased
                        ? 0.56
                        : (colorScheme == .dark ? 0.26 : 0.16)
                ),
                lineWidth: contrast == .increased ? 1.5 : 1
            )
        }
        .contentShape(shape)
    }
}

// MARK: - Pet context

/// Zone 5 personalization. Deliberately compact: pet context is a signal, not
/// a territory. The populated state reuses the production `HomePetSwitcher`,
/// which already owns its own heading, Edit action, and screen insets, so no
/// second pet heading is introduced. The empty state stays a single quiet row
/// so Home remains complete with no pet and when signed out.
@available(iOS 15.0, *)
struct PPHomePetContextStrip: View {
    let pets: [HomePetModel]
    let selectedID: String?
    let onSelect: (HomePetModel) -> Void
    let onEdit: () -> Void
    let onOpenProfiles: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if pets.isEmpty {
            emptyState
        } else {
            HomePetSwitcher(
                pets: pets,
                selectedID: selectedID,
                onSelect: onSelect,
                onEdit: onEdit
            )
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            PPHomeSectionHeading(
                title: PPHomeZoneCopy.petEmptyTitle,
                subtitle: PPHomeZoneCopy.petEmptySubtitle
            )

            Button(action: onOpenProfiles) {
                HStack(spacing: PPSpace.md) {
                    Image(systemName: "pawprint.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.ppAdoptionAccent)
                        .accessibilityHidden(true)

                    Text(PPHomeZoneCopy.petOpenProfile)
                        .font(HomeFont.bold(15))
                        .foregroundStyle(Color.homeTextPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: PPSpace.sm)

                    Image(systemName: "chevron.forward")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.homeTextSecondary)
                        .flipsForRightToLeftLayoutDirection(true)
                        .accessibilityHidden(true)
                }
                .padding(PPSpace.base)
                .frame(
                    maxWidth: .infinity,
                    minHeight: PPHomeZoneMetrics.minimumTarget + 12,
                    alignment: .leading
                )
                .background(
                    Color.homeSurface,
                    in: RoundedRectangle(
                        cornerRadius: PPCorner.card,
                        style: .continuous
                    )
                )
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: PPCorner.card,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(PPHomeSurfacePressStyle(reduceMotion: reduceMotion))
            .accessibilityLabel(PPHomeZoneCopy.petOpenProfile)
            .accessibilityHint(PPHomeZoneCopy.petEmptyHint)
        }
        .padding(.horizontal, PPSpace.screenMargin)
    }
}

// MARK: - Explore more

/// Renders every module the presentation bounded out, using the destination the
/// resolver already proved reachable. Nothing configured becomes unreachable.
@available(iOS 15.0, *)
struct PPHomeExploreMoreRow: View {
    struct Entry: Identifiable {
        let id: Int
        let title: String
        let symbol: String
        let action: () -> Void
    }

    let entries: [Entry]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            PPHomeSectionHeading(
                title: PPHomeZoneCopy.exploreMoreTitle,
                subtitle: PPHomeZoneCopy.exploreMoreSubtitle
            )

            LazyVGrid(columns: columns, alignment: .leading, spacing: PPSpace.sm) {
                ForEach(entries) { entry in
                    Button(action: entry.action) {
                        HStack(spacing: PPSpace.sm) {
                            Image(systemName: entry.symbol)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.ppAccentText)
                                .accessibilityHidden(true)

                            Text(entry.title)
                                .font(HomeFont.medium(14))
                                .foregroundStyle(Color.homeTextPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: PPSpace.xs)

                            Image(systemName: "chevron.forward")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.homeTextSecondary)
                                .flipsForRightToLeftLayoutDirection(true)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, PPSpace.md)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: PPHomeZoneMetrics.minimumTarget,
                            alignment: .leading
                        )
                        .background(
                            Color.homeSurface,
                            in: RoundedRectangle(
                                cornerRadius: PPCorner.small,
                                style: .continuous
                            )
                        )
                        .contentShape(
                            RoundedRectangle(
                                cornerRadius: PPCorner.small,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(
                        PPHomeSurfacePressStyle(reduceMotion: reduceMotion)
                    )
                    .accessibilityLabel(entry.title)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(
            repeating: GridItem(.flexible(), spacing: PPSpace.sm),
            count: count
        )
    }
}

// MARK: - Shared primitives

@available(iOS 15.0, *)
struct PPHomeDisclosureChip: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Text(PPHomeZoneCopy.campaignDisclosure)
            .font(HomeFont.bold(11))
            .foregroundStyle(Color.homeTextPrimary)
            .padding(.horizontal, PPSpace.sm)
            .padding(.vertical, PPSpace.xxs)
            .background(Color.homeRaisedSurface, in: Capsule())
            .overlay {
                Capsule().strokeBorder(
                    Color.homeSeparator.opacity(
                        contrast == .increased ? 1 : 0.7
                    ),
                    lineWidth: contrast == .increased ? 1.5 : 0.8
                )
            }
            // The visual chip is decorative here; the containing element
            // already speaks the disclosure first in its label.
            .accessibilityHidden(true)
    }
}

@available(iOS 15.0, *)
struct PPHomePrimaryAction: View {
    let title: String
    let fillsWidth: Bool
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: PPSpace.sm) {
                Text(title)
                    .font(HomeFont.bold(16))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Image(systemName: "chevron.forward")
                    .font(.system(size: 11, weight: .bold))
                    .flipsForRightToLeftLayoutDirection(true)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, PPSpace.lg)
            .frame(
                maxWidth: fillsWidth ? .infinity : nil,
                minHeight: PPHomeZoneMetrics.minimumTarget + 6
            )
            .background(
                Color.homeBrand,
                in: RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
            )
            .overlay {
                if contrast == .increased {
                    RoundedRectangle(
                        cornerRadius: PPCorner.medium,
                        style: .continuous
                    )
                    .strokeBorder(Color.homeTextPrimary, lineWidth: 1.5)
                }
            }
            .contentShape(
                RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
            )
        }
        .buttonStyle(PPHomeSurfacePressStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(title)
    }
}

@available(iOS 15.0, *)
struct PPHomeQuietAction: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(HomeFont.bold(15))
                .foregroundStyle(Color.ppAccentText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, PPSpace.sm)
                .frame(minHeight: PPHomeZoneMetrics.minimumTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

@available(iOS 15.0, *)
struct PPHomePageControl: View {
    let count: Int
    let selectedIndex: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: PPSpace.xs) {
            ForEach(0..<max(count, 0), id: \.self) { index in
                Capsule()
                    .fill(
                        index == selectedIndex
                            ? Color.ppAccentText
                            : Color.ppTextSecondary
                    )
                    .frame(
                        width: index == selectedIndex
                            ? PPHomeZoneMetrics.pageDotSelected
                            : PPHomeZoneMetrics.pageDot,
                        height: PPHomeZoneMetrics.pageDot
                    )
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.22),
                        value: selectedIndex
                    )
            }
        }
        .frame(height: PPSpace.md)
        .accessibilityHidden(true)
    }
}

/// One press feedback grammar for every Home surface control.
@available(iOS 15.0, *)
struct PPHomeSurfacePressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && !reduceMotion ? 0.985 : 1,
                anchor: .center
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.15),
                value: configuration.isPressed
            )
    }
}

// MARK: - Copy

/// Localized copy for the new zone family. Every value resolves through the
/// existing Arabic-first localization pipeline; nothing is hardcoded per
/// language in code.
enum PPHomeZoneCopy {
    static var campaignDisclosure: String {
        HomeModelAdapter.localized(
            "home_marketing_promotion_disclosure",
            fallback: "Promotion"
        )
    }

    static var stagePagePosition: String {
        HomeModelAdapter.localized(
            "home_marketing_stage_page_a11y",
            fallback: "Story %1$d of %2$d"
        )
    }

    static var stageNext: String {
        HomeModelAdapter.localized(
            "home_marketing_stage_next",
            fallback: "Next story"
        )
    }

    static var stagePrevious: String {
        HomeModelAdapter.localized(
            "home_marketing_stage_previous",
            fallback: "Previous story"
        )
    }

    static var partnerFeatureTitle: String {
        HomeModelAdapter.localized(
            "home_partner_feature_title",
            fallback: "Featured offer"
        )
    }

    static var launcherTitle: String {
        HomeModelAdapter.localized(
            "home_ecosystem_launcher_title",
            fallback: "Explore Pure Pets"
        )
    }

    static var launcherSubtitle: String {
        HomeModelAdapter.localized(
            "home_ecosystem_launcher_subtitle",
            fallback: "Your main destinations"
        )
    }

    static var livePriorityTitle: String {
        HomeModelAdapter.localized(
            "home_live_priority_title",
            fallback: "Happening now"
        )
    }

    static var exploreMoreTitle: String {
        HomeModelAdapter.localized(
            "home_zone_explore_more_title",
            fallback: "More on Pure Pets"
        )
    }

    static var exploreMoreSubtitle: String {
        HomeModelAdapter.localized(
            "home_zone_explore_more_subtitle",
            fallback: "Everything else, one tap away"
        )
    }

    static var petEmptyTitle: String {
        HomeModelAdapter.localized(
            "home_pet_profile_empty_compact_title",
            fallback: "Build your pet profile"
        )
    }

    static var petEmptySubtitle: String {
        HomeModelAdapter.localized(
            "home_pet_profile_empty_compact_subtitle",
            fallback: "Keep care details, vaccines, and reminders together."
        )
    }

    static var petEmptyHint: String {
        HomeModelAdapter.localized(
            "home_pet_profile_create_hint",
            fallback: "Opens pet profiles so you can add your first pet"
        )
    }

    static var petOpenProfile: String {
        HomeModelAdapter.localized(
            "home_pet_profile_open_cta",
            fallback: "Open pet profile"
        )
    }

    static var careGatewayTitle: String {
        HomeModelAdapter.localized(
            "home_premium_care_title",
            fallback: "Medicines and vets"
        )
    }

    static var careGatewaySubtitle: String {
        HomeModelAdapter.localized(
            "home_premium_care_subtitle",
            fallback: "Pet medicine and veterinarian care in one refined place."
        )
    }

    static var exploreMarketplace: String {
        HomeModelAdapter.localized(
            "home_pulse_explore_market",
            fallback: "Explore marketplace"
        )
    }

    static var orders: String {
        HomeModelAdapter.localized("home_pulse_orders", fallback: "Orders")
    }

    static var search: String {
        HomeModelAdapter.localized(
            "home_pulse_search_a11y",
            fallback: "Search Pure Pets"
        )
    }

    static var adoption: String {
        HomeModelAdapter.localized("home_quick_action_adopt", fallback: "Adopt")
    }

    static var myPet: String {
        HomeModelAdapter.localized(
            "home_pulse_priority_my_pet",
            fallback: "My pet"
        )
    }
}
