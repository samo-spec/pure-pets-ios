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
static NSString * const PPImageGalleryThumbnailCellIdentifier = @"PPImageGalleryThumbnailCell";
static const CGFloat PPImageGalleryThumbnailRailWidth = PPButtonHeightLG + PPSpaceBase;
static const CGFloat PPImageGalleryThumbnailRailMaximumHeight = 320.0;
static const CGFloat PPImageGalleryThumbnailRailHorizontalInset = PPSpaceMD;
static const CGFloat PPImageGalleryThumbnailRailVerticalInset = PPSpaceBase;
static const CGFloat PPImageGalleryThumbnailCellHeight = PPButtonHeightLG + PPSpaceXS;
static const CGFloat PPImageGalleryThumbnailImageSize = PPTouchTargetMin;
static const CGFloat PPImageGalleryThumbnailSpacing = PPSpaceXS;
static const CGFloat PPImageGalleryThumbnailSectionInset = PPSpaceSM;
static const CGFloat PPImageGalleryThumbnailFocusInset = PPSpaceMD;

@interface PPImageGalleryThumbnailCell : UICollectionViewCell

@property (nonatomic, strong) UIView *artworkContainerView;
@property (nonatomic, strong) UIView *selectionSurfaceView;
@property (nonatomic, strong) UIView *selectionMarkerView;
@property (nonatomic, strong) UIImageView *thumbnailImageView;
@property (nonatomic, strong) UIImageView *videoBadgeView;
@property (nonatomic, copy) NSString *representedIdentifier;
@property (nonatomic, assign) BOOL gallerySelected;

- (void)configureWithPlaceholder:(UIImage *)placeholder
                          isVideo:(BOOL)isVideo
                            index:(NSInteger)index
                       totalCount:(NSInteger)totalCount
                  imageIdentifier:(NSString *)imageIdentifier
                      contentMode:(UIViewContentMode)contentMode;
- (void)setThumbnailImage:(UIImage *)image;
- (void)applyGallerySelected:(BOOL)selected animated:(BOOL)animated;
- (void)refreshAppearance;

@end

@implementation PPImageGalleryThumbnailCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;

    _artworkContainerView = [[UIView alloc] init];
    _artworkContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _artworkContainerView.userInteractionEnabled = NO;
    _artworkContainerView.backgroundColor = UIColor.clearColor;
    [self.contentView addSubview:_artworkContainerView];

    _selectionSurfaceView = [[UIView alloc] init];
    _selectionSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _selectionSurfaceView.userInteractionEnabled = NO;
    _selectionSurfaceView.alpha = 0.0;
    _selectionSurfaceView.layer.borderWidth = 0.5;
    _selectionSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    _selectionSurfaceView.layer.shadowRadius = PPShadowSubtleRadius;
    _selectionSurfaceView.layer.shadowOpacity = 0.0;
    PPApplyContinuousCorners(_selectionSurfaceView, PPCornerMedium);
    [_artworkContainerView addSubview:_selectionSurfaceView];

    _thumbnailImageView = [[UIImageView alloc] init];
    _thumbnailImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _thumbnailImageView.contentMode = UIViewContentModeScaleAspectFill;
    _thumbnailImageView.clipsToBounds = YES;
    _thumbnailImageView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    _thumbnailImageView.layer.borderWidth = 0.5;
    PPApplyContinuousCorners(_thumbnailImageView, PPCornerSmall);
    _thumbnailImageView.isAccessibilityElement = NO;
    [_artworkContainerView addSubview:_thumbnailImageView];

    _selectionMarkerView = [[UIView alloc] init];
    _selectionMarkerView.translatesAutoresizingMaskIntoConstraints = NO;
    _selectionMarkerView.userInteractionEnabled = NO;
    _selectionMarkerView.alpha = 0.0;
    PPApplyContinuousCorners(_selectionMarkerView, PPCornerPill);
    [self.contentView addSubview:_selectionMarkerView];

    UIImageSymbolConfiguration *playConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:7.5
                                                        weight:UIImageSymbolWeightBold];
    _videoBadgeView = [[UIImageView alloc]
                       initWithImage:[[UIImage systemImageNamed:@"play.fill"]
                                      imageWithConfiguration:playConfiguration]];
    _videoBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    _videoBadgeView.tintColor = UIColor.whiteColor;
    _videoBadgeView.contentMode = UIViewContentModeCenter;
    _videoBadgeView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.56];
    _videoBadgeView.hidden = YES;
    _videoBadgeView.isAccessibilityElement = NO;
    PPApplyContinuousCorners(_videoBadgeView, PPCornerPill);
    [_artworkContainerView addSubview:_videoBadgeView];

    [NSLayoutConstraint activateConstraints:@[
        [_artworkContainerView.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [_artworkContainerView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_artworkContainerView.widthAnchor constraintEqualToConstant:PPButtonHeightLG],
        [_artworkContainerView.heightAnchor constraintEqualToConstant:PPButtonHeightLG],

        [_selectionSurfaceView.topAnchor constraintEqualToAnchor:_artworkContainerView.topAnchor],
        [_selectionSurfaceView.leadingAnchor constraintEqualToAnchor:_artworkContainerView.leadingAnchor],
        [_selectionSurfaceView.trailingAnchor constraintEqualToAnchor:_artworkContainerView.trailingAnchor],
        [_selectionSurfaceView.bottomAnchor constraintEqualToAnchor:_artworkContainerView.bottomAnchor],

        [_thumbnailImageView.centerXAnchor constraintEqualToAnchor:_artworkContainerView.centerXAnchor],
        [_thumbnailImageView.centerYAnchor constraintEqualToAnchor:_artworkContainerView.centerYAnchor],
        [_thumbnailImageView.widthAnchor constraintEqualToConstant:PPImageGalleryThumbnailImageSize],
        [_thumbnailImageView.heightAnchor constraintEqualToConstant:PPImageGalleryThumbnailImageSize],

        [_selectionMarkerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:1.0],
        [_selectionMarkerView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_selectionMarkerView.widthAnchor constraintEqualToConstant:3.0],
        [_selectionMarkerView.heightAnchor constraintEqualToConstant:18.0],

        [_videoBadgeView.trailingAnchor constraintEqualToAnchor:_thumbnailImageView.trailingAnchor constant:-3.0],
        [_videoBadgeView.bottomAnchor constraintEqualToAnchor:_thumbnailImageView.bottomAnchor constant:-3.0],
        [_videoBadgeView.widthAnchor constraintEqualToConstant:17.0],
        [_videoBadgeView.heightAnchor constraintEqualToConstant:17.0]
    ]];

    [self refreshAppearance];
    [self applyGallerySelected:NO animated:NO];
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self.layer removeAllAnimations];
    [self.contentView.layer removeAllAnimations];
    [self.artworkContainerView.layer removeAllAnimations];
    [self.selectionSurfaceView.layer removeAllAnimations];
    [self.selectionMarkerView.layer removeAllAnimations];
    [self.thumbnailImageView.layer removeAllAnimations];
    [self.videoBadgeView.layer removeAllAnimations];
    self.representedIdentifier = nil;
    self.thumbnailImageView.image = nil;
    self.videoBadgeView.hidden = YES;
    self.artworkContainerView.transform = CGAffineTransformIdentity;
    [self applyGallerySelected:NO animated:NO];
}

