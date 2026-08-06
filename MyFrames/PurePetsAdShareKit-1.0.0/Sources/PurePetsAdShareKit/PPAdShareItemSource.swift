#if canImport(UIKit) && canImport(LinkPresentation)
  import LinkPresentation
  import UIKit

  @available(iOS 17.0, *)
  internal final class PPAdShareItemSource: NSObject, UIActivityItemSource {
    private let message: String
    private let payload: PPAdSharePayload
    private let previewImageURL: URL

    init(
      message: String,
      payload: PPAdSharePayload,
      previewImageURL: URL
    ) {
      self.message = message
      self.payload = payload
      self.previewImageURL = previewImageURL
    }

    func activityViewControllerPlaceholderItem(
      _ activityViewController: UIActivityViewController
    ) -> Any {
      message
    }

    func activityViewController(
      _ activityViewController: UIActivityViewController,
      itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
      message
    }

    func activityViewController(
      _ activityViewController: UIActivityViewController,
      subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
      payload.title
    }

    func activityViewControllerLinkMetadata(
      _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
      let metadata = LPLinkMetadata()
      metadata.originalURL = payload.canonicalURL
      metadata.url = payload.canonicalURL
      metadata.title = payload.title
      metadata.imageProvider = NSItemProvider(contentsOf: previewImageURL)
      return metadata
    }
  }
#endif
