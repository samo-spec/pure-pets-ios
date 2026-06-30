//
//  PPProviderCompanyPremiumCardCell.m
//  Pure Pets
//
//  Studio-grade iOS provider card inspired by premium product-card layout.
//

#import "PPProviderCompanyPremiumCardCell.h"
#import <QuartzCore/QuartzCore.h>
#import "PPImageLoaderManager.h"
static CGFloat PPProviderPremiumClamp(CGFloat value, CGFloat minValue, CGFloat maxValue)
{
    return MIN(MAX(value, minValue), maxValue);
}

static UIColor *PPProviderPremiumDynamicColor(UIColor *lightColor, UIColor *darkColor)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static void PPProviderPremiumApplyContinuousCorners(UIView *view, CGFloat radius)
{
    view.layer.cornerRadius = radius;
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

static UIFont *PPProviderPremiumRoundedFont(CGFloat size, UIFontWeight weight, UIFontTextStyle textStyle)
{
    UIFont *font = nil;
    if (@available(iOS 13.0, *)) {
        font = [UIFont systemFontOfSize:size weight:weight];
        UIFontDescriptor *descriptor = [font.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
        if (descriptor) {
            font = [UIFont fontWithDescriptor:descriptor size:size];
        }
    } else {
        font = [UIFont systemFontOfSize:size weight:weight];
    }

    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:font];
    }
    return font;
}

static UIImage *PPProviderPremiumSymbolImage(NSString *name, CGFloat pointSize, UIImageSymbolWeight weight)
{
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:weight];
        return [[UIImage systemImageNamed:name withConfiguration:configuration] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return nil;
}

static UIColor *PPProviderPremiumSurfaceColor(void)
{
    return PPProviderPremiumDynamicColor([UIColor colorWithWhite:1.0 alpha:0.96],
                                         [UIColor colorWithWhite:0.105 alpha:0.86]);
}

static UIColor *PPProviderPremiumStageColor(void)
{
    return PPProviderPremiumDynamicColor([UIColor colorWithWhite:0.965 alpha:1.0],
                                         [UIColor colorWithWhite:1.0 alpha:0.075]);
}

// --- Gradient Helper Functions ---
static NSArray *PPProviderPremiumStageGradientColors(UIColor *accentColor)
{
    UIColor *accent = accentColor ?: [UIColor colorWithRed:0.93 green:0.43 blue:0.18 alpha:1.0];

    UIColor *topWash = PPProviderPremiumDynamicColor([UIColor colorWithWhite:1.0 alpha:0.92],
                                                     [UIColor colorWithWhite:1.0 alpha:0.075]);
    UIColor *middleTint = PPProviderPremiumDynamicColor([accent colorWithAlphaComponent:0.18],
                                                        [accent colorWithAlphaComponent:0.18]);
    UIColor *lowerDepth = PPProviderPremiumDynamicColor([UIColor colorWithWhite:0.0 alpha:0.035],
                                                        [UIColor colorWithWhite:0.0 alpha:0.24]);

    return @[
        (__bridge id)topWash.CGColor,
        (__bridge id)middleTint.CGColor,
        (__bridge id)lowerDepth.CGColor
    ];
}

static NSArray *PPProviderPremiumVignetteColors(void)
{
    UIColor *topLift = PPProviderPremiumDynamicColor([UIColor colorWithWhite:1.0 alpha:0.36],
                                                    [UIColor colorWithWhite:1.0 alpha:0.10]);
    UIColor *clearMid = [UIColor clearColor];
    UIColor *bottomDepth = PPProviderPremiumDynamicColor([UIColor colorWithWhite:0.0 alpha:0.16],
                                                        [UIColor colorWithWhite:0.0 alpha:0.38]);

    return @[
        (__bridge id)topLift.CGColor,
        (__bridge id)[clearMid colorWithAlphaComponent:0.0].CGColor,
        (__bridge id)bottomDepth.CGColor
    ];
}

static NSArray *PPProviderPremiumDoubleFadeColors(void)
{
    UIColor *topWhite = PPProviderPremiumDynamicColor([UIColor colorWithWhite:1.0 alpha:0.52],
                                                     [UIColor colorWithWhite:1.0 alpha:0.12]);
    UIColor *middleAir = [UIColor clearColor];
    UIColor *lowerInk = PPProviderPremiumDynamicColor([UIColor colorWithWhite:0.0 alpha:0.12],
                                                     [UIColor colorWithWhite:0.0 alpha:0.30]);

    return @[
        (__bridge id)topWhite.CGColor,
        (__bridge id)[middleAir colorWithAlphaComponent:0.0].CGColor,
        (__bridge id)lowerInk.CGColor
    ];
}

static UIColor *PPProviderPremiumPrimaryTextColor(void)
{
    if (@available(iOS 13.0, *)) {
        return UIColor.labelColor;
    }
    return [UIColor colorWithWhite:0.11 alpha:1.0];
}

static UIColor *PPProviderPremiumSecondaryTextColor(void)
{
    if (@available(iOS 13.0, *)) {
        return UIColor.secondaryLabelColor;
    }
    return [UIColor colorWithWhite:0.52 alpha:1.0];
}

static UIColor *PPProviderPremiumStrokeColor(void)
{
    return PPProviderPremiumDynamicColor([UIColor colorWithWhite:0.0 alpha:0.060],
                                         [UIColor colorWithWhite:1.0 alpha:0.115]);
}

static UIEdgeInsets PPProviderPremiumCardInsets(void)
{
    return UIEdgeInsetsMake(8.0, 16.0, 8.0, 16.0);
}

static CGFloat PPProviderPremiumStageHeightForTableWidth(CGFloat tableWidth)
{
    CGFloat cardWidth = MAX(tableWidth - PPProviderPremiumCardInsets().left - PPProviderPremiumCardInsets().right, 0.0);
    return PPProviderPremiumClamp(cardWidth * 0.575, 198.0, 246.0);
}

