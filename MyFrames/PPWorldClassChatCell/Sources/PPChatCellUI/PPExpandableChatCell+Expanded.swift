#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import UIKit
import PPChatCellCore

extension PPExpandableChatCell {
    // MARK: - Expanded content

    var expandedContent: some View {
        VStack(alignment: .leading, spacing: style.sectionSpacing) {
            HStack(spacing: 10) {
                presenceLabel

                Spacer(minLength: 8)

                Button(action: openChat) {
                    Label(copy.openFullChat, systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(style.brand)
                        .frame(minHeight: style.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PPChatSurfaceButtonStyle(reduceMotion: reduceMotion))
                .accessibilityHint(copy.openConversationHint)
                .accessibilityIdentifier("pp.chat.open.expanded.\(thread.id.rawValue)")
            }

            if let message = detailedMessage {
                Button(action: openChat) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(copy.latestMessage)
                                .font(.caption)
                                .foregroundStyle(Color.secondary)

                            if replyState.phase.isSending {
                                Label(copy.pending, systemImage: "clock")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(Color.secondary)
                            }
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            if replyState.optimisticMessage != nil {
                                Text(copy.you)
                                    .font(.subheadline.weight(.semibold))
                            }

                            Text(message)
                                .font(.subheadline)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 5 : 3)
                        }
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.leading, 12)
                    .frame(maxWidth: .infinity, minHeight: style.minimumTouchTarget, alignment: .leading)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(style.brand.opacity(0.46))
                            .frame(width: differentiateWithoutColor ? 4 : 2.5)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PPChatSurfaceButtonStyle(reduceMotion: reduceMotion))
                .accessibilityHint(copy.openConversationHint)
            }

            if let contextText = thread.contextText?.trimmingCharacters(in: .whitespacesAndNewlines),
               !contextText.isEmpty {
                contextBlock(contextText)
            }

            if !thread.quickReplies.isEmpty {
                quickReplies
            }

            composer
            sendStatus
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.top, style.sectionSpacing)
        .padding(.bottom, style.horizontalPadding)
    }

    var presenceLabel: some View {
        HStack(spacing: 7) {
            if differentiateWithoutColor {
                Image(systemName: presenceSymbol)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(presenceTint)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(presenceTint, lineWidth: 1.2))
            } else {
                Circle()
                    .fill(presenceTint)
                    .frame(width: 8, height: 8)
            }

            Text(presenceText)
                .font(.caption)
                .foregroundStyle(isOnline ? Color.primary : Color.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    func contextBlock(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(style.brand)
                .frame(width: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(copy.conversationContext)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(11)
        .background {
            RoundedRectangle(cornerRadius: style.compactCornerRadius, style: .continuous)
                .fill(style.brand.opacity(colorScheme == .dark ? 0.09 : 0.055))
        }
        .overlay {
            if colorSchemeContrast == .increased {
                RoundedRectangle(cornerRadius: style.compactCornerRadius, style: .continuous)
                    .stroke(style.brand.opacity(0.42), lineWidth: 1.2)
            }
        }
    }

    var quickReplies: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy.quickReplies)
                .font(.caption)
                .foregroundStyle(Color.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(thread.quickReplies) { reply in
                        Button {
                            chooseQuickReply(reply)
                        } label: {
                            Text(reply.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .padding(.horizontal, 13)
                                .frame(minHeight: style.minimumTouchTarget)
                                .background(Capsule().fill(style.quietFill))
                                .overlay {
                                    Capsule()
                                        .stroke(
                                            style.separator.opacity(borderOpacity),
                                            lineWidth: borderWidth
                                        )
                                }
                                .contentShape(Capsule())
                        }
                        .buttonStyle(PPChatSurfaceButtonStyle(reduceMotion: reduceMotion))
                        .disabled(replyState.phase.isSending)
                        .accessibilityIdentifier(
                            "pp.chat.quickReply.\(thread.id.rawValue).\(reply.id)"
                        )
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    var composer: some View {
        HStack(spacing: 6) {
            TextField(copy.replyPlaceholder, text: $replyState.draft, axis: .vertical)
                .focused($composerFocused)
                .font(.body)
                .lineLimit(1...3)
                .submitLabel(.send)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .onSubmit(sendDraft)
                .onChange(of: replyState.draft) { value in
                    normalizeDraft(value)
                }
                .accessibilityIdentifier("pp.chat.reply.input.\(thread.id.rawValue)")

            Button(action: sendDraft) {
                ZStack {
                    Circle()
                        .fill(canSend ? style.brand : Color(uiColor: .systemGray3))
                        .frame(width: 38, height: 38)

                    sendButtonSymbol
                        .foregroundStyle(Color.white)
                }
                .frame(width: style.minimumTouchTarget, height: style.minimumTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(PPChatIconButtonStyle(reduceMotion: reduceMotion))
            .disabled(!canSend)
            .accessibilityLabel(copy.sendReply)
            .accessibilityValue(sendButtonAccessibilityValue)
            .accessibilityIdentifier("pp.chat.reply.send.\(thread.id.rawValue)")
        }
        .padding(.leading, 15)
        .padding(.trailing, 4)
        .frame(minHeight: style.composerHeight)
        .background {
            Capsule()
                .fill(
                    reduceTransparency
                    ? style.opaqueSurface
                    : Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.50 : 0.76)
                )
        }
        .overlay {
            Capsule()
                .stroke(
                    composerFocused
                    ? style.brand.opacity(colorSchemeContrast == .increased ? 0.85 : 0.58)
                    : style.separator.opacity(borderOpacity),
                    lineWidth: composerFocused ? 1.6 : borderWidth
                )
        }
    }

    @ViewBuilder
    var sendButtonSymbol: some View {
        switch replyState.phase {
        case .sending:
            ProgressView()
                .tint(.white)
                .controlSize(.small)
        case .sent:
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
        case .idle, .failed:
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .bold))
        }
    }

    @ViewBuilder
    var sendStatus: some View {
        switch replyState.phase {
        case .idle, .sending:
            EmptyView()

        case .sent:
            Label(copy.sent, systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(uiColor: .systemGreen))
                .frame(minHeight: 20)
                .transition(.opacity)

        case let .failed(_, failure):
            HStack(alignment: .center, spacing: 8) {
                Label(copy.failureMessage(for: failure), systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: .systemRed))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(copy.retry, action: sendDraft)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.brand)
                    .frame(minHeight: style.minimumTouchTarget)
                    .contentShape(Rectangle())
                    .disabled(!canSend)
            }
            .transition(.opacity)
        }
    }

}
#endif
