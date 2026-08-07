#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import UIKit
import PPChatCellCore

/// A production chat-inbox cell with explicit gesture ownership:
/// - conversation surface → open the messaging controller;
/// - dedicated chevron → expand/collapse inline reply;
/// - inline controls → remain inside the cell.
@MainActor
public struct PPExpandableChatCell: View {
    public typealias OpenChatAction = (PPConversationID) -> Void
    public typealias OptimisticReplyAction = (String, PPConversationID) -> Void
    public typealias ReplyCommittedAction = (PPQuickReplyReceipt) -> Void
    public typealias ReplyFailedAction = (PPQuickReplyFailure, PPConversationID) -> Void
    public typealias SendReplyAction = @Sendable (
        _ message: String,
        _ conversationID: PPConversationID
    ) async throws -> PPQuickReplyReceipt

    let thread: PPChatThreadSnapshot
    @Binding var isExpanded: Bool

    let style: PPChatCellStyle
    let copy: PPChatCellCopy
    let timestampFormatter: PPChatTimestampFormatter
    let avatarPipeline: any PPAvatarImageProviding
    let onOpenChat: OpenChatAction
    let onOptimisticReply: OptimisticReplyAction
    let onReplyCommitted: ReplyCommittedAction
    let onReplyFailed: ReplyFailedAction
    let sendQuickReply: SendReplyAction

    let animationsEnabled: Bool
    /// Whether the one-time entrance (fade/offset/scale) is allowed to play.
    /// Hosts that recycle cells inside a scrolling list (e.g. the UIKit inbox)
    /// pass `false` so a reused row never replays an entrance mid-scroll, while
    /// expand/collapse and feedback still animate. Defaults to `true` for
    /// standalone SwiftUI use.
    let entranceEnabled: Bool

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.layoutDirection) var layoutDirection

    @State var replyState = PPQuickReplyStateMachine()
    @State var sendTask: Task<Void, Never>?
    @State var feedbackTask: Task<Void, Never>?
    @State var hasEntered = false
    @FocusState var composerFocused: Bool

    public init(
        thread: PPChatThreadSnapshot,
        isExpanded: Binding<Bool>,
        style: PPChatCellStyle = .purePets,
        copy: PPChatCellCopy = .package,
        timestampFormatter: PPChatTimestampFormatter = PPChatTimestampFormatter(),
        avatarPipeline: any PPAvatarImageProviding = PPAvatarImagePipeline.shared,
        onOpenChat: @escaping OpenChatAction,
        onOptimisticReply: @escaping OptimisticReplyAction = { _, _ in },
        onReplyCommitted: @escaping ReplyCommittedAction = { _ in },
        onReplyFailed: @escaping ReplyFailedAction = { _, _ in },
        sendQuickReply: @escaping SendReplyAction,
        animationsEnabled: Bool = true,
        entranceEnabled: Bool = true
    ) {
        self.thread = thread
        _isExpanded = isExpanded
        self.style = style
        self.copy = copy
        self.timestampFormatter = timestampFormatter
        self.avatarPipeline = avatarPipeline
        self.onOpenChat = onOpenChat
        self.onOptimisticReply = onOptimisticReply
        self.onReplyCommitted = onReplyCommitted
        self.onReplyFailed = onReplyFailed
        self.sendQuickReply = sendQuickReply
        self.animationsEnabled = animationsEnabled
        self.entranceEnabled = entranceEnabled
        // Start already-settled when the entrance is disabled, or for a thread
        // that has entered before this session (e.g. the host rebuilt the
        // UIHostingConfiguration after dismissing the messaging screen, or
        // reconfigured the row after a send). This avoids a one-frame
        // opacity/offset/scale flash and any entrance replay; genuinely new
        // threads still animate once via onAppear.
        _hasEntered = State(
            initialValue: !animationsEnabled || !entranceEnabled ||
                PPChatCellEntranceLedger.shared.hasEntered(thread.id)
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            summaryRow

            if isExpanded {
                expandedContent
                    .transition(expandedContentTransition)
            }
        }
        .background { surfaceBackground }
        .overlay { surfaceBorder }
        .overlay(alignment: .leading) { conversationSignal }
        .clipShape(surfaceShape)
        // Elevation contract: radius and offset are FIXED constants; only the
        // shadow's opacity animates between resting and lifted. Animating the
        // blur radius is the classic cause of "shadow trembling" during a
        // resize, so we never do it. A fixed kernel + opacity fade keeps the
        // shadow rock-steady while the card grows/shrinks.
        .shadow(
            color: style.shadowColor.opacity(currentShadowOpacity),
            radius: style.shadowRadius,
            x: 0,
            y: style.shadowYOffset
        )
        .padding(.horizontal, style.outerHorizontalInset)
        .padding(.vertical, style.outerVerticalInset)
        .opacity(hasEntered ? 1 : 0)
        .offset(
            x: hasEntered ? 0 : (layoutDirection == .rightToLeft ? 8 : -8),
            y: hasEntered ? 0 : 4
        )
        .scaleEffect(hasEntered ? 1 : 0.988, anchor: .center)
        .animation(expansionAnimation, value: isExpanded)
        .animation(feedbackAnimation, value: replyState.phase)
        .animation(entranceAnimation, value: hasEntered)
        .accessibilityIdentifier("pp.chat.thread.\(thread.id.rawValue)")
        .onAppear {
            playEntranceIfNeeded()
        }
        .onChange(of: isExpanded) { expanded in
            if !expanded { composerFocused = false }
        }
        .onChange(of: thread.id) { _ in
            resetForReuse()
            playEntranceIfNeeded()
        }
        .onDisappear {
            composerFocused = false
            cancelFeedbackOnly()
        }
    }

    /// Resolved shadow opacity for the current state. Interpolated by the
    /// expansion animation (opacity only — see `body`).
    var currentShadowOpacity: Double {
        isExpanded
        ? style.liftedShadowOpacity(colorScheme)
        : style.restingShadowOpacity(colorScheme)
    }

    var reduceMotion: Bool {
        !animationsEnabled || systemReduceMotion
    }

}
#endif
