//
//  NovaAmbientAssistantCoordinator.swift
//  Pure Pets
//
//  Centralizes contextual Nova presentation timing, cooldown, copy, and
//  eligibility. It deliberately leaves Nova chat/backend/API behavior untouched.
//

import UIKit

@objc(NovaAmbientAssistantCoordinator)
public final class NovaAmbientAssistantCoordinator: NSObject {
    @objc(sharedCoordinator)
    public static let shared = NovaAmbientAssistantCoordinator()

    private enum Context {
        case homeIdle
        case searchFocus
        case browsingPause
        case category
        case emptyState
        case shake
    }

    private enum Placement {
        case bottom
        case upper
    }

    private struct DefaultsKey {
        static let snoozedUntil = "pp.novaAmbient.snoozedUntil"
    }

    private weak var presenter: UIViewController?
    private weak var currentHostView: UIView?
    private var assistantView: NovaAmbientAssistantView?
    private var activeConstraints: [NSLayoutConstraint] = []

    private var screen = "unknown"
    private var screenAppearedAt = Date.distantPast
    private var sessionAppearanceCount = 0
    private var isUserTyping = false
    private var isSuppressedForCriticalFlow = false

    private var pendingShowWorkItem: DispatchWorkItem?
    private var autoHideWorkItem: DispatchWorkItem?
    private var typingIdleWorkItem: DispatchWorkItem?
    private var lastAppearanceAt = Date.distantPast

    private let defaults = UserDefaults.standard
    private let maxAppearancesPerSession = 3
    private let minimumDwellBeforeShow: TimeInterval = 1.45
    private let minimumGapBetweenAppearances: TimeInterval = 10.0
    private let dismissSnoozeInterval: TimeInterval = 10.0 * 60.0
    private let autoHideInterval: TimeInterval = 7.5

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reducedMotionDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc(screenDidAppearInViewController:screen:)
    public func screenDidAppear(in viewController: UIViewController, screen: String) {
        cancelPendingShow()
        cancelAutoHide()

        if presenter !== viewController {
            hideNova(animated: false)
        }

        presenter = viewController
        self.screen = screen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "unknown" : screen
        screenAppearedAt = Date()
        isUserTyping = false
        isSuppressedForCriticalFlow = false

        let context: Context = self.screen == "home" ? .homeIdle : .browsingPause
        scheduleShow(context: context, after: self.screen == "home" ? 3.0 : 2.2)
    }

    @objc public func userDidScroll() {
        cancelPendingShow()
        cancelAutoHide()
        hideNova(animated: true)
    }

    @objc public func userDidStopScrolling() {
        scheduleShow(context: .browsingPause, after: interactionDelayRespectingCooldown(minimumDelay: 0.85))
    }

    @objc public func searchDidFocus() {
        isUserTyping = false
        scheduleShow(context: .searchFocus, after: interactionDelayRespectingCooldown(minimumDelay: 0.9))
    }

    @objc public func searchDidBlur() {
        isUserTyping = false
        scheduleShow(context: screen == "home" ? .homeIdle : .browsingPause,
                     after: interactionDelayRespectingCooldown(minimumDelay: 3.0))
    }

