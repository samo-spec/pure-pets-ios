import SwiftUI

struct PPPetAdRelatedCard: View {
    let item: PPPetAdRelatedItem
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    PPPetAdRemoteImageView(
                        urlString: item.imageURL,
                        blurHash: item.blurHash,
                        contentMode: .fill,
                        accessibilityLabel: item.title
                    )
                    .frame(height: 148)
                    .clipped()

                    Text(kindLabel)
                        .font(PPPetAdTypography.footnoteBold)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, PPSpace.md)
                        .frame(minHeight: 28)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.white.opacity(0.20), lineWidth: 0.75)
                        }
                        .padding(PPSpace.sm)
                }

                VStack(alignment: .leading, spacing: PPSpace.xs) {
                    Text(item.title)
                        .font(PPPetAdTypography.headline)
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(PPPetAdTypography.footnote)
                            .foregroundStyle(Color.ppTextSecondary)
                            .lineLimit(1)
                    }

                    if !item.price.isEmpty {
                        Text(item.price)
                            .font(PPPetAdTypography.calloutBold)
                            .foregroundStyle(Color.ppPrimary)
                            .lineLimit(1)
                    }
                }
                .padding(PPSpace.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 210)
            .background(Color.ppCard)
            .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.24), lineWidth: 0.5)
            }
            .shadow(
                color: PPShadow.card.color,
                radius: PPShadow.card.radius,
                x: PPShadow.card.x,
                y: PPShadow.card.y
            )
        }
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.97))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var kindLabel: String {
        switch item.kind {
        case .petAd:
            return PPPetAdLocalization.text("pet_ad_viewer_pet_badge", fallback: "Pet")
        case .accessory:
            return PPPetAdLocalization.text("pet_ad_viewer_accessory_badge", fallback: "Accessory")
        }
    }
}



