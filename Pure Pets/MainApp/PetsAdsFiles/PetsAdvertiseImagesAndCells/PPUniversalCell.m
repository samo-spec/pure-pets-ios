//
//  PPUniversalCell.m
//  Pure Pets
//
//  Rebuilt as a single universal marketplace card for ads, accessories, food,
//  services, and clinics while preserving the existing public API + delegate contract.
//

#import "PPUniversalCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPUniversalCellHelper.h"
#import "PPImageLoaderManager.h"
#import "FavoriteButton.h"
#import "CartManager.h"
#import "PPHUD.h"
#import "PPFunc.h"
#import "PPAlertHelper.h"
#import "UserManager.h"
#import "PetAccessory.h"
#import "PetAd.h"
#import "ServiceModel.h"
#import "VetModel.h"

static CGFloat const PPUniversalCardCornerRadius = 26.0;
static CGFloat const PPUniversalImageCornerRadius = 22.0;
static CGFloat const PPUniversalOuterInset = 14.0;
static CGFloat const PPUniversalInnerSpacing = 12.0;
static CGFloat const PPUniversalButtonHeight = 34.0;
static CGFloat const PPUniversalPillHeight = 34.0;
static CGFloat const PPUniversalCompactTitleHeight = 24.0;
static CGFloat const PPUniversalCompactPriceHeight = 26.0;
static CGFloat const PPUniversalControlButtonSize = 38.0;
static NSTimeInterval const PPUniversalStepperAutoCollapseDelay = 3.5;
static BOOL const PPUniversalTemporarilyHideSubtitle = NO;
static BOOL const PPUniversalTemporarilyHideShareButton = YES;
static BOOL const PPUniversalTemporarilyHideCategoryBadge = YES;
static BOOL const PPUniversalTemporarilyHideMenuButton = NO;

static NSString *PPUniversalCellLocalizedString(NSString *key, NSString *fallback)
{
    NSString *value = kLang(key);
    return value.length > 0 ? value : fallback;
}

static UIColor *PPUniversalCellDynamicColor(UIColor *light, UIColor *dark)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull trait) {
            return trait.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light;
        }];
    }
    return light;
}

static UIFont *PPUniversalCellMediumFont(CGFloat size)
{
    UIFont *font = [GM MidFontWithSize:size];
    return font ?: [UIFont systemFontOfSize:size weight:UIFontWeightMedium];
}

static UIFont *PPUniversalCellBoldFont(CGFloat size)
{
    UIFont *font = [GM boldFontWithSize:size];
    return font ?: [UIFont systemFontOfSize:size weight:UIFontWeightBold];
}

static NSString *PPUniversalCellSafeString(NSString *value)
{
    return value.length > 0 ? value : @"";
}

static NSString *PPUniversalCellFormattedPrice(NSNumber *amount, NSString *currencyCode)
{
    if (!amount) {
        return @"";
    }

    NSNumberFormatter *formatter = [NSNumberFormatter new];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_QA"];

    double absoluteValue = fabs(amount.doubleValue);
    BOOL hasCents = fmod(absoluteValue, 1.0) > 0.0001;
    formatter.minimumFractionDigits = hasCents ? 2 : 0;
    formatter.maximumFractionDigits = 2;

    NSString *numberText = [formatter stringFromNumber:amount] ?: amount.stringValue;
    NSString *resolvedCurrency = currencyCode.length > 0 ? currencyCode : @"QAR";
    return Language.isRTL
        ? [NSString stringWithFormat:@"%@ %@", numberText, resolvedCurrency]
        : [NSString stringWithFormat:@"%@ %@", resolvedCurrency, numberText];
}

static BOOL PPUniversalCellReasonLooksNearby(NSString *text)
{
    NSString *lowerText = PPUniversalCellSafeString(text).lowercaseString;
    return [lowerText containsString:@"near"] ||
           [lowerText containsString:@"قريب"] ||
           [lowerText containsString:@"بالقرب"];
}

static NSString *PPUniversalCellNormalizedCurrencyCode(NSString *currencyCode)
{
    NSString *value = PPUniversalCellSafeString(currencyCode);
    if (value.length == 0) {
        return @"QAR";
    }

    NSString *upper = value.uppercaseString;
    if ([upper containsString:@"QAR"] ||
        [upper containsString:@"RIAL"] ||
        [value containsString:@"ريال"] ||
        [value containsString:@"ر.ق"] ||
        [value containsString:@"قط"]) {
        return @"QAR";
    }

    if ([upper containsString:@"EGP"] ||
        [upper containsString:@"POUND"] ||
        [value containsString:@"جنيه"] ||
        [value containsString:@"ج.م"] ||
        [value containsString:@"مص"]) {
        return @"EGP";
    }

    if ([upper containsString:@"SAR"] ||
        [value containsString:@"ر.س"] ||
        [value containsString:@"سعود"]) {
        return @"SAR";
    }

    if ([upper containsString:@"AED"] ||
        [value containsString:@"د.إ"] ||
        [value containsString:@"إمار"]) {
        return @"AED";
    }

    return upper;
}

static NSString *PPUniversalCellDisplayCurrencyCode(NSString *currencyCode)
{
    NSString *normalized = PPUniversalCellNormalizedCurrencyCode(currencyCode);
    if (!Language.isRTL) {
        return normalized;
    }

    if ([normalized isEqualToString:@"QAR"]) {
        return @"ر.ق";
    }
    if ([normalized isEqualToString:@"EGP"]) {
        return @"ج.م";
    }
    if ([normalized isEqualToString:@"SAR"]) {
        return @"ر.س";
    }
    if ([normalized isEqualToString:@"AED"]) {
        return @"د.إ";
    }
    return normalized;
}

static NSString *PPUniversalCellFormattedAmountString(NSNumber *amount)
{
    if (!amount) {
        return @"";
    }

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 2;
    formatter.usesGroupingSeparator = YES;
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    NSString *formatted = [formatter stringFromNumber:amount];
    return formatted.length > 0 ? formatted : amount.stringValue;
}

@interface PPUniversalGradientView : UIView
- (void)applyContextPaletteForContext:(PPCellContext)context;
@end

@implementation PPUniversalGradientView

+ (Class)layerClass
{
    return [CAGradientLayer class];
}

- (instancetype)init
{
    self = [super initWithFrame:CGRectZero];
    if (!self) {
        return nil;
    }

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.userInteractionEnabled = YES;
    self.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return self;
}

- (void)applyContextPaletteForContext:(PPCellContext)context
{
    self.backgroundColor = [UIColor clearColor];
    CAGradientLayer *layer = (CAGradientLayer *)self.layer;
    layer.colors = @[(id)[UIColor clearColor].CGColor, (id)[UIColor clearColor].CGColor];
}

@end

@interface PPUniversalInsetLabel : UILabel
@property (nonatomic, assign) UIEdgeInsets textInsets;
@end

@implementation PPUniversalInsetLabel

- (instancetype)init
{
    self = [super initWithFrame:CGRectZero];
    if (!self) {
        return nil;
    }

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.textInsets = UIEdgeInsetsMake(5.0, 10.0, 5.0, 10.0);
    self.numberOfLines = 1;
    self.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return self;
}

- (void)drawTextInRect:(CGRect)rect
{
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, self.textInsets)];
}

- (CGSize)intrinsicContentSize
{
    CGSize size = [super intrinsicContentSize];
    size.width += self.textInsets.left + self.textInsets.right;
    size.height += self.textInsets.top + self.textInsets.bottom;
    return size;
}

@end

@interface PPUniversalSkeletonView : UIView
@property (nonatomic, assign, getter=isCompactLayout) BOOL compactLayout;
@property (nonatomic, strong) NSArray<UIView *> *bars;
- (void)startAnimating;
- (void)stopAnimating;
@end

@implementation PPUniversalSkeletonView

- (instancetype)init
{
    self = [super initWithFrame:CGRectZero];
    if (!self) {
        return nil;
    }

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.userInteractionEnabled = NO;
    self.hidden = YES;
    self.backgroundColor = [UIColor clearColor];

    NSMutableArray<UIView *> *views = [NSMutableArray array];
    for (NSInteger idx = 0; idx < 7; idx++) {
        UIView *bar = [[UIView alloc] initWithFrame:CGRectZero];
        bar.backgroundColor = PPUniversalCellDynamicColor([UIColor colorWithWhite:0.92 alpha:1.0],
                                                          [UIColor colorWithWhite:0.20 alpha:1.0]);
        bar.layer.cornerRadius = 12.0;
        bar.layer.masksToBounds = YES;
        [self addSubview:bar];
        [views addObject:bar];
    }
    self.bars = views;
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat inset = 14.0;
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat imageHeight = self.isCompactLayout ? width - (inset * 2.0) : CGRectGetHeight(self.bounds) - (inset * 2.0);
    if (!self.isCompactLayout) {
        imageHeight = MIN(MAX(width * 0.34, 128.0), 160.0);
    }

    UIView *imageBar = self.bars[0];
    imageBar.frame = self.isCompactLayout
        ? CGRectMake(inset, inset, width - (inset * 2.0), MIN(MAX(width * 0.78, 116.0), 220.0))
        : CGRectMake(inset, inset, imageHeight, CGRectGetHeight(self.bounds) - (inset * 2.0));
    imageBar.layer.cornerRadius = 20.0;

    CGFloat contentX = self.isCompactLayout ? inset : CGRectGetMaxX(imageBar.frame) + 14.0;
    CGFloat contentWidth = width - contentX - inset;
    CGFloat currentY = self.isCompactLayout ? CGRectGetMaxY(imageBar.frame) + 14.0 : inset + 10.0;

    self.bars[1].frame = CGRectMake(contentX, currentY, MIN(112.0, contentWidth * 0.45), 20.0);
    currentY += 28.0;
    self.bars[2].frame = CGRectMake(contentX, currentY, contentWidth, 18.0);
    currentY += 26.0;
    self.bars[3].frame = CGRectMake(contentX, currentY, contentWidth * 0.68, 16.0);
    currentY += 28.0;
    self.bars[4].frame = CGRectMake(contentX, currentY, MIN(128.0, contentWidth * 0.55), 24.0);
    currentY += 36.0;
    self.bars[5].frame = CGRectMake(contentX, currentY, contentWidth, 44.0);
    currentY += 56.0;
    self.bars[6].frame = CGRectMake(contentX, currentY, MIN(110.0, contentWidth * 0.5), 24.0);
}