static NSString *PPProviderPremiumSafeText(NSString * _Nullable value)
{
    return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSAttributedString *PPProviderPremiumMetricText(NSString *valueText,
                                                       NSString *titleText,
                                                       UIColor *accentColor)
{
    NSString *value = [PPProviderPremiumSafeText(valueText)
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *title = [PPProviderPremiumSafeText(titleText)
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *fullText = @"";
    if (value.length && title.length) {
        fullText = [title rangeOfString:value].location != NSNotFound
            ? title
            : [NSString stringWithFormat:@"%@ %@", value, title];
    } else {
        fullText = value.length ? value : title;
    }
    UIColor *accent = accentColor ?: [UIColor colorWithRed:0.93 green:0.43 blue:0.18 alpha:1.0];
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:fullText attributes:@{
        NSFontAttributeName: PPProviderPremiumRoundedFont(12.0, UIFontWeightSemibold, UIFontTextStyleCaption1),
        NSForegroundColorAttributeName: [PPProviderPremiumPrimaryTextColor() colorWithAlphaComponent:0.74]
    }];
    if (value.length > 0) {
        NSRange valueRange = [fullText rangeOfString:value];
        if (valueRange.location != NSNotFound) {
            [text addAttributes:@{
                NSFontAttributeName: PPProviderPremiumRoundedFont(12.0, UIFontWeightHeavy, UIFontTextStyleCaption1),
                NSForegroundColorAttributeName: [accent colorWithAlphaComponent:0.92]
            } range:valueRange];
        }
    }
    return text;
}

static UIImage *PPProviderPremiumInitialsImage(NSString *title, UIColor *accentColor, CGSize size)
{
    CGFloat scale = UIScreen.mainScreen.scale ?: 2.0;
    UIGraphicsBeginImageContextWithOptions(size, NO, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        UIGraphicsEndImageContext();
        return nil;
    }

    UIColor *start = [accentColor colorWithAlphaComponent:0.22];
    UIColor *end = [accentColor colorWithAlphaComponent:0.055];
    NSArray *colors = @[(__bridge id)start.CGColor, (__bridge id)end.CGColor];
    CGFloat locations[] = {0.0, 1.0};
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);
    CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0, 0.0), CGPointMake(size.width, size.height), 0);

    NSString *trimmed = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *initial = trimmed.length > 0 ? [[trimmed substringToIndex:1] uppercaseString] : @"P";
    UIFont *font = PPProviderPremiumRoundedFont(MIN(size.width, size.height) * 0.34, UIFontWeightHeavy, UIFontTextStyleLargeTitle);
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: [accentColor colorWithAlphaComponent:0.82]
    };
    CGSize textSize = [initial sizeWithAttributes:attributes];
    CGRect textRect = CGRectMake((size.width - textSize.width) * 0.5,
                                 (size.height - textSize.height) * 0.5 - 2.0,
                                 textSize.width,
                                 textSize.height);
    [initial drawInRect:textRect withAttributes:attributes];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    UIGraphicsEndImageContext();
    return image;
}

@interface PPProviderPremiumTopPocketView : UIView
@end

@implementation PPProviderPremiumTopPocketView

- (void)layoutSubviews
{
    [super layoutSubviews];
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                               byRoundingCorners:(UIRectCornerTopRight | UIRectCornerBottomLeft)
                                                     cornerRadii:CGSizeMake(34.0, 34.0)];
    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.frame = self.bounds;
    mask.path = path.CGPath;
    self.layer.mask = mask;
}

@end

@implementation PPProviderCompanyPremiumCardViewModel

