import SwiftUI
import UIKit

// MARK: - Shared metrics

/// One coherent geometry vocabulary for the Home zone family, so the marketing
/// stage, partner feature, launcher, and gateways share the same rhythm instead
/// of each inventing its own numbers.
enum PPHomeZoneMetrics {
    static let stageMediaHeight: CGFloat = 176
    static let stageMediaAccessibilityHeight: CGFloat = 132
    static let marketplaceMediaAccessibilityHeight: CGFloat = 248
    static let marketplaceMediaAccessibilityMediumHeight: CGFloat = 296
    static let marketplaceMediaAccessibilityLargeHeight: CGFloat = 328
    static let marketplaceMediaAccessibilityExtraLargeHeight: CGFloat = 368
    static let marketplaceMediaAccessibilityMaximumHeight: CGFloat = 400
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
    let marketplaceSignals: HomeMarketplaceSignals
    let onSelect: (Int) -> Void
    let onPrimary: (HomeHeroPage) -> Void
    let onSecondary: (HomeHeroPage) -> Void
    let onInteractionChanged: (Bool) -> Void
    let onMarketplaceSignal: (HomeMarketplaceSignalKind) -> Void

    init(
        pages: [HomeHeroPage],
        selectedIndex: Int,
        discloseCampaign: Bool,
        marketplaceSignals: HomeMarketplaceSignals = HomeMarketplaceSignals(),
        onSelect: @escaping (Int) -> Void,
        onPrimary: @escaping (HomeHeroPage) -> Void,
        onSecondary: @escaping (HomeHeroPage) -> Void,
        onInteractionChanged: @escaping (Bool) -> Void,
        onMarketplaceSignal: @escaping (HomeMarketplaceSignalKind) -> Void = { _ in }
    ) {
        self.pages = pages
        self.selectedIndex = selectedIndex
        self.discloseCampaign = discloseCampaign
        self.marketplaceSignals = marketplaceSignals
        self.onSelect = onSelect
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
        self.onInteractionChanged = onInteractionChanged
        self.onMarketplaceSignal = onMarketplaceSignal
    }

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
        .modifier(
            PPHomeStageAccessibilityPaging(
                enabled: pages.count > 1,
                isRightToLeft: layoutDirection == .rightToLeft,
                nextTitle: nextActionTitle,
                previousTitle: previousActionTitle,
                onAdvance: advance
            )
        )
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
                PPHomeStageArtwork(
                    page: page,
                    accent: accent,
                    marketplaceSignals: marketplaceSignals,
                    onMarketplaceSignal: onMarketplaceSignal
                )
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
                PPHomeStageArtwork(
                    page: page,
                    accent: accent,
                    marketplaceSignals: marketplaceSignals,
                    onMarketplaceSignal: onMarketplaceSignal
                )
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
        .accessibilityHidden(!isMarketplace(page))
    }

    private var mediaHeight: CGFloat {
        guard dynamicTypeSize.isAccessibilitySize else {
            return PPHomeZoneMetrics.stageMediaHeight
        }
        guard let page, isMarketplace(page) else {
            return PPHomeZoneMetrics.stageMediaAccessibilityHeight
        }
        switch dynamicTypeSize {
        case .accessibility5:
            return PPHomeZoneMetrics.marketplaceMediaAccessibilityMaximumHeight
        case .accessibility4:
            return PPHomeZoneMetrics.marketplaceMediaAccessibilityExtraLargeHeight
        case .accessibility3:
            return PPHomeZoneMetrics.marketplaceMediaAccessibilityLargeHeight
        case .accessibility2:
            return PPHomeZoneMetrics.marketplaceMediaAccessibilityMediumHeight
        default:
            return PPHomeZoneMetrics.marketplaceMediaAccessibilityHeight
        }
    }

    private func isMarketplace(_ page: HomeHeroPage) -> Bool {
        if case .marketplace = page.kind { return true }
        return false
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
            .accessibilityHidden(isMarketplace(page))

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
/// Marketplace pages use a full-band, finite Living Ledger scene. Other page
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
    let marketplaceSignals: HomeMarketplaceSignals
    let onMarketplaceSignal: (HomeMarketplaceSignalKind) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection

    @ViewBuilder
    var body: some View {
        if isMarketplace {
            PPHomeMarketplaceLivingLedger(
                page: page,
                accent: accent,
                marketplaceSymbol: asset.primarySymbol,
                signals: marketplaceSignals,
                onSelectSignal: onMarketplaceSignal
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

/// The Living Ledger keeps one selected-category identity and three live facts
/// in one composition. It intentionally has no category plate, orbital diagram,
/// individual count cards, or horizontal accessibility rail.
private enum PPHomeLivingLedgerMetrics {
    /// The category artwork is one proportional unit: outline, wash, and pet.
    /// Scaling its width, height, and portrait together prevents layer drift.
    static let standardArtworkScale: CGFloat = 1.125
    static let standardIdentityMaximum: CGFloat =
        112 * standardArtworkScale
    static let standardIdentityMinimum: CGFloat =
        92 * standardArtworkScale
    static let compactIdentityWidth: CGFloat =
        64 * standardArtworkScale
    static let compactWidthBreakpoint: CGFloat = 332
    /// Three full controls plus two Increased Contrast separators.
    static let standardLedgerHeight: CGFloat =
        (PPHomeZoneMetrics.minimumTarget * 3) + 3
    static let standardCategoryHeight: CGFloat =
        standardLedgerHeight * standardArtworkScale
    static let standardOuterInset: CGFloat = PPSpace.base
    static let accessibilityIdentityHeight: CGFloat = 64
    static let portraitMaximum: CGFloat = 94 * standardArtworkScale
    static let accessibilityPortraitMaximum: CGFloat = 58
    static let maximumReadableWidth: CGFloat = 480
    static let ledgerCorner: CGFloat = PPCorner.card
    static let rowHorizontalPadding: CGFloat = PPSpace.md
    static let nodeSide: CGFloat = 28
    static let indexLineWidth: CGFloat = 2
}

/// Pure Pets' pet-first live index. The category portrait establishes scope at
/// a glance; one continuous ledger exposes products, services, and listings.
/// Each row retains its existing refresh/retry action, while navigation remains
/// owned by the hero's primary and secondary actions below.
@available(iOS 15.0, *)
private struct PPHomeMarketplaceLivingLedger: View {
    let page: HomeHeroPage
    let accent: Color
    let marketplaceSymbol: String
    let signals: HomeMarketplaceSignals
    let onSelectSignal: (HomeMarketplaceSignalKind) -> Void

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
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityConstellation
            } else {
                standardConstellation
            }
        }
        .task(id: motionKey) { await runEntrance() }
        .task(id: signals.categoryID) { requestIdleSignals() }
        .onDisappear(perform: settleWithoutAnimation)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Living Ledger composition

    private var standardConstellation: some View {
        GeometryReader { proxy in
            let geometry = StandardGeometry(size: proxy.size)

            HStack(alignment: .top, spacing: geometry.horizontalGap) {
                categoryAperture(
                    width: geometry.identityWidth,
                    height: geometry.categoryHeight,
                    portraitMaximum: PPHomeLivingLedgerMetrics.portraitMaximum
                )

                signalLedger(
                    height: geometry.ledgerHeight,
                    compactRows: geometry.usesCompactRows
                )
            }
            .frame(
                width: geometry.contentWidth,
                height: geometry.rowHeight,
                alignment: .top
            )
            .position(
                x: geometry.contentCenterX(
                    isRightToLeft: isRightToLeft
                ),
                y: geometry.topAlignedCenterY
            )
        }
    }

    /// Accessibility sizes keep every fact in the first look. The portrait
    /// becomes a compact scope header and the ledger consumes the remaining
    /// height; no control is hidden behind horizontal scrolling.
    private var accessibilityConstellation: some View {
        GeometryReader { proxy in
            let geometry = AccessibilityGeometry(size: proxy.size)

            VStack(spacing: PPSpace.sm) {
                categoryAperture(
                    width: geometry.contentWidth,
                    height: geometry.identityHeight,
                    portraitMaximum:
                        PPHomeLivingLedgerMetrics.accessibilityPortraitMaximum
                )

                signalLedger(
                    height: geometry.ledgerHeight,
                    compactRows: false
                )
            }
            .frame(
                width: geometry.contentWidth,
                height: geometry.readableHeight
            )
            .position(
                x: proxy.size.width / 2,
                y: geometry.opticalCenterY
            )
        }
    }

    // MARK: - Category aperture

    /// An open portrait aperture replaces the old closed category plate. The
    /// accent is category identity only: a quiet wash and one shared seam that
    /// visually scopes the adjacent live ledger.
    private func categoryAperture(
        width: CGFloat,
        height: CGFloat,
        portraitMaximum: CGFloat
    ) -> some View {
        let portraitSide = min(
            portraitMaximum,
            max(44, min(width * 0.84, height * 0.82))
        )
        let apertureShape = RoundedRectangle(
            cornerRadius: min(PPCorner.large, height * 0.34),
            style: .continuous
        )
        let outlineLineWidth: CGFloat =
            contrast == .increased ? 2 : 1.25

        return ZStack {
            apertureShape
                .inset(by: outlineLineWidth / 2)
                .trim(from: 0.08, to: 0.72)
                .stroke(
                    accent.opacity(
                        contrast == .increased
                            ? 0.78
                            : (colorScheme == .dark ? 0.48 : 0.34)
                    ),
                    style: StrokeStyle(
                        lineWidth: outlineLineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .scaleEffect(x: isRightToLeft ? -1 : 1, y: 1)

            // The wash and category art share one exact center inside the
            // outline. Their Z-order keeps the soft wash directly beneath the
            // animal without introducing independent alignment coordinates.
            ZStack {
                Ellipse()
                    .fill(accent.opacity(identityWashOpacity))
                    .frame(
                        width: portraitSide * 0.76,
                        height: portraitSide * 0.92
                    )

                identityArtwork(side: portraitSide)
            }
            .frame(width: portraitSide, height: portraitSide)

            Capsule()
                .fill(accent.opacity(contrast == .increased ? 0.92 : 0.68))
                .frame(
                    width: contrast == .increased ? 3 : 2,
                    height: max(PPSpace.xl, height * 0.34)
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .trailing
                )
                .scaleEffect(
                    y: seamPresented ? 1 : 0.08,
                    anchor: .center
                )
                .opacity(seamPresented ? 1 : 0.18)
        }
        .frame(width: width, height: height)
        .opacity(identityPresented ? 1 : 0.58)
        .offset(x: identityPresented ? 0 : logicalOffset(-PPSpace.sm))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(categoryAccessibilitySummary)
        .accessibilityAddTraits(.isHeader)
        .accessibilitySortPriority(4)
    }

    private var identityWashOpacity: Double {
        if contrast == .increased { return 0.16 }
        if reduceTransparency {
            return colorScheme == .dark ? 0.24 : 0.15
        }
        return colorScheme == .dark ? 0.20 : 0.10
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
            categoryArtworkPlaceholder(side: side)
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
            Image(systemName: marketplaceSymbol)
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

    private var categoryAccessibilitySummary: String {
        page.accessibilityLabel ?? page.title
    }

    // MARK: - Continuous availability ledger

    private func signalLedger(
        height: CGFloat,
        compactRows: Bool
    ) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: PPHomeLivingLedgerMetrics.ledgerCorner,
            style: .continuous
        )

        return ZStack(alignment: .leading) {
            shape.fill(Color.homeRaisedSurface)

            shape.fill(
                accent.opacity(
                    reduceTransparency
                        ? (colorScheme == .dark ? 0.10 : 0.05)
                        : (colorScheme == .dark ? 0.07 : 0.025)
                )
            )

            ledgerIndexLine(compactRows: compactRows)

            VStack(spacing: 0) {
                ForEach(HomeMarketplaceSignalKind.allCases, id: \.self) { kind in
                    signalRow(kind: kind, compactRows: compactRows)

                    if kind != .advertisements {
                        ledgerDivider(compactRows: compactRows)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                contrast == .increased
                    ? Color.ppTextPrimary.opacity(0.78)
                    : Color.ppSurfaceBorder.opacity(
                        colorScheme == .dark ? 0.68 : 0.86
                    ),
                lineWidth: contrast == .increased ? 1.5 : 1
            )
        }
        .accessibilityElement(children: .contain)
    }

    private func ledgerIndexLine(compactRows: Bool) -> some View {
        Capsule()
            .fill(
                accent.opacity(
                    contrast == .increased
                        ? 0.82
                        : (colorScheme == .dark ? 0.46 : 0.34)
                )
            )
            .frame(width: PPHomeLivingLedgerMetrics.indexLineWidth)
            .frame(maxHeight: .infinity)
            .padding(.vertical, PPHomeLivingLedgerMetrics.nodeSide / 2)
            .padding(
                .leading,
                rowHorizontalPadding(compactRows: compactRows)
                    + (PPHomeLivingLedgerMetrics.nodeSide / 2)
                    - (PPHomeLivingLedgerMetrics.indexLineWidth / 2)
            )
            .scaleEffect(
                y: seamPresented ? 1 : 0.04,
                anchor: .top
            )
            .opacity(seamPresented ? 1 : 0.16)
            .accessibilityHidden(true)
    }

    private func ledgerDivider(compactRows: Bool) -> some View {
        Rectangle()
            .fill(
                contrast == .increased
                    ? Color.ppTextPrimary.opacity(0.28)
                    : Color.ppSurfaceBorder.opacity(
                        colorScheme == .dark ? 0.56 : 0.74
                    )
            )
            .frame(height: contrast == .increased ? 1.5 : 1)
            .padding(
                .leading,
                rowHorizontalPadding(compactRows: compactRows)
                    + PPHomeLivingLedgerMetrics.nodeSide
                    + rowSpacing(compactRows: compactRows)
            )
            .accessibilityHidden(true)
    }

    private func signalRow(
        kind: HomeMarketplaceSignalKind,
        compactRows: Bool
    ) -> some View {
        let tone = routeTone(for: kind)

        return Button {
            onSelectSignal(kind)
        } label: {
            HStack(spacing: rowSpacing(compactRows: compactRows)) {
                signalNode(for: kind, tone: tone)

                Text(
                    signalDisplayLabel(
                        for: kind,
                        compactRows: compactRows
                    )
                )
                    .font(HomeFont.subheadline())
                    .foregroundStyle(Color.homeTextSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(
                        dynamicTypeSize.isAccessibilitySize || compactRows
                            ? 2
                            : 1
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                signalValue(for: kind, tone: tone)
                    .frame(
                        minWidth: dynamicTypeSize.isAccessibilitySize ? 52 : 44,
                        alignment: .trailing
                    )
                    .id(signalValueIdentity(for: kind))
                    .transition(.opacity)
                    .animation(
                        motionSuppressed
                            ? nil
                            : .easeOut(duration: 0.18),
                        value: signalValueIdentity(for: kind)
                    )
            }
            .padding(
                .horizontal,
                rowHorizontalPadding(compactRows: compactRows)
            )
            .frame(
                maxWidth: .infinity,
                minHeight: PPHomeZoneMetrics.minimumTarget,
                maxHeight: .infinity,
                alignment: .leading
            )
            .contentShape(Rectangle())
            .background {
                Rectangle()
                    .fill(
                        tone.opacity(
                            signalRowPresented(kind)
                                ? rowTintOpacity(for: kind)
                                : 0
                        )
                    )
            }
        }
        .buttonStyle(PPHomeSurfacePressStyle(reduceMotion: motionSuppressed))
        .opacity(
            signals.categoryID == nil
                ? (contrast == .increased ? 0.82 : 0.62)
                : (signalRowPresented(kind) ? 1 : 0.26)
        )
        .offset(
            x: signalRowPresented(kind)
                ? 0
                : logicalOffset(-PPSpace.sm)
        )
        .disabled(
            signals.categoryID == nil || isSignalLoading(kind)
        )
        .accessibilityLabel(signalLabel(for: kind))
        .accessibilityValue(accessibilityValue(for: kind))
        .accessibilityHint(signalHint(for: kind))
        .accessibilitySortPriority(accessibilityPriority(for: kind))
    }

    private func rowHorizontalPadding(compactRows: Bool) -> CGFloat {
        compactRows ? PPSpace.sm : PPHomeLivingLedgerMetrics.rowHorizontalPadding
    }

    private func rowSpacing(compactRows: Bool) -> CGFloat {
        compactRows ? PPSpace.xs : PPSpace.sm
    }

    private func signalNode(
        for kind: HomeMarketplaceSignalKind,
        tone: Color
    ) -> some View {
        ZStack {
            Circle()
                .fill(Color.homeRaisedSurface)

            Circle()
                .fill(tone.opacity(nodeTintOpacity(for: kind)))

            Circle()
                .strokeBorder(
                    contrast == .increased
                        ? Color.ppTextPrimary.opacity(0.76)
                        : tone.opacity(nodeBorderOpacity(for: kind)),
                    lineWidth: contrast == .increased ? 1.5 : 1
                )

            signalIcon(
                for: kind,
                glyphSize: PPHomeLivingLedgerMetrics.nodeSide * 0.46,
                tone: tone
            )
        }
        .frame(
            width: PPHomeLivingLedgerMetrics.nodeSide,
            height: PPHomeLivingLedgerMetrics.nodeSide
        )
        .accessibilityHidden(true)
    }

    private func rowTintOpacity(
        for kind: HomeMarketplaceSignalKind
    ) -> Double {
        if reduceTransparency {
            return colorScheme == .dark ? 0.10 : 0.045
        }
        switch signals.value(for: kind) {
        case .available: return colorScheme == .dark ? 0.075 : 0.025
        case .failed: return colorScheme == .dark ? 0.12 : 0.045
        case .loading: return colorScheme == .dark ? 0.06 : 0.018
        case .idle: return 0
        }
    }

    private func nodeTintOpacity(
        for kind: HomeMarketplaceSignalKind
    ) -> Double {
        if reduceTransparency {
            return colorScheme == .dark ? 0.24 : 0.16
        }
        switch signals.value(for: kind) {
        case .available: return colorScheme == .dark ? 0.24 : 0.14
        case .failed: return colorScheme == .dark ? 0.30 : 0.20
        case .loading: return colorScheme == .dark ? 0.18 : 0.11
        case .idle: return colorScheme == .dark ? 0.14 : 0.08
        }
    }

    private func nodeBorderOpacity(
        for kind: HomeMarketplaceSignalKind
    ) -> Double {
        switch signals.value(for: kind) {
        case .available: return colorScheme == .dark ? 0.70 : 0.46
        case .failed: return colorScheme == .dark ? 0.88 : 0.64
        case .loading: return colorScheme == .dark ? 0.58 : 0.38
        case .idle: return colorScheme == .dark ? 0.42 : 0.28
        }
    }

    private func signalIcon(
        for kind: HomeMarketplaceSignalKind,
        glyphSize: CGFloat,
        tone: Color
    ) -> some View {
        let symbol: String
        switch kind {
        case .marketplace: symbol = marketplaceSymbol
        case .services: symbol = "hands.sparkles.fill"
        case .advertisements: symbol = "pawprint.fill"
        }

        return Image(systemName: symbol)
            .font(.system(size: glyphSize, weight: .bold))
            .foregroundStyle(tone)
    }

    private func routeTone(
        for destination: HomeMarketplaceSignalKind
    ) -> Color {
        switch destination {
        case .marketplace: return Color.ppQuickActionShopping
        case .services: return Color.ppCareAccent
        case .advertisements: return Color.ppAdoptionAccent
        }
    }

    @ViewBuilder
    private func signalValue(
        for kind: HomeMarketplaceSignalKind,
        tone: Color
    ) -> some View {
        switch signals.value(for: kind) {
        case .idle:
            if signals.categoryID == nil {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.homeTextSecondary)
                    .accessibilityHidden(true)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(tone)
                    .scaleEffect(0.78)
                    .frame(height: 20)
            }
        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(tone)
                .scaleEffect(0.78)
                .frame(height: 20)
        case let .available(count):
            Text(localizedNumber(max(0, count)))
                .font(HomeFont.title2())
                .monospacedDigit()
                .foregroundStyle(Color.homeTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        case .failed:
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tone)
                .accessibilityHidden(true)
        }
    }

    @MainActor
    private func requestIdleSignals() {
        guard signals.categoryID != nil else { return }
        for kind in HomeMarketplaceSignalKind.allCases
        where signals.value(for: kind) == .idle {
            onSelectSignal(kind)
        }
    }

    private func signalLabel(
        for kind: HomeMarketplaceSignalKind
    ) -> String {
        switch kind {
        case .marketplace: return PPHomeZoneCopy.marketplaceSignalItemsLabel
        case .services: return PPHomeZoneCopy.marketplaceSignalServicesLabel
        case .advertisements: return PPHomeZoneCopy.marketplaceSignalAdsLabel
        }
    }

    /// Compact copy is presentation-only. Assistive technologies retain the
    /// complete marketplace terminology through `signalLabel(for:)`.
    private func signalDisplayLabel(
        for kind: HomeMarketplaceSignalKind,
        compactRows: Bool
    ) -> String {
        guard compactRows else { return signalLabel(for: kind) }

        switch kind {
        case .marketplace:
            return PPHomeZoneCopy.marketplaceSignalItemsCompactLabel
        case .services:
            return PPHomeZoneCopy.marketplaceSignalServicesCompactLabel
        case .advertisements:
            return PPHomeZoneCopy.marketplaceSignalAdsCompactLabel
        }
    }

    /// Stable per-state identity makes a completed load or retry crossfade in
    /// place without fake count-up motion or geometry changes.
    private func signalValueIdentity(
        for kind: HomeMarketplaceSignalKind
    ) -> String {
        switch signals.value(for: kind) {
        case .idle:
            return signals.categoryID == nil ? "idle-no-category" : "idle"
        case .loading:
            return "loading"
        case let .available(count):
            return "available-\(max(0, count))"
        case .failed:
            return "failed"
        }
    }

    private func accessibilityValue(
        for kind: HomeMarketplaceSignalKind
    ) -> String {
        let value: String
        switch signals.value(for: kind) {
        case .idle:
            value = signals.categoryID == nil
                ? PPHomeZoneCopy.marketplaceSignalCategoryRequired
                : PPHomeZoneCopy.marketplaceSignalIdle
        case .loading:
            value = PPHomeZoneCopy.marketplaceSignalLoading
        case let .available(count):
            value = String(
                format: PPHomeZoneCopy.marketplaceSignalAvailableFormat,
                locale: Locale(identifier: Language.currentLanguageCode() ?? "ar"),
                Int64(max(0, count))
            )
        case .failed:
            value = PPHomeZoneCopy.marketplaceSignalUnavailableRetry
        }
        return value
    }

    private var signalHint: String {
        PPHomeZoneCopy.marketplaceSignalLiveCountHint
    }

    private func signalHint(
        for kind: HomeMarketplaceSignalKind
    ) -> String {
        if signals.categoryID == nil {
            return PPHomeZoneCopy.marketplaceSignalCategoryRequired
        }
        if isSignalLoading(kind) {
            return PPHomeZoneCopy.marketplaceSignalLoading
        }
        return signalHint
    }

    private func isSignalLoading(
        _ kind: HomeMarketplaceSignalKind
    ) -> Bool {
        if case .loading = signals.value(for: kind) {
            return true
        }
        return false
    }

    private func localizedNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(
            identifier: Language.currentLanguageCode() ?? "ar"
        )
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func accessibilityPriority(
        for kind: HomeMarketplaceSignalKind
    ) -> Double {
        switch kind {
        case .marketplace: return 3
        case .services: return 2
        case .advertisements: return 1
        }
    }

    // MARK: - Required finite causal motion

    private struct MotionKey: Equatable {
        let identity: String
        let suppressed: Bool
    }

    private var motionKey: MotionKey {
        MotionKey(identity: artworkIdentity, suppressed: motionSuppressed)
    }

    /// Installs final geometry immediately, then reveals the category scope,
    /// shared seam, and real signal rows in semantic order. The task is tied to
    /// the selected-category identity, so a category change cancels and
    /// retargets the sequence without owning data or navigation state.
    @MainActor
    private func runEntrance() async {
        guard !reduceMotion,
              !motionSuppressed,
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

        guard await pauseForNextPhase(55_000_000) else { return }
        withAnimation(.easeOut(duration: 0.20)) {
            phase = .seam
        }

        guard await pauseForNextPhase(50_000_000) else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            phase = .marketplace
        }

        guard await pauseForNextPhase(45_000_000) else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            phase = .services
        }

        guard await pauseForNextPhase(45_000_000) else { return }
        withAnimation(.easeOut(duration: 0.20)) {
            phase = .settled
        }
        lastPresentedIdentity = artworkIdentity
    }

    private func pauseForNextPhase(_ nanoseconds: UInt64) async -> Bool {
        do {
            try await Task<Never, Never>.sleep(nanoseconds: nanoseconds)
        } catch {
            return false
        }
        return !Task.isCancelled
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

    private var seamPresented: Bool {
        presentationPhase.rawValue >= Phase.seam.rawValue
    }

    private func signalRowPresented(
        _ kind: HomeMarketplaceSignalKind
    ) -> Bool {
        switch kind {
        case .marketplace:
            return presentationPhase.rawValue >= Phase.marketplace.rawValue
        case .services:
            return presentationPhase.rawValue >= Phase.services.rawValue
        case .advertisements:
            return presentationPhase == .settled
        }
    }

    private var motionSuppressed: Bool {
        reduceMotion ||
            voiceOverEnabled ||
            switchControlEnabled ||
            scenePhase != .active
    }

    /// `HomeHeroPage.id` intentionally stays stable for marketplace paging.
    /// This private presentation key retargets only the visual scene when the
    /// selected MainKind changes.
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
        case seam
        case marketplace
        case services
        case settled
    }

    private struct StandardGeometry {
        let size: CGSize

        private var availableHeight: CGFloat {
            max(
                0,
                size.height - PPHomeLivingLedgerMetrics.standardOuterInset
            )
        }

        var topAlignedCenterY: CGFloat {
            PPHomeLivingLedgerMetrics.standardOuterInset + (rowHeight / 2)
        }

        var contentWidth: CGFloat {
            min(
                PPHomeLivingLedgerMetrics.maximumReadableWidth,
                max(
                    0,
                    size.width -
                        (PPHomeLivingLedgerMetrics.standardOuterInset * 2)
                )
            )
        }

        func contentCenterX(isRightToLeft: Bool) -> CGFloat {
            let outerInset = PPHomeLivingLedgerMetrics.standardOuterInset
            return isRightToLeft
                ? outerInset + (contentWidth / 2)
                : size.width - outerInset - (contentWidth / 2)
        }

        var categoryHeight: CGFloat {
            min(
                PPHomeLivingLedgerMetrics.standardCategoryHeight,
                availableHeight
            )
        }

        var ledgerHeight: CGFloat {
            min(
                PPHomeLivingLedgerMetrics.standardLedgerHeight,
                availableHeight
            )
        }

        var rowHeight: CGFloat { max(categoryHeight, ledgerHeight) }

        var identityWidth: CGFloat {
            if usesCompactRows {
                return PPHomeLivingLedgerMetrics.compactIdentityWidth
            }
            return min(
                PPHomeLivingLedgerMetrics.standardIdentityMaximum,
                max(
                    PPHomeLivingLedgerMetrics.standardIdentityMinimum,
                    contentWidth *
                        (0.32 *
                            PPHomeLivingLedgerMetrics.standardArtworkScale)
                )
            )
        }

        var usesCompactRows: Bool {
            contentWidth < PPHomeLivingLedgerMetrics.compactWidthBreakpoint
        }

        var horizontalGap: CGFloat {
            usesCompactRows ? PPSpace.sm : PPSpace.md
        }
    }

    private struct AccessibilityGeometry {
        let size: CGSize

        var readableHeight: CGFloat {
            max(0, size.height - PPSpace.xl)
        }

        var opticalCenterY: CGFloat { readableHeight / 2 }

        var contentWidth: CGFloat {
            min(
                PPHomeLivingLedgerMetrics.maximumReadableWidth,
                max(0, size.width - (PPSpace.base * 2))
            )
        }

        var identityHeight: CGFloat {
            min(
                PPHomeLivingLedgerMetrics.accessibilityIdentityHeight,
                max(52, readableHeight * 0.25)
            )
        }

        var ledgerHeight: CGFloat {
            max(
                PPHomeLivingLedgerMetrics.standardLedgerHeight,
                readableHeight - identityHeight - PPSpace.sm
            )
        }
    }
}

/// Keeps carousel-only accessibility actions off the single-page marketplace
/// hero so its three live-signal buttons are the media band's only controls.
@available(iOS 15.0, *)
private struct PPHomeStageAccessibilityPaging: ViewModifier {
    let enabled: Bool
    let isRightToLeft: Bool
    let nextTitle: String
    let previousTitle: String
    let onAdvance: (Int) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .accessibilityAction(named: Text(nextTitle)) { onAdvance(1) }
                .accessibilityAction(named: Text(previousTitle)) { onAdvance(-1) }
                .accessibilityScrollAction { edge in
                    switch edge {
                    case .leading:
                        onAdvance(isRightToLeft ? 1 : -1)
                    case .trailing:
                        onAdvance(isRightToLeft ? -1 : 1)
                    default:
                        break
                    }
                }
        } else {
            content
        }
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

    static var marketplaceSignalItemsLabel: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_marketplace_items_label",
            fallback: "Marketplace items"
        )
    }

    static var marketplaceSignalServicesLabel: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_services_label",
            fallback: "Services"
        )
    }

    static var marketplaceSignalAdsLabel: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_pet_ads_label",
            fallback: "Pet listings"
        )
    }

    static var marketplaceSignalItemsCompactLabel: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_marketplace_items_compact_label",
            fallback: "Items"
        )
    }

    static var marketplaceSignalServicesCompactLabel: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_services_compact_label",
            fallback: "Services"
        )
    }

    static var marketplaceSignalAdsCompactLabel: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_pet_ads_compact_label",
            fallback: "Listings"
        )
    }

    static var marketplaceSignalLiveCountHint: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_live_count_hint",
            fallback: "Shows how many are available now for the selected category. Tap to refresh."
        )
    }

    static var marketplaceSignalIdle: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_idle",
            fallback: "Preparing count…"
        )
    }

    static var marketplaceSignalCategoryRequired: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_category_required",
            fallback: "Choose a pet category to load live counts."
        )
    }

    static var marketplaceSignalLoading: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_loading",
            fallback: "Loading count…"
        )
    }

    static var marketplaceSignalAvailableFormat: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_available_count_format",
            fallback: "%ld available now"
        )
    }

    static var marketplaceSignalUnavailableRetry: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_unavailable_retry",
            fallback: "Count unavailable. Tap to try again."
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
