#import <UIKit/UIKit.h>
#import "PPPinterestLayout.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPManagerCellLayoutMode) {
    PPCellLayoutModeNil,
    PPCellLayoutModeFullWidth,
    PPCellLayoutModeSquare,
    PPCellLayoutModeVertical,
    PPCellLayoutModePinterest,
    PPCellLayoutModeMarket,
    PPCellLayoutModeCarousel,
    PPCellLayoutModeMainKinds,
    PPCellLayoutModeAllKinds,
};

@protocol PPPinterestManagerLayoutDelegate <NSObject>
@required
- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(PPPinterestLayout *)collectionViewLayout
heightForItemAtIndexPath:(NSIndexPath *)indexPath
               withWidth:(CGFloat)width;
@end


/**
 * PPCollectionLayoutManager is responsible for providing appropriate collection view layouts
 * for different cell layout modes and managing layout switches. It uses UICollectionViewCompositionalLayout
 * for iOS 13+ (FullWidth, Square, Vertical modes) and a custom PPPinterestLayout for Pinterest mode
 * or legacy iOS fallback.
 *
 * It also implements PPPinterestLayoutDelegate to supply item heights based on model aspect ratios.
 */
@interface PPCollectionLayoutManager : NSObject <PPPinterestLayoutDelegate>
@property (nonatomic, weak, nullable) id<PPPinterestManagerLayoutDelegate> delegate;

/// The current layout mode.
@property (nonatomic, assign) PPManagerCellLayoutMode currentLayoutMode;

/// Data source items (e.g., an array of PetAd models) used for computing layout metrics (like aspect ratios in Pinterest mode).
@property (nonatomic, strong, nullable) NSArray *items;

/**
 * Returns a UICollectionViewLayout configured for the given layout mode.
 * On iOS 13+, uses compositional layouts for FullWidth, Square, Vertical modes and custom Pinterest layout for Pinterest mode.
 * On iOS 12 and below, uses flow layouts for FullWidth, Square, Vertical, and the custom Pinterest layout for Pinterest.
 */
- (UICollectionViewLayout *)layoutForMode:(PPManagerCellLayoutMode)mode;

/** Convenience methods for each layout mode (for completeness). */
- (UICollectionViewLayout *)listLayout;     /// FullWidth mode layout (single column list).
- (UICollectionViewLayout *)squareLayout;   /// Square grid mode layout.
- (UICollectionViewLayout *)verticalLayout; /// Vertical grid mode layout.
- (UICollectionViewLayout *)pinterestLayout;/// Pinterest mode layout (staggered/masonry).

/**
 * Applies the specified layout mode to the given collection view, optionally animated.
 * This will create and set a new UICollectionViewLayout appropriate for the mode, and log the change.
 * If switching to Pinterest mode, it ensures the custom layout is properly refreshed.
 */
- (void)applyLayoutMode:(PPManagerCellLayoutMode)mode toCollectionView:(UICollectionView *)collectionView animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