- (void)configureWithPlaceholder:(UIImage *)placeholder
                          isVideo:(BOOL)isVideo
                            index:(NSInteger)index
                       totalCount:(NSInteger)totalCount
                  imageIdentifier:(NSString *)imageIdentifier
                      contentMode:(UIViewContentMode)contentMode
{
    self.representedIdentifier = imageIdentifier ?: @"";
    self.thumbnailImageView.image = placeholder;
    self.thumbnailImageView.contentMode = contentMode == UIViewContentModeScaleAspectFit
        ? UIViewContentModeScaleAspectFit
        : UIViewContentModeScaleAspectFill;
    self.videoBadgeView.hidden = !(PPReusableVideoMediaEnabled() && isVideo);
    self.accessibilityIdentifier = [NSString stringWithFormat:@"PPImageGalleryThumbnail_%ld", (long)index];
    self.accessibilityLabel = [NSString stringWithFormat:kLang(@"image_gallery_page_format"),
                               (long)(index + 1),
                               (long)totalCount];
    self.accessibilityHint = kLang(@"image_gallery_thumbnail_hint");
}

- (void)setThumbnailImage:(UIImage *)image
{
    if (image) {
        self.thumbnailImageView.image = image;
    }
}

- (void)applyGallerySelected:(BOOL)selected animated:(BOOL)animated
{
    BOOL changed = self.gallerySelected != selected;
    self.gallerySelected = selected;
    self.accessibilityTraits = selected
        ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected)
        : UIAccessibilityTraitButton;

    void (^changes)(void) = ^{
        self.selectionSurfaceView.alpha = selected ? 1.0 : 0.0;
        self.selectionSurfaceView.transform = selected
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeScale(0.88, 0.88);
        self.selectionSurfaceView.layer.shadowOpacity = selected ? 0.16 : 0.0;
        self.selectionMarkerView.alpha = selected ? 1.0 : 0.0;
        self.selectionMarkerView.transform = selected
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeScale(1.0, 0.35);
        self.thumbnailImageView.alpha = selected ? 1.0 : 0.68;
        self.thumbnailImageView.transform = selected
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeScale(0.93, 0.93);
        self.thumbnailImageView.layer.borderWidth = selected ? 1.5 : 0.5;
    };

    if (animated && changed && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:PPAnimDurationNormal
                              delay:0.0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.28
                            options:UIViewAnimationOptionAllowUserInteraction |
                                    UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
    [self refreshAppearance];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.artworkContainerView.transform = CGAffineTransformIdentity;
        return;
    }

    CGFloat scale = highlighted ? 0.94 : 1.0;
    NSTimeInterval duration = highlighted ? PPAnimDurationFast : 0.20;
    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:highlighted ? 1.0 : 0.82
          initialSpringVelocity:highlighted ? 0.0 : 0.25
                        options:UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.artworkContainerView.transform = CGAffineTransformMakeScale(scale, scale);
    } completion:nil];
}

- (void)refreshAppearance
{
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *accent = AppPrimaryClr ?: UIColor.systemPinkColor;
    UIColor *resolvedAccent = [accent resolvedColorWithTraitCollection:self.traitCollection];
    UIColor *hairline = dark
        ? [UIColor colorWithWhite:1.0 alpha:0.20]
        : [UIColor colorWithWhite:0.0 alpha:0.12];

    self.selectionSurfaceView.backgroundColor = [resolvedAccent colorWithAlphaComponent:dark ? 0.20 : 0.14];
    self.selectionSurfaceView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:dark ? 0.22 : 0.48].CGColor;
    self.selectionSurfaceView.layer.shadowColor = [resolvedAccent colorWithAlphaComponent:0.70].CGColor;
    self.selectionMarkerView.backgroundColor = resolvedAccent;
    self.thumbnailImageView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.thumbnailImageView.layer.borderColor = self.gallerySelected
        ? [resolvedAccent colorWithAlphaComponent:0.96].CGColor
        : hairline.CGColor;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self refreshAppearance];
}

@end

@interface PPImageGalleryThumbnailRailView : UIView
<UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UIVisualEffectView *materialView;
@property (nonatomic, strong) UIView *toneView;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<PetImageItem *> *imageItems;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *imageCache;
@property (nonatomic, assign) UIViewContentMode thumbnailContentMode;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, assign) NSInteger pendingFocusIndex;
@property (nonatomic, assign) BOOL pendingFocusAnimated;
@property (nonatomic, copy) void (^onSelectIndex)(NSInteger index);

