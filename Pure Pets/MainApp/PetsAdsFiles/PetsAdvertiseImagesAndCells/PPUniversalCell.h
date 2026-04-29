
#import <UIKit/UIKit.h>
#import "PPCollectionLayoutManager.h"
NS_ASSUME_NONNULL_BEGIN

typedef void (^PPImageLoader)(UIImageView *_Nullable imageView,
                              NSString *_Nullable url,
                              UIImage *_Nullable placeholder,
                              UIView *_Nullable card);

@class PPUniversalCellViewModel;
 
@protocol PPUniversalCellDelegate <NSObject>

@optional
// Legacy (kept)
- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel;
- (void)PPUniversalCell_tapShare:(PPUniversalCellViewModel *)universalModel;
- (void)PPUniversalCell_tapFavorite:(PPUniversalCellViewModel *)universalModel;
- (void)PPUniversalCell_tapEdit:(PPUniversalCellViewModel *)universalModel;
- (void)PPUniversalCell_tapDelete:(PPUniversalCellViewModel *)universalModel;
- (void)PPUniversalCell_changeQuantity:(PPUniversalCellViewModel *)universalModel quantity:(NSInteger)quantity;


@end

@interface PPUniversalGradientView : UIView
- (void)applyContextPaletteForContext:(PPCellContext)context;
@end

@interface PPUniversalCell : UICollectionViewCell
@property (nonatomic, weak) id<PPUniversalCellDelegate> delegate;
+ (NSString *)reuseIdentifier;
@property (nonatomic, strong) NSIndexPath *indexPath;
/// Core config
@property (nonatomic, assign) PPCellContext      context;
@property (nonatomic, assign) PPManagerCellLayoutMode   layoutMode;
@property (nonatomic, assign) PPDiscountStyle    discountStyle; // default: Badge
@property (nonatomic, copy, nullable) void (^onTap)(void);

/// Quantity (only used in Marker context)
@property (nonatomic, assign, readonly) NSInteger quantity;
- (void)setQuantity:(NSInteger)quantity animated:(BOOL)animated;
- (void)collapseStepper:(BOOL)animated;
/// Re-resolves dynamic layer colors after foreground/theme restoration.
- (void)refreshThemeAppearance;
/// Configure cell from a view model

- (void)applyViewModel:(PPUniversalCellViewModel *)vm
               context:(PPCellContext)context
            layoutMode:(PPManagerCellLayoutMode)layout
          discountMode:(PPDiscountStyle)discountStyle
           imageLoader:(PPImageLoader)loader;

/// Hides the top reason/location badge when set to YES.
@property (nonatomic, assign) BOOL hideTopBadge;

/// Shows the subtitle label when set to YES (default NO — subtitle hidden).
@property (nonatomic, assign) BOOL showsSubtitle;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) PPUniversalGradientView *imageContainer;
@end

NS_ASSUME_NONNULL_END
