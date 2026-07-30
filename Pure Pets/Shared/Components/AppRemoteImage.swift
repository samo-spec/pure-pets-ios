import SwiftUI
import UIKit
import Kingfisher

/// The single SwiftUI owner for remote-image retrieval, processing, caching,
/// placeholders, retry, transitions, and cancellation.
struct AppRemoteImage: View {
    let url: URL?
    let cacheKey: String?
    let displaySize: CGSize?
    let contentMode: SwiftUI.ContentMode

    private let retryCount: Int
    private let fadeDuration: TimeInterval
    private let showsRetryAction: Bool
    private let loadingPlaceholder: AnyView
    private let failurePlaceholder: AnyView
    private let onImageLoaded: ((UIImage) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var retryID = UUID()

    init(
        url: URL?,
        cacheKey: String? = nil,
        displaySize: CGSize? = nil,
        contentMode: SwiftUI.ContentMode = .fill,
        retryCount: Int = 2,
        fadeDuration: TimeInterval = 0.2,
        showsRetryAction: Bool = true,
        onImageLoaded: ((UIImage) -> Void)? = nil
    ) {
        self.init(
            resolvedURL: Self.normalized(url),
            cacheKey: cacheKey,
            displaySize: displaySize,
            contentMode: contentMode,
            retryCount: retryCount,
            fadeDuration: fadeDuration,
            showsRetryAction: showsRetryAction,
            onImageLoaded: onImageLoaded,
            loadingPlaceholder: AnyView(Self.defaultLoadingPlaceholder),
            failurePlaceholder: AnyView(Self.defaultFailurePlaceholder)
        )
    }

    init(
        urlString: String?,
        cacheKey: String? = nil,
        displaySize: CGSize? = nil,
        contentMode: SwiftUI.ContentMode = .fill,
        retryCount: Int = 2,
        fadeDuration: TimeInterval = 0.2,
        showsRetryAction: Bool = true,
        onImageLoaded: ((UIImage) -> Void)? = nil
    ) {
        self.init(
            resolvedURL: Self.normalizedURL(urlString),
            cacheKey: cacheKey,
            displaySize: displaySize,
            contentMode: contentMode,
            retryCount: retryCount,
            fadeDuration: fadeDuration,
            showsRetryAction: showsRetryAction,
            onImageLoaded: onImageLoaded,
            loadingPlaceholder: AnyView(Self.defaultLoadingPlaceholder),
            failurePlaceholder: AnyView(Self.defaultFailurePlaceholder)
        )
    }

    init<LoadingPlaceholder: View, FailurePlaceholder: View>(
        url: URL?,
        cacheKey: String? = nil,
        displaySize: CGSize? = nil,
        contentMode: SwiftUI.ContentMode = .fill,
        retryCount: Int = 2,
        fadeDuration: TimeInterval = 0.2,
        showsRetryAction: Bool = true,
        onImageLoaded: ((UIImage) -> Void)? = nil,
        @ViewBuilder placeholder: () -> LoadingPlaceholder,
        @ViewBuilder failurePlaceholder: () -> FailurePlaceholder
    ) {
        self.init(
            resolvedURL: Self.normalized(url),
            cacheKey: cacheKey,
            displaySize: displaySize,
            contentMode: contentMode,
            retryCount: retryCount,
            fadeDuration: fadeDuration,
            showsRetryAction: showsRetryAction,
            onImageLoaded: onImageLoaded,
            loadingPlaceholder: AnyView(placeholder()),
            failurePlaceholder: AnyView(failurePlaceholder())
        )
    }

    init<LoadingPlaceholder: View, FailurePlaceholder: View>(
        urlString: String?,
        cacheKey: String? = nil,
        displaySize: CGSize? = nil,
        contentMode: SwiftUI.ContentMode = .fill,
        retryCount: Int = 2,
        fadeDuration: TimeInterval = 0.2,
        showsRetryAction: Bool = true,
        onImageLoaded: ((UIImage) -> Void)? = nil,
        @ViewBuilder placeholder: () -> LoadingPlaceholder,
        @ViewBuilder failurePlaceholder: () -> FailurePlaceholder
    ) {
        self.init(
            resolvedURL: Self.normalizedURL(urlString),
            cacheKey: cacheKey,
            displaySize: displaySize,
            contentMode: contentMode,
            retryCount: retryCount,
            fadeDuration: fadeDuration,
            showsRetryAction: showsRetryAction,
            onImageLoaded: onImageLoaded,
            loadingPlaceholder: AnyView(placeholder()),
            failurePlaceholder: AnyView(failurePlaceholder())
        )
    }

    private init(
        resolvedURL: URL?,
        cacheKey: String?,
        displaySize: CGSize?,
        contentMode: SwiftUI.ContentMode,
        retryCount: Int,
        fadeDuration: TimeInterval,
        showsRetryAction: Bool,
        onImageLoaded: ((UIImage) -> Void)?,
        loadingPlaceholder: AnyView,
        failurePlaceholder: AnyView
    ) {
        self.url = resolvedURL
        self.cacheKey = Self.normalizedString(cacheKey)
        self.displaySize = Self.normalized(displaySize)
        self.contentMode = contentMode
        self.retryCount = max(0, retryCount)
        self.fadeDuration = max(0, fadeDuration)
        self.showsRetryAction = showsRetryAction
        self.onImageLoaded = onImageLoaded
        self.loadingPlaceholder = loadingPlaceholder
        self.failurePlaceholder = failurePlaceholder
    }

    @ViewBuilder
    var body: some View {
        if let resource {
            KFImage(source: resource.convertToSource())
                .placeholder { loadingPlaceholder }
                .onFailureView { retryableFailurePlaceholder }
                .setProcessor(processor)
                .scaleFactor(UIScreen.main.scale)
                .cacheOriginalImage()
                .loadDiskFileSynchronously(false)
                .retry(maxCount: retryCount, interval: .seconds(1))
                .fade(duration: reduceMotion ? 0 : fadeDuration)
                .cancelOnDisappear(true)
                .onSuccess { result in
                    onImageLoaded?(result.image)
                }
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: contentMode)
                .id(loadIdentity)
        } else {
            failurePlaceholder
        }
    }

