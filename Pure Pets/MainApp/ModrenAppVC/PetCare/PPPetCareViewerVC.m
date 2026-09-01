//
//  PPPetCareViewerVC.m
//  Pure Pets
//
//  Reimagined from first principles — NextGen V6 Flagship Veterinary Medicine Experience
//

#import "PPPetCareViewerVC.h"
#import "VetManager.h"
#import "PPImageLoaderManager.h"
#import "PPBottomBar.h"
#import "CartManager.h"
#import "UIViewController+PPBottomSurface.h"
#import "PPNetworkRetryHelper.h"
#import "PPAlertHelper.h"
#import "PPHUD.h"
#import <Pure_Pets-Swift.h>
#import "PPFunc.h"
#import "PPRootTabBarController.h"
#import "PPNavigationController.h"

static CGFloat const PPPetCareViewerSideInset = 16.0;
static CGFloat const PPPetCareViewerSectionSpacing = 16.0;
static CGFloat const PPPetCareViewerSurfaceRadius = 30.0;
static CGFloat const PPPetCareViewerCardRadius = 24.0;
static CGFloat const PPPetCareViewerBottomBarBase = 108.0;
static NSTimeInterval const PPPetCareViewerReducedMotionDuration = 0.18;

typedef NS_ENUM(NSInteger, PPPetWeightCategory) {
    PPPetWeightCategorySmall = 0,    // < 5 kg
    PPPetWeightCategoryMedium,       // 5 - 15 kg
    PPPetWeightCategoryLarge,        // 15 - 30 kg
    PPPetWeightCategoryXLarge        // > 30 kg
};

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
    return AppPrimaryClr ?: [UIColor colorWithRed:0.08 green:0.68 blue:0.58 alpha:1.0];
}

static UIColor *PPPetCareViewerWarmAccentColor(void)
{
    return [UIColor colorWithRed:0.98 green:0.62 blue:0.28 alpha:1.0];
}

static UIColor *PPPetCareViewerIndigoAccentColor(void)
{
    return [UIColor colorWithRed:0.38 green:0.42 blue:0.92 alpha:1.0];
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
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark ? [UIColor colorWithWhite:0.12 alpha:0.88] : [UIColor colorWithWhite:1.0 alpha:0.92];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.92];
}

static UIColor *PPPetCareViewerElevatedSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark ? [UIColor colorWithWhite:0.14 alpha:0.96] : [UIColor colorWithWhite:1.0 alpha:0.98];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.98];
}

static UIColor *PPPetCareViewerBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark ? [UIColor colorWithWhite:1.0 alpha:0.12] : [UIColor colorWithWhite:0.08 alpha:0.07];
        }];
    }
    return [UIColor colorWithWhite:0.08 alpha:0.07];
}

static UIColor *PPPetCareViewerQuietTileColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark ? [UIColor colorWithWhite:1.0 alpha:0.05] : [UIColor colorWithWhite:0.0 alpha:0.028];
        }];
    }
    return [UIColor colorWithWhite:0.0 alpha:0.028];
}

@interface PPPetCareViewerVC ()
@property (nonatomic, strong) VetMedicineModel *medicine;
@property (nonatomic, copy) NSString *mainKindName;
@property (nonatomic, assign) PPPetWeightCategory selectedWeightCategory;

// Ambient Atmosphere
@property (nonatomic, strong) UIView *backgroundGlowTopView;
@property (nonatomic, strong) UIView *backgroundGlowMiddleView;
@property (nonatomic, strong) UIView *backgroundGlowBottomView;

// Scaffold
@property (nonatomic, strong) BBCartBottomBar *bottomBar;
@property (nonatomic, strong) NSLayoutConstraint *bottomBarHeightConstraint;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

// Hero Stage
@property (nonatomic, strong) UIView *heroStageView;
@property (nonatomic, strong) UIView *heroArtworkChamberView;
@property (nonatomic, strong) CAGradientLayer *heroChamberGradientLayer;
@property (nonatomic, strong) UIImageView *heroImageView;
@property (nonatomic, strong) PPHomeInsetLabel *heroCertBadgeLabel;
@property (nonatomic, strong) PPHomeInsetLabel *heroStockStatusBadgeLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *categorySubtitleLabel;
@property (nonatomic, strong) UIStackView *speciesPillsStackView;
@property (nonatomic, strong) UIView *pricePlateView;
@property (nonatomic, strong) UILabel *pricePlateLabel;
@property (nonatomic, strong) UILabel *pricePlateCurrencyLabel;
@property (nonatomic, strong) NSLayoutConstraint *heroArtworkHeightConstraint;

// Clinical Bento Matrix (2x2)
@property (nonatomic, strong) UIView *bentoMatrixCardView;
@property (nonatomic, strong) UILabel *bentoMatrixTitleLabel;
@property (nonatomic, strong) UIStackView *bentoGridStackView;

// Smart Dosage Calculator
@property (nonatomic, strong) UIView *dosageCalculatorCardView;
@property (nonatomic, strong) UILabel *dosageTitleLabel;
@property (nonatomic, strong) UILabel *dosageSubtitleLabel;
@property (nonatomic, strong) UIStackView *dosageWeightButtonsStackView;
@property (nonatomic, strong) NSMutableArray<UIButton *> *weightSegmentButtons;
@property (nonatomic, strong) UIView *dosageResultContainerView;
@property (nonatomic, strong) UILabel *dosageResultValueLabel;
@property (nonatomic, strong) UILabel *dosageDisclaimerLabel;

// Clinical Indications & Highlights
@property (nonatomic, strong) UIView *indicationsCardView;
@property (nonatomic, strong) UILabel *indicationsTitleLabel;
@property (nonatomic, strong) UIStackView *indicationsStackView;

// Product Story / Full Description
@property (nonatomic, strong) UIView *descriptionCardView;
@property (nonatomic, strong) UILabel *descriptionTitleLabel;
@property (nonatomic, strong) UILabel *descriptionBodyLabel;

// Direct Vet Consultation Action Card
@property (nonatomic, strong) UIView *vetConsultCardView;
@property (nonatomic, strong) UIImageView *vetConsultIconView;
@property (nonatomic, strong) UILabel *vetConsultTitleLabel;
@property (nonatomic, strong) UILabel *vetConsultBodyLabel;
@property (nonatomic, strong) UIButton *vetConsultActionButton;

// Motion flags
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) BOOL didStartGlowAnimation;

@end

@implementation PPPetCareViewerVC

- (PPBottomSurfaceKind)pp_preferredBottomSurfaceKind
{
    return PPBottomSurfaceKindViewerCartBottomBar;
}

- (instancetype)initWithMedicine:(VetMedicineModel *)medicine
                    mainKindName:(NSString *)mainKindName
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) {
        return nil;
    }
    _medicine = medicine;
    _mainKindName = PPPetCareViewerSafeString(mainKindName);
    _selectedWeightCategory = PPPetWeightCategoryMedium;
    _weightSegmentButtons = [NSMutableArray array];
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
    [self pp_syncBottomBarState];
    [self pp_applyTheme];
    [self pp_prepareEntranceState];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleCartUpdated:)
                                                 name:kCartUpdatedNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto
                      button:nil
                       title:nil
                    showBack:YES];
    self.navigationItem.title = PPPetCareViewerLocalized(@"pet_care_medicines", @"Medicines");
    [self pp_syncBottomBarState];
    [self pp_applyTheme];
    [self pp_applyBottomSurfaceAnimated:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_beginEntranceAnimationIfNeeded];
    [self pp_beginAmbientGlowAnimationIfNeeded];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self pp_updateViewportLayout];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.heroChamberGradientLayer.frame = self.heroArtworkChamberView.bounds;
    self.heroChamberGradientLayer.cornerRadius = self.heroArtworkChamberView.layer.cornerRadius;

    self.heroStageView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.heroStageView.bounds
                                                                     cornerRadius:self.heroStageView.layer.cornerRadius].CGPath;
    self.bentoMatrixCardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bentoMatrixCardView.bounds
                                                                           cornerRadius:self.bentoMatrixCardView.layer.cornerRadius].CGPath;
    self.dosageCalculatorCardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.dosageCalculatorCardView.bounds
                                                                                cornerRadius:self.dosageCalculatorCardView.layer.cornerRadius].CGPath;
    self.indicationsCardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.indicationsCardView.bounds
                                                                           cornerRadius:self.indicationsCardView.layer.cornerRadius].CGPath;
    self.descriptionCardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.descriptionCardView.bounds
                                                                           cornerRadius:self.descriptionCardView.layer.cornerRadius].CGPath;
    self.vetConsultCardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.vetConsultCardView.bounds
                                                                          cornerRadius:self.vetConsultCardView.layer.cornerRadius].CGPath;

    if (self.view.window) {
        [self pp_beginEntranceAnimationIfNeeded];
        [self pp_beginAmbientGlowAnimationIfNeeded];
    }
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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.heroImageView];
}

#pragma mark - Layout

