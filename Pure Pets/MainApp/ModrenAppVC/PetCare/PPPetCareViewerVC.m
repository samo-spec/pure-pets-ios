//
//  PPPetCareViewerVC.m
//  Pure Pets
//
//  Created by Codex on 4/26/26.
//

#import "PPPetCareViewerVC.h"
#import "VetManager.h"
#import "PPImageLoaderManager.h"

static CGFloat const PPPetCareViewerSideInset = 18.0;
static CGFloat const PPPetCareViewerSectionSpacing = 14.0;
static CGFloat const PPPetCareViewerSurfaceRadius = 28.0;

static NSString *PPPetCareViewerLocalized(NSString *key, NSString *fallback)
{
    NSString *value = key.length > 0 ? kLang(key) : nil;
    if (value.length == 0 || [value isEqualToString:key]) {
        return fallback ?: @"";
    }
    return value;
}

static NSString *PPPetCareViewerSafeString(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [[[value stringValue] ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] copy];
    }
    return @"";
}

static UIColor *PPPetCareViewerAccentColor(void)
{
    return AppPrimaryClr ?: UIColor.systemTealColor;
}

static UIColor *PPPetCareViewerTextColor(void)
{
    return AppPrimaryTextClr ?: UIColor.labelColor;
}

static UIColor *PPPetCareViewerSecondaryTextColor(void)
{
    return AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
}

static UIColor *PPPetCareViewerSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark ? [UIColor colorWithWhite:0.12 alpha:0.86] : [UIColor colorWithWhite:1.0 alpha:0.92];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.92];
}

static UIColor *PPPetCareViewerBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark ? [UIColor colorWithWhite:1.0 alpha:0.10] : [UIColor colorWithWhite:0.0 alpha:0.08];
        }];
    }
    return [UIColor colorWithWhite:0.0 alpha:0.08];
}

@interface PPPetCareViewerVC ()
@property (nonatomic, strong) VetMedicineModel *medicine;
@property (nonatomic, copy) NSString *mainKindName;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *heroView;
@property (nonatomic, strong) UIImageView *heroImageView;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) UIView *heroIconPlateView;
@property (nonatomic, strong) UIImageView *heroIconView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *essentialsSectionView;
@property (nonatomic, strong) UILabel *essentialsTitleLabel;
@property (nonatomic, strong) UIStackView *factsStackView;
@property (nonatomic, strong) UIView *descriptionSectionView;
@property (nonatomic, strong) UILabel *descriptionTitleLabel;
@property (nonatomic, strong) UILabel *descriptionBodyLabel;
@property (nonatomic, strong) UIView *actionsSectionView;
@property (nonatomic, strong) UIStackView *actionsStackView;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@end

@implementation PPPetCareViewerVC

- (instancetype)initWithMedicine:(VetMedicineModel *)medicine
                    mainKindName:(NSString *)mainKindName
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) {
        return nil;
    }
    _medicine = medicine;
    _mainKindName = PPPetCareViewerSafeString(mainKindName);
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
    self.navigationItem.title = PPPetCareViewerLocalized(@"pet_care_medicines", @"Medicines");
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_beginEntranceAnimationIfNeeded];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.heroGradientLayer.frame = self.heroView.bounds;
    self.heroGradientLayer.cornerRadius = self.heroView.layer.cornerRadius;
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
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.heroImageView];
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
    [self pp_buildEssentialsSection];
    [self pp_buildDescriptionSection];
    [self pp_buildActionsSection];
}

