import SwiftUI

@available(iOS 16.0, *)
struct PPPetAdDetailsSummary: View {
    let title: String
    let location: String
    let price: String
    let type: String
    let age: String
    let gender: String

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.xl) {
            PPPetAdHeaderCard(
                title: title,
                location: location,
                price: price
            )

            if hasFacts {
                PPPetAdInfoGrid(
                    type: type,
                    age: age,
                    gender: gender
                )
            }
        }
        .padding(.leading, PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            PPPetAdLivingAccentLine()
                .frame(width: PPSpace.xs)
                .padding(.vertical, PPSpace.xs)
        }
        .accessibilityElement(children: .contain)
    }

    private var hasFacts: Bool {
        !type.isEmpty || !age.isEmpty || !gender.isEmpty
    }
}

@available(iOS 16.0, *)
struct PPPetAdHeaderCard: View {
    let title: String
    let location: String
    let price: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            Text(petNameLabel)
                .font(PPPetAdTypography.footnoteBold)
                .foregroundStyle(Color.ppPrimary)
                .accessibilityHidden(true)

            identityAndPrice
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var identityAndPrice: some View {
        if price.isEmpty {
            identityBlock
        } else if dynamicTypeSize >= .xxLarge {
            stackedIdentityAndPrice
        } else {
            ViewThatFits(in: .horizontal) {
                horizontalIdentityAndPrice
                stackedIdentityAndPrice
            }
        }
    }

    private var horizontalIdentityAndPrice: some View {
        HStack(alignment: .top, spacing: PPSpace.lg) {
            identityBlock
                .layoutPriority(1)

            Spacer(minLength: 0)

            PPPetAdPriceView(price: price)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var stackedIdentityAndPrice: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            identityBlock
            PPPetAdPriceView(price: price)
        }
    }

    private var identityBlock: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            titleView

            if !location.isEmpty {
                locationLabel
            }
        }
    }

    private var titleView: some View {
        Text(verbatim: "\u{2068}\(displayTitle)\u{2069}")
            .font(PPPetAdTypography.largeTitle)
            .foregroundStyle(Color.ppTextPrimary)
            .lineSpacing(PPSpace.xxs)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("\(petNameLabel): \(displayTitle)")
            .accessibilityAddTraits(.isHeader)
            .accessibilitySortPriority(3)
    }

    private var displayTitle: String {
        title.isEmpty
            ? PPPetAdLocalization.text(
                "pet_ad_viewer_title_fallback",
                fallback: "Pet advertisement"
            )
            : title
    }

    private var petNameLabel: String {
        PPPetAdLocalization.text(
            "pet_ad_viewer_pet_name_label",
            fallback: "Pet name"
        )
    }

    private var locationLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: PPSpace.xs) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.ppTextSecondary)
                .accessibilityHidden(true)

            Text(verbatim: "\u{2068}\(location)\u{2069}")
                .font(PPPetAdTypography.callout)
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(PPPetAdLocalization.text("Location", fallback: "Location")): \(location)"
        )
        .accessibilitySortPriority(1)
    }
}

@available(iOS 16.0, *)
private struct PPPetAdPriceView: View {
    let price: String

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.xxs) {
            Text(PPPetAdLocalization.text("Price", fallback: "Price"))
                .font(PPPetAdTypography.caption)
                .foregroundStyle(Color.ppTextSecondary)
                .accessibilityHidden(true)

            Text(verbatim: "\u{2068}\(price)\u{2069}")
                .font(PPPetAdTypography.price)
                .foregroundStyle(Color.ppPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(PPPetAdLocalization.text("Price", fallback: "Price")): \(price)")
        .accessibilitySortPriority(2)
    }
}

@available(iOS 16.0, *)
private struct PPPetAdLivingAccentLine: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @State private var isDrawn = false
    @State private var sweepProgress: CGFloat = 0
    @State private var isSweepVisible = false
    @State private var hasCompletedMotion = false

    var body: some View {
        GeometryReader { proxy in
            let lineHeight = max(proxy.size.height, 1)
            let sweepHeight = min(max(lineHeight * 0.16, 32), 72)

            ZStack(alignment: .top) {
                Capsule(style: .continuous)
                    .fill(Color.ppPrimary)

                if !reduceMotion {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color.white.opacity(0.88),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: sweepHeight)
                        .offset(
                            y: -sweepHeight
                                + ((lineHeight + (sweepHeight * 2)) * sweepProgress)
                        )
                        .opacity(
                            isSweepVisible
                                ? (colorSchemeContrast == .increased ? 0.44 : 0.32)
                                : 0
                        )
                }
            }
            .mask {
                Capsule(style: .continuous)
            }
            .scaleEffect(
                x: 1,
                y: reduceMotion || isDrawn ? 1 : 0.01,
                anchor: .top
            )
            .opacity(reduceMotion || isDrawn ? 1 : 0)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .task(id: reduceMotion) {
            await runMotionIfNeeded()
        }
    }

    @MainActor
    private func runMotionIfNeeded() async {
        guard !reduceMotion else {
            isDrawn = true
            isSweepVisible = false
            sweepProgress = 1
            hasCompletedMotion = true
            return
        }

        guard !hasCompletedMotion else {
            isDrawn = true
            isSweepVisible = false
            sweepProgress = 1
            return
        }

        withAnimation(.easeOut(duration: 0.58)) {
            isDrawn = true
        }

        guard await pause(nanoseconds: 520_000_000) else { return }

        sweepProgress = 0
        withAnimation(.easeOut(duration: 0.12)) {
            isSweepVisible = true
        }
        withAnimation(.linear(duration: 0.86)) {
            sweepProgress = 1
        }

        guard await pause(nanoseconds: 660_000_000) else { return }

        withAnimation(.easeIn(duration: 0.20)) {
            isSweepVisible = false
        }
        hasCompletedMotion = true
    }

    private func pause(nanoseconds: UInt64) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
            try Task.checkCancellation()
            return true
        } catch {
            return false
        }
    }
}

struct PPPetAdDetailSectionHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(PPPetAdTypography.title3)
            .foregroundStyle(Color.ppTextPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
    }
}
