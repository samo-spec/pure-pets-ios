// MARK: - Pure Pets iOS Design System — SwiftUI Reference
// This file provides SwiftUI equivalents of the design tokens and components
// for Pure Pets iOS. The actual app is Objective-C/UIKit, but these structures
// serve as a design reference and can be bridged via UIHostingController.

import SwiftUI

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1. DESIGN TOKENS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// MARK: Spacing

enum PPSpace {
    static let xxs: CGFloat  = 2
    static let xs: CGFloat   = 4
    static let sm: CGFloat   = 8
    static let md: CGFloat   = 12
    static let base: CGFloat = 16
    static let lg: CGFloat   = 20
    static let xl: CGFloat   = 24
    static let xxl: CGFloat  = 32
    static let xxxl: CGFloat = 40
    static let xxxxl: CGFloat = 48

    /// Screen content leading/trailing margin
    static let screenMargin: CGFloat = 20
}

// MARK: Corner Radii

enum PPCorner {
    static let verysmall: CGFloat   = 8
    static let small: CGFloat   = 12
    static let medium: CGFloat  = 18
    static let card: CGFloat    = 22
    static let hero: CGFloat    = 28
    static let large: CGFloat   = 42
    static let pill: CGFloat    = 9999

    static let continuousCurve: Bool = true
}

// MARK: Bottom decision surfaces

/// Shared geometry for persistent, product-specific bottom actions.
///
/// The Pet Ad contact rail and Accessory cart rail intentionally share this
/// physical grammar while keeping their separate state and business owners.
enum PPBottomDecisionBarGeometry {
    static let surfaceRadius: CGFloat = 34
    static let controlRadius: CGFloat = PPCorner.medium
    static let controlHeight: CGFloat = 58
    static let utilityControlSize: CGFloat = 54
    static let contentPadding: CGFloat = PPSpace.md
    static let controlSpacing: CGFloat = PPSpace.sm
    static let compactScreenInset: CGFloat = PPSpace.md
    static let regularScreenInset: CGFloat = PPSpace.xl
    static let bottomBreathingRoom: CGFloat = PPSpace.sm
}

// MARK: Shadows

struct PPShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let card     = PPShadow(color: .black.opacity(0.06), radius: 24, x: 0, y: 8)
    static let elevated = PPShadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 14)
    static let button   = PPShadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
    static let subtle   = PPShadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    static let icon     = PPShadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
}

// MARK: Colors

/// Canonical light-palette values.
///
/// Keep color values centralized here so the existing semantic Swift keys can
/// remain stable while the palette evolves.
// MARK: Colors

/// Centralized light and dark palette hex values.
private enum PPPaletteHex {
    enum Light {
        // Brand & Action
        static let brandPrimary   = "CB2654"
        static let pressedAction  = "A91E46"
        static let accentText     = "CB2654"
        static let quickActionShopping  = "D14A61"
        static let quickActionAnimals   = "9E5CAD"
        static let quickActionServices  = "47929C"
        static let quickActionCommunity = "618CB8"
        static let quickActionAdoption  = "D17F63"

        // Surfaces and fields
        static let mainBackground   = "F8F8F9"
        static let surface          = "FFFFFF"
        static let elevatedSurface  = "FFFDFC"//FFFDFC
        static let secondarySurface = "F7F1ED"
        static let warmPorcelain    = "F7F1ED"
        static let mineralBeige     = "EEE3DA"
        static let softRose         = "F6E2E8"
        static let quietLilac       = "EEEAF3"
        static let separator        = "E6DADD"
        static let border           = "E6DADD"

        // Text
        static let textPrimary   = "2A1D21"
        static let textSecondary = "75666B"
    }

    enum Dark {
        // Brand & Action
        static let action     = "CB2654"
        static let pressed    = "A91E46"
        static let accentText = "E05A7E"
        static let quickActionShopping  = "DF6A7D"
        static let quickActionAnimals   = "B881C2"
        static let quickActionServices  = "64AAB0"
        static let quickActionCommunity = "7CA0C6"
        static let quickActionAdoption  = "DB9278"

        // Surfaces and fields
        static let background       = "0E0B0C"
        static let surface          = "171214"
        static let elevatedSurface  = "21191C"
        static let secondarySurface = "2B2024"
        static let border           = "3B2D32"
        static let warmPorcelain    = "2B2024"
        static let mineralBeige     = "261E21"
        static let softRose         = "2B2024"
        static let quietLilac       = "21191D"

        // Text
        static let textPrimary   = "FFF8FA"
        static let textSecondary = "C2B4B9"
    }
}

// MARK: - Objective-C & Dynamic UIKit Bridge (Single Source of Truth)

