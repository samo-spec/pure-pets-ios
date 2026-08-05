#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI
import UIKit
import PPChatCellCore

extension PPExpandableChatCell {
    // MARK: - Expanded content

    var expandedContent: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(style.brand.opacity(0.78))
                        .frame(width: 34, height: differentiateWithoutColor ? 3 : 2)
                }
                .padding(.horizontal, style.horizontalPadding)

            VStack(alignment: .leading, spacing: style.sectionSpacing) {
                expandedToolbar

                if let message = detailedMessage {
                    latestMessageBlock(message)
                }

                if let contextText = thread.contextText?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !contextText.isEmpty {
                    contextBlock(contextText)
                }

                if !thread.quickReplies.isEmpty {
                    quickReplies
                }

                VStack(alignment: .leading, spacing: 8) {
                    composer
                    sendStatus
                }
            }
            .padding(.horizontal, style.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, style.horizontalPadding)
        }
    }

    var expandedToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                presenceLabel

                Spacer(minLength: 8)

                openFullChatButton
            }

            VStack(alignment: .leading, spacing: 6) {
                presenceLabel
                openFullChatButton
            }
        }
    }

    var openFullChatButton: some View {
        Button(action: openChat) {
            Label(copy.openFullChat, systemImage: "bubble.left.and.bubble.right.fill")
                .font(Font.ppBeirutiSemiBold(size: 12, relativeTo: .caption))
                .foregroundStyle(style.brand)
                .padding(.horizontal, 12)
                .frame(minHeight: style.minimumTouchTarget)
                .background {
                    Capsule().fill(style.brandSoft)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PPChatSurfaceButtonStyle(reduceMotion: reduceMotion))
        .accessibilityHint(copy.openConversationHint)
        .accessibilityIdentifier("pp.chat.open.expanded.\(thread.id.rawValue)")
    }

    func latestMessageBlock(_ message: String) -> some View {
        Button(action: openChat) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(copy.latestMessage)
                        .font(Font.ppBeirutiRegular(size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.secondary)

                    if replyState.phase.isSending {
                        Label(copy.pending, systemImage: "clock")
                            .font(Font.ppBeirutiMedium(size: 11, relativeTo: .caption2))
                            .foregroundStyle(Color.secondary)
                            .transition(.opacity)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    if replyState.optimisticMessage != nil {
                        Text(copy.you)
                            .font(Font.ppBeirutiSemiBold(size: 14, relativeTo: .subheadline))
                    }

                    Text(message)
                        .font(Font.ppBeirutiRegular(size: 14, relativeTo: .subheadline))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 5 : 3)
                }
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: style.minimumTouchTarget, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: style.compactCornerRadius, style: .continuous)
                    .fill(style.elevatedSurface.opacity(colorScheme == .dark ? 0.54 : 0.76))
            }
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(style.brand.opacity(0.68))
                    .frame(width: differentiateWithoutColor ? 5 : 3)
                    .padding(.vertical, 11)
            }
            .overlay {
                RoundedRectangle(cornerRadius: style.compactCornerRadius, style: .continuous)
                    .stroke(style.separator.opacity(borderOpacity * 0.68), lineWidth: borderWidth)
            }
            .contentShape(RoundedRectangle(cornerRadius: style.compactCornerRadius, style: .continuous))
        }
        .buttonStyle(PPChatSurfaceButtonStyle(reduceMotion: reduceMotion))
        .accessibilityHint(copy.openConversationHint)
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
                .font(Font.ppBeirutiRegular(size: 12, relativeTo: .caption))
                .foregroundStyle(isOnline ? Color.primary : Color.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    func contextBlock(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(style.brand)
                .frame(width: 30, height: 30)
                .background(Circle().fill(style.brandSoft))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(copy.conversationContext)
                    .font(Font.ppBeirutiRegular(size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.secondary)

                Text(text)
                    .font(Font.ppBeirutiRegular(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 3)
    }

    var quickReplies: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy.quickReplies)
                .font(Font.ppBeirutiRegular(size: 12, relativeTo: .caption))
                .foregroundStyle(Color.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(thread.quickReplies) { reply in
                        let isSelected = isQuickReplySelected(reply)

                        Button {
                            chooseQuickReply(reply)
                        } label: {
                            HStack(spacing: 6) {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                        .accessibilityHidden(true)
                                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                                }

                                Text(reply.title)
                                    .font(Font.ppBeirutiMedium(size: 14, relativeTo: .subheadline))
                                    .lineLimit(1)
                            }
                                .foregroundStyle(isSelected ? style.brand : Color.primary)
                                .padding(.horizontal, 14)
                                .frame(minHeight: style.minimumTouchTarget)
                                .background(Capsule().fill(isSelected ? style.brandSoft : style.quietFill))
                                .overlay {
                                    Capsule()
                                        .stroke(
                                            isSelected
                                            ? style.brand.opacity(0.42)
                                            : style.separator.opacity(borderOpacity),
                                            lineWidth: isSelected ? max(1.2, borderWidth) : borderWidth
                                        )
                                }
                                .contentShape(Capsule())
                        }
                        .buttonStyle(PPChatSurfaceButtonStyle(reduceMotion: reduceMotion))
                        .disabled(replyState.phase.isSending)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
        HStack(alignment: .center, spacing: 6) {
            TextField(copy.replyPlaceholder, text: $replyState.draft, axis: .vertical)
                .focused($composerFocused)
                .font(Font.ppBeirutiRegular(size: 16, relativeTo: .body))
                .lineLimit(1...3)
                .frame(maxHeight: .infinity, alignment: .center)
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
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(sendButtonFill)
                        .frame(width: 42, height: 42)

                    if replyState.phase.isSending && !reduceMotion {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.42), lineWidth: 1.5)
                            .frame(width: 42, height: 42)
                            .transition(.opacity)
                    }

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
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 2)
        .frame(minHeight: style.composerHeight)
        .background {
            RoundedRectangle(cornerRadius: style.compactCornerRadius + 2, style: .continuous)
                .fill(composerFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: style.compactCornerRadius + 2, style: .continuous)
                .stroke(
                    composerStroke,
                    lineWidth: composerStrokeWidth
                )
        }
        .animation(feedbackAnimation, value: composerFocused)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.18),
            value: canSend
        )
    }

    @ViewBuilder
    var sendButtonSymbol: some View {
        ZStack {
            switch replyState.phase {
            case .sending:
                ProgressView()
                    .tint(.white)
                    .controlSize(.small)
                    .transition(.opacity)
            case .sent:
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .transition(
                        reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .scale(scale: 0.72))
                    )
            case .idle, .failed:
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .transition(.opacity)
            }
        }
        .animation(feedbackAnimation, value: replyState.phase)
    }

    @ViewBuilder
    var sendStatus: some View {
        switch replyState.phase {
        case .idle:
            EmptyView()

        case .sending:
            Label(copy.sending, systemImage: "arrow.up.circle")
                .font(Font.ppBeirutiMedium(size: 12, relativeTo: .caption))
                .foregroundStyle(Color.secondary)
                .frame(minHeight: 20)
                .transition(.opacity)

        case .sent:
            Label(copy.sent, systemImage: "checkmark.circle.fill")
                .font(Font.ppBeirutiMedium(size: 12, relativeTo: .caption))
                .foregroundStyle(style.success)
                .frame(minHeight: 20)
                .transition(.opacity)

        case let .failed(_, failure):
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 8) {
                    failureLabel(failure)
                    retryButton
                }

                VStack(alignment: .leading, spacing: 4) {
                    failureLabel(failure)
                    retryButton
                }
            }
            .transition(.opacity)
        }
    }

    func failureLabel(_ failure: PPQuickReplyFailure) -> some View {
        Label(copy.failureMessage(for: failure), systemImage: "exclamationmark.circle.fill")
            .font(Font.ppBeirutiRegular(size: 12, relativeTo: .caption))
            .foregroundStyle(style.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var retryButton: some View {
        Button(copy.retry, action: sendDraft)
            .font(Font.ppBeirutiSemiBold(size: 12, relativeTo: .caption))
            .foregroundStyle(style.brand)
            .frame(minHeight: style.minimumTouchTarget)
            .contentShape(Rectangle())
            .disabled(!canSend)
    }

}
#endif
