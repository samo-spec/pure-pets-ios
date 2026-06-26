//
//  PetImageGalleryView 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//

#import <Vision/Vision.h>
#import <ImageIO/ImageIO.h>
#import <AVKit/AVKit.h>
#import <math.h>
#import "PetImageGalleryView.h"
#import "PPImageLoaderManager.h"
#import "FullScreenImageViewerController.h"
#import "PPAdSharingHelper.h"
#import "EnumValues.h"

typedef NS_ENUM(NSInteger, PPImageGallerySmartCropSource) {
    PPImageGallerySmartCropSourceNone = 0,
    PPImageGallerySmartCropSourceAnimal,
    PPImageGallerySmartCropSourceObject,
    PPImageGallerySmartCropSourceRectangle,
    PPImageGallerySmartCropSourceFace
};

static const CGFloat PPImageGalleryVerticalCropBiasYOffset = 0.35;
static NSInteger const PPImageGalleryVideoBadgeTag = 73041;

static CGFloat PPImageGalleryClamp(CGFloat value, CGFloat minValue, CGFloat maxValue)
{
    if (!isfinite(value)) return minValue;
    return MIN(MAX(value, minValue), maxValue);
}

static BOOL PPImageGalleryRectIsUsable(CGRect rect)
{
    return isfinite(rect.origin.x) &&
           isfinite(rect.origin.y) &&
           isfinite(rect.size.width) &&
           isfinite(rect.size.height) &&
           rect.size.width > 0.01 &&
           rect.size.height > 0.01;
}

static CGRect PPImageGalleryClampUnitRect(CGRect rect)
{
    if (!PPImageGalleryRectIsUsable(rect)) return CGRectZero;

    CGFloat width = PPImageGalleryClamp(rect.size.width, 0.0, 1.0);
    CGFloat height = PPImageGalleryClamp(rect.size.height, 0.0, 1.0);
    CGFloat x = PPImageGalleryClamp(rect.origin.x, 0.0, 1.0 - width);
    CGFloat y = PPImageGalleryClamp(rect.origin.y, 0.0, 1.0 - height);
    return CGRectMake(x, y, width, height);
}

static CGRect PPImageGalleryNormalizedRectFromVisionBox(CGRect boundingBox)
{
    // Vision boxes are normalized with the origin at bottom-left. CALayer
    // contentsRect uses normalized image space from the top-left, so flip Y.
    CGRect rect = CGRectMake(CGRectGetMinX(boundingBox),
                             1.0 - CGRectGetMaxY(boundingBox),
                             CGRectGetWidth(boundingBox),
                             CGRectGetHeight(boundingBox));
    return PPImageGalleryClampUnitRect(rect);
}

static CGImagePropertyOrientation PPImageGalleryCGImageOrientation(UIImageOrientation orientation)
{
    switch (orientation) {
        case UIImageOrientationUp: return kCGImagePropertyOrientationUp;
        case UIImageOrientationDown: return kCGImagePropertyOrientationDown;
        case UIImageOrientationLeft: return kCGImagePropertyOrientationLeft;
        case UIImageOrientationRight: return kCGImagePropertyOrientationRight;
        case UIImageOrientationUpMirrored: return kCGImagePropertyOrientationUpMirrored;
        case UIImageOrientationDownMirrored: return kCGImagePropertyOrientationDownMirrored;
        case UIImageOrientationLeftMirrored: return kCGImagePropertyOrientationLeftMirrored;
        case UIImageOrientationRightMirrored: return kCGImagePropertyOrientationRightMirrored;
    }
    return kCGImagePropertyOrientationUp;
}

@interface PetImageGalleryView ()<UICollectionViewDelegateFlowLayout,EllipsePageControlDelegate>
@property (nonatomic, strong) FullScreenImageViewerController *fullScreenViewer;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIButton *containerB;
@property (nonatomic, strong) UIVisualEffectView *pageControlMaterialView;
@property (nonatomic, strong) id currentModel;
@property (nonatomic,strong) EllipsePageControl *myPageControl1;

@property (nonatomic, strong) NSCache<NSString *, UIImage *> *imageCache;
@property (nonatomic, assign) BOOL pp_didPrepareGalleryEntranceAnimation;
@property (nonatomic, assign) BOOL pp_didRunGalleryEntranceAnimation;
@property (nonatomic, assign) BOOL pp_didNormalizeInitialLayout;
@property (nonatomic, assign) CGSize pp_lastLaidOutCollectionSize;
@property (nonatomic, assign) NSInteger pp_lastSettledPageIndex;
@property (nonatomic, strong) UIImpactFeedbackGenerator *pp_swipeFeedbackGenerator;

- (void)pp_resetImageViewForReuse:(UIImageView *)imageView placeholder:(UIImage *)placeholder itemURL:(NSString *)itemURL;
- (void)pp_applySmartVerticalBiasForImage:(UIImage *)image
                              onImageView:(UIImageView *)imageView
                                 inBounds:(CGRect)bounds;
- (void)pp_detectFaceAndApplyCropForImage:(UIImage *)image onImageView:(UIImageView *)imageView inBounds:(CGRect)bounds;
- (CGRect)pp_bestFocusRectFromAnimalRequest:(VNRecognizeAnimalsRequest *)animalRequest
                               faceRequest:(VNDetectFaceRectanglesRequest *)faceRequest
                          objectnessRequest:(VNGenerateObjectnessBasedSaliencyImageRequest *)objectnessRequest
                           rectangleRequest:(VNDetectRectanglesRequest *)rectangleRequest
                                     source:(PPImageGallerySmartCropSource *)source;
- (CGRect)pp_expandedFocusRect:(CGRect)focusRect source:(PPImageGallerySmartCropSource)source;
- (CGRect)pp_unionOfNormalizedBoxes:(NSArray<NSValue *> *)boxes;
- (CGRect)pp_contentsRectForImage:(UIImage *)image
                            bounds:(CGRect)bounds
                         focusRect:(CGRect)focusRect
                            source:(PPImageGallerySmartCropSource)source;
