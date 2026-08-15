import SwiftUI
import UIKit

// MARK: - Shared metrics

/// One coherent geometry vocabulary for the Home zone family, so the marketing
/// stage, partner feature, launcher, and gateways share the same rhythm instead
/// of each inventing its own numbers.
enum PPHomeZoneMetrics {
    static let stageMediaHeight: CGFloat = 176
    /// The marketplace ledger is denser than photographic marketing media.
    static let marketplaceStageMediaHeight: CGFloat = 160
    static let stageMediaAccessibilityHeight: CGFloat = 132
    static let marketplaceMediaAccessibilityHeight: CGFloat = 248
    static let marketplaceMediaAccessibilityMediumHeight: CGFloat = 296
    static let marketplaceMediaAccessibilityLargeHeight: CGFloat = 328
    static let marketplaceMediaAccessibilityExtraLargeHeight: CGFloat = 368
    static let marketplaceMediaAccessibilityMaximumHeight: CGFloat = 400
    static let partnerMediaSide: CGFloat = 104
    static let minimumTarget: CGFloat = 44
    static let gatewaySymbolPlate: CGFloat = 42
    static let statusSymbolPlate: CGFloat = 46
    static let pageDot: CGFloat = 6
    static let pageDotSelected: CGFloat = 18
}

/// Shared geometry for every standalone Home section header.
///
/// The 40-point section break is resolved by `HomeView` against the preceding
/// row's existing bottom inset. Keeping the remaining measurements here makes
/// the copy rhythm and action treatment identical across config-driven zones.
enum PPHomeSectionHeaderMetrics {
    static let sectionTopSpacing = PPSpace.xxxl
    static let titleSubtitleSpacing = PPSpace.md
    static let contentSpacing = PPSpace.xl
    static let actionTargetHeight: CGFloat = 44
    static let actionVisualHeight: CGFloat = 36
    static let actionHorizontalInset = PPSpace.md
    static let actionLabelSpacing = PPSpace.xs
    static let activationDebounce: CFTimeInterval = 0.22
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
    let titleAccent: Color?
    let actionTitle: String?
    let action: (() -> Void)?
    let actionIconName: String
    let actionAccessibilityIdentifier: String?
    let actionAccessibilityValue: String?
    let actionGeneratesHaptic: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        titleAccent: Color? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        actionIconName: String = "chevron.forward",
        actionAccessibilityIdentifier: String? = nil,
        actionAccessibilityValue: String? = nil,
        actionGeneratesHaptic: Bool = false
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.titleAccent = titleAccent
        self.actionTitle = actionTitle
        self.action = action
        self.actionIconName = actionIconName
        self.actionAccessibilityIdentifier = actionAccessibilityIdentifier
        self.actionAccessibilityValue = actionAccessibilityValue
        self.actionGeneratesHaptic = actionGeneratesHaptic
    }

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        return Group {
            if stacked {
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    copy
                    if let actionTitle, let action {
                        actionButton(actionTitle, action)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: PPSpace.md) {
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
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow)
                    .font(HomeFont.bold(11))
                    .foregroundStyle(Color.ppAccentText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(
                alignment: .leading,
                spacing: PPHomeSectionHeaderMetrics.titleSubtitleSpacing
            ) {
                HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
                    Text(title)
                        .font(HomeFont.title2())
                        .foregroundStyle(Color.homeTextPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    if let titleAccent {
                        Capsule(style: .continuous)
                            .fill(titleAccent)
                            .frame(width: PPSpace.lg, height: PPSpace.xs)
                            .accessibilityHidden(true)
                            .allowsHitTesting(false)
                    }
                }

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(HomeFont.footnote())
                        .foregroundStyle(Color.homeTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionButton(
        _ title: String,
        _ action: @escaping () -> Void
    ) -> some View {
        PPHomeSectionActionButton(
            title: title,
            iconName: actionIconName,
            accessibilityIdentifier: actionAccessibilityIdentifier,
            accessibilityValue: actionAccessibilityValue,
            generatesHaptic: actionGeneratesHaptic,
            action: action
        )
    }
}

@available(iOS 15.0, *)
private struct PPHomeSectionActionButton: View {
    let title: String
    let iconName: String
    let accessibilityIdentifier: String?
    let accessibilityValue: String?
    let generatesHaptic: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastActivationTimestamp: CFTimeInterval = 0

    @ViewBuilder
    var body: some View {
        if let accessibilityIdentifier {
            actionControl
                .accessibilityIdentifier(accessibilityIdentifier)
                .accessibilityValue(accessibilityValue ?? "")
        } else {
            actionControl
        }
    }

    private var actionControl: some View {
        Button(action: activate) {
            HStack(spacing: PPHomeSectionHeaderMetrics.actionLabelSpacing) {
                Text(title)
                    .font(HomeFont.bold(14))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .bold))
                    .flipsForRightToLeftLayoutDirection(true)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.ppAccentText)
            .padding(
                .horizontal,
                PPHomeSectionHeaderMetrics.actionHorizontalInset
            )
            .frame(
                minHeight: PPHomeSectionHeaderMetrics.actionVisualHeight
            )
            .fixedSize(horizontal: true, vertical: false)
            .modifier(PPHomeSectionActionSurfaceModifier())
        }
        .buttonStyle(
            PPHomeSectionActionPressStyle(reduceMotion: reduceMotion)
        )
        .frame(minHeight: PPHomeSectionHeaderMetrics.actionTargetHeight)
        .contentShape(Rectangle())
        .accessibilityLabel(title)
    }

    private func activate() {
        let now = CACurrentMediaTime()
        guard now - lastActivationTimestamp >=
                PPHomeSectionHeaderMetrics.activationDebounce
        else { return }

        lastActivationTimestamp = now
        if generatesHaptic {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        action()
    }
}

@available(iOS 15.0, *)
private struct PPHomeSectionActionSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private var shape: Capsule {
        Capsule(style: .continuous)
    }

    private var tint: Color {
        Color.homeBrand.opacity(colorScheme == .dark ? 0.10 : 0.055)
    }

    private var stroke: Color {
        Color.homeBrand.opacity(
            contrast == .increased
                ? 0.54
                : (colorScheme == .dark ? 0.30 : 0.20)
        )
    }

    @ViewBuilder
    func body(content: Content) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency {
            content
                .glassEffect(
                    .regular.tint(tint).interactive(true),
                    in: shape
                )
                .overlay {
                    shape.stroke(
                        stroke,
                        lineWidth: contrast == .increased ? 1.5 : 1
                    )
                }
        } else {
            fallback(content)
        }
#else
        fallback(content)
#endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    shape.fill(Color.homeSurface)
                } else {
                    shape
                        .fill(.ultraThinMaterial)
                        .overlay {
                            shape.fill(tint)
                        }
                }
            }
            .overlay {
                shape.stroke(
                    stroke,
                    lineWidth: contrast == .increased ? 1.5 : 1
                )
            }
    }
}

