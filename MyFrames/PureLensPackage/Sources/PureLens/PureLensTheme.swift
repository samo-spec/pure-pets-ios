#if canImport(UIKit)
import SwiftUI
import UIKit

public struct PureLensTypography {
    public var title2: Font
    public var headline: Font
    public var body: Font
    public var subheadline: Font
    public var subheadlineEmphasized: Font
    public var footnoteEmphasized: Font
    public var caption: Font
    public var captionEmphasized: Font
    public var caption2Medium: Font

    public init(
        title2: Font,
        headline: Font,
        body: Font,
        subheadline: Font,
        subheadlineEmphasized: Font,
        footnoteEmphasized: Font,
        caption: Font,
        captionEmphasized: Font,
        caption2Medium: Font
    ) {
        self.title2 = title2
        self.headline = headline
        self.body = body
        self.subheadline = subheadline
        self.subheadlineEmphasized = subheadlineEmphasized
        self.footnoteEmphasized = footnoteEmphasized
        self.caption = caption
        self.captionEmphasized = captionEmphasized
        self.caption2Medium = caption2Medium
    }

    public static let purePets = Self(
        title2: .lensBeiruti("Beiruti-Bold", size: 22, relativeTo: .title2, fallbackWeight: .bold),
        headline: .lensBeiruti("Beiruti-Bold", size: 17, relativeTo: .headline, fallbackWeight: .bold),
        body: .lensBeiruti("Beiruti-Regular", size: 17, relativeTo: .body, fallbackWeight: .regular),
        subheadline: .lensBeiruti("Beiruti-Regular", size: 15, relativeTo: .subheadline, fallbackWeight: .regular),
        subheadlineEmphasized: .lensBeiruti("Beiruti-Bold", size: 15, relativeTo: .subheadline, fallbackWeight: .semibold),
        footnoteEmphasized: .lensBeiruti("Beiruti-Medium", size: 13, relativeTo: .footnote, fallbackWeight: .semibold),
        caption: .lensBeiruti("Beiruti-Regular", size: 12, relativeTo: .caption, fallbackWeight: .regular),
        captionEmphasized: .lensBeiruti("Beiruti-Bold", size: 12, relativeTo: .caption, fallbackWeight: .bold),
        caption2Medium: .lensBeiruti("Beiruti-Medium", size: 11, relativeTo: .caption2, fallbackWeight: .medium)
    )
}

public struct PureLensTheme {
    public var canvas: Color
    public var ambientField: Color
    public var surface: Color
    public var surfaceRaised: Color
    public var surfaceElevated: Color
    public var overlay: Color
    public var cameraChrome: Color
    public var brandStrong: Color
    public var brandSignal: Color
    public var brandPressed: Color
    public var brandSoft: Color
    public var recognition: Color
    public var textPrimary: Color
    public var textSecondary: Color
    public var textOnCamera: Color
    public var success: Color
    public var warning: Color
    public var warningOnCamera: Color
    public var danger: Color
    public var separator: Color
    public var typography: PureLensTypography

    public init(
        canvas: Color,
        ambientField: Color,
        surface: Color,
        surfaceRaised: Color,
        surfaceElevated: Color,
        overlay: Color,
        cameraChrome: Color,
        brandStrong: Color,
        brandSignal: Color,
        brandPressed: Color,
        brandSoft: Color,
        recognition: Color,
        textPrimary: Color,
        textSecondary: Color,
        textOnCamera: Color,
        success: Color,
        warning: Color,
        warningOnCamera: Color,
        danger: Color,
        separator: Color,
        typography: PureLensTypography = .purePets
    ) {
        self.canvas = canvas
        self.ambientField = ambientField
        self.surface = surface
        self.surfaceRaised = surfaceRaised
        self.surfaceElevated = surfaceElevated
        self.overlay = overlay
        self.cameraChrome = cameraChrome
        self.brandStrong = brandStrong
        self.brandSignal = brandSignal
        self.brandPressed = brandPressed
        self.brandSoft = brandSoft
        self.recognition = recognition
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.textOnCamera = textOnCamera
        self.success = success
        self.warning = warning
        self.warningOnCamera = warningOnCamera
        self.danger = danger
        self.separator = separator
        self.typography = typography
    }

    public static let purePets = Self(
        canvas: .lensAsset("AppBackgroundColor", fallback: .systemBackground),
        ambientField: .lensAsset("AppBackgroundColorDarker", fallback: .systemGroupedBackground),
        surface: .lensAsset("AppForegroundColor", fallback: .secondarySystemBackground),
        surfaceRaised: .lensAsset("AppCardColor", fallback: .secondarySystemBackground),
        surfaceElevated: .lensAsset("AppSurfColor", fallback: .systemBackground),
        overlay: Color.black.opacity(0.44),
        cameraChrome: Color.black,
        brandStrong: .lensAsset("AppPrimaryColor", fallback: .systemPink),
        brandSignal: .lensAsset("AppPrimaryColor", fallback: .systemPink),
        brandPressed: .lensAsset("AppPrimaryColorDarker", fallback: .systemPink),
        brandSoft: .lensAsset("AppPrimaryColorShainer", fallback: .secondarySystemBackground),
        recognition: .lensAsset("SuccessColor", fallback: .systemGreen),
        textPrimary: .lensAsset("PrimaryTextColor", fallback: .label),
        textSecondary: .lensAsset("SecondaryTextColor", fallback: .secondaryLabel),
        textOnCamera: Color.white,
        success: .lensAsset("SuccessColor", fallback: .systemGreen),
        warning: .lensAsset("WarningColor", fallback: .systemOrange),
        warningOnCamera: .lensAsset("WarningColor", fallback: .systemOrange),
        danger: .lensAsset("ErrorColor", fallback: .systemRed),
        separator: .lensAsset("AppLightGrayColor", fallback: .separator)
    )
}

private extension Color {
    static func lensAsset(_ name: String, fallback: UIColor) -> Color {
        Color(uiColor: UIColor(named: name, in: .main, compatibleWith: nil) ?? fallback)
    }
}

private extension Font {
    static func lensBeiruti(
        _ name: String,
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        fallbackWeight: Font.Weight
    ) -> Font {
        guard UIFont(name: name, size: size) != nil else {
            return .system(size: size, weight: fallbackWeight)
        }
        return .custom(name, size: size, relativeTo: textStyle)
    }
}


#endif