- (void)startAnimating
{
    for (UIView *bar in self.bars) {
        if ([bar.layer animationForKey:@"pp.pulse"]) {
            continue;
        }
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
        pulse.fromValue = @(0.48);
        pulse.toValue = @(1.0);
        pulse.duration = 0.85;
        pulse.autoreverses = YES;
        pulse.repeatCount = HUGE_VALF;
        pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [bar.layer addAnimation:pulse forKey:@"pp.pulse"];
    }
}

- (void)stopAnimating
{
    for (UIView *bar in self.bars) {
        [bar.layer removeAnimationForKey:@"pp.pulse"];
    }
}

@end

@interface PPUniversalCell () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) PPUniversalGradientView *imageContainer;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *imageScrimView;
@property (nonatomic, strong) PPUniversalInsetLabel *reasonBadgeLabel;
@property (nonatomic, strong) PPUniversalInsetLabel *discountBadgeLabel;
@property (nonatomic, strong) PPUniversalInsetLabel *categoryBadgeLabel;
@property (nonatomic, strong) UIView *bodyContainer;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *priceContainerView;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UILabel *oldPriceLabel;
@property (nonatomic, strong) UIView *actionHostView;
@property (nonatomic, strong) UIButton *addButton;
@property (nonatomic, strong) UIView *stepperView;
@property (nonatomic, strong) UIButton *minusButton;
@property (nonatomic, strong) UILabel *quantityLabel;
@property (nonatomic, strong) UIButton *plusButton;
@property (nonatomic, strong) PPUniversalInsetLabel *availabilityLabel;
@property (nonatomic, strong) PPUniversalInsetLabel *serviceMetaLabel;
@property (nonatomic, strong) FavoriteFloatingButton *favoriteButton;
@property (nonatomic, strong) FavoriteFloatingButton *bodyFavButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) UIButton *menuButton;
@property (nonatomic, strong) PPUniversalSkeletonView *skeletonView;
@property (nonatomic, strong) CAGradientLayer *cardGradientLayer;

@property (nonatomic, strong) NSLayoutConstraint *imageAspectConstraint;
@property (nonatomic, strong) NSLayoutConstraint *fullWidthImageWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *priceTopToTitleConstraint;
@property (nonatomic, strong) NSLayoutConstraint *priceTopToSubtitleConstraint;
@property (nonatomic, strong) NSLayoutConstraint *subtitleHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *oldPriceCollapsedConstraint;
@property (nonatomic, strong) NSLayoutConstraint *availabilityLeadingToBodyConstraint;
@property (nonatomic, strong) NSLayoutConstraint *availabilityLeadingToMetaConstraint;
@property (nonatomic, strong) NSLayoutConstraint *serviceMetaCollapsedConstraint;
@property (nonatomic, strong) NSLayoutConstraint *availabilityTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *titleHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *priceHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *availabilityHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *priceContainerTrailingToBodyConstraint;
@property (nonatomic, strong) NSLayoutConstraint *priceContainerTrailingToFavConstraint;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *compactLayoutConstraints;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *fullWidthLayoutConstraints;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *dynamicBadgeConstraints;
@property (nonatomic, strong) PPUniversalCellViewModel *vm;
@property (nonatomic, copy) PPImageLoader imageLoader;
@property (nonatomic, assign, readwrite) NSInteger quantity;
@property (nonatomic, assign) BOOL isEditingQuantity;
@property (nonatomic, strong) NSTimer *stepperCollapseTimer;

@end

@implementation PPUniversalCell

#pragma mark - Lifecycle

+ (NSString *)reuseIdentifier
{
    return @"PPUniversalCell";
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
    self.contentView.clipsToBounds = NO;
    self.clipsToBounds = NO;
    self.context = PPCellForAds;
    self.layoutMode = PPCellLayoutModeSquare;
    self.discountStyle = PPDiscountStyleBadge;
    _quantity = 0;

    [self pp_buildViewHierarchy];
    [self pp_buildConstraints];
    [self pp_buildActions];
    [self pp_applyBaseStyling];
    return self;
}

- (void)dealloc
{
    [self.stepperCollapseTimer invalidate];
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.imageView];
}

- (void)prepareForReuse
{
    [super prepareForReuse];

    [self.stepperCollapseTimer invalidate];
    self.stepperCollapseTimer = nil;
    self.vm = nil;
    self.imageLoader = nil;
    self.onTap = nil;
    self.isEditingQuantity = NO;
    [self setQuantity:0 animated:NO];

    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.imageView];
    self.imageView.image = [UIImage imageNamed:@"placeholder"];
    self.priceLabel.attributedText = nil;
    self.titleLabel.text = @"";
    self.subtitleLabel.text = @"";
    self.priceLabel.text = @"";
    self.oldPriceLabel.attributedText = nil;
    self.oldPriceCollapsedConstraint.active = YES;
    self.availabilityLabel.text = @"";
    self.serviceMetaLabel.text = @"";
    self.serviceMetaLabel.attributedText = nil;
    self.serviceMetaLabel.hidden = YES;
    self.availabilityLeadingToBodyConstraint.active = YES;
    self.availabilityLeadingToMetaConstraint.active = NO;
    self.serviceMetaCollapsedConstraint.active = YES;
    self.reasonBadgeLabel.hidden = YES;
    self.hideTopBadge = NO;
    self.showsSubtitle = NO;
    self.discountBadgeLabel.hidden = YES;
    self.categoryBadgeLabel.hidden = YES;
    self.shareButton.hidden = YES;
    self.menuButton.hidden = YES;
    self.favoriteButton.hidden = YES;
    self.bodyFavButton.hidden = YES;
    self.priceContainerTrailingToFavConstraint.active = NO;
    self.priceContainerTrailingToBodyConstraint.active = YES;
    self.skeletonView.hidden = YES;
    [self.skeletonView stopAnimating];
    [NSLayoutConstraint deactivateConstraints:self.dynamicBadgeConstraints];
    self.dynamicBadgeConstraints = @[];
    [self.cardGradientLayer removeFromSuperlayer];
    self.cardGradientLayer = nil;
    [self collapseStepper:NO];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (self.cardGradientLayer) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.cardGradientLayer.frame = self.cardView.bounds;
        self.cardGradientLayer.cornerRadius = self.cardView.layer.cornerRadius;
        [CATransaction commit];
    }
}

#pragma mark - Setup

- (void)pp_buildViewHierarchy
{
    self.cardView = [[UIView alloc] init];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.cardView];

    self.imageContainer = [[PPUniversalGradientView alloc] init];
    self.imageContainer.layer.cornerRadius = PPUniversalImageCornerRadius;
    self.imageContainer.clipsToBounds = YES;
    [self.cardView addSubview:self.imageContainer];

    self.imageView = [[UIImageView alloc] init];
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.imageView.clipsToBounds = YES;
    [self.imageContainer addSubview:self.imageView];

    self.imageScrimView = [[UIView alloc] init];
    self.imageScrimView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageScrimView.userInteractionEnabled = NO;
    self.imageScrimView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
    [self.imageContainer addSubview:self.imageScrimView];

    self.reasonBadgeLabel = [self pp_makeBadgeLabel];
    self.reasonBadgeLabel.hidden = YES;
    [self.imageContainer addSubview:self.reasonBadgeLabel];

    self.discountBadgeLabel = [self pp_makeBadgeLabel];
    self.discountBadgeLabel.hidden = YES;
    [self.imageContainer addSubview:self.discountBadgeLabel];

    self.categoryBadgeLabel = [self pp_makeBadgeLabel];
    self.categoryBadgeLabel.hidden = YES;
    [self.imageContainer addSubview:self.categoryBadgeLabel];

    self.favoriteButton = [[FavoriteFloatingButton alloc] init];
    self.favoriteButton.hidesBackground = NO;
    self.favoriteButton.hidden = YES;
    self.favoriteButton.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
    self.favoriteButton.layer.cornerRadius = PPUniversalControlButtonSize / 2.0;
    self.favoriteButton.clipsToBounds = YES;
    [self.favoriteButton addTarget:self action:@selector(tapFavorite) forControlEvents:UIControlEventTouchUpInside];
    [self.imageContainer addSubview:self.favoriteButton];

    self.shareButton = [self pp_makeIconButtonWithSystemName:@"square.and.arrow.up"];
    self.shareButton.hidden = YES;
    [self.shareButton addTarget:self action:@selector(tapShare) forControlEvents:UIControlEventTouchUpInside];
    [self.imageContainer addSubview:self.shareButton];

    self.menuButton = [self pp_makeIconButtonWithSystemName:@"ellipsis"];
    self.menuButton.hidden = YES;
    [self.imageContainer addSubview:self.menuButton];

    self.bodyContainer = [[UIView alloc] init];
    self.bodyContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardView addSubview:self.bodyContainer];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.titleLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.bodyContainer addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.numberOfLines = 2;
    self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.subtitleLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.bodyContainer addSubview:self.subtitleLabel];

    self.priceContainerView = [[UIView alloc] init];
    self.priceContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.priceContainerView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.priceContainerView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.bodyContainer addSubview:self.priceContainerView];

    self.priceLabel = [[UILabel alloc] init];
    self.priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.priceLabel.adjustsFontSizeToFitWidth = YES;
    self.priceLabel.minimumScaleFactor = 0.78;
    self.priceLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.priceLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.priceContainerView addSubview:self.priceLabel];

    self.oldPriceLabel = [[UILabel alloc] init];
    self.oldPriceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.oldPriceLabel.numberOfLines = 1;
    self.oldPriceLabel.textAlignment = Language.isRTL ? NSTextAlignmentLeft :  NSTextAlignmentRight;
    [self.oldPriceLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.priceContainerView addSubview:self.oldPriceLabel];

    self.bodyFavButton = [[FavoriteFloatingButton alloc] init];
    self.bodyFavButton.hidesBackground = NO;
    self.bodyFavButton.hidden = YES;
    [self.bodyFavButton addTarget:self action:@selector(tapFavorite) forControlEvents:UIControlEventTouchUpInside];
    [self.bodyContainer addSubview:self.bodyFavButton];

    self.actionHostView = [[UIView alloc] init];
    self.actionHostView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.actionHostView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.actionHostView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.bodyContainer addSubview:self.actionHostView];

    self.addButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.addButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.addButton addTarget:self action:@selector(tapAddCollapsed) forControlEvents:UIControlEventTouchUpInside];
    [self.actionHostView addSubview:self.addButton];

    self.stepperView = [[UIView alloc] init];
    self.stepperView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stepperView.hidden = YES;
    self.stepperView.alpha = 0.0;
    [self.actionHostView addSubview:self.stepperView];

    self.minusButton = [self pp_makeStepperButtonWithSystemName:@"minus"];
    [self.minusButton addTarget:self action:@selector(tapMinus) forControlEvents:UIControlEventTouchUpInside];
    [self.stepperView addSubview:self.minusButton];

    self.quantityLabel = [[UILabel alloc] init];
    self.quantityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.quantityLabel.textAlignment = NSTextAlignmentCenter;
    self.quantityLabel.font = PPUniversalCellBoldFont(16.0);
    self.quantityLabel.textColor = AppPrimaryClr;
    self.quantityLabel.text = @"0";
    [self.quantityLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.quantityLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.stepperView addSubview:self.quantityLabel];

    self.plusButton = [self pp_makeStepperButtonWithSystemName:@"plus"];
    [self.plusButton addTarget:self action:@selector(tapPlus) forControlEvents:UIControlEventTouchUpInside];
    [self.stepperView addSubview:self.plusButton];

    self.availabilityLabel = [[PPUniversalInsetLabel alloc] init];
    self.availabilityLabel.textAlignment = NSTextAlignmentCenter;
    [self.availabilityLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.availabilityLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.bodyContainer addSubview:self.availabilityLabel];

    self.serviceMetaLabel = [[PPUniversalInsetLabel alloc] init];
    self.serviceMetaLabel.textAlignment = NSTextAlignmentCenter;
    self.serviceMetaLabel.hidden = YES;
    [self.serviceMetaLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.serviceMetaLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.bodyContainer addSubview:self.serviceMetaLabel];

    self.skeletonView = [[PPUniversalSkeletonView alloc] init];
    [self.cardView addSubview:self.skeletonView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleCardTap)];
    tap.delegate = self;
    [self.cardView addGestureRecognizer:tap];
}

