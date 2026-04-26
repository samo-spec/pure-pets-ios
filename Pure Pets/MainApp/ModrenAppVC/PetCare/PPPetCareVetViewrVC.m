//
//  PPPetCareVetViewrVC.m
//  Pure Pets
//
//  Created by Codex on 4/26/26.
//

#import "PPPetCareVetViewrVC.h"
#import "VetModel.h"
#import "PPImageLoaderManager.h"

static CGFloat const PPPetCareVetViewerSideInset = 18.0;
static CGFloat const PPPetCareVetViewerSectionSpacing = 14.0;
static CGFloat const PPPetCareVetViewerSurfaceRadius = 28.0;

static NSString *PPPetCareVetViewerLocalized(NSString *key, NSString *fallback)
{
    NSString *value = key.length > 0 ? kLang(key) : nil;
    if (value.length == 0 || [value isEqualToString:key]) {
        return fallback ?: @"";
    }
    return value;
}

static NSString *PPPetCareVetViewerSafeString(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [[[value stringValue] ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] copy];
    }
    return @"";
}

static UIColor *PPPetCareVetViewerAccentColor(void)
{
    return AppPrimaryClr ?: UIColor.systemTealColor;
}

static UIColor *PPPetCareVetViewerTextColor(void)
{
    return AppPrimaryTextClr ?: UIColor.labelColor;
}

static UIColor *PPPetCareVetViewerSecondaryTextColor(void)
{
    return AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
}

static UIColor *PPPetCareVetViewerSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark ? [UIColor colorWithWhite:0.12 alpha:0.86] : [UIColor colorWithWhite:1.0 alpha:0.92];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.92];
}

static UIColor *PPPetCareVetViewerBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark ? [UIColor colorWithWhite:1.0 alpha:0.10] : [UIColor colorWithWhite:0.0 alpha:0.08];
        }];
    }
    return [UIColor colorWithWhite:0.0 alpha:0.08];
}

@interface PPPetCareVetViewrVC ()
@property (nonatomic, strong) VetModel *vet;
@property (nonatomic, copy) NSString *mainKindName;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *heroView;
@property (nonatomic, strong) UIView *heroFillView;
@property (nonatomic, strong) UIView *logoPlateView;
@property (nonatomic, strong) UIImageView *logoImageView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *profileSectionView;
@property (nonatomic, strong) UILabel *profileTitleLabel;
@property (nonatomic, strong) UIStackView *factsStackView;
@property (nonatomic, strong) UIView *aboutSectionView;
@property (nonatomic, strong) UILabel *aboutTitleLabel;
@property (nonatomic, strong) UILabel *aboutBodyLabel;
@property (nonatomic, strong) UIView *actionsSectionView;
@property (nonatomic, strong) UIStackView *actionsStackView;
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UIButton *whatsappButton;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@end

@implementation PPPetCareVetViewrVC

- (instancetype)initWithVet:(VetModel *)vet
               mainKindName:(NSString *)mainKindName
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) {
        return nil;
    }
    _vet = vet;
    _mainKindName = PPPetCareVetViewerSafeString(mainKindName);
    self.hidesBottomBarWhenPushed = YES;
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.view.backgroundColor = AppBackgroundClr ?: UIColor.systemGroupedBackgroundColor;
    [self pp_setupLayout];
    [self pp_applyContent];
    [self pp_applyTheme];
    [self pp_prepareEntranceState];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto
                      button:nil
                       title:nil
                    showBack:YES];
    self.navigationItem.title = PPPetCareVetViewerLocalized(@"pet_care_veterinarians", @"Veterinarians");
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_beginEntranceAnimationIfNeeded];
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

- (void)dealloc
{
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.logoImageView];
}

#pragma mark - Layout