- (void)pp_runGalleryEntranceAnimationIfNeeded;
- (void)pp_prepareGalleryEntranceAnimationIfNeeded;
- (void)pp_applySwipeMotionToVisibleCells;
- (void)pp_resetMotionForCell:(UICollectionViewCell *)cell;
- (void)pp_emitSwipeFeedbackIfNeededForPage:(NSInteger)page;
- (void)pp_configureVideoBadgeInCell:(UICollectionViewCell *)cell visible:(BOOL)visible;
- (void)pp_updateGalleryAccessibilityForPage:(NSInteger)page;
- (void)pp_synchronizeCollectionLayoutIfNeeded;

@end

@implementation PetImageGalleryView

- (instancetype)initWithFrame:(CGRect)frame imageItems:(NSArray<PetImageItem *> *)items galleryType:(PetImageGalleryType)type itemHeight:(CGFloat)itemHeight parentVC:(UIViewController *)parentVC obj:(id)obj 
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _imageCache = [[NSCache alloc] init];
    // Core state
    _currentPagr = 0;
    _currentModel = obj;
    _parentViewController = parentVC;
    _galleryType = type;
    _contentMode = UIViewContentModeScaleAspectFill;
    _itemHeight = itemHeight;
    _pp_lastSettledPageIndex = NSNotFound;

    // 🔑 SINGLE SOURCE OF TRUTH
    _imageItems = items ?: @[];

    // Layout helpers
    _imageSizes = [NSMutableDictionary dictionary];

    // UI
    self.backgroundColor = UIColor.clearColor;
    [self setupCollectionView];

    return self;
}


- (void)setupCollectionView {
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    //layout.itemSize = CGSizeMake(self.frame.size.width, 300);
    layout.minimumLineSpacing = 0;

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.pagingEnabled = YES;
    _collectionView.decelerationRate = UIScrollViewDecelerationRateFast;
    _collectionView.contentInset = UIEdgeInsetsZero;
    _collectionView.scrollIndicatorInsets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        _collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    _collectionView.showsHorizontalScrollIndicator = NO;
    _collectionView.backgroundColor = _galleryType == PetImageGalleryTypeAccessory
        ? (AppForgroundColr ?: UIColor.secondarySystemBackgroundColor)
        : AppBackgroundClr;
    _collectionView.layer.cornerRadius = 0;
    _collectionView.clipsToBounds = YES;
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    //_collectionView.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner ;
    [_collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"ImageCell"];

    UIView *emptyView = [[UIView alloc] init];
    emptyView.backgroundColor = UIColor.clearColor;
    UIImageView *emptyIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"photo.on.rectangle.angled"]];
    emptyIcon.translatesAutoresizingMaskIntoConstraints = NO;
    emptyIcon.contentMode = UIViewContentModeScaleAspectFit;
    emptyIcon.tintColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.62];
    emptyIcon.isAccessibilityElement = NO;
    UILabel *emptyLabel = [[UILabel alloc] init];
    emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    emptyLabel.font = [GM MidFontWithSize:14.0];
    emptyLabel.textColor = UIColor.secondaryLabelColor;
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    emptyLabel.text = kLang(@"image_gallery_empty");
    emptyLabel.adjustsFontForContentSizeCategory = YES;
    emptyLabel.numberOfLines = 0;
    [emptyView addSubview:emptyIcon];
    [emptyView addSubview:emptyLabel];
    [NSLayoutConstraint activateConstraints:@[
        [emptyIcon.centerXAnchor constraintEqualToAnchor:emptyView.centerXAnchor],
        [emptyIcon.centerYAnchor constraintEqualToAnchor:emptyView.centerYAnchor constant:-14.0],
        [emptyIcon.widthAnchor constraintEqualToConstant:32.0],
        [emptyIcon.heightAnchor constraintEqualToConstant:32.0],
        [emptyLabel.topAnchor constraintEqualToAnchor:emptyIcon.bottomAnchor constant:10.0],
        [emptyLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:emptyView.leadingAnchor constant:24.0],
        [emptyLabel.trailingAnchor constraintLessThanOrEqualToAnchor:emptyView.trailingAnchor constant:-24.0],
        [emptyLabel.centerXAnchor constraintEqualToAnchor:emptyView.centerXAnchor]
    ]];
    emptyView.isAccessibilityElement = YES;
    emptyView.accessibilityLabel = emptyLabel.text;
    _collectionView.backgroundView = emptyView;
    _collectionView.backgroundView.hidden = _imageItems.count > 0;
    [self addSubview:_collectionView];
   
    
    // Set up imageGallery constraints
    self.collectionView .translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView .topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.collectionView .leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.collectionView .trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.collectionView .heightAnchor constraintEqualToAnchor:self.heightAnchor]
    ]];
    
    if (_imageItems.count > 1 && !self.hidesPageControl) {
        [self setupUI];
    }
    [self pp_prepareGalleryEntranceAnimationIfNeeded];
}

// layoutSubviews no longer manages myPageControl1 constraints

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setNeedsLayout];
            [self layoutIfNeeded];
            [self pp_synchronizeCollectionLayoutIfNeeded];
            [self pp_runGalleryEntranceAnimationIfNeeded];
            [self pp_applySwipeMotionToVisibleCells];
        });
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self pp_synchronizeCollectionLayoutIfNeeded];
    if (!self.hidesPageControl) {
        self.myPageControl1.frame = self.containerB.bounds;
    }
    [self pp_applySwipeMotionToVisibleCells];
}

- (void)pp_synchronizeCollectionLayoutIfNeeded
{
    CGSize pageSize = self.collectionView.bounds.size;
    if (pageSize.width <= 0.0 || pageSize.height <= 0.0) {
        return;
    }

    BOOL sizeChanged = !CGSizeEqualToSize(pageSize, self.pp_lastLaidOutCollectionSize);
    if (self.pp_didNormalizeInitialLayout && !sizeChanged) {
        return;
    }

    NSInteger targetIndex = 0;
    if (self.pp_didNormalizeInitialLayout && self.imageItems.count > 0) {
        CGPoint visibleCenter = CGPointMake(self.collectionView.contentOffset.x + CGRectGetMidX(self.collectionView.bounds),
                                            self.collectionView.contentOffset.y + CGRectGetMidY(self.collectionView.bounds));
        NSIndexPath *visibleIndexPath = [self.collectionView indexPathForItemAtPoint:visibleCenter];
        if (visibleIndexPath) {
            targetIndex = visibleIndexPath.item;
        }
    }

    UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    flowLayout.itemSize = pageSize;
    flowLayout.minimumLineSpacing = 0.0;
    flowLayout.minimumInteritemSpacing = 0.0;
    [flowLayout invalidateLayout];
    [self.collectionView layoutIfNeeded];

    if (self.imageItems.count > 0) {
        targetIndex = MIN(MAX(targetIndex, 0), (NSInteger)self.imageItems.count - 1);
        NSIndexPath *targetPath = [NSIndexPath indexPathForItem:targetIndex inSection:0];
        [UIView performWithoutAnimation:^{
            [self.collectionView scrollToItemAtIndexPath:targetPath
                                        atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                                animated:NO];
        }];
    } else {
        self.collectionView.contentOffset = CGPointZero;
    }

    self.pp_lastLaidOutCollectionSize = pageSize;
    self.pp_didNormalizeInitialLayout = YES;
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
    if (_contentMode == contentMode) {
        return;
    }
    _contentMode = contentMode;
    [self.collectionView reloadData];
}


