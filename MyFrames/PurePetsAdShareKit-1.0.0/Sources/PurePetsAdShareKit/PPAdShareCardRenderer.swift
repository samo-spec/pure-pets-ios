#if canImport(SwiftUI) && canImport(UIKit)
  import SwiftUI
  import UIKit

  @available(iOS 17.0, *)
  public final class PPAdShareCardRenderer {
    private let fileStore: PPAdShareFileStore

    public init(fileStore: PPAdShareFileStore = PPAdShareFileStore()) {
      self.fileStore = fileStore
    }

    @MainActor
    public func render(
      payload: PPAdSharePayload,
      listingImage: UIImage,
      configuration: PPAdShareConfiguration,
      copy: PPAdShareCopy
    ) throws -> URL {
      let card = PPAdShareCard(
        payload: payload,
        listingImage: listingImage,
        configuration: configuration,
        copy: copy
      )
      let renderer = ImageRenderer(content: card)
      renderer.scale = 1
      renderer.isOpaque = true
      renderer.proposedSize = ProposedViewSize(
        width: configuration.cardSize.width,
        height: configuration.cardSize.height
      )

      guard let image = renderer.uiImage,
        let data = image.jpegData(
          compressionQuality: configuration.jpegQuality
        )
      else {
        throw PPAdShareError.cardRenderFailed
      }

      return try fileStore.writeJPEG(data, advertisementID: payload.id)
    }

    public func removeTemporaryFile(at url: URL) {
      fileStore.removeFile(at: url)
    }

    public func removeExpiredTemporaryFiles(
      olderThan maximumAge: TimeInterval = 24 * 60 * 60
    ) {
      fileStore.removeFiles(olderThan: maximumAge)
    }
  }
#endif