@available(iOS 15.0, *)
private struct PPHomeSectionActionPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && !reduceMotion ? 0.975 : 1
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.14),
                value: configuration.isPressed
            )
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
                // Marketplace keeps its own stronger field so the centered
                // category plate reads against the hero background without
                // changing other Home marketing surfaces.
                cornerGlowOpacityScale: isMarketplace(page) ? 0.72 : 0.5
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
            guard let page, isMarketplace(page) else {
                return PPHomeZoneMetrics.stageMediaHeight
            }
            return PPHomeZoneMetrics.marketplaceStageMediaHeight
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
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.scenePhase) private var scenePhase

    @State private var plateMotionPhase: PlateMotionPhase = .staged
    @State private var plateMotionIdentity: String?
    @State private var lastPresentedPlateIdentity: String?

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
            .scaleEffect(plateFramePresented ? 1 : 0.985)
            .opacity(plateFramePresented ? 1 : 0.30)
        }
        .overlay(alignment: .topTrailing) {
            cornerIcon(symbol: asset.primarySymbol, side: 44)
                .scaleEffect(primaryIconPresented ? 1 : 0.88)
                .opacity(primaryIconPresented ? 1 : 0)
                .offset(
                    x: primaryIconHorizontalOffset,
                    y: primaryIconPresented ? -11 : -5
                )
        }
        .overlay(alignment: .bottomLeading) {
            cornerIcon(symbol: asset.secondarySymbol, side: 38)
                .scaleEffect(secondaryIconPresented ? 1 : 0.88)
                .opacity(secondaryIconPresented ? 1 : 0)
                .offset(
                    x: secondaryIconHorizontalOffset,
                    y: secondaryIconPresented ? 9 : 4
                )
        }
        .task(id: plateMotionKey) { await runPlateEntrance() }
        .accessibilityHidden(true)
    }

    // MARK: Plate motion

    private struct PlateMotionKey: Equatable {
        let identity: String
        let suppressed: Bool
        let sceneIsActive: Bool
    }

    private enum PlateMotionPhase: Int, Equatable {
        case staged
        case frame
        case primaryIcon
        case settled
    }

    private var plateIdentity: String {
        "\(page.id)|\(asset.name)|\(page.accentHex)"
    }

    private var plateMotionSuppressed: Bool {
        reduceMotion || voiceOverEnabled || switchControlEnabled
    }

    private var plateMotionKey: PlateMotionKey {
        PlateMotionKey(
            identity: plateIdentity,
            suppressed: plateMotionSuppressed,
            sceneIsActive: scenePhase == .active
        )
    }

    /// Accessibility and lifecycle suppression resolve synchronously so the
    /// first rendered frame is already static. A new data identity is staged
    /// before its task begins, preventing settled-to-staged rewinds.
    private var resolvedPlateMotionPhase: PlateMotionPhase {
        guard !plateMotionSuppressed, scenePhase == .active else {
            return .settled
        }
        guard plateMotionIdentity == plateIdentity else {
            return .staged
        }
        return plateMotionPhase
    }

    private var plateFramePresented: Bool {
        resolvedPlateMotionPhase.rawValue >= PlateMotionPhase.frame.rawValue
    }

    private var primaryIconPresented: Bool {
        resolvedPlateMotionPhase.rawValue >= PlateMotionPhase.primaryIcon.rawValue
    }

    private var secondaryIconPresented: Bool {
        resolvedPlateMotionPhase == .settled
    }

    private var primaryIconHorizontalOffset: CGFloat {
        logicalTrailingOffset(primaryIconPresented ? 12 : 6)
    }

    private var secondaryIconHorizontalOffset: CGFloat {
        -logicalTrailingOffset(secondaryIconPresented ? 12 : 6)
    }

    private func logicalTrailingOffset(_ distance: CGFloat) -> CGFloat {
        layoutDirection == .rightToLeft ? -distance : distance
    }

    @MainActor
    private func runPlateEntrance() async {
        guard !plateMotionSuppressed,
              scenePhase == .active,
              lastPresentedPlateIdentity != plateIdentity
        else {
            settlePlateWithoutAnimation()
            return
        }

        stagePlateWithoutAnimation()
        await Task.yield()
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.16)) {
            plateMotionPhase = .frame
        }

        guard await pauseForPlatePhase(40_000_000) else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            plateMotionPhase = .primaryIcon
        }

        guard await pauseForPlatePhase(45_000_000) else { return }
        withAnimation(.easeOut(duration: 0.20)) {
            plateMotionPhase = .settled
        }
        lastPresentedPlateIdentity = plateIdentity
    }

    private func pauseForPlatePhase(_ nanoseconds: UInt64) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
        } catch {
            return false
        }
        return !Task.isCancelled
    }

    private func stagePlateWithoutAnimation() {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            plateMotionIdentity = plateIdentity
            plateMotionPhase = .staged
        }
    }

    private func settlePlateWithoutAnimation() {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            plateMotionIdentity = plateIdentity
            plateMotionPhase = .settled
            lastPresentedPlateIdentity = plateIdentity
        }
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

/// The Species Portal keeps one dominant selected-category identity beside a
/// compact 2x2 ledger of its four real facts. The 42/58 split makes the animal
/// unmistakably primary while giving every value enough room for localization.
private enum PPHomeLivingLedgerMetrics {
    static let standardHorizontalInset: CGFloat = PPSpace.base
    static let standardPortalRatio: CGFloat = 0.42
    static let standardPortalMinimum: CGFloat = 80
    static let standardPortalMaximum: CGFloat = 156
    static let standardPortalGap: CGFloat = PPSpace.md
    static let standardCategoryHeight: CGFloat = 144
    static let standardCompositionMaximum: CGFloat = 144
    static let standardLedgerTitleHeight: CGFloat = 18
    static let standardLedgerTitleGap: CGFloat = PPSpace.xs
    /// Two 48pt rows keep every statistic comfortably above the 44pt target.
    static let standardLedgerGridHeight: CGFloat =
        (PPHomeZoneMetrics.minimumTarget * 2) + PPSpace.base
    static let accessibilityIdentityHeight: CGFloat = 80
    static let accessibilityCompositionMaximum: CGFloat = 72
    /// The plate (`padSide` / `padHeight`) keeps its full composition size;
    /// only the artwork inside it is inset slightly so the species never
    /// touches the portal edge.
    static let categoryArtworkScale: CGFloat = 0.78
    static let categoryWashWidthRatio: CGFloat = 1.46
    static let categoryWashHeightRatio: CGFloat = 0.94
    static let maximumReadableWidth: CGFloat = 480
    static let ledgerCorner: CGFloat = PPCorner.medium
    static let nodeSide: CGFloat = 26