- (instancetype)initWithImageCache:(NSCache<NSString *, UIImage *> *)imageCache;
- (void)reloadWithImageItems:(NSArray<PetImageItem *> *)imageItems
                 contentMode:(UIViewContentMode)contentMode
               selectedIndex:(NSInteger)selectedIndex;
- (void)setSelectedIndex:(NSInteger)selectedIndex
                animated:(BOOL)animated
           focusIfNeeded:(BOOL)focusIfNeeded;
- (CGFloat)preferredHeightForAvailableHeight:(CGFloat)availableHeight;
- (void)updateAccessibilityForPage:(NSInteger)page totalCount:(NSInteger)totalCount;
- (void)refreshAppearance;
- (void)pp_focusPendingSelectionIfPossible;
- (void)pp_accessibilityPreferencesDidChange:(NSNotification *)notification;

@end


@implementation PPImageGalleryThumbnailRailView

- (instancetype)initWithImageCache:(NSCache<NSString *, UIImage *> *)imageCache
{
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    _imageCache = imageCache;
    _imageItems = @[];
    _selectedIndex = 0;
    _pendingFocusIndex = NSNotFound;
    _thumbnailContentMode = UIViewContentModeScaleAspectFill;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.isAccessibilityElement = NO;
    self.accessibilityIdentifier = @"PPImageGalleryThumbnailRail";
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    PPApplyContinuousCorners(self, PPCornerCard);

    UIBlurEffect *materialEffect =
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    _materialView = [[UIVisualEffectView alloc] initWithEffect:materialEffect];
    _materialView.translatesAutoresizingMaskIntoConstraints = NO;
    _materialView.userInteractionEnabled = NO;
    _materialView.clipsToBounds = YES;
    _materialView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    PPApplyContinuousCorners(_materialView, PPCornerCard);
    [self addSubview:_materialView];

    _toneView = [[UIView alloc] init];
    _toneView.translatesAutoresizingMaskIntoConstraints = NO;
    _toneView.userInteractionEnabled = NO;
    [_materialView.contentView addSubview:_toneView];

    UICollectionViewFlowLayout *railLayout = [[UICollectionViewFlowLayout alloc] init];
    railLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
    railLayout.minimumLineSpacing = PPImageGalleryThumbnailSpacing;
    railLayout.minimumInteritemSpacing = 0.0;
    railLayout.sectionInset = UIEdgeInsetsMake(PPImageGalleryThumbnailSectionInset,
                                               0.0,
                                               PPImageGalleryThumbnailSectionInset,
                                               0.0);

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero
                                          collectionViewLayout:railLayout];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    _collectionView.backgroundColor = UIColor.clearColor;
    _collectionView.showsVerticalScrollIndicator = NO;
    _collectionView.showsHorizontalScrollIndicator = NO;
    _collectionView.alwaysBounceVertical = NO;
    _collectionView.decelerationRate = UIScrollViewDecelerationRateFast;
    _collectionView.contentInset = UIEdgeInsetsZero;
    _collectionView.scrollIndicatorInsets = UIEdgeInsetsZero;
    _collectionView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    _collectionView.clipsToBounds = YES;
    if (@available(iOS 11.0, *)) {
        _collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [_collectionView registerClass:PPImageGalleryThumbnailCell.class
        forCellWithReuseIdentifier:PPImageGalleryThumbnailCellIdentifier];
    [self addSubview:_collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [_materialView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_materialView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_materialView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_materialView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [_toneView.topAnchor constraintEqualToAnchor:_materialView.contentView.topAnchor],
        [_toneView.leadingAnchor constraintEqualToAnchor:_materialView.contentView.leadingAnchor],
        [_toneView.trailingAnchor constraintEqualToAnchor:_materialView.contentView.trailingAnchor],
        [_toneView.bottomAnchor constraintEqualToAnchor:_materialView.contentView.bottomAnchor],

        [_collectionView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_collectionView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_collectionView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_collectionView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(pp_accessibilityPreferencesDidChange:)
               name:UIAccessibilityReduceTransparencyStatusDidChangeNotification
             object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(pp_accessibilityPreferencesDidChange:)
               name:UIAccessibilityReduceMotionStatusDidChangeNotification
             object:nil];

    [self refreshAppearance];
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reloadWithImageItems:(NSArray<PetImageItem *> *)imageItems
                 contentMode:(UIViewContentMode)contentMode
               selectedIndex:(NSInteger)selectedIndex
{
    self.imageItems = imageItems ?: @[];
    self.thumbnailContentMode = contentMode;
    self.selectedIndex = self.imageItems.count > 0
        ? MIN(MAX(selectedIndex, 0), (NSInteger)self.imageItems.count - 1)
        : 0;
    self.pendingFocusIndex = self.imageItems.count > 0 ? self.selectedIndex : NSNotFound;
    self.pendingFocusAnimated = NO;
    [self.collectionView reloadData];
    [self.collectionView.collectionViewLayout invalidateLayout];
    [self setNeedsLayout];
}

- (CGFloat)preferredHeightForAvailableHeight:(CGFloat)availableHeight
{
    NSInteger count = self.imageItems.count;
    CGFloat minimumHeight = PPImageGalleryThumbnailCellHeight +
        (PPImageGalleryThumbnailSectionInset * 2.0);
    CGFloat contentHeight = (count * PPImageGalleryThumbnailCellHeight) +
        (MAX(count - 1, 0) * PPImageGalleryThumbnailSpacing) +
        (PPImageGalleryThumbnailSectionInset * 2.0);
    CGFloat usableHeight = MAX(minimumHeight, availableHeight);
    return MAX(minimumHeight,
               MIN(contentHeight,
                   MIN(PPImageGalleryThumbnailRailMaximumHeight, usableHeight)));
}

- (void)setSelectedIndex:(NSInteger)selectedIndex
                animated:(BOOL)animated
           focusIfNeeded:(BOOL)focusIfNeeded
{
    NSInteger count = self.imageItems.count;
    if (count <= 0) {
        self.selectedIndex = 0;
        self.pendingFocusIndex = NSNotFound;
        self.pendingFocusAnimated = NO;
        return;
    }

    NSInteger safeIndex = MIN(MAX(selectedIndex, 0), count - 1);
    BOOL changed = self.selectedIndex != safeIndex;
    self.selectedIndex = safeIndex;
    for (NSIndexPath *indexPath in self.collectionView.indexPathsForVisibleItems) {
        PPImageGalleryThumbnailCell *cell =
            (PPImageGalleryThumbnailCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        [cell applyGallerySelected:(indexPath.item == safeIndex)
                          animated:(animated && changed)];
    }

    if (focusIfNeeded) {
        self.pendingFocusIndex = safeIndex;
        self.pendingFocusAnimated = animated;
        [self setNeedsLayout];
    } else {
        // A direct thumbnail tap owns selection but must preserve the user's
        // rail offset. Cancel any deferred focus left by an older transition.
        self.pendingFocusIndex = NSNotFound;
        self.pendingFocusAnimated = NO;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                       cornerRadius:PPCornerCard].CGPath;
    self.collectionView.alwaysBounceVertical =
        self.collectionView.contentSize.height > CGRectGetHeight(self.collectionView.bounds) + 1.0;
    [self pp_focusPendingSelectionIfPossible];
}

- (void)pp_focusPendingSelectionIfPossible
{
    NSInteger targetIndex = self.pendingFocusIndex;
    if (targetIndex == NSNotFound ||
        targetIndex < 0 ||
        targetIndex >= (NSInteger)self.imageItems.count ||
        self.collectionView.dragging ||
        self.collectionView.decelerating) {
        return;
    }

    NSIndexPath *targetPath = [NSIndexPath indexPathForItem:targetIndex inSection:0];
    UICollectionViewLayoutAttributes *attributes =
        [self.collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:targetPath];
    if (!attributes) {
        [self.collectionView layoutIfNeeded];
        attributes =
            [self.collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:targetPath];
    }
    if (!attributes) return;

    self.pendingFocusIndex = NSNotFound;
    CGRect visibleRect = (CGRect){ self.collectionView.contentOffset,
                                  self.collectionView.bounds.size };
    CGRect comfortableVisibleRect = CGRectInset(visibleRect,
                                                0.0,
                                                PPImageGalleryThumbnailFocusInset);
    if (CGRectContainsRect(comfortableVisibleRect, attributes.frame)) {
        return;
    }

    UIEdgeInsets adjustedInset = self.collectionView.adjustedContentInset;
    CGFloat minimumOffsetY = -adjustedInset.top;
    CGFloat maximumOffsetY = MAX(minimumOffsetY,
                                 self.collectionView.contentSize.height -
                                 CGRectGetHeight(self.collectionView.bounds) +
                                 adjustedInset.bottom);
    CGFloat targetOffsetY = self.collectionView.contentOffset.y;
    if (CGRectGetMinY(attributes.frame) < CGRectGetMinY(comfortableVisibleRect)) {
        targetOffsetY = CGRectGetMinY(attributes.frame) - PPImageGalleryThumbnailFocusInset;
    } else if (CGRectGetMaxY(attributes.frame) > CGRectGetMaxY(comfortableVisibleRect)) {
        targetOffsetY = CGRectGetMaxY(attributes.frame) -
            CGRectGetHeight(self.collectionView.bounds) +
            PPImageGalleryThumbnailFocusInset;
    }
    targetOffsetY = MIN(MAX(targetOffsetY, minimumOffsetY), maximumOffsetY);
    if (fabs(targetOffsetY - self.collectionView.contentOffset.y) < 0.5) return;

    BOOL shouldAnimate = self.pendingFocusAnimated &&
        self.window != nil &&
        !UIAccessibilityIsReduceMotionEnabled();
    [self.collectionView setContentOffset:CGPointMake(self.collectionView.contentOffset.x,
                                                      targetOffsetY)
                                  animated:shouldAnimate];
}

- (void)updateAccessibilityForPage:(NSInteger)page totalCount:(NSInteger)totalCount
{
    self.collectionView.accessibilityLabel = kLang(@"image_gallery_accessibility_label");
    if (totalCount <= 0) {
        self.collectionView.accessibilityValue = nil;
        return;
    }
    NSInteger safePage = MIN(MAX(page, 0), totalCount - 1);
    self.collectionView.accessibilityValue =
        [NSString stringWithFormat:kLang(@"image_gallery_page_format"),
         (long)(safePage + 1),
         (long)totalCount];
}

- (void)refreshAppearance
{
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    BOOL reduceTransparency = UIAccessibilityIsReduceTransparencyEnabled();
    self.materialView.effect = reduceTransparency
        ? nil
        : [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = dark ? 0.28 : 0.13;
    self.layer.shadowRadius = dark ? 24.0 : 20.0;
    self.layer.shadowOffset = CGSizeMake(0.0, dark ? 11.0 : 9.0);
    self.layer.borderWidth = 0.5;
    self.layer.borderColor = dark
        ? [UIColor colorWithWhite:1.0 alpha:0.16].CGColor
        : [UIColor colorWithWhite:1.0 alpha:0.66].CGColor;
    if (reduceTransparency) {
        UIColor *solidSurface = AppForgroundColr ?: UIColor.systemBackgroundColor;
        self.toneView.backgroundColor = [solidSurface colorWithAlphaComponent:0.97];
    } else {
        self.toneView.backgroundColor = dark
            ? [[UIColor blackColor] colorWithAlphaComponent:0.10]
            : [[UIColor whiteColor] colorWithAlphaComponent:0.16];
    }
    for (PPImageGalleryThumbnailCell *cell in self.collectionView.visibleCells) {
        [cell refreshAppearance];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self refreshAppearance];
}

- (void)pp_accessibilityPreferencesDidChange:(NSNotification *)notification
{
    (void)notification;
    [self refreshAppearance];
    for (NSIndexPath *indexPath in self.collectionView.indexPathsForVisibleItems) {
        PPImageGalleryThumbnailCell *cell =
            (PPImageGalleryThumbnailCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        cell.artworkContainerView.transform = CGAffineTransformIdentity;
        [cell applyGallerySelected:(indexPath.item == self.selectedIndex) animated:NO];
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return self.imageItems.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    PPImageGalleryThumbnailCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:PPImageGalleryThumbnailCellIdentifier
                                                  forIndexPath:indexPath];
    PetImageItem *item = self.imageItems[indexPath.item];
    NSString *itemURL = item.url ?: @"";
    UIImage *placeholder = nil;
    if (item.blurHash.length > 0) {
        placeholder = [PPBlurHashBridge imageFrom:item.blurHash
                                         syncSize:CGSizeMake(28.0, 28.0)
                                            punch:1.0];
    }
    placeholder = placeholder ?: [UIImage imageNamed:@"placeholder"];
    [cell configureWithPlaceholder:placeholder
                           isVideo:item.isVideoMedia
                             index:indexPath.item
                        totalCount:self.imageItems.count
                   imageIdentifier:itemURL
                       contentMode:self.thumbnailContentMode];
    [cell applyGallerySelected:(indexPath.item == self.selectedIndex) animated:NO];

    UIImage *cachedImage = itemURL.length > 0 ? [self.imageCache objectForKey:itemURL] : nil;
    if (cachedImage) {
        [cell setThumbnailImage:cachedImage];
        return cell;
    }
    if (itemURL.length == 0) return cell;

    __weak typeof(self) weakSelf = self;
    __weak PPImageGalleryThumbnailCell *weakCell = cell;
    [[PPImageLoaderManager shared] fetchImageWithURL:itemURL
                                          completion:^(UIImage * _Nullable image) {
        if (!image) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            PPImageGalleryThumbnailCell *cell = weakCell;
            if (!self || !cell ||
                ![cell.representedIdentifier isEqualToString:itemURL]) {
                return;
            }
            [self.imageCache setObject:image forKey:itemURL];
            [cell setThumbnailImage:image];
        });
    }];
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.item < 0 || indexPath.item >= (NSInteger)self.imageItems.count) return;
    if (self.onSelectIndex) {
        self.onSelectIndex(indexPath.item);
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                   layout:(UICollectionViewLayout *)collectionViewLayout
   sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return CGSizeMake(MAX(PPImageGalleryThumbnailRailWidth,
                          CGRectGetWidth(collectionView.bounds)),
                      PPImageGalleryThumbnailCellHeight);
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        [self pp_focusPendingSelectionIfPossible];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self pp_focusPendingSelectionIfPossible];
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
@property (nonatomic, strong) id currentModel;
@property (nonatomic, strong) PPImageGalleryThumbnailRailView *thumbnailRailView;
@property (nonatomic, strong) NSLayoutConstraint *thumbnailRailHeightConstraint;

@property (nonatomic, strong) NSCache<NSString *, UIImage *> *imageCache;
@property (nonatomic, assign) BOOL pp_didPrepareGalleryEntranceAnimation;
@property (nonatomic, assign) BOOL pp_didRunGalleryEntranceAnimation;
@property (nonatomic, assign) BOOL pp_didNormalizeInitialLayout;
@property (nonatomic, assign) CGSize pp_lastLaidOutCollectionSize;
@property (nonatomic, assign) NSInteger pp_lastSettledPageIndex;
@property (nonatomic, assign) NSInteger pp_pendingProgrammaticPageIndex;
@property (nonatomic, assign) BOOL pp_pendingProgrammaticPageShouldNotify;
@property (nonatomic, assign) BOOL pp_pendingProgrammaticPageShouldHaptic;
@property (nonatomic, assign) BOOL pp_pendingProgrammaticPageShouldFocusRail;
@property (nonatomic, strong) UISelectionFeedbackGenerator *pp_selectionFeedbackGenerator;

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
- (BOOL)pp_imageItems:(NSArray<PetImageItem *> *)lhs haveSameIdentityAs:(NSArray<PetImageItem *> *)rhs;
- (BOOL)pp_shouldShowThumbnailRail;
- (void)pp_setupThumbnailRail;
- (void)pp_rebuildThumbnailRail;
- (void)pp_updateThumbnailRailLayout;
- (void)pp_updateThumbnailSelectionForPage:(NSInteger)page animated:(BOOL)animated scrollToVisible:(BOOL)scrollToVisible;
- (void)pp_setCurrentPageIndex:(NSInteger)page
                       animated:(BOOL)animated
                         notify:(BOOL)notify
                         haptic:(BOOL)haptic
              scrollRailIntoView:(BOOL)scrollRailIntoView;
- (NSInteger)pp_currentNearestPageIndex;
- (void)pp_scrollToPage:(NSInteger)page
               animated:(BOOL)animated
         notifyOnSettle:(BOOL)notifyOnSettle
         hapticOnSettle:(BOOL)hapticOnSettle
      focusRailIfNeeded:(BOOL)focusRailIfNeeded;
- (void)pp_cancelPendingProgrammaticPageTransition;
- (void)pp_applyCurrentLanguageDirection;

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
    _pp_lastSettledPageIndex = items.count > 0 ? 0 : NSNotFound;
    _pp_pendingProgrammaticPageIndex = NSNotFound;

    // 🔑 SINGLE SOURCE OF TRUTH
    _imageItems = items ?: @[];

    // Layout helpers
    _imageSizes = [NSMutableDictionary dictionary];

    // UI
    self.backgroundColor = UIColor.clearColor;
    [self pp_applyCurrentLanguageDirection];
    [self setupCollectionView];

    return self;
}


- (void)setupCollectionView {
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    //layout.itemSize = CGSizeMake(self.frame.size.width, 300);
    //layout.minimumLineSpacing = 0;

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    // Keep model indices stable while UIKit mirrors physical paging for Arabic.
    _collectionView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
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
        [self pp_setupThumbnailRail];
    }
    [self pp_prepareGalleryEntranceAnimationIfNeeded];
}

// layoutSubviews keeps the side thumbnail rail fitted to the current hero size.

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self pp_applyCurrentLanguageDirection];
        [self.thumbnailRailView refreshAppearance];
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
    if (self.pp_pendingProgrammaticPageIndex != NSNotFound) {
        targetIndex = self.pp_pendingProgrammaticPageIndex;
    }

    UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    flowLayout.itemSize = pageSize;
    flowLayout.minimumLineSpacing = 0.0;
    flowLayout.minimumInteritemSpacing = 0.0;
    [flowLayout invalidateLayout];
    [self.collectionView layoutIfNeeded];

    if (self.imageItems.count > 0) {
        targetIndex = MIN(MAX(targetIndex, 0), (NSInteger)self.imageItems.count - 1);
        BOOL finalizesPendingTransition = self.pp_pendingProgrammaticPageIndex != NSNotFound;
        BOOL pendingShouldNotify = self.pp_pendingProgrammaticPageShouldNotify;
        BOOL pendingShouldHaptic = self.pp_pendingProgrammaticPageShouldHaptic;
        BOOL pendingShouldFocusRail = self.pp_pendingProgrammaticPageShouldFocusRail;
        NSIndexPath *targetPath = [NSIndexPath indexPathForItem:targetIndex inSection:0];
        [UIView performWithoutAnimation:^{
            [self.collectionView scrollToItemAtIndexPath:targetPath
                                        atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                                animated:NO];
        }];
        if (finalizesPendingTransition) {
            [self pp_cancelPendingProgrammaticPageTransition];
        }
        [self pp_setCurrentPageIndex:targetIndex
                            animated:NO
                              notify:(finalizesPendingTransition && pendingShouldNotify)
                              haptic:(finalizesPendingTransition && pendingShouldHaptic)
                  scrollRailIntoView:(finalizesPendingTransition && pendingShouldFocusRail)];
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
    if (self.thumbnailRailView) {
        [self.thumbnailRailView reloadWithImageItems:self.imageItems
                                         contentMode:contentMode
                                       selectedIndex:self.currentPagr];
    }
    [self.collectionView reloadData];
}

- (void)setHidesPageControl:(BOOL)hidesPageControl
{
    if (_hidesPageControl == hidesPageControl) {
        return;
    }

    _hidesPageControl = hidesPageControl;
    if ([self pp_shouldShowThumbnailRail] && !self.thumbnailRailView) {
        [self pp_setupThumbnailRail];
    }
    self.thumbnailRailView.hidden = ![self pp_shouldShowThumbnailRail];
    if (!hidesPageControl) {
        [self pp_rebuildThumbnailRail];
        if (self.pp_didRunGalleryEntranceAnimation || UIAccessibilityIsReduceMotionEnabled()) {
            self.thumbnailRailView.alpha = 1.0;
            self.thumbnailRailView.transform = CGAffineTransformIdentity;
        }
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
 
- (void)pp_setupThumbnailRail
{
    if (self.thumbnailRailView) {
        self.thumbnailRailView.hidden = ![self pp_shouldShowThumbnailRail];
        [self pp_rebuildThumbnailRail];
        return;
    }

    self.thumbnailRailView =
        [[PPImageGalleryThumbnailRailView alloc] initWithImageCache:self.imageCache];
    self.thumbnailRailView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.thumbnailRailView.shouldGroupAccessibilityChildren = YES;
    __weak typeof(self) weakSelf = self;
    self.thumbnailRailView.onSelectIndex = ^(NSInteger index) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || index < 0 || index >= (NSInteger)self.imageItems.count) return;
        [self pp_scrollToPage:index
                     animated:YES
               notifyOnSettle:YES
              hapticOnSettle:YES
           focusRailIfNeeded:NO];
    };
    [self addSubview:self.thumbnailRailView];

    self.thumbnailRailHeightConstraint =
        [self.thumbnailRailView.heightAnchor constraintEqualToConstant:
         PPImageGalleryThumbnailCellHeight + (PPImageGalleryThumbnailSectionInset * 2.0)];
    NSLayoutConstraint *topLimit =
        [self.thumbnailRailView.topAnchor constraintGreaterThanOrEqualToAnchor:self.safeAreaLayoutGuide.topAnchor
                                                                       constant:PPImageGalleryThumbnailRailVerticalInset];
    NSLayoutConstraint *bottomLimit =
        [self.thumbnailRailView.bottomAnchor constraintLessThanOrEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor
                                                                       constant:-PPImageGalleryThumbnailRailVerticalInset];
    topLimit.priority = UILayoutPriorityDefaultHigh;
    bottomLimit.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [self.thumbnailRailView.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor
                                                                constant:-PPImageGalleryThumbnailRailHorizontalInset],
        [self.thumbnailRailView.centerYAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.centerYAnchor],
        [self.thumbnailRailView.widthAnchor constraintEqualToConstant:PPImageGalleryThumbnailRailWidth],
        self.thumbnailRailHeightConstraint,
        topLimit,
        bottomLimit
    ]];

    self.thumbnailRailView.hidden = ![self pp_shouldShowThumbnailRail];
    [self pp_rebuildThumbnailRail];
    [self pp_updateGalleryAccessibilityForPage:self.currentPagr];
}

