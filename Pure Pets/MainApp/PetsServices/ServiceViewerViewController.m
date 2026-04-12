//
//  ServiceViewerViewController.m
//  Pure Pets
//

#import "ServiceViewerViewController.h"
#import "ServiceModel.h"
#import "GM.h"
#import "PetAdManager.h"
#import "PPAlertHelper.h"
#import "PPCommerceFeedbackManager.h"
#import "AppClasses.h"
#import "UserModel.h"
#import "PPPetsTitleView.h"
#import "PPInfoPillsView.h"
#import "UserContactView.h"
#import "PPModernAvatarRenderer.h"
#import "MainKindsModel.h"
@import FirebaseFirestore;

static CGFloat const PPServiceViewerSideInset = 16.0;
static CGFloat const PPServiceViewerSectionSpacing = 14.0;
static CGFloat const PPServiceViewerHeroBottomInset = 20.0;
static CGFloat const PPServiceViewerSurfaceRadius = 26.0;

@interface ServiceViewerViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *topGlowView;
@property (nonatomic, strong) UIView *bottomGlowView;

@property (nonatomic, strong) UIView *heroContainerView;
@property (nonatomic, strong) UIImageView *heroImageView;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) NSLayoutConstraint *heroHeightConstraint;
@property (nonatomic, strong) PPPetsTitleView *titleView;

@property (nonatomic, strong) UIView *providerSectionView;
@property (nonatomic, strong) UILabel *providerTitleLabel;
@property (nonatomic, strong) UserContactView *providerContactView;
@property (nonatomic, strong) UILabel *providerMetaLabel;
@property (nonatomic, strong) UILabel *providerAboutTitleLabel;
@property (nonatomic, strong) UILabel *providerAboutLabel;

@property (nonatomic, strong) UIView *factsSectionView;
@property (nonatomic, strong) UILabel *factsTitleLabel;
@property (nonatomic, strong) UIStackView *factsStackView;

@property (nonatomic, strong) UIView *descriptionSectionView;
@property (nonatomic, strong) UILabel *descriptionTitleLabel;
@property (nonatomic, strong) UILabel *descriptionBodyLabel;

@property (nonatomic, strong) UIView *actionsSectionView;
@property (nonatomic, strong) UILabel *actionsTitleLabel;
@property (nonatomic, strong) UIStackView *actionsStackView;
@property (nonatomic, strong) UIButton *shareActionButton;
@property (nonatomic, strong) UIButton *PhoneActionButton;
@property (nonatomic, strong, nullable) UIButton *reportActionButton;

@property (nonatomic, strong) UserModel *ownerModel;
@property (nonatomic, assign) BOOL didTrackViewInteraction;
@property (nonatomic, assign) BOOL isResolvingOwner;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@end

@implementation ServiceViewerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.semanticContentAttribute = GM.setSemantic;
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.view.layer.cornerRadius = 28.0;
    self.view.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.view.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.modalInPresentation = NO;

    [self setupLayout];
    [self applyModelContent];
    [self loadOwnerIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (!self.didTrackViewInteraction) {
        self.didTrackViewInteraction = YES;
        [self trackServiceInteraction:PPItemInteractionTypeView];
    }

    [self pp_beginEntranceAnimationsIfNeeded];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    self.heroGradientLayer.frame = self.heroContainerView.bounds;
    self.heroHeightConstraint.constant = [self pp_heroHeight];
    self.topGlowView.layer.cornerRadius = CGRectGetWidth(self.topGlowView.bounds) / 2.0;
    self.bottomGlowView.layer.cornerRadius = CGRectGetWidth(self.bottomGlowView.bounds) / 2.0;
}

#pragma mark - Layout

- (void)setupLayout {
    [self buildBackgroundDecor];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.backgroundColor = UIColor.clearColor;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.semanticContentAttribute = GM.setSemantic;
    if (@available(iOS 11.0, *)) {
        self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.semanticContentAttribute = GM.setSemantic;

    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.contentView];

    UILayoutGuide *contentGuide = self.scrollView;
    UILayoutGuide *frameGuide = self.scrollView;
    if (@available(iOS 11.0, *)) {
        contentGuide = self.scrollView.contentLayoutGuide;
        frameGuide = self.scrollView.frameLayoutGuide;
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:contentGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:contentGuide.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:frameGuide.widthAnchor]
    ]];

    [self buildHeroSection];
    [self buildProviderSection];
    [self buildFactsSection];
    [self buildDescriptionSection];
    [self buildActionsSection];
    [self pp_prepareEntranceState];
}

- (void)buildBackgroundDecor {
    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemBlueColor;

    self.topGlowView = [[UIView alloc] init];
    self.topGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topGlowView.userInteractionEnabled = NO;
    self.topGlowView.backgroundColor = [accentColor colorWithAlphaComponent:0.18];
    self.topGlowView.layer.shadowColor = accentColor.CGColor;
    self.topGlowView.layer.shadowOpacity = 0.18f;
    self.topGlowView.layer.shadowRadius = 42.0f;
    self.topGlowView.layer.shadowOffset = CGSizeZero;

    self.bottomGlowView = [[UIView alloc] init];
    self.bottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomGlowView.userInteractionEnabled = NO;
    self.bottomGlowView.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    self.bottomGlowView.layer.shadowColor = accentColor.CGColor;
    self.bottomGlowView.layer.shadowOpacity = 0.12f;
    self.bottomGlowView.layer.shadowRadius = 36.0f;
    self.bottomGlowView.layer.shadowOffset = CGSizeZero;

    [self.view addSubview:self.topGlowView];
    [self.view addSubview:self.bottomGlowView];

    [NSLayoutConstraint activateConstraints:@[
        [self.topGlowView.widthAnchor constraintEqualToConstant:250.0],
        [self.topGlowView.heightAnchor constraintEqualToConstant:250.0],
        [self.topGlowView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-80.0],
        [self.topGlowView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-70.0],

        [self.bottomGlowView.widthAnchor constraintEqualToConstant:220.0],
        [self.bottomGlowView.heightAnchor constraintEqualToConstant:220.0],
        [self.bottomGlowView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:65.0],
        [self.bottomGlowView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:75.0]
    ]];
}

