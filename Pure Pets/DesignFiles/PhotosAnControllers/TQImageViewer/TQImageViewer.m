//  ViewerController.m
#import "TQImageViewer.h"
#import "SDWebImage/SDWebImage.h"

#ifndef dispatch_main_async_safe
#define dispatch_main_async_safe(block) \
if ([NSThread isMainThread]) { \
    block(); \
} else { \
    dispatch_async(dispatch_get_main_queue(), block); \
}
#endif
#import "PPAdSharingHelper.h"
@interface ViewerAttribute ()
@end

//  ViewerAttribute.m

@implementation ViewerAttribute

#pragma mark - Initializers

- (instancetype)initWithImage:(UIImage *)image {
    self = [super init];
    if (self) {
        _image = image;
        _loadFinished = YES;
    }
    return self;
}

- (instancetype)initWithImageURL:(NSURL *)imageURL
                      sourceView:(UIView *)sourceView {
    return [self initWithImageURL:imageURL
                       sourceView:sourceView
                 placeholderImage:nil];
}

- (instancetype)initWithImageURL:(NSURL *)imageURL
                      sourceView:(UIView *)sourceView
                placeholderImage:(UIImage *)placeholderImage {
    self = [super init];
    if (self) {
        _imageURL = imageURL;
        _sourceView = sourceView;
        _placeholderImage = placeholderImage;
        _placeholderInvalidate = sourceView ? NO : YES;
        _loadFinished = NO;
    }
    return self;
}

#pragma mark - Convenience Methods

+ (instancetype)attributeWithImage:(UIImage *)image {
    return [[self alloc] initWithImage:image];
}

+ (instancetype)attributeWithImageURL:(NSURL *)imageURL
                           sourceView:(UIView *)sourceView {
    return [[self alloc] initWithImageURL:imageURL
                               sourceView:sourceView];
}

+ (instancetype)attributeWithImageURL:(NSURL *)imageURL
                           sourceView:(UIView *)sourceView
                     placeholderImage:(UIImage *)placeholderImage {
    return [[self alloc] initWithImageURL:imageURL
                               sourceView:sourceView
                         placeholderImage:placeholderImage];
}

#pragma mark - Getters

- (UIImage *)placeholderImage {
    if (!_placeholderImage) {
        if ([_sourceView respondsToSelector:@selector(image)]) {
            return ((UIImageView *)_sourceView).image;
        }
    }
    return _placeholderImage;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<ViewerAttribute: %p> imageURL: %@, hasImage: %@, sourceView: %@",
            self,
            _imageURL,
            _image ? @"YES" : @"NO",
            _sourceView];
}

@end
#pragma mark - LoadingLayer

@interface ViewerLoadingLayer : CAShapeLayer
@property (nonatomic, assign) BOOL isLoading;
@end

@implementation ViewerLoadingLayer

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super init]) {
        self.frame = frame;
        self.cornerRadius = 20;
        self.fillColor = [UIColor clearColor].CGColor;
        self.strokeColor = [UIColor whiteColor].CGColor;
        self.lineCap = kCALineCapRound;
        self.lineWidth = 4;
        self.strokeStart = 0;
        self.strokeEnd = 0.35;
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5].CGColor;
        self.hidden = YES;
        self.isLoading = NO;
        
        CGFloat inset = 2.f;
        self.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(self.bounds, inset, inset) cornerRadius:self.cornerRadius - inset].CGPath;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    if (self.isLoading) [self startSpinning];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)startSpinning {
    self.hidden = NO;
    self.isLoading = YES;
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    anim.duration = 0.4;
    anim.toValue = @(M_PI - 0.5);
    anim.cumulative = YES;
    anim.repeatCount = MAXFLOAT;
    [self addAnimation:anim forKey:@"ViewerLoadingLayerSpinKey"];
}

- (void)stopSpinning {
    self.hidden = YES;
    self.isLoading = NO;
    [self removeAnimationForKey:@"ViewerLoadingLayerSpinKey"];
}

@end

#pragma mark - ViewerCell

@interface ViewerCell : UIScrollView <UIScrollViewDelegate>
@property (nonatomic, strong, readonly) UIImageView *imageView;
@property (nonatomic, strong, readonly) ViewerLoadingLayer *loadingLayer;
@property (nonatomic, strong, readonly) UIActivityIndicatorView *indicator;
@property (nonatomic, assign) ViewerLoadingStyle loadingStyle;
@property (nonatomic, strong, nullable) ViewerAttribute *attribute;
@property (nonatomic, assign) NSInteger pageIndex;

- (void)cancelCurrentLoad;
@end

@implementation ViewerCell

