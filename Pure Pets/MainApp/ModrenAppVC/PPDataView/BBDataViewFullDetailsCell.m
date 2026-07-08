#import "BBDataViewFullDetailsCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPImageLoaderManager.h"
#import "PetAd.h"
#import "PetAccessory.h"
#import "PetImageItem.h"
#import "ServiceModel.h"
#import "AdoptPetModel.h"
#import "VetModel.h"
#import "CartManager.h"
#import "UserManager.h"
#import "PPHUD.h"
#import "PPFunc.h"


static NSString * const BBFullDetailsImagePageReuseID = @"BBFullDetailsImagePageCell";
static CGFloat const BBFullDetailsCardCornerRadius = 42.0;
static CGFloat const BBFullDetailsMediaCornerRadius = 32.0;
static CGFloat const BBFullDetailsContentInset = 28.0;
static CGFloat const BBFullDetailsMediaOuterInset = 28.0;
static CGFloat const BBFullDetailsMediaToContentSpacing = 16.0;
static CGFloat const BBFullDetailsContentBottomInset = 22.0;
static CGFloat const BBFullDetailsActionHeight = 44.0;
static CGFloat const BBFullDetailsMediaLiquidBorderWidth = 0.180;
static CGFloat const BBFullDetailsStepperButtonSize = 34.0;
static NSTimeInterval const BBFullDetailsStepperAutoCollapseDelay = 3.5;

static UIColor *BBFullDetailsCardSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.095 green:0.098 blue:0.110 alpha:0.54];
            }
            return [UIColor colorWithWhite:1.0 alpha:0.88];
        }];
    }
    return [UIColor.whiteColor colorWithAlphaComponent:0.68];
}

static UIColor *BBFullDetailsCardBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.16];
            }
            return [UIColor colorWithWhite:1.0 alpha:0.88];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.88];
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

static NSArray<id> *BBFullDetailsLiquidBorderColors(BOOL isDark)
{
    UIColor *accent = AppPrimaryClr ?: UIColor.systemPinkColor;
    return @[
        (id)[UIColor colorWithWhite:1.0 alpha:(isDark ? 0.28 : 0.94)].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:(isDark ? 0.08 : 0.30)].CGColor,
        (id)[accent colorWithAlphaComponent:(isDark ? 0.12 : 0.07)].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:(isDark ? 0.18 : 0.58)].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:(isDark ? 0.07 : 0.25)].CGColor
    ];
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
    NSString *mediaType = [BBFullDetailsTrimmedString(media[@"media_type"] ?: media[@"type"]) lowercaseString];
    if ([mediaType isEqualToString:@"video"]) {
        NSString *thumbnail = BBFullDetailsTrimmedString(media[@"thumbnail_url"] ?: media[@"thumbnailURL"] ?: media[@"thumbnailUrl"]);
        if (thumbnail.length > 0) { return thumbnail; }
    }
    NSString *url = BBFullDetailsTrimmedString(media[@"url"]);
    if (url.length == 0) { url = BBFullDetailsTrimmedString(media[@"imageURL"]); }
    if (url.length == 0) { url = BBFullDetailsTrimmedString(media[@"imageUrl"]); }
    if (url.length == 0) { url = BBFullDetailsTrimmedString(media[@"thumbnail_url"]); }
    if (url.length == 0) { url = BBFullDetailsTrimmedString(media[@"thumbnailURL"]); }
    return url;
}

@interface BBFullDetailsImagePageCell : UICollectionViewCell
 @property (nonatomic, strong) UIView *backfillWashView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *failureLabel;
@property (nonatomic, copy) NSString *representedURL;
@property (nonatomic, strong) NSLayoutConstraint *imageWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *imageHeightConstraint;
- (void)configureWithURL:(NSString *)url
             placeholder:(UIImage *)placeholder
             imageLoader:(BBDataViewFullDetailsImageLoader)imageLoader
               pageIndex:(NSInteger)pageIndex
              totalPages:(NSInteger)totalPages;
@end

@implementation BBFullDetailsImagePageCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) { return nil; }

    self.backgroundColor = BBFullDetailsImageBackgroundColor();
    self.contentView.backgroundColor = BBFullDetailsImageBackgroundColor();
    self.contentView.clipsToBounds = YES;
 
    _backfillWashView = [[UIView alloc] init];
    _backfillWashView.translatesAutoresizingMaskIntoConstraints = NO;
    _backfillWashView.backgroundColor = [BBFullDetailsImageBackgroundColor() colorWithAlphaComponent:0.42];
    _backfillWashView.userInteractionEnabled = NO;
    [self.contentView addSubview:_backfillWashView];

    _imageView = [[UIImageView alloc] init];
    _imageView.translatesAutoresizingMaskIntoConstraints = NO;
    // Keep aspect-fit product imagery uncropped while letting the filled backplate cover letterbox space.
    _imageView.backgroundColor = UIColor.clearColor;
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    _imageView.clipsToBounds = YES;
    _imageView.layer.borderColor = AppBackgroundClrDarker.CGColor;
    _imageView.layer.borderWidth = 0.75;
   //_imageView.layer.borderColor = AppBackgroundClr;;
    _imageView.isAccessibilityElement = YES;
    [self.contentView addSubview:_imageView];

    _failureLabel = [[UILabel alloc] init];
    _failureLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _failureLabel.textAlignment = NSTextAlignmentCenter;
    _failureLabel.numberOfLines = 0;
    _failureLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
                          scaledFontForFont:([GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium])];
    _failureLabel.adjustsFontForContentSizeCategory = YES;
    _failureLabel.textColor = UIColor.secondaryLabelColor;
    _failureLabel.text = BBFullDetailsLocalized(@"bb_dataview_full_details_image_unavailable");
    _failureLabel.hidden = YES;
    [self.contentView addSubview:_failureLabel];

    [NSLayoutConstraint activateConstraints:@[
       
        
        [_backfillWashView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_backfillWashView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_backfillWashView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_backfillWashView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        
        [_imageView.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [_imageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_imageView.heightAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.heightAnchor],
        [_imageView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.contentView.leadingAnchor],
        [_imageView.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor],
        [_failureLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [_failureLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [_failureLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor]
    ]];
    self.imageWidthConstraint = [_imageView.widthAnchor constraintEqualToConstant:1.0];
   // self.imageHeightConstraint = [_imageView.heightAnchor constraintEqualToConstant:1.0];
    self.imageWidthConstraint.active = YES;
    //self.imageHeightConstraint.active = YES;

    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.imageView];
    self.representedURL = @"";
     self.imageView.image = nil;
     self.imageView.backgroundColor = UIColor.clearColor;
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.accessibilityLabel = nil;
    self.imageView.accessibilityValue = nil;
    self.failureLabel.hidden = YES;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
   [self bb_updateForegroundImageSizeForBounds:self.contentView.bounds.size];
}

- (void)bb_updateForegroundImageSizeForBounds:(CGSize)boundsSize
{
    CGFloat availableWidth = floor(MAX(boundsSize.width, 1.0));
    CGFloat availableHeight = floor(MAX(boundsSize.height, 1.0));
    CGSize imageSize = self.imageView.image.size;
    if (imageSize.width <= 0.0 || imageSize.height <= 0.0) {
        imageSize = CGSizeMake(availableWidth, availableHeight);
    }

    CGFloat imageAspect = imageSize.width / imageSize.height;
    CGFloat boundsAspect = availableWidth / availableHeight;
    CGFloat targetWidth = availableWidth;
    CGFloat targetHeight = availableHeight;
    if (imageAspect > boundsAspect) {
        targetHeight = floor(availableWidth / imageAspect);
    } else {
        targetWidth = floor(availableHeight * imageAspect);
    }

    targetWidth = MIN(MAX(targetWidth, 1.0), availableWidth);
    //targetHeight = MIN(MAX(targetHeight, 1.0), availableHeight);
    if (fabs(self.imageWidthConstraint.constant - targetWidth) > 0.5) {
        self.imageWidthConstraint.constant = targetWidth;
        //self.imageHeightConstraint.constant = targetHeight;
    }
}

- (void)configureWithURL:(NSString *)url
             placeholder:(UIImage *)placeholder
             imageLoader:(BBDataViewFullDetailsImageLoader)imageLoader
               pageIndex:(NSInteger)pageIndex
              totalPages:(NSInteger)totalPages
{
    self.representedURL = url ?: @"";
    UIImage *fallback = placeholder ?: [UIImage imageNamed:@"placeholder"];
     self.imageView.image = fallback;
 
    self.imageView.backgroundColor = UIColor.clearColor;
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.failureLabel.hidden = (self.representedURL.length > 0);
    self.imageView.accessibilityLabel = BBFullDetailsLocalized(@"bb_dataview_full_details_image_accessibility");
    self.imageView.accessibilityValue =
        [NSString stringWithFormat:BBFullDetailsLocalized(@"bb_dataview_full_details_image_page_format"),
         (long)(pageIndex + 1),
         (long)MAX(totalPages, 1)];

    if (self.representedURL.length == 0) {
        return;
    }

    if (imageLoader) {
        imageLoader(self.imageView, self.representedURL, fallback, self.contentView);
    } else {
        [[PPImageLoaderManager shared] setImageOnImageView:self.imageView
                                                       url:self.representedURL
                                               placeholder:fallback
                                           transitionStyle:PPImageTransitionStyleNone
                                                complation:^(UIImage * _Nullable image, NSString * _Nullable urlString) {
            [self setNeedsLayout];
        }];
    }
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;

    NSString *representedURL = self.representedURL.copy;
    __weak typeof(self) weakSelf = self;
    [[PPImageLoaderManager shared] fetchImageWithURL:representedURL completion:^(UIImage * _Nullable image) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !image || ![self.representedURL isEqualToString:representedURL]) { return; }
      
        self.imageView.backgroundColor = UIColor.clearColor;
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        if (!self.imageView.image || self.imageView.image == fallback) {
            self.imageView.image = image;
        }
        
        [self setNeedsLayout];
    }];
}

