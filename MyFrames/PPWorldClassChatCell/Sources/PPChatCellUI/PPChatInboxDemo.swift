#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import PPChatCellCore

private enum PPChatDemoRoute: Hashable {
    case conversation(PPConversationID)
}

@MainActor
public struct PPChatInboxDemo: View {
    @State private var path: [PPChatDemoRoute] = []
    @State private var expandedConversationID: PPConversationID?
    @State private var threads: [PPChatThreadSnapshot]

    public init() {
        _threads = State(initialValue: PPChatThreadSnapshot.previewSamples)
    }

    public var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(threads) { thread in
                        PPExpandableChatCell(
                            thread: thread,
                            isExpanded: expansionBinding(for: thread.id),
                            onOpenChat: { conversationID in
                                path.append(.conversation(conversationID))
                            },
                            onOptimisticReply: { _, _ in
                                // The cell renders the pending reply immediately.
                                // Your production store can enqueue an outbox event here.
                            },
                            onReplyCommitted: applyCommittedReply,
                            onReplyFailed: { _, _ in
                                // Product analytics or retry queue hook.
                            },
                            sendQuickReply: Self.simulateSend
                        )
                    }
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Chats")
            .navigationDestination(for: PPChatDemoRoute.self) { route in
                switch route {
                case let .conversation(conversationID):
                    if let thread = threads.first(where: { $0.id == conversationID }) {
                        PPChatDemoConversationView(thread: thread)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                                .font(.largeTitle)
                            Text("Conversation unavailable")
                                .font(Font.ppBeirutiSemiBold(size: 16, relativeTo: .headline))
                        }
                        .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
    }

    private func expansionBinding(for id: PPConversationID) -> Binding<Bool> {
        Binding(
            get: { expandedConversationID == id },
            set: { expanded in
                expandedConversationID = expanded ? id : nil
            }
        )
    }

    private func applyCommittedReply(_ receipt: PPQuickReplyReceipt) {
        guard let index = threads.firstIndex(where: { $0.id == receipt.conversationID }) else {
            return
        }

        threads[index].lastActivity = .text(sender: "You", text: receipt.message)
        threads[index].timestamp = receipt.sentAt
        threads[index].setUnreadCount(0)
    }

    private static func simulateSend(
        message: String,
        conversationID: PPConversationID
    ) async throws -> PPQuickReplyReceipt {
        try await Task.sleep(nanoseconds: 650_000_000)
        return PPQuickReplyReceipt(
            messageID: UUID().uuidString,
            conversationID: conversationID,
            message: message,
            sentAt: Date()
        )
    }
}

private struct PPChatDemoConversationView: View {
    let thread: PPChatThreadSnapshot

    var body: some View {
        VStack(spacing: 14) {
            Text(thread.initials)
                .font(Font.ppBeirutiSemiBold(size: 22, relativeTo: .title2))
                .foregroundStyle(PPChatCellStyle.purePets.brand)
                .frame(width: 72, height: 72)
                .background {
                    Circle().fill(PPChatCellStyle.purePets.brand.opacity(0.10))
                }

            Text(thread.displayName)
                .font(Font.ppBeirutiSemiBold(size: 19, relativeTo: .title3))

            Text("Replace this demo destination with your production MessagingController route.")
                .font(Font.ppBeirutiRegular(size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .accessibilityIdentifier("pp.chat.messaging.\(thread.id.rawValue)")
        .navigationTitle(thread.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension PPChatThreadSnapshot {
    static let previewSamples: [PPChatThreadSnapshot] = [
        PPChatThreadSnapshot(
            id: "conversation-ahmed-invoice",
            participantID: "user-ahmed",
            displayName: "Ahmed Mohamed",
            initials: "AM",
            isVerified: true,
            presence: .online,
            lastActivity: .text(
                sender: "Ahmed",
                text: "Can you send the updated invoice before delivery?"
            ),
            timestamp: Date().addingTimeInterval(-140),
            unreadCount: 2,
            contextText: "Customer is waiting for the final invoice before delivery.",
            quickReplies: [
                PPQuickReply(id: "send-now", title: "Sending it now", message: "Sending it now"),
                PPQuickReply(id: "check", title: "I’ll check", message: "I’ll check and update you"),
                PPQuickReply(id: "call", title: "Call you?", message: "Can I call you?")
            ]
        ),
        PPChatThreadSnapshot(
            id: "conversation-sarah-order",
            participantID: "user-sarah",
            displayName: "Sarah Khaled",
            initials: "SK",
            presence: .online,
            lastActivity: .typing,
            timestamp: Date(),
            contextText: "Order confirmation and delivery timing.",
            quickReplies: [
                PPQuickReply(id: "perfect", title: "Perfect", message: "Perfect, thank you"),
                PPQuickReply(id: "time-works", title: "Time works", message: "The delivery time works for me")
            ]
        ),
        PPChatThreadSnapshot(
            id: "conversation-omar-confirmed",
            participantID: "user-omar",
            displayName: "Omar Hassan",
            initials: "OH",
            presence: .offline(lastSeen: Date().addingTimeInterval(-86_400)),
            lastActivity: .text(sender: "You", text: "Great, the order is confirmed."),
            timestamp: Date().addingTimeInterval(-86_400),
            contextText: "No action needed. Order confirmed successfully.",
            quickReplies: [
                PPQuickReply(id: "welcome", title: "You’re welcome", message: "You’re welcome"),
                PPQuickReply(id: "anything-else", title: "Anything else?", message: "Let me know if you need anything else")
            ]
        ),
        PPChatThreadSnapshot(
            id: "conversation-mona-voice",
            participantID: "user-mona",
            displayName: "Mona Ali",
            initials: "MA",
            presence: .away,
            lastActivity: .voice(sender: "Mona", duration: 18),
            timestamp: Date().addingTimeInterval(-172_800),
            unreadCount: 1,
            quickReplies: [
                PPQuickReply(id: "listen-now", title: "I’ll listen now", message: "I’ll listen now"),
                PPQuickReply(id: "thanks", title: "Thanks", message: "Thanks")
            ]
        )
    ]
}
#endif
