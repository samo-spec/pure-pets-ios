#import "PPPetCareViewController.h"
#import "PPUniversalCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPImageLoaderManager.h"
#import "PPOverlayCoordinator.h"
#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "VetManager.h"
#import "VetModel.h"
#import "MainKindsModel.h"
#import "ArabicNormalizer.h"
#import "CartManager.h"
#import "CartViewController.h"
#import "PPNavigationController.h"
#import "PPHomeHelper.h"
#import "UIView+Badge.h"

typedef NS_ENUM(NSInteger, PPPetCareMedicineFilter) {
    PPPetCareMedicineFilterAll = 0,
    PPPetCareMedicineFilterOffers,
    PPPetCareMedicineFilterInStock,
    PPPetCareMedicineFilterNew
};

typedef NS_ENUM(NSInteger, PPPetCareVetFilter) {
    PPPetCareVetFilterAll = 0,
    PPPetCareVetFilterWithPhone,
    PPPetCareVetFilterCompany,
    PPPetCareVetFilterPersonal
};

static NSString * const PPPetCareMedicineCellID = @"PPPetCareMedicineCellID";
static NSString * const PPPetCareVetCellID = @"PPPetCareVetCellID";

static CGFloat PPPetCareNavigationSegmentWidth(void)
{
    CGFloat screenWidth = CGRectGetWidth(UIScreen.mainScreen.bounds);
    CGFloat availableWidth = screenWidth > 0.0 ? screenWidth - 150.0 : 240.0;
    return floor(MIN(278.0, MAX(224.0, availableWidth)));
}

static NSString *PPPetCareLocalized(NSString *key, NSString *fallback)
{
    NSString *value = key.length ? kLang(key) : nil;
    return value.length > 0 ? value : fallback;
}

static NSString *PPPetCareSafeString(id value)
{
    return [value isKindOfClass:NSString.class] ? (NSString *)value : @"";
}

static UIColor *PPPetCareTextColor(void)
{
    return AppPrimaryTextClr ?: UIColor.labelColor;
}

static UIColor *PPPetCareSecondaryTextColor(void)
{
    return AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
}

static UIColor *PPPetCareAccentColor(void)
{
    return AppPrimaryClr ?: UIColor.systemTealColor;
}

static UIColor *PPPetCareSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark
            ? [AppBackgroundClr colorWithAlphaComponent:0.075]
            : [AppBackgroundClrLigter colorWithAlphaComponent:0.76];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.76];
}

static UIColor *PPPetCareBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark
                ? [UIColor colorWithWhite:1.0 alpha:0.11]
                : [UIColor colorWithRed:0.72 green:0.66 blue:0.62 alpha:0.22];
        }];
    }
    return [UIColor colorWithRed:0.72 green:0.66 blue:0.62 alpha:0.22];
}

static UIColor *PPPetCareSearchSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark
                ? [UIColor colorWithWhite:0.12 alpha:0.86]
                : [UIColor colorWithWhite:1.0 alpha:0.88];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.88];
}

static UIColor *PPPetCareSearchBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark
                ? [UIColor colorWithWhite:1.0 alpha:0.10]
                : [UIColor colorWithWhite:1.0 alpha:0.56];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.56];
}

static NSString *PPPetCareNormalizedText(NSString *value)
{
    NSString *trimmed = [PPPetCareSafeString(value) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        return @"";
    }
    NSString *normalized = [ArabicNormalizer normalize:trimmed] ?: trimmed;
    return normalized.lowercaseString;
}

@interface PPPetCareVetCell : UICollectionViewCell
@property (nonatomic, copy, nullable) void (^onDetailsTap)(void);
@property (nonatomic, copy, nullable) void (^onCallTap)(void);
+ (NSString *)reuseIdentifier;
- (void)configureWithVet:(VetModel *)vet mainKindName:(NSString *)mainKindName;
@end
@implementation PPPetCareVetCell {
    UIView *_surfaceView;
    UIView *_surfaceFill;
    UIView *_decorativeOrbView;
    UIView *_logoShellView;
    UIImageView *_logoImageView;
    UILabel *_titleLabel;
    UILabel *_descriptionLabel;

    UIView *_kindPillView;
    UILabel *_kindPillLabel;
    UIImageView *_kindPillIcon;

    UIView *_typePillView;
    UILabel *_typePillLabel;
    UIImageView *_typePillIcon;

    UIView *_contactPillView;
    UILabel *_contactPillLabel;
    UIImageView *_contactPillIcon;

    UIButton *_detailsButton;
    UIButton *_callButton;
    UIStackView *_pillStackView;
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

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    _surfaceView = [[UIView alloc] init];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.clipsToBounds = NO;
    _surfaceView.layer.cornerRadius = 28.0;
    _surfaceView.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    _surfaceView.layer.shadowRadius = 24.0;
    _surfaceView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    [self.contentView addSubview:_surfaceView];

    _surfaceFill = [[UIView alloc] init];
    _surfaceFill.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceFill.backgroundColor = PPPetCareSurfaceColor();
    _surfaceFill.layer.cornerRadius = 28.0;
    _surfaceFill.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _surfaceFill.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_surfaceFill];

    [NSLayoutConstraint activateConstraints:@[
        [_surfaceFill.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor],
        [_surfaceFill.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor],
        [_surfaceFill.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor],
        [_surfaceFill.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor],
    ]];

    _decorativeOrbView = [[UIView alloc] init];
    _decorativeOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    _decorativeOrbView.layer.cornerRadius = 40.0;
    [_surfaceFill addSubview:_decorativeOrbView];

    _logoShellView = [[UIView alloc] init];
    _logoShellView.translatesAutoresizingMaskIntoConstraints = NO;
    _logoShellView.layer.cornerRadius = 32.0;
    _logoShellView.layer.borderWidth = 0.8;
    _logoShellView.clipsToBounds = NO;
    [_logoShellView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    _logoShellView.layer.shadowOpacity = 0.12;
    _logoShellView.layer.shadowRadius = 10.0;
    _logoShellView.layer.shadowOffset = CGSizeMake(0, 6);
    if (@available(iOS 13.0, *)) {
        _logoShellView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceFill addSubview:_logoShellView];

    _logoImageView = [[UIImageView alloc] init];
    _logoImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _logoImageView.contentMode = UIViewContentModeScaleAspectFill;
    _logoImageView.clipsToBounds = YES;
    _logoImageView.layer.cornerRadius = 32.0;
    _logoImageView.tintColor = PPPetCareAccentColor();
    [_logoShellView addSubview:_logoImageView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:18.0] ?: [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
    _titleLabel.textColor = PPPetCareTextColor();
    _titleLabel.numberOfLines = 1;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.82;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_surfaceFill addSubview:_titleLabel];

    _descriptionLabel = [[UILabel alloc] init];
    _descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _descriptionLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    _descriptionLabel.textColor = PPPetCareSecondaryTextColor();
    _descriptionLabel.numberOfLines = 2;
    _descriptionLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_surfaceFill addSubview:_descriptionLabel];

    _pillStackView = [[UIStackView alloc] init];
    _pillStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _pillStackView.axis = UILayoutConstraintAxisHorizontal;
    _pillStackView.alignment = UIStackViewAlignmentCenter;
    _pillStackView.spacing = 7.0;
    _pillStackView.distribution = UIStackViewDistributionFillProportionally;
    [_surfaceFill addSubview:_pillStackView];

    UILabel *kindLabel = nil;
    UIImageView *kindIcon = nil;
    _kindPillView = [self pp_makePillViewWithLabel:&kindLabel icon:&kindIcon];
    _kindPillLabel = kindLabel;
    _kindPillIcon = kindIcon;

    UILabel *typeLabel = nil;
    UIImageView *typeIcon = nil;
    _typePillView = [self pp_makePillViewWithLabel:&typeLabel icon:&typeIcon];
    _typePillLabel = typeLabel;
    _typePillIcon = typeIcon;

    UILabel *contactLabel = nil;
    UIImageView *contactIcon = nil;
    _contactPillView = [self pp_makePillViewWithLabel:&contactLabel icon:&contactIcon];
    _contactPillLabel = contactLabel;
    _contactPillIcon = contactIcon;

    [_pillStackView addArrangedSubview:_kindPillView];
    [_pillStackView addArrangedSubview:_typePillView];
    [_pillStackView addArrangedSubview:_contactPillView];

    _detailsButton = [self pp_makeActionButtonPrimary:YES];
    [_detailsButton setTitle:PPPetCareLocalized(@"pet_care_details", @"Details") forState:UIControlStateNormal];
    [_detailsButton addTarget:self action:@selector(pp_detailsTapped) forControlEvents:UIControlEventTouchUpInside];
    [_surfaceFill addSubview:_detailsButton];

    _callButton = [self pp_makeActionButtonPrimary:NO];
    [_callButton setTitle:PPPetCareLocalized(@"pet_care_call", @"Call") forState:UIControlStateNormal];
    [_callButton addTarget:self action:@selector(pp_callTapped) forControlEvents:UIControlEventTouchUpInside];
    [_surfaceFill addSubview:_callButton];

    [NSLayoutConstraint activateConstraints:@[
        [_surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
        [_surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],

        [_decorativeOrbView.trailingAnchor constraintEqualToAnchor:_surfaceFill.trailingAnchor constant:16.0],
        [_decorativeOrbView.topAnchor constraintEqualToAnchor:_surfaceFill.topAnchor constant:-16.0],
        [_decorativeOrbView.widthAnchor constraintEqualToConstant:80.0],
        [_decorativeOrbView.heightAnchor constraintEqualToConstant:80.0],

        [_logoShellView.leadingAnchor constraintEqualToAnchor:_surfaceFill.leadingAnchor constant:16.0],
        [_logoShellView.topAnchor constraintEqualToAnchor:_surfaceFill.topAnchor constant:16.0],
        [_logoShellView.widthAnchor constraintEqualToConstant:64.0],
        [_logoShellView.heightAnchor constraintEqualToConstant:64.0],

        [_logoImageView.topAnchor constraintEqualToAnchor:_logoShellView.topAnchor],
        [_logoImageView.leadingAnchor constraintEqualToAnchor:_logoShellView.leadingAnchor],
        [_logoImageView.trailingAnchor constraintEqualToAnchor:_logoShellView.trailingAnchor],
        [_logoImageView.bottomAnchor constraintEqualToAnchor:_logoShellView.bottomAnchor],

        [_titleLabel.topAnchor constraintEqualToAnchor:_surfaceFill.topAnchor constant:20.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_logoShellView.trailingAnchor constant:14.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_surfaceFill.trailingAnchor constant:-16.0],

        [_descriptionLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6.0],
        [_descriptionLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_descriptionLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [_pillStackView.leadingAnchor constraintEqualToAnchor:_surfaceFill.leadingAnchor constant:16.0],
        [_pillStackView.trailingAnchor constraintLessThanOrEqualToAnchor:_surfaceFill.trailingAnchor constant:-16.0],
        [_pillStackView.topAnchor constraintEqualToAnchor:_logoShellView.bottomAnchor constant:18.0],
        [_pillStackView.heightAnchor constraintEqualToConstant:30.0],

        [_detailsButton.leadingAnchor constraintEqualToAnchor:_surfaceFill.leadingAnchor constant:16.0],
        [_detailsButton.bottomAnchor constraintEqualToAnchor:_surfaceFill.bottomAnchor constant:-16.0],
        [_detailsButton.heightAnchor constraintEqualToConstant:42.0],

        [_callButton.leadingAnchor constraintEqualToAnchor:_detailsButton.trailingAnchor constant:12.0],
        [_callButton.trailingAnchor constraintEqualToAnchor:_surfaceFill.trailingAnchor constant:-16.0],
        [_callButton.widthAnchor constraintEqualToAnchor:_detailsButton.widthAnchor],
        [_callButton.centerYAnchor constraintEqualToAnchor:_detailsButton.centerYAnchor],
        [_callButton.heightAnchor constraintEqualToAnchor:_detailsButton.heightAnchor],
    ]];

    [self pp_applyTheme];
    return self;
}

- (UIView *)pp_makePillViewWithLabel:(UILabel **)labelRef icon:(UIImageView **)iconRef
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.layer.cornerRadius = 15.0;
    container.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        container.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 5.0;
    [container addSubview:stack];

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconView.widthAnchor constraintEqualToConstant:12.0].active = YES;
    [iconView.heightAnchor constraintEqualToConstant:12.0].active = YES;
    [stack addArrangedSubview:iconView];
    *iconRef = iconView;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    label.textAlignment = NSTextAlignmentCenter;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.78;
    [stack addArrangedSubview:label];
    *labelRef = label;

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:8.0],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-8.0],
        [stack.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [container.heightAnchor constraintEqualToConstant:30.0],
        [container.widthAnchor constraintGreaterThanOrEqualToConstant:76.0]
    ]];

    return container;
}

