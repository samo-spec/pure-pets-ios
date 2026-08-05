#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import UIKit
import PPChatCellCore

extension PPExpandableChatCell {
    // MARK: - Actions

    func openChat() {
        composerFocused = false
        PPChatHaptics.selection()
        onOpenChat(thread.id)
    }

    func toggleExpanded() {
        composerFocused = false
        let next = !isExpanded

        if let expansionAnimation {
            withAnimation(expansionAnimation) {
                isExpanded = next
            }
        } else {
            isExpanded = next
        }

        PPChatHaptics.impact(.light)
    }

    func chooseQuickReply(_ reply: PPQuickReply) {
        var next = replyState
        next.selectQuickReply(reply)

        if let feedbackAnimation {
            withAnimation(feedbackAnimation) {
                replyState = next
            }
        } else {
            replyState = next
        }

        composerFocused = true
        PPChatHaptics.selection()
    }

    func normalizeDraft(_ value: String) {
        if value.count > 240 {
            replyState.draft = String(value.prefix(240))
        }

        switch replyState.phase {
        case .sent, .failed:
            var next = replyState
            next.resetFeedback()
            replyState = next
        case .idle, .sending:
            break
        }
    }

    func sendDraft() {
        var next = replyState
        guard let message = next.beginSend() else { return }

        if let feedbackAnimation {
            withAnimation(feedbackAnimation) {
                replyState = next
            }
        } else {
            replyState = next
        }

        composerFocused = false
        feedbackTask?.cancel()
        sendTask?.cancel()
        onOptimisticReply(message, thread.id)

        sendTask = Task { @MainActor in
            do {
                let receipt = try await sendQuickReply(message, thread.id)
                try Task.checkCancellation()

                guard receipt.conversationID == thread.id,
                      !receipt.messageID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw PPQuickReplyFailure.unknown
                }

                var succeeded = replyState
                succeeded.succeed(with: receipt)
                if let feedbackAnimation {
                    withAnimation(feedbackAnimation) {
                        replyState = succeeded
                    }
                } else {
                    replyState = succeeded
                }
                onReplyCommitted(receipt)
                PPChatHaptics.notification(.success)
                scheduleFeedbackReset()
            } catch is CancellationError {
                return
            } catch {
                let failure = classify(error)
                var failed = replyState
                failed.fail(failure)
                if let feedbackAnimation {
                    withAnimation(feedbackAnimation) {
                        replyState = failed
                    }
                } else {
                    replyState = failed
                }
                onReplyFailed(failure, thread.id)
                composerFocused = true
                PPChatHaptics.notification(.error)
            }
        }
    }

    func scheduleFeedbackReset() {
        feedbackTask?.cancel()
        feedbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }

            var next = replyState
            if case .sent = next.phase {
                if reduceMotion {
                    next.resetFeedback()
                    replyState = next
                } else {
                    withAnimation(.easeOut(duration: 0.18)) {
                        next.resetFeedback()
                        replyState = next
                    }
                }
            }
        }
    }

    func classify(_ error: Error) -> PPQuickReplyFailure {
        if let failure = error as? PPQuickReplyFailure {
            return failure
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return .offline
            case .timedOut, .cannotConnectToHost, .cannotFindHost, .badServerResponse:
                return .server
            default:
                return .unknown
            }
        }

        return .unknown
    }

    func resetForReuse() {
        sendTask?.cancel()
        sendTask = nil
        cancelFeedbackOnly()
        replyState = PPQuickReplyStateMachine()
        composerFocused = false
    }

    func cancelFeedbackOnly() {
        feedbackTask?.cancel()
        feedbackTask = nil
    }

    // MARK: - Derived values

    var effectiveUnreadCount: Int {
        replyState.optimisticMessage == nil ? thread.unreadCount : 0
    }

    var timestampText: String {
        let date: Date
        switch replyState.phase {
        case let .sent(receipt):
            date = receipt.sentAt
        case .sending:
            date = Date()
        case .idle, .failed:
            date = thread.timestamp
        }
        return timestampFormatter.string(for: date, copy: copy)
    }

    var detailedMessage: String? {
        if let optimistic = replyState.optimisticMessage {
            return optimistic
        }
        return thread.lastActivity.textValue
    }

    var canSend: Bool {
        !replyState.phase.isSending &&
        !replyState.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func isQuickReplySelected(_ reply: PPQuickReply) -> Bool {
        !replyState.phase.isSending &&
        !replyState.draft.isEmpty &&
        replyState.draft == reply.message
    }

    var sendButtonFill: Color {
        switch replyState.phase {
        case .sending:
            return style.brand
        case .sent:
            return style.success
        case .idle, .failed:
            return canSend ? style.brand : Color(uiColor: .systemGray3)
        }
    }

    var composerFill: Color {
        if reduceTransparency {
            return style.opaqueSurface
        }

        return style.replyDockSurface.opacity(colorScheme == .dark ? 0.78 : 0.94)
    }

    var composerStroke: Color {
        switch replyState.phase {
        case .sent:
            return style.success.opacity(colorSchemeContrast == .increased ? 0.92 : 0.62)
        case .failed:
            return style.danger.opacity(colorSchemeContrast == .increased ? 0.94 : 0.68)
        case .idle, .sending:
            if composerFocused || replyState.phase.isSending {
                return style.brand.opacity(colorSchemeContrast == .increased ? 0.92 : 0.62)
            }
            return style.separator.opacity(borderOpacity)
        }
    }

    var composerStrokeWidth: CGFloat {
        if composerFocused || replyState.phase.isSending {
            return colorSchemeContrast == .increased ? 2 : 1.5
        }

        switch replyState.phase {
        case .sent, .failed:
            return colorSchemeContrast == .increased ? 2 : 1.5
        case .idle, .sending:
            return borderWidth
        }
    }

    var presenceText: String {
        switch thread.presence {
        case .online:
            return copy.onlineNow
        case .away:
            return copy.away
        case let .offline(lastSeen):
            guard let lastSeen else { return copy.offline }
            let relative = RelativeDateTimeFormatter()
            relative.locale = timestampFormatter.locale
            relative.unitsStyle = .full
            return relative.localizedString(for: lastSeen, relativeTo: Date())
        }
    }

    var presenceTint: Color {
        switch thread.presence {
        case .online:
            return Color(uiColor: .systemGreen)
        case .away:
            return Color(uiColor: .systemOrange)
        case .offline:
            return Color(uiColor: .systemGray3)
        }
    }

    var presenceSymbol: String {
        switch thread.presence {
        case .online:
            return "checkmark"
        case .away:
            return "minus"
        case .offline:
            return "xmark"
        }
    }

    var isOnline: Bool {
        if case .online = thread.presence { return true }
        return false
    }

    var borderWidth: CGFloat {
        colorSchemeContrast == .increased ? 1.5 : 1
    }

    var borderOpacity: Double {
        colorSchemeContrast == .increased ? 0.72 : colorScheme == .dark ? 0.46 : 0.30
    }

    var expandedShadowOpacity: Double {
        colorScheme == .dark ? 0.26 : 0.10
    }

    var expansionAnimation: Animation? {
        reduceMotion
        ? nil
        : .interactiveSpring(response: 0.42, dampingFraction: 0.90, blendDuration: 0.10)
    }

    var feedbackAnimation: Animation? {
        reduceMotion
        ? .easeOut(duration: 0.14)
        : .spring(response: 0.28, dampingFraction: 0.92, blendDuration: 0.06)
    }

    var expandedContentTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }

        return .asymmetric(
            insertion: .opacity
                .combined(with: .move(edge: .top))
                .combined(with: .scale(scale: 0.985, anchor: .top)),
            removal: .opacity.combined(with: .scale(scale: 0.992, anchor: .top))
        )
    }

    var summaryAccessibilityLabel: String {
        let items = [
            thread.displayName,
            thread.isVerified ? copy.verified : nil,
            presenceText,
            accessibilityActivityText,
            timestampText
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }

        return ListFormatter.localizedString(byJoining: items)
    }

    var accessibilityActivityText: String {
        if let optimistic = replyState.optimisticMessage {
            return "\(copy.you), \(optimistic)"
        }

        switch thread.lastActivity {
        case let .text(sender, text):
            let items = [sender, text].compactMap { $0 }
            return ListFormatter.localizedString(byJoining: items)
        case .typing:
            return copy.typing
        case .photo:
            return copy.photo
        case .video:
            return copy.video
        case .voice:
            return copy.voiceMessage
        case .deleted:
            return copy.deletedMessage
        case .none:
            return copy.noMessagesYet
        }
    }

    var unreadAccessibilityValue: String {
        effectiveUnreadCount > 0 ? copy.unreadCount(effectiveUnreadCount) : ""
    }

    var sendButtonAccessibilityValue: String {
        switch replyState.phase {
        case .idle:
            return canSend ? "" : copy.disabled
        case .sending:
            return copy.sending
        case .sent:
            return copy.sent
        case let .failed(_, failure):
            return copy.failureMessage(for: failure)
        }
    }
}
#endif
