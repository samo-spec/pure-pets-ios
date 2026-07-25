import SwiftUI

struct PPPetAdDescriptionCard: View {
    let title: String
    let description: String

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            Text(title)
                .font(PPPetAdTypography.headline)
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(normalizedDescription)
                .font(PPPetAdTypography.body)
                .foregroundStyle(Color.ppTextSecondary.opacity(0.78))
                .lineSpacing(4)
                .lineLimit(isExpanded ? nil : 6)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if shouldOfferExpansion {
                Button {
                    var transaction = Transaction(
                        animation:
                            reduceMotion
                            ? nil
                            : PPPetAdViewerMotion.expansion
                    )
                    transaction.disablesAnimations = reduceMotion
                    withTransaction(transaction) {
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
                            .font(.system(size: 11, weight: .bold))
                            .rotationEffect(
                                .degrees(isExpanded ? 180 : 0)
                            )
                            .accessibilityHidden(true)
                    }
                    .font(PPPetAdTypography.calloutBold)
                    .foregroundStyle(
                        PPPetAdViewerStyle.actionAccent
                    )
                    .padding(.horizontal, PPSpace.md)
                    .frame(minHeight: 44)
                    .background {
                        Capsule()
                            .fill(
                                PPPetAdViewerStyle.actionAccent.opacity(0.10)
                            )
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        PPPetAdViewerStyle.actionAccent.opacity(
                                            0.22
                                        ),
                                        lineWidth:
                                            PPPetAdViewerStyle
                                                .hairlineWidth
                                    )
                            }
                    }
                }
                .buttonStyle(
                    PPPetAdPressButtonStyle(pressedScale: 0.97)
                )
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
        .background(
            PPPetAdViewerStyle.sheetBackground,
            in: RoundedRectangle(
                cornerRadius: PPPetAdViewerStyle.descriptionRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PPPetAdViewerStyle.descriptionRadius,
                style: .continuous
            )
            .strokeBorder(
                Color(uiColor: .separator).opacity(
                    colorSchemeContrast == .increased ? 0.72 : 0.32
                ),
                style: StrokeStyle(
                    lineWidth:
                        colorSchemeContrast == .increased
                        ? 1.5
                        : 1,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [7, 6]
                )
            )
        }
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