- (void)pp_setupLayout
{
    [self pp_buildBackgroundAtmosphere];
    [self pp_buildScaffold];
    [self pp_buildHeroStageSection];
    [self pp_buildBentoMatrixSection];
    [self pp_buildDosageCalculatorSection];
    [self pp_buildIndicationsSection];
    [self pp_buildDescriptionSection];
    [self pp_buildVetConsultSection];
}

- (void)pp_buildBackgroundAtmosphere
{
    self.backgroundGlowTopView = [self pp_backgroundGlowViewWithRadius:148.0];
    self.backgroundGlowMiddleView = [self pp_backgroundGlowViewWithRadius:120.0];
    self.backgroundGlowBottomView = [self pp_backgroundGlowViewWithRadius:180.0];

    [self.view addSubview:self.backgroundGlowTopView];
    [self.view addSubview:self.backgroundGlowMiddleView];
    [self.view addSubview:self.backgroundGlowBottomView];

    [NSLayoutConstraint activateConstraints:@[
        [self.backgroundGlowTopView.widthAnchor constraintEqualToConstant:296.0],
        [self.backgroundGlowTopView.heightAnchor constraintEqualToConstant:296.0],
        [self.backgroundGlowTopView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-90.0],
        [self.backgroundGlowTopView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:110.0],

        [self.backgroundGlowMiddleView.widthAnchor constraintEqualToConstant:240.0],
        [self.backgroundGlowMiddleView.heightAnchor constraintEqualToConstant:240.0],
        [self.backgroundGlowMiddleView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:280.0],
        [self.backgroundGlowMiddleView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-110.0],

        [self.backgroundGlowBottomView.widthAnchor constraintEqualToConstant:360.0],
        [self.backgroundGlowBottomView.heightAnchor constraintEqualToConstant:360.0],
        [self.backgroundGlowBottomView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-160.0],
        [self.backgroundGlowBottomView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:130.0]
    ]];
}

- (UIView *)pp_backgroundGlowViewWithRadius:(CGFloat)radius
{
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.userInteractionEnabled = NO;
    view.alpha = 0.0;
    view.layer.cornerRadius = radius;
    view.layer.shadowRadius = 72.0;
    view.layer.shadowOpacity = 0.32;
    view.layer.shadowOffset = CGSizeZero;
    view.clipsToBounds = NO;
    return view;
}

- (void)pp_buildScaffold
{
    self.bottomBar = [[BBCartBottomBar alloc] init];
    self.bottomBar.presentationStyle = BBCartBottomBarPresentationStyleMedicineViewer;
    self.bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.bottomBar];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.backgroundColor = UIColor.clearColor;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.scrollView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    if (@available(iOS 11.0, *)) {
        self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self.scrollView addSubview:self.contentView];

    UILayoutGuide *contentGuide;
    UILayoutGuide *frameGuide;
    if (@available(iOS 11.0, *)) {
        contentGuide = self.scrollView.contentLayoutGuide;
        frameGuide = self.scrollView.frameLayoutGuide;
    } else {
        contentGuide = (id)self.scrollView;
        frameGuide = (id)self.scrollView;
    }

    self.bottomBarHeightConstraint = [self.bottomBar.heightAnchor constraintEqualToConstant:PPPetCareViewerBottomBarBase];

    [NSLayoutConstraint activateConstraints:@[
        [self.bottomBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        self.bottomBarHeightConstraint,

        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:contentGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:contentGuide.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:frameGuide.widthAnchor]
    ]];

    [self.view bringSubviewToFront:self.bottomBar];

    CGFloat itemAmount = MAX(self.medicine.price, 0.0);
    __weak typeof(self) weakSelf = self;
    __weak typeof(self.bottomBar) weakBottomBar = self.bottomBar;
    self.bottomBar.itemAmount = itemAmount;
    self.bottomBar.onAddToCart = ^(NSInteger quantity) {
        __strong typeof(weakSelf) self = weakSelf;
        [self pp_addToCartButtonTapped:quantity];
    };
    self.bottomBar.onQuantityChanged = ^(NSInteger quantity) {
        __strong typeof(weakBottomBar) bottomBar = weakBottomBar;
        CGFloat safeAmount = MAX(itemAmount, 0.0);
        bottomBar.totalAmount = MAX(quantity, 1) * safeAmount;
    };
    [self.bottomBar setInitItemAmount:itemAmount];
    self.bottomBar.cartItemquantity = 1;
    [self.bottomBar updateQuantityUI];
    [self.bottomBar.favButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [self.bottomBar.favButton addTarget:self action:@selector(pp_shareTapped) forControlEvents:UIControlEventTouchUpInside];
    self.bottomBar.favButton.accessibilityLabel = PPPetCareViewerLocalized(@"pet_care_viewer_share", @"Share");
}

- (void)pp_buildHeroStageSection
{
    self.heroStageView = [self pp_surfaceSectionView];
    self.heroStageView.backgroundColor = PPPetCareViewerElevatedSurfaceColor();
    self.heroStageView.layer.cornerRadius = PPPetCareViewerSurfaceRadius;
    self.heroStageView.layer.shadowOpacity = 0.14;
    self.heroStageView.layer.shadowRadius = 32.0;
    self.heroStageView.layer.shadowOffset = CGSizeMake(0.0, 16.0);
    [self.contentView addSubview:self.heroStageView];

    // Artwork Chamber
    self.heroArtworkChamberView = [[UIView alloc] init];
    self.heroArtworkChamberView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroArtworkChamberView.clipsToBounds = YES;
    self.heroArtworkChamberView.layer.cornerRadius = PPPetCareViewerCardRadius;
    self.heroArtworkChamberView.layer.borderWidth = 0.9;
    if (@available(iOS 13.0, *)) {
        self.heroArtworkChamberView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroStageView addSubview:self.heroArtworkChamberView];

    self.heroChamberGradientLayer = [CAGradientLayer layer];
    self.heroChamberGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.heroChamberGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [self.heroArtworkChamberView.layer addSublayer:self.heroChamberGradientLayer];

    // Product Image
    self.heroImageView = [[UIImageView alloc] init];
    self.heroImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.heroImageView.clipsToBounds = YES;
    self.heroImageView.layer.shadowRadius = 24.0;
    self.heroImageView.layer.shadowOpacity = 0.22;
    self.heroImageView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    [self.heroArtworkChamberView addSubview:self.heroImageView];

    // Top Chamber Badges (Certified Grade + In Stock Aura)
    self.heroCertBadgeLabel = [self pp_pillLabelWithFont:[GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold]];
    self.heroCertBadgeLabel.text = [NSString stringWithFormat:@"✓ %@", PPPetCareViewerLocalized(@"pet_care_viewer_certified_badge", @"Certified Veterinary Medicine")];
    [self.heroArtworkChamberView addSubview:self.heroCertBadgeLabel];

    self.heroStockStatusBadgeLabel = [self pp_pillLabelWithFont:[GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold]];
    [self.heroArtworkChamberView addSubview:self.heroStockStatusBadgeLabel];

    // Header Content (Title + Category Subtitle)
    self.titleLabel = [self pp_labelWithFont:[GM BlackFontWithSize:26.0] ?: [UIFont systemFontOfSize:24.0 weight:UIFontWeightBold]
                                       color:PPPetCareViewerTextColor()
                                       lines:2];
    self.titleLabel.minimumScaleFactor = 0.82;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    [self.heroStageView addSubview:self.titleLabel];

    self.categorySubtitleLabel = [self pp_labelWithFont:[GM MidFontWithSize:14.5] ?: [UIFont systemFontOfSize:14.5 weight:UIFontWeightMedium]
                                                  color:PPPetCareViewerSecondaryTextColor()
                                                  lines:2];
    [self.heroStageView addSubview:self.categorySubtitleLabel];

    // Species Target Badges (🐶 · 🐱 · 🦜)
    self.speciesPillsStackView = [[UIStackView alloc] init];
    self.speciesPillsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.speciesPillsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.speciesPillsStackView.alignment = UIStackViewAlignmentLeading;
    self.speciesPillsStackView.spacing = 8.0;
    [self.heroStageView addSubview:self.speciesPillsStackView];

    // Price Hero Plate
    self.pricePlateView = [[UIView alloc] init];
    self.pricePlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.pricePlateView.layer.cornerRadius = 18.0;
    self.pricePlateView.layer.borderWidth = 0.9;
    self.pricePlateView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.pricePlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroStageView addSubview:self.pricePlateView];

    self.pricePlateLabel = [self pp_labelWithFont:[GM BlackFontWithSize:24.0] ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold]
                                            color:PPPetCareViewerAccentColor()
                                            lines:1];
    [self.pricePlateView addSubview:self.pricePlateLabel];

    self.pricePlateCurrencyLabel = [self pp_labelWithFont:[GM boldFontWithSize:12.5] ?: [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold]
                                                    color:PPPetCareViewerSecondaryTextColor()
                                                    lines:1];
    [self.pricePlateView addSubview:self.pricePlateCurrencyLabel];

    self.heroArtworkHeightConstraint = [self.heroArtworkChamberView.heightAnchor constraintEqualToConstant:240.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroStageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12.0],
        [self.heroStageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareViewerSideInset],
        [self.heroStageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareViewerSideInset],

        [self.heroArtworkChamberView.topAnchor constraintEqualToAnchor:self.heroStageView.topAnchor constant:16.0],
        [self.heroArtworkChamberView.leadingAnchor constraintEqualToAnchor:self.heroStageView.leadingAnchor constant:16.0],
        [self.heroArtworkChamberView.trailingAnchor constraintEqualToAnchor:self.heroStageView.trailingAnchor constant:-16.0],
        self.heroArtworkHeightConstraint,

        [self.heroImageView.centerXAnchor constraintEqualToAnchor:self.heroArtworkChamberView.centerXAnchor],
        [self.heroImageView.centerYAnchor constraintEqualToAnchor:self.heroArtworkChamberView.centerYAnchor constant:12.0],
        [self.heroImageView.widthAnchor constraintLessThanOrEqualToAnchor:self.heroArtworkChamberView.widthAnchor multiplier:0.68],
        [self.heroImageView.heightAnchor constraintLessThanOrEqualToAnchor:self.heroArtworkChamberView.heightAnchor multiplier:0.75],
        [self.heroImageView.widthAnchor constraintGreaterThanOrEqualToConstant:140.0],
        [self.heroImageView.heightAnchor constraintGreaterThanOrEqualToConstant:140.0],

        [self.heroCertBadgeLabel.topAnchor constraintEqualToAnchor:self.heroArtworkChamberView.topAnchor constant:14.0],
        [self.heroCertBadgeLabel.leadingAnchor constraintEqualToAnchor:self.heroArtworkChamberView.leadingAnchor constant:14.0],
        [self.heroCertBadgeLabel.heightAnchor constraintGreaterThanOrEqualToConstant:28.0],

        [self.heroStockStatusBadgeLabel.topAnchor constraintEqualToAnchor:self.heroArtworkChamberView.topAnchor constant:14.0],
        [self.heroStockStatusBadgeLabel.trailingAnchor constraintEqualToAnchor:self.heroArtworkChamberView.trailingAnchor constant:-14.0],
        [self.heroStockStatusBadgeLabel.heightAnchor constraintGreaterThanOrEqualToConstant:28.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.heroArtworkChamberView.bottomAnchor constant:18.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.heroStageView.leadingAnchor constant:20.0],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.heroStageView.trailingAnchor constant:-20.0],

        [self.categorySubtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:6.0],
        [self.categorySubtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.categorySubtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],

        [self.speciesPillsStackView.topAnchor constraintEqualToAnchor:self.categorySubtitleLabel.bottomAnchor constant:14.0],
        [self.speciesPillsStackView.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.speciesPillsStackView.trailingAnchor constraintLessThanOrEqualToAnchor:self.pricePlateView.leadingAnchor constant:-12.0],

        [self.pricePlateView.centerYAnchor constraintEqualToAnchor:self.speciesPillsStackView.centerYAnchor],
        [self.pricePlateView.trailingAnchor constraintEqualToAnchor:self.heroStageView.trailingAnchor constant:-20.0],
        [self.pricePlateView.heightAnchor constraintEqualToConstant:38.0],

        [self.pricePlateLabel.leadingAnchor constraintEqualToAnchor:self.pricePlateView.leadingAnchor constant:14.0],
        [self.pricePlateLabel.centerYAnchor constraintEqualToAnchor:self.pricePlateView.centerYAnchor],

        [self.pricePlateCurrencyLabel.leadingAnchor constraintEqualToAnchor:self.pricePlateLabel.trailingAnchor constant:5.0],
        [self.pricePlateCurrencyLabel.trailingAnchor constraintEqualToAnchor:self.pricePlateView.trailingAnchor constant:-14.0],
        [self.pricePlateCurrencyLabel.centerYAnchor constraintEqualToAnchor:self.pricePlateView.centerYAnchor],

        [self.speciesPillsStackView.bottomAnchor constraintEqualToAnchor:self.heroStageView.bottomAnchor constant:-20.0]
    ]];
}

