import SwiftUI

enum PPPetAdDividerAxis {
    case horizontal
    case vertical
}

struct PPPetAdFadingDivider: View {
    let axis: PPPetAdDividerAxis

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    init(axis: PPPetAdDividerAxis) {
        self.axis = axis
    }

    @ViewBuilder
    var body: some View {
        let divider = LinearGradient(
            colors: [
                Color.clear,
                dividerColor,
                Color.clear
            ],
            startPoint: axis == .horizontal ? .leading : .top,
            endPoint: axis == .horizontal ? .trailing : .bottom
        )

        if axis == .horizontal {
            divider
                .frame(maxWidth: .infinity)
                .frame(height: dividerThickness)
                .accessibilityHidden(true)
        } else {
            divider
                .frame(
                    width: dividerThickness,
                    height: PPSpace.xxxxl
                )
                .accessibilityHidden(true)
        }
    }

    private var dividerColor: Color {
        Color.ppSeparator.opacity(
            colorSchemeContrast == .increased ? 0.92 : 0.52
        )
    }

    private var dividerThickness: CGFloat {
        colorSchemeContrast == .increased
            ? 1
            : PPPetAdViewerStyle.hairlineWidth
    }
}

struct PPPetAdInfoGrid: View {
    let type: String
    let age: String
    let gender: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @ViewBuilder
    var body: some View {
        if allItems.isEmpty {
            EmptyView()
        } else {
            ledger
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .contain)
        }
    }

    private var ledger: some View {
        VStack(spacing: 0) {
            if let featuredItem {
                infoView(
                    for: featuredItem,
                    emphasis: .featured,
                    usesCompactColumn: false
                )
                .padding(.vertical, PPSpace.sm)
            }

            if !supportingItems.isEmpty {
                if featuredItem != nil {
                    horizontalDivider
                }

                if usesStackedLayout {
                    stackedSupportingLedger
                } else {
                    compactSupportingLedger
                }
            }
        }
        .padding(PPSpace.sm)
        .background(ledgerSurface)
        .overlay {
            ledgerShape
                .stroke(
                    Color.ppBorder.opacity(
                        colorSchemeContrast == .increased ? 0.88 : 0.28
                    ),
                    lineWidth: colorSchemeContrast == .increased
                        ? 1.25
                        : PPPetAdViewerStyle.hairlineWidth
                )
                .accessibilityHidden(true)
        }
    }

    private var compactSupportingLedger: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(supportingItems) { item in
                infoView(
                    for: item,
                    emphasis: .supporting,
                    usesCompactColumn: true
                )
                .frame(maxWidth: .infinity)

                if item.id != supportingItems.last?.id {
                    verticalDivider
                }
            }
        }
    }

    private var stackedSupportingLedger: some View {
        VStack(spacing: 0) {
            ForEach(supportingItems) { item in
                infoView(
                    for: item,
                    emphasis: .supporting,
                    usesCompactColumn: false
                )

                if item.id != supportingItems.last?.id {
                    horizontalDivider
                }
            }
        }
    }

    private var horizontalDivider: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(height: dividerThickness)
            .accessibilityHidden(true)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(width: dividerThickness)
            .padding(.vertical, PPSpace.md)
            .accessibilityHidden(true)
    }

    private var dividerColor: Color {
        Color.ppSeparator.opacity(
            colorSchemeContrast == .increased ? 1 : 0.72
        )
    }

    private var dividerThickness: CGFloat {
        colorSchemeContrast == .increased
            ? 1
            : PPPetAdViewerStyle.hairlineWidth
    }

    private var usesStackedLayout: Bool {
        dynamicTypeSize >= .xxLarge
    }

    private func infoView(
        for item: PPPetAdInfoItem,
        emphasis: PPPetAdInfoEmphasis,
        usesCompactColumn: Bool
    ) -> some View {
        PPPetAdInfoPillView(
            systemIcon: item.systemIcon,
            assetIcon: item.assetIcon,
            label: item.label,
            value: item.value,
            signature: item.signature,
            emphasis: emphasis,
            showsBottomAccent: emphasis == .featured,
            usesCompactColumn: usesCompactColumn
        )
    }

    private var ledgerSurface: some View {
        ledgerShape.fill(
            colorScheme == .dark
                ? Color.ppForeground.opacity(0.68)
                : Color.ppForeground.opacity(0.56)
        )
    }

    private var ledgerShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PPPetAdViewerStyle.infoRadius,
            style: .continuous
        )
    }

    private var allItems: [PPPetAdInfoItem] {
        var items: [PPPetAdInfoItem] = []
        if let featuredItem {
            items.append(featuredItem)
        }
        items.append(contentsOf: supportingItems)
        return items
    }

    private var featuredItem: PPPetAdInfoItem? {
        guard !type.isEmpty else { return nil }
        return PPPetAdInfoItem(
            id: "breed",
            systemIcon: nil,
            assetIcon: "peeking_pets",
            signature: .breed,
            label: PPPetAdLocalization.text(
                "pet_ad_viewer_breed_label",
                fallback: "Breed"
            ),
            value: type
        )
    }

    private var supportingItems: [PPPetAdInfoItem] {
        var result: [PPPetAdInfoItem] = []

        if !age.isEmpty {
            result.append(
                PPPetAdInfoItem(
                    id: "age",
                    systemIcon: "calendar",
                    assetIcon: nil,
                    signature: .age,
                    label: PPPetAdLocalization.text("Age", fallback: "Age"),
                    value: age
                )
            )
        }

        if !gender.isEmpty {
            result.append(
                PPPetAdInfoItem(
                    id: "gender",
                    systemIcon: "circle.lefthalf.filled",
                    assetIcon: nil,
                    signature: .gender,
                    label: PPPetAdLocalization.text(
                        "pet_ad_viewer_sex_label",
                        fallback: "Sex"
                    ),
                    value: gender
                )
            )
        }

        return result
    }
}

private struct PPPetAdInfoItem: Identifiable {
    let id: String
    let systemIcon: String?
    let assetIcon: String?
    let signature: PPPetAdInfoSignature
    let label: String
    let value: String
}

#if DEBUG
#Preview("Unified info bills") {
    PPPetAdInfoGrid(
        type: "شيرازي أبيض طويل الشعر",
        age: "سنة واحدة",
        gender: "أنثى"
    )
    .padding()
    .background(Color.ppBackground)
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Unified info bills AX5") {
    PPPetAdInfoGrid(
        type: "Persian longhair",
        age: "One year and six months",
        gender: "Female"
    )
    .padding()
    .background(Color.ppBackground)
    .dynamicTypeSize(.accessibility5)
}
#endif
