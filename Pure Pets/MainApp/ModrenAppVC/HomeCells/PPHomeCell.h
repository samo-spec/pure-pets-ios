#import <UIKit/UIKit.h>

@class MainKindsModel;

NS_ASSUME_NONNULL_BEGIN

@interface PPHomeCell : UICollectionViewCell

@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *glassButton;

@property (nonatomic, assign) BOOL isAll;
@property (nonatomic, assign) BOOL isKindSelected;
@property (nonatomic, strong, nullable) MainKindsModel *model;

@property (nonatomic, copy) void (^onSelect)(MainKindsModel *_Nullable model, BOOL isAll);

- (void)configureWithMainKind:(nullable MainKindsModel *)kind
                        isAll:(BOOL)isAll
                     selected:(BOOL)selected;

@end

NS_ASSUME_NONNULL_END