- (void)pp_buildBentoMatrixSection
{
    self.bentoMatrixCardView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.bentoMatrixCardView];

    self.bentoMatrixTitleLabel = [self pp_sectionTitleLabelWithText:PPPetCareViewerLocalized(@"pet_care_viewer_trending_title", @"Clinical Specifications")
                                                             symbol:@"waveform.path.ecg"];
    [self.bentoMatrixCardView addSubview:self.bentoMatrixTitleLabel];

    self.bentoGridStackView = [[UIStackView alloc] init];
    self.bentoGridStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bentoGridStackView.axis = UILayoutConstraintAxisVertical;
    self.bentoGridStackView.spacing = 12.0;
    [self.bentoMatrixCardView addSubview:self.bentoGridStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.bentoMatrixCardView.topAnchor constraintEqualToAnchor:self.heroStageView.bottomAnchor constant:PPPetCareViewerSectionSpacing],
        [self.bentoMatrixCardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareViewerSideInset],
        [self.bentoMatrixCardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareViewerSideInset],

        [self.bentoMatrixTitleLabel.topAnchor constraintEqualToAnchor:self.bentoMatrixCardView.topAnchor constant:18.0],
        [self.bentoMatrixTitleLabel.leadingAnchor constraintEqualToAnchor:self.bentoMatrixCardView.leadingAnchor constant:18.0],
        [self.bentoMatrixTitleLabel.trailingAnchor constraintEqualToAnchor:self.bentoMatrixCardView.trailingAnchor constant:-18.0],

        [self.bentoGridStackView.topAnchor constraintEqualToAnchor:self.bentoMatrixTitleLabel.bottomAnchor constant:14.0],
        [self.bentoGridStackView.leadingAnchor constraintEqualToAnchor:self.bentoMatrixCardView.leadingAnchor constant:14.0],
        [self.bentoGridStackView.trailingAnchor constraintEqualToAnchor:self.bentoMatrixCardView.trailingAnchor constant:-14.0],
        [self.bentoGridStackView.bottomAnchor constraintEqualToAnchor:self.bentoMatrixCardView.bottomAnchor constant:-16.0]
    ]];
}

