import SwiftUI

// MARK: - PPPetAdDetailsSummary

@available(iOS 16.0, *)
struct PPPetAdDetailsSummary: View {
    let title: String
    let location: String
    let price: String
    let type: String
    let age: String
    let gender: String
    var ad: PetAd? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PPPetAdHeaderCard(
                title: title,
                location: location,
                price: price,
                postedDate: ad?.postedDate,
                showsFactsConnector: hasFacts
            )

            if hasFacts {
                PPPetAdInfoGrid(type: type, age: age, gender: gender)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var hasFacts: Bool {
        !type.isEmpty || !age.isEmpty || !gender.isEmpty
    }
}

// MARK: - PPPetAdHeaderCard

@available(iOS 16.0, *)
struct PPPetAdHeaderCard: View {
    let title: String
    let location: String
    let price: String
    var postedDate: Date? = nil
    var showsFactsConnector = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            adaptiveHeader

            if showsLocationBridge {
                PPPetAdLocationBridge(
                    location: location,
                    freshness: freshnessText,
                    continuesToFacts: showsFactsConnector
                )
                .padding(.vertical, PPSpace.lg)
                .accessibilitySortPriority(1)
            } else if showsFactsConnector {
                PPPetAdFadingDivider(axis: .horizontal)
                    .padding(.vertical, PPSpace.lg)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var adaptiveHeader: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            identityView
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var identityView: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Text(petNameLabel)
                .font(PPPetAdTypography.footnoteBold)
                .foregroundStyle(Color.ppPrimary)
                .accessibilityHidden(true)

            titlePriceRow
        }
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(3)
    }

    @ViewBuilder
    private var titlePriceRow: some View {
        if price.isEmpty {
            titleText
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if dynamicTypeSize.isAccessibilitySize {
            stackedTitlePriceRow
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: PPSpace.md) {
                    titleText
                        .layoutPriority(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    PPPetAdPriceView(price: price)
                        .fixedSize(horizontal: true, vertical: true)
                        .accessibilitySortPriority(2)
                }

                stackedTitlePriceRow
            }
        }
    }

    private var stackedTitlePriceRow: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            titleText
                .frame(maxWidth: .infinity, alignment: .leading)

            PPPetAdPriceView(price: price)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilitySortPriority(2)
        }
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

    private var showsLocationBridge: Bool {
        !location.isEmpty || freshnessText != nil
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

// MARK: - Price

@available(iOS 16.0, *)
private struct PPPetAdPriceView: View {
    let price: String

    private var presentation: PPPetAdPricePresentation {
        PPPetAdPricePresentation(formattedPrice: price)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PPSpace.xs) {
            Text(verbatim: "\u{2068}\(presentation.amount)\u{2069}")
                .font(PPPetAdTypography.dominantPrice)
                .foregroundStyle(Color.ppPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.trailing)

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

// MARK: - Location bridge

@available(iOS 16.0, *)
private struct PPPetAdLocationBridge: View {
    let location: String
    let freshness: String?
    let continuesToFacts: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                compactLayout
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var compactLayout: some View {
        HStack(spacing: PPSpace.sm) {
            bridgeSeparator
                .frame(minWidth: PPSpace.xl)

            if !location.isEmpty {
                locationContent
                    .layoutPriority(1)
            }

            if let freshness {
                freshnessContent(freshness)
            }

            bridgeSeparator
                .frame(minWidth: PPSpace.xl)
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            if !location.isEmpty {
                locationContent
            }
            if let freshness {
                freshnessContent(freshness)
            }
            if continuesToFacts {
                bridgeSeparator
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bridgeSeparator: some View {
        Capsule(style: .continuous)
            .fill(
                Color.ppPrimary.opacity(
                    colorSchemeContrast == .increased ? 0.46 : 0.26
                )
            )
            .frame(height: colorSchemeContrast == .increased ? 1.5 : 1)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var locationContent: some View {
        HStack(alignment: .center, spacing: PPSpace.sm) {
            ZStack {
                Circle()
                    .fill(
                        Color.ppPrimary.opacity(
                            colorSchemeContrast == .increased ? 0.24 : 0.13
                        )
                    )

                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ppPrimaryDarker)
            }
            .frame(width: PPSpace.xxxl, height: PPSpace.xxxl)
            .overlay {
                Circle()
                    .strokeBorder(
                        Color.ppPrimary.opacity(
                            colorSchemeContrast == .increased ? 0.58 : 0.30
                        ),
                        lineWidth:
                            colorSchemeContrast == .increased
                            ? 1.25
                            : PPPetAdViewerStyle.hairlineWidth
                    )
            }
            .accessibilityHidden(true)

            Text(verbatim: "\u{2068}\(location)\u{2069}")
                .font(PPPetAdTypography.subheadlineBold)
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(PPPetAdLocalization.text("Location", fallback: "Location")): \(location)"
        )
    }

    private func freshnessContent(_ text: String) -> some View {
        HStack(spacing: PPSpace.xs) {
            Circle()
                .fill(Color.ppSuccess)
                .frame(width: PPSpace.sm, height: PPSpace.sm)
                .overlay {
                    Circle()
                        .strokeBorder(
                            Color.ppSurface,
                            lineWidth: PPPetAdViewerStyle.hairlineWidth
                        )
                }
                .accessibilityHidden(true)

            Text(verbatim: text)
                .font(PPPetAdTypography.footnoteBold)
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PPPetAdLocalization.text(
                "pet_ad_viewer_freshness_label",
                fallback: "Recently posted"
            ) + ": " + text
        )
    }
}

// MARK: - Shared heading

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

#if DEBUG
@available(iOS 16.0, *)
#Preview("Arabic RTL") {
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
#Preview("Long content AX5") {
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
}

@available(iOS 16.0, *)
#Preview("Missing optional details") {
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
#endif
