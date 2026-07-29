import SwiftUI

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
    @ScaledMetric(relativeTo: .title) private var heroHeight: CGFloat = 256

    private var selectedPage: HomeHeroPage? {
        guard pages.indices.contains(selectedIndex) else { return nil }
        return pages[selectedIndex]
    }

    private var resolvedHeroHeight: CGFloat {
        min(heroHeight, dynamicTypeSize.isAccessibilitySize ? 420 : 286)
    }

    private var isRightToLeft: Bool {
        layoutDirection == .rightToLeft
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
            HomeHeroProviderGlassField(
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
                .padding(.top, PPSpace.lg)
                .padding(.bottom, PPSpace.md)

                pageControl(accent: accent)
                    .padding(.bottom, PPSpace.xs)
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
            RoundedRectangle(
                cornerRadius: PPCorner.hero,
                style: .continuous
            )
            .stroke(
                contrast == .increased
                    ? AnyShapeStyle(Color.ppTextPrimary.opacity(0.62))
                    : AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.20),
                                Color.white.opacity(
                                    colorScheme == .dark ? 0.10 : 0.62
                                ),
                                Color.ppBorder,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    ),
                lineWidth: contrast == .increased ? 1.5 : 1
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
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { _ in onInteractionChanged(true) }
                .onEnded { value in
                    defer { onInteractionChanged(false) }
                    guard abs(value.translation.width) > 44, pages.count > 1
                    else {
                        return
                    }
                    let physicalDirection =
                        value.translation.width < 0 ? 1 : -1
                    let logicalDirection =
                        layoutDirection == .rightToLeft
                            ? -physicalDirection
                            : physicalDirection
                    let next =
                        (selectedIndex + logicalDirection + pages.count)
                        % pages.count
                    onSelect(next)
                }
        )
        .accessibilityLabel(
            [page.eyebrow, page.title, page.subtitle]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        )
        .accessibilityValue(
            String(
                format: HomeModelAdapter.localized(
                    "home_pulse_page_position_a11y",
                    fallback: "%1$d of %2$d"
                ),
                selectedIndex + 1,
                pages.count
            )
        )
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                onSelect((selectedIndex + 1) % max(pages.count, 1))
            case .decrement:
                onSelect(
                    (selectedIndex - 1 + max(pages.count, 1))
                    % max(pages.count, 1)
                )
            @unknown default:
                break
            }
        }
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
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(
                    dynamicTypeSize.isAccessibilitySize ? 0.78 : 0.72
                )
                .allowsTightening(true)
                .frame(
                    maxWidth: .infinity,
                    minHeight: dynamicTypeSize.isAccessibilitySize ? 82 : 42,
                    maxHeight: dynamicTypeSize.isAccessibilitySize ? 82 : 42,
                    alignment: .leading
                )
                .accessibilityLabel(page.title)
                .accessibilityAddTraits(.isHeader)

            Text(page.subtitle)
                .font(HomeFont.subheadline())
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 3)
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
        }
    }

    private func compactHeroTitle(_ title: String) -> String {
        let words = title.split(whereSeparator: \.isWhitespace)
        guard words.count > 4 else {
            return words.joined(separator: " ")
        }
        return words.prefix(4).joined(separator: " ") + "…"
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
                    scale: 0.965,
                    blurRadius: 5
                ),
                identity: HomeHeroPagePhase.identity
            ),
            removal: .modifier(
                active: HomeHeroPagePhase(
                    opacity: 0,
                    offsetX: outgoingX,
                    scale: 1.018,
                    blurRadius: 2
                ),
                identity: HomeHeroPagePhase.identity
            )
        )
    }

    @ViewBuilder
    private func secondaryButton(_ page: HomeHeroPage) -> some View {
        if let title = page.secondaryTitle, !title.isEmpty {
            Button(action: onSecondaryAction) {
                Text(title)
                    .font(HomeFont.medium(14))
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 34,
                        alignment: .leading
                    )
                    .padding(.horizontal, PPSpace.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func heroArtwork(
        _ page: HomeHeroPage,
        accent: Color
    ) -> some View {
        let asset = heroArtworkAsset(for: page.kind)
        HomeHeroFloatingPlate(
            accent: accent,
            animationName: asset.animationName,
            imageName: asset.imageName,
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
        for kind: HomeHeroKind
    ) -> HomeHeroArtworkAsset {
        switch kind {
        case .pet:
            return HomeHeroArtworkAsset(
                animationName: "HomePetPulse",
                imageName: nil,
                loadsFromFirebase: false,
                primarySymbol: "heart.fill",
                secondarySymbol: "pawprint.fill"
            )
        case .reminder:
            return HomeHeroArtworkAsset(
                animationName: "Caretiming",
                imageName: nil,
                loadsFromFirebase: true,
                primarySymbol: "bell.fill",
                secondarySymbol: "calendar"
            )
        case .promotion:
            return HomeHeroArtworkAsset(
                animationName: "HomePromotionSpark",
                imageName: nil,
                loadsFromFirebase: false,
                primarySymbol: "sparkles",
                secondarySymbol: "tag.fill"
            )
        case .marketplace:
            return HomeHeroArtworkAsset(
                animationName: "petstore",
                imageName: nil,
                loadsFromFirebase: true,
                primarySymbol: "bag.fill",
                secondarySymbol: "shippingbox.fill"
            )
        case .petOnboarding:
            return HomeHeroArtworkAsset(
                animationName: nil,
                imageName: "pawprint4",
                loadsFromFirebase: false,
                primarySymbol: "plus",
                secondarySymbol: "pawprint.fill"
            )
        }
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

private struct HomeHeroArtworkAsset {
    let animationName: String?
    let imageName: String?
    let loadsFromFirebase: Bool
    let primarySymbol: String
    let secondarySymbol: String
}

private struct HomeHeroFloatingPlate: View {
    let accent: Color
    let animationName: String?
    let imageName: String?
    let loadsFromFirebase: Bool
    let primarySymbol: String
    let secondarySymbol: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var floating = false

    var body: some View {
        ZStack {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
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
                            cornerRadius: 30,
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
            .frame(width: 100, height: 100)
            .clipShape(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
            )
            .shadow(
                color: Color.black.opacity(contrast == .increased ? 0 : 0.08),
                radius: 12,
                y: 7
            )

            floatingTile(
                symbol: primarySymbol,
                side: 42
            )
            .offset(x: 47, y: -47 + (floating ? -2 : 2))

            floatingTile(
                symbol: secondarySymbol,
                side: 38
            )
            .offset(x: -45, y: 45 + (floating ? 2 : -2))
        }
        .frame(width: 124, height: 146)
        .offset(y: reduceMotion ? 0 : (floating ? -4 : 2))
        .animation(
            reduceMotion
                ? nil
                : .easeInOut(duration: 3.8).repeatForever(
                    autoreverses: true
                ),
            value: floating
        )
        .onAppear {
            updateFloatingMotion()
        }
        .onChange(of: reduceMotion) { _ in
            updateFloatingMotion()
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var centralArtwork: some View {
        if let imageName {
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
                playbackEnabled: !reduceMotion
            )
            .padding(8)
        }
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
        if reduceMotion {
            floating = false
        } else {
            DispatchQueue.main.async {
                floating = true
            }
        }
    }
}

private struct HomeHeroProviderGlassField: View {
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
            RoundedRectangle(
                cornerRadius: PPCorner.hero,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color.ppElevatedSurface,
                        accent.opacity(
                            colorScheme == .dark ? 0.10 : 0.055
                        ),
                        Color.ppElevatedSurface,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            if !increasedContrast {
                Circle()
                    .fill(
                        accent.opacity(
                            colorScheme == .dark ? 0.14 : 0.11
                        )
                    )
                    .frame(width: 176, height: 176)
                    .blur(radius: 22)
                    .offset(
                        x: isRightToLeft ? -54 : 54,
                        y: fieldAlive && !reduceMotion ? -46 : -28
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: isRightToLeft
                            ? .topLeading
                            : .topTrailing
                    )

                Circle()
                    .fill(
                        Color.white.opacity(
                            colorScheme == .dark ? 0.05 : 0.28
                        )
                    )
                    .frame(width: 124, height: 124)
                    .blur(radius: 18)
                    .offset(
                        x: isRightToLeft ? 36 : -36,
                        y: fieldAlive && !reduceMotion ? 42 : 24
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: isRightToLeft
                            ? .bottomTrailing
                            : .bottomLeading
                    )

                if !reduceMotion {
                    lightSweep
                }
            }
        }
        .onAppear {
            updateMotion()
        }
        .onChange(of: reduceMotion) { _ in
            updateMotion()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var lightSweep: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(
                            colorScheme == .dark ? 0.07 : 0.22
                        ),
                        Color.white.opacity(0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 76)
            .rotationEffect(.degrees(isRightToLeft ? -18 : 18))
            .offset(
                x: fieldAlive
                    ? (isRightToLeft ? -360 : 360)
                    : (isRightToLeft ? 360 : -360)
            )
            .blendMode(
                colorScheme == .dark ? .screen : .plusLighter
            )
            .allowsHitTesting(false)
    }

    private func updateMotion() {
        guard !reduceMotion else {
            fieldAlive = false
            return
        }
        guard !fieldAlive else { return }
        withAnimation(
            .easeInOut(duration: 5.8)
                .repeatForever(autoreverses: true)
        ) {
            fieldAlive = true
        }
    }
}

private struct HomeHeroLottieRepresentable: UIViewRepresentable {
    let animationName: String
    let loadsFromFirebase: Bool
    let playbackEnabled: Bool

    func makeUIView(context: Context) -> PPHomeHeroAnimationView {
        let view = PPHomeHeroAnimationView(
            animationName: animationName,
            loadsFromFirebase: loadsFromFirebase
        )
        view.isPlaybackEnabled = playbackEnabled
        return view
    }

    func updateUIView(
        _ uiView: PPHomeHeroAnimationView,
        context: Context
    ) {
        uiView.isPlaybackEnabled = playbackEnabled
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
