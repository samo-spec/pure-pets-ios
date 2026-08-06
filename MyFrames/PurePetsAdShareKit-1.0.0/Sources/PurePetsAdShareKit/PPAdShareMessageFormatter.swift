import Foundation

public struct PPAdShareMessageFormatter: Sendable {
  public let copy: PPAdShareCopy

  public init(copy: PPAdShareCopy) {
    self.copy = copy
  }

  public func message(for payload: PPAdSharePayload) -> String {
    let canonicalURL = payload.canonicalURL.absoluteString
    let safeTitle = cleaned(payload.title, removing: canonicalURL)
    var lines: [String] = [
      "🐾 \(safeTitle.isEmpty ? copy.fallbackTitle : safeTitle)"
    ]

    if let price = payload.formattedPrice {
      let safePrice = cleaned(price, removing: canonicalURL)
      if !safePrice.isEmpty {
        lines.append("💰 \(copy.priceLabel): \(safePrice)")
      }
    }

    if let location = payload.location {
      let safeLocation = cleaned(location, removing: canonicalURL)
      if !safeLocation.isEmpty {
        lines.append("📍 \(copy.locationLabel): \(safeLocation)")
      }
    }

    let attributes = payload.attributes
      .map { cleaned($0.title, removing: canonicalURL) }
      .filter { !$0.isEmpty }
    if !attributes.isEmpty {
      lines.append("✅ \(attributes.joined(separator: " • "))")
    }

    if let description = payload.shortDescription {
      let safeDescription = cleaned(description, removing: canonicalURL)
      if !safeDescription.isEmpty {
        lines.append(truncated(safeDescription, maximumCharacters: 180))
      }
    }

    lines.append("")
    let safeCallToAction = cleaned(copy.callToAction, removing: canonicalURL)
    if !safeCallToAction.isEmpty {
      lines.append(safeCallToAction)
    }
    lines.append(canonicalURL)
    return lines.joined(separator: "\n")
  }

  private func cleaned(_ value: String, removing canonicalURL: String) -> String {
    value
      .replacingOccurrences(of: canonicalURL, with: "")
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  private func truncated(_ value: String, maximumCharacters: Int) -> String {
    guard value.count > maximumCharacters else { return value }
    let index = value.index(value.startIndex, offsetBy: maximumCharacters - 1)
    return String(value[..<index]).ppShareTrimmed + "…"
  }
}
