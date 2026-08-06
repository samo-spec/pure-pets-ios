#if canImport(SwiftUI) && canImport(UIKit)
  import SwiftUI
  import UIKit

  @available(iOS 17.0, *)
  internal struct PPShareSheet: UIViewControllerRepresentable {
    let session: PPAdShareSession
    let coordinator: PPAdShareCoordinator
    let onCompletion: @MainActor () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
      coordinator.makeActivityViewController(
        for: session,
        onCompletion: onCompletion
      )
    }

    func updateUIViewController(
      _ uiViewController: UIActivityViewController,
      context: Context
    ) {}
  }
#endif