- (NSInteger)pageIndexForItemIndex:(NSInteger)itemIndex {
    UISemanticContentAttribute semantic = self.hidesPageControl
        ? Language.semanticAttributeForCurrentLanguage
        : _myPageControl1.semanticContentAttribute;
    UIUserInterfaceLayoutDirection dir = [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:semantic];
    if (dir == UIUserInterfaceLayoutDirectionRightToLeft) {
        return self.imageItems.count - 1 - itemIndex;
    }
    return itemIndex;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGSize pageSize = collectionView.bounds.size;
    if (pageSize.width <= 0.0 || pageSize.height <= 0.0) {
        pageSize = self.bounds.size;
    }
    if (pageSize.width <= 0.0 || pageSize.height <= 0.0) {
        pageSize = CGSizeMake(MAX(UIScreen.mainScreen.bounds.size.width, 1.0),
                              MAX(self.itemHeight, 1.0));
    }
    return pageSize;
}
 
- (void)setupUI {
    if (self.containerB) {
        self.containerB.hidden = self.imageItems.count <= 1;
        self.myPageControl1.numberOfPages = self.imageItems.count;
        return;
    }
    
    self.containerB = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed configType:PPButtonConfigrationFilled];
    self.containerB.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.containerB];
    
   
    BOOL accessoryStyle = _galleryType == PetImageGalleryTypeAccessory;
    if(PPIOS26())
    {
        UIButtonConfiguration *config = self.containerB.configuration;
        config.background.cornerRadius = 14;
        config.background.backgroundColor = accessoryStyle ? UIColor.clearColor : [AppForgroundColr colorWithAlphaComponent:0.2];
        config.baseBackgroundColor = accessoryStyle ? UIColor.clearColor : [AppForgroundColr colorWithAlphaComponent:0.2];
        config.background.strokeWidth = 0.0;
        config.background.strokeColor = UIColor.clearColor;
        self.containerB.configuration = config;
    }
    else
    {
        self.containerB.layer.cornerRadius = 14;
        self.containerB.backgroundColor = accessoryStyle ? UIColor.clearColor : [AppForgroundColr colorWithAlphaComponent:0.2];
        self.containerB.clipsToBounds = YES;

    }
    if (accessoryStyle) {
        self.pageControlMaterialView = [[UIVisualEffectView alloc]
                                        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
        self.pageControlMaterialView.translatesAutoresizingMaskIntoConstraints = NO;
        self.pageControlMaterialView.userInteractionEnabled = NO;
        self.pageControlMaterialView.layer.cornerRadius = 14.0;
        self.pageControlMaterialView.layer.masksToBounds = YES;
        if (@available(iOS 13.0, *)) {
            self.pageControlMaterialView.layer.cornerCurve = kCACornerCurveContinuous;
        }
        [self.containerB addSubview:self.pageControlMaterialView];
        [NSLayoutConstraint activateConstraints:@[
            [self.pageControlMaterialView.topAnchor constraintEqualToAnchor:self.containerB.topAnchor],
            [self.pageControlMaterialView.leadingAnchor constraintEqualToAnchor:self.containerB.leadingAnchor],
            [self.pageControlMaterialView.trailingAnchor constraintEqualToAnchor:self.containerB.trailingAnchor],
            [self.pageControlMaterialView.bottomAnchor constraintEqualToAnchor:self.containerB.bottomAnchor]
        ]];
        self.containerB.layer.shadowColor = UIColor.blackColor.CGColor;
        self.containerB.layer.shadowOpacity = 0.10;
        self.containerB.layer.shadowRadius = 12.0;
        self.containerB.layer.shadowOffset = CGSizeMake(0.0, 5.0);
        self.containerB.layer.masksToBounds = NO;
    }
 
    
    self.myPageControl1 = [[EllipsePageControl alloc] initWithFrame:CGRectMake(0, 0, 90, 30)];
   // self.myPageControl1.backgroundColor = UIColor.redColor;
    self.myPageControl1.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.myPageControl1.controlSize = accessoryStyle ? 5 : 6;
    self.myPageControl1.controlSpacing = accessoryStyle ? 7 : 8;
    self.myPageControl1.otherColor = [UIColor.labelColor colorWithAlphaComponent:0.22];
    self.myPageControl1.currentColor = accessoryStyle ? UIColor.labelColor : AppPrimaryClr;
    self.myPageControl1.isAccessibilityElement = YES;
    self.myPageControl1.accessibilityTraits = UIAccessibilityTraitStaticText;
    //self.myPageControl1.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerB addSubview:_myPageControl1];
    [self.containerB bringSubviewToFront:_myPageControl1];
    // Center myPageControl1 inside containerB and size to containerB
    /*
     [NSLayoutConstraint activateConstraints:@[
         [self.myPageControl1.centerXAnchor constraintEqualToAnchor:self.containerB.centerXAnchor],
         [self.myPageControl1.centerYAnchor constraintEqualToAnchor:self.containerB.centerYAnchor],
         [self.myPageControl1.widthAnchor constraintEqualToAnchor:self.containerB.widthAnchor],
         [self.myPageControl1.heightAnchor constraintEqualToAnchor:self.containerB.heightAnchor]
     ]];
     */
    NSLayoutConstraint *bottomBtn;
    if(_galleryType == PetImageGalleryTypeCardsViewer)
    {
        bottomBtn =  [self.containerB .bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12];
    }else if(_galleryType == PetImageGalleryTypePetAd)
    {
        bottomBtn =  [self.containerB .topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:5];
        //bottomBtn =  [self.containerB .bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-80];
    }
    else
    {
        bottomBtn =  [self.containerB .bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-20];
    }
    
    CGFloat indicatorWidth = MIN(132.0, MAX(58.0, 24.0 + (self.imageItems.count * 12.0)));
    [NSLayoutConstraint activateConstraints:@[
        bottomBtn,
        [self.containerB .centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.containerB .widthAnchor constraintEqualToConstant:indicatorWidth],
        [self.containerB .heightAnchor constraintEqualToConstant:30]
    ]];
    
    
    self.myPageControl1.numberOfPages = self.imageItems.count;
    self.myPageControl1.delegate=self;
    
    [self layoutSubviews];
    self.myPageControl1.frame = CGRectMake(0, 0, indicatorWidth, 30);
    
    self.containerB.layer.cornerRadius = 14.0;
    if (@available(iOS 13.0, *)) {
        self.containerB.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self pp_updateGalleryAccessibilityForPage:0];
    /*
     LCScaleColorPageStyle,
     LCSquirmPageStyle,
     LCDepthColorPageStyle,
     LCFillColorPageStyle,
     */}