- (UIButton *)pp_makeActionButtonPrimary:(BOOL)primary
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.titleLabel.font = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    button.layer.cornerRadius = 21.0;
    button.layer.borderWidth = primary ? 0.0 : 0.8;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return button;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:_logoImageView];
    _logoImageView.image = nil;
    _titleLabel.text = nil;
    _descriptionLabel.text = nil;
    _kindPillLabel.text = nil;
    _typePillLabel.text = nil;
    _contactPillLabel.text = nil;
    self.onDetailsTap = nil;
    self.onCallTap = nil;
    self.transform = CGAffineTransformIdentity;
    self.alpha = 1.0;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:_surfaceView.layer.cornerRadius].CGPath;
}

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
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    _surfaceView.backgroundColor = UIColor.clearColor;
    [_surfaceView pp_setBorderColor:PPPetCareBorderColor()];
    _surfaceView.layer.shadowOpacity = dark ? 0.12 : 0.08;
    _surfaceView.layer.shadowRadius = 24.0;
    _surfaceView.layer.shadowOffset = CGSizeMake(0.0, 12.0);

    _surfaceFill.backgroundColor = PPPetCareSurfaceColor();

    UIColor *accent = PPPetCareAccentColor();    _decorativeOrbView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.05 : 0.08];

    _logoShellView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.13 : 0.09];
    [_logoShellView pp_setBorderColor:PPPetCareBorderColor()];

    _titleLabel.textColor = PPPetCareTextColor();
    _descriptionLabel.textColor = PPPetCareSecondaryTextColor();

    // Distinct colors for badges
    UIColor *kindColor = dark ? [UIColor colorWithRed:0.28 green:0.82 blue:0.68 alpha:1.0] : [UIColor colorWithRed:0.0 green:0.6 blue:0.4 alpha:1.0];
    UIColor *typeColor = dark ? [UIColor colorWithRed:0.65 green:0.45 blue:0.95 alpha:1.0] : [UIColor colorWithRed:0.45 green:0.25 blue:0.8 alpha:1.0];
    UIColor *contactColor = dark ? [UIColor colorWithRed:0.98 green:0.68 blue:0.25 alpha:1.0] : [UIColor colorWithRed:0.9 green:0.45 blue:0.0 alpha:1.0];

    _kindPillView.backgroundColor = [kindColor colorWithAlphaComponent:dark ? 0.15 : 0.08];
    [_kindPillView pp_setBorderColor:[kindColor colorWithAlphaComponent:0.25]];
    _kindPillLabel.textColor = kindColor;
    _kindPillIcon.tintColor = kindColor;

    _typePillView.backgroundColor = [typeColor colorWithAlphaComponent:dark ? 0.15 : 0.08];
    [_typePillView pp_setBorderColor:[typeColor colorWithAlphaComponent:0.25]];
    _typePillLabel.textColor = typeColor;
    _typePillIcon.tintColor = typeColor;

    _contactPillView.backgroundColor = [contactColor colorWithAlphaComponent:dark ? 0.15 : 0.08];
    [_contactPillView pp_setBorderColor:[contactColor colorWithAlphaComponent:0.25]];
    _contactPillLabel.textColor = contactColor;
    _contactPillIcon.tintColor = contactColor;

    [_detailsButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _detailsButton.backgroundColor = accent;
    [_callButton setTitleColor:PPPetCareTextColor() forState:UIControlStateNormal];
    _callButton.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.13 : 0.08];
    [_callButton pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.24 : 0.15]];
}