- (void)buildHeroSection {
    self.heroContainerView = [[UIView alloc] init];
    self.heroContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroContainerView.backgroundColor = AppForgroundColr ?: UIColor.systemBackgroundColor;
    self.heroContainerView.layer.cornerRadius = 0.0;
    self.heroContainerView.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    self.heroContainerView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.heroContainerView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.heroImageView = [[UIImageView alloc] init];
    self.heroImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.heroImageView.clipsToBounds = YES;
    self.heroImageView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.48];

    self.heroGradientLayer = [CAGradientLayer layer];
    UIColor *surfaceColor = AppForgroundColr ?: UIColor.systemBackgroundColor;
    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    self.heroGradientLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:0.04 alpha:0.06].CGColor,
        (__bridge id)[UIColor colorWithWhite:0.04 alpha:0.18].CGColor,
        (__bridge id)[accentColor colorWithAlphaComponent:0.20].CGColor,
        (__bridge id)[surfaceColor colorWithAlphaComponent:0.96].CGColor
    ];
    self.heroGradientLayer.locations = @[@0.0, @0.42, @0.74, @1.0];
    self.heroGradientLayer.startPoint = CGPointMake(0.5, 0.0);
    self.heroGradientLayer.endPoint = CGPointMake(0.5, 1.0);

    self.closeButton = [self pp_topChromeButtonWithSystemName:@"xmark" selector:@selector(closeTapped)];

    self.titleView = [[PPPetsTitleView alloc] init];
    self.titleView.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleView.layer.cornerRadius = 28.0;
    [self.titleView enableBlurBackgroundWithStyle:UIBlurEffectStyleExtraLight];
    self.titleView.layer.borderWidth = 1.0;
    self.titleView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.16].CGColor;
    self.titleView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.titleView.layer.shadowOpacity = 0.12f;
    self.titleView.layer.shadowRadius = 22.0f;
    self.titleView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    if (@available(iOS 13.0, *)) {
        self.titleView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    [self.contentView addSubview:self.heroContainerView];
    [self.heroContainerView addSubview:self.heroImageView];
    [self.heroContainerView.layer addSublayer:self.heroGradientLayer];
    [self.heroContainerView addSubview:self.closeButton];
    [self.heroContainerView addSubview:self.titleView];

    self.heroHeightConstraint = [self.heroContainerView.heightAnchor constraintEqualToConstant:[self pp_heroHeight]];
    [NSLayoutConstraint activateConstraints:@[
        [self.heroContainerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.heroContainerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.heroContainerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        self.heroHeightConstraint,

        [self.heroImageView.topAnchor constraintEqualToAnchor:self.heroContainerView.topAnchor],
        [self.heroImageView.leadingAnchor constraintEqualToAnchor:self.heroContainerView.leadingAnchor],
        [self.heroImageView.trailingAnchor constraintEqualToAnchor:self.heroContainerView.trailingAnchor],
        [self.heroImageView.bottomAnchor constraintEqualToAnchor:self.heroContainerView.bottomAnchor],

        [self.closeButton.topAnchor constraintEqualToAnchor:self.heroContainerView.topAnchor constant:18.0],
        [self.closeButton.leadingAnchor constraintEqualToAnchor:self.heroContainerView.leadingAnchor constant:18.0],
        [self.closeButton.widthAnchor constraintEqualToConstant:40.0],
        [self.closeButton.heightAnchor constraintEqualToConstant:40.0],

        [self.titleView.leadingAnchor constraintEqualToAnchor:self.heroContainerView.leadingAnchor constant:PPServiceViewerSideInset],
        [self.titleView.trailingAnchor constraintEqualToAnchor:self.heroContainerView.trailingAnchor constant:-PPServiceViewerSideInset],
        [self.titleView.bottomAnchor constraintEqualToAnchor:self.heroContainerView.bottomAnchor constant:-PPServiceViewerHeroBottomInset]
    ]];
}

- (void)buildProviderSection {
    self.providerSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.providerSectionView];

    self.providerTitleLabel = [self pp_sectionTitleLabelWithText:kLang(@"service_view_provider_title")];
    [self.providerSectionView addSubview:self.providerTitleLabel];

    self.providerContactView = [[UserContactView alloc] init];
    self.providerContactView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.providerSectionView addSubview:self.providerContactView];

    self.providerMetaLabel = [[UILabel alloc] init];
    self.providerMetaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerMetaLabel.font = [GM MidFontWithSize:14];
    self.providerMetaLabel.numberOfLines = 0;
    self.providerMetaLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.72];
    self.providerMetaLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.providerSectionView addSubview:self.providerMetaLabel];

    self.providerAboutTitleLabel = [[UILabel alloc] init];
    self.providerAboutTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerAboutTitleLabel.font = [GM boldFontWithSize:15];
    self.providerAboutTitleLabel.textColor = AppPrimaryTextClr;
    self.providerAboutTitleLabel.text = kLang(@"service_view_provider_about_title");
    self.providerAboutTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.providerSectionView addSubview:self.providerAboutTitleLabel];

    self.providerAboutLabel = [[UILabel alloc] init];
    self.providerAboutLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.providerAboutLabel.font = [GM MidFontWithSize:15];
    self.providerAboutLabel.numberOfLines = 0;
    self.providerAboutLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.86];
    self.providerAboutLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.providerSectionView addSubview:self.providerAboutLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.providerSectionView.topAnchor constraintEqualToAnchor:self.heroContainerView.bottomAnchor constant:18.0],
        [self.providerSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPServiceViewerSideInset],
        [self.providerSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPServiceViewerSideInset],

        [self.providerTitleLabel.topAnchor constraintEqualToAnchor:self.providerSectionView.topAnchor constant:20.0],
        [self.providerTitleLabel.leadingAnchor constraintEqualToAnchor:self.providerSectionView.leadingAnchor constant:20.0],
        [self.providerTitleLabel.trailingAnchor constraintEqualToAnchor:self.providerSectionView.trailingAnchor constant:-20.0],

        [self.providerContactView.topAnchor constraintEqualToAnchor:self.providerTitleLabel.bottomAnchor constant:14.0],
        [self.providerContactView.leadingAnchor constraintEqualToAnchor:self.providerSectionView.leadingAnchor constant:18.0],
        [self.providerContactView.trailingAnchor constraintEqualToAnchor:self.providerSectionView.trailingAnchor constant:-18.0],
        [self.providerContactView.heightAnchor constraintEqualToConstant:76.0],

        [self.providerMetaLabel.topAnchor constraintEqualToAnchor:self.providerContactView.bottomAnchor constant:14.0],
        [self.providerMetaLabel.leadingAnchor constraintEqualToAnchor:self.providerSectionView.leadingAnchor constant:20.0],
        [self.providerMetaLabel.trailingAnchor constraintEqualToAnchor:self.providerSectionView.trailingAnchor constant:-20.0],

        [self.providerAboutTitleLabel.topAnchor constraintEqualToAnchor:self.providerMetaLabel.bottomAnchor constant:16.0],
        [self.providerAboutTitleLabel.leadingAnchor constraintEqualToAnchor:self.providerSectionView.leadingAnchor constant:20.0],
        [self.providerAboutTitleLabel.trailingAnchor constraintEqualToAnchor:self.providerSectionView.trailingAnchor constant:-20.0],

        [self.providerAboutLabel.topAnchor constraintEqualToAnchor:self.providerAboutTitleLabel.bottomAnchor constant:8.0],
        [self.providerAboutLabel.leadingAnchor constraintEqualToAnchor:self.providerSectionView.leadingAnchor constant:20.0],
        [self.providerAboutLabel.trailingAnchor constraintEqualToAnchor:self.providerSectionView.trailingAnchor constant:-20.0],
        [self.providerAboutLabel.bottomAnchor constraintEqualToAnchor:self.providerSectionView.bottomAnchor constant:-20.0]
    ]];
}