#pragma  mark EllipsePageControlDelegat
#pragma mark - EllipsePageControlDelegate
- (void)ellipsePageControlClick:(EllipsePageControl *)pageControl index:(NSInteger)clickIndex {
    if (self.hidesPageControl) return;

    UIUserInterfaceLayoutDirection dir =
    [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:_myPageControl1.semanticContentAttribute];

    NSInteger targetIndex = clickIndex;
    if (dir == UIUserInterfaceLayoutDirectionRightToLeft) {
        targetIndex = self.imageItems.count - 1 - clickIndex;
    }

    if (targetIndex < 0 || targetIndex >= self.imageItems.count) {
        return;
    }

    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:targetIndex inSection:0];
    [_collectionView scrollToItemAtIndexPath:indexPath
                            atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                    animated:YES];
    [self pp_updateGalleryAccessibilityForPage:targetIndex];
}

- (void)pp_updateGalleryAccessibilityForPage:(NSInteger)page
{
    if (self.hidesPageControl) return;
    NSInteger count = self.imageItems.count;
    if (count <= 0) {
        self.myPageControl1.accessibilityValue = nil;
        return;
    }
    NSInteger safePage = MIN(MAX(page, 0), count - 1);
    self.myPageControl1.accessibilityLabel = kLang(@"image_gallery_accessibility_label");
    self.myPageControl1.accessibilityValue = [NSString stringWithFormat:kLang(@"image_gallery_page_format"),
                                                   (long)(safePage + 1),
                                                   (long)count];
    self.myPageControl1.accessibilityHint = kLang(@"image_gallery_swipe_hint");
}

- (void)setImageItems:(NSArray<PetImageItem *> *)imageItems {
    _imageItems = imageItems ?: @[];
    [self.imageCache removeAllObjects];
    self.pp_didPrepareGalleryEntranceAnimation = NO;
    self.pp_didRunGalleryEntranceAnimation = NO;
    self.pp_didNormalizeInitialLayout = NO;
    self.pp_lastLaidOutCollectionSize = CGSizeZero;
    self.pp_lastSettledPageIndex = NSNotFound;
    if (_imageItems.count > 1 && !self.containerB && !self.hidesPageControl) {
        [self setupUI];
    }
    self.containerB.hidden = _imageItems.count <= 1 || self.hidesPageControl;
    self.collectionView.backgroundView.hidden = _imageItems.count > 0;
    if (!self.hidesPageControl) {
        _myPageControl1.numberOfPages = (int)_imageItems.count;
    }
    [self pp_updateGalleryAccessibilityForPage:0];
    [self pp_prepareGalleryEntranceAnimationIfNeeded];
    [self.collectionView reloadData];
    [self setNeedsLayout];
    [self pp_runGalleryEntranceAnimationIfNeeded];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.imageItems.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                          cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:@"ImageCell"
                                                  forIndexPath:indexPath];
    [self pp_resetMotionForCell:cell];
    cell.isAccessibilityElement = YES;
    cell.accessibilityTraits = UIAccessibilityTraitImage | UIAccessibilityTraitButton;
    cell.accessibilityLabel = [NSString stringWithFormat:kLang(@"image_gallery_page_format"),
                               (long)(indexPath.item + 1),
                               (long)self.imageItems.count];
    cell.accessibilityHint = kLang(@"image_gallery_open_hint");

    UIImageView *imageView = [cell.contentView viewWithTag:100];

    if (!imageView) {
        imageView = [[UIImageView alloc] init];
        imageView.tag = 100; // FIXED TAG — DO NOT CHANGE LATER
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        imageView.clipsToBounds = YES;
        imageView.contentMode = self.contentMode;
        imageView.layer.contentsGravity = self.contentMode == UIViewContentModeScaleAspectFit
            ? kCAGravityResizeAspect
            : kCAGravityResizeAspectFill;
        imageView.layer.contentsRect = CGRectMake(0.0, 0.0, 1.0, 1.0);

        [cell.contentView addSubview:imageView];

        [NSLayoutConstraint activateConstraints:@[
            [imageView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
            [imageView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor],
            [imageView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
            [imageView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
        ]];
    }

 
    PetImageItem *item = self.imageItems[indexPath.item];
    NSString *itemURL = item.url ?: @"";
    [self pp_configureVideoBadgeInCell:cell visible:(PPReusableVideoMediaEnabled() && item.isVideoMedia)];

    // BlurHash placeholder (if available)
    UIImage *placeholder = nil;
    if (item.blurHash.length > 0) {
        placeholder =
        [PPBlurHashBridge imageFrom:item.blurHash syncSize:CGSizeMake(40, 40) punch:1.0];

    }
    placeholder = placeholder ?: [UIImage imageNamed:@"placeholder"];
    [self pp_resetImageViewForReuse:imageView placeholder:placeholder itemURL:itemURL];

    UIImage *cachedImage = itemURL.length > 0 ? [self.imageCache objectForKey:itemURL] : nil;
    if (cachedImage) {
        imageView.image = cachedImage;
        [self pp_applySmartVerticalBiasForImage:cachedImage
                                    onImageView:imageView
                                       inBounds:imageView.bounds];
        [self pp_detectFaceAndApplyCropForImage:cachedImage
                                    onImageView:imageView
                                       inBounds:imageView.bounds];
        return cell;
    }


    [[PPImageLoaderManager shared]
     fetchImageWithURL:item.url
            completion:^(UIImage * _Nullable image) {

        if (!image) return;
        if (![imageView.accessibilityIdentifier isEqualToString:itemURL]) return;

        if (itemURL.length > 0) {
            [self.imageCache setObject:image forKey:itemURL];
        }

        imageView.image = image;
        imageView.layer.contentsScale = image.scale;
        [self pp_applySmartVerticalBiasForImage:image
                                    onImageView:imageView
                                       inBounds:imageView.bounds];
        [self pp_detectFaceAndApplyCropForImage:image
                                    onImageView:imageView
                                       inBounds:imageView.bounds];

    }];

    // Visual reset (keep exactly as before)
    imageView.layer.cornerRadius = 0;
    imageView.layer.cornerCurve = kCACornerCurveContinuous;
    imageView.layer.borderWidth = 0;
    imageView.backgroundColor = UIColor.clearColor;
    
    
    return cell;
}

- (void)pp_configureVideoBadgeInCell:(UICollectionViewCell *)cell visible:(BOOL)visible
{
    UIView *existing = [cell.contentView viewWithTag:PPImageGalleryVideoBadgeTag];
    if (!visible) {
        [existing removeFromSuperview];
        return;
    }
    if (existing) {
        existing.hidden = NO;
        return;
    }

    UIImageView *badge = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"play.circle.fill"]];
    badge.tag = PPImageGalleryVideoBadgeTag;
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.tintColor = UIColor.whiteColor;
    badge.contentMode = UIViewContentModeScaleAspectFit;
    badge.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.20];
    badge.layer.cornerRadius = 24.0;
    badge.clipsToBounds = YES;
    badge.userInteractionEnabled = NO;
    [cell.contentView addSubview:badge];
    [NSLayoutConstraint activateConstraints:@[
        [badge.centerXAnchor constraintEqualToAnchor:cell.contentView.centerXAnchor],
        [badge.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [badge.widthAnchor constraintEqualToConstant:48.0],
        [badge.heightAnchor constraintEqualToConstant:48.0]
    ]];
}


