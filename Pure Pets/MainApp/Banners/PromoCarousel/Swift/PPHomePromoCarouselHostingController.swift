import SwiftUI
import UIKit

@objcMembers
final class PPHomePromoCarouselHostingController: UIViewController {
  weak var actionHandler: PPHomePromoCarouselActionHandling?

  private let store = PPHomePromoCarouselStore()
  private var hostingController: UIHostingController<PPHomePromoCarouselView>?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    installHostingController()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    store.start()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    store.stop()
  }

  func reload() {
    store.reload()
  }

  func stopListening() {
    store.stop()
  }

  private func installHostingController() {
    let rootView = PPHomePromoCarouselView(store: store) { [weak self] action in
      self?.forward(action)
    }

    let hostingController = UIHostingController(rootView: rootView)
    hostingController.view.backgroundColor = .clear
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false

    addChild(hostingController)
    view.addSubview(hostingController.view)

    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    hostingController.didMove(toParent: self)
    self.hostingController = hostingController
  }

  private func forward(_ action: PPPromoAction) {
    actionHandler?.homePromoCarouselDidRequestAction(
      action.rawAction,
      value: action.value,
      cardID: action.cardID,
      source: action.source.rawValue
    )
  }
}
