import SwiftUI

/// Floating chrome that morphs continuously from a cinematic legibility
/// gradient into a studio-grade frosted navigation bar as the hero scrolls.
/// A single overflow menu consolidates every trailing action to reduce
/// visual noise over the imagery.
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

    /// Title appears smoothly in the final half of the morph.
    private var titleOpacity: Double {
        min(1, max(0, (progress - 0.50) / 0.50))
    }

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            // Back — leading
            chromeButton(
                symbol: layoutDirection == .rightToLeft ? "arrow.right" : "arrow.left",
                label: PPPetAdLocalization.text("Back", fallback: "Back"),
                action: onBack
            )
            .accessibilitySortPriority(4)

            // Title — center, fades in
            Text(title)
                .font(PPPetAdTypography.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .opacity(titleOpacity)
                .offset(y: reduceMotion ? 0 : (1 - titleOpacity) * 8)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(titleOpacity < 1)

            // Overflow menu — trailing, single button
            if canShare || canFavorite || canReport {
                Menu {
                    if canShare {
                        Button(action: onShare) {
                            Label(
                                PPPetAdLocalization.text("Share", fallback: "Share"),
                                systemImage: "square.and.arrow.up"
                            )
                        }
                    }

                    if canFavorite {
                        Button(action: onFavorite) {
                            Label(
                                isFavorite
                                    ? PPPetAdLocalization.text("a11y_btn_unfavorite", fallback: "Remove from favorites")
                                    : PPPetAdLocalization.text("a11y_btn_favorite", fallback: "Add to favorites"),
                                systemImage: isFavorite ? "heart.fill" : "heart"
                            )
                        }
                        .disabled(isFavoriteWorking)
                    }

                    if canReport {
                        Button(role: .destructive, action: onReport) {
                            Label(
                                PPPetAdLocalization.text("report_ad_title", fallback: "Report advertisement"),
                                systemImage: "flag.fill"
                            )
                        }
                        .disabled(isReportWorking)
                    }

                    if canShare {
                        Divider()
                        Button(action: onShare) {
                            Label(
                                PPPetAdLocalization.text("Copy Link", fallback: "Copy Link"),
                                systemImage: "link"
                            )
                        }
                    }
                } label: {
                    chromeIcon(symbol: "ellipsis")
                }
                .accessibilityLabel(PPPetAdLocalization.text("More actions", fallback: "More actions"))
                .accessibilitySortPriority(3)
            } else {
                Color.clear.frame(width: 42, height: 42)
            }
        }
        .padding(.horizontal, PPSpace.base)
        .padding(.vertical, PPSpace.sm)
        .background { chromeBackground }
    }

    // MARK: - Chrome background

    private var chromeBackground: some View {
        ZStack {
            // Legibility gradient — visible over hero
            LinearGradient(
                colors: [.black.opacity(0.54), .black.opacity(0.16), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(1 - progress)

            // Frosted material — solidifies as content scrolls beneath
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

    // MARK: - Buttons

    private func chromeButton(
        symbol: String,
        label: String,
        tint: Color = .white,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            chromeIcon(symbol: symbol, tint: tint, isLoading: isLoading)
        }
        .buttonStyle(PPPetAdPressButtonStyle())
        .accessibilityLabel(label)
        .accessibilityValue(isLoading ? PPPetAdLocalization.text("Loading", fallback: "Loading") : "")
    }

    @ViewBuilder
    private func chromeIcon(
        symbol: String,
        tint: Color = .white,
        isLoading: Bool = false
    ) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
            Circle()
                .fill(Color.black.opacity(0.26 - progress * 0.14))

            if isLoading {
                ProgressView().tint(tint)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: 42, height: 42)
        .overlay {
            Circle()
                .stroke(Color.white.opacity(0.30 - progress * 0.10), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
        .contentShape(Circle())
    }
}