@objc public extension UIColor {
    /// Guaranteed non-nil dynamic color provider for Light and Dark modes.
    @objc static func ppDynamicColor(light: UIColor, dark: UIColor) -> UIColor {
        let safeLight = light
        let safeDark = dark
        return UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return safeDark
            }
            return safeLight
        }
    }

    private static func dynamicHex(light: String, dark: String) -> UIColor {
        let lightColor = UIColor(Color(hex: light))
        let darkColor = UIColor(Color(hex: dark))
        return ppDynamicColor(light: lightColor, dark: darkColor)
    }

    // MARK: Brand & Action
    @objc static var ppPrimary: UIColor {
        dynamicHex(light: PPPaletteHex.Light.brandPrimary, dark: PPPaletteHex.Dark.action)
    }

    @objc static var ppPressedAction: UIColor {
        dynamicHex(light: PPPaletteHex.Light.pressedAction, dark: PPPaletteHex.Dark.pressed)
    }

    @objc static var ppPrimaryDarker: UIColor {
        ppPressedAction
    }

    @objc static var ppPrimaryShiner: UIColor {
        dynamicHex(light: PPPaletteHex.Light.softRose, dark: PPPaletteHex.Dark.secondarySurface)
    }

    @objc static var ppAccent: UIColor {
        ppPrimary
    }

    @objc static var ppAccentText: UIColor {
        dynamicHex(light: PPPaletteHex.Light.accentText, dark: PPPaletteHex.Dark.accentText)
    }

    @objc static var ppQuickActionShopping: UIColor {
        dynamicHex(
            light: PPPaletteHex.Light.quickActionShopping,
            dark: PPPaletteHex.Dark.quickActionShopping
        )
    }

    @objc static var ppQuickActionAnimals: UIColor {
        dynamicHex(
            light: PPPaletteHex.Light.quickActionAnimals,
            dark: PPPaletteHex.Dark.quickActionAnimals
        )
    }

    @objc static var ppQuickActionServices: UIColor {
        dynamicHex(
            light: PPPaletteHex.Light.quickActionServices,
            dark: PPPaletteHex.Dark.quickActionServices
        )
    }

    @objc static var ppQuickActionCommunity: UIColor {
        dynamicHex(
            light: PPPaletteHex.Light.quickActionCommunity,
            dark: PPPaletteHex.Dark.quickActionCommunity
        )
    }

    @objc static var ppQuickActionAdoption: UIColor {
        dynamicHex(
            light: PPPaletteHex.Light.quickActionAdoption,
            dark: PPPaletteHex.Dark.quickActionAdoption
        )
    }

    // MARK: Surfaces and fields
    @objc static var ppBackground: UIColor {
        dynamicHex(light: PPPaletteHex.Light.mainBackground, dark: PPPaletteHex.Dark.background)
    }

    @objc static var ppSurface: UIColor {
        dynamicHex(light: PPPaletteHex.Light.surface, dark: PPPaletteHex.Dark.surface)
    }

    @objc static var ppElevatedSurface: UIColor {
        dynamicHex(light: PPPaletteHex.Light.elevatedSurface, dark: PPPaletteHex.Dark.elevatedSurface)
    }

    @objc static var ppSecondarySurface: UIColor {
        dynamicHex(light: PPPaletteHex.Light.secondarySurface, dark: PPPaletteHex.Dark.secondarySurface)
    }

    @objc static var ppForeground: UIColor {
        ppSurface
    }

    @objc static var ppCard: UIColor {
        ppSurface
    }

    @objc static var ppWarmPorcelain: UIColor {
        dynamicHex(light: PPPaletteHex.Light.warmPorcelain, dark: PPPaletteHex.Dark.warmPorcelain)
    }

    @objc static var ppMineralBeige: UIColor {
        dynamicHex(light: PPPaletteHex.Light.mineralBeige, dark: PPPaletteHex.Dark.mineralBeige)
    }

    @objc static var ppSoftRose: UIColor {
        dynamicHex(light: PPPaletteHex.Light.softRose, dark: PPPaletteHex.Dark.softRose)
    }

    @objc static var ppQuietLilac: UIColor {
        dynamicHex(light: PPPaletteHex.Light.quietLilac, dark: PPPaletteHex.Dark.quietLilac)
    }

    @objc static var ppSeparator: UIColor {
        dynamicHex(light: PPPaletteHex.Light.separator, dark: PPPaletteHex.Dark.border)
    }

    @objc static var ppBorder: UIColor {
        dynamicHex(light: PPPaletteHex.Light.border, dark: PPPaletteHex.Dark.border)
    }

    // MARK: Text
    @objc static var ppTextPrimary: UIColor {
        dynamicHex(light: PPPaletteHex.Light.textPrimary, dark: PPPaletteHex.Dark.textPrimary)
    }

    @objc static var ppTextSecondary: UIColor {
        dynamicHex(light: PPPaletteHex.Light.textSecondary, dark: PPPaletteHex.Dark.textSecondary)
    }

    @objc static var ppTextTertiary: UIColor {
        ppDynamicColor(
            light: UIColor(Color(hex: PPPaletteHex.Light.textSecondary).opacity(0.72)),
            dark: UIColor(Color(hex: PPPaletteHex.Dark.textSecondary).opacity(0.72))
        )
    }

    // MARK: Semantic System
    @objc static var ppSuccess: UIColor {
        ppDynamicColor(
            light: UIColor(red: 0.204, green: 0.780, blue: 0.349, alpha: 1.0),
            dark: UIColor(red: 0.188, green: 0.820, blue: 0.345, alpha: 1.0)
        )
    }

    @objc static var ppWarning: UIColor {
        ppDynamicColor(
            light: UIColor(red: 1.000, green: 0.584, blue: 0.000, alpha: 1.0),
            dark: UIColor(red: 1.000, green: 0.624, blue: 0.039, alpha: 1.0)
        )
    }

    @objc static var ppError: UIColor {
        ppDynamicColor(
            light: UIColor(red: 1.000, green: 0.231, blue: 0.188, alpha: 1.0),
            dark: UIColor(red: 1.000, green: 0.271, blue: 0.227, alpha: 1.0)
        )
    }

    @objc static var ppInfo: UIColor {
        ppDynamicColor(
            light: UIColor(red: 0.000, green: 0.478, blue: 1.000, alpha: 1.0),
            dark: UIColor(red: 0.039, green: 0.518, blue: 1.000, alpha: 1.0)
        )
    }
}