- (void)buildFactsSection {
    self.factsSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.factsSectionView];

    self.factsTitleLabel = [self pp_sectionTitleLabelWithText:kLang(@"service_view_quick_facts_title")];
    [self.factsSectionView addSubview:self.factsTitleLabel];

    self.factsStackView = [[UIStackView alloc] init];
    self.factsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.factsStackView.axis = UILayoutConstraintAxisVertical;
    self.factsStackView.spacing = 12.0;
    [self.factsSectionView addSubview:self.factsStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.factsSectionView.topAnchor constraintEqualToAnchor:self.providerSectionView.bottomAnchor constant:PPServiceViewerSectionSpacing],
        [self.factsSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPServiceViewerSideInset],
        [self.factsSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPServiceViewerSideInset],

        [self.factsTitleLabel.topAnchor constraintEqualToAnchor:self.factsSectionView.topAnchor constant:20.0],
        [self.factsTitleLabel.leadingAnchor constraintEqualToAnchor:self.factsSectionView.leadingAnchor constant:20.0],
        [self.factsTitleLabel.trailingAnchor constraintEqualToAnchor:self.factsSectionView.trailingAnchor constant:-20.0],

        [self.factsStackView.topAnchor constraintEqualToAnchor:self.factsTitleLabel.bottomAnchor constant:14.0],
        [self.factsStackView.leadingAnchor constraintEqualToAnchor:self.factsSectionView.leadingAnchor constant:16.0],
        [self.factsStackView.trailingAnchor constraintEqualToAnchor:self.factsSectionView.trailingAnchor constant:-16.0],
        [self.factsStackView.bottomAnchor constraintEqualToAnchor:self.factsSectionView.bottomAnchor constant:-16.0]
    ]];
}

