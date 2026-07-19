#import "BBDataViewFullDetailsCell.h"
#import "PPUniversalCellViewModel.h"
#import "FavoriteButton.h"
#import "PPImageLoaderManager.h"
#import "PetAd.h"
#import "PetAccessory.h"
#import "PetImageItem.h"
#import "PetImageGalleryView.h"
#import "ServiceModel.h"
#import "AdoptPetModel.h"
#import "VetModel.h"
#import "CartManager.h"
#import "UserManager.h"
#import "UserModel.h"
#import "PPModernAvatarRenderer.h"
#import "PPHUD.h"
#import "PPFunc.h"

static CGFloat const BBFullDetailsCardCornerRadius = 42.0;
static CGFloat const BBFullDetailsMediaCornerRadius = 32.0;
static CGFloat const BBFullDetailsContentInset = 28.0;
static CGFloat const BBFullDetailsMediaOuterInset = 28.0;
static CGFloat const BBFullDetailsMediaToContentSpacing = 16.0;
static CGFloat const BBFullDetailsContentBottomInset = 22.0;
static CGFloat const BBFullDetailsActionHeight = 44.0;
static CGFloat const BBFullDetailsStepperButtonSize = 34.0;
static NSTimeInterval const BBFullDetailsStepperAutoCollapseDelay = 3.5;

static UIColor *BBFullDetailsCardSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.095 green:0.098 blue:0.110 alpha:0.54];
            }
            return [(AppForgroundColr ?: UIColor.whiteColor) colorWithAlphaComponent:0.02];
        }];
    }
    return [(AppForgroundColr ?: UIColor.whiteColor) colorWithAlphaComponent:0.02];
}

static UIColor *BBFullDetailsCardBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.16];
            }
            return [UIColor colorWithWhite:1.0 alpha:0.92];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.92];
}

static UIColor *BBFullDetailsPlateSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.12];
            }
            return [UIColor colorWithWhite:1.0 alpha:0.58];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.58];
}

static UIColor *BBFullDetailsPlateBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.08];
            }
            return [UIColor colorWithWhite:0.0 alpha:0.055];
        }];
    }
    return [UIColor colorWithWhite:0.0 alpha:0.055];
}

static UIColor *BBFullDetailsImageBackgroundColor(void)
{
    return AppForgroundColr;
}

static UIColor *BBFullDetailsMediaStaticBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.16];
            }
            return [AppBackgroundClr colorWithAlphaComponent:0.72];
        }];
    }
    return [AppBackgroundClr colorWithAlphaComponent:0.72];
}

static NSString *BBFullDetailsLocalized(NSString *key)
{
    NSString *value = kLang(key);
    return value.length > 0 ? value : key;
}

static NSString *BBFullDetailsTrimmedString(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value stringValue];
    }
    return @"";
}

static BOOL BBFullDetailsIsPlaceholderText(id value)
{
    NSString *trimmed = BBFullDetailsTrimmedString(value).lowercaseString;
    return trimmed.length == 0 ||
           [trimmed isEqualToString:@"no_value"] ||
           [trimmed isEqualToString:@"null"] ||
           [trimmed isEqualToString:@"(null)"];
}

static NSString *BBFullDetailsCountText(NSInteger count)
{
    static NSNumberFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.maximumFractionDigits = 0;
    });
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    return [formatter stringFromNumber:@(MAX(count, 0))] ?: @(MAX(count, 0)).stringValue;
}

static void BBFullDetailsAppendUniqueURL(NSMutableArray<NSString *> *urls,
                                         NSMutableSet<NSString *> *seen,
                                         NSString *candidate)
{
    NSString *url = BBFullDetailsTrimmedString(candidate);
    if (url.length == 0 || [seen containsObject:url]) { return; }
    [seen addObject:url];
    [urls addObject:url];
}

static NSString *BBFullDetailsURLFromMediaDictionary(NSDictionary *media)
{
    if (![media isKindOfClass:NSDictionary.class]) { return @""; }
    NSString *mediaType = [BBFullDetailsTrimmedString(media[@"media_type"] ?: media[@"mediaType"] ?: media[@"type"] ?: media[@"mimeType"] ?: media[@"contentType"]) lowercaseString];
    BOOL isVideo = [mediaType isEqualToString:@"video"] || [mediaType hasPrefix:@"video/"] || [mediaType containsString:@"video"];
    if (isVideo) {
        NSString *thumbnail = BBFullDetailsTrimmedString(media[@"thumbnail_url"] ?: media[@"thumbnailURL"] ?: media[@"thumbnailUrl"] ?: media[@"display_url"] ?: media[@"displayURL"]);
        if (thumbnail.length > 0) { return thumbnail; }
    }
    NSString *url = BBFullDetailsTrimmedString(media[@"url"]);
    if (url.length == 0) { url = BBFullDetailsTrimmedString(media[@"display_url"]); }
    if (url.length == 0) { url = BBFullDetailsTrimmedString(media[@"displayURL"]); }
    if (url.length == 0) { url = BBFullDetailsTrimmedString(media[@"imageURL"]); }
    if (url.length == 0) { url = BBFullDetailsTrimmedString(media[@"imageUrl"]); }
    if (url.length == 0) { url = BBFullDetailsTrimmedString(media[@"thumbnail_url"]); }
    if (url.length == 0) { url = BBFullDetailsTrimmedString(media[@"thumbnailURL"]); }
    return url;
}

static NSDictionary *BBFullDetailsNormalizedMediaDictionary(NSDictionary *media)
{
    if (![media isKindOfClass:NSDictionary.class]) { return nil; }

    NSString *rawType = BBFullDetailsTrimmedString(media[@"media_type"] ?: media[@"mediaType"] ?: media[@"type"] ?: media[@"mimeType"] ?: media[@"contentType"]).lowercaseString;
    BOOL isVideo = [rawType isEqualToString:@"video"] || [rawType hasPrefix:@"video/"] || [rawType containsString:@"video"];
    NSString *displayURL = BBFullDetailsURLFromMediaDictionary(media);
    NSString *videoURL = BBFullDetailsTrimmedString(media[@"video_url"] ?: media[@"videoURL"] ?: media[@"videoUrl"]);
    if (videoURL.length == 0 && isVideo) {
        videoURL = BBFullDetailsTrimmedString(media[@"url"]);
    }

    if (displayURL.length == 0) { return nil; }
    if (isVideo && videoURL.length == 0) { return nil; }

    NSMutableDictionary *normalized = [NSMutableDictionary dictionary];
    normalized[@"media_type"] = isVideo ? @"video" : @"image";
    normalized[@"url"] = isVideo ? videoURL : displayURL;
    if (isVideo) {
        normalized[@"thumbnail_url"] = displayURL;
    }

    for (NSString *key in @[@"width", @"height", @"thumbnail_width", @"thumbnail_height", @"blurHash", @"duration"]) {
        id value = media[key];
        if (value) {
            normalized[key] = value;
        }
    }
    return normalized.copy;
}

@interface BBFullDetailsAmbientGlowView : UIView
@property (nonatomic, strong, readonly) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) UIColor *baseColor;
@property (nonatomic, assign) CGFloat lightAlpha;
@property (nonatomic, assign) CGFloat darkAlpha;
- (void)bb_updateGlowColors;
@end

@implementation BBFullDetailsAmbientGlowView

+ (Class)layerClass {
    return [CAGradientLayer class];
}

- (CAGradientLayer *)gradientLayer {
    return (CAGradientLayer *)self.layer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.gradientLayer.type = kCAGradientLayerRadial;
        self.gradientLayer.startPoint = CGPointMake(0.5, 0.5);
        self.gradientLayer.endPoint = CGPointMake(1.0, 1.0);
        _lightAlpha = 0.06;
        _darkAlpha = 0.10;
        _baseColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    }
    return self;
}

- (void)setBaseColor:(UIColor *)baseColor {
    _baseColor = baseColor;
    [self bb_updateGlowColors];
}

- (void)bb_updateGlowColors {
    BOOL isDark = NO;
    if (@available(iOS 13.0, *)) {
        isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }
    CGFloat alpha = isDark ? self.darkAlpha : self.lightAlpha;
    UIColor *centerColor = [self.baseColor colorWithAlphaComponent:alpha];
    UIColor *outerColor = [self.baseColor colorWithAlphaComponent:0.0];
    self.gradientLayer.colors = @[
        (id)centerColor.CGColor,
        (id)outerColor.CGColor
    ];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self bb_updateGlowColors];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self bb_updateGlowColors];
        }
    }
}

@end

@interface BBDataViewFullDetailsCell () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) BBFullDetailsAmbientGlowView *ambientGlowView1;
@property (nonatomic, strong) BBFullDetailsAmbientGlowView *ambientGlowView2;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) PetImageGalleryView *imageGallery;
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, strong) UIView *mediaContainerView;
@property (nonatomic, strong) NSLayoutConstraint *mediaTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *mediaBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *mediaCollapsedTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *mediaCollapsedHeightConstraint;
@property (nonatomic, strong) UIStackView *detailsStackView;
@property (nonatomic, strong) UIView *actionBarView;
@property (nonatomic, strong) UIButton *primaryButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) UIButton *ownerMenuButton;
@property (nonatomic, strong) UIButton *ownerChatButton;
@property (nonatomic, strong) NSLayoutConstraint *primaryButtonLeadingToShareConstraint;
@property (nonatomic, strong) NSLayoutConstraint *primaryButtonLeadingToActionBarConstraint;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UIStackView *priceRowStackView;
@property (nonatomic, strong) FavoriteFloatingButton *favoriteButton;
@property (nonatomic, strong) UIStackView *highlightPlateStackView;
@property (nonatomic, strong) UIStackView *socialMetricStackView;
@property (nonatomic, copy) NSArray<NSString *> *imageURLs;
@property (nonatomic, strong) UIImage *placeholderImage;
@property (nonatomic, strong) PPUniversalCellViewModel *viewModel;

@property (nonatomic, strong) UIView *ownerCapsuleBadgeView;
@property (nonatomic, strong) UIImageView *ownerAvatarImageView;
@property (nonatomic, strong) UILabel *ownerNameLabel;
@property (nonatomic, strong) UIView *ownerRatingContainerView;
@property (nonatomic, strong) UIImageView *ownerRatingStarIcon;
@property (nonatomic, strong) UILabel *ownerRatingLabel;

@property (nonatomic, strong) UIView *stepperView;
@property (nonatomic, strong) UIButton *minusButton;
@property (nonatomic, strong) UIButton *plusButton;
@property (nonatomic, strong) UILabel *quantityLabel;
@property (nonatomic, assign) NSInteger quantity;
@property (nonatomic, assign) BOOL isEditingQuantity;
@property (nonatomic, strong) NSTimer *stepperCollapseTimer;
@property (nonatomic, strong) NSMutableArray<UIView *> *reusablePlateViews;
@end

@implementation BBDataViewFullDetailsCell

+ (NSString *)reuseIdentifier
{
    return @"BBDataViewFullDetailsCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) { return nil; }
    [self bb_buildViewHierarchy];
    [self bb_applyStaticStyle];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bb_cartDidUpdate:)
                                                 name:kCartUpdatedNotification
                                               object:nil];
    return self;
}

