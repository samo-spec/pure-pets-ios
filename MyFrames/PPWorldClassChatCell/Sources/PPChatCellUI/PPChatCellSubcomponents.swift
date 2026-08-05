#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
import PPChatCellCore

struct PPChatAvatarView: View {
    let thread: PPChatThreadSnapshot
    let style: PPChatCellStyle

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @StateObject private var loader: PPAvatarImageLoader

    init(
        thread: PPChatThreadSnapshot,
        style: PPChatCellStyle,
        pipeline: any PPAvatarImageProviding
    ) {
        self.thread = thread
        self.style = style
        _loader = StateObject(wrappedValue: PPAvatarImageLoader(pipeline: pipeline))
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(haloColor)
                .frame(width: style.avatarSize + 4, height: style.avatarSize + 4)

            avatarContent
                .frame(width: style.avatarSize, height: style.avatarSize)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(
                            Color.white.opacity(colorScheme == .dark ? 0.10 : 0.72),
                            lineWidth: 1
                        )
                }
        }
        .overlay(alignment: .bottomTrailing) {
            PPPresenceGlyph(
                presence: thread.presence,
                differentiateWithoutColor: differentiateWithoutColor,
                surfaceColor: style.opaqueSurface
            )
            .padding(1)
        }
        .accessibilityHidden(true)
        .onAppear(perform: load)
        .onChange(of: thread.avatarURL) { _ in load() }
        .onChange(of: displayScale) { _ in load() }
        .onDisappear { loader.cancel() }
    }

    @ViewBuilder
    private var avatarContent: some View {
        switch loader.state {
        case let .success(image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()

        case .loading:
            fallback
                .overlay {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.secondary)
                }

        case .empty, .failure:
            fallback
        }
    }

    private var fallback: some View {
        ZStack {
            Circle()
                .fill(style.brand.opacity(colorScheme == .dark ? 0.18 : 0.10))

            Text(thread.initials)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(style.brand)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .padding(6)
        }
    }

    private var haloColor: Color {
        switch thread.presence {
        case .online:
            return Color(uiColor: .systemGreen).opacity(colorScheme == .dark ? 0.15 : 0.09)
        case .away:
            return Color(uiColor: .systemOrange).opacity(colorScheme == .dark ? 0.14 : 0.08)
        case .offline:
            return style.quietFill
        }
    }

    private func load() {
        loader.load(
            url: thread.avatarURL,
            targetSize: CGSize(width: style.avatarSize, height: style.avatarSize),
            scale: displayScale
        )
    }
}

private struct PPPresenceGlyph: View {
    let presence: PPChatPresence
    let differentiateWithoutColor: Bool
    let surfaceColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(surfaceColor)
                .frame(width: 17, height: 17)

            if differentiateWithoutColor {
                Image(systemName: symbolName)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 13, height: 13)
                    .background(Circle().fill(surfaceColor))
                    .overlay(Circle().stroke(tint, lineWidth: 1.4))
            } else {
                Circle()
                    .fill(tint)
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(surfaceColor, lineWidth: 2.5))
            }
        }
    }

    private var tint: Color {
        switch presence {
        case .online:
            return Color(uiColor: .systemGreen)
        case .away:
            return Color(uiColor: .systemOrange)
        case .offline:
            return Color(uiColor: .systemGray3)
        }
    }

    private var symbolName: String {
        switch presence {
        case .online:
            return "checkmark"
        case .away:
            return "minus"
        case .offline:
            return "xmark"
        }
    }
}

struct PPChatActivityPreviewView: View {
    let activity: PPChatLastActivity
    let optimisticMessage: String?
    let copy: PPChatCellCopy
    let isUnread: Bool
    let brand: Color
    var lineLimit: Int = 1

    var body: some View {
        HStack(spacing: 6) {
            if let iconName {
                Image(systemName: iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isTyping ? brand : Color.secondary)
                    .accessibilityHidden(true)
            }

            if let sender = displayedSender, !sender.isEmpty {
                Text(sender)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
            }

            Text(displayedMessage)
                .font(.subheadline.weight(isUnread ? .medium : .regular))
                .foregroundStyle(textColor)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var displayedSender: String? {
        if optimisticMessage != nil { return copy.you }
        return activity.sender
    }

    private var displayedMessage: String {
        if let optimisticMessage { return optimisticMessage }

        switch activity {
        case let .text(_, text):
            return text
        case .typing:
            return copy.typing
        case .photo:
            return copy.photo
        case .video:
            return copy.video
        case let .voice(_, duration):
            guard let duration else { return copy.voiceMessage }
            return "\(copy.voiceMessage) · \(Self.durationText(duration))"
        case .deleted:
            return copy.deletedMessage
        case .none:
            return copy.noMessagesYet
        }
    }

    private var iconName: String? {
        if optimisticMessage != nil { return "arrow.up.circle.fill" }
        switch activity {
        case .text:
            return nil
        case .typing:
            return "ellipsis.bubble.fill"
        case .photo:
            return "photo.fill"
        case .video:
            return "video.fill"
        case .voice:
            return "waveform"
        case .deleted:
            return "nosign"
        case .none:
            return "bubble.left"
        }
    }

    private var isTyping: Bool {
        if case .typing = activity, optimisticMessage == nil { return true }
        return false
    }

    private var textColor: Color {
        if isTyping { return brand }
        return isUnread ? Color.primary.opacity(0.90) : Color.secondary
    }

    private static func durationText(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct PPUnreadBadge: View {
    let count: Int
    let brand: Color

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.white)
            .monospacedDigit()
            .padding(.horizontal, 7)
            .frame(minWidth: 22, minHeight: 22)
            .background(Capsule().fill(brand))
            .accessibilityHidden(true)
    }
}

struct PPChatSurfaceButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.988)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

struct PPChatIconButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.76 : 1)
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.92)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

enum PPChatHaptics {
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
#endif