- (instancetype)init
{
    self = [super init];
    if (self) {
        _providerIdentifier = @"";
        _title = @"";
        _subtitle = @"";
        _categoryText = @"";
        _countTitleText = @"";
        _countValueText = @"0";
        _countDisplayText = @"";
        _ratingText = kLang(@"provider_rating_new") ?: @"New";
        _ratingCountText = @"";
        _cityText = @"";
        _accentColor = [UIColor colorWithRed:0.93 green:0.43 blue:0.18 alpha:1.0];
        _accessoryStyle = PPProviderCompanyPremiumCardAccessoryStyleHeart;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    PPProviderCompanyPremiumCardViewModel *copy = [[[self class] allocWithZone:zone] init];
    copy.providerIdentifier = self.providerIdentifier;
    copy.title = self.title;
    copy.subtitle = self.subtitle;
    copy.categoryText = self.categoryText;
    copy.countTitleText = self.countTitleText;
    copy.countValueText = self.countValueText;
    copy.countDisplayText = self.countDisplayText;
    copy.ratingText = self.ratingText;
    copy.ratingCountText = self.ratingCountText;
    copy.cityText = self.cityText;
    copy.imageURL = self.imageURL;
    copy.placeholderImage = self.placeholderImage;
    copy.accentColor = self.accentColor;
    copy.verified = self.verified;
    copy.active = self.active;
    copy.favorite = self.favorite;
    copy.accessoryStyle = self.accessoryStyle;
    return copy;
}

@end

@interface PPProviderCompanyPremiumCardCell ()
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *imageStageView;
@property (nonatomic, strong) UIImageView *coverImageView;
@property (nonatomic, strong) CAGradientLayer *stageGradientLayer;
@property (nonatomic, strong) CAGradientLayer *vignetteLayer;
@property (nonatomic, strong) CAGradientLayer *doubleFadeLayer;
@property (nonatomic, strong) UIView *highlightBloomView;
@property (nonatomic, strong) UIView *topBadgeView;
@property (nonatomic, strong) UIImageView *topBadgeIconView;
@property (nonatomic, strong) UILabel *topBadgeLabel;
@property (nonatomic, strong) UIView *accessoryPocketView;
@property (nonatomic, strong) UIButton *accessoryButton;
@property (nonatomic, strong) UIView *contentPanelView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIStackView *metricsRailStackView;
@property (nonatomic, strong) UIView *countPillView;
@property (nonatomic, strong) UILabel *countTitleLabel;
@property (nonatomic, strong) UIView *contactPillView;
@property (nonatomic, strong) UIImageView *contactIconView;
@property (nonatomic, strong) UILabel *contactLabel;
@property (nonatomic, strong) UILabel *metaFootnoteLabel;
@property (nonatomic, strong) UIView *ratingPillView;
@property (nonatomic, strong) UIImageView *ratingIconView;
@property (nonatomic, strong) UILabel *ratingLabel;


@property (nonatomic, strong) NSLayoutConstraint *imageStageHeightConstraint;
@property (nonatomic, strong) PPProviderCompanyPremiumCardViewModel *viewModel;
@end

@implementation PPProviderCompanyPremiumCardCell

+ (NSString *)reuseIdentifier
{
    return NSStringFromClass(self.class);
}

+ (CGFloat)preferredHeightForTableWidth:(CGFloat)tableWidth
{
    CGFloat stageHeight = PPProviderPremiumStageHeightForTableWidth(tableWidth);
    return stageHeight + 110.0;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self pp_buildUI];
    }
    return self;
}

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    self.cardView = [[UIView alloc] init];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.backgroundColor = [PPProviderPremiumSurfaceColor() colorWithAlphaComponent:0.72];
    self.cardView.layer.borderWidth = 0.70;
    self.cardView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.cardView.layer.shadowOpacity = 0.085;
    self.cardView.layer.shadowRadius = 24.0;
    self.cardView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    PPProviderPremiumApplyContinuousCorners(self.cardView, 22.0);
    [self.contentView addSubview:self.cardView];

    self.imageStageView = [[UIView alloc] init];
    self.imageStageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageStageView.backgroundColor = PPProviderPremiumStageColor();
    self.imageStageView.clipsToBounds = YES;
    PPProviderPremiumApplyContinuousCorners(self.imageStageView, 20.0);
    [self.cardView addSubview:self.imageStageView];

    self.stageGradientLayer = [CAGradientLayer layer];
    self.stageGradientLayer.startPoint = CGPointMake(0.12, 0.0);
    self.stageGradientLayer.endPoint = CGPointMake(0.88, 1.0);
    self.stageGradientLayer.locations = @[@0.0, @0.48, @1.0];
    self.stageGradientLayer.colors = PPProviderPremiumStageGradientColors(nil);
    [self.imageStageView.layer addSublayer:self.stageGradientLayer];

    self.highlightBloomView = [[UIView alloc] init];
    self.highlightBloomView.translatesAutoresizingMaskIntoConstraints = NO;
    self.highlightBloomView.userInteractionEnabled = NO;
    self.highlightBloomView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.24];
    self.highlightBloomView.layer.shadowColor = UIColor.whiteColor.CGColor;
    self.highlightBloomView.layer.shadowOpacity = 0.55;
    self.highlightBloomView.layer.shadowRadius = 34.0;
    self.highlightBloomView.layer.shadowOffset = CGSizeZero;
    [self.imageStageView addSubview:self.highlightBloomView];

    self.coverImageView = [[UIImageView alloc] init];
    self.coverImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.coverImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.coverImageView.clipsToBounds = YES;
    self.coverImageView.backgroundColor = UIColor.clearColor;
    self.coverImageView.isAccessibilityElement = NO;
    [self.imageStageView addSubview:self.coverImageView];

    self.vignetteLayer = [CAGradientLayer layer];
    self.vignetteLayer.startPoint = CGPointMake(0.5, 0.0);
    self.vignetteLayer.endPoint = CGPointMake(0.5, 1.0);
    self.vignetteLayer.locations = @[@0.0, @0.58, @1.0];
    self.vignetteLayer.colors = PPProviderPremiumVignetteColors();
    [self.imageStageView.layer addSublayer:self.vignetteLayer];

    self.doubleFadeLayer = [CAGradientLayer layer];
    self.doubleFadeLayer.startPoint = CGPointMake(0.5, 0.0);
    self.doubleFadeLayer.endPoint = CGPointMake(0.5, 1.0);
    self.doubleFadeLayer.locations = @[@0.0, @0.50, @1.0];
    self.doubleFadeLayer.colors = PPProviderPremiumDoubleFadeColors();
    self.doubleFadeLayer.opacity = 0.88;
    [self.imageStageView.layer addSublayer:self.doubleFadeLayer];

    self.topBadgeView = [[UIView alloc] init];
    self.topBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topBadgeView.backgroundColor = [PPProviderPremiumSurfaceColor() colorWithAlphaComponent:0.82];
    self.topBadgeView.layer.borderWidth = 0.55;
    self.topBadgeView.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:0.50].CGColor;
    self.topBadgeView.clipsToBounds = NO;
    PPProviderPremiumApplyContinuousCorners(self.topBadgeView, 17.0);
    [self.imageStageView addSubview:self.topBadgeView];

    self.topBadgeIconView = [[UIImageView alloc] init];
    self.topBadgeIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topBadgeIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.topBadgeIconView.image = PPProviderPremiumSymbolImage(@"checkmark.seal.fill", 12.0, UIImageSymbolWeightSemibold);
    [self.topBadgeView addSubview:self.topBadgeIconView];

    self.topBadgeLabel = [[UILabel alloc] init];
    self.topBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.topBadgeLabel.font = [GM boldFontWithSize:13];
    self.topBadgeLabel.adjustsFontForContentSizeCategory = YES;
    self.topBadgeLabel.numberOfLines = 1;
    [self.topBadgeView addSubview:self.topBadgeLabel];

    self.accessoryPocketView = [[UIView alloc] init];
    self.accessoryPocketView.translatesAutoresizingMaskIntoConstraints = NO;
    self.accessoryPocketView.backgroundColor = [PPProviderPremiumSurfaceColor() colorWithAlphaComponent:0.84];
    self.accessoryPocketView.layer.borderWidth = 0.55;
    self.accessoryPocketView.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:0.50].CGColor;
    self.accessoryPocketView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.accessoryPocketView.layer.shadowOpacity = 0.060;
    self.accessoryPocketView.layer.shadowRadius = 14.0;
    self.accessoryPocketView.layer.shadowOffset = CGSizeMake(0.0, 7.0);
    self.accessoryPocketView.clipsToBounds = NO;
    PPProviderPremiumApplyContinuousCorners(self.accessoryPocketView, 20.0);
    [self.imageStageView addSubview:self.accessoryPocketView];

    self.accessoryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.accessoryButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.accessoryButton.tintColor = [PPProviderPremiumPrimaryTextColor() colorWithAlphaComponent:0.76];
    self.accessoryButton.accessibilityTraits = UIAccessibilityTraitButton;
    [self.accessoryButton addTarget:self action:@selector(pp_handleAccessoryTap:) forControlEvents:UIControlEventTouchUpInside];
    [self.accessoryPocketView addSubview:self.accessoryButton];

    self.contentPanelView = [[UIView alloc] init];
    self.contentPanelView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentPanelView.backgroundColor = UIColor.clearColor;
    [self.cardView addSubview:self.contentPanelView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font =[GM boldFontWithSize:23];
    self.titleLabel.textColor = PPProviderPremiumPrimaryTextColor();
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    [self.contentPanelView addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [GM MidFontWithSize:14];
    self.subtitleLabel.textColor = [PPProviderPremiumSecondaryTextColor() colorWithAlphaComponent:0.82];
    self.subtitleLabel.numberOfLines = 2;
    self.subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.subtitleLabel.adjustsFontForContentSizeCategory = YES;
    [self.contentPanelView addSubview:self.subtitleLabel];

    self.metaFootnoteLabel = [[UILabel alloc] init];
    self.metaFootnoteLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.metaFootnoteLabel.font = PPProviderPremiumRoundedFont(12.0, UIFontWeightMedium, UIFontTextStyleCaption1);
    self.metaFootnoteLabel.textColor = [PPProviderPremiumPrimaryTextColor() colorWithAlphaComponent:0.64];
    self.metaFootnoteLabel.numberOfLines = 1;
    self.metaFootnoteLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.metaFootnoteLabel.adjustsFontForContentSizeCategory = YES;
    [self.contentPanelView addSubview:self.metaFootnoteLabel];

    self.metricsRailStackView = [[UIStackView alloc] init];
    self.metricsRailStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.metricsRailStackView.axis = UILayoutConstraintAxisHorizontal;
    self.metricsRailStackView.alignment = UIStackViewAlignmentCenter;
    self.metricsRailStackView.distribution = UIStackViewDistributionFillProportionally;
    self.metricsRailStackView.spacing = 8.0;
    self.metricsRailStackView.hidden = NO;
    [self.contentPanelView addSubview:self.metricsRailStackView];

    self.countPillView = [[UIView alloc] init];
    self.countPillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.countPillView.backgroundColor = PPProviderPremiumStageColor();
    self.countPillView.layer.borderWidth = 0.55;
    self.countPillView.layer.borderColor = PPProviderPremiumStrokeColor().CGColor;
    self.countPillView.clipsToBounds = YES;
    self.countPillView.hidden = NO;
    PPProviderPremiumApplyContinuousCorners(self.countPillView, 18.0);
    [self.metricsRailStackView addArrangedSubview:self.countPillView];

    self.countTitleLabel = [[UILabel alloc] init];
    self.countTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.countTitleLabel.numberOfLines = 1;
    self.countTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.countTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.countTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.countTitleLabel.adjustsFontSizeToFitWidth = YES;
    self.countTitleLabel.minimumScaleFactor = 0.82;
    self.countTitleLabel.hidden = NO;
    [self.countPillView addSubview:self.countTitleLabel];

    self.contactPillView = [[UIView alloc] init];
    self.contactPillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contactPillView.backgroundColor = PPProviderPremiumStageColor();
    self.contactPillView.layer.borderWidth = 0.55;
    self.contactPillView.layer.borderColor = PPProviderPremiumStrokeColor().CGColor;
    self.contactPillView.clipsToBounds = YES;
    self.contactPillView.hidden = YES;
    PPProviderPremiumApplyContinuousCorners(self.contactPillView, 18.0);
    [self.metricsRailStackView addArrangedSubview:self.contactPillView];

    self.contactIconView = [[UIImageView alloc] init];
    self.contactIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contactIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.contactIconView.image = PPProviderPremiumSymbolImage(@"mappin.and.ellipse", 11.0, UIImageSymbolWeightSemibold);
    self.contactIconView.tintColor = [PPProviderPremiumPrimaryTextColor() colorWithAlphaComponent:0.58];
    [self.contactPillView addSubview:self.contactIconView];

    self.contactLabel = [[UILabel alloc] init];
    self.contactLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.contactLabel.font = PPProviderPremiumRoundedFont(12.0, UIFontWeightSemibold, UIFontTextStyleCaption1);
    self.contactLabel.textColor = [PPProviderPremiumPrimaryTextColor() colorWithAlphaComponent:0.76];
    self.contactLabel.numberOfLines = 1;
    self.contactLabel.adjustsFontSizeToFitWidth = YES;
    self.contactLabel.minimumScaleFactor = 0.82;
    self.contactLabel.adjustsFontForContentSizeCategory = YES;
    self.contactLabel.hidden = YES;
    [self.contactPillView addSubview:self.contactLabel];

    self.ratingPillView = [[UIView alloc] init];
    self.ratingPillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.ratingPillView.backgroundColor = PPProviderPremiumDynamicColor([UIColor colorWithWhite:0.96 alpha:0.92],
                                                                         [UIColor colorWithWhite:1.0 alpha:0.08]);
    self.ratingPillView.layer.borderWidth = 0.65;
    self.ratingPillView.layer.borderColor = PPProviderPremiumStrokeColor().CGColor;
    self.ratingPillView.clipsToBounds = YES;
    PPProviderPremiumApplyContinuousCorners(self.ratingPillView, 18.0);
    [self.contentPanelView addSubview:self.ratingPillView];

    self.ratingIconView = [[UIImageView alloc] init];
    self.ratingIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.ratingIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.ratingIconView.image = PPProviderPremiumSymbolImage(@"star.fill", 11.0, UIImageSymbolWeightBold);
    self.ratingIconView.tintColor = [UIColor colorWithRed:0.86 green:0.62 blue:0.15 alpha:1.0];
    [self.ratingPillView addSubview:self.ratingIconView];

    self.ratingLabel = [[UILabel alloc] init];
    self.ratingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.ratingLabel.font = PPProviderPremiumRoundedFont(12.0, UIFontWeightBold, UIFontTextStyleCaption1);
    self.ratingLabel.textColor = [UIColor colorWithRed:0.72 green:0.49 blue:0.10 alpha:1.0];
    self.ratingLabel.numberOfLines = 1;
    self.ratingLabel.adjustsFontSizeToFitWidth = YES;
    self.ratingLabel.minimumScaleFactor = 0.82;
    self.ratingLabel.adjustsFontForContentSizeCategory = YES;
    [self.ratingPillView addSubview:self.ratingLabel];
    [self.metricsRailStackView addArrangedSubview:self.ratingPillView];
  

    self.imageStageHeightConstraint = [self.imageStageView.heightAnchor constraintEqualToConstant:218.0];
    UILayoutGuide *contentGuide = self.contentPanelView.layoutMarginsGuide;
    self.contentPanelView.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPProviderPremiumCardInsets().top],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPProviderPremiumCardInsets().left],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPProviderPremiumCardInsets().right],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPProviderPremiumCardInsets().bottom],

        [self.imageStageView.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:14.0],
        [self.imageStageView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:14.0],
        [self.imageStageView.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-14.0],
        self.imageStageHeightConstraint,

        [self.highlightBloomView.topAnchor constraintEqualToAnchor:self.imageStageView.topAnchor constant:36.0],
        [self.highlightBloomView.trailingAnchor constraintEqualToAnchor:self.imageStageView.trailingAnchor constant:-54.0],
        [self.highlightBloomView.widthAnchor constraintEqualToConstant:96.0],
        [self.highlightBloomView.heightAnchor constraintEqualToConstant:96.0],

        [self.coverImageView.topAnchor constraintEqualToAnchor:self.imageStageView.topAnchor],
        [self.coverImageView.leadingAnchor constraintEqualToAnchor:self.imageStageView.leadingAnchor],
        [self.coverImageView.trailingAnchor constraintEqualToAnchor:self.imageStageView.trailingAnchor],
        [self.coverImageView.bottomAnchor constraintEqualToAnchor:self.imageStageView.bottomAnchor],

        [self.accessoryPocketView.trailingAnchor constraintEqualToAnchor:self.imageStageView.trailingAnchor constant:-16.0],
        [self.accessoryPocketView.centerYAnchor constraintEqualToAnchor:self.topBadgeView.centerYAnchor],
        [self.accessoryPocketView.widthAnchor constraintEqualToConstant:40.0],
        [self.accessoryPocketView.heightAnchor constraintEqualToConstant:40.0],

        [self.accessoryButton.centerXAnchor constraintEqualToAnchor:self.accessoryPocketView.centerXAnchor],
        [self.accessoryButton.centerYAnchor constraintEqualToAnchor:self.accessoryPocketView.centerYAnchor],
        [self.accessoryButton.widthAnchor constraintEqualToConstant:40.0],
        [self.accessoryButton.heightAnchor constraintEqualToConstant:40.0],

        [self.topBadgeView.leadingAnchor constraintEqualToAnchor:self.imageStageView.leadingAnchor constant:16.0],
        [self.topBadgeView.topAnchor constraintEqualToAnchor:self.imageStageView.topAnchor constant:15.0],
        [self.topBadgeView.heightAnchor constraintEqualToConstant:34.0],
        [self.topBadgeView.trailingAnchor constraintLessThanOrEqualToAnchor:self.accessoryPocketView.leadingAnchor constant:-12.0],

        [self.topBadgeIconView.leadingAnchor constraintEqualToAnchor:self.topBadgeView.leadingAnchor constant:12.0],
        [self.topBadgeIconView.centerYAnchor constraintEqualToAnchor:self.topBadgeView.centerYAnchor],
        [self.topBadgeIconView.widthAnchor constraintEqualToConstant:13.0],
        [self.topBadgeIconView.heightAnchor constraintEqualToConstant:13.0],

        [self.topBadgeLabel.leadingAnchor constraintEqualToAnchor:self.topBadgeIconView.trailingAnchor constant:6.0],
        [self.topBadgeLabel.trailingAnchor constraintEqualToAnchor:self.topBadgeView.trailingAnchor constant:-12.0],
        [self.topBadgeLabel.centerYAnchor constraintEqualToAnchor:self.topBadgeView.centerYAnchor],
 
        [self.contentPanelView.topAnchor constraintEqualToAnchor:self.imageStageView.bottomAnchor constant:14.0],
        [self.contentPanelView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:22.0],
        [self.contentPanelView.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-22.0],
        [self.contentPanelView.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-14.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:contentGuide.topAnchor],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4.0],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor],
        
        [self.metricsRailStackView.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:11.0],
        [self.metricsRailStackView.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor],
        [self.metricsRailStackView.trailingAnchor constraintLessThanOrEqualToAnchor:contentGuide.trailingAnchor],
        [self.metricsRailStackView.bottomAnchor constraintLessThanOrEqualToAnchor:contentGuide.bottomAnchor],
        [self.metricsRailStackView.heightAnchor constraintGreaterThanOrEqualToConstant:32.0],
        [self.countPillView.heightAnchor constraintGreaterThanOrEqualToConstant:32.0],
        [self.countPillView.widthAnchor constraintGreaterThanOrEqualToConstant:82.0],
        [self.contactPillView.heightAnchor constraintGreaterThanOrEqualToConstant:32.0],
        [self.contactPillView.widthAnchor constraintGreaterThanOrEqualToConstant:74.0],
        [self.contactPillView.widthAnchor constraintLessThanOrEqualToConstant:156.0],
        [self.ratingPillView.heightAnchor constraintGreaterThanOrEqualToConstant:32.0],
        [self.ratingPillView.widthAnchor constraintGreaterThanOrEqualToConstant:66.0],
        [self.ratingPillView.widthAnchor constraintLessThanOrEqualToConstant:118.0],

        [self.countTitleLabel.centerYAnchor constraintEqualToAnchor:self.countPillView.centerYAnchor],
        [self.countTitleLabel.leadingAnchor constraintEqualToAnchor:self.countPillView.leadingAnchor constant:10.0],
        [self.countTitleLabel.trailingAnchor constraintEqualToAnchor:self.countPillView.trailingAnchor constant:-10.0],

        [self.contactIconView.leadingAnchor constraintEqualToAnchor:self.contactPillView.leadingAnchor constant:11.0],
        [self.contactIconView.centerYAnchor constraintEqualToAnchor:self.contactPillView.centerYAnchor],
        [self.contactIconView.widthAnchor constraintEqualToConstant:12.0],
        [self.contactIconView.heightAnchor constraintEqualToConstant:12.0],

        [self.contactLabel.leadingAnchor constraintEqualToAnchor:self.contactIconView.trailingAnchor constant:6.0],
        [self.contactLabel.trailingAnchor constraintEqualToAnchor:self.contactPillView.trailingAnchor constant:-10.0],
        [self.contactLabel.centerYAnchor constraintEqualToAnchor:self.contactPillView.centerYAnchor],

        [self.ratingIconView.leadingAnchor constraintEqualToAnchor:self.ratingPillView.leadingAnchor constant:11.0],
        [self.ratingIconView.centerYAnchor constraintEqualToAnchor:self.ratingPillView.centerYAnchor],
        [self.ratingIconView.widthAnchor constraintEqualToConstant:12.0],
        [self.ratingIconView.heightAnchor constraintEqualToConstant:12.0],

        [self.ratingLabel.leadingAnchor constraintEqualToAnchor:self.ratingIconView.trailingAnchor constant:5.0],
        [self.ratingLabel.trailingAnchor constraintEqualToAnchor:self.ratingPillView.trailingAnchor constant:-11.0],
        [self.ratingLabel.centerYAnchor constraintEqualToAnchor:self.ratingPillView.centerYAnchor]
    ]];
    [self.ratingPillView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.ratingPillView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.titleLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.countTitleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
}

