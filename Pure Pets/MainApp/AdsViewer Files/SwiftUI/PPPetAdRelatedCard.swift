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
                    .frame(height: 168)
                    .accessibilityHidden(true)

                    Text(kindLabel)
                        .font(PPPetAdTypography.footnoteBold)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, PPSpace.md)
                        .frame(minHeight: 32)
                        .ppGlassSurface(
                            in: Capsule(),
                            tint: Color.black.opacity(0.12),
                            fallback: Color.black.opacity(0.82)
                        )
                        .padding(PPSpace.md)
                }
                .clipped()

                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    Text(item.title)
                        .font(PPPetAdTypography.headline)
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(PPPetAdTypography.footnote)
                            .foregroundStyle(Color.ppTextSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    if !item.price.isEmpty {
                        Text(item.price)
                            .font(PPPetAdTypography.calloutBold)
                            .foregroundStyle(Color.ppPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.80)
                    }
                }
                .padding(PPSpace.base)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 124,
                    alignment: .topLeading
                )
            }
            .frame(width: 270)
            .background(Color.ppCard)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PPCorner.card,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PPCorner.card,
                    style: .continuous
                )
                .stroke(
                    Color(uiColor: .separator).opacity(0.24),
                    lineWidth: 0.5
                )
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
        .accessibilityHint(
            PPPetAdLocalization.text(
                "pet_ad_viewer_open_related_hint",
                fallback: "Opens this listing"
            )
        )
    }

    private var kindLabel: String {
        switch item.kind {
        case .petAd:
            return PPPetAdLocalization.text(
                "pet_ad_viewer_pet_badge",
                fallback: "Pet"
            )
        case .accessory:
            return PPPetAdLocalization.text(
                "pet_ad_viewer_accessory_badge",
                fallback: "Accessory"
            )
        }
    }
}
