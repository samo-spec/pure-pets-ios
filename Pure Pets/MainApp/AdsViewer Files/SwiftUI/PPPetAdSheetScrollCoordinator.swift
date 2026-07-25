import SwiftUI
import UIKit

@MainActor
final class PPPetAdHeroScrollVisualState: ObservableObject {
    @Published private(set) var collapseProgress: CGFloat = 0

    fileprivate func update(collapseProgress: CGFloat) {
        let normalized = min(max(collapseProgress, 0), 1)
        guard abs(normalized - self.collapseProgress) > 0.004 else {
            return
        }
        self.collapseProgress = normalized
    }
}

struct PPPetAdHeroScrollContainer<Hero: View, Content: View>:
    UIViewControllerRepresentable
{
    let minimumHeroHeight: CGFloat
    let expandedHeroHeight: CGFloat
    let onRefresh: () -> Void
    let onNavigationCollapseChanged: (Bool) -> Void

    private let hero: (PPPetAdHeroScrollVisualState) -> Hero
    private let content: () -> Content

    init(
        minimumHeroHeight: CGFloat,
        expandedHeroHeight: CGFloat,
        onRefresh: @escaping () -> Void,
        onNavigationCollapseChanged: @escaping (Bool) -> Void,
        @ViewBuilder hero:
            @escaping (PPPetAdHeroScrollVisualState) -> Hero,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.minimumHeroHeight = minimumHeroHeight
        self.expandedHeroHeight = expandedHeroHeight
        self.onRefresh = onRefresh
        self.onNavigationCollapseChanged =
            onNavigationCollapseChanged
        self.hero = hero
        self.content = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onNavigationCollapseChanged:
                onNavigationCollapseChanged
        )
    }

    func makeUIViewController(
        context: Context
    ) -> PPPetAdHeroScrollViewController<Hero, Content> {
        let controller = PPPetAdHeroScrollViewController(
            hero: hero(context.coordinator.visualState),
            content: content(),
            minimumHeroHeight: minimumHeroHeight,
            expandedHeroHeight: expandedHeroHeight,
            onRefresh: onRefresh
        )
        controller.onCollapseProgressChanged = {
            [weak coordinator = context.coordinator] progress in
            coordinator?.update(collapseProgress: progress)
        }
        applyLayoutDirection(
            context.environment.layoutDirection,
            to: controller
        )
        return controller
    }

    func updateUIViewController(
        _ controller:
            PPPetAdHeroScrollViewController<Hero, Content>,
        context: Context
    ) {
        context.coordinator.onNavigationCollapseChanged =
            onNavigationCollapseChanged
        controller.onRefresh = onRefresh
        controller.update(
            hero: hero(context.coordinator.visualState),
            content: content(),
            minimumHeroHeight: minimumHeroHeight,
            expandedHeroHeight: expandedHeroHeight
        )
        applyLayoutDirection(
            context.environment.layoutDirection,
            to: controller
        )
    }

    static func dismantleUIViewController(
        _ controller:
            PPPetAdHeroScrollViewController<Hero, Content>,
        coordinator: Coordinator
    ) {
        controller.stopCoordinating()
    }

    private func applyLayoutDirection(
        _ layoutDirection: LayoutDirection,
        to controller:
            PPPetAdHeroScrollViewController<Hero, Content>
    ) {
        let attribute: UISemanticContentAttribute =
            layoutDirection == .rightToLeft
            ? .forceRightToLeft
            : .forceLeftToRight
        controller.view.semanticContentAttribute = attribute
        controller.scrollView.semanticContentAttribute = attribute
    }

    @MainActor
    final class Coordinator {
        let visualState = PPPetAdHeroScrollVisualState()
        var onNavigationCollapseChanged: (Bool) -> Void

        private var isNavigationCollapsed = false

        init(
            onNavigationCollapseChanged:
                @escaping (Bool) -> Void
        ) {
            self.onNavigationCollapseChanged =
                onNavigationCollapseChanged
        }

        func update(collapseProgress: CGFloat) {
            visualState.update(
                collapseProgress: collapseProgress
            )

            let nextCollapsed =
                isNavigationCollapsed
                ? collapseProgress > 0.72
                : collapseProgress >= 0.86
            guard nextCollapsed != isNavigationCollapsed else {
                return
            }
            isNavigationCollapsed = nextCollapsed
            onNavigationCollapseChanged(nextCollapsed)
        }
    }
}

@MainActor
private final class PPPetAdSizingHostingController<Content: View>:
    UIHostingController<Content>
{
    var onPreferredHeightChanged: ((CGFloat, CGFloat) -> Void)?

    private var lastReportedWidth: CGFloat = 0
    private var lastReportedHeight: CGFloat = 0

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let width = view.bounds.width
        guard width > 0 else { return }

        let measuredHeight = ceil(
            sizeThatFits(
                in: CGSize(
                    width: width,
                    height: UIView.layoutFittingExpandedSize.height
                )
            ).height
        )
        guard measuredHeight.isFinite, measuredHeight > 0 else {
            return
        }
        guard abs(lastReportedWidth - width) > 0.5
                || abs(lastReportedHeight - measuredHeight) > 0.5 else {
            return
        }

        lastReportedWidth = width
        lastReportedHeight = measuredHeight
        DispatchQueue.main.async {
            [weak self] in
            self?.onPreferredHeightChanged?(
                width,
                measuredHeight
            )
        }
    }
}