- (void)configureWithVet:(VetModel *)vet mainKindName:(NSString *)mainKindName
{
    [self pp_applyTheme];
    self.semanticContentAttribute = Language.isRTL ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    _titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    _descriptionLabel.textAlignment = [Language alignmentForCurrentLanguage];

    _titleLabel.text = vet.title.length > 0 ? vet.title : PPPetCareLocalized(@"pet_care_vet_untitled", @"Veterinarian");
    _descriptionLabel.text = vet.descriptionText.length > 0
        ? vet.descriptionText
        : PPPetCareLocalized(@"pet_care_vet_default_subtitle", @"Care provider ready for pet health support.");

    _kindPillLabel.text = mainKindName.length > 0 ? mainKindName : PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
    _kindPillIcon.image = [[UIImage systemImageNamed:@"pawprint.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    _typePillLabel.text = vet.type == VetTypeCompany
        ? PPPetCareLocalized(@"pet_care_vet_company", @"Clinic")
        : PPPetCareLocalized(@"pet_care_vet_personal", @"Doctor");
    _typePillIcon.image = [[UIImage systemImageNamed:vet.type == VetTypeCompany ? @"building.2.fill" : @"stethoscope"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    _contactPillLabel.text = (vet.phone.length > 0 || vet.whatsapp.length > 0)
        ? PPPetCareLocalized(@"pet_care_vet_contact_ready", @"Contact ready")
        : PPPetCareLocalized(@"pet_care_vet_no_phone", @"Details only");
    _contactPillIcon.image = [[UIImage systemImageNamed:(vet.phone.length > 0 || vet.whatsapp.length > 0) ? @"phone.fill" : @"info.circle.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    [_detailsButton setTitle:PPPetCareLocalized(@"pet_care_details", @"Details") forState:UIControlStateNormal];
    [_callButton setTitle:PPPetCareLocalized(@"pet_care_call", @"Call") forState:UIControlStateNormal];
    _callButton.enabled = (vet.phone.length > 0 || vet.whatsapp.length > 0);
    _callButton.alpha = _callButton.enabled ? 1.0 : 0.52;

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:28.0
                                                        weight:UIImageSymbolWeightSemibold];
    UIImage *placeholder =
        [[UIImage systemImageNamed:@"cross.case.fill" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _logoImageView.image = placeholder;
    _logoImageView.tintColor = PPPetCareAccentColor();
    _logoImageView.backgroundColor = [PPPetCareAccentColor() colorWithAlphaComponent:0.08];

    if (vet.logoURL.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:_logoImageView
                                                       url:vet.logoURL
                                               placeholder:placeholder
                                          transitionStyle:PPImageTransitionStyleFade
                                                complation:nil];
    }

    self.accessibilityLabel = [NSString stringWithFormat:@"%@. %@. %@",
                               _titleLabel.text ?: @"",
                               _descriptionLabel.text ?: @"",
                               _kindPillLabel.text ?: @""];
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

@interface PPPetCareViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITextFieldDelegate, PPUniversalCellDelegate>
@property (nonatomic, assign) PPPetCareInitialSection selectedSection;
@property (nonatomic, assign) PPPetCareMedicineFilter medicineFilter;
@property (nonatomic, assign) PPPetCareVetFilter vetFilter;
@property (nonatomic, strong, nullable) MainKindsModel *selectedMainKind;
@property (nonatomic, copy) NSArray<MainKindsModel *> *mainKinds;
@property (nonatomic, copy) NSArray<VetMedicineModel *> *allMedicines;
@property (nonatomic, copy) NSArray<VetMedicineModel *> *filteredMedicines;
@property (nonatomic, copy) NSArray<VetModel *> *allVets;
@property (nonatomic, copy) NSArray<VetModel *> *filteredVets;
@property (nonatomic, strong) UIView *heroView;
@property (nonatomic, strong) UIView *heroFill;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) UIView *largeOrbView;
@property (nonatomic, strong) UIView *smallOrbView;
@property (nonatomic, strong) UIView *iconPlateView;
@property (nonatomic, strong) UIImageView *heroIconView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *counterLabel;
@property (nonatomic, strong) UISegmentedControl *sectionControl;
@property (nonatomic, strong) UIView *sectionTitleContainer;
@property (nonatomic, strong, nullable) UIButton *navCartButton;
@property (nonatomic, strong) UIView *bottomSearchBarView;
@property (nonatomic, strong) UIView *searchPillView;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIImageView *searchIconView;
@property (nonatomic, strong) UIButton *filterButton;
@property (nonatomic, strong) UIView *filterBadgeView;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, strong) NSLayoutConstraint *bottomSearchBarBottomConstraint;
@property (nonatomic, assign) BOOL loadingMedicines;
@property (nonatomic, assign) BOOL loadingVets;
@property (nonatomic, assign) CGFloat keyboardOverlap;
@property (nonatomic, assign) BOOL previousIQKeyboardManagerEnabled;
@property (nonatomic, assign) BOOL previousIQKeyboardToolbarEnabled;
@property (nonatomic, assign) BOOL isOverridingIQKeyboardManager;
- (void)pp_styleNavigationSectionControl;
- (void)pp_installCartNavigationButton;
- (void)pp_updateCartBadge;
- (void)pp_applyKeyboardManagerOverridesIfNeeded;
- (void)pp_restoreKeyboardManagerOverridesIfNeeded;
@end

@interface PPPetCareMedicineCell : UICollectionViewCell
@property (nonatomic, copy, nullable) void (^onDetailsTap)(void);
+ (NSString *)reuseIdentifier;
- (void)configureWithMedicine:(VetMedicineModel *)medicine mainKindName:(NSString *)mainKindName;
@end

@implementation PPPetCareMedicineCell {
    UIView *_surfaceView;
    UIView *_surfaceFill;
    UIView *_imageShellView;
    UIImageView *_imageView;
    UILabel *_titleLabel;
    UILabel *_descriptionLabel;
    UILabel *_priceLabel;
    UILabel *_statusLabel;
    UILabel *_categoryLabel;
    UIButton *_detailsButton;
}

+ (NSString *)reuseIdentifier
{
    return PPPetCareMedicineCellID;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    _surfaceView = [[UIView alloc] init];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.layer.cornerRadius = 28.0;
    _surfaceView.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    _surfaceView.layer.shadowOpacity = 0.10;
    _surfaceView.layer.shadowRadius = 20.0;
    _surfaceView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    [self.contentView addSubview:_surfaceView];

    _surfaceFill = [[UIView alloc] init];
    _surfaceFill.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceFill.backgroundColor = PPPetCareSurfaceColor();
    _surfaceFill.layer.cornerRadius = 28.0;
    _surfaceFill.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _surfaceFill.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_surfaceFill];

    _imageShellView = [[UIView alloc] init];
    _imageShellView.translatesAutoresizingMaskIntoConstraints = NO;
    _imageShellView.layer.cornerRadius = 22.0;
    _imageShellView.layer.borderWidth = 0.8;
    _imageShellView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _imageShellView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceFill addSubview:_imageShellView];

    _imageView = [[UIImageView alloc] init];
    _imageView.translatesAutoresizingMaskIntoConstraints = NO;
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.clipsToBounds = YES;
    _imageView.tintColor = PPPetCareAccentColor();
    [_imageShellView addSubview:_imageView];

    _statusLabel = [[UILabel alloc] init];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.layer.cornerRadius = 13.0;
    _statusLabel.layer.masksToBounds = YES;
    [_surfaceFill addSubview:_statusLabel];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:17.0] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    _titleLabel.textColor = PPPetCareTextColor();
    _titleLabel.numberOfLines = 2;
    [_surfaceFill addSubview:_titleLabel];

    _descriptionLabel = [[UILabel alloc] init];
    _descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _descriptionLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    _descriptionLabel.textColor = PPPetCareSecondaryTextColor();
    _descriptionLabel.numberOfLines = 3;
    [_surfaceFill addSubview:_descriptionLabel];

    _categoryLabel = [[UILabel alloc] init];
    _categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    _categoryLabel.textColor = PPPetCareSecondaryTextColor();
    [_surfaceFill addSubview:_categoryLabel];

    _priceLabel = [[UILabel alloc] init];
    _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _priceLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    _priceLabel.textColor = PPPetCareTextColor();
    [_surfaceFill addSubview:_priceLabel];

    _detailsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _detailsButton.translatesAutoresizingMaskIntoConstraints = NO;
    _detailsButton.layer.cornerRadius = 18.0;
    _detailsButton.clipsToBounds = YES;
    _detailsButton.titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    [_detailsButton addTarget:self action:@selector(pp_detailsTapped) forControlEvents:UIControlEventTouchUpInside];
    [_surfaceFill addSubview:_detailsButton];

    [NSLayoutConstraint activateConstraints:@[
        [_surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [_surfaceFill.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor],
        [_surfaceFill.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor],
        [_surfaceFill.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor],
        [_surfaceFill.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor],

        [_imageShellView.topAnchor constraintEqualToAnchor:_surfaceFill.topAnchor constant:16.0],
        [_imageShellView.leadingAnchor constraintEqualToAnchor:_surfaceFill.leadingAnchor constant:16.0],
        [_imageShellView.trailingAnchor constraintEqualToAnchor:_surfaceFill.trailingAnchor constant:-16.0],
        [_imageShellView.heightAnchor constraintEqualToConstant:136.0],

        [_imageView.topAnchor constraintEqualToAnchor:_imageShellView.topAnchor],
        [_imageView.leadingAnchor constraintEqualToAnchor:_imageShellView.leadingAnchor],
        [_imageView.trailingAnchor constraintEqualToAnchor:_imageShellView.trailingAnchor],
        [_imageView.bottomAnchor constraintEqualToAnchor:_imageShellView.bottomAnchor],

        [_statusLabel.topAnchor constraintEqualToAnchor:_surfaceFill.topAnchor constant:16.0],
        [_statusLabel.trailingAnchor constraintEqualToAnchor:_surfaceFill.trailingAnchor constant:-16.0],
        [_statusLabel.heightAnchor constraintEqualToConstant:26.0],
        [_statusLabel.widthAnchor constraintGreaterThanOrEqualToConstant:88.0],

        [_titleLabel.topAnchor constraintEqualToAnchor:_imageShellView.bottomAnchor constant:14.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_surfaceFill.leadingAnchor constant:16.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_surfaceFill.trailingAnchor constant:-16.0],

        [_descriptionLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6.0],
        [_descriptionLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_descriptionLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [_categoryLabel.topAnchor constraintEqualToAnchor:_descriptionLabel.bottomAnchor constant:10.0],
        [_categoryLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_categoryLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [_priceLabel.topAnchor constraintEqualToAnchor:_categoryLabel.bottomAnchor constant:10.0],
        [_priceLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_priceLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [_detailsButton.topAnchor constraintEqualToAnchor:_priceLabel.bottomAnchor constant:14.0],
        [_detailsButton.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_detailsButton.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
        [_detailsButton.heightAnchor constraintEqualToConstant:44.0],
        [_detailsButton.bottomAnchor constraintEqualToAnchor:_surfaceFill.bottomAnchor constant:-16.0],
    ]];
    return self;
}

- (void)configureWithMedicine:(VetMedicineModel *)medicine mainKindName:(NSString *)mainKindName
{
    UIColor *accentColor = PPPetCareAccentColor();
    _surfaceView.layer.borderColor = PPPetCareBorderColor().CGColor;
    _imageShellView.layer.borderColor = [accentColor colorWithAlphaComponent:0.12].CGColor;
    _imageShellView.backgroundColor = [accentColor colorWithAlphaComponent:0.08];

    _titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    _descriptionLabel.textAlignment = [Language alignmentForCurrentLanguage];
    _categoryLabel.textAlignment = [Language alignmentForCurrentLanguage];
    _priceLabel.textAlignment = [Language alignmentForCurrentLanguage];

    _titleLabel.text = medicine.title.length > 0 ? medicine.title : PPPetCareLocalized(@"pet_care_medicine_untitled", @"Medicine");
    _descriptionLabel.text = medicine.medicineDescription.length > 0 ? medicine.medicineDescription : PPPetCareLocalized(@"pet_care_medicine_default_subtitle", @"Care essentials prepared by approved veterinary partners.");
    _categoryLabel.text = mainKindName.length > 0 ? mainKindName : PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
    _priceLabel.text = [NSString stringWithFormat:@"%.2f %@", medicine.price, medicine.currency.length > 0 ? medicine.currency : @"QAR"];

    BOOL prescriptionRequired = medicine.requiresPrescription;
    _statusLabel.text = prescriptionRequired
        ? PPPetCareLocalized(@"pet_care_medicine_prescription_required", @"Prescription required")
        : PPPetCareLocalized(@"pet_care_medicine_ready", @"Ready to order");
    _statusLabel.backgroundColor = [accentColor colorWithAlphaComponent:prescriptionRequired ? 0.14 : 0.09];
    _statusLabel.textColor = prescriptionRequired ? [UIColor systemOrangeColor] : accentColor;

    [_detailsButton setTitle:PPPetCareLocalized(@"pet_care_details_button", @"Details") forState:UIControlStateNormal];
    [_detailsButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _detailsButton.backgroundColor = accentColor;
    _detailsButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIImage *placeholder = [UIImage systemImageNamed:@"pills.fill"];
    _imageView.image = placeholder;
    if (medicine.imageUrl.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:_imageView
                                                       url:medicine.imageUrl
                                               placeholder:placeholder
                                          transitionStyle:PPImageTransitionStyleNone
                                                complation:nil];
    }
}

- (void)pp_detailsTapped
{
    if (self.onDetailsTap) {
        self.onDetailsTap();
    }
}

@end

@implementation PPPetCareViewController

- (instancetype)initWithInitialSection:(PPPetCareInitialSection)section
                              mainKind:(MainKindsModel *)mainKind
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) {
        return nil;
    }
    _selectedSection = section;
    _selectedMainKind = mainKind;
    _medicineFilter = PPPetCareMedicineFilterAll;
    _vetFilter = PPPetCareVetFilterAll;
    _mainKinds = @[];
    _allMedicines = @[];
    _filteredMedicines = @[];
    _allVets = @[];
    _filteredVets = @[];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self pp_applyKeyboardManagerOverridesIfNeeded];
    self.view.backgroundColor = UIColor.secondarySystemBackgroundColor;
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto
                      button:nil
                       title:nil//PPPetCareLocalized(@"pet_care_title", @"Pet Care")
                    showBack:YES];
    [self pp_setupViews];
    [self pp_installCartNavigationButton];
    [self pp_loadFilters];
    [self pp_updateLocalizedText];
    [self pp_applyTheme];
    [self pp_loadData];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_appWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleCartUpdated:)
                                                 name:kCartUpdatedNotification
                                               object:nil];
}

- (void)dealloc
{
    [self pp_restoreKeyboardManagerOverridesIfNeeded];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_applyKeyboardManagerOverridesIfNeeded];
    [self pp_installNavigationTitleControl];
    [self pp_installCartNavigationButton];
    [self pp_updateLocalizedText];
    [self pp_applyTheme];
    [self pp_updateCartBadge];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.searchField resignFirstResponder];
    [self pp_restoreKeyboardManagerOverridesIfNeeded];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyTheme];
            [self.collectionView reloadData];
        }
    }
}

