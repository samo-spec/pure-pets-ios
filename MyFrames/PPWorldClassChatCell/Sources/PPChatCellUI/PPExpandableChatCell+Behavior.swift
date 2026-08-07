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
        hasEntered = !animationsEnabled || !entranceEnabled
    }

    func playEntranceIfNeeded() {
        guard !hasEntered else { return }

        // Entrance is a one-time, opt-in flourish. Hosts that recycle cells in
        // a scrolling list disable it so a reused row never replays mid-scroll.
        guard entranceEnabled else {
            hasEntered = true
            return
        }

        // A thread animates its entrance only once per app session. When the
        // list re-appears — returning from the full messaging screen, or a
        // reused cell rebinding an already-seen thread — the fresh SwiftUI view
        // starts with `hasEntered == false`, which previously replayed the
        // opacity/offset/scale entrance every single time. The ledger makes the
        // cell settle instantly in that case instead of re-animating.
        if PPChatCellEntranceLedger.shared.hasEntered(thread.id) {
            hasEntered = true
            return
        }

        if reduceMotion {
            hasEntered = true
            PPChatCellEntranceLedger.shared.markEntered(thread.id)
            return
        }

        DispatchQueue.main.async {
            guard !hasEntered else { return }
            withAnimation(entranceAnimation) {
                hasEntered = true
            }
            PPChatCellEntranceLedger.shared.markEntered(thread.id)
        }
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

    /// True while the latest message shown in the expanded block is one the
    /// current user just sent (optimistic in-flight or freshly confirmed),
    /// so the block can label it with a bold sender token + sent indicator.
    var latestMessageIsOwn: Bool {
        if replyState.optimisticMessage != nil { return true }
        if case .sent = replyState.phase { return true }
        return false
    }

    var latestMessageWasSent: Bool {
        if case .sent = replyState.phase { return true }
        return false
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

    var expansionAnimation: Animation? {
        // Critically damped spring (dampingFraction 1.0 → zero overshoot).
        // Overshoot would make the row height bounce past its final value and
        // shove neighbouring rows back and forth in the table — the source of
        // "unstable in transitions". A no-bounce spring lets UIHosting
        // configuration animate the self-sizing resize monotonically, so the
        // card, its shadow, and every neighbour settle in one smooth pass.
        reduceMotion
        ? nil
        : .spring(response: 0.42, dampingFraction: 1.0, blendDuration: 0)
    }

    var feedbackAnimation: Animation? {
        guard animationsEnabled else { return nil }
        return reduceMotion
        ? .easeOut(duration: 0.14)
        : .spring(response: 0.28, dampingFraction: 0.92, blendDuration: 0.06)
    }

    var entranceAnimation: Animation? {
        reduceMotion
        ? nil
        : .timingCurve(0.20, 0.0, 0.0, 1.0, duration: 0.34)
    }

    var expandedContentTransition: AnyTransition {
        if !animationsEnabled {
            return .identity
        }

        // Seamless curtain reveal: the container's height animates via the
        // expansion spring and clips the content to the rounded surface, so the
        // body is uncovered top-to-bottom. The content itself only fades — no
        // `.move` (which slides content out from behind the summary → flash)
        // and no `.scale` (which rasterizes → blink). Opacity over an animated
        // height clip is what makes the reveal read as one continuous motion.
        return .opacity
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

/// Session-scoped record of which conversations have already played their
/// one-time entrance animation. Lives for the lifetime of the process so that
/// dismissing the full messaging screen (or reusing a hosting cell) does not
/// replay the entrance every time the inbox re-appears.
@MainActor
final class PPChatCellEntranceLedger {
    static let shared = PPChatCellEntranceLedger()

    private var entered: Set<String> = []

    private init() {}

    func hasEntered(_ id: PPConversationID) -> Bool {
        entered.contains(id.rawValue)
    }

    func markEntered(_ id: PPConversationID) {
        entered.insert(id.rawValue)
    }
}
#endif
