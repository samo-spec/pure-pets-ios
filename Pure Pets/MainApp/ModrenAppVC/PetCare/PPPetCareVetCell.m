//
//  PPPetCareVetCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/26/26.
//

#import "PPPetCareVetCell.h"
#import "PPImageLoaderManager.h"
#import "PetCareHelpers.h"

static const CGFloat PPPetCareVetCardRadius = 26.0;
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

static UIFont *PPPetCareVetScaledFont(UIFont *font, UIFontTextStyle textStyle)
{
    if (!font) {
        font = [UIFont preferredFontForTextStyle:textStyle];
    }
    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:font];
    }
    return font;
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
    self.layer.cornerRadius = 14.0;
    self.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
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
    _textLabel.numberOfLines = 1;
    _textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _textLabel.textAlignment = NSTextAlignmentCenter;
    _textLabel.isAccessibilityElement = NO;
    [_textLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_stackView addArrangedSubview:_textLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8.0],
        [_stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8.0],
        [_stackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

        [_iconView.widthAnchor constraintEqualToConstant:12.0],
        [_iconView.heightAnchor constraintEqualToConstant:12.0],
        [self.heightAnchor constraintEqualToConstant:28.0],
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
}

+ (NSString *)reuseIdentifier
{
    return PPPetCareVetCellID;
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
    _surfaceFillView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
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
    _logoPlateView.layer.cornerRadius = 22.0;
    _logoPlateView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _logoPlateView.clipsToBounds = NO;
    if (@available(iOS 13.0, *)) {
        _logoPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceFillView addSubview:_logoPlateView];

    _logoImageView = [[UIImageView alloc] init];
    _logoImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _logoImageView.contentMode = UIViewContentModeScaleAspectFill;
    _logoImageView.clipsToBounds = YES;
    _logoImageView.layer.cornerRadius = 19.0;
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
        [_topAccentView.centerXAnchor constraintEqualToAnchor:_surfaceFillView.centerXAnchor],
        [_topAccentView.widthAnchor constraintEqualToConstant:42.0],
        [_topAccentView.heightAnchor constraintEqualToConstant:5.0],

        [_logoPlateView.leadingAnchor constraintEqualToAnchor:_surfaceFillView.leadingAnchor constant:PPPetCareVetInnerPadding],
        [_logoPlateView.topAnchor constraintEqualToAnchor:_surfaceFillView.topAnchor constant:18.0],
        [_logoPlateView.widthAnchor constraintEqualToConstant:62.0],
        [_logoPlateView.heightAnchor constraintEqualToConstant:62.0],

        [_logoImageView.topAnchor constraintEqualToAnchor:_logoPlateView.topAnchor constant:4.0],
        [_logoImageView.leadingAnchor constraintEqualToAnchor:_logoPlateView.leadingAnchor constant:4.0],
        [_logoImageView.trailingAnchor constraintEqualToAnchor:_logoPlateView.trailingAnchor constant:-4.0],
        [_logoImageView.bottomAnchor constraintEqualToAnchor:_logoPlateView.bottomAnchor constant:-4.0],

        [_logoStatusDotView.widthAnchor constraintEqualToConstant:10.0],
        [_logoStatusDotView.heightAnchor constraintEqualToConstant:10.0],
        [_logoStatusDotView.trailingAnchor constraintEqualToAnchor:_logoPlateView.trailingAnchor constant:-2.0],
        [_logoStatusDotView.bottomAnchor constraintEqualToAnchor:_logoPlateView.bottomAnchor constant:-2.0],

        [_textStackView.leadingAnchor constraintEqualToAnchor:_logoPlateView.trailingAnchor constant:14.0],
        [_textStackView.trailingAnchor constraintEqualToAnchor:_surfaceFillView.trailingAnchor constant:-PPPetCareVetInnerPadding],
        [_textStackView.centerYAnchor constraintEqualToAnchor:_logoPlateView.centerYAnchor],

        [_badgeStackView.leadingAnchor constraintEqualToAnchor:_surfaceFillView.leadingAnchor constant:PPPetCareVetInnerPadding],
        [_badgeStackView.trailingAnchor constraintEqualToAnchor:_surfaceFillView.trailingAnchor constant:-PPPetCareVetInnerPadding],
        [_badgeStackView.topAnchor constraintEqualToAnchor:_logoPlateView.bottomAnchor constant:14.0],
        [_badgeStackView.heightAnchor constraintEqualToConstant:28.0],

        [_buttonStackView.leadingAnchor constraintEqualToAnchor:_surfaceFillView.leadingAnchor constant:PPPetCareVetInnerPadding],
        [_buttonStackView.trailingAnchor constraintEqualToAnchor:_surfaceFillView.trailingAnchor constant:-PPPetCareVetInnerPadding],
        [_buttonStackView.bottomAnchor constraintEqualToAnchor:_surfaceFillView.bottomAnchor constant:-16.0],
        [_buttonStackView.heightAnchor constraintGreaterThanOrEqualToConstant:44.0],
        [_buttonStackView.topAnchor constraintGreaterThanOrEqualToAnchor:_badgeStackView.bottomAnchor constant:10.0]
    ]];
}

