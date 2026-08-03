import SwiftUI

@available(iOS 16.0, *)
struct PPPetAdTrustJourneyDetailsContent: View {
    @ObservedObject var store: PPPetAdViewerStore
    let hasAppeared: Bool
    let bottomClearance: CGFloat

    var body: some View {
        let model = PPPetAdTrustJourneyModel(
            snapshot: store.snapshot,
            owner: store.owner
        )

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PPPetAdTrustJourneyHeader(
                    snapshot: store.snapshot,
                    facts: model.facts,
                    isFavorite: store.isFavorite,
                    isFavoriteWorking: store.favoriteState == .working,
                    canFavorite:
                        store.screenState == .content
                        && !store.snapshot.ad.adID.isEmpty,
                    onFavorite: store.toggleFavorite
                )
                .ppPetAdEntrance(
                    isPresented: hasAppeared,
                    delayIndex: 0
                )

                if store.isViewingOwnAdvertisement {
                    ownerNotice
                        .padding(.top, PPSpace.lg)
                }

                Rectangle()
                    .fill(Color.ppSeparator)
                    .frame(height: 1)
                    .padding(.vertical, PPSpace.xxl)
                    .accessibilityHidden(true)

                PPPetAdTrustTimeline(
                    model: model,
                    ownerState: store.ownerState,
                    isSignedIn: store.isSignedIn
                )
                .ppPetAdEntrance(
                    isPresented: hasAppeared,
                    delayIndex: 1
                )
            }
            .padding(.horizontal, PPSpace.screenMargin)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)

            PPPetAdRelatedSection(
                kind: .pets,
                title: PPPetAdLocalization.text(
                    "Similar Ads",
                    fallback: "Similar pets"
                ),
                subtitle: PPPetAdLocalization.text(
                    "pet_ad_viewer_similar_detail",
                    fallback:
                        "More listings selected from this category."
                ),
                state: store.relatedAdsState,
                items: store.relatedAds,
                onRetry: store.retryRelatedAds,
                onSelect: store.selectRelatedItem
            )
            .padding(.top, PPSpace.xxxxl)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .ppPetAdEntrance(
                isPresented: hasAppeared,
                delayIndex: 2
            )

            PPPetAdRelatedSection(
                kind: .accessories,
                title: PPPetAdLocalization.text(
                    "Similar Accessories",
                    fallback: "Related accessories"
                ),
                subtitle: PPPetAdLocalization.text(
                    "pet_ad_viewer_accessories_detail",
                    fallback:
                        "Useful finds chosen for pets in this category."
                ),
                state: store.accessoriesState,
                items: store.relatedAccessories,
                onRetry: store.retryAccessories,
                onSelect: store.selectRelatedItem
            )
            .padding(.top, PPSpace.xxxl)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .ppPetAdEntrance(
                isPresented: hasAppeared,
                delayIndex: 3
            )

            Color.clear
                .frame(height: max(bottomClearance, PPSpace.xxxl))
                .accessibilityHidden(true)
        }
        .padding(.top, PPSpace.sm)
        .background(Color.ppBackground)
    }

    private var ownerNotice: some View {
        HStack(alignment: .top, spacing: PPSpace.sm) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.ppAccentText)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    PPPetAdLocalization.text(
                        "pet_ad_viewer_your_listing",
                        fallback: "This is your advertisement"
                    )
                )
                .font(PPPetAdTypography.calloutBold)
                .foregroundStyle(Color.ppTextPrimary)

                Text(
                    PPPetAdLocalization.text(
                        "pet_ad_viewer_your_listing_detail",
                        fallback:
                            "Contact actions are hidden when you view your own listing."
                    )
                )
                .font(PPPetAdTypography.footnote)
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(PPSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.ppSoftRose.opacity(0.72),
            in: RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
    }
}

struct PPPetAdTrustTimeline: View {
    let model: PPPetAdTrustJourneyModel
    let ownerState: PPPetAdViewerSectionState
    let isSignedIn: Bool

