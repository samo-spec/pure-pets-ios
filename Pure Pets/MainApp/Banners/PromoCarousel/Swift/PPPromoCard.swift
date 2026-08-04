import Foundation

struct PPPromoCard: Identifiable, Equatable {
  let id: String
  let position: Int
  let totalCount: Int

  let badgeText: String
  let title: String
  let subtitle: String
  let primaryButtonTitle: String
  let secondaryButtonTitle: String
  let showsPrimaryButton: Bool
  let showsSecondaryButton: Bool

  let artworkURL: URL?
  let localArtworkName: String?
  let startColorHex: String
  let endColorHex: String
  let accentColorHex: String

  let cardActionRawValue: Int
  let cardActionValue: String
  let primaryActionRawValue: Int
  let primaryActionValue: String
  let secondaryActionRawValue: Int
  let secondaryActionValue: String
  let autoScrollInterval: TimeInterval

  init(
    id: String,
    position: Int,
    totalCount: Int,
    badgeText: String,
    title: String,
    subtitle: String,
    primaryButtonTitle: String,
    secondaryButtonTitle: String = "",
    showsPrimaryButton: Bool = true,
    showsSecondaryButton: Bool = false,
    artworkURL: URL? = nil,
    localArtworkName: String? = nil,
    startColorHex: String,
    endColorHex: String,
    accentColorHex: String,
    cardActionRawValue: Int,
    cardActionValue: String,
    primaryActionRawValue: Int,
    primaryActionValue: String,
    secondaryActionRawValue: Int,
    secondaryActionValue: String,
    autoScrollInterval: TimeInterval
  ) {
    self.id = id
    self.position = position
    self.totalCount = totalCount
    self.badgeText = badgeText
    self.title = title
    self.subtitle = subtitle
    self.primaryButtonTitle = primaryButtonTitle
    self.secondaryButtonTitle = secondaryButtonTitle
    self.showsPrimaryButton = showsPrimaryButton
    self.showsSecondaryButton = showsSecondaryButton
    self.artworkURL = artworkURL
    self.localArtworkName = localArtworkName
    self.startColorHex = startColorHex
    self.endColorHex = endColorHex
    self.accentColorHex = accentColorHex
    self.cardActionRawValue = cardActionRawValue
    self.cardActionValue = cardActionValue
    self.primaryActionRawValue = primaryActionRawValue
    self.primaryActionValue = primaryActionValue
    self.secondaryActionRawValue = secondaryActionRawValue
    self.secondaryActionValue = secondaryActionValue
    self.autoScrollInterval = max(2.0, autoScrollInterval)
  }
}

extension PPPromoCard {
  init(objectiveCCard card: PPHomePromoCarouselCard, position: Int, totalCount: Int) {
    self.init(
      id: card.cardID.isEmpty ? "promo-\(position)" : card.cardID,
      position: position,
      totalCount: totalCount,
      badgeText: card.localizedBadgeText(),
      title: card.localizedTitleText(),
      subtitle: card.localizedSubtitleText(),
      primaryButtonTitle: card.localizedPrimaryButtonTitle(),
      secondaryButtonTitle: card.localizedSecondaryButtonTitle(),
      showsPrimaryButton: card.showsPrimaryButton(),
      showsSecondaryButton: card.showsSecondaryButton(),
      artworkURL: card.characterImageURL,
      startColorHex: card.startColorHex,
      endColorHex: card.endColorHex,
      accentColorHex: card.accentColorHex,
      cardActionRawValue: Int(card.cardTapAction.rawValue),
      cardActionValue: card.cardTapValue,
      primaryActionRawValue: Int(card.primaryButtonTapAction.rawValue),
      primaryActionValue: card.primaryButtonTapValue,
      secondaryActionRawValue: Int(card.secondaryButtonTapAction.rawValue),
      secondaryActionValue: card.secondaryButtonTapValue,
      autoScrollInterval: card.autoScrollInterval
    )
  }
}
