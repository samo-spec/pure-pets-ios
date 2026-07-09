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
static const CGFloat PPImageGalleryThumbnailRailWidth = 58.0;
static const CGFloat PPImageGalleryThumbnailRailHorizontalInset = 12.0;
static const CGFloat PPImageGalleryThumbnailRailVerticalInset = 14.0;
static const CGFloat PPImageGalleryThumbnailControlSize = 48.0;
static const CGFloat PPImageGalleryThumbnailImageSize = 42.0;
static const CGFloat PPImageGalleryThumbnailSpacing = 10.0;

@interface PPImageGalleryThumbnailButton : UIControl

@property (nonatomic, strong) UIImageView *thumbnailImageView;
@property (nonatomic, strong) UIView *selectionRingView;
@property (nonatomic, strong) UIImageView *videoBadgeView;
@property (nonatomic, assign) NSInteger galleryIndex;

- (void)configureWithPlaceholder:(UIImage *)placeholder
                          isVideo:(BOOL)isVideo
                       totalCount:(NSInteger)totalCount;
- (void)setThumbnailImage:(UIImage *)image;
- (void)applySelected:(BOOL)selected animated:(BOOL)animated accentColor:(UIColor *)accentColor;

@end

@implementation PPImageGalleryThumbnailButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.exclusiveTouch = YES;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowRadius = 10.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 4.0);
    self.layer.shadowOpacity = 0.05;

    _thumbnailImageView = [[UIImageView alloc] init];
    _thumbnailImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _thumbnailImageView.contentMode = UIViewContentModeScaleAspectFill;
    _thumbnailImageView.clipsToBounds = YES;
    _thumbnailImageView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    _thumbnailImageView.layer.cornerRadius = 13.0;
    _thumbnailImageView.layer.borderWidth = 0.5;
    _thumbnailImageView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.28].CGColor;
    if (@available(iOS 13.0, *)) {
        _thumbnailImageView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    _thumbnailImageView.isAccessibilityElement = NO;
    [self addSubview:_thumbnailImageView];

    _selectionRingView = [[UIView alloc] init];
    _selectionRingView.translatesAutoresizingMaskIntoConstraints = NO;
    _selectionRingView.userInteractionEnabled = NO;
    _selectionRingView.backgroundColor = UIColor.clearColor;
    _selectionRingView.alpha = 0.0;
    _selectionRingView.layer.cornerRadius = 13.0;
    _selectionRingView.layer.borderWidth = 1.2;
    if (@available(iOS 13.0, *)) {
        _selectionRingView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self addSubview:_selectionRingView];

    _videoBadgeView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"play.fill"]];
    _videoBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    _videoBadgeView.tintColor = UIColor.whiteColor;
    _videoBadgeView.contentMode = UIViewContentModeScaleAspectFit;
    _videoBadgeView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.34];
    _videoBadgeView.layer.cornerRadius = 8.0;
    _videoBadgeView.clipsToBounds = YES;
    _videoBadgeView.hidden = YES;
    _videoBadgeView.isAccessibilityElement = NO;
    [self addSubview:_videoBadgeView];

    [NSLayoutConstraint activateConstraints:@[
        [self.widthAnchor constraintEqualToConstant:PPImageGalleryThumbnailControlSize],
        [self.heightAnchor constraintEqualToConstant:PPImageGalleryThumbnailControlSize],

        [_thumbnailImageView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_thumbnailImageView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_thumbnailImageView.widthAnchor constraintEqualToConstant:PPImageGalleryThumbnailImageSize],
        [_thumbnailImageView.heightAnchor constraintEqualToConstant:PPImageGalleryThumbnailImageSize],

        [_selectionRingView.centerXAnchor constraintEqualToAnchor:_thumbnailImageView.centerXAnchor],
        [_selectionRingView.centerYAnchor constraintEqualToAnchor:_thumbnailImageView.centerYAnchor],
        [_selectionRingView.widthAnchor constraintEqualToAnchor:_thumbnailImageView.widthAnchor],
        [_selectionRingView.heightAnchor constraintEqualToAnchor:_thumbnailImageView.heightAnchor],

        [_videoBadgeView.trailingAnchor constraintEqualToAnchor:_thumbnailImageView.trailingAnchor constant:-4.0],
        [_videoBadgeView.bottomAnchor constraintEqualToAnchor:_thumbnailImageView.bottomAnchor constant:-4.0],
        [_videoBadgeView.widthAnchor constraintEqualToConstant:16.0],
        [_videoBadgeView.heightAnchor constraintEqualToConstant:16.0]
    ]];

    [self applySelected:NO animated:NO accentColor:nil];
    return self;
}