- (void)buildDescriptionSection {
    self.descriptionSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.descriptionSectionView];

    self.descriptionTitleLabel = [self pp_sectionTitleLabelWithText:kLang(@"service_view_description_title")];
    [self.descriptionSectionView addSubview:self.descriptionTitleLabel];

    self.descriptionBodyLabel = [[UILabel alloc] init];
    self.descriptionBodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionBodyLabel.font = [GM MidFontWithSize:15];
    self.descriptionBodyLabel.numberOfLines = 0;
    self.descriptionBodyLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.86];
    self.descriptionBodyLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.descriptionSectionView addSubview:self.descriptionBodyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.descriptionSectionView.topAnchor constraintEqualToAnchor:self.factsSectionView.bottomAnchor constant:PPServiceViewerSectionSpacing],
        [self.descriptionSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPServiceViewerSideInset],
        [self.descriptionSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPServiceViewerSideInset],

        [self.descriptionTitleLabel.topAnchor constraintEqualToAnchor:self.descriptionSectionView.topAnchor constant:20.0],
        [self.descriptionTitleLabel.leadingAnchor constraintEqualToAnchor:self.descriptionSectionView.leadingAnchor constant:20.0],
        [self.descriptionTitleLabel.trailingAnchor constraintEqualToAnchor:self.descriptionSectionView.trailingAnchor constant:-20.0],

        [self.descriptionBodyLabel.topAnchor constraintEqualToAnchor:self.descriptionTitleLabel.bottomAnchor constant:10.0],
        [self.descriptionBodyLabel.leadingAnchor constraintEqualToAnchor:self.descriptionSectionView.leadingAnchor constant:20.0],
        [self.descriptionBodyLabel.trailingAnchor constraintEqualToAnchor:self.descriptionSectionView.trailingAnchor constant:-20.0],
        [self.descriptionBodyLabel.bottomAnchor constraintEqualToAnchor:self.descriptionSectionView.bottomAnchor constant:-20.0]
    ]];
}

- (void)buildActionsSection {
    self.actionsSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.actionsSectionView];

    self.actionsTitleLabel = [self pp_sectionTitleLabelWithText:kLang(@"service_view_actions_title")];
    [self.actionsSectionView addSubview:self.actionsTitleLabel];

    self.actionsStackView = [[UIStackView alloc] init];
    self.actionsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.actionsStackView.alignment = UIStackViewAlignmentFill;
    self.actionsStackView.distribution = UIStackViewDistributionFillEqually;
    self.actionsStackView.spacing = 12.0;
    [self.actionsSectionView addSubview:self.actionsStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.actionsSectionView.topAnchor constraintEqualToAnchor:self.descriptionSectionView.bottomAnchor constant:PPServiceViewerSectionSpacing],
        [self.actionsSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPServiceViewerSideInset],
        [self.actionsSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPServiceViewerSideInset],
        [self.actionsSectionView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-28.0],

        [self.actionsTitleLabel.topAnchor constraintEqualToAnchor:self.actionsSectionView.topAnchor constant:20.0],
        [self.actionsTitleLabel.leadingAnchor constraintEqualToAnchor:self.actionsSectionView.leadingAnchor constant:20.0],
        [self.actionsTitleLabel.trailingAnchor constraintEqualToAnchor:self.actionsSectionView.trailingAnchor constant:-20.0],

        [self.actionsStackView.topAnchor constraintEqualToAnchor:self.actionsTitleLabel.bottomAnchor constant:14.0],
        [self.actionsStackView.leadingAnchor constraintEqualToAnchor:self.actionsSectionView.leadingAnchor constant:16.0],
        [self.actionsStackView.trailingAnchor constraintEqualToAnchor:self.actionsSectionView.trailingAnchor constant:-16.0],
        [self.actionsStackView.bottomAnchor constraintEqualToAnchor:self.actionsSectionView.bottomAnchor constant:-16.0]
    ]];

    [self pp_rebuildActions];
}

#pragma mark - Configure

- (void)applyModelContent {
    [GM setImageFromUrlString:self.service.imageURL imageView:self.heroImageView phImage:@"placeholder"];

    NSString *title = [self pp_serviceTitle];
    NSString *providerName = [self pp_providerDisplayName];
    NSString *priceText = [self pp_priceText];
    NSString *categoryText = [self pp_categoryText];

    [self.titleView configureWithTitle:title location:providerName price:priceText category:categoryText];
    [self.titleView updateMetaPillsWithItems:[self pp_summaryPills]];

    self.descriptionBodyLabel.text = self.service.desc.length > 0 ? self.service.desc : kLang(@"service_view_no_description");

    [self pp_updateProviderSection];
    [self pp_reloadFacts];
    [self pp_updateActionAvailability];
}

- (void)pp_updateProviderSection {
    NSString *providerName = [self pp_providerDisplayName];
    UIImage *placeholderAvatar = [PPModernAvatarRenderer avatarImageForName:providerName size:44];

    if (self.ownerModel) {
        __weak typeof(self) weakSelf = self;
        [self.providerContactView configureWithUser:self.ownerModel
                                       chatCallback:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf chatTapped];
        } callCallback:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf callTapped];
        }];
    } else {
        self.providerContactView.nameLabel.text = providerName;
        self.providerContactView.avatarImageView.image = placeholderAvatar ?: PPSYSImage(@"person.crop.circle.fill");
        self.providerContactView.callButton.enabled = NO;
        self.providerContactView.chatButton.enabled = NO;
        self.providerContactView.callButton.alpha = 0.55;
        self.providerContactView.chatButton.alpha = 0.55;
    }

    self.providerMetaLabel.text = [self pp_providerMetaText];
    self.providerAboutLabel.text = [self pp_providerAboutText];
}

