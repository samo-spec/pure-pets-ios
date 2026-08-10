import SwiftUI
import UIKit

// MARK: - Seamless Chat Header

/// A living chat header that dissolves into the message surface.
/// The app's semantic main background owns the large color field; brand color
/// remains a quiet signal rather than becoming another painted surface.
@available(iOS 17.0, *)
public struct SpearChatHeader<AvatarContent: View>: View {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorScheme) private var colorScheme
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

  /// The canopy remains one calm surface. Live state motion stays local to the
  /// avatar and presence line, so content and layout never animate implicitly.
  private var headerBackground: some View {
    ZStack {
      style.mainBackgroundColor

      if !reduceTransparency {
        LinearGradient(
          colors: [
            Color.white.opacity(colorScheme == .dark ? 0.025 : 0.42),
            .clear,
          ],
          startPoint: .top,
          endPoint: .center
        )

        RadialGradient(
          colors: [
            style.brandColor.opacity(colorScheme == .dark ? 0.060 : 0.035),
            .clear,
          ],
          center: .topLeading,
          startRadius: 0,
          endRadius: 260
        )
      }
    }
    .overlay(alignment: .bottom) {
      Color.primary.opacity(contrast == .increased ? 0.22 : 0.060)
        .frame(height: contrast == .increased ? 2 : 1)
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
