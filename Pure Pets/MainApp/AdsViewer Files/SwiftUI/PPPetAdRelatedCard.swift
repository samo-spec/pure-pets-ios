import SwiftUI

struct PPPetAdRelatedCard: View {
    let item: PPPetAdRelatedItem
    let onSelect: () -> Void

    private var cardModel: PPUniversalCardModel {
        PPUniversalCardModel(
            id: item.id,
            title: item.title,
            subtitle: item.subtitle.isEmpty ? nil : item.subtitle,
            imageURL: item.imageURL.flatMap(URL.init(string:)),
            priceText: item.price.isEmpty ? nil : item.price
        )
    }

    private var context: PPUniversalCardContext {
        switch item.kind {
        case .petAd:
            return .ads
        case .accessory:
            return .accessory
        }
    }

    var body: some View {
        Button(action: onSelect) {
            if #available(iOS 16.0, *) {
                PPUniversalCardView(
                    model: cardModel,
                    context: context,
                    layout: .vertical,
                    discountStyle: .badge
                )
                .frame(width: 210)
                .contentShape(Rectangle())
            } else {
                VStack(alignment: .leading, spacing: PPSpace.xs) {
                    PPPetAdRemoteImageView(
                        urlString: item.imageURL,
                        blurHash: item.blurHash,
                        contentMode: .fill,
                        accessibilityLabel: item.title
                    )
                    .frame(height: 140)
                    .clipped()

                    Text(item.title)
                        .font(PPPetAdTypography.headline)
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(2)

                    if !item.price.isEmpty {
                        Text(item.price)
                            .font(PPPetAdTypography.calloutBold)
                            .foregroundStyle(Color.ppPrimary)
                    }
                }
                .padding(PPSpace.sm)
                .frame(width: 210)
                .background(Color.ppCard, in: RoundedRectangle(cornerRadius: PPCorner.card))
            }
        }
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.97))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(
            PPPetAdLocalization.text(
                "pet_ad_viewer_open_related_hint",
                fallback: "Opens this listing"
            )
        )
    }
}


