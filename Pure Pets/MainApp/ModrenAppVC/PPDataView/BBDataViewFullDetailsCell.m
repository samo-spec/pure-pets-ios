#import "BBDataViewFullDetailsCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPImageLoaderManager.h"
#import "PetAd.h"
#import "PetAccessory.h"
#import "PetImageItem.h"
#import "ServiceModel.h"
#import "AdoptPetModel.h"
#import "VetModel.h"

static NSString * const BBFullDetailsImagePageReuseID = @"BBFullDetailsImagePageCell";
static CGFloat const BBFullDetailsCardCornerRadius = 28.0;
static CGFloat const BBFullDetailsMediaCornerRadius = 22.0;
static CGFloat const BBFullDetailsContentInset = 14.0;
static CGFloat const BBFullDetailsMediaOuterInset = 18.0;
static CGFloat const BBFullDetailsMediaToContentSpacing = 18.0;
static CGFloat const BBFullDetailsContentBottomInset = 16.0;

static UIColor *BBFullDetailsCardSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.105 green:0.108 blue:0.120 alpha:0.38];
            }
            return [UIColor colorWithWhite:1.0 alpha:0.42];
        }];
    }
    return [UIColor.whiteColor colorWithAlphaComponent:0.42];
}

static UIColor *BBFullDetailsCardBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.12];
            }
            return [UIColor colorWithWhite:1.0 alpha:0.72];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.72];
}

static UIColor *BBFullDetailsPlateSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.085];
            }
            return [UIColor colorWithWhite:1.0 alpha:0.25];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.25];
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
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.045];
            }
            return [UIColor colorWithWhite:0.0 alpha:0.035];
        }];
    }
    return [UIColor colorWithWhite:0.0 alpha:0.04];
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
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *failureLabel;
@property (nonatomic, copy) NSString *representedURL;
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

    self.contentView.backgroundColor = [UIColor tertiarySystemFillColor];
    self.contentView.clipsToBounds = YES;

    _imageView = [[UIImageView alloc] init];
    _imageView.translatesAutoresizingMaskIntoConstraints = NO;
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.clipsToBounds = YES;
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
        [_imageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_imageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_imageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_imageView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [_failureLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [_failureLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [_failureLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor]
    ]];

    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.imageView];
    self.representedURL = @"";
    self.imageView.image = nil;
    self.imageView.accessibilityLabel = nil;
    self.imageView.accessibilityValue = nil;
    self.failureLabel.hidden = YES;
}

- (void)configureWithURL:(NSString *)url
             placeholder:(UIImage *)placeholder
             imageLoader:(BBDataViewFullDetailsImageLoader)imageLoader
               pageIndex:(NSInteger)pageIndex
              totalPages:(NSInteger)totalPages
{
    self.representedURL = url ?: @"";
    self.imageView.image = placeholder;
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
        imageLoader(self.imageView, self.representedURL, placeholder, self.contentView);
    } else {
        [[PPImageLoaderManager shared] setImageOnImageView:self.imageView
                                                       url:self.representedURL
                                               placeholder:placeholder
                                           transitionStyle:PPImageTransitionStyleNone
                                                complation:nil];
    }
}

@end