// MARK: - SwiftUI Dynamic Color Tokens

public extension Color {
    // MARK: Brand & Action
    static var ppPrimary: Color        { Color(uiColor: .ppPrimary) }
    static var ppPressedAction: Color  { Color(uiColor: .ppPressedAction) }
    static var ppPrimaryDarker: Color  { Color(uiColor: .ppPrimaryDarker) }
    static var ppPrimaryShiner: Color  { Color(uiColor: .ppPrimaryShiner) }
    static var ppAccent: Color         { Color(uiColor: .ppAccent) }
    static var ppAccentText: Color     { Color(uiColor: .ppAccentText) }
    static var ppQuickActionShopping: Color  { Color(uiColor: .ppQuickActionShopping) }
    static var ppQuickActionAnimals: Color   { Color(uiColor: .ppQuickActionAnimals) }
    static var ppQuickActionServices: Color  { Color(uiColor: .ppQuickActionServices) }
    static var ppQuickActionCommunity: Color { Color(uiColor: .ppQuickActionCommunity) }
    static var ppQuickActionAdoption: Color  { Color(uiColor: .ppQuickActionAdoption) }

    // MARK: Surfaces and fields
    static var ppBackground: Color       { Color(uiColor: .ppBackground) }
    static var ppSurface: Color          { Color(uiColor: .ppSurface) }
    static var ppElevatedSurface: Color  { Color(uiColor: .ppElevatedSurface) }
    static var ppSecondarySurface: Color { Color(uiColor: .ppSecondarySurface) }
    static var ppForeground: Color       { Color(uiColor: .ppForeground) }
    static var ppCard: Color             { Color(uiColor: .ppCard) }
    static var ppWarmPorcelain: Color    { Color(uiColor: .ppWarmPorcelain) }
    static var ppMineralBeige: Color     { Color(uiColor: .ppMineralBeige) }
    static var ppSoftRose: Color         { Color(uiColor: .ppSoftRose) }
    static var ppQuietLilac: Color       { Color(uiColor: .ppQuietLilac) }
    static var ppSeparator: Color        { Color(uiColor: .ppSeparator) }
    static var ppBorder: Color           { Color(uiColor: .ppBorder) }

    // MARK: Text
    static var ppTextPrimary: Color   { Color(uiColor: .ppTextPrimary) }
    static var ppTextSecondary: Color { Color(uiColor: .ppTextSecondary) }
    static var ppTextTertiary: Color  { Color(uiColor: .ppTextTertiary) }

    // MARK: Semantic system colors
    static var ppSuccess: Color { Color(uiColor: .ppSuccess) }
    static var ppWarning: Color { Color(uiColor: .ppWarning) }
    static var ppError: Color   { Color(uiColor: .ppError) }
    static var ppInfo: Color    { Color(uiColor: .ppInfo) }
}

extension ShapeStyle where Self == Color {
    static var ppPrimary: Color { Color.ppPrimary }
    static var ppPressedAction: Color { Color.ppPressedAction }
    static var ppPrimaryDarker: Color { Color.ppPrimaryDarker }
    static var ppPrimaryShiner: Color { Color.ppPrimaryShiner }
    static var ppAccent: Color { Color.ppAccent }
    static var ppAccentText: Color { Color.ppAccentText }

