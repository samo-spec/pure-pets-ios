import SwiftUI

struct PPPromoCardView: View {
  let card: PPPromoCard
  let isActive: Bool
  let reduceMotion: Bool
  let onSelectCard: () -> Void
  let onAction: (PPPromoAction) -> Void

  @Environment(\.layoutDirection) private var layoutDirection
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      let height = proxy.size.height
      let contentWidth = max(0, width - 40)

      ZStack {
        PPPromoCardBackground(
          startColor: Color(ppHex: card.startColorHex),
          endColor: Color(ppHex: card.endColorHex),
          accentColor: Color(ppHex: card.accentColorHex)
        )

        HStack(spacing: 0) {
          copyColumn
            .frame(width: contentWidth * copyWidthRatio, alignment: .leading)

          artwork
            .frame(width: contentWidth * (1 - copyWidthRatio), height: height * artworkHeightRatio)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .environment(\.layoutDirection, .leftToRight)

        topChrome
          .padding(16)
      }
      .clipShape(RoundedRectangle(cornerRadius: PPPromoTheme.cardCornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: PPPromoTheme.cardCornerRadius, style: .continuous)
          .stroke(Color.white.opacity(0.78), lineWidth: 1)
      }
      .shadow(
        color: Color.black.opacity(isActive ? 0.14 : 0.07), radius: isActive ? 24 : 12, x: 0,
        y: isActive ? 16 : 8
      )
      .contentShape(
        RoundedRectangle(cornerRadius: PPPromoTheme.cardCornerRadius, style: .continuous)
      )
      .onTapGesture(perform: handleCardTap)
      .accessibilityElement(children: .contain)
      .accessibilityHidden(!isActive)
      .accessibilityIdentifier("pp_home_promo_card_\(card.id)")
    }
  }

  private var copyColumn: some View {
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: 36)

      Text(card.title)
        .font(PPPromoTheme.titleFont)
        .foregroundStyle(PPPromoTheme.promoTextPrimary)
        .multilineTextAlignment(textAlignment)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
        .minimumScaleFactor(0.82)
        .frame(maxWidth: .infinity, alignment: textFrameAlignment)

      if !card.subtitle.isEmpty {
        Text(card.subtitle)
          .font(PPPromoTheme.subtitleFont)
          .foregroundStyle(PPPromoTheme.promoTextSecondary)
          .multilineTextAlignment(textAlignment)
          .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
          .minimumScaleFactor(0.86)
          .frame(maxWidth: .infinity, alignment: textFrameAlignment)
          .padding(.top, 3)
      }

      Spacer(minLength: 12)

      if card.showsPrimaryButton {
        primaryButton
      }

      if card.showsSecondaryButton {
        secondaryButton
          .padding(.top, 8)
      }
    }
    .environment(\.layoutDirection, layoutDirection)
  }

  private var artwork: some View {
    PPPromoRemoteImage(
      url: card.artworkURL,
      localImageName: card.localArtworkName,
      accessibilityLabel: card.title
    )
    .padding(.top, 18)
    .padding(.bottom, 2)
    .scaleEffect(isActive || reduceMotion ? 1 : 0.96)
    .offset(y: isActive || reduceMotion ? 0 : 4)
    .shadow(color: Color.black.opacity(0.13), radius: 12, x: 0, y: 9)
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.42), value: isActive)
  }

  private var topChrome: some View {
    VStack {
      HStack {
        Text("\(card.position + 1)/\(max(card.totalCount, 1))")
          .font(PPPromoTheme.badgeFont)
          .foregroundStyle(Color(ppHex: card.accentColorHex).opacity(0.88))
          .padding(.horizontal, 12)
          .frame(minHeight: 32)
          .ppPromoGlassCapsule(tint: Color(ppHex: card.startColorHex))
          .accessibilityHidden(true)

        Spacer()

        Label {
          if !card.badgeText.isEmpty {
            Text(card.badgeText)
              .font(PPPromoTheme.badgeFont)
          }
        } icon: {
          Image(systemName: "tag.fill")
            .font(.system(size: 13, weight: .semibold))
        }
        .labelStyle(.titleAndIcon)
        .foregroundStyle(Color(ppHex: card.accentColorHex))
        .padding(.horizontal, card.badgeText.isEmpty ? 11 : 12)
        .frame(minHeight: 40)
        .ppPromoGlassCapsule(tint: Color(ppHex: card.endColorHex))
        .accessibilityLabel(card.badgeText.isEmpty ? localizedOfferLabel : card.badgeText)
      }

      Spacer()
    }
  }

  private var primaryButton: some View {
    Button(action: handlePrimaryAction) {
      HStack(spacing: 10) {
        if layoutDirection == .rightToLeft {
          Image(systemName: "arrow.left")
            .font(.system(size: 16, weight: .bold))
        }

        Text(primaryTitle)
          .font(PPPromoTheme.buttonFont)
          .lineLimit(1)
          .minimumScaleFactor(0.8)

        if layoutDirection == .leftToRight {
          Image(systemName: "arrow.right")
            .font(.system(size: 16, weight: .bold))
        }
      }
      .environment(\.layoutDirection, .leftToRight)
      .foregroundStyle(Color.white)
      .frame(maxWidth: .infinity, minHeight: 48)
      .padding(.horizontal, 14)
      .background(
        LinearGradient(
          colors: [
            Color(ppHex: card.accentColorHex), Color(ppHex: card.accentColorHex).opacity(0.78),
          ],
          startPoint: .leading,
          endPoint: .trailing
        ),
        in: Capsule()
      )
      .overlay {
        Capsule()
          .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
      }
    }
    .buttonStyle(PPPromoPressButtonStyle())
    .accessibilityIdentifier("pp_home_promo_primary_\(card.id)")
  }

  private var secondaryButton: some View {
    Button(action: handleSecondaryAction) {
      Text(card.secondaryButtonTitle)
        .font(PPPromoTheme.badgeFont)
        .foregroundStyle(Color(ppHex: card.accentColorHex))
        .frame(maxWidth: .infinity, minHeight: 44)
        .ppPromoGlassCapsule(tint: Color(ppHex: card.startColorHex), interactive: true)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("pp_home_promo_secondary_\(card.id)")
  }

  private var copyWidthRatio: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? 0.58 : 0.48
  }

  private var artworkHeightRatio: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? 0.70 : 0.83
  }

  private var primaryTitle: String {
    if !card.primaryButtonTitle.isEmpty {
      return card.primaryButtonTitle
    }
    return NSLocalizedString("pp_promo_shop_now", comment: "Home promotional carousel CTA")
  }

  private var localizedOfferLabel: String {
    NSLocalizedString("pp_promo_offer", comment: "Promotional offer badge")
  }

  private var textAlignment: TextAlignment {
    layoutDirection == .rightToLeft ? .trailing : .leading
  }

  private var textFrameAlignment: Alignment {
    layoutDirection == .rightToLeft ? .trailing : .leading
  }

  private func handleCardTap() {
    guard isActive else {
      onSelectCard()
      return
    }

    PPPromoHaptics.actionPressed()
    onAction(
      PPPromoAction(
        rawAction: card.cardActionRawValue,
        value: card.cardActionValue,
        cardID: card.id,
        source: .card
      )
    )
  }

  private func handlePrimaryAction() {
    PPPromoHaptics.actionPressed()
    onAction(
      PPPromoAction(
        rawAction: card.primaryActionRawValue,
        value: card.primaryActionValue,
        cardID: card.id,
        source: .primaryButton
      )
    )
  }

  private func handleSecondaryAction() {
    PPPromoHaptics.actionPressed()
    onAction(
      PPPromoAction(
        rawAction: card.secondaryActionRawValue,
        value: card.secondaryActionValue,
        cardID: card.id,
        source: .secondaryButton
      )
    )
  }
}

private struct PPPromoPressButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
      .brightness(configuration.isPressed ? -0.04 : 0)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
  }
}
