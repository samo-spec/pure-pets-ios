import SwiftUI

struct PPPetAdDetailsSummary: View {
    let title: String
    let location: String
    let price: String
    let type: String
    let age: String
    let gender: String

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
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

struct PPPetAdHeaderCard: View {
    let title: String
    let location: String
    let price: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Text(petNameLabel)
                .font(PPPetAdTypography.footnote)
                .foregroundStyle(Color.ppTextSecondary.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
                Text(verbatim: "\u{2068}\(displayTitle)\u{2069}")
                    .font(PPPetAdTypography.title)
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !price.isEmpty {
                    Spacer(minLength: PPSpace.xs)
                    PPPetAdPriceView(price: price)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(petNameLabel): \(displayTitle)")
            .accessibilityAddTraits(.isHeader)

            if !location.isEmpty {
                locationLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
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
        HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
            Image(systemName: "location.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.ppTextSecondary.opacity(0.64))
                .accessibilityHidden(true)

            Text(verbatim: "\u{2068}\(location)\u{2069}")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(PPPetAdTypography.callout)
        .foregroundStyle(Color.ppTextSecondary.opacity(0.76))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(PPPetAdLocalization.text("Location", fallback: "Location")): \(location)"
        )
    }
}

private struct PPPetAdPriceView: View {
    let price: String

    private var parsed: (amount: String, currency: String, isLeading: Bool) {
        let trimmed = price.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", "", false) }

        if let firstChar = trimmed.first, !firstChar.isNumber, firstChar != "+" {
            let currencyStr = String(firstChar)
            let amountStr = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            if !amountStr.isEmpty {
                return (amountStr, currencyStr, true)
            }
        }

        let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if parts.count >= 2 {
            let first = parts[0]
            let rest = parts.dropFirst().joined(separator: " ")
            let cleanFirst = first.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: ".", with: "")
            if Double(cleanFirst) != nil || first.rangeOfCharacter(from: .decimalDigits) != nil {
                return (first, rest, false)
            } else {
                let last = parts.last!
                let front = parts.dropLast().joined(separator: " ")
                return (last, front, true)
            }
        }

        return (trimmed, "", false)
    }

    var body: some View {
        let (amount, currency, isLeading) = parsed

        HStack(alignment: .firstTextBaseline, spacing: 3) {
            if isLeading && !currency.isEmpty {
                Text(currency)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.ppTextSecondary.opacity(0.60))
            }

            Text(verbatim: "\u{2068}\(amount)\u{2069}")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ppTextPrimary)
                .monospacedDigit()

            if !isLeading && !currency.isEmpty {
                Text(currency)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.ppTextSecondary.opacity(0.60))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(PPPetAdLocalization.text("Price", fallback: "Price")): \(price)")
    }
}

struct PPPetAdDetailSectionHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(PPPetAdTypography.headline)
            .foregroundStyle(Color.ppTextPrimary)
            .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