- (void)pp_appWillEnterForeground
{
    [self pp_applyTheme];
    [self pp_updateBottomSearchPositionAnimated:NO notification:nil];
    [self pp_updateCollectionBottomInsets];
    [self.collectionView.visibleCells makeObjectsPerformSelector:@selector(setNeedsLayout)];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if (self.heroGradientLayer && self.heroFill) {
        self.heroGradientLayer.frame = self.heroFill.bounds;
        self.heroGradientLayer.cornerRadius = self.heroFill.layer.cornerRadius;
    }
    if (self.heroView) {
        self.heroView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.heroView.bounds cornerRadius:self.heroView.layer.cornerRadius].CGPath;
    }
    [self pp_updateBottomSearchPositionAnimated:NO notification:nil];
    [self pp_updateCollectionBottomInsets];
}

#pragma mark - Setup

- (void)pp_setupViews
{
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.backgroundColor = UIColor.clearColor;
    [self.view addSubview:contentView];

    _heroView = [[UIView alloc] init];
    _heroView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroView.layer.cornerRadius = 32.0;
    _heroView.layer.borderWidth = 0.8;
    _heroView.clipsToBounds = NO;
    if (@available(iOS 13.0, *)) {
        _heroView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_heroView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    _heroView.layer.shadowRadius = 24.0;
    _heroView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    [contentView addSubview:_heroView];

    _heroFill = [[UIView alloc] init];
    _heroFill.translatesAutoresizingMaskIntoConstraints = NO;
    _heroFill.layer.cornerRadius = 32.0;
    _heroFill.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _heroFill.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_heroView addSubview:_heroFill];

    _heroGradientLayer = [CAGradientLayer layer];
    _heroGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    _heroGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [_heroFill.layer insertSublayer:_heroGradientLayer atIndex:0];

    _largeOrbView = [[UIView alloc] init];
    _largeOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    _largeOrbView.layer.cornerRadius = 60.0;
    [_heroFill addSubview:_largeOrbView];

    _smallOrbView = [[UIView alloc] init];
    _smallOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    _smallOrbView.layer.cornerRadius = 24.0;
    [_heroFill addSubview:_smallOrbView];

    _iconPlateView = [[UIView alloc] init];
    _iconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconPlateView.layer.cornerRadius = 24.0;
    _iconPlateView.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        _iconPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_heroView addSubview:_iconPlateView];

    _heroIconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"cross.case.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    _heroIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroIconView.contentMode = UIViewContentModeScaleAspectFit;
    [_iconPlateView addSubview:_heroIconView];

    _eyebrowLabel = [[UILabel alloc] init];
    _eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _eyebrowLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    _eyebrowLabel.numberOfLines = 1;
    [_heroView addSubview:_eyebrowLabel];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:26.0] ?: [UIFont systemFontOfSize:26.0 weight:UIFontWeightBold];
    _titleLabel.numberOfLines = 1;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.78;
    [_heroView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    _subtitleLabel.numberOfLines = 2;
    [_heroView addSubview:_subtitleLabel];

    _counterLabel = [[UILabel alloc] init];
    _counterLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _counterLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    _counterLabel.textAlignment = NSTextAlignmentCenter;
    _counterLabel.layer.cornerRadius = 14.0;
    _counterLabel.layer.masksToBounds = YES;
    _counterLabel.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        _counterLabel.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_heroView addSubview:_counterLabel];

    _sectionControl = [[UISegmentedControl alloc] initWithItems:@[@"", @""]];
    _sectionControl.translatesAutoresizingMaskIntoConstraints = NO;
    _sectionControl.selectedSegmentIndex = self.selectedSection == PPPetCareInitialSectionVeterinarians ? 1 : 0;
    [_sectionControl addTarget:self action:@selector(pp_sectionChanged:) forControlEvents:UIControlEventValueChanged];
    [self pp_installNavigationTitleControl];

    _bottomSearchBarView = [[UIView alloc] init];
    _bottomSearchBarView.translatesAutoresizingMaskIntoConstraints = NO;
    _bottomSearchBarView.backgroundColor = UIColor.clearColor;
    _bottomSearchBarView.layer.shadowRadius = 22.0;
    _bottomSearchBarView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    _bottomSearchBarView.layer.shadowOpacity = 0.14;
    [_bottomSearchBarView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    [contentView addSubview:_bottomSearchBarView];

    _searchPillView = [[UIView alloc] init];
    _searchPillView.translatesAutoresizingMaskIntoConstraints = NO;
    _searchPillView.layer.cornerRadius = 28.0;
    _searchPillView.layer.borderWidth = 0.7;
    _searchPillView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _searchPillView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_bottomSearchBarView addSubview:_searchPillView];

    if (@available(iOS 13.0, *)) {
        UIVisualEffectView *searchMaterial =
            [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
        searchMaterial.translatesAutoresizingMaskIntoConstraints = NO;
        searchMaterial.userInteractionEnabled = NO;
        [_searchPillView addSubview:searchMaterial];
        [NSLayoutConstraint activateConstraints:@[
            [searchMaterial.topAnchor constraintEqualToAnchor:_searchPillView.topAnchor],
            [searchMaterial.leadingAnchor constraintEqualToAnchor:_searchPillView.leadingAnchor],
            [searchMaterial.trailingAnchor constraintEqualToAnchor:_searchPillView.trailingAnchor],
            [searchMaterial.bottomAnchor constraintEqualToAnchor:_searchPillView.bottomAnchor]
        ]];
    }

    _searchField = [[UITextField alloc] init];
    _searchField.translatesAutoresizingMaskIntoConstraints = NO;
    _searchField.delegate = self;
    _searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _searchField.returnKeyType = UIReturnKeySearch;
    _searchField.backgroundColor = UIColor.clearColor;
    _searchField.leftViewMode = UITextFieldViewModeNever;
    _searchField.inputAccessoryView = nil;
    if (@available(iOS 9.0, *)) {
        _searchField.inputAssistantItem.leadingBarButtonGroups = @[];
        _searchField.inputAssistantItem.trailingBarButtonGroups = @[];
    }
    _searchField.font = [GM MidFontWithSize:17.0] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    [_searchField addTarget:self action:@selector(pp_searchTextChanged:) forControlEvents:UIControlEventEditingChanged];
    [_searchPillView addSubview:_searchField];

    _searchIconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"magnifyingglass"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    _searchIconView.translatesAutoresizingMaskIntoConstraints = NO;
    _searchIconView.tintColor = PPPetCareSecondaryTextColor();
    _searchIconView.contentMode = UIViewContentModeScaleAspectFit;
    _searchIconView.isAccessibilityElement = NO;
    [_searchPillView addSubview:_searchIconView];

    _filterButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _filterButton.translatesAutoresizingMaskIntoConstraints = NO;
    _filterButton.layer.cornerRadius = 24.0;
    _filterButton.layer.borderWidth = 1.0;
    _filterButton.clipsToBounds = NO;
    if (@available(iOS 13.0, *)) {
        _filterButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_filterButton setImage:[[UIImage systemImageNamed:@"slider.horizontal.3"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    _filterButton.accessibilityLabel = PPPetCareLocalized(@"pet_care_filter_by", @"Filter By");
    if (@available(iOS 14.0, *)) {
        _filterButton.showsMenuAsPrimaryAction = YES;
    }
    [_bottomSearchBarView addSubview:_filterButton];

    _filterBadgeView = [[UIView alloc] init];
    _filterBadgeView.translatesAutoresizingMaskIntoConstraints = NO;
    _filterBadgeView.backgroundColor = [UIColor systemRedColor];
    _filterBadgeView.layer.cornerRadius = 4.5;
    _filterBadgeView.layer.masksToBounds = YES;
    _filterBadgeView.layer.borderWidth = 1.5;
    _filterBadgeView.layer.borderColor = UIColor.whiteColor.CGColor;
    _filterBadgeView.hidden = YES;
    _filterBadgeView.userInteractionEnabled = NO;
    [_filterButton addSubview:_filterBadgeView];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumLineSpacing = 12.0;
    layout.minimumInteritemSpacing = 12.0;
    layout.sectionInset = UIEdgeInsetsMake(6.0, 18.0, 24.0, 18.0);

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.backgroundColor = UIColor.clearColor;
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [_collectionView registerClass:PPPetCareMedicineCell.class forCellWithReuseIdentifier:PPPetCareMedicineCellID];
    [_collectionView registerClass:PPPetCareVetCell.class forCellWithReuseIdentifier:PPPetCareVetCell.reuseIdentifier];
    [contentView addSubview:_collectionView];

    _emptyView = [[UIView alloc] init];
    _emptyView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyView.userInteractionEnabled = NO;
    _emptyView.hidden = YES;

    UIImageView *emptyIcon = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"heart.text.square.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    emptyIcon.translatesAutoresizingMaskIntoConstraints = NO;
    emptyIcon.tintColor = [PPPetCareAccentColor() colorWithAlphaComponent:0.72];
    [_emptyView addSubview:emptyIcon];

    _emptyTitleLabel = [[UILabel alloc] init];
    _emptyTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyTitleLabel.font = [GM boldFontWithSize:18.0] ?: [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
    _emptyTitleLabel.textColor = PPPetCareTextColor();
    _emptyTitleLabel.textAlignment = NSTextAlignmentCenter;
    _emptyTitleLabel.numberOfLines = 2;
    [_emptyView addSubview:_emptyTitleLabel];

    _emptySubtitleLabel = [[UILabel alloc] init];
    _emptySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptySubtitleLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    _emptySubtitleLabel.textColor = PPPetCareSecondaryTextColor();
    _emptySubtitleLabel.textAlignment = NSTextAlignmentCenter;
    _emptySubtitleLabel.numberOfLines = 3;
    [_emptyView addSubview:_emptySubtitleLabel];
    [contentView addSubview:_emptyView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    self.bottomSearchBarBottomConstraint =
        [_bottomSearchBarView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor];

    [NSLayoutConstraint activateConstraints:@[
        [contentView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_heroFill.topAnchor constraintEqualToAnchor:_heroView.topAnchor],
        [_heroFill.leadingAnchor constraintEqualToAnchor:_heroView.leadingAnchor],
        [_heroFill.trailingAnchor constraintEqualToAnchor:_heroView.trailingAnchor],
        [_heroFill.bottomAnchor constraintEqualToAnchor:_heroView.bottomAnchor],

        [_heroView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:12.0],
        [_heroView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:18.0],
        [_heroView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-18.0],
        [_heroView.heightAnchor constraintEqualToConstant:162.0],

        [_largeOrbView.widthAnchor constraintEqualToConstant:120.0],
        [_largeOrbView.heightAnchor constraintEqualToConstant:120.0],
        [_largeOrbView.trailingAnchor constraintEqualToAnchor:_heroFill.trailingAnchor constant:24.0],
        [_largeOrbView.topAnchor constraintEqualToAnchor:_heroFill.topAnchor constant:-24.0],

        [_smallOrbView.widthAnchor constraintEqualToConstant:48.0],
        [_smallOrbView.heightAnchor constraintEqualToConstant:48.0],
        [_smallOrbView.leadingAnchor constraintEqualToAnchor:_heroFill.leadingAnchor constant:30.0],
        [_smallOrbView.bottomAnchor constraintEqualToAnchor:_heroFill.bottomAnchor constant:16.0],

        [_iconPlateView.trailingAnchor constraintEqualToAnchor:_heroView.trailingAnchor constant:-18.0],
        [_iconPlateView.topAnchor constraintEqualToAnchor:_heroView.topAnchor constant:18.0],
        [_iconPlateView.widthAnchor constraintEqualToConstant:48.0],
        [_iconPlateView.heightAnchor constraintEqualToConstant:48.0],

        [_heroIconView.centerXAnchor constraintEqualToAnchor:_iconPlateView.centerXAnchor],
        [_heroIconView.centerYAnchor constraintEqualToAnchor:_iconPlateView.centerYAnchor],
        [_heroIconView.widthAnchor constraintEqualToConstant:22.0],
        [_heroIconView.heightAnchor constraintEqualToConstant:22.0],

        [_eyebrowLabel.leadingAnchor constraintEqualToAnchor:_heroView.leadingAnchor constant:20.0],
        [_eyebrowLabel.topAnchor constraintEqualToAnchor:_heroView.topAnchor constant:18.0],
        [_eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_iconPlateView.leadingAnchor constant:-12.0],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_eyebrowLabel.leadingAnchor],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_iconPlateView.leadingAnchor constant:-12.0],
        [_titleLabel.topAnchor constraintEqualToAnchor:_eyebrowLabel.bottomAnchor constant:8.0],

        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_heroView.trailingAnchor constant:-20.0],
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6.0],

        [_counterLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_counterLabel.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:12.0],
        [_counterLabel.heightAnchor constraintEqualToConstant:28.0],
        [_counterLabel.widthAnchor constraintGreaterThanOrEqualToConstant:76.0],

        [_collectionView.topAnchor constraintEqualToAnchor:_heroView.bottomAnchor constant:14.0],
        [_collectionView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [_collectionView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [_collectionView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],

        [_bottomSearchBarView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:18.0],
        [_bottomSearchBarView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-18.0],
        self.bottomSearchBarBottomConstraint,
        [_bottomSearchBarView.heightAnchor constraintEqualToConstant:64.0],

        [_searchPillView.leadingAnchor constraintEqualToAnchor:_bottomSearchBarView.leadingAnchor],
        [_searchPillView.centerYAnchor constraintEqualToAnchor:_bottomSearchBarView.centerYAnchor],
        [_searchPillView.heightAnchor constraintEqualToConstant:56.0],

        [_filterButton.leadingAnchor constraintEqualToAnchor:_searchPillView.trailingAnchor constant:10.0],
        [_filterButton.trailingAnchor constraintEqualToAnchor:_bottomSearchBarView.trailingAnchor],
        [_filterButton.centerYAnchor constraintEqualToAnchor:_bottomSearchBarView.centerYAnchor],
        [_filterButton.heightAnchor constraintEqualToConstant:56.0],
        [_filterButton.widthAnchor constraintEqualToConstant:56.0],

        [_filterBadgeView.topAnchor constraintEqualToAnchor:_filterButton.topAnchor constant:14.0],
        [_filterBadgeView.trailingAnchor constraintEqualToAnchor:_filterButton.trailingAnchor constant:-14.0],
        [_filterBadgeView.widthAnchor constraintEqualToConstant:9.0],
        [_filterBadgeView.heightAnchor constraintEqualToConstant:9.0],

        [_searchField.topAnchor constraintEqualToAnchor:_searchPillView.topAnchor],
        [_searchField.leadingAnchor constraintEqualToAnchor:_searchPillView.leadingAnchor constant:18.0],
        [_searchField.trailingAnchor constraintEqualToAnchor:_searchIconView.leadingAnchor constant:-10.0],
        [_searchField.bottomAnchor constraintEqualToAnchor:_searchPillView.bottomAnchor],

        [_searchIconView.trailingAnchor constraintEqualToAnchor:_searchPillView.trailingAnchor constant:-18.0],
        [_searchIconView.centerYAnchor constraintEqualToAnchor:_searchPillView.centerYAnchor],
        [_searchIconView.widthAnchor constraintEqualToConstant:20.0],
        [_searchIconView.heightAnchor constraintEqualToConstant:20.0],

        [_emptyView.centerXAnchor constraintEqualToAnchor:_collectionView.centerXAnchor],
        [_emptyView.centerYAnchor constraintEqualToAnchor:_collectionView.centerYAnchor constant:-20.0],
        [_emptyView.leadingAnchor constraintGreaterThanOrEqualToAnchor:_collectionView.leadingAnchor constant:36.0],
        [_emptyView.trailingAnchor constraintLessThanOrEqualToAnchor:_collectionView.trailingAnchor constant:-36.0],

        [emptyIcon.topAnchor constraintEqualToAnchor:_emptyView.topAnchor],
        [emptyIcon.centerXAnchor constraintEqualToAnchor:_emptyView.centerXAnchor],
        [emptyIcon.widthAnchor constraintEqualToConstant:38.0],
        [emptyIcon.heightAnchor constraintEqualToConstant:38.0],

        [_emptyTitleLabel.topAnchor constraintEqualToAnchor:emptyIcon.bottomAnchor constant:12.0],
        [_emptyTitleLabel.leadingAnchor constraintEqualToAnchor:_emptyView.leadingAnchor],
        [_emptyTitleLabel.trailingAnchor constraintEqualToAnchor:_emptyView.trailingAnchor],

        [_emptySubtitleLabel.topAnchor constraintEqualToAnchor:_emptyTitleLabel.bottomAnchor constant:7.0],
        [_emptySubtitleLabel.leadingAnchor constraintEqualToAnchor:_emptyView.leadingAnchor],
        [_emptySubtitleLabel.trailingAnchor constraintEqualToAnchor:_emptyView.trailingAnchor],
        [_emptySubtitleLabel.bottomAnchor constraintEqualToAnchor:_emptyView.bottomAnchor],
    ]];

    [contentView bringSubviewToFront:_bottomSearchBarView];
    [self pp_updateBottomSearchPositionAnimated:NO notification:nil];
    [self pp_updateCollectionBottomInsets];
}

#pragma mark - Navigation And Bottom Search

- (void)pp_applyKeyboardManagerOverridesIfNeeded
{
    IQKeyboardManager *manager = [IQKeyboardManager sharedManager];
    if (!self.isOverridingIQKeyboardManager) {
        self.previousIQKeyboardManagerEnabled = manager.enable;
        self.previousIQKeyboardToolbarEnabled = manager.enableAutoToolbar;
        self.isOverridingIQKeyboardManager = YES;
    }

    manager.enable = NO;
    manager.enableAutoToolbar = NO;
    self.searchField.inputAccessoryView = nil;
    [self.searchField reloadInputViews];
}

- (void)pp_restoreKeyboardManagerOverridesIfNeeded
{
    if (!self.isOverridingIQKeyboardManager) {
        return;
    }

    IQKeyboardManager *manager = [IQKeyboardManager sharedManager];
    manager.enable = self.previousIQKeyboardManagerEnabled;
    manager.enableAutoToolbar = self.previousIQKeyboardToolbarEnabled;
    self.isOverridingIQKeyboardManager = NO;
}

- (void)pp_installNavigationTitleControl
{
    if (!self.sectionControl) {
        return;
    }

    CGFloat segmentWidth = PPPetCareNavigationSegmentWidth();
    CGFloat segmentHeight = 34.0;
    if (!self.sectionTitleContainer) {
        self.sectionTitleContainer = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, segmentWidth, segmentHeight)];
        [self.sectionTitleContainer addSubview:self.sectionControl];
        [NSLayoutConstraint activateConstraints:@[
            [self.sectionControl.topAnchor constraintEqualToAnchor:self.sectionTitleContainer.topAnchor],
            [self.sectionControl.leadingAnchor constraintEqualToAnchor:self.sectionTitleContainer.leadingAnchor],
            [self.sectionControl.trailingAnchor constraintEqualToAnchor:self.sectionTitleContainer.trailingAnchor],
            [self.sectionControl.bottomAnchor constraintEqualToAnchor:self.sectionTitleContainer.bottomAnchor]
        ]];
    }
    self.sectionTitleContainer.frame = CGRectMake(0.0, 0.0, segmentWidth, segmentHeight);
    self.sectionTitleContainer.bounds = CGRectMake(0.0, 0.0, segmentWidth, segmentHeight);

    self.navigationItem.title = nil;
    self.navigationItem.hidesBackButton = NO;
    if (self.navigationItem.titleView != self.sectionTitleContainer) {
        self.navigationItem.titleView = self.sectionTitleContainer;
    }
    [self pp_styleNavigationSectionControl];
}

- (void)pp_styleNavigationSectionControl
{
    if (!self.sectionControl) {
        return;
    }

    UIFont *normalFont = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    UIFont *selectedFont = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    UIColor *normalColor = PPPetCareSecondaryTextColor();
    UIColor *selectedColor = PPPetCareTextColor();

    [self.sectionControl setTitleTextAttributes:@{
        NSFontAttributeName: normalFont,
        NSForegroundColorAttributeName: normalColor
    } forState:UIControlStateNormal];
    [self.sectionControl setTitleTextAttributes:@{
        NSFontAttributeName: selectedFont,
        NSForegroundColorAttributeName: selectedColor
    } forState:UIControlStateSelected];

    self.sectionControl.backgroundColor = PPPetCareSurfaceColor();
    self.sectionControl.selectedSegmentTintColor = [PPPetCareAccentColor() colorWithAlphaComponent:0.18];
    self.sectionControl.tintColor = PPPetCareAccentColor();
    self.sectionControl.apportionsSegmentWidthsByContent = NO;
}

- (void)pp_installCartNavigationButton
{
    if (self.navCartButton && self.navigationItem.rightBarButtonItem.customView == self.navCartButton) {
        return;
    }

    UIButton *cartNavBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [cartNavBtn setImage:[UIImage systemImageNamed:@"cart.fill"] forState:UIControlStateNormal];
    [cartNavBtn addTarget:self action:@selector(onCartTapped) forControlEvents:UIControlEventTouchUpInside];
    cartNavBtn.accessibilityLabel = PPPetCareLocalized(@"Cart", @"Cart");

    if (!PPIOS26()) {
        cartNavBtn.backgroundColor = AppForgroundColr;
        cartNavBtn.layer.cornerRadius = 20.0;
        cartNavBtn.clipsToBounds = NO;
        [cartNavBtn.widthAnchor constraintEqualToConstant:40.0].active = YES;
        [cartNavBtn.heightAnchor constraintEqualToConstant:40.0].active = YES;
    }

    self.navCartButton = cartNavBtn;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cartNavBtn];
    [self pp_updateCartBadge];
}