- (void)pp_buildDosageCalculatorSection
{
    self.dosageCalculatorCardView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.dosageCalculatorCardView];

    self.dosageTitleLabel = [self pp_sectionTitleLabelWithText:PPPetCareViewerLocalized(@"pet_care_viewer_dosage_calc_title", @"Approximate Dosage Guide")
                                                        symbol:@"scalemass.fill"];
    [self.dosageCalculatorCardView addSubview:self.dosageTitleLabel];

    self.dosageSubtitleLabel = [self pp_labelWithFont:[GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular]
                                                color:PPPetCareViewerSecondaryTextColor()
                                                lines:2];
    self.dosageSubtitleLabel.text = PPPetCareViewerLocalized(@"pet_care_viewer_weight_hint", @"Select pet weight class to preview recommended dose:");
    [self.dosageCalculatorCardView addSubview:self.dosageSubtitleLabel];

    self.dosageWeightButtonsStackView = [[UIStackView alloc] init];
    self.dosageWeightButtonsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.dosageWeightButtonsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.dosageWeightButtonsStackView.distribution = UIStackViewDistributionFillEqually;
    self.dosageWeightButtonsStackView.spacing = 8.0;
    [self.dosageCalculatorCardView addSubview:self.dosageWeightButtonsStackView];

    NSArray<NSString *> *weightTitles = @[
        PPPetCareViewerLocalized(@"pet_care_viewer_weight_small", @"< 5 kg"),
        PPPetCareViewerLocalized(@"pet_care_viewer_weight_medium", @"5 - 15 kg"),
        PPPetCareViewerLocalized(@"pet_care_viewer_weight_large", @"15 - 30 kg"),
        PPPetCareViewerLocalized(@"pet_care_viewer_weight_xlarge", @"> 30 kg")
    ];

    [self.weightSegmentButtons removeAllObjects];
    for (NSInteger i = 0; i < weightTitles.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        btn.tag = i;
        btn.layer.cornerRadius = 14.0;
        btn.layer.borderWidth = 0.8;
        btn.titleLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
        btn.titleLabel.adjustsFontSizeToFitWidth = YES;
        btn.titleLabel.minimumScaleFactor = 0.8;
        [btn setTitle:weightTitles[i] forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(pp_weightSegmentTapped:) forControlEvents:UIControlEventTouchUpInside];
        if (@available(iOS 13.0, *)) {
            btn.layer.cornerCurve = kCACornerCurveContinuous;
        }
        [self.dosageWeightButtonsStackView addArrangedSubview:btn];
        [self.weightSegmentButtons addObject:btn];
    }

    // Dosage Result Container
    self.dosageResultContainerView = [[UIView alloc] init];
    self.dosageResultContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.dosageResultContainerView.backgroundColor = PPPetCareViewerQuietTileColor();
    self.dosageResultContainerView.layer.cornerRadius = 18.0;
    self.dosageResultContainerView.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        self.dosageResultContainerView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.dosageCalculatorCardView addSubview:self.dosageResultContainerView];

    UIImageView *doseIconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"cross.vial.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    doseIconView.translatesAutoresizingMaskIntoConstraints = NO;
    doseIconView.tintColor = PPPetCareViewerAccentColor();
    doseIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.dosageResultContainerView addSubview:doseIconView];

    self.dosageResultValueLabel = [self pp_labelWithFont:[GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold]
                                                   color:PPPetCareViewerTextColor()
                                                   lines:0];
    [self.dosageResultContainerView addSubview:self.dosageResultValueLabel];

    self.dosageDisclaimerLabel = [self pp_labelWithFont:[GM MidFontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightRegular]
                                                  color:PPPetCareViewerSecondaryTextColor()
                                                  lines:0];
    self.dosageDisclaimerLabel.text = PPPetCareViewerLocalized(@"pet_care_viewer_dose_disclaimer", @"This guide is for reference only. Please follow your veterinarian's specific instructions.");
    [self.dosageCalculatorCardView addSubview:self.dosageDisclaimerLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.dosageCalculatorCardView.topAnchor constraintEqualToAnchor:self.bentoMatrixCardView.bottomAnchor constant:PPPetCareViewerSectionSpacing],
        [self.dosageCalculatorCardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareViewerSideInset],
        [self.dosageCalculatorCardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareViewerSideInset],

        [self.dosageTitleLabel.topAnchor constraintEqualToAnchor:self.dosageCalculatorCardView.topAnchor constant:18.0],
        [self.dosageTitleLabel.leadingAnchor constraintEqualToAnchor:self.dosageCalculatorCardView.leadingAnchor constant:18.0],
        [self.dosageTitleLabel.trailingAnchor constraintEqualToAnchor:self.dosageCalculatorCardView.trailingAnchor constant:-18.0],

        [self.dosageSubtitleLabel.topAnchor constraintEqualToAnchor:self.dosageTitleLabel.bottomAnchor constant:6.0],
        [self.dosageSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.dosageTitleLabel.leadingAnchor],
        [self.dosageSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.dosageTitleLabel.trailingAnchor],

        [self.dosageWeightButtonsStackView.topAnchor constraintEqualToAnchor:self.dosageSubtitleLabel.bottomAnchor constant:14.0],
        [self.dosageWeightButtonsStackView.leadingAnchor constraintEqualToAnchor:self.dosageCalculatorCardView.leadingAnchor constant:16.0],
        [self.dosageWeightButtonsStackView.trailingAnchor constraintEqualToAnchor:self.dosageCalculatorCardView.trailingAnchor constant:-16.0],
        [self.dosageWeightButtonsStackView.heightAnchor constraintEqualToConstant:38.0],

        [self.dosageResultContainerView.topAnchor constraintEqualToAnchor:self.dosageWeightButtonsStackView.bottomAnchor constant:14.0],
        [self.dosageResultContainerView.leadingAnchor constraintEqualToAnchor:self.dosageCalculatorCardView.leadingAnchor constant:16.0],
        [self.dosageResultContainerView.trailingAnchor constraintEqualToAnchor:self.dosageCalculatorCardView.trailingAnchor constant:-16.0],

        [doseIconView.leadingAnchor constraintEqualToAnchor:self.dosageResultContainerView.leadingAnchor constant:14.0],
        [doseIconView.centerYAnchor constraintEqualToAnchor:self.dosageResultContainerView.centerYAnchor],
        [doseIconView.widthAnchor constraintEqualToConstant:20.0],
        [doseIconView.heightAnchor constraintEqualToConstant:20.0],

        [self.dosageResultValueLabel.topAnchor constraintEqualToAnchor:self.dosageResultContainerView.topAnchor constant:12.0],
        [self.dosageResultValueLabel.leadingAnchor constraintEqualToAnchor:doseIconView.trailingAnchor constant:12.0],
        [self.dosageResultValueLabel.trailingAnchor constraintEqualToAnchor:self.dosageResultContainerView.trailingAnchor constant:-14.0],
        [self.dosageResultValueLabel.bottomAnchor constraintEqualToAnchor:self.dosageResultContainerView.bottomAnchor constant:-12.0],

        [self.dosageDisclaimerLabel.topAnchor constraintEqualToAnchor:self.dosageResultContainerView.bottomAnchor constant:10.0],
        [self.dosageDisclaimerLabel.leadingAnchor constraintEqualToAnchor:self.dosageCalculatorCardView.leadingAnchor constant:18.0],
        [self.dosageDisclaimerLabel.trailingAnchor constraintEqualToAnchor:self.dosageCalculatorCardView.trailingAnchor constant:-18.0],
        [self.dosageDisclaimerLabel.bottomAnchor constraintEqualToAnchor:self.dosageCalculatorCardView.bottomAnchor constant:-16.0]
    ]];
}

- (void)pp_buildIndicationsSection
{
    self.indicationsCardView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.indicationsCardView];

    self.indicationsTitleLabel = [self pp_sectionTitleLabelWithText:PPPetCareViewerLocalized(@"pet_care_viewer_benefits_title", @"Key Benefits & Clinical Efficacy")
                                                             symbol:@"shield.lefthalf.filled"];
    [self.indicationsCardView addSubview:self.indicationsTitleLabel];

    self.indicationsStackView = [[UIStackView alloc] init];
    self.indicationsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.indicationsStackView.axis = UILayoutConstraintAxisVertical;
    self.indicationsStackView.spacing = 10.0;
    [self.indicationsCardView addSubview:self.indicationsStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.indicationsCardView.topAnchor constraintEqualToAnchor:self.dosageCalculatorCardView.bottomAnchor constant:PPPetCareViewerSectionSpacing],
        [self.indicationsCardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareViewerSideInset],
        [self.indicationsCardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareViewerSideInset],

        [self.indicationsTitleLabel.topAnchor constraintEqualToAnchor:self.indicationsCardView.topAnchor constant:18.0],
        [self.indicationsTitleLabel.leadingAnchor constraintEqualToAnchor:self.indicationsCardView.leadingAnchor constant:18.0],
        [self.indicationsTitleLabel.trailingAnchor constraintEqualToAnchor:self.indicationsCardView.trailingAnchor constant:-18.0],

        [self.indicationsStackView.topAnchor constraintEqualToAnchor:self.indicationsTitleLabel.bottomAnchor constant:14.0],
        [self.indicationsStackView.leadingAnchor constraintEqualToAnchor:self.indicationsCardView.leadingAnchor constant:14.0],
        [self.indicationsStackView.trailingAnchor constraintEqualToAnchor:self.indicationsCardView.trailingAnchor constant:-14.0],
        [self.indicationsStackView.bottomAnchor constraintEqualToAnchor:self.indicationsCardView.bottomAnchor constant:-16.0]
    ]];
}

- (void)pp_buildDescriptionSection
{
    self.descriptionCardView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.descriptionCardView];

    self.descriptionTitleLabel = [self pp_sectionTitleLabelWithText:PPPetCareViewerLocalized(@"pet_care_viewer_description", @"Description & Clinical Notes")
                                                             symbol:@"doc.text.fill"];
    [self.descriptionCardView addSubview:self.descriptionTitleLabel];

    self.descriptionBodyLabel = [self pp_labelWithFont:[GM MidFontWithSize:14.5] ?: [UIFont systemFontOfSize:14.5 weight:UIFontWeightRegular]
                                                 color:PPPetCareViewerTextColor()
                                                 lines:0];
    [self.descriptionCardView addSubview:self.descriptionBodyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.descriptionCardView.topAnchor constraintEqualToAnchor:self.indicationsCardView.bottomAnchor constant:PPPetCareViewerSectionSpacing],
        [self.descriptionCardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareViewerSideInset],
        [self.descriptionCardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareViewerSideInset],

        [self.descriptionTitleLabel.topAnchor constraintEqualToAnchor:self.descriptionCardView.topAnchor constant:18.0],
        [self.descriptionTitleLabel.leadingAnchor constraintEqualToAnchor:self.descriptionCardView.leadingAnchor constant:18.0],
        [self.descriptionTitleLabel.trailingAnchor constraintEqualToAnchor:self.descriptionCardView.trailingAnchor constant:-18.0],

        [self.descriptionBodyLabel.topAnchor constraintEqualToAnchor:self.descriptionTitleLabel.bottomAnchor constant:10.0],
        [self.descriptionBodyLabel.leadingAnchor constraintEqualToAnchor:self.descriptionCardView.leadingAnchor constant:18.0],
        [self.descriptionBodyLabel.trailingAnchor constraintEqualToAnchor:self.descriptionCardView.trailingAnchor constant:-18.0],
        [self.descriptionBodyLabel.bottomAnchor constraintEqualToAnchor:self.descriptionCardView.bottomAnchor constant:-18.0]
    ]];
}

