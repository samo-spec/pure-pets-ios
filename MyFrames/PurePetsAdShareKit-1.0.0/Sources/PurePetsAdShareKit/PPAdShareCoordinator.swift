#if canImport(UIKit) && canImport(LinkPresentation)
  import UIKit

  @available(iOS 17.0, *)
  public final class PPAdShareSession: Identifiable {
    public let id = UUID()
    public let advertisementID: String
    public let imageFileURL: URL

    internal let activityItems: [Any]

    internal init(
      advertisementID: String,
      imageFileURL: URL,
      activityItems: [Any]
    ) {
      self.advertisementID = advertisementID
      self.imageFileURL = imageFileURL
      self.activityItems = activityItems
    }
  }

  @available(iOS 17.0, *)
  public final class PPAdShareCoordinator {
    public let configuration: PPAdShareConfiguration

    private let imageLoader: any PPAdShareImageLoading
    private let renderer: PPAdShareCardRenderer
    private let analytics: any PPAdShareAnalytics

    public init(
      configuration: PPAdShareConfiguration = .purePets,
      imageLoader: any PPAdShareImageLoading = PPAdShareImageLoader(),
      renderer: PPAdShareCardRenderer = PPAdShareCardRenderer(),
      analytics: any PPAdShareAnalytics = PPNoopAdShareAnalytics.shared
    ) {
      self.configuration = configuration
      self.imageLoader = imageLoader
      self.renderer = renderer
      self.analytics = analytics
    }

    @MainActor
    public func prepare(
      payload: PPAdSharePayload,
      imageSource: PPAdShareImageSource? = nil,
      copy: PPAdShareCopy
    ) async throws -> PPAdShareSession {
      try Task.checkCancellation()
      renderer.removeExpiredTemporaryFiles()
      analytics.record(.preparationStarted(advertisementID: payload.id))

      do {
        let resolvedSource = try resolveImageSource(
          explicitSource: imageSource,
          payload: payload
        )
        let image = try await imageLoader.load(
          resolvedSource,
          maximumDownloadBytes: configuration.maximumDownloadBytes,
          maximumPixelSize: configuration.maximumImagePixelSize
        )
        try Task.checkCancellation()
        let imageFileURL = try renderer.render(
          payload: payload,
          listingImage: image,
          configuration: configuration,
          copy: copy
        )
        do {
          try Task.checkCancellation()
        } catch {
          renderer.removeTemporaryFile(at: imageFileURL)
          throw error
        }

        let message = PPAdShareMessageFormatter(copy: copy).message(for: payload)
        let itemSource = PPAdShareItemSource(
          message: message,
          payload: payload,
          previewImageURL: imageFileURL
        )

        return PPAdShareSession(
          advertisementID: payload.id,
          imageFileURL: imageFileURL,
          activityItems: [imageFileURL, itemSource]
        )
      } catch {
        analytics.record(
          .preparationFailed(
            advertisementID: payload.id,
            errorCode: Self.errorCode(for: error)
          )
        )
        throw error
      }
    }

    @MainActor
    public func makeActivityViewController(
      for session: PPAdShareSession,
      onCompletion: @escaping @MainActor () -> Void = {}
    ) -> UIActivityViewController {
      let controller = UIActivityViewController(
        activityItems: session.activityItems,
        applicationActivities: nil
      )
      controller.excludedActivityTypes = configuration.excludedActivityTypes
      controller.allowsProminentActivity = true
      controller.completionWithItemsHandler = {
        [weak self] activityType, completed, _, _ in
        Task { @MainActor in
          guard let self else {
            onCompletion()
            return
          }

          self.analytics.record(
            .shareCompleted(
              advertisementID: session.advertisementID,
              activityType: activityType?.rawValue,
              completed: completed
            )
          )
          if self.configuration.cleansTemporaryFileAfterSharing {
            self.renderer.removeTemporaryFile(at: session.imageFileURL)
          }
          onCompletion()
        }
      }
      return controller
    }

    @MainActor
    public func present(
      payload: PPAdSharePayload,
      imageSource: PPAdShareImageSource? = nil,
      copy: PPAdShareCopy,
      from viewController: UIViewController,
      sourceView: UIView? = nil,
      onCompletion: @escaping @MainActor () -> Void = {}
    ) async throws {
      let session = try await prepare(
        payload: payload,
        imageSource: imageSource,
        copy: copy
      )
      let controller = makeActivityViewController(
        for: session,
        onCompletion: onCompletion
      )

      if let popover = controller.popoverPresentationController,
         let anchorView = sourceView ?? viewController.view {
        popover.sourceView = anchorView
        popover.sourceRect =
          sourceView?.bounds
          ?? CGRect(
            x: anchorView.bounds.midX,
            y: anchorView.bounds.midY,
            width: 1,
            height: 1
          )
        popover.permittedArrowDirections = sourceView == nil ? [] : .any
      }

      viewController.present(controller, animated: true)
    }

    @MainActor
    public func discard(_ session: PPAdShareSession) {
      renderer.removeTemporaryFile(at: session.imageFileURL)
    }

    private func resolveImageSource(
      explicitSource: PPAdShareImageSource?,
      payload: PPAdSharePayload
    ) throws -> PPAdShareImageSource {
      if let explicitSource {
        return explicitSource
      }
      if let imageURL = payload.imageURL {
        return .remote(imageURL)
      }
      throw PPAdShareError.imageUnavailable
    }

    private static func errorCode(for error: Error) -> String {
      if error is CancellationError {
        return "cancelled"
      }
      if let shareError = error as? PPAdShareError {
        return String(describing: shareError)
      }
      return "unknown"
    }
  }
#endif