#pragma mark - Animal-friendly Smart Crop

- (void)pp_resetImageViewForReuse:(UIImageView *)imageView placeholder:(UIImage *)placeholder itemURL:(NSString *)itemURL
{
    imageView.accessibilityIdentifier = itemURL ?: @"";
    imageView.image = placeholder;
    BOOL fitsEntireProduct = self.contentMode == UIViewContentModeScaleAspectFit;
    imageView.contentMode = fitsEntireProduct ? UIViewContentModeScaleAspectFit : UIViewContentModeScaleAspectFill;
    imageView.layer.contentsGravity = fitsEntireProduct ? kCAGravityResizeAspect : kCAGravityResizeAspectFill;
    imageView.layer.contentsRect = CGRectMake(0.0, 0.0, 1.0, 1.0);
    imageView.layer.contentsScale = UIScreen.mainScreen.scale;
    imageView.layer.masksToBounds = YES;
    imageView.layer.cornerRadius = 0;
    imageView.layer.cornerCurve = kCACornerCurveContinuous;
    imageView.layer.borderWidth = 0;
    imageView.backgroundColor = UIColor.clearColor;
}

- (void)pp_applySmartVerticalBiasForImage:(UIImage *)image
                              onImageView:(UIImageView *)imageView
                                 inBounds:(CGRect)bounds
{
    if (!image || !imageView) return;
    if (self.contentMode == UIViewContentModeScaleAspectFit) {
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.layer.contentsGravity = kCAGravityResizeAspect;
        imageView.layer.contentsRect = CGRectMake(0.0, 0.0, 1.0, 1.0);
        return;
    }

    CGRect targetBounds = CGRectIsEmpty(bounds) ? imageView.bounds : bounds;
    if (CGRectIsEmpty(targetBounds)) {
        targetBounds = self.collectionView.bounds;
    }

    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    imageView.layer.masksToBounds = YES;
    imageView.layer.contentsGravity = kCAGravityResizeAspectFill;
    imageView.layer.contentsRect = [self pp_contentsRectForImage:image
                                                          bounds:targetBounds
                                                       focusRect:CGRectZero
                                                          source:PPImageGallerySmartCropSourceNone];
}

- (void)pp_detectFaceAndApplyCropForImage:(UIImage *)image
                              onImageView:(UIImageView *)imageView
                                 inBounds:(CGRect)bounds
{
    if (!image || !imageView) return;
    if (self.contentMode == UIViewContentModeScaleAspectFit) return;

    CGRect targetBounds = CGRectIsEmpty(bounds) ? imageView.bounds : bounds;
    if (CGRectIsEmpty(targetBounds)) {
        targetBounds = self.collectionView.bounds;
    }
    if (CGRectGetWidth(targetBounds) <= 0.0 || CGRectGetHeight(targetBounds) <= 0.0) {
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.layer.contentsGravity = kCAGravityResizeAspectFill;
        imageView.layer.contentsRect = CGRectMake(0.0, 0.0, 1.0, 1.0);
        return;
    }

    CGImageRef cgImage = image.CGImage;
    if (!cgImage) {
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.layer.contentsGravity = kCAGravityResizeAspectFill;
        imageView.layer.contentsRect = CGRectMake(0.0, 0.0, 1.0, 1.0);
        return;
    }

    VNRecognizeAnimalsRequest *animalRequest = [[VNRecognizeAnimalsRequest alloc] init];
    VNDetectFaceRectanglesRequest *faceRequest = [[VNDetectFaceRectanglesRequest alloc] init];
    VNGenerateObjectnessBasedSaliencyImageRequest *objectnessRequest = [[VNGenerateObjectnessBasedSaliencyImageRequest alloc] init];
    VNDetectRectanglesRequest *rectangleRequest = [[VNDetectRectanglesRequest alloc] init];
    rectangleRequest.maximumObservations = 8;
    rectangleRequest.minimumConfidence = 0.34;
    rectangleRequest.minimumSize = 0.12;

    CGImagePropertyOrientation orientation = PPImageGalleryCGImageOrientation(image.imageOrientation);
    VNImageRequestHandler *handler =
    [[VNImageRequestHandler alloc] initWithCGImage:cgImage
                                      orientation:orientation
                                          options:@{}];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<VNRequest *> *requests = @[animalRequest, objectnessRequest, rectangleRequest, faceRequest];
        [handler performRequests:requests error:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (imageView.image != image) return;

            PPImageGallerySmartCropSource source = PPImageGallerySmartCropSourceNone;
            CGRect focusRect = [self pp_bestFocusRectFromAnimalRequest:animalRequest
                                                           faceRequest:faceRequest
                                                      objectnessRequest:objectnessRequest
                                                       rectangleRequest:rectangleRequest
                                                                 source:&source];
            CGRect contentsRect = [self pp_contentsRectForImage:image
                                                         bounds:targetBounds
                                                      focusRect:focusRect
                                                         source:source];

            imageView.contentMode = UIViewContentModeScaleAspectFill;
            imageView.layer.contentsGravity = kCAGravityResizeAspectFill;
            imageView.layer.contentsRect = contentsRect;
        });
    });
}