- (void)configureWithPlaceholder:(UIImage *)placeholder
                          isVideo:(BOOL)isVideo
                       totalCount:(NSInteger)totalCount
{
    self.thumbnailImageView.image = placeholder;
    self.videoBadgeView.hidden = !(PPReusableVideoMediaEnabled() && isVideo);
    self.accessibilityLabel = [NSString stringWithFormat:kLang(@"image_gallery_page_format"),
                               (long)(self.galleryIndex + 1),
                               (long)totalCount];
    self.accessibilityHint = kLang(@"image_gallery_swipe_hint");
}

- (void)setThumbnailImage:(UIImage *)image
{
    if (!image) return;
    self.thumbnailImageView.image = image;
}

- (void)applySelected:(BOOL)selected animated:(BOOL)animated accentColor:(UIColor *)accentColor
{
    UIColor *resolvedAccent = accentColor ?: [AppBackgroundClrLigter colorWithAlphaComponent:1.0] ?: UIColor.labelColor;
    self.selected = selected;
    self.accessibilityTraits = selected
        ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected)
        : UIAccessibilityTraitButton;
    self.selectionRingView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.42].CGColor;
    self.selectionRingView.layer.shadowColor = resolvedAccent.CGColor;
    self.selectionRingView.layer.shadowOffset = CGSizeZero;

    void (^changes)(void) = ^{
        self.selectionRingView.alpha = selected ? 0.36 : 0.0;
        self.selectionRingView.layer.shadowOpacity = selected ? 0.04 : 0.0;
        self.selectionRingView.layer.shadowRadius = selected ? 2.0 : 0.0;
        self.thumbnailImageView.alpha = selected ? 1.0 : 0.66;
        self.thumbnailImageView.layer.borderWidth = selected ? 1.25 : 0.5;
        self.thumbnailImageView.layer.borderColor = selected
            ? [resolvedAccent colorWithAlphaComponent:0.94].CGColor
            : [UIColor colorWithWhite:1.0 alpha:0.24].CGColor;
        self.thumbnailImageView.transform = selected ? CGAffineTransformMakeScale(1.025, 1.025) : CGAffineTransformIdentity;
        self.selectionRingView.transform = self.thumbnailImageView.transform;
        self.layer.shadowOpacity = selected ? 0.08 : 0.04;
        self.layer.shadowRadius = selected ? 8.0 : 6.0;
        self.transform = CGAffineTransformIdentity;
    };

    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.24
                              delay:0.0
             usingSpringWithDamping:0.84
              initialSpringVelocity:0.35
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

@end

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

@interface PetImageGalleryView ()<UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) FullScreenImageViewerController *fullScreenViewer;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIButton *containerB;
@property (nonatomic, strong) UIVisualEffectView *thumbnailRailMaterialView;
@property (nonatomic, strong) id currentModel;
@property (nonatomic, strong) UIScrollView *thumbnailRailScrollView;
@property (nonatomic, strong) UIStackView *thumbnailRailStackView;
@property (nonatomic, strong) NSMutableArray<PPImageGalleryThumbnailButton *> *thumbnailButtons;
@property (nonatomic, strong) NSLayoutConstraint *thumbnailRailHeightConstraint;

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
- (UIImage *)pp_thumbnailPlaceholderForItem:(PetImageItem *)item;
- (BOOL)pp_imageItems:(NSArray<PetImageItem *> *)lhs haveSameIdentityAs:(NSArray<PetImageItem *> *)rhs;
- (BOOL)pp_shouldShowThumbnailRail;
- (void)pp_rebuildThumbnailRail;
- (void)pp_updateThumbnailRailLayout;
- (void)pp_updateThumbnailSelectionForPage:(NSInteger)page animated:(BOOL)animated scrollToVisible:(BOOL)scrollToVisible;
- (void)pp_setCurrentPageIndex:(NSInteger)page
                       animated:(BOOL)animated
                         notify:(BOOL)notify
                         haptic:(BOOL)haptic
                 scrollRailIntoView:(BOOL)scrollRailIntoView;
