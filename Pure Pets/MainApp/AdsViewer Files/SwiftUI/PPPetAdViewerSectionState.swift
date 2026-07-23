import Foundation

enum PPPetAdViewerSectionState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case offline(message: String)
    case failed(message: String)
}
