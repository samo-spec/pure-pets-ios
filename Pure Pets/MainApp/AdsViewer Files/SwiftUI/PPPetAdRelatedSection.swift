import SwiftUI

@available(iOS 16.0, *)
struct PPPetAdRelatedSection: View {
    let title: String
    let subtitle: String
    let state: PPPetAdViewerSectionState
    let items: [PPPetAdRelatedItem]
    let onRetry: () -> Void
    let onSelect: (PPPetAdRelatedItem) -> Void
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            PPPetAdSectionHeading(
                symbol: "sparkles",
                title: title,
                subtitle: subtitle
            )
            .padding(.horizontal, PPSpace.screenMargin)
            
            sectionContent
                .id(sectionStateIdentity)
                .transition(
                    reduceMotion
                    ? .opacity
                    : .opacity.combined(
                        with: .scale(scale: 0.992)
                    )
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(
            reduceMotion ? nil : PPPetAdViewerMotion.state,
            value: sectionStateIdentity
        )
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
            .frame(height: carouselHeight)
            .fixedSize(horizontal: false, vertical: true)
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
                        universalCard(for: item)
                    }
                }
                .padding(.horizontal, PPSpace.screenMargin)
                .padding(.vertical, PPSpace.xs)
            }
            .frame(height: carouselHeight)
            .fixedSize(horizontal: false, vertical: true)
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
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
            .fill(Color.ppTextTertiary.opacity(0.10))
            .frame(height: loadingImageHeight)
            
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.ppTextTertiary.opacity(0.15))
                    .frame(width: 132, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.ppTextTertiary.opacity(0.10))
                    .frame(width: 96, height: 9)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.ppPrimary.opacity(0.12))
                    .frame(width: 69, height: 12)
            }
            .padding(.horizontal, PPSpace.sm)
            .padding(.bottom, PPSpace.sm)
            .frame(
                minHeight: loadingTextAreaHeight,
                alignment: .topLeading
            )
        }
        .frame(width: loadingCardWidth)
        .clipShape(
            RoundedRectangle(
                cornerRadius: PPPetAdViewerStyle.surfaceRadius,
                style: .continuous
            )
        )
        .ppPetAdSurface()
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
        .ppPetAdSurface()
        .padding(.horizontal, PPSpace.screenMargin)
    }
    
    private func universalCard(for item: PPPetAdRelatedItem) -> some View {
        let isPetAd: Bool
        if case .petAd = item.kind {
            isPetAd = true
        } else {
            isPetAd = false
        }
        
        let imageURL = item.imageURL.flatMap(URL.init(string:))
        let model = PPUniversalCardModel(
            id: item.id,
            title: item.title,
            subtitle: item.subtitle.isEmpty ? nil : item.subtitle,
            imageURL: imageURL,
            priceText: item.price.isEmpty ? nil : item.price,
            badgeText: kindLabel(for: item),
            prefersEdgeToEdgeMedia: true
        )
        let context: PPUniversalCardContext = isPetAd ? .ads : .accessory
        
        return PPUniversalCardView(
            model: model,
            context: context,
            layout: .vertical,
            actions: PPUniversalCardActions(
                onTap: { _ in onSelect(item) }
            )
        )
        .frame(width: cardWidth)
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.97))
    }
    
    private func kindLabel(for item: PPPetAdRelatedItem) -> String {
        switch item.kind {
        case .petAd(_):
            return PPPetAdLocalization.text(
                "pet_ad_viewer_pet_badge",
                fallback: "Pet"
            )
        case .accessory(_):
            return PPPetAdLocalization.text(
                "pet_ad_viewer_accessory_badge",
                fallback: "Accessory"
            )
        }
    }

    private var cardWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 232 : 185
    }

    private var loadingCardWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 232 : 185
    }

    private var loadingImageHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 140 : 117
    }

    private var carouselHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 340 : 340
    }

    private var loadingTextAreaHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 160 : 120
    }

    private var sectionStateIdentity: Int {
        switch state {
        case .idle:
            return 0
        case .loading:
            return 1
        case .loaded:
            return 2
        case .empty:
            return 3
        case .offline:
            return 4
        case .failed:
            return 5
        }
    }
}


