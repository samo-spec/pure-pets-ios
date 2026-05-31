#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPIntroPanel : NSObject
@property (nonatomic, copy) NSString *imageName;
@property (nonatomic, copy) NSString *headline;
@property (nonatomic, copy) NSString *body;
- (instancetype)initWithImage:(NSString *)imageName
                    lottieName:(NSString *)lottieName
                      headline:(NSString *)headline
                          body:(NSString *)body;
@end

@interface PPIntroViewController : UIViewController
+ (BOOL)shouldShowIntro;
+ (void)markIntroAsShown;
- (void)showOverWindow:(UIWindow *)window completion:(nullable dispatch_block_t)completion;
@end

NS_ASSUME_NONNULL_END
