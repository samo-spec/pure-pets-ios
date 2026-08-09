//
//  PPPetCareVetCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/26/26.
//

#import "PPPetCareVetCell.h"
#import "PPImageLoaderManager.h"
#import "PetCareHelpers.h"

static const CGFloat PPPetCareVetCardRadius = 22.0;
static const CGFloat PPPetCareVetInnerPadding = 16.0;

static UIColor *PPPetCareVetResolvedColor(UIColor *color, UITraitCollection *traitCollection)
{
    if (!color) {
        return UIColor.clearColor;
    }
    if (@available(iOS 13.0, *)) {
        return [color resolvedColorWithTraitCollection:traitCollection];
    }
    return color;
}

static UIColor *PPPetCareVetBlendColor(UIColor *baseColor,
                                       UIColor *overlayColor,
                                       CGFloat amount,
                                       UITraitCollection *traitCollection)
{
    amount = MIN(MAX(amount, 0.0), 1.0);
    UIColor *base = PPPetCareVetResolvedColor(baseColor, traitCollection);
    UIColor *overlay = PPPetCareVetResolvedColor(overlayColor, traitCollection);

    CGFloat br = 1.0, bg = 1.0, bb = 1.0, ba = 1.0;
    CGFloat or = 1.0, og = 1.0, ob = 1.0, oa = 1.0;
    if (![base getRed:&br green:&bg blue:&bb alpha:&ba]) {
        br = bg = bb = 1.0;
        ba = 1.0;
    }
    if (![overlay getRed:&or green:&og blue:&ob alpha:&oa]) {
        or = og = ob = 1.0;
        oa = 1.0;
    }

    return [UIColor colorWithRed:(br * (1.0 - amount)) + (or * amount)
                           green:(bg * (1.0 - amount)) + (og * amount)
                            blue:(bb * (1.0 - amount)) + (ob * amount)
                           alpha:(ba * (1.0 - amount)) + (oa * amount)];
}

static BOOL PPPetCareVetIsDarkMode(UITraitCollection *traitCollection)
{
    if (@available(iOS 13.0, *)) {
        return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static UIFont *PPPetCareVetScaledFontForTrait(UIFont *font,
                                              UIFontTextStyle textStyle,
                                              UITraitCollection *traitCollection)
{
    if (!font) {
        font = [UIFont preferredFontForTextStyle:textStyle];
    }
    if (@available(iOS 11.0, *)) {
        UIFontMetrics *metrics = [UIFontMetrics metricsForTextStyle:textStyle];
        if (traitCollection) {
            return [metrics scaledFontForFont:font compatibleWithTraitCollection:traitCollection];
        }
        return [metrics scaledFontForFont:font];
    }
    return font;
}

static UIFont *PPPetCareVetScaledFont(UIFont *font, UIFontTextStyle textStyle)
{
    return PPPetCareVetScaledFontForTrait(font, textStyle, nil);
}

static CGFloat PPPetCareVetMeasuredTextHeight(NSString *text, UIFont *font, CGFloat width)
{
    if (text.length == 0 || !font || width <= 0.0) {
        return 0.0;
    }
    CGRect bounds = [text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                       options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                    attributes:@{NSFontAttributeName: font}
                                       context:nil];
    return ceil(CGRectGetHeight(bounds));
}

static BOOL PPPetCareVetUsesAccessibilityLayout(UITraitCollection *traitCollection)
{
    return UIContentSizeCategoryIsAccessibilityCategory(traitCollection.preferredContentSizeCategory);
}

static UIImage *PPPetCareVetSymbol(NSString *name, CGFloat pointSize, UIImageSymbolWeight weight)
{
    if (name.length == 0) {
        return nil;
    }
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:weight];
    return [[UIImage systemImageNamed:name withConfiguration:configuration] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@interface PPPetCareVetBadgeView : UIView
- (void)configureWithText:(NSString *)text systemIcon:(NSString *)systemIcon;
- (void)applyTintColor:(UIColor *)tintColor fillAlpha:(CGFloat)fillAlpha borderAlpha:(CGFloat)borderAlpha;
@end

@implementation PPPetCareVetBadgeView {
    UIStackView *_stackView;
    UIImageView *_iconView;
    UILabel *_textLabel;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.layer.cornerRadius = 13.0;
    self.layer.borderWidth = 0.0;
    self.clipsToBounds = YES;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitStaticText;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }

    _stackView = [[UIStackView alloc] init];
    _stackView.translatesAutoresizingMaskIntoConstraints = NO;
    _stackView.axis = UILayoutConstraintAxisHorizontal;
    _stackView.alignment = UIStackViewAlignmentCenter;
    _stackView.spacing = 5.0;
    _stackView.userInteractionEnabled = NO;
    [self addSubview:_stackView];

    _iconView = [[UIImageView alloc] init];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.isAccessibilityElement = NO;
    [_iconView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_stackView addArrangedSubview:_iconView];

    _textLabel = [[UILabel alloc] init];
    _textLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _textLabel.font = PPPetCareVetScaledFont([GM MidFontWithSize:10.5] ?: [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold],
                                             UIFontTextStyleCaption2);
    _textLabel.adjustsFontForContentSizeCategory = YES;
    _textLabel.numberOfLines = 0;
    _textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _textLabel.textAlignment = NSTextAlignmentCenter;
    _textLabel.isAccessibilityElement = NO;
    [_textLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_stackView addArrangedSubview:_textLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8.0],
        [_stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8.0],
        [_stackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_stackView.topAnchor constraintGreaterThanOrEqualToAnchor:self.topAnchor constant:5.0],
        [_stackView.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-5.0],

        [_iconView.widthAnchor constraintEqualToConstant:12.0],
        [_iconView.heightAnchor constraintEqualToConstant:12.0],
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:26.0],
        [self.widthAnchor constraintGreaterThanOrEqualToConstant:70.0]
    ]];

    return self;
}