@MainActor
final class PPPetAdHeroScrollViewController<
    Hero: View,
    Content: View
>: UIViewController, UIScrollViewDelegate {
    let scrollView = UIScrollView()

    var onRefresh: () -> Void
    var onCollapseProgressChanged: ((CGFloat) -> Void)?

    private let heroController: UIHostingController<Hero>
    private let contentController:
        PPPetAdSizingHostingController<Content>
    private let refreshControl = UIRefreshControl()

    private var heroHeightConstraint: NSLayoutConstraint!
    private var contentHeightConstraint: NSLayoutConstraint!
    private var minimumHeroHeight: CGFloat
    private var expandedHeroHeight: CGFloat
    private var hasAppliedInitialOffset = false
    private var isApplyingMetrics = false
    private var lastMeasuredContentWidth: CGFloat = 0
    private var needsContentMeasurement = true
    private var pendingContentMeasurement:
        (height: CGFloat, width: CGFloat)?

    init(
        hero: Hero,
        content: Content,
        minimumHeroHeight: CGFloat,
        expandedHeroHeight: CGFloat,
        onRefresh: @escaping () -> Void
    ) {
        heroController = UIHostingController(rootView: hero)
        if #available(iOS 16.4, *) {
            heroController.safeAreaRegions = []
        }
        contentController =
            PPPetAdSizingHostingController(rootView: content)
        self.minimumHeroHeight = minimumHeroHeight
        self.expandedHeroHeight = expandedHeroHeight
        self.onRefresh = onRefresh
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        contentController.onPreferredHeightChanged = {
            [weak self] width, height in
            self?.applyMeasuredContentHeight(
                height,
                measuredWidth: width
            )
        }

        configureScrollView()
        installHeroController()
        installContentController()
        scrollView.bringSubviewToFront(contentController.view)
        scrollView.bringSubviewToFront(refreshControl)
        applyMetrics(preservingPosition: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateContentHeightIfNeeded()
        updateHero(for: scrollView.contentOffset.y)
    }

    func update(
        hero: Hero,
        content: Content,
        minimumHeroHeight: CGFloat,
        expandedHeroHeight: CGFloat
    ) {
        heroController.rootView = hero
        contentController.rootView = content

        let metricsChanged =
            abs(self.minimumHeroHeight - minimumHeroHeight) > 0.5
            || abs(self.expandedHeroHeight - expandedHeroHeight) > 0.5
        self.minimumHeroHeight = minimumHeroHeight
        self.expandedHeroHeight = expandedHeroHeight

        contentController.view.invalidateIntrinsicContentSize()
        needsContentMeasurement = true
        view.setNeedsLayout()
        if metricsChanged {
            applyMetrics(preservingPosition: true)
        }
    }

    func stopCoordinating() {
        scrollView.delegate = nil
        onCollapseProgressChanged = nil
        contentController.onPreferredHeightChanged = nil
        refreshControl.removeTarget(
            self,
            action: #selector(refreshRequested),
            for: .valueChanged
        )
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isApplyingMetrics else { return }
        updateHero(for: scrollView.contentOffset.y)
    }

    func scrollViewDidEndDragging(
        _ scrollView: UIScrollView,
        willDecelerate decelerate: Bool
    ) {
        guard !decelerate else { return }
        applyPendingContentMeasurementIfNeeded()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        applyPendingContentMeasurementIfNeeded()
    }

    @objc
    private func refreshRequested() {
        onRefresh()
        DispatchQueue.main.async { [weak self] in
            self?.refreshControl.endRefreshing()
        }
    }

    private func configureScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.isDirectionalLockEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        scrollView.refreshControl = refreshControl
        scrollView.accessibilityIdentifier =
            "PPPetAdViewer.ScrollView"

        refreshControl.tintColor =
            UIColor(named: "AppPrimaryColor")
        refreshControl.addTarget(
            self,
            action: #selector(refreshRequested),
            for: .valueChanged
        )

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(
                equalTo: view.topAnchor,
                constant: 0
            ),
            scrollView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            scrollView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            )
        ])
    }

    private func installContentController() {
        addChild(contentController)
        contentController.view.translatesAutoresizingMaskIntoConstraints =
            false
        contentController.view.backgroundColor = .clear
        scrollView.addSubview(contentController.view)

        contentHeightConstraint =
            contentController.view.heightAnchor.constraint(
                equalToConstant: 1
            )
        NSLayoutConstraint.activate([
            contentController.view.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor
            ),
            contentController.view.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor
            ),
            contentController.view.trailingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.trailingAnchor
            ),
            contentController.view.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor
            ),
            contentController.view.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor
            ),
            contentHeightConstraint
        ])
        contentController.didMove(toParent: self)
        scrollView.bringSubviewToFront(contentController.view)
    }

    private func installHeroController() {
        addChild(heroController)
        heroController.view.translatesAutoresizingMaskIntoConstraints =
            false
        heroController.view.backgroundColor = .clear
        heroController.view.clipsToBounds = false
        heroController.view.isUserInteractionEnabled = true
        scrollView.addSubview(heroController.view)

        heroHeightConstraint =
            heroController.view.heightAnchor.constraint(
                equalToConstant: expandedHeroHeight
            )
        NSLayoutConstraint.activate([
            heroController.view.topAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.topAnchor,
                constant: 0
            ),
            heroController.view.leadingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.leadingAnchor
            ),
            heroController.view.trailingAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.trailingAnchor
            ),
            heroHeightConstraint
        ])
        heroController.didMove(toParent: self)
        scrollView.bringSubviewToFront(refreshControl)
    }

    private func applyMetrics(preservingPosition: Bool) {
        guard isViewLoaded else { return }

        let minimum = max(minimumHeroHeight, 1)
        let expanded = max(expandedHeroHeight, minimum + 1)
        let previousExpanded = scrollView.contentInset.top
        let previousOffset = scrollView.contentOffset.y
        let wasAtRest =
            !hasAppliedInitialOffset
            || abs(previousOffset + previousExpanded) < 1.5

        isApplyingMetrics = true
        scrollView.contentInset.top = expanded
        scrollView.verticalScrollIndicatorInsets.top = minimum

        if !preservingPosition || wasAtRest {
            scrollView.setContentOffset(
                CGPoint(x: 0, y: -expanded),
                animated: false
            )
        } else if previousExpanded > 0 {
            let distanceFromRest =
                previousOffset + previousExpanded
            scrollView.setContentOffset(
                CGPoint(
                    x: 0,
                    y: -expanded + distanceFromRest
                ),
                animated: false
            )
        }

        hasAppliedInitialOffset = true
        isApplyingMetrics = false
        updateHero(for: scrollView.contentOffset.y)
    }

    private func updateHero(for contentOffsetY: CGFloat) {
        let minimum = max(minimumHeroHeight, 1)
        let expanded = max(expandedHeroHeight, minimum + 1)
        let visibleInsetHeight = -contentOffsetY
        let heroHeight = max(minimum, visibleInsetHeight)
        let collapseRange = max(expanded - minimum, 1)
        let clampedVisibleHeight =
            min(max(visibleInsetHeight, minimum), expanded)
        let progress =
            (expanded - clampedVisibleHeight) / collapseRange

        if abs(heroHeightConstraint.constant - heroHeight) > 0.25 {
            heroHeightConstraint.constant = heroHeight
            scrollView.setNeedsLayout()
        }

        onCollapseProgressChanged?(progress)
    }

    private func updateContentHeightIfNeeded() {
        let width = scrollView.bounds.width
        guard width > 0 else { return }
        guard needsContentMeasurement
                || abs(lastMeasuredContentWidth - width) > 0.5 else {
            return
        }

        let targetSize = contentController.sizeThatFits(
            in: CGSize(
                width: width,
                height: UIView.layoutFittingExpandedSize.height
            )
        )
        let resolvedHeight = max(ceil(targetSize.height), 1)
        scheduleOrApplyContentHeight(
            resolvedHeight,
            measuredWidth: width
        )
    }

    private func applyMeasuredContentHeight(
        _ height: CGFloat,
        measuredWidth: CGFloat
    ) {
        guard abs(scrollView.bounds.width - measuredWidth) < 1 else {
            return
        }
        let resolvedHeight = max(height, 1)

        scheduleOrApplyContentHeight(
            resolvedHeight,
            measuredWidth: measuredWidth
        )
    }

    private func scheduleOrApplyContentHeight(
        _ height: CGFloat,
        measuredWidth: CGFloat
    ) {
        needsContentMeasurement = false
        lastMeasuredContentWidth = measuredWidth

        if scrollView.isDragging || scrollView.isDecelerating {
            pendingContentMeasurement = (
                height: height,
                width: measuredWidth
            )
            return
        }

        pendingContentMeasurement = nil
        applyContentHeight(height)
    }

    private func applyPendingContentMeasurementIfNeeded() {
        guard let pendingContentMeasurement else { return }
        self.pendingContentMeasurement = nil
        guard abs(
            scrollView.bounds.width - pendingContentMeasurement.width
        ) < 1 else {
            needsContentMeasurement = true
            view.setNeedsLayout()
            return
        }
        applyContentHeight(pendingContentMeasurement.height)
    }

    private func applyContentHeight(_ height: CGFloat) {
        guard abs(contentHeightConstraint.constant - height) > 0.5 else {
            return
        }
        contentHeightConstraint.constant = height
        scrollView.setNeedsLayout()
    }
}