- (NSInteger)pp_currentCartItemCount
{
    return [CartManager.sharedManager totalItemsCount];
}

- (void)pp_updateCartBadge
{
    if (!self.navCartButton) {
        return;
    }

    UIButton *badgeHost = self.navCartButton;
    [badgeHost removeBadge];

    NSInteger count = [self pp_currentCartItemCount];
    if (count <= 0) {
        return;
    }

    NSString *badgeText = (count > 99) ? @"99+" : [NSString stringWithFormat:@"%ld", (long)count];
    UIColor *badgeColor = AppPrimaryClr ?: UIColor.systemPinkColor;

    void (^applyBadge)(void) = ^{
        UIButton *host = self.navCartButton;
        if (!host) return;

        [host layoutIfNeeded];
        if (CGRectIsEmpty(host.bounds)) return;

        [host removeBadge];
        [host addBadgeWithContent:badgeText
                       badgeColor:badgeColor
                           offset:CGPointMake(-10.0, 10.0)
                      badgeRadius:9.5];
    };

    applyBadge();
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController.navigationBar setNeedsLayout];
        [self.navigationController.navigationBar layoutIfNeeded];
        applyBadge();
    });
}

- (void)pp_handleCartUpdated:(NSNotification *)notification
{
    (void)notification;
    [self pp_updateCartBadge];
}