- (void)configureWithText:(NSString *)text systemIcon:(NSString *)systemIcon
{
    _textLabel.text = text ?: @"";
    _iconView.image = PPPetCareVetSymbol(systemIcon, 11.5, UIImageSymbolWeightSemibold);
    self.accessibilityLabel = _textLabel.text;
}

- (void)applyTintColor:(UIColor *)tintColor fillAlpha:(CGFloat)fillAlpha borderAlpha:(CGFloat)borderAlpha
{
    UIColor *resolvedTint = tintColor ?: PPPetCareAccentColor();
    self.backgroundColor = [resolvedTint colorWithAlphaComponent:fillAlpha];
    self.layer.borderColor = [resolvedTint colorWithAlphaComponent:borderAlpha].CGColor;
    _textLabel.textColor = resolvedTint;
    _iconView.tintColor = resolvedTint;
}

@end

@implementation PPPetCareVetCell {
    UIView *_surfaceView;
    UIView *_surfaceFillView;
    CAGradientLayer *_surfaceGradientLayer;

    UIView *_ambientGlowView;
    CAGradientLayer *_ambientGlowLayer;
    UIView *_topAccentView;

    UIView *_logoPlateView;
    UIImageView *_logoImageView;
    UIView *_logoStatusDotView;

    UIStackView *_textStackView;
    UILabel *_titleLabel;
    UILabel *_descriptionLabel;

    UIStackView *_badgeStackView;
    PPPetCareVetBadgeView *_kindBadgeView;
    PPPetCareVetBadgeView *_typeBadgeView;
    PPPetCareVetBadgeView *_contactBadgeView;

    UIStackView *_buttonStackView;
    UIButton *_detailsButton;
    CAGradientLayer *_detailsGradientLayer;
    UIButton *_callButton;
    BOOL _canContact;

    NSLayoutConstraint *_textLeadingToLogoConstraint;
    NSLayoutConstraint *_textLeadingExpandedConstraint;
    NSLayoutConstraint *_textCenterYConstraint;
    NSLayoutConstraint *_textTopExpandedConstraint;
    NSLayoutConstraint *_badgeTopToLogoConstraint;
    NSLayoutConstraint *_badgeTopToTextConstraint;
}

+ (NSString *)reuseIdentifier
{
    return PPPetCareVetCellID;
}