- (void)pp_updateGalleryAccessibilityForPage:(NSInteger)page
{
    NSInteger count = self.imageItems.count;
    [self.thumbnailRailView updateAccessibilityForPage:page totalCount:count];
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
    if (!self.thumbnailRailView) return;
    self.thumbnailRailView.hidden = ![self pp_shouldShowThumbnailRail];
    [self.thumbnailRailView reloadWithImageItems:self.imageItems
                                     contentMode:self.contentMode
                                   selectedIndex:self.currentPagr];
    [self pp_updateThumbnailRailLayout];
    [self pp_updateGalleryAccessibilityForPage:self.currentPagr];
}

- (void)pp_updateThumbnailRailLayout
{
    if (!self.thumbnailRailView || !self.thumbnailRailHeightConstraint) return;
    self.thumbnailRailView.hidden = ![self pp_shouldShowThumbnailRail];
    if (self.thumbnailRailView.hidden) return;

    CGFloat safeHeight = MAX(0.0,
                             CGRectGetHeight(self.bounds) -
                             self.safeAreaInsets.top -
                             self.safeAreaInsets.bottom);
    CGFloat availableHeight = MAX(PPImageGalleryThumbnailCellHeight +
                                  (PPImageGalleryThumbnailSectionInset * 2.0),
                                  safeHeight -
                                  (PPImageGalleryThumbnailRailVerticalInset * 2.0));
    CGFloat targetHeight =
        [self.thumbnailRailView preferredHeightForAvailableHeight:availableHeight];
    if (fabs(self.thumbnailRailHeightConstraint.constant - targetHeight) > 0.5) {
        self.thumbnailRailHeightConstraint.constant = targetHeight;
        [self.thumbnailRailView setSelectedIndex:self.currentPagr
                                        animated:NO
                                   focusIfNeeded:YES];
    }
}