    private var resource: KF.ImageResource? {
        guard let url else { return nil }
        return KF.ImageResource(
            downloadURL: url,
            cacheKey: cacheKey ?? url.absoluteString
        )
    }

    private var processor: any ImageProcessor {
        guard let displaySize else {
            return DefaultImageProcessor.default
        }
        return DownsamplingImageProcessor(size: displaySize)
    }

    private var loadIdentity: String {
        "\(url?.absoluteString ?? "invalid")|\(cacheKey ?? "")|\(retryID.uuidString)"
    }

    @ViewBuilder
    private var retryableFailurePlaceholder: some View {
        if showsRetryAction {
            Button {
                retryID = UUID()
            } label: {
                failurePlaceholder
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                Text(NSLocalizedString("Retry", comment: "Retry loading image"))
            )
            .accessibilityHint(
                Text(
                    NSLocalizedString(
                        "load_error_retry",
                        comment: "Image loading retry hint"
                    )
                )
            )
        } else {
            failurePlaceholder
        }
    }

    private static var defaultLoadingPlaceholder: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            ProgressView()
                .accessibilityLabel(
                    Text(
                        NSLocalizedString(
                            "loading_images",
                            comment: "Remote image loading state"
                        )
                    )
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static var defaultFailurePlaceholder: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static func normalized(_ url: URL?) -> URL? {
        guard let url else { return nil }
        guard let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return nil
        }
        return url
    }

    private static func normalizedURL(_ urlString: String?) -> URL? {
        guard let value = normalizedString(urlString),
              let url = URL(string: value) else {
            return nil
        }
        return normalized(url)
    }

    private static func normalizedString(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func normalized(_ size: CGSize?) -> CGSize? {
        guard let size, size.width > 0, size.height > 0 else {
            return nil
        }
        return size
    }
}

/// Shared imperative access for existing UIKit surfaces that consume the same
/// Kingfisher cache and request policy as ``AppRemoteImage``.
final class AppRemoteImageTask {
    fileprivate var task: DownloadTask?

    func cancel() {
        task?.cancel()
        task = nil
    }
}

enum AppRemoteImagePipeline {
    @discardableResult
    static func load(
        urlString: String?,
        cacheKey: String? = nil,
        displaySize: CGSize? = nil,
        retryCount: Int = 2,
        completion: @escaping (UIImage?) -> Void
    ) -> AppRemoteImageTask? {
        guard let url = normalizedURL(urlString) else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return nil
        }

        let resource = KF.ImageResource(
            downloadURL: url,
            cacheKey: normalized(cacheKey) ?? url.absoluteString
        )
        var options: KingfisherOptionsInfo = [
            .scaleFactor(UIScreen.main.scale),
            .cacheOriginalImage,
            .retryStrategy(
                DelayRetryStrategy(
                    maxRetryCount: max(0, retryCount),
                    retryInterval: .seconds(1)
                )
            )
        ]
        if let displaySize, displaySize.width > 0, displaySize.height > 0 {
            options.append(
                .processor(DownsamplingImageProcessor(size: displaySize))
            )
        }

        let request = AppRemoteImageTask()
        request.task = KingfisherManager.shared.retrieveImage(
            with: resource,
            options: options
        ) { result in
            DispatchQueue.main.async {
                completion(try? result.get().image)
            }
        }
        return request
    }

    private static func normalizedURL(_ value: String?) -> URL? {
        guard let value = normalized(value),
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return nil
        }
        return url
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !value.isEmpty else {
            return nil
        }
        return value
    }
}
