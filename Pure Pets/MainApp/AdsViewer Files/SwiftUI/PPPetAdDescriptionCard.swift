import SwiftUI

private struct PPPetAdStoryHeightMeasurement: Equatable {
    let story: String
    let height: CGFloat

    static let empty = PPPetAdStoryHeightMeasurement(
        story: "",
        height: 0
    )
}

private struct PPPetAdCollapsedStoryHeightPreferenceKey: PreferenceKey {
    static var defaultValue = PPPetAdStoryHeightMeasurement.empty

    static func reduce(
        value: inout PPPetAdStoryHeightMeasurement,
        nextValue: () -> PPPetAdStoryHeightMeasurement
    ) {
        value = nextValue()
    }
}

private struct PPPetAdFullStoryHeightPreferenceKey: PreferenceKey {
    static var defaultValue = PPPetAdStoryHeightMeasurement.empty

    static func reduce(
        value: inout PPPetAdStoryHeightMeasurement,
        nextValue: () -> PPPetAdStoryHeightMeasurement
    ) {
        value = nextValue()
    }
}

struct PPPetAdTrustStorySection: View {
    let story: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var collapsedStoryMeasurement =
        PPPetAdStoryHeightMeasurement.empty
    @State private var fullStoryMeasurement =
        PPPetAdStoryHeightMeasurement.empty

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            if normalizedStory.isEmpty {
                HStack(alignment: .top, spacing: PPSpace.sm) {
                    Image(systemName: "text.badge.xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.ppTextTertiary)
                        .accessibilityHidden(true)

                    Text(
                        PPPetAdLocalization.text(
                            "pet_ad_trust_story_missing",
                            fallback:
                                "The advertiser has not added this pet’s story yet."
                        )
                    )
                    .font(PPPetAdTypography.body)
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                storyText(lineLimit: isExpanded ? nil : 4)
                    .background {
                        storyHeightMeasurement(
                            lineLimit: 4,
                            key: PPPetAdCollapsedStoryHeightPreferenceKey.self
                        )
                    }
                    .background {
                        storyHeightMeasurement(
                            lineLimit: nil,
                            key: PPPetAdFullStoryHeightPreferenceKey.self
                        )
                    }

                if shouldOfferExpansion {
                    Button {
                        if reduceMotion {
                            isExpanded.toggle()
                        } else {
                            withAnimation(PPPetAdViewerMotion.expansion) {
                                isExpanded.toggle()
                            }
                        }
                    } label: {
                        HStack(spacing: PPSpace.xs) {
                            Text(
                                isExpanded
                                    ? PPPetAdLocalization.text(
                                        "pet_ad_trust_read_less",
                                        fallback: "Read less"
                                    )
                                    : PPPetAdLocalization.text(
                                        "pet_ad_trust_read_more",
                                        fallback: "Read the full story"
                                    )
                            )
                            .font(PPPetAdTypography.calloutBold)

                            Image(
                                systemName:
                                    isExpanded
                                    ? "chevron.up"
                                    : "chevron.down"
                            )
                            .font(.system(size: 12, weight: .bold))
                            .accessibilityHidden(true)
                        }
                        .foregroundStyle(Color.ppAccentText)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PPPetAdPressButtonStyle())
                    .accessibilityValue(
                        isExpanded
                            ? PPPetAdLocalization.text(
                                "pet_ad_trust_expanded",
                                fallback: "Expanded"
                            )
                            : PPPetAdLocalization.text(
                                "pet_ad_trust_collapsed",
                                fallback: "Collapsed"
                            )
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onPreferenceChange(
            PPPetAdCollapsedStoryHeightPreferenceKey.self
        ) { measurement in
            guard measurement.story == normalizedStory else { return }
            collapsedStoryMeasurement = measurement
        }
        .onPreferenceChange(
            PPPetAdFullStoryHeightPreferenceKey.self
        ) { measurement in
            guard measurement.story == normalizedStory else { return }
            fullStoryMeasurement = measurement
        }
        .onChange(of: normalizedStory) { _ in
            isExpanded = false
        }
    }

    private var normalizedStory: String {
        story.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shouldOfferExpansion: Bool {
        guard collapsedStoryMeasurement.story == normalizedStory,
              fullStoryMeasurement.story == normalizedStory else {
            return false
        }
        return fullStoryMeasurement.height
            > collapsedStoryMeasurement.height + 0.5
    }

    private func storyText(lineLimit: Int?) -> some View {
        Text(normalizedStory)
            .font(PPPetAdTypography.body)
            .foregroundStyle(Color.ppTextSecondary)
            .lineSpacing(4)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func storyHeightMeasurement<Key: PreferenceKey>(
        lineLimit: Int?,
        key: Key.Type
    ) -> some View where Key.Value == PPPetAdStoryHeightMeasurement {
        storyText(lineLimit: lineLimit)
            .hidden()
            .accessibilityHidden(true)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: key,
                        value: PPPetAdStoryHeightMeasurement(
                            story: normalizedStory,
                            height: proxy.size.height
                        )
                    )
                }
            }
    }
}
