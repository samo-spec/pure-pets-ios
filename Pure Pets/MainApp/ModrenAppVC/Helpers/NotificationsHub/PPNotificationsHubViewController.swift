//
//  PPNotificationsHubViewController.swift
//  Pure Pets
//
//  SwiftUI replacement for the Objective-C `PPNotificationsHubViewController`.
//
//  Ownership contract preserved from the legacy screen:
//  • The hub owns tab selection, hero copy and the single action affordance.
//  • Chats and Reminders remain UIKit view controllers, created once and reused
//    across tab switches, so their state survives exactly as it did when the
//    legacy hub added and removed them as children.
//  • Navigation stays host-owned: pushes go through the real
//    `UINavigationController`, never a SwiftUI-managed stack.
//

import SwiftUI
import UIKit

// MARK: - Tab identity

enum PPNotificationsHubTab: Int, CaseIterable {
    case chats = 0
    case reminders = 1
    case notifications = 2

    var titleKey: String {
        switch self {
        case .chats: return "pet_chats_tab"
        case .reminders: return "pet_reminders_tab"
        case .notifications: return "notifications_inbox_tab"
        }
    }

    var subtitleKey: String {
        switch self {
        case .chats: return "notifications_hub_hero_chats_subtitle_no_stories"
        case .reminders: return "notifications_hub_hero_reminders_subtitle"
        case .notifications: return "notifications_hub_hero_notifications_subtitle"
        }
    }

    var segmentSymbol: String {
        switch self {
        case .chats: return "ellipsis.message.fill"
        case .reminders: return "bell.badge.fill"
        case .notifications: return "app.badge.fill"
        }
    }

    var actionSymbol: String {
        switch self {
        case .chats: return "square.and.pencil"
        case .reminders: return "plus"
        case .notifications: return "arrow.clockwise"
        }
    }

    var actionAccessibilityKey: String {
        switch self {
        case .chats: return "empty_chats_button"
        case .reminders: return "pet_reminder_add"
        case .notifications: return "empty_retry_button"
        }
    }
}

// MARK: - Model

@MainActor
final class PPNotificationsHubModel: ObservableObject {
    @Published var selectedTab: PPNotificationsHubTab = .chats
    @Published var bottomClearance: CGFloat = PPHubMetrics.listBaseBottomInset
    @Published var heroDidEnter: Bool = false
    /// Bumped on language change so every `PPHubText(...)` call re-resolves.
    @Published private(set) var languageRevision: Int = 0

    let inboxStore = PPNotificationsInboxStore()

    let chatsController: UserChatsViewController = {
        let controller = UserChatsViewController()
        controller.shouldHideStories = true
        return controller
    }()

    let remindersController = PPPetRemindersViewController()

    private var notificationTokens: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        // `PPLanguageDidChangeNotification` is a header-level C constant and is
        // therefore invisible to Swift; its literal value is used directly.
        for name in ["LanguageDidChangeNotification", "PPLanguageDidChangeNotification"] {
            let token = center.addObserver(
                forName: Notification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.languageRevision += 1 }
            }
            notificationTokens.append(token)
        }
    }

    deinit {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }

    var segmentItems: [PPHubTopTabItem] {
        PPNotificationsHubTab.allCases.map { tab in
            PPHubTopTabItem(
                id: tab.rawValue,
                title: PPHubText(tab.titleKey),
                systemImage: tab.segmentSymbol
            )
        }
    }

    func select(_ tab: PPNotificationsHubTab) {
        selectedTab = tab
        if tab == .notifications {
            inboxStore.reloadNotifications()
        }
    }

    func performPrimaryAction() {
        switch selectedTab {
        case .chats:
            chatsController.startNewChat()
        case .reminders:
            remindersController.pp_addReminder()
        case .notifications:
            inboxStore.reloadNotifications()
        }
    }
}

// MARK: - UIKit child bridge

/// Presents an already-instantiated UIKit view controller. The instance is
/// owned by `PPNotificationsHubModel`, so switching tabs detaches and
/// re-attaches the same controller instead of rebuilding it — matching the
/// legacy `addChildViewController` / `removeFromParentViewController` cycle.
private struct PPHubChildControllerView: UIViewControllerRepresentable {
    let controller: UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - Screen

struct PPNotificationsHubView: View {
    @ObservedObject var model: PPNotificationsHubModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var layoutDirection: LayoutDirection {
        Language.isRTL() ? .rightToLeft : .leftToRight
    }

