////  ViewerController.h
#import <UIKit/UIKit.h>
@class PetAd;
NS_ASSUME_NONNULL_BEGIN

#pragma mark - Enums

typedef NS_ENUM(NSUInteger, ViewerLoadingStyle) {
    ViewerLoadingStyleSpin,
    ViewerLoadingStyleIndicator,
    ViewerLoadingStyleProgress
};

typedef NS_ENUM(NSUInteger, ViewerPageLabelStyle) {
    ViewerPageLabelStyleDot,
    ViewerPageLabelStyleNumber,
    ViewerPageLabelStylePersonalityNumber,
    ViewerPageLabelStyleNone
};

typedef NS_ENUM(NSUInteger, ViewerPresentationStyle) {
    ViewerPresentationStyleModal,           // Present modally (default)
    ViewerPresentationStylePush,            // Push onto navigation stack
    ViewerPresentationStyleOverFullScreen,  // Present over full screen
    ViewerPresentationStyleChild,           // Add as child view controller
    ViewerPresentationStyleCustom           // Custom presentation
};

typedef NS_ENUM(NSUInteger, ViewerAnimationStyle) {
    ViewerAnimationStyleZoom,               // Zoom from source view
    ViewerAnimationStyleFade,               // Fade in/out
    ViewerAnimationStyleSlide,              // Slide from bottom
    ViewerAnimationStyleNone                // No animation
};

#pragma mark - Delegate Protocol

@class ViewerController;

@protocol ViewerControllerDelegate <NSObject>
@optional
- (void)viewerControllerDidDismiss:(ViewerController *)viewer;
- (void)viewerController:(ViewerController *)viewer
    didLongPressAtIndex:(NSInteger)index
              attribute:(id)attribute
                  image:(nullable UIImage *)image;
- (void)viewerController:(ViewerController *)viewer
       didChangeToPage:(NSInteger)page;
- (BOOL)viewerController:(ViewerController *)viewer
    shouldDismissAtPage:(NSInteger)page;
@end

#pragma mark - Attribute Model

@interface ViewerAttribute : NSObject
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, strong, nullable) NSURL *imageURL;
@property (nonatomic, weak, nullable) UIView *sourceView;
@property (nonatomic, strong, nullable) UIImage *placeholderImage;
@property (nonatomic, assign) BOOL loadFinished;
@property (nonatomic, assign) BOOL placeholderInvalidate;
@property (nonatomic, strong, nullable) NSString *title;
@property (nonatomic, strong, nullable) NSString *caption;

// Initializers
- (instancetype)initWithImage:(nullable UIImage *)image;
- (instancetype)initWithImageURL:(nullable NSURL *)imageURL
                      sourceView:(nullable UIView *)sourceView;
- (instancetype)initWithImageURL:(nullable NSURL *)imageURL
                      sourceView:(nullable UIView *)sourceView
                placeholderImage:(nullable UIImage *)placeholderImage;

// Convenience methods
+ (instancetype)attributeWithImage:(nullable UIImage *)image;
+ (instancetype)attributeWithImageURL:(nullable NSURL *)imageURL
                           sourceView:(nullable UIView *)sourceView;
+ (instancetype)attributeWithImageURL:(nullable NSURL *)imageURL
                           sourceView:(nullable UIView *)sourceView
                     placeholderImage:(nullable UIImage *)placeholderImage;
@end

#pragma mark - Main Viewer Controller

@interface ViewerController : UIViewController
@property (nonatomic, strong) PetAd *currentAd;

#pragma mark - Properties

// Delegate
@property (nonatomic, weak) id<ViewerControllerDelegate> delegate;

// Content
@property (nonatomic, copy, readonly) NSArray<ViewerAttribute *> *attributes;
@property (nonatomic, assign, readonly) NSInteger currentPage;

// Configuration
@property (nonatomic, assign) ViewerLoadingStyle loadingStyle;
@property (nonatomic, assign) ViewerPageLabelStyle pageLabelStyle;
@property (nonatomic, assign) BOOL alwaysShowPageLabel;
@property (nonatomic, assign) BOOL bouncesAnimated;
@property (nonatomic, assign) CGFloat pageSpacing;
@property (nonatomic, assign) NSTimeInterval animateDuration;

