import SwiftUI

/// A canonical, category-defining transparent navigation bar for the Pet Ad Viewer.
/// Provides glass floating action controls over the hero gallery with safe status bar clearance.
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

    private var hasOverflowActions: Bool {
        canShare || canReport
    }

    var body: some View {
        HStack(spacing: PPSpace.md) {
            backButton

            if isCollapsed {
                Text(title)
                    .font(PPPetAdTypography.subheadlineBold)
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, PPSpace.sm)
                    .accessibilityAddTraits(.isHeader)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(
                                with: .scale(scale: 0.98)
                            )
                    )
            } else {
                Spacer(minLength: PPSpace.sm)
            }

            if canFavorite {
                favoriteControl
            } else if hasOverflowActions {
                overflowMenu
            }
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.bottom, 8)
        .animation(
            reduceMotion ? nil : PPPetAdViewerMotion.navigation,
            value: isCollapsed
        )
    }

    private var backButton: some View {
        Button(action: onBack) {
            circleControl(
                symbol:
                    layoutDirection == .rightToLeft
                    ? "chevron.right"
                    : "chevron.left",
                tint: .ppTextPrimary
            )
        }
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.90))
        .accessibilityLabel(
            PPPetAdLocalization.text("Back", fallback: "Back")
        )
    }

    @ViewBuilder
    private var favoriteControl: some View {
        if hasOverflowActions {
            Menu {
                overflowActions
            } label: {
                favoriteLabel
            } primaryAction: {
                onFavorite()
            }
            .menuIndicator(.hidden)
            .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.90))
            .accessibilityLabel(favoriteAccessibilityLabel)
            .accessibilityValue(favoriteAccessibilityValue)
            .accessibilityHint(
                PPPetAdLocalization.text(
                    "pet_ad_viewer_favorite_menu_hint",
                    fallback:
                        "Tap to change favorite status. Touch and hold for more actions."
                )
            )
        } else {
            Button(action: onFavorite) {
                favoriteLabel
            }
            .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.90))
            .disabled(isFavoriteWorking)
            .accessibilityLabel(favoriteAccessibilityLabel)
            .accessibilityValue(favoriteAccessibilityValue)
        }
    }

    private var favoriteLabel: some View {
        circleControl(
            symbol: isFavorite ? "heart.fill" : "heart",
            tint: isFavorite ? .ppError : .ppTextPrimary,
            showsProgress: isFavoriteWorking
        )
    }

    private var favoriteAccessibilityLabel: String {
        isFavorite
            ? PPPetAdLocalization.text(
                "a11y_btn_unfavorite",
                fallback: "Remove from favorites"
            )
            : PPPetAdLocalization.text(
                "a11y_btn_favorite",
                fallback: "Add to favorites"
            )
    }

    private var favoriteAccessibilityValue: String {
        if isFavoriteWorking {
            return PPPetAdLocalization.text(
                "Loading",
                fallback: "Loading"
            )
        }
        return isFavorite
            ? PPPetAdLocalization.text(
                "Selected",
                fallback: "Selected"
            )
            : ""
    }

    private var overflowMenu: some View {
        Menu {
            overflowActions
        } label: {
            circleControl(
                symbol: "ellipsis",
                tint: .ppTextPrimary,
                showsProgress: isReportWorking
            )
        }
        .menuIndicator(.hidden)
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.90))
        .disabled(isReportWorking)
        .accessibilityLabel(
            PPPetAdLocalization.text("Actions", fallback: "Actions")
        )
    }

    @ViewBuilder
    private var overflowActions: some View {
        if canShare {
            Button(action: onShare) {
                Label(
                    PPPetAdLocalization.text(
                        "Share",
                        fallback: "Share"
                    ),
                    systemImage: "square.and.arrow.up"
                )
            }
        }

        if canReport {
            Button(action: onReport) {
                Label(
                    PPPetAdLocalization.text(
                        "report_ad_title",
                        fallback: "Report advertisement"
                    ),
                    systemImage: "exclamationmark.triangle"
                )
            }
            .disabled(isReportWorking)
        }
    }

    private func circleControl(
        symbol: String,
        tint: Color,
        showsProgress: Bool = false
    ) -> some View {
        ZStack {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .tint(tint)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.monochrome)
            }
        }
        .frame(width: 44, height: 44)
        .ppGlassSurface(
            in: Circle(),
            tint: Color.ppCard.opacity(0.76),
            fallback: Color(uiColor: .systemBackground).opacity(0.92),
            stroke: Color.white.opacity(0.32),
            lineWidth: PPPetAdViewerStyle.hairlineWidth
        )
        .shadow(
            color: Color.black.opacity(0.12),
            radius: 8,
            x: 0,
            y: 4
        )
        .contentShape(Circle())
    }
}

