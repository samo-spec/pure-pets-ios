import Foundation

enum PPPromoActionSource: Int, Sendable {
  case card = 0
  case primaryButton = 1
  case secondaryButton = 2
}

struct PPPromoAction: Equatable, Sendable {
  let rawAction: Int
  let value: String
  let cardID: String
  let source: PPPromoActionSource
}
