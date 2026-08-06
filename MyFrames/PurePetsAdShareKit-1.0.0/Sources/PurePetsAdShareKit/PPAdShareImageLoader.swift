#if canImport(UIKit) && canImport(ImageIO)
  @preconcurrency import Foundation
  import ImageIO
  @preconcurrency import UIKit

  @available(iOS 17.0, *)
  public protocol PPAdShareImageLoading: AnyObject {
    @MainActor
    func load(
      _ source: PPAdShareImageSource,
      maximumDownloadBytes: Int,
      maximumPixelSize: CGFloat
    ) async throws -> UIImage
  }

  @available(iOS 17.0, *)
  public final class PPAdShareImageLoader: PPAdShareImageLoading {
    private let sessionConfiguration: URLSessionConfiguration
    private let decodeQueue = DispatchQueue(
      label: "com.purepets.adshare.image-decode",
      qos: .userInitiated
    )

    public init(configuration: URLSessionConfiguration = .default) {
      sessionConfiguration =
        configuration.copy() as? URLSessionConfiguration
        ?? .default
    }

    @MainActor
    public func load(
      _ source: PPAdShareImageSource,
      maximumDownloadBytes: Int,
      maximumPixelSize: CGFloat
    ) async throws -> UIImage {
      switch source {
      case .image(let image):
        guard image.size.width > 0, image.size.height > 0 else {
          throw PPAdShareError.imageDecodeFailed
        }
        return image

      case .data(let data):
        guard data.count <= maximumDownloadBytes else {
          throw PPAdShareError.imageTooLarge
        }
        return try await decode(data, maximumPixelSize: maximumPixelSize)

      case .remote(let url):
        guard url.ppIsSecurePublicURL else {
          throw PPAdShareError.imageUnavailable
        }

        var request = URLRequest(
          url: url,
          cachePolicy: .returnCacheDataElseLoad,
          timeoutInterval: 30
        )
        request.setValue("image/*", forHTTPHeaderField: "Accept")

        let downloader = PPAdShareBoundedImageDownloader(
          configuration: sessionConfiguration,
          maximumBytes: maximumDownloadBytes
        )
        let data = try await downloader.download(request)
        return try await decode(data, maximumPixelSize: maximumPixelSize)
      }
    }

    @MainActor
    private func decode(
      _ data: Data,
      maximumPixelSize: CGFloat
    ) async throws -> UIImage {
      try await withCheckedThrowingContinuation { continuation in
        decodeQueue.async {
          guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            continuation.resume(throwing: PPAdShareError.imageDecodeFailed)
            return
          }

          let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
          ]

          guard
            let cgImage = CGImageSourceCreateThumbnailAtIndex(
              source,
              0,
              options as CFDictionary
            )
          else {
            continuation.resume(throwing: PPAdShareError.imageDecodeFailed)
            return
          }

          continuation.resume(returning: UIImage(cgImage: cgImage))
        }
      }
    }
  }

  @available(iOS 17.0, *)
  private final class PPAdShareBoundedImageDownloader:
    NSObject,
    URLSessionDataDelegate,
    @unchecked Sendable
  {
    private let configuration: URLSessionConfiguration
    private let maximumBytes: Int
    private let lock = NSLock()

    private var continuation: CheckedContinuation<Data, Error>?
    private var receivedData = Data()
    private var session: URLSession?
    private var terminalResult: Result<Data, Error>?

    init(
      configuration: URLSessionConfiguration,
      maximumBytes: Int
    ) {
      self.configuration =
        configuration.copy() as? URLSessionConfiguration
        ?? .default
      self.maximumBytes = max(1, maximumBytes)
    }

    func download(_ request: URLRequest) async throws -> Data {
      try Task.checkCancellation()
      return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
          lock.lock()
          if let terminalResult {
            lock.unlock()
            continuation.resume(with: terminalResult)
            return
          }
          self.continuation = continuation
          lock.unlock()

          let delegateQueue = OperationQueue()
          delegateQueue.name = "com.purepets.adshare.image-download"
          delegateQueue.maxConcurrentOperationCount = 1

          let session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: delegateQueue
          )
          let task = session.dataTask(with: request)

          lock.lock()
          if terminalResult != nil {
            lock.unlock()
            session.invalidateAndCancel()
            return
          }
          self.session = session
          lock.unlock()
          task.resume()
        }
      } onCancel: {
        self.complete(.failure(CancellationError()))
      }
    }

    func urlSession(
      _ session: URLSession,
      task: URLSessionTask,
      willPerformHTTPRedirection response: HTTPURLResponse,
      newRequest request: URLRequest,
      completionHandler: @escaping (URLRequest?) -> Void
    ) {
      guard request.url?.ppIsSecurePublicURL == true else {
        completionHandler(nil)
        complete(.failure(PPAdShareError.imageResponseInvalid))
        return
      }
      completionHandler(request)
    }

    func urlSession(
      _ session: URLSession,
      dataTask: URLSessionDataTask,
      didReceive response: URLResponse,
      completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
      guard let httpResponse = response as? HTTPURLResponse,
        200..<300 ~= httpResponse.statusCode
      else {
        completionHandler(.cancel)
        complete(.failure(PPAdShareError.imageResponseInvalid))
        return
      }

      if let mimeType = response.mimeType?.lowercased(),
        !mimeType.hasPrefix("image/")
      {
        completionHandler(.cancel)
        complete(.failure(PPAdShareError.imageResponseInvalid))
        return
      }

      let expectedLength = response.expectedContentLength
      if expectedLength > 0, expectedLength > Int64(maximumBytes) {
        completionHandler(.cancel)
        complete(.failure(PPAdShareError.imageTooLarge))
        return
      }

      completionHandler(.allow)
    }

    func urlSession(
      _ session: URLSession,
      dataTask: URLSessionDataTask,
      didReceive data: Data
    ) {
      lock.lock()
      guard terminalResult == nil else {
        lock.unlock()
        return
      }

      let remainingCapacity = maximumBytes - receivedData.count
      guard data.count <= remainingCapacity else {
        lock.unlock()
        dataTask.cancel()
        complete(.failure(PPAdShareError.imageTooLarge))
        return
      }

      receivedData.append(data)
      lock.unlock()
    }

    func urlSession(
      _ session: URLSession,
      task: URLSessionTask,
      didCompleteWithError error: Error?
    ) {
      if let error {
        complete(.failure(error))
      } else {
        lock.lock()
        let data = receivedData
        lock.unlock()
        complete(.success(data))
      }
    }

    private func complete(_ result: Result<Data, Error>) {
      lock.lock()
      guard terminalResult == nil else {
        lock.unlock()
        return
      }
      terminalResult = result
      let continuation = self.continuation
      self.continuation = nil
      let session = self.session
      self.session = nil
      lock.unlock()

      session?.invalidateAndCancel()
      continuation?.resume(with: result)
    }
  }
#endif
