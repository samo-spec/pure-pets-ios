import SwiftUI

public enum PPMediaContentMode: Sendable {
    /// Shows the complete image. This is the package default and prevents silent top/bottom cropping.
    case fit
    /// Intentionally fills and crops. Use only when the product design explicitly requires it.
    case fill
}

public struct PPAsyncMediaSurface<Placeholder: View>: View {
    public let url: URL?
    public let aspectRatio: CGFloat
    public let contentMode: PPMediaContentMode
    public let cornerRadius: CGFloat
    private let placeholder: Placeholder

    public init(
        url: URL?,
        aspectRatio: CGFloat,
        contentMode: PPMediaContentMode = .fit,
        cornerRadius: CGFloat = 18,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        self.aspectRatio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.placeholder = placeholder()
    }

    public var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .modifier(PPResolvedContentModeModifier(mode: contentMode))
                    .transition(.opacity)
            case .failure:
                ZStack {
                    Color(uiColor: .tertiarySystemFill)
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            case .empty:
                placeholder
            @unknown default:
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1 / aspectRatio, contentMode: .fit)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct PPResolvedContentModeModifier: ViewModifier {
    let mode: PPMediaContentMode

    @ViewBuilder
    func body(content: Content) -> some View {
        switch mode {
        case .fit:
            content.scaledToFit()
        case .fill:
            content.scaledToFill().clipped()
        }
    }
}
