import SwiftUI

struct PPPetAdViewerEmptyStateView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: PPSpace.xl) {
            Image(systemName: "pawprint.circle")
                .font(.system(size: 74, weight: .light))
                .foregroundStyle(Color.ppPrimary)

            VStack(spacing: PPSpace.sm) {
                Text(
                    PPPetAdLocalization.text(
                        "pet_ad_viewer_empty_title",
                        fallback: "This advertisement is unavailable"
                    )
                )
                .font(PPPetAdTypography.title2)
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.center)

                Text(
                    PPPetAdLocalization.text(
                        "pet_ad_viewer_empty_detail",
                        fallback:
                            "It may have been removed, completed, or no longer contains displayable details."
                    )
                )
                .font(PPPetAdTypography.body)
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onClose) {
                Text(PPPetAdLocalization.text("Close", fallback: "Close"))
                    .font(PPPetAdTypography.calloutBold)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, PPSpace.xxl)
                    .frame(minHeight: 50)
                    .background(PPGradient.hero)
                    .clipShape(Capsule())
            }
            .buttonStyle(PPPetAdPressButtonStyle())
        }
        .padding(PPSpace.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