@end

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

@interface BBDataViewFullDetailsCell () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) BBFullDetailsAmbientGlowView *ambientGlowView1;
@property (nonatomic, strong) BBFullDetailsAmbientGlowView *ambientGlowView2;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UICollectionView *imageCollectionView;
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, strong) UIView *mediaContainerView;
 @property (nonatomic, strong) CAGradientLayer *mediaLiquidBorderLayer;
@property (nonatomic, strong) CAShapeLayer *mediaLiquidBorderMaskLayer;
@property (nonatomic, strong) NSLayoutConstraint *mediaTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *mediaBottomConstraint;
@property (nonatomic, strong) UIStackView *detailsStackView;
@property (nonatomic, strong) UIView *actionBarView;
@property (nonatomic, strong) UIButton *primaryButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) UIButton *ownerMenuButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UIStackView *highlightPlateStackView;
@property (nonatomic, strong) UIStackView *socialMetricStackView;
@property (nonatomic, copy) NSArray<NSString *> *imageURLs;
@property (nonatomic, strong) UIImage *placeholderImage;
@property (nonatomic, copy) BBDataViewFullDetailsImageLoader imageLoader;
@property (nonatomic, strong) PPUniversalCellViewModel *viewModel;
@property (nonatomic, assign) CGSize lastImageCollectionLayoutSize;