- (void)dealloc
{
    [self.stepperCollapseTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self.stepperCollapseTimer invalidate];
    self.stepperCollapseTimer = nil;
    self.isEditingQuantity = NO;
    _quantity = 0;
    self.quantityLabel.text = @"0";
    self.stepperView.hidden = YES;
    self.stepperView.alpha = 0.0;
    self.primaryButton.alpha = 1.0;
    self.primaryButton.hidden = NO;

    self.delegate = nil;
    self.viewModel = nil;
    self.imageURLs = @[];
    self.placeholderImage = [UIImage imageNamed:@"placeholder"];
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.priceLabel.text = nil;
    self.titleLabel.accessibilityLabel = nil;
    self.subtitleLabel.accessibilityLabel = nil;
    self.priceLabel.accessibilityLabel = nil;
    self.favoriteButton.hidden = YES;
    self.favoriteButton.adID = nil;
    self.favoriteButton.collection = nil;
    [self bb_recyclePlateViewsFromStack:self.highlightPlateStackView];
    [self bb_recyclePlateViewsFromStack:self.socialMetricStackView];
    self.highlightPlateStackView.hidden = YES;
    self.socialMetricStackView.hidden = YES;
    self.cardView.transform = CGAffineTransformIdentity;
    self.cardView.alpha = 1.0;
    self.selected = NO;
    self.highlighted = NO;
    self.pageControl.numberOfPages = 0;
    self.pageControl.currentPage = 0;
    self.pageControl.hidden = YES;

    self.mediaContainerView.hidden = YES;
    self.mediaTopConstraint.active = NO;
    self.mediaBottomConstraint.active = NO;
    self.mediaCollapsedTopConstraint.active = YES;
    self.mediaCollapsedHeightConstraint.active = YES;
 

    [self bb_removeAllArrangedSubviewsFromStack:self.detailsStackView];
    [self.imageGallery removeFromSuperview];
    self.imageGallery = nil;
    [self.primaryButton setTitle:nil forState:UIControlStateNormal];
    [self.shareButton setTitle:nil forState:UIControlStateNormal];
    [self.ownerMenuButton setTitle:nil forState:UIControlStateNormal];
    self.actionBarView.hidden = YES;
    self.actionBarView.userInteractionEnabled = NO;
    self.shareButton.hidden = YES;
    self.ownerMenuButton.hidden = YES;
    self.ownerChatButton.hidden = YES;
    self.ownerMenuButton.menu = nil;
    self.ownerMenuButton.showsMenuAsPrimaryAction = NO;
    self.primaryButton.enabled = YES;
    self.shareButton.enabled = YES;
    self.ownerMenuButton.enabled = YES;
    self.ownerChatButton.enabled = NO;
    if (_ownerCapsuleBadgeView) {
        _ownerCapsuleBadgeView.hidden = YES;
        _ownerNameLabel.text = nil;
        _ownerAvatarImageView.image = nil;
        _ownerRatingContainerView.hidden = YES;
        _ownerRatingLabel.text = nil;
        _ownerChatButton.hidden = YES;
    }
    self.isEditingQuantity = NO;
    [self bb_setQuantity:0 animated:NO];
    self.stepperView.hidden = YES;
    self.stepperView.alpha = 0.0;
    self.stepperView.transform = CGAffineTransformIdentity;
    self.primaryButton.hidden = NO;
    self.primaryButton.alpha = 1.0;
    self.primaryButton.transform = CGAffineTransformIdentity;
    self.accessibilityLabel = nil;
    self.accessibilityValue = nil;
}

- (void)configureWithViewModel:(PPUniversalCellViewModel *)viewModel
                   imageLoader:(BBDataViewFullDetailsImageLoader)imageLoader
                      delegate:(id<BBDataViewFullDetailsCellDelegate>)delegate
{
    (void)imageLoader;
    self.viewModel = viewModel;
    self.delegate = delegate;
    self.placeholderImage = viewModel.placeholder ?: [UIImage imageNamed:@"placeholder"];

    if (viewModel.isSkeleton) {
        [self bb_configureLoadingState];
        return;
    }

    self.titleLabel.text = BBFullDetailsTrimmedString(viewModel.title);
    self.subtitleLabel.text = [self bb_descriptionSubtitleForViewModel:viewModel];
    self.subtitleLabel.hidden = self.subtitleLabel.text.length == 0;

    NSArray<PetImageItem *> *galleryItems = [self bb_imageItemsForViewModel:viewModel];
    self.imageURLs = [self bb_displayURLsFromImageItems:galleryItems];
    BOOL hasImages = galleryItems.count > 0;
    self.mediaContainerView.hidden = !hasImages;
    [self bb_updateMediaHeightForSize:self.bounds.size];
    self.pageControl.numberOfPages = galleryItems.count;
    self.pageControl.currentPage = 0;
    self.pageControl.hidden = galleryItems.count <= 1;

    if (hasImages) {
        [self bb_configureImageGalleryWithItems:galleryItems viewModel:viewModel];
    } else if (self.imageGallery) {
        [self.imageGallery removeFromSuperview];
        self.imageGallery = nil;
    }
    

    [self bb_buildDetailsForViewModel:viewModel];
    [self bb_configureActionsForViewModel:viewModel];
    [self setNeedsLayout];

    self.accessibilityLabel = self.titleLabel.text;
    self.accessibilityValue = [self bb_accessibilitySummaryForViewModel:viewModel];
}

- (void)setBounds:(CGRect)bounds
{
    CGRect oldBounds = self.bounds;
    [super setBounds:bounds];
    if (!CGSizeEqualToSize(oldBounds.size, bounds.size)) {
        [self bb_updateMediaHeightForSize:bounds.size];
    }
}

- (void)setFrame:(CGRect)frame
{
    CGRect oldFrame = self.frame;
    [super setFrame:frame];
    if (!CGSizeEqualToSize(oldFrame.size, frame.size)) {
        [self bb_updateMediaHeightForSize:frame.size];
    }
}

- (void)bb_updateMediaHeightForSize:(CGSize)size
{
    (void)size;
    if ( !self.mediaTopConstraint || !self.mediaBottomConstraint) {
        return;
    }

    BOOL hasImages = self.viewModel && !self.viewModel.isSkeleton && self.imageURLs.count > 0;
    if (!hasImages) {
        self.mediaTopConstraint.active = NO;
        self.mediaBottomConstraint.active = NO;
        self.mediaCollapsedTopConstraint.active = YES;
        self.mediaCollapsedHeightConstraint.active = YES;
        return;
    }

    self.mediaCollapsedTopConstraint.active = NO;
    self.mediaCollapsedHeightConstraint.active = NO;
    self.mediaTopConstraint.active = YES;
    self.mediaBottomConstraint.active = YES;
    [self setNeedsLayout];
}



- (void)layoutSubviews
{
    
    [super layoutSubviews];

    self.cardView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.cardView.bounds
                                   cornerRadius:BBFullDetailsCardCornerRadius].CGPath;
    self.surfaceView.layer.borderColor = BBFullDetailsCardBorderColor().CGColor;
    if (_ownerCapsuleBadgeView) {
        _ownerCapsuleBadgeView.layer.borderColor = BBFullDetailsPlateBorderColor().CGColor;
    }
    [self bb_applyStaticMediaBorder];
    
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            self.surfaceView.layer.borderColor = BBFullDetailsCardBorderColor().CGColor;
            [self bb_applyStaticMediaBorder];
            if (_ownerCapsuleBadgeView) {
                _ownerCapsuleBadgeView.layer.borderColor = BBFullDetailsPlateBorderColor().CGColor;
            }
        }
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self bb_applyPressedAppearance:highlighted || self.selected animated:YES];
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    [self bb_applyPressedAppearance:selected || self.highlighted animated:YES];
}

#pragma mark - Build

- (void)bb_buildViewHierarchy
{
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;

    _cardView = [[UIView alloc] init];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.clipsToBounds = NO;
    _cardView.isAccessibilityElement = NO;
    [self.contentView addSubview:_cardView];

    UIView *surfaceView = [[UIView alloc] init];
    surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    surfaceView.backgroundColor = [BBFullDetailsCardSurfaceColor() colorWithAlphaComponent:0.82];
    surfaceView.layer.cornerRadius = BBFullDetailsCardCornerRadius;
    surfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    surfaceView.layer.borderColor = BBFullDetailsCardBorderColor().CGColor;
    surfaceView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    surfaceView.tag = 90210;
    [_cardView addSubview:surfaceView];
    self.surfaceView = surfaceView;

    _ambientGlowView1 = [[BBFullDetailsAmbientGlowView alloc] initWithFrame:CGRectZero];
    _ambientGlowView1.translatesAutoresizingMaskIntoConstraints = NO;
    _ambientGlowView1.baseColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    _ambientGlowView1.lightAlpha = 0.06;
    _ambientGlowView1.darkAlpha = 0.10;
    [surfaceView insertSubview:_ambientGlowView1 atIndex:0];

    _ambientGlowView2 = [[BBFullDetailsAmbientGlowView alloc] initWithFrame:CGRectZero];
    _ambientGlowView2.translatesAutoresizingMaskIntoConstraints = NO;
    _ambientGlowView2.baseColor = [UIColor colorWithRed:0.63 green:0.40 blue:0.95 alpha:1.0];
    _ambientGlowView2.lightAlpha = 0.04;
    _ambientGlowView2.darkAlpha = 0.08;
    [surfaceView insertSubview:_ambientGlowView2 atIndex:1];

    [NSLayoutConstraint activateConstraints:@[
        [_ambientGlowView1.topAnchor constraintEqualToAnchor:surfaceView.bottomAnchor constant:-280.0],
        [_ambientGlowView1.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:10.0],
        [_ambientGlowView1.widthAnchor constraintEqualToConstant:280.0],
        [_ambientGlowView1.heightAnchor constraintEqualToConstant:280.0],

        [_ambientGlowView2.bottomAnchor constraintEqualToAnchor:surfaceView.bottomAnchor constant:40.0],
        [_ambientGlowView2.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:40.0],
        [_ambientGlowView2.widthAnchor constraintEqualToConstant:240.0],
        [_ambientGlowView2.heightAnchor constraintEqualToConstant:240.0]
    ]];

    _mediaContainerView = [[UIView alloc] init];
    _mediaContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _mediaContainerView.backgroundColor = BBFullDetailsImageBackgroundColor();
    _mediaContainerView.clipsToBounds = YES;
    _mediaContainerView.layer.cornerRadius = BBFullDetailsMediaCornerRadius;
    _mediaContainerView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _mediaContainerView.layer.borderColor = BBFullDetailsMediaStaticBorderColor().CGColor;
    if (@available(iOS 13.0, *)) {
        _mediaContainerView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [surfaceView addSubview:_mediaContainerView];

    _pageControl = [[UIPageControl alloc] init];
    _pageControl.translatesAutoresizingMaskIntoConstraints = NO;
    _pageControl.hidesForSinglePage = YES;
    _pageControl.userInteractionEnabled = NO;
    _pageControl.currentPageIndicatorTintColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    _pageControl.pageIndicatorTintColor = [AppBackgroundClrDarker colorWithAlphaComponent:0.55];
    [_mediaContainerView addSubview:_pageControl];

    _ownerMenuButton = [self bb_iconButtonWithSystemImageName:@"ellipsis"];
    _ownerMenuButton.hidden = YES;
    [_mediaContainerView addSubview:_ownerMenuButton];

    _actionBarView = [[UIView alloc] init];
    _actionBarView.translatesAutoresizingMaskIntoConstraints = NO;
    _actionBarView.backgroundColor = UIColor.clearColor;
    _actionBarView.hidden = YES;
    _actionBarView.userInteractionEnabled = NO;

    _primaryButton = [self bb_actionButtonWithTitle:@"" systemImageName:@"arrow.up.forward"];
    [_primaryButton addTarget:self action:@selector(bb_primaryTapped) forControlEvents:UIControlEventTouchUpInside];
    [_actionBarView addSubview:_primaryButton];

    _stepperView = [[UIView alloc] init];
    _stepperView.translatesAutoresizingMaskIntoConstraints = NO;
    _stepperView.hidden = YES;
    _stepperView.alpha = 0.0;
    [_actionBarView addSubview:_stepperView];

    _minusButton = [self bb_stepperButtonWithSystemName:@"minus"];
    [_minusButton addTarget:self action:@selector(bb_minusTapped) forControlEvents:UIControlEventTouchUpInside];
    [_stepperView addSubview:_minusButton];

    _quantityLabel = [[UILabel alloc] init];
    _quantityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _quantityLabel.textAlignment = NSTextAlignmentCenter;
    _quantityLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCallout]
                           scaledFontForFont:([GM boldFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightBold])];
    _quantityLabel.adjustsFontForContentSizeCategory = YES;
    _quantityLabel.textColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    _quantityLabel.text = @"0";
    [_quantityLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_quantityLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_stepperView addSubview:_quantityLabel];

    _plusButton = [self bb_stepperButtonWithSystemName:@"plus"];
    [_plusButton addTarget:self action:@selector(bb_plusTapped) forControlEvents:UIControlEventTouchUpInside];
    [_stepperView addSubview:_plusButton];

    _shareButton = [self bb_iconButtonWithSystemImageName:@"square.and.arrow.up"];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIImageSymbolWeightMedium];
        UIImage *image = [UIImage systemImageNamed:@"square.and.arrow.up" withConfiguration:symbolConfig];
        [_shareButton setImage:image forState:UIControlStateNormal];
    }
    [_shareButton addTarget:self action:@selector(bb_shareTapped) forControlEvents:UIControlEventTouchUpInside];
    [_actionBarView addSubview:_shareButton];

    self.primaryButtonLeadingToShareConstraint = [_primaryButton.leadingAnchor constraintEqualToAnchor:_shareButton.trailingAnchor constant:8.0];
    self.primaryButtonLeadingToActionBarConstraint = [_primaryButton.leadingAnchor constraintEqualToAnchor:_actionBarView.leadingAnchor];
    self.primaryButtonLeadingToShareConstraint.active = NO;
    self.primaryButtonLeadingToActionBarConstraint.active = NO;

    [NSLayoutConstraint activateConstraints:@[
        [_actionBarView.heightAnchor constraintGreaterThanOrEqualToConstant:BBFullDetailsActionHeight],
        [_shareButton.topAnchor constraintEqualToAnchor:_actionBarView.topAnchor],
        [_shareButton.leadingAnchor constraintEqualToAnchor:_actionBarView.leadingAnchor],
        [_shareButton.bottomAnchor constraintEqualToAnchor:_actionBarView.bottomAnchor],
        [_shareButton.widthAnchor constraintEqualToConstant:BBFullDetailsActionHeight],
        [_shareButton.heightAnchor constraintEqualToConstant:BBFullDetailsActionHeight],
        [_primaryButton.topAnchor constraintEqualToAnchor:_actionBarView.topAnchor],
        [_primaryButton.trailingAnchor constraintEqualToAnchor:_actionBarView.trailingAnchor],
        [_primaryButton.bottomAnchor constraintEqualToAnchor:_actionBarView.bottomAnchor],
        [_primaryButton.heightAnchor constraintEqualToConstant:BBFullDetailsActionHeight],
        [_stepperView.topAnchor constraintEqualToAnchor:_primaryButton.topAnchor],
        [_stepperView.leadingAnchor constraintEqualToAnchor:_primaryButton.leadingAnchor],
        [_stepperView.trailingAnchor constraintEqualToAnchor:_primaryButton.trailingAnchor],
        [_stepperView.bottomAnchor constraintEqualToAnchor:_primaryButton.bottomAnchor],
        [_minusButton.leadingAnchor constraintEqualToAnchor:_stepperView.leadingAnchor constant:5.0],
        [_minusButton.centerYAnchor constraintEqualToAnchor:_stepperView.centerYAnchor],
        [_minusButton.widthAnchor constraintEqualToConstant:BBFullDetailsStepperButtonSize],
        [_minusButton.heightAnchor constraintEqualToConstant:BBFullDetailsStepperButtonSize],
        [_plusButton.trailingAnchor constraintEqualToAnchor:_stepperView.trailingAnchor constant:-5.0],
        [_plusButton.centerYAnchor constraintEqualToAnchor:_stepperView.centerYAnchor],
        [_plusButton.widthAnchor constraintEqualToConstant:BBFullDetailsStepperButtonSize],
        [_plusButton.heightAnchor constraintEqualToConstant:BBFullDetailsStepperButtonSize],
        [_quantityLabel.centerXAnchor constraintEqualToAnchor:_stepperView.centerXAnchor],
        [_quantityLabel.centerYAnchor constraintEqualToAnchor:_stepperView.centerYAnchor],
        [_quantityLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:_minusButton.trailingAnchor constant:8.0],
        [_plusButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:_quantityLabel.trailingAnchor constant:8.0]
    ]];

    _detailsStackView = [[UIStackView alloc] init];
    _detailsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _detailsStackView.axis = UILayoutConstraintAxisVertical;
    _detailsStackView.alignment = UIStackViewAlignmentFill;
    _detailsStackView.distribution = UIStackViewDistributionFill;
    _detailsStackView.spacing = 7.0;
    [surfaceView addSubview:_detailsStackView];
 

    _mediaTopConstraint = [_mediaContainerView.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:BBFullDetailsMediaOuterInset];
    _mediaBottomConstraint = [_mediaContainerView.bottomAnchor constraintEqualToAnchor:_detailsStackView.topAnchor constant:-BBFullDetailsMediaToContentSpacing];
    _mediaCollapsedTopConstraint = [_mediaContainerView.topAnchor constraintEqualToAnchor:surfaceView.topAnchor];
    _mediaCollapsedHeightConstraint = [_mediaContainerView.heightAnchor constraintEqualToConstant:0.0];
    _mediaCollapsedTopConstraint.active = YES;
    _mediaCollapsedHeightConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        
        
        [surfaceView.topAnchor constraintEqualToAnchor:_cardView.topAnchor],
        [surfaceView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor],
        [surfaceView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor],
        [surfaceView.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor],

        [_mediaContainerView.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:BBFullDetailsMediaOuterInset],
        [_mediaContainerView.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-BBFullDetailsMediaOuterInset],
        
        [_pageControl.centerXAnchor constraintEqualToAnchor:_mediaContainerView.centerXAnchor],
        [_pageControl.bottomAnchor constraintEqualToAnchor:_mediaContainerView.bottomAnchor constant:-8.0],
        
        [_ownerMenuButton.topAnchor constraintEqualToAnchor:_mediaContainerView.topAnchor constant:10.0],
        [_ownerMenuButton.leadingAnchor constraintEqualToAnchor:_mediaContainerView.leadingAnchor constant:10.0],
        [_ownerMenuButton.widthAnchor constraintEqualToConstant:36.0],
        [_ownerMenuButton.heightAnchor constraintEqualToConstant:36.0],

        [_detailsStackView.bottomAnchor constraintEqualToAnchor:surfaceView.bottomAnchor constant:-BBFullDetailsContentBottomInset],
        [_detailsStackView.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:BBFullDetailsContentInset],
        [_detailsStackView.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-BBFullDetailsContentInset],
        [_detailsStackView.topAnchor constraintGreaterThanOrEqualToAnchor:surfaceView.topAnchor constant:BBFullDetailsContentInset],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bb_cardTapped)];
    tap.cancelsTouchesInView = NO;
    tap.delegate = self;
    [surfaceView addGestureRecognizer:tap];
}