- (void)pp_buildHeroSection
{
    self.heroView = [[UIView alloc] init];
    self.heroView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroView.clipsToBounds = YES;
    self.heroView.layer.cornerRadius = 34.0;
    self.heroView.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        self.heroView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.heroImageView = [[UIImageView alloc] init];
    self.heroImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.heroImageView.clipsToBounds = YES;
    self.heroImageView.tintColor = PPPetCareViewerAccentColor();
    self.heroImageView.backgroundColor = [PPPetCareViewerAccentColor() colorWithAlphaComponent:0.08];

    self.heroGradientLayer = [CAGradientLayer layer];
    self.heroGradientLayer.startPoint = CGPointMake(0.5, 0.0);
    self.heroGradientLayer.endPoint = CGPointMake(0.5, 1.0);

    self.heroIconPlateView = [[UIView alloc] init];
    self.heroIconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIconPlateView.layer.cornerRadius = 24.0;
    self.heroIconPlateView.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        self.heroIconPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.heroIconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"pills.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    self.heroIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIconView.contentMode = UIViewContentModeScaleAspectFit;

    self.eyebrowLabel = [self pp_labelWithFont:[GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold]
                                         color:UIColor.whiteColor
                                         lines:1];
    self.eyebrowLabel.text = PPPetCareViewerLocalized(@"pet_care_eyebrow", @"Premium care");

    self.titleLabel = [self pp_labelWithFont:[GM boldFontWithSize:30.0] ?: [UIFont systemFontOfSize:30.0 weight:UIFontWeightBold]
                                       color:UIColor.whiteColor
                                       lines:2];
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.78;

    self.subtitleLabel = [self pp_labelWithFont:[GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium]
                                          color:[UIColor colorWithWhite:1.0 alpha:0.84]
                                          lines:2];

    self.priceLabel = [self pp_labelWithFont:[GM boldFontWithSize:18.0] ?: [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold]
                                       color:UIColor.whiteColor
                                       lines:1];

    self.statusLabel = [self pp_labelWithFont:[GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold]
                                        color:UIColor.whiteColor
                                        lines:1];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.layer.cornerRadius = 14.0;
    self.statusLabel.layer.masksToBounds = YES;

    [self.contentView addSubview:self.heroView];
    [self.heroView addSubview:self.heroImageView];
    [self.heroView.layer insertSublayer:self.heroGradientLayer above:self.heroImageView.layer];
    [self.heroView addSubview:self.heroIconPlateView];
    [self.heroIconPlateView addSubview:self.heroIconView];
    [self.heroView addSubview:self.eyebrowLabel];
    [self.heroView addSubview:self.titleLabel];
    [self.heroView addSubview:self.subtitleLabel];
    [self.heroView addSubview:self.priceLabel];
    [self.heroView addSubview:self.statusLabel];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.heroView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12.0],
        [self.heroView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareViewerSideInset],
        [self.heroView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareViewerSideInset],
        [self.heroView.heightAnchor constraintGreaterThanOrEqualToConstant:336.0],
        [self.heroView.topAnchor constraintGreaterThanOrEqualToAnchor:safe.topAnchor constant:4.0],

        [self.heroImageView.topAnchor constraintEqualToAnchor:self.heroView.topAnchor],
        [self.heroImageView.leadingAnchor constraintEqualToAnchor:self.heroView.leadingAnchor],
        [self.heroImageView.trailingAnchor constraintEqualToAnchor:self.heroView.trailingAnchor],
        [self.heroImageView.bottomAnchor constraintEqualToAnchor:self.heroView.bottomAnchor],

        [self.heroIconPlateView.topAnchor constraintEqualToAnchor:self.heroView.topAnchor constant:18.0],
        [self.heroIconPlateView.trailingAnchor constraintEqualToAnchor:self.heroView.trailingAnchor constant:-18.0],
        [self.heroIconPlateView.widthAnchor constraintEqualToConstant:48.0],
        [self.heroIconPlateView.heightAnchor constraintEqualToConstant:48.0],

        [self.heroIconView.centerXAnchor constraintEqualToAnchor:self.heroIconPlateView.centerXAnchor],
        [self.heroIconView.centerYAnchor constraintEqualToAnchor:self.heroIconPlateView.centerYAnchor],
        [self.heroIconView.widthAnchor constraintEqualToConstant:22.0],
        [self.heroIconView.heightAnchor constraintEqualToConstant:22.0],

        [self.eyebrowLabel.leadingAnchor constraintEqualToAnchor:self.heroView.leadingAnchor constant:22.0],
        [self.eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroIconPlateView.leadingAnchor constant:-14.0],
        [self.eyebrowLabel.topAnchor constraintEqualToAnchor:self.heroView.topAnchor constant:24.0],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.eyebrowLabel.leadingAnchor],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.heroView.trailingAnchor constant:-22.0],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.eyebrowLabel.bottomAnchor constant:92.0],

        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8.0],

        [self.priceLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.priceLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.statusLabel.leadingAnchor constant:-12.0],
        [self.priceLabel.bottomAnchor constraintEqualToAnchor:self.heroView.bottomAnchor constant:-22.0],

        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.heroView.trailingAnchor constant:-22.0],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.priceLabel.centerYAnchor],
        [self.statusLabel.heightAnchor constraintEqualToConstant:28.0],
        [self.statusLabel.widthAnchor constraintGreaterThanOrEqualToConstant:110.0]
    ]];
}

