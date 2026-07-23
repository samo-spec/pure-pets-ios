import SwiftUI

/// The pet's story. Long copy collapses behind a soft fade with a single
/// quiet control; expanding springs open without layout jumps.
struct PPPetAdDescriptionCard: View {
    let description: String

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            Label {
                Text(
                    PPPetAdLocalization.text(
                        "pet_ad_viewer_description",
                        fallback: "About this pet"
                    )
                )
                .font(PPPetAdTypography.title3)
                .foregroundStyle(Color.ppTextPrimary)
            } icon: {
                Image(systemName: "text.quote")
                    .foregroundStyle(Color.ppPrimary)
            }
            .accessibilityAddTraits(.isHeader)

            Text(description)
                .font(PPPetAdTypography.body)
                .foregroundStyle(Color.ppTextSecondary)
                .lineSpacing(6)
                .lineLimit(isExpanded ? nil : 6)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .overlay(alignment: .bottom) {
                    collapseFade
                }

            if shouldOfferExpansion {
                Button {
                    withAnimation(
                        reduceMotion
                            ? nil
                            : PPPetAdViewerMotion.expansion
                    ) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: PPSpace.xs) {
                        Text(
                            isExpanded
                                ? PPPetAdLocalization.text(
                                    "ReadLess",
                                    fallback: "Show less"
                                )
                                : PPPetAdLocalization.text(
                                    "ReadMore",
                                    fallback: "Read more"
                                )
                        )
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .rotationEffect(
                                .degrees(isExpanded ? 180 : 0)
                            )
                    }
                    .font(PPPetAdTypography.calloutBold)
                    .foregroundStyle(Color.ppPrimary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(
                    isExpanded
                        ? PPPetAdLocalization.text(
                            "Expanded",
                            fallback: "Expanded"
                        )
                        : PPPetAdLocalization.text(
                            "Collapsed",
                            fallback: "Collapsed"
                        )
                )
            }
        }
        .padding(PPSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ppCard()
    }

    /// Soft fade suggesting more copy beneath the fold.
    @ViewBuilder
    private var collapseFade: some View {
        if !isExpanded, shouldOfferExpansion {
            LinearGradient(
                colors: [
                    Color.ppCard.opacity(0),
                    Color.ppCard
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 36)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var shouldOfferExpansion: Bool {
        description.count > 260 ||
            description.components(separatedBy: "\n").count > 4
    }
}
