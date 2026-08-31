//
//  PPChatCellBridge.swift
//  Pure Pets
//
//  UIKit ↔ SwiftUI bridge: hosts PPExpandableChatCell inside
//  UITableViewCell via UIHostingConfiguration.
//
//  Migration owner: this is the SOLE bridge from the ObjC
//  UserChatsViewController to the SwiftUI PPWorldClassChatCell package.
//  The legacy ChCell.h/.m is archived in _ArchivedLegacyIOSAPP/ChCells/.
//
//  Created on 2026-08-05.
//

import UIKit
import SwiftUI
import PPChatCellCore
import PPChatCellUI

// MARK: - SwiftUI Host State

@MainActor
private final class PPChatCellExpansionStore: ObservableObject {
    @Published var expandedConversationID: String?
}

@MainActor
private final class PPChatCellContentStore: ObservableObject {
    @Published private(set) var thread: PPChatThreadSnapshot
    private(set) var sourceThread: ChatThreadModel

    init(thread: PPChatThreadSnapshot, sourceThread: ChatThreadModel) {
        self.thread = thread
        self.sourceThread = sourceThread
    }

    func apply(_ nextThread: PPChatThreadSnapshot, sourceThread: ChatThreadModel) {
        self.sourceThread = sourceThread
        guard thread != nextThread else { return }
        thread = nextThread
    }
}

@MainActor
private struct PPChatCellHost: View {
    @ObservedObject var contentStore: PPChatCellContentStore
    let style: PPChatCellStyle
    let copy: PPChatCellCopy
    let timestampFormatter: PPChatTimestampFormatter
    @ObservedObject var expansionStore: PPChatCellExpansionStore
    let onOpenChat: () -> Void
    let sendQuickReply: PPExpandableChatCell.SendReplyAction

    var body: some View {
        let thread = contentStore.thread

        PPExpandableChatCell(
            thread: thread,
            isExpanded: Binding(
                get: { expansionStore.expandedConversationID == thread.id.rawValue },
                set: { expanded in
                    expansionStore.expandedConversationID = expanded ? thread.id.rawValue : nil
                }
            ),
            style: style,
            copy: copy,
            timestampFormatter: timestampFormatter,
            onOpenChat: { _ in onOpenChat() },
            onOptimisticReply: { _, _ in },
            onReplyCommitted: { _ in },
            onReplyFailed: { _, _ in },
            sendQuickReply: sendQuickReply,
            animationsEnabled: true,
            entranceEnabled: false
        )
    }
}

// MARK: - Bridge

/// Bridges the SwiftUI `PPExpandableChatCell` into a UIKit `UITableViewCell`
/// using `UIHostingConfiguration` (iOS 16+). Callable from Objective-C.
@objcMembers
@MainActor
final class PPChatCellBridge: NSObject {

    // MARK: - Reuse Identity

    static let reuseID = "PPChatCellBridge"

    // MARK: - Expansion State

    private let expansionStore = PPChatCellExpansionStore()
    private var contentStores: [String: PPChatCellContentStore] = [:]

    /// Which conversation (if any) is currently expanded.
    /// Only one at a time — matches `MIGRATION_FROM_CHCELL.md` contract.
    var expandedConversationID: String? {
        expansionStore.expandedConversationID
    }

    /// Collapse any expanded row.
    func collapseExpanded() {
        expansionStore.expandedConversationID = nil
    }

    /// Whether a given conversation is the expanded one.
    func isExpanded(_ conversationID: String) -> Bool {
        expansionStore.expandedConversationID == conversationID
    }

    // MARK: - Hosted Content State

