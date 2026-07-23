import SwiftUI

/// Identity block of the viewer: title, classification, location, and a
/// confidently anchored price. This is the decision surface — it reads in
/// one glance, in either language, at any Dynamic Type size.
struct PPPetAdHeaderCard: View {
    let title: String
    let categoryLine: String
    let location: String
    let price: String
    let postedDate: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            VStack(alignment: .leading, spacing: PPSpace.sm) {
                Text(
                    title.isEmpty
                        ? PPPetAdLocalization.text(
                            "pet_ad_viewer_title_fallback",
                            fallback: "Pet advertisement"
                        )
                        : title
                )
                .font(PPPetAdTypography.title)
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

                if !categoryLine.isEmpty {
                    Text(categoryLine)
                        .font(PPPetAdTypography.subheadline)
                        .foregroundStyle(Color.ppTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    locationLabel
                    priceLabel
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: PPSpace.md) {
                    locationLabel
                    Spacer(minLength: PPSpace.sm)
                    priceLabel
                }
            }

            if !postedDate.isEmpty {
                Label {
                    Text(postedDate)
                } icon: {
                    Image(systemName: "clock")
                        .foregroundStyle(Color.ppPrimary)
                }
                .font(PPPetAdTypography.footnote)
                .foregroundStyle(Color.ppTextTertiary)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(PPSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ppCard()
    }

    private var locationLabel: some View {
        Label {
            Text(location)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "location.fill")
                .foregroundStyle(Color.ppPrimary)
        }
        .font(PPPetAdTypography.callout)
        .foregroundStyle(Color.ppTextSecondary)
    }

    @ViewBuilder
    private var priceLabel: some View {
        if !price.isEmpty {
            Text(price)
                .font(PPPetAdTypography.title2)
                .foregroundStyle(Color.ppPrimary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(
                    "\(PPPetAdLocalization.text("Price", fallback: "Price")): \(price)"
                )
        }
    }
}
