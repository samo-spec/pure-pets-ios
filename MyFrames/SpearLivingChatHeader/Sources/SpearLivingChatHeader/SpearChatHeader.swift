import SwiftUI
import UIKit

// MARK: - Seamless Chat Header

/// A living chat header that dissolves into the message surface.
/// Uses a warm gradient field instead of a hard divider, with presence
/// communicated through color atmosphere rather than explicit decoration.
@available(iOS 17.0, *)
public struct SpearChatHeader<AvatarContent: View>: View {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.colorSchemeContrast) private var contrast

  private let state: SpearChatHeaderLoadState
  private let style: SpearChatHeaderStyle
  private let copy: SpearChatHeaderCopy
  private let actions: SpearChatHeaderActions
  private let avatarBuilder: (SpearChatHeaderModel) -> AvatarContent

  public init(
    state: SpearChatHeaderLoadState,
    style: SpearChatHeaderStyle = .spear,
    copy: SpearChatHeaderCopy = .english,
    actions: SpearChatHeaderActions,
    @ViewBuilder avatar: @escaping (SpearChatHeaderModel) -> AvatarContent
  ) {
    self.state = state
    self.style = style
    self.copy = copy
    self.actions = actions
    self.avatarBuilder = avatar
  }

  public var body: some View {
    VStack(spacing: 0) {
      switch state {
      case .loading:
        SpearHeaderLoadingRow(copy: copy, actions: actions)

      case .ready(let model):
        SpearReadyHeader(
          model: model,
          style: style,
          copy: copy,
          actions: actions,
          avatarContent: avatarBuilder(model)
        )
        .id(model.id)

      case .unavailable(let title, let retryTitle):
        SpearHeaderUnavailableRow(
          title: title,
          retryTitle: retryTitle,
          copy: copy,
          brandColor: style.brandColor,
          actions: actions
        )
      }
    }
    .padding(.top, safeAreaTopInset)
    .background(seamlessBackground.ignoresSafeArea(.container, edges: .top))
    .accessibilityIdentifier(SpearChatHeaderAccessibilityID.root)
  }

  /// Returns the top safe area inset so content stays below the status bar
  /// while the background extends beneath it.
  private var safeAreaTopInset: CGFloat {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    return scene?.keyWindow?.safeAreaInsets.top ?? 0
  }

  /// The seamless gradient dissolve — replaces the hard divider with a
  /// warm gradient that fades into the conversation background.
  private var seamlessBackground: some View {
    Group {
      if reduceTransparency {
        // Accessibility: opaque surface with subtle tint
        Color(uiColor: .systemBackground)
          .overlay(alignment: .bottom) {
            Rectangle()
              .fill(Color.primary.opacity(contrast == .increased ? 0.12 : 0.04))
              .frame(height: 1)
          }
      } else {
        ZStack {
          // Base material for navigation-level context
          Rectangle().fill(.bar)

          // Warm atmosphere gradient that dissolves downward
          LinearGradient(
            stops: gradientStops,
            startPoint: .top,
            endPoint: .bottom
          )
        }
      }
    }
  }

  private var gradientStops: [Gradient.Stop] {
    let brandTint = style.brandColor

    if colorScheme == .dark {
      return [
        .init(color: brandTint.opacity(0.06), location: 0),
        .init(color: brandTint.opacity(0.03), location: 0.5),
        .init(color: .clear, location: 1.0),
      ]
    } else {
      return [
        .init(color: brandTint.opacity(0.04), location: 0),
        .init(color: brandTint.opacity(0.02), location: 0.6),
        .init(color: .clear, location: 1.0),
      ]
    }
  }
}

// MARK: - Default Avatar Convenience

@available(iOS 17.0, *)
extension SpearChatHeader where AvatarContent == SpearDefaultAvatarContent {
  public init(
    state: SpearChatHeaderLoadState,
    style: SpearChatHeaderStyle = .spear,
    copy: SpearChatHeaderCopy = .english,
    actions: SpearChatHeaderActions
  ) {
    self.init(
      state: state,
      style: style,
      copy: copy,
      actions: actions
    ) { model in
      SpearDefaultAvatarContent(
        fallback: model.avatarFallback,
        brandColor: style.brandColor
      )
    }
  }
}
