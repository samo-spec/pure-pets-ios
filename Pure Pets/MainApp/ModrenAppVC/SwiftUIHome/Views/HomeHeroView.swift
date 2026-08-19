import SwiftUI
import UIKit
import Combine

private let homeHeroShowsSelectedMainKindArtwork = true

struct HomeHeroView: View {
    let pages: [HomeHeroPage]
    let selectedIndex: Int
    let onSelect: (Int) -> Void
    let onPrimaryAction: () -> Void
    let onSecondaryAction: () -> Void
    let onInteractionChanged: (Bool) -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @ScaledMetric(relativeTo: .title) private var heroHeight: CGFloat =
        HomeVisualTokens.heroHeight
    
    private var selectedPage: HomeHeroPage? {
        guard pages.indices.contains(selectedIndex) else { return nil }
        return pages[selectedIndex]
    }
    
    private var resolvedHeroHeight: CGFloat {
        min(heroHeight, dynamicTypeSize.isAccessibilitySize ? 458 : 332)
    }
    
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
                HomeHeroSkeleton()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: resolvedHeroHeight)
        .accessibilityElement(children: .contain)
    }
    
    private func hero(_ page: HomeHeroPage) -> some View {
        let accent = Color(hex: page.accentHex)
        return ZStack {
            HomeHeroField(
                accent: accent,
                increasedContrast: contrast == .increased,
                cornerGlowOpacityScale: 0.78,
                isAnimated: true
            )
            
            // Next-Gen V6 Ambient Living Flanks (Left & Right Bubbles & Icons)
            PPHomeHeroFlankLivingBubblesView(
                accent: accent,
                isDark: colorScheme == .dark
            )
            
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let compactWidth = proxy.size.width < 350
                    
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            heroCopy(page, accent: accent)
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .leading
                                )
                        } else {
                            HStack(
                                alignment: .center,
                                spacing: compactWidth ? 6 : 10
                            ) {
                                if isRightToLeft {
                                    heroArtwork(
                                        page,
                                        accent: accent,
                                        compact: compactWidth
                                    )
                                    .layoutPriority(0)
                                    
                                    heroCopy(page, accent: accent)
                                        .environment(
                                            \.layoutDirection,
                                             .rightToLeft
                                        )
                                        .layoutPriority(1)
                                } else {
                                    heroCopy(page, accent: accent)
                                        .environment(
                                            \.layoutDirection,
                                             .leftToRight
                                        )
                                        .layoutPriority(1)
                                    
                                    heroArtwork(
                                        page,
                                        accent: accent,
                                        compact: compactWidth
                                    )
                                    .layoutPriority(0)
                                }
                            }
                            .environment(\.layoutDirection, .leftToRight)
                            .frame(maxHeight: .infinity)
                        }
                    }
                    .padding(
                        .horizontal,
                        compactWidth ? PPSpace.sm : PPSpace.base
                    )
                    .padding(.top, PPSpace.sm)
                    .padding(
                        .bottom,
                        allowsPaging ? PPSpace.xxs : PPSpace.sm
                    )
                }
                
                if allowsPaging {
                    pageControl(accent: accent)
                        .padding(.bottom, PPSpace.xs)
                }
            }
            .id(page.id)
            .transition(
                heroPageTransition
            )
        }
        .modifier(
            HomeHeroPageMotionModifier(
                pageID: AnyHashable(page.id),
                reduceMotion: reduceMotion
            )
        )
        .clipShape(
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
        )
        .overlay {
            HomeHeroBorder(
                accent: accent,
                darkMode: colorScheme == .dark,
                increasedContrast: contrast == .increased
            )
        }
        .shadow(
            color: Color.black.opacity(
                contrast == .increased
                ? 0
                : (colorScheme == .dark ? 0.20 : 0.06)
            ),
            radius: HomeVisualTokens.heroShadowRadius,
            y: HomeVisualTokens.heroShadowOffsetY
        )
        .contentShape(
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
        )
        .modifier(
            HomeHeroPagingGestureModifier(
                isEnabled: allowsPaging,
                selectedIndex: selectedIndex,
                pageCount: pages.count,
                layoutDirection: layoutDirection,
                onSelect: onSelect,
                onInteractionChanged: onInteractionChanged
            )
        )
        .accessibilityLabel(
            [page.eyebrow, page.title, page.subtitle]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        )
        .modifier(
            HomeHeroPagingAccessibilityModifier(
                isEnabled: allowsPaging,
                selectedIndex: selectedIndex,
                pageCount: pages.count,
                onSelect: onSelect
            )
        )
    }
    
    private func heroCopy(
        _ page: HomeHeroPage,
        accent: Color
    ) -> some View {
        VStack(alignment: .center, spacing: 10) {
            eyebrowLabel(page, accent: accent)
                .frame(maxWidth: .infinity, alignment: .center)
            
            VStack(alignment: .center, spacing: 4) {
                Text(compactHeroTitle(page.title))
                    .font(HomeFont.title1())
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .allowsTightening(true)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )
                    .accessibilityLabel(page.title)
                    .accessibilityAddTraits(.isHeader)
                
                Text(page.subtitle)
                    .font(HomeFont.subheadline())
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 5 : 2)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            heroMetaPill(page, accent: accent)
                .frame(maxWidth: .infinity, alignment: .center)
            
            primaryButton(page, accent: accent)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func heroMetaPill(
        _ page: HomeHeroPage,
        accent: Color
    ) -> some View {
        let items = heroMetaItems(for: page)
        return HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(accent.opacity(colorScheme == .dark ? 0.35 : 0.22))
                        .frame(width: 1, height: 11)
                        .padding(.horizontal, 6)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accent)
                    
                    Text(item.title)
                        .font(HomeFont.bold(11.5))
                        .foregroundStyle(Color.ppTextPrimary.opacity(0.88))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(accent.opacity(colorScheme == .dark ? 0.14 : 0.08))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    accent.opacity(colorScheme == .dark ? 0.28 : 0.18),
                    lineWidth: 0.85
                )
        )
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func heroMetaItems(for page: HomeHeroPage) -> [HomeHeroMetaItem] {
        switch page.kind {
        case .marketplace:
            return [
                HomeHeroMetaItem(
                    symbol: "shippingbox.fill",
                    title: HomeModelAdapter.localized(
                        "home_hero_stat_products",
                        fallback: "منتجات حصرية"
                    )
                ),
                HomeHeroMetaItem(
                    symbol: "sparkles",
                    title: HomeModelAdapter.localized(
                        "home_hero_stat_services",
                        fallback: "خدمات موثوقة"
                    )
                ),
                HomeHeroMetaItem(
                    symbol: "checkmark.shield.fill",
                    title: HomeModelAdapter.localized(
                        "home_hero_stat_verified",
                        fallback: "مزودون معتمدون"
                    )
                ),
            ]
        case .pet:
            return [
                HomeHeroMetaItem(
                    symbol: "heart.fill",
                    title: HomeModelAdapter.localized(
                        "home_hero_stat_health",
                        fallback: "صحة ورعاية"
                    )
                ),
                HomeHeroMetaItem(
                    symbol: "pawprint.fill",
                    title: HomeModelAdapter.localized(
                        "home_hero_stat_profile",
                        fallback: "ملف متكامل"
                    )
                ),
            ]
        case .reminder:
            return [
                HomeHeroMetaItem(
                    symbol: "bell.fill",
                    title: HomeModelAdapter.localized(
                        "home_hero_stat_schedule",
                        fallback: "تذكير ذكي"
                    )
                ),
                HomeHeroMetaItem(
                    symbol: "calendar.badge.clock",
                    title: HomeModelAdapter.localized(
                        "home_hero_stat_on_time",
                        fallback: "في الموعد"
                    )
                ),
            ]
        case .promotion:
            return [
                HomeHeroMetaItem(
                    symbol: "tag.fill",
                    title: HomeModelAdapter.localized(
                        "home_hero_stat_offer",
                        fallback: "خصم خاص"
                    )
                ),
                HomeHeroMetaItem(
                    symbol: "bolt.fill",
                    title: HomeModelAdapter.localized(
                        "home_hero_stat_fast",
                        fallback: "توصيل سريع"
                    )
                ),
            ]
        case .pharmacy:
            return [
                HomeHeroMetaItem(
                    symbol: "pills.fill",
                    title: HomeModelAdapter.localized(
                        "home_hero_stat_pharmacy",
                        fallback: "أدوية معتمدة"
                    )
                ),
                HomeHeroMetaItem(
                    symbol: "cross.case.fill",
                    title: HomeModelAdapter.localized(
                        "home_hero_stat_vet_care",
                        fallback: "رعاية بيطرية"
                    )
                ),
            ]
        case .petOnboarding:
            return [
                HomeHeroMetaItem(
                    symbol: "plus.circle.fill",
                    title: HomeModelAdapter.localized(
                        "home_hero_stat_new_pet",
                        fallback: "أضف أليفك"
                    )
                ),
                HomeHeroMetaItem(
                    symbol: "sparkles",
                    title: HomeModelAdapter.localized(
                        "home_hero_stat_custom_care",
                        fallback: "رعاية مخصصة"
                    )
                ),
            ]
        }
    }
    
    private func eyebrowLabel(
        _ page: HomeHeroPage,
        accent: Color
    ) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(accent)
                .frame(width: 6, height: 6)
                .overlay {
                    Circle()
                        .stroke(accent.opacity(0.24), lineWidth: 4)
                }
                .accessibilityHidden(true)
            
            Text(page.eyebrow)
                .font(HomeFont.bold(11))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .accessibilityElement(children: .combine)
    }
    
    private func compactHeroTitle(_ title: String) -> String {
        return title
    }
    
    private func primaryButton(
        _ page: HomeHeroPage,
        accent: Color
    ) -> some View {
        Button(action: onPrimaryAction) {
            HStack(alignment: .center, spacing: PPSpace.xs) {
                Text(page.primaryTitle)
                    .font(HomeFont.bold(15))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.84)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                Spacer(minLength: PPSpace.xs)
                
                Image(systemName: "arrow.forward")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(
                        Color.white.opacity(0.16),
                        in: Circle()
                    )
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .foregroundStyle(Color.white)
            .frame(
                maxWidth: .infinity,
                minHeight: 48,
                alignment: .leading
            )
            .padding(.leading, PPSpace.base)
            .padding(.trailing, 10)
            .background(
                LinearGradient(
                    colors: [
                        accent,
                        accent.opacity(0.86)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            }
            .shadow(
                color: accent.opacity(colorScheme == .dark ? 0.42 : 0.28),
                radius: 12,
                x: 0,
                y: 6
            )
        }
        .buttonStyle(
            HomeHeroPrimaryButtonStyle(reduceMotion: reduceMotion)
        )
        .accessibilityHint(
            HomeModelAdapter.localized(
                "home_pulse_opens_destination_a11y",
                fallback: "Opens this destination"
            )
        )
    }
    
    private var heroPageTransition: AnyTransition {
        let incomingX: CGFloat = isRightToLeft ? -34 : 34
        let outgoingX: CGFloat = isRightToLeft ? 24 : -24
        return .asymmetric(
            insertion: .modifier(
                active: HomeHeroPagePhase(
                    opacity: 0,
                    offsetX: incomingX,
                    scale: 1
                ),
                identity: HomeHeroPagePhase.identity
            ),
            removal: .modifier(
                active: HomeHeroPagePhase(
                    opacity: 0,
                    offsetX: outgoingX,
                    scale: 1
                ),
                identity: HomeHeroPagePhase.identity
            )
        )
    }
    
    @ViewBuilder
    private func heroArtwork(
        _ page: HomeHeroPage,
        accent: Color,
        compact: Bool
    ) -> some View {
        let asset = heroArtworkAsset(for: page)
        HomeHeroLivingGateway(
            accent: accent,
            animationName: asset.animationName,
            imageName: asset.imageName,
            localImage: asset.localImage,
            remoteImageURL: asset.remoteImageURL,
            usesCategoryArtworkTreatment: asset.usesCategoryArtworkTreatment,
            loadsFromFirebase: asset.loadsFromFirebase,
            stabilizesCentralArtworkScale: page.kind == .pet,
            compact: compact,
            isActive: true
        )
        .frame(
            width: compact ? 118 : 140,
            height: compact ? 150 : 172,
            alignment: .center
        )
    }
    
    private func pageControl(accent: Color) -> some View {
        HStack(spacing: 6) {
            ForEach(
                Array(pages.enumerated()),
                id: \.element.id
            ) { index, _ in
                Button {
                    onSelect(index)
                } label: {
                    Capsule()
                        .fill(
                            index == selectedIndex
                            ? accent
                            : Color.ppTextTertiary.opacity(0.32)
                        )
                        .frame(
                            width: index == selectedIndex ? 22 : 7,
                            height: 7
                        )
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    String(
                        format: HomeModelAdapter.localized(
                            "home_pulse_show_page_a11y",
                            fallback: "Show item %d"
                        ),
                        index + 1
                    )
                )
                .accessibilityAddTraits(
                    index == selectedIndex ? .isSelected : []
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, PPSpace.base)
    }
    
    private func heroArtworkAsset(
        for page: HomeHeroPage
    ) -> HomeHeroArtworkAsset {
        switch page.kind {
        case .pet:
            if let imageURL = normalizedHeroImageURL(page.imageURL) {
                return HomeHeroArtworkAsset(
                    animationName: nil,
                    imageName: nil,
                    localImage: nil,
                    remoteImageURL: imageURL,
                    usesCategoryArtworkTreatment: false,
                    loadsFromFirebase: false
                )
            }
            return HomeHeroArtworkAsset(
                animationName: "Profile.lottie",
                imageName: nil,
                localImage: nil,
                remoteImageURL: nil,
                usesCategoryArtworkTreatment: false,
                loadsFromFirebase: true
            )
        case .reminder:
            return HomeHeroArtworkAsset(
                animationName: "Caretiming",
                imageName: nil,
                localImage: nil,
                remoteImageURL: nil,
                usesCategoryArtworkTreatment: false,
                loadsFromFirebase: true
            )
        case .promotion:
            let remoteURL = normalizedHeroImageURL(page.imageURL)
            return HomeHeroArtworkAsset(
                animationName: remoteURL == nil ? "HomePromotionSpark" : nil,
                imageName: nil,
                localImage: nil,
                remoteImageURL: remoteURL,
                usesCategoryArtworkTreatment: false,
                loadsFromFirebase: false
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
            if homeHeroShowsSelectedMainKindArtwork
                && (hasSelectedCategory || hasPageArtwork) {
                let categoryImage = page.localImage
                let fallbackImage = categoryImage ?? UIImage(named: "pawprint4")
                return HomeHeroArtworkAsset(
                    animationName: nil,
                    imageName: fallbackImage == nil ? "pawprint4" : nil,
                    localImage: fallbackImage,
                    // The category rail and the selected Hero must present the
                    // same pet identity. Prefer its resolved local artwork;
                    // use the remote source only when no local artwork exists.
                    remoteImageURL: categoryImage == nil
                    ? normalizedHeroImageURL(page.imageURL)
                    : nil,
                    usesCategoryArtworkTreatment: true,
                    loadsFromFirebase: false
                )
            }
            return HomeHeroArtworkAsset(
                animationName: "Shop2.json",
                imageName: nil,
                localImage: nil,
                remoteImageURL: nil,
                usesCategoryArtworkTreatment: false,
                loadsFromFirebase: false
            )
        case .petOnboarding:
            return HomeHeroArtworkAsset(
                animationName: "LottieAnimations/Boy Giving Food To Rabbit New.json",
                imageName: nil,
                localImage: nil,
                remoteImageURL: nil,
                usesCategoryArtworkTreatment: false,
                loadsFromFirebase: true
            )
        case .pharmacy:
            return HomeHeroArtworkAsset(
                animationName: "PetMedicine",
                imageName: nil,
                localImage: nil,
                remoteImageURL: nil,
                usesCategoryArtworkTreatment: false,
                loadsFromFirebase: false
            )
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

private struct HomeHeroMetaItem {
    let symbol: String
    let title: String
}

private struct HomeHeroPageMotionModifier: ViewModifier {
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
    
    private struct HomeHeroPrimaryButtonStyle: ButtonStyle {
        let reduceMotion: Bool
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.985 : 1)
                .brightness(configuration.isPressed ? -0.035 : 0)
                .animation(
                    reduceMotion
                    ? nil
                    : .easeOut(duration: 0.14),
                    value: configuration.isPressed
                )
        }
    }
    
    private struct HomeHeroPagePhase: ViewModifier {
        let opacity: Double
        let offsetX: CGFloat
        let scale: CGFloat
        
        static let identity = HomeHeroPagePhase(
            opacity: 1,
            offsetX: 0,
            scale: 1
        )
        
        func body(content: Content) -> some View {
            content
                .opacity(opacity)
                .offset(x: offsetX)
                .scaleEffect(scale)
        }
    }
    
    private struct HomeHeroPagingGestureModifier: ViewModifier {
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
                            guard dx > 44, dx > dy * 1.35 else {
                                return
                            }
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
    
    private struct HomeHeroPagingAccessibilityModifier: ViewModifier {
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
    
    private struct HomeHeroArtworkAsset {
        var animationName: String? = nil
        var imageName: String? = nil
        var localImage: UIImage? = nil
        var remoteImageURL: String? = nil
        var usesCategoryArtworkTreatment: Bool = false
        var loadsFromFirebase: Bool = false

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
    
    private struct HomeHeroLivingGateway: View {
        let accent: Color
        let animationName: String?
        let imageName: String?
        let localImage: UIImage?
        let remoteImageURL: String?
        let usesCategoryArtworkTreatment: Bool
        let loadsFromFirebase: Bool
        let stabilizesCentralArtworkScale: Bool
        let compact: Bool
        let isActive: Bool
        
        @Environment(\.layoutDirection) private var layoutDirection
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.colorSchemeContrast) private var contrast
        @Environment(\.scenePhase) private var scenePhase
        @State private var presented = false
        
        var body: some View {
            ZStack {
                portalCore

                centralArtworkStage
                    .scaleEffect(
                        presented
                            ? (stabilizesCentralArtworkScale ? 1 : 1.02)
                            : 0.96
                    )
                    .offset(y: presented ? 2 : 8)
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
            }
            .modifier(
                HomeHeroGatewayStageFrame(compact: compact)
            )
            .onAppear(perform: updatePresentation)
            .onChange(of: reduceMotion) { _ in
                updatePresentation()
            }
            .onChange(of: isActive) { _ in
                updatePresentation()
            }
            .onDisappear {
                setPresented(false, animated: false)
            }
            .accessibilityHidden(true)
        }
        
        private var centralArtworkStage: some View {
            ZStack {
                centralArtwork
            }
            .modifier(
                HomeHeroArtworkStageFrame(side: centralArtworkSize)
            )
        }
        
        private var portalWidth: CGFloat {
            portalDiameter
        }
        
        private var portalCore: some View {
            let trailingOffset = (portalWidth - portalDiameter) / 2
            let trailingShift = layoutDirection == .rightToLeft ? -trailingOffset : trailingOffset
            
            let fill = LinearGradient(
                colors: [
                    Color.ppSurfaceRaised,
                    accent.opacity(colorScheme == .dark ? 0.28 : 0.18),
                    Color.homeBrand.opacity(
                        colorScheme == .dark ? 0.18 : 0.10
                    ),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            return PPHomeHeroLivingBlobView(
                fillGradient: fill,
                accent: accent,
                isDark: colorScheme == .dark
            )
            .frame(width: portalWidth, height: portalDiameter)
            .offset(x: trailingShift)
            .scaleEffect(presented ? 1 : 0.94)
            .opacity(presented ? 1 : 0.62)
            .shadow(
                color: accent.opacity(
                    contrast == .increased
                    ? 0
                    : (colorScheme == .dark ? 0.22 : 0.14)
                ),
                radius: 12,
                y: 6
            )
            .animation(
                reduceMotion
                ? nil
                : .easeOut(duration: 0.26),
                value: presented
            )
        }
        
        @ViewBuilder
        private var centralArtwork: some View {
            if let remoteImageURL, usesCategoryArtworkTreatment {
                AppRemoteImage(
                    urlString: remoteImageURL,
                    displaySize: CGSize(
                        width: categoryArtworkSize,
                        height: categoryArtworkSize
                    ),
                    contentMode: .fit,
                    fadeDuration: 0
                ) {
                    categoryArtworkPlaceholder
                } failurePlaceholder: {
                    categoryArtworkPlaceholder
                }
                .frame(width: categoryArtworkSize, height: categoryArtworkSize)
            } else if let remoteImageURL {
                HomeRemoteImage(
                    urlString: remoteImageURL,
                    placeholder: localImage,
                    contentMode: .scaleToFill
                )
                .frame(width: profileArtworkSize, height: profileArtworkSize)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.85)
                }
            } else if let localImage, usesCategoryArtworkTreatment {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: categoryArtworkSize, height: categoryArtworkSize)
            } else if let localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: profileArtworkSize, height: profileArtworkSize)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.82), lineWidth: 1)
                    }
            } else if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: compact ? 78 : 94,
                        height: compact ? 78 : 94
                    )
            } else if let animationName {
                HomeHeroLottieRepresentable(
                    animationName: animationName,
                    loadsFromFirebase: loadsFromFirebase,
                    playbackEnabled: lottiePlaybackEnabled,
                    tintColor: lottieTintColor(for: animationName)
                )
                .scaleEffect(lottieScale(for: animationName))
            }
        }
        
        /// Feed the UIKit Lottie bridge the same scene lifecycle SwiftUI uses for
        /// the hero. This makes a foreground transition re-evaluate playback even
        /// when the view was created while the application was inactive.
        private var lottiePlaybackEnabled: Bool {
            scenePhase == .active
        }
        
        private func lottieScale(for animationName: String) -> CGFloat {
            if animationName == "Shop2.json" { return compact ? 1.25 : 1.38 }
            return animationName == "petstore" ? 1.12 : 1.45
        }
        
        private func lottieTintColor(for animationName: String) -> UIColor? {
            if animationName == "Shop2.json" || animationName == "bag2.json" || animationName == "petstore" {
                return .ppQuickActionShopping
            }
            return UIColor(accent)
        }
        
        private var categoryArtworkSize: CGFloat {
            compact ? 106 : 126
        }
        
        private var profileArtworkSize: CGFloat {
            compact ? 82 : 98
        }
        
        private var centralArtworkSize: CGFloat {
            compact ? 112 : 136
        }
        
        private var portalDiameter: CGFloat {
            compact ? 80 : 97
        }
        
        @ViewBuilder
        private var categoryArtworkPlaceholder: some View {
            if let localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        
        private func updatePresentation() {
            setPresented(true, animated: false)
        }
        
        private func setPresented(_ value: Bool, animated: Bool) {
            guard presented != value else { return }
            if animated {
                presented = value
            } else {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    presented = value
                }
            }
        }
    }
    
    struct HomeHeroField: View {
        let accent: Color
        let increasedContrast: Bool
        let cornerGlowOpacityScale: Double
        var isAnimated: Bool = true
        var cornerRadius: CGFloat = PPCorner.hero
        
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.layoutDirection) private var layoutDirection
        @State private var fieldAlive = false
        
        init(
            accent: Color,
            increasedContrast: Bool,
            cornerGlowOpacityScale: Double,
            isAnimated: Bool = true,
            cornerRadius: CGFloat = PPCorner.hero
        ) {
            self.accent = accent
            self.increasedContrast = increasedContrast
            self.cornerGlowOpacityScale = cornerGlowOpacityScale
            self.isAnimated = isAnimated
            self.cornerRadius = cornerRadius
        }
        
        private var isRightToLeft: Bool {
            layoutDirection == .rightToLeft
        }
        
        var body: some View {
            ZStack {
                heroShape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.homeRaisedSurface,
                                increasedContrast
                                ? Color.homeSectionBand
                                : Color.homeSurface,
                                Color.homeSurface.opacity(
                                    colorScheme == .dark ? 0.96 : 0.86
                                ),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                if !increasedContrast {
                    cornerGlowField
                        .scaleEffect(fieldAlive ? 1.035 : 0.97)
                        .opacity(fieldAlive ? 0.92 : 0.70)
                        .animation(
                            reduceMotion
                            ? nil
                            : .easeOut(duration: 0.28),
                            value: fieldAlive
                        )
                    careCurrent
                }
            }
            .clipShape(heroShape)
            .onAppear(perform: updateMotion)
            .onChange(of: reduceMotion) { _ in
                updateMotion()
            }
            .onChange(of: isAnimated) { _ in
                updateMotion()
            }
            .onDisappear {
                fieldAlive = false
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        
        private var heroShape: RoundedRectangle {
            RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )
        }
        
        private var cornerGlowField: some View {
            GeometryReader { proxy in
                let radiusBasis = max(proxy.size.width, proxy.size.height)
                
                ZStack {
                    RadialGradient(
                        colors: [
                            Color.white.opacity(
                                colorScheme == .dark ? 0.14 : 0.28
                            ),
                            accent.opacity(
                                (colorScheme == .dark ? 0.22 : 0.18) * cornerGlowOpacityScale
                            ),
                            accent.opacity(
                                (colorScheme == .dark ? 0.08 : 0.05) * cornerGlowOpacityScale
                            ),
                            Color.clear,
                        ],
                        center: isRightToLeft
                        ? UnitPoint(x: 1.04, y: -0.04)
                        : UnitPoint(x: -0.04, y: -0.04),
                        startRadius: 0,
                        endRadius: radiusBasis * 0.58
                    )
                    
                    RadialGradient(
                        colors: [
                            Color.white.opacity(
                                colorScheme == .dark ? 0.10 : 0.22
                            ),
                            accent.opacity(
                                (colorScheme == .dark ? 0.18 : 0.14) * cornerGlowOpacityScale
                            ),
                            accent.opacity(
                                (colorScheme == .dark ? 0.06 : 0.035) * cornerGlowOpacityScale
                            ),
                            Color.clear,
                        ],
                        center: isRightToLeft
                        ? UnitPoint(x: -0.05, y: 1.06)
                        : UnitPoint(x: 1.05, y: 1.06),
                        startRadius: 0,
                        endRadius: radiusBasis * 0.65
                    )
                }
            }
            .opacity(1.0)
        }
        
        private var careCurrent: some View {
            ZStack {
                HomeHeroCareCurrentRibbon()
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(
                                    colorScheme == .dark ? 0.03 : 0.022
                                ),
                                accent.opacity(
                                    colorScheme == .dark ? 0.15 : 0.09
                                ),
                                accent.opacity(
                                    colorScheme == .dark ? 0.064 : 0.034
                                ),
                                Color.clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                HomeHeroCareCurrentRibbon()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.homeRaisedSurface.opacity(
                                    colorScheme == .dark ? 0.08 : 0.68
                                ),
                                Color.clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(
                        x: fieldAlive && !reduceMotion ? 18 : -18,
                        y: fieldAlive && !reduceMotion ? -2 : 2
                    )
                
                HomeHeroCareCurrentLine()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                accent.opacity(
                                    colorScheme == .dark ? 0.24 : 0.14
                                ),
                                accent.opacity(
                                    colorScheme == .dark ? 0.08 : 0.04
                                ),
                                Color.clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(
                            lineWidth: colorScheme == .dark ? 0.8 : 0.65,
                            lineCap: .round
                        )
                    )
                    .opacity(fieldAlive && !reduceMotion ? 0.76 : 0.48)
            }
            .scaleEffect(x: isRightToLeft ? -1 : 1, y: 1)
            .offset(y: fieldAlive ? -3 : 3)
            .allowsHitTesting(false)
        }
        
        private func updateMotion() {
            guard isAnimated else {
                fieldAlive = false
                return
            }
            guard !fieldAlive else { return }
            
            withAnimation(.easeOut(duration: 0.28)) {
                fieldAlive = true
            }
        }
    }
    
    private struct HomeHeroCareCurrentRibbon: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(
                to: CGPoint(
                    x: rect.minX - (rect.width * 0.08),
                    y: rect.minY + (rect.height * 0.69)
                )
            )
            path.addCurve(
                to: CGPoint(
                    x: rect.maxX + (rect.width * 0.08),
                    y: rect.minY + (rect.height * 0.25)
                ),
                control1: CGPoint(
                    x: rect.minX + (rect.width * 0.30),
                    y: rect.minY + (rect.height * 0.74)
                ),
                control2: CGPoint(
                    x: rect.minX + (rect.width * 0.68),
                    y: rect.minY + (rect.height * 0.08)
                )
            )
            path.addLine(
                to: CGPoint(
                    x: rect.maxX + (rect.width * 0.08),
                    y: rect.minY + (rect.height * 0.53)
                )
            )
            path.addCurve(
                to: CGPoint(
                    x: rect.minX - (rect.width * 0.08),
                    y: rect.minY + (rect.height * 0.88)
                ),
                control1: CGPoint(
                    x: rect.minX + (rect.width * 0.70),
                    y: rect.minY + (rect.height * 0.36)
                ),
                control2: CGPoint(
                    x: rect.minX + (rect.width * 0.31),
                    y: rect.minY + (rect.height * 0.91)
                )
            )
            path.closeSubpath()
            return path
        }
    }
    
    private struct HomeHeroCareCurrentLine: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(
                to: CGPoint(
                    x: rect.minX - (rect.width * 0.05),
                    y: rect.minY + (rect.height * 0.77)
                )
            )
            path.addCurve(
                to: CGPoint(
                    x: rect.maxX + (rect.width * 0.05),
                    y: rect.minY + (rect.height * 0.37)
                ),
                control1: CGPoint(
                    x: rect.minX + (rect.width * 0.31),
                    y: rect.minY + (rect.height * 0.79)
                ),
                control2: CGPoint(
                    x: rect.minX + (rect.width * 0.67),
                    y: rect.minY + (rect.height * 0.18)
                )
            )
            return path
        }
    }
    
    struct HomeHeroBorder: View {
        let accent: Color
        let darkMode: Bool
        let increasedContrast: Bool
        
        @Environment(\.layoutDirection) private var layoutDirection
        
        var body: some View {
            heroShape
                .strokeBorder(
                    borderStyle,
                    lineWidth: increasedContrast ? 1.5 : 0.65
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        
        private var heroShape: RoundedRectangle {
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
        }
        
        private var borderStyle: AnyShapeStyle {
            if increasedContrast {
                return AnyShapeStyle(Color.homeTextPrimary.opacity(0.76))
            }
            
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        darkMode ? Color.white.opacity(0.16) : Color.white.opacity(0.98),
                        darkMode ? Color.white.opacity(0.12) : Color.white.opacity(0.90),
                        accent.opacity(darkMode ? 0.18 : 0.07),
                        darkMode ? Color.white.opacity(0.10) : Color.white.opacity(0.84),
                        darkMode ? Color.white.opacity(0.14) : Color.white.opacity(0.96),
                    ],
                    startPoint: layoutDirection == .rightToLeft
                    ? .topTrailing
                    : .topLeading,
                    endPoint: layoutDirection == .rightToLeft
                    ? .bottomLeading
                    : .bottomTrailing
                )
            )
        }
    }
    
    struct HomeHeroLottieRepresentable: UIViewRepresentable {
        let animationName: String
        let loadsFromFirebase: Bool
        let playbackEnabled: Bool
        var tintColor: UIColor? = nil
        
        func makeUIView(context: Context) -> PPHomeHeroAnimationView {
            let view = PPHomeHeroAnimationView(
                animationName: animationName,
                loadsFromFirebase: loadsFromFirebase
            )
            view.isPlaybackEnabled = true
            if let tintColor {
                view.customTintColor = tintColor
            }
            return view
        }
        
        func updateUIView(
            _ uiView: PPHomeHeroAnimationView,
            context: Context
        ) {
            uiView.isPlaybackEnabled = true
            if let tintColor {
                uiView.customTintColor = tintColor
            }
        }
        
        static func dismantleUIView(
            _ uiView: PPHomeHeroAnimationView,
            coordinator: Void
        ) {
        }
    }
    
    private struct HomeHeroSkeleton: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.colorSchemeContrast) private var contrast
        @State private var faded = false
        
        var body: some View {
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .fill(Color.ppSecondarySurface)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: PPSpace.md) {
                        Capsule().fill(Color.ppSeparator).frame(width: 84, height: 12)
                        Capsule().fill(Color.ppSeparator).frame(width: 190, height: 26)
                        Capsule().fill(Color.ppSeparator).frame(width: 224, height: 14)
                        Capsule().fill(Color.ppSeparator).frame(width: 144, height: 14)
                        Spacer()
                        Capsule().fill(Color.ppPrimary.opacity(0.18))
                            .frame(width: 128, height: 46)
                    }
                    .padding(PPSpace.lg)
                    .opacity(1)
                }
                .overlay {
                    HomeHeroBorder(
                        accent: Color.homeBrand,
                        darkMode: colorScheme == .dark,
                        increasedContrast: contrast == .increased
                    )
                }
                .onAppear(perform: updateAppearance)
                .onChange(of: reduceMotion) { _ in
                    updateAppearance()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    HomeModelAdapter.localized(
                        "home_pulse_loading",
                        fallback: "Loading Home"
                    )
                )
        }
        
        private func updateAppearance() {
            guard !faded else { return }
            if reduceMotion {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    faded = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.24)) {
                    faded = true
                }
            }
        }
    }
    
    @available(iOS 15.0, *)
    private struct PPHomeHeroBackgroundRootView: View {
        @Environment(\.colorSchemeContrast) private var contrast
        @State private var isRightToLeft = Language.isRTL()
        
        var body: some View {
            HomeHeroField(
                accent: .homeBrand,
                increasedContrast: contrast == .increased,
                cornerGlowOpacityScale: 0.72
            )
            .environment(
                \.layoutDirection,
                 isRightToLeft ? .rightToLeft : .leftToRight
            )
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("LanguageDidChangeNotification")
                )
            ) { _ in
                isRightToLeft = Language.isRTL()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("PPLanguageDidChangeNotification")
                )
            ) { _ in
                isRightToLeft = Language.isRTL()
            }
        }
    }
    
    /// UIKit bridge for the live Home hero field so legacy UIKit hero surfaces can
    /// reuse the same background owner without duplicating its material or motion.
    @available(iOS 15.0, *)
    @MainActor
    @objc(PPHomeHeroBackgroundHostingController)
    public final class PPHomeHeroBackgroundHostingController: UIViewController {
        private let hostingController: UIHostingController<PPHomeHeroBackgroundRootView>
        
        @objc public init() {
            hostingController = UIHostingController(
                rootView: PPHomeHeroBackgroundRootView()
            )
            super.init(nibName: nil, bundle: nil)
        }
        
        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError(
                "PPHomeHeroBackgroundHostingController must be created programmatically."
            )
        }
        
        public override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            
            addChild(hostingController)
            guard let hostedView = hostingController.view else {
                return
            }
            hostedView.translatesAutoresizingMaskIntoConstraints = false
            hostedView.backgroundColor = .clear
            hostedView.isUserInteractionEnabled = false
            view.addSubview(hostedView)
            NSLayoutConstraint.activate([
                hostedView.topAnchor.constraint(equalTo: view.topAnchor),
                hostedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostedView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            hostingController.didMove(toParent: self)
        }
    }
    
    private struct HomeHeroGatewayStageFrame: ViewModifier {
        let compact: Bool
        
        func body(content: Content) -> some View {
            content.frame(
                width: compact ? 118 : 140,
                height: compact ? 150 : 172,
                alignment: .center
            )
        }
    }
    
    private struct HomeHeroArtworkStageFrame: ViewModifier {
        let side: CGFloat
        
        func body(content: Content) -> some View {
            content.frame(width: side, height: side)
        }
    }
