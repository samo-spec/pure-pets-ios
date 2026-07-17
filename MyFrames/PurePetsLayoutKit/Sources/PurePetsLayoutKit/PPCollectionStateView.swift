import SwiftUI

public struct PPCollectionStateView: View {
    public let state: PPCollectionState
    public var retry: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(state: PPCollectionState, retry: (() -> Void)? = nil) {
        self.state = state
        self.retry = retry
    }

    public var body: some View {
        Group {
            switch state {
            case .loading:
                loadingView
            case .content:
                EmptyView()
            case let .empty(title, message, systemImage):
                messageView(
                    title: title,
                    message: message,
                    systemImage: systemImage,
                    actionTitle: nil
                )
            case let .error(title, message, retryTitle):
                messageView(
                    title: title,
                    message: message,
                    systemImage: "exclamationmark.triangle.fill",
                    actionTitle: retryTitle
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }

    private var loadingView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .accessibilityLabel(Text("Loading"))
            Text("Loading…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
    }

    private func messageView(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String?
    ) -> some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)

            if let actionTitle, let retry {
                Button(actionTitle, action: retry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 4)
            }
        }
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
    }
}
