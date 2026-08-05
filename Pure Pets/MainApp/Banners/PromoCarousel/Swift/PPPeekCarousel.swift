import SwiftUI

struct PPPeekCarousel: View {
  let cards: [PPPromoCard]
  let isActive: Bool
  let onAction: (PPPromoAction) -> Void

  @Binding var selection: Int
  @GestureState private var dragTranslation: CGFloat = 0
  @State private var visualPage = 1
  @State private var isDragging = false
  @State private var isWrapping = false
  @State private var ignoreNextSelectionChange = false
  @State private var autoScrollGeneration = 0
  @State private var wrapGeneration = 0

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    GeometryReader { proxy in
      let containerWidth = proxy.size.width
      let cardWidth = PPPromoCarouselMetrics.cardWidth(containerWidth: containerWidth)
      let cardHeight = PPPromoCarouselMetrics.cardHeight(
        cardWidth: cardWidth,
        usesAccessibilityType: dynamicTypeSize.isAccessibilitySize
      )
      let stride = cardWidth + PPPromoTheme.cardSpacing
      let centeredInset = (containerWidth - cardWidth) / 2
      let baseOffset = centeredInset - CGFloat(visualPage) * stride
      let items = displayItems

      VStack(spacing: 0) {
        HStack(spacing: PPPromoTheme.cardSpacing) {
          ForEach(Array(items.enumerated()), id: \.element.id) { displayIndex, item in
            let relativeIndex = CGFloat(displayIndex - visualPage)
            let normalizedDrag = dragTranslation / max(stride, 1)
            let relativeProgress = relativeIndex + normalizedDrag
            let isActive = displayIndex == visualPage

            PPPromoCardView(
              card: item.card,
              isActive: isActive,
              reduceMotion: reduceMotion,
              onSelectCard: { selectDisplayIndex(displayIndex) },
              onAction: onAction
            )
            .frame(width: cardWidth, height: cardHeight)
            .scaleEffect(
              reduceMotion ? 1 : PPPromoCarouselMetrics.scale(relativeProgress: relativeProgress)
            )
            .rotation3DEffect(
              .degrees(
                reduceMotion
                  ? 0
                  : PPPromoCarouselMetrics.rotation(relativeProgress: relativeProgress)
              ),
              axis: (x: 0, y: 1, z: 0),
              anchor: relativeProgress < 0 ? .trailing : .leading,
              perspective: 0.78
            )
            .offset(
              y: reduceMotion
                ? 0
                : PPPromoCarouselMetrics.verticalOffset(relativeProgress: relativeProgress)
            )
            .opacity(PPPromoCarouselMetrics.opacity(relativeProgress: relativeProgress))
            .zIndex(PPPromoCarouselMetrics.zIndex(relativeProgress: relativeProgress))
          }
        }
        .offset(x: baseOffset + dragTranslation)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .gesture(dragGesture(cardStride: stride))
        .animation(activeAnimation, value: visualPage)

        PPPromoPageIndicator(count: cards.count, selection: $selection)
          .frame(height: 44)
          .padding(.top, 2)
      }
      .frame(height: cardHeight + 48, alignment: .top)
      .clipped()
      .accessibilityElement(children: .contain)
      .accessibilityLabel(
        NSLocalizedString("pp_promo_carousel", comment: "Home promotional carousel")
      )
      .accessibilityValue(carouselAccessibilityValue)
      .accessibilityAdjustableAction { direction in
        switch direction {
        case .increment:
          move(by: 1, userInitiated: true)
        case .decrement:
          move(by: -1, userInitiated: true)
        @unknown default:
          break
        }
      }
      .task(id: autoScrollTaskID) {
        await scheduleAutoScrollIfNeeded()
      }
      .onAppear {
        reconcileAfterCardsChange()
      }
      .onChange(of: cards.map(\.id)) { _ in
        reconcileAfterCardsChange()
      }
      .onChange(of: selection) { newSelection in
        handleExternalSelectionChange(newSelection)
      }
    }
    .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 342 : 250)
  }

  private var displayItems: [PPPromoCarouselDisplayItem] {
    PPPromoCarouselDisplayItems.make(from: cards)
  }

  private var carouselAccessibilityValue: String {
    guard !cards.isEmpty else { return "" }
    return String(
      format: NSLocalizedString("pp_promo_page_format", comment: "Carousel page number"),
      min(selection + 1, cards.count),
      cards.count
    )
  }

  private var activeAnimation: Animation {
    reduceMotion ? PPPromoTheme.reducedMotionAnimation : PPPromoTheme.snapAnimation
  }

  private var autoScrollTaskID: String {
    [
      String(selection),
      String(cards.count),
      String(autoScrollGeneration),
      String(isDragging),
      String(isActive),
      String(isWrapping),
      String(voiceOverEnabled),
      String(describing: scenePhase),
    ].joined(separator: "-")
  }

  private func dragGesture(cardStride: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 6)
      .updating($dragTranslation) { value, state, _ in
        guard !isWrapping else { return }
        state = value.translation.width
      }
      .onChanged { _ in
        guard !isWrapping else { return }
        isDragging = true
      }
      .onEnded { value in
        guard !isWrapping else { return }
        isDragging = false
        let projected = value.predictedEndTranslation.width
        let threshold = cardStride * 0.16

        if projected < -threshold {
          move(by: 1, userInitiated: true)
        } else if projected > threshold {
          move(by: -1, userInitiated: true)
        } else {
          autoScrollGeneration &+= 1
        }
      }
  }

  private func move(by delta: Int, userInitiated: Bool) {
    guard cards.count > 1, !isWrapping else { return }

    let targetPage = min(max(visualPage + delta, 0), displayItems.count - 1)
    guard targetPage != visualPage else { return }

    if userInitiated {
      PPPromoHaptics.selectionChanged()
    }

    let logicalIndex = displayItems[targetPage].logicalIndex
    ignoreNextSelectionChange = true
    selection = logicalIndex

    withAnimation(activeAnimation) {
      visualPage = targetPage
    }

    if targetPage == 0 || targetPage == displayItems.count - 1 {
      scheduleWrapReset(from: targetPage)
    }
  }

  private func selectDisplayIndex(_ displayIndex: Int) {
    guard displayItems.indices.contains(displayIndex) else { return }
    let delta = displayIndex - visualPage

    if abs(delta) == 1 {
      move(by: delta, userInitiated: true)
      return
    }

    let logicalIndex = displayItems[displayIndex].logicalIndex
    guard cards.indices.contains(logicalIndex) else { return }
    PPPromoHaptics.selectionChanged()
    ignoreNextSelectionChange = true
    selection = logicalIndex

    withAnimation(activeAnimation) {
      visualPage = cards.count > 1 ? logicalIndex + 1 : logicalIndex
    }
  }

  private func scheduleWrapReset(from targetPage: Int) {
    isWrapping = true
    wrapGeneration &+= 1
    let generation = wrapGeneration
    let resetPage = targetPage == 0 ? cards.count : 1
    let delayNanoseconds: UInt64 = reduceMotion ? 180_000_000 : 560_000_000

    Task { @MainActor in
      try? await Task.sleep(nanoseconds: delayNanoseconds)
      guard generation == wrapGeneration else { return }

      var transaction = Transaction()
      transaction.disablesAnimations = true
      withTransaction(transaction) {
        visualPage = resetPage
      }

      isWrapping = false
      autoScrollGeneration &+= 1
    }
  }

  private func handleExternalSelectionChange(_ newSelection: Int) {
    if ignoreNextSelectionChange {
      ignoreNextSelectionChange = false
      return
    }

    guard cards.indices.contains(newSelection) else { return }
    let targetPage = cards.count > 1 ? newSelection + 1 : newSelection

    withAnimation(activeAnimation) {
      visualPage = targetPage
    }
    autoScrollGeneration &+= 1
  }

  private func reconcileAfterCardsChange() {
    let safeSelection = min(selection, max(cards.count - 1, 0))
    selection = safeSelection

    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) {
      visualPage = cards.count > 1 ? safeSelection + 1 : safeSelection
    }

    isWrapping = false
    wrapGeneration &+= 1
    autoScrollGeneration &+= 1
  }

  private func scheduleAutoScrollIfNeeded() async {
    guard cards.count > 1,
      cards.indices.contains(selection),
      isActive,
      !reduceMotion,
      !voiceOverEnabled,
      !isDragging,
      !isWrapping,
      scenePhase == .active
    else {
      return
    }

    let interval = cards[selection].autoScrollInterval
    guard interval.isFinite, interval > 0 else { return }
    let nanoseconds = UInt64(min(interval, 60.0) * 1_000_000_000)

    do {
      try await Task.sleep(nanoseconds: nanoseconds)
    } catch {
      return
    }

    guard !Task.isCancelled else { return }
    move(by: 1, userInitiated: false)
  }

}