    /// Two accessibility rows retain four independently reachable 44pt facts.
    static let standardLedgerHeight: CGFloat =
        (PPHomeZoneMetrics.minimumTarget * 3) + 3
}

/// An architectural species portal: organic, quiet, and large enough for the
/// real animal to lead. It avoids the scanner ring and dangling blade language.
private struct PPHomeSpeciesPortalShape: Shape {
    func path(in rect: CGRect) -> Path {
        let point: (CGFloat, CGFloat) -> CGPoint = { x, y in
            CGPoint(x: rect.minX + (rect.width * x),
                    y: rect.minY + (rect.height * y))
        }

        var path = Path()
        path.move(to: point(0.50, 0.02))
        path.addCurve(
            to: point(0.94, 0.43),
            control1: point(0.76, 0.01),
            control2: point(0.94, 0.19)
        )
        path.addCurve(
            to: point(0.60, 0.97),
            control1: point(0.94, 0.68),
            control2: point(0.77, 0.91)
        )
        path.addCurve(
            to: point(0.40, 0.97),
            control1: point(0.55, 0.99),
            control2: point(0.45, 0.99)
        )
        path.addCurve(
            to: point(0.06, 0.43),
            control1: point(0.23, 0.91),
            control2: point(0.06, 0.68)
        )
        path.addCurve(
            to: point(0.50, 0.02),
            control1: point(0.06, 0.19),
            control2: point(0.24, 0.01)
        )
        path.closeSubpath()
        return path
    }
}

/// A presentation-only frame signal gives the recurring hero heartbeat an
/// explicit viewport owner. Geometry never feeds layout back into itself; it
/// only starts or cancels the existing task when enough of the hero is visible.
private struct PPHomeMarketplaceViewportFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .null

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