    static var ppBackground: Color { Color.ppBackground }
    static var ppSurface: Color { Color.ppSurface }
    static var ppElevatedSurface: Color { Color.ppElevatedSurface }
    static var ppSecondarySurface: Color { Color.ppSecondarySurface }
    static var ppForeground: Color { Color.ppForeground }
    static var ppCard: Color { Color.ppCard }
    static var ppWarmPorcelain: Color { Color.ppWarmPorcelain }
    static var ppMineralBeige: Color { Color.ppMineralBeige }
    static var ppSoftRose: Color { Color.ppSoftRose }
    static var ppQuietLilac: Color { Color.ppQuietLilac }
    static var ppSeparator: Color { Color.ppSeparator }
    static var ppBorder: Color { Color.ppBorder }

    static var ppTextPrimary: Color { Color.ppTextPrimary }
    static var ppTextSecondary: Color { Color.ppTextSecondary }
    static var ppTextTertiary: Color { Color.ppTextTertiary }

    static var ppSuccess: Color { Color.ppSuccess }
    static var ppWarning: Color { Color.ppWarning }
    static var ppError: Color { Color.ppError }
    static var ppInfo: Color { Color.ppInfo }
}

// MARK: Gradients

enum PPGradient {
    /// Brand gradient reserved for primary actions and focused hero moments.
    static let hero = LinearGradient(
        colors: [.ppPrimary, .ppPressedAction],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Stronger brand treatment for pressed, selected or high-emphasis states.
    static let heroDark = LinearGradient(
        colors: [.ppPressedAction, .ppPrimary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Quiet card treatment built from the elevated and porcelain surfaces.
    static let card = LinearGradient(
        colors: [.ppElevatedSurface, .ppWarmPorcelain],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Light branded field for onboarding, empty states and soft feature moments.
    static let softBrandField = LinearGradient(
        colors: [.ppElevatedSurface, .ppSoftRose],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Neutral balancing field for secondary content that should not compete with actions.
    static let balancedField = LinearGradient(
        colors: [.ppWarmPorcelain, .ppMineralBeige, .ppQuietLilac],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let overlay = LinearGradient(
        colors: [.black.opacity(0), .black.opacity(0.65)],
        startPoint: .top,
        endPoint: .bottom
    )

    // Service-specific gradients
    static let vet = LinearGradient(
        colors: [Color(hex: "4A90D9"), Color(hex: "6BB3F0")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let grooming = LinearGradient(
        colors: [Color(hex: "2ECDA7"), Color(hex: "5EEDC4")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let training = LinearGradient(
        colors: [Color(hex: "FF9500"), Color(hex: "FFBC57")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let food = LinearGradient(
        colors: [Color(hex: "FF6B6B"), Color(hex: "FF9999")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: Typography

enum PPFont {
    static func largeTitle()  -> Font { .custom("Beiruti-Bold", size: 34) }
    static func title1()      -> Font { .custom("Beiruti-Bold", size: 28) }
    static func title2()      -> Font { .custom("Beiruti-Bold", size: 22) }
    static func title3()      -> Font { .custom("Beiruti-Medium", size: 20) }
    static func headline()    -> Font { .custom("Beiruti-Bold", size: 17) }
    static func body()        -> Font { .custom("Beiruti-Regular", size: 17) }
    static func callout()     -> Font { .custom("Beiruti-Regular", size: 16) }
    static func subheadline() -> Font { .custom("Beiruti-Regular", size: 15) }
    static func footnote()    -> Font { .custom("Beiruti-Regular", size: 13) }
    static func caption1()    -> Font { .custom("Beiruti-Regular", size: 12) }
    static func caption2()    -> Font { .custom("Beiruti-Regular", size: 11) }

    static func bold(_ size: CGFloat) -> Font { .custom("Beiruti-Bold", size: size) }
    static func medium(_ size: CGFloat) -> Font { .custom("Beiruti-Medium", size: size) }
    static func regular(_ size: CGFloat) -> Font { .custom("Beiruti-Regular", size: size) }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 2. REUSABLE MODIFIERS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct PPCardStyle: ViewModifier {
    var cornerRadius: CGFloat = PPCorner.card
    var shadowToken: PPShadow = .card

    func body(content: Content) -> some View {
        content
            .background(Color.ppCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: shadowToken.color, radius: shadowToken.radius, x: shadowToken.x, y: shadowToken.y)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.ppSeparator, lineWidth: 0.33)
            )
    }
}

struct PPBottomDecisionBarSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: PPCorner.hero,
            style: .continuous
        )
        let borderColor =
            colorSchemeContrast == .increased
            ? Color.ppTextPrimary.opacity(0.48)
            : Color.ppBorder.opacity(colorScheme == .dark ? 0.88 : 0.72)

        return content
            .background(Color.clear)
            .background(Color.ppElevatedSurface, in: shape)
            .overlay {
                shape.strokeBorder(
                    borderColor,
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                )
            }
            .shadow(
                color: Color.black.opacity(
                    colorScheme == .dark ? 0.16 : 0.07
                ),
                radius: 12,
                x: 0,
                y: 4
            )
    }
}

struct PPBottomDecisionPressStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.975

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                reduceMotion || !configuration.isPressed || !isEnabled
                    ? 1
                    : pressedScale
            )
            .opacity(
                !isEnabled
                    ? 0.46
                    : (configuration.isPressed ? 0.80 : 1)
            )
            .animation(
                reduceMotion
                    ? nil
                    : .spring(
                        response: 0.22,
                        dampingFraction: 0.86,
                        blendDuration: 0.02
                    ),
                value: configuration.isPressed
            )
    }
}

extension View {
    func ppBottomDecisionBarSurface() -> some View {
        modifier(PPBottomDecisionBarSurfaceModifier())
    }
}

struct PPTapFeedback: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    func ppCard(cornerRadius: CGFloat = PPCorner.card, shadow: PPShadow = .card) -> some View {
        modifier(PPCardStyle(cornerRadius: cornerRadius, shadowToken: shadow))
    }

    func ppTapFeedback() -> some View {
        modifier(PPTapFeedback())
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 3. COMPONENTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// MARK: PPButton

enum PPButtonVariant {
    case primary, secondary, tertiary, glass, destructive, icon
}

struct PPButton: View {
    let title: String
    let icon: String?
    let variant: PPButtonVariant
    let action: () -> Void

    init(_ title: String, icon: String? = nil, variant: PPButtonVariant = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.variant = variant
        self.action = action
    }

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: PPSpace.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .semibold))
                }
                Text(title)
                    .font(titleFont)
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: height)
            .padding(.horizontal, PPSpace.lg)
            .foregroundStyle(foregroundColor)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: hasShadow ? PPShadow.button.color : .clear,
                radius: hasShadow ? PPShadow.button.radius : 0,
                x: 0, y: hasShadow ? PPShadow.button.y : 0
            )
        }
        .ppTapFeedback()
    }

    // Variant properties
    private var height: CGFloat {
        switch variant {
        case .primary: return 52
        case .secondary, .glass, .destructive: return 48
        case .tertiary: return 44
        case .icon: return 44
        }
    }

    private var cornerRadius: CGFloat {
        switch variant {
        case .primary: return 26
        case .secondary, .glass, .destructive: return 24
        case .tertiary: return 22
        case .icon: return 22
        }
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .primary:
            PPGradient.hero
        case .secondary:
            Color.ppForeground
        case .tertiary:
            Color.clear
        case .glass:
            Color.clear.background(.ultraThinMaterial)
        case .destructive:
            Color.ppError.opacity(0.12)
        case .icon:
            Color.ppCard
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: return .white
        case .secondary: return .ppPrimary
        case .tertiary: return .ppPrimary
        case .glass: return .ppPrimary
        case .destructive: return .ppError
        case .icon: return .ppPrimary
        }
    }

    private var titleFont: Font {
        switch variant {
        case .primary: return PPFont.bold(17)
        case .secondary, .glass, .destructive: return PPFont.bold(16)
        case .tertiary: return PPFont.medium(16)
        case .icon: return PPFont.medium(15)
        }
    }

    private var iconSize: CGFloat {
        switch variant {
        case .primary: return 18
        case .icon: return 20
        default: return 16
        }
    }

    private var isFullWidth: Bool { variant == .primary }
    private var hasShadow: Bool { variant == .primary || variant == .secondary || variant == .icon }
}


// MARK: PPProductCard

struct PPProductCard: View {
    let name: String
    let description: String
    let price: String
    let currency: String
    let rating: Double
    let reviewCount: Int
    let imageURL: URL?
    let discount: Int? // percentage, nil = no discount
    var isFavorite: Bool = false
    var onAddToCart: (() -> Void)?
    var onFavoriteToggle: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image area
            ZStack(alignment: .topLeading) {
                // Product image placeholder
                RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                    .fill(Color.ppBackground)
                    .aspectRatio(4/3, contentMode: .fit)

                // Favorite button (top-leading in RTL = top-right visually)
                Button(action: { onFavoriteToggle?() }) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isFavorite ? .ppPrimary : .ppTextSecondary)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(PPSpace.sm)

