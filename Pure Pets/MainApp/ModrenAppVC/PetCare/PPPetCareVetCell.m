//
//  PPPetCareVetCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/26/26.
//

#import "PPPetCareVetCell.h"
#import "PPImageLoaderManager.h"
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
