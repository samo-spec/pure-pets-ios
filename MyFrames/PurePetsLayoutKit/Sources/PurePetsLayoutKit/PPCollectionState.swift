import Foundation

public enum PPCollectionState: Equatable, Sendable {
    case loading
    case content
    case empty(title: String, message: String, systemImage: String)
    case error(title: String, message: String, retryTitle: String)
}