+ (CGFloat)preferredHeightForVet:(VetModel *)vet
                    mainKindName:(NSString *)mainKindName
                           width:(CGFloat)width
                 traitCollection:(UITraitCollection *)traitCollection
{
    if (!PPPetCareVetUsesAccessibilityLayout(traitCollection)) {
        return 206.0;
    }

    NSString *title = vet.title.length > 0
        ? vet.title
        : PPPetCareLocalized(@"pet_care_vet_untitled", @"Veterinarian");
    NSString *subtitle = vet.descriptionText.length > 0
        ? vet.descriptionText
        : PPPetCareLocalized(@"pet_care_vet_default_subtitle", @"Care provider ready for pet health support.");
    NSString *kind = mainKindName.length > 0
        ? mainKindName
        : PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
    NSString *type = vet.type == VetTypeCompany
        ? PPPetCareLocalized(@"pet_care_vet_company", @"Clinic")
        : PPPetCareLocalized(@"pet_care_vet_personal", @"Doctor");
    BOOL canContact = (vet.phone.length > 0 || vet.whatsapp.length > 0);
    NSString *contact = canContact
        ? PPPetCareLocalized(@"pet_care_vet_contact_ready", @"Contact ready")
        : PPPetCareLocalized(@"pet_care_vet_no_phone", @"Details only");

    UIFont *titleFont = PPPetCareVetScaledFontForTrait(
        [GM boldFontWithSize:17.0] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold],
        UIFontTextStyleHeadline,
        traitCollection
    );
    UIFont *subtitleFont = PPPetCareVetScaledFontForTrait(
        [GM MidFontWithSize:12.5] ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium],
        UIFontTextStyleSubheadline,
        traitCollection
    );
    UIFont *badgeFont = PPPetCareVetScaledFontForTrait(
        [GM MidFontWithSize:10.5] ?: [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold],
        UIFontTextStyleCaption2,
        traitCollection
    );
    UIFont *buttonFont = PPPetCareVetScaledFontForTrait(
        [GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold],
        UIFontTextStyleCallout,
        traitCollection
    );

    CGFloat innerWidth = MAX(0.0, width - (PPPetCareVetInnerPadding * 2.0));
    CGFloat titleHeight = PPPetCareVetMeasuredTextHeight(title, titleFont, innerWidth);
    CGFloat measuredSubtitleHeight = PPPetCareVetMeasuredTextHeight(subtitle, subtitleFont, innerWidth);
    CGFloat subtitleHeight = MIN(measuredSubtitleHeight, ceil(subtitleFont.lineHeight * 3.0));
    CGFloat textHeight = titleHeight + 4.0 + subtitleHeight;

    CGFloat badgeTextWidth = MAX(0.0, innerWidth - 33.0);
    CGFloat tallestBadgeHeight = 26.0;
    for (NSString *badgeText in @[kind ?: @"", type ?: @"", contact ?: @""]) {
        CGFloat badgeTextHeight = PPPetCareVetMeasuredTextHeight(badgeText, badgeFont, badgeTextWidth);
        tallestBadgeHeight = MAX(tallestBadgeHeight, badgeTextHeight + 10.0);
    }
    CGFloat badgesHeight = (tallestBadgeHeight * 3.0) + 12.0;

    CGFloat buttonTextWidth = MAX(0.0, innerWidth - 24.0);
    CGFloat detailsHeight = MAX(44.0,
                                PPPetCareVetMeasuredTextHeight(PPPetCareLocalized(@"pet_care_details", @"Details"),
                                                               buttonFont,
                                                               buttonTextWidth) + 16.0);
    CGFloat callHeight = MAX(44.0,
                             PPPetCareVetMeasuredTextHeight(PPPetCareLocalized(@"pet_care_call", @"Call"),
                                                            buttonFont,
                                                            buttonTextWidth) + 16.0);
    CGFloat actionsHeight = (MAX(detailsHeight, callHeight) * 2.0) + 10.0;
    CGFloat measuredHeight = 6.0 + 18.0 + 58.0 + 12.0 + textHeight + 12.0
        + badgesHeight + 10.0 + actionsHeight + 14.0 + 6.0;
    return MAX(420.0, ceil(measuredHeight));
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    [self pp_buildHierarchy];
    [self pp_activateLayout];
    [self pp_configureAccessibility];
    [self pp_applyTheme];
    return self;
}

#pragma mark - Setup