- (void)pp_setupLayout
{
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.backgroundColor = UIColor.clearColor;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    if (@available(iOS 11.0, *)) {
        self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.contentView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    if (@available(iOS 11.0, *)) {
        [NSLayoutConstraint activateConstraints:@[
            [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
            [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
            [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
            [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
            [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor]
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
            [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
            [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
            [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
            [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor]
        ]];
    }

    [self pp_buildHeroSection];
    [self pp_buildProfileSection];
    [self pp_buildAboutSection];
    [self pp_buildActionsSection];
}

- (void)pp_buildHeroSection
{
    self.heroView = [[UIView alloc] init];
    self.heroView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroView.layer.cornerRadius = 34.0;
    self.heroView.layer.borderWidth = 0.8;
    self.heroView.clipsToBounds = NO;
    [self.heroView pp_setShadowColor:UIColor.blackColor];
    self.heroView.layer.shadowOpacity = 0.10;
    self.heroView.layer.shadowRadius = 24.0;
    self.heroView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    if (@available(iOS 13.0, *)) {
        self.heroView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.heroFillView = [[UIView alloc] init];
    self.heroFillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroFillView.layer.cornerRadius = 34.0;
    self.heroFillView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.heroFillView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.logoPlateView = [[UIView alloc] init];
    self.logoPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoPlateView.layer.cornerRadius = 42.0;
    self.logoPlateView.layer.borderWidth = 0.8;
    self.logoPlateView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.logoPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.logoImageView = [[UIImageView alloc] init];
    self.logoImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.logoImageView.clipsToBounds = YES;
    self.logoImageView.tintColor = PPPetCareVetViewerAccentColor();

    self.eyebrowLabel = [self pp_labelWithFont:[GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold]
                                         color:PPPetCareVetViewerSecondaryTextColor()
                                         lines:1];
    self.eyebrowLabel.text = PPPetCareVetViewerLocalized(@"pet_care_eyebrow", @"Premium care");

    self.titleLabel = [self pp_labelWithFont:[GM boldFontWithSize:28.0] ?: [UIFont systemFontOfSize:28.0 weight:UIFontWeightBold]
                                       color:PPPetCareVetViewerTextColor()
                                       lines:2];
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.78;

    self.subtitleLabel = [self pp_labelWithFont:[GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium]
                                          color:PPPetCareVetViewerSecondaryTextColor()
                                          lines:2];

    self.statusLabel = [self pp_labelWithFont:[GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold]
                                        color:UIColor.whiteColor
                                        lines:1];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.layer.cornerRadius = 14.0;
    self.statusLabel.layer.masksToBounds = YES;

    [self.contentView addSubview:self.heroView];
    [self.heroView addSubview:self.heroFillView];
    [self.heroFillView addSubview:self.logoPlateView];
    [self.logoPlateView addSubview:self.logoImageView];
    [self.heroFillView addSubview:self.eyebrowLabel];
    [self.heroFillView addSubview:self.titleLabel];
    [self.heroFillView addSubview:self.subtitleLabel];
    [self.heroFillView addSubview:self.statusLabel];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.heroView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12.0],
        [self.heroView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareVetViewerSideInset],
        [self.heroView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareVetViewerSideInset],
        [self.heroView.heightAnchor constraintGreaterThanOrEqualToConstant:286.0],
        [self.heroView.topAnchor constraintGreaterThanOrEqualToAnchor:safe.topAnchor constant:4.0],

        [self.heroFillView.topAnchor constraintEqualToAnchor:self.heroView.topAnchor],
        [self.heroFillView.leadingAnchor constraintEqualToAnchor:self.heroView.leadingAnchor],
        [self.heroFillView.trailingAnchor constraintEqualToAnchor:self.heroView.trailingAnchor],
        [self.heroFillView.bottomAnchor constraintEqualToAnchor:self.heroView.bottomAnchor],

        [self.logoPlateView.topAnchor constraintEqualToAnchor:self.heroFillView.topAnchor constant:22.0],
        [self.logoPlateView.leadingAnchor constraintEqualToAnchor:self.heroFillView.leadingAnchor constant:22.0],
        [self.logoPlateView.widthAnchor constraintEqualToConstant:84.0],
        [self.logoPlateView.heightAnchor constraintEqualToConstant:84.0],

        [self.logoImageView.topAnchor constraintEqualToAnchor:self.logoPlateView.topAnchor],
        [self.logoImageView.leadingAnchor constraintEqualToAnchor:self.logoPlateView.leadingAnchor],
        [self.logoImageView.trailingAnchor constraintEqualToAnchor:self.logoPlateView.trailingAnchor],
        [self.logoImageView.bottomAnchor constraintEqualToAnchor:self.logoPlateView.bottomAnchor],

        [self.eyebrowLabel.leadingAnchor constraintEqualToAnchor:self.logoPlateView.trailingAnchor constant:18.0],
        [self.eyebrowLabel.trailingAnchor constraintEqualToAnchor:self.heroFillView.trailingAnchor constant:-22.0],
        [self.eyebrowLabel.topAnchor constraintEqualToAnchor:self.heroFillView.topAnchor constant:28.0],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.eyebrowLabel.leadingAnchor],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.eyebrowLabel.trailingAnchor],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.eyebrowLabel.bottomAnchor constant:8.0],

        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8.0],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.heroFillView.leadingAnchor constant:22.0],
        [self.statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroFillView.trailingAnchor constant:-22.0],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.heroFillView.bottomAnchor constant:-22.0],
        [self.statusLabel.heightAnchor constraintEqualToConstant:28.0],
        [self.statusLabel.widthAnchor constraintGreaterThanOrEqualToConstant:112.0]
    ]];
}