- (void)pp_updateThumbnailSelectionForPage:(NSInteger)page animated:(BOOL)animated scrollToVisible:(BOOL)scrollToVisible
{
    if (!self.thumbnailRailView || self.imageItems.count == 0) return;
    NSInteger safePage = MIN(MAX(page, 0), (NSInteger)self.imageItems.count - 1);
    [self.thumbnailRailView setSelectedIndex:safePage
                                    animated:animated
                               focusIfNeeded:scrollToVisible];
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

    CGFloat visibleCenterX = self.collectionView.contentOffset.x +
        CGRectGetMidX(self.collectionView.bounds);
    NSInteger nearestIndex = NSNotFound;
    CGFloat nearestDistance = CGFLOAT_MAX;
    for (NSIndexPath *indexPath in self.collectionView.indexPathsForVisibleItems) {
        UICollectionViewLayoutAttributes *attributes =
            [self.collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
        if (!attributes) continue;
        CGFloat distance = fabs(attributes.center.x - visibleCenterX);
        if (distance < nearestDistance) {
            nearestDistance = distance;
            nearestIndex = indexPath.item;
        }
    }
    if (nearestIndex != NSNotFound) {
        return MIN(MAX(nearestIndex, 0), count - 1);
    }
    return MIN(MAX(self.currentPagr, 0), count - 1);
}

- (void)pp_syncThumbnailRailWithVisiblePageDuringUserScroll
{
    if (self.pp_pendingProgrammaticPageIndex != NSNotFound) return;
    if (self.imageItems.count <= 1) return;
    if (!self.collectionView.dragging && !self.collectionView.decelerating) return;

    NSInteger page = [self pp_currentNearestPageIndex];
    if (page == self.currentPagr) return;

    [self pp_setCurrentPageIndex:page
                        animated:YES
                          notify:NO
                          haptic:NO
              scrollRailIntoView:YES];
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
    BOOL isNewSettledPage = self.pp_lastSettledPageIndex != safePage;
    self.currentPagr = safePage;
    [self pp_updateThumbnailSelectionForPage:safePage
                                    animated:animated
                             scrollToVisible:scrollRailIntoView];
    [self pp_updateGalleryAccessibilityForPage:safePage];
    if (haptic && isNewSettledPage) {
        [self pp_emitSwipeFeedbackIfNeededForPage:safePage];
    } else if (notify && isNewSettledPage) {
        self.pp_lastSettledPageIndex = safePage;
    }
    if (notify && isNewSettledPage && self.onPageChanged) {
        self.onPageChanged(safePage);
    }
}

- (void)pp_scrollToPage:(NSInteger)page
               animated:(BOOL)animated
         notifyOnSettle:(BOOL)notifyOnSettle
        hapticOnSettle:(BOOL)hapticOnSettle
      focusRailIfNeeded:(BOOL)focusRailIfNeeded
{
    if (page < 0 || page >= (NSInteger)self.imageItems.count) return;
    [self.collectionView layoutIfNeeded];
    NSInteger visiblePage = [self pp_currentNearestPageIndex];
    BOOL alreadySettled = visiblePage == page &&
        !self.collectionView.dragging &&
        !self.collectionView.decelerating;
    BOOL effectiveAnimation = animated &&
        !alreadySettled &&
        self.window != nil &&
        !UIAccessibilityIsReduceMotionEnabled();

    [self pp_cancelPendingProgrammaticPageTransition];
    if (effectiveAnimation) {
        self.pp_pendingProgrammaticPageIndex = page;
        self.pp_pendingProgrammaticPageShouldNotify = notifyOnSettle;
        self.pp_pendingProgrammaticPageShouldHaptic = hapticOnSettle;
        self.pp_pendingProgrammaticPageShouldFocusRail = focusRailIfNeeded;
    }

    [self pp_setCurrentPageIndex:page
                        animated:effectiveAnimation
                          notify:(!effectiveAnimation && notifyOnSettle)
                          haptic:(!effectiveAnimation && hapticOnSettle)
              scrollRailIntoView:focusRailIfNeeded];

    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:page inSection:0];
    if (effectiveAnimation) {
        [self.collectionView scrollToItemAtIndexPath:indexPath
                                    atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                            animated:YES];
    } else {
        [UIView performWithoutAnimation:^{
            [self.collectionView scrollToItemAtIndexPath:indexPath
                                        atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                                animated:NO];
        }];
        [self pp_applySwipeMotionToVisibleCells];
    }
}

