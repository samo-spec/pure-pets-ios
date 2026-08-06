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
    .background(seamlessBackground.ignoresSafeArea(.container, edges: .top))
    .accessibilityIdentifier(SpearChatHeaderAccessibilityID.root)
  }

  /// The seamless gradient dissolve — replaces the hard divider with a
  /// non-brand cool atmosphere that fades into the conversation background.
  /// The brand color is intentionally kept out of the background so the header
  /// dissolves into the messaging aurora instead of painting the brand hue.
  private var seamlessBackground: some View {
    Group {
      if reduceTransparency {
        Color(uiColor: .systemBackground)
          .overlay {
            LinearGradient(
              colors: [SpearHeaderAtmosphere.indigo.opacity(0.06), .clear],
              startPoint: .top,
              endPoint: .bottom
            )
          }
          .overlay(alignment: .bottom) {
            Rectangle()
              .fill(Color.primary.opacity(contrast == .increased ? 0.16 : 0.07))
              .frame(height: 1)
          }
      } else {
        ZStack {
          Rectangle().fill(.bar)

          LinearGradient(
            stops: gradientStops,
            startPoint: .top,
            endPoint: .bottom
          )

          RadialGradient(
            colors: [
              SpearHeaderAtmosphere.indigo.opacity(colorScheme == .dark ? 0.12 : 0.10),
              SpearHeaderAtmosphere.indigo.opacity(colorScheme == .dark ? 0.04 : 0.025),
              .clear,
            ],
            center: .top,
            startRadius: 0,
            endRadius: 250
          )

          RadialGradient(
            colors: [
              SpearHeaderAtmosphere.aqua.opacity(colorScheme == .dark ? 0.06 : 0.04),
              .clear,
            ],
            center: .topTrailing,
            startRadius: 0,
            endRadius: 210
          )

          LinearGradient(
            colors: [
              Color.white.opacity(colorScheme == .dark ? 0.025 : 0.26),
              .clear,
            ],
            startPoint: .top,
            endPoint: .center
          )
        }
        .overlay(alignment: .bottom) {
          LinearGradient(
            colors: [
              .clear,
              SpearHeaderAtmosphere.indigo.opacity(contrast == .increased ? 0.20 : 0.09),
              .clear,
            ],
            startPoint: .leading,
            endPoint: .trailing
          )
          .frame(height: contrast == .increased ? 1.5 : 0.75)
        }
      }
    }
  }

  private var gradientStops: [Gradient.Stop] {
    let atmosphere = SpearHeaderAtmosphere.indigo

    if colorScheme == .dark {
      return [
        .init(color: atmosphere.opacity(0.10), location: 0),
        .init(color: atmosphere.opacity(0.045), location: 0.52),
        .init(color: .clear, location: 1.0),
      ]
    } else {
      return [
        .init(color: atmosphere.opacity(0.075), location: 0),
        .init(color: atmosphere.opacity(0.025), location: 0.62),
        .init(color: .clear, location: 1.0),
      ]
    }
  }
}

// MARK: - Non-brand header atmosphere (never the brand berry)
//
// Cool twilight hues that match the messaging aurora background so the header
// reads as one continuous surface. Kept separate from the configurable
// `style.brandColor`, which still drives identity/action accents. Declared
// outside the generic `SpearChatHeader` because Swift forbids stored static
// properties on generic types.
internal enum SpearHeaderAtmosphere {
  /// Periwinkle indigo `#5C6FC4`.
  static let indigo = Color(
    red: 92.0 / 255.0,
    green: 111.0 / 255.0,
    blue: 196.0 / 255.0
  )

  /// Cool aqua `#4FB6C9`.
  static let aqua = Color(
    red: 79.0 / 255.0,
    green: 182.0 / 255.0,
    blue: 201.0 / 255.0
  )
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