- (void)bb_applyStaticStyle
{
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.contentView.clipsToBounds = NO;
    self.cardView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.cardView.layer.shadowOpacity = 0.13;
    self.cardView.layer.shadowRadius = 30.0;
    self.cardView.layer.shadowOffset = CGSizeMake(0.0, 18.0);
    [self bb_applyStepperStyle];
}

- (UIButton *)bb_actionButtonWithTitle:(NSString *)title systemImageName:(NSString *)systemImageName
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;

    UIFont *font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCallout]
                    scaledFontForFont:([GM boldFontWithSize:14.5] ?: [UIFont systemFontOfSize:14.5 weight:UIFontWeightSemibold])];
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: UIColor.whiteColor
    };
    NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:attributes];

    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    UIColor *accent = AppPrimaryClr ?: UIColor.systemPinkColor;
    button.backgroundColor = UIColor.clearColor;
    button.layer.cornerRadius = BBFullDetailsActionHeight * 0.5;
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 18.0, 0.0, 18.0);
    button.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    if (@available(iOS 15.0, *)) {
        [button setAttributedTitle:nil forState:UIControlStateNormal];
        [button setTitle:nil forState:UIControlStateNormal];
        UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
        configuration.baseBackgroundColor = accent;
        configuration.baseForegroundColor = UIColor.whiteColor;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(0.0, 18.0, 0.0, 18.0);
        configuration.imagePadding = 7.0;
        configuration.background.cornerRadius = BBFullDetailsActionHeight * 0.5;
        configuration.attributedTitle = attributedTitle;
        if (@available(iOS 13.0, *)) {
            configuration.image = [UIImage systemImageNamed:systemImageName];
        }
        button.configuration = configuration;
    } else {
        [button setAttributedTitle:attributedTitle forState:UIControlStateNormal];
    }
    if (@available(iOS 13.0, *)) {
        UIImage *image = [UIImage systemImageNamed:systemImageName];
        [button setImage:image forState:UIControlStateNormal];
        button.tintColor = UIColor.whiteColor;
        button.imageEdgeInsets = UIEdgeInsetsMake(0.0, Language.isRTL ? 8.0 : -8.0, 0.0, Language.isRTL ? -8.0 : 8.0);
    }
    button.accessibilityTraits = UIAccessibilityTraitButton;
    return button;
}

- (UIButton *)bb_stepperButtonWithSystemName:(NSString *)systemName
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    button.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.88];
    button.layer.cornerRadius = BBFullDetailsStepperButtonSize * 0.5;
    button.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
        UIImageSymbolConfiguration *symbolConfig =
            [UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                            weight:UIImageSymbolWeightBold
                                                             scale:UIImageSymbolScaleMedium];
        [button setPreferredSymbolConfiguration:symbolConfig forImageInState:UIControlStateNormal];
        [button setImage:[UIImage systemImageNamed:systemName] forState:UIControlStateNormal];
    }
    button.accessibilityTraits = UIAccessibilityTraitButton;
    button.accessibilityLabel = [systemName isEqualToString:@"minus"]
        ? BBFullDetailsLocalized(@"a11y_btn_decrease_qty")
        : BBFullDetailsLocalized(@"a11y_btn_increase_qty");
    return button;
}

- (UIButton *)bb_iconButtonWithSystemImageName:(NSString *)systemImageName
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = 36.0 * 0.5;
    button.backgroundColor = BBFullDetailsPlateSurfaceColor();
    button.tintColor = UIColor.labelColor;
    button.clipsToBounds = YES;
    button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    button.layer.borderColor = BBFullDetailsPlateBorderColor().CGColor;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
        [button setImage:[UIImage systemImageNamed:systemImageName] forState:UIControlStateNormal];
    }
    button.accessibilityTraits = UIAccessibilityTraitButton;
    return button;
}

#pragma mark - Configure

- (void)bb_configureLoadingState
{
    self.titleLabel.text = BBFullDetailsLocalized(@"bb_dataview_full_details_loading");
    self.subtitleLabel.text = @"";
    self.imageURLs = @[];
    self.mediaContainerView.hidden = YES;
    [self bb_updateMediaHeightForSize:self.bounds.size];
    self.primaryButton.enabled = NO;
    self.shareButton.enabled = NO;
    self.ownerMenuButton.hidden = YES;
    [self bb_removeAllArrangedSubviewsFromStack:self.detailsStackView];
    [self bb_addHeaderForViewModel:self.viewModel];
}

- (void)bb_buildDetailsForViewModel:(PPUniversalCellViewModel *)viewModel
{
    [self bb_removeAllArrangedSubviewsFromStack:self.detailsStackView];
    [self bb_addHeaderForViewModel:viewModel];
}

- (void)bb_addHeaderForViewModel:(PPUniversalCellViewModel *)viewModel
{
    self.titleLabel = self.titleLabel ?: [self bb_labelWithTextStyle:UIFontTextStyleHeadline weight:UIFontWeightBold color:UIColor.labelColor];
    self.subtitleLabel = self.subtitleLabel ?: [self bb_labelWithTextStyle:UIFontTextStyleSubheadline weight:UIFontWeightMedium color:UIColor.secondaryLabelColor];
    self.priceLabel = self.priceLabel ?: [self bb_labelWithTextStyle:UIFontTextStyleHeadline weight:UIFontWeightBold color:(AppPrimaryClr ?: UIColor.systemPinkColor)];

    UIFont *titleFont = [GM boldFontWithSize:22.0] ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    self.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle3] scaledFontForFont:titleFont];
    self.titleLabel.adjustsFontForContentSizeCategory = YES;

    UIFont *subtitleFont = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    self.subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:subtitleFont];
    self.subtitleLabel.adjustsFontForContentSizeCategory = YES;

    UIFont *priceFont = [GM BlackFontWithSize:30.0] ?: [UIFont systemFontOfSize:23.0 weight:UIFontWeightBold];
    self.priceLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline] scaledFontForFont:priceFont];
    self.priceLabel.adjustsFontForContentSizeCategory = YES;

    // Symmetrically configure premium favorite button and container stack view
    if (!self.favoriteButton) {
        self.favoriteButton = [[FavoriteFloatingButton alloc] init];
        self.favoriteButton.hidesBackground = NO;
        self.favoriteButton.hidden = YES;
        self.favoriteButton.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.92];
        self.favoriteButton.layer.cornerRadius = 19.0;
        self.favoriteButton.clipsToBounds = YES;
        [self.favoriteButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [self.favoriteButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    }
    
    if (!self.priceRowStackView) {
        self.priceRowStackView = [[UIStackView alloc] init];
        self.priceRowStackView.translatesAutoresizingMaskIntoConstraints = NO;
        self.priceRowStackView.axis = UILayoutConstraintAxisHorizontal;
        self.priceRowStackView.alignment = UIStackViewAlignmentCenter;
        self.priceRowStackView.distribution = UIStackViewDistributionFill;
        self.priceRowStackView.spacing = 12.0;
        self.priceRowStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    }

    if (viewModel.isSkeleton) {
        self.titleLabel.text = BBFullDetailsLocalized(@"bb_dataview_full_details_loading");
        self.subtitleLabel.text = @"";
        self.priceLabel.text = @"";
        self.favoriteButton.hidden = YES;
    } else {
        self.titleLabel.text = BBFullDetailsTrimmedString(viewModel.title);
        self.subtitleLabel.text = [self bb_descriptionSubtitleForViewModel:viewModel];
        self.priceLabel.text = BBFullDetailsTrimmedString(viewModel.priceText);
        
        BOOL showsFav = !viewModel.isOwner && viewModel.ModelID.length > 0;
        self.favoriteButton.hidden = !showsFav;
        if (showsFav) {
            self.favoriteButton.adID = viewModel.ModelID ?: @"";
            self.favoriteButton.collection = [self bb_favoritesCollectionForContext:viewModel.modelContext];
            [self.favoriteButton initValue];
        }
    }

    self.subtitleLabel.hidden = self.subtitleLabel.text.length == 0;
    self.priceLabel.hidden = self.priceLabel.text.length == 0;

    self.titleLabel.numberOfLines = 2;
    self.subtitleLabel.numberOfLines = 3;
    self.priceLabel.numberOfLines = 1;

    self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.priceLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    [self.detailsStackView addArrangedSubview:self.titleLabel];
    [self.detailsStackView addArrangedSubview:self.subtitleLabel];
    
    [self bb_removeAllArrangedSubviewsFromStack:self.priceRowStackView];
    [self.priceRowStackView addArrangedSubview:self.priceLabel];
    [self.priceRowStackView addArrangedSubview:self.favoriteButton];
    [self.detailsStackView addArrangedSubview:self.priceRowStackView];

    [self bb_configureHighlightPlatesForViewModel:viewModel];
    [self.detailsStackView addArrangedSubview:self.highlightPlateStackView];
    
    BOOL isService = [viewModel.ModelObject isKindOfClass:ServiceModel.class];
    [self bb_configureOwnerCapsuleBadgeForViewModel:viewModel];
    if (isService) {
        [self.detailsStackView addArrangedSubview:self.actionBarView];
        [self.detailsStackView addArrangedSubview:self.ownerCapsuleBadgeView];
    } else {
        [self.detailsStackView addArrangedSubview:self.ownerCapsuleBadgeView];
        [self.detailsStackView addArrangedSubview:self.actionBarView];
    }
    [self.detailsStackView setCustomSpacing:10.0 afterView:self.highlightPlateStackView];
    [self.detailsStackView setCustomSpacing:10.0 afterView:self.actionBarView];
    [self.detailsStackView setCustomSpacing:12.0 afterView:self.ownerCapsuleBadgeView];

    [self.detailsStackView setNeedsLayout];
    [self.detailsStackView layoutIfNeeded];
}

