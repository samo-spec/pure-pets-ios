import XCTest
@testable import PPChatCellCore

final class PPChatCellCoreTests: XCTestCase {
    func testConversationIdentityIsStableAcrossRecreatedSnapshots() {
        let first = PPChatThreadSnapshot.fixture(conversationID: "conversation-42")
        let second = PPChatThreadSnapshot.fixture(conversationID: "conversation-42")

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.id.rawValue, "conversation-42")
    }

    func testQuickRepliesAllowDuplicateVisibleTitlesWithoutDuplicateIdentity() {
        let first = PPQuickReply(id: "thanks-short", title: "Thanks", message: "Thanks")
        let second = PPQuickReply(id: "thanks-warm", title: "Thanks", message: "Thank you so much")

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.title, second.title)
    }

    func testEmptyQuickReplyIDUsesDeterministicNonEmptyFallback() {
        let first = PPQuickReply(id: "   ", title: "Thanks", message: "Thank you")
        let second = PPQuickReply(id: "", title: "Thanks", message: "Thank you")

        XCTAssertFalse(first.id.isEmpty)
        XCTAssertEqual(first.id, second.id)
    }

    func testSelectingQuickReplyAfterSuccessReturnsPhaseToIdle() {
        var machine = PPQuickReplyStateMachine(draft: "First")
        _ = machine.beginSend()
        machine.succeed(
            with: PPQuickReplyReceipt(
                messageID: "message-1",
                conversationID: "conversation-1",
                message: "First",
                sentAt: Date(timeIntervalSince1970: 100)
            )
        )

        machine.selectQuickReply(
            PPQuickReply(id: "next", title: "Next", message: "Second")
        )

        XCTAssertEqual(machine.phase, .idle)
        XCTAssertEqual(machine.draft, "Second")
    }

    func testUnreadCountIsClampedToZero() {
        let thread = PPChatThreadSnapshot.fixture(unreadCount: -7)
        XCTAssertEqual(thread.unreadCount, 0)
    }

    func testBeginSendRejectsWhitespaceOnlyDraft() {
        var machine = PPQuickReplyStateMachine(draft: "   \n ")
        XCTAssertNil(machine.beginSend())
        XCTAssertEqual(machine.phase, .idle)
    }

    func testBeginSendCreatesOptimisticOutgoingPreviewAndBlocksDuplicateSend() {
        var machine = PPQuickReplyStateMachine(draft: "  Sending it now  ")

        XCTAssertEqual(machine.beginSend(), "Sending it now")
        XCTAssertEqual(machine.phase, .sending(message: "Sending it now"))
        XCTAssertEqual(machine.optimisticMessage, "Sending it now")
        XCTAssertNil(machine.beginSend())
    }

    func testSuccessfulSendClearsDraftAndCommitsReceipt() {
        var machine = PPQuickReplyStateMachine(draft: "Done")
        _ = machine.beginSend()
        let receipt = PPQuickReplyReceipt(
            messageID: "message-9",
            conversationID: PPConversationID("conversation-42"),
            message: "Done",
            sentAt: Date(timeIntervalSince1970: 100)
        )

        machine.succeed(with: receipt)

        XCTAssertEqual(machine.phase, .sent(receipt: receipt))
        XCTAssertEqual(machine.draft, "")
        XCTAssertEqual(machine.optimisticMessage, "Done")
    }

    func testFailedSendRestoresDraftAndSupportsRetry() {
        var machine = PPQuickReplyStateMachine(draft: "Please retry")
        _ = machine.beginSend()

        machine.fail(.offline)

        XCTAssertEqual(machine.phase, .failed(message: "Please retry", failure: .offline))
        XCTAssertEqual(machine.draft, "Please retry")
        XCTAssertEqual(machine.beginSend(), "Please retry")
    }
}

private extension PPChatThreadSnapshot {
    static func fixture(
        conversationID: String = "conversation-1",
        unreadCount: Int = 0
    ) -> PPChatThreadSnapshot {
        PPChatThreadSnapshot(
            id: PPConversationID(conversationID),
            participantID: "user-1",
            displayName: "Ahmed",
            initials: "AM",
            isVerified: false,
            presence: .online,
            lastActivity: .text(sender: "Ahmed", text: "Hello"),
            timestamp: Date(timeIntervalSince1970: 0),
            unreadCount: unreadCount,
            contextText: nil,
            quickReplies: []
        )
    }
}