- (void)pp_buildEssentialsSection
{
    self.essentialsSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.essentialsSectionView];

    self.essentialsTitleLabel = [self pp_sectionTitleLabelWithText:PPPetCareViewerLocalized(@"pet_care_viewer_essentials", @"Essentials")];
    [self.essentialsSectionView addSubview:self.essentialsTitleLabel];

    self.factsStackView = [[UIStackView alloc] init];
    self.factsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.factsStackView.axis = UILayoutConstraintAxisVertical;
    self.factsStackView.spacing = 10.0;
    [self.essentialsSectionView addSubview:self.factsStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.essentialsSectionView.topAnchor constraintEqualToAnchor:self.heroView.bottomAnchor constant:PPPetCareViewerSectionSpacing],
        [self.essentialsSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareViewerSideInset],
        [self.essentialsSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareViewerSideInset],

        [self.essentialsTitleLabel.topAnchor constraintEqualToAnchor:self.essentialsSectionView.topAnchor constant:20.0],
        [self.essentialsTitleLabel.leadingAnchor constraintEqualToAnchor:self.essentialsSectionView.leadingAnchor constant:20.0],
        [self.essentialsTitleLabel.trailingAnchor constraintEqualToAnchor:self.essentialsSectionView.trailingAnchor constant:-20.0],

        [self.factsStackView.topAnchor constraintEqualToAnchor:self.essentialsTitleLabel.bottomAnchor constant:14.0],
        [self.factsStackView.leadingAnchor constraintEqualToAnchor:self.essentialsSectionView.leadingAnchor constant:16.0],
        [self.factsStackView.trailingAnchor constraintEqualToAnchor:self.essentialsSectionView.trailingAnchor constant:-16.0],
        [self.factsStackView.bottomAnchor constraintEqualToAnchor:self.essentialsSectionView.bottomAnchor constant:-16.0]
    ]];
}

- (void)pp_buildDescriptionSection
{
    self.descriptionSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.descriptionSectionView];

    self.descriptionTitleLabel = [self pp_sectionTitleLabelWithText:PPPetCareViewerLocalized(@"pet_care_viewer_description", @"Description")];
    [self.descriptionSectionView addSubview:self.descriptionTitleLabel];

    self.descriptionBodyLabel = [self pp_labelWithFont:[GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular]
                                                 color:PPPetCareViewerTextColor()
                                                 lines:0];
    [self.descriptionSectionView addSubview:self.descriptionBodyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.descriptionSectionView.topAnchor constraintEqualToAnchor:self.essentialsSectionView.bottomAnchor constant:PPPetCareViewerSectionSpacing],
        [self.descriptionSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareViewerSideInset],
        [self.descriptionSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareViewerSideInset],

        [self.descriptionTitleLabel.topAnchor constraintEqualToAnchor:self.descriptionSectionView.topAnchor constant:20.0],
        [self.descriptionTitleLabel.leadingAnchor constraintEqualToAnchor:self.descriptionSectionView.leadingAnchor constant:20.0],
        [self.descriptionTitleLabel.trailingAnchor constraintEqualToAnchor:self.descriptionSectionView.trailingAnchor constant:-20.0],

        [self.descriptionBodyLabel.topAnchor constraintEqualToAnchor:self.descriptionTitleLabel.bottomAnchor constant:10.0],
        [self.descriptionBodyLabel.leadingAnchor constraintEqualToAnchor:self.descriptionSectionView.leadingAnchor constant:20.0],
        [self.descriptionBodyLabel.trailingAnchor constraintEqualToAnchor:self.descriptionSectionView.trailingAnchor constant:-20.0],
        [self.descriptionBodyLabel.bottomAnchor constraintEqualToAnchor:self.descriptionSectionView.bottomAnchor constant:-20.0]
    ]];
}

