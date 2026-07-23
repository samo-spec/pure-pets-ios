import Foundation

enum PPPetAdViewerActionState: Equatable {
    case idle
    case working
    case succeeded(message: String)
    case failed(message: String)
}
