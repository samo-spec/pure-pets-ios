#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import PPChatCellCore

struct PPExpandableChatCell_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PPChatInboxDemo()
                .previewDisplayName("Inbox · Light")

            PPChatInboxDemo()
                .preferredColorScheme(.dark)
                .previewDisplayName("Inbox · Dark")

            PPChatCellPreviewHarness(
                thread: arabicThread,
                initiallyExpanded: true,
                copy: .localized(languageCode: "ar"),
                timestampFormatter: PPChatTimestampFormatter(
                    locale: Locale(identifier: "ar_EG"),
                    timeZone: TimeZone(identifier: "Africa/Cairo") ?? .autoupdatingCurrent
                )
            )
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar_EG"))
            .previewDisplayName("Arabic · RTL")

            PPChatCellPreviewHarness(
                thread: PPChatThreadSnapshot.previewSamples[0],
                initiallyExpanded: true
            )
            .environment(\.dynamicTypeSize, .accessibility3)
            .previewDisplayName("Accessibility Type")

            PPChatCellPreviewHarness(
                thread: PPChatThreadSnapshot.previewSamples[0],
                initiallyExpanded: true
            )
            // Accessibility Preferences overrides are read-only in this SwiftUI version.
            .previewDisplayName("Accessibility Preferences")
        }
    }

    private static let arabicThread = PPChatThreadSnapshot(
        id: "conversation-arabic-invoice",
        participantID: "user-arabic",
        displayName: "أحمد محمد",
        initials: "أم",
        isVerified: true,
        presence: .online,
        lastActivity: .text(sender: "أحمد", text: "هل يمكنك إرسال الفاتورة المحدثة؟"),
        timestamp: Date().addingTimeInterval(-180),
        unreadCount: 2,
        contextText: "العميل ينتظر الفاتورة النهائية قبل موعد التوصيل.",
        quickReplies: [
            PPQuickReply(id: "send-now-ar", title: "سأرسلها الآن", message: "سأرسلها الآن"),
            PPQuickReply(id: "check-ar", title: "سأراجعها", message: "سأراجعها وأخبرك"),
            PPQuickReply(id: "call-ar", title: "هل أتصل بك؟", message: "هل يمكنني الاتصال بك؟")
        ]
    )
}

@MainActor
private struct PPChatCellPreviewHarness: View {
    let thread: PPChatThreadSnapshot
    let copy: PPChatCellCopy
    let timestampFormatter: PPChatTimestampFormatter

    @State private var expanded: Bool

    init(
        thread: PPChatThreadSnapshot,
        initiallyExpanded: Bool,
        copy: PPChatCellCopy = .package,
        timestampFormatter: PPChatTimestampFormatter = PPChatTimestampFormatter()
    ) {
        self.thread = thread
        self.copy = copy
        self.timestampFormatter = timestampFormatter
        _expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        ScrollView {
            PPExpandableChatCell(
                thread: thread,
                isExpanded: $expanded,
                copy: copy,
                timestampFormatter: timestampFormatter,
                onOpenChat: { _ in },
                sendQuickReply: { message, conversationID in
                    try await Task.sleep(nanoseconds: 500_000_000)
                    return PPQuickReplyReceipt(
                        messageID: UUID().uuidString,
                        conversationID: conversationID,
                        message: message,
                        sentAt: Date()
                    )
                }
            )
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
#endif
