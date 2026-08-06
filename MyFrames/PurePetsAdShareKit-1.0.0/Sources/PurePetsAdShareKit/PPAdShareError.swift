import Foundation

public enum PPAdShareError: Error, Equatable, Sendable {
  case invalidIdentifier
  case identifierTooLong
  case invalidTitle
  case titleTooLong
  case invalidCanonicalURL
  case invalidImageURL
  case imageUnavailable
  case imageResponseInvalid
  case imageTooLarge
  case imageDecodeFailed
  case cardRenderFailed
  case temporaryFileWriteFailed
  case presentationUnavailable
}

extension PPAdShareError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .invalidIdentifier:
      return "The advertisement has no valid public identifier."
    case .identifierTooLong:
      return "The advertisement public identifier is too long."
    case .invalidTitle:
      return "The advertisement has no valid title."
    case .titleTooLong:
      return "The advertisement title is too long to share safely."
    case .invalidCanonicalURL:
      return "The advertisement has no valid secure public web link."
    case .invalidImageURL:
      return "The advertisement has no valid secure public image link."
    case .imageUnavailable:
      return "The advertisement image is unavailable."
    case .imageResponseInvalid:
      return "The advertisement image could not be downloaded."
    case .imageTooLarge:
      return "The advertisement image is too large to share safely."
    case .imageDecodeFailed:
      return "The advertisement image could not be opened."
    case .cardRenderFailed:
      return "The advertisement share card could not be created."
    case .temporaryFileWriteFailed:
      return "The advertisement share file could not be saved."
    case .presentationUnavailable:
      return "The share sheet is unavailable right now."
    }
  }
}
