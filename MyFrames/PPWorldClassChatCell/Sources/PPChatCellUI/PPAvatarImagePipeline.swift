#if canImport(SwiftUI) && canImport(UIKit) && canImport(ImageIO)
import Foundation
import ImageIO
import SwiftUI
import UIKit

public struct PPAvatarImage: @unchecked Sendable {
    public let value: UIImage

    public init(value: UIImage) {
        self.value = value
    }
}

public protocol PPAvatarImageProviding: Sendable {
    func image(
        for url: URL,
        targetSize: CGSize,
        scale: CGFloat
    ) async throws -> PPAvatarImage
}

public enum PPAvatarImagePipelineError: Error {
    case invalidResponse
    case unsupportedImage
}

/// Memory-cached, request-coalesced, thumbnail-downsampling avatar pipeline.
/// View-owned tasks may be cancelled safely; shared in-flight work is retained for
/// other rows requesting the same avatar and then cached for future reuse.
public final class PPAvatarImagePipeline: PPAvatarImageProviding, @unchecked Sendable {
    public static let shared = PPAvatarImagePipeline()

    private let session: URLSession
    private let cache = NSCache<NSString, UIImage>()
    private struct InFlightEntry {
        let token: UUID
        let task: Task<PPAvatarImage, Error>
    }

    private let lock = NSLock()
    private var inFlight: [String: InFlightEntry] = [:]

    public init(
        session: URLSession = .shared,
        memoryLimitInBytes: Int = 24 * 1_024 * 1_024,
        itemLimit: Int = 240
    ) {
        self.session = session
        cache.totalCostLimit = max(4 * 1_024 * 1_024, memoryLimitInBytes)
        cache.countLimit = max(32, itemLimit)
    }

    public func image(
        for url: URL,
        targetSize: CGSize,
        scale: CGFloat
    ) async throws -> PPAvatarImage {
        try Task.checkCancellation()

        let normalizedScale = max(1, scale)
        let key = cacheKey(url: url, targetSize: targetSize, scale: normalizedScale)

        if let cached = cache.object(forKey: key as NSString) {
            return PPAvatarImage(value: cached)
        }

        let entry: InFlightEntry = withLock {
            if let existing = inFlight[key] {
                return existing
            }

            let token = UUID()
            let created = Task<PPAvatarImage, Error> { [session] in
                try Task.checkCancellation()
                let (data, response) = try await session.data(from: url)
                try Task.checkCancellation()

                if let http = response as? HTTPURLResponse,
                   !(200...299).contains(http.statusCode) {
                    throw PPAvatarImagePipelineError.invalidResponse
                }

                guard let image = Self.downsample(
                    data: data,
                    targetSize: targetSize,
                    scale: normalizedScale
                ) else {
                    throw PPAvatarImagePipelineError.unsupportedImage
                }

                return PPAvatarImage(value: image)
            }

            let entry = InFlightEntry(token: token, task: created)
            inFlight[key] = entry
            return entry
        }

        do {
            let result = try await entry.task.value
            let pixelWidth = max(1, Int(result.value.size.width * result.value.scale))
            let pixelHeight = max(1, Int(result.value.size.height * result.value.scale))
            cache.setObject(
                result.value,
                forKey: key as NSString,
                cost: pixelWidth * pixelHeight * 4
            )
            removeInFlightEntry(forKey: key, token: entry.token)
            try Task.checkCancellation()
            return result
        } catch {
            removeInFlightEntry(forKey: key, token: entry.token)
            throw error
        }
    }

    public func removeAllCachedImages() {
        cache.removeAllObjects()
        withLock {
            inFlight.values.forEach { $0.task.cancel() }
            inFlight.removeAll()
        }
    }


    private func removeInFlightEntry(forKey key: String, token: UUID) {
        withLock {
            guard inFlight[key]?.token == token else { return }
            inFlight[key] = nil
        }
    }

    private func cacheKey(url: URL, targetSize: CGSize, scale: CGFloat) -> String {
        let width = Int((targetSize.width * scale).rounded(.up))
        let height = Int((targetSize.height * scale).rounded(.up))
        return "\(url.absoluteString)|\(width)x\(height)"
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }

    private static func downsample(
        data: Data,
        targetSize: CGSize,
        scale: CGFloat
    ) -> UIImage? {
        let sourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }

        let maxDimension = max(targetSize.width, targetSize.height) * scale
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxDimension.rounded(.up)))
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

@MainActor
final class PPAvatarImageLoader: ObservableObject {
    enum State {
        case empty
        case loading
        case success(UIImage)
        case failure
    }

    @Published private(set) var state: State = .empty

    private let pipeline: any PPAvatarImageProviding
    private var task: Task<Void, Never>?
    private var requestKey: String?

    init(pipeline: any PPAvatarImageProviding) {
        self.pipeline = pipeline
    }

    deinit {
        task?.cancel()
    }

    func load(url: URL?, targetSize: CGSize, scale: CGFloat) {
        guard let url else {
            cancel()
            state = .empty
            return
        }

        let key = "\(url.absoluteString)|\(targetSize.width)x\(targetSize.height)|\(scale)"
        guard requestKey != key else { return }

        task?.cancel()
        requestKey = key
        state = .loading

        task = Task { [weak self, pipeline] in
            do {
                let result = try await pipeline.image(
                    for: url,
                    targetSize: targetSize,
                    scale: scale
                )
                guard !Task.isCancelled else { return }
                self?.state = .success(result.value)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.state = .failure
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        requestKey = nil
    }
}
#endif