- (void)pp_reloadFacts {
    for (UIView *view in self.factsStackView.arrangedSubviews) {
        [self.factsStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    UIColor *neutralAccent = [AppPrimaryTextClr colorWithAlphaComponent:0.68];
    NSString *providerCountryText = [self pp_providerCountryText];

    UIView *rowOne = [self pp_factRowWithViews:@[
        [self pp_factTileWithIcon:@"sparkles"
                            title:kLang(@"service_view_category")
                            value:[self pp_categoryText]
                           accent:accentColor],
        [self pp_factTileWithIcon:@"pawprint.fill"
                            title:kLang(@"service_view_pet_kind")
                            value:[self pp_petKindText]
                           accent:[UIColor colorWithRed:0.32 green:0.66 blue:0.56 alpha:1.0]]
    ]];

    UIView *rowTwo = [self pp_factRowWithViews:@[
        [self pp_factTileWithIcon:@"calendar"
                            title:kLang(@"service_view_available_date")
                            value:[self pp_availableDateText]
                           accent:[UIColor colorWithRed:0.95 green:0.63 blue:0.20 alpha:1.0]],
        [self pp_factTileWithIcon:@"globe"
                            title:kLang(@"Country")
                            value:providerCountryText
                           accent:[UIColor colorWithRed:0.34 green:0.55 blue:0.89 alpha:1.0]]
    ]];

    UIView *rowThree = [self pp_factRowWithViews:@[
        [self pp_factTileWithIcon:@"clock"
                            title:kLang(@"service_view_posted_date")
                            value:[self pp_postedDateText]
                           accent:neutralAccent ?: UIColor.secondaryLabelColor]
    ]];

    [self.factsStackView addArrangedSubview:rowOne];
    [self.factsStackView addArrangedSubview:rowTwo];
    [self.factsStackView addArrangedSubview:rowThree];
}

- (void)pp_rebuildActions {
    for (UIView *view in self.actionsStackView.arrangedSubviews) {
        [self.actionsStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    self.shareActionButton = [self pp_actionTileButtonWithSymbol:@"square.and.arrow.up"
                                                           title:kLang(@"Share")
                                                            tint:AppPrimaryClr ?: UIColor.systemBlueColor
                                                         selector:@selector(shareTapped)];
    self.PhoneActionButton = [self pp_actionTileButtonWithSymbol:@"doc.on.doc"
                                                               title:kLang(@"service_view_copy_number")
                                                                tint:[UIColor colorWithRed:0.20 green:0.62 blue:0.58 alpha:1.0]
                                                             selector:@selector(copyNumberTapped)];

    [self.actionsStackView addArrangedSubview:self.shareActionButton];
    [self.actionsStackView addArrangedSubview:self.PhoneActionButton];

    if (![self pp_isOwnedByCurrentUser]) {
        self.reportActionButton = [self pp_actionTileButtonWithSymbol:@"flag.fill"
                                                                title:kLang(@"report_alert_title")
                                                                 tint:[UIColor systemRedColor]
                                                              selector:@selector(reportAdBTN)];
        [self.actionsStackView addArrangedSubview:self.reportActionButton];
    } else {
        self.reportActionButton = nil;
    }

    [self pp_updateActionAvailability];
}

#pragma mark - Content Helpers

- (NSArray<PPInfoPill *> *)pp_summaryPills {
    NSMutableArray<PPInfoPill *> *items = [NSMutableArray array];

    NSString *petKindText = [self pp_petKindText];
    if (petKindText.length > 0 && ![petKindText isEqualToString:kLang(@"Not specified")]) {
        [items addObject:[PPInfoPill itemWithIcon:@"pawprint.fill" text:petKindText]];
    }

    NSString *availableDateText = [self pp_availableDateText];
    if (availableDateText.length > 0 && ![availableDateText isEqualToString:kLang(@"Not specified")]) {
        [items addObject:[PPInfoPill itemWithIcon:@"calendar" text:availableDateText]];
    }

    NSString *postedDateText = [self pp_postedDateText];
    if (postedDateText.length > 0 && ![postedDateText isEqualToString:kLang(@"Not specified")]) {
        [items addObject:[PPInfoPill itemWithIcon:@"clock" text:postedDateText]];
    }

    return items.copy;
}

- (NSString *)pp_serviceTitle {
    return self.service.title.length > 0 ? self.service.title : kLang(@"service_view_default_title");
}

- (NSString *)pp_categoryText {
    return self.service.category.length > 0 ? self.service.category : kLang(@"not available");
}

- (NSString *)pp_petKindText {
    if (self.service.petMainKindID > 0) {
        MainKindsModel *kind = [MainKindsModel mainKindModelForID:self.service.petMainKindID];
        if (kind.KindName.length > 0) {
            return kind.KindName;
        }
    }
    return kLang(@"Not specified");
}

- (NSString *)pp_availableDateText {
    if ([self.service.availableDate isKindOfClass:[NSDate class]]) {
        return [GM formattedDate:self.service.availableDate];
    }
    return kLang(@"Not specified");
}

- (NSString *)pp_postedDateText {
    NSDate *postedDate = self.service.timestamp ?: self.service.availableDate;
    if ([postedDate isKindOfClass:[NSDate class]]) {
        return [GM formattedDate:postedDate];
    }
    return kLang(@"Not specified");
}

- (NSString *)pp_providerDisplayName {
    NSString *providerName = @"";
    if ([self.ownerModel respondsToSelector:@selector(PPBestDisplayName)]) {
        providerName = [self.ownerModel PPBestDisplayName];
    }
    if (providerName.length == 0) {
        providerName = self.ownerModel.UserName ?: @"";
    }
    if (providerName.length == 0 && self.service.serviceOwnerID.length > 0) {
        return kLang(@"service_view_owner_pending");
    }
    if (providerName.length == 0) {
        return kLang(@"service_view_owner");
    }
    return providerName;
}

- (NSString *)pp_providerMetaText {
    if (!self.ownerModel) {
        return kLang(@"service_view_provider_loading");
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [parts addObject:(self.ownerModel.isVerified
                      ? kLang(@"service_view_provider_verified")
                      : kLang(@"service_view_provider_unverified"))];

    NSDate *memberDate = self.ownerModel.loginDate ?: self.ownerModel.updatedAt;
    if ([memberDate isKindOfClass:[NSDate class]]) {
        NSString *memberSinceText = [NSString stringWithFormat:@"%@ %@",
                                     kLang(@"service_view_member_since"),
                                     [GM formattedDate:memberDate]];
        [parts addObject:memberSinceText];
    }

    if (self.ownerModel.MobileNo.length > 0) {
        [parts addObject:kLang(@"service_view_contact_ready")];
    } else {
        [parts addObject:kLang(@"service_view_contact_limited")];
    }

    NSString *countryText = [self pp_providerCountryText];
    if (countryText.length > 0 && ![countryText isEqualToString:kLang(@"Not specified")]) {
        [parts addObject:countryText];
    }

    return [parts componentsJoinedByString:@" • "];
}

- (NSString *)pp_providerAboutText {
    if (self.ownerModel.UserAbout.length > 0) {
        return self.ownerModel.UserAbout;
    }
    if (!self.ownerModel) {
        return kLang(@"service_view_contact_loading");
    }
    return kLang(@"service_view_provider_about_empty");
}

- (NSString *)pp_providerCountryText {
    if (!self.ownerModel || self.ownerModel.CountryID <= 0) {
        return kLang(@"Not specified");
    }

    NSString *countryName = [CitiesManager.shared countryNameForID:self.ownerModel.CountryID];
    return countryName.length > 0 ? countryName : kLang(@"Not specified");
}

- (NSString *)pp_priceText {
    NSString *formattedPrice = [GM formatPrice:@(self.service.price) currencyCode:kLang(@"Rials")];
    if (formattedPrice.length > 0) {
        return formattedPrice;
    }
    return [NSString stringWithFormat:@"%.2f %@", self.service.price, kLang(@"Rials")];
}

- (BOOL)pp_isOwnedByCurrentUser {
    NSString *currentUID = [self trackingUserID];
    if (currentUID.length == 0 || self.service.serviceOwnerID.length == 0) {
        return NO;
    }
    return [currentUID isEqualToString:self.service.serviceOwnerID];
}

- (void)pp_updateActionAvailability {
    BOOL canCopyNumber = self.ownerModel.MobileNo.length > 0;
    self.PhoneActionButton.enabled = canCopyNumber;
    self.PhoneActionButton.alpha = canCopyNumber ? 1.0 : 0.58;
}

#pragma mark - Motion

- (void)pp_prepareEntranceState {
    NSArray<UIView *> *animatedSections = @[
        self.providerSectionView,
        self.factsSectionView,
        self.descriptionSectionView,
        self.actionsSectionView
    ];

    for (UIView *view in animatedSections) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 18.0);
    }
}

- (void)pp_beginEntranceAnimationsIfNeeded {
    if (self.didAnimateEntrance) {
        return;
    }
    self.didAnimateEntrance = YES;

    [self.titleView animatePillsIn];

    NSArray<UIView *> *animatedSections = @[
        self.providerSectionView,
        self.factsSectionView,
        self.descriptionSectionView,
        self.actionsSectionView
    ];

    [animatedSections enumerateObjectsUsingBlock:^(UIView * _Nonnull sectionView, NSUInteger idx, BOOL * _Nonnull stop) {
        [UIView animateWithDuration:0.46
                              delay:0.08 + (0.06 * idx)
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.18
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            sectionView.alpha = 1.0;
            sectionView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

#pragma mark - Actions

- (void)closeTapped {
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];

    if (self.presentingViewController ||
        (self.navigationController.presentingViewController &&
         self.navigationController.viewControllers.firstObject == self)) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    [self.navigationController popViewControllerAnimated:YES];
}

- (void)shareTapped {
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"%@: %@",
                      kLang(@"service_view_share_title"),
                      [self pp_serviceTitle]]];
    [lines addObject:[NSString stringWithFormat:@"%@: %@",
                      kLang(@"service_view_category"),
                      [self pp_categoryText]]];
    [lines addObject:[NSString stringWithFormat:@"%@: %@",
                      kLang(@"service_view_owner"),
                      [self pp_providerDisplayName]]];
    [lines addObject:[NSString stringWithFormat:@"%@: %@",
                      kLang(@"Price"),
                      [self pp_priceText]]];

    if (self.service.desc.length > 0) {
        [lines addObject:self.service.desc];
    }

    UIActivityViewController *activityVC =
        [[UIActivityViewController alloc] initWithActivityItems:@[[lines componentsJoinedByString:@"\n"]]
                                          applicationActivities:nil];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.shareActionButton ?: self.view;
        activityVC.popoverPresentationController.sourceRect = self.shareActionButton
            ? self.shareActionButton.bounds
            : CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1.0, 1.0);
        activityVC.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    [self presentViewController:activityVC animated:YES completion:nil];
    [self trackServiceInteraction:PPItemInteractionTypeShare];
}

- (void)copyNumberTapped {
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];

    if (![self ensureSignedInForContactAction]) {
        return;
    }

    [self loadOwnerIfNeeded];
    if (!self.ownerModel) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"service_view_provider_title")
                         subtitle:kLang(@"service_view_contact_loading")];
        return;
    }

    if (self.ownerModel.MobileNo.length == 0) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"No Number")
                         subtitle:kLang(@"service_view_copy_number_missing")];
        return;
    }

    UIPasteboard.generalPasteboard.string = self.ownerModel.MobileNo;
    [PPAlertHelper showSuccessIn:self
                           title:kLang(@"service_view_copy_number")
                        subtitle:kLang(@"service_view_copy_number_success")];
}