- (void)onCartTapped
{
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    CartViewController *vc = [[CartViewController alloc] init];
    PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [PPHomeHelper presentViewControllerSafely:nav
                                         from:self
                                     animated:YES
                                   completion:nil];
}

- (void)pp_updateBottomSearchPositionAnimated:(BOOL)animated
                                 notification:(NSNotification *)notification
{
    if (!self.bottomSearchBarBottomConstraint) {
        return;
    }

    CGFloat safeBottom = self.view.safeAreaInsets.bottom;
    CGFloat bottomInset = self.keyboardOverlap > 0.0 ? self.keyboardOverlap + 12.0 : safeBottom + 12.0;
    self.bottomSearchBarBottomConstraint.constant = -bottomInset;
    [self pp_updateCollectionBottomInsets];

    void (^changes)(void) = ^{
        self.bottomSearchBarView.transform = CGAffineTransformIdentity;
        [self.view layoutIfNeeded];
    };

    if (!animated) {
        changes();
        return;
    }

    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    if (duration <= 0.0) {
        duration = 0.28;
    }
    UIViewAnimationCurve curve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    UIViewAnimationOptions options = (curve << 16) | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction;

    [UIView animateWithDuration:duration
                          delay:0.0
                        options:options
                     animations:changes
                     completion:nil];
}

- (void)pp_updateCollectionBottomInsets
{
    if (!self.collectionView) {
        return;
    }

    CGFloat bottomInset = self.keyboardOverlap > 0.0 ? self.keyboardOverlap + 12.0 : self.view.safeAreaInsets.bottom;
    CGFloat bottomChrome = 92.0 + bottomInset;
    UIEdgeInsets contentInset = self.collectionView.contentInset;
    contentInset.bottom = bottomChrome;
    self.collectionView.contentInset = contentInset;

    UIEdgeInsets indicatorInset = self.collectionView.scrollIndicatorInsets;
    indicatorInset.bottom = bottomChrome;
    self.collectionView.scrollIndicatorInsets = indicatorInset;
}

- (void)pp_keyboardWillChangeFrame:(NSNotification *)notification
{
    self.navigationItem.hidesBackButton = NO;
    CGRect keyboardEndFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameInView = [self.view convertRect:keyboardEndFrame fromView:nil];
    CGFloat overlap = CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(keyboardFrameInView);
    self.keyboardOverlap = MAX(0.0, overlap);
    [self pp_updateBottomSearchPositionAnimated:YES notification:notification];
}

- (void)pp_keyboardWillHide:(NSNotification *)notification
{
    self.navigationItem.hidesBackButton = NO;
    self.keyboardOverlap = 0.0;
    [self pp_updateBottomSearchPositionAnimated:YES notification:notification];
}

#pragma mark - Data

- (void)pp_loadFilters
{
    NSArray *kinds = [MKM.MainKindsArray isKindOfClass:NSArray.class] ? MKM.MainKindsArray : @[];
    self.mainKinds = kinds;
    [self pp_updateFilterMenu];
}

- (void)pp_updateFilterMenu
{
    if (@available(iOS 14.0, *)) {
        NSMutableArray<UIAction *> *kindActions = [NSMutableArray array];
        __weak typeof(self) weakSelf = self;

        UIAction *allKindAction = [UIAction actionWithTitle:PPPetCareLocalized(@"pet_care_all_pets", @"All pets") image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            weakSelf.selectedMainKind = nil;
            [weakSelf pp_applyFiltersAndReload];
            [weakSelf pp_updateFilterMenu];
        }];
        allKindAction.state = self.selectedMainKind == nil ? UIMenuElementStateOn : UIMenuElementStateOff;
        [kindActions addObject:allKindAction];

        for (MainKindsModel *kind in self.mainKinds) {
            NSString *title = kind.KindName.length > 0 ? kind.KindName : kind.KindNameEn ?: kind.KindNameAr ?: @"";
            UIAction *action = [UIAction actionWithTitle:title image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                weakSelf.selectedMainKind = kind;
                [weakSelf pp_applyFiltersAndReload];
                [weakSelf pp_updateFilterMenu];
            }];
            action.state = (self.selectedMainKind && self.selectedMainKind.ID == kind.ID) ? UIMenuElementStateOn : UIMenuElementStateOff;
            [kindActions addObject:action];
        }

        UIMenu *kindMenu = [UIMenu menuWithTitle:PPPetCareLocalized(@"pet_care_kind_filter", @"Pet Kind") image:[UIImage systemImageNamed:@"pawprint.fill"] identifier:nil options:0 children:kindActions];

        NSMutableArray<UIAction *> *modeActions = [NSMutableArray array];
        NSArray<NSDictionary *> *items = self.selectedSection == PPPetCareInitialSectionMedicines
            ? @[
                @{@"title": PPPetCareLocalized(@"pet_care_filter_all", @"All"), @"tag": @(PPPetCareMedicineFilterAll)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_offers", @"Offers"), @"tag": @(PPPetCareMedicineFilterOffers)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_in_stock", @"In stock"), @"tag": @(PPPetCareMedicineFilterInStock)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_new", @"New"), @"tag": @(PPPetCareMedicineFilterNew)}
            ]
            : @[
                @{@"title": PPPetCareLocalized(@"pet_care_filter_all", @"All"), @"tag": @(PPPetCareVetFilterAll)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_with_phone", @"Contact ready"), @"tag": @(PPPetCareVetFilterWithPhone)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_clinics", @"Clinics"), @"tag": @(PPPetCareVetFilterCompany)},
                @{@"title": PPPetCareLocalized(@"pet_care_filter_doctors", @"Doctors"), @"tag": @(PPPetCareVetFilterPersonal)}
            ];

        for (NSDictionary *item in items) {
            NSInteger tag = [item[@"tag"] integerValue];
            BOOL isSelected = self.selectedSection == PPPetCareInitialSectionMedicines
                ? tag == self.medicineFilter
                : tag == self.vetFilter;

            UIAction *action = [UIAction actionWithTitle:item[@"title"] image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                if (weakSelf.selectedSection == PPPetCareInitialSectionMedicines) {
                    weakSelf.medicineFilter = (PPPetCareMedicineFilter)tag;
                } else {
                    weakSelf.vetFilter = (PPPetCareVetFilter)tag;
                }
                [weakSelf pp_applyFiltersAndReload];
                [weakSelf pp_updateFilterMenu];
            }];
            action.state = isSelected ? UIMenuElementStateOn : UIMenuElementStateOff;
            [modeActions addObject:action];
        }

        UIMenu *modeMenu = [UIMenu menuWithTitle:PPPetCareLocalized(@"pet_care_filter_by", @"Filter By") image:[UIImage systemImageNamed:@"line.3.horizontal.decrease"] identifier:nil options:0 children:modeActions];

        UIMenu *mainMenu = [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[kindMenu, modeMenu]];
        self.filterButton.menu = mainMenu;
    }
}