- (NSString *)bb_favoritesCollectionForContext:(PPCellContext)context
{
    switch (context) {
        case PPCellForMarket:
        case PPCellForFood:
        case PPCellForContextAccessory:
            return @"favoritesAccessories";
        case PPCellForVets:
            return @"favoritesVets";
        case PPCellForServices:
            return @"favoritesServices";
        case PPCellForHomeAds:
        case PPCellForAds:
        default:
            return @"favoritesAds";
    }
}

- (UILabel *)bb_labelWithTextStyle:(UIFontTextStyle)textStyle
                            weight:(UIFontWeight)weight
                             color:(UIColor *)color
{
    UILabel *label = [[UILabel alloc] init];
    label.numberOfLines = 0;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.textColor = color;
    UIFont *baseFont = [UIFont systemFontOfSize:[UIFont preferredFontForTextStyle:textStyle].pointSize weight:weight];
    label.font = [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:baseFont];
    label.adjustsFontForContentSizeCategory = YES;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    return label;
}

- (NSString *)bb_descriptionSubtitleForViewModel:(PPUniversalCellViewModel *)viewModel
{
    id model = viewModel.ModelObject;
    NSString *descriptionText = @"";
    if ([model isKindOfClass:PetAd.class]) {
        PetAd *ad = (PetAd *)model;
        if (!BBFullDetailsIsPlaceholderText(ad.adDescription)) {
            descriptionText = BBFullDetailsTrimmedString(ad.adDescription);
        }
    } else if ([model isKindOfClass:PetAccessory.class]) {
        PetAccessory *accessory = (PetAccessory *)model;
        if (!BBFullDetailsIsPlaceholderText(accessory.desc)) {
            descriptionText = BBFullDetailsTrimmedString(accessory.desc);
        }
    } else if ([model isKindOfClass:AdoptPetModel.class]) {
        AdoptPetModel *pet = (AdoptPetModel *)model;
        if (!BBFullDetailsIsPlaceholderText(pet.details)) {
            descriptionText = BBFullDetailsTrimmedString(pet.details);
        }
    } else if ([model isKindOfClass:ServiceModel.class]) {
        ServiceModel *service = (ServiceModel *)model;
        if (!BBFullDetailsIsPlaceholderText(service.descriptionText)) {
            descriptionText = BBFullDetailsTrimmedString(service.descriptionText);
        }
    } else if ([model isKindOfClass:VetModel.class]) {
        VetModel *vet = (VetModel *)model;
        if (!BBFullDetailsIsPlaceholderText(vet.descriptionText)) {
            descriptionText = BBFullDetailsTrimmedString(vet.descriptionText);
        }
    }

    if (descriptionText.length > 0) {
        return descriptionText;
    }
    return BBFullDetailsTrimmedString(viewModel.subtitle);
}

- (UIStackView *)bb_plateStackView
{
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.distribution = UIStackViewDistributionFill;
    stack.spacing = 6.0;
    stack.hidden = YES;
    return stack;
}

- (void)bb_configureHighlightPlatesForViewModel:(PPUniversalCellViewModel *)viewModel
{
    self.highlightPlateStackView = self.highlightPlateStackView ?: [self bb_plateStackView];

    NSMutableArray<UIView *> *plates = [NSMutableArray array];
    NSString *availabilityText = BBFullDetailsTrimmedString(viewModel.availabilityText);
    if (availabilityText.length > 0) {
        BOOL commerce = (viewModel.modelContext == PPCellForMarket ||
                         viewModel.modelContext == PPCellForFood ||
                         [viewModel.ModelObject isKindOfClass:PetAccessory.class]);
        BOOL outOfStock = commerce && viewModel.itemQuantitiy <= 0;
        [plates addObject:[self bb_plateViewWithIconName:(outOfStock ? @"exclamationmark.circle.fill" : @"checkmark.seal.fill")
                                                    text:availabilityText
                                      accessibilityLabel:[self bb_accessibilityTextForLabelKey:@"bb_dataview_full_details_status"
                                                                                         value:availabilityText]
                                               tintColor:(outOfStock ? UIColor.systemOrangeColor : UIColor.systemGreenColor)
                                              emphasized:NO]];
    }

    id model = viewModel.ModelObject;
    if ([model isKindOfClass:PetAd.class]) {
        PetAd *ad = model;
        NSString *viewsText = BBFullDetailsCountText(ad.viewsCount.integerValue);
        NSString *favoritesText = BBFullDetailsCountText(ad.favoritesCount.integerValue);
        [plates addObject:[self bb_plateViewWithIconName:@"eye.fill"
                                                    text:viewsText
                                      accessibilityLabel:[self bb_accessibilityTextForLabelKey:@"bb_dataview_full_details_views"
                                                                                         value:viewsText]
                                               tintColor:UIColor.systemIndigoColor
                                              emphasized:NO]];
        [plates addObject:[self bb_plateViewWithIconName:@"heart.fill"
                                                    text:favoritesText
                                      accessibilityLabel:[self bb_accessibilityTextForLabelKey:@"bb_dataview_full_details_favorites"
                                                                                         value:favoritesText]
                                               tintColor:(AppPrimaryClr ?: UIColor.systemPinkColor)
                                              emphasized:NO]];
    }

    if ([model isKindOfClass:PetAccessory.class] && plates.count < 4) {
        PetAccessory *accessory = model;
        NSString *conditionText = BBFullDetailsTrimmedString([PetAccessory conditionTextForAccessory:accessory]);
        NSString *notSpecified = BBFullDetailsLocalized(@"Not specified");
        if (conditionText.length > 0 && ![conditionText isEqualToString:notSpecified]) {
            BOOL used = accessory.condition == AccessConditionsUsed;
            [plates addObject:[self bb_plateViewWithIconName:(used ? @"clock.arrow.circlepath" : @"sparkles")
                                                        text:conditionText
                                          accessibilityLabel:[self bb_accessibilityTextForLabelKey:@"bb_dataview_full_details_condition"
                                                                                             value:conditionText]
                                                   tintColor:(used ? UIColor.secondaryLabelColor : (AppPrimaryClr ?: UIColor.systemPinkColor))
                                                  emphasized:YES]];
        }
    }

    NSString *discountText = BBFullDetailsTrimmedString(viewModel.discountText);
    if (discountText.length > 0 && plates.count < 4) {
        [plates addObject:[self bb_plateViewWithIconName:@"tag.fill"
                                                    text:discountText
                                      accessibilityLabel:[self bb_accessibilityTextForLabelKey:@"bb_dataview_full_details_offer"
                                                                                         value:discountText]
                                               tintColor:(AppPrimaryClr ?: UIColor.systemPinkColor)
                                              emphasized:YES]];
    }

    NSString *stockText = BBFullDetailsTrimmedString(viewModel.stockStatusText);
    if (stockText.length > 0 && ![stockText isEqualToString:availabilityText] && plates.count < 4) {
        [plates addObject:[self bb_plateViewWithIconName:@"shippingbox.fill"
                                                    text:stockText
                                      accessibilityLabel:[self bb_accessibilityTextForLabelKey:@"bb_dataview_full_details_stock"
                                                                                         value:stockText]
                                               tintColor:UIColor.systemBlueColor
                                              emphasized:NO]];
    }

    NSString *locationText = BBFullDetailsTrimmedString(viewModel.location);
    if (locationText.length > 0 && plates.count < 4) {
        [plates addObject:[self bb_plateViewWithIconName:@"mappin.and.ellipse"
                                                    text:locationText
                                      accessibilityLabel:[self bb_accessibilityTextForLabelKey:@"bb_dataview_full_details_location"
                                                                                         value:locationText]
                                               tintColor:UIColor.secondaryLabelColor
                                              emphasized:NO]];
    }

    [self bb_configurePlateStack:self.highlightPlateStackView withPlates:plates.copy];
}

- (NSString *)bb_accessibilityTextForLabelKey:(NSString *)labelKey value:(NSString *)value
{
    NSString *label = BBFullDetailsLocalized(labelKey);
    NSString *cleanValue = BBFullDetailsTrimmedString(value);
    if (label.length == 0) { return cleanValue; }
    if (cleanValue.length == 0) { return label; }
    return [NSString stringWithFormat:@"%@, %@", label, cleanValue];
}

- (void)bb_configurePlateStack:(UIStackView *)plateStack withPlates:(NSArray<UIView *> *)plates
{
    [self bb_recyclePlateViewsFromStack:plateStack];
    plateStack.hidden = plates.count == 0;
    if (plates.count == 0) { return; }

    for (UIView *plate in plates) {
        [plateStack addArrangedSubview:plate];
    }
}

- (UIView *)bb_plateViewWithIconName:(NSString *)iconName
                                text:(NSString *)text
                  accessibilityLabel:(NSString *)accessibilityLabel
                            tintColor:(UIColor *)tintColor
                           emphasized:(BOOL)emphasized
{
    UIView *plate = nil;
    UIStackView *stack = nil;
    UIImageView *iconView = nil;
    UILabel *label = nil;
    
    if (self.reusablePlateViews.count > 0) {
        plate = self.reusablePlateViews.lastObject;
        [self.reusablePlateViews removeLastObject];
        
        for (UIView *subview in plate.subviews) {
            if ([subview isKindOfClass:[UIStackView class]]) {
                stack = (UIStackView *)subview;
                break;
            }
        }
        if (stack && stack.arrangedSubviews.count >= 2) {
            iconView = (UIImageView *)stack.arrangedSubviews[0];
            label = (UILabel *)stack.arrangedSubviews[1];
        }
    }
    
    if (!plate || !stack || !iconView || !label) {
        plate = [[UIView alloc] init];
        plate.translatesAutoresizingMaskIntoConstraints = NO;
        plate.layer.cornerRadius = 14.0;
        plate.clipsToBounds = YES;
        if (@available(iOS 13.0, *)) {
            plate.layer.cornerCurve = kCACornerCurveContinuous;
        }

        iconView = [[UIImageView alloc] init];
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        iconView.contentMode = UIViewContentModeScaleToFill;

        label = [[UILabel alloc] init];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.numberOfLines = 1;
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.82;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        label.textAlignment = Language.alignmentForCurrentLanguage;

        stack = [[UIStackView alloc] initWithArrangedSubviews:@[iconView, label]];
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        stack.axis = UILayoutConstraintAxisHorizontal;
        stack.alignment = UIStackViewAlignmentCenter;
        stack.distribution = UIStackViewDistributionFill;
        stack.spacing = 4.0;
        [plate addSubview:stack];

        [NSLayoutConstraint activateConstraints:@[
            [stack.topAnchor constraintEqualToAnchor:plate.topAnchor constant:6.0],
            [stack.leadingAnchor constraintEqualToAnchor:plate.leadingAnchor constant:7.0],
            [stack.trailingAnchor constraintEqualToAnchor:plate.trailingAnchor constant:-7.0],
            [stack.bottomAnchor constraintEqualToAnchor:plate.bottomAnchor constant:-6.0],
            [iconView.widthAnchor constraintEqualToConstant:11.0],
            [iconView.heightAnchor constraintEqualToConstant:11.0],
            [plate.heightAnchor constraintGreaterThanOrEqualToConstant:28.0]
        ]];

        [plate setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
        [plate setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        plate.isAccessibilityElement = YES;
    }

    plate.backgroundColor = BBFullDetailsPlateSurfaceColor();
    plate.layer.borderWidth = emphasized ? 0.8 : 0.65;
    plate.layer.borderColor = BBFullDetailsPlateBorderColor().CGColor;

    iconView.tintColor = tintColor ?: UIColor.secondaryLabelColor;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration =
            [UIImageSymbolConfiguration configurationWithPointSize:10.5
                                                            weight:UIImageSymbolWeightSemibold];
        UIImage *image = [UIImage systemImageNamed:iconName withConfiguration:configuration];
        iconView.image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    iconView.hidden = iconView.image == nil;

    label.text = BBFullDetailsTrimmedString(text);
    label.textColor = emphasized ? (tintColor ?: UIColor.labelColor) : UIColor.labelColor;
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                  scaledFontForFont:([GM MidFontWithSize:(emphasized ? 11.5 : 11.0)] ?: [UIFont systemFontOfSize:(emphasized ? 11.5 : 11.0) weight:UIFontWeightSemibold])];
    label.adjustsFontForContentSizeCategory = YES;

    plate.accessibilityLabel = accessibilityLabel;
    return plate;
}

- (NSString *)bb_summaryMetaTextForViewModel:(PPUniversalCellViewModel *)viewModel
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *candidate in @[viewModel.contextualReasonText ?: @"",
                                  viewModel.discountText ?: @""]) {
        NSString *trimmed = BBFullDetailsTrimmedString(candidate);
        if (trimmed.length > 0 && ![parts containsObject:trimmed]) {
            [parts addObject:trimmed];
        }
    }
    return [parts componentsJoinedByString:@" · "];
}