- (instancetype)init {
    if (self = [super init]) {
        self.bouncesZoom = YES;
        self.maximumZoomScale = 3;
        self.multipleTouchEnabled = YES;
        self.delegate = self;
        self.alwaysBounceVertical = NO;
        self.showsVerticalScrollIndicator = NO;
        self.showsHorizontalScrollIndicator = NO;
        self.frame = [UIScreen mainScreen].bounds;
        
        if (@available(iOS 11.0, *)) {
            self.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
        
        _imageView = [[UIImageView alloc] init];
        _imageView.clipsToBounds = YES;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.backgroundColor = [UIColor blackColor];
        [self addSubview:_imageView];
        
        _loadingLayer = [[ViewerLoadingLayer alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        [self.layer addSublayer:_loadingLayer];
        
        _indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        _indicator.color = [UIColor whiteColor];
        [self addSubview:_indicator];
        [self updateLayout];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect frame = _loadingLayer.frame;
    CGPoint point = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    frame.origin.x = point.x - frame.size.width / 2;
    frame.origin.y = point.y - frame.size.height / 2;
    _loadingLayer.frame = frame;
    _indicator.center = point;
}

- (void)updateLayout {
    _imageView.frame = CGRectMake(0, 0, self.bounds.size.width, 0);
    CGRect imageRect = _imageView.frame;
    UIImage *image = _imageView.image;
    
    if (!image || image.size.width < 0.1 || self.bounds.size.width < 0.1) {
        imageRect.size.height = self.bounds.size.height;
        _imageView.frame = imageRect;
    } else {
        CGFloat imgRatio = image.size.height / image.size.width;
        CGFloat viewRatio = self.bounds.size.height / self.bounds.size.width;

        if (imgRatio > viewRatio) {
            imageRect.size.height = floor(image.size.height / (image.size.width / self.bounds.size.width));
            _imageView.frame = imageRect;
        } else {
            CGFloat height = floor(imgRatio * self.bounds.size.width);
            if (height < 1 || !isfinite(height)) height = self.bounds.size.height;
            imageRect.size.height = height;
            _imageView.frame = imageRect;
            _imageView.center = CGPointMake(_imageView.center.x, self.bounds.size.height / 2);
        }
    }
    
    if (_imageView.frame.size.height > self.bounds.size.height && _imageView.frame.size.height - self.bounds.size.height <= 1) {
        imageRect.size.height = self.bounds.size.height;
        _imageView.frame = imageRect;
    }
    
    self.contentSize = CGSizeMake(self.bounds.size.width, MAX(_imageView.frame.size.height, self.bounds.size.height));
    [self scrollRectToVisible:self.bounds animated:NO];
    self.alwaysBounceVertical = _imageView.frame.size.height > self.bounds.size.height;
}

- (void)cancelCurrentLoad {
    [_imageView sd_cancelCurrentImageLoad];
    [_loadingLayer stopSpinning];
    [_indicator stopAnimating];
}

- (void)setLoadingStyle:(ViewerLoadingStyle)loadingStyle {
    _loadingStyle = loadingStyle;
}

- (void)setAttribute:(ViewerAttribute *)attribute {
    if (_attribute == attribute) return;
    _attribute = attribute;
    
    _attribute.loadFinished = NO;
    [self cancelCurrentLoad];
    
    [self setZoomScale:1.0 animated:NO];
    self.maximumZoomScale = 1;
    
    if (!_attribute) {
        _imageView.image = nil;
        return;
    }
    
    if (attribute.image) {
        _attribute.loadFinished = YES;
        _imageView.image = attribute.image;
        [self updateLayout];
    } else if (attribute.imageURL) {
        __weak typeof(self) weakSelf = self;
        SDWebImageDownloaderProgressBlock progressCallback = nil;
        
        if (_loadingStyle == ViewerLoadingStyleProgress) {
            progressCallback = ^(NSInteger receivedSize, NSInteger expectedSize, NSURL *targetURL) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                dispatch_main_async_safe(^{
                    CGFloat progress = receivedSize / (float)expectedSize;
                    progress = progress < 0.01 ? 0.01 : progress > 1 ? 1 : progress;
                    if (isnan(progress)) progress = 0;
                    strongSelf.loadingLayer.hidden = NO;
                    strongSelf.loadingLayer.strokeEnd = progress;
                });
            };
        } else if (_loadingStyle == ViewerLoadingStyleSpin) {
            [_loadingLayer startSpinning];
        } else {
            [_indicator startAnimating];
            if (_attribute.placeholderInvalidate) {
                attribute.placeholderImage = nil;
            }
        }
        
        [_imageView sd_setImageWithURL:attribute.imageURL
                      placeholderImage:attribute.placeholderImage
                               options:kNilOptions
                              progress:progressCallback
                             completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            if (self->_loadingStyle == ViewerLoadingStyleSpin) {
                [strongSelf.loadingLayer stopSpinning];
            } else if (strongSelf.loadingStyle == ViewerLoadingStyleProgress) {
                strongSelf.loadingLayer.hidden = YES;
            } else {
                [strongSelf.indicator stopAnimating];
                if (strongSelf.attribute.placeholderInvalidate) {
                    self->_imageView.alpha = 0;
                    [UIView animateWithDuration:0.2 animations:^{
                        self->_imageView.alpha = 1;
                    }];
                }
            }
            
            if (image) {
                strongSelf.attribute.loadFinished = YES;
                [self updateLayout];
                self.maximumZoomScale = 3;
            }
        }];
        [self updateLayout];
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return _imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    CGFloat offsetX = (scrollView.bounds.size.width > scrollView.contentSize.width) ?
    (scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5 : 0.0;
    
    CGFloat offsetY = (scrollView.bounds.size.height > scrollView.contentSize.height) ?
    (scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5 : 0.0;
    
    _imageView.center = CGPointMake(scrollView.contentSize.width * 0.5 + offsetX,
                                   scrollView.contentSize.height * 0.5 + offsetY);
}

@end

#pragma mark - ViewerController

@interface ViewerController () <UIGestureRecognizerDelegate, UIScrollViewDelegate>

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, strong) UILabel *pageTextLabel;

@property (nonatomic, weak) UIView *fromView;
@property (nonatomic, assign) BOOL isPresenting;
@property (nonatomic, assign) BOOL fromStatusBarHidden;
@property (nonatomic, assign) BOOL fromInteractivePopGestureRecognizerEnabled;

@property (nonatomic, copy) NSArray<ViewerAttribute *> *attributes;
@property (nonatomic, strong) NSMutableArray<ViewerCell *> *reusableCells;

@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *shareButton;

@end

@implementation ViewerController

// Add to ViewerController.m

#pragma mark - Convenience Initializers

- (instancetype)initWithImages:(NSArray<UIImage *> *)images {
    NSMutableArray<ViewerAttribute *> *attributes = [NSMutableArray array];
    
    for (UIImage *image in images) {
        ViewerAttribute *attribute = [ViewerAttribute attributeWithImage:image];
        [attributes addObject:attribute];
    }
    
    return [self initWithAttributes:attributes];
}

- (instancetype)initWithImageURLs:(NSArray<NSURL *> *)imageURLs sourceView:(nullable UIView *)sourceView {
    NSMutableArray<ViewerAttribute *> *attributes = [NSMutableArray array];
    
    for (NSURL *url in imageURLs) {
        ViewerAttribute *attribute = [ViewerAttribute attributeWithImageURL:url
                                                                 sourceView:sourceView];
        [attributes addObject:attribute];
    }
    
    return [self initWithAttributes:attributes];
}

#pragma mark - Navigation Methods

- (void)goToPage:(NSInteger)page animated:(BOOL)animated {
    if (page < 0 || page >= _attributes.count || !_scrollView) {
        return;
    }
    
    CGRect rect = CGRectMake(_scrollView.frame.size.width * page, 0,
                            _scrollView.frame.size.width, _scrollView.frame.size.height);
    
    if (animated) {
        [UIView animateWithDuration:0.3 animations:^{
            [self->_scrollView scrollRectToVisible:rect animated:NO];
        }];
    } else {
        [_scrollView scrollRectToVisible:rect animated:NO];
    }
    
    // Update page label
    [self setupPageLabelWithPage:page];
    
    // Load the cell for the new page
    [self scrollViewDidScroll:_scrollView];
}

- (void)goToNextPageAnimated:(BOOL)animated {
    NSInteger currentPage = [self currentPage];
    NSInteger nextPage = currentPage + 1;
    
    if (nextPage < _attributes.count) {
        [self goToPage:nextPage animated:animated];
    }
}

- (void)goToPreviousPageAnimated:(BOOL)animated {
    NSInteger currentPage = [self currentPage];
    NSInteger prevPage = currentPage - 1;
    
    if (prevPage >= 0) {
        [self goToPage:prevPage animated:animated];
    }
}

#pragma mark - Dismiss Methods

- (void)dismissWithCompletion:(nullable void (^)(void))completion {
    [self dismissWithAnimationStyle:self.animationStyle completion:completion];
}

- (void)dismiss {
    [self dismissWithCompletion:nil];
}

#pragma mark - UI Customization Methods

- (void)setCloseButtonImage:(nullable UIImage *)image forState:(UIControlState)state {
    if (_closeButton) {
        [_closeButton setImage:image forState:state];
    }
}

- (void)setCloseButtonTintColor:(nullable UIColor *)color {
    if (_closeButton) {
        _closeButton.tintColor = color;
    }
}

- (void)setShareButtonImage:(nullable UIImage *)image forState:(UIControlState)state {
    if (_shareButton) {
        [_shareButton setImage:image forState:state];
    }
}

- (void)setShareButtonTintColor:(nullable UIColor *)color {
    if (_shareButton) {
        _shareButton.tintColor = color;
    }
}

- (void)setCurrentPageIndicatorTintColor:(nullable UIColor *)color {
    if (_pageControl) {
        _pageControl.currentPageIndicatorTintColor = color ?: [UIColor whiteColor];
    }
}

- (void)setPageIndicatorTintColor:(nullable UIColor *)color {
    if (_pageControl) {
        _pageControl.pageIndicatorTintColor = color ?: [[UIColor whiteColor] colorWithAlphaComponent:0.2];
    }
}

- (void)setPageTextColor:(nullable UIColor *)color {
    if (_pageTextLabel) {
        _pageTextLabel.textColor = color ?: [UIColor whiteColor];
    }
}

- (void)setPageTextFont:(nullable UIFont *)font {
    if (_pageTextLabel) {
        _pageTextLabel.font = font ?: [UIFont systemFontOfSize:[UIFont systemFontSize]];
    }
}

- (void)setBackgroundColor:(nullable UIColor *)color {
    if (_containerView) {
        _containerView.backgroundColor = color ?: [UIColor blackColor];
    }
}

#pragma mark - Utility Methods

- (nullable UIImage *)imageAtPage:(NSInteger)page {
    if (page < 0 || page >= _attributes.count) {
        return nil;
    }
    
    // Try to get from attribute
    ViewerAttribute *attribute = _attributes[page];
    if (attribute.image) {
        return attribute.image;
    }
    
    // Try to get from cell
    ViewerCell *cell = [self cellForPage:page];
    if (cell && cell.imageView.image) {
        return cell.imageView.image;
    }
    
    return nil;
}

- (void)reloadData {
    // Cancel all current loads
    [self cancelAllImageLoads];
    
    // Reset scroll view
    _scrollView.contentSize = CGSizeMake(_scrollView.frame.size.width * _attributes.count,
                                        _scrollView.frame.size.height);
    
    // Update page label
    [self setupPageLabelWithPage:[self currentPage]];
    
    // Reload visible cells
    [self scrollViewDidScroll:_scrollView];
}

- (void)preloadImages {
    for (ViewerAttribute *attribute in _attributes) {
        if (attribute.imageURL && !attribute.image) {
            // Use SDWebImage to preload
            [[SDWebImagePrefetcher sharedImagePrefetcher] prefetchURLs:@[attribute.imageURL]];
        }
    }
}

#pragma mark - Helper Methods (Add these to your private interface)

- (void)cancelAllImageLoads {
    for (ViewerCell *cell in _reusableCells) {
        if (cell.superview) {
            [cell cancelCurrentLoad];
        }
    }
}

- (NSInteger)currentPage {
    if (!_scrollView || _scrollView.frame.size.width == 0) {
        return 0;
    }
    
    NSInteger page = _scrollView.contentOffset.x / _scrollView.frame.size.width + 0.5;
    page = MAX(0, MIN(page, _attributes.count - 1));
    return page;
}

- (ViewerCell *)cellForPage:(NSInteger)page {
    for (ViewerCell *cell in _reusableCells) {
        if (cell.pageIndex == page) {
            return cell;
        }
    }
    return nil;
}

- (void)setupPageLabelWithPage:(NSInteger)page {
    // Implementation as before
    switch (self.pageLabelStyle) {
        case ViewerPageLabelStyleDot:
            _pageTextLabel.hidden = YES;
            _pageControl.hidden = NO;
            _pageControl.numberOfPages = _attributes.count;
            _pageControl.currentPage = page;
            break;
            
        case ViewerPageLabelStyleNumber:
        case ViewerPageLabelStylePersonalityNumber:
            _pageControl.hidden = YES;
            _pageTextLabel.hidden = NO;
            _pageTextLabel.attributedText = [self attributedTextForPage:page + 1 total:_attributes.count];
            break;
            
        case ViewerPageLabelStyleNone:
            _pageControl.hidden = YES;
            _pageTextLabel.hidden = YES;
            break;
    }
}

- (NSAttributedString *)attributedTextForPage:(NSInteger)current total:(NSInteger)total {
    // Implementation as before
    NSString *currentText = [NSString stringWithFormat:@"%ld", (long)current];
    NSString *totalText = [NSString stringWithFormat:@" / %ld", (long)total];
    NSString *text = [currentText stringByAppendingString:totalText];
    
    if (_pageLabelStyle == ViewerPageLabelStylePersonalityNumber) {
        NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:text];
        [attributedText addAttributes:@{NSFontAttributeName: [UIFont fontWithName:@"Georgia" size:17],
                                        NSForegroundColorAttributeName: [UIColor whiteColor]}
                                range:[text rangeOfString:totalText]];
        [attributedText addAttributes:@{NSFontAttributeName: [UIFont fontWithName:@"Georgia-Bold" size:27],
                                        NSForegroundColorAttributeName: [UIColor whiteColor]}
                                range:[text rangeOfString:currentText]];
        return attributedText;
    }
    
    return [[NSAttributedString alloc] initWithString:text
                                           attributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]}];
}
//  ViewerController.m - Refactored presentation method

#pragma mark - Presentation Methods

- (void)presentFromViewController:(UIViewController *)viewController
                     currentIndex:(NSInteger)index
                presentationStyle:(ViewerPresentationStyle)presentationStyle
                   animationStyle:(ViewerAnimationStyle)animationStyle
                       completion:(nullable void (^)(void))completion {
    
    
    if (_isPresenting) return;
    
    _presentationStyle = presentationStyle;
    _animationStyle = animationStyle;
    
    // Store original status bar state for restoration
    _fromStatusBarHidden = [UIApplication sharedApplication].isStatusBarHidden;
    
    // Store navigation bar state if pushing
    if (presentationStyle == ViewerPresentationStylePush && viewController.navigationController) {
        _fromStatusBarHidden = viewController.navigationController.navigationBarHidden;
        if (_hideNavigationBar) {
            [viewController.navigationController setNavigationBarHidden:YES animated:YES];
        }
    }
    
    // Disable interactive pop gesture if in navigation controller
    UIGestureRecognizer *popGesture = [self findInteractivePopGestureRecognizer];
    if (popGesture) {
        _fromInteractivePopGestureRecognizerEnabled = popGesture.isEnabled;
        popGesture.enabled = NO;
    }
    
    // Configure modal presentation if needed
    if (presentationStyle == ViewerPresentationStyleModal ||
        presentationStyle == ViewerPresentationStyleOverFullScreen ||
        presentationStyle == ViewerPresentationStyleCustom) {
        
        if (@available(iOS 13.0, *)) {
            if (presentationStyle == ViewerPresentationStyleOverFullScreen) {
                self.modalPresentationStyle = UIModalPresentationOverFullScreen;
            } else {
                self.modalPresentationStyle = UIModalPresentationFullScreen;
            }
            
            // Configure interactive dismiss
            if (!_disableInteractiveDismiss) {
                self.modalInPresentation = NO;
            } else {
                self.modalInPresentation = YES;
            }
        } else {
            if (presentationStyle == ViewerPresentationStyleOverFullScreen) {
                self.modalPresentationStyle = UIModalPresentationOverFullScreen;
            } else {
                self.modalPresentationStyle = UIModalPresentationFullScreen;
            }
        }
        
        // Status bar appearance
        //self.modalPresentationCapturesStatusBarAppearance = _modalPresentationCapturesStatusBarAppearance;
    }
    
    // Setup initial state before presentation
    NSInteger page = MAX(0, MIN(index, _attributes.count - 1));
    [self setupPageLabelWithPage:page];
    
    _scrollView.contentSize = CGSizeMake(_scrollView.frame.size.width * _attributes.count, _scrollView.frame.size.height);
    [_scrollView scrollRectToVisible:CGRectMake(_scrollView.frame.size.width * page, 0,
                                               _scrollView.frame.size.width,
                                               _scrollView.frame.size.height)
                            animated:NO];
    [self scrollViewDidScroll:_scrollView];
    
    NSInteger currentPage = [self currentPage];
    ViewerCell *cell = [self cellForPage:currentPage];
    ViewerAttribute *attribute = _attributes[currentPage];
    _fromView = attribute.sourceView;
    
    // Preload the current image
    [self preloadImageForAttribute:attribute cell:cell];
    
    // Perform presentation based on style
    switch (presentationStyle) {
        case ViewerPresentationStyleModal:
            [self presentModalFromViewController:viewController
                                    currentIndex:index
                                   animationStyle:animationStyle
                                       completion:completion];
            break;
            
        case ViewerPresentationStylePush:
            [self pushToViewController:viewController
                          currentIndex:index
                         animationStyle:animationStyle
                             completion:completion];
            break;
            
        case ViewerPresentationStyleOverFullScreen:
            [self presentOverFullScreenFromViewController:viewController
                                             currentIndex:index
                                            animationStyle:animationStyle
                                                completion:completion];
            break;
            
        case ViewerPresentationStyleChild:
            [self addAsChildViewController:viewController
                              currentIndex:index
                             animationStyle:animationStyle
                                 completion:completion];
            break;
            
        case ViewerPresentationStyleCustom:
            [self presentWithCustomAnimationFromViewController:viewController
                                                  currentIndex:index
                                                 animationStyle:animationStyle
                                                     completion:completion];
            break;
    }
}

- (void)presentFromViewController:(UIViewController *)viewController
                     currentIndex:(NSInteger)index
                       completion:(nullable void (^)(void))completion {
    
    // Default to modal presentation with zoom animation
    [self presentFromViewController:viewController
                       currentIndex:index
                  presentationStyle:ViewerPresentationStyleModal
                     animationStyle:ViewerAnimationStyleZoom
                         completion:completion];
}

#pragma mark - Presentation Style Implementations

- (void)presentModalFromViewController:(UIViewController *)viewController
                          currentIndex:(NSInteger)index
                         animationStyle:(ViewerAnimationStyle)animationStyle
                             completion:(nullable void (^)(void))completion {
    
   
    __weak typeof(self) weakSelf = self;
    [viewController presentViewController:self animated:(animationStyle != ViewerAnimationStyleNone) completion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        strongSelf->_isPresenting = YES;
        if (completion) completion();
        // Perform entrance animation if needed
        if (animationStyle == ViewerAnimationStyleSlide) {
           // [strongSelf performSlideInAnimationWithCompletion:completion];
        } else if (animationStyle == ViewerAnimationStyleFade) {
           // [strongSelf performFadeInAnimationWithCompletion:completion];
        } else if (animationStyle == ViewerAnimationStyleNone) {
           // [strongSelf finalizePresentationWithCompletion:completion];
        } else {
            // Zoom animation handled by transition delegate
            if (completion) completion();
        }
    }];
}