- (void)pp_buildProfileSection
{
    self.profileSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.profileSectionView];

    self.profileTitleLabel = [self pp_sectionTitleLabelWithText:PPPetCareVetViewerLocalized(@"pet_care_vet_viewer_profile", @"Profile")];
    [self.profileSectionView addSubview:self.profileTitleLabel];

    self.factsStackView = [[UIStackView alloc] init];
    self.factsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.factsStackView.axis = UILayoutConstraintAxisVertical;
    self.factsStackView.spacing = 10.0;
    [self.profileSectionView addSubview:self.factsStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.profileSectionView.topAnchor constraintEqualToAnchor:self.heroView.bottomAnchor constant:PPPetCareVetViewerSectionSpacing],
        [self.profileSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareVetViewerSideInset],
        [self.profileSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareVetViewerSideInset],

        [self.profileTitleLabel.topAnchor constraintEqualToAnchor:self.profileSectionView.topAnchor constant:20.0],
        [self.profileTitleLabel.leadingAnchor constraintEqualToAnchor:self.profileSectionView.leadingAnchor constant:20.0],
        [self.profileTitleLabel.trailingAnchor constraintEqualToAnchor:self.profileSectionView.trailingAnchor constant:-20.0],

        [self.factsStackView.topAnchor constraintEqualToAnchor:self.profileTitleLabel.bottomAnchor constant:14.0],
        [self.factsStackView.leadingAnchor constraintEqualToAnchor:self.profileSectionView.leadingAnchor constant:16.0],
        [self.factsStackView.trailingAnchor constraintEqualToAnchor:self.profileSectionView.trailingAnchor constant:-16.0],
        [self.factsStackView.bottomAnchor constraintEqualToAnchor:self.profileSectionView.bottomAnchor constant:-16.0]
    ]];
}

- (void)pp_buildAboutSection
{
    self.aboutSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.aboutSectionView];

    self.aboutTitleLabel = [self pp_sectionTitleLabelWithText:PPPetCareVetViewerLocalized(@"pet_care_vet_viewer_about", @"About")];
    [self.aboutSectionView addSubview:self.aboutTitleLabel];

    self.aboutBodyLabel = [self pp_labelWithFont:[GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular]
                                           color:PPPetCareVetViewerTextColor()
                                           lines:0];
    [self.aboutSectionView addSubview:self.aboutBodyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.aboutSectionView.topAnchor constraintEqualToAnchor:self.profileSectionView.bottomAnchor constant:PPPetCareVetViewerSectionSpacing],
        [self.aboutSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareVetViewerSideInset],
        [self.aboutSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareVetViewerSideInset],

        [self.aboutTitleLabel.topAnchor constraintEqualToAnchor:self.aboutSectionView.topAnchor constant:20.0],
        [self.aboutTitleLabel.leadingAnchor constraintEqualToAnchor:self.aboutSectionView.leadingAnchor constant:20.0],
        [self.aboutTitleLabel.trailingAnchor constraintEqualToAnchor:self.aboutSectionView.trailingAnchor constant:-20.0],

        [self.aboutBodyLabel.topAnchor constraintEqualToAnchor:self.aboutTitleLabel.bottomAnchor constant:10.0],
        [self.aboutBodyLabel.leadingAnchor constraintEqualToAnchor:self.aboutSectionView.leadingAnchor constant:20.0],
        [self.aboutBodyLabel.trailingAnchor constraintEqualToAnchor:self.aboutSectionView.trailingAnchor constant:-20.0],
        [self.aboutBodyLabel.bottomAnchor constraintEqualToAnchor:self.aboutSectionView.bottomAnchor constant:-20.0]
    ]];
}