@interface BBDataViewFullDetailsCell () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate>
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UICollectionView *imageCollectionView;
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, strong) UIView *mediaContainerView;
@property (nonatomic, strong) NSLayoutConstraint *mediaHeightConstraint;
@property (nonatomic, strong) UIScrollView *detailsScrollView;
@property (nonatomic, strong) UIStackView *detailsStackView;
@property (nonatomic, strong) UIView *actionBarView;
@property (nonatomic, strong) UIButton *primaryButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) UIButton *ownerMenuButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UIStackView *highlightPlateStackView;
@property (nonatomic, strong) UIStackView *socialMetricStackView;
@property (nonatomic, copy) NSArray<NSString *> *imageURLs;
@property (nonatomic, strong) UIImage *placeholderImage;
@property (nonatomic, copy) BBDataViewFullDetailsImageLoader imageLoader;
@property (nonatomic, strong) PPUniversalCellViewModel *viewModel;
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
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.delegate = nil;
    self.imageLoader = nil;
    self.viewModel = nil;
    self.imageURLs = @[];
    self.placeholderImage = [UIImage imageNamed:@"placeholder"];
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.priceLabel.text = nil;
    self.metaLabel.text = nil;
    self.titleLabel.accessibilityLabel = nil;
    self.subtitleLabel.accessibilityLabel = nil;
    self.priceLabel.accessibilityLabel = nil;
    self.metaLabel.accessibilityLabel = nil;
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
    self.mediaContainerView.hidden = YES;
    self.mediaHeightConstraint.constant = 0.0;
    self.detailsScrollView.contentOffset = CGPointZero;
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
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.cardView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.detailsStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    if (viewModel.isSkeleton) {
        [self bb_configureLoadingState];
        return;
    }

    self.titleLabel.text = BBFullDetailsTrimmedString(viewModel.title);
    self.subtitleLabel.text = BBFullDetailsTrimmedString(viewModel.subtitle);
    self.subtitleLabel.hidden = self.subtitleLabel.text.length == 0;
    self.metaLabel.text = [self bb_summaryMetaTextForViewModel:viewModel];
    self.metaLabel.hidden = self.metaLabel.text.length == 0;

    self.imageURLs = [self bb_imageURLsForViewModel:viewModel];
    BOOL hasImages = self.imageURLs.count > 0;
    self.mediaContainerView.hidden = !hasImages;
    self.pageControl.numberOfPages = self.imageURLs.count;
    self.pageControl.currentPage = 0;
    self.pageControl.hidden = self.imageURLs.count <= 1;
    self.imageCollectionView.showsHorizontalScrollIndicator = self.imageURLs.count > 1;
    [self.imageCollectionView setContentOffset:CGPointZero animated:NO];
    [self.imageCollectionView reloadData];
    [self setNeedsLayout];

    [self bb_buildDetailsForViewModel:viewModel];
    [self bb_configureActionsForViewModel:viewModel];
    self.mediaHeightConstraint.constant = hasImages ? [self bb_preferredMediaHeight] : 0.0;
    [self setNeedsLayout];

    self.accessibilityLabel = self.titleLabel.text;
    self.accessibilityValue = [self bb_accessibilitySummaryForViewModel:viewModel];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.cardView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.cardView.bounds
                                   cornerRadius:BBFullDetailsCardCornerRadius].CGPath;
    self.surfaceView.layer.borderColor = BBFullDetailsCardBorderColor().CGColor;
    self.mediaHeightConstraint.constant = self.imageURLs.count > 0
        ? [self bb_preferredMediaHeight]
        : 0.0;
}