- (NSInteger)pp_currentNearestPageIndex;
- (void)pp_thumbnailButtonTapped:(PPImageGalleryThumbnailButton *)sender;

@end

@implementation PetImageGalleryView

- (instancetype)initWithFrame:(CGRect)frame imageItems:(NSArray<PetImageItem *> *)items galleryType:(PetImageGalleryType)type itemHeight:(CGFloat)itemHeight parentVC:(UIViewController *)parentVC obj:(id)obj 
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _imageCache = [[NSCache alloc] init];
    _thumbnailButtons = [NSMutableArray array];
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
    //layout.minimumLineSpacing = 0;

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
        : AppForgroundColr;
    _collectionView.layer.cornerRadius = 0;
    _collectionView.clipsToBounds = YES;
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    //_collectionView.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner ;
    [_collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"ImageCell"];

    UITapGestureRecognizer *galleryTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_galleryTapped:)];
    [_collectionView addGestureRecognizer:galleryTap];

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

// layoutSubviews keeps the side thumbnail rail fitted to the current hero size.

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
    [self pp_updateThumbnailRailLayout];
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

    NSInteger targetIndex = self.imageItems.count > 0
        ? MIN(MAX(self.currentPagr, 0), (NSInteger)self.imageItems.count - 1)
        : 0;
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
        [self pp_setCurrentPageIndex:targetIndex
                            animated:NO
                              notify:NO
                              haptic:NO
                  scrollRailIntoView:NO];
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
    for (PPImageGalleryThumbnailButton *button in self.thumbnailButtons) {
        button.thumbnailImageView.contentMode = contentMode == UIViewContentModeScaleAspectFit
            ? UIViewContentModeScaleAspectFit
            : UIViewContentModeScaleAspectFill;
    }
    [self.collectionView reloadData];
}