- (void)pp_loadData
{
    self.loadingMedicines = YES;
    self.loadingVets = YES;
    [self pp_updateEmptyState];

    __weak typeof(self) weakSelf = self;
    [[VetManager sharedManager] fetchAllPetMedicinesWithCompletion:^(NSArray<VetMedicineModel *> *medicinesArray, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.loadingMedicines = NO;
        NSArray<VetMedicineModel *> *medicines = medicinesArray ?: @[];
        self.allMedicines = [medicines sortedArrayUsingComparator:^NSComparisonResult(VetMedicineModel *a, VetMedicineModel *b) {
            return [PPPetCareSafeString(a.title) localizedCaseInsensitiveCompare:PPPetCareSafeString(b.title)];
        }];
        [self pp_applyFiltersAndReload];
    }];

    [[VetManager sharedManager] fetchAllVetsWithCompletion:^(NSArray<VetModel *> *vetsArray, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.loadingVets = NO;
        NSArray *vets = vetsArray ?: @[];
        self.allVets = [vets sortedArrayUsingComparator:^NSComparisonResult(VetModel *a, VetModel *b) {
            return [PPPetCareSafeString(a.title) localizedCaseInsensitiveCompare:PPPetCareSafeString(b.title)];
        }];
        [self pp_applyFiltersAndReload];
    }];
}

- (void)pp_applyFiltersAndReload
{
    NSString *query = PPPetCareNormalizedText(self.searchField.text);
    NSInteger kindID = self.selectedMainKind ? self.selectedMainKind.ID : 0;

    BOOL hasActiveFilter = (kindID > 0);
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        hasActiveFilter = hasActiveFilter || (self.medicineFilter != PPPetCareMedicineFilterAll);
    } else {
        hasActiveFilter = hasActiveFilter || (self.vetFilter != PPPetCareVetFilterAll);
    }
    self.filterBadgeView.hidden = !hasActiveFilter;

    NSMutableArray<VetMedicineModel *> *medicines = [NSMutableArray array];
    for (VetMedicineModel *item in self.allMedicines) {
        if (kindID > 0 && ![self pp_animalTypes:item.animalTypes matchMainKind:self.selectedMainKind]) {
            continue;
        }
        if (![self pp_medicine:item matchesFilter:self.medicineFilter]) {
            continue;
        }
        if (query.length > 0) {
            NSString *haystack = PPPetCareNormalizedText([@[PPPetCareSafeString(item.title),
                                                           PPPetCareSafeString(item.title_lowercase)]
                                                         componentsJoinedByString:@" "]);
            if (![haystack containsString:query]) {
                continue;
            }
        }
        [medicines addObject:item];
    }
    self.filteredMedicines = medicines.copy;

    NSMutableArray<VetModel *> *vets = [NSMutableArray array];
    for (VetModel *vet in self.allVets) {
        if (kindID > 0 && ![self pp_vet:vet matchesMainKind:self.selectedMainKind]) {
            continue;
        }
        if (![self pp_vet:vet matchesFilter:self.vetFilter]) {
            continue;
        }
        if (query.length > 0) {
            NSString *haystack = PPPetCareNormalizedText([@[PPPetCareSafeString(vet.title),
                                                           PPPetCareSafeString(vet.name_lowercase)]
                                                         componentsJoinedByString:@" "]);
            if (![haystack containsString:query]) {
                continue;
            }
        }
        [vets addObject:vet];
    }
    self.filteredVets = vets.copy;

    [self.collectionView reloadData];
    [self pp_updateCounter];
    [self pp_updateEmptyState];
}

- (BOOL)pp_medicine:(VetMedicineModel *)medicine matchesFilter:(PPPetCareMedicineFilter)filter
{
    if (medicine.isPublished == NO || medicine.isDisabled || medicine.isAvailable == NO) {
        return NO;
    }
    switch (filter) {
        case PPPetCareMedicineFilterOffers:
            return medicine.requiresPrescription == NO;
        case PPPetCareMedicineFilterInStock:
            return medicine.stockQuantity > 0;
        case PPPetCareMedicineFilterNew:
            if (!medicine.createdAt) {
                return YES;
            }
            return [medicine.createdAt timeIntervalSinceNow] >= -(14.0 * 24.0 * 60.0 * 60.0);
        case PPPetCareMedicineFilterAll:
        default:
            return YES;
    }
}

- (BOOL)pp_vet:(VetModel *)vet matchesFilter:(PPPetCareVetFilter)filter
{
    if (vet.isDisabled) {
        return NO;
    }
    NSString *verificationStatus = PPPetCareSafeString(vet.verificationStatus).lowercaseString;
    if (verificationStatus.length == 0) {
        verificationStatus = @"pending";
    }
    if (![verificationStatus isEqualToString:@"approved"]) {
        return NO;
    }
    switch (filter) {
        case PPPetCareVetFilterWithPhone:
            return vet.readyToContact || vet.phone.length > 0 || vet.whatsapp.length > 0;
        case PPPetCareVetFilterCompany:
            return vet.type == VetTypeCompany;
        case PPPetCareVetFilterPersonal:
            return vet.type == VetTypePersonal;
        case PPPetCareVetFilterAll:
        default:
            return YES;
    }
}

- (BOOL)pp_animalTypes:(NSArray<NSString *> *)animalTypes matchMainKind:(MainKindsModel *)mainKind
{
    if (!mainKind) {
        return YES;
    }
    if (animalTypes.count == 0) {
        return YES;
    }

    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    if (mainKind.ID > 0) {
        [candidates addObject:[NSString stringWithFormat:@"%ld", (long)mainKind.ID]];
    }
    for (NSString *value in @[PPPetCareSafeString(mainKind.KindName), PPPetCareSafeString(mainKind.KindNameEn), PPPetCareSafeString(mainKind.KindNameAr)]) {
        NSString *normalized = PPPetCareNormalizedText(value);
        if (normalized.length > 0) {
            [candidates addObject:normalized];
        }
    }

    for (NSString *animalType in animalTypes) {
        NSString *normalizedAnimalType = PPPetCareNormalizedText(animalType);
        for (NSString *candidate in candidates) {
            if ([normalizedAnimalType isEqualToString:candidate]) {
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)pp_vet:(VetModel *)vet matchesMainKind:(MainKindsModel *)mainKind
{
    if (!mainKind) {
        return YES;
    }
    if (vet.animalTypes.count > 0) {
        return [self pp_animalTypes:vet.animalTypes matchMainKind:mainKind];
    }
    return vet.petMainKindID == mainKind.ID;
}

#pragma mark - Localization and Theme

- (void)pp_updateLocalizedText
{
    [self pp_installNavigationTitleControl];
    [self.sectionControl setTitle:PPPetCareLocalized(@"pet_care_medicines", @"Medicines") forSegmentAtIndex:0];
    [self.sectionControl setTitle:PPPetCareLocalized(@"pet_care_veterinarians", @"Veterinarians") forSegmentAtIndex:1];
    self.searchField.placeholder = self.selectedSection == PPPetCareInitialSectionMedicines
        ? PPPetCareLocalized(@"pet_care_search_medicines", @"Search medicines")
        : PPPetCareLocalized(@"pet_care_search_vets", @"Search veterinarians");
    self.eyebrowLabel.text = PPPetCareLocalized(@"pet_care_eyebrow", @"Premium care");
    self.titleLabel.text = self.selectedSection == PPPetCareInitialSectionMedicines
        ? PPPetCareLocalized(@"pet_care_medicine_title", @"Pet medicines")
        : PPPetCareLocalized(@"pet_care_vets_title", @"Veterinarians");
    self.subtitleLabel.text = self.selectedSection == PPPetCareInitialSectionMedicines
        ? PPPetCareLocalized(@"pet_care_medicine_subtitle", @"Curated treatment, wellness, and care supplies from the shared store catalog.")
        : PPPetCareLocalized(@"pet_care_vets_subtitle", @"Find veterinarians matched to pet kind, contact readiness, and clinic type.");
    self.sectionControl.selectedSegmentIndex = self.selectedSection == PPPetCareInitialSectionVeterinarians ? 1 : 0;
    self.view.semanticContentAttribute = Language.isRTL ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    self.sectionTitleContainer.semanticContentAttribute = self.view.semanticContentAttribute;
    self.bottomSearchBarView.semanticContentAttribute = self.view.semanticContentAttribute;
    self.searchPillView.semanticContentAttribute = self.view.semanticContentAttribute;
    self.searchField.semanticContentAttribute = self.view.semanticContentAttribute;
    self.searchIconView.semanticContentAttribute = self.view.semanticContentAttribute;
    self.searchField.textAlignment = [Language alignmentForCurrentLanguage];
    self.eyebrowLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];

    self.heroIconView.image = [[UIImage systemImageNamed:self.selectedSection == PPPetCareInitialSectionMedicines ? @"pills.fill" : @"cross.case.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    [self pp_updateFilterMenu];
    [self pp_updateCounter];
    [self pp_updateEmptyState];
}

- (void)pp_applyTheme
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *accent = PPPetCareAccentColor();
    self.view.backgroundColor = AppBackgroundClr ?: UIColor.systemBackgroundColor;
    self.heroView.backgroundColor = PPPetCareSurfaceColor();
    [self.heroView pp_setBorderColor:PPPetCareBorderColor()];
    self.heroView.layer.shadowOpacity = dark ? 0.0 : 0.08;

    self.heroGradientLayer.colors = @[
        (id)[accent colorWithAlphaComponent:dark ? 0.20 : 0.13].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    self.largeOrbView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.12 : 0.08];
    self.smallOrbView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.18 : 0.12];

    self.iconPlateView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.18 : 0.11];
    [self.iconPlateView pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.24 : 0.16]];
    self.heroIconView.tintColor = accent;

    self.eyebrowLabel.textColor = [accent colorWithAlphaComponent:dark ? 0.92 : 0.82];
    self.titleLabel.textColor = PPPetCareTextColor();
    self.subtitleLabel.textColor = PPPetCareSecondaryTextColor();
    self.counterLabel.textColor = PPPetCareTextColor();
    self.counterLabel.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.15 : 0.09];
    [self.counterLabel pp_setBorderColor:PPPetCareBorderColor()];

    self.bottomSearchBarView.layer.shadowOpacity = dark ? 0.22 : 0.14;
    self.searchPillView.backgroundColor = PPPetCareSearchSurfaceColor();
    [self.searchPillView pp_setBorderColor:PPPetCareSearchBorderColor()];
    self.searchField.textColor = PPPetCareTextColor();
    self.searchField.backgroundColor = UIColor.clearColor;
    self.searchField.tintColor = PPPetCareAccentColor();
    self.searchIconView.tintColor = PPPetCareTextColor();

    self.filterButton.tintColor = PPPetCareTextColor();
    self.filterButton.backgroundColor = PPPetCareSearchSurfaceColor();
    [self.filterButton pp_setBorderColor:PPPetCareSearchBorderColor()];

    self.filterBadgeView.layer.borderColor = self.filterButton.backgroundColor.CGColor;

    [self pp_styleNavigationSectionControl];
}