- (void)pp_buildConstraints
{
    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4.0],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:2.0],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-2.0],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4.0],

        [self.imageView.topAnchor constraintEqualToAnchor:self.imageContainer.topAnchor],
        [self.imageView.leadingAnchor constraintEqualToAnchor:self.imageContainer.leadingAnchor],
        [self.imageView.trailingAnchor constraintEqualToAnchor:self.imageContainer.trailingAnchor],
        [self.imageView.bottomAnchor constraintEqualToAnchor:self.imageContainer.bottomAnchor],

        [self.imageScrimView.topAnchor constraintEqualToAnchor:self.imageContainer.topAnchor],
        [self.imageScrimView.leadingAnchor constraintEqualToAnchor:self.imageContainer.leadingAnchor],
        [self.imageScrimView.trailingAnchor constraintEqualToAnchor:self.imageContainer.trailingAnchor],
        [self.imageScrimView.bottomAnchor constraintEqualToAnchor:self.imageContainer.bottomAnchor],
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [self.favoriteButton.topAnchor constraintEqualToAnchor:self.imageContainer.topAnchor constant:10.0],
        [self.favoriteButton.leadingAnchor constraintEqualToAnchor:self.imageContainer.leadingAnchor constant:10.0],

        [self.shareButton.centerYAnchor constraintEqualToAnchor:self.favoriteButton.centerYAnchor],
        [self.shareButton.leadingAnchor constraintEqualToAnchor:self.favoriteButton.trailingAnchor constant:8.0],

        [self.menuButton.topAnchor constraintEqualToAnchor:self.imageContainer.topAnchor constant:10.0],
        [self.menuButton.trailingAnchor constraintEqualToAnchor:self.imageContainer.trailingAnchor constant:-10.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.bodyContainer.topAnchor],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.bodyContainer.leadingAnchor],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.bodyContainer.trailingAnchor],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:2.0],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.bodyContainer.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.bodyContainer.trailingAnchor],

        [self.priceContainerView.leadingAnchor constraintEqualToAnchor:self.bodyContainer.leadingAnchor],

        [self.bodyFavButton.trailingAnchor constraintEqualToAnchor:self.bodyContainer.trailingAnchor],
        [self.bodyFavButton.centerYAnchor constraintEqualToAnchor:self.priceContainerView.topAnchor],

        [self.priceLabel.topAnchor constraintEqualToAnchor:self.priceContainerView.topAnchor],
        [self.priceLabel.leadingAnchor constraintEqualToAnchor:self.priceContainerView.leadingAnchor],
        [self.priceLabel.bottomAnchor constraintEqualToAnchor:self.priceContainerView.bottomAnchor],

        [self.oldPriceLabel.leadingAnchor constraintEqualToAnchor:self.priceLabel.trailingAnchor constant:8.0],
        [self.oldPriceLabel.firstBaselineAnchor constraintEqualToAnchor:self.priceLabel.firstBaselineAnchor],
        [self.oldPriceLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.priceContainerView.trailingAnchor],
        [self.oldPriceLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.priceContainerView.bottomAnchor],

        [self.actionHostView.topAnchor constraintEqualToAnchor:self.priceContainerView.bottomAnchor constant:6.0],
        [self.actionHostView.leadingAnchor constraintEqualToAnchor:self.bodyContainer.leadingAnchor],
        [self.actionHostView.trailingAnchor constraintEqualToAnchor:self.bodyContainer.trailingAnchor],
        [self.actionHostView.heightAnchor constraintEqualToConstant:PPUniversalButtonHeight],

        [self.addButton.topAnchor constraintEqualToAnchor:self.actionHostView.topAnchor],
        [self.addButton.leadingAnchor constraintEqualToAnchor:self.actionHostView.leadingAnchor],
        [self.addButton.trailingAnchor constraintEqualToAnchor:self.actionHostView.trailingAnchor],
        [self.addButton.bottomAnchor constraintEqualToAnchor:self.actionHostView.bottomAnchor],

        [self.stepperView.topAnchor constraintEqualToAnchor:self.actionHostView.topAnchor],
        [self.stepperView.leadingAnchor constraintEqualToAnchor:self.actionHostView.leadingAnchor],
        [self.stepperView.trailingAnchor constraintEqualToAnchor:self.actionHostView.trailingAnchor],
        [self.stepperView.bottomAnchor constraintEqualToAnchor:self.actionHostView.bottomAnchor],

        [self.minusButton.leadingAnchor constraintEqualToAnchor:self.stepperView.leadingAnchor constant:2.0],
        [self.minusButton.centerYAnchor constraintEqualToAnchor:self.stepperView.centerYAnchor],
        [self.minusButton.widthAnchor constraintEqualToConstant:30.0],
        [self.minusButton.heightAnchor constraintEqualToConstant:30.0],

        [self.plusButton.trailingAnchor constraintEqualToAnchor:self.stepperView.trailingAnchor constant:-2.0],
        [self.plusButton.centerYAnchor constraintEqualToAnchor:self.stepperView.centerYAnchor],
        [self.plusButton.widthAnchor constraintEqualToConstant:30.0],
        [self.plusButton.heightAnchor constraintEqualToConstant:30.0],

        [self.quantityLabel.centerXAnchor constraintEqualToAnchor:self.stepperView.centerXAnchor],
        [self.quantityLabel.centerYAnchor constraintEqualToAnchor:self.stepperView.centerYAnchor],
        [self.quantityLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.minusButton.trailingAnchor constant:8.0],
        [self.plusButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.quantityLabel.trailingAnchor constant:8.0],

        [self.availabilityLabel.trailingAnchor constraintEqualToAnchor:self.bodyContainer.trailingAnchor],
        [self.availabilityLabel.bottomAnchor constraintEqualToAnchor:self.bodyContainer.bottomAnchor],

        [self.serviceMetaLabel.topAnchor constraintEqualToAnchor:self.availabilityLabel.topAnchor],
        [self.serviceMetaLabel.leadingAnchor constraintEqualToAnchor:self.bodyContainer.leadingAnchor],
        [self.serviceMetaLabel.bottomAnchor constraintEqualToAnchor:self.bodyContainer.bottomAnchor],

        [self.skeletonView.topAnchor constraintEqualToAnchor:self.cardView.topAnchor],
        [self.skeletonView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor],
        [self.skeletonView.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor],
        [self.skeletonView.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor]
    ]];

    self.imageAspectConstraint = [self.imageContainer.heightAnchor constraintEqualToAnchor:self.imageContainer.widthAnchor multiplier:0.82];
    self.imageAspectConstraint.active = YES;
    self.fullWidthImageWidthConstraint = [self.imageContainer.widthAnchor constraintEqualToConstant:136.0];
    self.priceTopToTitleConstraint = [self.priceContainerView.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4.0];
    self.priceTopToSubtitleConstraint = [self.priceContainerView.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:4.0];
    self.subtitleHeightConstraint = [self.subtitleLabel.heightAnchor constraintEqualToConstant:0.0];
    self.oldPriceCollapsedConstraint = [self.oldPriceLabel.widthAnchor constraintEqualToConstant:0.0];
    self.availabilityLeadingToBodyConstraint = [self.availabilityLabel.leadingAnchor constraintEqualToAnchor:self.bodyContainer.leadingAnchor];
    self.availabilityLeadingToMetaConstraint = [self.availabilityLabel.leadingAnchor constraintEqualToAnchor:self.serviceMetaLabel.trailingAnchor constant:8.0];
    self.serviceMetaCollapsedConstraint = [self.serviceMetaLabel.widthAnchor constraintEqualToConstant:0.0];
    self.availabilityTopConstraint = [self.availabilityLabel.topAnchor constraintEqualToAnchor:self.actionHostView.bottomAnchor constant:10.0];
    self.titleHeightConstraint = [self.titleLabel.heightAnchor constraintEqualToConstant:PPUniversalCompactTitleHeight];
    self.priceHeightConstraint = [self.priceContainerView.heightAnchor constraintEqualToConstant:PPUniversalCompactPriceHeight];
    self.availabilityHeightConstraint = [self.availabilityLabel.heightAnchor constraintEqualToConstant:PPUniversalPillHeight];
    self.priceContainerTrailingToBodyConstraint = [self.priceContainerView.trailingAnchor constraintEqualToAnchor:self.bodyContainer.trailingAnchor];
    self.priceContainerTrailingToFavConstraint = [self.priceContainerView.trailingAnchor constraintEqualToAnchor:self.bodyFavButton.leadingAnchor constant:-10.0];
    self.priceTopToTitleConstraint.active = YES;
    self.subtitleHeightConstraint.active = YES;
    self.oldPriceCollapsedConstraint.active = YES;
    self.availabilityLeadingToBodyConstraint.active = YES;
    self.priceContainerTrailingToBodyConstraint.active = YES;
    self.serviceMetaCollapsedConstraint.active = YES;
    self.availabilityTopConstraint.active = YES;
    self.imageAspectConstraint.priority = UILayoutPriorityDefaultHigh;
    self.titleHeightConstraint.active = YES;
    self.priceHeightConstraint.active = YES;
    self.availabilityHeightConstraint.active = YES;

    self.compactLayoutConstraints = @[
        [self.imageContainer.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:PPUniversalOuterInset],
        [self.imageContainer.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:PPUniversalOuterInset],
        [self.imageContainer.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-PPUniversalOuterInset],
        [self.bodyContainer.topAnchor constraintEqualToAnchor:self.imageContainer.bottomAnchor constant:PPUniversalInnerSpacing /2],
        [self.bodyContainer.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:PPUniversalOuterInset],
        [self.bodyContainer.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-PPUniversalOuterInset],
        [self.bodyContainer.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-PPUniversalOuterInset]
    ];

    self.fullWidthLayoutConstraints = @[
        [self.imageContainer.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:PPUniversalOuterInset],
        [self.imageContainer.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:PPUniversalOuterInset],
        [self.imageContainer.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-PPUniversalOuterInset],
        [self.bodyContainer.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:PPUniversalOuterInset],
        [self.bodyContainer.leadingAnchor constraintEqualToAnchor:self.imageContainer.trailingAnchor constant:14.0],
        [self.bodyContainer.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-PPUniversalOuterInset],
        [self.bodyContainer.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-PPUniversalOuterInset]
    ];

    [NSLayoutConstraint activateConstraints:self.compactLayoutConstraints];
}

