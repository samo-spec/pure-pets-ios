#import <UIKit/UIKit.h>
#import "PPPinterestLayout.h"

NS_ASSUME_NONNULL_BEGIN

@protocol PPPinterestManagerLayoutDelegate <NSObject>
@required
- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(PPPinterestLayout *)collectionViewLayout
 heightForItemAtIndexPath:(NSIndexPath *)indexPath
               withWidth:(CGFloat)width;
@end

typedef NS_ENUM(NSInteger, PPManagerCellLayoutMode) {
    PPCellLayoutModeNil = 0,
    PPCellLayoutModeFullWidth = 1,
    PPCellLayoutModeHorizontalRow = 2,
    PPCellLayoutModeVertical = 3,
    PPCellLayoutModePinterest = 4,
    PPCellLayoutModeMarket = 5,
    PPCellLayoutModeCarousel = 6,
    PPCellLayoutModeMainKinds = 7,
    PPCellLayoutModeAllKinds = 8,
    PPCellLayoutModeDataViewFullDetails = 9001,
};

@interface PPCollectionLayoutManager : NSObject <PPPinterestLayoutDelegate>
@property (nonatomic, weak, nullable) id<PPPinterestManagerLayoutDelegate> delegate;
@property (nonatomic, assign) PPManagerCellLayoutMode currentLayoutMode;
@property (nonatomic, strong, nullable) NSArray *items;
- (UICollectionViewLayout *)layoutForMode:(PPManagerCellLayoutMode)mode;
- (UICollectionViewLayout *)listLayout;
- (UICollectionViewLayout *)horizontalRowLayout;
- (UICollectionViewLayout *)verticalLayout;
- (UICollectionViewLayout *)pinterestLayout;
- (UICollectionViewLayout *)fullDetailsLayout;
- (void)applyLayoutMode:(PPManagerCellLayoutMode)mode
       toCollectionView:(UICollectionView *)collectionView
               animated:(BOOL)animated;
- (void)invalidateLayoutIn:(UICollectionView *)collectionView
                indexPaths:(nullable NSArray<NSIndexPath *> *)indexPaths;
@end

NS_ASSUME_NONNULL_END
