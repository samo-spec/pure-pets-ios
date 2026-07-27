import SwiftUI
import UIKit

public struct PPHero: UIViewRepresentable {
    public var accentStyle: PPHeroGlassAccentStyle
    public var useShimmer: Bool
    public var useUnderFingerMotion: Bool
    public var surfaceColor: UIColor?
    public var topColor: UIColor?
    public var middleColor: UIColor?
    public var bottomColor: UIColor?
    public var solidColor: UIColor?

    public init(
        accentStyle: PPHeroGlassAccentStyle = .fullScreen,
        useShimmer: Bool = false,
        useUnderFingerMotion: Bool = false,
        surfaceColor: UIColor? = nil,
        topColor: UIColor? = nil,
        middleColor: UIColor? = nil,
        bottomColor: UIColor? = nil,
        solidColor: UIColor? = nil
    ) {
        self.accentStyle = accentStyle
        self.useShimmer = useShimmer
        self.useUnderFingerMotion = useUnderFingerMotion
        self.surfaceColor = surfaceColor
        self.topColor = topColor
        self.middleColor = middleColor
        self.bottomColor = bottomColor
        self.solidColor = solidColor
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
        view.overrideSurfaceColor = resolvedSurfaceColor
        view.overrideTopGlowColor = resolvedTopGlowColor
        view.overrideCenterGlowColor = resolvedMiddleGlowColor
        view.overrideBottomGlowColor = resolvedBottomGlowColor
        view.overrideSolidColor = solidColor
    }

    private var usesLightFullScreenDefaults: Bool {
        accentStyle == .fullScreen
    }

    private var resolvedSurfaceColor: UIColor? {
        surfaceColor ?? (usesLightFullScreenDefaults ? Self.fullScreenLightSurface : nil)
    }

    private var resolvedTopGlowColor: UIColor? {
        topColor ?? (usesLightFullScreenDefaults ? Self.fullScreenTopGlow : nil)
    }

    private var resolvedMiddleGlowColor: UIColor? {
        middleColor ?? (usesLightFullScreenDefaults ? Self.fullScreenMiddleGlow : nil)
    }

    private var resolvedBottomGlowColor: UIColor? {
        bottomColor ?? (usesLightFullScreenDefaults ? Self.fullScreenBottomGlow : nil)
    }

    private static let fullScreenLightSurface = UIColor(
        displayP3Red: 0.996,
        green: 0.992,
        blue: 0.974,
        alpha: 1
    )

    private static let fullScreenTopGlow = UIColor(
        displayP3Red: 1.000,
        green: 0.955,
        blue: 0.775,
        alpha: 1
    )

    private static let fullScreenMiddleGlow = UIColor(
        displayP3Red: 0.715,
        green: 0.950,
        blue: 0.925,
        alpha: 1
    )

    private static let fullScreenBottomGlow = UIColor(
        displayP3Red: 1.000,
        green: 0.780,
        blue: 0.855,
        alpha: 1
    )
}

struct PPHeroApexGlowCornerSurface: View {
    var cornerRadius: CGFloat = PPCorner.hero
    var accentStyle: PPHeroGlassAccentStyle = .cornerGlow
    var solidColor: UIColor? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: cornerRadius,
            style: .continuous
        )
        let borderColor =
            colorSchemeContrast == .increased
            ? Color.ppTextPrimary.opacity(0.48)
            : Color.ppBorder.opacity(colorScheme == .dark ? 0.72 : 0.54)

        PPHero(
            accentStyle: accentStyle,
            useShimmer: false,
            useUnderFingerMotion: false,
            solidColor: solidColor
        )
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                borderColor,
                lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
            )
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08),
            radius: 14,
            x: 0,
            y: 5
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