- (void)pp_buildActions
{
    if (@available(iOS 14.0, *)) {
        self.menuButton.showsMenuAsPrimaryAction = YES;
    } else {
        [self.menuButton addTarget:self action:@selector(presentOwnerActionsFallback) forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)pp_applyBaseStyling
{
    self.cardView.backgroundColor = PPUniversalCellDynamicColor([UIColor colorWithWhite:0.998 alpha:1.0],
                                                                [UIColor colorWithWhite:0.12 alpha:1.0]);
    self.cardView.layer.cornerRadius = PPUniversalCardCornerRadius;
    self.cardView.layer.borderWidth = 1.0;
    [self.cardView pp_setBorderColor:PPUniversalCellDynamicColor([UIColor colorWithWhite:0.93 alpha:1.0],
                                                                  [UIColor colorWithWhite:0.22 alpha:1.0])];
    [self.cardView pp_setShadowColor:UIColor.blackColor];
    self.cardView.layer.shadowOpacity = 0.08;
    self.cardView.layer.shadowRadius = 16.0;
    self.cardView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    if (@available(iOS 13.0, *)) {
        self.cardView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.imageContainer.layer.borderWidth = 1.0;
    [self.imageContainer pp_setBorderColor:PPUniversalCellDynamicColor([UIColor colorWithWhite:1.0 alpha:0.82],
                                                                        [UIColor colorWithWhite:0.28 alpha:1.0])];

    self.titleLabel.font = PPUniversalCellBoldFont(14.0);
    self.titleLabel.textColor = PPUniversalCellDynamicColor([UIColor colorWithRed:0.10 green:0.11 blue:0.15 alpha:1.0],
                                                            [UIColor colorWithWhite:0.95 alpha:1.0]);
    self.subtitleLabel.font = PPUniversalCellMediumFont(12.0);
    self.subtitleLabel.textColor = PPUniversalCellDynamicColor([UIColor colorWithRed:0.43 green:0.45 blue:0.52 alpha:1.0],
                                                               [UIColor colorWithWhite:0.74 alpha:1.0]);

    self.priceLabel.font = PPUniversalCellBoldFont(28.0);
    self.priceLabel.textColor = AppPrimaryClr;
    self.oldPriceLabel.font = PPUniversalCellMediumFont(12.0);
    self.oldPriceLabel.textColor = PPUniversalCellDynamicColor([UIColor colorWithRed:0.57 green:0.59 blue:0.65 alpha:1.0],
                                                               [UIColor colorWithWhite:0.58 alpha:1.0]);

    self.actionHostView.clipsToBounds = NO;

    self.stepperView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.08];
    self.stepperView.layer.cornerRadius = 17.0;
    self.stepperView.layer.borderWidth = 1.0;
    [self.stepperView pp_setBorderColor:[AppPrimaryClr colorWithAlphaComponent:0.14]];
    if (@available(iOS 13.0, *)) {
        self.stepperView.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

- (void)pp_applyCardGradientForContext:(PPCellContext)ctx
{
    [self.cardGradientLayer removeFromSuperlayer];
    self.cardGradientLayer = nil;
}

#pragma mark - Public API

- (void)applyViewModel:(PPUniversalCellViewModel *)vm
               context:(PPCellContext)context
            layoutMode:(PPManagerCellLayoutMode)layout
          discountMode:(PPDiscountStyle)discountStyle
           imageLoader:(PPImageLoader)loader
{
    self.vm = vm;
    self.context = context;
    self.layoutMode = layout;
    self.discountStyle = discountStyle;
    self.imageLoader = loader;

    [self pp_applySemanticDirection];
    [self.imageContainer applyContextPaletteForContext:context];
    [self pp_applyCardGradientForContext:context];
    [self pp_applyLayoutMode];

    BOOL isSkeleton = vm == nil || vm.isSkeleton;
    [self pp_configureSkeleton:isSkeleton];
    if (isSkeleton) {
        return;
    }

    [self pp_configureImageWithViewModel:vm];
    [self pp_configureTextsWithViewModel:vm];
    [self pp_configureBadgesWithViewModel:vm];
    [self pp_configureControlsWithViewModel:vm];
    [self pp_configureAvailabilityWithViewModel:vm];
    [self pp_configureQuantityStateWithViewModel:vm];
}

- (void)setQuantity:(NSInteger)quantity animated:(BOOL)animated
{
    _quantity = MAX(0, quantity);
    self.quantityLabel.text = [NSString stringWithFormat:@"%ld", (long)_quantity];

    if (_quantity == 0) {
        self.isEditingQuantity = NO;
    }

    [self pp_refreshActionPresentationAnimated:animated];
}

- (void)collapseStepper:(BOOL)animated
{
    if (![self pp_usesQuantityControl]) {
        self.isEditingQuantity = NO;
        self.stepperView.hidden = YES;
        self.stepperView.alpha = 0.0;
        return;
    }

    self.isEditingQuantity = NO;
    [self pp_refreshActionPresentationAnimated:animated];
}

#pragma mark - Configure

- (void)pp_configureSkeleton:(BOOL)isSkeleton
{
    self.skeletonView.hidden = !isSkeleton;
    self.skeletonView.compactLayout = ![self pp_isFullWidthLayout];
    self.imageContainer.alpha = isSkeleton ? 0.0 : 1.0;
    self.bodyContainer.alpha = isSkeleton ? 0.0 : 1.0;
    self.favoriteButton.hidden = isSkeleton;
    self.bodyFavButton.hidden = YES;
    self.shareButton.hidden = isSkeleton;
    self.menuButton.hidden = YES;
    self.reasonBadgeLabel.hidden = isSkeleton;
    self.discountBadgeLabel.hidden = isSkeleton;
    self.categoryBadgeLabel.hidden = isSkeleton;

    if (isSkeleton) {
        [NSLayoutConstraint deactivateConstraints:self.dynamicBadgeConstraints];
        self.dynamicBadgeConstraints = @[];
        [self.skeletonView startAnimating];
    } else {
        [self.skeletonView stopAnimating];
    }
}

- (void)pp_configureImageWithViewModel:(PPUniversalCellViewModel *)vm
{
    UIImage *placeholder = vm.placeholder ?: [UIImage imageNamed:@"placeholder"];
    self.imageView.image = placeholder;
    self.imageView.alpha = 1.0;

    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.imageView];

    NSString *url = PPUniversalCellSafeString(vm.imageURL);
    if (url.length == 0) {
        return;
    }

    if (self.imageLoader) {
        self.imageLoader(self.imageView, url, placeholder, self.cardView);
        return;
    }

    [[PPImageLoaderManager shared] setImageOnImageView:self.imageView
                                                   url:url
                                           placeholder:placeholder
                                            complation:nil];
}

- (void)pp_configureTextsWithViewModel:(PPUniversalCellViewModel *)vm
{
    self.titleLabel.text = PPUniversalCellSafeString(vm.title);
    self.subtitleLabel.text = PPUniversalCellSafeString(vm.subtitle);
    BOOL shouldHideSubtitle = PPUniversalTemporarilyHideSubtitle || self.subtitleLabel.text.length == 0 || !self.showsSubtitle;
    if (shouldHideSubtitle) {
        self.subtitleLabel.text = @"";
    }
    self.subtitleLabel.hidden = shouldHideSubtitle;

    BOOL hasPrice = vm.priceText.length > 0 || vm.finalPrice != nil || vm.price != nil;
    self.priceLabel.attributedText = hasPrice ? [self pp_attributedPriceForViewModel:vm] : nil;
    self.priceLabel.text = hasPrice ? nil : @"";
    self.priceTopToTitleConstraint.active = shouldHideSubtitle;
    self.priceTopToSubtitleConstraint.active = !shouldHideSubtitle;
    self.subtitleHeightConstraint.active = shouldHideSubtitle;

    BOOL showsDiscountedPrice = (vm.price.doubleValue > 0.0 &&
                                 vm.finalPrice.doubleValue > 0.0 &&
                                 fabs(vm.price.doubleValue - vm.finalPrice.doubleValue) > 0.009);
    if (showsDiscountedPrice) {
        NSString *original = PPUniversalCellFormattedPrice(vm.price,
                                                           PPUniversalCellDisplayCurrencyCode(vm.currencyCode));
        NSDictionary *attrs = @{
            NSStrikethroughStyleAttributeName : @(NSUnderlineStyleSingle),
            NSForegroundColorAttributeName : self.oldPriceLabel.textColor,
            NSFontAttributeName : self.oldPriceLabel.font
        };
        self.oldPriceLabel.attributedText = [[NSAttributedString alloc] initWithString:original attributes:attrs];
        self.oldPriceLabel.hidden = NO;
        self.oldPriceCollapsedConstraint.active = NO;
    } else {
        self.oldPriceLabel.attributedText = nil;
        self.oldPriceLabel.hidden = YES;
        self.oldPriceCollapsedConstraint.active = YES;
    }

    BOOL fullWidth = [self pp_isFullWidthLayout];
    CGFloat compactPriceFontSize = [self pp_isServiceLikeContext] ? 21.0 : 23.0;
    self.titleLabel.font = fullWidth ? PPUniversalCellBoldFont(16.0) : PPUniversalCellBoldFont(13.0);
    self.subtitleLabel.font = fullWidth ? PPUniversalCellMediumFont(12.5) : PPUniversalCellMediumFont(13.0);
    self.priceLabel.font = fullWidth ? PPUniversalCellBoldFont(21.0) : PPUniversalCellBoldFont(compactPriceFontSize);
    if (hasPrice) {
        self.priceLabel.attributedText = [self pp_attributedPriceForViewModel:vm];
    }
    //self.priceLabel.backgroundColor = UIColor.redColor;
    //self.titleLabel.backgroundColor = UIColor.blueColor;
}

- (void)pp_configureBadgesWithViewModel:(PPUniversalCellViewModel *)vm
{
    NSString *reasonText = @"";
    if ([self pp_isAdContext]) {
        if (PPUniversalCellReasonLooksNearby(vm.contextualReasonText)) {
            reasonText = PPUniversalCellLocalizedString(@"Home_NearbyAds", @"Nearby");
        } else {
            reasonText = PPUniversalCellSafeString(vm.location);
        }
    }
    NSString *badgeText = PPUniversalTemporarilyHideCategoryBadge ? @"" : PPUniversalCellSafeString(vm.badgeText);
    NSString *discountText = (self.discountStyle == PPDiscountStyleBadge) ? PPUniversalCellSafeString(vm.discountText) : @"";

    self.reasonBadgeLabel.numberOfLines = 0;
    self.reasonBadgeLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self pp_applyBadgeLabel:self.reasonBadgeLabel
                        text:reasonText
                     bgColor:[AppForgroundColr colorWithAlphaComponent:0.34]
                   textColor:AppPrimaryTextClr
                  borderColor:[NewBgColor colorWithAlphaComponent:0.38]];

    [self pp_applyBadgeLabel:self.discountBadgeLabel
                        text:discountText
                     bgColor:[UIColor colorWithRed:0.95 green:0.26 blue:0.34 alpha:0.96]
                   textColor:UIColor.whiteColor
                  borderColor:[UIColor clearColor]];

    [self pp_applyBadgeLabel:self.categoryBadgeLabel
                        text:badgeText
                     bgColor:[UIColor colorWithWhite:1.0 alpha:0.88]
                   textColor:PPUniversalCellDynamicColor([UIColor colorWithRed:0.19 green:0.20 blue:0.24 alpha:1.0],
                                                         [UIColor colorWithWhite:0.08 alpha:1.0])
                  borderColor:[UIColor colorWithWhite:1.0 alpha:0.18]];

    [self pp_updateBadgeConstraints];

    if (self.hideTopBadge) {
        self.reasonBadgeLabel.hidden = YES;
    }
}

- (void)pp_configureControlsWithViewModel:(PPUniversalCellViewModel *)vm
{
    BOOL isOwner = vm.isOwner;
    BOOL hasID = vm.ModelID.length > 0;
    BOOL showsFav = !isOwner && hasID;
    BOOL isAd = [self pp_isAdContext];

    self.shareButton.hidden = PPUniversalTemporarilyHideShareButton;
    self.shareButton.alpha = self.shareButton.hidden ? 0.0 : 1.0;

    if (isAd && showsFav) {
        self.favoriteButton.hidden = NO;
        self.favoriteButton.alpha = 1.0;
        self.favoriteButton.adID = vm.ModelID ?: @"";
        self.favoriteButton.collection = [self pp_favoritesCollectionForContext:self.context];
        [self.favoriteButton initValue];
        self.bodyFavButton.hidden = YES;
        self.bodyFavButton.alpha = 0.0;
        self.priceContainerTrailingToFavConstraint.active = NO;
        self.priceContainerTrailingToBodyConstraint.active = YES;
    } else {
        self.favoriteButton.hidden = !showsFav;
        self.favoriteButton.alpha = showsFav ? 1.0 : 0.0;
        if (showsFav) {
            self.favoriteButton.adID = vm.ModelID ?: @"";
            self.favoriteButton.collection = [self pp_favoritesCollectionForContext:self.context];
            [self.favoriteButton initValue];
        }
        self.bodyFavButton.hidden = YES;
        self.bodyFavButton.alpha = 0.0;
        self.priceContainerTrailingToFavConstraint.active = NO;
        self.priceContainerTrailingToBodyConstraint.active = YES;
    }

    BOOL showMenu = isOwner && !PPUniversalTemporarilyHideMenuButton;
    self.menuButton.hidden = !showMenu;
    self.menuButton.alpha = showMenu ? 1.0 : 0.0;

    [self pp_configureOwnerMenuIfNeeded];
    [self pp_updateBadgeConstraints];
}

- (void)pp_configureAvailabilityWithViewModel:(PPUniversalCellViewModel *)vm
{
    NSString *title = @"";
    UIColor *foreground = UIColor.whiteColor;
    UIColor *background = [UIColor colorWithRed:0.11 green:0.71 blue:0.43 alpha:0.10];
    UIColor *border = [UIColor colorWithRed:0.11 green:0.71 blue:0.43 alpha:0.18];

    if ([self pp_usesQuantityControl]) {
        NSInteger stock = [self pp_stockLimitForCurrentItem];
        if (stock <= 0) {
            title = PPUniversalCellLocalizedString(@"Out of stock", @"Out of stock");
            foreground = [UIColor colorWithRed:0.85 green:0.24 blue:0.28 alpha:1.0];
            background = [foreground colorWithAlphaComponent:0.10];
            border = [foreground colorWithAlphaComponent:0.16];
        } else if (stock < 5) {
            NSString *only = PPUniversalCellLocalizedString(@"Only", @"Only");
            NSString *left = PPUniversalCellLocalizedString(@"left in stock", @"left in stock");
            title = [NSString stringWithFormat:@"%@ %ld %@", only, (long)stock, left];
            foreground = [UIColor colorWithRed:0.87 green:0.49 blue:0.18 alpha:1.0];
            background = [foreground colorWithAlphaComponent:0.12];
            border = [foreground colorWithAlphaComponent:0.16];
        } else {
            title = vm.availabilityText.length > 0
                ? vm.availabilityText
                : PPUniversalCellLocalizedString(@"Available", @"Available");
            foreground = [UIColor colorWithRed:0.15 green:0.62 blue:0.35 alpha:1.0];
            background = [foreground colorWithAlphaComponent:0.10];
            border = [foreground colorWithAlphaComponent:0.14];
        }
    } else {
        title = vm.availabilityText.length > 0 ? vm.availabilityText : PPUniversalCellLocalizedString(@"Available", @"Available");
        NSString *lower = title.lowercaseString;
        BOOL negative = [lower containsString:@"sold"] ||
                        [lower containsString:@"out"] ||
                        [lower containsString:@"نف"] ||
                        [lower containsString:@"غير"];
        if (negative) {
            foreground = [UIColor colorWithRed:0.82 green:0.25 blue:0.29 alpha:1.0];
            background = [foreground colorWithAlphaComponent:0.10];
            border = [foreground colorWithAlphaComponent:0.14];
        } else {
            foreground = [UIColor colorWithRed:0.17 green:0.59 blue:0.42 alpha:1.0];
            background = [foreground colorWithAlphaComponent:0.10];
            border = [foreground colorWithAlphaComponent:0.14];
        }
    }

    if ([self pp_isAdContext]) {
        title = @"";
    }

    self.availabilityLabel.text = title;
    self.availabilityLabel.font = PPUniversalCellBoldFont(12.0);
    self.availabilityLabel.textColor = foreground;
    self.availabilityLabel.backgroundColor = background;
    self.availabilityLabel.layer.cornerRadius = PPUniversalPillHeight / 2.0;
    self.availabilityLabel.layer.borderWidth = 1.0;
    [self.availabilityLabel pp_setBorderColor:border];
    BOOL shouldHideAvailability = title.length == 0;
    self.availabilityLabel.hidden = shouldHideAvailability;
    self.availabilityTopConstraint.constant = shouldHideAvailability ? 0.0 : 10.0;
    self.availabilityHeightConstraint.constant = shouldHideAvailability ? 0.0 : PPUniversalPillHeight;

    ServiceModel *service = [vm.ModelObject isKindOfClass:[ServiceModel class]]
        ? (ServiceModel *)vm.ModelObject
        : nil;
    BOOL showsServiceMeta = [self pp_isServiceLikeContext];
    if (showsServiceMeta) {
        CGFloat rating = MAX(0.0, service.ratingValue.doubleValue);
        NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] init];
        UIColor *starColor = [UIColor colorWithRed:0.97 green:0.72 blue:0.20 alpha:1.0];
        UIColor *valueColor = PPUniversalCellDynamicColor([UIColor colorWithRed:0.10 green:0.11 blue:0.15 alpha:1.0],
                                                          [UIColor colorWithWhite:0.96 alpha:1.0]);

        [attrText appendAttributedString:[[NSAttributedString alloc]
            initWithString:@"★"
            attributes:@{
                NSFontAttributeName: PPUniversalCellBoldFont(13.0),
                NSForegroundColorAttributeName: starColor
            }]];
        [attrText appendAttributedString:[[NSAttributedString alloc]
            initWithString:@"  "
            attributes:@{
                NSFontAttributeName: PPUniversalCellBoldFont(12.0),
                NSForegroundColorAttributeName: valueColor
            }]];
        [attrText appendAttributedString:[[NSAttributedString alloc]
            initWithString:[NSString stringWithFormat:@"%.1f", rating]
            attributes:@{
                NSFontAttributeName: PPUniversalCellBoldFont(12.5),
                NSForegroundColorAttributeName: valueColor
            }]];

        self.serviceMetaLabel.attributedText = attrText;
        self.serviceMetaLabel.font = PPUniversalCellBoldFont(12.0);
        self.serviceMetaLabel.textInsets = UIEdgeInsetsMake(4.0, 12.0, 4.0, 12.0);
        self.serviceMetaLabel.backgroundColor = PPUniversalCellDynamicColor([UIColor colorWithWhite:1.0 alpha:0.98],
                                                                            [UIColor colorWithWhite:0.14 alpha:1.0]);
        self.serviceMetaLabel.layer.cornerRadius = PPUniversalPillHeight / 2.0;
        self.serviceMetaLabel.layer.borderWidth = 1.0;
        [self.serviceMetaLabel pp_setBorderColor:[UIColor colorWithRed:0.96 green:0.86 blue:0.88 alpha:1.0]];
        self.serviceMetaLabel.hidden = NO;
        self.serviceMetaCollapsedConstraint.active = NO;
    } else {
        self.serviceMetaLabel.text = @"";
        self.serviceMetaLabel.attributedText = nil;
        self.serviceMetaLabel.hidden = YES;
        self.serviceMetaCollapsedConstraint.active = YES;
    }

    BOOL tieAvailabilityToServiceMeta = showsServiceMeta && !shouldHideAvailability;
    self.availabilityLeadingToBodyConstraint.active = !tieAvailabilityToServiceMeta;
    self.availabilityLeadingToMetaConstraint.active = tieAvailabilityToServiceMeta;
}

