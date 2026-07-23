import SwiftUI

/// Identity block of the viewer: title + price in one visual group,
/// metadata in a compact secondary row. Reads in one glance, in either
/// language, at any Dynamic Type size with strict 8pt rhythm.
struct PPPetAdHeaderCard: View {
    let title: String
    let categoryLine: String
    let location: String
    let price: String
    let postedDate: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            // Title + Price — same visual group, leading/trailing split
            HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
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
                .frame(maxWidth: .infinity, alignment: .leading)

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

            // Compact secondary row: category • location • posted date
            HStack(spacing: PPSpace.xs) {
                if !categoryLine.isEmpty {
                    Text(categoryLine)
                        .font(PPPetAdTypography.subheadline)
                        .foregroundStyle(Color.ppTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !categoryLine.isEmpty && (!location.isEmpty || !postedDate.isEmpty) {
                    Text("·")
                        .font(PPPetAdTypography.subheadline)
                        .foregroundStyle(Color.ppTextTertiary)
                }

                if !location.isEmpty {
                    Label {
                        Text(location)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(PPPetAdTypography.footnote)
                    .foregroundStyle(Color.ppTextSecondary)
                }

                if !location.isEmpty && !postedDate.isEmpty {
                    Text("·")
                        .font(PPPetAdTypography.subheadline)
                        .foregroundStyle(Color.ppTextTertiary)
                }

                if !postedDate.isEmpty {
                    Label {
                        Text(postedDate)
                    } icon: {
                        Image(systemName: "clock")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(PPPetAdTypography.footnote)
                    .foregroundStyle(Color.ppTextTertiary)
                }
            }
            .accessibilityElement(children: .combine)
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ppCard()
    }
}
