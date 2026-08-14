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

/// The Living Ledger keeps one selected-category identity and three live facts
/// in one composition. It intentionally has no category plate, orbital diagram,
/// individual count cards, or horizontal accessibility rail.
private enum PPHomeLivingLedgerMetrics {
    /// The standard hero is a centered diptych: a dominant category field and
    /// a deliberately quieter, width-bounded live-statistics sidecar.
    static let standardIdentityMaximum: CGFloat = 164
    static let standardIdentityMinimum: CGFloat = 132
    static let compactIdentityMinimum: CGFloat = 88
    static let standardLedgerWidth: CGFloat = 188
    static let compactWidthBreakpoint: CGFloat = 332
    /// Three full controls plus two Increased Contrast separators.
    static let standardLedgerHeight: CGFloat =
        (PPHomeZoneMetrics.minimumTarget * 3) + 3
    static let standardCategoryHeight: CGFloat = 160
    static let standardHorizontalInset: CGFloat = PPSpace.base
    static let accessibilityIdentityHeight: CGFloat = 72
    static let standardCompositionMaximum: CGFloat = 136
    static let identityCompositionWidthRatio: CGFloat = 0.90
    static let standardTrailingFocusShift: CGFloat = PPSpace.sm
    static let accessibilityCompositionMaximum: CGFloat = 64
    static let identityWashWidthRatio: CGFloat = 0.88
    static let identityWashHeightRatio: CGFloat = 1.08
    static let maximumReadableWidth: CGFloat = 480
    static let ledgerCorner: CGFloat = PPCorner.medium
    static let rowHorizontalPadding: CGFloat = PPSpace.sm
    /// The ledger remains a 44-point control per row; only the decorative
    /// badge cluster contracts slightly so the category identity can lead.
    static let nodeSide: CGFloat = 26
    static let indexLineWidth: CGFloat = 2
}

/// A single category-to-ledger gesture replaces the generic broken border.
/// The standard curve gathers around the portrait before resolving into the
/// logical trailing seam. Accessibility sizes use a separate local curve so a
/// full-width header never becomes a decorative underline.
private struct PPHomeCategoryRibbonShape: Shape {
    let usesWideHeaderPath: Bool

    func path(in rect: CGRect) -> Path {
        let safeRect = rect.insetBy(dx: 3, dy: 3)
        return usesWideHeaderPath
            ? wideHeaderPath(in: safeRect)
            : portraitPath(in: safeRect)
    }

    /// Keeps the portrait gesture proportional as the standard layout narrows,
    /// rather than stretching the sweep vertically.
    private func portraitPath(in rect: CGRect) -> Path {
        let localHeight = min(rect.height, rect.width * 1.18)
        let drawingRect = CGRect(
            x: rect.minX,
            y: rect.midY - (localHeight / 2),
            width: rect.width,
            height: localHeight
        )

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: drawingRect.minX + (drawingRect.width * x),
                y: drawingRect.minY + (drawingRect.height * y)
            )
        }

        var path = Path()
        path.move(to: point(0.22, 0.14))
        path.addCurve(
            to: point(0.07, 0.50),
            control1: point(0.11, 0.22),
            control2: point(0.045, 0.36)
        )
        path.addCurve(
            to: point(0.26, 0.87),
            control1: point(0.07, 0.69),
            control2: point(0.14, 0.82)
        )
        path.addCurve(
            to: point(0.72, 0.83),
            control1: point(0.39, 0.94),
            control2: point(0.60, 0.92)
        )
        path.addCurve(
            to: point(1.00, 0.50),
            control1: point(0.88, 0.78),
            control2: point(0.95, 0.63)
        )
        return path
    }

    /// Accessibility headers keep the wrap local to the centered portrait, then
    /// rise into one quiet terminal that reaches the real logical trailing seam.
    /// This avoids both a floating seam and a full-width decorative underline.
    private func wideHeaderPath(in rect: CGRect) -> Path {
        let span = min(rect.height, rect.width * 0.24)

        func localPoint(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.midX + (span * x),
                y: rect.minY + (rect.height * y)
            )
        }

        var path = Path()
        path.move(to: localPoint(-0.18, 0.08))
        path.addCurve(
            to: localPoint(-0.50, 0.46),
            control1: localPoint(-0.38, 0.13),
            control2: localPoint(-0.52, 0.29)
        )
        path.addCurve(
            to: localPoint(-0.20, 0.88),
            control1: localPoint(-0.52, 0.69),
            control2: localPoint(-0.39, 0.84)
        )
        path.addCurve(
            to: localPoint(0.36, 0.74),
            control1: localPoint(0.01, 0.95),
            control2: localPoint(0.25, 0.88)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: localPoint(0.66, 0.65),
            control2: CGPoint(
                x: rect.maxX - min(28, rect.width * 0.09),
                y: rect.midY + (rect.height * 0.08)
            )
        )
        return path
    }
}

