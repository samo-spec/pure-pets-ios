import SwiftUI

struct PPPetAdInfoGrid: View {
    let type: String
    let age: String
    let gender: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let featuredItem {
                infoView(
                    for: featuredItem,
                    emphasis: .featured
                )

                if !supportingItems.isEmpty {
                    factDivider
                }
            }

            supportingFacts
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            factDivider
        }
        .overlay(alignment: .bottom) {
            factDivider
        }
        .accessibilityElement(children: .contain)
    }

    private var usesStackedLayout: Bool {
        dynamicTypeSize >= .xxLarge
    }

    @ViewBuilder
    private var supportingFacts: some View {
        if !supportingItems.isEmpty {
            if usesStackedLayout || supportingItems.count == 1 {
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
            colorSchemeContrast == .increased ? 0.64 : 0.24
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
