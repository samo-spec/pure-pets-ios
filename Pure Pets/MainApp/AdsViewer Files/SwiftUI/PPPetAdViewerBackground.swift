import SwiftUI

struct PPPetAdViewerBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    var body: some View {
        ZStack {
            Color.ppBackground

            if !reduceTransparency {
                Circle()
                    .fill(Color.ppPrimary.opacity(colorScheme == .dark ? 0.10 : 0.07))
                    .frame(width: 330, height: 330)
                    .blur(radius: 48)
                    .offset(x: 190, y: -280)

                Circle()
                    .fill(Color.ppPrimaryShiner.opacity(colorScheme == .dark ? 0.07 : 0.045))
                    .frame(width: 290, height: 290)
                    .blur(radius: 54)
                    .offset(x: -210, y: 360)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
