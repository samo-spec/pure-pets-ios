import SwiftUI

/// Recoverable failure and offline states — a tinted symbol, plain-spoken
/// copy, and one gradient retry action with a quiet escape hatch.
/// Entrance animated with subtle spring.
struct PPPetAdViewerErrorStateView: View {
    let isOffline: Bool
    let message: String
    let onRetry: () -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: PPSpace.xl) {
            Image(
                systemName: isOffline
                    ? "wifi.slash"
                    : "exclamationmark.triangle.fill"
            )
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(
                isOffline ? Color.ppWarning : Color.ppError
            )
            .frame(width: 88, height: 88)
            .background(
                (isOffline ? Color.ppWarning : Color.ppError)
                    .opacity(0.10),
                in: Circle()
            )

            VStack(spacing: PPSpace.sm) {
                Text(
                    isOffline
                        ? PPPetAdLocalization.text(
                            "pet_ad_viewer_offline_title",
                            fallback: "You’re offline"
                        )
                        : PPPetAdLocalization.text(
                            "pet_ad_viewer_error_title",
                            fallback: "This page did not load"
                        )
                )
                .font(PPPetAdTypography.title2)
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.center)

                Text(message)
                    .font(PPPetAdTypography.body)
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: PPSpace.md) {
                Button(action: onRetry) {
                    Label(
                        PPPetAdLocalization.text(
                            "Retry",
                            fallback: "Retry"
                        ),
                        systemImage: "arrow.clockwise"
                    )
                    .font(PPPetAdTypography.calloutBold)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(PPGradient.hero)
                    .clipShape(Capsule())
                    .shadow(
                        color: Color.ppPrimary.opacity(0.22),
                        radius: 14,
                        y: 8
                    )
                }
                .buttonStyle(PPPetAdPressButtonStyle())

                Button(action: onClose) {
                    Text(
                        PPPetAdLocalization.text(
                            "Close",
                            fallback: "Close"
                        )
                    )
                    .font(PPPetAdTypography.calloutBold)
                    .foregroundStyle(Color.ppPrimary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(PPSpace.xxl)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(reduceMotion ? 1 : (hasAppeared ? 1 : 0))
        .offset(y: reduceMotion ? 0 : (hasAppeared ? 0 : 12))
        .onAppear {
            guard !reduceMotion, !hasAppeared else {
                hasAppeared = true
                return
            }
            withAnimation(.spring(response: 0.40, dampingFraction: 0.86)) {
                hasAppeared = true
            }
        }
    }
}
