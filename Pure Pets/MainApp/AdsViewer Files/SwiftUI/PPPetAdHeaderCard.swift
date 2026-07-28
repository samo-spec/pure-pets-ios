import SwiftUI

// MARK: - PPPetAdDetailsSummary (Consumer)

@available(iOS 16.0, *)
struct PPPetAdDetailsSummary: View {
    let title: String
    let location: String
    let price: String
    let type: String
    let age: String
    let gender: String
    var ad: PetAd? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PPPetAdHeaderCard(
                title: title,
                location: location,
                price: price,
                postedDate: ad?.postedDate
            )

            if hasFacts {
                PPPetAdFadingDivider(axis: .horizontal)
                    .frame(height: PPPetAdViewerStyle.hairlineWidth)
                    .padding(.top, PPSpace.lg)

                PPPetAdInfoGrid(type: type, age: age, gender: gender)
                    .padding(.top, PPSpace.xs)
            }
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(summarySurface)
        .overlay {
            summaryShape
                .strokeBorder(summaryBorder, lineWidth: summaryBorderWidth)
                .accessibilityHidden(true)
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.045),
            radius: colorScheme == .dark ? 18 : 12,
            x: 0,
            y: colorScheme == .dark ? 9 : 5
        )
        .accessibilityElement(children: .contain)
    }

    private var hasFacts: Bool {
        !type.isEmpty || !age.isEmpty || !gender.isEmpty
    }

    private var summarySurface: some View {
        summaryShape.fill(summaryFill)
    }

    private var summaryFill: LinearGradient {
        let topColor = colorScheme == .dark
            ? Color.ppForeground.opacity(0.58)
            : Color.ppPrimary.opacity(0.055)
        let bottomColor = colorScheme == .dark
            ? Color.ppCard.opacity(0.94)
            : Color.ppCard.opacity(0.96)

        return LinearGradient(
            colors: [topColor, bottomColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var summaryBorder: LinearGradient {
        let accentOpacity = colorSchemeContrast == .increased ? 0.92 : 0.58
        let quietOpacity = colorSchemeContrast == .increased ? 0.82 : 0.26

        return LinearGradient(
            stops: [
                .init(color: Color.ppPrimary.opacity(accentOpacity), location: 0),
                .init(color: Color.ppPrimary.opacity(accentOpacity), location: 0.045),
                .init(color: Color.ppBorder.opacity(quietOpacity), location: 0.18),
                .init(color: Color.ppBorder.opacity(quietOpacity * 0.72), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var summaryBorderWidth: CGFloat {
        colorSchemeContrast == .increased
            ? 1.5
            : 1
    }

    private var summaryShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PPPetAdViewerStyle.surfaceRadius + 4,
            style: .continuous
        )
    }
}

// MARK: - PPPetAdHeaderCard

@available(iOS 16.0, *)
struct PPPetAdHeaderCard: View {
    let title: String
    let location: String
    let price: String
    var postedDate: Date? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            identityBlock
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var identityBlock: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Text(petNameLabel)
                .font(PPPetAdTypography.footnoteBold)
                .foregroundStyle(Color.ppPrimary)
                .accessibilityHidden(true)

            titleText
                .frame(maxWidth: .infinity, alignment: .leading)

            if !price.isEmpty {
                PPPetAdPriceView(price: price)
                    .padding(.top, PPSpace.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilitySortPriority(2)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(3)
    }

    private var titleText: some View {
        Text(verbatim: "\u{2068}\(displayTitle)\u{2069}")
            .font(PPPetAdTypography.title)
            .foregroundStyle(Color.ppTextPrimary)
            .lineSpacing(PPSpace.xxs)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .accessibilityLabel("\(petNameLabel): \(displayTitle)")
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Computed Properties

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

    private var freshnessText: String? {
        guard let postedDate, postedDate <= Date() else { return nil }

        let days = Calendar.current.dateComponents(
            [.day],
            from: postedDate,
            to: Date()
        ).day ?? Int.max

        guard days >= 0, days <= 7 else { return nil }

        if days == 0 {
            return PPPetAdLocalization.text(
                "pet_ad_viewer_freshness_today",
                fallback: "Today"
            )
        }
        if days == 1 {
            return PPPetAdLocalization.text(
                "pet_ad_viewer_freshness_yesterday",
                fallback: "Yesterday"
            )
        }

        let format = PPPetAdLocalization.text(
            "pet_ad_viewer_freshness_days_ago",
            fallback: "%d days ago"
        )
        return String(format: format, days)
    }
}

// MARK: - Price View

@available(iOS 16.0, *)
private struct PPPetAdPriceView: View {
    let price: String

    private var presentation: PPPetAdPricePresentation {
        PPPetAdPricePresentation(formattedPrice: price)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PPSpace.xs) {
            Text(verbatim: "\u{2068}\(presentation.amount)\u{2069}")
                .font(PPPetAdTypography.price)
                .foregroundStyle(Color.ppPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            if !presentation.currency.isEmpty {
                Text(verbatim: "\u{2068}\(presentation.currency)\u{2069}")
                    .font(PPPetAdTypography.microCurrency)
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
        .layoutPriority(2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(PPPetAdLocalization.text("Price", fallback: "Price")): \(price)"
        )
    }
}

private struct PPPetAdPricePresentation {
    let amount: String
    let currency: String

    init(formattedPrice: String) {
        let trimmed = formattedPrice.trimmingCharacters(in: .whitespacesAndNewlines)
        let localizedCurrency = PPPetAdLocalization.text(
            "Rials",
            fallback: "QAR"
        )

        guard !trimmed.isEmpty else {
            amount = ""
            currency = ""
            return
        }

        if let range = trimmed.range(
            of: localizedCurrency,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) {
            let strippedAmount = trimmed
                .replacingCharacters(in: range, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            amount = strippedAmount.isEmpty ? trimmed : strippedAmount
            currency = strippedAmount.isEmpty ? "" : localizedCurrency
        } else {
            amount = trimmed
            currency = ""
        }
    }
}

// MARK: - Section Heading (Shared)

struct PPPetAdDetailSectionHeading: View {
    let title: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
            RoundedRectangle(cornerRadius: PPSpace.xxs, style: .continuous)
                .fill(Color.ppPrimary)
                .frame(width: PPSpace.xs, height: 18)
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

// MARK: - Previews

#if DEBUG
@available(iOS 16.0, *)
#Preview("Arabic RTL — Full") {
    ScrollView {
        PPPetAdDetailsSummary(
            title: "قطة شيرازية بيضاء",
            location: "الدوحة، قطر",
            price: "٣٥٠ ر.ق",
            type: "شيرازي",
            age: "٦ أشهر",
            gender: "أنثى"
        )
        .padding(PPSpace.screenMargin)
    }
    .background(Color.ppBackground)
    .environment(\.layoutDirection, .rightToLeft)
}

@available(iOS 16.0, *)
#Preview("Long Content AX5") {
    ScrollView {
        PPPetAdDetailsSummary(
            title: "قطة شيرازية بيضاء نادرة ذات اسم طويل للغاية",
            location: "منطقة طويلة جداً داخل الدوحة، دولة قطر",
            price: "12,350 QAR",
            type: "شيرازي أبيض طويل الشعر",
            age: "سنة وستة أشهر",
            gender: "أنثى"
        )
        .padding(PPSpace.screenMargin)
    }
    .background(Color.ppBackground)
    .dynamicTypeSize(.accessibility5)
    .environment(\.layoutDirection, .rightToLeft)
}

@available(iOS 16.0, *)
#Preview("Missing Optional Details") {
    ScrollView {
        PPPetAdDetailsSummary(
            title: "White Persian Cat",
            location: "",
            price: "Free",
            type: "",
            age: "",
            gender: ""
        )
        .padding(PPSpace.screenMargin)
    }
    .background(Color.ppBackground)
}

@available(iOS 16.0, *)
#Preview("Price Only") {
    ScrollView {
        PPPetAdDetailsSummary(
            title: "Kitten for Adoption",
            location: "",
            price: "500 QAR",
            type: "",
            age: "",
            gender: ""
        )
        .padding(PPSpace.screenMargin)
    }
    .background(Color.ppBackground)
}

@available(iOS 16.0, *)
#Preview("Location Only") {
    ScrollView {
        PPPetAdDetailsSummary(
            title: "Rescue Dog",
            location: "Al Rayyan, Qatar",
            price: "",
            type: "",
            age: "",
            gender: ""
        )
        .padding(PPSpace.screenMargin)
    }
    .background(Color.ppBackground)
}

@available(iOS 16.0, *)
#Preview("Dark Mode") {
    ScrollView {
        PPPetAdDetailsSummary(
            title: "Golden Retriever Puppy",
            location: "Doha, Qatar",
            price: "2,500 QAR",
            type: "Golden Retriever",
            age: "3 months",
            gender: "Male"
        )
        .padding(PPSpace.screenMargin)
    }
    .background(Color.ppBackground)
    .environment(\.colorScheme, .dark)
}

@available(iOS 16.0, *)
#Preview("High Contrast") {
    ScrollView {
        PPPetAdDetailsSummary(
            title: "Siamese Cat",
            location: "Al Wakrah",
            price: "800 QAR",
            type: "Siamese",
            age: "1 year",
            gender: "Female"
        )
        .padding(PPSpace.screenMargin)
    }
    .background(Color.ppBackground)
    .environment(\.colorSchemeContrast, .increased)
}

@available(iOS 16.0, *)
#Preview("Reduce Motion") {
    ScrollView {
        PPPetAdDetailsSummary(
            title: "Arabian Mau",
            location: "Umm Salal",
            price: "Free",
            type: "Arabian Mau",
            age: "2 years",
            gender: "Male"
        )
        .padding(PPSpace.screenMargin)
    }
    .background(Color.ppBackground)
    .environment(\.accessibilityReduceMotion, true)
}
#endif