                // Discount badge (top-trailing)
                if let discount {
                    HStack {
                        Spacer()
                        Text("-%\(discount)")
                            .font(PPFont.bold(12))
                            .foregroundStyle(.white)
                            .padding(.horizontal, PPSpace.sm)
                            .padding(.vertical, PPSpace.xs)
                            .background(PPGradient.hero)
                            .clipShape(RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous))
                    }
                    .padding(PPSpace.sm)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(name)
                    .font(PPFont.headline())
                    .foregroundStyle(.ppTextPrimary)
                    .lineLimit(2)

                Text(description)
                    .font(PPFont.footnote())
                    .foregroundStyle(.ppTextSecondary)
                    .lineLimit(1)

                // Rating
                HStack(spacing: PPSpace.xxs) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.ppWarning)
                    Text(String(format: "%.1f", rating))
                        .font(PPFont.caption1())
                        .foregroundStyle(.ppTextPrimary)
                    Text("(\(reviewCount))")
                        .font(PPFont.caption1())
                        .foregroundStyle(.ppTextTertiary)
                }

                // Price + Add to Cart
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(price)
                            .font(PPFont.bold(18))
                            .foregroundStyle(.ppTextPrimary)
                        Text(currency)
                            .font(PPFont.caption1())
                            .foregroundStyle(.ppTextSecondary)
                    }

                    Spacer()

                    Button(action: { onAddToCart?() }) {
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(PPGradient.hero)
                            .clipShape(RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous))
                    }
                    .ppTapFeedback()
                }
            }
            .padding(PPSpace.md)
        }
        .ppCard()
    }
}


