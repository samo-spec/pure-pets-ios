import SwiftUI
import UIKit

private let homeHeroShowsSelectedMainKindArtwork = false

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
    @ScaledMetric(relativeTo: .title) private var heroHeight: CGFloat = 224

    private var selectedPage: HomeHeroPage? {
        guard pages.indices.contains(selectedIndex) else { return nil }
        return pages[selectedIndex]
    }

    private var resolvedHeroHeight: CGFloat {
        min(heroHeight, dynamicTypeSize.isAccessibilitySize ? 388 : 254)
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
                increasedContrast: contrast == .increased
            )

            VStack(spacing: 0) {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        heroCopy(page, accent: accent)
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: .leading
                            )
                    } else {
                        HStack(alignment: .center, spacing: 18) {
                            heroArtwork(page, accent: accent)
                                .frame(width: 124, height: 146)
                                .layoutPriority(0)

                            heroCopy(page, accent: accent)
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .leading
                                )
                                .layoutPriority(1)
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
                .padding(.horizontal, PPSpace.lg)
                .padding(.vertical, PPSpace.lg)

                if allowsPaging {
                    pageControl(accent: accent)
                        .padding(.bottom, PPSpace.xs)
                }
            }
            .id(page.id)
            .transition(heroPageTransition)
        }
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.18)
                : .interactiveSpring(
                    response: 0.52,
                    dampingFraction: 0.82,
                    blendDuration: 0.16
                ),
            value: page.id
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
            radius: 28,
            y: 16
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
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            eyebrowPill(page, accent: accent)

            Text(compactHeroTitle(page.title))
                .font(HomeFont.title1())
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .frame(
                    maxWidth: .infinity,
                    minHeight: dynamicTypeSize.isAccessibilitySize ? 82 : 56,
                    maxHeight: dynamicTypeSize.isAccessibilitySize ? 82 : 56,
                    alignment: .leading
                )
                .accessibilityLabel(page.title)
                .accessibilityAddTraits(.isHeader)

            Text(page.subtitle)
                .font(HomeFont.subheadline())
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: PPSpace.xs) {
                primaryButton(page, accent: accent)
                secondaryButton(page)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func eyebrowPill(
        _ page: HomeHeroPage,
        accent: Color
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: eyebrowSymbol(for: page.kind))
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(accent)
                .accessibilityHidden(true)

            Text(page.eyebrow)
                .font(HomeFont.bold(11))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            accent.opacity(colorScheme == .dark ? 0.22 : 0.17),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(
                    accent.opacity(colorScheme == .dark ? 0.30 : 0.24),
                    lineWidth: 1
                )
        }
    }

    private func eyebrowSymbol(for kind: HomeHeroKind) -> String {
        switch kind {
        case .marketplace:
            return "storefront.fill"
        case .pet:
            return "pawprint.fill"
        case .reminder:
            return "bell.fill"
        case .promotion:
            return "sparkles"
        case .petOnboarding:
            return "plus.circle.fill"
        case .pharmacy:
            return "pills.fill"
        }
    }

    private func compactHeroTitle(_ title: String) -> String {
        return title
    }

    private func primaryButton(
        _ page: HomeHeroPage,
        accent: Color
    ) -> some View {
        Button(action: onPrimaryAction) {
            HStack(alignment: .center, spacing: PPSpace.md) {
                Text(page.primaryTitle)
                    .font(HomeFont.bold(15))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.84)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                Image(systemName: "arrow.forward")
                    .font(.system(size: 13, weight: .bold))
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .foregroundStyle(Color.white)
            .frame(
                minWidth: dynamicTypeSize.isAccessibilitySize ? nil : 104, maxWidth: dynamicTypeSize.isAccessibilitySize
                ? .infinity
                : nil,
                minHeight: 44,
                alignment: .center
            )
            .padding(.horizontal, PPSpace.base)
            .background(
                accent,
                in: RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint(
            HomeModelAdapter.localized(
                "home_pulse_opens_destination_a11y",
                fallback: "Opens this destination"
            )
        )
    }

    private var heroPageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let incomingX: CGFloat = isRightToLeft ? -34 : 34
        let outgoingX: CGFloat = isRightToLeft ? 24 : -24
        return .asymmetric(
            insertion: .modifier(
                active: HomeHeroPagePhase(
                    opacity: 0,
                    offsetX: incomingX,
                    scale: 1,
                    blurRadius: 5
                ),
                identity: HomeHeroPagePhase.identity
            ),
            removal: .modifier(
                active: HomeHeroPagePhase(
                    opacity: 0,
                    offsetX: outgoingX,
                    scale: 1,
                    blurRadius: 2
                ),
                identity: HomeHeroPagePhase.identity
            )
        )
    }

    @ViewBuilder
    private func secondaryButton(_ page: HomeHeroPage) -> some View {
        // Temporarily hidden per user request
        EmptyView()
    }

    @ViewBuilder
    private func heroArtwork(
        _ page: HomeHeroPage,
        accent: Color
    ) -> some View {
        let asset = heroArtworkAsset(for: page)
        HomeHeroFloatingPlate(
            accent: accent,
            animationName: asset.animationName,
            imageName: asset.imageName,
            localImage: asset.localImage,
            remoteImageURL: asset.remoteImageURL,
            usesCategoryArtworkTreatment: asset.usesCategoryArtworkTreatment,
            loadsFromFirebase: asset.loadsFromFirebase,
            primarySymbol: asset.primarySymbol,
            secondarySymbol: asset.secondarySymbol
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
                        .frame(minWidth: 24, minHeight: 28)
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
                    loadsFromFirebase: false,
                    primarySymbol: "heart.fill",
                    secondarySymbol: "pawprint.fill"
                )
            }
            return HomeHeroArtworkAsset(
                animationName: "Profile.lottie",
                imageName: nil,
                localImage: nil,
                remoteImageURL: nil,
                usesCategoryArtworkTreatment: false,
                loadsFromFirebase: true,
                primarySymbol: "heart.fill",
                secondarySymbol: "pawprint.fill"
            )
        case .reminder:
            return HomeHeroArtworkAsset(
                animationName: "Caretiming",
                imageName: nil,
                localImage: nil,
                remoteImageURL: nil,
                usesCategoryArtworkTreatment: false,
                loadsFromFirebase: true,
                primarySymbol: "bell.fill",
                secondarySymbol: "calendar"
            )
        case .promotion:
            let remoteURL = normalizedHeroImageURL(page.imageURL)
            return HomeHeroArtworkAsset(
                animationName: remoteURL == nil ? "HomePromotionSpark" : nil,
                imageName: nil,
                localImage: nil,
                remoteImageURL: remoteURL,
                usesCategoryArtworkTreatment: false,
                loadsFromFirebase: false,
                primarySymbol: "sparkles",
                secondarySymbol: "tag.fill"
            )
        case .marketplace:
            let hasSelectedCategory: Bool
            if case let .openMarketplace(mainKind) = page.action {
                hasSelectedCategory = mainKind != nil
            } else {
                hasSelectedCategory = false
            }
            if homeHeroShowsSelectedMainKindArtwork && hasSelectedCategory {
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
                    loadsFromFirebase: false,
                    primarySymbol: "bag.fill",
                    secondarySymbol: "shippingbox.fill"
                )
            }
            return HomeHeroArtworkAsset(
                animationName: "petstore",
                imageName: nil,
                localImage: nil,
                remoteImageURL: nil,
                usesCategoryArtworkTreatment: false,
                loadsFromFirebase: true,
                primarySymbol: "bag.fill",
                secondarySymbol: "shippingbox.fill"
            )
        case .petOnboarding:
            return HomeHeroArtworkAsset(
                animationName: "LottieAnimations/Boy Giving Food To Rabbit New.json",
                imageName: nil,
                localImage: nil,
                remoteImageURL: nil,
                usesCategoryArtworkTreatment: false,
                loadsFromFirebase: true,
                primarySymbol: "plus",
                secondarySymbol: "pawprint.fill"
            )
        case .pharmacy:
            return HomeHeroArtworkAsset(
                animationName: "PetMedicine",
                imageName: nil,
                localImage: nil,
                remoteImageURL: nil,
                usesCategoryArtworkTreatment: false,
                loadsFromFirebase: false,
                primarySymbol: "pills.fill",
                secondarySymbol: "bandage.fill"
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

private struct HomeHeroPagePhase: ViewModifier {
    let opacity: Double
    let offsetX: CGFloat
    let scale: CGFloat
    let blurRadius: CGFloat

    static let identity = HomeHeroPagePhase(
        opacity: 1,
        offsetX: 0,
        scale: 1,
        blurRadius: 0
    )

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .offset(x: offsetX)
            .scaleEffect(scale)
            .blur(radius: blurRadius)
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
    let animationName: String?
    let imageName: String?
    let localImage: UIImage?
    let remoteImageURL: String?
    let usesCategoryArtworkTreatment: Bool
    let loadsFromFirebase: Bool
    let primarySymbol: String
    let secondarySymbol: String
}

private struct HomeHeroFloatingPlate: View {
    let accent: Color
    let animationName: String?
    let imageName: String?
    let localImage: UIImage?
    let remoteImageURL: String?
    let usesCategoryArtworkTreatment: Bool
    let loadsFromFirebase: Bool
    let primarySymbol: String
    let secondarySymbol: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var floating = false

    var body: some View {
        ZStack {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.30),
                                Color.ppSurface.opacity(0.94),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 32,
                            style: .continuous
                        )
                        .stroke(
                            contrast == .increased
                                ? Color.ppTextPrimary.opacity(0.62)
                                : Color.white.opacity(0.82),
                            lineWidth: contrast == .increased ? 1.5 : 1
                        )
                    }

                centralArtwork
            }
            .frame(width: plateSize, height: plateSize)
            .clipShape(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
            )
            .offset(y: -2)
            .shadow(
                color: Color.black.opacity(contrast == .increased ? 0 : 0.08),
                radius: 12,
                y: 7
            )

            floatingTile(
                symbol: primarySymbol,
                side: 44
            )
            .offset(x: 40, y: -39 + (floatingPhase ? -2 : 2))

            floatingTile(
                symbol: secondarySymbol,
                side: 38
            )
            .offset(x: -43, y: 40 + (floatingPhase ? 2 : -2))
        }
        .frame(width: 124, height: 146)
        .offset(y: floatingPhase ? -4 : 0)
        .animation(
            allowsFloatingMotion
                ? .easeInOut(duration: 3.8).repeatForever(
                    autoreverses: true
                )
                : nil,
            value: floating
        )
        .onAppear {
            updateFloatingMotion()
        }
        .onChange(of: reduceMotion) { _ in
            updateFloatingMotion()
        }
        .onChange(of: usesCategoryArtworkTreatment) { _ in
            updateFloatingMotion()
        }
        .accessibilityHidden(true)
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
            .clipped()
        } else if let remoteImageURL {
            HomeRemoteImage(
                urlString: remoteImageURL,
                placeholder: localImage,
                contentMode: .scaleToFill
            )
            .frame(width: 76, height: 76)
            .clipShape(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.82), lineWidth: 1)
            }
        } else if let localImage, usesCategoryArtworkTreatment {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFit()
                .frame(width: categoryArtworkSize, height: categoryArtworkSize)
                .clipped()
        } else if let localImage {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .clipShape(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.82), lineWidth: 1)
                }
        } else if let imageName {
            Image(imageName)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(Color.black)
                .frame(width: 52, height: 52)
        } else if let animationName {
            HomeHeroLottieRepresentable(
                animationName: animationName,
                loadsFromFirebase: loadsFromFirebase,
                playbackEnabled: !reduceMotion,
                tintColor: lottieTintColor(for: animationName)
            )
            .scaleEffect(lottieScale(for: animationName))
            .tint(Color(lottieTintColor(for: animationName)))
        }
    }

    private func lottieScale(for animationName: String) -> CGFloat {
        animationName == "petstore" ? 0.78 : 1.30
    }

    private func lottieTintColor(for animationName: String) -> UIColor {
        animationName == "petstore"
            ? UIColor(Color.ppPrimary)
            : UIColor.white
    }

    private var categoryArtworkSize: CGFloat {
        70
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

    private var plateSize: CGFloat {
        100
    }

    private var allowsFloatingMotion: Bool {
        false
    }

    private var floatingPhase: Bool {
        false
    }


    private func floatingTile(
        symbol: String,
        side: CGFloat
    ) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(accent)
            .frame(width: side, height: side)
            .background(Color.ppSurface.opacity(0.92), in: RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            ))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.78), lineWidth: 1)
            }
            .shadow(
                color: Color.black.opacity(contrast == .increased ? 0 : 0.08),
                radius: 8,
                y: 4
            )
    }

    private func updateFloatingMotion() {
        if !allowsFloatingMotion {
            floating = false
        } else {
            DispatchQueue.main.async {
                floating = true
            }
        }
    }
}

