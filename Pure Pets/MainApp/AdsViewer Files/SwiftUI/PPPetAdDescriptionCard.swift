import SwiftUI

struct PPPetAdDescriptionCard: View {
    let title: String
    let description: String

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            PPPetAdDetailSectionHeading(title: title)

            Text(normalizedDescription)
                .font(PPPetAdTypography.body)
                .foregroundStyle(Color.ppTextSecondary)
                .lineSpacing(PPSpace.xs)
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
                    .foregroundStyle(PPPetAdViewerStyle.actionAccent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(
                    PPPetAdPressButtonStyle(pressedScale: 0.985)
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
        .padding(.top, PPSpace.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.ppSeparator.opacity(
                    colorSchemeContrast == .increased ? 1 : 0.72
                ))
                .frame(
                    height: colorSchemeContrast == .increased ? 1.5 : 1
                )
                .accessibilityHidden(true)
        }
        .onChange(of: description) { _ in
            isExpanded = false
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
