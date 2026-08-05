import SwiftUI
import UIKit

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
    .background(headerBackground)
    .overlay(alignment: .bottom) {
      Divider()
        .opacity(contrast == .increased ? 1 : (colorScheme == .dark ? 0.55 : 0.72))
    }
    .accessibilityIdentifier(SpearChatHeaderAccessibilityID.root)
  }

  private var headerBackground: some View {
    Group {
      if reduceTransparency {
        Color(uiColor: .systemBackground)
      } else {
        Rectangle().fill(.bar)
      }
    }
  }
}

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
