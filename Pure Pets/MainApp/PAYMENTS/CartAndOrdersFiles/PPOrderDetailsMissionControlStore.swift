//
//  PPOrderDetailsMissionControlStore.swift
//  Pure Pets
//

import Combine
import Foundation
import MapKit
import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class PPOrderDetailsMissionControlStore: ObservableObject {
    @Published private(set) var state: PPOrderMissionState = .empty
    @Published var activeSheet: PPOrderMissionSheet?
    @Published var notice: PPOrderMissionNotice? {
        didSet {
            guard let notice else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.presentPPAlert(for: notice)
            }
        }
    }
    @Published private(set) var isCommandRunning = false
    @Published private(set) var addresses: [PPOrderMissionAddress] = []
    @Published private(set) var addressesLoading = false
    @Published private(set) var addressesError = ""
    @Published private(set) var requestEvents: [PPOrderMissionTimelineEvent] = []
    @Published private(set) var requestEventsLoading = false
    @Published private(set) var requestEventsError = ""
    @Published private(set) var languageCode =
        Language.currentLanguageCode() ?? "ar"
    @Published private(set) var isRightToLeft = Language.isRTL()
    @Published private(set) var closeSymbol = "chevron.backward"

    let bridge: PPOrderDetailsMissionControlBridge
    weak var presenter: UIViewController?
    var onClose: (() -> Void)?

    private var hasStarted = false
    private var entryPresentationState = 0
    private var entryPresentationMessage = ""
    private var didPresentEntryState = false
    private var requestEventsRevision = 0
    private var pendingPostDismissAction: (() -> Void)?

    init(bridge: PPOrderDetailsMissionControlBridge) {
        self.bridge = bridge
    }

    deinit {
        bridge.stopRequestEvents()
        bridge.stop()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        bridge.start { [weak self] rawState in
            guard let self else { return }
            Task { @MainActor in
                let nextState = PPOrderMissionState(
                    dictionary: Self.dictionary(rawState)
                )
                if !nextState.isAuthorized && !nextState.isInitialLoading {
                    self.pendingPostDismissAction = nil
                    self.activeSheet = nil
                }
                self.state = nextState
            }
        }
    }

    func setVisible(_ visible: Bool) {
        bridge.setScreenVisible(visible)
    }

    func refresh() {
        bridge.refresh()
        restartActiveRequestEventsIfNeeded()
    }

    func configureEntryPresentation(state: Int, message: String?) {
        guard !didPresentEntryState else { return }
        entryPresentationState = state
        entryPresentationMessage = message?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
    }

    func presentEntryIfNeeded() {
        guard !didPresentEntryState, entryPresentationState != 0 else {
            return
        }
        didPresentEntryState = true
        let isSuccess = entryPresentationState == 1
        let fallback = PPOrderMissionText(
            isSuccess
                ? "order_paid_success_subtitle"
                : "checkout_payment_verification_pending"
        )
        notice = PPOrderMissionNotice(
            title: PPOrderMissionText(isSuccess ? "Success" : "Info"),
            message: entryPresentationMessage.isEmpty
                ? fallback
                : entryPresentationMessage,
            isError: false
        )
        if isSuccess {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        entryPresentationState = 0
        entryPresentationMessage = ""
    }

    func updateLanguage() {
        isRightToLeft = Language.isRTL()
        languageCode = Language.currentLanguageCode() ?? "ar"
        bridge.refresh()
        restartActiveRequestEventsIfNeeded()
    }

    func close() {
        onClose?()
    }

    func setCloseSymbol(_ symbol: String) {
        closeSymbol = symbol
    }

    func copyReference() {
        guard !state.reference.isEmpty else { return }
        UIPasteboard.general.string = state.reference
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        notice = PPOrderMissionNotice(
            title: PPOrderMissionText("order_mission_reference_copied"),
            message: state.reference,
            isError: false
        )
    }

    func share() {
        guard let presenter else { return }
        let text = [
            "\(PPOrderMissionText("OrderID")) #\(state.reference)",
            "\(PPOrderMissionText("order_status")): \(state.statusTitle)",
            "\(PPOrderMissionText("Total")): \(state.totalText)"
        ].joined(separator: "\n")
        let activity = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        if let popover = activity.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 1,
                height: 1
            )
            popover.permittedArrowDirections = []
        }
        presenter.present(activity, animated: true)
    }

    func openMap() {
        guard state.hasCoordinate else {
            notice = PPOrderMissionNotice(
                title: PPOrderMissionText("DeliveryLocation"),
                message: PPOrderMissionText("order_mission_location_unavailable"),
                isError: false
            )
            return
        }
        let latitude = state.latitude
        let longitude = state.longitude
        let label = PPOrderMissionText("DeliveryLocation")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let google = URL(
            string: "comgooglemaps://?q=\(latitude),\(longitude)&zoom=15"
        ), UIApplication.shared.canOpenURL(google) {
            UIApplication.shared.open(google)
            return
        }
        guard let apple = URL(
            string: "https://maps.apple.com/?ll=\(latitude),\(longitude)&q=\(label)"
        ) else { return }
        UIApplication.shared.open(apple)
    }

    func openItem(_ item: PPOrderMissionItem) {
        guard item.canOpen, let presenter else { return }
        isCommandRunning = true
        bridge.openAccessory(
            identifier: item.itemID,
            from: presenter
        ) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.isCommandRunning = false
                if let error {
                    self.present(error: error)
                }
            }
        }
    }

    func handle(_ action: PPOrderMissionAction) {
        guard action.isVisible else { return }
        guard action.isEligible else {
            notice = PPOrderMissionNotice(
                title: action.title,
                message: action.message.isEmpty
                    ? PPOrderMissionText("order_mission_action_unavailable")
                    : action.message,
                isError: false
            )
            return
        }

        switch action.kind {
        case "track":
            activeSheet = .timeline
        case "requests":
            activeSheet = .requests
        case "support":
            activeSheet = .support
        case "cancel":
            presentCancellationConfirmation()
        case "return", "refund", "replacement", "complaint":
            activeSheet = .composer(action)
        default:
            break
        }
    }

    private func presentCancellationConfirmation() {
        guard let presenter else {
            notice = PPOrderMissionNotice(
                title: PPOrderMissionText("order_cancel_title"),
                message: PPOrderMissionText("order_mission_action_unavailable"),
                isError: false
            )
            return
        }

        PPAlertHelper.showConfirmation(
            in: presenter,
            title: PPOrderMissionText("order_cancel_title"),
            subtitle: PPOrderMissionText("order_cancel_confirm"),
            confirmButton: PPOrderMissionText("order_cancel_button"),
            cancelButton: PPOrderMissionText("No"),
            icon: UIImage(systemName: "xmark.circle"),
            confirmBlock: { [weak self] _, didConfirm in
                guard didConfirm else { return }
                Task { @MainActor in
                    self?.confirmCancellation()
                }
            },
            cancelBlock: nil
        )
    }

    func presentRequest(_ request: PPOrderMissionRequest) {
        if activeSheet != nil {
            dismissSheetThen { [weak self] in
                self?.activateRequest(request)
            }
            return
        }
        activateRequest(request)
    }

    private func activateRequest(_ request: PPOrderMissionRequest) {
        requestEvents = []
        requestEventsError = ""
        requestEventsLoading = true
        activeSheet = .request(request)
        startRequestEvents(for: request)
    }

    private func startRequestEvents(for request: PPOrderMissionRequest) {
        requestEventsRevision += 1
        let revision = requestEventsRevision
        bridge.startRequestEvents(
            requestID: request.requestID
        ) { [weak self] rawEvents, error in
            guard let self else { return }
            Task { @MainActor in
                guard revision == self.requestEventsRevision else { return }
                self.requestEventsLoading = false
                self.requestEvents = rawEvents.map {
                    PPOrderMissionTimelineEvent(
                        dictionary: Self.dictionary($0)
                    )
                }
                if let error {
                    NSLog(
                        "[PPOrderMission] request events failed: %@",
                        error.localizedDescription
                    )
                    self.requestEventsError = PPOrderMissionText(
                        "order_mission_request_events_load_error"
                    )
                } else {
                    self.requestEventsError = ""
                }
            }
        }
    }

    func sheetDidDismiss() {
        requestEventsRevision += 1
        bridge.stopRequestEvents()
        requestEvents = []
        requestEventsLoading = false
        requestEventsError = ""
        guard let action = pendingPostDismissAction else { return }
        pendingPostDismissAction = nil
        DispatchQueue.main.async(execute: action)
    }

    func retryRequestEvents() {
        restartActiveRequestEventsIfNeeded()
    }

    func presentSupportComposer() {
        guard let action = state.actions.first(where: { $0.kind == "support" })
        else { return }
        if activeSheet != nil {
            dismissSheetThen { [weak self] in
                self?.activeSheet = .composer(action)
            }
        } else {
            activeSheet = .composer(action)
        }
    }

    func callSupport() {
        guard let presenter else { return }
        dismissSheetThen { [weak self, weak presenter] in
            guard let self, let presenter else { return }
            self.bridge.requestSupportCall(from: presenter)
        }
    }

    func chatWithSupport() {
        guard let presenter else { return }
        dismissSheetThen { [weak self, weak presenter] in
            guard let self, let presenter else { return }
            self.bridge.openSupportChat(from: presenter)
        }
    }

    func confirmCancellation() {
        isCommandRunning = true
        bridge.cancel { [weak self] rawResult, error in
            guard let self else { return }
            Task { @MainActor in
                self.isCommandRunning = false
                if let error {
                    self.present(error: error)
                    return
                }
                let result = Self.dictionary(rawResult)
                let notice = PPOrderMissionNotice(
                    title: result.missionString("title"),
                    message: result.missionString("message"),
                    isError: false
                )
                if !self.presentReturnedRequestIfAvailable(result) {
                    self.notice = notice
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    func reasons(for action: PPOrderMissionAction) -> [PPOrderMissionReason] {
        guard let type = PPOrderCustomerActionType(
            rawValue: action.actionType
        ) else { return [] }
        return bridge.reasonOptions(for: type).map {
            PPOrderMissionReason(dictionary: Self.dictionary($0))
        }
    }

    func submit(
        action: PPOrderMissionAction,
        reason: PPOrderMissionReason?,
        notes: String,
        selectedItemIDs: Set<String>,
        images: [UIImage]
    ) {
        guard let type = PPOrderCustomerActionType(
            rawValue: action.actionType
        ) else {
            notice = PPOrderMissionNotice(
                title: PPOrderMissionText("Error"),
                message: PPOrderMissionText("SomethingWentWrong"),
                isError: true
            )
            return
        }
        let options = reasons(for: action)
        if !options.isEmpty, reason == nil {
            notice = PPOrderMissionNotice(
                title: action.title,
                message: PPOrderMissionText("order_request_select_reason"),
                isError: true
            )
            return
        }
        if reason?.requiresItemSelection == true, selectedItemIDs.isEmpty {
            notice = PPOrderMissionNotice(
                title: action.title,
                message: PPOrderMissionText(
                    "order_request_select_items_error"
                ),
                isError: true
            )
            return
        }
        isCommandRunning = true
        bridge.submit(
            action: type,
            reasonCode: reason?.code ?? "other",
            reasonTitle: reason?.title ?? "",
            notes: notes,
            selectedItemIDs: Array(selectedItemIDs).sorted(),
            images: images
        ) { [weak self] rawResult, error in
            guard let self else { return }
            Task { @MainActor in
                self.isCommandRunning = false
                if let error {
                    self.present(error: error)
                    return
                }
                let result = Self.dictionary(rawResult)
                let notice = PPOrderMissionNotice(
                    title: result.missionString("title"),
                    message: result.missionString("message"),
                    isError: false
                )
                if !self.presentReturnedRequestIfAvailable(result) {
                    self.dismissSheetThen { [weak self] in
                        self?.notice = notice
                    }
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    func presentAddresses() {
        guard state.addressEditable else {
            notice = PPOrderMissionNotice(
                title: PPOrderMissionText("Select Delivery Location"),
                message: state.addressEditMessage,
                isError: false
            )
            return
        }
        activeSheet = .addresses
        addressesLoading = true
        addressesError = ""
        bridge.loadAddresses { [weak self] rawAddresses, error in
            guard let self else { return }
            Task { @MainActor in
                self.addressesLoading = false
                self.addresses = rawAddresses.map {
                    PPOrderMissionAddress(dictionary: Self.dictionary($0))
                }
                if let error {
                    NSLog(
                        "[PPOrderMission] addresses failed: %@",
                        error.localizedDescription
                    )
                    self.addressesError = PPOrderMissionText(
                        "order_mission_addresses_load_error"
                    )
                } else {
                    self.addressesError = ""
                }
            }
        }
    }

    func selectAddress(_ address: PPOrderMissionAddress) {
        guard address.isSelectable else {
            notice = PPOrderMissionNotice(
                title: PPOrderMissionText("Select Delivery Location"),
                message: address.availabilityMessage.isEmpty
                    ? PPOrderMissionText("order_mission_address_not_selectable")
                    : address.availabilityMessage,
                isError: false
            )
            return
        }
        isCommandRunning = true
        bridge.selectAddress(
            identifier: address.id
        ) { [weak self] rawResult, error in
            guard let self else { return }
            Task { @MainActor in
                self.isCommandRunning = false
                if let error {
                    self.present(error: error)
                    return
                }
                let result = Self.dictionary(rawResult)
                let notice = PPOrderMissionNotice(
                    title: result.missionString("title"),
                    message: result.missionString("message"),
                    isError: false
                )
                self.dismissSheetThen { [weak self] in
                    self?.notice = notice
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    func addAddress() {
        guard let presenter else { return }
        dismissSheetThen { [weak self, weak presenter] in
            guard let self, let presenter else { return }
            self.bridge.openAddressEditor(from: presenter)
        }
    }

    private func present(error: Error) {
        let underlying = error as NSError
        NSLog(
            "[PPOrderMission] command failed domain=%@ code=%ld: %@",
            underlying.domain,
            underlying.code,
            underlying.localizedDescription
        )
        let localizedMessage = underlying.localizedDescription.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let message = underlying.domain == "com.purepets.order-mission-control"
            ? localizedMessage
            : PPOrderMissionText("SomethingWentWrong")
        notice = PPOrderMissionNotice(
            title: PPOrderMissionText("Error"),
            message: message.isEmpty
                ? PPOrderMissionText("SomethingWentWrong")
                : message,
            isError: true
        )
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func restartActiveRequestEventsIfNeeded() {
        guard let activeSheet,
              case let .request(request) = activeSheet else { return }
        requestEvents = []
        requestEventsError = ""
        requestEventsLoading = true
        startRequestEvents(for: request)
    }

    private func dismissSheetThen(_ action: @escaping () -> Void) {
        guard activeSheet != nil else {
            action()
            return
        }
        pendingPostDismissAction = action
        activeSheet = nil
    }

    @discardableResult
    private func presentReturnedRequestIfAvailable(
        _ result: [AnyHashable: Any]
    ) -> Bool {
        let dictionary = result.missionDictionary("request")
        let request = PPOrderMissionRequest(dictionary: dictionary)
        guard !request.requestID.isEmpty else { return false }
        presentRequest(request)
        return true
    }

    private func presentPPAlert(for notice: PPOrderMissionNotice) {
        let vc = self.presenter ?? AppManager.sharedInstance().topViewController()
        if notice.isError {
            PPAlertHelper.showFail(
                in: vc,
                title: notice.title,
                subtitle: notice.message.isEmpty ? nil : notice.message,
                completion: nil
            )
        } else {
            PPAlertHelper.showInfo(
                in: vc,
                title: notice.title,
                subtitle: notice.message.isEmpty ? nil : notice.message
            )
        }
    }

    nonisolated private static func dictionary(
        _ value: Any?
    ) -> [AnyHashable: Any] {
        if let value = value as? [AnyHashable: Any] { return value }
        guard let value = value as? NSDictionary else { return [:] }
        var result: [AnyHashable: Any] = [:]
        value.forEach { key, entry in
            if let key = key as? AnyHashable {
                result[key] = entry
            }
        }
        return result
    }
}
