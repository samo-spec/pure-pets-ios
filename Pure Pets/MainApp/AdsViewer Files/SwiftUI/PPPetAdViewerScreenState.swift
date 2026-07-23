import Foundation

enum PPPetAdViewerScreenState: Equatable {
    case loading
    case content
    case empty
    case offline(message: String)
    case failed(message: String)
}