- (void)pp_buildActionsSection
{
    self.actionsSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.actionsSectionView];

    self.actionsStackView = [[UIStackView alloc] init];
    self.actionsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionsStackView.axis = UILayoutConstraintAxisVertical;
    self.actionsStackView.alignment = UIStackViewAlignmentFill;
    self.actionsStackView.distribution = UIStackViewDistributionFillEqually;
    self.actionsStackView.spacing = 12.0;
    [self.actionsSectionView addSubview:self.actionsStackView];

    self.callButton = [self pp_actionButtonWithTitle:PPPetCareVetViewerLocalized(@"pet_care_call", @"Call")
                                              symbol:@"phone.fill"
                                             primary:YES
                                            selector:@selector(pp_callTapped)];
    self.whatsappButton = [self pp_actionButtonWithTitle:PPPetCareVetViewerLocalized(@"pet_care_vet_viewer_whatsapp", @"WhatsApp")
                                                  symbol:@"message.fill"
                                                 primary:NO
                                                selector:@selector(pp_whatsappTapped)];
    UIButton *shareButton = [self pp_actionButtonWithTitle:PPPetCareVetViewerLocalized(@"pet_care_viewer_share", @"Share")
                                                     symbol:@"square.and.arrow.up"
                                                    primary:NO
                                                   selector:@selector(pp_shareTapped)];

    [self.actionsStackView addArrangedSubview:self.callButton];
    [self.actionsStackView addArrangedSubview:self.whatsappButton];
    [self.actionsStackView addArrangedSubview:shareButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.actionsSectionView.topAnchor constraintEqualToAnchor:self.aboutSectionView.bottomAnchor constant:PPPetCareVetViewerSectionSpacing],
        [self.actionsSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareVetViewerSideInset],
        [self.actionsSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareVetViewerSideInset],
        [self.actionsSectionView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-28.0],

        [self.actionsStackView.topAnchor constraintEqualToAnchor:self.actionsSectionView.topAnchor constant:16.0],
        [self.actionsStackView.leadingAnchor constraintEqualToAnchor:self.actionsSectionView.leadingAnchor constant:16.0],
        [self.actionsStackView.trailingAnchor constraintEqualToAnchor:self.actionsSectionView.trailingAnchor constant:-16.0],
        [self.actionsStackView.bottomAnchor constraintEqualToAnchor:self.actionsSectionView.bottomAnchor constant:-16.0],
        [self.actionsStackView.heightAnchor constraintEqualToConstant:180.0]
    ]];
}

#pragma mark - Content

- (void)pp_applyContent
{
    self.titleLabel.text = self.vet.title.length > 0 ? self.vet.title : PPPetCareVetViewerLocalized(@"pet_care_vet_untitled", @"Veterinarian");
    self.subtitleLabel.text = self.vet.type == VetTypeCompany
        ? PPPetCareVetViewerLocalized(@"pet_care_vet_company", @"Clinic")
        : PPPetCareVetViewerLocalized(@"pet_care_vet_personal", @"Doctor");
    self.statusLabel.text = [self pp_contactStatusText];
    self.aboutBodyLabel.text = self.vet.descriptionText.length > 0
        ? self.vet.descriptionText
        : PPPetCareVetViewerLocalized(@"pet_care_vet_default_subtitle", @"Care provider ready for pet health support.");
    self.aboutBodyLabel.textAlignment = Language.alignmentForCurrentLanguage;

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:38.0 weight:UIImageSymbolWeightSemibold];
    NSString *symbol = self.vet.type == VetTypeCompany ? @"building.2.fill" : @"stethoscope";
    UIImage *placeholder = [[UIImage systemImageNamed:symbol withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.logoImageView.image = placeholder;
    if (self.vet.logoURL.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:self.logoImageView
                                                       url:self.vet.logoURL
                                               placeholder:placeholder
                                          transitionStyle:PPImageTransitionStyleFade
                                                complation:nil];
    }

    BOOL canCall = self.vet.phone.length > 0 || self.vet.whatsapp.length > 0;
    self.callButton.enabled = canCall;
    self.callButton.alpha = canCall ? 1.0 : 0.52;
    self.whatsappButton.enabled = self.vet.whatsapp.length > 0 || self.vet.phone.length > 0;
    self.whatsappButton.alpha = self.whatsappButton.enabled ? 1.0 : 0.52;

    [self pp_reloadFacts];
    self.view.accessibilityLabel = self.titleLabel.text;
}

