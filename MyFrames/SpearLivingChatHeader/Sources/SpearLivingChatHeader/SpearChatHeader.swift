import SwiftUI
import UIKit

// MARK: - Conversation Header

/// One conversation surface, with identity first and contextual actions below.
/// Its height belongs to content; the host retains transcript and route ownership.
@available(iOS 15.0, *)
public struct SpearChatHeader<AvatarContent: View>: View {
  @Environment(\.colorSchemeContrast) private var contrast

  private let state: SpearChatHeaderLoadState
  private let style: SpearChatHeaderStyle
  private let copy: SpearChatHeaderCopy
  private let actions: SpearChatHeaderActions
  private let onExpansionChanged: (Bool) -> Void
  private let contextThumbnailBuilder: (URL) -> AnyView
  private let avatarBuilder: (SpearChatHeaderModel) -> AvatarContent

  public init(
    state: SpearChatHeaderLoadState,
    style: SpearChatHeaderStyle = .spear,
    copy: SpearChatHeaderCopy = .english,
    actions: SpearChatHeaderActions,
    onExpansionChanged: @escaping (Bool) -> Void = { _ in },
    contextThumbnail: @escaping (URL) -> AnyView = { _ in AnyView(EmptyView()) },
    @ViewBuilder avatar: @escaping (SpearChatHeaderModel) -> AvatarContent
  ) {
    self.state = state
    self.style = style
    self.copy = copy
    self.actions = actions
    self.onExpansionChanged = onExpansionChanged
    self.contextThumbnailBuilder = contextThumbnail
    self.avatarBuilder = avatar
  }

  public var body: some View {
    headerContent
      .frame(maxWidth: SpearHeaderLayout.maximumContentWidth)
      .frame(maxWidth: .infinity)
      // The content owns intrinsic header height. Keeping the Color field in
      // a background prevents it from greedily competing with the transcript
      // for the host's remaining vertical proposal.
      .background {
        headerBackground
          .ignoresSafeArea(.container, edges: .top)
      }
      .accessibilityIdentifier(SpearChatHeaderAccessibilityID.root)
  }

  @ViewBuilder
  private var headerContent: some View {
    switch state {
    case .loading:
      SpearHeaderLoadingRow(copy: copy, actions: actions)

    case .ready(let model):
      SpearReadyHeader(
        model: model,
        style: style,
        copy: copy,
        actions: actions,
        onExpansionChanged: onExpansionChanged,
        contextThumbnail: contextThumbnailBuilder,
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

  /// An opaque semantic field also serves Reduce Transparency. Color is reserved
  /// for real trust, presence, and actions instead of painting the entire header.
  private var headerBackground: some View {
    style.mainBackgroundColor
      .overlay(alignment: .bottom) {
        Color.primary.opacity(contrast == .increased ? 0.24 : 0.08)
          .frame(height: contrast == .increased ? 1.5 : 0.5)
      }
  }
}

// MARK: - Default Avatar Convenience

@available(iOS 15.0, *)
extension SpearChatHeader where AvatarContent == SpearDefaultAvatarContent {
  public init(
    state: SpearChatHeaderLoadState,
    style: SpearChatHeaderStyle = .spear,
    copy: SpearChatHeaderCopy = .english,
    actions: SpearChatHeaderActions,
    onExpansionChanged: @escaping (Bool) -> Void = { _ in },
    contextThumbnail: @escaping (URL) -> AnyView = { _ in AnyView(EmptyView()) }
  ) {
    self.init(
      state: state,
      style: style,
      copy: copy,
      actions: actions,
      onExpansionChanged: onExpansionChanged,
      contextThumbnail: contextThumbnail
    ) { model in
      SpearDefaultAvatarContent(
        fallback: model.avatarFallback,
        brandColor: style.brandColor
      )
    }
  }
}
