//
//  PPProviderCompanyPremiumCardCell.m
//  Pure Pets
//
//  Clarity-grade provider card — clean cover, separated content, minimal gradient noise.
//

#import "PPProviderCompanyPremiumCardCell.h"
#import <QuartzCore/QuartzCore.h>
#import "PPImageLoaderManager.h"

@import Firebase;
@import FirebaseFirestore;
@import FirebaseStorage;

static CGFloat PPClamp(CGFloat value, CGFloat minValue, CGFloat maxValue)
{
    return MIN(MAX(value, minValue), maxValue);
}

static UIColor *PPDynamicColor(UIColor *lightColor, UIColor *darkColor)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static void PPApplyContinuousCorners(UIView *view, CGFloat radius)
{
    view.layer.cornerRadius = radius;
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

static UIFont *PPScaledFont(CGFloat size, UIFontWeight weight, UIFontTextStyle textStyle)
{
    UIFont *font = weight >= UIFontWeightSemibold ? [GM boldFontWithSize:size] : [GM MidFontWithSize:size];
    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:font];
    }
    return font;
}

static NSAttributedString *PPAttributed(NSString *text,
                                         UIFont *font,
                                         UIColor *color,
                                         NSTextAlignment alignment,
                                         CGFloat lineSpacing)
{
    NSString *safeText = [text isKindOfClass:NSString.class] ? text : @"";
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineBreakMode = NSLineBreakByTruncatingTail;
    style.alignment = alignment;
    style.lineSpacing = lineSpacing;
    return [[NSAttributedString alloc] initWithString:safeText attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: style
    }];
}

static UIImage *PPSymbol(NSString *name, CGFloat pointSize, UIImageSymbolWeight weight)
{
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:weight];
        return [[UIImage systemImageNamed:name withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return nil;
}

static NSString *PPSafeText(NSString * _Nullable value)
{
    return [value isKindOfClass:NSString.class] ? value : @"";
}

#pragma mark - Semantic Colors

static UIColor *PPSurfaceColor(void)
{
    return PPDynamicColor([UIColor colorWithWhite:1.0 alpha:0.985],
                          [UIColor colorWithWhite:0.11 alpha:0.96]);
}

static UIColor *PPContentSurface(void)
{
    return PPDynamicColor(UIColor.whiteColor,
                          [UIColor colorWithWhite:0.13 alpha:1.0]);
}

static UIColor *PPCoverFallback(void)
{
    return PPDynamicColor([UIColor colorWithWhite:0.955 alpha:1.0],
                          [UIColor colorWithWhite:0.10 alpha:1.0]);
}

static UIColor *PPStrokeColor(void)
{
    return PPDynamicColor([UIColor colorWithWhite:0.0 alpha:0.06],
                          [UIColor colorWithWhite:1.0 alpha:0.10]);
}

static UIColor *PPPrimaryText(void)
{
    if (@available(iOS 13.0, *)) {
        return UIColor.labelColor;
    }
    return [UIColor colorWithWhite:0.11 alpha:1.0];
}

static UIColor *PPSecondaryText(void)
{
    if (@available(iOS 13.0, *)) {
        return UIColor.secondaryLabelColor;
    }
    return [UIColor colorWithWhite:0.52 alpha:1.0];
}

static UIColor *PPVerifiedGreen(void)
{
    return [UIColor colorWithRed:0.29 green:0.82 blue:0.54 alpha:1.0];
}

static UIColor *PPAccentTint(UIColor *accent, CGFloat alpha)
{
    return [accent colorWithAlphaComponent:alpha];
}

static UIImage *PPInitialsImage(NSString *title, UIColor *accentColor, CGSize size)
{
    CGFloat scale = UIScreen.mainScreen.scale ?: 2.0;
    UIGraphicsBeginImageContextWithOptions(size, NO, scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) { UIGraphicsEndImageContext(); return nil; }

    UIColor *start = PPAccentTint(accentColor, 0.18);
    UIColor *end = PPAccentTint(accentColor, 0.04);
    NSArray *colors = @[(__bridge id)start.CGColor, (__bridge id)end.CGColor];
    CGFloat locs[] = {0.0, 1.0};
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGGradientRef grad = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)colors, locs);
    CGContextDrawLinearGradient(ctx, grad, CGPointZero, CGPointMake(size.width, size.height), 0);

    NSString *trimmed = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *initial = trimmed.length > 0 ? [[trimmed substringToIndex:1] uppercaseString] : @"P";
    UIFont *font = PPPcaledFont(MIN(size.width, size.height) * 0.34, UIFontWeightHeavy, UIFontTextStyleLargeTitle);
    NSDictionary *attrs = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: PPAccentTint(accentColor, 0.82)
    };
    CGSize ts = [initial sizeWithAttributes:attrs];
    CGRect rect = CGRectMake((size.width - ts.width) * 0.5, (size.height - ts.height) * 0.5 - 2.0, ts.width, ts.height);
    [initial drawInRect:rect withAttributes:attrs];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    CGGradientRelease(grad);
    CGColorSpaceRelease(cs);
    UIGraphicsEndImageContext();
    return img;
}

