import SwiftUI

struct PPPetAdInfoGrid: View {
    let type: String
    let age: String
    let gender: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: PPSpace.sm) {
                    pills
                }
            } else {
                HStack(alignment: .top, spacing: PPSpace.sm) {
                    pills
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var pills: some View {
        if !type.isEmpty {
            PPPetAdInfoPillView(
                symbol: "pawprint.fill",
                label: PPPetAdLocalization.text("Type", fallback: "Type"),
                value: type,
                tint: .ppPrimary
            )
        }

        if !age.isEmpty {
            PPPetAdInfoPillView(
                symbol: "calendar",
                label: PPPetAdLocalization.text("Age", fallback: "Age"),
                value: age,
                tint: .ppInfo
            )
        }

        if !gender.isEmpty {
            PPPetAdInfoPillView(
                symbol: "sparkles",
                label: PPPetAdLocalization.text("Gender", fallback: "Gender"),
                value: gender,
                tint: .ppWarning
            )
        }
    }
}
