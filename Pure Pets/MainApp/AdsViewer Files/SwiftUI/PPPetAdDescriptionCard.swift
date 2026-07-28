import SwiftUI

struct PPPetAdDescriptionCard: View {
    let title: String
    let description: String

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            storyHeading

            HStack(alignment: .top, spacing: PPSpace.md) {
                Capsule(style: .continuous)
                    .fill(
                        Color.ppPrimary.opacity(
                            colorSchemeContrast == .increased ? 0.90 : 0.58
                        )
                    )
                    .frame(width: 3)
                    .accessibilityHidden(true)

                Text(normalizedDescription)
                    .font(PPPetAdTypography.body)
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineSpacing(PPSpace.xs)
                    .lineLimit(isExpanded ? nil : 6)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(.leading, PPSpace.xs)

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
        .padding(PPSpace.base)
        .background(descriptionSurface)
        .overlay {
            descriptionShape
                .stroke(
                    Color.ppBorder.opacity(
                        colorSchemeContrast == .increased ? 0.92 : 0.36
                    ),
                    lineWidth: colorSchemeContrast == .increased
                        ? 1.5
                        : PPPetAdViewerStyle.hairlineWidth
                )
                .accessibilityHidden(true)
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.14 : 0.03),
            radius: colorScheme == .dark ? 14 : 8,
            x: 0,
            y: colorScheme == .dark ? 7 : 3
        )
        .padding(.top, PPSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: description) { _ in
            isExpanded = false
        }
    }

    private var storyHeading: some View {
        HStack(alignment: .center, spacing: PPSpace.md) {
            Image(systemName: "text.quote")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.ppPrimary)
                .frame(width: 34, height: 34)
                .background(
                    Color.ppPrimary.opacity(
                        colorSchemeContrast == .increased ? 0.16 : 0.09
                    ),
                    in: RoundedRectangle(
                        cornerRadius: PPPetAdViewerStyle.insetRadius,
                        style: .continuous
                    )
                )
                .accessibilityHidden(true)

            Text(title)
                .font(PPPetAdTypography.title3)
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
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

    private var descriptionSurface: some View {
        descriptionShape
            .fill(Color.ppCard)
    }

    private var descriptionShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PPPetAdViewerStyle.descriptionRadius,
            style: .continuous
        )
    }
}
