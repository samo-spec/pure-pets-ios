import Combine
import SwiftUI
import UIKit

// MARK: - Coordinated Scroll View Subclass

final class PPPetAdCoordinatedScrollView: UIScrollView {
    var onScrollOffsetChanged: ((CGFloat) -> Void)?

    override var contentOffset: CGPoint {
        get { super.contentOffset }
        set {
            super.contentOffset = newValue
            onScrollOffsetChanged?(newValue.y)
        }
    }
}

// MARK: - Sheet & Hero Scroll Coordinator

@MainActor
final class PPPetAdSheetScrollCoordinator: ObservableObject {

    // MARK: Published state

    @Published private(set) var currentHeroHeight: CGFloat = 440
    @Published private(set) var collapseProgress: CGFloat = 0
    @Published private(set) var isPinned: Bool = false
    @Published private(set) var navBarScrollOffset: CGFloat = 0

    // MARK: Geometry Bounds

    private(set) var minHeroHeight: CGFloat = 180
    private(set) var maxHeroHeight: CGFloat = 440
    private(set) var collapseRange: CGFloat = 260
    private var isConfigured = false

    weak var scrollView: PPPetAdCoordinatedScrollView?

    // MARK: Configuration

    func configure(minHeroHeight: CGFloat, maxHeroHeight: CGFloat) {
        guard !isConfigured || self.minHeroHeight != minHeroHeight || self.maxHeroHeight != maxHeroHeight else { return }
        self.minHeroHeight = max(80, minHeroHeight)
        self.maxHeroHeight = max(self.minHeroHeight + 40, maxHeroHeight)
        self.collapseRange = self.maxHeroHeight - self.minHeroHeight
        self.currentHeroHeight = self.maxHeroHeight
        self.isConfigured = true
    }

    // MARK: Dynamic Scroll & Drag Updates

    func updateScroll(offsetY: CGFloat) {
        if offsetY <= 0 {
            let pull = max(0, -offsetY)
            let rubberBandPull = sqrt(pull) * 3.5
            currentHeroHeight = maxHeroHeight + rubberBandPull
            collapseProgress = 0
            isPinned = false
            navBarScrollOffset = -pull
        } else if offsetY <= collapseRange {
            currentHeroHeight = max(minHeroHeight, maxHeroHeight - offsetY)
            collapseProgress = (maxHeroHeight - currentHeroHeight) / collapseRange
            isPinned = currentHeroHeight <= minHeroHeight + 0.5
            navBarScrollOffset = offsetY
        } else {
            currentHeroHeight = minHeroHeight
            collapseProgress = 1.0
            isPinned = true
            navBarScrollOffset = offsetY
        }
    }
}

// MARK: - UIScrollViewDelegate bridge

final class PPPetAdScrollViewBridge: NSObject, UIScrollViewDelegate {
    let coordinator: PPPetAdSheetScrollCoordinator
    let onRefresh: () -> Void
    weak var hostingController: UIViewController?

    init(
        coordinator: PPPetAdSheetScrollCoordinator,
        onRefresh: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.onRefresh = onRefresh
    }

    @objc func handleRefresh() {
        onRefresh()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        Task { @MainActor in
            coordinator.updateScroll(offsetY: scrollView.contentOffset.y)
        }
    }
}

// MARK: - UIViewRepresentable Internal Scroll Container

struct PPPetAdInternalScrollView<Content: View>: UIViewRepresentable {
    @ObservedObject var coordinator: PPPetAdSheetScrollCoordinator
    let onRefresh: () -> Void
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> PPPetAdScrollViewBridge {
        PPPetAdScrollViewBridge(
            coordinator: coordinator,
            onRefresh: onRefresh
        )
    }

    func makeUIView(context: Context) -> PPPetAdCoordinatedScrollView {
        let sv = PPPetAdCoordinatedScrollView()
        sv.showsVerticalScrollIndicator = true
        sv.showsHorizontalScrollIndicator = false
        sv.alwaysBounceVertical = true
        sv.bounces = true
        sv.isScrollEnabled = true
        sv.delegate = context.coordinator
        sv.backgroundColor = .clear
        sv.keyboardDismissMode = .onDrag

        sv.onScrollOffsetChanged = { [weak coordinator = context.coordinator] offsetY in
            Task { @MainActor in
                coordinator?.coordinator.updateScroll(offsetY: offsetY)
            }
        }

        let rc = UIRefreshControl()
        rc.addTarget(
            context.coordinator,
            action: #selector(PPPetAdScrollViewBridge.handleRefresh),
            for: .valueChanged
        )
        sv.refreshControl = rc

        let hosting = UIHostingController(rootView: content())
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.backgroundColor = .clear
        sv.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: sv.contentLayoutGuide.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: sv.contentLayoutGuide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: sv.contentLayoutGuide.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: sv.contentLayoutGuide.bottomAnchor),
            hosting.view.widthAnchor.constraint(equalTo: sv.frameLayoutGuide.widthAnchor)
        ])

        context.coordinator.hostingController = hosting
        coordinator.scrollView = sv
        return sv
    }

    func updateUIView(_ scrollView: PPPetAdCoordinatedScrollView, context: Context) {
        if let hosting = context.coordinator.hostingController as? UIHostingController<Content> {
            hosting.rootView = content()
        }
        if scrollView.refreshControl?.isRefreshing == true {
            scrollView.refreshControl?.endRefreshing()
        }
    }
}