- (void)setHidesPageControl:(BOOL)hidesPageControl
{
    if (_hidesPageControl == hidesPageControl) {
        return;
    }

    _hidesPageControl = hidesPageControl;
    if ([self pp_shouldShowThumbnailRail] && !self.containerB) {
        [self setupUI];
    }
    self.containerB.hidden = ![self pp_shouldShowThumbnailRail];
    if (hidesPageControl) {
        for (PPImageGalleryThumbnailButton *button in self.thumbnailButtons) {
            [button removeTarget:self
                          action:@selector(pp_thumbnailButtonTapped:)
                forControlEvents:UIControlEventTouchUpInside];
        }
    } else {
        [self pp_rebuildThumbnailRail];
    }
    [self setNeedsLayout];
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
        self.containerB.hidden = ![self pp_shouldShowThumbnailRail];
        [self pp_rebuildThumbnailRail];
        return;
    }

    self.containerB = [UIButton buttonWithType:UIButtonTypeCustom];
    self.containerB.translatesAutoresizingMaskIntoConstraints = NO;
    self.containerB.backgroundColor = UIColor.clearColor;
    self.containerB.isAccessibilityElement = NO;
    self.containerB.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    self.containerB.clipsToBounds = NO;
    self.containerB.layer.cornerRadius = 18.0;
    self.containerB.layer.shadowColor = UIColor.blackColor.CGColor;
    self.containerB.layer.shadowOpacity = 0.12;
    self.containerB.layer.shadowRadius = 18.0;
    self.containerB.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    self.containerB.layer.masksToBounds = NO;
    if (@available(iOS 13.0, *)) {
        self.containerB.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self addSubview:self.containerB];

    UIBlurEffectStyle railBlurStyle = UIBlurEffectStyleExtraLight;
    if (@available(iOS 13.0, *)) {
        railBlurStyle = UIBlurEffectStyleSystemThinMaterial;
    }
    UIBlurEffect *railBlur = [UIBlurEffect effectWithStyle:railBlurStyle];
    self.thumbnailRailMaterialView = [[UIVisualEffectView alloc] initWithEffect:railBlur];
    self.thumbnailRailMaterialView.translatesAutoresizingMaskIntoConstraints = NO;
    self.thumbnailRailMaterialView.userInteractionEnabled = NO;
    self.thumbnailRailMaterialView.layer.cornerRadius = 18.0;
    self.thumbnailRailMaterialView.layer.masksToBounds = YES;
    self.thumbnailRailMaterialView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;

    if (@available(iOS 13.0, *)) {
        self.thumbnailRailMaterialView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.containerB addSubview:self.thumbnailRailMaterialView];

    self.thumbnailRailScrollView = [[UIScrollView alloc] init];
    self.thumbnailRailScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.thumbnailRailScrollView.backgroundColor = UIColor.clearColor;
    self.thumbnailRailScrollView.showsVerticalScrollIndicator = NO;
    self.thumbnailRailScrollView.showsHorizontalScrollIndicator = NO;
    self.thumbnailRailScrollView.alwaysBounceVertical = NO;
    self.thumbnailRailScrollView.clipsToBounds = YES;
    if (@available(iOS 11.0, *)) {
        self.thumbnailRailScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    self.thumbnailRailScrollView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [self.containerB addSubview:self.thumbnailRailScrollView];

    self.thumbnailRailStackView = [[UIStackView alloc] init];
    self.thumbnailRailStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.thumbnailRailStackView.axis = UILayoutConstraintAxisVertical;
    self.thumbnailRailStackView.alignment = UIStackViewAlignmentCenter;
    self.thumbnailRailStackView.distribution = UIStackViewDistributionFill;
    self.thumbnailRailStackView.spacing = PPImageGalleryThumbnailSpacing;
    self.thumbnailRailStackView.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [self.thumbnailRailScrollView addSubview:self.thumbnailRailStackView];

    BOOL isRTL  = NO;
    NSLayoutConstraint *sideConstraint = isRTL
        ? [self.containerB.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:PPImageGalleryThumbnailRailHorizontalInset]
        : [self.containerB.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-PPImageGalleryThumbnailRailHorizontalInset];
    self.thumbnailRailHeightConstraint = [self.containerB.heightAnchor constraintEqualToConstant:80.0];
    NSLayoutConstraint *topLimit =
    [self.containerB.topAnchor constraintGreaterThanOrEqualToAnchor:self.topAnchor
                                                           constant:PPImageGalleryThumbnailRailVerticalInset];
    NSLayoutConstraint *bottomLimit =
    [self.containerB.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor
                                                           constant:-PPImageGalleryThumbnailRailVerticalInset];
    topLimit.priority = UILayoutPriorityDefaultHigh;
    bottomLimit.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        sideConstraint,
        [self.containerB.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.containerB.widthAnchor constraintEqualToConstant:PPImageGalleryThumbnailRailWidth],
        self.thumbnailRailHeightConstraint,
        topLimit,
        bottomLimit,

        [self.thumbnailRailMaterialView.topAnchor constraintEqualToAnchor:self.containerB.topAnchor],
        [self.thumbnailRailMaterialView.leadingAnchor constraintEqualToAnchor:self.containerB.leadingAnchor],
        [self.thumbnailRailMaterialView.trailingAnchor constraintEqualToAnchor:self.containerB.trailingAnchor],
        [self.thumbnailRailMaterialView.bottomAnchor constraintEqualToAnchor:self.containerB.bottomAnchor],

        [self.thumbnailRailScrollView.topAnchor constraintEqualToAnchor:self.containerB.topAnchor constant:6.0],
        [self.thumbnailRailScrollView.leadingAnchor constraintEqualToAnchor:self.containerB.leadingAnchor],
        [self.thumbnailRailScrollView.trailingAnchor constraintEqualToAnchor:self.containerB.trailingAnchor],
        [self.thumbnailRailScrollView.bottomAnchor constraintEqualToAnchor:self.containerB.bottomAnchor constant:-0.0]
    ]];

    if (@available(iOS 11.0, *)) {
        [NSLayoutConstraint activateConstraints:@[
            [self.thumbnailRailStackView.topAnchor constraintEqualToAnchor:self.thumbnailRailScrollView.contentLayoutGuide.topAnchor],
            [self.thumbnailRailStackView.leadingAnchor constraintEqualToAnchor:self.thumbnailRailScrollView.contentLayoutGuide.leadingAnchor],
            [self.thumbnailRailStackView.trailingAnchor constraintEqualToAnchor:self.thumbnailRailScrollView.contentLayoutGuide.trailingAnchor],
            [self.thumbnailRailStackView.bottomAnchor constraintEqualToAnchor:self.thumbnailRailScrollView.contentLayoutGuide.bottomAnchor],
            [self.thumbnailRailStackView.widthAnchor constraintEqualToAnchor:self.thumbnailRailScrollView.frameLayoutGuide.widthAnchor]
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [self.thumbnailRailStackView.topAnchor constraintEqualToAnchor:self.thumbnailRailScrollView.topAnchor],
            [self.thumbnailRailStackView.leadingAnchor constraintEqualToAnchor:self.thumbnailRailScrollView.leadingAnchor],
            [self.thumbnailRailStackView.trailingAnchor constraintEqualToAnchor:self.thumbnailRailScrollView.trailingAnchor],
            [self.thumbnailRailStackView.bottomAnchor constraintEqualToAnchor:self.thumbnailRailScrollView.bottomAnchor],
            [self.thumbnailRailStackView.widthAnchor constraintEqualToAnchor:self.thumbnailRailScrollView.widthAnchor]
        ]];
    }

    self.containerB.hidden = ![self pp_shouldShowThumbnailRail];
    [self pp_rebuildThumbnailRail];
    [self pp_updateGalleryAccessibilityForPage:self.currentPagr];
}