// Presentation
@property (nonatomic, assign) ViewerPresentationStyle presentationStyle;
@property (nonatomic, assign) ViewerAnimationStyle animationStyle;
@property (nonatomic, assign) BOOL disableInteractiveDismiss;
@property (nonatomic, assign) BOOL hideNavigationBar;
@property (nonatomic, assign) BOOL modalPresentationCapturesStatusBarAppearance;
@property (nonatomic, assign) BOOL enableCloseButton;
@property (nonatomic, assign) BOOL enableShareButton;

// UI Elements (optional customization)
@property (nonatomic, strong, readonly) UIButton *closeButton;
@property (nonatomic, strong, readonly) UIButton *shareButton;
@property (nonatomic, strong, readonly) UIPageControl *pageControl;
@property (nonatomic, strong, readonly) UILabel *pageTextLabel;


#pragma mark - Initialization

// Primary initializer
- (instancetype)initWithAttributes:(NSArray<ViewerAttribute *> *)attributes;

// Convenience initializers
- (instancetype)initWithImages:(NSArray<UIImage *> *)images;
- (instancetype)initWithImageURLs:(NSArray<NSURL *> *)imageURLs
                       sourceView:(nullable UIView *)sourceView;

#pragma mark - Presentation Methods

// Full control presentation
- (void)presentFromViewController:(UIViewController *)viewController
                     currentIndex:(NSInteger)index
                presentationStyle:(ViewerPresentationStyle)presentationStyle
                   animationStyle:(ViewerAnimationStyle)animationStyle
                       completion:(nullable void (^)(void))completion;

// Convenience methods
- (void)presentFromViewController:(UIViewController *)viewController
                     currentIndex:(NSInteger)index
                       completion:(nullable void (^)(void))completion;

- (void)presentFromViewController:(UIViewController *)viewController
                     currentIndex:(NSInteger)index
                presentationStyle:(ViewerPresentationStyle)presentationStyle
                       completion:(nullable void (^)(void))completion;

#pragma mark - Dismissal Methods

// Full control dismissal
- (void)dismissWithAnimationStyle:(ViewerAnimationStyle)animationStyle
                       completion:(nullable void (^)(void))completion;

// Convenience dismissal
- (void)dismissWithCompletion:(nullable void (^)(void))completion;
- (void)dismiss;

#pragma mark - Navigation

- (void)goToPage:(NSInteger)page animated:(BOOL)animated;
- (void)goToNextPageAnimated:(BOOL)animated;
- (void)goToPreviousPageAnimated:(BOOL)animated;

#pragma mark - UI Customization

- (void)setCloseButtonImage:(nullable UIImage *)image forState:(UIControlState)state;
- (void)setShareButtonImage:(nullable UIImage *)image forState:(UIControlState)state;
- (void)setCloseButtonTintColor:(nullable UIColor *)color;
- (void)setShareButtonTintColor:(nullable UIColor *)color;
- (void)setPageIndicatorTintColor:(nullable UIColor *)color;
- (void)setCurrentPageIndicatorTintColor:(nullable UIColor *)color;
- (void)setPageTextColor:(nullable UIColor *)color;
- (void)setPageTextFont:(nullable UIFont *)font;
- (void)setBackgroundColor:(nullable UIColor *)color;

#pragma mark - Utility Methods

- (nullable UIImage *)imageAtPage:(NSInteger)page;
- (void)reloadData;
- (void)preloadImages;

@end




/*
 
 // 1. INSTANTIATION
 ViewerController *viewer = [[ViewerController alloc] initWithAttributes:attributes];
 ViewerController *viewer = [[ViewerController alloc] initWithImages:@[image1, image2]];
 ViewerController *viewer = [[ViewerController alloc] initWithImageURLs:urls sourceView:nil];

 // 2. CONFIGURATION (Before Presentation)
 viewer.loadingStyle = ViewerLoadingStyleSpin;
 viewer.pageLabelStyle = ViewerPageLabelStyleDot;
 viewer.bouncesAnimated = YES;
 viewer.alwaysShowPageLabel = NO;

 // 3. PRESENTATION STYLES
 [viewer presentFromViewController:self currentIndex:0 completion:nil]; // Default: Modal + Zoom
 [viewer presentFromViewController:self currentIndex:0 presentationStyle:ViewerPresentationStylePush completion:nil];
 [viewer presentFromViewController:self currentIndex:0 presentationStyle:ViewerPresentationStyleModal animationStyle:ViewerAnimationStyleFade completion:nil];

 // 4. DISMISSAL
 [viewer dismiss]; // Default
 [viewer dismissWithCompletion:^{}];
 [viewer dismissWithAnimationStyle:ViewerAnimationStyleFade completion:^{}];

 // 5. NAVIGATION
 [viewer goToPage:2 animated:YES];
 [viewer goToNextPageAnimated:YES];
 [viewer goToPreviousPageAnimated:YES];

 // 6. UI CUSTOMIZATION
 [viewer setCloseButtonImage:image forState:UIControlStateNormal];
 [viewer setBackgroundColor:[UIColor blackColor]];
 [viewer setPageIndicatorTintColor:[UIColor grayColor]];
 
 
 */