- (void)pp_reloadFacts
{
    for (UIView *view in self.factsStackView.arrangedSubviews) {
        [self.factsStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    UIColor *accent = PPPetCareVetViewerAccentColor();
    UIColor *green = [UIColor colorWithRed:0.20 green:0.62 blue:0.43 alpha:1.0];
    UIColor *blue = [UIColor colorWithRed:0.32 green:0.53 blue:0.88 alpha:1.0];
    UIColor *purple = [UIColor colorWithRed:0.56 green:0.40 blue:0.80 alpha:1.0];

    [self.factsStackView addArrangedSubview:[self pp_factRowWithIcon:@"cross.case.fill"
                                                               title:PPPetCareVetViewerLocalized(@"pet_care_vet_viewer_type", @"Type")
                                                               value:self.subtitleLabel.text ?: @""
                                                              accent:accent]];
    [self.factsStackView addArrangedSubview:[self pp_factRowWithIcon:@"pawprint.fill"
                                                               title:PPPetCareVetViewerLocalized(@"pet_care_viewer_pet_kind", @"Pet kind")
                                                               value:[self pp_petKindText]
                                                              accent:green]];
    [self.factsStackView addArrangedSubview:[self pp_factRowWithIcon:@"phone.fill"
                                                               title:PPPetCareVetViewerLocalized(@"pet_care_vet_viewer_contact", @"Contact")
                                                               value:[self pp_contactStatusText]
                                                              accent:(self.vet.phone.length > 0 || self.vet.whatsapp.length > 0) ? blue : UIColor.systemOrangeColor]];
    [self.factsStackView addArrangedSubview:[self pp_factRowWithIcon:@"calendar"
                                                               title:PPPetCareVetViewerLocalized(@"pet_care_vet_viewer_available_date", @"Available")
                                                               value:[self pp_dateText:self.vet.availableDate]
                                                              accent:purple]];
    [self.factsStackView addArrangedSubview:[self pp_factRowWithIcon:@"checkmark.seal.fill"
                                                               title:PPPetCareVetViewerLocalized(@"pet_care_vet_viewer_verification", @"Verification")
                                                               value:[self pp_verificationText]
                                                              accent:green]];
    [self.factsStackView addArrangedSubview:[self pp_factRowWithIcon:@"star.circle.fill"
                                                               title:PPPetCareVetViewerLocalized(@"pet_care_vet_viewer_membership", @"Membership")
                                                               value:[self pp_subscriptionText]
                                                              accent:accent]];
}

- (NSString *)pp_petKindText
{
    if (self.vet.animalTypes.count > 0) {
        return [self.vet.animalTypes componentsJoinedByString:@", "];
    }
    return self.mainKindName.length > 0 ? self.mainKindName : PPPetCareVetViewerLocalized(@"pet_care_all_pets", @"All pets");
}

- (NSString *)pp_contactStatusText
{
    if (self.vet.phone.length > 0 || self.vet.whatsapp.length > 0 || self.vet.readyToContact) {
        return PPPetCareVetViewerLocalized(@"pet_care_vet_contact_ready", @"Contact ready");
    }
    return PPPetCareVetViewerLocalized(@"pet_care_vet_viewer_contact_unavailable", @"Contact unavailable");
}

- (NSString *)pp_verificationText
{
    NSString *status = PPPetCareVetViewerSafeString(self.vet.verificationStatus).lowercaseString;
    if (status.length == 0 || [status isEqualToString:@"approved"] || [status isEqualToString:@"active"] || [status isEqualToString:@"verified"]) {
        return PPPetCareVetViewerLocalized(@"pet_care_vet_viewer_verified", @"Verified");
    }
    return self.vet.verificationStatus.length > 0 ? self.vet.verificationStatus : PPPetCareVetViewerLocalized(@"pet_care_viewer_not_specified", @"Not specified");
}

- (NSString *)pp_subscriptionText
{
    if (!self.vet.subscriptionActive) {
        return PPPetCareVetViewerLocalized(@"pet_care_vet_viewer_subscription_inactive", @"Standard profile");
    }
    if (self.vet.subscriptionTier > 0) {
        NSString *format = PPPetCareVetViewerLocalized(@"pet_care_vet_viewer_subscription_tier_format", @"Tier %ld active");
        return [NSString stringWithFormat:format, (long)self.vet.subscriptionTier];
    }
    return PPPetCareVetViewerLocalized(@"pet_care_vet_viewer_subscription_active", @"Active membership");
}

- (NSString *)pp_dateText:(NSDate *)date
{
    if (!date) {
        return PPPetCareVetViewerLocalized(@"pet_care_viewer_not_specified", @"Not specified");
    }
    NSString *formatted = [GM formattedDate:date];
    return formatted.length > 0 ? formatted : PPPetCareVetViewerLocalized(@"pet_care_viewer_not_specified", @"Not specified");
}

#pragma mark - Theme

- (void)pp_applyTheme
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    UIColor *accent = PPPetCareVetViewerAccentColor();
    [self.heroView pp_setBorderColor:PPPetCareVetViewerBorderColor()];
    self.heroView.layer.shadowOpacity = dark ? 0.14 : 0.09;
    self.heroFillView.backgroundColor = PPPetCareVetViewerSurfaceColor();

    self.logoPlateView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.14 : 0.09];
    [self.logoPlateView pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.24 : 0.16]];
    self.logoImageView.tintColor = accent;
    self.logoImageView.backgroundColor = [accent colorWithAlphaComponent:0.06];
    UIColor *statusColor = (self.vet.phone.length > 0 || self.vet.whatsapp.length > 0)
        ? accent
        : UIColor.systemOrangeColor;
    self.statusLabel.backgroundColor = [statusColor colorWithAlphaComponent:0.88];

    [self pp_applySectionTheme:self.profileSectionView];
    [self pp_applySectionTheme:self.aboutSectionView];
    [self pp_applySectionTheme:self.actionsSectionView];
    self.profileTitleLabel.textColor = PPPetCareVetViewerTextColor();
    self.aboutTitleLabel.textColor = PPPetCareVetViewerTextColor();
    self.aboutBodyLabel.textColor = PPPetCareVetViewerTextColor();
}