- (void)callTapped {
    if (![self ensureSignedInForContactAction]) {
        return;
    }

    [self loadOwnerIfNeeded];
    if (!self.ownerModel) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"service_view_provider_title")
                         subtitle:kLang(@"service_view_contact_loading")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    if (self.ownerModel.MobileNo.length == 0) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"No Number")
                         subtitle:kLang(@"service_view_copy_number_missing")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [AppClasses callPhoneNumber:self.ownerModel.MobileNo fromViewController:self];
    [self trackServiceInteraction:PPItemInteractionTypeCall];
}

- (void)chatTapped {
    if (![self ensureSignedInForContactAction]) {
        return;
    }

    [self loadOwnerIfNeeded];
    if (!self.ownerModel) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"error")
                         subtitle:kLang(@"service_view_contact_loading")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [GM chatWith:self.ownerModel FromController:self];
    [self trackServiceInteraction:PPItemInteractionTypeChat];
}

#pragma mark - Owner

- (void)loadOwnerIfNeeded {
    if (self.ownerModel || self.isResolvingOwner || self.service.serviceOwnerID.length == 0) {
        return;
    }

    self.isResolvingOwner = YES;
    __weak typeof(self) weakSelf = self;
    [UsrMgr getOtherUserModelFromFirestoreWithUID:self.service.serviceOwnerID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            strongSelf.isResolvingOwner = NO;
            if (error || !user) {
                [strongSelf pp_updateProviderSection];
                return;
            }

            strongSelf.ownerModel = user;
            [strongSelf applyModelContent];
        });
    }];
}