- (CGRect)pp_bestFocusRectFromAnimalRequest:(VNRecognizeAnimalsRequest *)animalRequest
                                faceRequest:(VNDetectFaceRectanglesRequest *)faceRequest
                           objectnessRequest:(VNGenerateObjectnessBasedSaliencyImageRequest *)objectnessRequest
                            rectangleRequest:(VNDetectRectanglesRequest *)rectangleRequest
                                      source:(PPImageGallerySmartCropSource *)source
{
    NSMutableArray<NSValue *> *boxes = [NSMutableArray array];

    for (VNRecognizedObjectObservation *observation in animalRequest.results ?: @[]) {
        if (![observation isKindOfClass:VNRecognizedObjectObservation.class]) continue;
        if (observation.confidence < 0.22) continue;
        CGRect rect = PPImageGalleryNormalizedRectFromVisionBox(observation.boundingBox);
        if (PPImageGalleryRectIsUsable(rect)) {
            [boxes addObject:[NSValue valueWithCGRect:rect]];
        }
    }
    if (boxes.count > 0) {
        if (source) *source = PPImageGallerySmartCropSourceAnimal;
        return [self pp_expandedFocusRect:[self pp_unionOfNormalizedBoxes:boxes]
                                   source:PPImageGallerySmartCropSourceAnimal];
    }

    VNSaliencyImageObservation *saliency = nil;
    VNObservation *firstSaliencyObservation = objectnessRequest.results.firstObject;
    if ([firstSaliencyObservation isKindOfClass:VNSaliencyImageObservation.class]) {
        saliency = (VNSaliencyImageObservation *)firstSaliencyObservation;
    }
    [boxes removeAllObjects];
    for (VNRectangleObservation *observation in saliency.salientObjects ?: @[]) {
        if (![observation isKindOfClass:VNRectangleObservation.class]) continue;
        if (observation.confidence < 0.18) continue;
        CGRect rect = PPImageGalleryNormalizedRectFromVisionBox(observation.boundingBox);
        if (PPImageGalleryRectIsUsable(rect)) {
            [boxes addObject:[NSValue valueWithCGRect:rect]];
        }
    }
    if (boxes.count > 0) {
        if (source) *source = PPImageGallerySmartCropSourceObject;
        return [self pp_expandedFocusRect:[self pp_unionOfNormalizedBoxes:boxes]
                                   source:PPImageGallerySmartCropSourceObject];
    }

    [boxes removeAllObjects];
    for (VNRectangleObservation *observation in rectangleRequest.results ?: @[]) {
        if (![observation isKindOfClass:VNRectangleObservation.class]) continue;
        CGRect rect = PPImageGalleryNormalizedRectFromVisionBox(observation.boundingBox);
        if (PPImageGalleryRectIsUsable(rect)) {
            [boxes addObject:[NSValue valueWithCGRect:rect]];
        }
    }
    if (boxes.count > 0) {
        if (source) *source = PPImageGallerySmartCropSourceRectangle;
        return [self pp_expandedFocusRect:[self pp_unionOfNormalizedBoxes:boxes]
                                   source:PPImageGallerySmartCropSourceRectangle];
    }

    [boxes removeAllObjects];
    for (VNFaceObservation *observation in faceRequest.results ?: @[]) {
        if (![observation isKindOfClass:VNFaceObservation.class]) continue;
        CGRect rect = PPImageGalleryNormalizedRectFromVisionBox(observation.boundingBox);
        if (PPImageGalleryRectIsUsable(rect)) {
            [boxes addObject:[NSValue valueWithCGRect:rect]];
        }
    }
    if (boxes.count > 0) {
        if (source) *source = PPImageGallerySmartCropSourceFace;
        return [self pp_expandedFocusRect:[self pp_unionOfNormalizedBoxes:boxes]
                                   source:PPImageGallerySmartCropSourceFace];
    }

    if (source) *source = PPImageGallerySmartCropSourceNone;
    return CGRectZero;
}

- (CGRect)pp_unionOfNormalizedBoxes:(NSArray<NSValue *> *)boxes
{
    CGRect unionRect = CGRectNull;
    for (NSValue *value in boxes) {
        CGRect rect = PPImageGalleryClampUnitRect(value.CGRectValue);
        if (!PPImageGalleryRectIsUsable(rect)) continue;
        unionRect = CGRectIsNull(unionRect) ? rect : CGRectUnion(unionRect, rect);
    }
    if (CGRectIsNull(unionRect)) return CGRectZero;
    return PPImageGalleryClampUnitRect(unionRect);
}

- (CGRect)pp_expandedFocusRect:(CGRect)focusRect source:(PPImageGallerySmartCropSource)source
{
    if (!PPImageGalleryRectIsUsable(focusRect)) return CGRectZero;

    CGFloat horizontalPadding = CGRectGetWidth(focusRect) * 0.36;
    CGFloat topPadding = CGRectGetHeight(focusRect) * 0.34;
    CGFloat bottomPadding = CGRectGetHeight(focusRect) * 0.40;

    if (source == PPImageGallerySmartCropSourceFace) {
        // A face box is only a head hint. For pets and humans, expand much
        // farther below the head so the crop keeps shoulders/body instead of
        // creating the old over-zoomed face-only thumbnail.
        horizontalPadding = CGRectGetWidth(focusRect) * 0.95;
        topPadding = CGRectGetHeight(focusRect) * 0.75;
        bottomPadding = CGRectGetHeight(focusRect) * 1.70;
    }

    CGRect padded = CGRectMake(CGRectGetMinX(focusRect) - horizontalPadding,
                               CGRectGetMinY(focusRect) - topPadding,
                               CGRectGetWidth(focusRect) + (horizontalPadding * 2.0),
                               CGRectGetHeight(focusRect) + topPadding + bottomPadding);
    return PPImageGalleryClampUnitRect(padded);
}

