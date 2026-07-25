import SwiftUI
import UIKit

public struct PPHero: UIViewRepresentable {
    public var accentStyle: PPHeroGlassAccentStyle
    public var useShimmer: Bool
    public var useUnderFingerMotion: Bool
    public var topColor: UIColor?
    public var middleColor: UIColor?
    public var bottomColor: UIColor?

    public init(
        accentStyle: PPHeroGlassAccentStyle = .fullScreen,
        useShimmer: Bool = false,
        useUnderFingerMotion: Bool = true,
        topColor: UIColor? = nil,
        middleColor: UIColor? = nil,
        bottomColor: UIColor? = nil
    ) {
        self.accentStyle = accentStyle
        self.useShimmer = useShimmer
        self.useUnderFingerMotion = useUnderFingerMotion
        self.topColor = topColor
        self.middleColor = middleColor
        self.bottomColor = bottomColor
    }

    public func makeUIView(context: Context) -> PPBackgroundView {
        let view = PPBackgroundView()
        updateView(view)
        return view
    }

    public func updateUIView(_ uiView: PPBackgroundView, context: Context) {
        updateView(uiView)
    }

    private func updateView(_ view: PPBackgroundView) {
        view.accentStyle = accentStyle
        view.ppHeroApexUseShimmer = useShimmer
        view.ppHeroApexUseUnderFingerMotion = useUnderFingerMotion
        view.overrideTopGlowColor = topColor
        view.overrideCenterGlowColor = middleColor
        view.overrideBottomGlowColor = bottomColor
    }
}