- (NSString *)bb_accessibilitySummaryForViewModel:(PPUniversalCellViewModel *)viewModel
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *candidate in @[viewModel.priceText ?: @"",
                                  viewModel.availabilityText ?: @"",
                                  viewModel.location ?: @"",
                                  viewModel.stockStatusText ?: @"",
                                  viewModel.contextualReasonText ?: @""]) {
        NSString *trimmed = BBFullDetailsTrimmedString(candidate);
        if (trimmed.length > 0 && ![parts containsObject:trimmed]) {
            [parts addObject:trimmed];
        }
    }

    if ([viewModel.ModelObject isKindOfClass:PetAd.class]) {
        PetAd *ad = viewModel.ModelObject;
        NSString *viewsText = BBFullDetailsCountText(ad.viewsCount.integerValue);
        NSString *favoritesText = BBFullDetailsCountText(ad.favoritesCount.integerValue);
        [parts addObject:[self bb_accessibilityTextForLabelKey:@"bb_dataview_full_details_views"
                                                         value:viewsText]];
        [parts addObject:[self bb_accessibilityTextForLabelKey:@"bb_dataview_full_details_favorites"
                                                         value:favoritesText]];
    }

    return [parts componentsJoinedByString:@", "];
}

- (NSArray<NSString *> *)bb_imageURLsForViewModel:(PPUniversalCellViewModel *)viewModel
{
    NSMutableArray<NSString *> *urls = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    id model = viewModel.ModelObject;

    void (^appendMetadataArray)(NSArray *) = ^(NSArray *metadataArray) {
        if (![metadataArray isKindOfClass:NSArray.class]) { return; }
        for (id item in metadataArray) {
            if ([item isKindOfClass:NSDictionary.class]) {
                BBFullDetailsAppendUniqueURL(urls, seen, BBFullDetailsURLFromMediaDictionary(item));
            } else if ([item isKindOfClass:NSString.class]) {
                BBFullDetailsAppendUniqueURL(urls, seen, item);
            }
        }
    };

    void (^appendImageItems)(NSArray<PetImageItem *> *) = ^(NSArray<PetImageItem *> *items) {
        if (![items isKindOfClass:NSArray.class]) { return; }
        for (PetImageItem *item in items) {
            if ([item isKindOfClass:PetImageItem.class]) {
                BBFullDetailsAppendUniqueURL(urls, seen, item.isVideoMedia ? (item.mediaMetadata ? BBFullDetailsURLFromMediaDictionary(item.mediaMetadata) : item.url) : item.url);
            }
        }
    };

    if ([model isKindOfClass:PetAccessory.class]) {
        PetAccessory *accessory = model;
        appendImageItems(accessory.imageItems);
        appendMetadataArray(accessory.imageMeta);
        for (NSString *url in accessory.imageURLsArray) {
            BBFullDetailsAppendUniqueURL(urls, seen, url);
        }
    } else if ([model isKindOfClass:PetAd.class]) {
        PetAd *ad = model;
        appendImageItems(ad.imageItems);
        appendMetadataArray(ad.imageItemsRaw);
        appendMetadataArray(ad.imageMeta);
        for (NSString *url in ad.imageURLs) {
            BBFullDetailsAppendUniqueURL(urls, seen, url);
        }
    } else if ([model isKindOfClass:AdoptPetModel.class]) {
        AdoptPetModel *pet = model;
        appendMetadataArray(pet.imageMeta);
        for (NSString *url in pet.imageURLs) {
            BBFullDetailsAppendUniqueURL(urls, seen, url);
        }
    } else if ([model isKindOfClass:ServiceModel.class]) {
        BBFullDetailsAppendUniqueURL(urls, seen, ((ServiceModel *)model).imageURL);
    } else if ([model isKindOfClass:VetModel.class]) {
        BBFullDetailsAppendUniqueURL(urls, seen, ((VetModel *)model).logoURL);
    }

    BBFullDetailsAppendUniqueURL(urls, seen, viewModel.imageURL);
    return urls.copy;
}

- (NSArray<PetImageItem *> *)bb_imageItemsForViewModel:(PPUniversalCellViewModel *)viewModel
{
    NSMutableArray<PetImageItem *> *items = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    id model = viewModel.ModelObject;

    void (^appendItem)(PetImageItem *) = ^(PetImageItem *item) {
        if (![item isKindOfClass:PetImageItem.class]) { return; }
        NSString *displayURL = BBFullDetailsTrimmedString(item.url);
        NSString *videoURL = BBFullDetailsTrimmedString(item.videoURL);
        if (displayURL.length == 0) { return; }
        if ((displayURL.length > 0 && [seen containsObject:displayURL]) ||
            (videoURL.length > 0 && [seen containsObject:videoURL])) {
            return;
        }
        if (displayURL.length > 0) { [seen addObject:displayURL]; }
        if (videoURL.length > 0) { [seen addObject:videoURL]; }
        [items addObject:item];
    };

    void (^appendURL)(NSString *) = ^(NSString *candidate) {
        NSString *url = BBFullDetailsTrimmedString(candidate);
        if (url.length == 0 || [seen containsObject:url]) { return; }
        PetImageItem *item = [PetImageItem itemWithURL:url width:0 height:0 blurHash:nil];
        appendItem(item);
    };

    void (^appendImageItems)(NSArray<PetImageItem *> *) = ^(NSArray<PetImageItem *> *candidateItems) {
        if (![candidateItems isKindOfClass:NSArray.class]) { return; }
        for (PetImageItem *item in candidateItems) {
            appendItem(item);
        }
    };

    void (^appendMetadataArray)(NSArray *) = ^(NSArray *metadataArray) {
        if (![metadataArray isKindOfClass:NSArray.class]) { return; }
        for (id candidate in metadataArray) {
            if ([candidate isKindOfClass:PetImageItem.class]) {
                appendItem(candidate);
            } else if ([candidate isKindOfClass:NSDictionary.class]) {
                NSDictionary *normalized = BBFullDetailsNormalizedMediaDictionary(candidate);
                PetImageItem *item = [PetImageItem itemWithMediaMetadata:normalized];
                appendItem(item);
            } else if ([candidate isKindOfClass:NSString.class]) {
                appendURL(candidate);
            }
        }
    };

    if ([model isKindOfClass:PetAccessory.class]) {
        PetAccessory *accessory = model;
        appendImageItems(accessory.imageItems);
        appendMetadataArray(accessory.imageMeta);
        for (NSString *url in accessory.imageURLsArray) {
            appendURL(url);
        }
    } else if ([model isKindOfClass:PetAd.class]) {
        PetAd *ad = model;
        appendImageItems(ad.imageItems);
        appendMetadataArray(ad.imageItemsRaw);
        appendMetadataArray(ad.imageMeta);
        for (NSString *url in ad.imageURLs) {
            appendURL(url);
        }
    } else if ([model isKindOfClass:AdoptPetModel.class]) {
        AdoptPetModel *pet = model;
        appendMetadataArray(pet.imageMeta);
        for (NSString *url in pet.imageURLs) {
            appendURL(url);
        }
    } else if ([model isKindOfClass:ServiceModel.class]) {
        appendURL(((ServiceModel *)model).imageURL);
    } else if ([model isKindOfClass:VetModel.class]) {
        appendURL(((VetModel *)model).logoURL);
    }

    appendURL(viewModel.imageURL);
    if (items.count == 0) {
        for (NSString *url in [self bb_imageURLsForViewModel:viewModel]) {
            appendURL(url);
        }
    }
    return items.copy;
}

- (NSArray<NSString *> *)bb_displayURLsFromImageItems:(NSArray<PetImageItem *> *)items
{
    NSMutableArray<NSString *> *urls = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (PetImageItem *item in items) {
        if (![item isKindOfClass:PetImageItem.class]) { continue; }
        BBFullDetailsAppendUniqueURL(urls, seen, item.url);
    }
    return urls.copy;
}

- (void)bb_configureImageGalleryWithItems:(NSArray<PetImageItem *> *)items
                                viewModel:(PPUniversalCellViewModel *)viewModel
{
    if (items.count == 0) { return; }

    if (!self.imageGallery) {
        PetImageGalleryView *gallery =
            [[PetImageGalleryView alloc] initWithFrame:CGRectZero
                                            imageItems:items
                                           galleryType:PetImageGalleryTypeCardsViewer
                                            itemHeight:300.0
                                              parentVC:nil
                                                   obj:viewModel.ModelObject];
        gallery.translatesAutoresizingMaskIntoConstraints = NO;
        gallery.backgroundColor = UIColor.clearColor;
        gallery.contentMode = UIViewContentModeScaleToFill;
        gallery.hidesPageControl = YES;

        __weak typeof(self) weakSelf = self;
        gallery.onPageChanged = ^(NSInteger page) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) { return; }
            NSInteger maxPage = MAX((NSInteger)self.pageControl.numberOfPages - 1, 0);
            self.pageControl.currentPage = MIN(MAX(page, 0), maxPage);
            self.pageControl.accessibilityValue =
                [NSString stringWithFormat:BBFullDetailsLocalized(@"bb_dataview_full_details_image_page_format"),
                 (long)(self.pageControl.currentPage + 1),
                 (long)MAX(self.pageControl.numberOfPages, 1)];
        };

        self.imageGallery = gallery;
        [self.mediaContainerView insertSubview:gallery atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [gallery.leadingAnchor constraintEqualToAnchor:self.mediaContainerView.leadingAnchor],
            [gallery.trailingAnchor constraintEqualToAnchor:self.mediaContainerView.trailingAnchor],
            [gallery.topAnchor constraintEqualToAnchor:self.mediaContainerView.topAnchor],
            [gallery.bottomAnchor constraintEqualToAnchor:self.mediaContainerView.bottomAnchor],
        ]];
        [self bb_applyStaticMediaBorder];
    } else {
        self.imageGallery.contentMode = UIViewContentModeScaleAspectFit;
        self.imageGallery.imageItems = items;
    }

    self.imageGallery.currentPagr = 0;
    [self.imageGallery scrollToPage:0 animated:NO];
    self.pageControl.accessibilityValue =
        [NSString stringWithFormat:BBFullDetailsLocalized(@"bb_dataview_full_details_image_page_format"),
         1L,
         (long)MAX(items.count, 1)];
}

