import SwiftUI

public enum PPPremiumCardMaterial: Sendable {
    /// Opaque system surface. Recommended for long, fast-scrolling feeds.
    case performance
    /// Native material. Recommended for short editorial/carousel surfaces.
    case material
}

public struct PPPremiumCardSurface<Content: View>: View {
    private let cornerRadius: CGFloat
    private let material: PPPremiumCardMaterial
    private let content: Content

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(
        cornerRadius: CGFloat = 22,
        material: PPPremiumCardMaterial = .performance,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.material = material
        self.content = content()
    }

    public var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundStyle)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.75)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.18 : 0.075),
                radius: 9,
                x: 0,
                y: 4
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .ppPressFeedback()
    }

    private var backgroundStyle: AnyShapeStyle {
        guard material == .material, !reduceTransparency else {
            return AnyShapeStyle(Color(uiColor: .secondarySystemBackground))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    private var borderColor: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.065)
    }
}