- (void)pp_buildVetConsultSection
{
    self.vetConsultCardView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.vetConsultCardView];

    self.vetConsultIconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"stethoscope"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    self.vetConsultIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.vetConsultIconView.tintColor = PPPetCareViewerAccentColor();
    self.vetConsultIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.vetConsultCardView addSubview:self.vetConsultIconView];

    self.vetConsultTitleLabel = [self pp_labelWithFont:[GM boldFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightBold]
                                                 color:PPPetCareViewerTextColor()
                                                 lines:1];
    self.vetConsultTitleLabel.text = PPPetCareViewerLocalized(@"pet_care_viewer_vet_consult_title", @"Need guidance about this medicine?");
    [self.vetConsultCardView addSubview:self.vetConsultTitleLabel];

    self.vetConsultBodyLabel = [self pp_labelWithFont:[GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular]
                                                color:PPPetCareViewerSecondaryTextColor()
                                                lines:0];
    self.vetConsultBodyLabel.text = PPPetCareViewerLocalized(@"pet_care_viewer_vet_consult_desc", @"Connect instantly with a certified veterinarian on Pure Pets.");
    [self.vetConsultCardView addSubview:self.vetConsultBodyLabel];

    self.vetConsultActionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.vetConsultActionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.vetConsultActionButton.layer.cornerRadius = 16.0;
    self.vetConsultActionButton.titleLabel.font = [GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold];
    [self.vetConsultActionButton setTitle:PPPetCareViewerLocalized(@"pet_care_viewer_vet_consult_btn", @"Consult a Veterinarian Now") forState:UIControlStateNormal];
    [self.vetConsultActionButton addTarget:self action:@selector(pp_vetConsultTapped) forControlEvents:UIControlEventTouchUpInside];
    if (@available(iOS 13.0, *)) {
        self.vetConsultActionButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.vetConsultCardView addSubview:self.vetConsultActionButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.vetConsultCardView.topAnchor constraintEqualToAnchor:self.descriptionCardView.bottomAnchor constant:PPPetCareViewerSectionSpacing],
        [self.vetConsultCardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareViewerSideInset],
        [self.vetConsultCardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareViewerSideInset],
        [self.vetConsultCardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-32.0],

        [self.vetConsultIconView.topAnchor constraintEqualToAnchor:self.vetConsultCardView.topAnchor constant:18.0],
        [self.vetConsultIconView.leadingAnchor constraintEqualToAnchor:self.vetConsultCardView.leadingAnchor constant:18.0],
        [self.vetConsultIconView.widthAnchor constraintEqualToConstant:24.0],
        [self.vetConsultIconView.heightAnchor constraintEqualToConstant:24.0],

        [self.vetConsultTitleLabel.centerYAnchor constraintEqualToAnchor:self.vetConsultIconView.centerYAnchor],
        [self.vetConsultTitleLabel.leadingAnchor constraintEqualToAnchor:self.vetConsultIconView.trailingAnchor constant:10.0],
        [self.vetConsultTitleLabel.trailingAnchor constraintEqualToAnchor:self.vetConsultCardView.trailingAnchor constant:-18.0],

        [self.vetConsultBodyLabel.topAnchor constraintEqualToAnchor:self.vetConsultIconView.bottomAnchor constant:8.0],
        [self.vetConsultBodyLabel.leadingAnchor constraintEqualToAnchor:self.vetConsultCardView.leadingAnchor constant:18.0],
        [self.vetConsultBodyLabel.trailingAnchor constraintEqualToAnchor:self.vetConsultCardView.trailingAnchor constant:-18.0],

        [self.vetConsultActionButton.topAnchor constraintEqualToAnchor:self.vetConsultBodyLabel.bottomAnchor constant:14.0],
        [self.vetConsultActionButton.leadingAnchor constraintEqualToAnchor:self.vetConsultCardView.leadingAnchor constant:16.0],
        [self.vetConsultActionButton.trailingAnchor constraintEqualToAnchor:self.vetConsultCardView.trailingAnchor constant:-16.0],
        [self.vetConsultActionButton.heightAnchor constraintEqualToConstant:44.0],
        [self.vetConsultActionButton.bottomAnchor constraintEqualToAnchor:self.vetConsultCardView.bottomAnchor constant:-16.0]
    ]];
}

- (void)pp_updateViewportLayout
{
    CGFloat safeBottom = self.view.safeAreaInsets.bottom;
    CGFloat bottomBarHeight = PPPetCareViewerBottomBarBase + safeBottom;
    if (fabs(self.bottomBarHeightConstraint.constant - bottomBarHeight) > 0.5) {
        self.bottomBarHeightConstraint.constant = bottomBarHeight;
    }

    CGFloat width = CGRectGetWidth(self.view.bounds) - (PPPetCareViewerSideInset * 2.0) - 32.0;
    if (width > 0.0) {
        BOOL isPad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
        CGFloat targetArtworkHeight = isPad
            ? MIN(MAX(width * 0.46, 240.0), 320.0)
            : MIN(MAX(width * 0.62, 220.0), 280.0);
        if (fabs(self.heroArtworkHeightConstraint.constant - targetArtworkHeight) > 0.5) {
            self.heroArtworkHeightConstraint.constant = targetArtworkHeight;
        }
    }

    UIEdgeInsets inset = self.scrollView.contentInset;
    inset.bottom = bottomBarHeight + 20.0;
    self.scrollView.contentInset = inset;
    self.scrollView.scrollIndicatorInsets = inset;
}

#pragma mark - Content & Data Binding

- (void)pp_applyContent
{
    self.titleLabel.text = self.medicine.title.length > 0 ? self.medicine.title : PPPetCareViewerLocalized(@"pet_care_medicine_untitled", @"Medicine");
    self.categorySubtitleLabel.text = self.medicine.category.length > 0 ? self.medicine.category : PPPetCareViewerLocalized(@"pet_care_viewer_about_medicine", @"Veterinary care essential");

    // Price
    NSString *currency = PPPetCareMedicineCurrencyCode(self.medicine);
    self.pricePlateLabel.text = [NSString stringWithFormat:@"%.2f", MAX(self.medicine.price, 0.0)];
    self.pricePlateCurrencyLabel.text = currency.length > 0 ? currency : kLang(@"Rials");

    // Stock Badge
    BOOL isAvailable = [self pp_isMedicineCurrentlyAvailable];
    NSInteger stock = MAX(self.medicine.stockQuantity, 0);
    if (!isAvailable || stock <= 0) {
        self.heroStockStatusBadgeLabel.text = [NSString stringWithFormat:@"✕ %@", PPPetCareViewerLocalized(@"pet_care_medicine_out_of_stock", @"Out of stock")];
    } else if (stock <= 3) {
        self.heroStockStatusBadgeLabel.text = [NSString stringWithFormat:@"⚠️ %@", PPPetCareViewerLocalized(@"pet_care_viewer_low_stock_badge", @"Low stock")];
    } else {
        self.heroStockStatusBadgeLabel.text = [NSString stringWithFormat:@"● %@", [NSString stringWithFormat:PPPetCareViewerLocalized(@"pet_care_viewer_stock_units_format", @"%ld in stock"), (long)stock]];
    }

    // Species Badges
    [self pp_reloadSpeciesPills];

    // Hero Image
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:56.0 weight:UIImageSymbolWeightSemibold];
    UIImage *placeholder = [[UIImage systemImageNamed:@"pills.fill" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.heroImageView.image = placeholder;
    self.heroImageView.tintColor = PPPetCareViewerAccentColor();
    if (self.medicine.imageUrl.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:self.heroImageView
                                                       url:self.medicine.imageUrl
                                               placeholder:placeholder
                                           transitionStyle:PPImageTransitionStyleFade
                                                complation:nil];
    }

    // Clinical Bento
    [self pp_reloadBentoMatrixTiles];

    // Dosage Estimator
    [self pp_refreshDosageEstimationUIAnimated:NO];

    // Indications
    [self pp_reloadIndicationsHighlights];

    // Description
    self.descriptionBodyLabel.text = self.medicine.medicineDescription.length > 0
        ? self.medicine.medicineDescription
        : PPPetCareViewerLocalized(@"pet_care_viewer_no_description", @"No description has been added yet.");

    self.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.categorySubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.descriptionBodyLabel.textAlignment = Language.alignmentForCurrentLanguage;
}

