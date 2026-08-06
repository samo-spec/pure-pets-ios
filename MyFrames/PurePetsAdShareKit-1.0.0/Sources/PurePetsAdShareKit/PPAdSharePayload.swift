import Foundation

public struct PPAdShareAttribute: Equatable, Hashable, Identifiable, Sendable {
  public let id: String
  public let title: String

  public init(id: String, title: String) {
    self.id = id.ppShareNormalized(maximumCharacters: 128)
    self.title = title.ppShareNormalized(maximumCharacters: 80)
  }
}

public struct PPAdSharePayload: Equatable, Identifiable, Sendable {
  public let id: String
  public let title: String
  public let formattedPrice: String?
  public let location: String?
  public let shortDescription: String?
  public let attributes: [PPAdShareAttribute]
  public let imageURL: URL?
  public let canonicalURL: URL
  public let sellerDisplayName: String?

  public init(
    id: String,
    title: String,
    formattedPrice: String? = nil,
    location: String? = nil,
    shortDescription: String? = nil,
    attributes: [PPAdShareAttribute] = [],
    imageURL: URL? = nil,
    canonicalURL: URL,
    sellerDisplayName: String? = nil
  ) throws {
    let normalizedID = id.ppShareCollapsed
    guard !normalizedID.isEmpty else {
      throw PPAdShareError.invalidIdentifier
    }
    guard normalizedID.count <= 256 else {
      throw PPAdShareError.identifierTooLong
    }

    let normalizedTitle = title.ppShareCollapsed
    guard !normalizedTitle.isEmpty else {
      throw PPAdShareError.invalidTitle
    }
    guard normalizedTitle.count <= 240 else {
      throw PPAdShareError.titleTooLong
    }

    guard canonicalURL.ppIsSecurePublicURL else {
      throw PPAdShareError.invalidCanonicalURL
    }

    self.id = normalizedID
    self.title = normalizedTitle
    self.formattedPrice = formattedPrice.ppShareNonEmpty(maximumCharacters: 80)
    self.location = location.ppShareNonEmpty(maximumCharacters: 120)
    if let imageURL, !imageURL.ppIsSecurePublicURL {
      throw PPAdShareError.invalidImageURL
    }

    self.shortDescription = shortDescription.ppShareNonEmpty(maximumCharacters: 500)
    self.attributes = Self.normalizedAttributes(attributes)
    self.imageURL = imageURL
    self.canonicalURL = canonicalURL
    self.sellerDisplayName = sellerDisplayName.ppShareNonEmpty(maximumCharacters: 120)
  }

  private static func normalizedAttributes(
    _ attributes: [PPAdShareAttribute]
  ) -> [PPAdShareAttribute] {
    var seen = Set<String>()
    var result: [PPAdShareAttribute] = []

    for attribute in attributes {
      guard !attribute.id.isEmpty,
        !attribute.title.isEmpty,
        seen.insert(attribute.id).inserted
      else {
        continue
      }

      result.append(attribute)
      if result.count == 3 {
        break
      }
    }

    return result
  }
}

extension String {
  var ppShareTrimmed: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var ppShareCollapsed: String {
    components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  func ppShareNormalized(maximumCharacters: Int) -> String {
    let value = ppShareCollapsed
    guard value.count > maximumCharacters else { return value }
    let end = value.index(value.startIndex, offsetBy: maximumCharacters)
    return String(value[..<end])
  }
}

extension Optional where Wrapped == String {
  func ppShareNonEmpty(maximumCharacters: Int) -> String? {
    guard let value = self?.ppShareNormalized(maximumCharacters: maximumCharacters),
      !value.isEmpty
    else {
      return nil
    }
    return value
  }
}

extension URL {
  var ppIsSecurePublicURL: Bool {
    guard scheme?.lowercased() == "https",
      let rawHost = host,
      !rawHost.isEmpty,
      user == nil,
      password == nil
    else {
      return false
    }

    let normalizedHost =
      rawHost
      .lowercased()
      .trimmingCharacters(in: CharacterSet(charactersIn: "."))

    guard !normalizedHost.isEmpty,
      !normalizedHost.ppIsLocalHostname,
      !normalizedHost.ppIsPrivateOrReservedIPAddress
    else {
      return false
    }

    return true
  }
}

extension String {
  fileprivate var ppIsLocalHostname: Bool {
    if self == "localhost" || hasSuffix(".localhost") {
      return true
    }

    let blockedSuffixes = [".local", ".internal", ".lan", ".home"]
    if blockedSuffixes.contains(where: hasSuffix) {
      return true
    }

    return !contains(".") && !contains(":")
  }

  fileprivate var ppIsPrivateOrReservedIPAddress: Bool {
    if contains(":") {
      let value = lowercased().split(separator: "%", maxSplits: 1).first.map(String.init) ?? self
      if value == "::" || value == "::1" {
        return true
      }

      // Public IPv6 global unicast addresses are currently within 2000::/3.
      guard let first = value.first else { return true }
      return first != "2" && first != "3"
    }

    let components = split(separator: ".", omittingEmptySubsequences: false)
    guard components.count == 4 else { return false }
    guard
      components.allSatisfy({ component in
        guard let value = Int(component) else { return false }
        return (0...255).contains(value)
      })
    else {
      return false
    }

    let octets = components.compactMap { Int($0) }
    guard octets.count == 4 else { return true }
    let first = octets[0]
    let second = octets[1]
    let third = octets[2]

    if first == 0 || first == 10 || first == 127 { return true }
    if first == 100 && (64...127).contains(second) { return true }
    if first == 169 && second == 254 { return true }
    if first == 172 && (16...31).contains(second) { return true }
    if first == 192 && second == 168 { return true }
    if first == 198 && (18...19).contains(second) { return true }
    if first >= 224 { return true }

    // IETF documentation and protocol-assignment ranges are never valid CDN targets.
    if first == 192 && second == 0 && (third == 0 || third == 2) { return true }
    if first == 198 && second == 51 && third == 100 { return true }
    if first == 203 && second == 0 && third == 113 { return true }

    return false
  }
}