- (void)pp_cancelPendingProgrammaticPageTransition
{
    self.pp_pendingProgrammaticPageIndex = NSNotFound;
    self.pp_pendingProgrammaticPageShouldNotify = NO;
    self.pp_pendingProgrammaticPageShouldHaptic = NO;
    self.pp_pendingProgrammaticPageShouldFocusRail = NO;
}

- (void)pp_applyCurrentLanguageDirection
{
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;
    BOOL directionChanged = self.semanticContentAttribute != semantic;
    self.semanticContentAttribute = semantic;
    self.collectionView.semanticContentAttribute = semantic;
    self.thumbnailRailView.semanticContentAttribute = semantic;
    self.thumbnailRailView.collectionView.semanticContentAttribute = semantic;
    if (directionChanged && self.collectionView) {
        self.pp_didNormalizeInitialLayout = NO;
        self.pp_lastLaidOutCollectionSize = CGSizeZero;
        [self.collectionView.collectionViewLayout invalidateLayout];
        [self setNeedsLayout];
    }
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
        self.pp_lastSettledPageIndex = _imageItems.count > 0 ? self.currentPagr : NSNotFound;
        [self pp_cancelPendingProgrammaticPageTransition];
    }
    if ([self pp_shouldShowThumbnailRail] && !self.thumbnailRailView) {
        [self pp_setupThumbnailRail];
    }
    self.thumbnailRailView.hidden = ![self pp_shouldShowThumbnailRail];
    self.collectionView.backgroundView.hidden = _imageItems.count > 0;
    if (sameItems) {
        [self pp_updateThumbnailRailLayout];
        [self pp_updateThumbnailSelectionForPage:self.currentPagr animated:NO scrollToVisible:NO];
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

    imageView.contentMode = UIViewContentModeScaleAspectFit;
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
            self.thumbnailRailView.alpha = 1.0;
            self.thumbnailRailView.transform = CGAffineTransformIdentity;
        }
        return;
    }
    self.collectionView.alpha = 0.0;
    self.collectionView.transform =
    CGAffineTransformMakeScale(1.025, 1.025);
    if ([self pp_shouldShowThumbnailRail]) {
        CGFloat outwardOffset = Language.isRTL ? -PPSpaceSM : PPSpaceSM;
        self.thumbnailRailView.alpha = 0.0;
        self.thumbnailRailView.transform =
        CGAffineTransformScale(CGAffineTransformMakeTranslation(outwardOffset, PPSpaceXXS),
                               0.96,
                               0.96);
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
            self.thumbnailRailView.alpha = 1.0;
            self.thumbnailRailView.transform = CGAffineTransformIdentity;
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
            self.thumbnailRailView.alpha = 1.0;
            self.thumbnailRailView.transform = CGAffineTransformIdentity;
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

    if (!self.pp_selectionFeedbackGenerator) {
        self.pp_selectionFeedbackGenerator = [[UISelectionFeedbackGenerator alloc] init];
    }
    [self.pp_selectionFeedbackGenerator selectionChanged];
    [self.pp_selectionFeedbackGenerator prepare];
}