- (void)pp_configureQuantityStateWithViewModel:(PPUniversalCellViewModel *)vm
{
    NSInteger quantity = 0;
    if ([vm.ModelObject isKindOfClass:[PetAccessory class]]) {
        quantity = [CartManager.sharedManager quantityForAccessory:(PetAccessory *)vm.ModelObject];
        NSInteger stock = [self pp_stockLimitForCurrentItem];
        if (stock > 0) {
            quantity = MIN(quantity, stock);
        }
    }

    self.isEditingQuantity = NO;
    [self setQuantity:quantity animated:NO];
}

#pragma mark - Layout + Styling

- (void)pp_applySemanticDirection
{
    UISemanticContentAttribute attr = Language.semanticAttributeForCurrentLanguage;
    NSTextAlignment alignment = Language.alignmentForCurrentLanguage;

    self.semanticContentAttribute = attr;
    self.contentView.semanticContentAttribute = attr;
    self.cardView.semanticContentAttribute = attr;
    self.bodyContainer.semanticContentAttribute = attr;
    self.titleLabel.textAlignment = alignment;
    self.subtitleLabel.textAlignment = alignment;
    self.priceLabel.textAlignment = alignment;
    self.oldPriceLabel.textAlignment = alignment;
    self.serviceMetaLabel.textAlignment = NSTextAlignmentCenter;
    self.availabilityLabel.textAlignment = NSTextAlignmentCenter;
}

