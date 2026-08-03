import SwiftUI

struct PPPetAdViewerBackground: View {
    var topColor: UIColor? = nil
    var middleColor: UIColor? = nil
    var bottomColor: UIColor? = nil

    var body: some View {
        Color.ppBackground
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