    /// Publishes fresh thread snapshots into existing SwiftUI hosts without
    /// replacing their UIHostingConfiguration or resetting their local state.
    @objc(syncHostedContentWithThreads:)
    func syncHostedContent(with threads: [ChatThreadModel]) {
        var activeConversationIDs = Set<String>()

        for thread in threads {
            let snapshot = Self.makeSnapshot(from: thread)
            let conversationID = snapshot.id.rawValue
            activeConversationIDs.insert(conversationID)
            contentStores[conversationID]?.apply(snapshot, sourceThread: thread)
        }

        contentStores = contentStores.filter {
            activeConversationIDs.contains($0.key)
        }
    }

    /// Updates one existing host in place, if that conversation is currently
    /// materialized. Offscreen rows receive the latest snapshot when dequeued.
    @objc(updateHostedContentWithThread:)
    func updateHostedContent(with thread: ChatThreadModel) {
        let snapshot = Self.makeSnapshot(from: thread)
        contentStores[snapshot.id.rawValue]?.apply(snapshot, sourceThread: thread)
    }

    // MARK: - Cell Configuration

    /// Applies `UIHostingConfiguration` containing `PPExpandableChatCell`
    /// to the provided table view cell.
    ///
    /// - Parameters:
    ///   - cell: The dequeued `UITableViewCell`.
    ///   - thread: The ObjC `ChatThreadModel`.
    ///   - onOpenChat: Called when the user taps the conversation surface.
    func configureCell(
        _ cell: UITableViewCell,
        with thread: ChatThreadModel,
        onOpenChat: @escaping (ChatThreadModel) -> Void
    ) {
        let snapshot = Self.makeSnapshot(from: thread)
        let conversationID = snapshot.id.rawValue
        let contentStore: PPChatCellContentStore
        if let existingStore = contentStores[conversationID] {
            existingStore.apply(snapshot, sourceThread: thread)
            contentStore = existingStore
        } else {
            let newStore = PPChatCellContentStore(
                thread: snapshot,
                sourceThread: thread
            )
            contentStores[conversationID] = newStore
            contentStore = newStore
        }
        let languageCode = Language.currentLanguageCode() ?? "en"
        let locale = Locale(identifier: languageCode)

        let rootView = PPChatCellHost(
            contentStore: contentStore,
            style: Self.liveStyle,
            copy: .localized(languageCode: languageCode),
            timestampFormatter: PPChatTimestampFormatter(locale: locale),
            expansionStore: expansionStore,
            onOpenChat: { onOpenChat(contentStore.sourceThread) },
            sendQuickReply: { message, conversationID in
                try await Self.sendQuickReplyBridge(
                    message: message,
                    conversationID: conversationID,
                    receiverID: snapshot.participantID
                )
            }
        )
        // Keep SwiftUI state scoped to one immutable conversation ID even
        // when UIKit reconfigures a reusable hosting cell.
        .id(conversationID)
        .environment(\.locale, locale)
        .environment(
            \.layoutDirection,
            languageCode == "ar" ? .rightToLeft : .leftToRight
        )

        if #available(iOS 16.0, *) {
            cell.contentConfiguration = UIHostingConfiguration {
                rootView
            }
            .margins(.all, 0)
            .minSize(width: 0, height: 76)
        } else {
            let hostingTag = 948271
            if let hostingView = cell.contentView.viewWithTag(hostingTag) {
                hostingView.removeFromSuperview()
            }
            let host = UIHostingController(rootView: rootView)
            host.view.tag = hostingTag
            host.view.backgroundColor = .clear
            host.view.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                host.view.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
                host.view.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor)
            ])
        }

        cell.backgroundColor = .clear
        cell.selectionStyle = .none
    }

    /// Resolve the live app color asset so light/dark brand behavior stays
    /// aligned with Pure Pets instead of freezing the package preview color.
    private static var liveStyle: PPChatCellStyle {
        let fallback = UIColor { traits in
            traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 155 / 255, blue: 150 / 255, alpha: 1)
            : UIColor(red: 203 / 255, green: 38 / 255, blue: 84 / 255, alpha: 1)
        }
        let brand = UIColor(named: "AppPrimaryColor") ?? fallback
        return PPChatCellStyle(brand: Color(uiColor: brand))
    }

    // MARK: - Snapshot Mapping

    /// Maps `ChatThreadModel` + `UserModel` + `ChatPresenceManager` → `PPChatThreadSnapshot`.
    static func makeSnapshot(from thread: ChatThreadModel) -> PPChatThreadSnapshot {
        let user = ChatThreadModel.resolveOtherUser(fromThread: thread) ?? thread.otherUser
        let conversationID = PPConversationID(thread.id)

        // Display name
        let displayName: String = {
            if let best = user?.ppBestDisplayName(), !best.isEmpty { return best }
            if let userName = user?.userName, !userName.isEmpty { return userName }
            return ""
        }()

        // Avatar URL
        let avatarURL: URL? = user?.userImageUrl

        // Verified
        let isVerified = user?.isVerified ?? false

        // Presence
        let presence: PPChatPresence = {
            let userID = user?.id ?? ""
            guard !userID.isEmpty else {
                return .offline(lastSeen: nil)
            }
            let online = ChatPresenceManager.shared().isUserOnline(userID)
            if online {
                return .online
            }
            let lastSeen = ChatPresenceManager.shared().lastSeen(forUser: userID)
            return .offline(lastSeen: lastSeen)
        }()

        // Last activity
        let lastActivity: PPChatLastActivity = {
            let lastMsg = thread.lastMessage
            guard !lastMsg.isEmpty else {
                return .none
            }
            if lastMsg == "__pp_message_unsent__" {
                return .deleted
            }
            let cleaned = lastMsg
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .text(sender: nil, text: cleaned.isEmpty ? "" : cleaned)
        }()

        // Timestamp
        let timestamp: Date = {
            let lastAt = thread.lastMessageAt
            if lastAt != Date.distantPast {
                return lastAt
            }
            let ts = thread.timestamp
            if ts != Date.distantPast {
                return ts
            }
            return Date()
        }()

        return PPChatThreadSnapshot(
            id: conversationID,
            participantID: user?.id ?? "",
            displayName: displayName,
            avatarURL: avatarURL,
            isVerified: isVerified,
            presence: presence,
            lastActivity: lastActivity,
            timestamp: timestamp,
            unreadCount: max(0, thread.unreadCount)
        )
    }

    // MARK: - Quick Reply Bridge

    /// Bridges quick-reply sends through `ChManager` by constructing a
    /// `ChatMessageModel` with the typed text and sending it through the
    /// existing messaging pipeline.
    private static func sendQuickReplyBridge(
        message: String,
        conversationID: PPConversationID,
        receiverID: String
    ) async throws -> PPQuickReplyReceipt {
        return try await withCheckedThrowingContinuation { continuation in
            let threadID = conversationID.rawValue
            let resolvedReceiverID = receiverID
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let msg = ChatMessageModel()
            msg.text = message
            msg.messageType = .text
            msg.timestamp = Date()
            msg.id = UUID().uuidString

            let senderID = UserManager.shared().currentUser?.id ?? ""

            msg.senderID = senderID
            msg.receiverID = resolvedReceiverID

            guard !threadID.isEmpty,
                  !senderID.isEmpty,
                  !resolvedReceiverID.isEmpty,
                  senderID != resolvedReceiverID else {
                continuation.resume(throwing: PPQuickReplyFailure.unknown)
                return
            }

            ChManager.shared().sendMessage(
                msg,
                inThread: threadID,
                senderID: senderID
            ) { error in
                if let _ = error {
                    continuation.resume(throwing: PPQuickReplyFailure.server)
                    return
                }
                let msgID = msg.id.isEmpty ? UUID().uuidString : msg.id
                let receipt = PPQuickReplyReceipt(
                    messageID: msgID,
                    conversationID: conversationID,
                    message: message,
                    sentAt: Date()
                )
                continuation.resume(returning: receipt)
            }
        }
    }
}