static NSAttributedString *PPMetricText(NSString *valueText, NSString *titleText, UIColor *accentColor)
{
    NSString *value = [PPSafeText(valueText) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *title = [PPSafeText(titleText) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *full = @"";
    if (value.length && title.length) {
        full = [title rangeOfString:value].location != NSNotFound ? title : [NSString stringWithFormat:@"%@ %@", value, title];
    } else {
        full = value.length ? value : title;
    }
    UIColor *accent = accentColor ?: [UIColor colorWithRed:0.93 green:0.43 blue:0.18 alpha:1.0];
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.alignment = NSTextAlignmentCenter;
    ps.lineBreakMode = NSLineBreakByTruncatingTail;
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:full attributes:@{
        NSFontAttributeName: PPPScaledFont(11.0, UIFontWeightSemibold, UIFontTextStyleCaption1),
        NSForegroundColorAttributeName: PPAccentTint(PPPrimaryText(), 0.70),
        NSParagraphStyleAttributeName: ps
    }];
    if (value.length > 0) {
        NSRange vr = [full rangeOfString:value];
        if (vr.location != NSNotFound) {
            [result addAttributes:@{
                NSFontAttributeName: PPPScaledFont(11.0, UIFontWeightHeavy, UIFontTextStyleCaption1),
                NSForegroundColorAttributeName: PPAccentTint(accent, 0.92)
            } range:vr];
        }
    }
    return result;
}

#pragma mark - Layout Constants

static UIEdgeInsets PPCardInsets(void)
{
    return UIEdgeInsetsMake(6.0, 16.0, 6.0, 16.0);
}

static CGFloat PPCoverHeightForTableWidth(CGFloat tableWidth)
{
    CGFloat cardWidth = MAX(tableWidth - PPCardInsets().left - PPCardInsets().right, 0.0);
    return PPClamp(cardWidth * 0.44, 148.0, 180.0);
}

#pragma mark - ViewModel

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

- (id)copyWithZone:(NSZone)zone
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
    copy.avatarURL = self.avatarURL;
    copy.placeholderImage = self.placeholderImage;
    copy.avatarPlaceholderImage = self.avatarPlaceholderImage;
    copy.accentColor = self.accentColor;
    copy.verified = self.verified;
    copy.active = self.active;
    copy.favorite = self.favorite;
    copy.accessoryStyle = self.accessoryStyle;
    return copy;
}

@end

#pragma mark - Cell

@interface PPProviderCompanyPremiumCardCell ()
// Card shell
@property (nonatomic, strong) UIView *cardView;

// Cover zone
@property (nonatomic, strong) UIView *coverStageView;
@property (nonatomic, strong) UIImageView *coverImageView;
@property (nonatomic, strong) CAGradientLayer *coverFadeLayer;
@property (nonatomic, strong) UIView *topBadgeView;
@property (nonatomic, strong) UIImageView *topBadgeIconView;
@property (nonatomic, strong) UILabel *topBadgeLabel;
@property (nonatomic, strong) UIView *accessoryPocketView;
@property (nonatomic, strong) UIButton *accessoryButton;

// Content zone (below cover)
@property (nonatomic, strong) UIView *contentSurfaceView;
@property (nonatomic, strong) UIView *avatarContainer;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UIView *avatarBadgeView;
@property (nonatomic, strong) UIImageView *avatarBadgeIconView;
@property (nonatomic, strong) UIStackView *titleRowStack;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;

// Meta rail
@property (nonatomic, strong) UIView *metaRailView;
@property (nonatomic, strong) UIView *countPillView;
@property (nonatomic, strong) UILabel *countTitleLabel;
@property (nonatomic, strong) UIView *contactPillView;
@property (nonatomic, strong) UIImageView *contactIconView;
@property (nonatomic, strong) UILabel *contactLabel;
@property (nonatomic, strong) UIView *ratingPillView;
@property (nonatomic, strong) UIImageView *ratingIconView;
@property (nonatomic, strong) UILabel *ratingLabel;
@property (nonatomic, strong) UIView *metaSpacer;

// Constraints
@property (nonatomic, strong) NSLayoutConstraint *coverHeightConstraint;
@property (nonatomic, strong) PPProviderCompanyPremiumCardViewModel *viewModel;
@end

@implementation PPProviderCompanyPremiumCardCell

+ (NSString *)reuseIdentifier
{
    return NSStringFromClass(self.class);
}

+ (CGFloat)preferredHeightForTableWidth:(CGFloat)tableWidth
{
    CGFloat coverH = PPCoverHeightForTableWidth(tableWidth);
    return coverH + 96.0;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) { [self pp_buildUI]; }
    return self;
}

