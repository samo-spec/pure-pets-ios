//
//  PPBackgroundView.h
//  Pure Pets
//
//  Reusable decorative glass background extracted from PPUserMenuViewController.
//  The stable Objective-C surface is backed by the shared Swift hero engine.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Selects the single implementation compiled for `PPBackgroundView`.
///
/// Apex is the production default. Targets that cannot link Swift may define
/// `PP_HERO_APEX_ENABLED=0` and compile `PPBackgroundView.m` as the legacy
/// fallback. Keeping both implementation files in one target is safe.
#ifndef PP_HERO_APEX_ENABLED
#define PP_HERO_APEX_ENABLED 1
#endif

typedef NS_ENUM(NSInteger, PPHeroGlassAccentStyle) {
    PPHeroGlassAccentStyleBar = 0,
    PPHeroGlassAccentStyleCornerGlow = 1,
    PPHeroGlassAccentStyleFullScreen = 2,
    PPHeroGlassAccentStyleSolid = 3,
    PPHeroGlassAccentStyleFullScreenPink = 4,
    PPHeroGlassAccentStyleFullScreenPage = 5,
    /// Opaque pearl–beige ambient field intended for a hero-backed base surface.
    PPHeroGlassAccentStyleBBBaseBackground = 6
};

/// A reusable background-only UIView that renders the premium hero glass surface
/// used behind header content across the app.
@interface PPBackgroundView : UIView

/// If YES, overrides the default borders.
@property (nonatomic, assign) BOOL overrideBorders;

/// Optional border color if overrideBorders is YES.
@property (nonatomic, strong, nullable) UIColor *overrideBorderColor;

/// Optional solid background color if accentStyle is PPHeroGlassAccentStyleSolid.
@property (nonatomic, strong, nullable) UIColor *overrideSolidColor;

/// Optional corner radius override.
@property (nonatomic, assign) CGFloat overrideCornerRadius;
@property (nonatomic, assign) CGFloat overrideCornerRaduis;

/// Optional accent override for screens that need the hero glass surface to
/// follow local state (for example, an order status color).
/// Leave nil to preserve the default shared hero accent palette.
@property (nonatomic, strong, nullable) UIColor *accentColorOverride;
@property (nonatomic, strong, nullable) UIColor *overrideCenterGlowColor;
@property (nonatomic, strong, nullable) UIColor *overrideBottomGlowColor;
@property (nonatomic, strong, nullable) UIColor *overrideTopGlowColor;
@property (nonatomic, strong, nullable) UIColor *overrideSurfureColor
    __attribute__((deprecated("Use overrideSurfaceColor")));
@property (nonatomic, strong, nullable) UIColor *overrideSurfaceColor;

/// Controls how the accent is rendered. Defaults to the original slim top bar.
@property (nonatomic, assign) PPHeroGlassAccentStyle accentStyle;

/// Multiplies the decorative corner-glow opacity when `accentStyle` is
/// `PPHeroGlassAccentStyleCornerGlow`. Defaults to 1.0.
@property (nonatomic, assign) CGFloat cornerGlowOpacityMultiplier;

/// Controls the semantic alignment of decorative glows:
/// 0 follows the interface direction, 1 pins left, and 2 pins right.
@property (nonatomic, assign) NSInteger glowDirection;

/// Enables the restrained signature shimmer sweep. Apex defaults to YES.
@property (nonatomic, assign) BOOL PPHeroApexUseShimmer;

/// Enables passive under-finger depth and lens motion. Apex defaults to YES.
@property (nonatomic, assign) BOOL PPHeroApexUseUnderFingerMotion;

/// Requests the semantic motion timeline. Safe to call repeatedly; animation
/// identity and phase are preserved whenever the view is only suspended.
- (void)startAnimations;

/// Stops motion deterministically until `startAnimations` is called again.
- (void)stopAnimations;

/// Re-applies the full color palette for the current trait collection.
/// Call this after a trait-collection change to update colors/opacities.
- (void)reapplyPalette;

@end

NS_ASSUME_NONNULL_END