@property (nonatomic, strong) UIView *stepperView;
@property (nonatomic, strong) UIButton *minusButton;
@property (nonatomic, strong) UIButton *plusButton;
@property (nonatomic, strong) UILabel *quantityLabel;
@property (nonatomic, assign) NSInteger quantity;
@property (nonatomic, assign) BOOL isEditingQuantity;
@property (nonatomic, strong) NSTimer *stepperCollapseTimer;
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
    self.imageLoader = nil;
    self.viewModel = nil;
    self.imageURLs = @[];
    self.placeholderImage = [UIImage imageNamed:@"placeholder"];
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.priceLabel.text = nil;
    self.titleLabel.accessibilityLabel = nil;
    self.subtitleLabel.accessibilityLabel = nil;
    self.priceLabel.accessibilityLabel = nil;
    [self bb_removeAllArrangedSubviewsFromStack:self.highlightPlateStackView];
    [self bb_removeAllArrangedSubviewsFromStack:self.socialMetricStackView];
    self.highlightPlateStackView.hidden = YES;
    self.socialMetricStackView.hidden = YES;
    self.cardView.transform = CGAffineTransformIdentity;
    self.cardView.alpha = 1.0;
    self.selected = NO;
    self.highlighted = NO;
    self.pageControl.numberOfPages = 0;
    self.pageControl.currentPage = 0;
    self.pageControl.hidden = YES;
    self.imageCollectionView.showsHorizontalScrollIndicator = NO;
    self.lastImageCollectionLayoutSize = CGSizeZero;
    self.mediaContainerView.hidden = YES;
    self.mediaTopConstraint.active = NO;
    self.mediaBottomConstraint.active = NO;
 

    [self bb_removeAllArrangedSubviewsFromStack:self.detailsStackView];
    for (UICollectionViewCell *visibleCell in self.imageCollectionView.visibleCells) {
        if ([visibleCell isKindOfClass:BBFullDetailsImagePageCell.class]) {
            [(BBFullDetailsImagePageCell *)visibleCell prepareForReuse];
        }
    }
    [self.imageCollectionView setContentOffset:CGPointZero animated:NO];
    [self.imageCollectionView reloadData];
    [self.primaryButton setTitle:nil forState:UIControlStateNormal];
    [self.shareButton setTitle:nil forState:UIControlStateNormal];
    [self.ownerMenuButton setTitle:nil forState:UIControlStateNormal];
    self.actionBarView.hidden = YES;
    self.actionBarView.userInteractionEnabled = NO;
    self.shareButton.hidden = YES;
    self.ownerMenuButton.hidden = YES;
    self.ownerMenuButton.menu = nil;
    self.ownerMenuButton.showsMenuAsPrimaryAction = NO;
    self.primaryButton.enabled = YES;
    self.shareButton.enabled = YES;
    self.ownerMenuButton.enabled = YES;
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
    self.viewModel = viewModel;
    self.delegate = delegate;
    self.imageLoader = imageLoader;
    self.placeholderImage = viewModel.placeholder ?: [UIImage imageNamed:@"placeholder"];
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    if (viewModel.isSkeleton) {
        [self bb_configureLoadingState];
        return;
    }

    self.titleLabel.text = BBFullDetailsTrimmedString(viewModel.title);
    self.subtitleLabel.text = [self bb_descriptionSubtitleForViewModel:viewModel];
    self.subtitleLabel.hidden = self.subtitleLabel.text.length == 0;

    self.imageURLs = [self bb_imageURLsForViewModel:viewModel];
    BOOL hasImages = self.imageURLs.count > 0;
    self.mediaContainerView.hidden = !hasImages;
    [self bb_updateMediaHeightForSize:self.bounds.size];
    self.pageControl.numberOfPages = self.imageURLs.count;
    self.pageControl.currentPage = 0;
    self.pageControl.hidden = self.imageURLs.count <= 1;
    self.imageCollectionView.showsHorizontalScrollIndicator = self.imageURLs.count > 1;
    [self.imageCollectionView setContentOffset:CGPointZero animated:NO];
    [self bb_updateImageCollectionLayoutIfNeeded];
    [self.imageCollectionView reloadData];
    

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
      
        return;
    }

  
    self.mediaTopConstraint.active = YES;
    self.mediaBottomConstraint.active = YES;
 
        self.lastImageCollectionLayoutSize = CGSizeZero;
        [self.imageCollectionView.collectionViewLayout invalidateLayout];
        [self setNeedsLayout];
   
}