    private var contentTransitionAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.26)
    }

    var body: some View {
        VStack(spacing: 0) {
            hero
                .padding(.horizontal, PPHubMetrics.heroHorizontalInset)
                .padding(.top, PPHubMetrics.heroTopInset)
                .opacity(model.heroDidEnter ? 1 : 0)
                .offset(y: model.heroDidEnter ? 0 : 12)

            Color.clear
                .frame(height: PPHubMetrics.contentTopGap)
                .accessibilityHidden(true)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ppBackground)
        .environment(\.layoutDirection, layoutDirection)
        .onAppear(perform: playHeroEntranceIfNeeded)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(PPHubText("notifications_hub_hero_eyebrow"))
                        .font(PPHubTypography.heroEyebrow())
                        .foregroundStyle(Color.ppAccentText)
                        .multilineTextAlignment(.leading)

                    Text(PPHubText(model.selectedTab.titleKey))
                        .font(PPHubTypography.heroTitle())
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, PPSpace.xxs)

                    Text(PPHubText(model.selectedTab.subtitleKey))
                        .font(PPHubTypography.heroSubtitle())
                        .foregroundStyle(Color.ppTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, PPSpace.xs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, PPSpace.xs)

                actionButton
                    .padding(.top, PPSpace.xs)
            }

            PPHubTopTabsView(
                items: model.segmentItems,
                selectedIndex: model.selectedTab.rawValue,
                onSelect: { index in
                    guard let tab = PPNotificationsHubTab(rawValue: index) else { return }
                    withAnimation(contentTransitionAnimation) {
                        model.select(tab)
                    }
                }
            )
            .padding(.top, PPSpace.md)
            .padding(.bottom, PPSpace.sm)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.selectedTab)
    }

    private var actionButton: some View {
        Button {
            model.performPrimaryAction()
        } label: {
            Image(systemName: model.selectedTab.actionSymbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ppPrimary)
                .frame(
                    width: PPHubMetrics.actionButtonSize,
                    height: PPHubMetrics.actionButtonSize
                )
                .background {
                    RoundedRectangle(cornerRadius: PPCorner.card - 3, style: .continuous)
                        .fill(Color.ppSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: PPCorner.card - 3, style: .continuous)
                                .strokeBorder(Color.ppBorder, lineWidth: 0.75)
                        }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PPHubText(model.selectedTab.actionAccessibilityKey))
        .accessibilityHint(PPHubText("empty_retry_button"))
    }

    // MARK: Content

    private var content: some View {
        ZStack {
            switch model.selectedTab {
            case .chats:
                PPHubChildControllerView(controller: model.chatsController)
                    .transition(childTransition)
            case .reminders:
                PPHubChildControllerView(controller: model.remindersController)
                    .transition(childTransition)
            case .notifications:
                PPNotificationsInboxView(
                    store: model.inboxStore,
                    bottomClearance: model.bottomClearance
                )
                .transition(childTransition)
            }
        }
    }

    private var childTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 8)),
            removal: .opacity.combined(with: .offset(y: -8))
        )
    }

    // MARK: Motion

    private func playHeroEntranceIfNeeded() {
        guard !model.heroDidEnter else { return }
        if reduceMotion {
            model.heroDidEnter = true
            return
        }
        withAnimation(.spring(duration: 0.42, bounce: 0.12).delay(0.02)) {
            model.heroDidEnter = true
        }
    }
}

// MARK: - Hosting controller

@MainActor
@objc(PPNotificationsHubViewController)
final class PPNotificationsHubViewController: UIViewController {

    private let model = PPNotificationsHubModel()
    private var hostingController: UIHostingController<PPNotificationsHubView>?
    private var hasStoredPreviousNavigationBarHidden = false
    private var previousNavigationBarHidden = false

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .ppBackground
        view.semanticContentAttribute = Language.isRTL() ? .forceRightToLeft : .forceLeftToRight

        model.inboxStore.hostViewController = self

        let hosting = UIHostingController(rootView: PPNotificationsHubView(model: model))
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hosting)
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
        hostingController = hosting

        applyNavigationItems()

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: Self, _) in
                controller.view.backgroundColor = .ppBackground
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !hasStoredPreviousNavigationBarHidden {
            previousNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
            hasStoredPreviousNavigationBarHidden = true
        }
        navigationController?.setNavigationBarHidden(true, animated: animated)
        applyNavigationItems()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if hasStoredPreviousNavigationBarHidden {
            navigationController?.setNavigationBarHidden(previousNavigationBarHidden, animated: animated)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateBottomClearance()
    }

    @objc func pp_showNotificationsInbox() {
        model.select(.notifications)
    }

    // MARK: Chrome

    private func applyNavigationItems() {
        navigationItem.title = nil
        navigationItem.titleView = nil
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = nil
    }

    /// The root tab controller owns the floating Command Deck clearance. Reading
    /// it here keeps a single source of truth instead of hard-coding a dock
    /// height, and lets a hidden or shrunken deck reclaim the space.
    private func updateBottomClearance() {
        var clearance = PPHubMetrics.listBaseBottomInset
        if let root = tabBarController as? PPRootTabBarController {
            clearance = max(clearance, root.pp_currentBottomNavigationContentClearance())
        }
        if abs(model.bottomClearance - clearance) > 0.5 {
            model.bottomClearance = clearance
        }
    }
}