- (void)pp_applySectionTheme:(UIView *)section
{
    section.backgroundColor = PPPetCareVetViewerSurfaceColor();
    [section pp_setBorderColor:PPPetCareVetViewerBorderColor()];
}

#pragma mark - Actions

- (void)pp_callTapped
{
    NSString *raw = self.vet.phone.length > 0 ? self.vet.phone : self.vet.whatsapp;
    NSURL *url = [self pp_telURLForRawNumber:raw];
    if (!url || ![UIApplication.sharedApplication canOpenURL:url]) {
        return;
    }
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

- (void)pp_whatsappTapped
{
    NSString *raw = self.vet.whatsapp.length > 0 ? self.vet.whatsapp : self.vet.phone;
    NSString *clean = [self pp_digitsAndPlusFromString:raw];
    if (clean.length == 0) {
        return;
    }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://wa.me/%@", clean]];
    if (!url) {
        return;
    }
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

- (void)pp_shareTapped
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [parts addObject:self.titleLabel.text ?: @""];
    [parts addObject:self.subtitleLabel.text ?: @""];
    if (self.vet.descriptionText.length > 0) {
        [parts addObject:self.vet.descriptionText];
    }
    if (self.vet.phone.length > 0) {
        [parts addObject:[NSString stringWithFormat:@"%@: %@", PPPetCareVetViewerLocalized(@"pet_care_call", @"Call"), self.vet.phone]];
    }

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[[parts componentsJoinedByString:@"\n"]]
                                                                             applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.actionsSectionView;
        activityVC.popoverPresentationController.sourceRect = self.actionsSectionView.bounds;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (NSURL *)pp_telURLForRawNumber:(NSString *)rawNumber
{
    NSString *clean = [self pp_digitsAndPlusFromString:rawNumber];
    if (clean.length == 0) {
        return nil;
    }
    return [NSURL URLWithString:[NSString stringWithFormat:@"telprompt:%@", clean]];
}

- (NSString *)pp_digitsAndPlusFromString:(NSString *)rawNumber
{
    NSString *raw = PPPetCareVetViewerSafeString(rawNumber);
    NSMutableString *clean = [NSMutableString string];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"+0123456789"];
    for (NSUInteger idx = 0; idx < raw.length; idx++) {
        unichar ch = [raw characterAtIndex:idx];
        if ([allowed characterIsMember:ch]) {
            [clean appendFormat:@"%C", ch];
        }
    }
    return clean.copy;
}

#pragma mark - Components

- (UIView *)pp_surfaceSectionView
{
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.layer.cornerRadius = PPPetCareVetViewerSurfaceRadius;
    view.layer.borderWidth = 0.8;
    view.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return view;
}

- (UILabel *)pp_labelWithFont:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines
{
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (UILabel *)pp_sectionTitleLabelWithText:(NSString *)text
{
    UILabel *label = [self pp_labelWithFont:[GM boldFontWithSize:18.0] ?: [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold]
                                      color:PPPetCareVetViewerTextColor()
                                      lines:1];
    label.text = text;
    return label;
}

- (UIView *)pp_factRowWithIcon:(NSString *)symbol title:(NSString *)title value:(NSString *)value accent:(UIColor *)accent
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [accent colorWithAlphaComponent:0.075];
    container.layer.cornerRadius = 20.0;
    container.layer.borderWidth = 0.8;
    [container pp_setBorderColor:[accent colorWithAlphaComponent:0.16]];
    if (@available(iOS 13.0, *)) {
        container.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:symbol] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = accent;
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *titleLabel = [self pp_labelWithFont:[GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium]
                                           color:PPPetCareVetViewerSecondaryTextColor()
                                           lines:1];
    titleLabel.text = title;

    UILabel *valueLabel = [self pp_labelWithFont:[GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold]
                                           color:PPPetCareVetViewerTextColor()
                                           lines:2];
    valueLabel.text = value.length > 0 ? value : PPPetCareVetViewerLocalized(@"pet_care_viewer_not_specified", @"Not specified");

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, valueLabel]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 3.0;

    [container addSubview:iconView];
    [container addSubview:textStack];

    [NSLayoutConstraint activateConstraints:@[
        [container.heightAnchor constraintGreaterThanOrEqualToConstant:68.0],
        [iconView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16.0],
        [iconView.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:22.0],
        [iconView.heightAnchor constraintEqualToConstant:22.0],

        [textStack.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:14.0],
        [textStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16.0],
        [textStack.topAnchor constraintGreaterThanOrEqualToAnchor:container.topAnchor constant:12.0],
        [textStack.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor constant:-12.0],
        [textStack.centerYAnchor constraintEqualToAnchor:container.centerYAnchor]
    ]];
    return container;
}

