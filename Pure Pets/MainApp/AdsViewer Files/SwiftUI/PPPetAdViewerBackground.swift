import SwiftUI

struct PPPetAdViewerBackground: View {
    var topColor: UIColor? = nil
    var middleColor: UIColor? = nil
    var bottomColor: UIColor? = nil

    var body: some View {
        PPHero(
            accentStyle: .fullScreen,
            useShimmer: false,
            useUnderFingerMotion: false,
            topColor: topColor,
            middleColor: middleColor,
            bottomColor: bottomColor
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