- (void)layoutSubviews
{
    
    [super layoutSubviews];

    self.cardView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.cardView.bounds
                                   cornerRadius:BBFullDetailsCardCornerRadius].CGPath;
    self.surfaceView.layer.borderColor = BBFullDetailsCardBorderColor().CGColor;
    [self bb_layoutMediaLiquidBorder];
    [self bb_updateImageCollectionLayoutIfNeeded];
    
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
    if (@available(iOS 13.0, *)) {
        _mediaContainerView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [surfaceView addSubview:_mediaContainerView];

    UICollectionViewFlowLayout *mediaLayout = [[UICollectionViewFlowLayout alloc] init];
    mediaLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    mediaLayout.minimumLineSpacing = 0.0;
    mediaLayout.minimumInteritemSpacing = 0.0;
    mediaLayout.estimatedItemSize = CGSizeZero;

    _imageCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:mediaLayout];
    _imageCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _imageCollectionView.backgroundColor = BBFullDetailsImageBackgroundColor();
    _imageCollectionView.dataSource = self;
    _imageCollectionView.delegate = self;
    _imageCollectionView.pagingEnabled = YES;
    _imageCollectionView.decelerationRate = UIScrollViewDecelerationRateFast;
    _imageCollectionView.directionalLockEnabled = YES;
    _imageCollectionView.showsHorizontalScrollIndicator = NO;
    _imageCollectionView.showsVerticalScrollIndicator = NO;
    //_imageCollectionView.scrollIndicatorInsets = UIEdgeInsetsMake(0.0, 18.0, 0.0, 18.0);
    _imageCollectionView.alwaysBounceVertical = NO;
    _imageCollectionView.scrollsToTop = NO;
    [_imageCollectionView registerClass:BBFullDetailsImagePageCell.class
             forCellWithReuseIdentifier:BBFullDetailsImagePageReuseID];
    [_mediaContainerView addSubview:_imageCollectionView];

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

    [NSLayoutConstraint activateConstraints:@[
        [_actionBarView.heightAnchor constraintGreaterThanOrEqualToConstant:BBFullDetailsActionHeight],
        [_shareButton.topAnchor constraintEqualToAnchor:_actionBarView.topAnchor],
        [_shareButton.leadingAnchor constraintEqualToAnchor:_actionBarView.leadingAnchor],
        [_shareButton.bottomAnchor constraintEqualToAnchor:_actionBarView.bottomAnchor],
        [_shareButton.widthAnchor constraintEqualToConstant:BBFullDetailsActionHeight],
        [_shareButton.heightAnchor constraintEqualToConstant:BBFullDetailsActionHeight],
        [_primaryButton.topAnchor constraintEqualToAnchor:_actionBarView.topAnchor],
        [_primaryButton.leadingAnchor constraintEqualToAnchor:_shareButton.trailingAnchor constant:8.0],
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

        [_imageCollectionView.leadingAnchor constraintEqualToAnchor:_mediaContainerView.leadingAnchor],
        [_imageCollectionView.trailingAnchor constraintEqualToAnchor:_mediaContainerView.trailingAnchor],
        [_imageCollectionView.topAnchor constraintEqualToAnchor:_mediaContainerView.topAnchor],
        [_imageCollectionView.bottomAnchor constraintEqualToAnchor:_mediaContainerView.bottomAnchor],
        
        
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
        
        [_mediaContainerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:BBFullDetailsMediaOuterInset],
        [_mediaContainerView.bottomAnchor constraintEqualToAnchor:_detailsStackView.topAnchor constant:-BBFullDetailsMediaOuterInset],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bb_cardTapped)];
    tap.cancelsTouchesInView = NO;
    tap.delegate = self;
    [surfaceView addGestureRecognizer:tap];
    [self bb_installMediaLiquidBorderIfNeeded];
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

    UIFont *priceFont = [GM BlackFontWithSize:26.0] ?: [UIFont systemFontOfSize:19.0 weight:UIFontWeightBold];
    self.priceLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline] scaledFontForFont:priceFont];
    self.priceLabel.adjustsFontForContentSizeCategory = YES;

    if (viewModel.isSkeleton) {
        self.titleLabel.text = BBFullDetailsLocalized(@"bb_dataview_full_details_loading");
        self.subtitleLabel.text = @"";
        self.priceLabel.text = @"";
    } else {
        self.titleLabel.text = BBFullDetailsTrimmedString(viewModel.title);
        self.subtitleLabel.text = [self bb_descriptionSubtitleForViewModel:viewModel];
        self.priceLabel.text = BBFullDetailsTrimmedString(viewModel.priceText);
    }

    self.subtitleLabel.hidden = self.subtitleLabel.text.length == 0;
    self.priceLabel.hidden = self.priceLabel.text.length == 0;

    self.titleLabel.numberOfLines = 2;
    self.subtitleLabel.numberOfLines = 2;
    self.priceLabel.numberOfLines = 1;

    self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.priceLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    [self.detailsStackView addArrangedSubview:self.titleLabel];
    [self.detailsStackView addArrangedSubview:self.subtitleLabel];
    [self.detailsStackView addArrangedSubview:self.priceLabel];

    [self bb_configureHighlightPlatesForViewModel:viewModel];
    [self.detailsStackView addArrangedSubview:self.highlightPlateStackView];
    [self.detailsStackView addArrangedSubview:self.actionBarView];
    [self.detailsStackView setCustomSpacing:10.0 afterView:self.highlightPlateStackView];

    [self.detailsStackView setNeedsLayout];
    [self.detailsStackView layoutIfNeeded];
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
    [self bb_removeAllArrangedSubviewsFromStack:plateStack];
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
    UIView *plate = [[UIView alloc] init];
    plate.translatesAutoresizingMaskIntoConstraints = NO;
    plate.backgroundColor = BBFullDetailsPlateSurfaceColor();
    plate.layer.borderWidth = emphasized ? 0.8 : 0.65;
    plate.layer.borderColor = BBFullDetailsPlateBorderColor().CGColor;
    plate.layer.cornerRadius = 14.0;
    plate.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        plate.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleToFill;
    iconView.tintColor = tintColor ?: UIColor.secondaryLabelColor;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration =
            [UIImageSymbolConfiguration configurationWithPointSize:10.5
                                                            weight:UIImageSymbolWeightSemibold];
        UIImage *image = [UIImage systemImageNamed:iconName withConfiguration:configuration];
        iconView.image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    iconView.hidden = iconView.image == nil;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = BBFullDetailsTrimmedString(text);
    label.textColor = emphasized ? (tintColor ?: UIColor.labelColor) : UIColor.labelColor;
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1]
                  scaledFontForFont:([GM MidFontWithSize:(emphasized ? 11.5 : 11.0)] ?: [UIFont systemFontOfSize:(emphasized ? 11.5 : 11.0) weight:UIFontWeightSemibold])];
    label.adjustsFontForContentSizeCategory = YES;
    label.numberOfLines = 1;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.82;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.textAlignment = Language.alignmentForCurrentLanguage;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[iconView, label]];
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

    BOOL usesCartCTA = [self bb_usesCartCTAForViewModel:viewModel];
    BOOL canShare = usesCartCTA && [viewModel.ModelObject isKindOfClass:PetAccessory.class];
    if (usesCartCTA || canShare) {
        self.actionBarView.hidden = NO;
        self.actionBarView.userInteractionEnabled = YES;
        self.primaryButton.hidden = !usesCartCTA;
        self.primaryButton.accessibilityElementsHidden = !usesCartCTA;
        self.stepperView.accessibilityElementsHidden = !usesCartCTA;
        if (usesCartCTA) {
            [self bb_configureQuantityStateWithViewModel:viewModel];
        } else {
            [self bb_setQuantity:0 animated:NO];
        }

        self.shareButton.hidden = !canShare;
        self.shareButton.enabled = canShare;
        self.shareButton.accessibilityElementsHidden = !canShare;
        self.shareButton.accessibilityLabel = BBFullDetailsLocalized(@"bb_dataview_full_details_share");
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
        imageName = @"plus.cart.fill";
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

- (void)bb_installMediaLiquidBorderIfNeeded
{
    if (self.mediaLiquidBorderLayer) { return; }
    self.mediaLiquidBorderLayer = [CAGradientLayer layer];
    self.mediaLiquidBorderLayer.startPoint = CGPointMake(0.0, 0.0);
    self.mediaLiquidBorderLayer.endPoint = CGPointMake(1.0, 1.0);
    self.mediaLiquidBorderLayer.locations = @[@0.0, @0.24, @0.52, @0.76, @1.0];
    self.mediaLiquidBorderMaskLayer = [CAShapeLayer layer];
    self.mediaLiquidBorderMaskLayer.fillColor = UIColor.clearColor.CGColor;
    self.mediaLiquidBorderMaskLayer.strokeColor = UIColor.blackColor.CGColor;
    self.mediaLiquidBorderMaskLayer.lineWidth = BBFullDetailsMediaLiquidBorderWidth;
    self.mediaLiquidBorderLayer.mask = self.mediaLiquidBorderMaskLayer;
    if (self.imageCollectionView) {
        [self.mediaContainerView.layer insertSublayer:self.mediaLiquidBorderLayer above:self.imageCollectionView.layer];
    } else {
        [self.mediaContainerView.layer addSublayer:self.mediaLiquidBorderLayer];
    }
}

- (void)bb_layoutMediaLiquidBorder
{
    [self bb_installMediaLiquidBorderIfNeeded];
    
    // Dynamically guarantee correct Z-index ordering (above image collection, below interactive elements)
    if (self.mediaLiquidBorderLayer.superlayer == self.mediaContainerView.layer) {
        [self.mediaLiquidBorderLayer removeFromSuperlayer];
    }
    if (self.imageCollectionView) {
        [self.mediaContainerView.layer insertSublayer:self.mediaLiquidBorderLayer above:self.imageCollectionView.layer];
    } else {
        [self.mediaContainerView.layer addSublayer:self.mediaLiquidBorderLayer];
    }
    
    BOOL isDark = NO;
    if (@available(iOS 13.0, *)) {
        isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    self.mediaLiquidBorderLayer.hidden = self.mediaContainerView.hidden || CGRectIsEmpty(self.mediaContainerView.bounds);
    self.mediaLiquidBorderLayer.colors = BBFullDetailsLiquidBorderColors(isDark);
    self.mediaLiquidBorderLayer.frame = self.mediaContainerView.bounds;
    self.mediaLiquidBorderMaskLayer.frame = self.mediaContainerView.bounds;

    CGRect strokeRect = CGRectInset(self.mediaContainerView.bounds,
                                    BBFullDetailsMediaLiquidBorderWidth * 0.5,
                                    BBFullDetailsMediaLiquidBorderWidth * 0.5);
    CGFloat radius = MAX(0.0, BBFullDetailsMediaCornerRadius - BBFullDetailsMediaLiquidBorderWidth * 0.5);
    self.mediaLiquidBorderMaskLayer.path =
        [UIBezierPath bezierPathWithRoundedRect:strokeRect cornerRadius:radius].CGPath;
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

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
      shouldReceiveTouch:(UITouch *)touch
{
    UIView *view = touch.view;
    while (view && view != self.surfaceView) {
        if ([view isKindOfClass:UIControl.class]) {
            return NO;
        }
        view = view.superview;
    }
    return YES;
}

#pragma mark - Collection

- (void)bb_updateImageCollectionLayoutIfNeeded
{
    CGSize targetSize = self.imageCollectionView.bounds.size;
    if (targetSize.width < 1.0 || targetSize.height < 1.0) {
        return;
    }

    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.imageCollectionView.collectionViewLayout;
    if (![layout isKindOfClass:UICollectionViewFlowLayout.class]) {
        return;
    }

    BOOL sizeChanged = !CGSizeEqualToSize(self.lastImageCollectionLayoutSize, targetSize);
    BOOL layoutSizeNeedsUpdate = !CGSizeEqualToSize(layout.itemSize, targetSize);
    BOOL estimatedSizeNeedsReset = !CGSizeEqualToSize(layout.estimatedItemSize, CGSizeZero);
    if (!sizeChanged && !layoutSizeNeedsUpdate && !estimatedSizeNeedsReset) {
        return;
    }

    self.lastImageCollectionLayoutSize = targetSize;
    layout.estimatedItemSize = CGSizeZero;
    layout.itemSize = targetSize;
    [layout invalidateLayout];
    [self.imageCollectionView layoutIfNeeded];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.imageURLs.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                          cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    BBFullDetailsImagePageCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:BBFullDetailsImagePageReuseID
                                                  forIndexPath:indexPath];
    NSString *url = indexPath.item < self.imageURLs.count ? self.imageURLs[indexPath.item] : @"";
    [cell configureWithURL:url
               placeholder:self.placeholderImage
               imageLoader:self.imageLoader
                 pageIndex:indexPath.item
                totalPages:self.imageURLs.count];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return collectionView.bounds.size;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView != self.imageCollectionView || self.imageURLs.count <= 1) { return; }
    CGFloat width = MAX(CGRectGetWidth(scrollView.bounds), 1.0);
    NSInteger page = (NSInteger)llround(scrollView.contentOffset.x / width);
    page = MAX(0, MIN(page, (NSInteger)self.imageURLs.count - 1));
    self.pageControl.currentPage = page;
    self.pageControl.accessibilityValue =
        [NSString stringWithFormat:BBFullDetailsLocalized(@"bb_dataview_full_details_image_page_format"),
         (long)(page + 1),
         (long)self.imageURLs.count];
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