- (void)pp_buildActionsSection
{
    self.actionsSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.actionsSectionView];

    self.actionsStackView = [[UIStackView alloc] init];
    self.actionsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.actionsStackView.alignment = UIStackViewAlignmentFill;
    self.actionsStackView.distribution = UIStackViewDistributionFillEqually;
    self.actionsStackView.spacing = 12.0;
    [self.actionsSectionView addSubview:self.actionsStackView];

    UIButton *shareButton = [self pp_actionButtonWithTitle:PPPetCareViewerLocalized(@"pet_care_viewer_share", @"Share")
                                                     symbol:@"square.and.arrow.up"
                                                    primary:YES
                                                   selector:@selector(pp_shareTapped)];
    [self.actionsStackView addArrangedSubview:shareButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.actionsSectionView.topAnchor constraintEqualToAnchor:self.descriptionSectionView.bottomAnchor constant:PPPetCareViewerSectionSpacing],
        [self.actionsSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareViewerSideInset],
        [self.actionsSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareViewerSideInset],
        [self.actionsSectionView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-28.0],

        [self.actionsStackView.topAnchor constraintEqualToAnchor:self.actionsSectionView.topAnchor constant:16.0],
        [self.actionsStackView.leadingAnchor constraintEqualToAnchor:self.actionsSectionView.leadingAnchor constant:16.0],
        [self.actionsStackView.trailingAnchor constraintEqualToAnchor:self.actionsSectionView.trailingAnchor constant:-16.0],
        [self.actionsStackView.bottomAnchor constraintEqualToAnchor:self.actionsSectionView.bottomAnchor constant:-16.0],
        [self.actionsStackView.heightAnchor constraintEqualToConstant:52.0]
    ]];
}

#pragma mark - Content

- (void)pp_applyContent
{
    self.titleLabel.text = self.medicine.title.length > 0 ? self.medicine.title : PPPetCareViewerLocalized(@"pet_care_medicine_untitled", @"Medicine");
    self.subtitleLabel.text = self.medicine.category.length > 0 ? self.medicine.category : PPPetCareViewerLocalized(@"pet_care_viewer_about_medicine", @"Veterinary care essential");
    self.priceLabel.text = [self pp_priceText];
    self.statusLabel.text = [self pp_availabilityText];
    self.descriptionBodyLabel.text = self.medicine.medicineDescription.length > 0
        ? self.medicine.medicineDescription
        : PPPetCareViewerLocalized(@"pet_care_viewer_no_description", @"No description has been added yet.");
    self.descriptionBodyLabel.textAlignment = Language.alignmentForCurrentLanguage;

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:44.0 weight:UIImageSymbolWeightSemibold];
    UIImage *placeholder = [[UIImage systemImageNamed:@"pills.fill" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.heroImageView.image = placeholder;
    if (self.medicine.imageUrl.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:self.heroImageView
                                                       url:self.medicine.imageUrl
                                               placeholder:placeholder
                                          transitionStyle:PPImageTransitionStyleFade
                                                complation:nil];
    }

    [self pp_reloadFacts];
    self.view.accessibilityLabel = self.titleLabel.text;
}