- (void)pushToViewController:(UIViewController *)viewController
                currentIndex:(NSInteger)index
               animationStyle:(ViewerAnimationStyle)animationStyle
                   completion:(nullable void (^)(void))completion {
    
    if (!viewController.navigationController) {
        // Fallback to modal if no navigation controller
        [self presentModalFromViewController:viewController
                                currentIndex:index
                               animationStyle:animationStyle
                                   completion:completion];
        return;
    }
    
    // Configure for push
    self.hidesBottomBarWhenPushed = YES;
    
    __weak typeof(self) weakSelf = self;
    
    // Push with or without animation
    BOOL animated = (animationStyle != ViewerAnimationStyleNone);
    [viewController.navigationController pushViewController:self animated:animated];
    
    // Use a small delay to ensure view is loaded
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        strongSelf->_isPresenting = YES;
        [strongSelf finalizePresentationWithCompletion:completion];
    });
}

- (void)presentOverFullScreenFromViewController:(UIViewController *)viewController
                                   currentIndex:(NSInteger)index
                                  animationStyle:(ViewerAnimationStyle)animationStyle
                                      completion:(nullable void (^)(void))completion {
    
    // Similar to modal but with overFullScreen style
    [self presentModalFromViewController:viewController
                            currentIndex:index
                           animationStyle:animationStyle
                               completion:completion];
}

