import SwiftUI

@available(iOS 16.0, *)
struct PPPetAdDetailsSummary: View {
    let title: String
    let location: String
    let price: String
    let type: String
    let age: String
    let gender: String

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.xl) {
            PPPetAdHeaderCard(
                title: title,
                location: location,
                price: price
            )

            if hasFacts {
                PPPetAdInfoGrid(
                    type: type,
                    age: age,
                    gender: gender
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var hasFacts: Bool {
        !type.isEmpty || !age.isEmpty || !gender.isEmpty
    }
}

@available(iOS 16.0, *)
struct PPPetAdHeaderCard: View {
    let title: String
    let location: String
    let price: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: headerSpacing) {
            eyebrowRow
            identityAndPrice

            if !location.isEmpty {
                locationLabel
            }
        }
        .padding(.leading, PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            brandSpine
        }
        .accessibilityElement(children: .contain)
    }

    private var headerSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? PPSpace.lg : PPSpace.md
    }

    private var eyebrowRow: some View {
        HStack(spacing: PPSpace.sm) {
            Text(petNameLabel)
                .font(PPPetAdTypography.footnoteBold)
                .foregroundStyle(Color.ppPrimary)

            Capsule(style: .continuous)
                .fill(Color.ppPrimary.opacity(0.34))
                .frame(width: 34, height: 3)
                .accessibilityHidden(true)
        }
        .accessibilityHidden(true)
    }

    private var brandSpine: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color.ppPrimary)
            .frame(
                width: colorSchemeContrast == .increased ? 5 : 4
            )
            .padding(.vertical, PPSpace.xs)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var identityAndPrice: some View {
        if price.isEmpty {
            titleView
        } else if dynamicTypeSize >= .xxLarge {
            stackedIdentityAndPrice
        } else {
            ViewThatFits(in: .horizontal) {
                horizontalIdentityAndPrice
                stackedIdentityAndPrice
            }
        }
    }

    private var horizontalIdentityAndPrice: some View {
        HStack(alignment: .top, spacing: PPSpace.lg) {
            titleView
                .layoutPriority(1)

            Spacer(minLength: PPSpace.sm)

            PPPetAdPriceView(price: price)
                .frame(maxWidth: 168, alignment: .trailing)
        }
    }

    private var stackedIdentityAndPrice: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            titleView
            PPPetAdPriceView(price: price)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var titleView: some View {
        Text(verbatim: "\u{2068}\(displayTitle)\u{2069}")
            .font(PPPetAdTypography.largeTitle)
            .foregroundStyle(Color.ppTextPrimary)
            .lineSpacing(PPSpace.xxs)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("\(petNameLabel): \(displayTitle)")
            .accessibilityAddTraits(.isHeader)
            .accessibilitySortPriority(3)
    }

    private var displayTitle: String {
        title.isEmpty
            ? PPPetAdLocalization.text(
                "pet_ad_viewer_title_fallback",
                fallback: "Pet advertisement"
            )
            : title
    }

    private var petNameLabel: String {
        PPPetAdLocalization.text(
            "pet_ad_viewer_pet_name_label",
            fallback: "Pet name"
        )
    }

    private var locationLabel: some View {
        HStack(alignment: .top, spacing: PPSpace.sm) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.ppTextSecondary)
                .frame(width: 24, height: 24)
                .background(
                    Color.ppTextTertiary.opacity(
                        colorSchemeContrast == .increased ? 0.18 : 0.10
                    ),
                    in: RoundedRectangle(
                        cornerRadius: PPSpace.sm,
                        style: .continuous
                    )
                )
                .accessibilityHidden(true)

            Text(verbatim: "\u{2068}\(location)\u{2069}")
                .font(PPPetAdTypography.callout)
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .padding(.top, 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(PPPetAdLocalization.text("Location", fallback: "Location")): \(location)"
        )
        .accessibilitySortPriority(1)
    }
}

@available(iOS 16.0, *)
private struct PPPetAdPriceView: View {
    let price: String

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.xxs) {
            Text(PPPetAdLocalization.text("Price", fallback: "Price"))
                .font(PPPetAdTypography.footnoteBold)
                .foregroundStyle(Color.ppPrimary)
                .accessibilityHidden(true)

            Text(verbatim: "\u{2068}\(price)\u{2069}")
                .font(PPPetAdTypography.price)
                .foregroundStyle(Color.ppPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.sm)
        .background(
            Color.ppPrimary.opacity(
                colorSchemeContrast == .increased ? 0.16 : 0.08
            ),
            in: RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
            .strokeBorder(
                Color.ppPrimary.opacity(
                    colorSchemeContrast == .increased ? 0.42 : 0.18
                ),
                lineWidth:
                    colorSchemeContrast == .increased
                    ? 1.25
                    : PPPetAdViewerStyle.hairlineWidth
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(PPPetAdLocalization.text("Price", fallback: "Price")): \(price)")
        .accessibilitySortPriority(2)
    }
}

struct PPPetAdDetailSectionHeading: View {
    let title: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.ppPrimary)
                .frame(width: 4, height: 18)
                .accessibilityHidden(true)

            Text(title)
                .font(PPPetAdTypography.title3)
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