- (UIButton *)pp_actionButtonWithTitle:(NSString *)title
                                symbol:(NSString *)symbol
                               primary:(BOOL)primary
                              selector:(SEL)selector
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = 22.0;
    button.layer.borderWidth = primary ? 0.0 : 0.8;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    button.titleLabel.font = [GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    button.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 14.0, 0.0, 14.0);
    [button setTitle:title forState:UIControlStateNormal];
    [button setImage:[[UIImage systemImageNamed:symbol] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    button.tintColor = primary ? UIColor.whiteColor : PPPetCareVetViewerAccentColor();
    [button setTitleColor:(primary ? UIColor.whiteColor : PPPetCareVetViewerTextColor()) forState:UIControlStateNormal];
    button.backgroundColor = primary ? PPPetCareVetViewerAccentColor() : [PPPetCareVetViewerAccentColor() colorWithAlphaComponent:0.08];
    if (!primary) {
        [button pp_setBorderColor:[PPPetCareVetViewerAccentColor() colorWithAlphaComponent:0.18]];
    }
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    button.accessibilityLabel = title;
    return button;
}

#pragma mark - Motion

- (void)pp_prepareEntranceState
{
    NSArray<UIView *> *views = @[self.heroView, self.profileSectionView, self.aboutSectionView, self.actionsSectionView];
    for (UIView *view in views) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 18.0);
    }
}

- (void)pp_beginEntranceAnimationIfNeeded
{
    if (self.didAnimateEntrance) {
        return;
    }
    self.didAnimateEntrance = YES;
    NSArray<UIView *> *views = @[self.heroView, self.profileSectionView, self.aboutSectionView, self.actionsSectionView];
    [views enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        [UIView animateWithDuration:0.48
                              delay:0.06 * idx
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.18
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

@end
