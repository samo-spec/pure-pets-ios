import Foundation
import PPChatCellCore

public struct PPChatCellCopy {
    public let bundle: Bundle
    public let tableName: String

    public init(bundle: Bundle, tableName: String = "PPChatCell") {
        self.bundle = bundle
        self.tableName = tableName
    }

    public static let package = PPChatCellCopy(bundle: .module)

    public static func localized(languageCode: String) -> PPChatCellCopy {
        guard let path = Bundle.module.path(forResource: languageCode, ofType: "lproj"),
              let localizedBundle = Bundle(path: path) else {
            return .package
        }
        return PPChatCellCopy(bundle: localizedBundle)
    }

    public var onlineNow: String { value("chat.cell.online_now", fallback: "Online now") }
    public var away: String { value("chat.cell.away", fallback: "Away") }
    public var offline: String { value("chat.cell.offline", fallback: "Offline") }
    public var openFullChat: String { value("chat.cell.open_full_chat", fallback: "Open full chat") }
    public var latestMessage: String { value("chat.cell.latest_message", fallback: "Latest message") }
    public var conversationContext: String { value("chat.cell.conversation_context", fallback: "Conversation context") }
    public var quickReplies: String { value("chat.cell.quick_replies", fallback: "Quick replies") }
    public var replyPlaceholder: String { value("chat.cell.reply_placeholder", fallback: "Write a quick reply…") }
    public var expandReply: String { value("chat.cell.expand_reply", fallback: "Expand quick reply") }
    public var collapseReply: String { value("chat.cell.collapse_reply", fallback: "Collapse quick reply") }
    public var sendReply: String { value("chat.cell.send_reply", fallback: "Send quick reply") }
    public var sending: String { value("chat.cell.sending", fallback: "Sending…") }
    public var sent: String { value("chat.cell.sent", fallback: "Reply sent") }
    public var retry: String { value("chat.cell.retry", fallback: "Try again") }
    public var noMessagesYet: String { value("chat.cell.no_messages", fallback: "No messages yet") }
    public var photo: String { value("chat.cell.photo", fallback: "Photo") }
    public var video: String { value("chat.cell.video", fallback: "Video") }
    public var voiceMessage: String { value("chat.cell.voice_message", fallback: "Voice message") }
    public var deletedMessage: String { value("chat.cell.deleted_message", fallback: "Message deleted") }
    public var typing: String { value("chat.cell.typing", fallback: "Typing…") }
    public var verified: String { value("chat.cell.verified", fallback: "Verified") }
    public var openConversationHint: String { value("chat.cell.open_hint", fallback: "Opens the complete messaging screen.") }
    public var inlineReplyHint: String { value("chat.cell.inline_hint", fallback: "Shows a compact reply composer inside this conversation card.") }
    public var expanded: String { value("chat.cell.expanded", fallback: "Expanded") }
    public var collapsed: String { value("chat.cell.collapsed", fallback: "Collapsed") }
    public var disabled: String { value("chat.cell.disabled", fallback: "Disabled") }
    public var pending: String { value("chat.cell.pending", fallback: "Pending") }
    public var yesterday: String { value("chat.cell.yesterday", fallback: "Yesterday") }
    public var you: String { value("chat.cell.you", fallback: "You") }

    public func unreadCount(_ count: Int) -> String {
        let format = NSLocalizedString(
            "chat.cell.unread_count",
            tableName: tableName,
            bundle: bundle,
            value: "%ld unread messages",
            comment: "VoiceOver unread message count"
        )
        return String.localizedStringWithFormat(format, count)
    }

    public func failureMessage(for failure: PPQuickReplyFailure) -> String {
        switch failure {
        case .offline:
            return value("chat.cell.error.offline", fallback: "You appear to be offline. Your reply wasn’t sent.")
        case .permissionDenied:
            return value("chat.cell.error.permission", fallback: "You can no longer reply to this conversation.")
        case .conversationClosed:
            return value("chat.cell.error.closed", fallback: "This conversation is closed.")
        case .rateLimited:
            return value("chat.cell.error.rate_limited", fallback: "Too many replies were sent. Try again shortly.")
        case .server:
            return value("chat.cell.error.server", fallback: "The service is temporarily unavailable.")
        case .unknown:
            return value("chat.cell.error.unknown", fallback: "Your reply couldn’t be sent.")
        }
    }

    private func value(_ key: String, fallback: String) -> String {
        NSLocalizedString(
            key,
            tableName: tableName,
            bundle: bundle,
            value: fallback,
            comment: ""
        )
    }
}

public struct PPChatTimestampFormatter {
    public var calendar: Calendar
    public var locale: Locale
    public var timeZone: TimeZone

    public init(
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.calendar = calendar
        self.locale = locale
        self.timeZone = timeZone
    }

    public func string(for date: Date, relativeTo now: Date = Date(), copy: PPChatCellCopy = .package) -> String {
        var calendar = calendar
        calendar.locale = locale
        calendar.timeZone = timeZone

        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(
                Date.FormatStyle(
                    date: .omitted,
                    time: .shortened,
                    locale: locale,
                    calendar: calendar,
                    timeZone: timeZone
                )
            )
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return copy.yesterday
        }

        let dayDistance = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? Int.max

        if (2...6).contains(dayDistance) {
            return date.formatted(
                Date.FormatStyle(
                    date: .complete,
                    time: .omitted,
                    locale: locale,
                    calendar: calendar,
                    timeZone: timeZone
                )
                .weekday(.abbreviated)
            )
        }

        return date.formatted(
            Date.FormatStyle(
                date: .abbreviated,
                time: .omitted,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone
            )
        )
    }
}