- (void)addAsChildViewController:(UIViewController *)viewController
                    currentIndex:(NSInteger)index
                   animationStyle:(ViewerAnimationStyle)animationStyle
                       completion:(nullable void (^)(void))completion {
    
    // Original child controller implementation
    [viewController addChildViewController:self];
    [viewController.view addSubview:self.view];
    
    // Setup frame
    self.view.frame = viewController.view.bounds;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // Perform entrance animation
    [self performEntranceAnimationWithStyle:animationStyle completion:^{
        [self didMoveToParentViewController:viewController];
        self->_isPresenting = YES;
        [self finalizePresentationWithCompletion:completion];
    }];
}

- (void)presentWithCustomAnimationFromViewController:(UIViewController *)viewController
                                        currentIndex:(NSInteger)index
                                       animationStyle:(ViewerAnimationStyle)animationStyle
                                           completion:(nullable void (^)(void))completion {
    
    // Add as child for custom animations
    [viewController addChildViewController:self];
    
    // Add to window for full screen custom animations
    UIWindow *window = viewController.view.window ?: [UIApplication sharedApplication].keyWindow;
    [window addSubview:self.view];
    
    self.view.frame = window.bounds;
    
    // Perform custom animation
    [self performCustomEntranceAnimationWithStyle:animationStyle completion:^{
        [self didMoveToParentViewController:viewController];
        self->_isPresenting = YES;
        [self finalizePresentationWithCompletion:completion];
    }];
}

#pragma mark - Animation Methods

- (void)performEntranceAnimationWithStyle:(ViewerAnimationStyle)animationStyle
                               completion:(void (^)(void))completion {
    
    switch (animationStyle) {
        case ViewerAnimationStyleZoom:
            [self performZoomInAnimationWithCompletion:completion];
            break;
            
        case ViewerAnimationStyleFade:
            [self performFadeInAnimationWithCompletion:completion];
            break;
            
        case ViewerAnimationStyleSlide:
            [self performSlideInAnimationWithCompletion:completion];
            break;
            
        case ViewerAnimationStyleNone:
            if (completion) completion();
            break;
    }
}

- (void)performZoomInAnimationWithCompletion:(void (^)(void))completion {
    if (!_fromView) {
        [self performFadeInAnimationWithCompletion:completion];
        return;
    }
    
    NSInteger currentPage = [self currentPage];
    ViewerCell *cell = [self cellForPage:currentPage];
    
    CGRect fromFrame = [_fromView convertRect:_fromView.bounds toView:cell];
    CGRect toFrame = cell.imageView.frame;
    
    cell.imageView.frame = fromFrame;
    _containerView.backgroundColor = [UIColor clearColor];
    self.view.alpha = 0;
    
    [UIView animateWithDuration:0.15 animations:^{
        self.view.alpha = 1;
        self->_containerView.backgroundColor = [UIColor blackColor];
    }];
    
    if (self.bouncesAnimated) {
        [UIView animateWithDuration:0.55
                              delay:0
             usingSpringWithDamping:0.6
              initialSpringVelocity:0.2
                            options:UIViewAnimationOptionCurveLinear
                         animations:^{
            cell.imageView.frame = toFrame;
        } completion:^(BOOL finished) {
            if (completion) completion();
        }];
    } else {
        [UIView animateWithDuration:_animateDuration animations:^{
            cell.imageView.frame = toFrame;
        } completion:^(BOOL finished) {
            if (completion) completion();
        }];
    }
}

- (void)performFadeInAnimationWithCompletion:(void (^)(void))completion {
    self.view.alpha = 0;
    _containerView.alpha = 0;
    
    NSInteger currentPage = [self currentPage];
    ViewerCell *cell = [self cellForPage:currentPage];
    cell.imageView.alpha = 0;
    
    [UIView animateWithDuration:_animateDuration animations:^{
        self.view.alpha = 1;
        self->_containerView.alpha = 1;
        cell.imageView.alpha = 1;
    } completion:^(BOOL finished) {
        if (completion) completion();
    }];
}

- (void)performSlideInAnimationWithCompletion:(void (^)(void))completion {
    CGRect originalFrame = self.view.frame;
    CGRect startFrame = originalFrame;
    startFrame.origin.y = CGRectGetHeight(self.view.bounds);
    self.view.frame = startFrame;
    
    [UIView animateWithDuration:0.3
                          delay:0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.view.frame = originalFrame;
    } completion:^(BOOL finished) {
        if (completion) completion();
    }];
}

- (void)performCustomEntranceAnimationWithStyle:(ViewerAnimationStyle)animationStyle
                                     completion:(void (^)(void))completion {
    // Default to fade for custom
    [self performFadeInAnimationWithCompletion:completion];
}

#pragma mark - Finalize Presentation

- (void)finalizePresentationWithCompletion:(nullable void (^)(void))completion {
    NSInteger currentPage = [self currentPage];
    ViewerCell *cell = [self cellForPage:currentPage];
    ViewerAttribute *attribute = _attributes[currentPage];
    
    // Ensure cell is loaded with proper style
    cell.loadingStyle = self.loadingStyle;
    cell.attribute = attribute;
    
    // Hide page label after delay
    [self hidePageLabel];
    
    if (completion) completion();
}

#pragma mark - Helper Methods

- (void)preloadImageForAttribute:(ViewerAttribute *)attribute cell:(ViewerCell *)cell {
    if (attribute.image) {
        cell.imageView.image = attribute.image;
        [cell updateLayout];
        return;
    }
    
    if (attribute.imageURL) {
        SDWebImageManager *manager = [SDWebImageManager sharedManager];
        NSString *cacheKey = [manager cacheKeyForURL:attribute.imageURL];
        
        // Check if image exists in cache
        SDImageCache *imageCache = manager.imageCache;
        [imageCache containsImageForKey:cacheKey cacheType:SDImageCacheTypeAll completion:^(SDImageCacheType containsCacheType) {
            dispatch_main_async_safe(^{
                if (containsCacheType != SDImageCacheTypeNone) {
                    cell.attribute = attribute;
                } else {
                    cell.imageView.image = attribute.placeholderImage;
                    [cell updateLayout];
                }
            });
        }];
    } else {
        cell.imageView.image = attribute.placeholderImage;
        [cell updateLayout];
    }
}