- (void)pp_reloadFacts
{
    for (UIView *view in self.factsStackView.arrangedSubviews) {
        [self.factsStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    UIColor *accent = PPPetCareViewerAccentColor();
    UIColor *green = [UIColor colorWithRed:0.20 green:0.62 blue:0.43 alpha:1.0];
    UIColor *orange = [UIColor colorWithRed:0.91 green:0.49 blue:0.16 alpha:1.0];

    [self.factsStackView addArrangedSubview:[self pp_factRowWithIcon:@"tag.fill"
                                                               title:PPPetCareViewerLocalized(@"pet_care_viewer_category", @"Category")
                                                               value:[self pp_categoryText]
                                                              accent:accent]];
    [self.factsStackView addArrangedSubview:[self pp_factRowWithIcon:@"pawprint.fill"
                                                               title:PPPetCareViewerLocalized(@"pet_care_viewer_pet_kind", @"Pet kind")
                                                               value:[self pp_petKindText]
                                                              accent:[UIColor colorWithRed:0.32 green:0.66 blue:0.56 alpha:1.0]]];
    [self.factsStackView addArrangedSubview:[self pp_factRowWithIcon:self.medicine.requiresPrescription ? @"doc.text.fill" : @"checkmark.seal.fill"
                                                               title:PPPetCareViewerLocalized(@"pet_care_viewer_prescription", @"Prescription")
                                                               value:self.medicine.requiresPrescription ? PPPetCareViewerLocalized(@"pet_care_medicine_prescription_required", @"Prescription required") : PPPetCareViewerLocalized(@"pet_care_medicine_ready", @"Ready to order")
                                                              accent:self.medicine.requiresPrescription ? orange : green]];
    [self.factsStackView addArrangedSubview:[self pp_factRowWithIcon:self.medicine.stockQuantity > 0 ? @"shippingbox.fill" : @"exclamationmark.triangle.fill"
                                                               title:PPPetCareViewerLocalized(@"pet_care_medicine_stock", @"Stock")
                                                               value:[self pp_stockText]
                                                              accent:self.medicine.stockQuantity > 0 ? green : UIColor.systemRedColor]];
    [self.factsStackView addArrangedSubview:[self pp_factRowWithIcon:@"clock"
                                                               title:PPPetCareViewerLocalized(@"pet_care_viewer_added_date", @"Added")
                                                               value:[self pp_dateText:self.medicine.createdAt]
                                                              accent:PPPetCareViewerSecondaryTextColor()]];
}

- (NSString *)pp_priceText
{
    NSString *currency = self.medicine.currency.length > 0 ? self.medicine.currency : @"QAR";
    NSString *formatted = [GM formatPrice:@(self.medicine.price) currencyCode:currency];
    return formatted.length > 0 ? formatted : [NSString stringWithFormat:@"%.2f %@", self.medicine.price, currency];
}

- (NSString *)pp_categoryText
{
    return self.medicine.category.length > 0 ? self.medicine.category : PPPetCareViewerLocalized(@"pet_care_viewer_not_specified", @"Not specified");
}

- (NSString *)pp_petKindText
{
    if (self.medicine.animalTypes.count > 0) {
        return [self.medicine.animalTypes componentsJoinedByString:@", "];
    }
    return self.mainKindName.length > 0 ? self.mainKindName : PPPetCareViewerLocalized(@"pet_care_all_pets", @"All pets");
}

- (NSString *)pp_stockText
{
    if (self.medicine.stockQuantity <= 0) {
        return PPPetCareViewerLocalized(@"pet_care_medicine_out_of_stock", @"Out of stock");
    }
    NSString *format = PPPetCareViewerLocalized(@"pet_care_viewer_stock_units_format", @"%ld in stock");
    return [NSString stringWithFormat:format, (long)self.medicine.stockQuantity];
}

- (NSString *)pp_availabilityText
{
    if (self.medicine.stockQuantity <= 0 || !self.medicine.isAvailable) {
        return PPPetCareViewerLocalized(@"pet_care_medicine_out_of_stock", @"Out of stock");
    }
    return self.medicine.requiresPrescription
        ? PPPetCareViewerLocalized(@"pet_care_medicine_prescription_required", @"Prescription required")
        : PPPetCareViewerLocalized(@"pet_care_medicine_ready", @"Ready to order");
}

- (NSString *)pp_dateText:(NSDate *)date
{
    if (!date) {
        return PPPetCareViewerLocalized(@"pet_care_viewer_not_specified", @"Not specified");
    }
    NSString *formatted = [GM formattedDate:date];
    return formatted.length > 0 ? formatted : PPPetCareViewerLocalized(@"pet_care_viewer_not_specified", @"Not specified");
}

#pragma mark - Theme

- (void)pp_applyTheme
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    UIColor *accent = PPPetCareViewerAccentColor();
    self.heroView.backgroundColor = [accent colorWithAlphaComponent:0.10];
    [self.heroView pp_setBorderColor:PPPetCareViewerBorderColor()];
    self.heroGradientLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:dark ? 0.22 : 0.12].CGColor,
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.16].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:0.52].CGColor,
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.74].CGColor
    ];
    self.heroGradientLayer.locations = @[@0.0, @0.42, @0.72, @1.0];

    self.heroIconPlateView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:dark ? 0.12 : 0.18];
    [self.heroIconPlateView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.24]];
    self.heroIconView.tintColor = UIColor.whiteColor;

    UIColor *statusColor = (self.medicine.stockQuantity > 0 && self.medicine.isAvailable)
        ? (self.medicine.requiresPrescription ? UIColor.systemOrangeColor : accent)
        : UIColor.systemRedColor;
    self.statusLabel.backgroundColor = [statusColor colorWithAlphaComponent:0.82];
    self.statusLabel.textColor = UIColor.whiteColor;

    [self pp_applySectionTheme:self.essentialsSectionView];
    [self pp_applySectionTheme:self.descriptionSectionView];
    [self pp_applySectionTheme:self.actionsSectionView];
    self.essentialsTitleLabel.textColor = PPPetCareViewerTextColor();
    self.descriptionTitleLabel.textColor = PPPetCareViewerTextColor();
    self.descriptionBodyLabel.textColor = PPPetCareViewerTextColor();
}

