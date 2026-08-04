import UIKit

@MainActor
enum PPPromoHaptics {
  static func selectionChanged() {
    let generator = UISelectionFeedbackGenerator()
    generator.prepare()
    generator.selectionChanged()
  }

  static func actionPressed() {
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.prepare()
    generator.impactOccurred(intensity: 0.72)
  }
}