- (void)pp_buildUI
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    // ── Card shell ──
    _cardView = [[UIView alloc] init];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = PPCoverFallback();
    _cardView.layer.shadowColor = UIColor.blackColor.CGColor;
    _cardView.layer.shadowOpacity = 0.07;
    _cardView.layer.shadowRadius = 20.0;
    _cardView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    _cardView.layer.masksToBounds = NO;
    PPApplyContinuousCorners(_cardView, PPCornerCard);
    [self.contentView addSubview:_cardView];

    // ── Cover stage ──
    _coverStageView = [[UIView alloc] init];
    _coverStageView.translatesAutoresizingMaskIntoConstraints = NO;
    _coverStageView.backgroundColor = PPCoverFallback();
    _coverStageView.clipsToBounds = YES;
    PPApplyContinuousCorners(_coverStageView, PPCornerCard);
    [_cardView addSubview:_coverStageView];

    _coverImageView = [[UIImageView alloc] init];
    _coverImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _coverImageView.contentMode = UIViewContentModeScaleAspectFill;
    _coverImageView.clipsToBounds = YES;
    _coverImageView.backgroundColor = UIColor.clearColor;
    _coverImageView.isAccessibilityElement = NO;
    [_coverStageView addSubview:_coverImageView];

    _coverFadeLayer = [CAGradientLayer layer];
    _coverFadeLayer.startPoint = CGPointMake(0.5, 0.65);
    _coverFadeLayer.endPoint = CGPointMake(0.5, 1.0);
    _coverFadeLayer.locations = @[@0.0, @1.0];
    _coverFadeLayer.colors = @[
        (__bridge id)[UIColor clearColor].CGColor,
        (__bridge id)PPCoverFallback().CGColor
    ];
    [_coverStageView.layer addSublayer:_coverFadeLayer];

    // ── Top badge ──
    _topBadgeView = [[UIView alloc] init];
    _topBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    _topBadgeView.backgroundColor = PPDynamicColor([UIColor colorWithWhite:1.0 alpha:0.88],
                                                   [UIColor colorWithWhite:0.18 alpha:0.88]);
    _topBadgeView.layer.shadowColor = UIColor.blackColor.CGColor;
    _topBadgeView.layer.shadowOpacity = 0.06;
    _topBadgeView.layer.shadowRadius = 8.0;
    _topBadgeView.layer.shadowOffset = CGSizeMake(0.0, 4.0);
    _topBadgeView.hidden = YES;
    PPApplyContinuousCorners(_topBadgeView, 14.0);
    [_coverStageView addSubview:_topBadgeView];

    _topBadgeIconView = [[UIImageView alloc] init];
    _topBadgeIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _topBadgeIconView.contentMode = UIViewContentModeScaleAspectFit;
    [_topBadgeView addSubview:_topBadgeIconView];

    _topBadgeLabel = [[UILabel alloc] init];
    _topBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _topBadgeLabel.font = [GM boldFontWithSize:11.0];
    _topBadgeLabel.adjustsFontForContentSizeCategory = YES;
    _topBadgeLabel.numberOfLines = 1;
    [_topBadgeView addSubview:_topBadgeLabel];

    // ── Accessory pocket ──
    _accessoryPocketView = [[UIView alloc] init];
    _accessoryPocketView.translatesAutoresizingMaskIntoConstraints = NO;
    _accessoryPocketView.backgroundColor = PPDynamicColor([UIColor colorWithWhite:1.0 alpha:0.88],
                                                          [UIColor colorWithWhite:0.18 alpha:0.88]);
    _accessoryPocketView.layer.shadowColor = UIColor.blackColor.CGColor;
    _accessoryPocketView.layer.shadowOpacity = 0.06;
    _accessoryPocketView.layer.shadowRadius = 8.0;
    _accessoryPocketView.layer.shadowOffset = CGSizeMake(0.0, 4.0);
    PPApplyContinuousCorners(_accessoryPocketView, 18.0);
    [_coverStageView addSubview:_accessoryPocketView];

    _accessoryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _accessoryButton.translatesAutoresizingMaskIntoConstraints = NO;
    _accessoryButton.tintColor = PPDynamicColor([UIColor colorWithWhite:0.25 alpha:1.0],
                                               [UIColor colorWithWhite:0.85 alpha:1.0]);
    _accessoryButton.accessibilityTraits = UIAccessibilityTraitButton;
    [_accessoryButton addTarget:self action:@selector(pp_handleAccessoryTap:) forControlEvents:UIControlEventTouchUpInside];
    [_accessoryPocketView addSubview:_accessoryButton];

    // ── Content surface (below cover) ──
    _contentSurfaceView = [[UIView alloc] init];
    _contentSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _contentSurfaceView.backgroundColor = PPContentSurface();
    PPApplyContinuousCorners(_contentSurfaceView, PPCornerCard);
    [_cardView addSubview:_contentSurfaceView];

    // ── Avatar ──
    _avatarContainer = [[UIView alloc] init];
    _avatarContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarContainer.backgroundColor = PPContentSurface();
    _avatarContainer.layer.shadowColor = UIColor.blackColor.CGColor;
    _avatarContainer.layer.shadowOpacity = 0.08;
    _avatarContainer.layer.shadowRadius = 10.0;
    _avatarContainer.layer.shadowOffset = CGSizeMake(0.0, 4.0);
    _avatarContainer.layer.masksToBounds = NO;
    PPApplyContinuousCorners(_avatarContainer, 26.0);
    [_cardView addSubview:_avatarContainer];

    _avatarImageView = [[UIImageView alloc] init];
    _avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    _avatarImageView.clipsToBounds = YES;
    _avatarImageView.backgroundColor = PPDynamicColor([UIColor colorWithWhite:0.94 alpha:1.0],
                                                      [UIColor colorWithWhite:0.16 alpha:1.0]);
    _avatarImageView.isAccessibilityElement = NO;
    PPApplyContinuousCorners(_avatarImageView, 23.0);
    [_avatarContainer addSubview:_avatarImageView];

    _avatarBadgeView = [[UIView alloc] init];
    _avatarBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarBadgeView.backgroundColor = UIColor.clearColor;
    _avatarBadgeView.hidden = YES;
    PPApplyContinuousCorners(_avatarBadgeView, 9.0);
    [_avatarContainer addSubview:_avatarBadgeView];

    _avatarBadgeIconView = [[UIImageView alloc] init];
    _avatarBadgeIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarBadgeIconView.contentMode = UIViewContentModeScaleAspectFit;
    _avatarBadgeIconView.image = PPPSymbol(@"checkmark.seal.fill", 14.0, UIImageSymbolWeightBold);
    _avatarBadgeIconView.tintColor = PPVerifiedGreen();
    [_avatarBadgeView addSubview:_avatarBadgeIconView];

    // ── Title row ──
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:20];
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    [_titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                forAxis:UILayoutConstraintAxisHorizontal];
    [_titleLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh
                                  forAxis:UILayoutConstraintAxisHorizontal];

    BOOL isRTL = [Language isRTL];
    _titleRowStack = [[UIStackView alloc] initWithArrangedSubviews:isRTL
        ? @[_avatarBadgeView, _titleLabel]
        : @[_titleLabel, _avatarBadgeView]];
    _titleRowStack.translatesAutoresizingMaskIntoConstraints = NO;
    _titleRowStack.axis = UILayoutConstraintAxisHorizontal;
    _titleRowStack.alignment = UIStackViewAlignmentCenter;
    _titleRowStack.distribution = UIStackViewDistributionFill;
    _titleRowStack.spacing = 5.0;
    [_contentSurfaceView addSubview:_titleRowStack];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [GM MidFontWithSize:13.0];
    _subtitleLabel.numberOfLines = 1;
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _subtitleLabel.adjustsFontForContentSizeCategory = YES;
    [_subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh
                                                   forAxis:UILayoutConstraintAxisVertical];
    [_contentSurfaceView addSubview:_subtitleLabel];

    // ── Meta rail ──
    _metaRailView = [[UIView alloc] init];
    _metaRailView.translatesAutoresizingMaskIntoConstraints = NO;
    _metaRailView.backgroundColor = PPContentSurface();
    [_cardView addSubview:_metaRailView];

    _countPillView = [[UIView alloc] init];
    _countPillView.translatesAutoresizingMaskIntoConstraints = NO;
    _countPillView.clipsToBounds = YES;
    PPApplyContinuousCorners(_countPillView, PPCornerPill);
    [_metaRailView addSubview:_countPillView];

    _countTitleLabel = [[UILabel alloc] init];
    _countTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _countTitleLabel.numberOfLines = 1;
    _countTitleLabel.adjustsFontForContentSizeCategory = YES;
    _countTitleLabel.textAlignment = NSTextAlignmentCenter;
    _countTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _countTitleLabel.adjustsFontSizeToFitWidth = YES;
    _countTitleLabel.minimumScaleFactor = 0.82;
    _countTitleLabel.font = [GM MidFontWithSize:11.0];
    [_countPillView addSubview:_countTitleLabel];

    _contactPillView = [[UIView alloc] init];
    _contactPillView.translatesAutoresizingMaskIntoConstraints = NO;
    _contactPillView.clipsToBounds = YES;
    _contactPillView.hidden = YES;
    PPApplyContinuousCorners(_contactPillView, PPCornerPill);
    [_metaRailView addSubview:_contactPillView];

    _contactIconView = [[UIImageView alloc] init];
    _contactIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _contactIconView.contentMode = UIViewContentModeScaleAspectFit;
    _contactIconView.image = PPPSymbol(@"mappin.and.ellipse", 10.0, UIImageSymbolWeightSemibold);
    [_contactPillView addSubview:_contactIconView];

    _contactLabel = [[UILabel alloc] init];
    _contactLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _contactLabel.font = [GM MidFontWithSize:11.0];
    _contactLabel.numberOfLines = 1;
    _contactLabel.adjustsFontSizeToFitWidth = YES;
    _contactLabel.minimumScaleFactor = 0.82;
    _contactLabel.adjustsFontForContentSizeCategory = YES;
    _contactLabel.hidden = YES;
    [_contactPillView addSubview:_contactLabel];

    _ratingPillView = [[UIView alloc] init];
    _ratingPillView.translatesAutoresizingMaskIntoConstraints = NO;
    _ratingPillView.clipsToBounds = YES;
    PPApplyContinuousCorners(_ratingPillView, PPCornerPill);
    [_metaRailView addSubview:_ratingPillView];

    _ratingIconView = [[UIImageView alloc] init];
    _ratingIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _ratingIconView.contentMode = UIViewContentModeScaleAspectFit;
    _ratingIconView.image = PPPSymbol(@"star.fill", 10.0, UIImageSymbolWeightBold);
    _ratingIconView.tintColor = [UIColor colorWithRed:0.86 green:0.62 blue:0.15 alpha:1.0];
    [_ratingPillView addSubview:_ratingIconView];

    _ratingLabel = [[UILabel alloc] init];
    _ratingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _ratingLabel.font = [GM MidFontWithSize:11.0];
    _ratingLabel.numberOfLines = 1;
    _ratingLabel.adjustsFontSizeToFitWidth = YES;
    _ratingLabel.minimumScaleFactor = 0.82;
    _ratingLabel.adjustsFontForContentSizeCategory = YES;
    [_ratingPillView addSubview:_ratingLabel];

    _metaSpacer = [[UIView alloc] init];
    _metaSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    _metaSpacer.userInteractionEnabled = NO;
    [_metaRailView addSubview:_metaSpacer];

    // ── Constraints ──
    _coverHeightConstraint = [_coverStageView.heightAnchor constraintEqualToConstant:160.0];

    UILayoutGuide *safe = self.contentView.layoutMarginsGuide;

    [NSLayoutConstraint activateConstraints:@[
        // Card shell
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPCardInsets().top],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPCardInsets().left],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPCardInsets().right],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPCardInsets().bottom],

        // Cover stage
        [_coverStageView.topAnchor constraintEqualToAnchor:_cardView.topAnchor],
        [_coverStageView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor],
        [_coverStageView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor],
        _coverHeightConstraint,

        // Cover image fills stage
        [_coverImageView.topAnchor constraintEqualToAnchor:_coverStageView.topAnchor],
        [_coverImageView.leadingAnchor constraintEqualToAnchor:_coverStageView.leadingAnchor],
        [_coverImageView.trailingAnchor constraintEqualToAnchor:_coverStageView.trailingAnchor],
        [_coverImageView.bottomAnchor constraintEqualToAnchor:_coverStageView.bottomAnchor],

        // Top badge
        [_topBadgeView.leadingAnchor constraintEqualToAnchor:_coverStageView.leadingAnchor constant:12.0],
        [_topBadgeView.topAnchor constraintEqualToAnchor:_coverStageView.topAnchor constant:12.0],
        [_topBadgeView.heightAnchor constraintEqualToConstant:26.0],
        [_topBadgeView.trailingAnchor constraintLessThanOrEqualToAnchor:_coverStageView.trailingAnchor constant:-52.0],

        [_topBadgeIconView.leadingAnchor constraintEqualToAnchor:_topBadgeView.leadingAnchor constant:8.0],
        [_topBadgeIconView.centerYAnchor constraintEqualToAnchor:_topBadgeView.centerYAnchor],
        [_topBadgeIconView.widthAnchor constraintEqualToConstant:11.0],
        [_topBadgeIconView.heightAnchor constraintEqualToConstant:11.0],

        [_topBadgeLabel.leadingAnchor constraintEqualToAnchor:_topBadgeIconView.trailingAnchor constant:5.0],
        [_topBadgeLabel.trailingAnchor constraintEqualToAnchor:_topBadgeView.trailingAnchor constant:-9.0],
        [_topBadgeLabel.centerYAnchor constraintEqualToAnchor:_topBadgeView.centerYAnchor],

        // Accessory pocket (trailing, top of cover)
        [_accessoryPocketView.widthAnchor constraintEqualToConstant:34.0],
        [_accessoryPocketView.heightAnchor constraintEqualToConstant:34.0],
        [_accessoryPocketView.trailingAnchor constraintEqualToAnchor:_coverStageView.trailingAnchor constant:-12.0],
        [_accessoryPocketView.topAnchor constraintEqualToAnchor:_coverStageView.topAnchor constant:12.0],

        [_accessoryButton.centerXAnchor constraintEqualToAnchor:_accessoryPocketView.centerXAnchor],
        [_accessoryButton.centerYAnchor constraintEqualToAnchor:_accessoryPocketView.centerYAnchor],
        [_accessoryButton.widthAnchor constraintEqualToConstant:34.0],
        [_accessoryButton.heightAnchor constraintEqualToConstant:34.0],

        // Avatar — overlaps cover/content boundary
        [_avatarContainer.topAnchor constraintEqualToAnchor:_coverStageView.bottomAnchor constant:-24.0],
        [_avatarContainer.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:20.0],
        [_avatarContainer.widthAnchor constraintEqualToConstant:52.0],
        [_avatarContainer.heightAnchor constraintEqualToConstant:52.0],

        [_avatarImageView.topAnchor constraintEqualToAnchor:_avatarContainer.topAnchor constant:3.0],
        [_avatarImageView.leadingAnchor constraintEqualToAnchor:_avatarContainer.leadingAnchor constant:3.0],
        [_avatarImageView.trailingAnchor constraintEqualToAnchor:_avatarContainer.trailingAnchor constant:-3.0],
        [_avatarImageView.bottomAnchor constraintEqualToAnchor:_avatarContainer.bottomAnchor constant:-3.0],

        [_avatarBadgeView.widthAnchor constraintEqualToConstant:18.0],
        [_avatarBadgeView.heightAnchor constraintEqualToConstant:18.0],
        [_avatarBadgeIconView.centerXAnchor constraintEqualToAnchor:_avatarBadgeView.centerXAnchor],
        [_avatarBadgeIconView.centerYAnchor constraintEqualToAnchor:_avatarBadgeView.centerYAnchor],
        [_avatarBadgeIconView.widthAnchor constraintEqualToConstant:18.0],
        [_avatarBadgeIconView.heightAnchor constraintEqualToConstant:18.0],

        // Content surface — below cover, right of avatar
        [_contentSurfaceView.topAnchor constraintEqualToAnchor:_coverStageView.bottomAnchor],
        [_contentSurfaceView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor],
        [_contentSurfaceView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor],
        [_contentSurfaceView.bottomAnchor constraintEqualToAnchor:_metaRailView.topAnchor],

        // Title row
        [_titleRowStack.topAnchor constraintEqualToAnchor:_contentSurfaceView.topAnchor constant:32.0],
        [_titleRowStack.leadingAnchor constraintEqualToAnchor:_contentSurfaceView.leadingAnchor constant:20.0],
        [_titleRowStack.trailingAnchor constraintEqualToAnchor:_contentSurfaceView.trailingAnchor constant:-20.0],

        // Subtitle
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleRowStack.bottomAnchor constant:3.0],
        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_contentSurfaceView.leadingAnchor constant:20.0],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_contentSurfaceView.trailingAnchor constant:-20.0],
        [_subtitleLabel.bottomAnchor constraintEqualToAnchor:_contentSurfaceView.bottomAnchor constant:-14.0],

        // Meta rail
        [_metaRailView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor],
        [_metaRailView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor],
        [_metaRailView.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor],
        [_metaRailView.heightAnchor constraintGreaterThanOrEqualToConstant:44.0],

        // Count pill
        [_countPillView.leadingAnchor constraintEqualToAnchor:_metaRailView.leadingAnchor constant:20.0],
        [_countPillView.centerYAnchor constraintEqualToAnchor:_metaRailView.centerYAnchor],
        [_countPillView.heightAnchor constraintEqualToConstant:28.0],
        [_countPillView.widthAnchor constraintGreaterThanOrEqualToConstant:60.0],

        [_countTitleLabel.leadingAnchor constraintEqualToAnchor:_countPillView.leadingAnchor constant:10.0],
        [_countTitleLabel.trailingAnchor constraintEqualToAnchor:_countPillView.trailingAnchor constant:-10.0],
        [_countTitleLabel.centerYAnchor constraintEqualToAnchor:_countPillView.centerYAnchor],

        // Contact pill
        [_contactPillView.centerYAnchor constraintEqualToAnchor:_metaRailView.centerYAnchor],
        [_contactPillView.heightAnchor constraintEqualToConstant:28.0],
        [_contactPillView.widthAnchor constraintGreaterThanOrEqualToConstant:56.0],

        [_contactIconView.leadingAnchor constraintEqualToAnchor:_contactPillView.leadingAnchor constant:8.0],
        [_contactIconView.centerYAnchor constraintEqualToAnchor:_contactPillView.centerYAnchor],
        [_contactIconView.widthAnchor constraintEqualToConstant:10.0],
        [_contactIconView.heightAnchor constraintEqualToConstant:10.0],

        [_contactLabel.leadingAnchor constraintEqualToAnchor:_contactIconView.trailingAnchor constant:4.0],
        [_contactLabel.trailingAnchor constraintEqualToAnchor:_contactPillView.trailingAnchor constant:-8.0],
        [_contactLabel.centerYAnchor constraintEqualToAnchor:_contactPillView.centerYAnchor],

        // Rating pill (trailing)
        [_ratingPillView.trailingAnchor constraintEqualToAnchor:_metaRailView.trailingAnchor constant:-20.0],
        [_ratingPillView.centerYAnchor constraintEqualToAnchor:_metaRailView.centerYAnchor],
        [_ratingPillView.heightAnchor constraintEqualToConstant:28.0],
        [_ratingPillView.widthAnchor constraintGreaterThanOrEqualToConstant:52.0],

        [_ratingIconView.leadingAnchor constraintEqualToAnchor:_ratingPillView.leadingAnchor constant:8.0],
        [_ratingIconView.centerYAnchor constraintEqualToAnchor:_ratingPillView.centerYAnchor],
        [_ratingIconView.widthAnchor constraintEqualToConstant:10.0],
        [_ratingIconView.heightAnchor constraintEqualToConstant:10.0],

        [_ratingLabel.leadingAnchor constraintEqualToAnchor:_ratingIconView.trailingAnchor constant:4.0],
        [_ratingLabel.trailingAnchor constraintEqualToAnchor:_ratingPillView.trailingAnchor constant:-8.0],
        [_ratingLabel.centerYAnchor constraintEqualToAnchor:_ratingPillView.centerYAnchor],

        // Meta spacer fills between count and rating
        [_metaSpacer.leadingAnchor constraintEqualToAnchor:_countPillView.trailingAnchor constant:8.0],
        [_metaSpacer.trailingAnchor constraintEqualToAnchor:_ratingPillView.leadingAnchor constant:-8.0],
        [_metaSpacer.centerYAnchor constraintEqualToAnchor:_metaRailView.centerYAnchor],
    ]];

    // Content hugging
    [_ratingPillView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_ratingPillView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_avatarContainer setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_avatarContainer setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_countPillView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_countPillView setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [_contactPillView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_contactPillView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_countTitleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_metaSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_metaSpacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
}

#pragma mark - Configuration

- (void)configureWithViewModel:(PPProviderCompanyPremiumCardViewModel *)viewModel
{
    self.viewModel = [viewModel copy];
    PPProviderCompanyPremiumCardViewModel *model = self.viewModel;

    UIColor *accent = model.accentColor ?: [UIColor colorWithRed:0.93 green:0.43 blue:0.18 alpha:1.0];
    NSString *title = PPSafeText(model.title).length ? PPSafeText(model.title) : PPSafeText(model.categoryText);
    NSString *subtitle = PPSafeText(model.subtitle);
    NSString *category = PPSafeText(model.categoryText);
    NSString *ratingText = PPSafeText(model.ratingText).length ? model.ratingText : (kLang(@"provider_rating_new") ?: @"New");
    NSString *ratingCount = PPSafeText(model.ratingCountText);
    BOOL isRTL = (self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
    NSTextAlignment leading = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;

    // Card
    self.cardView.backgroundColor = PPCoverFallback();

    // Cover stage
    self.coverStageView.backgroundColor = PPAccentTint(accent, 0.08);

    // Cover fade layer — match bottom color to content surface
    UIColor *fadeTarget = PPContentSurface();
    self.coverFadeLayer.colors = @[
        (__bridge id)[UIColor clearColor].CGColor,
        (__bridge id)fadeTarget.CGColor
    ];

    // Top badge
    BOOL showsVerifiedBadge = model.isVerified;
    self.topBadgeView.hidden = YES;
    self.topBadgeIconView.hidden = YES;
    self.topBadgeLabel.hidden = YES;
    self.topBadgeView.backgroundColor = PPDynamicColor([UIColor colorWithWhite:1.0 alpha:0.88],
                                                       [UIColor colorWithWhite:0.18 alpha:0.88]);
    self.topBadgeIconView.image = PPPSymbol(@"tag.fill", 10.0, UIImageSymbolWeightSemibold);
    self.topBadgeIconView.tintColor = PPAccentTint(accent, 0.78);
    self.topBadgeLabel.attributedText = nil;

    // Accessory
    self.accessoryPocketView.backgroundColor = PPDynamicColor([UIColor colorWithWhite:1.0 alpha:0.88],
                                                              [UIColor colorWithWhite:0.18 alpha:0.88]);
    self.accessoryButton.tintColor = PPDynamicColor([UIColor colorWithWhite:0.25 alpha:1.0],
                                                   [UIColor colorWithWhite:0.85 alpha:1.0]);

    // Avatar
    self.avatarContainer.backgroundColor = PPContentSurface();
    self.avatarContainer.layer.shadowOpacity = 0.08;
    self.avatarBadgeView.hidden = !showsVerifiedBadge;
    self.avatarBadgeView.backgroundColor = UIColor.clearColor;
    self.avatarBadgeIconView.image = showsVerifiedBadge
        ? PPPSymbol(@"checkmark.seal.fill", 14.0, UIImageSymbolWeightBold) : nil;
    self.avatarBadgeIconView.tintColor = PPVerifiedGreen();

    // Content surface
    self.contentSurfaceView.backgroundColor = PPContentSurface();

    // Meta rail
    self.metaRailView.backgroundColor = PPContentSurface();

    // Count pill
    self.countPillView.backgroundColor = PPAccentTint(accent, 0.06);
    self.countPillView.layer.borderWidth = 0.5;
    self.countPillView.layer.borderColor = PPAccentTint(accent, 0.12).CGColor;

    // Contact pill
    self.contactPillView.backgroundColor = PPDynamicColor([UIColor colorWithWhite:0.96 alpha:1.0],
                                                          [UIColor colorWithWhite:0.16 alpha:1.0]);
    self.contactPillView.layer.borderWidth = 0.5;
    self.contactPillView.layer.borderColor = PPStrokeColor().CGColor;

    // Rating pill
    self.ratingPillView.backgroundColor = PPDynamicColor([UIColor colorWithWhite:0.96 alpha:1.0],
                                                         [UIColor colorWithWhite:0.16 alpha:1.0]);
    self.ratingPillView.layer.borderWidth = 0.5;
    self.ratingPillView.layer.borderColor = PPStrokeColor().CGColor;

    // ── Typography ──
    self.titleLabel.attributedText = PPAttributed(title,
                                                  [GM boldFontWithSize:19],
                                                  PPPrimaryText(),
                                                  leading,
                                                  0.0);
    self.titleLabel.textAlignment = leading;

    NSString *displaySubtitle = subtitle.length ? subtitle : category;
    self.subtitleLabel.attributedText = PPAttributed(displaySubtitle,
                                                     [GM MidFontWithSize:13.0],
                                                     PPSecondaryText(),
                                                     leading,
                                                     1.5);
    self.subtitleLabel.textAlignment = leading;
    self.subtitleLabel.hidden = NO;

    // Count
    NSString *countDisplay = [PPSafeText(model.countDisplayText)
                              stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (countDisplay.length == 0) {
        countDisplay = [PPSafeText(model.countTitleText)
                        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    self.countTitleLabel.attributedText = PPMetricText(PPSafeText(model.countValueText), countDisplay, accent);

    // City
    NSString *cityText = [PPSafeText(model.cityText)
                          stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    BOOL hasResolvedCity = cityText.length > 0;
    if (!hasResolvedCity) {
        cityText = kLang(@"City Undefined") ?: kLang(@"city") ?: @"City";
    }
    self.contactPillView.hidden = NO;
    self.contactLabel.hidden = NO;
    self.contactIconView.hidden = NO;
    CGFloat cityAlpha = hasResolvedCity ? 0.70 : 0.45;
    self.contactIconView.tintColor = PPAccentTint(PPPrimaryText(), cityAlpha);
    self.contactLabel.attributedText = PPAttributed(cityText,
                                                    [GM MidFontWithSize:11.0],
                                                    PPAccentTint(PPPrimaryText(), cityAlpha),
                                                    leading,
                                                    0.0);

    // Rating
    NSString *ratingDisplay = ratingCount.length
        ? [NSString stringWithFormat:@"%@ %@", ratingText, ratingCount]
        : ratingText;
    self.ratingLabel.attributedText = PPAttributed(ratingDisplay,
                                                   [GM MidFontWithSize:11.0],
                                                   [UIColor colorWithRed:0.72 green:0.49 blue:0.10 alpha:1.0],
                                                   leading,
                                                   0.0);

    // Accessory button
    self.accessoryPocketView.hidden = (model.accessoryStyle == PPProviderCompanyPremiumCardAccessoryStyleHidden);
    self.accessoryButton.hidden = self.accessoryPocketView.hidden;
    self.accessoryButton.accessibilityLabel =
        model.accessoryStyle == PPProviderCompanyPremiumCardAccessoryStyleHeart
            ? (kLang(@"favorite") ?: @"Favorite")
            : (kLang(@"view_details") ?: @"View details");
    [self pp_updateAccessoryImageAnimated:NO];

    // Cover image
    UIImage *placeholder = model.placeholderImage ?: PPInitialsImage(title, accent, CGSizeMake(720.0, 480.0));
    self.coverImageView.image = placeholder;
    [self pp_loadImageURL:model.imageURL placeholder:placeholder];

    // Avatar image
    UIImage *avatarPlaceholder = model.avatarPlaceholderImage ?: PPInitialsImage(title, accent, CGSizeMake(72.0, 72.0));
    self.avatarImageView.image = avatarPlaceholder;
    [self pp_loadAvatarImageURL:model.avatarURL placeholder:avatarPlaceholder];

    // RTL title row ordering
    NSArray<UIView *> *desiredOrder = isRTL
        ? @[_avatarBadgeView, _titleLabel]
        : @[_titleLabel, _avatarBadgeView];
    for (UIView *v in self.titleRowStack.arrangedSubviews) {
        [self.titleRowStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    for (UIView *v in desiredOrder) {
        [self.titleRowStack addArrangedSubview:v];
    }

    self.semanticContentAttribute = GM.setSemantic;

    // Accessibility
    NSMutableArray<NSString *> *a11y = [NSMutableArray array];
    if (title.length) [a11y addObject:title];
    if (showsVerifiedBadge) [a11y addObject:(kLang(@"verified") ?: @"Verified")];
    if (displaySubtitle.length) [a11y addObject:displaySubtitle];
    if (cityText.length) [a11y addObject:cityText];
    if (self.countTitleLabel.attributedText.string.length) [a11y addObject:self.countTitleLabel.attributedText.string];
    if (self.ratingLabel.attributedText.string.length) [a11y addObject:self.ratingLabel.attributedText.string];
    self.accessibilityLabel = [a11y componentsJoinedByString:@", "];
    self.accessibilityHint = kLang(@"a11y_cell_tap_hint") ?: @"Double-tap to view details";

    [self setNeedsLayout];
}

#pragma mark - Image Loading

- (void)pp_loadImageURL:(NSURL *)imageURL placeholder:(UIImage *)placeholder
{
    NSString *url = imageURL.absoluteString ?: @"";
    if (url.length == 0) { self.coverImageView.image = placeholder; return; }
    [[PPImageLoaderManager shared] setImageOnImageView:self.coverImageView
                                                 url:url
                                        placeholder:placeholder
                                     transitionStyle:PPImageTransitionStyleCrossDissolve
                                           complation:nil];
}

- (void)pp_loadAvatarImageURL:(NSURL *)imageURL placeholder:(UIImage *)placeholder
{
    NSString *url = imageURL.absoluteString ?: @"";
    if (url.length == 0) { self.avatarImageView.image = placeholder; return; }
    [[PPImageLoaderManager shared] setImageOnImageView:self.avatarImageView
                                                 url:url
                                        placeholder:placeholder
                                     transitionStyle:PPImageTransitionStyleCrossDissolve
                                           complation:nil];
}

#pragma mark - Actions

- (void)pp_setFavoriteTarget:(nullable id)target action:(nullable SEL)action
{
    [self.accessoryButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [self.accessoryButton addTarget:self action:@selector(pp_handleAccessoryTap:) forControlEvents:UIControlEventTouchUpInside];
    if (target && action) {
        [self.accessoryButton addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)pp_handleAccessoryTap:(UIButton *)button
{
    if (self.viewModel.accessoryStyle == PPProviderCompanyPremiumCardAccessoryStyleHeart) {
        self.viewModel.favorite = !self.viewModel.favorite;
        [self pp_updateAccessoryImageAnimated:YES];
    }

    if (UIAccessibilityIsReduceMotionEnabled()) return;
    button.transform = CGAffineTransformMakeScale(0.88, 0.88);
    [UIView animateWithDuration:0.36
                          delay:0.0
         usingSpringWithDamping:0.55
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
    UIColor *tintColor = PPDynamicColor([UIColor colorWithWhite:0.25 alpha:1.0],
                                       [UIColor colorWithWhite:0.85 alpha:1.0]);

    if (self.viewModel.accessoryStyle == PPProviderCompanyPremiumCardAccessoryStyleChevron) {
        BOOL isRTL = (self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
        symbolName = isRTL ? @"arrow.left" : @"arrow.right";
        weight = UIImageSymbolWeightBold;
        tintColor = PPDynamicColor([UIColor colorWithWhite:0.20 alpha:1.0],
                                  [UIColor colorWithWhite:0.88 alpha:1.0]);
    } else if (self.viewModel.isFavorite) {
        symbolName = @"heart.fill";
        weight = UIImageSymbolWeightSemibold;
        tintColor = self.viewModel.accentColor ?: tintColor;
    }

    UIImage *image = PPPSymbol(symbolName, 14.0, weight);
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

#pragma mark - Highlight / Selection

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.cardView.alpha = highlighted ? 0.92 : 1.0;
        return;
    }
    CGAffineTransform t = highlighted ? CGAffineTransformMakeScale(0.982, 0.982) : CGAffineTransformIdentity;
    CGFloat a = highlighted ? 0.94 : 1.0;
    [UIView animateWithDuration:highlighted ? 0.09 : 0.24
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.22
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.cardView.transform = t;
        self.cardView.alpha = a;
    } completion:nil];
}

#pragma mark - Entrance Animation

- (void)pp_runEntranceAnimationWithDelay:(NSTimeInterval)delay
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.cardView.alpha = 1.0;
        self.cardView.transform = CGAffineTransformIdentity;
        self.coverStageView.alpha = 1.0;
        self.coverStageView.transform = CGAffineTransformIdentity;
        self.avatarContainer.alpha = 1.0;
        self.avatarContainer.transform = CGAffineTransformIdentity;
        self.contentSurfaceView.alpha = 1.0;
        self.contentSurfaceView.transform = CGAffineTransformIdentity;
        self.metaRailView.alpha = 1.0;
        self.metaRailView.transform = CGAffineTransformIdentity;
        return;
    }

    self.cardView.alpha = 0.0;
    self.cardView.transform = CGAffineTransformScale(CGAffineTransformMakeTranslation(0.0, 10.0), 0.984, 0.984);
    self.coverStageView.alpha = 0.0;
    self.coverStageView.transform = CGAffineTransformMakeScale(1.02, 1.02);
    self.avatarContainer.alpha = 0.0;
    self.avatarContainer.transform = CGAffineTransformScale(CGAffineTransformMakeTranslation(0.0, 5.0), 0.92, 0.92);
    self.contentSurfaceView.alpha = 0.0;
    self.contentSurfaceView.transform = CGAffineTransformMakeTranslation(0.0, 6.0);
    self.metaRailView.alpha = 0.0;
    self.metaRailView.transform = CGAffineTransformMakeTranslation(0.0, 4.0);

    [UIView animateWithDuration:0.42
                          delay:delay
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.cardView.alpha = 1.0;
        self.cardView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.36
                          delay:delay + 0.04
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.coverStageView.alpha = 1.0;
        self.coverStageView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.32
                          delay:delay + 0.08
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.16
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.avatarContainer.alpha = 1.0;
        self.avatarContainer.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.34
                          delay:delay + 0.10
         usingSpringWithDamping:0.94
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.contentSurfaceView.alpha = 1.0;
        self.contentSurfaceView.transform = CGAffineTransformIdentity;
        self.metaRailView.alpha = 1.0;
        self.metaRailView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat coverH = PPCoverHeightForTableWidth(CGRectGetWidth(self.contentView.bounds));
    if (fabs(self.coverHeightConstraint.constant - coverH) > 0.5) {
        self.coverHeightConstraint.constant = coverH;
    }

    PPApplyContinuousCorners(self.cardView, PPCornerCard);
    PPApplyContinuousCorners(self.coverStageView, PPCornerCard);
    PPApplyContinuousCorners(self.avatarContainer, CGRectGetHeight(self.avatarContainer.bounds) * 0.5);
    PPApplyContinuousCorners(self.avatarImageView, CGRectGetHeight(self.avatarImageView.bounds) * 0.5);
    PPApplyContinuousCorners(self.topBadgeView, CGRectGetHeight(self.topBadgeView.bounds) * 0.5);
    PPApplyContinuousCorners(self.accessoryPocketView, CGRectGetHeight(self.accessoryPocketView.bounds) * 0.5);
    PPApplyContinuousCorners(self.contentSurfaceView, PPCornerCard);
    PPApplyContinuousCorners(self.countPillView, CGRectGetHeight(self.countPillView.bounds) * 0.5);
    PPApplyContinuousCorners(self.contactPillView, CGRectGetHeight(self.contactPillView.bounds) * 0.5);
    PPApplyContinuousCorners(self.ratingPillView, CGRectGetHeight(self.ratingPillView.bounds) * 0.5);

    self.cardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.cardView.bounds
                                                              cornerRadius:PPCornerCard].CGPath;
    self.coverFadeLayer.frame = self.coverStageView.bounds;

    UIColor *accent = self.viewModel.accentColor ?: [UIColor colorWithRed:0.93 green:0.43 blue:0.18 alpha:1.0];
    self.countPillView.layer.borderColor = PPAccentTint(accent, 0.12).CGColor;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.coverImageView];
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.avatarImageView];
    self.viewModel = nil;
    self.coverImageView.image = nil;
    self.avatarImageView.image = nil;
    self.titleLabel.text = nil;
    self.titleLabel.attributedText = nil;
    self.subtitleLabel.text = nil;
    self.subtitleLabel.attributedText = nil;
    self.subtitleLabel.hidden = NO;
    self.countTitleLabel.attributedText = nil;
    self.countTitleLabel.text = nil;
    self.contactLabel.text = nil;
    self.contactLabel.attributedText = nil;
    self.contactLabel.hidden = YES;
    self.contactIconView.hidden = YES;
    self.ratingLabel.text = nil;
    self.ratingLabel.attributedText = nil;
    self.topBadgeLabel.text = nil;
    self.topBadgeLabel.attributedText = nil;
    self.topBadgeView.hidden = YES;
    self.avatarBadgeView.hidden = YES;
    self.cardView.alpha = 1.0;
    self.cardView.transform = CGAffineTransformIdentity;
    self.coverStageView.alpha = 1.0;
    self.coverStageView.transform = CGAffineTransformIdentity;
    self.avatarContainer.alpha = 1.0;
    self.avatarContainer.transform = CGAffineTransformIdentity;
    self.contentSurfaceView.alpha = 1.0;
    self.contentSurfaceView.transform = CGAffineTransformIdentity;
    self.metaRailView.alpha = 1.0;
    self.metaRailView.transform = CGAffineTransformIdentity;
    self.accessoryButton.transform = CGAffineTransformIdentity;
    self.contactPillView.hidden = YES;
    self.accessoryPocketView.hidden = NO;
    self.accessoryButton.hidden = NO;
    self.accessibilityLabel = nil;
    self.accessibilityHint = nil;
}

#pragma mark - Cover Upload

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
    [imageRef putData:imageData metadata:metadata completion:^(FIRStorageMetadata * _Nullable meta, NSError * _Nullable uploadError) {
        if (uploadError) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, uploadError); });
            return;
        }
        [imageRef downloadURLWithCompletion:^(NSURL * _Nullable downloadURL, NSError * _Nullable downloadError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) { if (completion) completion(nil, nil); return; }
                if (downloadError) { if (completion) completion(nil, downloadError); return; }
                NSString *urlStr = downloadURL.absoluteString;
                if (urlStr.length > 0) {
                    self.viewModel.imageURL = downloadURL;
                    [[PPImageLoaderManager shared] setImageOnImageView:self.coverImageView
                                                                 url:urlStr
                                                        placeholder:nil
                                                     transitionStyle:PPImageTransitionStyleCrossDissolve
                                                           complation:nil];
                }
                if (completion) completion(urlStr, nil);
            });
        }];
    }];
}

@end
