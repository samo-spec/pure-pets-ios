#import <UIKit/UIKit.h>

@class MainKindsModel;

NS_ASSUME_NONNULL_BEGIN

@interface PPModerHomeCell : UICollectionViewCell

+ (NSString *)reuseIdentifier;

@property (nonatomic, copy, nullable) void (^onSelect)(MainKindsModel *_Nullable model, BOOL isAll);

- (void)configureWithMainKind:(nullable MainKindsModel *)kind
                        isAll:(BOOL)isAll
                     selected:(BOOL)selected;
- (void)playRestoredSelectionAnimation;
@property (nonatomic, copy, nullable) NSString *boundCellID;

@end

NS_ASSUME_NONNULL_END