- (void)pp_buildHierarchy
{
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.clipsToBounds = NO;
    self.clipsToBounds = NO;
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    _surfaceView = [[UIView alloc] init];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.backgroundColor = UIColor.clearColor;
    _surfaceView.clipsToBounds = NO;
    _surfaceView.layer.cornerRadius = PPPetCareVetCardRadius;
    [self.contentView addSubview:_surfaceView];

    _surfaceFillView = [[UIView alloc] init];
    _surfaceFillView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceFillView.clipsToBounds = YES;
    _surfaceFillView.layer.cornerRadius = PPPetCareVetCardRadius;
    _surfaceFillView.layer.borderWidth = 0.0;
    _surfaceFillView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    if (@available(iOS 13.0, *)) {
        _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
        _surfaceFillView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_surfaceFillView];

    _surfaceGradientLayer = [CAGradientLayer layer];
    _surfaceGradientLayer.locations = @[@0.0, @0.58, @1.0];
    [_surfaceFillView.layer insertSublayer:_surfaceGradientLayer atIndex:0];

    _ambientGlowView = [[UIView alloc] init];
    _ambientGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    _ambientGlowView.clipsToBounds = YES;
    _ambientGlowView.userInteractionEnabled = NO;
    _ambientGlowView.layer.cornerRadius = 76.0;
    _ambientGlowView.hidden = YES;
    [_surfaceFillView addSubview:_ambientGlowView];

    _ambientGlowLayer = [CAGradientLayer layer];
    _ambientGlowLayer.startPoint = CGPointMake(0.0, 0.0);
    _ambientGlowLayer.endPoint = CGPointMake(1.0, 1.0);
    [_ambientGlowView.layer insertSublayer:_ambientGlowLayer atIndex:0];

    _topAccentView = [[UIView alloc] init];
    _topAccentView.translatesAutoresizingMaskIntoConstraints = NO;
    _topAccentView.layer.cornerRadius = 2.5;
    _topAccentView.userInteractionEnabled = NO;
    [_surfaceFillView addSubview:_topAccentView];

    _logoPlateView = [[UIView alloc] init];
    _logoPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    _logoPlateView.layer.cornerRadius = 19.0;
    _logoPlateView.layer.borderWidth = 0.0;
    _logoPlateView.clipsToBounds = NO;
    if (@available(iOS 13.0, *)) {
        _logoPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceFillView addSubview:_logoPlateView];

    _logoImageView = [[UIImageView alloc] init];
    _logoImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _logoImageView.contentMode = UIViewContentModeScaleAspectFill;
    _logoImageView.clipsToBounds = YES;
    _logoImageView.layer.cornerRadius = 16.0;
    _logoImageView.isAccessibilityElement = NO;
    if (@available(iOS 13.0, *)) {
        _logoImageView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_logoPlateView addSubview:_logoImageView];

    _logoStatusDotView = [[UIView alloc] init];
    _logoStatusDotView.translatesAutoresizingMaskIntoConstraints = NO;
    _logoStatusDotView.layer.cornerRadius = 5.0;
    _logoStatusDotView.layer.borderWidth = 1.5;
    _logoStatusDotView.isAccessibilityElement = NO;
    [_logoPlateView addSubview:_logoStatusDotView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = PPPetCareVetScaledFont([GM boldFontWithSize:17.0] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold],
                                              UIFontTextStyleHeadline);
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];

    _descriptionLabel = [[UILabel alloc] init];
    _descriptionLabel.font = PPPetCareVetScaledFont([GM MidFontWithSize:12.5] ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium],
                                                    UIFontTextStyleSubheadline);
    _descriptionLabel.adjustsFontForContentSizeCategory = YES;
    _descriptionLabel.numberOfLines = 2;
    _descriptionLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    _textStackView = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _descriptionLabel]];
    _textStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _textStackView.axis = UILayoutConstraintAxisVertical;
    _textStackView.alignment = UIStackViewAlignmentFill;
    _textStackView.spacing = 4.0;
    _textStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [_surfaceFillView addSubview:_textStackView];

    _kindBadgeView = [[PPPetCareVetBadgeView alloc] init];
    _typeBadgeView = [[PPPetCareVetBadgeView alloc] init];
    _contactBadgeView = [[PPPetCareVetBadgeView alloc] init];

    _badgeStackView = [[UIStackView alloc] initWithArrangedSubviews:@[_kindBadgeView, _typeBadgeView, _contactBadgeView]];
    _badgeStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _badgeStackView.axis = UILayoutConstraintAxisHorizontal;
    _badgeStackView.alignment = UIStackViewAlignmentFill;
    _badgeStackView.distribution = UIStackViewDistributionFillEqually;
    _badgeStackView.spacing = 6.0;
    _badgeStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [_surfaceFillView addSubview:_badgeStackView];

    _detailsButton = [self pp_makeActionButtonPrimary:YES];
    _detailsGradientLayer = [CAGradientLayer layer];
    _detailsGradientLayer.locations = @[@0.0, @1.0];
    [_detailsButton.layer insertSublayer:_detailsGradientLayer atIndex:0];

    _callButton = [self pp_makeActionButtonPrimary:NO];

    _buttonStackView = [[UIStackView alloc] initWithArrangedSubviews:@[_detailsButton, _callButton]];
    _buttonStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _buttonStackView.axis = UILayoutConstraintAxisHorizontal;
    _buttonStackView.alignment = UIStackViewAlignmentFill;
    _buttonStackView.distribution = UIStackViewDistributionFillEqually;
    _buttonStackView.spacing = 10.0;
    _buttonStackView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [_surfaceFillView addSubview:_buttonStackView];

    [_detailsButton addTarget:self action:@selector(pp_detailsTapped) forControlEvents:UIControlEventTouchUpInside];
    [_callButton addTarget:self action:@selector(pp_callTapped) forControlEvents:UIControlEventTouchUpInside];
    [self pp_addControlTouchAnimations:_detailsButton];
    [self pp_addControlTouchAnimations:_callButton];
}