- (CGRect)pp_contentsRectForImage:(UIImage *)image
                            bounds:(CGRect)bounds
                         focusRect:(CGRect)focusRect
                            source:(PPImageGallerySmartCropSource)source
{
    if (!image || image.size.width <= 0.0 || image.size.height <= 0.0 ||
        bounds.size.width <= 0.0 || bounds.size.height <= 0.0) {
        return CGRectMake(0.0, 0.0, 1.0, 1.0);
    }

    BOOL hasFocus = PPImageGalleryRectIsUsable(focusRect);
    CGFloat imageAspect = image.size.width / image.size.height;
    CGFloat viewAspect = bounds.size.width / bounds.size.height;
    CGFloat cropWidth = 1.0;
    CGFloat cropHeight = 1.0;

    // Crop math:
    // contentsRect is normalized image space. To avoid stretch, the selected
    // crop must match the UIImageView aspect ratio in real pixels:
    // (cropW * imageW) / (cropH * imageH) == viewW / viewH.
    // When the source photo is wider than the viewer we crop width; when it is
    // taller we crop height. The preview always remains aspectFill; focus
    // detection only moves this crop, it never falls back to letterboxing.
    if (imageAspect > viewAspect) {
        cropWidth = viewAspect / imageAspect;
    } else {
        cropHeight = imageAspect / viewAspect;
    }
    cropWidth = PPImageGalleryClamp(cropWidth, 0.0, 1.0);
    cropHeight = PPImageGalleryClamp(cropHeight, 0.0, 1.0);

    CGFloat centerX = hasFocus ? CGRectGetMidX(focusRect) : 0.5;
    CGFloat centerY = hasFocus ? CGRectGetMidY(focusRect) : 0.5;
    CGFloat originX = centerX - (cropWidth * 0.5);
    CGFloat originY = centerY - (cropHeight * 0.5);

    if (hasFocus) {
        CGFloat upwardBias = (source == PPImageGallerySmartCropSourceAnimal) ? 0.055 : 0.035;
        if (source == PPImageGallerySmartCropSourceFace) upwardBias = -0.03;
        originY -= cropHeight * upwardBias;
    } else {
        originY = (1.0 - cropHeight) * PPImageGalleryVerticalCropBiasYOffset;
    }

    if (cropHeight < 1.0) {
        CGFloat upwardBiasedOriginY = (1.0 - cropHeight) * PPImageGalleryVerticalCropBiasYOffset;
        originY = hasFocus ? MIN(originY, upwardBiasedOriginY) : upwardBiasedOriginY;
    }

    originX = PPImageGalleryClamp(originX, 0.0, 1.0 - cropWidth);
    originY = PPImageGalleryClamp(originY, 0.0, 1.0 - cropHeight);
    return PPImageGalleryClampUnitRect(CGRectMake(originX, originY, cropWidth, cropHeight));
}

- (void)pp_prepareGalleryEntranceAnimationIfNeeded
{
    if (self.pp_didPrepareGalleryEntranceAnimation || self.pp_didRunGalleryEntranceAnimation) return;
    self.pp_didPrepareGalleryEntranceAnimation = YES;
    if (UIAccessibilityIsReduceMotionEnabled() || self.imageItems.count == 0) {
        self.collectionView.alpha = 1.0;
        self.collectionView.transform = CGAffineTransformIdentity;
        if (!self.hidesPageControl) {
            self.containerB.alpha = 1.0;
            self.containerB.transform = CGAffineTransformIdentity;
        }
        return;
    }
    self.collectionView.alpha = 0.0;
    self.collectionView.transform =
    CGAffineTransformMakeScale(1.025, 1.025);
    if (!self.hidesPageControl) {
        self.containerB.alpha = 0.0;
        self.containerB.transform =
        CGAffineTransformScale(CGAffineTransformMakeTranslation(0.0, 6.0), 0.94, 0.94);
    }
}

- (void)pp_runGalleryEntranceAnimationIfNeeded
{
    if (self.pp_didRunGalleryEntranceAnimation || !self.window || self.imageItems.count == 0) return;
    [self pp_prepareGalleryEntranceAnimationIfNeeded];
    self.pp_didRunGalleryEntranceAnimation = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.collectionView.alpha = 1.0;
        self.collectionView.transform = CGAffineTransformIdentity;
        if (!self.hidesPageControl) {
            self.containerB.alpha = 1.0;
            self.containerB.transform = CGAffineTransformIdentity;
        }
        return;
    }

    [UIView animateWithDuration:0.48
                          delay:0.0
         usingSpringWithDamping:0.92
           initialSpringVelocity:0.16
                         options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                      animations:^{
        self.collectionView.alpha = 1.0;
        self.collectionView.transform = CGAffineTransformIdentity;
    } completion:nil];

    if (!self.hidesPageControl) {
        [UIView animateWithDuration:0.30
                              delay:0.12
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.containerB.alpha = 1.0;
            self.containerB.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)pp_applySwipeMotionToVisibleCells
{
    if (!self.collectionView || CGRectIsEmpty(self.collectionView.bounds)) return;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
            [self pp_resetMotionForCell:cell];
        }
        return;
    }

    CGFloat viewportWidth = MAX(1.0, CGRectGetWidth(self.collectionView.bounds));
    CGFloat visibleCenterX = self.collectionView.contentOffset.x + (viewportWidth * 0.5);

    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        CGFloat distance = cell.center.x - visibleCenterX;
        CGFloat progress = PPImageGalleryClamp(fabs(distance) / viewportWidth, 0.0, 1.0);
        CGFloat scale = 1.0 - (progress * 0.035);
        CGFloat alpha = 1.0 - (progress * 0.16);
        CGFloat translateX = -distance * 0.018;

        CGAffineTransform transform =
        CGAffineTransformScale(CGAffineTransformMakeTranslation(translateX, 0.0), scale, scale);

        cell.contentView.alpha = alpha;
        cell.contentView.transform = transform;
        cell.layer.zPosition = 1000.0 - progress;
    }
}