- (BOOL)ensureSignedInForContactAction {
    if (UserManager.sharedManager.isUserLoggedIn) {
        return YES;
    }

    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
    [UserManager showPromptOnTopController];
    return NO;
}

#pragma mark - Tracking

- (NSString *)trackingUserID {
    NSString *userID = [UserManager sharedManager].currentUser.ID;
    if (userID.length > 0) {
        return userID;
    }
    if (PPCurrentFIRAuthUser.uid.length > 0) {
        return PPCurrentFIRAuthUser.uid;
    }
    return nil;
}

- (void)trackServiceInteraction:(PPItemInteractionType)interaction {
    if (self.service.serviceID.length == 0) {
        return;
    }

    [PetAdManager trackInteraction:interaction
                         forItemID:self.service.serviceID
                        collection:@"serviceOffers"
                            userID:[self trackingUserID]
                        completion:nil];
}

#pragma mark - UI Helpers

- (CGFloat)pp_heroHeight {
    CGFloat width = CGRectGetWidth(self.view.bounds);
    if (width <= 0.0) {
        width = UIScreen.mainScreen.bounds.size.width;
    }
    return MIN(MAX(width * 0.90, 330.0), 430.0);
}

- (UIView *)pp_surfaceSectionView {
    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = PPBackgroundColorForIOS26([AppForgroundColr colorWithAlphaComponent:0.96]);
    surface.layer.cornerRadius = PPServiceViewerSurfaceRadius;
    surface.layer.borderWidth = 1.0;
    surface.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06].CGColor;
    surface.layer.shadowColor = UIColor.blackColor.CGColor;
    surface.layer.shadowOpacity = 0.08f;
    surface.layer.shadowRadius = 18.0f;
    surface.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    if (@available(iOS 13.0, *)) {
        surface.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return surface;
}

- (UILabel *)pp_sectionTitleLabelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM boldFontWithSize:20];
    label.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.text = text;
    return label;
}

- (UILabel *)pp_badgeLabelWithBackgroundColor:(UIColor *)backgroundColor textColor:(UIColor *)textColor {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM boldFontWithSize:13];
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = textColor;
    label.backgroundColor = backgroundColor;
    label.layer.cornerRadius = 16.0;
    label.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        label.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return label;
}

- (UIButton *)pp_topChromeButtonWithSystemName:(NSString *)systemName selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    UIImage *icon = [[UIImage systemImageNamed:systemName] imageByApplyingSymbolConfiguration:configuration];
    [button setImage:icon forState:UIControlStateNormal];
    button.tintColor = AppPrimaryTextClr ?: UIColor.labelColor;
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.86];
    button.layer.cornerRadius = 20.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.14].CGColor;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = 0.08f;
    button.layer.shadowRadius = 14.0f;
    button.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIView *)pp_factRowWithViews:(NSArray<UIView *> *)views {
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:views];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentFill;
    row.distribution = UIStackViewDistributionFillEqually;
    row.spacing = 12.0;
    return row;
}

- (UIView *)pp_factTileWithIcon:(NSString *)iconName
                          title:(NSString *)title
                          value:(NSString *)value
                         accent:(UIColor *)accentColor {
    UIView *tile = [[UIView alloc] init];
    tile.translatesAutoresizingMaskIntoConstraints = NO;
    tile.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    tile.layer.cornerRadius = 22.0;
    tile.layer.borderWidth = 1.0;
    tile.layer.borderColor = [[accentColor colorWithAlphaComponent:0.18] CGColor];
    if (@available(iOS 13.0, *)) {
        tile.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *iconShell = [[UIView alloc] init];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.backgroundColor = [accentColor colorWithAlphaComponent:0.16];
    iconShell.layer.cornerRadius = 15.0;
    if (@available(iOS 13.0, *)) {
        iconShell.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    iconView.image = [[UIImage systemImageNamed:iconName] imageByApplyingSymbolConfiguration:configuration];
    iconView.tintColor = accentColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM MidFontWithSize:12];
    titleLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.64];
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.text = title;
    titleLabel.numberOfLines = 1;

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.font = [GM boldFontWithSize:15];
    valueLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    valueLabel.numberOfLines = 2;
    valueLabel.text = value;

    [tile addSubview:iconShell];
    [iconShell addSubview:iconView];
    [tile addSubview:titleLabel];
    [tile addSubview:valueLabel];

    [NSLayoutConstraint activateConstraints:@[
        [tile.heightAnchor constraintGreaterThanOrEqualToConstant:110.0],

        [iconShell.topAnchor constraintEqualToAnchor:tile.topAnchor constant:14.0],
        [iconShell.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor constant:14.0],
        [iconShell.widthAnchor constraintEqualToConstant:30.0],
        [iconShell.heightAnchor constraintEqualToConstant:30.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:15.0],
        [iconView.heightAnchor constraintEqualToConstant:15.0],

        [titleLabel.topAnchor constraintEqualToAnchor:iconShell.bottomAnchor constant:12.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor constant:14.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor constant:-14.0],

        [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:5.0],
        [valueLabel.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor constant:14.0],
        [valueLabel.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor constant:-14.0],
        [valueLabel.bottomAnchor constraintLessThanOrEqualToAnchor:tile.bottomAnchor constant:-14.0]
    ]];

    return tile;
}

