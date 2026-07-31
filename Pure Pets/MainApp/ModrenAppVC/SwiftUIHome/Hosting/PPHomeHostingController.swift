import Combine
import CoreLocation
import SwiftUI
import UIKit

/// SwiftUI production owner for the Pure Pets Home.
///
/// `PPHomeViewController` remains the Objective-C runtime compatibility shell;
/// this controller owns the visible hierarchy and the single authoritative
/// `HomeStore`.
@available(iOS 15.0, *)
@MainActor
@objc(PPHomeHostingController)
public final class PPHomeHostingController: UIViewController {
    private let store: HomeStore
    private let hostingController: UIHostingController<HomeView>
    private var stateCancellable: AnyCancellable?
    private var isInitialContentReady = false
    private var didRevealInitialContent = false
    private var initialCoverLookupAttempts = 0
    private var readinessFallbackTask: Task<Void, Never>?

    @objc(initWithOwner:)
    public init(owner: PPHomeViewController) {
        let store = HomeStore(owner: owner)
        self.store = store
        self.hostingController = UIHostingController(
            rootView: HomeView(store: store)
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError(
            "PPHomeHostingController must be created with its compatibility owner."
        )
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ppBackground

        addChild(hostingController)
        let hostedView = hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        hostedView.backgroundColor = .clear
        view.addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: view.topAnchor),
            hostedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostedView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingController.didMove(toParent: self)

        stateCancellable = store.$state
            .map(\.phase)
            .removeDuplicates()
            .sink { [weak self] phase in
                self?.homePhaseDidChange(phase)
            }

        store.start()
        scheduleReadinessFallback()
    }

    isolated deinit {
        readinessFallbackTask?.cancel()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scheduleInitialContentReveal()
    }

    @objc public func setInitialMainKindID(_ identifier: Int) {
        store.setInitialMainKindID(identifier)
    }

    @objc public func homeWillAppear() {
        store.setVisible(true)
    }

    @objc public func homeDidDisappear() {
        store.setVisible(false)
    }

    @objc public func refresh() {
        store.retryAll()
    }

    @objc public func handleReselection() {
        store.handleReselection()
    }

    @objc public func useAutomaticLocation() {
        store.requestAutomaticLocation()
    }

    @objc public var homeLocationAreaName: String {
        store.state.location.areaName
    }

    @objc public var homeLocationPresentationRawValue: Int {
        switch store.state.location.presentation {
        case .notDetermined: return 0
        case .loading: return 1
        case .ready: return 2
        case .denied: return 3
        case .restricted: return 4
        case .failed: return 5
        }
    }

    @objc public var homeLocationUsesManualSelection: Bool {
        store.state.location.isManual
    }

    @objc
    public func applyManualLocation(
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        title: String
    ) {
        store.applyManualLocation(
            latitude: latitude,
            longitude: longitude,
            title: title
        )
    }

    private func homePhaseDidChange(_ phase: HomeScreenPhase) {
        switch phase {
        case .loaded, .partial, .empty, .failed:
            readinessFallbackTask?.cancel()
            readinessFallbackTask = nil
            isInitialContentReady = true
            scheduleInitialContentReveal()
        case .coldLoading, .warmLoading, .refreshing:
            break
        }
    }

    private func scheduleReadinessFallback() {
        readinessFallbackTask?.cancel()
        readinessFallbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard !Task.isCancelled, let self, !self.didRevealInitialContent else {
                return
            }
            self.isInitialContentReady = true
            self.scheduleInitialContentReveal()
        }
    }

    /// The splash controller keeps a window-level snapshot in place until Home
    /// has a complete first presentation. The legacy UIKit Home removed this
    /// tag from its first-render gate; the SwiftUI owner preserves that launch
    /// contract here, after its state and layout are ready.
    private func scheduleInitialContentReveal() {
        guard isInitialContentReady, !didRevealInitialContent else { return }

        view.setNeedsLayout()
        view.layoutIfNeeded()
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()

        DispatchQueue.main.async { [weak self] in
            self?.revealInitialContentIfPossible()
        }
    }

    private func revealInitialContentIfPossible() {
        guard isInitialContentReady, !didRevealInitialContent else { return }
        guard let window = view.window else { return }

        guard let coverView = window.viewWithTag(99182) else {
            // Root installation and splash-cover attachment happen in the same
            // run-loop turn. Allow a few bounded retries if cached Home data
            // becomes ready before the cover has been attached.
            guard initialCoverLookupAttempts < 4 else { return }
            initialCoverLookupAttempts += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                [weak self] in
                self?.revealInitialContentIfPossible()
            }
            return
        }

        didRevealInitialContent = true
        coverView.frame = window.bounds
        window.bringSubviewToFront(coverView)

        let duration = UIAccessibility.isReduceMotionEnabled ? 0.0 : 0.4
        UIView.animate(
            withDuration: duration,
            delay: duration == 0 ? 0 : 0.04,
            options: [
                .curveEaseInOut,
                .beginFromCurrentState,
                .allowUserInteraction,
            ],
            animations: {
                coverView.alpha = 0
            },
            completion: { _ in
                coverView.removeFromSuperview()
            }
        )
    }
}