/// Pure Pets' pet-first live index. The category portrait establishes scope at
/// a glance; one continuous ledger exposes products, services, and listings.
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
        .onChange(of: scenePhase) { newPhase in
            guard newPhase != .active else { return }
            settleWithoutAnimation()
        }
        .onDisappear(perform: settleWithoutAnimation)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Living Ledger composition

    private var standardConstellation: some View {
        GeometryReader { proxy in
            let geometry = StandardGeometry(size: proxy.size)

            HStack(alignment: .center, spacing: geometry.horizontalGap) {
                categoryAperture(
                    width: geometry.identityWidth,
                    height: geometry.categoryHeight,
                    compositionMaximum:
                        PPHomeLivingLedgerMetrics.standardCompositionMaximum
                )

                signalLedger(
                    height: geometry.ledgerHeight,
                    compactRows: geometry.usesCompactRows
                )
                .frame(width: geometry.ledgerWidth)
            }
            .frame(
                width: geometry.clusterWidth,
                height: geometry.rowHeight,
                alignment: .center
            )
            .position(
                x: (proxy.size.width / 2) + logicalOffset(
                    PPHomeLivingLedgerMetrics.standardTrailingFocusShift
                ),
                y: proxy.size.height / 2
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
                    compositionMaximum:
                        PPHomeLivingLedgerMetrics
                            .accessibilityCompositionMaximum
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
    /// accent is category identity only: one living ribbon gathers beneath the
    /// portrait and resolves toward the shared seam of the adjacent ledger.
    private func categoryAperture(
        width: CGFloat,
        height: CGFloat,
        compositionMaximum: CGFloat
    ) -> some View {
        let compositionSide = min(
            compositionMaximum,
            max(
                PPHomeZoneMetrics.minimumTarget,
                min(
                    width * PPHomeLivingLedgerMetrics
                        .identityCompositionWidthRatio,
                    height * 0.84
                )
            )
        )
        let washWidth = compositionSide *
            PPHomeLivingLedgerMetrics.identityWashWidthRatio
        let washHeight = compositionSide *
            PPHomeLivingLedgerMetrics.identityWashHeightRatio
        let ribbonShape = PPHomeCategoryRibbonShape(
            usesWideHeaderPath: dynamicTypeSize.isAccessibilitySize
        )
        let ribbonLineWidth: CGFloat =
            contrast == .increased ? 2.25 : 1.5

        let identityComposition = ZStack {
            ZStack {
                if contrast != .increased {
                    ribbonShape
                        .trim(from: 0, to: categoryRibbonProgress)
                        .stroke(
                            accent.opacity(
                                colorScheme == .dark ? 0.16 : 0.10
                            ),
                            style: StrokeStyle(
                                lineWidth: 6,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                }

                ribbonShape
                    .trim(from: 0, to: categoryRibbonProgress)
                    .stroke(
                        accent.opacity(
                            contrast == .increased
                                ? 0.92
                                : (colorScheme == .dark ? 0.64 : 0.52)
                        ),
                        style: StrokeStyle(
                            lineWidth: ribbonLineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
                .opacity(categoryRibbonOpacity)
                .scaleEffect(x: isRightToLeft ? -1 : 1, y: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            // The ribbon, fade, and category art now share one explicit frame
            // and one center. Enlargement therefore changes real layout bounds
            // instead of applying a post-layout scale or an offset guess.
            ZStack {
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
                                        identityWashOpacity * 0.52
                                    ),
                                    location: 0.42
                                ),
                                .init(
                                    color: accent.opacity(0),
                                    location: 0.72
                                ),
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: max(washWidth, washHeight) * 0.56
                        )
                    )
                    .frame(
                        width: washWidth,
                        height: washHeight
                    )

                identityArtwork(side: compositionSide)
            }
            .frame(
                width: max(compositionSide, washWidth),
                height: max(compositionSide, washHeight)
            )
        }
        .frame(width: width, height: height, alignment: .center)
        .overlay(alignment: .trailing) {
            Capsule()
                .fill(accent.opacity(contrast == .increased ? 0.92 : 0.68))
                .frame(
                    width: contrast == .increased ? 3 : 2,
                    height: max(PPSpace.xl, height * 0.34)
                )
                .scaleEffect(
                    y: seamPresented ? 1 : 0.08,
                    anchor: .center
                )
                .opacity(seamPresented ? 1 : 0.18)
        }

        return identityComposition
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

    /// The existing category-identity task remains the only animation owner.
    /// Its identity phase draws the portrait wrap; its seam phase completes the
    /// short ledger-facing terminal. Suppressed or inactive environments receive
    /// the same complete contour immediately, with no second timer or loop.
    private var categoryRibbonProgress: CGFloat {
        if frameMotionSuppressed { return 1 }

        switch presentationPhase {
        case .staged: return 0
        case .identity: return 0.78
        case .seam, .marketplace, .services, .settled: return 1
        }
    }

    private var categoryRibbonOpacity: Double {
        if frameMotionSuppressed { return 1 }

        switch presentationPhase {
        case .staged: return 0
        case .identity: return 0.86
        case .seam, .marketplace, .services, .settled: return 1
        }
    }

    private var frameMotionSuppressed: Bool {
        motionSuppressed || scenePhase != .active
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
                playbackEnabled: !motionSuppressed,
                tintColor: UIColor(accent)
            )
            .frame(width: side, height: side)
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
            shape.fill(Color.clear)

            ledgerIndexLine(compactRows: compactRows)

            VStack(spacing: 0) {
                ForEach(HomeMarketplaceSignalKind.allCases, id: \.self) { kind in
                    signalRow(kind: kind, compactRows: compactRows)

                    if kind != .advertisements {
                        ledgerDivider(for: kind, compactRows: compactRows)
                    }
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

    /// Measures from the same localized copy and font as the visible title, so
    /// every separator reads as that title's underline in Arabic and English.
    private func ledgerDivider(
        for kind: HomeMarketplaceSignalKind,
        compactRows: Bool
    ) -> some View {
        let lineHeight = contrast == .increased ? 1.5 : 1
        let usesCondensedLabel = compactRows ||
            (!dynamicTypeSize.isAccessibilitySize &&
                dynamicTypeSize >= .xLarge)

        return HStack(spacing: 0) {
            Text(
                signalDisplayLabel(
                    for: kind,
                    usesCompactCopy: usesCondensedLabel
                )
            )
            .font(HomeFont.caption2())
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
            .hidden()
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(
                        contrast == .increased
                            ? Color.ppTextPrimary.opacity(0.28)
                            : Color.ppSurfaceBorder.opacity(
                                colorScheme == .dark ? 0.56 : 0.74
                            )
                    )
                    .frame(height: lineHeight)
            }

            Spacer(minLength: 0)
        }
        .frame(height: lineHeight, alignment: .bottom)
        .clipped()
        .padding(
            .leading,
            rowHorizontalPadding(compactRows: compactRows)
                + PPHomeLivingLedgerMetrics.nodeSide
                + rowSpacing(compactRows: compactRows)
        )
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func signalRow(
        kind: HomeMarketplaceSignalKind,
        compactRows: Bool
    ) -> some View {
        let tone = routeTone(for: kind)

        if signals.categoryID == nil {
            signalRowContent(
                kind: kind,
                tone: tone,
                compactRows: compactRows
            )
            .opacity(signalRowPresented(kind) ? 1 : 0.26)
            .offset(
                x: signalRowPresented(kind)
                    ? 0
                    : logicalOffset(-PPSpace.sm)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(signalLabel(for: kind))
            .accessibilityValue(accessibilityValue(for: kind))
            .accessibilityHint(signalHint(for: kind))
            .accessibilitySortPriority(accessibilityPriority(for: kind))
        } else {
            Button {
                onSelectSignal(kind)
            } label: {
                signalRowContent(
                    kind: kind,
                    tone: tone,
                    compactRows: compactRows
                )
            }
            .buttonStyle(
                PPHomeSurfacePressStyle(reduceMotion: motionSuppressed)
            )
            .opacity(signalRowPresented(kind) ? 1 : 0.26)
            .offset(
                x: signalRowPresented(kind)
                    ? 0
                    : logicalOffset(-PPSpace.sm)
            )
            .disabled(isSignalLoading(kind))
            .accessibilityLabel(signalLabel(for: kind))
            .accessibilityValue(accessibilityValue(for: kind))
            .accessibilityHint(signalHint(for: kind))
            .accessibilitySortPriority(accessibilityPriority(for: kind))
        }
    }

    private func signalRowContent(
        kind: HomeMarketplaceSignalKind,
        tone: Color,
        compactRows: Bool
    ) -> some View {
        let verticalInset = compactRows ? PPSpace.xxs : PPSpace.xs
        let usesCondensedLabel = compactRows ||
            (!dynamicTypeSize.isAccessibilitySize &&
                dynamicTypeSize >= .xLarge)

        return HStack(spacing: rowSpacing(compactRows: compactRows)) {
            signalNode(for: kind, tone: tone)

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                signalValue(for: kind, tone: tone)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(signalValueIdentity(for: kind))
                    .transition(.opacity)
                    .animation(
                        motionSuppressed
                            ? nil
                            : .easeOut(duration: 0.18),
                        value: signalValueIdentity(for: kind)
                    )

                Text(
                    signalDisplayLabel(
                        for: kind,
                        usesCompactCopy: usesCondensedLabel
                    )
                )
                    .font(HomeFont.caption2())
                    .foregroundStyle(Color.homeTextSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(
                        dynamicTypeSize.isAccessibilitySize || compactRows
                            ? 2
                            : 1
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, rowHorizontalPadding(compactRows: compactRows))
        .padding(.vertical, verticalInset)
        .frame(
            maxWidth: .infinity,
            minHeight: PPHomeZoneMetrics.minimumTarget,
            maxHeight: .infinity,
            alignment: .leading
        )
        .contentShape(Rectangle())
        .background {
            Rectangle()
                .fill(Color.clear)
        }
    }

    private func rowHorizontalPadding(compactRows: Bool) -> CGFloat {
        PPHomeLivingLedgerMetrics.rowHorizontalPadding
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
                .fill(Color.clear)

            Circle()
                .fill(Color.clear)

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
        case .marketplace: return 3
        case .services: return 2
        case .advertisements: return 1
        }
    }

    // MARK: - Required finite causal motion

    private struct MotionKey: Equatable {
        let identity: String
        let suppressed: Bool
        let sceneIsActive: Bool
    }

    private var motionKey: MotionKey {
        MotionKey(
            identity: artworkIdentity,
            suppressed: motionSuppressed,
            sceneIsActive: scenePhase == .active
        )
    }

    /// Installs final geometry immediately, then reveals the category scope,
    /// shared seam, and real signal rows in semantic order. The task is tied to
    /// the selected-category identity, so a category change cancels and
    /// retargets the sequence without owning data or navigation state.
    @MainActor
    private func runEntrance() async {
        guard !reduceMotion,
              !motionSuppressed,
              scenePhase == .active,
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
                size.height - PPSpace.base
            )
        }

        var contentWidth: CGFloat {
            let horizontalInset =
                PPHomeLivingLedgerMetrics.standardHorizontalInset
            return min(
                PPHomeLivingLedgerMetrics.maximumReadableWidth,
                max(
                    0,
                    size.width - (horizontalInset * 2)
                )
            )
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

        private var minimumIdentityWidth: CGFloat {
            usesCompactRows
                ? PPHomeLivingLedgerMetrics.compactIdentityMinimum
                : PPHomeLivingLedgerMetrics.standardIdentityMinimum
        }

        private var preferredLedgerWidth: CGFloat {
            PPHomeLivingLedgerMetrics.standardLedgerWidth
        }

        var ledgerWidth: CGFloat {
            min(
                preferredLedgerWidth,
                max(0, contentWidth - horizontalGap - minimumIdentityWidth)
            )
        }

        var identityWidth: CGFloat {
            return min(
                PPHomeLivingLedgerMetrics.standardIdentityMaximum,
                max(
                    minimumIdentityWidth,
                    contentWidth - horizontalGap - ledgerWidth
                )
            )
        }

        var clusterWidth: CGFloat {
            identityWidth + horizontalGap + ledgerWidth
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
                max(60, readableHeight * 0.28)
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
