import SwiftUI

struct PPPetAdRelatedSection: View {
    let title: String
    let subtitle: String
    let state: PPPetAdViewerSectionState
    let items: [PPPetAdRelatedItem]
    let onRetry: () -> Void
    let onSelect: (PPPetAdRelatedItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(title)
                    .font(PPPetAdTypography.title2)
                    .foregroundStyle(Color.ppTextPrimary)
                    .accessibilityAddTraits(.isHeader)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(PPPetAdTypography.subheadline)
                        .foregroundStyle(Color.ppTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, PPSpace.screenMargin)

            sectionContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch state {
        case .idle, .loading:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PPSpace.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        loadingCard
                    }
                }
                .padding(.horizontal, PPSpace.screenMargin)
                .padding(.vertical, PPSpace.xs)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                PPPetAdLocalization.text(
                    "Loading",
                    fallback: "Loading recommendations"
                )
            )
        case .loaded:
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: PPSpace.md) {
                    ForEach(items) { item in
                        PPPetAdRelatedCard(item: item) {
                            onSelect(item)
                        }
                    }
                }
                .padding(.horizontal, PPSpace.screenMargin)
                .padding(.vertical, PPSpace.xs)
            }
        case .empty:
            stateCard(
                symbol: "sparkles",
                title: PPPetAdLocalization.text(
                    "pet_ad_viewer_related_empty",
                    fallback: "Nothing similar yet"
                ),
                message: PPPetAdLocalization.text(
                    "pet_ad_viewer_related_empty_detail",
                    fallback:
                        "New listings appear often. Check back again soon."
                ),
                actionTitle: nil,
                tint: .ppPrimary,
                action: nil
            )
        case let .offline(message):
            stateCard(
                symbol: "wifi.slash",
                title: PPPetAdLocalization.text(
                    "pet_ad_viewer_related_offline",
                    fallback: "Recommendations are offline"
                ),
                message: message,
                actionTitle: PPPetAdLocalization.text(
                    "Retry",
                    fallback: "Retry"
                ),
                tint: .ppWarning,
                action: onRetry
            )
        case let .failed(message):
            stateCard(
                symbol: "exclamationmark.arrow.triangle.2.circlepath",
                title: PPPetAdLocalization.text(
                    "pet_ad_viewer_related_failed",
                    fallback: "Recommendations did not load"
                ),
                message: message,
                actionTitle: PPPetAdLocalization.text(
                    "Retry",
                    fallback: "Retry"
                ),
                tint: .ppError,
                action: onRetry
            )
        }
    }

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
            .fill(Color.ppTextTertiary.opacity(0.10))
            .frame(height: 168)

            VStack(alignment: .leading, spacing: PPSpace.sm) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.ppTextTertiary.opacity(0.15))
                    .frame(width: 176, height: 15)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.ppTextTertiary.opacity(0.10))
                    .frame(width: 128, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.ppPrimary.opacity(0.12))
                    .frame(width: 92, height: 15)
            }
            .padding(.horizontal, PPSpace.base)
            .padding(.bottom, PPSpace.base)
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
                Color(uiColor: .separator).opacity(0.18),
                lineWidth: 0.5
            )
        }
    }

    private func stateCard(
        symbol: String,
        title: String,
        message: String,
        actionTitle: String?,
        tint: Color,
        action: (() -> Void)?
    ) -> some View {
        PPPetAdInlineStateView(
            symbol: symbol,
            title: title,
            message: message,
            actionTitle: actionTitle,
            tint: tint,
            action: action
        )
        .background(Color.ppCard)
        .clipShape(
            RoundedRectangle(
                cornerRadius: PPCorner.card,
                style: .continuous
            )
        )
        .padding(.horizontal, PPSpace.screenMargin)
    }
}
