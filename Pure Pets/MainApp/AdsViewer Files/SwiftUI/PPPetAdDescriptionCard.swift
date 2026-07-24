import SwiftUI

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

            Text(normalizedDescription)
                .font(PPPetAdTypography.body)
                .foregroundStyle(Color.ppTextSecondary)
                .lineSpacing(5)
                .lineLimit(isExpanded ? nil : 6)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

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
                        Image(
                            systemName: isExpanded
                                ? "chevron.up"
                                : "chevron.down"
                        )
                        .font(.system(size: 12, weight: .bold))
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

    private var normalizedDescription: String {
        description
            .components(separatedBy: .newlines)
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private var shouldOfferExpansion: Bool {
        normalizedDescription.count > 260 ||
            normalizedDescription.components(separatedBy: "\n").count > 4
    }
}
