//
//  PPPinterestLayout.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/10/2025.
//




#import <UIKit/UIKit.h>

@class PPPinterestLayout;
static const CGFloat kPPPinterestMinCellHeight = 130.0;

NS_ASSUME_NONNULL_BEGIN
/**
 * Delegate protocol for PPPinterestLayout to provide item height based on width (typically using the item's aspect ratio).
 */
 

@protocol PPPinterestLayoutDelegate <NSObject>

@required
- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(PPPinterestLayout *)layout
heightForItemAtIndexPath:(NSIndexPath *)indexPath
                withWidth:(CGFloat)width;

@optional
// Diffable-safe stable identifier (REQUIRED for diffable data source safety)
- (NSString *)collectionView:(UICollectionView *)collectionView
                      layout:(PPPinterestLayout *)layout
 stableIDForItemAtIndexPath:(NSIndexPath *)indexPath;

@end




/**
 * PPPinterestLayout is a custom UICollectionViewLayout that arranges cells in a Pinterest-like waterfall layout.
 * It supports multiple columns and variable item heights. The number of columns, spacing, and section insets are configurable.
 * The layout asks its delegate for the height of each item given the item's width (to preserve aspect ratio).
 */
@interface PPPinterestLayout : UICollectionViewLayout

/// Delegate to provide item height (usually implemented by PPCollectionLayoutManager or the view controller).
@property (nonatomic, weak, nullable) id<PPPinterestLayoutDelegate> delegate;

/// Number of columns in the layout. Set to 0 to enable automatic column count based on collection width (default).
@property (nonatomic) NSUInteger columnCount;
@property (nonatomic) CGFloat spacing;
/// Spacing between columns (horizontal spacing). Default is 8.0 points.
@property (nonatomic) CGFloat minimumInteritemSpacing;

/// Spacing between rows (vertical spacing between items). Default is 8.0 points.
@property (nonatomic) CGFloat minimumLineSpacing;

/// Insets for each section (top, left, bottom, right padding). Default is UIEdgeInsetsMake(10, 10, 10, 10).
@property (nonatomic) UIEdgeInsets sectionInset;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary *> *heightCache;
@end




@interface PPHeightCacheManager : NSObject

+ (instancetype)sharedManager;

/// Load height cache for a specific key
- (void)loadCacheForKey:(NSString *)cacheKey;

/// Save height cache for a specific key
- (void)saveCacheForKey:(NSString *)cacheKey;

/// Clear cache for a specific key
- (void)clearCacheForKey:(NSString *)cacheKey;

/// Get cached height for indexPath + key
- (nullable NSNumber *)heightForIndexPath:(NSIndexPath *)indexPath key:(NSString *)cacheKey;

/// Set height for indexPath + key
- (void)setHeight:(CGFloat)height forIndexPath:(NSIndexPath *)indexPath key:(NSString *)cacheKey;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary *> *heightCache;
@end

NS_ASSUME_NONNULL_END