#pragma mark - Dismiss Methods

- (void)dismissWithAnimationStyle:(ViewerAnimationStyle)animationStyle
                       completion:(nullable void (^)(void))completion {
    
    if (!_isPresenting) {
        if (completion) completion();
        return;
    }
    
    // Restore status bar
    [self setNeedsStatusBarAppearanceUpdate];
    
    // Re-enable interactive pop gesture
    UIGestureRecognizer *popGesture = [self findInteractivePopGestureRecognizer];
    if (popGesture) {
        popGesture.enabled = _fromInteractivePopGestureRecognizerEnabled;
    }
    
    // Restore navigation bar if needed
    if (_presentationStyle == ViewerPresentationStylePush && self.navigationController && _hideNavigationBar) {
        //[self.navigationController setNavigationBarHidden:NO animated:YES];
    }
    
    [self cancelAllImageLoads];
    
    [UIView animateWithDuration:0.15 animations:^{
        self->_pageTextLabel.alpha = self->_pageControl.alpha = 0;
    }];
    
    void (^dismissCallback)(void) = ^{
        self->_isPresenting = NO;
        
        switch (self.presentationStyle) {
            case ViewerPresentationStyleModal:
            case ViewerPresentationStyleOverFullScreen:
                [self dismissViewControllerAnimated:(animationStyle != ViewerAnimationStyleNone) completion:completion];
                break;
                
            case ViewerPresentationStylePush:
                [self.navigationController popViewControllerAnimated:(animationStyle != ViewerAnimationStyleNone)];
                if (completion) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), completion);
                }
                break;
                
            case ViewerPresentationStyleChild:
            case ViewerPresentationStyleCustom:
                [self removeFromParentViewControllerWithAnimationStyle:animationStyle completion:completion];
                break;
        }
    };
    
    // Perform exit animation
    if (animationStyle != ViewerAnimationStyleNone && _presentationStyle != ViewerPresentationStyleModal) {
        [self performExitAnimationWithStyle:animationStyle completion:dismissCallback];
    } else {
        dismissCallback();
    }
}

- (void)removeFromParentViewControllerWithAnimationStyle:(ViewerAnimationStyle)animationStyle
                                              completion:(nullable void (^)(void))completion {
    
    [self willMoveToParentViewController:nil];
    
    [self performExitAnimationWithStyle:animationStyle completion:^{
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
        [self dismissWithCompletion:^{
            if (completion) completion();
        }];
        
    }];
}

- (void)performExitAnimationWithStyle:(ViewerAnimationStyle)animationStyle
                           completion:(void (^)(void))completion {
    
    switch (animationStyle) {
        case ViewerAnimationStyleZoom:
            [self performZoomOutAnimationWithCompletion:completion];
            break;
            
        case ViewerAnimationStyleFade:
            [self performFadeOutAnimationWithCompletion:completion];
            break;
            
        case ViewerAnimationStyleSlide:
            [self performSlideOutAnimationWithCompletion:completion];
            break;
            
        case ViewerAnimationStyleNone:
            if (completion) completion();
            break;
    }
}

- (void)performZoomOutAnimationWithCompletion:(void (^)(void))completion {
    NSInteger currentPage = [self currentPage];
    ViewerCell *cell = [self cellForPage:currentPage];
    ViewerAttribute *attribute = _attributes[currentPage];
    UIView *sourceView = attribute.sourceView;
    
    if (!sourceView) {
        [self performFadeOutAnimationWithCompletion:completion];
        return;
    }
    
    CGRect toFrame = [sourceView convertRect:sourceView.bounds toView:cell];
    
    if (self.bouncesAnimated) {
        [UIView animateWithDuration:0.15 animations:^{
            self->_containerView.alpha = 0;
            self.view.backgroundColor = [UIColor clearColor];
        }];
        
        [UIView animateWithDuration:0.55
                              delay:0
             usingSpringWithDamping:0.6
              initialSpringVelocity:0.2
                            options:UIViewAnimationOptionCurveLinear
                         animations:^{
            cell.imageView.frame = toFrame;
        } completion:^(BOOL finished) {
            if (completion) completion();
        }];
    } else {
        [UIView animateWithDuration:_animateDuration
                              delay:0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            cell.imageView.frame = toFrame;
            self->_containerView.alpha = 0;
            self.view.backgroundColor = [UIColor clearColor];
        } completion:^(BOOL finished) {
            if (completion) completion();
        }];
    }
}

- (void)performFadeOutAnimationWithCompletion:(void (^)(void))completion {
    [UIView animateWithDuration:0.25 animations:^{
        self.view.alpha = 0;
    } completion:^(BOOL finished) {
        if (completion) completion();
    }];
}

- (void)performSlideOutAnimationWithCompletion:(void (^)(void))completion {
    CGRect endFrame = self.view.frame;
    endFrame.origin.y = CGRectGetHeight(self.view.bounds);
    
    [UIView animateWithDuration:0.3 animations:^{
        self.view.frame = endFrame;
    } completion:^(BOOL finished) {
        if (completion) completion();
    }];
}

#pragma mark - Lifecycle

- (instancetype)initWithAttributes:(NSArray<ViewerAttribute *> *)attributes {
    NSParameterAssert(attributes.count > 0);
    if (self = [super init]) {
        _attributes = [attributes copy];
        _reusableCells = [NSMutableArray array];
        _pageSpacing = 20;
        _animateDuration = 0.2;
        _loadingStyle = ViewerLoadingStyleSpin;
        _pageLabelStyle = ViewerPageLabelStyleDot;
        _alwaysShowPageLabel = NO;
        _bouncesAnimated = NO;
        
        [self setupGestureRecognizers];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateLayout];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation {
    return UIStatusBarAnimationFade;
}

#pragma mark - Setup

- (void)setupUI {
    self.view.backgroundColor = [UIColor clearColor];
    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.clipsToBounds = YES;
    
    // Container View
    _containerView = [[UIView alloc] init];
    _containerView.frame = self.view.bounds;
    _containerView.backgroundColor = [UIColor blackColor];
    _containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_containerView];
    
    // Scroll View
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.frame = CGRectMake(-_pageSpacing / 2, 0,
                                   self.view.frame.size.width + _pageSpacing,
                                   self.view.frame.size.height);
    _scrollView.delegate = self;
    _scrollView.scrollsToTop = NO;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.delaysContentTouches = NO;
    _scrollView.pagingEnabled = YES;
    _scrollView.canCancelContentTouches = YES;
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.alwaysBounceHorizontal = _attributes.count > 1;
    [self.view addSubview:_scrollView];
    
    // Page Control
    _pageControl = [[UIPageControl alloc] init];
    _pageControl.hidesForSinglePage = YES;
    _pageControl.userInteractionEnabled = NO;
    _pageControl.frame = CGRectMake(0, 0, self.view.frame.size.width - 40, 10);
    _pageControl.pageIndicatorTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.2];
    _pageControl.currentPageIndicatorTintColor = [UIColor whiteColor];
    _pageControl.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height - 20);
    _pageControl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _pageControl.alpha = 0;
    [self.view addSubview:_pageControl];
    
    // Page Text Label
    _pageTextLabel = [[UILabel alloc] init];
    _pageTextLabel.frame = CGRectMake(0, 0, 120, 30);
    _pageTextLabel.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height - 40);
    _pageTextLabel.textColor = [UIColor whiteColor];
    _pageTextLabel.textAlignment = NSTextAlignmentCenter;
    _pageTextLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
    _pageTextLabel.alpha = 0;
    [self.view addSubview:_pageTextLabel];
    
    // Close Button
    _closeButton = [AppMgr.topViewController pp_ButtonWithSystemName:@"multiply" action:@selector(dismiss)];
     _closeButton.contentMode = UIViewContentModeScaleAspectFill;
    _closeButton.backgroundColor = [UIColor clearColor];
    _closeButton.tintColor = [UIColor whiteColor];
    [_closeButton addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_closeButton];
    
    // Share Button
    _shareButton =  [AppMgr.topViewController pp_ButtonWithSystemName:@"square.and.arrow.up" action:@selector(handleShareAction)];
    _shareButton.contentMode = UIViewContentModeScaleAspectFill;
    _shareButton.backgroundColor = [UIColor clearColor];
    _shareButton.tintColor = [UIColor whiteColor];
    [_shareButton addTarget:self action:@selector(handleShareAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_shareButton];
}