/// Pure Pets' pet-first live index. The category portrait establishes scope at
/// a glance; the four data beans expose products, listings, services, and vets.
/// Selected-category rows retain their existing refresh/retry action. In the
/// All scope they become honest informational rows rather than disabled
/// controls, while navigation stays owned by the hero actions below.
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
    @State private var ambientPhase: AmbientPhase = .rest
    @State private var lastPresentedIdentity: String?
    @State private var isInViewport = false
    @State private var viewportResolved = false
    @State private var latestViewportFrame: CGRect = .null

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityConstellation
            } else {
                standardConstellation
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PPHomeMarketplaceViewportFrameKey.self,
                    value: proxy.frame(in: .global)
                )
            }
        }
        .onPreferenceChange(PPHomeMarketplaceViewportFrameKey.self) {
            updateViewportVisibility(frame: $0)
        }
        .task(id: motionKey) { await runPresentationMotion() }
        .task(id: signals.categoryID) { requestIdleSignals() }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                updateViewportVisibility(frame: latestViewportFrame)
            } else {
                settleForLifecycleExit()
            }
        }
        .onDisappear(perform: settleForLifecycleExit)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Living Ledger composition

    private var standardConstellation: some View {
        GeometryReader { proxy in
            let geometry = StandardGeometry(size: proxy.size)

            HStack(alignment: .center, spacing: geometry.portalGap) {
                categoryAperture(
                    width: geometry.portalWidth,
                    height: geometry.contentHeight,
                    compositionMaximum: geometry.portalCompositionMaximum
                )
                .frame(
                    width: geometry.portalWidth,
                    height: geometry.contentHeight
                )

                availabilityLedger(
                    width: geometry.ledgerWidth,
                    height: geometry.contentHeight,
                    gridHeight: geometry.ledgerGridHeight
                )
            }
            .frame(
                width: geometry.contentWidth,
                height: geometry.contentHeight,
                alignment: .center
            )
            .position(
                x: proxy.size.width / 2,
                y: proxy.size.height / 2
            )
        }
    }

    private func availabilityLedger(
        width: CGFloat,
        height: CGFloat,
        gridHeight: CGFloat
    ) -> some View {
        // `.leading` is already direction-aware: SwiftUI resolves it to the
        // physical right in Arabic. Flipping it manually double-mirrors the
        // ledger title and pushes it to the physical end edge.
        VStack(
            alignment: .leading,
            spacing: PPHomeLivingLedgerMetrics.standardLedgerTitleGap
        ) {
            HStack(spacing: PPSpace.xs) {
                Capsule()
                    .fill(accent)
                    .frame(width: PPSpace.md, height: PPSpace.xxs)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                Text(categoryAvailabilityTitle)
                    .font(HomeFont.footnote())
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.homeTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(
                maxWidth: .infinity,
                minHeight:
                    PPHomeLivingLedgerMetrics.standardLedgerTitleHeight,
                maxHeight:
                    PPHomeLivingLedgerMetrics.standardLedgerTitleHeight,
                alignment: .leading
            )
            .accessibilityHidden(true)

            signalGrid(height: gridHeight)
        }
        .frame(width: width, height: height, alignment: .center)
        .accessibilityElement(children: .contain)
    }
    /// height; no control is hidden behind horizontal scrolling.
    private var accessibilityConstellation: some View {
        GeometryReader { proxy in
            let geometry = AccessibilityGeometry(size: proxy.size)

            VStack(spacing: PPSpace.sm) {
                categoryAperture(
                    width: geometry.contentWidth,
                    height: geometry.identityHeight,
                    compositionMaximum:
                        PPHomeLivingLedgerMetrics
                            .accessibilityCompositionMaximum
                )

                signalGrid(
                    height: geometry.ledgerHeight
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

    /// The category image fills the dominant Species Portal. One bounded
    /// radial wash joins it to the adjacent ledger; there is no ring, scanner
    /// contour, blade, axis, or decorative hit target.
    private func categoryAperture(
        width: CGFloat,
        height: CGFloat,
        compositionMaximum: CGFloat
    ) -> some View {
        let padSide = min(
            compositionMaximum,
            max(
                PPHomeZoneMetrics.minimumTarget,
                min(
                    width,
                    height
                )
            )
        )
        let padHeight = padSide * 0.86
        let artworkSide =
            padSide * PPHomeLivingLedgerMetrics.categoryArtworkScale
        let washWidth = min(
            width,
            padSide * PPHomeLivingLedgerMetrics.categoryWashWidthRatio
        )
        let washHeight = min(
            height,
            padSide * PPHomeLivingLedgerMetrics.categoryWashHeightRatio
        )
        let padShape = PPHomeSpeciesPortalShape()

        return ZStack {
            // One fixed-paint field binds the category to the four facts. Its
            // animation is applied to the outer opacity/transform only.
            Ellipse()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(
                                color: accent.opacity(identityWashOpacity),
                                location: 0
                            ),
                            .init(
                                color: accent.opacity(
                                    identityWashOpacity * 0.46
                                ),
                                location: 0.44
                            ),
                            .init(color: accent.opacity(0), location: 0.74),
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: max(washWidth, washHeight) * 0.54
                    )
                )
                .frame(width: washWidth, height: washHeight)
                .offset(y: padSide * 0.05)
                .scaleEffect(ambientFieldScale * portalEntranceFieldScale)
                .opacity(identityPresented ? 1 : 0.18)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(
                                colorScheme == .dark ? 0.075 : 0.045
                            ),
                            accent.opacity(0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: max(washWidth, washHeight) * 0.52
                    )
                )
                .frame(width: washWidth, height: washHeight)
                .offset(y: padSide * 0.05)
                .opacity(
                    max(
                        ambientWashHighlightOpacity,
                        portalEntranceWashHighlightOpacity
                    )
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            // One finite echo follows a selected-category entrance or retarget.
            // It never joins the inherited heartbeat: the category event owns
            // this scale/opacity transition and resolves it fully to rest.
            padShape
                .stroke(
                    accent.opacity(colorScheme == .dark ? 0.30 : 0.22),
                    lineWidth: 1.25
                )
                .frame(width: padSide, height: padHeight)
                .scaleEffect(portalEntranceEchoScale)
                .opacity(portalEntranceEchoOpacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            padShape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.ppSurfaceRaised,
                            reduceTransparency
                                ? Color.ppSurfaceRaised
                                : accent.opacity(
                                    colorScheme == .dark ? 0.14 : 0.055
                                ),
                        ],
                        startPoint: .top,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: padSide, height: padHeight)
                .overlay {
                    padShape.stroke(
                        contrast == .increased
                            ? Color.ppTextPrimary.opacity(0.68)
                            : Color.ppSurfaceBorder.opacity(
                                colorScheme == .dark ? 0.88 : 0.72
                            ),
                        lineWidth: contrast == .increased ? 1.5 : 1
                    )
                }
                .scaleEffect(
                    (identityPresented ? 1 : 0.98) *
                        ambientPadScale *
                        portalEntrancePadScale
                )
                .offset(x: portalEntranceHorizontalOffset)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            identityArtwork(side: artworkSide)
                .scaleEffect(
                    ambientArtworkScale * portalEntranceArtworkScale
                )
                .rotationEffect(.degrees(portalEntranceArtworkRotation))
                .offset(x: portalEntranceHorizontalOffset)
                .offset(
                    y: ambientArtworkVerticalOffset +
                        portalEntranceArtworkVerticalOffset
                )
                .frame(width: artworkSide, height: artworkSide)
                .clipShape(padShape)
        }
        .frame(width: width, height: height, alignment: .center)
        .offset(y: identityPresented ? 0 : PPSpace.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(categoryAccessibilitySummary)
        .accessibilityAddTraits(.isHeader)
        .accessibilitySortPriority(5)
    }

    private var identityWashOpacity: Double {
        if contrast == .increased { return 0.14 }
        if reduceTransparency {
            return colorScheme == .dark ? 0.20 : 0.12
        }
        return colorScheme == .dark ? 0.17 : 0.085
    }

    private var ambientWashHighlightOpacity: Double {
        switch ambientPresentationPhase {
        case .identity: return 1
        case .constellation: return 0.42
        case .field: return 0.18
        case .rest: return 0
        }
    }

    private var ambientArtworkScale: CGFloat {
        guard signals.categoryID != nil else { return 1 }

        switch ambientPresentationPhase {
        case .identity: return 1.012
        case .constellation: return 1.004
        case .rest, .field: return 1
        }
    }

    private var ambientArtworkVerticalOffset: CGFloat {
        guard signals.categoryID != nil else { return 0 }

        switch ambientPresentationPhase {
        case .identity: return -1
        case .constellation: return -0.25
        case .rest, .field: return 0
        }
    }

    private var ambientPadScale: CGFloat {
        guard signals.categoryID != nil else { return 1 }

        switch ambientPresentationPhase {
        case .identity: return 1.012
        case .constellation: return 1.005
        case .rest, .field: return 1
        }
    }

    private var ambientFieldScale: CGFloat {
        ambientPresentationPhase == .field ? 1.025 : 1
    }

    /// The All-scope `Shop2.json` asset keeps its established Lottie motion.
    /// Only a concrete selected category receives the finite portal relay.
    private var portalEntrancePhase: Phase {
        signals.categoryID == nil ? .settled : presentationPhase
    }

    private var portalEntranceHorizontalOffset: CGFloat {
        let towardLedger: CGFloat = layoutDirection == .rightToLeft ? -1 : 1

        switch portalEntrancePhase {
        case .leadingSignals: return 1.5 * towardLedger
        case .trailingSignals: return 0.5 * towardLedger
        case .staged, .identity, .settled: return 0
        }
    }

    private var portalEntranceEchoScale: CGFloat {
        switch portalEntrancePhase {
        case .staged: return 0.985
        case .identity: return 1.012
        case .leadingSignals: return 1.035
        case .trailingSignals: return 1.055
        case .settled: return 1.065
        }
    }

    private var portalEntranceEchoOpacity: Double {
        switch portalEntrancePhase {
        case .staged, .settled: return 0
        case .identity: return colorScheme == .dark ? 0.34 : 0.26
        case .leadingSignals: return colorScheme == .dark ? 0.22 : 0.16
        case .trailingSignals: return colorScheme == .dark ? 0.10 : 0.07
        }
    }

    private var portalEntrancePadScale: CGFloat {
        switch portalEntrancePhase {
        case .identity: return 1.018
        case .leadingSignals: return 1.010
        case .trailingSignals: return 0.998
        case .staged, .settled: return 1
        }
    }

    private var portalEntranceArtworkScale: CGFloat {
        switch portalEntrancePhase {
        case .identity: return 1.028
        case .leadingSignals: return 1.014
        case .trailingSignals: return 0.998
        case .staged, .settled: return 1
        }
    }

    private var portalEntranceArtworkVerticalOffset: CGFloat {
        switch portalEntrancePhase {
        case .identity: return -2.25
        case .leadingSignals: return -0.75
        case .trailingSignals: return 0.40
        case .staged, .settled: return 0
        }
    }

    private var portalEntranceArtworkRotation: Double {
        let towardLedger = layoutDirection == .rightToLeft ? -1.0 : 1.0

        switch portalEntrancePhase {
        case .identity: return 0.85 * towardLedger
        case .leadingSignals: return -0.30 * towardLedger
        case .staged, .trailingSignals, .settled: return 0
        }
    }

    private var portalEntranceWashHighlightOpacity: Double {
        switch portalEntrancePhase {
        case .identity: return 1
        case .leadingSignals: return 0.62
        case .trailingSignals: return 0.26
        case .staged, .settled: return 0
        }
    }

    private var portalEntranceFieldScale: CGFloat {
        portalEntrancePhase == .trailingSignals ? 1.045 : 1
    }

    @ViewBuilder
    private func identityArtwork(side: CGFloat) -> some View {
        if signals.categoryID == nil {
            // Reuse the original Home hero's local marketplace animation and
            // UIKit bridge. The bridge owns its loop and stops automatically
            // off-window, in the background, and when Reduce Motion is active.
            HomeHeroLottieRepresentable(
                animationName: "Shop2.json",
                loadsFromFirebase: false,
                playbackEnabled: allCategoryPlaybackEnabled,
                tintColor: UIColor(accent)
            )
            .frame(width: side, height: side)
            // Reverse only the All-category presentation. Playback direction,
            // the bundled file, bridge lifecycle, tint, and speed stay intact.
            .scaleEffect(x: -1, y: 1, anchor: .center)
        } else if let imageURL = selectedCategoryURL {
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

    private var categoryAvailabilityTitle: String {
        guard signals.categoryID != nil,
              case let .openMarketplace(mainKind) = page.action,
              let mainKind
        else {
            return PPHomeZoneCopy.marketplaceSignalAllCategorySummary
        }
        let categoryTitle = HomeModelAdapter.mainKindTitle(mainKind)
        let isolatedCategoryTitle = "\u{2068}\(categoryTitle)\u{2069}"
        return String(
            format: PPHomeZoneCopy.marketplaceSignalCategorySummaryFormat,
            locale: Locale(
                identifier: Language.currentLanguageCode() ?? "ar"
            ),
            isolatedCategoryTitle
        )
    }

    // MARK: - Species availability ledger

    /// Standard and accessibility layouts share the same semantic 2x2 ledger.
    /// Its leading column remains physical right in Arabic.
    private var logicalLeadingSignalKinds: [HomeMarketplaceSignalKind] {
        [.marketplace, .advertisements]
    }

    private var logicalTrailingSignalKinds: [HomeMarketplaceSignalKind] {
        [.services, .veterinarians]
    }

    private func signalGrid(height: CGFloat) -> some View {
        HStack(spacing: PPSpace.sm) {
            signalColumn(
                kinds: logicalLeadingSignalKinds,
                height: height
            )

            signalColumn(
                kinds: logicalTrailingSignalKinds,
                height: height
            )
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .accessibilityElement(children: .contain)
    }

    private func signalColumn(
        kinds: [HomeMarketplaceSignalKind],
        height: CGFloat
    ) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: PPHomeLivingLedgerMetrics.ledgerCorner,
            style: .continuous
        )

        return ZStack {
            shape
                .fill(
                    accent.opacity(
                        colorScheme == .dark ? 0.14 : 0.075
                    )
                )
                .opacity(ambientLedgerBackdropOpacity)
                .scaleEffect(
                    x: ambientLedgerBackdropScale,
                    y: 1
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: PPSpace.xs) {
                ForEach(kinds, id: \.self) { kind in
                    signalStat(kind: kind)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                Color.clear,
                lineWidth: contrast == .increased ? 1.5 : 1
            )
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func signalStat(kind: HomeMarketplaceSignalKind) -> some View {
        let tone = routeTone(for: kind)

        if signals.categoryID == nil {
            signalStatContent(
                kind: kind,
                tone: tone
            )
            .offset(y: signalRowPresented(kind) ? 0 : -PPSpace.xs)
            .scaleEffect(ambientBeanScale)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(signalLabel(for: kind))
            .accessibilityValue(accessibilityValue(for: kind))
            .accessibilityHint(signalHint(for: kind))
            .accessibilitySortPriority(accessibilityPriority(for: kind))
        } else {
            Button {
                onSelectSignal(kind)
            } label: {
                signalStatContent(
                    kind: kind,
                    tone: tone
                )
            }
            .buttonStyle(
                PPHomeSurfacePressStyle(
                    reduceMotion: presentationMotionSuppressed
                )
            )
            .offset(y: signalRowPresented(kind) ? 0 : -PPSpace.xs)
            .scaleEffect(ambientBeanScale)
            .disabled(isSignalLoading(kind))
            .accessibilityLabel(signalLabel(for: kind))
            .accessibilityValue(accessibilityValue(for: kind))
            .accessibilityHint(signalHint(for: kind))
            .accessibilitySortPriority(accessibilityPriority(for: kind))
        }
    }

    private func signalStatContent(
        kind: HomeMarketplaceSignalKind,
        tone: Color
    ) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: PPHomeLivingLedgerMetrics.ledgerCorner,
            style: .continuous
        )

        return HStack(spacing: PPSpace.xs) {
            signalNode(for: kind, tone: tone)

            // Value and label hug the glyph on both sides of the mirror:
            // `.leading` resolves to the physical right in Arabic, so no
            // manual flip is applied here.
            VStack(
                alignment: .leading,
                spacing: 0
            ) {
                signalValue(for: kind, tone: tone)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .id(signalValueIdentity(for: kind))
                    .transition(.opacity)
                    .animation(
                        presentationMotionSuppressed
                            ? nil
                            : .easeOut(duration: 0.18),
                        value: signalValueIdentity(for: kind)
                    )

                Text(
                    signalDisplayLabel(
                        for: kind,
                        usesCompactCopy: true
                    )
                )
                .font(HomeFont.caption2())
                .foregroundStyle(Color.homeTextSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(
                    dynamicTypeSize.isAccessibilitySize ? 1 : 0.72
                )
                .fixedSize(
                    horizontal: false,
                    vertical: dynamicTypeSize.isAccessibilitySize
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
            }
        }
        .padding(.horizontal, PPSpace.xs)
        .padding(.vertical, PPSpace.xxs)
        .frame(
            maxWidth: .infinity,
            minHeight: PPHomeZoneMetrics.minimumTarget,
            maxHeight: .infinity,
            alignment: .center
        )
        .contentShape(Rectangle())
        .background {
            ZStack {
                shape.fill(Color.ppSurfaceRaised)

                shape
                    .fill(
                        accent.opacity(
                            colorScheme == .dark ? 0.085 : 0.035
                        )
                    )
                    .opacity(ambientBeanHighlightOpacity)
            }
        }
        .overlay {
            shape.strokeBorder(
                contrast == .increased
                    ? Color.ppTextPrimary.opacity(0.66)
                    : Color.ppSurfaceBorder.opacity(
                        colorScheme == .dark ? 0.88 : 0.74
                    ),
                lineWidth: contrast == .increased ? 1.5 : 1
            )
        }
    }

    private func signalNode(
        for kind: HomeMarketplaceSignalKind,
        tone: Color
    ) -> some View {
        ZStack {
            Circle()
                .fill(Color.ppSurface)

            Circle()
                .strokeBorder(
                    contrast == .increased
                        ? Color.ppTextPrimary.opacity(0.76)
                        : Color.ppSurfaceBorder.opacity(
                            colorScheme == .dark ? 0.90 : 0.76
                        ),
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

    private var ambientLedgerBackdropOpacity: Double {
        ambientPresentationPhase == .field ? 1 : 0
    }

    private var ambientLedgerBackdropScale: CGFloat {
        ambientPresentationPhase == .field ? 1 : 0.96
    }

    private var ambientBeanHighlightOpacity: Double {
        switch ambientPresentationPhase {
        case .constellation: return 1
        case .field: return 0.28
        case .rest, .identity: return 0
        }
    }

    private var ambientBeanScale: CGFloat {
        guard signals.categoryID != nil else { return 1 }
        return ambientPresentationPhase == .constellation ? 1.006 : 1
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
        case .veterinarians: symbol = "stethoscope"
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
        case .veterinarians: return Color.ppCareAccent
        }
    }

    @ViewBuilder
    private func signalValue(
        for kind: HomeMarketplaceSignalKind,
        tone: Color
    ) -> some View {
        if signals.categoryID == nil {
            Text(PPHomeZoneCopy.marketplaceSignalAllScope)
                .font(HomeFont.footnote())
                .fontWeight(.semibold)
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        } else {
            switch signals.value(for: kind) {
            case .idle:
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(tone)
                    .scaleEffect(0.74)
                    .frame(height: 18)
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(tone)
                    .scaleEffect(0.74)
                    .frame(height: 18)
            case let .available(count):
                Text(localizedNumber(max(0, count)))
                    .font(HomeFont.bold(15))
                    .monospacedDigit()
                    .foregroundStyle(tone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            case .failed:
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tone)
                    .accessibilityHidden(true)
            }
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
        case .veterinarians:
            return PPHomeZoneCopy.marketplaceSignalVeterinariansLabel
        }
    }

    /// Compact copy is presentation-only. Assistive technologies retain the
    /// complete marketplace terminology through `signalLabel(for:)`.
    private func signalDisplayLabel(
        for kind: HomeMarketplaceSignalKind,
        usesCompactCopy: Bool
    ) -> String {
        guard usesCompactCopy else { return signalLabel(for: kind) }

        switch kind {
        case .marketplace:
            return PPHomeZoneCopy.marketplaceSignalItemsCompactLabel
        case .services:
            return PPHomeZoneCopy.marketplaceSignalServicesCompactLabel
        case .advertisements:
            return PPHomeZoneCopy.marketplaceSignalAdsCompactLabel
        case .veterinarians:
            return PPHomeZoneCopy.marketplaceSignalVeterinariansCompactLabel
        }
    }

    /// Stable per-state identity makes a completed load or retry crossfade in
    /// place without fake count-up motion or geometry changes.
    private func signalValueIdentity(
        for kind: HomeMarketplaceSignalKind
    ) -> String {
        guard signals.categoryID != nil else { return "all-categories" }

        switch signals.value(for: kind) {
        case .idle:
            return "idle"
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
        guard signals.categoryID != nil else {
            return PPHomeZoneCopy.marketplaceSignalAllScopeAccessibility
        }

        let value: String
        switch signals.value(for: kind) {
        case .idle:
            value = PPHomeZoneCopy.marketplaceSignalIdle
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
            return PPHomeZoneCopy.marketplaceSignalAllScopeHint
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
        case .marketplace: return 4
        case .advertisements: return 3
        case .services: return 2
        case .veterinarians: return 1
        }
    }

    // MARK: - Finite entrance and lifecycle-bound ambient relay

    private struct MotionKey: Equatable {
        let identity: String
        let suppressed: Bool
        let sceneIsActive: Bool
        let viewportResolved: Bool
        let viewportVisible: Bool
    }

    private var motionKey: MotionKey {
        MotionKey(
            identity: artworkIdentity,
            suppressed: presentationMotionSuppressed,
            sceneIsActive: scenePhase == .active,
            viewportResolved: viewportResolved,
            viewportVisible: isInViewport
        )
    }

    @MainActor
    private func updateViewportVisibility(frame: CGRect) {
        latestViewportFrame = frame
        // A missing window during scene activation is not proof that the hero
        // is offscreen. Keep the viewport unresolved until both coordinate
        // spaces are trustworthy, then let the existing motion key re-evaluate.
        guard let visible = isMeaningfullyVisible(frame: frame) else { return }
        let wasResolved = viewportResolved
        guard !wasResolved || visible != isInViewport else { return }

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            viewportResolved = true
            isInViewport = visible
            // Never consume the first-visible entrance merely because the
            // initial global frame resolved offscreen. Once the view has been
            // presented, later viewport exits settle and do not replay it.
            if wasResolved && !visible {
                phase = .settled
                ambientPhase = .rest
                lastPresentedIdentity = artworkIdentity
            }
        }
    }

    @MainActor
    private func isMeaningfullyVisible(frame: CGRect) -> Bool? {
        guard !frame.isNull,
              !frame.isInfinite,
              frame.width > 0,
              frame.height > 0,
              let viewport = activeWindowBounds
        else { return nil }

        let intersection = frame.intersection(viewport)
        guard !intersection.isNull else { return false }

        let minimumVisibleHeight = min(
            frame.height,
            max(PPHomeZoneMetrics.minimumTarget, frame.height * 0.20)
        )
        let minimumVisibleWidth = min(
            frame.width,
            PPHomeZoneMetrics.minimumTarget
        )

        return intersection.height >= minimumVisibleHeight &&
            intersection.width >= minimumVisibleWidth
    }

    @MainActor
    private var activeWindowBounds: CGRect? {
        for case let windowScene as UIWindowScene in
        UIApplication.shared.connectedScenes
        where windowScene.activationState == .foregroundActive {
            if let window = windowScene.windows.first(where: { $0.isKeyWindow })
                ?? windowScene.windows.first(where: { !$0.isHidden }) {
                return window.convert(window.bounds, to: nil)
            }

            // SwiftUI can emit its first geometry preference before the key
            // window is attached. The scene's screen bounds are the matching
            // global coordinate fallback for that narrow lifecycle window.
            return windowScene.screen.bounds
        }
        return nil
    }

    /// One task owns the complete presentation story for the current category:
    /// the finite entrance first, followed by the selected-scope heartbeat.
    @MainActor
    private func runPresentationMotion() async {
        // SwiftUI may start this task before the first global-frame preference
        // is delivered. Waiting here makes the first impression deterministic.
        guard viewportResolved else { return }
        await runEntrance()
        guard !Task.isCancelled, ambientMotionEnabled else {
            settleAmbientWithoutAnimation()
            return
        }
        await runAmbientMotion()
    }

    /// Resolves the species portal first, then both semantic ledger columns.
    /// Counts never pulse or count up; only the containing surfaces enter.
    @MainActor
    private func runEntrance() async {
        guard viewportResolved else { return }

        // An initially offscreen hero remains staged so its first meaningful
        // viewport entry still receives the one finite entrance.
        guard isInViewport, scenePhase == .active else {
            if lastPresentedIdentity != artworkIdentity {
                stageWithoutAnimation()
            }
            return
        }

        guard !reduceMotion,
              !voiceOverEnabled,
              !switchControlEnabled,
              !presentationMotionSuppressed
        else {
            settleWithoutAnimation()
            return
        }

        guard lastPresentedIdentity != artworkIdentity else {
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
            phase = .leadingSignals
        }

        guard await pauseForNextPhase(50_000_000) else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            phase = .trailingSignals
        }

        guard await pauseForNextPhase(60_000_000) else { return }
        withAnimation(.easeOut(duration: 0.20)) {
            phase = .settled
        }
        lastPresentedIdentity = artworkIdentity
    }

    /// A long-rest heartbeat keeps a selected category perceptually alive
    /// without presenting snapshot counts as polling, refresh, or auto-retry.
    /// Fixed-paint decorative layers move only through opacity and transform.
    @MainActor
    private func runAmbientMotion() async {
        settleAmbientWithoutAnimation()
        guard ambientMotionEnabled else { return }

        defer { settleAmbientWithoutAnimation() }

        while !Task.isCancelled {
            guard await pauseForNextPhase(2_600_000_000),
                  ambientMotionEnabled
            else { break }

            presentAmbient(.identity)
            guard await pauseForNextPhase(400_000_000),
                  ambientMotionEnabled
            else { break }

            presentAmbient(.constellation)
            guard await pauseForNextPhase(360_000_000),
                  ambientMotionEnabled
            else { break }

            presentAmbient(.field)
            guard await pauseForNextPhase(440_000_000),
                  ambientMotionEnabled
            else { break }

            presentAmbient(.rest)
        }
    }

    @MainActor
    private func presentAmbient(_ nextPhase: AmbientPhase) {
        guard !reduceMotion,
              !voiceOverEnabled,
              !switchControlEnabled,
              ambientMotionEnabled
        else {
            settleAmbientWithoutAnimation()
            return
        }

        withAnimation(.easeInOut(duration: 0.20)) {
            ambientPhase = nextPhase
        }
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
            ambientPhase = .rest
        }
    }

    private func settleWithoutAnimation() {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            phase = .settled
            ambientPhase = .rest
            lastPresentedIdentity = artworkIdentity
        }
    }

    private func settleForLifecycleExit() {
        if lastPresentedIdentity == artworkIdentity ||
            (viewportResolved && isInViewport) {
            settleWithoutAnimation()
        } else {
            stageWithoutAnimation()
        }
    }

    private func settleAmbientWithoutAnimation() {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            ambientPhase = .rest
        }
    }

    private var presentationPhase: Phase {
        guard viewportResolved else { return .staged }

        // A category that has never been presented must remain staged while
        // offscreen. Otherwise the suppression fallback would briefly expose
        // the final state before snapping backward at the visibility threshold.
        if lastPresentedIdentity != artworkIdentity && !isInViewport {
            return .staged
        }
        return presentationMotionSuppressed ? .settled : phase
    }

    private var ambientPresentationPhase: AmbientPhase {
        presentationMotionSuppressed || signals.categoryID == nil
            ? .rest
            : ambientPhase
    }

    private var ambientMotionEnabled: Bool {
        signals.categoryID != nil &&
            !presentationMotionSuppressed &&
            lastPresentedIdentity == artworkIdentity &&
            presentationPhase == .settled
    }

    /// The All-category animation is an established Home asset, not part of the
    /// selected-category entrance relay. Let it begin while the first viewport
    /// preference is resolving, then use the resolved visibility state to stop
    /// offscreen work. Assistive motion settings and app lifecycle still win.
    private var allCategoryPlaybackEnabled: Bool {
        !motionSuppressed &&
            scenePhase == .active &&
            (!viewportResolved || isInViewport)
    }

    private var presentationMotionSuppressed: Bool {
        motionSuppressed ||
            reduceTransparency ||
            contrast == .increased ||
            dynamicTypeSize.isAccessibilitySize ||
            !viewportResolved ||
            !isInViewport ||
            scenePhase != .active
    }

    private var identityPresented: Bool {
        presentationPhase.rawValue >= Phase.identity.rawValue
    }

    private func signalRowPresented(
        _ kind: HomeMarketplaceSignalKind
    ) -> Bool {
        switch kind {
        case .marketplace, .advertisements:
            return presentationPhase.rawValue >= Phase.leadingSignals.rawValue
        case .services, .veterinarians:
            return presentationPhase.rawValue >= Phase.trailingSignals.rawValue
        }
    }

    private var motionSuppressed: Bool {
        reduceMotion ||
            voiceOverEnabled ||
            switchControlEnabled
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
        layoutDirection == .rightToLeft || Language.isRTL()
    }

    private enum Phase: Int, Equatable {
        case staged
        case identity
        case leadingSignals
        case trailingSignals
        case settled
    }

    private enum AmbientPhase: Equatable {
        case rest
        case identity
        case constellation
        case field
    }

    private struct StandardGeometry {
        let size: CGSize

        var contentWidth: CGFloat {
            let inset = PPHomeLivingLedgerMetrics.standardHorizontalInset
            return min(
                PPHomeLivingLedgerMetrics.maximumReadableWidth,
                max(0, size.width - (inset * 2))
            )
        }

        var contentHeight: CGFloat {
            min(
                PPHomeLivingLedgerMetrics.standardCategoryHeight,
                max(0, size.height - PPSpace.base)
            )
        }

        var portalGap: CGFloat {
            PPHomeLivingLedgerMetrics.standardPortalGap
        }

        private var minimumLedgerWidth: CGFloat {
            (PPHomeZoneMetrics.minimumTarget * 2) + PPSpace.sm
        }

        private var maximumPortalWidth: CGFloat {
            max(0, contentWidth - portalGap - minimumLedgerWidth)
        }

        var portalWidth: CGFloat {
            let preferred =
                contentWidth * PPHomeLivingLedgerMetrics.standardPortalRatio
            return min(
                PPHomeLivingLedgerMetrics.standardPortalMaximum,
                max(
                    PPHomeLivingLedgerMetrics.standardPortalMinimum,
                    min(preferred, maximumPortalWidth)
                )
            )
        }

        var portalCompositionMaximum: CGFloat {
            min(
                PPHomeLivingLedgerMetrics.standardCompositionMaximum,
                max(
                    PPHomeZoneMetrics.minimumTarget,
                    min(
                        portalWidth - PPSpace.xs,
                        contentHeight - PPSpace.xs
                    )
                )
            )
        }

        var ledgerWidth: CGFloat {
            max(0, contentWidth - portalWidth - portalGap)
        }

        var ledgerGridHeight: CGFloat {
            min(
                PPHomeLivingLedgerMetrics.standardLedgerGridHeight,
                max(
                    0,
                    contentHeight -
                        PPHomeLivingLedgerMetrics.standardLedgerTitleHeight -
                        PPHomeLivingLedgerMetrics.standardLedgerTitleGap
                )
            )
        }
    }

    private struct AccessibilityGeometry {
        let size: CGSize

        private var verticalInset: CGFloat { PPSpace.sm }

        var readableHeight: CGFloat {
            max(0, size.height - (verticalInset * 2))
        }

        var opticalCenterY: CGFloat {
            verticalInset + (readableHeight / 2)
        }

        var contentWidth: CGFloat {
            min(
                PPHomeLivingLedgerMetrics.maximumReadableWidth,
                max(0, size.width - (PPSpace.base * 2))
            )
        }

        var identityHeight: CGFloat {
            min(
                PPHomeLivingLedgerMetrics.accessibilityIdentityHeight,
                max(72, readableHeight * 0.28)
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
/// hero so its four live-signal buttons are the media band's only controls.
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
            .padding(
                .bottom,
                PPHomeSectionHeaderMetrics.contentSpacing - PPSpace.md
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
/// My Pet owns the logical-leading, two-row feature lane. The first four
/// secondary actions keep their source priority in the adjacent 2 x 2 grid;
/// lower-priority actions remain available through their existing entry points.
/// Accessibility text sizes preserve source order in full-width rows.
@available(iOS 15.0, *)
struct PPHomeEcosystemLauncher: View {
    let featuredAction: HomePriorityAction?
    let featuredPet: HomePetModel?
    let actions: [HomePriorityAction]
    let onSelect: (HomePriorityAction) -> Void

    private var boundedActions: [HomePriorityAction] {
        Array(
            actions
                .filter { $0.id != "pet" }
                .prefix(
                    PPHomePresentationLimits
                        .ecosystemLauncherSecondaryActions
                )
        )
    }

    private var bentoActions: [HomePriorityAction] {
        var result: [HomePriorityAction] = []
        if let featuredAction, featuredAction.id == "pet" {
            result.append(featuredAction)
        }
        result.append(contentsOf: boundedActions)
        return result
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: PPHomeSectionHeaderMetrics.contentSpacing
        ) {
            PPHomeSectionHeading(
                title: PPHomeZoneCopy.launcherTitle,
                subtitle: PPHomeZoneCopy.launcherSubtitle
            )

            HomePriorityGrid(
                actions: bentoActions,
                featuredPet: featuredPet,
                onSelect: onSelect
            )
        }
        .accessibilityElement(children: .contain)
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
        VStack(
            alignment: .leading,
            spacing: PPHomeSectionHeaderMetrics.contentSpacing
        ) {
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
        VStack(
            alignment: .leading,
            spacing: PPHomeSectionHeaderMetrics.contentSpacing
        ) {
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
        VStack(
            alignment: .leading,
            spacing: PPHomeSectionHeaderMetrics.contentSpacing
        ) {
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

    static var marketplaceSignalVeterinariansLabel: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_veterinarians_label",
            fallback: "Veterinarians"
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

    static var marketplaceSignalVeterinariansCompactLabel: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_veterinarians_compact_label",
            fallback: "Vets"
        )
    }

    static var marketplaceSignalCategorySummaryFormat: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_category_summary_format",
            fallback: "Available for %@"
        )
    }

    static var marketplaceSignalAllCategorySummary: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_all_category_summary",
            fallback: "Across all categories"
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

    static var marketplaceSignalAllScope: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_all_scope",
            fallback: "All"
        )
    }

    static var marketplaceSignalAllScopeAccessibility: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_all_scope_accessibility",
            fallback: "All categories"
        )
    }

    static var marketplaceSignalAllScopeHint: String {
        HomeModelAdapter.localized(
            "home_marketplace_signal_all_scope_hint",
            fallback: "Select a category to see its live count."
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
