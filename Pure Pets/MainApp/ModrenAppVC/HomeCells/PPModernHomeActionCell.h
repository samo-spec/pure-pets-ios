#import <UIKit/UIKit.h>
#import "PPHomeModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPModernHomeActionCell : UICollectionViewCell

+ (NSString *)reuseIdentifier;

@property (nonatomic, copy, nullable) void (^onTap)(void);

- (void)configureWithTitle:(NSString *)title
                systemIcon:(NSString *)systemIconName;
- (void)configureWithQuickAction:(PPHomeQuickActionModel *)quickAction;
@property (nonatomic, copy, nullable) NSString *boundCellID;

@end

NS_ASSUME_NONNULL_END