- (UIButton *)pp_makeActionButtonPrimary:(BOOL)primary
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.titleLabel.font = PPPetCareVetScaledFont([GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold],
                                                    UIFontTextStyleCallout);
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 12.0, 0.0, 12.0);
    button.layer.cornerRadius = 22.0;
    button.layer.borderWidth = primary ? 0.0 : 1.0 / UIScreen.mainScreen.scale;
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
    [self pp_applyTheme];

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
    UIColor *background = AppBackgroundClr ?: (dark ? UIColor.blackColor : UIColor.whiteColor);
    UIColor *surfaceHighlight = PPPetCareVetBlendColor(surface, UIColor.whiteColor, dark ? 0.07 : 0.18, self.traitCollection);
    UIColor *surfaceTint = PPPetCareVetBlendColor(surface, accent, dark ? 0.11 : 0.055, self.traitCollection);
    UIColor *surfaceTail = PPPetCareVetBlendColor(surface, background, dark ? 0.16 : 0.045, self.traitCollection);
    UIColor *border = dark
        ? [UIColor.whiteColor colorWithAlphaComponent:0.13]
        : [UIColor.blackColor colorWithAlphaComponent:0.055];
    UIColor *logoFill = [accent colorWithAlphaComponent:dark ? 0.13 : 0.075];

    _surfaceFillView.backgroundColor = UIColor.clearColor;
    _surfaceFillView.layer.borderColor = border.CGColor;
    _surfaceView.layer.shadowColor = UIColor.blackColor.CGColor;
    _surfaceView.layer.shadowOpacity = dark ? 0.18 : 0.07;
    _surfaceView.layer.shadowRadius = 20.0;
    _surfaceView.layer.shadowOffset = CGSizeMake(0.0, 10.0);

    BOOL rtl = Language.isRTL;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _surfaceGradientLayer.startPoint = rtl ? CGPointMake(1.0, 0.0) : CGPointMake(0.0, 0.0);
    _surfaceGradientLayer.endPoint = rtl ? CGPointMake(0.0, 1.0) : CGPointMake(1.0, 1.0);
    _surfaceGradientLayer.opacity = dark ? 0.84 : 0.72;
    _surfaceGradientLayer.colors = @[
        (id)surfaceHighlight.CGColor,
        (id)surfaceTint.CGColor,
        (id)surfaceTail.CGColor
    ];

    _ambientGlowLayer.colors = @[
        (id)[accent colorWithAlphaComponent:dark ? 0.105 : 0.095].CGColor,
        (id)[accent colorWithAlphaComponent:0.0].CGColor
    ];

    _detailsGradientLayer.startPoint = rtl ? CGPointMake(1.0, 0.5) : CGPointMake(0.0, 0.5);
    _detailsGradientLayer.endPoint = rtl ? CGPointMake(0.0, 0.5) : CGPointMake(1.0, 0.5);
    _detailsGradientLayer.colors = @[
        (id)accent.CGColor,
        (id)[accent colorWithAlphaComponent:0.86].CGColor
    ];
    [CATransaction commit];

    _topAccentView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.72 : 0.62];
    _logoPlateView.backgroundColor = logoFill;
    _logoPlateView.layer.borderColor = [accent colorWithAlphaComponent:dark ? 0.18 : 0.12].CGColor;
    _logoPlateView.layer.shadowColor = UIColor.blackColor.CGColor;
    _logoPlateView.layer.shadowOpacity = dark ? 0.16 : 0.07;
    _logoPlateView.layer.shadowRadius = 10.0;
    _logoPlateView.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    _logoImageView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.12 : 0.07];
    _logoImageView.tintColor = accent;
    _logoStatusDotView.backgroundColor = accent;
    _logoStatusDotView.layer.borderColor = PPPetCareVetResolvedColor(surfaceHighlight, self.traitCollection).CGColor;

    _titleLabel.textColor = PPPetCareTextColor();
    _descriptionLabel.textColor = PPPetCareSecondaryTextColor();

    UIColor *kindColor = dark
        ? [UIColor colorWithRed:0.44 green:0.92 blue:0.76 alpha:1.0]
        : [UIColor colorWithRed:0.00 green:0.56 blue:0.40 alpha:1.0];
    UIColor *typeColor = dark
        ? [UIColor colorWithRed:0.72 green:0.58 blue:0.98 alpha:1.0]
        : [UIColor colorWithRed:0.45 green:0.30 blue:0.78 alpha:1.0];
    UIColor *contactColor = dark
        ? [UIColor colorWithRed:1.00 green:0.76 blue:0.38 alpha:1.0]
        : [UIColor colorWithRed:0.86 green:0.42 blue:0.06 alpha:1.0];
    [_kindBadgeView applyTintColor:kindColor fillAlpha:(dark ? 0.14 : 0.075) borderAlpha:(dark ? 0.24 : 0.16)];
    [_typeBadgeView applyTintColor:typeColor fillAlpha:(dark ? 0.14 : 0.075) borderAlpha:(dark ? 0.24 : 0.16)];
    [_contactBadgeView applyTintColor:contactColor fillAlpha:(dark ? 0.14 : 0.075) borderAlpha:(dark ? 0.24 : 0.16)];

    [_detailsButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [_detailsButton setTitleColor:[UIColor.whiteColor colorWithAlphaComponent:0.82] forState:UIControlStateHighlighted];
    [_callButton setTitleColor:accent forState:UIControlStateNormal];
    [_callButton setTitleColor:[accent colorWithAlphaComponent:0.72] forState:UIControlStateHighlighted];
    _callButton.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.12 : 0.062];
    _callButton.layer.borderColor = [accent colorWithAlphaComponent:dark ? 0.22 : 0.13].CGColor;

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