- (void)pp_reloadSpeciesPills
{
    for (UIView *view in self.speciesPillsStackView.arrangedSubviews) {
        [self.speciesPillsStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    NSMutableArray<NSString *> *species = [NSMutableArray array];
    if (self.medicine.animalTypes.count > 0) {
        for (NSString *type in self.medicine.animalTypes) {
            if (type.length > 0) {
                [species addObject:type];
            }
        }
    }
    if (species.count == 0 && self.mainKindName.length > 0) {
        [species addObject:self.mainKindName];
    }
    if (species.count == 0) {
        [species addObject:PPPetCareViewerLocalized(@"pet_care_all_pets", @"All pets")];
    }

    for (NSString *name in species) {
        PPHomeInsetLabel *pill = [self pp_pillLabelWithFont:[GM boldFontWithSize:11.5] ?: [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold]];
        pill.text = [self pp_formattedSpeciesName:name];
        [self pp_applyTintPillToLabel:pill
                                 tint:PPPetCareViewerAccentColor()
                             fillAlpha:0.12
                           borderAlpha:0.24
                             textColor:PPPetCareViewerTextColor()];
        [self.speciesPillsStackView addArrangedSubview:pill];
    }
}

- (NSString *)pp_formattedSpeciesName:(NSString *)rawName
{
    NSString *lower = rawName.lowercaseString;
    if ([lower containsString:@"cat"] || [lower containsString:@"قط"]) {
        return [NSString stringWithFormat:@"🐱 %@", rawName];
    }
    if ([lower containsString:@"dog"] || [lower containsString:@"كلب"]) {
        return [NSString stringWithFormat:@"🐶 %@", rawName];
    }
    if ([lower containsString:@"bird"] || [lower containsString:@"طير"] || [lower containsString:@"عصفور"]) {
        return [NSString stringWithFormat:@"🦜 %@", rawName];
    }
    if ([lower containsString:@"rabbit"] || [lower containsString:@"أرنب"]) {
        return [NSString stringWithFormat:@"🐰 %@", rawName];
    }
    return [NSString stringWithFormat:@"🐾 %@", rawName];
}

- (void)pp_reloadBentoMatrixTiles
{
    for (UIView *view in self.bentoGridStackView.arrangedSubviews) {
        [self.bentoGridStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    UIStackView *firstRow = [[UIStackView alloc] init];
    firstRow.translatesAutoresizingMaskIntoConstraints = NO;
    firstRow.axis = UILayoutConstraintAxisHorizontal;
    firstRow.distribution = UIStackViewDistributionFillEqually;
    firstRow.spacing = 12.0;

    UIStackView *secondRow = [[UIStackView alloc] init];
    secondRow.translatesAutoresizingMaskIntoConstraints = NO;
    secondRow.axis = UILayoutConstraintAxisHorizontal;
    secondRow.distribution = UIStackViewDistributionFillEqually;
    secondRow.spacing = 12.0;

    UIColor *accent = PPPetCareViewerAccentColor();
    UIColor *warm = PPPetCareViewerWarmAccentColor();
    UIColor *indigo = PPPetCareViewerIndigoAccentColor();
    UIColor *green = [UIColor colorWithRed:0.20 green:0.70 blue:0.42 alpha:1.0];

    NSString *dosageForm = [self pp_dosageFormForCategory:self.medicine.category title:self.medicine.title];

    [firstRow addArrangedSubview:[self pp_clinicalBentoTileWithSymbol:@"pills.fill"
                                                                title:PPPetCareViewerLocalized(@"pet_care_viewer_dosage_form", @"Dosage Form")
                                                                value:dosageForm
                                                                 tint:accent]];

    [firstRow addArrangedSubview:[self pp_clinicalBentoTileWithSymbol:@"checkmark.shield.fill"
                                                                title:PPPetCareViewerLocalized(@"pet_care_viewer_rx_tier", @"Prescription")
                                                                value:PPPetCareViewerLocalized(@"pet_care_viewer_rx_otc", @"Over-The-Counter (OTC)")
                                                                 tint:green]];

    [secondRow addArrangedSubview:[self pp_clinicalBentoTileWithSymbol:@"thermometer.sun.fill"
                                                                 title:PPPetCareViewerLocalized(@"pet_care_viewer_storage", @"Storage")
                                                                 value:PPPetCareViewerLocalized(@"pet_care_viewer_storage_cool", @"15° - 25°C · Cool & Dry")
                                                                  tint:warm]];

    [secondRow addArrangedSubview:[self pp_clinicalBentoTileWithSymbol:@"seal.fill"
                                                                 title:PPPetCareViewerLocalized(@"pet_care_viewer_guarantee", @"Quality Assurance")
                                                                 value:PPPetCareViewerLocalized(@"pet_care_viewer_guarantee_orig", @"100% Genuine · Licensed Pharmacy")
                                                                  tint:indigo]];

    [self.bentoGridStackView addArrangedSubview:firstRow];
    [self.bentoGridStackView addArrangedSubview:secondRow];
}

- (NSString *)pp_dosageFormForCategory:(NSString *)category title:(NSString *)title
{
    NSString *text = [NSString stringWithFormat:@"%@ %@", category ?: @"", title ?: @""].lowercaseString;
    if ([text containsString:@"spray"] || [text containsString:@"بخاخ"]) {
        return PPPetCareViewerLocalized(@"pet_care_viewer_dosage_form_spray", @"Topical Spray");
    }
    if ([text containsString:@"syrup"] || [text containsString:@"liquid"] || [text containsString:@"شراب"] || [text containsString:@"نقط"]) {
        return PPPetCareViewerLocalized(@"pet_care_viewer_dosage_form_liquid", @"Oral Liquid Syrup");
    }
    if ([text containsString:@"spot"] || [text containsString:@"pipette"] || [text containsString:@"موضعي"] || [text containsString:@"امبول"]) {
        return PPPetCareViewerLocalized(@"pet_care_viewer_dosage_form_topical", @"Topical Pipette");
    }
    return PPPetCareViewerLocalized(@"pet_care_viewer_dosage_form_tablets", @"Oral Chewable Tablets");
}

- (void)pp_reloadIndicationsHighlights
{
    for (UIView *view in self.indicationsStackView.arrangedSubviews) {
        [self.indicationsStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    UIColor *accent = PPPetCareViewerAccentColor();
    UIColor *warm = PPPetCareViewerWarmAccentColor();
    UIColor *indigo = PPPetCareViewerIndigoAccentColor();

    [self.indicationsStackView addArrangedSubview:[self pp_indicationHighlightRowWithSymbol:@"cross.vial.fill"
                                                                                      title:PPPetCareViewerLocalized(@"pet_care_viewer_benefit_1_title", @"High-Efficacy Veterinary Formula")
                                                                                   subtitle:PPPetCareViewerLocalized(@"pet_care_viewer_benefit_1_desc", @"Fast-acting formulation engineered for optimal therapeutic relief.")
                                                                                       tint:accent]];

    [self.indicationsStackView addArrangedSubview:[self pp_indicationHighlightRowWithSymbol:@"snowflake"
                                                                                      title:PPPetCareViewerLocalized(@"pet_care_viewer_benefit_2_title", @"Certified Cold-Chain Storage")
                                                                                   subtitle:PPPetCareViewerLocalized(@"pet_care_viewer_benefit_2_desc", @"Stored and transported under controlled temperatures to preserve active efficacy.")
                                                                                       tint:indigo]];

    [self.indicationsStackView addArrangedSubview:[self pp_indicationHighlightRowWithSymbol:@"heart.text.square.fill"
                                                                                      title:PPPetCareViewerLocalized(@"pet_care_viewer_benefit_3_title", @"Tested Pet Safety Profile")
                                                                                   subtitle:PPPetCareViewerLocalized(@"pet_care_viewer_benefit_3_desc", @"Veterinary-tested and compliant with international pet health standards.")
                                                                                       tint:warm]];
}

#pragma mark - Theme

- (void)pp_applyTheme
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    UIColor *accent = PPPetCareViewerAccentColor();
    UIColor *warmAccent = PPPetCareViewerWarmAccentColor();
    UIColor *indigoAccent = PPPetCareViewerIndigoAccentColor();

    self.backgroundGlowTopView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.18 : 0.12];
    self.backgroundGlowTopView.layer.shadowColor = accent.CGColor;
    self.backgroundGlowTopView.alpha = 1.0;

    self.backgroundGlowMiddleView.backgroundColor = [warmAccent colorWithAlphaComponent:dark ? 0.13 : 0.09];
    self.backgroundGlowMiddleView.layer.shadowColor = warmAccent.CGColor;
    self.backgroundGlowMiddleView.alpha = 1.0;

    self.backgroundGlowBottomView.backgroundColor = [indigoAccent colorWithAlphaComponent:dark ? 0.16 : 0.11];
    self.backgroundGlowBottomView.layer.shadowColor = indigoAccent.CGColor;
    self.backgroundGlowBottomView.alpha = 1.0;

    // Hero Stage Theme
    self.heroStageView.backgroundColor = PPPetCareViewerElevatedSurfaceColor();
    [self.heroStageView pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.22 : 0.12]];
    [self.heroStageView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:dark ? 0.55 : 0.16]];

    self.heroArtworkChamberView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.16 : 0.08];
    [self.heroArtworkChamberView pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.28 : 0.16]];

    self.heroChamberGradientLayer.colors = @[
        (__bridge id)[accent colorWithAlphaComponent:dark ? 0.28 : 0.16].CGColor,
        (__bridge id)[warmAccent colorWithAlphaComponent:dark ? 0.18 : 0.10].CGColor,
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:dark ? 0.56 : 0.12].CGColor
    ];
    self.heroChamberGradientLayer.locations = @[@0.0, @0.55, @1.0];

    [self pp_applyTintPillToLabel:self.heroCertBadgeLabel
                             tint:accent
                         fillAlpha:(dark ? 0.26 : 0.16)
                       borderAlpha:(dark ? 0.38 : 0.24)
                         textColor:accent];

    UIColor *stockTint = [self pp_isMedicineCurrentlyAvailable] ? accent : UIColor.systemRedColor;
    [self pp_applyTintPillToLabel:self.heroStockStatusBadgeLabel
                             tint:stockTint
                         fillAlpha:(dark ? 0.26 : 0.16)
                       borderAlpha:(dark ? 0.38 : 0.24)
                         textColor:stockTint];

    self.pricePlateView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.18 : 0.10];
    [self.pricePlateView pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.32 : 0.20]];
    self.pricePlateLabel.textColor = accent;
    self.pricePlateCurrencyLabel.textColor = PPPetCareViewerSecondaryTextColor();

    // Section Themes
    [self pp_applySectionTheme:self.bentoMatrixCardView];
    [self pp_applySectionTheme:self.dosageCalculatorCardView];
    [self pp_applySectionTheme:self.indicationsCardView];
    [self pp_applySectionTheme:self.descriptionCardView];
    [self pp_applySectionTheme:self.vetConsultCardView];

    // Vet Consult Action Button
    self.vetConsultActionButton.backgroundColor = accent;
    [self.vetConsultActionButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];

    [self pp_refreshDosageEstimationUIAnimated:NO];
    [self pp_syncBottomBarState];
}