- (void)pp_updateGalleryAccessibilityForPage:(NSInteger)page
{
    NSInteger count = self.imageItems.count;
    if (count <= 0) {
        self.containerB.accessibilityValue = nil;
        return;
    }
    NSInteger safePage = MIN(MAX(page, 0), count - 1);
    self.containerB.accessibilityLabel = kLang(@"image_gallery_accessibility_label");
    self.containerB.accessibilityValue = [NSString stringWithFormat:kLang(@"image_gallery_page_format"),
                                          (long)(safePage + 1),
                                          (long)count];
    self.containerB.accessibilityHint = kLang(@"image_gallery_swipe_hint");
}

- (UIImage *)pp_thumbnailPlaceholderForItem:(PetImageItem *)item
{
    UIImage *placeholder = nil;
    if (item.blurHash.length > 0) {
        placeholder = [PPBlurHashBridge imageFrom:item.blurHash
                                         syncSize:CGSizeMake(28.0, 28.0)
                                            punch:1.0];
    }
    return placeholder ?: [UIImage imageNamed:@"placeholder"];
}

- (BOOL)pp_imageItems:(NSArray<PetImageItem *> *)lhs haveSameIdentityAs:(NSArray<PetImageItem *> *)rhs
{
    if (lhs.count != rhs.count) return NO;
    for (NSInteger index = 0; index < (NSInteger)lhs.count; index++) {
        PetImageItem *leftItem = lhs[index];
        PetImageItem *rightItem = rhs[index];
        if (![(leftItem.url ?: @"") isEqualToString:(rightItem.url ?: @"")]) return NO;
        if (![(leftItem.videoURL ?: @"") isEqualToString:(rightItem.videoURL ?: @"")]) return NO;
        if (![(leftItem.blurHash ?: @"") isEqualToString:(rightItem.blurHash ?: @"")]) return NO;
        if (leftItem.isVideoMedia != rightItem.isVideoMedia) return NO;
    }
    return YES;
}

- (BOOL)pp_shouldShowThumbnailRail
{
    return !self.hidesPageControl && self.imageItems.count > 1;
}

