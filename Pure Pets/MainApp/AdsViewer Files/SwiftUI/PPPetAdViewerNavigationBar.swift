import SwiftUI

struct PPPetAdViewerNavigationBar: View {
    let title: String
    let isCollapsed: Bool
    let isFavorite: Bool
    let isFavoriteWorking: Bool
    let canShare: Bool
    let canFavorite: Bool
    let canReport: Bool
    let isReportWorking: Bool
    let onBack: () -> Void
    let onFavorite: () -> Void
    let onShare: () -> Void
    let onReport: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasActions: Bool {
        canShare || canFavorite || canReport
    }

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            backButton

            if isCollapsed {
                Text(title)
                    .font(PPPetAdTypography.headline)
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, PPSpace.xs)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .move(edge: .top))
                    )
            } else {
                Spacer(minLength: PPSpace.sm)
            }

            if hasActions {
                actionGroup
            }
        }
        .padding(.horizontal, PPSpace.base)
        .padding(.vertical, PPPetAdViewerLayoutMetrics.navigationVerticalPadding)
        .animation(
            reduceMotion ? nil : PPPetAdViewerMotion.navigation,
            value: isCollapsed
        )
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(
                systemName: layoutDirection == .rightToLeft
                    ? "chevron.right"
                    : "chevron.left"
            )
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(
                width: PPPetAdViewerLayoutMetrics.navigationControlSize,
                height: PPPetAdViewerLayoutMetrics.navigationControlSize
            )
            .contentShape(Circle())
        }
        .ppGlassSurface(
            in: Circle(),
            tint: Color.black.opacity(0.16),
            fallback: Color.black.opacity(0.84)
        )
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.88))
        .accessibilityLabel(
            PPPetAdLocalization.text("Back", fallback: "Back")
        )
    }

    private var actionGroup: some View {
        HStack(spacing: 0) {
            if canShare {
                actionButton(
                    symbol: "square.and.arrow.up",
                    label: PPPetAdLocalization.text(
                        "Share",
                        fallback: "Share"
                    ),
                    action: onShare
                )
            }

            if canFavorite {
                actionButton(
                    symbol: isFavorite ? "heart.fill" : "heart",
                    label: isFavorite
                        ? PPPetAdLocalization.text(
                            "a11y_btn_unfavorite",
                            fallback: "Remove from favorites"
                        )
                        : PPPetAdLocalization.text(
                            "a11y_btn_favorite",
                            fallback: "Add to favorites"
                        ),
                    tint: isFavorite ? .ppPrimaryShiner : .white,
                    isEnabled: !isFavoriteWorking,
                    isLoading: isFavoriteWorking,
                    action: onFavorite
                )
                .scaleEffect(isFavorite ? 1.04 : 1)
                .animation(
                    reduceMotion ? nil : PPPetAdViewerMotion.expansion,
                    value: isFavorite
                )
            }

            if canReport {
                actionButton(
                    symbol: "ellipsis",
                    label: PPPetAdLocalization.text(
                        "report_ad_title",
                        fallback: "Report advertisement"
                    ),
                    isEnabled: !isReportWorking,
                    isLoading: isReportWorking,
                    action: onReport
                )
            }
        }
        .padding(3)
        .ppGlassSurface(
            in: Capsule(),
            tint: Color.black.opacity(0.16),
            fallback: Color.black.opacity(0.84)
        )
        .fixedSize()
    }

    private func actionButton(
        symbol: String,
        label: String,
        tint: Color = .white,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(tint)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tint)
                }
            }
            .frame(width: 40, height: 40)
            .contentShape(Circle())
        }
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.88))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.52)
        .accessibilityLabel(label)
        .accessibilityValue(
            isLoading
                ? PPPetAdLocalization.text(
                    "Loading",
                    fallback: "Loading"
                )
                : ""
        )
    }
}