- (void)pp_activateLayout
{
    _textLeadingToLogoConstraint = [_textStackView.leadingAnchor constraintEqualToAnchor:_logoPlateView.trailingAnchor constant:14.0];
    _textLeadingExpandedConstraint = [_textStackView.leadingAnchor constraintEqualToAnchor:_surfaceFillView.leadingAnchor constant:PPPetCareVetInnerPadding];
    _textCenterYConstraint = [_textStackView.centerYAnchor constraintEqualToAnchor:_logoPlateView.centerYAnchor];
    _textTopExpandedConstraint = [_textStackView.topAnchor constraintEqualToAnchor:_logoPlateView.bottomAnchor constant:12.0];
    _badgeTopToLogoConstraint = [_badgeStackView.topAnchor constraintEqualToAnchor:_logoPlateView.bottomAnchor constant:12.0];
    _badgeTopToTextConstraint = [_badgeStackView.topAnchor constraintEqualToAnchor:_textStackView.bottomAnchor constant:12.0];

    [NSLayoutConstraint activateConstraints:@[
        [_surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
        [_surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],

        [_surfaceFillView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor],
        [_surfaceFillView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor],
        [_surfaceFillView.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor],
        [_surfaceFillView.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor],

        [_ambientGlowView.trailingAnchor constraintEqualToAnchor:_surfaceFillView.trailingAnchor constant:34.0],
        [_ambientGlowView.topAnchor constraintEqualToAnchor:_surfaceFillView.topAnchor constant:-54.0],
        [_ambientGlowView.widthAnchor constraintEqualToConstant:152.0],
        [_ambientGlowView.heightAnchor constraintEqualToConstant:152.0],

        [_topAccentView.topAnchor constraintEqualToAnchor:_surfaceFillView.topAnchor constant:10.0],
        [_topAccentView.leadingAnchor constraintEqualToAnchor:_surfaceFillView.leadingAnchor constant:PPPetCareVetInnerPadding],
        [_topAccentView.widthAnchor constraintEqualToConstant:36.0],
        [_topAccentView.heightAnchor constraintEqualToConstant:4.0],

        [_logoPlateView.leadingAnchor constraintEqualToAnchor:_surfaceFillView.leadingAnchor constant:PPPetCareVetInnerPadding],
        [_logoPlateView.topAnchor constraintEqualToAnchor:_surfaceFillView.topAnchor constant:18.0],
        [_logoPlateView.widthAnchor constraintEqualToConstant:58.0],
        [_logoPlateView.heightAnchor constraintEqualToConstant:58.0],

        [_logoImageView.topAnchor constraintEqualToAnchor:_logoPlateView.topAnchor constant:4.0],
        [_logoImageView.leadingAnchor constraintEqualToAnchor:_logoPlateView.leadingAnchor constant:4.0],
        [_logoImageView.trailingAnchor constraintEqualToAnchor:_logoPlateView.trailingAnchor constant:-4.0],
        [_logoImageView.bottomAnchor constraintEqualToAnchor:_logoPlateView.bottomAnchor constant:-4.0],

        [_logoStatusDotView.widthAnchor constraintEqualToConstant:10.0],
        [_logoStatusDotView.heightAnchor constraintEqualToConstant:10.0],
        [_logoStatusDotView.trailingAnchor constraintEqualToAnchor:_logoPlateView.trailingAnchor constant:-2.0],
        [_logoStatusDotView.bottomAnchor constraintEqualToAnchor:_logoPlateView.bottomAnchor constant:-2.0],

        _textLeadingToLogoConstraint,
        [_textStackView.trailingAnchor constraintEqualToAnchor:_surfaceFillView.trailingAnchor constant:-PPPetCareVetInnerPadding],
        _textCenterYConstraint,

        [_badgeStackView.leadingAnchor constraintEqualToAnchor:_surfaceFillView.leadingAnchor constant:PPPetCareVetInnerPadding],
        [_badgeStackView.trailingAnchor constraintEqualToAnchor:_surfaceFillView.trailingAnchor constant:-PPPetCareVetInnerPadding],
        _badgeTopToLogoConstraint,
        [_badgeStackView.heightAnchor constraintGreaterThanOrEqualToConstant:26.0],

        [_buttonStackView.leadingAnchor constraintEqualToAnchor:_surfaceFillView.leadingAnchor constant:PPPetCareVetInnerPadding],
        [_buttonStackView.trailingAnchor constraintEqualToAnchor:_surfaceFillView.trailingAnchor constant:-PPPetCareVetInnerPadding],
        [_buttonStackView.bottomAnchor constraintEqualToAnchor:_surfaceFillView.bottomAnchor constant:-14.0],
        [_buttonStackView.heightAnchor constraintGreaterThanOrEqualToConstant:44.0],
        [_buttonStackView.topAnchor constraintGreaterThanOrEqualToAnchor:_badgeStackView.bottomAnchor constant:10.0]
    ]];

    [self pp_updateTypographyLayout];
}

- (void)pp_updateTypographyLayout
{
    BOOL usesAccessibilityLayout = PPPetCareVetUsesAccessibilityLayout(self.traitCollection);

    _titleLabel.numberOfLines = usesAccessibilityLayout ? 0 : 1;
    _descriptionLabel.numberOfLines = usesAccessibilityLayout ? 3 : 2;
    _badgeStackView.axis = usesAccessibilityLayout ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    _buttonStackView.axis = usesAccessibilityLayout ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;

    if (usesAccessibilityLayout) {
        [NSLayoutConstraint deactivateConstraints:@[
            _textLeadingToLogoConstraint,
            _textCenterYConstraint,
            _badgeTopToLogoConstraint
        ]];
        [NSLayoutConstraint activateConstraints:@[
            _textLeadingExpandedConstraint,
            _textTopExpandedConstraint,
            _badgeTopToTextConstraint
        ]];
    } else {
        [NSLayoutConstraint deactivateConstraints:@[
            _textLeadingExpandedConstraint,
            _textTopExpandedConstraint,
            _badgeTopToTextConstraint
        ]];
        [NSLayoutConstraint activateConstraints:@[
            _textLeadingToLogoConstraint,
            _textCenterYConstraint,
            _badgeTopToLogoConstraint
        ]];
    }

    [self setNeedsLayout];
}

- (UIButton *)pp_makeActionButtonPrimary:(BOOL)primary
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.titleLabel.font = PPPetCareVetScaledFont([GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold],
                                                    UIFontTextStyleCallout);
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    button.contentEdgeInsets = UIEdgeInsetsMake(8.0, 12.0, 8.0, 12.0);
    button.layer.cornerRadius = 22.0;
    button.layer.borderWidth = 0.0;
    button.clipsToBounds = YES;
    button.adjustsImageWhenHighlighted = NO;
    button.accessibilityTraits = UIAccessibilityTraitButton;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return button;
}

