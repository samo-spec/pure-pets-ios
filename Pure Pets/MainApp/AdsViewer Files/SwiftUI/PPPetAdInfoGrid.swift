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

    var body: some View {
        LinearGradient(
            colors: [
                Color.clear,
                dividerColor,
                Color.clear
            ],
            startPoint: axis == .horizontal ? .leading : .top,
            endPoint: axis == .horizontal ? .trailing : .bottom
        )
        .frame(
            maxWidth: axis == .horizontal ? .infinity : dividerThickness,
            maxHeight: axis == .vertical ? .infinity : dividerThickness
        )
        .accessibilityHidden(true)
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

private struct PPPetAdInfoSurfaceModifier: ViewModifier {
    let accentColor: Color

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: PPCorner.card,
            style: .continuous
        )

        content
            .background {
                surfaceBackground
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    surfaceStroke,
                    lineWidth: colorSchemeContrast == .increased
                        ? 1
                        : PPPetAdViewerStyle.hairlineWidth
                )
            }
            .shadow(
                color: PPShadow.card.color,
                radius: PPShadow.card.radius,
                x: PPShadow.card.x,
                y: PPShadow.card.y
            )
    }

    private var surfaceBackground: some View {
        ZStack {
            Color.ppSurface

            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.04 : 0.20),
                    accentColor.opacity(colorScheme == .dark ? 0.075 : 0.032)
                ],
                startPoint: layoutDirection == .rightToLeft
                    ? .topTrailing
                    : .topLeading,
                endPoint: layoutDirection == .rightToLeft
                    ? .bottomLeading
                    : .bottomTrailing
            )
        }
    }

    private var surfaceStroke: Color {
        if colorSchemeContrast == .increased {
            return Color.ppBorder
        }
        return Color.white.opacity(colorScheme == .dark ? 0.12 : 0.78)
    }
}

extension View {
    func ppPetAdInfoSurface(accentColor: Color = .ppPrimary) -> some View {
        modifier(PPPetAdInfoSurfaceModifier(accentColor: accentColor))
    }
}

struct PPPetAdInfoGrid: View {
    let type: String
    let age: String
    let gender: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

    @ViewBuilder
    private var ledger: some View {
        if usesStackedLayout {
            stackedLedger
        } else {
            compactLedger
        }
    }

    private var compactLedger: some View {
        HStack(alignment: .top, spacing: PPSpace.md) {
            ForEach(allItems) { item in
                infoView(
                    for: item,
                    emphasis: item.id == featuredItem?.id
                        ? .featured
                        : .supporting,
                    showsBottomAccent: true,
                    usesCompactColumn: true
                )
                .frame(maxWidth: .infinity)
                .ppPetAdInfoSurface(accentColor: item.signature.accentColor)
            }
        }
    }

    private var stackedLedger: some View {
        VStack(spacing: PPSpace.md) {
            ForEach(allItems) { item in
                infoView(
                    for: item,
                    emphasis: item.id == featuredItem?.id
                        ? .featured
                        : .supporting,
                    showsBottomAccent: true,
                    usesCompactColumn: false
                )
                .frame(maxWidth: .infinity)
                .ppPetAdInfoSurface(accentColor: item.signature.accentColor)
            }
        }
    }

    private var usesStackedLayout: Bool {
        dynamicTypeSize >= .xxLarge
    }

    private func infoView(
        for item: PPPetAdInfoItem,
        emphasis: PPPetAdInfoEmphasis,
        showsBottomAccent: Bool,
        usesCompactColumn: Bool
    ) -> some View {
        PPPetAdInfoPillView(
            systemIcon: item.systemIcon,
            assetIcon: item.assetIcon,
            label: item.label,
            value: item.value,
            signature: item.signature,
            emphasis: emphasis,
            showsBottomAccent: showsBottomAccent,
            usesCompactColumn: usesCompactColumn
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
