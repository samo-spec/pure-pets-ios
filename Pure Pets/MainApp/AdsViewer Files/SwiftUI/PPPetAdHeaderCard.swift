import SwiftUI

// MARK: - PPPetAdDetailsSummary (Consumer)

@MainActor
@available(iOS 16.0, *)
struct PPPetAdDetailsSummary: View {
    let title: String
    let location: String
    let price: String
    let type: String
    let age: String
    let gender: String
    var ad: PetAd? = nil

    @ObservedObject private var interactionState: PPPetAdViewerInteractionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        title: String,
        location: String,
        price: String,
        type: String,
        age: String,
        gender: String,
        ad: PetAd? = nil,
        interactionState: PPPetAdViewerInteractionState? = nil
    ) {
        self.title = title
        self.location = location
        self.price = price
        self.type = type
        self.age = age
        self.gender = gender
        self.ad = ad
        _interactionState = ObservedObject(
            wrappedValue: interactionState ?? PPPetAdViewerInteractionState()
        )
    }

    var body: some View {
        PPPetAdAdaptiveSummaryLayout(
            identityExtent: interactionState.mainHeaderExtent
        ) {
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
                }
            }
            .opacity(Double(interactionState.mainHeaderVisibility))
            .offset(
                y: reduceMotion
                    ? 0
                    : -PPSpace.sm * (1 - interactionState.mainHeaderVisibility)
            )
            .accessibilityHidden(!interactionState.mainHeaderOwnsAccessibility)

            if hasFacts {
                PPPetAdInfoGrid(type: type, age: age, gender: gender)
                    .padding(.top, PPSpace.xs)
            }
        }
        .clipped()
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
    }

    private var hasFacts: Bool {
        !type.isEmpty || !age.isEmpty || !gender.isEmpty
    }
}

@available(iOS 16.0, *)
private struct PPPetAdAdaptiveSummaryLayout: Layout {
    let identityExtent: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let sizes = measuredSizes(proposal: proposal, subviews: subviews)
        guard let identity = sizes.first else { return .zero }

        let factsHeight = sizes.dropFirst().first?.height ?? 0
        let width = proposal.width ?? sizes.map(\.width).max() ?? 0
        return CGSize(
            width: width,
            height: identity.height + factsHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let sizes = measuredSizes(
            proposal: ProposedViewSize(width: bounds.width, height: nil),
            subviews: subviews
        )
        guard let identity = subviews.first,
              let identitySize = sizes.first else { return }

        identity.place(
            at: CGPoint(
                x: bounds.minX,
                y: bounds.minY
            ),
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: bounds.width,
                height: identitySize.height
            )
        )

        guard subviews.count > 1 else { return }
        let facts = subviews[subviews.index(after: subviews.startIndex)]
        facts.place(
            at: CGPoint(
                x: bounds.minX,
                y: bounds.minY + identitySize.height
            ),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: nil)
        )
    }

    private var clampedExtent: CGFloat {
        min(max(identityExtent, 0), 1)
    }

    private func measuredSizes(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> [CGSize] {
        subviews.map {
            $0.sizeThatFits(
                ProposedViewSize(width: proposal.width, height: nil)
            )
        }
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
        identityBlock
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var identityBlock: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            Text(petNameLabel)
                .font(PPPetAdTypography.footnoteBold)
                .foregroundStyle(Color.ppPrimary)
                .accessibilityHidden(true)

            titlePriceLayout

            metadataRow
        }
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(3)
    }

    @ViewBuilder
    private var titlePriceLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stackedTitlePrice
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: PPSpace.base) {
                    titleText
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                    if !price.isEmpty {
                        PPPetAdPriceView(price: price)
                            .accessibilitySortPriority(2)
                    }
                }

                stackedTitlePrice
            }
        }
    }

    private var stackedTitlePrice: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            titleText
                .frame(maxWidth: .infinity, alignment: .leading)

            if !price.isEmpty {
                PPPetAdPriceView(price: price)
                    .accessibilitySortPriority(2)
            }
        }
    }

    @ViewBuilder
    private var metadataRow: some View {
        if !location.isEmpty || freshnessText != nil {
            HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
                if !location.isEmpty {
                    Label {
                        Text(location)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    } icon: {
                        Image(systemName: "mappin.and.ellipse")
                    }
                    .accessibilityLabel(
                        "\(PPPetAdLocalization.text("Location", fallback: "Location")): \(location)"
                    )
                }

                if !location.isEmpty, freshnessText != nil {
                    Circle()
                        .fill(Color.ppTextSecondary.opacity(0.56))
                        .frame(width: PPSpace.xxs, height: PPSpace.xxs)
                        .accessibilityHidden(true)
                }

                if let freshnessText {
                    Text(freshnessText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(PPPetAdTypography.footnote)
            .foregroundStyle(Color.ppTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
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