- (void)pp_configureAccessibility
{
    self.isAccessibilityElement = NO;
    self.contentView.isAccessibilityElement = NO;
    _surfaceView.isAccessibilityElement = NO;
    _surfaceFillView.isAccessibilityElement = NO;
    _titleLabel.isAccessibilityElement = YES;
    _descriptionLabel.isAccessibilityElement = YES;
    _logoImageView.isAccessibilityElement = NO;
    self.accessibilityElements = @[
        _titleLabel,
        _descriptionLabel,
        _kindBadgeView,
        _typeBadgeView,
        _contactBadgeView,
        _detailsButton,
        _callButton
    ];
}

#pragma mark - Configuration

- (void)configureWithVet:(VetModel *)vet mainKindName:(NSString *)mainKindName
{
    [self pp_updateSemanticContent];
    NSString *title = vet.title.length > 0
        ? vet.title
        : PPPetCareLocalized(@"pet_care_vet_untitled", @"Veterinarian");
    NSString *subtitle = vet.descriptionText.length > 0
        ? vet.descriptionText
        : PPPetCareLocalized(@"pet_care_vet_default_subtitle", @"Care provider ready for pet health support.");
    NSString *kind = mainKindName.length > 0
        ? mainKindName
        : PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
    NSString *type = vet.type == VetTypeCompany
        ? PPPetCareLocalized(@"pet_care_vet_company", @"Clinic")
        : PPPetCareLocalized(@"pet_care_vet_personal", @"Doctor");
    BOOL canContact = (vet.phone.length > 0 || vet.whatsapp.length > 0);
    _canContact = canContact;
    [self pp_applyTheme];
    NSString *contact = canContact
        ? PPPetCareLocalized(@"pet_care_vet_contact_ready", @"Contact ready")
        : PPPetCareLocalized(@"pet_care_vet_no_phone", @"Details only");

    _titleLabel.text = title;
    _descriptionLabel.text = subtitle;
    [_kindBadgeView configureWithText:kind systemIcon:@"pawprint.fill"];
    [_typeBadgeView configureWithText:type
                           systemIcon:(vet.type == VetTypeCompany ? @"building.2.fill" : @"stethoscope")];
    [_contactBadgeView configureWithText:contact
                              systemIcon:(canContact ? @"phone.fill" : @"info.circle.fill")];

    [_detailsButton setTitle:PPPetCareLocalized(@"pet_care_details", @"Details") forState:UIControlStateNormal];
    [_callButton setTitle:PPPetCareLocalized(@"pet_care_call", @"Call") forState:UIControlStateNormal];
    _detailsButton.accessibilityLabel = _detailsButton.currentTitle;
    _callButton.accessibilityLabel = _callButton.currentTitle;
    _callButton.enabled = canContact;
    _callButton.alpha = canContact ? 1.0 : 0.54;
    _callButton.accessibilityTraits = canContact
        ? UIAccessibilityTraitButton
        : (UIAccessibilityTraitButton | UIAccessibilityTraitNotEnabled);

    UIImage *placeholder = PPImage(@"paw");
    _logoImageView.contentMode = vet.logoURL.length > 0 ? UIViewContentModeScaleAspectFill : UIViewContentModeScaleAspectFit;
    _logoImageView.image = placeholder;
    _logoImageView.tintColor = PPPetCareAccentColor();

    if (vet.logoURL.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:_logoImageView
                                                       url:vet.logoURL
                                               placeholder:placeholder
                                           transitionStyle:PPImageTransitionStyleFade
                                                complation:nil];
    }

    _titleLabel.accessibilityLabel = title;
    _descriptionLabel.accessibilityLabel = subtitle;
    self.accessibilityLabel = [NSString stringWithFormat:@"%@. %@. %@. %@. %@",
                               title ?: @"",
                               subtitle ?: @"",
                               kind ?: @"",
                               type ?: @"",
                               contact ?: @""];
    [self pp_updateLayerFrames];
}

