import Foundation

struct PPPromoCarouselDisplayItem: Identifiable {
  let id: String
  let card: PPPromoCard
  let logicalIndex: Int
}

enum PPPromoCarouselDisplayItems {
  static func make(from cards: [PPPromoCard]) -> [PPPromoCarouselDisplayItem] {
    guard cards.count > 1, let first = cards.first, let last = cards.last else {
      return cards.enumerated().map { index, card in
        PPPromoCarouselDisplayItem(
          id: "original-\(card.id)",
          card: card,
          logicalIndex: index
        )
      }
    }

    var items: [PPPromoCarouselDisplayItem] = [
      PPPromoCarouselDisplayItem(
        id: "leading-clone-\(last.id)",
        card: last,
        logicalIndex: cards.count - 1
      )
    ]

    items.append(
      contentsOf: cards.enumerated().map { index, card in
        PPPromoCarouselDisplayItem(
          id: "original-\(card.id)",
          card: card,
          logicalIndex: index
        )
      })

    items.append(
      PPPromoCarouselDisplayItem(
        id: "trailing-clone-\(first.id)",
        card: first,
        logicalIndex: 0
      )
    )

    return items
  }
}