- (void)configureWithViewModel:(PPProviderCompanyPremiumCardViewModel *)viewModel
{
    self.viewModel = [viewModel copy];
    PPProviderCompanyPremiumCardViewModel *model = self.viewModel;

    UIColor *accent = model.accentColor ?: [UIColor colorWithRed:0.93 green:0.43 blue:0.18 alpha:1.0];
    NSString *title = PPProviderPremiumSafeText(model.title).length ? PPProviderPremiumSafeText(model.title) : PPProviderPremiumSafeText(model.categoryText);
    NSString *subtitle = PPProviderPremiumSafeText(model.subtitle);
    NSString *category = PPProviderPremiumSafeText(model.categoryText);
    NSString *ratingText = PPProviderPremiumSafeText(model.ratingText).length ? model.ratingText : (kLang(@"provider_rating_new") ?: @"New");
    NSString *ratingCount = PPProviderPremiumSafeText(model.ratingCountText);

    self.cardView.layer.borderColor = PPProviderPremiumStrokeColor().CGColor;
    self.imageStageView.backgroundColor = [accent colorWithAlphaComponent:0.10];
    self.stageGradientLayer.colors = PPProviderPremiumStageGradientColors(accent);
    self.vignetteLayer.colors = PPProviderPremiumVignetteColors();
    self.doubleFadeLayer.colors = PPProviderPremiumDoubleFadeColors();
    self.topBadgeView.backgroundColor = [PPProviderPremiumSurfaceColor() colorWithAlphaComponent:0.84];
    BOOL showsVerifiedBadge = model.isVerified;
    UIColor *verifiedTint = [UIColor colorWithRed:0.12 green:0.57 blue:0.36 alpha:1.0];
    self.topBadgeIconView.image = showsVerifiedBadge
        ? PPProviderPremiumSymbolImage(@"checkmark.seal.fill", 12.0, UIImageSymbolWeightSemibold)
        : PPProviderPremiumSymbolImage(@"sparkles", 12.0, UIImageSymbolWeightSemibold);
    self.topBadgeIconView.tintColor = showsVerifiedBadge ? verifiedTint : accent;
    self.topBadgeLabel.textColor = showsVerifiedBadge ? verifiedTint : [accent colorWithAlphaComponent:0.90];
    self.topBadgeLabel.text = showsVerifiedBadge ? (kLang(@"service_view_provider_verified") ?: @"Verified account") : category;
    self.accessoryPocketView.backgroundColor = [PPProviderPremiumSurfaceColor() colorWithAlphaComponent:0.84];
    self.accessoryPocketView.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:0.50].CGColor;
    self.countPillView.backgroundColor = [accent colorWithAlphaComponent:0.060];
    self.countPillView.layer.borderColor = [accent colorWithAlphaComponent:0.135].CGColor;
    self.metricsRailStackView.hidden = NO;
    self.countPillView.hidden = NO;
    self.countTitleLabel.hidden = NO;

    self.titleLabel.text = title;
    NSString *displaySubtitle = subtitle.length ? subtitle : category;
    NSMutableParagraphStyle *subtitleStyle = [[NSMutableParagraphStyle alloc] init];
    subtitleStyle.lineSpacing = 2.0;
    subtitleStyle.lineBreakMode = NSLineBreakByWordWrapping;
    subtitleStyle.alignment = self.subtitleLabel.textAlignment;
    self.subtitleLabel.attributedText =
        [[NSAttributedString alloc] initWithString:displaySubtitle
                                        attributes:@{
            NSFontAttributeName: [GM MidFontWithSize:14],
            NSForegroundColorAttributeName: [PPProviderPremiumSecondaryTextColor() colorWithAlphaComponent:0.82],
            NSParagraphStyleAttributeName: subtitleStyle
        }];
    self.subtitleLabel.hidden = NO;
    NSString *cityText =
        [PPProviderPremiumSafeText(model.cityText)
         stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *countDisplay =
        [PPProviderPremiumSafeText(model.countDisplayText)
         stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (countDisplay.length == 0) {
        countDisplay = [PPProviderPremiumSafeText(model.countTitleText)
                        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    self.metaFootnoteLabel.text = cityText;
    self.countTitleLabel.attributedText = PPProviderPremiumMetricText(PPProviderPremiumSafeText(model.countValueText),
                                                                      countDisplay,
                                                                      accent);
    self.contactLabel.text = cityText;
    self.contactPillView.hidden = (cityText.length == 0);
    self.contactLabel.hidden = self.contactPillView.hidden;
    self.contactIconView.hidden = self.contactPillView.hidden;
    self.ratingLabel.text = ratingCount.length ? [NSString stringWithFormat:@"%@ %@", ratingText, ratingCount] : ratingText;
    self.metaFootnoteLabel.hidden = (self.metaFootnoteLabel.text.length == 0);
 

    self.accessoryPocketView.hidden = (model.accessoryStyle == PPProviderCompanyPremiumCardAccessoryStyleHidden);
    self.accessoryButton.hidden = self.accessoryPocketView.hidden;
    self.accessoryButton.accessibilityLabel =
        model.accessoryStyle == PPProviderCompanyPremiumCardAccessoryStyleHeart
            ? (kLang(@"favorite") ?: @"Favorite")
            : (kLang(@"view_details") ?: @"View details");
    [self pp_updateAccessoryImageAnimated:NO];

    UIImage *placeholder = model.placeholderImage ?: PPProviderPremiumInitialsImage(title, accent, CGSizeMake(720.0, 480.0));
    self.coverImageView.image = placeholder;
    [self pp_loadImageURL:model.imageURL placeholder:placeholder];

    BOOL isRTL = (self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
    NSTextAlignment leading = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    self.titleLabel.textAlignment = leading;
    self.subtitleLabel.textAlignment = leading;
    self.metaFootnoteLabel.textAlignment = leading;
    if (self.subtitleLabel.attributedText.length > 0) {
        NSMutableAttributedString *subtitleText = [self.subtitleLabel.attributedText mutableCopy];
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.lineSpacing = 2.0;
        style.lineBreakMode = NSLineBreakByWordWrapping;
        style.alignment = leading;
        [subtitleText addAttribute:NSParagraphStyleAttributeName
                              value:style
                              range:NSMakeRange(0, subtitleText.length)];
        self.subtitleLabel.attributedText = subtitleText;
    }
    self.countTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.contactLabel.textAlignment = leading;
    self.metricsRailStackView.alignment = UIStackViewAlignmentCenter;
    self.semanticContentAttribute = isRTL ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    self.cardView.semanticContentAttribute = self.semanticContentAttribute;
    self.contentPanelView.semanticContentAttribute = self.semanticContentAttribute;
    self.metricsRailStackView.semanticContentAttribute = self.semanticContentAttribute;
    self.contactPillView.semanticContentAttribute = self.semanticContentAttribute;
    self.countPillView.semanticContentAttribute = self.semanticContentAttribute;
    self.ratingPillView.semanticContentAttribute = self.semanticContentAttribute;

    NSMutableArray<NSString *> *a11yParts = [NSMutableArray array];
    if (title.length) [a11yParts addObject:title];
    if (displaySubtitle.length) [a11yParts addObject:displaySubtitle];
    if (self.metaFootnoteLabel.text.length) [a11yParts addObject:self.metaFootnoteLabel.text];
    if (self.countTitleLabel.attributedText.string.length) [a11yParts addObject:self.countTitleLabel.attributedText.string];
    if (self.ratingLabel.text.length) [a11yParts addObject:self.ratingLabel.text];
    self.accessibilityLabel = [a11yParts componentsJoinedByString:@", "];
    self.accessibilityHint = kLang(@"a11y_cell_tap_hint") ?: @"Double-tap to view details";

    [self setNeedsLayout];
}

- (void)pp_setFavoriteTarget:(nullable id)target action:(nullable SEL)action
{
    [self.accessoryButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [self.accessoryButton addTarget:self action:@selector(pp_handleAccessoryTap:) forControlEvents:UIControlEventTouchUpInside];
    if (target && action) {
        [self.accessoryButton addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)pp_loadImageURL:(NSURL *)imageURL placeholder:(UIImage *)placeholder
{
    NSString *urlString = imageURL.absoluteString ?: @"";
    if (urlString.length == 0) {
        self.coverImageView.image = placeholder;
        return;
    }

    [[PPImageLoaderManager shared] setImageOnImageView:self.coverImageView
                                                 url:urlString
                                       placeholder:placeholder
                                    transitionStyle:PPImageTransitionStyleCrossDissolve
                                      complation:nil];
}

- (void)pp_handleAccessoryTap:(UIButton *)button
{
    if (self.viewModel.accessoryStyle == PPProviderCompanyPremiumCardAccessoryStyleHeart) {
        self.viewModel.favorite = !self.viewModel.favorite;
        [self pp_updateAccessoryImageAnimated:YES];
    }

    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    button.transform = CGAffineTransformMakeScale(0.90, 0.90);
    [UIView animateWithDuration:0.34
                          delay:0.0
         usingSpringWithDamping:0.58
          initialSpringVelocity:0.45
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        button.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_updateAccessoryImageAnimated:(BOOL)animated
{
    NSString *symbolName = @"heart";
    UIImageSymbolWeight weight = UIImageSymbolWeightRegular;
    UIColor *tintColor = [PPProviderPremiumPrimaryTextColor() colorWithAlphaComponent:0.76];

    if (self.viewModel.accessoryStyle == PPProviderCompanyPremiumCardAccessoryStyleChevron) {
        BOOL isRTL = (self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
        symbolName = isRTL ? @"arrow.left" : @"arrow.right";
        weight = UIImageSymbolWeightBold;
        tintColor = [PPProviderPremiumPrimaryTextColor() colorWithAlphaComponent:0.68];
    } else if (self.viewModel.isFavorite) {
        symbolName = @"heart.fill";
        weight = UIImageSymbolWeightSemibold;
        tintColor = self.viewModel.accentColor ?: tintColor;
    }

    UIImage *image = PPProviderPremiumSymbolImage(symbolName, 16.0, weight);
    void (^changes)(void) = ^{
        [self.accessoryButton setImage:image forState:UIControlStateNormal];
        self.accessoryButton.tintColor = tintColor;
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        return;
    }

    [UIView transitionWithView:self.accessoryButton
                      duration:0.18
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                    animations:changes
                    completion:nil];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.cardView.alpha = highlighted ? 0.92 : 1.0;
        return;
    }

    CGAffineTransform transform = highlighted ? CGAffineTransformMakeScale(0.982, 0.982) : CGAffineTransformIdentity;
    CGFloat alpha = highlighted ? 0.94 : 1.0;
    [UIView animateWithDuration:highlighted ? 0.09 : 0.24
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.22
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.cardView.transform = transform;
        self.cardView.alpha = alpha;
    } completion:nil];
}

- (void)pp_runEntranceAnimationWithDelay:(NSTimeInterval)delay
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.cardView.alpha = 1.0;
        self.cardView.transform = CGAffineTransformIdentity;
        self.imageStageView.alpha = 1.0;
        self.imageStageView.transform = CGAffineTransformIdentity;
        self.contentPanelView.alpha = 1.0;
        self.contentPanelView.transform = CGAffineTransformIdentity;
        return;
    }

    self.cardView.alpha = 0.0;
    self.cardView.transform = CGAffineTransformScale(CGAffineTransformMakeTranslation(0.0, 16.0), 0.972, 0.972);
    self.imageStageView.alpha = 0.0;
    self.imageStageView.transform = CGAffineTransformMakeScale(1.018, 1.018);
    self.contentPanelView.alpha = 0.0;
    self.contentPanelView.transform = CGAffineTransformMakeTranslation(0.0, 8.0);
    [UIView animateWithDuration:0.46
                          delay:delay
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.cardView.alpha = 1.0;
        self.cardView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.36
                          delay:delay + 0.05
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.imageStageView.alpha = 1.0;
        self.imageStageView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.34
                          delay:delay + 0.10
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.16
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.contentPanelView.alpha = 1.0;
        self.contentPanelView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat stageHeight = PPProviderPremiumStageHeightForTableWidth(CGRectGetWidth(self.contentView.bounds));
    if (fabs(self.imageStageHeightConstraint.constant - stageHeight) > 0.5) {
        self.imageStageHeightConstraint.constant = stageHeight;
    }

    PPProviderPremiumApplyContinuousCorners(self.cardView, 28.0);
    PPProviderPremiumApplyContinuousCorners(self.imageStageView, 24.0);
    PPProviderPremiumApplyContinuousCorners(self.topBadgeView, CGRectGetHeight(self.topBadgeView.bounds) * 0.5);
    PPProviderPremiumApplyContinuousCorners(self.accessoryPocketView, CGRectGetHeight(self.accessoryPocketView.bounds) * 0.5);
    PPProviderPremiumApplyContinuousCorners(self.countPillView, 18.0);
    PPProviderPremiumApplyContinuousCorners(self.contactPillView, 18.0);
    PPProviderPremiumApplyContinuousCorners(self.ratingPillView, CGRectGetHeight(self.ratingPillView.bounds) * 0.5);

    PPProviderPremiumApplyContinuousCorners(self.highlightBloomView, CGRectGetWidth(self.highlightBloomView.bounds) * 0.5);

    self.cardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.cardView.bounds cornerRadius:34.0].CGPath;
    self.stageGradientLayer.frame = self.imageStageView.bounds;
    self.stageGradientLayer.cornerRadius = 29.0;
    self.vignetteLayer.frame = self.imageStageView.bounds;
    self.vignetteLayer.cornerRadius = 29.0;
    self.doubleFadeLayer.frame = self.imageStageView.bounds;
    self.doubleFadeLayer.cornerRadius = 29.0;

    self.stageGradientLayer.colors = PPProviderPremiumStageGradientColors(self.viewModel.accentColor);
    self.vignetteLayer.colors = PPProviderPremiumVignetteColors();
    self.doubleFadeLayer.colors = PPProviderPremiumDoubleFadeColors();
    UIColor *accent = self.viewModel.accentColor ?: [UIColor colorWithRed:0.93 green:0.43 blue:0.18 alpha:1.0];

    self.countPillView.layer.borderColor = [accent colorWithAlphaComponent:0.135].CGColor;
    self.ratingPillView.layer.borderColor = PPProviderPremiumStrokeColor().CGColor;
    self.accessoryPocketView.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:0.50].CGColor;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.coverImageView];
    self.viewModel = nil;
    self.coverImageView.image = nil;
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.subtitleLabel.attributedText = nil;
    self.subtitleLabel.hidden = NO;
    self.metaFootnoteLabel.text = nil;
    self.metaFootnoteLabel.hidden = NO;
    self.countTitleLabel.attributedText = nil;
    self.countTitleLabel.text = nil;
    self.countTitleLabel.hidden = NO;
    self.contactLabel.text = nil;
    self.contactLabel.hidden = YES;
    self.contactIconView.hidden = YES;
    self.ratingLabel.text = nil;
    self.topBadgeLabel.text = nil;
    self.cardView.alpha = 1.0;
    self.cardView.transform = CGAffineTransformIdentity;
    self.imageStageView.alpha = 1.0;
    self.imageStageView.transform = CGAffineTransformIdentity;
    self.contentPanelView.alpha = 1.0;
    self.contentPanelView.transform = CGAffineTransformIdentity;
    self.accessoryButton.transform = CGAffineTransformIdentity;
    self.metricsRailStackView.hidden = NO;
    self.countPillView.hidden = NO;
    self.contactPillView.hidden = YES;
 
    self.stageGradientLayer.colors = PPProviderPremiumStageGradientColors(nil);
    self.vignetteLayer.colors = PPProviderPremiumVignetteColors();
    self.doubleFadeLayer.colors = PPProviderPremiumDoubleFadeColors();

    self.accessoryPocketView.hidden = NO;
    self.accessoryButton.hidden = NO;
    self.accessibilityLabel = nil;
    self.accessibilityHint = nil;
}

- (void)pp_uploadCoverImage:(UIImage *)image
                completion:(void(^)(NSString * _Nullable downloadURL, NSError * _Nullable error))completion
{
    if (!image) {
        if (completion) completion(nil, [NSError errorWithDomain:@"CoverImageUpload" code:100 userInfo:@{NSLocalizedDescriptionKey: @"Image is nil"}]);
        return;
    }

    NSString *providerID = self.viewModel.providerIdentifier ?: @"";
    if (providerID.length == 0) {
        if (completion) completion(nil, [NSError errorWithDomain:@"CoverImageUpload" code:101 userInfo:@{NSLocalizedDescriptionKey: @"No provider identifier"}]);
        return;
    }

    NSString *fileName = [NSString stringWithFormat:@"cover_%@.jpg", [[NSUUID UUID] UUIDString]];
    FIRStorageReference *coversRef = [[[GM UserImagesRefrence] child:providerID] child:@"covers"];
    FIRStorageReference *imageRef = [coversRef child:fileName];

    NSData *imageData = [GM compressImageToMaxSize:image maxSizeKB:800];
    if (!imageData) {
        if (completion) completion(nil, [NSError errorWithDomain:@"CoverImageUpload" code:102 userInfo:@{NSLocalizedDescriptionKey: @"Failed to compress image"}]);
        return;
    }

    FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
    metadata.contentType = @"image/jpeg";

    __weak typeof(self) weakSelf = self;
    FIRStorageUploadTask *task = [imageRef putData:imageData metadata:metadata completion:^(FIRStorageMetadata * _Nullable meta, NSError * _Nullable uploadError) {
        if (uploadError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, uploadError);
            });
            return;
        }

        [imageRef downloadURLWithCompletion:^(NSURL * _Nullable downloadURL, NSError * _Nullable downloadError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) {
                    if (completion) completion(nil, nil);
                    return;
                }

                if (downloadError) {
                    if (completion) completion(nil, downloadError);
                    return;
                }

                NSString *downloadURLString = downloadURL.absoluteString;
                if (downloadURLString.length > 0) {
                    self.viewModel.imageURL = downloadURL;
                    [[PPImageLoaderManager shared] setImageOnImageView:self.coverImageView
                                                                 url:downloadURLString
                                                           placeholder:nil
                                                        transitionStyle:PPImageTransitionStyleCrossDissolve
                                                              complation:nil];
                }
                if (completion) completion(downloadURLString, nil);
            });
        }];
    }];

    [task observeStatus:FIRStorageTaskStatusProgress handler:^(FIRStorageTaskSnapshot *snapshot) {
    }];
}

@end
