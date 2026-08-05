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

// MARK: - Bridge

/// Bridges the SwiftUI `PPExpandableChatCell` into a UIKit `UITableViewCell`
/// using `UIHostingConfiguration` (iOS 16+). Callable from Objective-C.
@objcMembers
@MainActor
final class PPChatCellBridge: NSObject {

    // MARK: - Reuse Identity

    static let reuseID = "PPChatCellBridge"

    // MARK: - Expansion State

    /// Which conversation (if any) is currently expanded.
    /// Only one at a time — matches `MIGRATION_FROM_CHCELL.md` contract.
    private(set) var expandedConversationID: String?

    /// Collapse any expanded row.
    func collapseExpanded() {
        expandedConversationID = nil
    }

    /// Whether a given conversation is the expanded one.
    func isExpanded(_ conversationID: String) -> Bool {
        expandedConversationID == conversationID
    }

    // MARK: - Cell Configuration

    /// Applies `UIHostingConfiguration` containing `PPExpandableChatCell`
    /// to the provided table view cell.
    ///
    /// - Parameters:
    ///   - cell: The dequeued `UITableViewCell`.
    ///   - thread: The ObjC `ChatThreadModel`.
    ///   - onOpenChat: Called when the user taps the conversation surface.
    ///   - onPresenceRefresh: Optional closure the caller provides so the
    ///     bridge can re-query presence at configure time.
    func configureCell(
        _ cell: UITableViewCell,
        with thread: ChatThreadModel,
        onOpenChat: @escaping (ChatThreadModel) -> Void
    ) {
        let snapshot = Self.makeSnapshot(from: thread)
        let threadID = snapshot.id.rawValue

        // Expansion binding: read/write expandedConversationID
        let expansionBinding = Binding<Bool>(
            get: { [weak self] in
                self?.expandedConversationID == threadID
            },
            set: { [weak self] newValue in
                self?.expandedConversationID = newValue ? threadID : nil
            }
        )

        cell.contentConfiguration = UIHostingConfiguration {
            PPExpandableChatCell(
                thread: snapshot,
                isExpanded: expansionBinding,
                onOpenChat: { _ in
                    onOpenChat(thread)
                },
                onOptimisticReply: { message, conversationID in
                    // Optimistic: the cell shows the message instantly.
                    // No external action needed for now.
                },
                onReplyCommitted: { receipt in
                    // The send succeeded — the cell already updated.
                },
                onReplyFailed: { failure, conversationID in
                    // The cell shows inline error + retry.
                },
                sendQuickReply: { [weak self] message, conversationID in
                    try await Self.sendQuickReplyBridge(
                        message: message,
                        conversationID: conversationID
                    )
                }
            )
        }
        .margins(.all, 0)
        .minSize(width: 0, height: 76)

        cell.backgroundColor = .clear
        cell.selectionStyle = .none
    }

    // MARK: - Snapshot Mapping

    /// Maps `ChatThreadModel` + `UserModel` + `ChatPresenceManager` → `PPChatThreadSnapshot`.
    static func makeSnapshot(from thread: ChatThreadModel) -> PPChatThreadSnapshot {
        let user = ChatThreadModel.resolveOtherUser(fromThread: thread) ?? thread.otherUser
        let conversationID = PPConversationID(thread.id ?? "")

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
            let lastMsg = thread.lastMessage ?? ""
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
        let timestamp: Date = thread.lastMessageAt ?? thread.timestamp ?? Date.distantPast

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
        conversationID: PPConversationID
    ) async throws -> PPQuickReplyReceipt {
        return try await withCheckedThrowingContinuation { continuation in
            let threadID = conversationID.rawValue

            let msg = ChatMessageModel()
            msg.text = message
            msg.messageType = .text
            msg.timestamp = Date()
            msg.id = UUID().uuidString

            let senderID = UserManager.shared().currentUser?.id ?? ""

            msg.senderID = senderID

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