// MARK: PPServiceCard

struct PPServiceCard: View {
    let title: String
    let icon: String
    let gradient: LinearGradient
    var isCompact: Bool = true

    var body: some View {
        HStack(spacing: PPSpace.md) {
            // Icon chip
            ZStack {
                RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                    .fill(gradient.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(gradient)
            }

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                Text(title)
                    .font(PPFont.headline())
                    .foregroundStyle(.ppTextPrimary)
            }

            Spacer()

            Image(systemName: "chevron.forward")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.ppTextTertiary)
                .padding(PPSpace.sm)
                .background(.ppBackground)
                .clipShape(Capsule())
        }
        .padding(PPSpace.base)
        .ppCard(cornerRadius: PPCorner.medium)
        .ppTapFeedback()
    }
}


// MARK: PPStoryRing

struct PPStoryRing: View {
    let avatarURL: URL?
    let name: String
    let isSeen: Bool

    var body: some View {
        VStack(spacing: PPSpace.xs) {
            ZStack {
                // Gradient ring (unseen) or faded ring (seen)
                Circle()
                    .strokeBorder(
                        isSeen
                            ? LinearGradient(colors: [.ppTextSecondary.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                            : PPGradient.hero,
                        lineWidth: isSeen ? 1.5 : 3
                    )
                    .frame(width: 68, height: 68)

                // Avatar
                Circle()
                    .fill(.ppCard)
                    .frame(width: 62, height: 62)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(.ppTextTertiary)
                    )
            }

            Text(name)
                .font(PPFont.caption2())
                .foregroundStyle(.ppTextPrimary)
                .lineLimit(1)
                .frame(width: 68)
        }
        .ppTapFeedback()
    }
}


// MARK: PPSectionHeader

struct PPSectionHeader: View {
    let title: String
    let emoji: String?
    let trailingText: String?
    var onTrailingTap: (() -> Void)?

    init(_ title: String, emoji: String? = nil, trailing: String? = nil, onTrailingTap: (() -> Void)? = nil) {
        self.title = title
        self.emoji = emoji
        self.trailingText = trailing
        self.onTrailingTap = onTrailingTap
    }

    var body: some View {
        HStack {
            HStack(spacing: PPSpace.xs) {
                if let emoji {
                    Text(emoji)
                }
                Text(title)
                    .font(PPFont.title3())
                    .foregroundStyle(.ppTextPrimary)
            }

            Spacer()

            if let trailingText {
                Button(action: { onTrailingTap?() }) {
                    HStack(spacing: PPSpace.xxs) {
                        Text(trailingText)
                            .font(PPFont.subheadline())
                            .foregroundStyle(.ppPrimary)
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.ppPrimary)
                    }
                }
            }
        }
        .padding(.horizontal, PPSpace.screenMargin)
    }
}


// MARK: PPOrderTrackingCard

struct PPOrderTrackingCard: View {
    let orderNumber: String
    let itemCount: Int
    let progress: Double // 0.0 - 1.0
    let estimatedTime: String
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack {
                Circle()
                    .fill(.ppSuccess)
                    .frame(width: 8, height: 8)
                Text(status)
                    .font(PPFont.bold(13))
                    .foregroundStyle(.ppSuccess)
                Spacer()
            }

            Text("طلب #\(orderNumber) • \(itemCount) منتجات")
                .font(PPFont.subheadline())
                .foregroundStyle(.ppTextSecondary)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.ppBackground)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(PPGradient.hero)
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("الوصول المتوقع: \(estimatedTime)")
                    .font(PPFont.footnote())
                    .foregroundStyle(.ppTextTertiary)

                Spacer()

                PPButton("تتبع الطلب", icon: "location.fill", variant: .tertiary) {}
            }
        }
        .padding(PPSpace.base)
        .ppCard()
    }
}


// MARK: PPDiscountBadge

struct PPDiscountBadge: View {
    let percentage: Int

    var body: some View {
        Text("-%\(percentage)")
            .font(PPFont.bold(11))
            .foregroundStyle(.white)
            .padding(.horizontal, PPSpace.sm)
            .padding(.vertical, PPSpace.xs)
            .background(PPGradient.hero)
            .clipShape(Capsule())
    }
}