- (void)pp_applySectionTheme:(UIView *)section
{
    section.backgroundColor = PPPetCareViewerSurfaceColor();
    [section pp_setBorderColor:PPPetCareViewerBorderColor()];
    [section pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:0.09]];
    section.layer.shadowOpacity = 0.09;
    section.layer.shadowRadius = 24.0;
    section.layer.shadowOffset = CGSizeMake(0.0, 12.0);
}

#pragma mark - Dosage Estimation Logic

- (void)pp_weightSegmentTapped:(UIButton *)sender
{
    [PPFunc triggerLightHaptic];
    self.selectedWeightCategory = (PPPetWeightCategory)sender.tag;
    [self pp_refreshDosageEstimationUIAnimated:YES];
}

- (void)pp_refreshDosageEstimationUIAnimated:(BOOL)animated
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    UIColor *accent = PPPetCareViewerAccentColor();

    for (NSInteger i = 0; i < self.weightSegmentButtons.count; i++) {
        UIButton *btn = self.weightSegmentButtons[i];
        BOOL selected = (i == (NSInteger)self.selectedWeightCategory);
        if (selected) {
            btn.backgroundColor = accent;
            [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
            [btn pp_setBorderColor:accent];
        } else {
            btn.backgroundColor = PPPetCareViewerQuietTileColor();
            [btn setTitleColor:PPPetCareViewerTextColor() forState:UIControlStateNormal];
            [btn pp_setBorderColor:PPPetCareViewerBorderColor()];
        }
    }

    NSString *desc = @"";
    switch (self.selectedWeightCategory) {
        case PPPetWeightCategorySmall:
            desc = PPPetCareViewerLocalized(@"pet_care_viewer_dose_small_desc", @"1/2 tablet or 2.5ml · Consult vet for young pets");
            break;
        case PPPetWeightCategoryMedium:
            desc = PPPetCareViewerLocalized(@"pet_care_viewer_dose_medium_desc", @"1 full tablet or 5ml with meal");
            break;
        case PPPetWeightCategoryLarge:
            desc = PPPetCareViewerLocalized(@"pet_care_viewer_dose_large_desc", @"2 tablets or 10ml split into two doses");
            break;
        case PPPetWeightCategoryXLarge:
            desc = PPPetCareViewerLocalized(@"pet_care_viewer_dose_xlarge_desc", @"3 tablets or according to veterinary prescription");
            break;
    }

    [self.dosageResultContainerView pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.28 : 0.16]];

    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView transitionWithView:self.dosageResultValueLabel
                          duration:0.24
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            self.dosageResultValueLabel.text = desc;
        } completion:nil];
    } else {
        self.dosageResultValueLabel.text = desc;
    }
}

#pragma mark - Cart & Actions

- (void)pp_handleCartUpdated:(NSNotification *)notification
{
    (void)notification;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pp_syncBottomBarState];
    });
}

- (void)pp_syncBottomBarState
{
    NSInteger existingQuantity = PPPetCareCartQuantityForMedicine(self.medicine);
    NSInteger stockQuantity = MAX(self.medicine.stockQuantity, 0);
    NSInteger remainingToAdd = MAX(0, stockQuantity - existingQuantity);
    CGFloat itemAmount = MAX(self.medicine.price, 0.0);
    NSInteger selectedQuantity = MAX(self.bottomBar.cartItemquantity, 1);

    self.bottomBar.itemAmount = itemAmount;
    self.bottomBar.totalAmount = itemAmount * selectedQuantity;
    self.bottomBar.addToCartButton.enabled = self.medicine.isAvailable && remainingToAdd > 0;
    self.bottomBar.addToCartButton.alpha = self.bottomBar.addToCartButton.enabled ? 1.0 : 0.58;
}

- (void)pp_addToCartButtonTapped:(NSInteger)quantity
{
    if (![PPNetworkRetryHelper isNetworkAvailable]) {
        [self.bottomBar performAddToCartFailureAnimation];
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"offline_action_title")
                            subtitle:kLang(@"offline_action_message")
                          completion:nil];
        return;
    }

    if (![self pp_ensureSignedInForAction]) {
        [self.bottomBar performAddToCartFailureAnimation];
        return;
    }

    NSInteger stockQuantity = MAX(self.medicine.stockQuantity, 0);
    NSInteger existingQuantity = PPPetCareCartQuantityForMedicine(self.medicine);
    NSInteger requestedQuantity = MAX(quantity, 1);
    NSInteger availableToAdd = MAX(0, stockQuantity - existingQuantity);

    if (!self.medicine.isAvailable || stockQuantity <= 0 || availableToAdd <= 0) {
        [self.bottomBar performAddToCartFailureAnimation];
        [PPHUD showError:kLang(@"Out of stock")];
        [PPFunc triggerWarningHaptic];
        return;
    }

    NSInteger safeQuantity = MIN(requestedQuantity, availableToAdd);
    CartItem *item = PPPetCareCartItemForMedicine(self.medicine, safeQuantity);
    if (!item) {
        [self.bottomBar performAddToCartFailureAnimation];
        [PPHUD showError:kLang(@"Out of stock")];
        [PPFunc triggerWarningHaptic];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [[CartManager sharedManager] addItem:item
                presentingViewController:self
                               completion:^(BOOL didAdd, BOOL didCancel) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        if (didCancel) {
            [self.bottomBar cancelAddToCartPendingState];
            return;
        }
        if (!didAdd) {
            [self.bottomBar performAddToCartFailureAnimation];
            [PPHUD showError:kLang(@"Out of stock")];
            [PPFunc triggerWarningHaptic];
            return;
        }

        NSString *message = safeQuantity < requestedQuantity
            ? [NSString stringWithFormat:@"%@ %ld %@",
               kLang(@"Only"),
               (long)availableToAdd,
               kLang(@"left in stock")]
            : kLang(@"ItemAddedToYourCart");

        [self.bottomBar performAddToCartSuccessAnimation];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [PPAddToCartSuccessToast showWithTitle:kLang(@"AddedToCart") subtitle:message];
        });
        if (safeQuantity == 1) {
            [PPFunc triggerLightHaptic];
        } else {
            [PPFunc triggerMediumHaptic];
        }

        self.bottomBar.cartItemquantity = 1;
        [self.bottomBar updateQuantityUI];
        [self pp_syncBottomBarState];
    }];
}

- (BOOL)pp_ensureSignedInForAction
{
    if (UserManager.sharedManager.isUserLoggedIn) {
        return YES;
    }
    [PPFunc triggerWarningHaptic];
    [UserManager showPromptOnTopController];
    return NO;
}

