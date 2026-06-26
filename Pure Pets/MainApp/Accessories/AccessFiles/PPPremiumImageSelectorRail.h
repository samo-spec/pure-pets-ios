//
//  PPPremiumImageSelectorRail.h
//  Pure Pets
//
//  Ultra-premium vertical image selector rail for hero galleries.
//  Built from scratch — no legacy indicator UI.
//  Replaces PetImageGalleryView's built-in page control with a polished,
//  animated vertical thumbnail rail: main hero + up to 5 rounded blocks,
//  selected-state highlight, smooth tap-to-switch cross-dissolve,
//  subtle haptics, RTL/safe-area support, full accessibility.
//  Reuses existing PetImageItem data; no backend/cart/product logic changes.
//

#import <UIKit/UIKit.h>
#import "PetImageItem.h"

NS_ASSUME_NONNULL_BEGIN

@protocol PPPremiumImageSelectorRailDelegate <NSObject>

@optional

/// Called when user selects a new image index via tap.
- (void)premiumImageSelectorRail:(id)sender didSelectIndex:(NSInteger)index;

/// Called when user taps the currently selected block (optional: open fullscreen).
- (void)premiumImageSelectorRailDidTapSelectedBlock:(id)sender;

@end

@interface PPPremiumImageSelectorRail : UIView

/// Maximum number of thumbnail blocks to display (default 5).
@property (nonatomic, assign) NSInteger maxVisibleBlocks;

/// Currently selected index (0-based). Set programmatically to sync with hero.
@property (nonatomic, assign) NSInteger selectedIndex;

/// Weak delegate for selection callbacks.
@property (nonatomic, weak) id<PPPremiumImageSelectorRailDelegate> delegate;

/// Initialize with image items.
/// - Parameter imageItems: Array of PetImageItem objects (reuses existing data).
- (instancetype)initWithImageItems:(NSArray<PetImageItem *> *)imageItems;

/// Reload with new image items (preserves selection if possible).
- (void)reloadWithImageItems:(NSArray<PetImageItem *> *)imageItems;

/// Scroll to index with animation (called by hero gallery on page change).
- (void)setSelectedIndex:(NSInteger)index animated:(BOOL)animated;

/// Prepare entrance state (call before view appears / in viewWillAppear).
- (void)prepareEntranceState;

/// Run entrance animation (call in viewDidAppear).
- (void)runEntranceAnimationIfNeeded;

/// Accessibility: override label for the rail.
@property (nonatomic, copy, nullable) NSString *accessibilityLabel;

/// Accessibility: override hint for the rail.
@property (nonatomic, copy, nullable) NSString *accessibilityHint;

@end

NS_ASSUME_NONNULL_END