- (void)bb_configureActionsForViewModel:(PPUniversalCellViewModel *)viewModel
{
    self.actionBarView.hidden = YES;
    self.actionBarView.userInteractionEnabled = NO;
    self.primaryButton.hidden = YES;
    self.shareButton.hidden = YES;
    self.stepperView.hidden = YES;
    self.stepperView.alpha = 0.0;
    self.primaryButton.enabled = NO;
    self.shareButton.enabled = NO;
    self.primaryButton.accessibilityElementsHidden = YES;
    self.shareButton.accessibilityElementsHidden = YES;
    self.stepperView.accessibilityElementsHidden = YES;
    [self bb_updateActionBarLeadingForShareVisible:NO];

    BOOL usesCartCTA = [self bb_usesCartCTAForViewModel:viewModel];
    BOOL usesServiceChatCTA = [self bb_usesServiceChatCTAForViewModel:viewModel];
    BOOL canShare = usesCartCTA && [viewModel.ModelObject isKindOfClass:PetAccessory.class];
    if (usesCartCTA || canShare || usesServiceChatCTA) {
        self.actionBarView.hidden = NO;
        self.actionBarView.userInteractionEnabled = YES;
        self.primaryButton.hidden = !(usesCartCTA || usesServiceChatCTA);
        self.primaryButton.accessibilityElementsHidden = !(usesCartCTA || usesServiceChatCTA);
        self.stepperView.accessibilityElementsHidden = !usesCartCTA;
        if (usesCartCTA) {
            [self bb_configureQuantityStateWithViewModel:viewModel];
        } else if (usesServiceChatCTA) {
            [self bb_configureServiceChatButtonForViewModel:viewModel];
        } else {
            [self bb_setQuantity:0 animated:NO];
        }

        self.shareButton.hidden = !canShare;
        self.shareButton.enabled = canShare;
        self.shareButton.accessibilityElementsHidden = !canShare;
        self.shareButton.accessibilityLabel = BBFullDetailsLocalized(@"bb_dataview_full_details_share");
        [self bb_updateActionBarLeadingForShareVisible:canShare];
    } else {
        [self bb_setQuantity:0 animated:NO];
    }

    BOOL isOwner = viewModel.isOwner;
    self.ownerMenuButton.hidden = !isOwner;
    self.ownerMenuButton.userInteractionEnabled = isOwner;
    self.ownerMenuButton.accessibilityElementsHidden = !isOwner;
    self.ownerMenuButton.accessibilityLabel = BBFullDetailsLocalized(@"bb_dataview_full_details_owner_actions");
    if (isOwner) {
        [self bb_configureOwnerMenuForViewModel:viewModel];
    }

    BOOL showsOwnerChat = [self bb_showsAdsOwnerChatForViewModel:viewModel];
    self.ownerChatButton.hidden = !showsOwnerChat;
    self.ownerChatButton.enabled = showsOwnerChat;
    self.ownerChatButton.accessibilityElementsHidden = !showsOwnerChat;
    self.ownerChatButton.accessibilityLabel = BBFullDetailsLocalized(@"bb_dataview_full_details_chat_owner");
}

- (BOOL)bb_usesCartCTAForViewModel:(PPUniversalCellViewModel *)viewModel
{
    if (viewModel.isOwner) {
        return NO;
    }
    if (![viewModel.ModelObject isKindOfClass:PetAccessory.class]) {
        return NO;
    }
    PetAccessory *accessory = (PetAccessory *)viewModel.ModelObject;
    if (accessory.condition == AccessConditionsUsed) {
        return NO;
    }
    return YES;
}

- (BOOL)bb_usesServiceChatCTAForViewModel:(PPUniversalCellViewModel *)viewModel
{
    if (viewModel.isOwner || viewModel.isSkeleton) {
        return NO;
    }
    if (![viewModel.ModelObject isKindOfClass:ServiceModel.class]) {
        return NO;
    }
    return [self bb_ownerIDForViewModel:viewModel].length > 0;
}

- (BOOL)bb_showsAdsOwnerChatForViewModel:(PPUniversalCellViewModel *)viewModel
{
    if (viewModel.isOwner || viewModel.isSkeleton) {
        return NO;
    }
    if (![viewModel.ModelObject isKindOfClass:PetAd.class]) {
        return NO;
    }
    return [self bb_ownerIDForViewModel:viewModel].length > 0;
}

- (void)bb_updateActionBarLeadingForShareVisible:(BOOL)shareVisible
{
    self.primaryButtonLeadingToShareConstraint.active = shareVisible;
    self.primaryButtonLeadingToActionBarConstraint.active = !shareVisible;
}

- (void)bb_configureServiceChatButtonForViewModel:(PPUniversalCellViewModel *)viewModel
{
    (void)viewModel;
    UIColor *brand = AppPrimaryClr ?: UIColor.systemPinkColor;
    UIColor *foreground = UIColor.whiteColor;
    UIFont *font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCallout]
                    scaledFontForFont:([GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold])];
    NSString *title = BBFullDetailsLocalized(@"bb_dataview_full_details_chat_provider");

    if (@available(iOS 15.0, *)) {
        [self.primaryButton setAttributedTitle:nil forState:UIControlStateNormal];
        [self.primaryButton setTitle:nil forState:UIControlStateNormal];
        [self.primaryButton setImage:nil forState:UIControlStateNormal];

        UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        configuration.baseBackgroundColor = brand;
        configuration.baseForegroundColor = foreground;
        configuration.background.cornerRadius = BBFullDetailsActionHeight * 0.5;
        configuration.image = [UIImage systemImageNamed:@"message.fill"];
        configuration.imagePlacement = NSDirectionalRectEdgeLeading;
        configuration.imagePadding = 7.0;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(9.0, 16.0, 9.0, 16.0);
        configuration.title = title;
        configuration.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
            NSMutableDictionary *attributes = incoming.mutableCopy;
            attributes[NSFontAttributeName] = font;
            attributes[NSForegroundColorAttributeName] = foreground;
            return attributes;
        };
        self.primaryButton.configuration = configuration;
        self.primaryButton.backgroundColor = UIColor.clearColor;
    } else {
        [self.primaryButton setAttributedTitle:nil forState:UIControlStateNormal];
        [self.primaryButton setTitle:title forState:UIControlStateNormal];
        [self.primaryButton setTitleColor:foreground forState:UIControlStateNormal];
        if (@available(iOS 13.0, *)) {
            [self.primaryButton setImage:[UIImage systemImageNamed:@"message.fill"] forState:UIControlStateNormal];
        }
        self.primaryButton.backgroundColor = brand;
        self.primaryButton.titleLabel.font = font;
    }

    self.primaryButton.enabled = YES;
    self.primaryButton.alpha = 1.0;
    self.primaryButton.layer.cornerRadius = BBFullDetailsActionHeight * 0.5;
    self.primaryButton.layer.borderWidth = 0.0;
    self.primaryButton.layer.borderColor = UIColor.clearColor.CGColor;
    self.primaryButton.layer.shadowColor = brand.CGColor;
    self.primaryButton.layer.shadowOpacity = 0.075;
    self.primaryButton.layer.shadowRadius = 9.0;
    self.primaryButton.layer.shadowOffset = CGSizeMake(0.0, 4.5);
    self.primaryButton.accessibilityLabel = title;
}

- (void)bb_setPrimaryButtonTitle:(NSString *)title enabled:(BOOL)enabled
{
    NSString *resolvedTitle = BBFullDetailsTrimmedString(title);
    UIFont *font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCallout]
                    scaledFontForFont:([GM boldFontWithSize:14.5] ?: [UIFont systemFontOfSize:14.5 weight:UIFontWeightSemibold])];

    UIColor *textColor = enabled ? UIColor.whiteColor : UIColor.secondaryLabelColor;
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: textColor
    };
    NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:resolvedTitle attributes:attributes];

    self.primaryButton.alpha = enabled ? 1.0 : 0.58;
    if (@available(iOS 15.0, *)) {
        [self.primaryButton setAttributedTitle:nil forState:UIControlStateNormal];
        [self.primaryButton setTitle:nil forState:UIControlStateNormal];
        UIButtonConfiguration *configuration = self.primaryButton.configuration ?: [UIButtonConfiguration filledButtonConfiguration];
        configuration.attributedTitle = attributedTitle;
        configuration.baseBackgroundColor = enabled
            ? (AppPrimaryClr ?: UIColor.systemPinkColor)
            : UIColor.tertiarySystemFillColor;
        configuration.baseForegroundColor = textColor;
        configuration.background.cornerRadius = BBFullDetailsActionHeight * 0.5;
        self.primaryButton.configuration = configuration;
        self.primaryButton.backgroundColor = UIColor.clearColor;
    } else {
        [self.primaryButton setAttributedTitle:attributedTitle forState:UIControlStateNormal];
        self.primaryButton.backgroundColor = enabled
            ? (AppPrimaryClr ?: UIColor.systemPinkColor)
            : UIColor.tertiarySystemFillColor;
    }
}

- (void)bb_cartDidUpdate:(NSNotification *)notification
{
    (void)notification;
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self bb_cartDidUpdate:notification];
        });
        return;
    }
    if (!self.viewModel || self.viewModel.isSkeleton || ![self bb_usesCartCTAForViewModel:self.viewModel]) {
        return;
    }

    NSInteger previousQuantity = self.quantity;
    NSInteger refreshedQuantity = [self bb_cartQuantityForViewModel:self.viewModel];
    self.isEditingQuantity = self.isEditingQuantity && refreshedQuantity > 0;
    [self bb_setQuantity:refreshedQuantity animated:(self.window != nil && previousQuantity != refreshedQuantity)];
}

- (NSInteger)bb_cartQuantityForViewModel:(PPUniversalCellViewModel *)viewModel
{
    if (![viewModel.ModelObject isKindOfClass:PetAccessory.class]) {
        return 0;
    }
    NSInteger stockLimit = [self bb_stockLimitForViewModel:viewModel];
    if (stockLimit <= 0) {
        return 0;
    }
    NSInteger cartQuantity = [[CartManager sharedManager] quantityForAccessory:(PetAccessory *)viewModel.ModelObject];
    return MIN(MAX(cartQuantity, 0), stockLimit);
}

- (NSInteger)bb_stockLimitForViewModel:(PPUniversalCellViewModel *)viewModel
{
    if ([viewModel.ModelObject isKindOfClass:PetAccessory.class]) {
        return MAX(((PetAccessory *)viewModel.ModelObject).quantity, 0);
    }
    return MAX(viewModel.itemQuantitiy, 0);
}

- (NSInteger)bb_stockLimitForCurrentItem
{
    return [self bb_stockLimitForViewModel:self.viewModel];
}

- (void)bb_configureQuantityStateWithViewModel:(PPUniversalCellViewModel *)viewModel
{
    self.isEditingQuantity = NO;
    [self bb_setQuantity:[self bb_cartQuantityForViewModel:viewModel] animated:NO];
}

- (void)bb_setQuantity:(NSInteger)quantity animated:(BOOL)animated
{
    _quantity = MAX(0, quantity);
    self.quantityLabel.text = [NSString stringWithFormat:@"%ld", (long)_quantity];
    if (_quantity == 0) {
        self.isEditingQuantity = NO;
    }
    [self bb_refreshActionPresentationAnimated:animated];
}

- (void)bb_refreshActionPresentationAnimated:(BOOL)animated
{
    BOOL usesQuantity = (self.viewModel != nil && [self bb_usesCartCTAForViewModel:self.viewModel]);
    BOOL shouldShowStepper = usesQuantity && self.isEditingQuantity && self.quantity > 0;

    if (!usesQuantity) {
        self.stepperView.hidden = YES;
        self.stepperView.alpha = 0.0;
        self.primaryButton.hidden = YES;
        self.primaryButton.alpha = 1.0;
        return;
    }

    [self bb_configurePrimaryActionButton];
    [self bb_updateStepperButtonStates];
    [self bb_applyStepperStyle];
    
    // Force layout pass on primaryButton to avoid delayed title application with UIButtonConfiguration
    [self.primaryButton setNeedsLayout];
    [self.primaryButton layoutIfNeeded];

    if (shouldShowStepper) {
        self.stepperView.hidden = NO;
        self.primaryButton.hidden = NO;
    }

    void (^updates)(void) = ^{
        self.primaryButton.alpha = shouldShowStepper ? 0.0 : 1.0;
        self.stepperView.alpha = shouldShowStepper ? 1.0 : 0.0;
        self.stepperView.transform = shouldShowStepper
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeScale(0.96, 0.96);
    };

    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        self.primaryButton.hidden = shouldShowStepper;
        self.stepperView.hidden = !shouldShowStepper;
    };

    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.22
                              delay:0.0
             usingSpringWithDamping:0.90
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:updates
                         completion:completion];
    } else {
        updates();
        completion(YES);
    }
}