    @objc public func userDidBeginTyping() {
        isUserTyping = true
        cancelPendingShow()
        hideNova(animated: true)

        typingIdleWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.isUserTyping = false
        }
        typingIdleWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: workItem)
    }

    @objc(categoryDidOpen:)
    public func categoryDidOpen(_ categoryName: String?) {
        _ = categoryName
        isUserTyping = false
        scheduleShow(context: .category, after: interactionDelayRespectingCooldown(minimumDelay: 1.15))
    }

    @objc public func emptyStateDidAppear() {
        isUserTyping = false
        scheduleShow(context: .emptyState, after: interactionDelayRespectingCooldown(minimumDelay: 0.75))
    }

    @objc public func hideNova() {
        hideNova(animated: true)
    }

    @objc public func userDidShakeDevice() {
        cancelPendingShow()
        cancelAutoHide()
        guard isEligibleForManualAppearance() else { return }

        if let view = assistantView, view.superview != nil {
            view.configure(message: message(for: .shake))
            view.animateAttention()
            lastAppearanceAt = Date()
            triggerLightFeedback()
            scheduleAutoHide()
            return
        }

        show(context: .shake, countsAsSessionAppearance: false)
        triggerLightFeedback()
    }

    @objc(setSuppressedForCriticalFlow:)
    public func setSuppressedForCriticalFlow(_ suppressed: Bool) {
        isSuppressedForCriticalFlow = suppressed
        if suppressed {
            cancelPendingShow()
            hideNova(animated: true)
        }
    }

    @objc public func openNovaChat() {
        guard let presenter = visiblePresenter() else { return }
        cancelPendingShow()
        cancelAutoHide()
        hideNova(animated: true)

        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.prepare()
        feedback.impactOccurred()

        PPNovaAmbientAssistantChatBridge.open(from: presenter)
    }

    private func scheduleShow(context: Context, after delay: TimeInterval) {
        cancelPendingShow()

        let workItem = DispatchWorkItem { [weak self] in
            self?.attemptShow(context: context)
        }
        pendingShowWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func attemptShow(context: Context) {
        pendingShowWorkItem = nil
        guard isEligibleForAppearance() else { return }
        show(context: context)
    }

    private func show(context: Context, countsAsSessionAppearance: Bool = true) {
        guard let presenter = visiblePresenter() else { return }

        let view = assistantView ?? NovaAmbientAssistantView()
        assistantView = view
        view.removeTarget(nil, action: nil, for: .allEvents)
        view.addTarget(self, action: #selector(openNovaChat), for: .touchUpInside)
        view.setCloseHandler { [weak self] in
            self?.dismissFromUser()
        }
        view.configure(message: message(for: context))

        attach(view, to: presenter)
        view.prepareForEntrance()
        presenter.view.layoutIfNeeded()
        view.animateIn()

        if countsAsSessionAppearance { sessionAppearanceCount += 1 }
        lastAppearanceAt = Date()

        scheduleAutoHide()
    }

    private func attach(_ view: NovaAmbientAssistantView, to presenter: UIViewController) {
        guard let hostView: UIView = presenter.tabBarController?.view
            ?? presenter.navigationController?.view
            ?? presenter.view else {
            return
        }
        if view.superview !== hostView {
            NSLayoutConstraint.deactivate(activeConstraints)
            activeConstraints.removeAll()
            view.removeFromSuperview()
            hostView.addSubview(view)
            currentHostView = hostView

            let guide = hostView.safeAreaLayoutGuide
            let responsiveWidth = view.widthAnchor.constraint(equalTo: guide.widthAnchor, constant: -32.0)
            responsiveWidth.priority = UILayoutPriority.defaultHigh
            activeConstraints = [
                view.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: 16.0),
                view.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -16.0),
                view.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
                responsiveWidth,
                view.widthAnchor.constraint(greaterThanOrEqualToConstant: 280.0),
                view.widthAnchor.constraint(lessThanOrEqualToConstant: 364.0)
            ]

            switch placement(for: screen) {
            case .upper:
                activeConstraints.append(view.topAnchor.constraint(equalTo: guide.topAnchor, constant: 78.0))
            case .bottom:
                if let bottomAnchorView = bottomNavigationAnchorView(for: presenter, in: hostView) {
                    activeConstraints.append(view.bottomAnchor.constraint(equalTo: bottomAnchorView.topAnchor, constant: -12.0))
                } else {
                    activeConstraints.append(view.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -14.0))
                }
            }

            NSLayoutConstraint.activate(activeConstraints)
        }

        hostView.bringSubviewToFront(view)
    }

    private func dismissFromUser() {
        defaults.set(Date().addingTimeInterval(dismissSnoozeInterval).timeIntervalSince1970,
                     forKey: DefaultsKey.snoozedUntil)
        cancelPendingShow()
        cancelAutoHide()
        hideNova(animated: true)
    }

    private func hideNova(animated: Bool) {
        guard let view = assistantView, view.superview != nil else { return }

        let cleanup = { [weak self, weak view] in
            guard let self else { return }
            NSLayoutConstraint.deactivate(self.activeConstraints)
            self.activeConstraints.removeAll()
            view?.removeFromSuperview()
            self.currentHostView = nil
        }

        if animated {
            view.animateOut(completion: cleanup)
        } else {
            view.removeFromSuperview()
            cleanup()
        }
    }

    private func scheduleAutoHide() {
        cancelAutoHide()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.hideNova(animated: true)
            self.schedulePassiveReappearanceAfterAutoHide()
        }
        autoHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + autoHideInterval, execute: workItem)
    }

    private func schedulePassiveReappearanceAfterAutoHide() {
        guard sessionAppearanceCount < maxAppearancesPerSession else { return }
        guard !isCriticalScreen(screen), !isSuppressedForCriticalFlow else { return }
        guard Date().timeIntervalSince1970 >= defaults.double(forKey: DefaultsKey.snoozedUntil) else { return }

        let elapsedSinceLastAppearance = Date().timeIntervalSince(lastAppearanceAt)
        let delay = max(1.0, minimumGapBetweenAppearances - elapsedSinceLastAppearance)
        scheduleShow(context: passiveContext(), after: delay)
    }

    private func cancelPendingShow() {
        pendingShowWorkItem?.cancel()
        pendingShowWorkItem = nil
    }

    private func cancelAutoHide() {
        autoHideWorkItem?.cancel()
        autoHideWorkItem = nil
    }

    private func isEligibleForAppearance() -> Bool {
        guard sessionAppearanceCount < maxAppearancesPerSession else { return false }
        guard !isUserTyping, !isSuppressedForCriticalFlow else { return false }
        guard Date().timeIntervalSince(screenAppearedAt) >= minimumDwellBeforeShow else { return false }
        guard !isCriticalScreen(screen) else { return false }
        guard Date().timeIntervalSince1970 >= defaults.double(forKey: DefaultsKey.snoozedUntil) else { return false }

        if Date().timeIntervalSince(lastAppearanceAt) < minimumGapBetweenAppearances {
            return false
        }

        return visiblePresenter() != nil
    }

    private func passiveContext() -> Context {
        return screen == "home" ? .homeIdle : .browsingPause
    }

    private func interactionDelayRespectingCooldown(minimumDelay: TimeInterval) -> TimeInterval {
        let remainingCooldown = minimumGapBetweenAppearances - Date().timeIntervalSince(lastAppearanceAt)
        return max(minimumDelay, remainingCooldown)
    }

    private func isEligibleForManualAppearance() -> Bool {
        guard !isUserTyping, !isSuppressedForCriticalFlow else { return false }
        guard !isCriticalScreen(screen) else { return false }
        return visiblePresenter() != nil
    }

    private func visiblePresenter() -> UIViewController? {
        guard let presenter else { return nil }
        guard presenter.isViewLoaded, presenter.view.window != nil else { return nil }
        if let navigationController = presenter.navigationController,
           navigationController.topViewController !== presenter {
            return nil
        }
        if presenter.presentedViewController != nil { return nil }
        if presenter.navigationController?.presentedViewController != nil { return nil }
        if presenter.tabBarController?.presentedViewController != nil { return nil }
        return presenter
    }

    private func bottomNavigationAnchorView(for presenter: UIViewController, in hostView: UIView) -> UIView? {
        guard screen == "home", let tabController = presenter.tabBarController else { return nil }

        let selector = NSSelectorFromString("pp_novaAmbientBottomNavigationAnchorView")
        if tabController.responds(to: selector),
           let unmanagedAnchor = tabController.perform(selector),
           let anchorView = unmanagedAnchor.takeUnretainedValue() as? UIView,
           anchorView.isDescendant(of: hostView),
           !anchorView.isHidden,
           anchorView.alpha > 0.01 {
            return anchorView
        }

        let systemTabBar = tabController.tabBar
        if systemTabBar.isDescendant(of: hostView),
           !systemTabBar.isHidden,
           systemTabBar.alpha > 0.01 {
            return systemTabBar
        }

        return nil
    }

    private func message(for context: Context) -> String {
        let key: String
        switch context {
        case .homeIdle:
            key = "nova_ambient_home_idle"
        case .searchFocus:
            key = "nova_ambient_search_focus"
        case .browsingPause:
            key = "nova_ambient_browsing"
        case .category:
            key = "nova_ambient_category"
        case .emptyState:
            key = "nova_ambient_empty_state"
        case .shake:
            key = "nova_ambient_shake"
        }
        return NSLocalizedString(key, comment: "")
    }

    private func triggerLightFeedback() {
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.prepare()
        feedback.impactOccurred()
    }

    private func placement(for screen: String) -> Placement {
        return (screen == "search" || screen == "product") ? .upper : .bottom
    }

    private func isCriticalScreen(_ screen: String) -> Bool {
        let value = screen.lowercased()
        return value.contains("checkout")
            || value.contains("payment")
            || value.contains("cart")
            || value.contains("qib")
            || value.contains("order_submit")
    }

    @objc private func reducedMotionDidChange() {
        guard let view = assistantView, view.superview != nil else { return }
        view.prepareForEntrance()
        view.animateIn()
    }
}

@objc(PPNovaMotionWindow)
public final class PPNovaMotionWindow: UIWindow {
    public override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NovaAmbientAssistantCoordinator.shared.userDidShakeDevice()
        }
        super.motionEnded(motion, with: event)
    }
}