- (CGFloat)bb_preferredMediaHeight
{
    CGFloat cardHeight = CGRectGetHeight(self.bounds);
    if (cardHeight <= 0.0) {
        return 260.0;
    }
    CGFloat detailsWidth = MAX(1.0, CGRectGetWidth(self.bounds) - (BBFullDetailsContentInset * 2.0));
    CGSize fittingSize = CGSizeMake(detailsWidth, UILayoutFittingCompressedSize.height);
    CGFloat detailsHeight =
        [self.detailsStackView systemLayoutSizeFittingSize:fittingSize
                             withHorizontalFittingPriority:UILayoutPriorityRequired
                                   verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
    if (!isfinite(detailsHeight) || detailsHeight <= 1.0) {
        detailsHeight = 118.0;
    }

    CGFloat availableHeight =
        cardHeight -
        BBFullDetailsMediaOuterInset -
        BBFullDetailsMediaToContentSpacing -
        BBFullDetailsContentBottomInset -
        ceil(detailsHeight);
    return floor(MAX(160.0, availableHeight));
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
    surfaceView.backgroundColor = BBFullDetailsCardSurfaceColor();
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
    _imageCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:mediaLayout];
    _imageCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _imageCollectionView.backgroundColor = UIColor.clearColor;
    _imageCollectionView.dataSource = self;
    _imageCollectionView.delegate = self;
    _imageCollectionView.pagingEnabled = YES;
    _imageCollectionView.decelerationRate = UIScrollViewDecelerationRateFast;
    _imageCollectionView.directionalLockEnabled = YES;
    _imageCollectionView.showsHorizontalScrollIndicator = NO;
    _imageCollectionView.showsVerticalScrollIndicator = NO;
    _imageCollectionView.scrollIndicatorInsets = UIEdgeInsetsMake(0.0, 18.0, 7.0, 18.0);
    _imageCollectionView.alwaysBounceVertical = NO;
    _imageCollectionView.scrollsToTop = NO;
    _imageCollectionView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [_imageCollectionView registerClass:BBFullDetailsImagePageCell.class
             forCellWithReuseIdentifier:BBFullDetailsImagePageReuseID];
    [_mediaContainerView addSubview:_imageCollectionView];

    _pageControl = [[UIPageControl alloc] init];
    _pageControl.translatesAutoresizingMaskIntoConstraints = NO;
    _pageControl.hidesForSinglePage = YES;
    _pageControl.userInteractionEnabled = NO;
    _pageControl.currentPageIndicatorTintColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    _pageControl.pageIndicatorTintColor = [UIColor.whiteColor colorWithAlphaComponent:0.55];
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

    _shareButton = [self bb_iconButtonWithSystemImageName:@"square.and.arrow.up"];
    [_shareButton addTarget:self action:@selector(bb_shareTapped) forControlEvents:UIControlEventTouchUpInside];
    [_actionBarView addSubview:_shareButton];

    _detailsScrollView = [[UIScrollView alloc] init];
    _detailsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _detailsScrollView.alwaysBounceVertical = NO;
    _detailsScrollView.alwaysBounceHorizontal = NO;
    _detailsScrollView.directionalLockEnabled = YES;
    _detailsScrollView.showsVerticalScrollIndicator = NO;
    _detailsScrollView.scrollsToTop = NO;
    _detailsScrollView.contentInset = UIEdgeInsetsZero;
    [surfaceView addSubview:_detailsScrollView];

    _detailsStackView = [[UIStackView alloc] init];
    _detailsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _detailsStackView.axis = UILayoutConstraintAxisVertical;
    _detailsStackView.alignment = UIStackViewAlignmentFill;
    _detailsStackView.distribution = UIStackViewDistributionFill;
    _detailsStackView.spacing = 7.0;
    [_detailsScrollView addSubview:_detailsStackView];

    _mediaHeightConstraint = [_mediaContainerView.heightAnchor constraintEqualToConstant:220.0];
    _mediaHeightConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [surfaceView.topAnchor constraintEqualToAnchor:_cardView.topAnchor],
        [surfaceView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor],
        [surfaceView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor],
        [surfaceView.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor],

        [_mediaContainerView.topAnchor constraintEqualToAnchor:surfaceView.topAnchor constant:BBFullDetailsMediaOuterInset],
        [_mediaContainerView.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:BBFullDetailsMediaOuterInset],
        [_mediaContainerView.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-BBFullDetailsMediaOuterInset],
        [_imageCollectionView.topAnchor constraintEqualToAnchor:_mediaContainerView.topAnchor],
        [_imageCollectionView.leadingAnchor constraintEqualToAnchor:_mediaContainerView.leadingAnchor],
        [_imageCollectionView.trailingAnchor constraintEqualToAnchor:_mediaContainerView.trailingAnchor],
        [_imageCollectionView.bottomAnchor constraintEqualToAnchor:_mediaContainerView.bottomAnchor],
        [_pageControl.centerXAnchor constraintEqualToAnchor:_mediaContainerView.centerXAnchor],
        [_pageControl.bottomAnchor constraintEqualToAnchor:_mediaContainerView.bottomAnchor constant:-8.0],
        [_ownerMenuButton.topAnchor constraintEqualToAnchor:_mediaContainerView.topAnchor constant:10.0],
        [_ownerMenuButton.leadingAnchor constraintEqualToAnchor:_mediaContainerView.leadingAnchor constant:10.0],
        [_ownerMenuButton.widthAnchor constraintEqualToConstant:36.0],
        [_ownerMenuButton.heightAnchor constraintEqualToConstant:36.0],

        [_detailsScrollView.topAnchor constraintEqualToAnchor:_mediaContainerView.bottomAnchor constant:BBFullDetailsMediaToContentSpacing],
        [_detailsScrollView.leadingAnchor constraintEqualToAnchor:surfaceView.leadingAnchor constant:BBFullDetailsContentInset],
        [_detailsScrollView.trailingAnchor constraintEqualToAnchor:surfaceView.trailingAnchor constant:-BBFullDetailsContentInset],
        [_detailsScrollView.bottomAnchor constraintEqualToAnchor:surfaceView.bottomAnchor constant:-BBFullDetailsContentBottomInset],
        [_detailsStackView.topAnchor constraintEqualToAnchor:_detailsScrollView.contentLayoutGuide.topAnchor],
        [_detailsStackView.leadingAnchor constraintEqualToAnchor:_detailsScrollView.contentLayoutGuide.leadingAnchor],
        [_detailsStackView.trailingAnchor constraintEqualToAnchor:_detailsScrollView.contentLayoutGuide.trailingAnchor],
        [_detailsStackView.bottomAnchor constraintEqualToAnchor:_detailsScrollView.contentLayoutGuide.bottomAnchor],
        [_detailsStackView.widthAnchor constraintEqualToAnchor:_detailsScrollView.frameLayoutGuide.widthAnchor]
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bb_cardTapped)];
    tap.cancelsTouchesInView = NO;
    [surfaceView addGestureRecognizer:tap];
}