- (void)pp_applyLayoutMode
{
    BOOL fullWidth = [self pp_isFullWidthLayout];
    [NSLayoutConstraint deactivateConstraints:self.compactLayoutConstraints];
    [NSLayoutConstraint deactivateConstraints:self.fullWidthLayoutConstraints];
    [NSLayoutConstraint activateConstraints:fullWidth ? self.fullWidthLayoutConstraints : self.compactLayoutConstraints];

    self.fullWidthImageWidthConstraint.active = fullWidth;
    self.fullWidthImageWidthConstraint.constant = MIN(164.0, MAX(126.0, UIScreen.mainScreen.bounds.size.width * 0.30));

    self.imageAspectConstraint.active = NO;
    if (!fullWidth) {
        self.imageAspectConstraint = [self.imageContainer.heightAnchor constraintEqualToAnchor:self.imageContainer.widthAnchor
                                                                                    multiplier:[self pp_imageAspectRatioForCurrentContent]];
        self.imageAspectConstraint.priority = UILayoutPriorityDefaultHigh;
        self.imageAspectConstraint.active = YES;
    }

    self.titleLabel.numberOfLines = fullWidth ? 2 : 1;
    self.subtitleLabel.numberOfLines = fullWidth ? 2 : 1;
    self.titleHeightConstraint.active = !fullWidth;
    self.priceHeightConstraint.active = !fullWidth;
    self.availabilityHeightConstraint.active = !fullWidth;
    self.skeletonView.compactLayout = !fullWidth;
}

- (CGFloat)pp_imageAspectRatioForCurrentContent
{
    CGFloat fallback = 0.82;
    if ([self pp_isAdContext]) {
        fallback = 0.98;
    } else if ([self pp_isServiceLikeContext]) {
        fallback = 0.74;
    } else if ([self pp_usesQuantityControl]) {
        fallback = 0.78;
    }

    CGFloat vmRatio = self.vm.preferredAspectRatio;
    if (vmRatio <= 0.0) {
        return fallback;
    }
    return MAX(0.68, MIN(1.18, vmRatio));
}

- (void)pp_refreshActionPresentationAnimated:(BOOL)animated
{
    BOOL usesQuantity = [self pp_usesQuantityControl];
    self.stepperView.hidden = !usesQuantity || !self.isEditingQuantity || self.quantity <= 0;

    [self pp_configurePrimaryActionButton];
    [self pp_updateStepperButtonStates];

    void (^updates)(void) = ^{
        self.addButton.alpha = self.stepperView.hidden ? 1.0 : 0.0;
        self.stepperView.alpha = self.stepperView.hidden ? 0.0 : 1.0;
        self.stepperView.transform = self.stepperView.hidden
            ? CGAffineTransformMakeScale(0.96, 0.96)
            : CGAffineTransformIdentity;
    };

    if (animated) {
        if (!self.stepperView.hidden) {
            self.stepperView.transform = CGAffineTransformMakeScale(0.96, 0.96);
        }
        [UIView animateWithDuration:0.22
                              delay:0.0
             usingSpringWithDamping:0.90
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:updates
                         completion:^(__unused BOOL finished) {
            self.addButton.hidden = !self.stepperView.hidden;
        }];
    } else {
        updates();
        self.addButton.hidden = !self.stepperView.hidden;
    }
}

- (void)pp_configurePrimaryActionButton
{
    BOOL usesQuantity = [self pp_usesQuantityControl];
    BOOL isOutOfStock = usesQuantity && [self pp_stockLimitForCurrentItem] <= 0;
    BOOL isInCart = usesQuantity && self.quantity > 0;

    NSString *title = nil;
    NSString *imageName = nil;
    UIColor *foreground = UIColor.whiteColor;
    UIColor *background = AppPrimaryClr;
    UIColor *border = [UIColor clearColor];

    if (usesQuantity) {
        if (isOutOfStock) {
            title = PPUniversalCellLocalizedString(@"Out of stock", @"Out of stock");
            imageName = @"exclamationmark.circle.fill";
            foreground = [UIColor colorWithRed:0.83 green:0.25 blue:0.29 alpha:1.0];
            background = [foreground colorWithAlphaComponent:0.10];
            border = [foreground colorWithAlphaComponent:0.14];
        } else if (isInCart) {
            title = [NSString stringWithFormat:@"%@ • %ld",
                     PPUniversalCellLocalizedString(@"InCart", @"In cart"),
                     (long)self.quantity];
            imageName = @"cart.fill";
            foreground = AppPrimaryClr;
            background = [AppPrimaryClr colorWithAlphaComponent:0.09];
            border = [AppPrimaryClr colorWithAlphaComponent:0.14];
        } else {
            title = PPUniversalCellLocalizedString(@"addToCart", @"Add to cart");
            imageName = @"plus.cart.fill";
        }
    } else {
        title = PPUniversalCellLocalizedString(@"Details", @"Details");
        imageName = [self pp_isServiceLikeContext] ? @"sparkles" : @"arrow.up.right";
    }

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        config.baseBackgroundColor = background;
        config.baseForegroundColor = foreground;
        config.background.cornerRadius = 14.0;
        config.background.strokeWidth = (usesQuantity && (isOutOfStock || isInCart)) ? 1.0 : 0.0;
        config.background.strokeColor = border;
        config.image = [UIImage systemImageNamed:imageName];
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.imagePadding = 8.0;
        config.contentInsets = NSDirectionalEdgeInsetsMake(11.0, 14.0, 11.0, 14.0);
        config.title = title;
        UIFont *font = PPUniversalCellBoldFont(14.0);
        config.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
            NSMutableDictionary *attrs = [incoming mutableCopy];
            attrs[NSFontAttributeName] = font;
            attrs[NSForegroundColorAttributeName] = foreground;
            return attrs;
        };
        self.addButton.configuration = config;
    } else {
        [self.addButton setTitle:title forState:UIControlStateNormal];
        [self.addButton setTitleColor:foreground forState:UIControlStateNormal];
        [self.addButton setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
        self.addButton.backgroundColor = background;
        self.addButton.titleLabel.font = PPUniversalCellBoldFont(14.0);
        self.addButton.contentEdgeInsets = UIEdgeInsetsMake(10.0, 14.0, 10.0, 14.0);
        self.addButton.layer.borderWidth = (usesQuantity && (isOutOfStock || isInCart)) ? 1.0 : 0.0;
        [self.addButton pp_setBorderColor:border];
    }

    self.addButton.layer.cornerRadius = 17.0;
    [self.addButton pp_setShadowColor:AppPrimaryClr];
    self.addButton.layer.shadowOpacity = (usesQuantity && (isOutOfStock || isInCart)) ? 0.0 : 0.10;
    self.addButton.layer.shadowRadius = 12.0;
    self.addButton.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    self.addButton.enabled = !isOutOfStock;
}