- (void)bb_configurePrimaryActionButton
{
    NSInteger stockLimit = [self bb_stockLimitForCurrentItem];
    BOOL isOutOfStock = stockLimit <= 0;
    BOOL isInCart = self.quantity > 0;

    NSString *title = nil;
    NSString *imageName = nil;
    UIColor *brand = AppPrimaryClr ?: UIColor.systemPinkColor;
    UIColor *foreground = UIColor.whiteColor;
    UIColor *background = brand;
    UIColor *border = UIColor.clearColor;

    if (isOutOfStock) {
        title = BBFullDetailsLocalized(@"Out of stock");
        imageName = @"exclamationmark.circle.fill";
        foreground = [UIColor colorWithRed:0.83 green:0.25 blue:0.29 alpha:1.0];
        background = [foreground colorWithAlphaComponent:0.10];
        border = [foreground colorWithAlphaComponent:0.14];
    } else if (isInCart) {
        title = [NSString stringWithFormat:@"%@ • %ld",
                 BBFullDetailsLocalized(@"InCart"),
                 (long)self.quantity];
        imageName = @"cart.fill";
        foreground = brand;
        background = [brand colorWithAlphaComponent:0.09];
        border = [brand colorWithAlphaComponent:0.14];
    } else {
        title = BBFullDetailsLocalized(@"addToCart");
        imageName = @"cart.plus.fill";
    }

    UIFont *font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCallout]
                    scaledFontForFont:([GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold])];

    if (@available(iOS 15.0, *)) {
        [self.primaryButton setAttributedTitle:nil forState:UIControlStateNormal];
        [self.primaryButton setTitle:nil forState:UIControlStateNormal];
        [self.primaryButton setImage:nil forState:UIControlStateNormal];
        
        UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        configuration.baseBackgroundColor = background;
        configuration.baseForegroundColor = foreground;
        configuration.background.cornerRadius = BBFullDetailsActionHeight * 0.5;
        configuration.background.strokeWidth = (isOutOfStock || isInCart) ? 1.0 : 0.0;
        configuration.background.strokeColor = border;
        configuration.image = [UIImage systemImageNamed:imageName];
        configuration.imagePlacement = NSDirectionalRectEdgeLeading;
        configuration.imagePadding = 7.0;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(9.0, 16.0, 9.0, 16.0);
        configuration.title = title;
        configuration.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
            NSMutableDictionary *attributes = incoming.mutableCopy;
            attributes[NSFontAttributeName] = font;
            attributes[NSForegroundColorAttributeName] = foreground;
            return attributes;
        };
        self.primaryButton.configuration = configuration;
        self.primaryButton.backgroundColor = UIColor.clearColor;
    } else {
        [self.primaryButton setAttributedTitle:nil forState:UIControlStateNormal];
        [self.primaryButton setTitle:title forState:UIControlStateNormal];
        [self.primaryButton setTitleColor:foreground forState:UIControlStateNormal];
        if (@available(iOS 13.0, *)) {
            [self.primaryButton setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
        }
        self.primaryButton.backgroundColor = background;
        self.primaryButton.titleLabel.font = font;
        self.primaryButton.layer.borderWidth = (isOutOfStock || isInCart) ? 1.0 : 0.0;
        self.primaryButton.layer.borderColor = border.CGColor;
    }

    self.primaryButton.enabled = !isOutOfStock;
    self.primaryButton.accessibilityLabel = title;
    self.primaryButton.layer.cornerRadius = BBFullDetailsActionHeight * 0.5;
    self.primaryButton.layer.borderColor = border.CGColor;
    self.primaryButton.layer.shadowColor = brand.CGColor;
    self.primaryButton.layer.shadowOpacity = (isOutOfStock || isInCart) ? 0.0 : 0.075;
    self.primaryButton.layer.shadowRadius = 9.0;
    self.primaryButton.layer.shadowOffset = CGSizeMake(0.0, 4.5);
}

- (void)bb_updateStepperButtonStates
{
    NSInteger stockLimit = [self bb_stockLimitForCurrentItem];
    BOOL canDecrease = self.quantity > 0;
    BOOL canIncrease = stockLimit > 0 && self.quantity < stockLimit;

    self.minusButton.enabled = canDecrease;
    self.minusButton.alpha = canDecrease ? 1.0 : 0.45;
    self.plusButton.enabled = canIncrease;
    self.plusButton.alpha = canIncrease ? 1.0 : 0.45;
}

- (void)bb_applyStepperStyle
{
    UIColor *brand = AppPrimaryClr ?: UIColor.systemPinkColor;
    self.stepperView.backgroundColor = [brand colorWithAlphaComponent:0.08];
    self.stepperView.layer.cornerRadius = BBFullDetailsActionHeight * 0.5;
    self.stepperView.layer.borderWidth = 1.0;
    self.stepperView.layer.borderColor = [brand colorWithAlphaComponent:0.14].CGColor;
    self.stepperView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.stepperView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIColor *buttonFill = [UIColor.whiteColor colorWithAlphaComponent:0.88];
    if (@available(iOS 13.0, *)) {
        buttonFill = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:1.0 alpha:0.16]
                : [UIColor colorWithWhite:1.0 alpha:0.88];
        }];
    }
    for (UIButton *button in @[self.minusButton, self.plusButton]) {
        button.tintColor = brand;
        button.backgroundColor = buttonFill;
        button.layer.cornerRadius = BBFullDetailsStepperButtonSize * 0.5;
    }
    self.quantityLabel.textColor = brand;
}

- (void)bb_showOutOfStockFeedback
{
    [PPHUD showError:BBFullDetailsLocalized(@"Out of stock")];
    [PPFunc triggerWarningHaptic];
}

- (void)bb_showStockLimitFeedback:(NSInteger)stockLimit
{
    NSString *only = BBFullDetailsLocalized(@"Only");
    NSString *left = BBFullDetailsLocalized(@"left in stock");
    [PPHUD showInfo:[NSString stringWithFormat:@"%@ %ld %@", only, (long)stockLimit, left]];
    [PPFunc triggerMediumHaptic];
}

- (void)bb_animatePrimaryActionPulse
{
    if (UIAccessibilityIsReduceMotionEnabled()) { return; }
    self.primaryButton.transform = CGAffineTransformMakeScale(0.96, 0.96);
    [UIView animateWithDuration:0.20
                          delay:0.0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.primaryButton.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)bb_restartStepperCollapseTimer
{
    [self.stepperCollapseTimer invalidate];
    self.stepperCollapseTimer = [NSTimer scheduledTimerWithTimeInterval:BBFullDetailsStepperAutoCollapseDelay
                                                                 target:self
                                                               selector:@selector(bb_handleStepperAutoCollapseTimer)
                                                               userInfo:nil
                                                                repeats:NO];
}

- (void)bb_handleStepperAutoCollapseTimer
{
    [self bb_collapseStepper:YES];
}

- (void)bb_collapseStepper:(BOOL)animated
{
    self.isEditingQuantity = NO;
    [self bb_refreshActionPresentationAnimated:animated];
}

- (void)bb_applyStaticMediaBorder
{
    self.mediaContainerView.layer.borderWidth = self.mediaContainerView.hidden ? 0.0 : (1.0 / UIScreen.mainScreen.scale);
    self.mediaContainerView.layer.borderColor = BBFullDetailsMediaStaticBorderColor().CGColor;
}

- (void)bb_configureOwnerMenuForViewModel:(PPUniversalCellViewModel *)viewModel
{
    __weak typeof(self) weakSelf = self;
    UIAction *edit = [UIAction actionWithTitle:BBFullDetailsLocalized(@"Edit")
                                         image:[UIImage systemImageNamed:@"pencil"]
                                    identifier:nil
                                       handler:^(__kindof UIAction * _Nonnull action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.viewModel) { return; }
        if ([self.delegate respondsToSelector:@selector(fullDetailsCellDidRequestEdit:viewModel:)]) {
            [self.delegate fullDetailsCellDidRequestEdit:self viewModel:self.viewModel];
        }
    }];
    UIAction *visibility = [UIAction actionWithTitle:BBFullDetailsLocalized(@"bb_dataview_full_details_visibility")
                                               image:[UIImage systemImageNamed:@"eye"]
                                          identifier:nil
                                             handler:^(__kindof UIAction * _Nonnull action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.viewModel) { return; }
        if ([self.delegate respondsToSelector:@selector(fullDetailsCellDidRequestVisibilityToggle:viewModel:)]) {
            [self.delegate fullDetailsCellDidRequestVisibilityToggle:self viewModel:self.viewModel];
        }
    }];
    UIAction *deleteAction = [UIAction actionWithTitle:BBFullDetailsLocalized(@"Delete")
                                                image:[UIImage systemImageNamed:@"trash"]
                                           identifier:nil
                                              handler:^(__kindof UIAction * _Nonnull action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.viewModel) { return; }
        if ([self.delegate respondsToSelector:@selector(fullDetailsCellDidRequestDelete:viewModel:)]) {
            [self.delegate fullDetailsCellDidRequestDelete:self viewModel:self.viewModel];
        }
    }];
    deleteAction.attributes = UIMenuElementAttributesDestructive;
    self.ownerMenuButton.menu = [UIMenu menuWithTitle:@"" children:@[edit, visibility, deleteAction]];
    self.ownerMenuButton.showsMenuAsPrimaryAction = YES;
}

#pragma mark - Actions

- (void)bb_primaryTapped
{
    if (!self.viewModel) { return; }
    if ([self bb_usesServiceChatCTAForViewModel:self.viewModel]) {
        [self bb_requestChat];
        return;
    }
    if (![self bb_usesCartCTAForViewModel:self.viewModel]) {
        [self bb_cardTapped];
        return;
    }

    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    NSInteger stockLimit = [self bb_stockLimitForCurrentItem];
    if (stockLimit <= 0) {
        [self bb_showOutOfStockFeedback];
        [self bb_setQuantity:0 animated:YES];
        return;
    }

    self.isEditingQuantity = YES;
    if (self.quantity > 0) {
        [self bb_refreshActionPresentationAnimated:YES];
        [self bb_restartStepperCollapseTimer];
        return;
    }

    [self bb_animatePrimaryActionPulse];
    [self bb_setQuantity:MIN(1, stockLimit) animated:YES];
    if ([self.delegate respondsToSelector:@selector(fullDetailsCell:didRequestQuantityDelta:viewModel:)]) {
        [self.delegate fullDetailsCell:self didRequestQuantityDelta:1 viewModel:self.viewModel];
    }
    [self bb_restartStepperCollapseTimer];
}

- (void)bb_minusTapped
{
    if (!self.viewModel || ![self bb_usesCartCTAForViewModel:self.viewModel]) { return; }
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    if (self.quantity <= 0) {
        [self bb_setQuantity:0 animated:YES];
        return;
    }

    NSInteger nextQuantity = MAX(0, self.quantity - 1);
    [self bb_setQuantity:nextQuantity animated:YES];
    if ([self.delegate respondsToSelector:@selector(fullDetailsCell:didRequestQuantityDelta:viewModel:)]) {
        [self.delegate fullDetailsCell:self didRequestQuantityDelta:-1 viewModel:self.viewModel];
    }
    [self bb_restartStepperCollapseTimer];
}

- (void)bb_plusTapped
{
    if (!self.viewModel || ![self bb_usesCartCTAForViewModel:self.viewModel]) { return; }
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    NSInteger stockLimit = [self bb_stockLimitForCurrentItem];
    if (stockLimit <= 0) {
        [self bb_showOutOfStockFeedback];
        [self bb_setQuantity:0 animated:YES];
        return;
    }
    if (self.quantity >= stockLimit) {
        [self bb_showStockLimitFeedback:stockLimit];
        [self bb_restartStepperCollapseTimer];
        return;
    }

    [self bb_setQuantity:MIN(stockLimit, self.quantity + 1) animated:YES];
    if ([self.delegate respondsToSelector:@selector(fullDetailsCell:didRequestQuantityDelta:viewModel:)]) {
        [self.delegate fullDetailsCell:self didRequestQuantityDelta:1 viewModel:self.viewModel];
    }
    [self bb_restartStepperCollapseTimer];
}

- (void)bb_cardTapped
{
    if (!self.viewModel) { return; }
    if ([self.delegate respondsToSelector:@selector(fullDetailsCellDidRequestOpen:viewModel:)]) {
        [self.delegate fullDetailsCellDidRequestOpen:self viewModel:self.viewModel];
    }
}

- (void)bb_shareTapped
{
    if (!self.viewModel) { return; }
    if ([self.delegate respondsToSelector:@selector(fullDetailsCellDidRequestShare:viewModel:)]) {
        [self.delegate fullDetailsCellDidRequestShare:self viewModel:self.viewModel];
    }
}

- (void)bb_ownerChatTapped
{
    [self bb_requestChat];
}