@class ImageViewerManager;

@protocol ImageViewerManagerDelegate <NSObject>
@optional
- (void)imageViewerManagerDidDismiss:(ImageViewerManager *)manager;
- (void)imageViewerManager:(ImageViewerManager *)manager didLongPressAtIndex:(NSInteger)index image:(nullable UIImage *)image sourceView:(nullable UIView *)sourceView;
- (void)imageViewerManager:(ImageViewerManager *)manager willPresentAtIndex:(NSInteger)index;
- (void)imageViewerManager:(ImageViewerManager *)manager didPresentAtIndex:(NSInteger)index;
- (void)imageViewerManager:(ImageViewerManager *)manager didChangePageToIndex:(NSInteger)index;
@end

@interface ImageViewerManager : NSObject

@property (nonatomic, weak) id<ImageViewerManagerDelegate> delegate;
@property (nonatomic, strong, readonly) ViewerController *currentViewer;
@property (nonatomic, assign) BOOL shouldSaveToPhotosOnLongPress;
@property (nonatomic, assign) BOOL shouldShowShareOption;
@property (nonatomic, assign) BOOL enableDoubleTapToZoom;
@property (nonatomic, assign) BOOL enableSingleTapToDismiss;

// Configuration
+ (ImageViewerManager *)sharedManager;
+ (void)configureDefaultSettings;

// Presentation methods
- (void)presentWithImages:(NSArray<UIImage *> *)images
           fromController:(UIViewController *)presentingController
             currentIndex:(NSInteger)index
               sourceView:(nullable UIView *)sourceView;

- (void)presentWithImageURLs:(NSArray<NSString *> *)imageURLs
              fromController:(UIViewController *)presentingController
                currentIndex:(NSInteger)index
                  sourceView:(nullable UIView *)sourceView
            placeholderImage:(nullable UIImage *)placeholder;

- (void)presentWithMixedContent:(NSArray<id> *)content
                 fromController:(UIViewController *)presentingController
                   currentIndex:(NSInteger)index
                     sourceView:(nullable UIView *)sourceView;

- (void)presentViewerWithAttributes:(NSArray<ViewerAttribute *> *)attributes
                     fromController:(UIViewController *)presentingController
                       currentIndex:(NSInteger)index;

// Dismiss methods
- (void)dismissCurrentViewerAnimated:(BOOL)animated completion:(nullable void (^)(void))completion;
- (void)dismissAllViewersAnimated:(BOOL)animated completion:(nullable void (^)(void))completion;

// Utility methods
- (BOOL)isViewerPresented;
- (NSInteger)currentPageIndex;
- (nullable UIImage *)currentImage;
- (void)preloadImagesForURLs:(NSArray<NSURL *> *)urls;

// Configuration setters
- (void)setLoadingStyle:(ViewerLoadingStyle)loadingStyle;
- (void)setPageLabelStyle:(ViewerPageLabelStyle)pageLabelStyle;
- (void)setBouncesAnimated:(BOOL)bouncesAnimated;
- (void)setPageSpacing:(CGFloat)pageSpacing;
- (void)setAlwaysShowPageLabel:(BOOL)alwaysShowPageLabel;

// Customization
- (void)setCloseButtonImage:(nullable UIImage *)image;
- (void)setShareButtonImage:(nullable UIImage *)image;
- (void)setCloseButtonHidden:(BOOL)hidden;
- (void)setShareButtonHidden:(BOOL)hidden;

@end

NS_ASSUME_NONNULL_END
