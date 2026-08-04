import SwiftUI

extension Color {
  init(ppHex rawHex: String, fallback: Color = PPPromoTheme.warmPorcelain) {
    let cleaned =
      rawHex
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "#", with: "")

    guard let value = UInt64(cleaned, radix: 16) else {
      self = fallback
      return
    }

    switch cleaned.count {
    case 6:
      self.init(
        .sRGB,
        red: Double((value >> 16) & 0xFF) / 255,
        green: Double((value >> 8) & 0xFF) / 255,
        blue: Double(value & 0xFF) / 255,
        opacity: 1
      )
    case 8:
      self.init(
        .sRGB,
        red: Double((value >> 24) & 0xFF) / 255,
        green: Double((value >> 16) & 0xFF) / 255,
        blue: Double((value >> 8) & 0xFF) / 255,
        opacity: Double(value & 0xFF) / 255
      )
    default:
      self = fallback
    }
  }
}
