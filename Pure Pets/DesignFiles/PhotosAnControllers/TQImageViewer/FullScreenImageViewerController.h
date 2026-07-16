#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FullScreenImageViewerController : UIViewController

@property (nonatomic, copy, nullable) void (^dismissalCompletion)(void);
@property (nonatomic, copy, nullable) void (^shareHandler)(FullScreenImageViewerController *viewer);
@property (nonatomic, copy, nullable) void (^editHandler)(FullScreenImageViewerController *viewer,
                                                          UIImage *image);

- (instancetype)initWithImage:(nullable UIImage *)image NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)presentFullScreenFromImageView:(UIImageView *)sourceImageView;
- (void)dismissFullScreen;

@end

@interface PPPremiumVideoPlayerViewController : UIViewController

@property (nonatomic, copy, nullable) void (^editHandler)(PPPremiumVideoPlayerViewController *viewer,
                                                          NSURL *videoURL);

- (instancetype)initWithURL:(NSURL *)videoURL NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