- (void)bb_requestChat
{
    if (!self.viewModel) { return; }
    if ([self.delegate respondsToSelector:@selector(fullDetailsCellDidRequestChat:viewModel:)]) {
        [self.delegate fullDetailsCellDidRequestChat:self viewModel:self.viewModel];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
      shouldReceiveTouch:(UITouch *)touch
{
    (void)gestureRecognizer;
    UIView *view = touch.view;
    if (self.imageGallery && [view isDescendantOfView:self.imageGallery]) {
        return NO;
    }
    while (view && view != self.surfaceView) {
        if ([view isKindOfClass:UIControl.class]) {
            return NO;
        }
        view = view.superview;
    }
    return YES;
}

#pragma mark - Owner Capsule Badge

- (void)bb_setupOwnerCapsuleBadgeIfNeeded
{
    if (self.ownerCapsuleBadgeView) return;
    
    _ownerCapsuleBadgeView = [[UIView alloc] init];
    _ownerCapsuleBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    _ownerCapsuleBadgeView.layer.cornerRadius = 22.0;
    _ownerCapsuleBadgeView.layer.masksToBounds = YES;
    _ownerCapsuleBadgeView.backgroundColor = BBFullDetailsPlateSurfaceColor();
    _ownerCapsuleBadgeView.layer.borderWidth = 1.0;
    _ownerCapsuleBadgeView.layer.borderColor = BBFullDetailsPlateBorderColor().CGColor;
    
    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisHorizontal;
    contentStack.alignment = UIStackViewAlignmentCenter;
    contentStack.distribution = UIStackViewDistributionFill;
    contentStack.spacing = 12.0;
    [_ownerCapsuleBadgeView addSubview:contentStack];
    
    _ownerAvatarImageView = [[UIImageView alloc] init];
    _ownerAvatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _ownerAvatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    _ownerAvatarImageView.layer.cornerRadius = 16.0;
    _ownerAvatarImageView.layer.masksToBounds = YES;
    _ownerAvatarImageView.backgroundColor = [UIColor.systemGrayColor colorWithAlphaComponent:0.1];
    
    _ownerNameLabel = [[UILabel alloc] init];
    _ownerNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _ownerNameLabel.textColor = UIColor.labelColor;
    UIFont *nameFont = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    _ownerNameLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:nameFont];
    _ownerNameLabel.adjustsFontForContentSizeCategory = YES;
    _ownerNameLabel.textAlignment = Language.alignmentForCurrentLanguage;

    _ownerChatButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _ownerChatButton.translatesAutoresizingMaskIntoConstraints = NO;
    _ownerChatButton.hidden = YES;
    _ownerChatButton.enabled = NO;
    _ownerChatButton.backgroundColor = [(AppPrimaryClr ?: UIColor.systemPinkColor) colorWithAlphaComponent:0.10];
    _ownerChatButton.tintColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    _ownerChatButton.layer.cornerRadius = 16.0;
    _ownerChatButton.layer.masksToBounds = YES;
    _ownerChatButton.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _ownerChatButton.layer.borderColor = [(AppPrimaryClr ?: UIColor.systemPinkColor) colorWithAlphaComponent:0.14].CGColor;
    _ownerChatButton.accessibilityTraits = UIAccessibilityTraitButton;
    [_ownerChatButton addTarget:self action:@selector(bb_ownerChatTapped) forControlEvents:UIControlEventTouchUpInside];
    if (@available(iOS 13.0, *)) {
        _ownerChatButton.layer.cornerCurve = kCACornerCurveContinuous;
        UIImageSymbolConfiguration *symbolConfig =
            [UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleMedium];
        [_ownerChatButton setPreferredSymbolConfiguration:symbolConfig forImageInState:UIControlStateNormal];
        [_ownerChatButton setImage:[UIImage systemImageNamed:@"message.fill"] forState:UIControlStateNormal];
    }
    
    _ownerRatingContainerView = [[UIView alloc] init];
    _ownerRatingContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    _ownerRatingContainerView.backgroundColor = [UIColor colorWithRed:1.0 green:0.80 blue:0.34 alpha:0.15];
    _ownerRatingContainerView.layer.cornerRadius = 12.0;
    _ownerRatingContainerView.layer.masksToBounds = YES;
    
    _ownerRatingStarIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"star.fill"]];
    _ownerRatingStarIcon.translatesAutoresizingMaskIntoConstraints = NO;
    _ownerRatingStarIcon.contentMode = UIViewContentModeScaleAspectFit;
    _ownerRatingStarIcon.tintColor = [UIColor colorWithRed:1.0 green:0.75 blue:0.0 alpha:1.0];
    
    _ownerRatingLabel = [[UILabel alloc] init];
    _ownerRatingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _ownerRatingLabel.textColor = [UIColor colorWithRed:1.0 green:0.65 blue:0.0 alpha:1.0];
    UIFont *ratingFont = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
    _ownerRatingLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1] scaledFontForFont:ratingFont];
    _ownerRatingLabel.adjustsFontForContentSizeCategory = YES;
    
    [_ownerRatingContainerView addSubview:_ownerRatingStarIcon];
    [_ownerRatingContainerView addSubview:_ownerRatingLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [_ownerRatingStarIcon.leadingAnchor constraintEqualToAnchor:_ownerRatingContainerView.leadingAnchor constant:8.0],
        [_ownerRatingStarIcon.centerYAnchor constraintEqualToAnchor:_ownerRatingContainerView.centerYAnchor],
        [_ownerRatingStarIcon.widthAnchor constraintEqualToConstant:12.0],
        [_ownerRatingStarIcon.heightAnchor constraintEqualToConstant:12.0],
        
        [_ownerRatingLabel.leadingAnchor constraintEqualToAnchor:_ownerRatingStarIcon.trailingAnchor constant:4.0],
        [_ownerRatingLabel.trailingAnchor constraintEqualToAnchor:_ownerRatingContainerView.trailingAnchor constant:-8.0],
        [_ownerRatingLabel.centerYAnchor constraintEqualToAnchor:_ownerRatingContainerView.centerYAnchor],
        [_ownerRatingLabel.topAnchor constraintEqualToAnchor:_ownerRatingContainerView.topAnchor constant:4.0],
        [_ownerRatingLabel.bottomAnchor constraintEqualToAnchor:_ownerRatingContainerView.bottomAnchor constant:-4.0],
    ]];
    
    [contentStack addArrangedSubview:_ownerAvatarImageView];
    [contentStack addArrangedSubview:_ownerNameLabel];
    
    [_ownerNameLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_ownerNameLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    
    [contentStack addArrangedSubview:_ownerRatingContainerView];
    [contentStack addArrangedSubview:_ownerChatButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [_ownerAvatarImageView.widthAnchor constraintEqualToConstant:32.0],
        [_ownerAvatarImageView.heightAnchor constraintEqualToConstant:32.0],
        [_ownerChatButton.widthAnchor constraintEqualToConstant:32.0],
        [_ownerChatButton.heightAnchor constraintEqualToConstant:32.0],
        
        [contentStack.leadingAnchor constraintEqualToAnchor:_ownerCapsuleBadgeView.leadingAnchor constant:12.0],
        [contentStack.trailingAnchor constraintEqualToAnchor:_ownerCapsuleBadgeView.trailingAnchor constant:-12.0],
        [contentStack.topAnchor constraintEqualToAnchor:_ownerCapsuleBadgeView.topAnchor constant:6.0],
        [contentStack.bottomAnchor constraintEqualToAnchor:_ownerCapsuleBadgeView.bottomAnchor constant:-6.0],
        
        [_ownerCapsuleBadgeView.heightAnchor constraintEqualToConstant:44.0]
    ]];
}

- (NSString *)bb_ownerIDForViewModel:(PPUniversalCellViewModel *)viewModel
{
    if (!viewModel || viewModel.isSkeleton) {
        return nil;
    }
    id model = viewModel.ModelObject;
    if (!model) {
        return nil;
    }
    
    NSString *ownerID = nil;
    if ([model isKindOfClass:PetAd.class]) {
        ownerID = ((PetAd *)model).ownerID;
    } else if ([model isKindOfClass:PetAccessory.class]) {
        ownerID = ((PetAccessory *)model).ownerID;
    } else if ([model isKindOfClass:AdoptPetModel.class]) {
        ownerID = ((AdoptPetModel *)model).ownerID;
    } else if ([model isKindOfClass:ServiceModel.class]) {
        if ([model respondsToSelector:@selector(serviceOwnerID)]) {
            ownerID = [model performSelector:@selector(serviceOwnerID)];
        } else if ([model respondsToSelector:@selector(ownerID)]) {
            ownerID = [model performSelector:@selector(ownerID)];
        }
    } else if ([model isKindOfClass:VetModel.class]) {
        if ([model respondsToSelector:@selector(userID)]) {
            ownerID = [model performSelector:@selector(userID)];
        } else if ([model respondsToSelector:@selector(ownerID)]) {
            ownerID = [model performSelector:@selector(ownerID)];
        }
    }
    
    if (!ownerID && [model respondsToSelector:@selector(ownerID)]) {
        ownerID = [model performSelector:@selector(ownerID)];
    }
    
    if (!ownerID && [model respondsToSelector:@selector(userID)]) {
        ownerID = [model performSelector:@selector(userID)];
    }
    
    return ownerID;
}

- (void)bb_configureOwnerCapsuleBadgeForViewModel:(PPUniversalCellViewModel *)viewModel
{
    [self bb_setupOwnerCapsuleBadgeIfNeeded];
    
    NSString *ownerID = [self bb_ownerIDForViewModel:viewModel];
    if (ownerID.length == 0 || viewModel.isSkeleton) {
        self.ownerCapsuleBadgeView.hidden = YES;
        return;
    }
    
    self.ownerCapsuleBadgeView.hidden = NO;
    
    // Default / loading state
    self.ownerNameLabel.text = BBFullDetailsLocalized(@"bb_dataview_full_details_loading");
    self.ownerAvatarImageView.image = [PPModernAvatarRenderer avatarImageForName:@"" size:32.0];
    self.ownerRatingContainerView.hidden = YES;
    [self bb_applyRatingBadgeForViewModel:viewModel user:nil];
    
    __weak typeof(self) weakSelf = self;
    [UsrMgr getOtherUserModelFromFirestoreWithUID:ownerID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.viewModel || ![ownerID isEqualToString:[self bb_ownerIDForViewModel:self.viewModel]]) {
            return;
        }
        
        if (error || !user) {
            self.ownerNameLabel.text = BBFullDetailsLocalized(@"unknown");
            return;
        }
        
        NSString *displayName = user.userName;
        if (displayName.length == 0) {
            displayName = BBFullDetailsLocalized(@"unknown");
        }
        self.ownerNameLabel.text = displayName;
        
        UIImage *placeholder = [PPModernAvatarRenderer avatarImageForName:displayName size:32.0];
        self.ownerAvatarImageView.image = placeholder;
        
        NSURL *avatarURL = [user userImageUrl];
        if (avatarURL) {
            [[PPImageLoaderManager shared] setImageOnImageView:self.ownerAvatarImageView
                                                           url:avatarURL.absoluteString
                                                   placeholder:placeholder
                                                    complation:nil];
        }
        
        [self bb_applyRatingBadgeForViewModel:self.viewModel user:user];
    }];
}

- (void)bb_applyRatingBadgeForViewModel:(PPUniversalCellViewModel *)viewModel
                                   user:(UserModel *)user
{
    if ([viewModel.ModelObject isKindOfClass:ServiceModel.class]) {
        ServiceModel *service = (ServiceModel *)viewModel.ModelObject;
        if ([service hasDisplayableRating]) {
            self.ownerRatingLabel.text = [NSString stringWithFormat:@"%.1f", service.ratingValue.doubleValue];
            self.ownerRatingContainerView.hidden = NO;
            return;
        }
    }

    if (user.providerReviewCount > 0 && user.providerRatingValue > 0.0) {
        self.ownerRatingLabel.text = [NSString stringWithFormat:@"%.1f", user.providerRatingValue];
        self.ownerRatingContainerView.hidden = NO;
    } else {
        self.ownerRatingContainerView.hidden = YES;
    }
}

#pragma mark - Helpers

- (void)bb_removeAllArrangedSubviewsFromStack:(UIStackView *)stack
{
    NSArray<UIView *> *views = stack.arrangedSubviews.copy;
    for (UIView *view in views) {
        [stack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
}

- (void)bb_recyclePlateViewsFromStack:(UIStackView *)stack
{
    if (!self.reusablePlateViews) {
        self.reusablePlateViews = [NSMutableArray array];
    }
    NSArray<UIView *> *views = stack.arrangedSubviews.copy;
    for (UIView *view in views) {
        [stack removeArrangedSubview:view];
        [view removeFromSuperview];
        [self.reusablePlateViews addObject:view];
    }
}

- (void)bb_applyPressedAppearance:(BOOL)pressed animated:(BOOL)animated
{
    CGAffineTransform transform = pressed ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
    CGFloat alpha = pressed ? 0.96 : 1.0;
    void (^updates)(void) = ^{
        self.cardView.transform = transform;
        self.cardView.alpha = alpha;
    };
    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        updates();
        return;
    }
    [UIView animateWithDuration:0.14
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:updates
                     completion:nil];
}

@end