// MARK: PPRatingView

struct PPRatingView: View {
    let rating: Double
    let count: Int

    var body: some View {
        HStack(spacing: PPSpace.xxs) {
            ForEach(0..<5) { index in
                Image(systemName: index < Int(rating) ? "star.fill" : (Double(index) < rating ? "star.leadinghalf.filled" : "star"))
                    .font(.system(size: 11))
                    .foregroundStyle(.ppWarning)
            }
            Text(String(format: "%.1f", rating))
                .font(PPFont.caption1())
                .foregroundStyle(.ppTextPrimary)
            Text("(\(count))")
                .font(PPFont.caption1())
                .foregroundStyle(.ppTextTertiary)
        }
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 4. HOME SCREEN COMPOSITION
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct PPHomeView: View {
    @Environment(\.layoutDirection) var layoutDirection

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: PPSpace.xl) {

                // ── Section A: Hero ──
                PPHeroSection()

                // ── Section B: Stories ──
                PPStoriesRow()

                // ── Section C: Quick Actions ──
                PPQuickActionsRow()

                // ── Section D: Category Filter ──
                PPCategoryFilter()

                // ── Section E: Services Grid ──
                PPSectionHeader("الخدمات", emoji: "🐾", trailing: "عرض الكل")
                PPServicesGrid()

                // ── Section F: Current Orders (NEW) ──
                PPSectionHeader("طلباتك الحالية", trailing: "عرض الكل")
                PPCurrentOrdersRow()

                // ── Section G: Most Popular (NEW) ──
                PPSectionHeader("الأكثر طلباً", emoji: "🔥", trailing: "عرض الكل")
                PPPopularProductsRow()

                // ── Section H: Nearby Ads ──
                PPSectionHeader("القريبة منك", emoji: "📍", trailing: "عرض الكل")
                PPNearbyAdsRow()

                // ── Section I: Special Offers (NEW) ──
                PPSectionHeader("عروض خاصة", emoji: "🏷️", trailing: "عرض الكل")
                PPSpecialOffersSection()

                // ── Section J: Banners ──
                PPBannersCarousel()

                // Bottom safe area spacer
                Color.clear.frame(height: 100)
            }
        }
        .background(.ppBackground)
        .environment(\.layoutDirection, .rightToLeft) // Arabic RTL default
    }
}


// MARK: Hero Section

struct PPHeroSection: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .fill(PPGradient.hero)
                .frame(height: 260)

            // Readability overlay
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .fill(PPGradient.overlay)

            // Content
            VStack(alignment: .leading, spacing: PPSpace.md) {
                // Status pill
                HStack {
                    Spacer()
                    Text("🟢 متصل")
                        .font(PPFont.caption1())
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, PPSpace.md)
                        .padding(.vertical, PPSpace.xs)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                Spacer()

                // Greeting
                Text("مرحباً، سناء ✨")
                    .font(PPFont.title2())
                    .foregroundStyle(.white)

                Text("اكتشف أفضل المنتجات لحيوانك الأليف")
                    .font(PPFont.subheadline())
                    .foregroundStyle(.white.opacity(0.85))

                // Location control
                HStack(spacing: PPSpace.sm) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14))
                    Text("الدوحة، قطر")
                        .font(PPFont.subheadline())
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, PPSpace.base)
                .frame(height: 44)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))

                // CTA
                PPButton("🛍️ ابدأ التسوق", variant: .secondary) {}
            }
            .padding(PPSpace.lg)
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .shadow(color: .ppPrimary.opacity(0.25), radius: 24, x: 0, y: 14)
    }
}


// MARK: Stories Row

struct PPStoriesRow: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: PPSpace.md) {
                ForEach(0..<8) { i in
                    PPStoryRing(
                        avatarURL: nil,
                        name: "حيواني \(i + 1)",
                        isSeen: i > 2
                    )
                }
            }
            .padding(.horizontal, PPSpace.screenMargin)
        }
    }
}


// MARK: Quick Actions

struct PPQuickActionsRow: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: PPSpace.md) {
                PPQuickActionItem(icon: "cross.case.fill", title: "أقرب بيطري", color: .blue)
                PPQuickActionItem(icon: "scissors", title: "حلاقة حيوانات", color: .teal)
                PPQuickActionItem(icon: "fork.knife", title: "طعام الحيوان", color: .orange)
                PPQuickActionItem(icon: "graduationcap.fill", title: "تدريب", color: .green)
            }
            .padding(.horizontal, PPSpace.screenMargin)
        }
    }
}

struct PPQuickActionItem: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: PPSpace.xl) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 56, height: 56)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))

            Text(title)
                .font(PPFont.footnote())
                .foregroundStyle(.ppTextPrimary)
                .multilineTextAlignment(.center)
                .frame(width: 80)
                .lineLimit(2)
        }
        .ppTapFeedback()
    }
}