- (UIButton *)pp_actionTileButtonWithSymbol:(NSString *)symbol
                                      title:(NSString *)title
                                       tint:(UIColor *)tintColor
                                    selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [tintColor colorWithAlphaComponent:0.12];
    button.layer.cornerRadius = 24.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [[tintColor colorWithAlphaComponent:0.18] CGColor];
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = 0.04f;
    button.layer.shadowRadius = 10.0f;
    button.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *iconShell = [[UIView alloc] init];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.userInteractionEnabled = NO;
    iconShell.backgroundColor = [tintColor colorWithAlphaComponent:0.18];
    iconShell.layer.cornerRadius = 18.0;
    if (@available(iOS 13.0, *)) {
        iconShell.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.userInteractionEnabled = NO;
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    iconView.image = [[UIImage systemImageNamed:symbol] imageByApplyingSymbolConfiguration:configuration];
    iconView.tintColor = tintColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.userInteractionEnabled = NO;
    titleLabel.text = title;
    titleLabel.font = [GM boldFontWithSize:13];
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[iconShell, titleLabel]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.userInteractionEnabled = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10.0;
    stack.alignment = UIStackViewAlignmentCenter;

    [button addSubview:stack];
    [iconShell addSubview:iconView];

    [NSLayoutConstraint activateConstraints:@[
        [button.heightAnchor constraintEqualToConstant:104.0],

        [iconShell.widthAnchor constraintEqualToConstant:36.0],
        [iconShell.heightAnchor constraintEqualToConstant:36.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:16.0],
        [iconView.heightAnchor constraintEqualToConstant:16.0],

        [stack.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:button.leadingAnchor constant:8.0],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:button.trailingAnchor constant:-8.0]
    ]];

    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

#pragma mark - Reporting

- (void)reportAdBTN {
    if (![UserManager sharedManager].isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    if ([self pp_isOwnedByCurrentUser]) {
        return;
    }

    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:kLang(@"report_alert_title")
                         message:kLang(@"report_alert_message")
                  preferredStyle:UIAlertControllerStyleActionSheet];

    NSDictionary *reasons = @{
        @"spam": kLang(@"report_reason_spam"),
        @"inappropriate_content": kLang(@"report_reason_inappropriate"),
        @"scam_fraud": kLang(@"report_reason_fraud"),
        @"wrong_category": kLang(@"report_reason_wrong_category"),
        @"other": kLang(@"report_reason_other")
    };

    for (NSString *code in @[@"inappropriate_content", @"scam_fraud", @"wrong_category", @"spam", @"other"]) {
        [sheet addAction:[UIAlertAction actionWithTitle:reasons[code]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction * _Nonnull action) {
            [self submitServiceReportWithReasonCode:code];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = self.reportActionButton ?: self.view;
        sheet.popoverPresentationController.sourceRect = self.reportActionButton
            ? self.reportActionButton.bounds
            : CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1.0, 1.0);
        sheet.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)submitServiceReportWithReasonCode:(NSString *)reasonCode {
    NSString *uid = [self trackingUserID];
    if (uid.length == 0 || self.service.serviceID.length == 0) {
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *contentRef = [[db collectionWithPath:@"serviceOffers"]
                                        documentWithPath:self.service.serviceID];

    [contentRef updateData:@{
        @"reportedBy": [FIRFieldValue fieldValueForArrayUnion:@[uid]],
        @"reportCount": [FIRFieldValue fieldValueForIntegerIncrement:1],
        @"lastReportedAt": [FIRFieldValue fieldValueForServerTimestamp]
    } completion:nil];

    NSString *reportID = [NSString stringWithFormat:@"%@_%@", self.service.serviceID, uid];
    FIRDocumentReference *reportRef = [[db collectionWithPath:@"reports"] documentWithPath:reportID];

    NSDictionary *reportData = @{
        @"reportId": reportID,
        @"contentId": self.service.serviceID,
        @"contentType": @"serviceOffer",
        @"collection": @"serviceOffers",
        @"reason": reasonCode,
        @"reporterUid": uid,
        @"reportedOwnerUid": self.service.serviceOwnerID ?: @"",
        @"status": @"pending",
        @"platform": @"ios",
        @"createdAt": [FIRFieldValue fieldValueForServerTimestamp],
        @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
    };

    [reportRef setData:reportData merge:YES completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [PPAlertHelper showInfoIn:self
                                    title:kLang(@"error")
                                 subtitle:kLang(@"report_submit_failed_message")];
            } else {
                [PPAlertHelper showSuccessIn:self
                                       title:kLang(@"report_submit_title")
                                    subtitle:kLang(@"report_submit_message")];
            }
        });
    }];
}

@end