- (void)pp_updateStepperButtonStates
{
    NSInteger stockLimit = [self pp_stockLimitForCurrentItem];
    BOOL canDecrease = self.quantity > 0;
    BOOL canIncrease = stockLimit <= 0 ? NO : self.quantity < stockLimit;

    self.minusButton.enabled = canDecrease;
    self.minusButton.alpha = canDecrease ? 1.0 : 0.45;
    self.plusButton.enabled = canIncrease;
    self.plusButton.alpha = canIncrease ? 1.0 : 0.45;
}

- (NSAttributedString *)pp_attributedPriceForViewModel:(PPUniversalCellViewModel *)vm
{
    NSNumber *displayPrice = vm.finalPrice ?: vm.price;
    if (!displayPrice) {
        NSString *plainPrice = PPUniversalCellSafeString(vm.priceText);
        if (plainPrice.length == 0) {
            return nil;
        }
        return [[NSAttributedString alloc] initWithString:plainPrice attributes:@{
            NSFontAttributeName : self.priceLabel.font ?: PPUniversalCellBoldFont(21.0),
            NSForegroundColorAttributeName : self.priceLabel.textColor ?: AppPrimaryClr
        }];
    }

    NSString *displayCurrency = PPUniversalCellDisplayCurrencyCode(vm.currencyCode);
    NSString *formattedAmount = PPUniversalCellFormattedAmountString(displayPrice);
    NSArray<NSString *> *parts = [formattedAmount componentsSeparatedByString:@"."];
    NSString *integerPart = parts.firstObject.length > 0 ? parts.firstObject : @"0";
    NSString *fractionPart = parts.count > 1 ? parts.lastObject : @"00";
    UIFont *integerFont = self.priceLabel.font ?: PPUniversalCellBoldFont(21.0);
    CGFloat currencySize = MAX(9.0, floor(integerFont.pointSize * 0.40));
    CGFloat fractionSize = MAX(9.0, floor(integerFont.pointSize * 0.46));
    UIFont *currencyFont = PPUniversalCellBoldFont(currencySize);
    UIFont *fractionFont = PPUniversalCellBoldFont(fractionSize);
    UIColor *priceColor = self.priceLabel.textColor ?: AppPrimaryClr;
    CGFloat currencyLift = MAX(4.0, round(integerFont.pointSize * 0.28));
    CGFloat fractionLift = MAX(5.0, round(integerFont.pointSize * 0.34));
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = self.priceLabel.textAlignment;
    paragraph.baseWritingDirection = Language.isRTL ? NSWritingDirectionRightToLeft : NSWritingDirectionLeftToRight;

    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
    NSAttributedString *currencyString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@", displayCurrency]
                                                                         attributes:@{
        NSFontAttributeName : currencyFont,
        NSForegroundColorAttributeName : priceColor,
        NSBaselineOffsetAttributeName : @(currencyLift),
        NSParagraphStyleAttributeName : paragraph
    }];
    NSAttributedString *integerString = [[NSAttributedString alloc] initWithString:integerPart
                                                                         attributes:@{
        NSFontAttributeName : integerFont,
        NSForegroundColorAttributeName : priceColor,
        NSParagraphStyleAttributeName : paragraph
    }];
    NSAttributedString *fractionString = [[NSAttributedString alloc] initWithString:fractionPart
                                                                          attributes:@{
        NSFontAttributeName : fractionFont,
        NSForegroundColorAttributeName : priceColor,
        NSBaselineOffsetAttributeName : @(fractionLift),
        NSParagraphStyleAttributeName : paragraph
    }];

    if (Language.isRTL) {
        [result appendAttributedString:integerString];
        [result appendAttributedString:fractionString];
        [result appendAttributedString:currencyString];
    } else {
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ ", displayCurrency]
                                                                       attributes:@{
            NSFontAttributeName : currencyFont,
            NSForegroundColorAttributeName : priceColor,
            NSBaselineOffsetAttributeName : @(currencyLift),
            NSParagraphStyleAttributeName : paragraph
        }]];
        [result appendAttributedString:integerString];
        [result appendAttributedString:fractionString];
    }
    return result;
}

#pragma mark - Actions

- (void)handleCardTap
{
    if (!self.vm || self.vm.isSkeleton) {
        return;
    }

    [UIView animateWithDuration:0.10 animations:^{
        self.cardView.transform = CGAffineTransformMakeScale(0.985, 0.985);
    } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.16 animations:^{
            self.cardView.transform = CGAffineTransformIdentity;
        }];
    }];

    if (self.onTap) {
        self.onTap();
    }
    if ([self.delegate respondsToSelector:@selector(PPUniversalCell_tapCard:)]) {
        [self.delegate PPUniversalCell_tapCard:self.vm];
    }
}

- (void)tapShare
{
    if (!self.vm) {
        return;
    }

    if ([self.delegate respondsToSelector:@selector(PPUniversalCell_tapShare:)]) {
        [self.delegate PPUniversalCell_tapShare:self.vm];
        return;
    }

    UIViewController *parentVC = [self pp_parentViewController];
    if (!parentVC) {
        return;
    }

    if ([self.vm.ModelObject isKindOfClass:[PetAd class]]) {
        [PetAd sharePetAd:(PetAd *)self.vm.ModelObject fromViewController:parentVC sourceView:self.shareButton];
    } else if ([self.vm.ModelObject isKindOfClass:[PetAccessory class]]) {
        [PetAccessory sharePetAccessory:(PetAccessory *)self.vm.ModelObject fromViewController:parentVC sourceView:self.shareButton];
    }
}

- (void)tapFavorite
{
    if ([self.delegate respondsToSelector:@selector(PPUniversalCell_tapFavorite:)]) {
        [self.delegate PPUniversalCell_tapFavorite:self.vm];
    }
}

- (void)tapEdit
{
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    if ([self.delegate respondsToSelector:@selector(PPUniversalCell_tapEdit:)]) {
        [self.delegate PPUniversalCell_tapEdit:self.vm];
    }
}

- (void)tapDelete
{
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    if ([self.delegate respondsToSelector:@selector(PPUniversalCell_tapDelete:)]) {
        [self.delegate PPUniversalCell_tapDelete:self.vm];
    }
}

- (void)tapAddCollapsed
{
    if (![self pp_usesQuantityControl]) {
        [self handleCardTap];
        return;
    }

    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    NSInteger stockLimit = [self pp_stockLimitForCurrentItem];
    if (stockLimit <= 0) {
        [self pp_showOutOfStockFeedback];
        [self setQuantity:0 animated:YES];
        return;
    }

    self.isEditingQuantity = YES;
    if (self.quantity > 0) {
        [self pp_refreshActionPresentationAnimated:YES];
        [self restartStepperCollapseTimer];
        return;
    }

    [self pp_animatePrimaryActionPulse];
    NSInteger nextQuantity = MIN(1, stockLimit);
    [self setQuantity:nextQuantity animated:YES];
    if ([self.delegate respondsToSelector:@selector(PPUniversalCell_changeQuantity:quantity:)]) {
        [self.delegate PPUniversalCell_changeQuantity:self.vm quantity:nextQuantity];
    }
    [self restartStepperCollapseTimer];
}

- (void)tapMinus
{
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    NSInteger q = MAX(0, self.quantity - 1);
    [self setQuantity:q animated:YES];
    if ([self.delegate respondsToSelector:@selector(PPUniversalCell_changeQuantity:quantity:)]) {
        [self.delegate PPUniversalCell_changeQuantity:self.vm quantity:q];
    }
    [self restartStepperCollapseTimer];
}

- (void)tapPlus
{
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    NSInteger stockLimit = [self pp_stockLimitForCurrentItem];
    if (stockLimit <= 0) {
        [self pp_showOutOfStockFeedback];
        [self setQuantity:0 animated:YES];
        return;
    }
    if (self.quantity >= stockLimit) {
        [self pp_showStockLimitFeedback:stockLimit];
        [self restartStepperCollapseTimer];
        return;
    }

    NSInteger q = MIN(stockLimit, self.quantity + 1);
    [self setQuantity:q animated:YES];
    if ([self.delegate respondsToSelector:@selector(PPUniversalCell_changeQuantity:quantity:)]) {
        [self.delegate PPUniversalCell_changeQuantity:self.vm quantity:q];
    }
    [self restartStepperCollapseTimer];
}

- (void)presentOwnerActionsFallback
{
    UIViewController *parentVC = [self pp_parentViewController];
    if (!parentVC) {
        return;
    }

    [PPAlertHelper showThreeActionConfirmationIn:parentVC
                                           title:PPUniversalCellLocalizedString(@"Options", @"Options")
                                        subtitle:nil
                                   primaryButton:PPUniversalCellLocalizedString(@"Edit", @"Edit")
                                    primaryStyle:UIAlertActionStyleDefault
                                 secondaryButton:PPUniversalCellLocalizedString(@"Delete", @"Delete")
                                  secondaryStyle:UIAlertActionStyleDestructive
                                  tertiaryButton:PPUniversalCellLocalizedString(@"Cancel", @"Cancel")
                                   tertiaryStyle:UIAlertActionStyleCancel
                                    primaryBlock:^{
        [self tapEdit];
    }
                                  secondaryBlock:^{
        [PPAlertHelper showConfirmationIn:parentVC
                                    title:kLang(@"DeleteConfirmTitle") ?: @"Delete"
                                 subtitle:kLang(@"DeleteConfirmMessage") ?: @"Are you sure you want to delete this item?"
                            confirmButton:kLang(@"yes") ?: @"Yes"
                             cancelButton:kLang(@"no") ?: @"No"
                                     icon:PPSYSImage(@"trash")
                             confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
            if (!didConfirm) return;
            [self tapDelete];
        }
                              cancelBlock:nil];
    }
                                   tertiaryBlock:nil];
}

