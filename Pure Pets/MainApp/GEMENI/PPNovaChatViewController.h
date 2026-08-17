//
//  PPNovaChatViewController.h
//  Pure Pets
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPNovaChatViewController : UIViewController

+ (void)presentNovaFromViewController:(UIViewController *)presentingVC;
+ (void)presentNovaFromViewController:(UIViewController *)presentingVC
                         initialDraft:(nullable NSString *)initialDraft;

@end

NS_ASSUME_NONNULL_END
