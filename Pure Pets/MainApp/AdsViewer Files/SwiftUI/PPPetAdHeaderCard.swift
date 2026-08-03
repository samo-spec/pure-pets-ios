import SwiftUI

struct PPPetAdHeroContentBlend: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.ppBackground.opacity(0),
                Color.ppBackground.opacity(0.42),
                Color.ppBackground.opacity(0.90),
                Color.ppBackground
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(
            height:
                PPPetAdViewerLayoutMetrics.trustJourneyContentBlendHeight
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct PPPetAdTrustJourneyHeader: View {
    let snapshot: PPPetAdViewerSnapshot
    let facts: [PPPetAdTrustJourneyFact]
    let isFavorite: Bool
    let isFavoriteWorking: Bool
    let canFavorite: Bool
    let onFavorite: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.lg) {
            VStack(alignment: .leading, spacing: PPSpace.sm) {
                HStack(alignment: .center, spacing: PPSpace.md) {
                    Text(displayTitle)
                        .font(PPPetAdTypography.largeTitle)
                        .foregroundStyle(Color.ppTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)

                    favoriteButton
                }

                if !displayPrice.isEmpty {
                    Text(displayPrice)
                        .font(PPPetAdTypography.dominantPrice)
                        .foregroundStyle(Color.ppAccentText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(
                            String(
                                format: PPPetAdLocalization.text(
                                    "pet_ad_trust_price_accessibility",
                                    fallback: "Price: %@"
                                ),
                                displayPrice
                            )
                        )
                } else {
                    Text(
                        PPPetAdLocalization.text(
                            "pet_ad_trust_price_on_request",
                            fallback: "Price on request"
                        )
                    )
                    .font(PPPetAdTypography.title2)
                    .foregroundStyle(Color.ppTextSecondary)
                }

                if !typeLine.isEmpty {
                    Text(typeLine)
                        .font(PPPetAdTypography.body)
                        .foregroundStyle(Color.ppTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !facts.isEmpty {
                factsLayout
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var favoriteButton: some View {
        Button(action: onFavorite) {
            Group {
                if isFavoriteWorking {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.ppAccentText)
                } else {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            isFavorite ? Color.white : Color.ppAccentText
                        )
                }
            }
            .frame(
                width: PPPetAdViewerLayoutMetrics.navigationControlSize,
                height: PPPetAdViewerLayoutMetrics.navigationControlSize
            )
            .background(
                isFavorite ? Color.ppPrimary : Color.ppSoftRose,
                in: Circle()
            )
            .overlay {
                Circle()
                    .strokeBorder(
                        Color.ppPrimary.opacity(isFavorite ? 0 : 0.22),
                        lineWidth: PPPetAdViewerStyle.hairlineWidth
                    )
            }
            .contentShape(Circle())
        }
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.92))
        .disabled(!canFavorite || isFavoriteWorking)
        .accessibilityLabel(favoriteAccessibilityLabel)
        .accessibilityValue(favoriteAccessibilityValue)
    }

    private var favoriteAccessibilityLabel: String {
        isFavorite
            ? PPPetAdLocalization.text(
                "a11y_btn_unfavorite",
                fallback: "Remove from favorites"
            )
            : PPPetAdLocalization.text(
                "a11y_btn_favorite",
                fallback: "Add to favorites"
            )
    }

    private var favoriteAccessibilityValue: String {
        if isFavoriteWorking {
            return PPPetAdLocalization.text(
                "Loading",
                fallback: "Loading"
            )
        }
        return isFavorite
            ? PPPetAdLocalization.text(
                "Selected",
                fallback: "Selected"
            )
            : ""
    }

    @ViewBuilder
    private var factsLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 0) {
                ForEach(Array(facts.enumerated()), id: \.element.id) {
                    index,
                    fact in
                    PPPetAdTrustFactView(fact: fact)
                        .padding(.vertical, PPSpace.md)

                    if index < facts.count - 1 {
                        Divider()
                            .overlay(Color.ppSeparator)
                    }
                }
            }
        } else {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(facts.enumerated()), id: \.element.id) {
                    index,
                    fact in
                    PPPetAdTrustFactView(fact: fact)
                        .frame(maxWidth: .infinity)

                    if index < facts.count - 1 {
                        Rectangle()
                            .fill(Color.ppSeparator)
                            .frame(
                                width:
                                    colorSchemeContrast == .increased
                                    ? 1.5
                                    : 1,
                                height: 48
                            )
                            .padding(.horizontal, PPSpace.sm)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private var displayTitle: String {
        let value = snapshot.title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return value.isEmpty
            ? PPPetAdLocalization.text(
                "pet_ad_viewer_title_fallback",
                fallback: "Pet advertisement"
            )
            : value
    }

    private var displayPrice: String {
        snapshot.price.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var typeLine: String {
        var values = [snapshot.category, snapshot.subcategory]
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        if values.count == 2, values[0] == values[1] {
            values.removeLast()
        }
        return values.joined(separator: " · ")
    }
}

private struct PPPetAdTrustFactView: View {
    let fact: PPPetAdTrustJourneyFact

    var body: some View {
        HStack(alignment: .top, spacing: PPSpace.sm) {
            Image(systemName: fact.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.ppAccentText)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(fact.value)
                    .font(PPPetAdTypography.calloutBold)
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(fact.label)
                    .font(PPPetAdTypography.caption)
                    .foregroundStyle(Color.ppTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
