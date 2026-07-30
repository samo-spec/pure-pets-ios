import SwiftUI

private enum HomePresentationFlags {
    /// Kept as a one-line restoration point while the location workflow and
    /// premium sheet remain fully wired.
    static let showsLocationContextPill = false
}

@available(iOS 16.0, *)
@available(iOS 16.0, *)
struct HomeView: View {
    @ObservedObject var store: HomeStore

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var loadedEntranceVisible = false

    private let topAnchor = "pp-home-top"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Color.clear
                        .frame(height: 1)
                        .id(topAnchor)
                        .accessibilityHidden(true)

                    Section {
                        content
                            .padding(.top, PPSpace.md)
                            .padding(.bottom, bottomPadding)
                    } header: {
                        HomeCommandBar(
                            state: store.state,
                            searchAction: store.router.openSearch,
                            cartAction: store.router.openCart
                        )
                        .zIndex(10)
                    }
                }
            }
            .background(background)
            .scrollDismissesKeyboardCompat()
            .refreshable {
                await store.refresh()
            }
            .onChange(of: store.scrollToTopGeneration) { _ in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) {
                    proxy.scrollTo(topAnchor, anchor: .top)
                }
            }
        }
        .environment(
            \.layoutDirection,
            store.state.isRightToLeft ? .rightToLeft : .leftToRight
        )
        .overlay(alignment: .bottomTrailing) {
            if store.state.config.novaFloatingVisible {
                novaButton
                    .padding(.trailing, PPSpace.screenMargin)
                    .padding(
                        .bottom,
                        store.state.bottomContentClearance + PPSpace.md
                    )
            }
        }
        .onChange(of: scenePhase) { phase in
            DispatchQueue.main.async {
                store.setSceneActive(phase == .active)
            }
        }
        .onChange(of: reduceMotion) { value in
            DispatchQueue.main.async {
                store.setReduceMotion(value)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: PPSpace.xl) {
            if HomePresentationFlags.showsLocationContextPill {
                HomeLocationContextButton(
                    state: store.state,
                    action: store.locationTapped
                )
                .padding(.horizontal, PPSpace.screenMargin)
            }

            HomeStatusBanner(
                state: store.state,
                retry: store.retryAll
            )
            .padding(.horizontal, PPSpace.screenMargin)

            switch store.state.phase {
            case .coldLoading, .warmLoading:
                loadingContent
            case let .failed(message):
                HomeInlineState(
                    symbol: "wifi.exclamationmark",
                    title: HomeModelAdapter.localized(
                        "home_pulse_failed_title",
                        fallback: "Home could not load"
                    ),
                    message: message,
                    actionTitle: HomeModelAdapter.localized(
                        "Retry",
                        fallback: "Retry"
                    ),
                    action: store.retryAll
                )
                .padding(.horizontal, PPSpace.screenMargin)
            case .empty:
                emptyContent
            case .loaded, .refreshing, .partial:
                loadedContent
            }
        }
    }

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: PPSpace.xl) {
            HomeHeroView(
                pages: [],
                selectedIndex: 0,
                onSelect: { _ in },
                onPrimaryAction: {},
                onSecondaryAction: {},
                onInteractionChanged: { _ in }
            )
            .padding(.horizontal, PPSpace.screenMargin)

            HomePriorityGrid(
                actions: placeholderActions,
                onSelect: { _ in }
            )
            .redacted(reason: .placeholder)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .padding(.horizontal, PPSpace.screenMargin)

            HomeInlineState(
                symbol: "hourglass",
                title: HomeModelAdapter.localized(
                    "home_pulse_loading_title",
                    fallback: "Preparing your Home"
                ),
                message: HomeModelAdapter.localized(
                    "home_pulse_loading_message",
                    fallback: "Pet context, marketplace, and care destinations are loading."
                ),
                actionTitle: nil,
                action: nil
            )
            .padding(.horizontal, PPSpace.screenMargin)
        }
    }

    private var loadedContent: some View {
        Group {
            HomeHeroView(
                pages: store.state.heroPages,
                selectedIndex: store.state.selectedHeroIndex,
                onSelect: store.selectHero,
                onPrimaryAction: store.performSelectedHeroAction,
                onSecondaryAction: store.performSelectedHeroSecondaryAction,
                onInteractionChanged: store.setHeroInteractionActive
            )
            .padding(.horizontal, PPSpace.screenMargin)
            .homeEntrance(
                isVisible: loadedEntranceVisible,
                delay: 0.06,
                reduceMotion: reduceMotion
            )
            .onAppear(perform: startLoadedEntranceIfNeeded)

            if !store.state.categories.isEmpty {
                HomeCategoryRail(
                    categories: store.state.categories,
                    selectedID: store.state.selectedMainKindID,
                    onSelect: store.selectCategory
                )
            }

            if !store.state.pets.isEmpty {
                HomePetSwitcher(
                    pets: store.state.pets,
                    selectedID: store.state.selectedPetID,
                    onSelect: store.selectPet,
                    onEdit: store.editSelectedPet
                )
                .homeEntrance(
                    isVisible: loadedEntranceVisible,
                    delay: 0.08,
                    reduceMotion: reduceMotion
                )
            }

            HomePriorityGrid(
                actions: store.state.priorityActions,
                onSelect: store.performPriorityAction
            )
            .padding(.horizontal, PPSpace.screenMargin)
            .homeEntrance(
                isVisible: loadedEntranceVisible,
                delay: 0.10,
                reduceMotion: reduceMotion
            )

            if let order = store.state.featuredOrder {
                HomeOrderCard(
                    order: order,
                    onTap: store.openFeaturedOrder,
                    onSeeAll: {
                        store.seeAll(.currentOrder)
                    }
                )
                .padding(.horizontal, PPSpace.screenMargin)
            }

            ForEach(store.state.sections) { section in
                HomeFeedSection(section: section, store: store)
                    .id(section.id)
            }

            HomeMyPetProfileCard(
                pets: store.state.pets,
                selectedID: store.state.selectedPetID,
                isLoading: store.state.phase.isLoading,
                errorMessage: nil,
                action: store.openPetProfiles
            )
            .padding(.horizontal, PPSpace.screenMargin)
            .homeEntrance(
                isVisible: loadedEntranceVisible,
                delay: 0.18,
                reduceMotion: reduceMotion
            )
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: PPSpace.xl) {
            HomeHeroView(
                pages: store.state.heroPages,
                selectedIndex: store.state.selectedHeroIndex,
                onSelect: store.selectHero,
                onPrimaryAction: store.performSelectedHeroAction,
                onSecondaryAction: store.performSelectedHeroSecondaryAction,
                onInteractionChanged: store.setHeroInteractionActive
            )

            HomeInlineState(
                symbol: "pawprint.fill",
                title: HomeModelAdapter.localized(
                    "home_pulse_empty_title",
                    fallback: "Your Home is ready to grow"
                ),
                message: HomeModelAdapter.localized(
                    "home_pulse_empty_message",
                    fallback: "Explore pet listings, products, and care destinations while new recommendations arrive."
                ),
                actionTitle: HomeModelAdapter.localized(
                    "home_pulse_explore_market",
                    fallback: "Explore marketplace"
                ),
                action: store.exploreMarketplace
            )
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .homeEntrance(
            isVisible: loadedEntranceVisible,
            delay: 0.06,
            reduceMotion: reduceMotion
        )
        .onAppear(perform: startLoadedEntranceIfNeeded)
    }

    private var background: some View {
        Group {
            if showsAmbientDecoration {
                PPHero(
                    accentStyle: .bbBaseBackground,
                    useShimmer: false,
                    useUnderFingerMotion: false
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            } else {
                Color.ppBackground
                    .ignoresSafeArea()
            }
        }
    }

    private var showsAmbientDecoration: Bool {
        !store.state.config.backgroundGlowsFaded
    }

    private var novaButton: some View {
        Button(action: store.router.openNova) {
            Image(systemName: "sparkles")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 54, height: 54)
                .background(
                    LinearGradient(
                        colors: [.ppPrimaryShiner, .ppPrimary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay(Circle().stroke(Color.white.opacity(0.72), lineWidth: 1))
                .shadow(color: Color.ppPrimary.opacity(0.28), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            HomeModelAdapter.localized(
                "home_pulse_nova_a11y",
                fallback: "Open Nova assistant"
            )
        )
        .accessibilityHint(
            HomeModelAdapter.localized(
                "home_pulse_nova_hint_a11y",
                fallback: "Ask Pure Pets for help"
            )
        )
    }

    private var bottomPadding: CGFloat {
        store.state.bottomContentClearance +
            (dynamicTypeSize.isAccessibilitySize ? 144 : 96)
    }

    private func startLoadedEntranceIfNeeded() {
        guard !loadedEntranceVisible else { return }
        loadedEntranceVisible = true
    }

    private var placeholderActions: [HomePriorityAction] {
        (0 ..< 6).map { index in
            HomePriorityAction(
                id: "placeholder-\(index)",
                title: "••••",
                subtitle: "••••••••",
                systemImage: "pawprint.fill",
                accent: .ppPrimary,
                destination: .petProfile
            )
        }
    }
}

private struct HomeEntranceModifier: ViewModifier {
    let isVisible: Bool
    let delay: Double
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(
                y: reduceMotion || isVisible
                    ? 0
                    : 20
            )
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.16)
                    : .spring(
                        response: 0.68,
                        dampingFraction: 0.90
                    )
                    .delay(delay),
                value: isVisible
            )
    }
}

private extension View {
    func homeEntrance(
        isVisible: Bool,
        delay: Double,
        reduceMotion: Bool
    ) -> some View {
        modifier(
            HomeEntranceModifier(
                isVisible: isVisible,
                delay: delay,
                reduceMotion: reduceMotion
            )
        )
    }

    @ViewBuilder
    func scrollDismissesKeyboardCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}