- (void)pp_resetMotionForCell:(UICollectionViewCell *)cell
{
    cell.contentView.alpha = 1.0;
    cell.contentView.transform = CGAffineTransformIdentity;
    cell.layer.zPosition = 0.0;
}

- (void)pp_emitSwipeFeedbackIfNeededForPage:(NSInteger)page
{
    if (page < 0 || page >= (NSInteger)self.imageItems.count) return;
    if (self.pp_lastSettledPageIndex == page) return;

    self.pp_lastSettledPageIndex = page;
    if (UIAccessibilityIsReduceMotionEnabled()) return;

    if (!self.pp_swipeFeedbackGenerator) {
        self.pp_swipeFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    }
    [self.pp_swipeFeedbackGenerator impactOccurredWithIntensity:0.45];
    [self.pp_swipeFeedbackGenerator prepare];
}

- (void)collectionView:(UICollectionView *)collectionView
       willDisplayCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!self.hidesPageControl) {
        NSInteger page = [self pageIndexForItemIndex:indexPath.item];
        _myPageControl1.currentPage = page;
    }
    [self pp_updateGalleryAccessibilityForPage:indexPath.item];
    [self pp_applySwipeMotionToVisibleCells];
}

- (void)collectionView:(UICollectionView *)collectionView
  didEndDisplayingCell:(UICollectionViewCell *)cell
   forItemAtIndexPath:(NSIndexPath *)indexPath
{
    (void)collectionView;
    (void)indexPath;
    [self pp_resetMotionForCell:cell];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView || UIAccessibilityIsReduceMotionEnabled()) return;
    [self.pp_swipeFeedbackGenerator prepare];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) return;
    [self pp_applySwipeMotionToVisibleCells];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) return;
    NSInteger page = (NSInteger)llround(scrollView.contentOffset.x / MAX(1.0, CGRectGetWidth(scrollView.bounds)));
    if (!self.hidesPageControl) {
        _myPageControl1.currentPage = [self pageIndexForItemIndex:page];
    }
    [self pp_updateGalleryAccessibilityForPage:page];
    [self pp_emitSwipeFeedbackIfNeededForPage:page];
    [self pp_applySwipeMotionToVisibleCells];
    if (self.onPageChanged) {
        self.onPageChanged(page);
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (scrollView != self.collectionView) return;
    if (!decelerate) {
        [self scrollViewDidEndDecelerating:scrollView];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) return;
    [self scrollViewDidEndDecelerating:scrollView];
}



-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *selectedCell = [collectionView cellForItemAtIndexPath:indexPath];
    UIImageView *sourceImageView = [selectedCell.contentView viewWithTag:100];
    PetImageItem *item = indexPath.item < self.imageItems.count ? self.imageItems[indexPath.item] : nil;
    if (PPReusableVideoMediaEnabled() && item.isVideoMedia) {
        NSURL *videoURL = [NSURL URLWithString:item.videoURL ?: @""];
        if (videoURL) {
            PPPremiumVideoPlayerViewController *playerVC =
            [[PPPremiumVideoPlayerViewController alloc] initWithURL:videoURL];
            UIViewController *presenter = AppMgr.topViewController ?: self.parentViewController;
            [presenter presentViewController:playerVC animated:YES completion:nil];
        }
        return;
    }
    UIImage *image = item.url.length > 0 ? [self.imageCache objectForKey:item.url] : nil;
    image = image ?: sourceImageView.image;
    if (!image || !sourceImageView) {
        return;
    }

    _currentPagr = indexPath.item;

    void (^presentViewer)(void) = ^{
        self.fullScreenViewer = [[FullScreenImageViewerController alloc] initWithImage:image];
        __weak typeof(self) weakSelf = self;
        if ([self.currentModel isKindOfClass:PetAccessory.class] ||
            [self.currentModel isKindOfClass:PetAd.class]) {
            self.fullScreenViewer.shareHandler = ^(FullScreenImageViewerController *viewer) {
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                if ([self.currentModel isKindOfClass:PetAccessory.class]) {
                    [PetAccessory sharePetAccessory:(PetAccessory *)self.currentModel
                                 fromViewController:viewer];
                } else if ([self.currentModel isKindOfClass:PetAd.class]) {
                    [PPAdSharingHelper sharePetAd:(PetAd *)self.currentModel
                               fromViewController:viewer];
                }
            };
        }
        self.fullScreenViewer.dismissalCompletion = ^{
            __strong typeof(weakSelf) self = weakSelf;
            self.fullScreenViewer = nil;
        };
        [self.fullScreenViewer presentFullScreenFromImageView:sourceImageView];
    };

    if (selectedCell && !UIAccessibilityIsReduceMotionEnabled()) {
        UIImpactFeedbackGenerator *tapFeedback =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [tapFeedback impactOccurredWithIntensity:0.55];

        [UIView animateWithDuration:0.08
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            selectedCell.contentView.transform = CGAffineTransformScale(selectedCell.contentView.transform, 0.975, 0.975);
            selectedCell.contentView.alpha = 0.96;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.14
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                selectedCell.contentView.transform = CGAffineTransformIdentity;
                selectedCell.contentView.alpha = 1.0;
            } completion:^(BOOL finished) {
                [self pp_applySwipeMotionToVisibleCells];
                presentViewer();
            }];
        }];
    } else {
        presentViewer();
    }
    
     
     //  [PPPhotoBrowser showBrowserFrom:AppMgr.topViewController
        //            imageURLStrings:self.imageURLs
         //               startIndex:indexPath.item];
 
 
     
 }

- (void)scrollToPage:(NSInteger)page animated:(BOOL)animated
{
    if (page < 0 || page >= (NSInteger)self.imageItems.count) return;
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:page inSection:0];
    [self.collectionView scrollToItemAtIndexPath:indexPath
                                atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                        animated:animated];
    if (!animated) {
        if (!self.hidesPageControl) {
            _myPageControl1.currentPage = [self pageIndexForItemIndex:page];
        }
        [self pp_updateGalleryAccessibilityForPage:page];
        if (self.onPageChanged) {
            self.onPageChanged(page);
        }
    }
}

@end
