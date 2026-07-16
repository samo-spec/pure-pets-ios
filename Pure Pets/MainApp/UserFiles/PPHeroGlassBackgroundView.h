//
//  PPHeroGlassBackgroundView.h
//  Pure Pets
//
//  Reusable decorative glass background extracted from PPUserMenuViewController.
//  The stable Objective-C surface is backed by the shared Swift hero engine.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPHeroGlassAccentStyle) {
    PPHeroGlassAccentStyleBar = 0,
    PPHeroGlassAccentStyleCornerGlow,
    PPHeroGlassAccentStyleFullScreen
};

/// A reusable background-only UIView that renders the premium hero glass surface
/// used behind header content across the app.
///
/// Includes:
/// - Adaptive glass, depth, and contrast-aware surface layers
/// - A restrained top-right aurora beacon and ambient particle field
/// - Optional logical-leading accent bar or physical top-right corner glow
/// - Interruption-safe entrance, ambient, and touch-reactive motion
/// - Reduce Motion, low-power, thermal, and offscreen lifecycle handling
/// - Continuous corner radius and a restrained inner edge treatment
///
/// Does NOT contain any profile-specific content (avatar, name, labels, buttons).
///
/// Usage:
/// @code
///   PPHeroGlassBackgroundView *bg = [PPHeroGlassBackgroundView new];
///   bg.translatesAutoresizingMaskIntoConstraints = NO;
///   [myCard insertSubview:bg atIndex:0];
///   // pin to all edges of myCard ...
///   [bg startAnimations];
/// @endcode
@interface PPHeroGlassBackgroundView : UIView

/// Optional accent override for screens that need the hero glass surface to
/// follow local state (for example, an order status color).
/// Leave nil to preserve the default shared hero accent palette.
@property (nonatomic, strong, nullable) UIColor *accentColorOverride;
@property (nonatomic, strong, nullable) UIColor *overrideCenterGlowColor;

/// Controls how the accent is rendered. Defaults to the original slim top bar.
@property (nonatomic, assign) PPHeroGlassAccentStyle accentStyle;

/// Multiplies the decorative corner-glow opacity when `accentStyle` is
/// `PPHeroGlassAccentStyleCornerGlow`. Defaults to 1.0.
@property (nonatomic, assign) CGFloat cornerGlowOpacityMultiplier;

/// Controls the alignment and layout direction of the decorative glows.
/// Defaults to system direction (standard swapped layout).
@property (nonatomic, assign) NSInteger glowDirection;

/// Enables the optional premium signature shimmer sweep. Defaults to NO.
@property (nonatomic, assign) BOOL PPHeroApexUseShimmer;

/// Enables optional under-finger depth and lens motion. Defaults to NO.
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