- (void)bb_applyStaticStyle
{
    self.backgroundColor = UIColor.clearColor;
    self.clipsToBounds = NO;
    self.contentView.clipsToBounds = NO;
    self.cardView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.cardView.layer.shadowOpacity = 0.09;
    self.cardView.layer.shadowRadius = 22.0;
    self.cardView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
}

- (UIButton *)bb_actionButtonWithTitle:(NSString *)title systemImageName:(NSString *)systemImageName
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCallout]
                              scaledFontForFont:([GM boldFontWithSize:14.5] ?: [UIFont systemFontOfSize:14.5 weight:UIFontWeightSemibold])];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.backgroundColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    button.layer.cornerRadius = 22.0;
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 16.0, 0.0, 16.0);
    if (@available(iOS 13.0, *)) {
        UIImage *image = [UIImage systemImageNamed:systemImageName];
        [button setImage:image forState:UIControlStateNormal];
        button.tintColor = UIColor.whiteColor;
        button.imageEdgeInsets = UIEdgeInsetsMake(0.0, Language.isRTL ? 8.0 : -8.0, 0.0, Language.isRTL ? -8.0 : 8.0);
    }
    button.accessibilityTraits = UIAccessibilityTraitButton;
    return button;
}

- (UIButton *)bb_iconButtonWithSystemImageName:(NSString *)systemImageName
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = 22.0;
    button.backgroundColor = UIColor.tertiarySystemFillColor;
    button.tintColor = UIColor.labelColor;
    button.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
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
    self.metaLabel.text = @"";
    self.mediaContainerView.hidden = YES;
    self.mediaHeightConstraint.constant = 0.0;
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
    self.metaLabel = self.metaLabel ?: [self bb_labelWithTextStyle:UIFontTextStyleFootnote weight:UIFontWeightMedium color:UIColor.secondaryLabelColor];

    UIFont *titleFont = [GM boldFontWithSize:22.0] ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    self.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle3] scaledFontForFont:titleFont];
    self.titleLabel.adjustsFontForContentSizeCategory = YES;

    UIFont *subtitleFont = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    self.subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:subtitleFont];
    self.subtitleLabel.adjustsFontForContentSizeCategory = YES;

    UIFont *priceFont = [GM boldFontWithSize:19.0] ?: [UIFont systemFontOfSize:19.0 weight:UIFontWeightBold];
    self.priceLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline] scaledFontForFont:priceFont];
    self.priceLabel.adjustsFontForContentSizeCategory = YES;

    UIFont *metaFont = [GM fontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular];
    self.metaLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote] scaledFontForFont:metaFont];
    self.metaLabel.adjustsFontForContentSizeCategory = YES;

    if (viewModel.isSkeleton) {
        self.titleLabel.text = BBFullDetailsLocalized(@"bb_dataview_full_details_loading");
        self.subtitleLabel.text = @"";
        self.priceLabel.text = @"";
        self.metaLabel.text = @"";
    } else {
        self.titleLabel.text = BBFullDetailsTrimmedString(viewModel.title);
        self.subtitleLabel.text = BBFullDetailsTrimmedString(viewModel.subtitle);
        self.priceLabel.text = BBFullDetailsTrimmedString(viewModel.priceText);
        self.metaLabel.text = [self bb_summaryMetaTextForViewModel:viewModel];
    }

    self.subtitleLabel.hidden = self.subtitleLabel.text.length == 0;
    self.priceLabel.hidden = self.priceLabel.text.length == 0;
    self.metaLabel.hidden = self.metaLabel.text.length == 0;

    self.titleLabel.numberOfLines = 2;
    self.subtitleLabel.numberOfLines = 1;
    self.priceLabel.numberOfLines = 1;
    self.metaLabel.numberOfLines = 1;

    self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.priceLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.metaLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    [self.detailsStackView addArrangedSubview:self.titleLabel];
    [self.detailsStackView addArrangedSubview:self.subtitleLabel];
    [self.detailsStackView addArrangedSubview:self.priceLabel];
    [self.detailsStackView addArrangedSubview:self.metaLabel];

    [self bb_configureHighlightPlatesForViewModel:viewModel];
    [self.detailsStackView addArrangedSubview:self.highlightPlateStackView];
    [self.detailsStackView setCustomSpacing:6.0 afterView:self.metaLabel];
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

