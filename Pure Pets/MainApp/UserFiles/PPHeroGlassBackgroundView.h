//
//  PPHeroGlassBackgroundView.h
//  Pure Pets
//
//  Reusable decorative glass background extracted from PPUserMenuViewController hero card.
//  Contains gradient, constellation lines, animated dots, and top accent bar.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A reusable background-only UIView that renders the premium hero glass surface
/// used behind header content across the app.
///
/// Includes:
/// - Three-stop diagonal gradient
/// - Depth gradient layer
/// - Animated constellation lines
/// - 14 animated dot particles with halos
/// - Top accent bar
/// - Continuous corner radius, border, and shadow
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

/// Starts constellation line and dot pulse animations.
/// Safe to call multiple times — will not duplicate animations.
- (void)startAnimations;

/// Stops all running animations.
- (void)stopAnimations;

/// Re-applies the full color palette for the current trait collection.
/// Call this after a trait-collection change to update colors/opacities.
- (void)reapplyPalette;

@end

NS_ASSUME_NONNULL_END
