#import <UIKit/UIKit.h>
#import "PPCollectionLayoutManager.h"
NS_ASSUME_NONNULL_BEGIN

extern BOOL PPUniversalCellShowsCTA;

typedef void (^PPImageLoader)(UIImageView *_Nullable imageView,
                              NSString *_Nullable url,
                              UIImage *_Nullable placeholder,
                              UIView *_Nullable card);

@class PPUniversalCellViewModel;
 
@protocol PPUniversalCellDelegate <NSObject>

@optional
- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel;
- (void)PPUniversalCell_tapShare:(PPUniversalCellViewModel *)universalModel;
- (void)PPUniversalCell_tapVideo:(PPUniversalCellViewModel *)universalModel;
- (void)PPUniversalCell_tapFavorite:(PPUniversalCellViewModel *)universalModel;
- (void)PPUniversalCell_tapEdit:(PPUniversalCellViewModel *)universalModel;
- (void)PPUniversalCell_tapVisibilityToggle:(PPUniversalCellViewModel *)universalModel;
- (void)PPUniversalCell_tapDelete:(PPUniversalCellViewModel *)universalModel;
- (void)PPUniversalCell_changeQuantity:(PPUniversalCellViewModel *)universalModel quantity:(NSInteger)quantity;
- (void)PPUniversalCell_tapChat:(PPUniversalCellViewModel *)universalModel;
- (void)PPUniversalCell_tapReport:(PPUniversalCellViewModel *)universalModel;
- (void)PPUniversalCell_tapSaveForLater:(PPUniversalCellViewModel *)universalModel;

@end

@interface PPUniversalGradientView : UIView
- (void)applyContextPaletteForContext:(PPCellContext)context;
@end

@interface PPUniversalCell : UICollectionViewCell
@property (nonatomic, weak) id<PPUniversalCellDelegate> delegate;
+ (NSString *)reuseIdentifier;
@property (nonatomic, strong) NSIndexPath *indexPath;
@property (nonatomic, assign) PPCellContext      context;
@property (nonatomic, assign) PPManagerCellLayoutMode   layoutMode;
@property (nonatomic, assign) PPDiscountStyle    discountStyle;
@property (nonatomic, copy, nullable) void (^onTap)(void);

@property (nonatomic, assign, readonly) NSInteger quantity;
- (void)setQuantity:(NSInteger)quantity animated:(BOOL)animated;
- (void)collapseStepper:(BOOL)animated;
- (void)refreshThemeAppearance;
- (void)stopMediaPlayback;

- (void)applyViewModel:(PPUniversalCellViewModel *)vm
               context:(PPCellContext)context
            layoutMode:(PPManagerCellLayoutMode)layout
          discountMode:(PPDiscountStyle)discountStyle
           imageLoader:(PPImageLoader)loader;

@property (nonatomic, assign) BOOL hideTopBadge;
@property (nonatomic, assign) BOOL forceShowsOwnerMenuButton;
@property (nonatomic, assign) BOOL showsSubtitle;
@property (nonatomic, assign) BOOL dataViewPresentation;
@property (nonatomic, assign) BOOL userBordersV2;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) PPUniversalGradientView *imageContainer;

/// Registers the SwiftUI PPUniversalCardHostingCell under reuseIdentifier @"PPUniversalCell".
+ (void)pp_registerInCollectionView:(UICollectionView *)collectionView;

/// Dequeues a PPUniversalCardHostingCell. Returns the cell as `id`; callers
/// should rely on dynamic dispatch for the PPUniversalCell-compatible API.
+ (id)pp_dequeueFromCollectionView:(UICollectionView *)collectionView
                         indexPath:(NSIndexPath *)indexPath;

/// Returns YES when the cell is a PPUniversalCardHostingCell.
+ (BOOL)pp_isUniversalCell:(UICollectionViewCell *)cell;
@end

NS_ASSUME_NONNULL_END