    var body: some View {
        VStack(spacing: 0) {
            PPPetAdTrustTimelineRow(
                symbol: "text.quote",
                title: PPPetAdLocalization.text(
                    "pet_ad_trust_story_title",
                    fallback: "Their story"
                ),
                isLast: false
            ) {
                PPPetAdTrustStorySection(story: model.story)
            }

            PPPetAdTrustTimelineRow(
                symbol: "cross.case.fill",
                title: PPPetAdLocalization.text(
                    "pet_ad_trust_health_title",
                    fallback: "Health & trust"
                ),
                isLast: false
            ) {
                VStack(spacing: PPSpace.sm) {
                    ForEach(model.evidence) { evidence in
                        PPPetAdTrustEvidenceRow(evidence: evidence)
                    }
                }
            }

            PPPetAdTrustTimelineRow(
                symbol: "person.crop.circle.fill",
                title: PPPetAdLocalization.text(
                    "pet_ad_trust_seller_title",
                    fallback: "The advertiser"
                ),
                isLast: false
            ) {
                PPPetAdTrustSellerSection(
                    model: model,
                    ownerState: ownerState,
                    isSignedIn: isSignedIn
                )
            }

            PPPetAdTrustTimelineRow(
                symbol: "checklist",
                title: PPPetAdLocalization.text(
                    "pet_ad_trust_decision_title",
                    fallback: "Before you decide"
                ),
                isLast: true
            ) {
                VStack(spacing: PPSpace.sm) {
                    ForEach(model.decisionPrompts) { prompt in
                        PPPetAdDecisionPromptRow(prompt: prompt)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PPPetAdTrustTimelineRow<Content: View>: View {
    let symbol: String
    let title: String
    let isLast: Bool
    let content: Content

    init(
        symbol: String,
        title: String,
        isLast: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.symbol = symbol
        self.title = title
        self.isLast = isLast
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: PPSpace.md) {
            timelineRail

            VStack(alignment: .leading, spacing: PPSpace.md) {
                Text(title)
                    .font(PPPetAdTypography.title2)
                    .foregroundStyle(Color.ppAccentText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, isLast ? 0 : PPSpace.xxxl)
        }
    }

    private var timelineRail: some View {
        VStack(spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.ppAccentText)
                .frame(width: 44, height: 44)
                .background(Color.ppSoftRose, in: Circle())
                .overlay {
                    Circle()
                        .stroke(
                            Color.ppPrimary.opacity(0.24),
                            lineWidth: 1
                        )
                }

            if !isLast {
                Rectangle()
                    .fill(Color.ppPrimary.opacity(0.40))
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 2)
            }
        }
        .frame(width: 44)
        .accessibilityHidden(true)
    }
}

private struct PPPetAdTrustEvidenceRow: View {
    let evidence: PPPetAdTrustEvidence

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        HStack(alignment: .top, spacing: PPSpace.md) {
            Image(systemName: statusSymbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(statusColor)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(evidence.title)
                    .font(PPPetAdTypography.calloutBold)
                    .foregroundStyle(Color.ppTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(evidence.detail)
                    .font(PPPetAdTypography.footnote)
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.ppElevatedSurface,
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
            .stroke(
                statusColor.opacity(
                    colorSchemeContrast == .increased ? 0.66 : 0.20
                ),
                lineWidth:
                    colorSchemeContrast == .increased ? 1.5 : 0.75
            )
        }
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        switch evidence.kind {
        case .verified: return .ppSuccess
        case .reviewed: return .ppPrimary
        case .provided: return .ppInfo
        case .attention: return .ppWarning
        }
    }

    private var statusSymbol: String {
        switch evidence.kind {
        case .verified: return "checkmark.seal.fill"
        case .reviewed: return "checkmark.shield.fill"
        case .provided: return "checkmark.circle.fill"
        case .attention: return "exclamationmark.circle.fill"
        }
    }
}

private struct PPPetAdDecisionPromptRow: View {
    let prompt: PPPetAdDecisionPrompt

    var body: some View {
        HStack(alignment: .top, spacing: PPSpace.md) {
            Image(systemName: prompt.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ppAccentText)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            Text(prompt.title)
                .font(PPPetAdTypography.callout)
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, PPSpace.sm)
        .accessibilityElement(children: .combine)
    }
}
