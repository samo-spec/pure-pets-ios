import SwiftUI

@available(iOS 16.0, *)
struct PPPetAdViewerNavigationBar: View {
    @ObservedObject var interactionState: PPPetAdViewerInteractionState
    let topInset: CGFloat
    let canShare: Bool
    let canReport: Bool
    let isReportWorking: Bool
    let onBack: () -> Void
    let onShare: () -> Void
    let onReport: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            navigationButton(
                symbol: "chevron.backward",
                accessibilityLabel: PPPetAdLocalization.text(
                    "Back",
                    fallback: "Back"
                ),
                action: onBack
            )

            Spacer(minLength: PPSpace.base)

            if canShare || canReport {
                optionsMenu
            }
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.vertical, PPSpace.sm)
        .padding(.top, topInset)
        .background(alignment: .top) {
            navigationScrim
        }
        .scaleEffect(
            reduceMotion ? 1 : interactionState.navigationControlScale,
            anchor: .top
        )
    }

    private var optionsMenu: some View {
        Menu {
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
                Button(role: .destructive, action: onReport) {
                    Label(
                        PPPetAdLocalization.text(
                            "report_ad_title",
                            fallback: "Report advertisement"
                        ),
                        systemImage: "exclamationmark.bubble"
                    )
                }
                .disabled(isReportWorking)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(
                    width: PPPetAdViewerLayoutMetrics.navigationControlSize,
                    height: PPPetAdViewerLayoutMetrics.navigationControlSize
                )
                .ppPetAdNavigationGlassControl()
                .contentShape(Circle())
        }
        .buttonStyle(PPPetAdPressButtonStyle())
        .accessibilityLabel(
            PPPetAdLocalization.text(
                "a11y_btn_more_options",
                fallback: "More options"
            )
        )
    }

    private func navigationButton(
        symbol: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(
                    width: PPPetAdViewerLayoutMetrics.navigationControlSize,
                    height: PPPetAdViewerLayoutMetrics.navigationControlSize
                )
                .ppPetAdNavigationGlassControl()
                .contentShape(Circle())
        }
        .buttonStyle(PPPetAdPressButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var navigationScrim: some View {
        LinearGradient(
            colors: [
                Color.ppBackground.opacity(
                    Double(max(interactionState.progress - 0.48, 0) * 1.65)
                ),
                Color.ppBackground.opacity(
                    Double(max(interactionState.progress - 0.66, 0) * 0.90)
                ),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 108 + topInset)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private extension View {
    func ppPetAdNavigationGlassControl() -> some View {
        ppGlassSurface(
            in: Circle(),
            tint: Color.black.opacity(0.20),
            fallback: Color.black.opacity(0.82),
            stroke: Color.white.opacity(0.24),
            isInteractive: true
        )
    }
}