- (void)pp_shareTapped
{
    [PPFunc triggerLightHaptic];
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [parts addObject:self.titleLabel.text ?: @""];
    if (self.medicine.medicineDescription.length > 0) {
        [parts addObject:self.medicine.medicineDescription];
    }
    [parts addObject:[NSString stringWithFormat:@"%@: %.2f %@", PPPetCareViewerLocalized(@"pet_care_medicine_price", @"Price"), MAX(self.medicine.price, 0.0), PPPetCareMedicineCurrencyCode(self.medicine)]];

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[[parts componentsJoinedByString:@"\n"]]
                                                                             applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.bottomBar.favButton ?: self.heroStageView;
        activityVC.popoverPresentationController.sourceRect = self.bottomBar.favButton ? self.bottomBar.favButton.bounds : self.heroStageView.bounds;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)pp_vetConsultTapped
{
    [PPFunc triggerMediumHaptic];
    [self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)pp_isMedicineCurrentlyAvailable
{
    return self.medicine.isAvailable && self.medicine.stockQuantity > 0;
}

#pragma mark - UI Component Helpers

- (UIView *)pp_surfaceSectionView
{
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.layer.cornerRadius = PPPetCareViewerCardRadius;
    view.layer.borderWidth = 0.8;
    view.clipsToBounds = NO;
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

- (UILabel *)pp_sectionTitleLabelWithText:(NSString *)text symbol:(NSString *)symbol
{
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM boldFontWithSize:16.5] ?: [UIFont systemFontOfSize:16.5 weight:UIFontWeightBold];
    label.textColor = PPPetCareViewerTextColor();
    label.numberOfLines = 1;
    label.textAlignment = Language.alignmentForCurrentLanguage;

    NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:15.0 weight:UIImageSymbolWeightBold];
    attachment.image = [[UIImage systemImageNamed:symbol withConfiguration:config] imageWithTintColor:PPPetCareViewerAccentColor()];
    
    NSMutableAttributedString *attributedString = [[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy];
    [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"  %@", text]]];
    label.attributedText = attributedString;
    return label;
}

- (PPHomeInsetLabel *)pp_pillLabelWithFont:(UIFont *)font
{
    PPHomeInsetLabel *label = [[PPHomeInsetLabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textAlignment = NSTextAlignmentCenter;
    label.contentInsets = UIEdgeInsetsMake(6.0, 10.0, 6.0, 10.0);
    label.layer.cornerRadius = 14.0;
    label.layer.borderWidth = 0.8;
    label.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        label.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return label;
}

- (void)pp_applyTintPillToLabel:(UILabel *)label
                           tint:(UIColor *)tint
                       fillAlpha:(CGFloat)fillAlpha
                     borderAlpha:(CGFloat)borderAlpha
                       textColor:(UIColor *)textColor
{
    label.backgroundColor = [tint colorWithAlphaComponent:fillAlpha];
    label.textColor = textColor;
    [label pp_setBorderColor:[tint colorWithAlphaComponent:borderAlpha]];
}

- (UIView *)pp_clinicalBentoTileWithSymbol:(NSString *)symbol
                                     title:(NSString *)title
                                     value:(NSString *)value
                                      tint:(UIColor *)tint
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = PPPetCareViewerQuietTileColor();
    container.layer.cornerRadius = 20.0;
    container.layer.borderWidth = 0.8;
    [container pp_setBorderColor:[tint colorWithAlphaComponent:0.16]];
    if (@available(iOS 13.0, *)) {
        container.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *iconShell = [[UIView alloc] init];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.backgroundColor = [tint colorWithAlphaComponent:0.12];
    iconShell.layer.cornerRadius = 16.0;
    if (@available(iOS 13.0, *)) {
        iconShell.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [container addSubview:iconShell];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:symbol] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = tint;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconShell addSubview:iconView];

    UILabel *titleLabel = [self pp_labelWithFont:[GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium]
                                           color:PPPetCareViewerSecondaryTextColor()
                                           lines:1];
    titleLabel.text = title;

    UILabel *valueLabel = [self pp_labelWithFont:[GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold]
                                           color:PPPetCareViewerTextColor()
                                           lines:2];
    valueLabel.text = value.length > 0 ? value : PPPetCareViewerLocalized(@"pet_care_viewer_not_specified", @"Not specified");

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, valueLabel]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 3.0;
    [container addSubview:textStack];

    [NSLayoutConstraint activateConstraints:@[
        [container.heightAnchor constraintGreaterThanOrEqualToConstant:106.0],

        [iconShell.topAnchor constraintEqualToAnchor:container.topAnchor constant:14.0],
        [iconShell.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:14.0],
        [iconShell.widthAnchor constraintEqualToConstant:32.0],
        [iconShell.heightAnchor constraintEqualToConstant:32.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:16.0],
        [iconView.heightAnchor constraintEqualToConstant:16.0],

        [textStack.topAnchor constraintEqualToAnchor:iconShell.bottomAnchor constant:10.0],
        [textStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:14.0],
        [textStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-14.0],
        [textStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-14.0]
    ]];
    return container;
}

- (UIView *)pp_indicationHighlightRowWithSymbol:(NSString *)symbol
                                          title:(NSString *)title
                                       subtitle:(NSString *)subtitle
                                           tint:(UIColor *)tint
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = PPPetCareViewerQuietTileColor();
    container.layer.cornerRadius = 18.0;
    container.layer.borderWidth = 0.8;
    [container pp_setBorderColor:[tint colorWithAlphaComponent:0.16]];
    if (@available(iOS 13.0, *)) {
        container.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *iconShell = [[UIView alloc] init];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.backgroundColor = [tint colorWithAlphaComponent:0.12];
    iconShell.layer.cornerRadius = 16.0;
    if (@available(iOS 13.0, *)) {
        iconShell.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [container addSubview:iconShell];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:symbol] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = tint;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconShell addSubview:iconView];

    UILabel *titleLabel = [self pp_labelWithFont:[GM boldFontWithSize:13.5] ?: [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold]
                                           color:PPPetCareViewerTextColor()
                                           lines:1];
    titleLabel.text = title;

    UILabel *subLabel = [self pp_labelWithFont:[GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular]
                                         color:PPPetCareViewerSecondaryTextColor()
                                         lines:0];
    subLabel.text = subtitle;

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subLabel]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 3.0;
    [container addSubview:textStack];

    [NSLayoutConstraint activateConstraints:@[
        [container.heightAnchor constraintGreaterThanOrEqualToConstant:64.0],

        [iconShell.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:14.0],
        [iconShell.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [iconShell.widthAnchor constraintEqualToConstant:32.0],
        [iconShell.heightAnchor constraintEqualToConstant:32.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:16.0],
        [iconView.heightAnchor constraintEqualToConstant:16.0],

        [textStack.topAnchor constraintEqualToAnchor:container.topAnchor constant:12.0],
        [textStack.leadingAnchor constraintEqualToAnchor:iconShell.trailingAnchor constant:12.0],
        [textStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-14.0],
        [textStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-12.0]
    ]];
    return container;
}

#pragma mark - Motion & Staggered Entrance

- (void)pp_prepareEntranceState
{
    NSArray<UIView *> *sections = @[
        self.heroStageView,
        self.bentoMatrixCardView,
        self.dosageCalculatorCardView,
        self.indicationsCardView,
        self.descriptionCardView,
        self.vetConsultCardView
    ];

    for (UIView *view in sections) {
        if (!view) continue;
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 24.0);
    }

    self.bottomBar.alpha = 0.0;
    self.bottomBar.transform = CGAffineTransformMakeTranslation(0.0, 28.0);
}

- (void)pp_beginEntranceAnimationIfNeeded
{
    if (self.didAnimateEntrance) {
        return;
    }
    self.didAnimateEntrance = YES;

    NSArray<UIView *> *sections = @[
        self.heroStageView,
        self.bentoMatrixCardView,
        self.dosageCalculatorCardView,
        self.indicationsCardView,
        self.descriptionCardView,
        self.vetConsultCardView
    ];

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();

    for (NSUInteger idx = 0; idx < sections.count; idx++) {
        UIView *view = sections[idx];
        if (!view) continue;
        NSTimeInterval delay = 0.06 * idx;

        if (reduceMotion) {
            [UIView animateWithDuration:PPPetCareViewerReducedMotionDuration
                                  delay:delay
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                view.alpha = 1.0;
                view.transform = CGAffineTransformIdentity;
            } completion:nil];
        } else {
            [UIView animateWithDuration:0.58
                                  delay:delay
                 usingSpringWithDamping:0.84
                  initialSpringVelocity:0.24
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                view.alpha = 1.0;
                view.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
    }

    // Bottom Bar
    NSTimeInterval barDelay = 0.12;
    if (reduceMotion) {
        [UIView animateWithDuration:PPPetCareViewerReducedMotionDuration
                              delay:barDelay
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.bottomBar.alpha = 1.0;
            self.bottomBar.transform = CGAffineTransformIdentity;
        } completion:nil];
    } else {
        [UIView animateWithDuration:0.62
                              delay:barDelay
             usingSpringWithDamping:0.82
              initialSpringVelocity:0.28
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.bottomBar.alpha = 1.0;
            self.bottomBar.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)pp_beginAmbientGlowAnimationIfNeeded
{
    if (self.didStartGlowAnimation) {
        return;
    }
    self.didStartGlowAnimation = YES;

    [UIView animateWithDuration:5.8
                          delay:0.0
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.backgroundGlowTopView.transform = CGAffineTransformMakeTranslation(-18.0, 14.0);
        self.backgroundGlowMiddleView.transform = CGAffineTransformMakeTranslation(14.0, -12.0);
    } completion:nil];

    [UIView animateWithDuration:7.2
                          delay:0.0
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.backgroundGlowBottomView.transform = CGAffineTransformMakeTranslation(22.0, -16.0);
    } completion:nil];
}

@end