- (void)pp_rebuildThumbnailRail
{
    if (!self.thumbnailRailStackView) return;

    for (UIView *view in self.thumbnailRailStackView.arrangedSubviews) {
        [self.thumbnailRailStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [self.thumbnailButtons removeAllObjects];

    NSInteger count = self.imageItems.count;
    if (count <= 1 || self.hidesPageControl) {
        self.containerB.hidden = YES;
        [self pp_updateThumbnailRailLayout];
        return;
    }

    self.containerB.hidden = NO;
    __weak typeof(self) weakSelf = self;
    for (NSInteger index = 0; index < count; index++) {
        PetImageItem *item = self.imageItems[index];
        NSString *itemURL = item.url ?: @"";

        PPImageGalleryThumbnailButton *button = [[PPImageGalleryThumbnailButton alloc] initWithFrame:CGRectZero];
        button.galleryIndex = index;
        button.thumbnailImageView.contentMode = self.contentMode == UIViewContentModeScaleAspectFit
            ? UIViewContentModeScaleAspectFit
            : UIViewContentModeScaleAspectFill;
        [button configureWithPlaceholder:[self pp_thumbnailPlaceholderForItem:item]
                                  isVideo:item.isVideoMedia
                               totalCount:count];
        [button addTarget:self
                   action:@selector(pp_thumbnailButtonTapped:)
         forControlEvents:UIControlEventTouchUpInside];

        [self.thumbnailRailStackView addArrangedSubview:button];
        [self.thumbnailButtons addObject:button];

        UIImage *cachedImage = itemURL.length > 0 ? [self.imageCache objectForKey:itemURL] : nil;
        if (cachedImage) {
            [button setThumbnailImage:cachedImage];
            continue;
        }
        if (itemURL.length == 0) {
            continue;
        }

        [[PPImageLoaderManager shared] fetchImageWithURL:itemURL
                                              completion:^(UIImage * _Nullable image) {
            if (!image) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self || ![self.thumbnailButtons containsObject:button]) return;
                if (button.galleryIndex < 0 || button.galleryIndex >= (NSInteger)self.imageItems.count) return;
                PetImageItem *currentItem = self.imageItems[button.galleryIndex];
                if (![(currentItem.url ?: @"") isEqualToString:itemURL]) return;
                [self.imageCache setObject:image forKey:itemURL];
                [button setThumbnailImage:image];
            });
        }];
    }

    [self pp_updateThumbnailRailLayout];
    [self pp_updateThumbnailSelectionForPage:self.currentPagr animated:NO scrollToVisible:NO];
    [self pp_updateGalleryAccessibilityForPage:self.currentPagr];
}

- (void)pp_updateThumbnailRailLayout
{
    if (!self.containerB || !self.thumbnailRailHeightConstraint) return;

    self.containerB.hidden = ![self pp_shouldShowThumbnailRail];
    if (self.containerB.hidden) {
        return;
    }

    NSInteger count = self.thumbnailButtons.count;
    CGFloat contentHeight = (count * PPImageGalleryThumbnailControlSize) +
        (MAX(count - 1, 0) * PPImageGalleryThumbnailSpacing);
    CGFloat availableHeight = MAX(PPImageGalleryThumbnailControlSize + 12.0,
                                  CGRectGetHeight(self.bounds) - (PPImageGalleryThumbnailRailVerticalInset * 2.0));
    CGFloat preferredMaxHeight = MIN(300.0, availableHeight);
    CGFloat targetHeight = MIN(preferredMaxHeight, contentHeight + 12.0);
    if (count <= 3) {
        targetHeight = MIN(availableHeight, contentHeight + 18.0);
    }

    self.thumbnailRailHeightConstraint.constant = MAX(PPImageGalleryThumbnailControlSize + 12.0, targetHeight);
    self.containerB.layer.cornerRadius = 22.0;
    self.thumbnailRailMaterialView.layer.cornerRadius = 22.0;

    CGFloat visibleHeight = MAX(1.0, self.thumbnailRailHeightConstraint.constant - 12.0);
    CGFloat centeredInset = MAX(3.0, (visibleHeight - contentHeight) * 0.5);
    UIEdgeInsets inset = UIEdgeInsetsMake(centeredInset, 0.0, centeredInset, 0.0);
    if (!UIEdgeInsetsEqualToEdgeInsets(self.thumbnailRailScrollView.contentInset, inset)) {
        self.thumbnailRailScrollView.contentInset = inset;
    }
    self.thumbnailRailScrollView.alwaysBounceVertical = contentHeight > visibleHeight;
    
}