- (void)pp_applySectionTheme:(UIView *)section
{
    section.backgroundColor = PPPetCareViewerSurfaceColor();
    [section pp_setBorderColor:PPPetCareViewerBorderColor()];
}

#pragma mark - Actions

- (void)pp_shareTapped
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [parts addObject:self.titleLabel.text ?: @""];
    if (self.medicine.medicineDescription.length > 0) {
        [parts addObject:self.medicine.medicineDescription];
    }
    [parts addObject:[NSString stringWithFormat:@"%@: %@", PPPetCareViewerLocalized(@"pet_care_medicine_price", @"Price"), [self pp_priceText]]];
    [parts addObject:[NSString stringWithFormat:@"%@: %@", PPPetCareViewerLocalized(@"pet_care_medicine_stock", @"Stock"), [self pp_stockText]]];

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[[parts componentsJoinedByString:@"\n"]]
                                                                             applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.actionsSectionView;
        activityVC.popoverPresentationController.sourceRect = self.actionsSectionView.bounds;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - Components

- (UIView *)pp_surfaceSectionView
{
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.layer.cornerRadius = PPPetCareViewerSurfaceRadius;
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
                                      color:PPPetCareViewerTextColor()
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
                                           color:PPPetCareViewerSecondaryTextColor()
                                           lines:1];
    titleLabel.text = title;

    UILabel *valueLabel = [self pp_labelWithFont:[GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold]
                                           color:PPPetCareViewerTextColor()
                                           lines:2];
    valueLabel.text = value.length > 0 ? value : PPPetCareViewerLocalized(@"pet_care_viewer_not_specified", @"Not specified");

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
    button.tintColor = primary ? UIColor.whiteColor : PPPetCareViewerAccentColor();
    [button setTitleColor:(primary ? UIColor.whiteColor : PPPetCareViewerTextColor()) forState:UIControlStateNormal];
    button.backgroundColor = primary ? PPPetCareViewerAccentColor() : [PPPetCareViewerAccentColor() colorWithAlphaComponent:0.08];
    if (!primary) {
        [button pp_setBorderColor:[PPPetCareViewerAccentColor() colorWithAlphaComponent:0.18]];
    }
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    button.accessibilityLabel = title;
    return button;
}

#pragma mark - Motion

- (void)pp_prepareEntranceState
{
    NSArray<UIView *> *views = @[self.heroView, self.essentialsSectionView, self.descriptionSectionView, self.actionsSectionView];
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
    NSArray<UIView *> *views = @[self.heroView, self.essentialsSectionView, self.descriptionSectionView, self.actionsSectionView];
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
