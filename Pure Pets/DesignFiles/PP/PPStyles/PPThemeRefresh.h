//
//  PPThemeRefresh.h
//  Pure Pets
//
//  Automatic dark/light theme refresh for the entire view hierarchy.
//
//  HOW IT WORKS
//  ────────────
//  1. PPThemeManager posts PPThemeDidChangeNotification after every toggle.
//  2. UIView+PPTheme stores a semantic UIColor alongside every
//     layer.borderColor / layer.shadowColor assignment made through
//     pp_setBorderColor: / pp_setShadowColor:.
//  3. On traitCollectionDidChange, the view re-resolves the stored
//     UIColor to a fresh CGColorRef for the new appearance.
//  4. UIViewController+PPTheme provides a -pp_refreshThemeColors
//     override point that is called automatically when the trait
//     collection changes.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted by PPThemeManager after the window's interface style changes.
extern NSNotificationName const PPThemeDidChangeNotification;

#pragma mark - UIView+PPTheme

@interface UIView (PPTheme)

/// Assigns layer.borderColor and remembers the semantic UIColor so it can
/// be re-resolved automatically when the trait collection changes.
- (void)pp_setBorderColor:(nullable UIColor *)color;

/// Assigns layer.shadowColor and remembers the semantic UIColor.
- (void)pp_setShadowColor:(nullable UIColor *)color;

/// Re-resolves all stored dynamic layer colors for the current trait
/// collection.  Called automatically by -traitCollectionDidChange: when
/// the color appearance has changed.
- (void)pp_resolveLayerColors;

/// Recursively walks the entire subview tree and re-resolves layer colors.
/// Useful on the window or a root view after a theme toggle.
- (void)pp_resolveLayerColorsRecursively;

@end

#pragma mark - UIViewController+PPTheme

@interface UIViewController (PPTheme)

/// Override in subclasses to update hardcoded / non-dynamic colors,
/// reload visible cells, or refresh gradient layers.
/// The default implementation calls -pp_resolveLayerColors on self.view
/// and reloads visible cells of any UITableView / UICollectionView.
- (void)pp_refreshThemeColors;

@end

NS_ASSUME_NONNULL_END