- (void)collectionView:(UICollectionView *)collectionView
       willDisplayCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath
{
    [self pp_updateGalleryAccessibilityForPage:self.currentPagr];
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
    if (scrollView != self.collectionView) return;
    [self pp_cancelPendingProgrammaticPageTransition];
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    if (!self.pp_selectionFeedbackGenerator) {
        self.pp_selectionFeedbackGenerator = [[UISelectionFeedbackGenerator alloc] init];
    }
    [self.pp_selectionFeedbackGenerator prepare];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) return;

    // Keep the thumbnail rail visually coupled to manual swipes. Notification
    // and haptic ownership still stays with the final settled page below.
    [self pp_syncThumbnailRailWithVisiblePageDuringUserScroll];
    [self pp_applySwipeMotionToVisibleCells];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView != self.collectionView) return;
    if (self.pp_pendingProgrammaticPageIndex != NSNotFound) return;
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
    if (self.pp_pendingProgrammaticPageIndex == NSNotFound) {
        return;
    }

    NSInteger targetPage = self.pp_pendingProgrammaticPageIndex;
    BOOL shouldNotify = self.pp_pendingProgrammaticPageShouldNotify;
    BOOL shouldHaptic = self.pp_pendingProgrammaticPageShouldHaptic;
    BOOL shouldFocusRail = self.pp_pendingProgrammaticPageShouldFocusRail;
    [self pp_cancelPendingProgrammaticPageTransition];
    if (targetPage < 0 || targetPage >= (NSInteger)self.imageItems.count) return;
    if ([self pp_currentNearestPageIndex] != targetPage) {
        NSIndexPath *targetPath = [NSIndexPath indexPathForItem:targetPage inSection:0];
        [UIView performWithoutAnimation:^{
            [self.collectionView scrollToItemAtIndexPath:targetPath
                                        atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                                animated:NO];
        }];
    }
    [self pp_setCurrentPageIndex:targetPage
                        animated:YES
                          notify:shouldNotify
                          haptic:shouldHaptic
              scrollRailIntoView:shouldFocusRail];
    [self pp_applySwipeMotionToVisibleCells];
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
    if (self.pp_pendingProgrammaticPageIndex != NSNotFound ||
        self.collectionView.dragging ||
        self.collectionView.decelerating) {
        return;
    }
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

    [self pp_setCurrentPageIndex:indexPath.item
                        animated:NO
                          notify:NO
                          haptic:NO
              scrollRailIntoView:NO];

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
    [self pp_scrollToPage:page
                 animated:animated
           notifyOnSettle:YES
          hapticOnSettle:NO
       focusRailIfNeeded:YES];
}

@end