- (void)setupGestureRecognizers {
    // Single Tap
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    singleTap.delegate = self;
    singleTap.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:singleTap];
    
    // Double Tap
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.delegate = self;
    doubleTap.numberOfTapsRequired = 2;
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [self.view addGestureRecognizer:doubleTap];
    
    // Long Press
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.delegate = self;
    [self.view addGestureRecognizer:longPress];
}

- (void)updateLayout {
    _closeButton.frame = CGRectMake(20, 50, 40, 40);
    _shareButton.frame = CGRectMake(self.view.frame.size.width - 60, 50, 40, 40);
    _pageControl.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height - 20);
    _pageTextLabel.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height - 40);
}

#pragma mark - Public Methods


- (void)dismissAnimated:(BOOL)animated completion:(void (^)(void))completion {
    if (!_isPresenting) return;
    [self dismissViewControllerAnimated:YES completion:^{ }]; return;
    // Restore status bar
    [self setNeedsStatusBarAppearanceUpdate];
    
    // Re-enable interactive pop gesture
    UIGestureRecognizer *popGesture = [self findInteractivePopGestureRecognizer];
    if (popGesture) {
        popGesture.enabled = _fromInteractivePopGestureRecognizerEnabled;
    }
    
    if (!animated) _animateDuration = 0;
    
    NSInteger currentPage = [self currentPage];
    ViewerCell *cell = [self cellForPage:currentPage];
    ViewerAttribute *attribute = _attributes[currentPage];
    UIView *sourceView = attribute.sourceView;
    
    [self cancelAllImageLoads];
    
    [UIView animateWithDuration:0.15 animations:^{
        self->_pageTextLabel.alpha = self->_pageControl.alpha = 0;
    }];
    
    void (^dismissCallback)(void) = ^{
        self->_isPresenting = NO;
        [self willMoveToParentViewController:nil];
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
        [self.delegate viewerControllerDidDismiss:self];
        if (completion) completion();
    };
    
    
     if (sourceView) {
         CGRect fromFrame = [sourceView convertRect:sourceView.bounds toView:cell];
         
         if (self.bouncesAnimated) {
             [UIView animateWithDuration:0.15 animations:^{
                 self->_containerView.alpha = 0;
                 self.view.backgroundColor = [UIColor clearColor];
             }];
             
             [UIView animateWithDuration:0.55 delay:0.f usingSpringWithDamping:0.6 initialSpringVelocity:0.2 options:UIViewAnimationOptionCurveLinear animations:^{
                 cell.imageView.frame = fromFrame;
             } completion:^(BOOL finished) {
                 if (finished) dismissCallback();
             }];
         } else {
             [UIView animateWithDuration:_animateDuration delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
                 cell.imageView.frame = fromFrame;
                 self->_containerView.alpha = 0;
                 self.view.backgroundColor = [UIColor clearColor];
             } completion:^(BOOL finished) {
                 if (finished) dismissCallback();
             }];
         }
         
        
     } else {
         [UIView animateWithDuration:0.25 animations:^{
             self.view.alpha = 0;
         } completion:^(BOOL finished) {
             if (finished) dismissCallback();
         }];
     }
        
}

#pragma mark - Private Methods

- (UIGestureRecognizer *)findInteractivePopGestureRecognizer {
    UIViewController *viewController = self.parentViewController;
    while (viewController) {
        if ([viewController isKindOfClass:[UINavigationController class]]) {
            return ((UINavigationController *)viewController).interactivePopGestureRecognizer;
        }
        viewController = viewController.parentViewController;
    }
    return nil;
}
 

- (void)hidePageLabel {
    if (_alwaysShowPageLabel) return;
    
    [UIView animateWithDuration:0.45 delay:0.65 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut animations:^{
        self->_pageTextLabel.alpha = self->_pageControl.alpha = 0;
    } completion:NULL];
}
 

#pragma mark - Cell Management

- (void)updateReusableCells {
    for (ViewerCell *cell in _reusableCells) {
        if (cell.superview) {
            if (cell.frame.origin.x > _scrollView.contentOffset.x + _scrollView.frame.size.width * 2 ||
                (cell.frame.origin.x + cell.frame.size.width) < _scrollView.contentOffset.x - _scrollView.frame.size.width) {
                [cell removeFromSuperview];
                cell.pageIndex = -1;
                cell.attribute = nil;
            }
        }
    }
}
 

- (ViewerCell *)dequeueReusableCell {
    for (ViewerCell *cell in _reusableCells) {
        if (!cell.superview) return cell;
    }
    
    ViewerCell *cell = [[ViewerCell alloc] init];
    cell.frame = self.view.bounds;
    cell.pageIndex = -1;
    cell.attribute = nil;
    [_reusableCells addObject:cell];
    return cell;
}

#pragma mark - Gesture Handlers

- (void)handleSingleTap:(UITapGestureRecognizer *)gesture {
    [self dismissAnimated:YES completion:nil];
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gesture {
    if (!_isPresenting) return;
    
    ViewerCell *cell = [self cellForPage:[self currentPage]];
    if (!cell) return;
    
    if (cell.zoomScale > 1) {
        [cell setZoomScale:1 animated:YES];
    } else {
        CGPoint touchPoint = [gesture locationInView:cell.imageView];
        CGFloat newZoomScale = cell.maximumZoomScale;
        CGFloat xsize = cell.bounds.size.width / newZoomScale;
        CGFloat ysize = cell.bounds.size.height / newZoomScale;
        [cell zoomToRect:CGRectMake(touchPoint.x - xsize/2, touchPoint.y - ysize/2, xsize, ysize) animated:YES];
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (!_isPresenting || gesture.state != UIGestureRecognizerStateBegan) return;
    
    NSInteger currentPage = [self currentPage];
    ViewerCell *cell = [self cellForPage:currentPage];
    ViewerAttribute *attribute = _attributes[currentPage];
    
    if ([self.delegate respondsToSelector:@selector(viewerController:didLongPressAtIndex:attribute:image:)]) {
        [self.delegate viewerController:self
                    didLongPressAtIndex:currentPage
                              attribute:attribute
                                  image:cell.imageView.image];
    }
}

- (void)handleShareAction {
    NSInteger currentPage = [self currentPage];
    ViewerCell *cell = [self cellForPage:currentPage];
    ViewerAttribute *attribute = _attributes[currentPage];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [PPAdSharingHelper sharePetAd:self.currentAd fromViewController:self];
    });
}
 

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) [self hidePageLabel];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self hidePageLabel];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self updateReusableCells];
    
    CGFloat floatPage = _scrollView.contentOffset.x / _scrollView.frame.size.width;
    NSInteger page = _scrollView.contentOffset.x / _scrollView.frame.size.width + 0.5;
    
    // Load visible and adjacent cells
    for (NSInteger i = page - 1; i <= page + 1; i++) {
        if (i >= 0 && i < _attributes.count) {
            ViewerCell *cell = [self cellForPage:i];
            if (!cell) {
                cell = [self dequeueReusableCell];
                cell.pageIndex = i;
                CGRect frame = cell.frame;
                frame.origin.x = (self.view.frame.size.width + _pageSpacing) * i + _pageSpacing / 2;
                cell.frame = frame;
                
                if (_isPresenting) {
                    cell.loadingStyle = self.loadingStyle;
                    cell.attribute = _attributes[i];
                }
                [_scrollView addSubview:cell];
            } else if (_isPresenting && !cell.attribute) {
                cell.loadingStyle = self.loadingStyle;
                cell.attribute = _attributes[i];
            }
        }
    }
    
    NSInteger intPage = floatPage + 0.5;
    intPage = MAX(0, MIN(intPage, _attributes.count - 1));
    
    _pageControl.currentPage = intPage;
    _pageTextLabel.attributedText = [self attributedTextForPage:intPage + 1 total:_attributes.count];
    
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut animations:^{
        self->_pageControl.alpha = 1;
        self->_pageTextLabel.alpha = 1;
    } completion:NULL];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isDescendantOfView:_closeButton] || [touch.view isDescendantOfView:_shareButton]) {
        return NO;
    }
    return YES;
}