- (void)pp_updateThumbnailSelectionForPage:(NSInteger)page animated:(BOOL)animated scrollToVisible:(BOOL)scrollToVisible
{
    NSInteger count = self.thumbnailButtons.count;
    if (count == 0) return;

    NSInteger safePage = MIN(MAX(page, 0), count - 1);
    UIColor *accent = AppPrimaryClr ?: UIColor.labelColor;
    for (PPImageGalleryThumbnailButton *button in self.thumbnailButtons) {
        [button applySelected:(button.galleryIndex == safePage)
                     animated:animated
                  accentColor:accent];
    }

    if (scrollToVisible && safePage < count && self.thumbnailRailScrollView) {
        PPImageGalleryThumbnailButton *selectedButton = self.thumbnailButtons[safePage];
        CGRect targetRect = [selectedButton convertRect:selectedButton.bounds
                                                 toView:self.thumbnailRailScrollView];
        CGFloat insetY = 8.0;
        targetRect = CGRectInset(targetRect, 0.0, -insetY);
        [self.thumbnailRailScrollView scrollRectToVisible:targetRect
                                                 animated:(animated && self.window != nil)];
    }
}

- (NSInteger)pp_currentNearestPageIndex
{
    NSInteger count = self.imageItems.count;
    if (count <= 0) return 0;

    CGPoint visibleCenter = CGPointMake(self.collectionView.contentOffset.x + CGRectGetMidX(self.collectionView.bounds),
                                        self.collectionView.contentOffset.y + CGRectGetMidY(self.collectionView.bounds));
    NSIndexPath *centeredIndexPath = [self.collectionView indexPathForItemAtPoint:visibleCenter];
    if (centeredIndexPath) {
        return MIN(MAX((NSInteger)centeredIndexPath.item, 0), count - 1);
    }

    CGFloat width = MAX(1.0, CGRectGetWidth(self.collectionView.bounds));
    NSInteger page = (NSInteger)llround(self.collectionView.contentOffset.x / width);
    return MIN(MAX(page, 0), count - 1);
}

- (void)pp_setCurrentPageIndex:(NSInteger)page
                       animated:(BOOL)animated
                         notify:(BOOL)notify
                         haptic:(BOOL)haptic
             scrollRailIntoView:(BOOL)scrollRailIntoView
{
    NSInteger count = self.imageItems.count;
    if (count <= 0) {
        self.currentPagr = 0;
        return;
    }

    NSInteger safePage = MIN(MAX(page, 0), count - 1);
    self.currentPagr = safePage;
    [self pp_updateThumbnailSelectionForPage:safePage
                                    animated:animated
                             scrollToVisible:scrollRailIntoView];
    [self pp_updateGalleryAccessibilityForPage:safePage];
    if (haptic) {
        [self pp_emitSwipeFeedbackIfNeededForPage:safePage];
    }
    if (notify && self.onPageChanged) {
        self.onPageChanged(safePage);
    }
}

- (void)pp_thumbnailButtonTapped:(PPImageGalleryThumbnailButton *)sender
{
    NSInteger targetIndex = sender.galleryIndex;
    if (targetIndex < 0 || targetIndex >= (NSInteger)self.imageItems.count) return;

    if (!UIAccessibilityIsReduceMotionEnabled()) {
        UIImpactFeedbackGenerator *tapFeedback =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [tapFeedback impactOccurredWithIntensity:0.42];
    }

    [self pp_setCurrentPageIndex:targetIndex
                        animated:YES
                          notify:NO
                          haptic:NO
              scrollRailIntoView:YES];

    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:targetIndex inSection:0];
    [self.collectionView scrollToItemAtIndexPath:indexPath
                                atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                        animated:YES];
}

