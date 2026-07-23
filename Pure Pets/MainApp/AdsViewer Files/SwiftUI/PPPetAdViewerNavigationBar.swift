import SwiftUI

/// Floating viewer chrome that morphs continuously from an invisible
/// overlay into a frosted navigation bar as the hero scrolls away.
struct PPPetAdViewerNavigationBar: View {
    let title: String
    let isCollapsed: Bool
    let scrollOffset: CGFloat
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

    /// Continuous 0→1 collapse progress across a 160pt scroll window.
    private var progress: Double {
        if isCollapsed { return 1 }
        return min(1, max(0, Double(-scrollOffset / 160.0)))
    }

    /// Title appears only in the final third of the morph.
    private var titleOpacity: Double {
        min(1, max(0, (progress - 0.66) / 0.34))
    }

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            navigationButton(
                symbol: layoutDirection == .rightToLeft
                    ? "chevron.forward"
                    : "chevron.backward",
                label: PPPetAdLocalization.text("Back", fallback: "Back"),
                action: onBack
            )
            .accessibilitySortPriority(4)

            Text(title)
                .font(PPPetAdTypography.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .opacity(titleOpacity)
                .offset(y: reduceMotion ? 0 : (1 - titleOpacity) * 8)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(titleOpacity < 1)

            HStack(spacing: PPSpace.xs) {
                if canShare {
                    navigationButton(
                        symbol: "square.and.arrow.up",
                        label: PPPetAdLocalization.text(
                            "Share",
                            fallback: "Share"
                        ),
                        action: onShare
                    )
                }

                if canFavorite {
                    navigationButton(
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
                        tint: isFavorite ? Color.ppPrimary : .white,
                        isEnabled: !isFavoriteWorking,
                        isLoading: isFavoriteWorking,
                        action: onFavorite
                    )
                    .scaleEffect(isFavorite ? 1.12 : 1)
                    .animation(
                        reduceMotion ? nil : PPPetAdViewerMotion.heartPop,
                        value: isFavorite
                    )
                }

                if canReport {
                    navigationButton(
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
            .accessibilitySortPriority(3)
        }
        .padding(.horizontal, PPSpace.base)
        .padding(.vertical, PPSpace.sm)
        .background { chromeBackground }
    }
}

// MARK: - Chrome background & buttons

private extension PPPetAdViewerNavigationBar {
    /// Two crossfading layers: a legibility gradient over the hero and a
    /// frosted material that solidifies as content scrolls beneath it.
    var chromeBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .black.opacity(0.52),
                    .black.opacity(0.16),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(1 - progress)

            Color.black.opacity(0.30)
                .background(.ultraThinMaterial)
                .opacity(progress)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.white.opacity(0.16))
                        .frame(height: 0.75)
                        .opacity(progress)
                }
        }
        .ignoresSafeArea(edges: .top)
        .accessibilityHidden(true)
    }

    func navigationButton(
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
            .frame(width: 42, height: 42)
            .background(
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(
                        Color.black.opacity(0.28 - progress * 0.16)
                    )
                }
            )
            .overlay {
                Circle()
                    .stroke(
                        Color.white.opacity(0.32 - progress * 0.12),
                        lineWidth: 0.75
                    )
            }
            .shadow(
                color: Color.black.opacity(0.16),
                radius: 8,
                y: 3
            )
            .contentShape(Circle())
        }
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.88))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.52)
        .accessibilityLabel(label)
        .accessibilityValue(
            isLoading
                ? PPPetAdLocalization.text("Loading", fallback: "Loading")
                : ""
        )
    }
}