- (UIStackView *)bb_plateStackView
{
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.distribution = UIStackViewDistributionFill;
    stack.spacing = 6.0;
    stack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    stack.hidden = YES;
    return stack;
}

- (void)bb_configureHighlightPlatesForViewModel:(PPUniversalCellViewModel *)viewModel
{
    self.highlightPlateStackView = self.highlightPlateStackView ?: [self bb_plateStackView];
    self.highlightPlateStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

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
    iconView.contentMode = UIViewContentModeScaleAspectFit;
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
    stack.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
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
    self.primaryButton.enabled = NO;
    self.shareButton.enabled = NO;
    self.primaryButton.accessibilityElementsHidden = YES;
    self.shareButton.accessibilityElementsHidden = YES;

    BOOL isOwner = viewModel.isOwner;
    self.ownerMenuButton.hidden = !isOwner;
    self.ownerMenuButton.userInteractionEnabled = isOwner;
    self.ownerMenuButton.accessibilityElementsHidden = !isOwner;
    self.ownerMenuButton.accessibilityLabel = BBFullDetailsLocalized(@"bb_dataview_full_details_owner_actions");
    if (isOwner) {
        [self bb_configureOwnerMenuForViewModel:viewModel];
    }
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
    BOOL commerce = (self.viewModel.modelContext == PPCellForMarket ||
                     self.viewModel.modelContext == PPCellForFood ||
                     [self.viewModel.ModelObject isKindOfClass:PetAccessory.class]);
    if (commerce && self.viewModel.itemQuantitiy > 0 &&
        [self.delegate respondsToSelector:@selector(fullDetailsCell:didRequestQuantityDelta:viewModel:)]) {
        [self.delegate fullDetailsCell:self didRequestQuantityDelta:1 viewModel:self.viewModel];
        return;
    }
    [self bb_cardTapped];
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

#pragma mark - Collection

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