@end

// Optional: Custom transition class for zoom animations
@interface ViewerTransition : NSObject <UIViewControllerAnimatedTransitioning>
@property (nonatomic, assign) BOOL presenting;
@property (nonatomic, weak) UIView *sourceView;
@property (nonatomic, assign) ViewerAnimationStyle animationStyle;
- (instancetype)initWithAnimationStyle:(ViewerAnimationStyle)animationStyle;
@end

@implementation ViewerTransition
// Implementation of custom transition animations
- (void)animateTransition:(nonnull id<UIViewControllerContextTransitioning>)transitionContext { 
    
}


@end





































 
@interface ImageViewerManager () <ViewerControllerDelegate>

@property (nonatomic, strong) ViewerController *currentViewer;
@property (nonatomic, weak) UIViewController *presentingController;
@property (nonatomic, strong) NSMutableArray<ViewerController *> *presentedViewers;
@property (nonatomic, strong) NSMutableDictionary *configuration;

// Caching
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, strong) SDWebImagePrefetcher *imagePrefetcher;

@end

@implementation ImageViewerManager

#pragma mark - Singleton & Initialization

+ (ImageViewerManager *)sharedManager {
    static ImageViewerManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (void)configureDefaultSettings {
    ImageViewerManager *manager = [self sharedManager];
    [manager setLoadingStyle:ViewerLoadingStyleSpin];
    [manager setPageLabelStyle:ViewerPageLabelStyleDot];
    [manager setBouncesAnimated:YES];
    [manager setPageSpacing:20];
    [manager setAlwaysShowPageLabel:NO];
    
    manager.shouldSaveToPhotosOnLongPress = YES;
    manager.shouldShowShareOption = YES;
    manager.enableDoubleTapToZoom = YES;
    manager.enableSingleTapToDismiss = YES;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _presentedViewers = [NSMutableArray array];
        _configuration = [NSMutableDictionary dictionary];
        _imageCache = [[NSCache alloc] init];
        _imageCache.name = @"ImageViewerManagerCache";
        _imageCache.countLimit = 50; // Cache up to 50 images
        
        _shouldSaveToPhotosOnLongPress = YES;
        _shouldShowShareOption = YES;
        _enableDoubleTapToZoom = YES;
        _enableSingleTapToDismiss = YES;
        
        // Default configuration
        _configuration[@"loadingStyle"] = @(ViewerLoadingStyleSpin);
        _configuration[@"pageLabelStyle"] = @(ViewerPageLabelStyleDot);
        _configuration[@"bouncesAnimated"] = @(YES);
        _configuration[@"pageSpacing"] = @(20);
        _configuration[@"alwaysShowPageLabel"] = @(NO);
        
        // Setup image prefetcher
        _imagePrefetcher = [SDWebImagePrefetcher sharedImagePrefetcher];
        _imagePrefetcher.options = SDWebImageHighPriority;
        _imagePrefetcher.maxConcurrentPrefetchCount = 3;
    }
    return self;
}

#pragma mark - Public Presentation Methods

- (void)presentWithImages:(NSArray<UIImage *> *)images
           fromController:(UIViewController *)presentingController
             currentIndex:(NSInteger)index
               sourceView:(nullable UIView *)sourceView {
    
    NSMutableArray<ViewerAttribute *> *attributes = [NSMutableArray array];
    
    for (int i = 0; i < images.count; i++) {
        UIImage *image = images[i];
        ViewerAttribute *attribute = [ViewerAttribute attributeWithImage:image];
        
        // Use the source view only for the current index if provided
        if (i == index && sourceView) {
            attribute.sourceView = sourceView;
        }
        
        [attributes addObject:attribute];
    }
    
    [self presentViewerWithAttributes:attributes
                       fromController:presentingController
                         currentIndex:index];
}

- (void)presentWithImageURLs:(NSArray<NSString *> *)imageURLs
              fromController:(UIViewController *)presentingController
                currentIndex:(NSInteger)index
                  sourceView:(nullable UIView *)sourceView
            placeholderImage:(nullable UIImage *)placeholder {
    
    NSMutableArray<ViewerAttribute *> *attributes = [NSMutableArray array];
    
    for (int i = 0; i < imageURLs.count; i++) {
        NSURL *url = [NSURL URLWithString:imageURLs[i]];
        ViewerAttribute *attribute = [ViewerAttribute attributeWithImageURL:url sourceView:nil];
        attribute.placeholderImage = placeholder;
        
        // Use the source view only for the current index if provided
        if (i == index && sourceView) {
            attribute.sourceView = sourceView;
        }
        
        [attributes addObject:attribute];
    }
    
    [self presentViewerWithAttributes:attributes
                       fromController:presentingController
                         currentIndex:index];
}

- (void)presentWithMixedContent:(NSArray<id> *)content
                 fromController:(UIViewController *)presentingController
                   currentIndex:(NSInteger)index
                     sourceView:(nullable UIView *)sourceView {
    
    NSMutableArray<ViewerAttribute *> *attributes = [NSMutableArray array];
    
    for (int i = 0; i < content.count; i++) {
        id item = content[i];
        ViewerAttribute *attribute = nil;
        
        if ([item isKindOfClass:[UIImage class]]) {
            attribute = [ViewerAttribute attributeWithImage:item];
        } else if ([item isKindOfClass:[NSURL class]]) {
            attribute = [ViewerAttribute attributeWithImageURL:item sourceView:nil];
        } else if ([item isKindOfClass:[NSString class]]) {
            NSURL *url = [NSURL URLWithString:item];
            if (url) {
                attribute = [ViewerAttribute attributeWithImageURL:url sourceView:nil];
            }
        } else if ([item isKindOfClass:[ViewerAttribute class]]) {
            attribute = item;
        }
        
        if (attribute) {
            // Use the source view only for the current index if provided
            if (i == index && sourceView && !attribute.sourceView) {
                attribute.sourceView = sourceView;
            }
            [attributes addObject:attribute];
        }
    }
    
    [self presentViewerWithAttributes:attributes
                       fromController:presentingController
                         currentIndex:index];
}

- (void)presentViewerWithAttributes:(NSArray<ViewerAttribute *> *)attributes
                     fromController:(UIViewController *)presentingController
                       currentIndex:(NSInteger)index {
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(imageViewerManager:willPresentAtIndex:)]) {
        [self.delegate imageViewerManager:self willPresentAtIndex:index];
    }
    
    // Create viewer controller
    ViewerController *viewer = [[ViewerController alloc] initWithAttributes:attributes];
    viewer.delegate = self;
    
    // Apply configuration
    viewer.loadingStyle = [self.configuration[@"loadingStyle"] integerValue];
    viewer.pageLabelStyle = [self.configuration[@"pageLabelStyle"] integerValue];
    viewer.bouncesAnimated = [self.configuration[@"bouncesAnimated"] boolValue];
    viewer.pageSpacing = [self.configuration[@"pageSpacing"] floatValue];
    viewer.alwaysShowPageLabel = [self.configuration[@"alwaysShowPageLabel"] boolValue];
    
    // Configure gestures
    viewer.view.gestureRecognizers = nil;
    if (self.enableSingleTapToDismiss) {
        UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
        singleTap.numberOfTapsRequired = 1;
        [viewer.view addGestureRecognizer:singleTap];
    }
    
    if (self.enableDoubleTapToZoom) {
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
        doubleTap.numberOfTapsRequired = 2;
        [viewer.view addGestureRecognizer:doubleTap];
    }
    
    _currentViewer = viewer;
    _presentingController = presentingController;
    
    // Store reference
    [_presentedViewers addObject:viewer];
    
    // Present
    __weak typeof(self) weakSelf = self;
    [viewer presentFromViewController:presentingController
                         currentIndex:index
                           completion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // Notify delegate
        if ([strongSelf.delegate respondsToSelector:@selector(imageViewerManager:didPresentAtIndex:)]) {
            [strongSelf.delegate imageViewerManager:strongSelf didPresentAtIndex:index];
        }
    }];
}

