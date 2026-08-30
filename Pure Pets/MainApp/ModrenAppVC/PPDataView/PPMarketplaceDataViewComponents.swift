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
        .ppBackground
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
        ZStack {
            Color.ppMarketplaceCanvas
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(uiColor: accent).opacity(topOpacity),
                    Color(uiColor: accent).opacity(middleOpacity),
                    .clear
                ],
                startPoint: .topTrailing,
                endPoint: .center
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(uiColor: accent).opacity(glowOpacity),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 330
            )
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var topOpacity: Double {
        guard contrast != .increased else { return 0 }
        if usesBrandAccent {
            return colorScheme == .dark ? 0.075 : 0.045
        }
        return colorScheme == .dark ? 0.16 : 0.10
    }

    private var middleOpacity: Double {
        guard contrast != .increased else { return 0 }
        if usesBrandAccent {
            return colorScheme == .dark ? 0.025 : 0.014
        }
        return colorScheme == .dark ? 0.06 : 0.035
    }

    private var glowOpacity: Double {
        guard contrast != .increased else { return 0 }
        if usesBrandAccent {
            return colorScheme == .dark ? 0.03 : 0.014
        }
        return colorScheme == .dark ? 0.07 : 0.04
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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            heroSurface

            PPMarketplaceHeroWave(
                accentColor: store.accentColor,
                heroFlowOpacity: heroFlowOpacity,
                heroFlowTailOpacity: heroFlowTailOpacity,
                isRightToLeft: store.isRightToLeft
            )
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 156 : 96)
            .accessibilityHidden(true)

            content
                .padding(heroPadding)
        }
        .frame(maxWidth: .infinity)
        .clipShape(
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .strokeBorder(heroBorder, lineWidth: heroBorderWidth)
        }
        .shadow(
            color: contrast == .increased
                ? .clear
                : Color.black.opacity(colorScheme == .dark ? 0.14 : 0.055),
            radius: 22,
            y: 10
        )
        .padding(.horizontal, horizontalInset)
        .accessibilityElement(children: .contain)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            topContextRail

            browseCommands
        }
    }

    private var topContextRail: some View {
        HStack(alignment: .center, spacing: 0) {
            backControl

            topContextSeparator

            identity
                .layoutPriority(1)

            topContextSeparator

            sectionGlyph
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: topRailControlSize)
        .background {
            topContextShape
                .fill(
                    colorScheme == .dark
                        ? Color.ppSurfaceRaised
                        : Color.white
                )
        }
        .overlay {
            topContextShape
                .strokeBorder(heroBorder, lineWidth: heroBorderWidth)
        }
        .shadow(
            color: contrast == .increased
                ? .clear
                : Color.black.opacity(colorScheme == .dark ? 0.10 : 0.045),
            radius: 12,
            y: 5
        )
    }

    private var topContextSeparator: some View {
        Rectangle()
            .fill(
                contrast == .increased
                    ? Color.ppMarketplaceTextPrimary.opacity(0.68)
                    : Color.ppSeparator.opacity(
                        colorScheme == .dark ? 0.82 : 0.68
                    )
            )
            .frame(
                width: contrast == .increased
                    ? 1.5
                    : 1 / UIScreen.main.scale
            )
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 12 : 10)
            .accessibilityHidden(true)
    }

    private var topContextShape: Capsule {
        Capsule(style: .continuous)
    }

    private var backControl: some View {
        PPMarketplaceBackControl(
            accent: store.accentColor,
            isRightToLeft: store.isRightToLeft,
            isEmbedded: true,
            action: store.goBack
        )
        .frame(width: topRailControlSize, height: topRailControlSize)
        .opacity(showsBackControl ? 1 : 0)
        .allowsHitTesting(showsBackControl)
        .accessibilityHidden(!showsBackControl)
    }

    private var identity: some View {
        PPMarketplaceSmartContextPill(
            store: store,
            action: store.beginFilterEditing
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var sectionGlyph: some View {
        PPMarketplaceSectionGlyphPlate(
            store: store,
            reduceMotion: reduceMotion,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
    }

    private var browseCommands: some View {
        HStack(alignment: .center, spacing: heroControlMetrics.spacing) {
            categoryCommand
                .frame(maxWidth: .infinity)

            searchCommand
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var categoryCommand: some View {
        HStack(spacing: PPSpace.xs) {
            VStack(spacing: 0) {
                mainKindMenu
                Divider()
                    .padding(.leading, PPSpace.sm)
                subKindMenu
            }

            // The hero keeps category selection compact; the filter affordance
            // remains available through the marketplace's full filter surface.
        }
        .padding(.horizontal, PPSpace.xs)
        .padding(.vertical, PPSpace.xxs)
        .frame(
            maxWidth: .infinity,
            minHeight: max(
                heroControlMetrics.categoryMinimumHeight,
                dynamicTypeSize.isAccessibilitySize ? 112 : 92
            ),
            alignment: .leading
        )
        .background(
            heroCommandSurface,
            in: RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
            .strokeBorder(heroBorder, lineWidth: 1)
        }
        .accessibilityIdentifier("pp.marketplace.category")
        .disabled(store.isReplacingContext)
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
                text: PPMarketplaceText.formatted(
                    "marketplace_category_main_kind_format",
                    store.currentMainKindTitle
                ),
                primary: true
            )
        }
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
                text: PPMarketplaceText.formatted(
                    "marketplace_category_subkind_format",
                    store.currentSubKindTitle
                ),
                primary: false
            )
        }
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_category_subkind_hint")
        )
        .accessibilityIdentifier("pp.marketplace.category.subkind")
    }

    private func categoryMenuLabel(
        text: String,
        primary: Bool
    ) -> some View {
        HStack(spacing: PPSpace.sm) {
            Text(text)
                .font(primary ? HomeFont.headline() : HomeFont.footnote())
                .foregroundStyle(
                    primary
                        ? Color.ppMarketplaceTextPrimary
                        : Color.ppMarketplaceTextSecondary
                )
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.ppMarketplaceTextSecondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, PPSpace.sm)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var searchCommand: some View {
        Button(action: store.openSearch) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(uiColor: store.accentColor))
                .frame(
                    width: heroControlMetrics.searchButtonSize,
                    height: heroControlMetrics.searchButtonSize
                )
                .background(
                    heroCommandSurface,
                    in: RoundedRectangle(
                        cornerRadius: PPCorner.medium,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: PPCorner.medium,
                        style: .continuous
                    )
                    .strokeBorder(heroBorder, lineWidth: 1)
                }
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: PPCorner.medium,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(PPMarketplacePressStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(PPMarketplaceText.localized("marketplace_search_title"))
        .accessibilityHint(PPMarketplaceText.localized("marketplace_search_hint"))
        .accessibilityIdentifier("pp.marketplace.search")
    }

    private var heroCommandSurface: Color {
        Color.ppMarketplaceSurface.opacity(
            colorScheme == .dark ? 0.92 : 0.97
        )
    }

    private var heroControlMetrics: PPMarketplaceHeroControlLayoutMetrics {
        PPMarketplaceHeroControlLayoutPolicy.metrics(
            availableWidth: availableWidth,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
            layoutDirection: store.isRightToLeft ? .rightToLeft : .leftToRight
        )
    }

    private var topRailControlSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 64 : 52
    }

    private var heroSurface: some View {
        RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.ppMarketplaceSurface,
                        Color(uiColor: store.accentColor).opacity(
                            heroSurfaceAccentOpacity
                        )
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var heroBorder: Color {
        contrast == .increased
            ? Color.ppMarketplaceTextPrimary
            : Color(uiColor: store.accentColor).opacity(heroBorderOpacity)
    }

    private var heroBorderWidth: CGFloat {
        contrast == .increased ? 2 : 1
    }

    private var horizontalInset: CGFloat {
        horizontalSizeClass == .regular ? PPSpace.xxl : PPSpace.screenMargin
    }

    private var heroPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? PPSpace.lg : PPSpace.md
    }

    private var heroFlowOpacity: Double {
        guard store.usesBrandAccent else { return 0.18 }
        return colorScheme == .dark ? 0.11 : 0.08
    }

    private var heroFlowTailOpacity: Double {
        store.usesBrandAccent ? 0.01 : 0.02
    }

    private var heroSurfaceAccentOpacity: Double {
        if store.usesBrandAccent {
            return colorScheme == .dark ? 0.055 : 0.025
        }
        return colorScheme == .dark ? 0.10 : 0.055
    }

    private var heroBorderOpacity: Double {
        if store.usesBrandAccent {
            return colorScheme == .dark ? 0.15 : 0.09
        }
        return colorScheme == .dark ? 0.22 : 0.14
    }

    private var heroAuxiliarySurfaceOpacity: Double {
        if store.usesBrandAccent {
            return colorScheme == .dark ? 0.075 : 0.055
        }
        return colorScheme == .dark ? 0.13 : 0.10
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceBackControl: View {
    let accent: UIColor
    let isRightToLeft: Bool
    var isEmbedded = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isRightToLeft ? "chevron.right" : "chevron.left")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(uiColor: accent))
                .frame(width: 44, height: 44)
                .background {
                    if !isEmbedded {
                        Circle()
                            .fill(.ultraThinMaterial)
                    }
                }
                .overlay {
                    if !isEmbedded {
                        Circle()
                            .strokeBorder(
                                Color(uiColor: accent).opacity(0.20),
                                lineWidth: 1
                            )
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .shadow(
            color: isEmbedded ? .clear : Color.black.opacity(0.08),
            radius: 10,
            y: 5
        )
        .accessibilityLabel(PPMarketplaceText.localized("Back"))
        .accessibilityIdentifier("pp.marketplace.back")
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceCurrentFlowShape: Shape {
    let isRightToLeft: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()

        if isRightToLeft {
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.52))
            path.addCurve(
                to: CGPoint(x: rect.minX, y: rect.minY),
                control1: CGPoint(x: rect.width * 0.68, y: rect.maxY * 1.08),
                control2: CGPoint(x: rect.width * 0.30, y: rect.maxY * 0.12)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.52))
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control1: CGPoint(x: rect.width * 0.32, y: rect.maxY * 1.08),
                control2: CGPoint(x: rect.width * 0.70, y: rect.maxY * 0.12)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceHeroWave: View {
    let accentColor: UIColor
    let heroFlowOpacity: Double
    let heroFlowTailOpacity: Double
    let isRightToLeft: Bool

    var body: some View {
        PPMarketplaceCurrentFlowShape(isRightToLeft: isRightToLeft)
            .fill(
                LinearGradient(
                    colors: [
                        Color(uiColor: accentColor)
                            .opacity(heroFlowOpacity),
                        Color(uiColor: accentColor)
                            .opacity(heroFlowTailOpacity)
                    ],
                    startPoint: isRightToLeft ? .topLeading : .topTrailing,
                    endPoint: isRightToLeft ? .bottomTrailing : .bottomLeading
                )
            )
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceSectionGlyphPlate: View {
    @ObservedObject var store: PPMarketplaceDataViewStore
    let reduceMotion: Bool
    let isAccessibilitySize: Bool

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseRotation: Double = 0.0
    @State private var isGlowing: Bool = false

    private var activeIconName: String {
        let context = store.navigationContext
        let name = context.systemImageName.isEmpty
            ? store.currentSectionDescriptor.iconName
            : context.systemImageName
        return name.isEmpty ? "storefront.fill" : name
    }

    var body: some View {
        ZStack {
            Image(systemName: activeIconName)
                .font(.system(
                    size: isAccessibilitySize ? 24 : 20,
                    weight: .semibold
                ))
                .foregroundStyle(Color(uiColor: store.accentColor))
                .symbolRenderingMode(.hierarchical)
                .id("\(activeIconName)_\(store.currentMainKindID)")
                .transition(reduceMotion ? .opacity : .scale(scale: 0.75).combined(with: .opacity))
        }
        .frame(
            width: isAccessibilitySize ? 64 : 52,
            height: isAccessibilitySize ? 64 : 52
        )
        .scaleEffect(reduceMotion ? 1.0 : pulseScale)
        .rotationEffect(.degrees(reduceMotion ? 0 : pulseRotation))
        .shadow(
            color: Color(uiColor: store.accentColor).opacity(reduceMotion ? 0 : (isGlowing ? 0.30 : 0.08)),
            radius: isGlowing ? 10 : 4
        )
        .onChange(of: store.currentMainKindID) { _ in
            triggerSectionChangeMotion()
        }
        .onChange(of: activeIconName) { _ in
            triggerSectionChangeMotion()
        }
        .accessibilityHidden(true)
    }

    private func triggerSectionChangeMotion() {
        guard !reduceMotion else { return }
        pulseScale = 0.82
        pulseRotation = -12
        isGlowing = true
        withAnimation(.spring(response: 0.36, dampingFraction: 0.58)) {
            pulseScale = 1.15
            pulseRotation = 6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                pulseScale = 1.0
                pulseRotation = 0
                isGlowing = false
            }
        }
    }
}

// MARK: - Smart Context Pill (Animated V6)
//
// Motion contract (NextGen V6):
//   decision: feedback
//   trigger: user-initiated category/filter/species change, occasional (2–9/session)
//   intent: acknowledge navigation context change; preserve spatial continuity of the pill label
//   phases: 2 — (1) old text exits upward with fade, (2) new text enters from below with fade
//   mechanism: SwiftUI .transition + withAnimation spring
//   reduce-motion: instant crossfade (opacity only), no spatial movement
//   RTL: uses .leading alignment — no mirrored directional slide needed
//   lifecycle: stops on disappearance (SwiftUI default); no infinite loop
//   accessibility: VoiceOver announces new label via .accessibilityLabel update
//   duration: ~0.28s spring (response 0.28, damping 0.82) — under 300ms feedback cap

@available(iOS 15.0, *)
private struct PPMarketplaceSmartContextPill: View {
    @ObservedObject var store: PPMarketplaceDataViewStore
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Animation state
    @State private var contextRevision: Int = 0
    @State private var pillScale: CGFloat = 1.0
    @State private var chevronRotation: Double = 0.0

    // Track previous values to detect changes
    @State private var lastTitle: String = ""
    @State private var lastSubtitle: String = ""

    private var context: PPMarketplaceNavigationContext {
        store.navigationContext
    }

    private var isEnabled: Bool {
        !store.isReplacingContext
    }

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: PPSpace.xs) {
                contextLabels
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                chevronIcon
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, PPSpace.sm)
        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: .infinity, alignment: .leading)
        .scaleEffect(pillScale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            context.accessibilityLabel.isEmpty ? context.title : context.accessibilityLabel
        )
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_filters_open_hint")
        )
        .accessibilityIdentifier("pp.data.filters.smartDockedPill")
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.58)
        .onChange(of: context.title) { newTitle in
            guard newTitle != lastTitle else { return }
            lastTitle = newTitle
            triggerContextChangeMotion()
        }
        .onChange(of: context.subtitle) { newSubtitle in
            guard newSubtitle != lastSubtitle else { return }
            lastSubtitle = newSubtitle
            triggerContextChangeMotion()
        }
        .onAppear {
            lastTitle = context.title
            lastSubtitle = context.subtitle
        }
    }

    // MARK: - Context Labels (animated)

    private var contextLabels: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title — keyed by content for identity-based transition
            Text(context.title)
                .font(HomeFont.bold(12.8))
                .foregroundStyle(Color.ppMarketplaceTextPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .id("pill_title_\(contextRevision)")
                .transition(contextTextTransition)

            // Subtitle
            if !context.subtitle.isEmpty {
                Text(context.subtitle)
                    .font(HomeFont.medium(10.4))
                    .foregroundStyle(Color.ppMarketplaceTextSecondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .id("pill_subtitle_\(contextRevision)")
                    .transition(contextTextTransition)
            }
        }
        .animation(contextChangeAnimation, value: contextRevision)
    }

    // MARK: - Chevron

    private var chevronIcon: some View {
        Image(systemName: "chevron.down.circle.fill")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color(uiColor: store.accentColor))
            .frame(width: 44, height: 44)
            .rotationEffect(.degrees(chevronRotation))
            .accessibilityHidden(true)
    }

    // MARK: - Motion

    /// Vertical slide + fade for spatial continuity on context change.
    /// Reduce Motion: opacity-only crossfade preserving equivalent meaning.
    private var contextTextTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }

    private var contextChangeAnimation: Animation? {
        if reduceMotion {
            return .easeOut(duration: 0.15)
        }
        return .spring(response: 0.28, dampingFraction: 0.82)
    }

    private func triggerContextChangeMotion() {
        // Bump revision to swap text identity → triggers transition
        withAnimation(contextChangeAnimation) {
            contextRevision &+= 1
        }

        // Subtle pill breathe (matches SectionGlyphPlate pattern)
        guard !reduceMotion else { return }

        pillScale = 0.96
        chevronRotation = -8

        withAnimation(.spring(response: 0.26, dampingFraction: 0.62)) {
            pillScale = 1.02
            chevronRotation = 4
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.76)) {
                pillScale = 1.0
                chevronRotation = 0
            }
        }
    }

    // MARK: - Interaction

    private func handleTap() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        action()
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceCurrentDock: View {
    @ObservedObject var store: PPMarketplaceDataViewStore
    let showsPinnedBackControl: Bool
    let statusBarHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            sectionRail
            actionRail
        }
        .padding(.top, PPSpace.sm)
        .padding(.bottom, PPSpace.md)
        .overlay(alignment: .bottom) {
            PPMarketplaceDockLiquidBottomBorder(
                accent: .ppSoftRose,
                contrast: contrast
            )
        }
        .background {
            GeometryReader { dockProxy in
                let distanceToMainViewTop: CGFloat = 34
                let resolvedStatusBarHeight = max(statusBarHeight, 0)
                let totalTopExtension =
                    distanceToMainViewTop + resolvedStatusBarHeight
                // The thin glass is hidden in the resting state and becomes
                // visible only as the controls dock takes pinned ownership.
                let pinnedMaterialProgress: CGFloat =
                    showsPinnedBackControl ? 1 : 0
                PPMarketplaceFadedDockMaterial()
                    .frame(
                        height: dockProxy.size.height + totalTopExtension
                    )
                    .overlay(alignment: .bottom) {
                        PPMarketplacePinnedDockMaterial(
                            revealProgress: pinnedMaterialProgress
                        )
                        .frame(
                            height:
                                dockProxy.size.height +
                                resolvedStatusBarHeight
                        )
                    }
                    // Frame growth is placed entirely above the dock. Keeping
                    // the equal negative offset preserves the pinned bottom
                    // edge and leaves the status-bar extension content-free.
                    .offset(y: -totalTopExtension)
            }
        }
        .zIndex(4)
    }

    private var sectionRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PPSpace.sm) {
                ForEach(store.sections) { descriptor in
                    let selected = descriptor.rawValue == store.currentSection.rawValue
                    Button {
                        store.selectSection(descriptor)
                    } label: {
                        HStack(spacing: PPSpace.sm) {
                            Image(systemName: descriptor.iconName)
                                .font(.system(size: 13, weight: .semibold))
                                .accessibilityHidden(true)
                            Text(PPMarketplaceText.localized(descriptor.titleKey))
                                .font(HomeFont.bold(15))
                                .lineLimit(1)
                        }
                        .foregroundStyle(
                            selected
                                ? .white
                                : Color.ppMarketplaceTextSecondary
                        )
                        .padding(.horizontal, PPSpace.base)
                        .frame(minHeight: 44)
                        .background {
                            selectedCurrentBackground
                                .opacity(selected ? 1 : 0)
                        }
                        .contentShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        PPMarketplaceText.localized(descriptor.titleKey)
                    )
                    .accessibilityHint(
                        PPMarketplaceText.localized("marketplace_section_select_hint")
                    )
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, horizontalInset)
            .animation(sectionSelectionAnimation, value: store.currentSection.rawValue)
        }
    }

    @ViewBuilder
    private var selectedCurrentBackground: some View {
        let capsule = Capsule(style: .continuous)
            .fill(store.accentPalette.fill)
            .shadow(
                color: Color(uiColor: store.accentColor).opacity(
                    contrast == .increased ? 0 : 0.20
                ),
                radius: 7,
                y: 3
            )
        capsule
    }

    private var actionRail: some View {
        HStack(spacing: PPSpace.sm) {
            if showsPinnedBackControl {
                PPMarketplaceBackControl(
                    accent: store.accentColor,
                    isRightToLeft: store.isRightToLeft,
                    action: store.goBack
                )
                .padding(.leading, horizontalInset)
                .transition(pinnedBackControlTransition)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PPSpace.sm) {
                    Button(action: store.beginFilterEditing) {
                        PPMarketplaceActionChipLabel(
                            icon: "line.3.horizontal.decrease.circle.fill",
                            title: PPMarketplaceText.localized("filterPPAction"),
                            badge: store.activeFilterCount,
                            selected: store.activeFilterCount > 0,
                            accent: store.accentColor
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(
                        PPMarketplaceText.localized("marketplace_filters_open_hint")
                    )

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
                            PPMarketplaceActionChipLabel(
                                icon: group.chipIconName ?? "slider.horizontal.3",
                                title: filterChipTitle(group),
                                badge: 0,
                                selected: isActive(group),
                                accent: store.accentColor
                            )
                        }
                    }

                    if store.bridge.sectionSupportsProviderFilter(store.currentSection),
                       !store.providerOptions.isEmpty {
                        Button(action: store.presentProviderFilter) {
                            PPMarketplaceActionChipLabel(
                                icon: "storefront.fill",
                                title: selectedProviderTitle,
                                badge: 0,
                                selected: store.selectedProviderID != nil,
                                accent: store.accentColor
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Menu {
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
                    } label: {
                        PPMarketplaceActionChipLabel(
                            icon: store.layout.iconName,
                            title: PPMarketplaceText.localized(store.layout.titleKey),
                            badge: 0,
                            selected: false,
                            accent: store.accentColor
                        )
                    }

                    Text(store.resultCountText)
                        .font(HomeFont.bold(12))
                        .foregroundStyle(Color.ppMarketplaceTextSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, PPSpace.md)
                        .frame(minHeight: 44)
                        .background(
                            Color.ppMarketplaceSurface.opacity(0.72),
                            in: Capsule(style: .continuous)
                        )
                        .accessibilityLabel(store.resultCountText)

                    if store.isRefreshing {
                        ProgressView()
                            .tint(Color(uiColor: store.accentColor))
                            .frame(width: 44, height: 44)
                            .background(
                                Color.ppMarketplaceSurface.opacity(0.72),
                                in: Circle()
                            )
                            .accessibilityLabel(
                                PPMarketplaceText.localized("marketplace_refreshing")
                            )
                    }
                }
                .padding(.leading, showsPinnedBackControl ? 0 : horizontalInset)
                .padding(.trailing, horizontalInset)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(minHeight: 44)
        .animation(pinnedBackControlAnimation, value: showsPinnedBackControl)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            PPMarketplaceText.localized("marketplace_browse_controls")
        )
    }

    private func isActive(_ group: PPFilterGroup) -> Bool {
        group.isActive()
    }

    private func filterChipTitle(_ group: PPFilterGroup) -> String {
        guard isActive(group),
              let selected = group.options.first(where: {
                  $0.value == group.selectedValue
              }) else {
            return group.title
        }
        return selected.title
    }

    private var selectedProviderTitle: String {
        guard let providerID = store.selectedProviderID,
              let provider = store.providerOptions.first(where: {
                  $0.providerID == providerID
              }) else {
            return PPMarketplaceText.localized("dataview_filter_by_provider")
        }
        return provider.title
    }

    private var horizontalInset: CGFloat {
        horizontalSizeClass == .regular ? PPSpace.xxl : PPSpace.screenMargin
    }

    private var interactionMotionIsDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }

    private var sectionSelectionAnimation: Animation? {
        interactionMotionIsDisabled
            ? nil
            : .easeOut(duration: 0.16)
    }

    private var pinnedBackControlAnimation: Animation? {
        interactionMotionIsDisabled
            ? nil
            : .easeOut(duration: 0.20)
    }

    private var pinnedBackControlTransition: AnyTransition {
        interactionMotionIsDisabled
            ? .identity
            : .move(edge: .leading).combined(with: .opacity)
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceFadedDockMaterial: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
            Rectangle()
                // `systemBackground` is the requested white fade in light
                // appearance and remains legible against semantic label colors
                // when the device changes to dark appearance.
                .fill(Color(uiColor: .systemBackground).opacity(0.86))
        }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0.96), location: 0.36),
                    .init(color: .black.opacity(0.62), location: 0.72),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }
        .ignoresSafeArea(.container, edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@available(iOS 15.0, *)
private struct PPMarketplacePinnedDockMaterial: View {
    let revealProgress: CGFloat

    var body: some View {
        Rectangle()
            .fill(.thinMaterial)
            .opacity(Double(revealProgress))
            .ignoresSafeArea(.container, edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceDockLiquidBottomBorder: View {
    let accent: UIColor
    let contrast: ColorSchemeContrast

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color.ppMarketplaceSurface.opacity(0.95),
                    Color(uiColor: accent).opacity(0.35),
                    Color.ppMarketplaceSurface,
                    Color(uiColor: accent).opacity(0.28),
                    Color.ppMarketplaceSurface.opacity(0.95)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: contrast == .increased ? 2.5 : 1.5)
            .blur(radius: 0.5)

            LinearGradient(
                colors: [
                    Color.ppMarketplaceSurface,
                    Color(uiColor: accent).opacity(0.50),
                    Color.ppMarketplaceSurface.opacity(0.90),
                    Color(uiColor: accent).opacity(0.50),
                    Color.ppMarketplaceSurface
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: contrast == .increased ? 2 : 1)
        }
        .shadow(color: Color.ppMarketplaceSurface.opacity(0.55), radius: 3, x: 0, y: 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceActionChipLabel: View {
    let icon: String
    let title: String
    let badge: Int
    let selected: Bool
    let accent: UIColor

    private var palette: PPMarketplaceAccentPalette {
        PPMarketplaceAccentPalette(accent: accent)
    }

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .accessibilityHidden(true)
            Text(title)
                .font(HomeFont.bold(13))
                .lineLimit(1)
            if badge > 0 {
                Text("\(badge)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .frame(minWidth: 18, minHeight: 18)
                    .background(
                        selected ? palette.onAccent.opacity(0.16) : palette.fill,
                        in: Circle()
                    )
                    .foregroundStyle(palette.onAccent)
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .opacity(0.70)
                .accessibilityHidden(true)
        }
        .foregroundStyle(
            selected
                ? palette.onAccent
                : Color.ppMarketplaceTextPrimary
        )
        .padding(.horizontal, PPSpace.md)
        .frame(minHeight: 44)
        .background(
            selected
                ? palette.fill
                : Color.ppMarketplaceSurface,
            in: Capsule(style: .continuous)
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    selected
                        ? Color.clear
                        : Color.ppMarketplaceSeparator.opacity(0.38),
                    lineWidth: 1
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
                    borderMode: .pordersDataView,
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
                .font(HomeFont.headline())
            Text(PPMarketplaceText.localized("marketplace_skeleton_subtitle"))
                .font(HomeFont.subheadline())
            Text(PPMarketplaceText.localized("marketplace_skeleton_price"))
                .font(HomeFont.title2())
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
                    .font(HomeFont.title2())
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(HomeFont.callout())
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
                    .font(HomeFont.subheadline())
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