struct HomeHeroField: View {
    let accent: Color
    let increasedContrast: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var fieldAlive = false

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
                careCurrent
            }
        }
        .onAppear(perform: updateMotion)
        .onChange(of: reduceMotion) { _ in
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
            cornerRadius: PPCorner.hero,
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
                            colorScheme == .dark ? 0.12 : 0.34
                        ),
                        accent.opacity(
                            colorScheme == .dark ? 0.22 : 0.16
                        ),
                        accent.opacity(
                            colorScheme == .dark ? 0.075 : 0.052
                        ),
                        Color.clear,
                    ],
                    center: isRightToLeft
                        ? UnitPoint(x: 1.04, y: -0.04)
                        : UnitPoint(x: -0.04, y: -0.04),
                    startRadius: 0,
                    endRadius: radiusBasis * 0.52
                )

                RadialGradient(
                    colors: [
                        Color.white.opacity(
                            colorScheme == .dark ? 0.10 : 0.30
                        ),
                        accent.opacity(
                            colorScheme == .dark ? 0.19 : 0.14
                        ),
                        accent.opacity(
                            colorScheme == .dark ? 0.065 : 0.044
                        ),
                        Color.clear,
                    ],
                    center: isRightToLeft
                        ? UnitPoint(x: -0.05, y: 1.06)
                        : UnitPoint(x: 1.05, y: 1.06),
                    startRadius: 0,
                    endRadius: radiusBasis * 0.60
                )
            }
        }
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
        .offset(y: fieldAlive && !reduceMotion ? -3 : 3)
        .allowsHitTesting(false)
    }

    private func updateMotion() {
        guard !reduceMotion, !increasedContrast else {
            fieldAlive = false
            return
        }
        guard !fieldAlive else { return }

        withAnimation(
            .easeInOut(duration: 8.6)
                .repeatForever(autoreverses: true)
        ) {
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

private struct HomeHeroBorder: View {
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
                    Color.white.opacity(darkMode ? 0.66 : 0.98),
                    Color.white.opacity(darkMode ? 0.52 : 0.90),
                    accent.opacity(darkMode ? 0.12 : 0.07),
                    Color.white.opacity(darkMode ? 0.46 : 0.84),
                    Color.white.opacity(darkMode ? 0.60 : 0.96),
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
        view.isPlaybackEnabled = playbackEnabled
        if let tintColor {
            view.customTintColor = tintColor
        }
        return view
    }

    func updateUIView(
        _ uiView: PPHomeHeroAnimationView,
        context: Context
    ) {
        uiView.isPlaybackEnabled = playbackEnabled
        if let tintColor {
            uiView.customTintColor = tintColor
        }
    }

    static func dismantleUIView(
        _ uiView: PPHomeHeroAnimationView,
        coordinator: Void
    ) {
        uiView.isPlaybackEnabled = false
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
                .opacity(faded ? 0.55 : 1)
            }
            .overlay {
                HomeHeroBorder(
                    accent: Color.homeBrand,
                    darkMode: colorScheme == .dark,
                    increasedContrast: contrast == .increased
                )
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                ) {
                    faded = true
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                HomeModelAdapter.localized(
                    "home_pulse_loading",
                    fallback: "Loading Home"
                )
            )
    }
}