#pragma mark - Helpers

- (UIButton *)pp_makeIconButtonWithSystemName:(NSString *)systemName
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = PPUniversalCellDynamicColor([UIColor colorWithRed:0.28 green:0.30 blue:0.35 alpha:1.0],
                                                   [UIColor colorWithWhite:0.96 alpha:1.0]);
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.86];
    button.layer.cornerRadius = PPUniversalControlButtonSize / 2.0;
    button.layer.borderWidth = 1.0;
    [button pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.32]];
    [button pp_setShadowColor:UIColor.blackColor];
    button.layer.shadowOpacity = 0.06;
    button.layer.shadowRadius = 8.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 3.0);
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIImageSymbolConfiguration *symbolConfig =
    [UIImageSymbolConfiguration configurationWithPointSize:16.0
                                                    weight:UIImageSymbolWeightSemibold
                                                     scale:UIImageSymbolScaleMedium];
    [button setPreferredSymbolConfiguration:symbolConfig forImageInState:UIControlStateNormal];
    [button setImage:[UIImage systemImageNamed:systemName] forState:UIControlStateNormal];

    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:PPUniversalControlButtonSize],
        [button.heightAnchor constraintEqualToConstant:PPUniversalControlButtonSize]
    ]];

    return button;
}

- (UIButton *)pp_makeStepperButtonWithSystemName:(NSString *)systemName
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = AppPrimaryClr;
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.84];
    button.layer.cornerRadius = 15.0;
    button.layer.masksToBounds = YES;
    UIImageSymbolConfiguration *symbolConfig =
    [UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                    weight:UIImageSymbolWeightBold
                                                     scale:UIImageSymbolScaleMedium];
    [button setPreferredSymbolConfiguration:symbolConfig forImageInState:UIControlStateNormal];
    [button setImage:[UIImage systemImageNamed:systemName] forState:UIControlStateNormal];
    return button;
}

- (PPUniversalInsetLabel *)pp_makeBadgeLabel
{
    PPUniversalInsetLabel *label = [[PPUniversalInsetLabel alloc] init];
    label.font = PPUniversalCellBoldFont(11.0);
    label.textInsets = UIEdgeInsetsMake(5.0, 10.0, 5.0, 10.0);
    label.layer.cornerRadius = 12.0;
    return label;
}

- (void)pp_applyBadgeLabel:(PPUniversalInsetLabel *)label
                      text:(NSString *)text
                   bgColor:(UIColor *)bgColor
                 textColor:(UIColor *)textColor
                borderColor:(UIColor *)borderColor
{
    label.text = text;
    label.textColor = textColor;
    label.backgroundColor = bgColor;
    label.layer.borderWidth = CGColorGetAlpha(borderColor.CGColor) > 0.001 ? 1.0 : 0.0;
    [label pp_setBorderColor:borderColor];
    label.hidden = text.length == 0;
}

- (void)pp_updateBadgeConstraints
{
    [NSLayoutConstraint deactivateConstraints:self.dynamicBadgeConstraints];

    NSArray<PPUniversalInsetLabel *> *orderedBadges = @[
        self.discountBadgeLabel,
        self.reasonBadgeLabel
    ];

    NSMutableArray<PPUniversalInsetLabel *> *visibleBadges = [NSMutableArray array];
    for (PPUniversalInsetLabel *badge in orderedBadges) {
        if (!badge.hidden) {
            [visibleBadges addObject:badge];
        }
    }

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray array];
    if (visibleBadges.count == 0) {
        self.dynamicBadgeConstraints = @[];
        return;
    }

    NSLayoutXAxisAnchor *currentTrailingAnchor = self.menuButton.hidden
        ? self.imageContainer.trailingAnchor
        : self.menuButton.leadingAnchor;
    CGFloat trailingSpacing = self.menuButton.hidden ? -12.0 : -8.0;
    PPUniversalInsetLabel *leftMostBadge = nil;

    for (PPUniversalInsetLabel *badge in visibleBadges) {
        [constraints addObject:[badge.topAnchor constraintEqualToAnchor:self.imageContainer.topAnchor constant:12.0]];
        [constraints addObject:[badge.trailingAnchor constraintEqualToAnchor:currentTrailingAnchor constant:trailingSpacing]];
        currentTrailingAnchor = badge.leadingAnchor;
        trailingSpacing = -6.0;
        leftMostBadge = badge;
    }

    NSLayoutXAxisAnchor *minimumLeadingAnchor = self.favoriteButton.hidden
        ? self.imageContainer.leadingAnchor
        : self.favoriteButton.trailingAnchor;
    CGFloat leadingSpacing = self.favoriteButton.hidden ? 12.0 : 8.0;
    [constraints addObject:[leftMostBadge.leadingAnchor constraintGreaterThanOrEqualToAnchor:minimumLeadingAnchor constant:leadingSpacing]];

    self.dynamicBadgeConstraints = constraints;
    [NSLayoutConstraint activateConstraints:self.dynamicBadgeConstraints];
}

- (NSInteger)pp_stockLimitForCurrentItem
{
    if ([self.vm.ModelObject isKindOfClass:[PetAccessory class]]) {
        return MAX(((PetAccessory *)self.vm.ModelObject).quantity, 0);
    }
    return MAX(self.vm.itemQuantitiy, 0);
}

- (BOOL)pp_usesQuantityControl
{
    return [self.vm.ModelObject isKindOfClass:[PetAccessory class]] ||
           self.context == PPCellForMarket ||
           self.context == PPCellForFood ||
           self.context == PPCellForContextAccessory;
}

- (BOOL)pp_isAdContext
{
    return [self.vm.ModelObject isKindOfClass:[PetAd class]] ||
           self.context == PPCellForAds ||
           self.context == PPCellForHomeAds;
}

- (BOOL)pp_isServiceLikeContext
{
    return [self.vm.ModelObject isKindOfClass:[ServiceModel class]] ||
           [self.vm.ModelObject isKindOfClass:[VetModel class]] ||
           self.context == PPCellForServices ||
           self.context == PPCellForVets;
}

- (BOOL)pp_isFullWidthLayout
{
    return self.layoutMode == PPCellLayoutModeFullWidth;
}

- (void)pp_showOutOfStockFeedback
{
    [PPHUD showError:PPUniversalCellLocalizedString(@"Out of stock", @"Out of stock")];
    [PPFunc triggerWarningHaptic];
}

- (void)pp_showStockLimitFeedback:(NSInteger)stockLimit
{
    NSString *only = PPUniversalCellLocalizedString(@"Only", @"Only");
    NSString *left = PPUniversalCellLocalizedString(@"left in stock", @"left in stock");
    [PPHUD showInfo:[NSString stringWithFormat:@"%@ %ld %@", only, (long)stockLimit, left]];
    [PPFunc triggerMediumHaptic];
}

- (void)pp_animatePrimaryActionPulse
{
    self.addButton.transform = CGAffineTransformMakeScale(0.96, 0.96);
    [UIView animateWithDuration:0.20
                          delay:0.0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.addButton.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)restartStepperCollapseTimer
{
    [self.stepperCollapseTimer invalidate];
    self.stepperCollapseTimer = [NSTimer scheduledTimerWithTimeInterval:PPUniversalStepperAutoCollapseDelay
                                                                 target:self
                                                               selector:@selector(handleStepperAutoCollapseTimer)
                                                               userInfo:nil
                                                                repeats:NO];
}

- (void)handleStepperAutoCollapseTimer
{
    [self collapseStepper:YES];
}

- (NSString *)pp_favoritesCollectionForContext:(PPCellContext)context
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

- (void)pp_configureOwnerMenuIfNeeded
{
    if (!self.vm.isOwner) {
        if (@available(iOS 14.0, *)) {
            self.menuButton.menu = nil;
        }
        return;
    }

    if (@available(iOS 14.0, *)) {
        __weak typeof(self) weakSelf = self;
        UIAction *edit = [UIAction actionWithTitle:PPUniversalCellLocalizedString(@"Edit", @"Edit")
                                             image:[UIImage systemImageNamed:@"square.and.pencil"]
                                        identifier:nil
                                           handler:^(__unused UIAction * _Nonnull action) {
            [weakSelf tapEdit];
        }];
        UIAction *deleteAction = [UIAction actionWithTitle:PPUniversalCellLocalizedString(@"Delete", @"Delete")
                                                     image:[UIImage systemImageNamed:@"trash"]
                                                identifier:nil
                                                   handler:^(__unused UIAction * _Nonnull action) {
            [weakSelf tapDelete];
        }];
        deleteAction.attributes = UIMenuElementAttributesDestructive;
        self.menuButton.menu = [UIMenu menuWithTitle:@"" children:@[edit, deleteAction]];
    }
}

- (UIViewController *)pp_parentViewController
{
    UIResponder *responder = self;
    while (responder) {
        responder = responder.nextResponder;
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
    }
    return nil;
}

#pragma mark - Gesture Delegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    (void)gestureRecognizer;
    // Only consume the tap when a handler is actually wired up.
    // VCs that rely on collectionView:didSelectItemAtIndexPath: (e.g. Home)
    // need the touch to fall through to the collection view.
    return (self.onTap != nil ||
            [self.delegate respondsToSelector:@selector(PPUniversalCell_tapCard:)]);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    (void)gestureRecognizer;
    UIView *view = touch.view;
    while (view) {
        if ([view isKindOfClass:[UIControl class]]) {
            return NO;
        }
        view = view.superview;
    }
    return YES;
}

@end









