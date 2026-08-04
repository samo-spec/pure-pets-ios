import Foundation

@MainActor
final class PPHomePromoCarouselStore: ObservableObject {
  enum Phase: Equatable {
    case idle
    case loading
    case content
    case empty
    case failed(message: String)
  }

  @Published private(set) var cards: [PPPromoCard] = []
  @Published private(set) var phase: Phase = .idle
  @Published private(set) var isVisible = false

  private let dataSource: PPHomePromoCarouselDataSource
  private var isListening = false
  private var lifecycleGeneration = 0

  init(dataSource: PPHomePromoCarouselDataSource = .shared()) {
    self.dataSource = dataSource
  }

  func start() {
    guard !isListening else { return }
    isListening = true
    isVisible = true
    lifecycleGeneration &+= 1
    let generation = lifecycleGeneration

    if cards.isEmpty {
      phase = .loading
    }

    dataSource.start { [weak self] objectiveCCards, error in
      guard let self else { return }
      Task { @MainActor in
        guard generation == self.lifecycleGeneration else { return }
        self.apply(objectiveCCards: objectiveCCards ?? [], error: error)
      }
    }
  }

  func stop() {
    guard isListening else { return }
    lifecycleGeneration &+= 1
    dataSource.stop()
    isListening = false
    isVisible = false
  }

  func reload() {
    phase = cards.isEmpty ? .loading : .content
    let generation = lifecycleGeneration

    dataSource.fetchOnce { [weak self] objectiveCCards, error in
      guard let self else { return }
      Task { @MainActor in
        guard generation == self.lifecycleGeneration else { return }
        self.apply(objectiveCCards: objectiveCCards ?? [], error: error)
      }
    }
  }

  private func apply(objectiveCCards: [PPHomePromoCarouselCard], error: Error?) {
    let mappedCards = objectiveCCards.enumerated().map { index, card in
      PPPromoCard(
        objectiveCCard: card,
        position: index,
        totalCount: objectiveCCards.count
      )
    }

    if !mappedCards.isEmpty {
      cards = mappedCards
      phase = .content
      return
    }

    if cards.isEmpty {
      if let error {
        phase = .failed(message: error.localizedDescription)
      } else {
        phase = .empty
      }
    }
  }
}