- (void)prepareForReuse
{
    [super prepareForReuse];

    [[PPImageLoaderManager shared] cancelImageLoadForImageView:_logoImageView];
    _logoImageView.image = nil;
    _logoImageView.contentMode = UIViewContentModeScaleAspectFill;
    _titleLabel.text = nil;
    _descriptionLabel.text = nil;
    [_kindBadgeView configureWithText:@"" systemIcon:nil];
    [_typeBadgeView configureWithText:@"" systemIcon:nil];
    [_contactBadgeView configureWithText:@"" systemIcon:nil];
    [_detailsButton setTitle:nil forState:UIControlStateNormal];
    [_callButton setTitle:nil forState:UIControlStateNormal];
    _callButton.enabled = YES;
    _callButton.alpha = 1.0;
    _canContact = NO;
    self.onDetailsTap = nil;
    self.onCallTap = nil;
    self.transform = CGAffineTransformIdentity;
    _surfaceFillView.alpha = 1.0;
    _surfaceView.transform = CGAffineTransformIdentity;
    _detailsButton.alpha = 1.0;
    _detailsButton.transform = CGAffineTransformIdentity;
    _callButton.transform = CGAffineTransformIdentity;
    self.alpha = 1.0;
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self pp_updateLayerFrames];
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];
    [self setNeedsLayout];
    [self.contentView setNeedsLayout];
    [self pp_updateLayerFrames];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self setNeedsLayout];
        [self.contentView setNeedsLayout];
        [self pp_updateLayerFrames];
    }
}

- (void)pp_updateLayerFrames
{
    [self.contentView layoutIfNeeded];
    [_surfaceView layoutIfNeeded];
    [_surfaceFillView layoutIfNeeded];
    [_detailsButton layoutIfNeeded];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _surfaceGradientLayer.frame = CGRectIsEmpty(_surfaceFillView.bounds) ? CGRectZero : _surfaceFillView.bounds;
    _surfaceGradientLayer.cornerRadius = PPPetCareVetCardRadius;
    _ambientGlowLayer.frame = CGRectIsEmpty(_ambientGlowView.bounds) ? CGRectZero : _ambientGlowView.bounds;
    _ambientGlowLayer.cornerRadius = CGRectGetWidth(_ambientGlowView.bounds) * 0.5;
    _detailsGradientLayer.frame = CGRectIsEmpty(_detailsButton.bounds) ? CGRectZero : _detailsButton.bounds;
    _detailsGradientLayer.cornerRadius = _detailsButton.layer.cornerRadius;
    [CATransaction commit];

    if (!CGRectIsEmpty(_surfaceView.frame)) {
        _surfaceView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:_surfaceView.bounds cornerRadius:PPPetCareVetCardRadius].CGPath;
    } else {
        _surfaceView.layer.shadowPath = nil;
    }
}

#pragma mark - Theme

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (![self.traitCollection.preferredContentSizeCategory isEqualToString:previousTraitCollection.preferredContentSizeCategory]) {
        [self pp_updateTypographyLayout];
    }
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyTheme];
        }
    }
}

