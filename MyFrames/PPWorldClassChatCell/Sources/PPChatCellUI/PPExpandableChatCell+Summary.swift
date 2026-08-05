#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import UIKit
import PPChatCellCore

extension PPExpandableChatCell {
    // MARK: - Summary

    var summaryRow: some View {
        HStack(spacing: style.rowSpacing) {
            Button(action: openChat) {
                HStack(spacing: style.rowSpacing) {
                    PPChatAvatarView(
                        thread: thread,
                        isUnread: effectiveUnreadCount > 0,
                        style: style,
                        pipeline: avatarPipeline
                    )

                    VStack(alignment: .leading, spacing: 7) {
                        identityRow

                        PPChatActivityPreviewView(
                            activity: thread.lastActivity,
                            optimisticMessage: replyState.optimisticMessage,
                            copy: copy,
                            isUnread: effectiveUnreadCount > 0,
                            brand: style.brand,
                            lineLimit: dynamicTypeSize.isAccessibilitySize ? 2 : 1
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if effectiveUnreadCount > 0 {
                        PPUnreadBadge(count: effectiveUnreadCount, brand: style.brand)
                            .transition(
                                reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .scale(scale: 0.82))
                            )
                    }
                }
                .frame(maxWidth: .infinity, minHeight: style.minimumSummaryHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(PPChatSurfaceButtonStyle(reduceMotion: reduceMotion))
            .accessibilityLabel(summaryAccessibilityLabel)
            .accessibilityValue(unreadAccessibilityValue)
            .accessibilityHint(copy.openConversationHint)
            .accessibilityIdentifier("pp.chat.open.\(thread.id.rawValue)")

            Button(action: toggleExpanded) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            isExpanded
                            ? style.brandSoft
                            : style.quietFill
                        )
                        .frame(width: 40, height: 40)

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isExpanded
                            ? style.brand.opacity(0.40)
                            : style.separator.opacity(borderOpacity),
                            lineWidth: borderWidth
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isExpanded ? style.brand : Color.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .frame(width: style.minimumTouchTarget, height: style.minimumTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(PPChatIconButtonStyle(reduceMotion: reduceMotion))
            .accessibilityLabel(isExpanded ? copy.collapseReply : copy.expandReply)
            .accessibilityHint(copy.inlineReplyHint)
            .accessibilityValue(isExpanded ? copy.expanded : copy.collapsed)
            .accessibilityIdentifier("pp.chat.expand.\(thread.id.rawValue)")
        }
        .padding(.leading, style.horizontalPadding)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
    }

    var identityRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                displayName

                Spacer(minLength: 8)

                timestamp
            }

            VStack(alignment: .leading, spacing: 2) {
                displayName
                timestamp
            }
        }
    }

    var displayName: some View {
        HStack(spacing: 5) {
            Text(thread.displayName)
                .font(.headline.weight(effectiveUnreadCount > 0 ? .bold : .semibold))
                .foregroundStyle(Color.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .multilineTextAlignment(.leading)

            if thread.isVerified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.brand)
                    .accessibilityLabel(copy.verified)
            }
        }
    }

    var timestamp: some View {
        Text(timestampText)
            .font(.caption)
            .foregroundStyle(effectiveUnreadCount > 0 ? Color.primary : Color.secondary)
            .monospacedDigit()
            .lineLimit(1)
    }

}
#endif
