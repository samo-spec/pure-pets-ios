//
//  PPNotificationsInboxStore.swift
//  Pure Pets
//
//  Data owner for the SwiftUI notifications inbox. Replaces the Firestore /
//  routing half of the legacy `PPNotificationsInboxViewController`.
//
//  Read path: UsersCol/{uid}/inbox ordered by createdAt desc, limit 50, live
//  snapshot listener. Provider/driver-only payloads are filtered out client
//  side so the consumer inbox never shows Pro traffic.
//

import Foundation
import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class PPNotificationsInboxStore: ObservableObject {

    // MARK: Published state

    @Published private(set) var items: [PPNotificationInboxItem] = []
    @Published private(set) var state: PPNotificationsInboxState = .loading

    /// Set by the hosting controller so chat / order routing keeps using the
    /// real navigation stack instead of a SwiftUI-owned one.
    weak var hostViewController: UIViewController?

    // MARK: Private state

    private var inboxListener: ListenerRegistration?
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    private var notificationTokens: [NSObjectProtocol] = []
    private var loadGeneration: Int = 0
    private var observedUID: String = ""
    private var rawPayloads: [(documentID: String, payload: [String: Any], isRead: Bool)] = []
    private var refreshContinuations: [CheckedContinuation<Void, Never>] = []
    private var hasActivated = false

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = PPHubLocale
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM h:mm a")
        return formatter
    }()

    // MARK: Lifecycle

    /// Deferred until the inbox surface is first shown. The legacy screen wired
    /// its observers and first read inside the child controller's `viewDidLoad`,
    /// which only ran when the Notifications tab was opened — starting the
    /// Firestore listener at hub construction time would add reads at launch.
    func activate() {
        guard !hasActivated else { return }
        hasActivated = true
        registerObservers()
        reloadNotifications()
    }

    deinit {
        inboxListener?.remove()
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func registerObservers() {
        let center = NotificationCenter.default
        let refreshNames: [Notification.Name] = [
            UIApplication.didBecomeActiveNotification,
            Notification.Name("PPRemoteNotificationTapped")
        ]
        for name in refreshNames {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reloadNotifications() }
            }
            notificationTokens.append(token)
        }

        // `PPLanguageDidChangeNotification` is a header-level C constant and is
        // therefore invisible to Swift; its literal value is used directly.
        let languageNames: [Notification.Name] = [
            Notification.Name("LanguageDidChangeNotification"),
            Notification.Name("PPLanguageDidChangeNotification")
        ]
        for name in languageNames {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.handleLanguageChange() }
            }
            notificationTokens.append(token)
        }

        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            MainActor.assumeIsolated { self?.reloadNotifications() }
        }
    }

    // MARK: Formatting

    func metaText(for item: PPNotificationInboxItem) -> String {
        var dateText = ""
        if let timestamp = item.timestamp {
            dateText = dateFormatter.string(from: timestamp)
        }
        if !dateText.isEmpty, !item.categoryTitle.isEmpty {
            return "\(item.categoryTitle) • \(dateText)"
        }
        return item.categoryTitle.isEmpty ? dateText : item.categoryTitle
    }

    // MARK: Language

    private func handleLanguageChange() {
        dateFormatter.locale = PPHubLocale
        dateFormatter.setLocalizedDateFormatFromTemplate("EEE d MMM h:mm a")
        // The legacy screen only redrew the cached strings, which left rows in
        // the previous language until the next snapshot. Re-deriving them from
        // the retained payloads keeps the inbox fully bilingual on the spot.
        items = mapItems(from: rawPayloads)
        render(state)
    }

    // MARK: Load

    func refresh() async {
        await withCheckedContinuation { continuation in
            refreshContinuations.append(continuation)
            reloadNotifications()
        }
    }

    private func finishRefresh() {
        let pending = refreshContinuations
        refreshContinuations.removeAll()
        pending.forEach { $0.resume() }
    }

    func reloadNotifications() {
        inboxListener?.remove()
        inboxListener = nil

        let uid = PPHubPayload.trimmed(Auth.auth().currentUser?.uid)
        if observedUID != uid {
            observedUID = uid
            rawPayloads = []
            items = []
        }

        loadGeneration += 1
        let generation = loadGeneration

        if items.isEmpty {
            render(.loading)
        }

        if uid.isEmpty {
            finishRefresh()
            render(.empty)
            return
        }

        let query = Firestore.firestore()
            .collection("UsersCol")
            .document(uid)
            .collection("inbox")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)

        inboxListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            MainActor.assumeIsolated {
                guard generation == self.loadGeneration else { return }

                if let error {
                    self.handleLoadFailure(error)
                    return
                }

                self.apply(documents: snapshot?.documents ?? [])
            }
        }
    }

    private func handleLoadFailure(_ error: Error) {
        let nsError = error as NSError
        print("[NotificationsInbox] Read failed | domain=\(nsError.domain) code=\(nsError.code)")

        finishRefresh()
        if items.isEmpty {
            render(.error)
        } else {
            render(.content)
            PPHUD.showInfo(PPHubText("load_error_title"))
        }
    }

    private func apply(documents: [QueryDocumentSnapshot]) {
        var payloads: [(documentID: String, payload: [String: Any], isRead: Bool)] = []
        for document in documents {
            let payload = document.data()
            if PPHubPayload.isProviderOnlyNotification(payload) { continue }
            let isRead = PPHubPayload.boolean(payload["isRead"]) || PPHubPayload.boolean(payload["read"])
            payloads.append((documentID: document.documentID, payload: payload, isRead: isRead))
        }

        rawPayloads = payloads
        items = mapItems(from: payloads)
        finishRefresh()
        render(items.isEmpty ? .empty : .content)
    }

    private func mapItems(
        from payloads: [(documentID: String, payload: [String: Any], isRead: Bool)]
    ) -> [PPNotificationInboxItem] {
        payloads
            .map { entry in
                let payload = entry.payload
                let rawTitle = PPHubPayload.trimmed(payload["title"])
                let rawBody = PPHubPayload.trimmed(payload["body"])

                var title = PPHubPayload.localizedTitle(
                    rawTitle: rawTitle,
                    rawBody: rawBody,
                    payload: payload
                )
                if title.isEmpty {
                    title = PPHubPayload.categoryTitle(for: payload)
                }

                var subtitle = PPHubPayload.localizedBody(
                    rawBody: rawBody,
                    rawTitle: rawTitle,
                    payload: payload
                )
                if subtitle.isEmpty {
                    subtitle = PPHubPayload.trimmed(payload["message"] ?? payload["status"])
                }

                let identifier = PPHubPayload.trimmed(payload["notificationId"])
                let documentID = PPHubPayload.trimmed(entry.documentID)

                return PPNotificationInboxItem(
                    id: identifier.isEmpty ? documentID : identifier,
                    documentID: documentID,
                    title: title,
                    subtitle: subtitle,
                    categoryTitle: PPHubPayload.categoryTitle(for: payload),
                    symbolName: PPHubPayload.symbolName(for: payload),
                    accentColor: PPHubPayload.accentColor(for: payload),
                    timestamp: PPHubPayload.date(
                        from: payload["createdAt"] ?? payload["occurredAt"] ?? payload["updatedAt"]
                    ),
                    payload: payload,
                    isRead: entry.isRead
                )
            }
            .sorted { lhs, rhs in
                let first = lhs.timestamp ?? .distantPast
                let second = rhs.timestamp ?? .distantPast
                return first > second
            }
    }

    private func render(_ next: PPNotificationsInboxState) {
        state = next
    }

    // MARK: Read acknowledgement

    private func markItemReadIfNeeded(_ item: PPNotificationInboxItem) {
        guard !item.isRead, !item.documentID.isEmpty else { return }

        let uid = PPHubPayload.trimmed(Auth.auth().currentUser?.uid)
        guard !uid.isEmpty else { return }

        let inboxRef = Firestore.firestore()
            .collection("UsersCol")
            .document(uid)
            .collection("inbox")
            .document(item.documentID)

        let documentID = item.documentID
        inboxRef.updateData(["isRead": true]) { [weak self] error in
            guard let self else { return }
            MainActor.assumeIsolated {
                if let error {
                    let nsError = error as NSError
                    print("[NotificationsInbox] Read acknowledgement failed | domain=\(nsError.domain) code=\(nsError.code)")
                    return
                }
                self.applyLocalReadState(documentID: documentID)
            }
        }
    }

    private func applyLocalReadState(documentID: String) {
        if let index = rawPayloads.firstIndex(where: { $0.documentID == documentID }) {
            rawPayloads[index].isRead = true
        }
        if let index = items.firstIndex(where: { $0.documentID == documentID }) {
            items[index].isRead = true
        }
    }

    // MARK: Selection

    func select(_ item: PPNotificationInboxItem) {
        markItemReadIfNeeded(item)

        let payload = item.payload
        let meta = PPHubPayload.safeDictionary(payload["meta"])
        let threadID = PPHubPayload.threadID(from: payload)
        let orderID = PPHubPayload.orderID(from: payload)
        let type = PPHubPayload.notificationType(payload, meta)

        print("PPLAB NotificationsHub select start | type=\(type) orderId=\(orderID) threadID=\(threadID)")

        if !threadID.isEmpty || type == "chat" {
            guard let host = hostViewController else { return }
            ChNotificationRouter.shared().handleChatNotification(payload, from: host)
            return
        }

        if orderID.isEmpty, !type.hasPrefix("order") {
            return
        }

        if orderID.isEmpty {
            PPHUD.showInfo(PPHubText("notifications_inbox_empty_subtitle"))
            return
        }

        let orderRef = Firestore.firestore().collection("Orders").document(orderID)
        orderRef.getDocument { [weak self] snapshot, error in
            guard let self else { return }
            MainActor.assumeIsolated {
                guard error == nil, let snapshot, snapshot.exists else {
                    PPHUD.showError(PPHubText("order_support_unavailable_no_order"))
                    return
                }

                let order: PPOrder? = PPOrder(from: snapshot)
                guard let order else {
                    PPHUD.showError(PPHubText("order_support_unavailable_no_order"))
                    return
                }

                let detailsVC = PPOrderDetailsRouter.controller(with: order)
                self.hostViewController?.navigationController?.pushViewController(detailsVC, animated: true)
            }
        }
    }
}