- (void)pp_applyTheme
{
    BOOL dark = PPPetCareVetIsDarkMode(self.traitCollection);
    UIColor *accent = PPPetCareAccentColor();
    UIColor *surface = PPPetCareSurfaceColor();
    UIColor *surfaceHighlight = PPPetCareVetBlendColor(surface, UIColor.whiteColor, dark ? 0.07 : 0.18, self.traitCollection);
    UIColor *logoFill = [accent colorWithAlphaComponent:dark ? 0.12 : 0.065];

    _surfaceFillView.backgroundColor = surface;
    _surfaceFillView.layer.borderWidth = 0.0;
    _surfaceFillView.layer.borderColor = UIColor.clearColor.CGColor;
    _surfaceView.layer.shadowColor = UIColor.blackColor.CGColor;
    _surfaceView.layer.shadowOpacity = dark ? 0.14 : 0.045;
    _surfaceView.layer.shadowRadius = 12.0;
    _surfaceView.layer.shadowOffset = CGSizeMake(0.0, 7.0);

    BOOL rtl = Language.isRTL;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _surfaceGradientLayer.startPoint = rtl ? CGPointMake(1.0, 0.0) : CGPointMake(0.0, 0.0);
    _surfaceGradientLayer.endPoint = rtl ? CGPointMake(0.0, 1.0) : CGPointMake(1.0, 1.0);
    _surfaceGradientLayer.opacity = 0.0;
    _surfaceGradientLayer.colors = @[(id)surface.CGColor, (id)surface.CGColor, (id)surface.CGColor];

    _ambientGlowLayer.colors = @[(id)UIColor.clearColor.CGColor, (id)UIColor.clearColor.CGColor];

    _detailsGradientLayer.startPoint = rtl ? CGPointMake(1.0, 0.5) : CGPointMake(0.0, 0.5);
    _detailsGradientLayer.endPoint = rtl ? CGPointMake(0.0, 0.5) : CGPointMake(1.0, 0.5);
    _detailsGradientLayer.colors = @[
        (id)accent.CGColor,
        (id)[accent colorWithAlphaComponent:0.86].CGColor
    ];
    [CATransaction commit];

    _topAccentView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.86 : 0.76];
    _logoPlateView.backgroundColor = logoFill;
    _logoPlateView.layer.borderWidth = 0.0;
    _logoPlateView.layer.borderColor = UIColor.clearColor.CGColor;
    _logoPlateView.layer.shadowColor = UIColor.blackColor.CGColor;
    _logoPlateView.layer.shadowOpacity = dark ? 0.10 : 0.035;
    _logoPlateView.layer.shadowRadius = 7.0;
    _logoPlateView.layer.shadowOffset = CGSizeMake(0.0, 4.0);
    _logoImageView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.12 : 0.07];
    _logoImageView.tintColor = accent;
    _logoStatusDotView.backgroundColor = accent;
    _logoStatusDotView.layer.borderColor = PPPetCareVetResolvedColor(surfaceHighlight, self.traitCollection).CGColor;

    _titleLabel.textColor = PPPetCareTextColor();
    _descriptionLabel.textColor = PPPetCareSecondaryTextColor();

    UIColor *kindColor = accent;
    UIColor *typeColor = PPPetCareSecondaryTextColor();
    UIColor *contactColor = _canContact
        ? (dark ? [UIColor colorWithRed:0.44 green:0.92 blue:0.76 alpha:1.0]
                : [UIColor colorWithRed:0.00 green:0.50 blue:0.36 alpha:1.0])
        : PPPetCareSecondaryTextColor();
    [_kindBadgeView applyTintColor:kindColor fillAlpha:(dark ? 0.12 : 0.065) borderAlpha:0.0];
    [_typeBadgeView applyTintColor:typeColor fillAlpha:(dark ? 0.10 : 0.055) borderAlpha:0.0];
    [_contactBadgeView applyTintColor:contactColor fillAlpha:(dark ? 0.12 : 0.065) borderAlpha:0.0];

    [_detailsButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [_detailsButton setTitleColor:[UIColor.whiteColor colorWithAlphaComponent:0.82] forState:UIControlStateHighlighted];
    [_callButton setTitleColor:accent forState:UIControlStateNormal];
    [_callButton setTitleColor:[accent colorWithAlphaComponent:0.72] forState:UIControlStateHighlighted];
    _callButton.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.12 : 0.065];
    _callButton.layer.borderWidth = 0.0;
    _callButton.layer.borderColor = UIColor.clearColor.CGColor;

    [self pp_updateLayerFrames];
}

- (void)pp_updateSemanticContent
{
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;
    self.semanticContentAttribute = semantic;
    self.contentView.semanticContentAttribute = semantic;
    _surfaceFillView.semanticContentAttribute = semantic;
    _textStackView.semanticContentAttribute = semantic;
    _badgeStackView.semanticContentAttribute = semantic;
    _buttonStackView.semanticContentAttribute = semantic;
    _titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    _descriptionLabel.textAlignment = [Language alignmentForCurrentLanguage];
}

#pragma mark - Interaction

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self pp_setCardPressed:highlighted animated:YES];
}

- (void)pp_setCardPressed:(BOOL)pressed animated:(BOOL)animated
{
    CGFloat scale = pressed ? 0.992 : 1.0;
    CGFloat alpha = pressed ? 0.96 : 1.0;
    void (^changes)(void) = ^{
        _surfaceView.transform = CGAffineTransformMakeScale(scale, scale);
        _surfaceFillView.alpha = alpha;
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        return;
    }

    if (pressed) {
        [UIView animateWithDuration:0.09
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
    } else {
        [UIView animateWithDuration:0.24
                              delay:0.0
             usingSpringWithDamping:0.78
              initialSpringVelocity:0.34
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
    }
}

- (void)pp_addControlTouchAnimations:(UIButton *)button
{
    [button addTarget:self action:@selector(pp_controlTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_controlTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
}

- (void)pp_controlTouchDown:(UIButton *)sender
{
    if (!sender.enabled) {
        return;
    }
    void (^changes)(void) = ^{
        sender.transform = CGAffineTransformMakeScale(0.974, 0.974);
        sender.alpha = 0.92;
    };
    if (UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        return;
    }
    [UIView animateWithDuration:0.08
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:changes
                     completion:nil];
}

- (void)pp_controlTouchUp:(UIButton *)sender
{
    CGFloat targetAlpha = (sender == _callButton && !sender.enabled) ? 0.54 : 1.0;
    void (^changes)(void) = ^{
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = targetAlpha;
    };
    if (UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        return;
    }
    [UIView animateWithDuration:0.22
                          delay:0.0
         usingSpringWithDamping:0.72
          initialSpringVelocity:0.35
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:changes
                     completion:nil];
}

- (void)pp_detailsTapped
{
    if (self.onDetailsTap) {
        self.onDetailsTap();
    }
}

- (void)pp_callTapped
{
    if (self.onCallTap) {
        self.onCallTap();
    }
}

@end
