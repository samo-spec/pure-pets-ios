import SwiftUI

struct PPPetAdInfoGrid: View {
    let type: String
    let age: String
    let gender: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        Group {
            if allItems.isEmpty {
                EmptyView()
            } else if usesStackedLayout {
                stackedLedger
            } else {
                compactLedger
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ledgerBackground,
            in: RoundedRectangle(
                cornerRadius: PPCorner.card,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PPCorner.card,
                style: .continuous
            )
            .strokeBorder(
                Color.ppSeparator.opacity(
                    colorSchemeContrast == .increased ? 1 : 0.52
                ),
                lineWidth: dividerThickness
            )
        }
        .accessibilityElement(children: .contain)
    }

    private var usesStackedLayout: Bool {
        dynamicTypeSize >= .xxLarge || dynamicTypeSize.isAccessibilitySize
    }

    @ViewBuilder
    private var compactLedger: some View {
        if let featuredItem, !supportingItems.isEmpty {
            HStack(alignment: .top, spacing: 0) {
                infoView(
                    for: featuredItem,
                    emphasis: .featured
                )
                .layoutPriority(1)

                verticalFactDivider

                supportingFactsStack
                    .frame(
                        minWidth: 116,
                        maxWidth: 214,
                        alignment: .leading
                    )
            }
        } else if let featuredItem {
            infoView(
                for: featuredItem,
                emphasis: .featured
            )
        } else if supportingItems.count == 1,
                  let item = supportingItems.first {
            infoView(
                for: item,
                emphasis: .supporting
            )
        } else {
            HStack(alignment: .top, spacing: 0) {
                ForEach(supportingItems) { item in
                    infoView(
                        for: item,
                        emphasis: .supporting
                    )
                    .frame(maxWidth: .infinity)

                    if item.id != supportingItems.last?.id {
                        verticalFactDivider
                    }
                }
            }
        }
    }

    private var stackedLedger: some View {
        VStack(spacing: 0) {
            ForEach(allItems) { item in
                infoView(
                    for: item,
                    emphasis:
                        item.id == featuredItem?.id
                        ? .featured
                        : .supporting
                )

                if item.id != allItems.last?.id {
                    factDivider
                }
            }
        }
    }

    private var supportingFactsStack: some View {
        VStack(spacing: 0) {
            ForEach(supportingItems) { item in
                infoView(
                    for: item,
                    emphasis: .supporting
                )

                if item.id != supportingItems.last?.id {
                    factDivider
                }
            }
        }
    }

    private var allItems: [PPPetAdInfoItem] {
        var items: [PPPetAdInfoItem] = []
        if let featuredItem {
            items.append(featuredItem)
        }
        items.append(contentsOf: supportingItems)
        return items
    }

    private var ledgerBackground: Color {
        Color.ppForeground.opacity(
            colorScheme == .dark ? 0.34 : 0.58
        )
    }

    private func infoView(
        for item: PPPetAdInfoItem,
        emphasis: PPPetAdInfoEmphasis
    ) -> some View {
        PPPetAdInfoPillView(
            systemIcon: item.systemIcon,
            assetIcon: item.assetIcon,
            label: item.label,
            value: item.value,
            emphasis: emphasis
        )
    }

    private var featuredItem: PPPetAdInfoItem? {
        guard !type.isEmpty else { return nil }
        return PPPetAdInfoItem(
            id: 0,
            systemIcon: nil,
            assetIcon: "peeking_pets",
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
                    id: 1,
                    systemIcon: "calendar",
                    assetIcon: nil,
                    label: PPPetAdLocalization.text(
                        "Age",
                        fallback: "Age"
                    ),
                    value: age
                )
            )
        }

        if !gender.isEmpty {
            result.append(
                PPPetAdInfoItem(
                    id: 2,
                    systemIcon: "circle.lefthalf.filled",
                    assetIcon: nil,
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

    private var factDivider: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(height: dividerThickness)
            .accessibilityHidden(true)
    }

    private var verticalFactDivider: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(width: dividerThickness)
            .padding(.vertical, PPSpace.md)
            .accessibilityHidden(true)
    }

    private var dividerColor: Color {
        Color(uiColor: .separator).opacity(
            colorSchemeContrast == .increased ? 0.68 : 0.26
        )
    }

    private var dividerThickness: CGFloat {
        colorSchemeContrast == .increased ? 1.5 : 1
    }
}

private struct PPPetAdInfoItem: Identifiable {
    let id: Int
    let systemIcon: String?
    let assetIcon: String?
    let label: String
    let value: String
}

#if DEBUG
#Preview("Info Grid") {
    PPPetAdInfoGrid(
        type: "شيرازي",
        age: "سنة واحدة",
        gender: "ذكر"
    )
    .padding()
    .background(Color.ppBackground)
}
#endif
