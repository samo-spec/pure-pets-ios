#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPSavedForLaterBottomSheetVC : UIViewController

@property (nonatomic, copy, nullable) void (^onDismiss)(void);
@property (nonatomic, copy, nullable) void (^onItemsMovedToCart)(void);

@end

NS_ASSUME_NONNULL_END