- (void)setImageItems:(NSArray<PetImageItem *> *)imageItems {
    NSArray<PetImageItem *> *nextItems = imageItems ?: @[];
    BOOL sameItems = [self pp_imageItems:_imageItems haveSameIdentityAs:nextItems];
    _imageItems = nextItems;
    if (!sameItems) {
        [self.imageCache removeAllObjects];
    }
    self.currentPagr = _imageItems.count == 0 ? 0 : MIN(MAX(self.currentPagr, 0), (NSInteger)_imageItems.count - 1);
    if (!sameItems) {
        self.pp_didPrepareGalleryEntranceAnimation = NO;
        self.pp_didRunGalleryEntranceAnimation = NO;
        self.pp_didNormalizeInitialLayout = NO;
        self.pp_lastLaidOutCollectionSize = CGSizeZero;
        self.pp_lastSettledPageIndex = NSNotFound;
    }
    if ([self pp_shouldShowThumbnailRail] && !self.containerB) {
        [self setupUI];
    }
    self.containerB.hidden = ![self pp_shouldShowThumbnailRail];
    self.collectionView.backgroundView.hidden = _imageItems.count > 0;
    if (sameItems) {
        [self pp_updateThumbnailRailLayout];
        [self pp_updateThumbnailSelectionForPage:self.currentPagr animated:NO scrollToVisible:YES];
    } else {
        [self pp_rebuildThumbnailRail];
    }
    [self pp_updateGalleryAccessibilityForPage:self.currentPagr];
    if (!sameItems) {
        [self pp_prepareGalleryEntranceAnimationIfNeeded];
        [self.collectionView reloadData];
    }
    [self setNeedsLayout];
    if (!sameItems) {
        [self pp_runGalleryEntranceAnimationIfNeeded];
    }
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
        if ([self pp_shouldShowThumbnailRail]) {
            self.containerB.alpha = 1.0;
            self.containerB.transform = CGAffineTransformIdentity;
        }
        return;
    }
    self.collectionView.alpha = 0.0;
    self.collectionView.transform =
    CGAffineTransformMakeScale(1.025, 1.025);
    if ([self pp_shouldShowThumbnailRail]) {
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
        if ([self pp_shouldShowThumbnailRail]) {
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

    if ([self pp_shouldShowThumbnailRail]) {
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
    NSInteger page = [self pp_currentNearestPageIndex];
    [self pp_updateGalleryAccessibilityForPage:page];
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
    if (!self.pp_swipeFeedbackGenerator) {
        self.pp_swipeFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    }
    [self.pp_swipeFeedbackGenerator prepare];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) return;
    
    // Only update intermediate pages and selection if the scroll was initiated by the user.
    // This prevents the selection state from jumping/flickering through intermediate items during programmatic scrollToPage: animations.
    if (!scrollView.isDragging && !scrollView.isDecelerating) {
        [self pp_applySwipeMotionToVisibleCells];
        return;
    }
    
    NSInteger page = [self pp_currentNearestPageIndex];
    [self pp_setCurrentPageIndex:page
                        animated:YES
                          notify:NO
                          haptic:NO
              scrollRailIntoView:YES];
    [self pp_applySwipeMotionToVisibleCells];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) return;
    NSInteger page = [self pp_currentNearestPageIndex];
    [self pp_setCurrentPageIndex:page
                        animated:YES
                          notify:YES
                          haptic:YES
              scrollRailIntoView:YES];
    [self pp_applySwipeMotionToVisibleCells];
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

- (void)pp_galleryTapped:(UITapGestureRecognizer *)gesture
{
    if (gesture.state != UIGestureRecognizerStateEnded) return;

    CGPoint point = [gesture locationInView:self.collectionView];
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:point];

    if (indexPath) {
        [self collectionView:self.collectionView didSelectItemAtIndexPath:indexPath];
        return;
    }

    CGFloat viewWidth = CGRectGetWidth(self.bounds);
    if (viewWidth <= 0) return;

    CGPoint pointInBounds = [gesture locationInView:self];
    CGFloat x = pointInBounds.x;

    BOOL isRTL = Language.isRTL;
    BOOL isLeftHalf = (x < viewWidth * 0.5);

    NSInteger currentPage = self.currentPagr;
    NSInteger totalPages = self.imageItems.count;
    if (totalPages <= 1) return;

    NSInteger targetPage = currentPage;
    if (isRTL) {
        if (isLeftHalf) {
            targetPage = currentPage + 1;
        } else {
            targetPage = currentPage - 1;
        }
    } else {
        if (isLeftHalf) {
            targetPage = currentPage - 1;
        } else {
            targetPage = currentPage + 1;
        }
    }

    if (targetPage >= totalPages) {
        targetPage = totalPages - 1;
    } else if (targetPage < 0) {
        targetPage = 0;
    }

    [self scrollToPage:targetPage animated:YES];
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
    [self pp_setCurrentPageIndex:page
                        animated:animated
                          notify:!animated
                          haptic:NO
              scrollRailIntoView:YES];
    [self.collectionView scrollToItemAtIndexPath:indexPath
                                atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                        animated:animated];
}

@end
