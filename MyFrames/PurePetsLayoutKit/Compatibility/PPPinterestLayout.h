#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class PPPinterestLayout;
static const CGFloat kPPPinterestMinCellHeight = 130.0;

@protocol PPPinterestLayoutDelegate <NSObject>
- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(PPPinterestLayout *)layout
 heightForItemAtIndexPath:(NSIndexPath *)indexPath
                withWidth:(CGFloat)width;
@optional
- (NSString *)collectionView:(UICollectionView *)collectionView
                      layout:(PPPinterestLayout *)layout
 stableIDForItemAtIndexPath:(NSIndexPath *)indexPath;
@end

@interface PPPinterestLayout : UICollectionViewLayout
@property (nonatomic, weak, nullable) id<PPPinterestLayoutDelegate> delegate;
@property (nonatomic) NSUInteger columnCount;
@property (nonatomic) CGFloat spacing;
@property (nonatomic) CGFloat minimumInteritemSpacing;
@property (nonatomic) CGFloat minimumLineSpacing;
@property (nonatomic) UIEdgeInsets sectionInset;
@property (nonatomic, strong) NSMutableDictionary *heightCache;
@end

@interface PPHeightCacheManager : NSObject
+ (instancetype)sharedManager;
- (void)loadCacheForKey:(NSString *)cacheKey;
- (void)saveCacheForKey:(NSString *)cacheKey;
- (void)clearCacheForKey:(NSString *)cacheKey;
- (nullable NSNumber *)heightForIndexPath:(NSIndexPath *)indexPath key:(NSString *)cacheKey;
- (void)setHeight:(CGFloat)height forIndexPath:(NSIndexPath *)indexPath key:(NSString *)cacheKey;
@property (nonatomic, strong) NSMutableDictionary *heightCache;
@end

NS_ASSUME_NONNULL_END