// MARK: Placeholder sections

struct PPCategoryFilter: View {
    @State private var selected = 0
    let categories = ["الكل", "قطط", "كلاب", "طيور", "أسماك"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PPSpace.sm) {
                ForEach(categories.indices, id: \.self) { i in
                    Text(categories[i])
                        .font(PPFont.bold(13))
                        .foregroundStyle(selected == i ? .white : .ppTextSecondary)
                        .padding(.horizontal, PPSpace.base)
                        .frame(height: 36)
                        .background(selected == i ? AnyShapeStyle(PPGradient.hero) : AnyShapeStyle(Color.ppCard))
                        .clipShape(Capsule())
                        .onTapGesture { withAnimation(.spring(response: 0.3)) { selected = i } }
                }
            }
            .padding(.horizontal, PPSpace.screenMargin)
        }
    }
}

struct PPServicesGrid: View {
    var body: some View {
        VStack(spacing: PPSpace.md) {
            PPServiceCard(title: "عيادة بيطرية", icon: "cross.case.fill", gradient: PPGradient.vet)
            PPServiceCard(title: "حلاقة وتجميل", icon: "scissors", gradient: PPGradient.grooming)
        }
        .padding(.horizontal, PPSpace.screenMargin)
    }
}

struct PPCurrentOrdersRow: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PPSpace.base) {
                PPOrderTrackingCard(
                    orderNumber: "4521",
                    itemCount: 3,
                    progress: 0.75,
                    estimatedTime: "٢:٣٠ م",
                    status: "قيد التوصيل"
                )
                .frame(width: 300)
            }
            .padding(.horizontal, PPSpace.screenMargin)
        }
    }
}

struct PPPopularProductsRow: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PPSpace.base) {
                ForEach(0..<4) { _ in
                    PPProductCard(
                        name: "طعام قطط رويال كانين",
                        description: "طعام جاف للقطط البالغة",
                        price: "85",
                        currency: "ر.ق",
                        rating: 4.8,
                        reviewCount: 120,
                        imageURL: nil,
                        discount: 20
                    )
                    .frame(width: 200)
                }
            }
            .padding(.horizontal, PPSpace.screenMargin)
        }
    }
}

struct PPNearbyAdsRow: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PPSpace.base) {
                ForEach(0..<4) { _ in
                    PPProductCard(
                        name: "قط شيرازي",
                        description: "عمر ٦ أشهر • الدوحة",
                        price: "350",
                        currency: "ر.ق",
                        rating: 4.5,
                        reviewCount: 32,
                        imageURL: nil,
                        discount: nil
                    )
                    .frame(width: 200)
                }
            }
            .padding(.horizontal, PPSpace.screenMargin)
        }
    }
}

struct PPSpecialOffersSection: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .fill(PPGradient.hero)
                .frame(height: 160)

            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .fill(PPGradient.overlay)

            VStack(alignment: .leading, spacing: PPSpace.sm) {
                Text("خصم 30% على طعام القطط")
                    .font(PPFont.title2())
                    .foregroundStyle(.white)
                Text("العرض ينتهي خلال ٤٨ ساعة")
                    .font(PPFont.subheadline())
                    .foregroundStyle(.white.opacity(0.85))
                PPButton("تسوق الآن", icon: "bag.fill", variant: .secondary) {}
            }
            .padding(PPSpace.lg)
        }
        .padding(.horizontal, PPSpace.screenMargin)
    }
}

struct PPBannersCarousel: View {
    var body: some View {
        TabView {
            ForEach(0..<3) { _ in
                RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                    .fill(Color.ppCard)
                    .frame(height: 160)
                    .padding(.horizontal, PPSpace.screenMargin)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 180)
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 5. COLOR UTILITY
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            assertionFailure("Invalid hex color: \(hex)")
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 6. PREVIEW
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#Preview("Pure Pets Home") {
    PPHomeView()
}

#Preview("Components") {
    ScrollView {
        VStack(spacing: 24) {
            PPButton("ابدأ التسوق", icon: "bag.fill", variant: .primary) {}
            PPButton("عرض المنتجات", variant: .secondary) {}
            PPButton("تغيير الموقع", icon: "location.fill", variant: .glass) {}
            PPButton("حذف", icon: "trash", variant: .destructive) {}

            PPProductCard(
                name: "طعام قطط رويال كانين",
                description: "طعام جاف للقطط البالغة",
                price: "85",
                currency: "ر.ق",
                rating: 4.8,
                reviewCount: 120,
                imageURL: nil,
                discount: 20
            )
            .frame(width: 220)

            PPServiceCard(title: "عيادة بيطرية", icon: "cross.case.fill", gradient: PPGradient.vet)

            PPRatingView(rating: 4.5, count: 234)

            PPDiscountBadge(percentage: 30)
        }
        .padding()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
