import SwiftUI

/// A canonical container view presenting pet ad metadata info pills in a responsive grid.
struct PPPetAdInfoGrid: View {
    let type: String
    let age: String
    let gender: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        Group {
            if usesStackedLayout {
                accessibilityLayout
            } else {
                compactLayout
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ppCard, in: railShape)
        .overlay {
            railShape.stroke(
                Color(uiColor: .separator).opacity(
                    colorSchemeContrast == .increased ? 0.54 : 0.20
                ),
                lineWidth: colorSchemeContrast == .increased
                    ? 1.5
                    : PPPetAdViewerStyle.hairlineWidth
            )
        }
        .clipShape(railShape)
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.10 : 0.035),
            radius: 10,
            x: 0,
            y: 4
        )
        .accessibilityElement(children: .contain)
    }

    private var railShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PPPetAdViewerStyle.infoRadius,
            style: .continuous
        )
    }

    private var usesStackedLayout: Bool {
        dynamicTypeSize >= .xxLarge
    }

    private var compactLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(items) { item in
                infoView(for: item)
                    .frame(maxWidth: .infinity)

                if item.id != items.last?.id {
                    Divider()
                        .frame(height: 44)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private var accessibilityLayout: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                infoView(for: item)
                    .frame(maxWidth: .infinity)

                if item.id != items.last?.id {
                    Divider()
                        .padding(.horizontal, PPSpace.md)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func infoView(
        for item: PPPetAdInfoItem
    ) -> some View {
        PPPetAdInfoPillView(
            systemIcon: item.systemIcon,
            assetIcon: item.assetIcon,
            label: item.label,
            value: item.value
        )
    }

    private var items: [PPPetAdInfoItem] {
        var result: [PPPetAdInfoItem] = []

        if !gender.isEmpty {
            result.append(
                PPPetAdInfoItem(
                    id: 0,
                    systemIcon: "sparkles",
                    assetIcon: nil,
                    label: PPPetAdLocalization.text(
                        "pet_ad_viewer_sex_label",
                        fallback: "Sex"
                    ),
                    value: gender
                )
            )
        }

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

        if !type.isEmpty {
            result.append(
                PPPetAdInfoItem(
                    id: 2,
                    systemIcon: nil,
                    assetIcon: "peeking_pets",
                    label: PPPetAdLocalization.text(
                        "pet_ad_viewer_breed_label",
                        fallback: "Breed"
                    ),
                    value: type
                )
            )
        }

        return result
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