#pragma mark - Dismiss Methods

- (void)dismissCurrentViewerAnimated:(BOOL)animated completion:(nullable void (^)(void))completion {
    if (!_currentViewer) {
        if (completion) completion();
        return;
    }
    
    [_currentViewer dismissAnimated:animated completion:^{
        if (completion) completion();
    }];
}

- (void)dismissAllViewersAnimated:(BOOL)animated completion:(nullable void (^)(void))completion {
    if (_presentedViewers.count == 0) {
        if (completion) completion();
        return;
    }
    
    __block NSInteger remaining = _presentedViewers.count;
    
    for (ViewerController *viewer in _presentedViewers) {
        [viewer dismissAnimated:animated completion:^{
            remaining--;
            if (remaining == 0) {
                [self->_presentedViewers removeAllObjects];
                self->_currentViewer = nil;
                if (completion) completion();
            }
        }];
    }
}

#pragma mark - Utility Methods

- (BOOL)isViewerPresented {
    return _currentViewer != nil;
}

- (NSInteger)currentPageIndex {
    return _currentViewer ? [[_currentViewer valueForKey:@"currentPage"] integerValue] : -1;
}

- (nullable UIImage *)currentImage {
    if (!_currentViewer) return nil;
    
    NSInteger currentPage = [self currentPageIndex];
    if (currentPage < 0) return nil;
    
    // Try to get image from viewer
    @try {
        id cell = [_currentViewer valueForKeyPath:[NSString stringWithFormat:@"cellForPage:%ld", (long)currentPage]];
        if (cell && [cell respondsToSelector:@selector(imageView)]) {
            UIImageView *imageView = [cell imageView];
            return imageView.image;
        }
    } @catch (NSException *exception) {
        NSLog(@"Error getting current image: %@", exception);
    }
    
    return nil;
}

- (void)preloadImagesForURLs:(NSArray<NSURL *> *)urls {
    if (urls.count == 0) return;
    
    [_imagePrefetcher prefetchURLs:urls progress:nil completed:^(NSUInteger noOfFinishedUrls, NSUInteger noOfSkippedUrls) {
        NSLog(@"Prefetched %lu images, skipped %lu", (unsigned long)noOfFinishedUrls, (unsigned long)noOfSkippedUrls);
    }];
}

- (void)clearImageCache {
    [_imageCache removeAllObjects];
    
    // Clear SDWebImage cache
    [[SDImageCache sharedImageCache] clearMemory];
}

#pragma mark - Configuration Setters

- (void)setLoadingStyle:(ViewerLoadingStyle)loadingStyle {
    _configuration[@"loadingStyle"] = @(loadingStyle);
    if (_currentViewer) {
        _currentViewer.loadingStyle = loadingStyle;
    }
}

- (void)setPageLabelStyle:(ViewerPageLabelStyle)pageLabelStyle {
    _configuration[@"pageLabelStyle"] = @(pageLabelStyle);
    if (_currentViewer) {
        _currentViewer.pageLabelStyle = pageLabelStyle;
    }
}

- (void)setBouncesAnimated:(BOOL)bouncesAnimated {
    _configuration[@"bouncesAnimated"] = @(bouncesAnimated);
    if (_currentViewer) {
        _currentViewer.bouncesAnimated = bouncesAnimated;
    }
}

- (void)setPageSpacing:(CGFloat)pageSpacing {
    _configuration[@"pageSpacing"] = @(pageSpacing);
    if (_currentViewer) {
        _currentViewer.pageSpacing = pageSpacing;
    }
}

- (void)setAlwaysShowPageLabel:(BOOL)alwaysShowPageLabel {
    _configuration[@"alwaysShowPageLabel"] = @(alwaysShowPageLabel);
    if (_currentViewer) {
        _currentViewer.alwaysShowPageLabel = alwaysShowPageLabel;
    }
}

#pragma mark - Customization

- (void)setCloseButtonImage:(nullable UIImage *)image {
    if (_currentViewer) {
        [_currentViewer.closeButton setImage:image forState:UIControlStateNormal];
    }
}

- (void)setShareButtonImage:(nullable UIImage *)image {
    if (_currentViewer) {
        [_currentViewer.shareButton setImage:image forState:UIControlStateNormal];
    }
}

- (void)setCloseButtonHidden:(BOOL)hidden {
    if (_currentViewer) {
        _currentViewer.closeButton.hidden = hidden;
    }
}

- (void)setShareButtonHidden:(BOOL)hidden {
    if (_currentViewer) {
        _currentViewer.shareButton.hidden = hidden;
    }
}

#pragma mark - Gesture Handlers

- (void)handleSingleTap:(UITapGestureRecognizer *)gesture {
    if (self.enableSingleTapToDismiss) {
        [self dismissCurrentViewerAnimated:YES completion:nil];
    }
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gesture {
    // Double tap zoom is handled by ViewerController internally
    // This method is just for enabling/disabling the gesture
}

#pragma mark - ViewerControllerDelegate

- (void)viewerControllerDidDismiss:(ViewerController *)viewer {
    // Remove from array
    [_presentedViewers removeObject:viewer];
    
    if (_currentViewer == viewer) {
        _currentViewer = nil;
    }
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(imageViewerManagerDidDismiss:)]) {
        [self.delegate imageViewerManagerDidDismiss:self];
    }
}

- (void)viewerController:(ViewerController *)viewer
    didLongPressAtIndex:(NSInteger)index
              attribute:(ViewerAttribute *)attribute
                  image:(nullable UIImage *)image {
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(imageViewerManager:didLongPressAtIndex:image:sourceView:)]) {
        [self.delegate imageViewerManager:self
                    didLongPressAtIndex:index
                                  image:image
                             sourceView:attribute.sourceView];
    }
    
    // Show default action sheet if delegate didn't handle it
    if (![self.delegate respondsToSelector:@selector(imageViewerManager:didLongPressAtIndex:image:sourceView:)]) {
        [self showDefaultActionSheetForImage:image atIndex:index];
    }
}

#pragma mark - Default Action Sheet

- (void)showDefaultActionSheetForImage:(nullable UIImage *)image atIndex:(NSInteger)index {
    if (!image) return;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    if (self.shouldSaveToPhotosOnLongPress) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Save to Photos"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
        }]];
    }
    
    if (self.shouldShowShareOption) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Share"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            [self shareImage:image];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    // For iPad
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = _currentViewer.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(_currentViewer.view.bounds.size.width/2,
                                                                   _currentViewer.view.bounds.size.height/2,
                                                                   1, 1);
    }
    
    [_currentViewer presentViewController:alert animated:YES completion:nil];
}

- (void)shareImage:(UIImage *)image {
    if (!image) return;
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[image]
                                                                             applicationActivities:nil];
    
    // For iPad
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = _currentViewer.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(_currentViewer.view.bounds.size.width/2,
                                                                        _currentViewer.view.bounds.size.height/2,
                                                                        1, 1);
    }
    
    [_currentViewer presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - Save Image Callback

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if (error) {
        NSLog(@"Error saving image: %@", error.localizedDescription);
        [self showAlertWithTitle:@"Error" message:@"Failed to save image to Photos"];
    } else {
        NSLog(@"Image saved successfully");
        [self showAlertWithTitle:@"Success" message:@"Image saved to Photos"];
    }
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    
    [_currentViewer presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Cleanup

- (void)dealloc {
    [self clearImageCache];
    [_presentedViewers removeAllObjects];
}

@end