- (void)pp_updateCounter
{
    NSInteger count = self.selectedSection == PPPetCareInitialSectionMedicines
        ? self.filteredMedicines.count
        : self.filteredVets.count;
    NSString *format = self.selectedSection == PPPetCareInitialSectionMedicines
        ? PPPetCareLocalized(@"pet_care_medicine_count_format", @"%ld medicines")
        : PPPetCareLocalized(@"pet_care_vet_count_format", @"%ld vets");
    self.counterLabel.text = [NSString stringWithFormat:format, (long)count];
}

- (void)pp_updateEmptyState
{
    BOOL isLoading = self.selectedSection == PPPetCareInitialSectionMedicines ? self.loadingMedicines : self.loadingVets;
    NSInteger count = self.selectedSection == PPPetCareInitialSectionMedicines ? self.filteredMedicines.count : self.filteredVets.count;
    self.emptyView.hidden = isLoading || count > 0;
    if (isLoading) {
        return;
    }
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        self.emptyTitleLabel.text = PPPetCareLocalized(@"pet_care_empty_medicines_title", @"No medicines found");
        self.emptySubtitleLabel.text = PPPetCareLocalized(@"pet_care_empty_medicines_subtitle", @"Try another pet kind, remove filters, or search with a shorter word.");
    } else {
        self.emptyTitleLabel.text = PPPetCareLocalized(@"pet_care_empty_vets_title", @"No veterinarians found");
        self.emptySubtitleLabel.text = PPPetCareLocalized(@"pet_care_empty_vets_subtitle", @"Try all pet kinds, contact-ready filters, or a different search term.");
    }
}

#pragma mark - Actions

- (void)pp_sectionChanged:(UISegmentedControl *)sender
{
    self.selectedSection = sender.selectedSegmentIndex == 1
        ? PPPetCareInitialSectionVeterinarians
        : PPPetCareInitialSectionMedicines;
    [self pp_updateLocalizedText];
    [self pp_applyFiltersAndReload];
}

- (void)pp_kindChipTapped:(UIButton *)sender
{
    if (sender.tag == 0) {
        self.selectedMainKind = nil;
    } else {
        NSInteger index = sender.tag - 1;
        self.selectedMainKind = (index >= 0 && index < self.mainKinds.count) ? self.mainKinds[index] : nil;
    }
    [self pp_applyFiltersAndReload];
    [self pp_updateFilterMenu];
}

- (void)pp_filterChipTapped:(UIButton *)sender
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        self.medicineFilter = (PPPetCareMedicineFilter)sender.tag;
    } else {
        self.vetFilter = (PPPetCareVetFilter)sender.tag;
    }
    [self pp_applyFiltersAndReload];
    [self pp_updateFilterMenu];
}

- (void)pp_searchTextChanged:(UITextField *)textField
{
    [self pp_applyFiltersAndReload];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Collection

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        return self.filteredMedicines.count;
    }
    return self.filteredVets.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                          cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        PPPetCareMedicineCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPPetCareMedicineCellID
                                                                                forIndexPath:indexPath];
        if (indexPath.item < self.filteredMedicines.count) {
            VetMedicineModel *medicine = self.filteredMedicines[indexPath.item];
            NSString *mainKindName = self.selectedMainKind ? [self pp_mainKindNameForID:self.selectedMainKind.ID] : PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
            [cell configureWithMedicine:medicine mainKindName:mainKindName];
            __weak typeof(self) weakSelf = self;
            cell.onDetailsTap = ^{
                __strong typeof(weakSelf) self = weakSelf;
                [self pp_openObject:medicine];
            };
        }
        return cell;
    }

    PPPetCareVetCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPPetCareVetCell.reuseIdentifier
                                                                       forIndexPath:indexPath];
    if (indexPath.item < self.filteredVets.count) {
        VetModel *vet = self.filteredVets[indexPath.item];
        [cell configureWithVet:vet mainKindName:[self pp_mainKindNameForID:vet.petMainKindID]];
        __weak typeof(self) weakSelf = self;
        cell.onDetailsTap = ^{
            __strong typeof(weakSelf) self = weakSelf;
            [self pp_openObject:vet];
        };
        cell.onCallTap = ^{
            __strong typeof(weakSelf) self = weakSelf;
            [self pp_callVet:vet];
        };
    }
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat width = CGRectGetWidth(collectionView.bounds);
    UIEdgeInsets inset = ((UICollectionViewFlowLayout *)collectionViewLayout).sectionInset;
    CGFloat available = width - inset.left - inset.right;
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        BOOL twoColumns = available >= 330.0;
        CGFloat itemWidth = twoColumns ? floor((available - 12.0) / 2.0) : available;
        return CGSizeMake(itemWidth, MAX(294.0, itemWidth * 1.42));
    }
    return CGSizeMake(available, 206.0);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        if (indexPath.item < self.filteredMedicines.count) {
            [self pp_openObject:self.filteredMedicines[indexPath.item]];
        }
    } else {
        if (indexPath.item < self.filteredVets.count) {
            [self pp_openObject:self.filteredVets[indexPath.item]];
        }
    }
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [UIView animateWithDuration:0.12 animations:^{
        cell.transform = CGAffineTransformMakeScale(0.985, 0.985);
        cell.alpha = 0.92;
    }];
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [UIView animateWithDuration:0.20
                          delay:0.0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        cell.transform = CGAffineTransformIdentity;
        cell.alpha = 1.0;
    } completion:nil];
}

#pragma mark - Universal Cell

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel
{
    [self pp_openObject:universalModel.ModelObject];
}

#pragma mark - Routing

- (void)pp_openObject:(id)object
{
    if (!object) {
        return;
    }
    if ([object isKindOfClass:VetMedicineModel.class]) {
        [self pp_presentMedicineDetails:(VetMedicineModel *)object];
        return;
    }
    [PPOverlayCoordinator pp_openDetailForObject:object
                                         fromVC:self
                                     routingNav:(PPNavigationController *)self.navigationController];
}

- (void)pp_presentMedicineDetails:(VetMedicineModel *)medicine
{
    NSString *title = medicine.title.length > 0 ? medicine.title : PPPetCareLocalized(@"pet_care_medicine_untitled", @"Medicine");
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    if (medicine.medicineDescription.length > 0) {
        [lines addObject:medicine.medicineDescription];
    }
    [lines addObject:[NSString stringWithFormat:@"%@: %.2f %@", PPPetCareLocalized(@"pet_care_medicine_price", @"Price"), medicine.price, medicine.currency.length > 0 ? medicine.currency : @"QAR"]];
    [lines addObject:[NSString stringWithFormat:@"%@: %ld", PPPetCareLocalized(@"pet_care_medicine_stock", @"Stock"), (long)medicine.stockQuantity]];
    [lines addObject:medicine.requiresPrescription
        ? PPPetCareLocalized(@"pet_care_medicine_prescription_required", @"Prescription required")
        : PPPetCareLocalized(@"pet_care_medicine_ready", @"Ready to order")];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:[lines componentsJoinedByString:@"\n\n"]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:PPPetCareLocalized(@"OK_Title", @"OK")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1.0, 1.0);
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)pp_callVet:(VetModel *)vet
{
    NSString *rawPhone = vet.phone.length > 0 ? vet.phone : vet.whatsapp;
    if (rawPhone.length == 0) {
        return;
    }

    NSMutableString *clean = [NSMutableString string];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"+0123456789"];
    for (NSUInteger idx = 0; idx < rawPhone.length; idx++) {
        unichar ch = [rawPhone characterAtIndex:idx];
        if ([allowed characterIsMember:ch]) {
            [clean appendFormat:@"%C", ch];
        }
    }
    if (clean.length == 0) {
        return;
    }

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"telprompt:%@", clean]];
    if (!url) {
        return;
    }
    UIApplication *application = UIApplication.sharedApplication;
    if ([application canOpenURL:url]) {
        [application openURL:url options:@{} completionHandler:nil];
    }
}

- (NSString *)pp_mainKindNameForID:(NSInteger)kindID
{
    if (kindID <= 0) {
        return PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
    }
    for (MainKindsModel *kind in self.mainKinds) {
        if (kind.ID == kindID) {
            return kind.KindName.length > 0 ? kind.KindName : kind.KindNameEn ?: kind.KindNameAr ?: @"";
        }
    }
    return PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
}

@end
