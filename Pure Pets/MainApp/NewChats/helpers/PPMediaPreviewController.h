//
//  PPMediaPreviewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 24/01/2026.
//


typedef NS_ENUM(NSInteger, PPMediaPreviewType) {
    PPMediaPreviewTypeImage,
    PPMediaPreviewTypeVideo
};

@interface PPMediaPreviewController : UIViewController

@property (nonatomic, copy) void (^onSendImage)(UIImage *image);
@property (nonatomic, copy) void (^onSendVideo)(NSURL *videoURL);

- (instancetype)initWithImage:(UIImage *)image;
- (instancetype)initWithVideoURL:(NSURL *)videoURL;

@end