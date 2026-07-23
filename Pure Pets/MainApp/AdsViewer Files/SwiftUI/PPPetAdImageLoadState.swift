import UIKit

enum PPPetAdImageLoadState {
    case idle
    case loading(placeholder: UIImage?)
    case loaded(UIImage)
    case failed
}
