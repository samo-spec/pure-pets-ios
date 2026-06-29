//
//  PPPetCareViewerVC.m
//  Pure Pets
//
//  Created by Codex on 4/26/26.
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
#import "PPFunc.h"
#import "PPRootTabBarController.h"

static CGFloat const PPPetCareViewerSideInset = 16.0;
static CGFloat const PPPetCareViewerSectionSpacing = 16.0;
static CGFloat const PPPetCareViewerSurfaceRadius = 32.0;
static CGFloat const PPPetCareViewerArtworkCornerRadius = 28.0;
static CGFloat const PPPetCareViewerBottomBarBase = 106.0;
static CGFloat const PPPetCareViewerEntranceCardOffset = 26.0;
static CGFloat const PPPetCareViewerEntranceContentOffset = 18.0;
static CGFloat const PPPetCareViewerEntranceTileOffset = 14.0;
static NSTimeInterval const PPPetCareViewerEntranceCardDuration = 0.62;
static NSTimeInterval const PPPetCareViewerEntranceContentDuration = 0.52;
static NSTimeInterval const PPPetCareViewerReducedMotionDuration = 0.18;

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
    return AppPrimaryClr ?: [UIColor colorWithRed:0.10 green:0.67 blue:0.60 alpha:1.0];
}

static UIColor *PPPetCareViewerWarmAccentColor(void)
{
    return [UIColor colorWithRed:0.96 green:0.77 blue:0.46 alpha:1.0];
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
            return dark ? [UIColor colorWithWhite:0.11 alpha:0.88] : [UIColor colorWithWhite:1.0 alpha:0.90];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.90];
}

static UIColor *PPPetCareViewerElevatedSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark ? [UIColor colorWithWhite:0.13 alpha:0.96] : [UIColor colorWithWhite:1.0 alpha:0.98];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.98];
}

static UIColor *PPPetCareViewerBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark ? [UIColor colorWithWhite:1.0 alpha:0.10] : [UIColor colorWithWhite:0.08 alpha:0.08];
        }];
    }
    return [UIColor colorWithWhite:0.08 alpha:0.08];
}

static UIColor *PPPetCareViewerQuietTileColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark ? [UIColor colorWithWhite:1.0 alpha:0.045] : [UIColor colorWithWhite:0.0 alpha:0.025];
        }];
    }
    return [UIColor colorWithWhite:0.0 alpha:0.025];
}

@interface PPPetCareViewerVC ()
@property (nonatomic, strong) VetMedicineModel *medicine;
@property (nonatomic, copy) NSString *mainKindName;
@property (nonatomic, strong) UIView *backgroundGlowTopView;
@property (nonatomic, strong) UIView *backgroundGlowMiddleView;
@property (nonatomic, strong) UIView *backgroundGlowBottomView;

@property (nonatomic, strong) BBCartBottomBar *bottomBar;
@property (nonatomic, strong) NSLayoutConstraint *bottomBarHeightConstraint;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *heroView;
@property (nonatomic, strong) UIView *heroArtworkView;
@property (nonatomic, strong) UIImageView *heroImageView;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) UIView *heroIconPlateView;
@property (nonatomic, strong) UIImageView *heroIconView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIStackView *heroChipsStackView;
@property (nonatomic, strong) PPHomeInsetLabel *categoryChipLabel;
@property (nonatomic, strong) PPHomeInsetLabel *petKindChipLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) PPHomeInsetLabel *statusLabel;
@property (nonatomic, strong) PPHomeInsetLabel *cartStateLabel;
@property (nonatomic, strong) UIView *proofSectionView;
@property (nonatomic, strong) UILabel *proofTitleLabel;
@property (nonatomic, strong) UIStackView *proofGridStackView;
@property (nonatomic, strong) UIView *storySectionView;
@property (nonatomic, strong) UILabel *storyTitleLabel;
@property (nonatomic, strong) UILabel *storyBodyLabel;
@property (nonatomic, strong) UIStackView *storyHighlightsStackView;
@property (nonatomic, strong) UIView *careSectionView;
@property (nonatomic, strong) UILabel *careTitleLabel;
@property (nonatomic, strong) UILabel *careBodyLabel;
@property (nonatomic, strong) PPHomeInsetLabel *careHintLabel;
@property (nonatomic, strong) NSLayoutConstraint *heroArtworkHeightConstraint;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) BOOL didStartGlowAnimation;

- (void)pp_buildBackgroundAtmosphere;
- (UIView *)pp_backgroundGlowViewWithRadius:(CGFloat)radius;
- (NSArray<UIView *> *)pp_compactEntranceViews:(NSArray<UIView *> *)views;
- (NSArray<UIView *> *)pp_metricTileEntranceViews;
- (NSArray<UIView *> *)pp_storyHighlightEntranceViews;
- (void)pp_prepareEntranceViews:(NSArray<UIView *> *)views
                 verticalOffset:(CGFloat)verticalOffset
               alternatingShift:(CGFloat)alternatingShift
                          scale:(CGFloat)scale
                       rotation:(CGFloat)rotation;
- (void)pp_animateEntranceViews:(NSArray<UIView *> *)views
                   initialDelay:(NSTimeInterval)initialDelay
                      stepDelay:(NSTimeInterval)stepDelay
                       duration:(NSTimeInterval)duration
                        damping:(CGFloat)damping
                       velocity:(CGFloat)velocity;
- (BOOL)pp_isMedicineCurrentlyAvailable;
- (void)pp_syncBottomBarState;
- (void)pp_refreshCartStateLabelWithQuantity:(NSInteger)existingQuantity remainingToAdd:(NSInteger)remainingToAdd;
- (BOOL)pp_ensureSignedInForAction;
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
    self.heroGradientLayer.frame = self.heroArtworkView.bounds;
    self.heroGradientLayer.cornerRadius = self.heroArtworkView.layer.cornerRadius;
    self.heroView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.heroView.bounds
                                                                cornerRadius:self.heroView.layer.cornerRadius].CGPath;
    self.proofSectionView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.proofSectionView.bounds
                                                                         cornerRadius:self.proofSectionView.layer.cornerRadius].CGPath;
    self.storySectionView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.storySectionView.bounds
                                                                         cornerRadius:self.storySectionView.layer.cornerRadius].CGPath;
    self.careSectionView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.careSectionView.bounds
                                                                        cornerRadius:self.careSectionView.layer.cornerRadius].CGPath;

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
    [self pp_buildHeroSection];
    [self pp_buildProofSection];
    [self pp_buildStorySection];
    [self pp_buildCareSection];
}

- (void)pp_buildBackgroundAtmosphere
{
    self.backgroundGlowTopView = [self pp_backgroundGlowViewWithRadius:138.0];
    self.backgroundGlowMiddleView = [self pp_backgroundGlowViewWithRadius:110.0];
    self.backgroundGlowBottomView = [self pp_backgroundGlowViewWithRadius:166.0];

    [self.view addSubview:self.backgroundGlowTopView];
    [self.view addSubview:self.backgroundGlowMiddleView];
    [self.view addSubview:self.backgroundGlowBottomView];

    [NSLayoutConstraint activateConstraints:@[
        [self.backgroundGlowTopView.widthAnchor constraintEqualToConstant:276.0],
        [self.backgroundGlowTopView.heightAnchor constraintEqualToConstant:276.0],
        [self.backgroundGlowTopView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-82.0],
        [self.backgroundGlowTopView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:96.0],

        [self.backgroundGlowMiddleView.widthAnchor constraintEqualToConstant:220.0],
        [self.backgroundGlowMiddleView.heightAnchor constraintEqualToConstant:220.0],
        [self.backgroundGlowMiddleView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:214.0],
        [self.backgroundGlowMiddleView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-96.0],

        [self.backgroundGlowBottomView.widthAnchor constraintEqualToConstant:332.0],
        [self.backgroundGlowBottomView.heightAnchor constraintEqualToConstant:332.0],
        [self.backgroundGlowBottomView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-142.0],
        [self.backgroundGlowBottomView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:112.0]
    ]];
}

- (UIView *)pp_backgroundGlowViewWithRadius:(CGFloat)radius
{
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.userInteractionEnabled = NO;
    view.alpha = 0.0;
    view.layer.cornerRadius = radius;
    view.layer.shadowRadius = 64.0;
    view.layer.shadowOpacity = 0.28;
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

- (void)pp_buildHeroSection
{
    self.heroView = [self pp_surfaceSectionView];
    self.heroView.backgroundColor = PPPetCareViewerElevatedSurfaceColor();
    self.heroView.layer.cornerRadius = 34.0;
    self.heroView.layer.shadowOpacity = 0.12;
    self.heroView.layer.shadowRadius = 34.0;
    self.heroView.layer.shadowOffset = CGSizeMake(0.0, 18.0);
    [self.contentView addSubview:self.heroView];

    self.heroArtworkView = [[UIView alloc] init];
    self.heroArtworkView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroArtworkView.clipsToBounds = YES;
    self.heroArtworkView.layer.cornerRadius = PPPetCareViewerArtworkCornerRadius;
    self.heroArtworkView.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        self.heroArtworkView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroView addSubview:self.heroArtworkView];

    self.heroImageView = [[UIImageView alloc] init];
    self.heroImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.heroImageView.clipsToBounds = YES;
    [self.heroArtworkView addSubview:self.heroImageView];

    self.heroGradientLayer = [CAGradientLayer layer];
    self.heroGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.heroGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    [self.heroArtworkView.layer insertSublayer:self.heroGradientLayer above:self.heroImageView.layer];

    self.heroIconPlateView = [[UIView alloc] init];
    self.heroIconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIconPlateView.layer.cornerRadius = 24.0;
    self.heroIconPlateView.layer.borderWidth = 0.9;
    if (@available(iOS 13.0, *)) {
        self.heroIconPlateView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroArtworkView addSubview:self.heroIconPlateView];

    UIImageSymbolConfiguration *heroIconConfig = [UIImageSymbolConfiguration configurationWithPointSize:22.0 weight:UIImageSymbolWeightSemibold];
    self.heroIconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"cross.case.fill" withConfiguration:heroIconConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    self.heroIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.heroIconPlateView addSubview:self.heroIconView];

    self.eyebrowLabel = [self pp_labelWithFont:[GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold]
                                         color:UIColor.whiteColor
                                         lines:1];
    self.eyebrowLabel.text = PPPetCareViewerLocalized(@"pet_care_viewer_modern_badge", @"Modern pet pharmacy");
    [self.heroArtworkView addSubview:self.eyebrowLabel];

    self.titleLabel = [self pp_labelWithFont:[GM boldFontWithSize:30.0] ?: [UIFont systemFontOfSize:30.0 weight:UIFontWeightBold]
                                       color:PPPetCareViewerTextColor()
                                       lines:2];
    self.titleLabel.minimumScaleFactor = 0.78;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    [self.heroView addSubview:self.titleLabel];

    self.subtitleLabel = [self pp_labelWithFont:[GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium]
                                          color:PPPetCareViewerSecondaryTextColor()
                                          lines:2];
    [self.heroView addSubview:self.subtitleLabel];

    self.heroChipsStackView = [[UIStackView alloc] init];
    self.heroChipsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroChipsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.heroChipsStackView.alignment = UIStackViewAlignmentLeading;
    self.heroChipsStackView.spacing = 10.0;
    [self.heroView addSubview:self.heroChipsStackView];

    self.categoryChipLabel = [self pp_pillLabelWithFont:[GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium]];
    self.petKindChipLabel = [self pp_pillLabelWithFont:[GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium]];
    
    self.statusLabel = [self pp_pillLabelWithFont:[GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold]];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
 
    
    [self.heroChipsStackView addArrangedSubview:self.categoryChipLabel];
    [self.heroChipsStackView addArrangedSubview:self.petKindChipLabel];
    [self.heroChipsStackView addArrangedSubview:self.statusLabel];
    self.priceLabel = [self pp_labelWithFont:[GM BlackFontWithSize:26.0] ?: [UIFont systemFontOfSize:24.0 weight:UIFontWeightBold]
                                       color:PPPetCareViewerAccentColor()
                                       lines:1];
    [self.heroView addSubview:self.priceLabel];

    

    self.cartStateLabel = [self pp_pillLabelWithFont:[GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium]];
    self.cartStateLabel.numberOfLines = 1;
    [self.heroView addSubview:self.cartStateLabel];

    self.heroArtworkHeightConstraint = [self.heroArtworkView.heightAnchor constraintEqualToConstant:248.0];
    [NSLayoutConstraint activateConstraints:@[
        [self.heroView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12.0],
        [self.heroView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareViewerSideInset],
        [self.heroView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareViewerSideInset],

        [self.heroArtworkView.topAnchor constraintEqualToAnchor:self.heroView.topAnchor constant:18.0],
        [self.heroArtworkView.leadingAnchor constraintEqualToAnchor:self.heroView.leadingAnchor constant:18.0],
        [self.heroArtworkView.trailingAnchor constraintEqualToAnchor:self.heroView.trailingAnchor constant:-18.0],
        self.heroArtworkHeightConstraint,

        [self.heroImageView.centerXAnchor constraintEqualToAnchor:self.heroArtworkView.centerXAnchor],
        [self.heroImageView.centerYAnchor constraintEqualToAnchor:self.heroArtworkView.centerYAnchor constant:14.0],
        [self.heroImageView.widthAnchor constraintLessThanOrEqualToAnchor:self.heroArtworkView.widthAnchor multiplier:0.60],
        [self.heroImageView.heightAnchor constraintLessThanOrEqualToAnchor:self.heroArtworkView.heightAnchor multiplier:0.74],
        [self.heroImageView.widthAnchor constraintGreaterThanOrEqualToConstant:142.0],
        [self.heroImageView.heightAnchor constraintGreaterThanOrEqualToConstant:142.0],

        [self.heroIconPlateView.topAnchor constraintEqualToAnchor:self.heroArtworkView.topAnchor constant:16.0],
        [self.heroIconPlateView.trailingAnchor constraintEqualToAnchor:self.heroArtworkView.trailingAnchor constant:-16.0],
        [self.heroIconPlateView.widthAnchor constraintEqualToConstant:48.0],
        [self.heroIconPlateView.heightAnchor constraintEqualToConstant:48.0],

        [self.heroIconView.centerXAnchor constraintEqualToAnchor:self.heroIconPlateView.centerXAnchor],
        [self.heroIconView.centerYAnchor constraintEqualToAnchor:self.heroIconPlateView.centerYAnchor],
        [self.heroIconView.widthAnchor constraintEqualToConstant:24.0],
        [self.heroIconView.heightAnchor constraintEqualToConstant:24.0],

        [self.eyebrowLabel.leadingAnchor constraintEqualToAnchor:self.heroArtworkView.leadingAnchor constant:18.0],
        [self.eyebrowLabel.topAnchor constraintEqualToAnchor:self.heroArtworkView.topAnchor constant:18.0],
        [self.eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroIconPlateView.leadingAnchor constant:-12.0],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.heroArtworkView.bottomAnchor constant:18.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.heroView.leadingAnchor constant:22.0],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.heroView.trailingAnchor constant:-22.0],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8.0],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],

        [self.heroChipsStackView.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:12.0],
        [self.heroChipsStackView.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.heroChipsStackView.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroView.trailingAnchor constant:-22.0],

        [self.priceLabel.topAnchor constraintEqualToAnchor:self.heroChipsStackView.bottomAnchor constant:16.0],
        [self.priceLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.priceLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.statusLabel.leadingAnchor constant:-12.0],

       

        [self.cartStateLabel.topAnchor constraintEqualToAnchor:self.priceLabel.bottomAnchor constant:14.0],
        [self.cartStateLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.cartStateLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroView.trailingAnchor constant:-22.0],
        [self.cartStateLabel.bottomAnchor constraintEqualToAnchor:self.heroView.bottomAnchor constant:-22.0],
        [self.cartStateLabel.heightAnchor constraintGreaterThanOrEqualToConstant:32.0]
    ]];
}

- (void)pp_buildProofSection
{
    self.proofSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.proofSectionView];

    self.proofTitleLabel = [self pp_sectionTitleLabelWithText:PPPetCareViewerLocalized(@"pet_care_viewer_trending_title", @"Trending details")];
    [self.proofSectionView addSubview:self.proofTitleLabel];

    self.proofGridStackView = [[UIStackView alloc] init];
    self.proofGridStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.proofGridStackView.axis = UILayoutConstraintAxisVertical;
    self.proofGridStackView.spacing = 12.0;
    [self.proofSectionView addSubview:self.proofGridStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.proofSectionView.topAnchor constraintEqualToAnchor:self.heroView.bottomAnchor constant:PPPetCareViewerSectionSpacing],
        [self.proofSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareViewerSideInset],
        [self.proofSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareViewerSideInset],

        [self.proofTitleLabel.topAnchor constraintEqualToAnchor:self.proofSectionView.topAnchor constant:20.0],
        [self.proofTitleLabel.leadingAnchor constraintEqualToAnchor:self.proofSectionView.leadingAnchor constant:20.0],
        [self.proofTitleLabel.trailingAnchor constraintEqualToAnchor:self.proofSectionView.trailingAnchor constant:-20.0],

        [self.proofGridStackView.topAnchor constraintEqualToAnchor:self.proofTitleLabel.bottomAnchor constant:16.0],
        [self.proofGridStackView.leadingAnchor constraintEqualToAnchor:self.proofSectionView.leadingAnchor constant:16.0],
        [self.proofGridStackView.trailingAnchor constraintEqualToAnchor:self.proofSectionView.trailingAnchor constant:-16.0],
        [self.proofGridStackView.bottomAnchor constraintEqualToAnchor:self.proofSectionView.bottomAnchor constant:-16.0]
    ]];
}

- (void)pp_buildStorySection
{
    self.storySectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.storySectionView];

    self.storyTitleLabel = [self pp_sectionTitleLabelWithText:PPPetCareViewerLocalized(@"pet_care_viewer_story_title", @"Why it stands out")];
    [self.storySectionView addSubview:self.storyTitleLabel];

    self.storyBodyLabel = [self pp_labelWithFont:[GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular]
                                           color:PPPetCareViewerTextColor()
                                           lines:0];
    [self.storySectionView addSubview:self.storyBodyLabel];

    self.storyHighlightsStackView = [[UIStackView alloc] init];
    self.storyHighlightsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.storyHighlightsStackView.axis = UILayoutConstraintAxisVertical;
    self.storyHighlightsStackView.spacing = 10.0;
    [self.storySectionView addSubview:self.storyHighlightsStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.storySectionView.topAnchor constraintEqualToAnchor:self.proofSectionView.bottomAnchor constant:PPPetCareViewerSectionSpacing],
        [self.storySectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareViewerSideInset],
        [self.storySectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareViewerSideInset],

        [self.storyTitleLabel.topAnchor constraintEqualToAnchor:self.storySectionView.topAnchor constant:20.0],
        [self.storyTitleLabel.leadingAnchor constraintEqualToAnchor:self.storySectionView.leadingAnchor constant:20.0],
        [self.storyTitleLabel.trailingAnchor constraintEqualToAnchor:self.storySectionView.trailingAnchor constant:-20.0],

        [self.storyBodyLabel.topAnchor constraintEqualToAnchor:self.storyTitleLabel.bottomAnchor constant:10.0],
        [self.storyBodyLabel.leadingAnchor constraintEqualToAnchor:self.storySectionView.leadingAnchor constant:20.0],
        [self.storyBodyLabel.trailingAnchor constraintEqualToAnchor:self.storySectionView.trailingAnchor constant:-20.0],

        [self.storyHighlightsStackView.topAnchor constraintEqualToAnchor:self.storyBodyLabel.bottomAnchor constant:16.0],
        [self.storyHighlightsStackView.leadingAnchor constraintEqualToAnchor:self.storySectionView.leadingAnchor constant:16.0],
        [self.storyHighlightsStackView.trailingAnchor constraintEqualToAnchor:self.storySectionView.trailingAnchor constant:-16.0],
        [self.storyHighlightsStackView.bottomAnchor constraintEqualToAnchor:self.storySectionView.bottomAnchor constant:-16.0]
    ]];
}

- (void)pp_buildCareSection
{
    self.careSectionView = [self pp_surfaceSectionView];
    [self.contentView addSubview:self.careSectionView];

    self.careTitleLabel = [self pp_sectionTitleLabelWithText:PPPetCareViewerLocalized(@"pet_care_viewer_checkout_title", @"Before you checkout")];
    [self.careSectionView addSubview:self.careTitleLabel];

    self.careBodyLabel = [self pp_labelWithFont:[GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium]
                                          color:PPPetCareViewerSecondaryTextColor()
                                          lines:0];
    [self.careSectionView addSubview:self.careBodyLabel];

    self.careHintLabel = [self pp_pillLabelWithFont:[GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium]];
    self.careHintLabel.numberOfLines = 0;
    [self.careSectionView addSubview:self.careHintLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.careSectionView.topAnchor constraintEqualToAnchor:self.storySectionView.bottomAnchor constant:PPPetCareViewerSectionSpacing],
        [self.careSectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPPetCareViewerSideInset],
        [self.careSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPPetCareViewerSideInset],
        [self.careSectionView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-28.0],

        [self.careTitleLabel.topAnchor constraintEqualToAnchor:self.careSectionView.topAnchor constant:20.0],
        [self.careTitleLabel.leadingAnchor constraintEqualToAnchor:self.careSectionView.leadingAnchor constant:20.0],
        [self.careTitleLabel.trailingAnchor constraintEqualToAnchor:self.careSectionView.trailingAnchor constant:-20.0],

        [self.careBodyLabel.topAnchor constraintEqualToAnchor:self.careTitleLabel.bottomAnchor constant:10.0],
        [self.careBodyLabel.leadingAnchor constraintEqualToAnchor:self.careSectionView.leadingAnchor constant:20.0],
        [self.careBodyLabel.trailingAnchor constraintEqualToAnchor:self.careSectionView.trailingAnchor constant:-20.0],

        [self.careHintLabel.topAnchor constraintEqualToAnchor:self.careBodyLabel.bottomAnchor constant:14.0],
        [self.careHintLabel.leadingAnchor constraintEqualToAnchor:self.careSectionView.leadingAnchor constant:20.0],
        [self.careHintLabel.trailingAnchor constraintEqualToAnchor:self.careSectionView.trailingAnchor constant:-20.0],
        [self.careHintLabel.bottomAnchor constraintEqualToAnchor:self.careSectionView.bottomAnchor constant:-18.0],
        [self.careHintLabel.heightAnchor constraintGreaterThanOrEqualToConstant:38.0]
    ]];
}

- (void)pp_updateViewportLayout
{
    CGFloat safeBottom = self.view.safeAreaInsets.bottom;
    CGFloat bottomBarHeight = PPPetCareViewerBottomBarBase + safeBottom;
    if (fabs(self.bottomBarHeightConstraint.constant - bottomBarHeight) > 0.5) {
        self.bottomBarHeightConstraint.constant = bottomBarHeight;
    }

    CGFloat width = CGRectGetWidth(self.view.bounds) - (PPPetCareViewerSideInset * 2.0) - 36.0;
    if (width > 0.0) {
        BOOL isPad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
        CGFloat targetArtworkHeight = isPad
            ? MIN(MAX(width * 0.48, 248.0), 340.0)
            : MIN(MAX(width * 0.64, 220.0), 296.0);
        if (fabs(self.heroArtworkHeightConstraint.constant - targetArtworkHeight) > 0.5) {
            self.heroArtworkHeightConstraint.constant = targetArtworkHeight;
        }
    }

    UIEdgeInsets inset = self.scrollView.contentInset;
    inset.bottom = bottomBarHeight + 20.0;
    self.scrollView.contentInset = inset;
    self.scrollView.scrollIndicatorInsets = inset;
}

#pragma mark - Content

- (void)pp_applyContent
{
    self.titleLabel.text = self.medicine.title.length > 0 ? self.medicine.title : PPPetCareViewerLocalized(@"pet_care_medicine_untitled", @"Medicine");
    self.subtitleLabel.text = self.medicine.category.length > 0 ? self.medicine.category : PPPetCareViewerLocalized(@"pet_care_viewer_about_medicine", @"Veterinary care essential");
    self.categoryChipLabel.text = [self pp_categoryText];
    self.petKindChipLabel.text = [self pp_petKindText];
    self.priceLabel.text = [self pp_priceText];
    self.statusLabel.text = [self pp_availabilityText];
    self.storyBodyLabel.text = self.medicine.medicineDescription.length > 0
        ? self.medicine.medicineDescription
        : PPPetCareViewerLocalized(@"pet_care_viewer_no_description", @"No description has been added yet.");
    self.careBodyLabel.text = PPPetCareViewerLocalized(@"pet_care_viewer_checkout_hint", @"Use the cart bar below to choose a quantity and add this medicine instantly.");
    self.storyBodyLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.careBodyLabel.textAlignment = Language.alignmentForCurrentLanguage;

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:58.0 weight:UIImageSymbolWeightSemibold];
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

    [self pp_reloadProofTiles];
    [self pp_reloadStoryHighlights];
    self.view.accessibilityLabel = self.titleLabel.text;
}

- (void)pp_reloadProofTiles
{
    for (UIView *view in self.proofGridStackView.arrangedSubviews) {
        [self.proofGridStackView removeArrangedSubview:view];
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
    UIColor *greenAccent = [UIColor colorWithRed:0.22 green:0.67 blue:0.44 alpha:1.0];
    UIColor *violetAccent = [UIColor colorWithRed:0.52 green:0.43 blue:0.86 alpha:1.0];
    BOOL isAvailable = [self pp_isMedicineCurrentlyAvailable];

    [firstRow addArrangedSubview:[self pp_metricTileWithSymbol:@"tag.fill"
                                                         title:PPPetCareViewerLocalized(@"pet_care_viewer_category", @"Category")
                                                         value:[self pp_categoryText]
                                                          tint:accent]];
    [firstRow addArrangedSubview:[self pp_metricTileWithSymbol:isAvailable ? @"checkmark.seal.fill" : @"xmark.seal.fill"
                                                         title:PPPetCareViewerLocalized(@"pet_care_viewer_availability", @"Availability")
                                                         value:[self pp_availabilityText]
                                                          tint:isAvailable ? greenAccent : UIColor.systemRedColor]];

    [secondRow addArrangedSubview:[self pp_metricTileWithSymbol:self.medicine.stockQuantity > 0 ? @"shippingbox.fill" : @"exclamationmark.triangle.fill"
                                                          title:PPPetCareViewerLocalized(@"pet_care_medicine_stock", @"Stock")
                                                          value:[self pp_stockText]
                                                           tint:self.medicine.stockQuantity > 0 ? greenAccent : UIColor.systemRedColor]];
    [secondRow addArrangedSubview:[self pp_metricTileWithSymbol:@"clock.fill"
                                                          title:PPPetCareViewerLocalized(@"pet_care_viewer_added_date", @"Added")
                                                          value:[self pp_dateText:self.medicine.createdAt]
                                                           tint:violetAccent]];

    [self.proofGridStackView addArrangedSubview:firstRow];
    [self.proofGridStackView addArrangedSubview:secondRow];
}

- (void)pp_reloadStoryHighlights
{
    for (UIView *view in self.storyHighlightsStackView.arrangedSubviews) {
        [self.storyHighlightsStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    UIColor *accent = PPPetCareViewerAccentColor();
    BOOL isAvailable = [self pp_isMedicineCurrentlyAvailable];
    NSString *fulfilmentCopy = isAvailable
        ? PPPetCareViewerLocalized(@"pet_care_viewer_available_copy", @"This medicine is available now from the shared pet-care catalog.")
        : PPPetCareViewerLocalized(@"pet_care_viewer_unavailable_copy", @"This medicine is currently not available from the shared pet-care catalog.");
    NSString *catalogCopy = isAvailable
        ? PPPetCareViewerLocalized(@"pet_care_viewer_direct_add_copy", @"This medicine can be added directly from the shared pet-care catalog.")
        : PPPetCareViewerLocalized(@"pet_care_viewer_unavailable_hint", @"Browse another medicine or check back again while availability updates.");

    [self.storyHighlightsStackView addArrangedSubview:[self pp_highlightRowWithSymbol:isAvailable ? @"checkmark.circle.fill" : @"xmark.circle.fill"
                                                                                  text:fulfilmentCopy
                                                                                  tint:isAvailable ? accent : UIColor.systemRedColor]];
    [self.storyHighlightsStackView addArrangedSubview:[self pp_highlightRowWithSymbol:@"bag.fill.badge.plus"
                                                                                  text:catalogCopy
                                                                                  tint:accent]];
}

- (NSString *)pp_priceText
{
    NSString *currency = PPPetCareMedicineCurrencyCode(self.medicine);
    NSString *formatted = [GM formatPrice:@(MAX(self.medicine.price, 0.0)) currencyCode:currency];
    return formatted.length > 0 ? formatted : [NSString stringWithFormat:@"%.2f %@", MAX(self.medicine.price, 0.0), currency];
}

- (NSString *)pp_categoryText
{
    return self.medicine.category.length > 0 ? self.medicine.category : PPPetCareViewerLocalized(@"pet_care_viewer_not_specified", @"Not specified");
}

- (NSString *)pp_petKindText
{
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

- (BOOL)pp_isMedicineCurrentlyAvailable
{
    return self.medicine.isAvailable && self.medicine.stockQuantity > 0;
}

- (NSString *)pp_availabilityText
{
    return [self pp_isMedicineCurrentlyAvailable]
        ? PPPetCareViewerLocalized(@"pet_care_medicine_available", @"Available")
        : PPPetCareViewerLocalized(@"pet_care_medicine_not_available", @"Not available");
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
    UIColor *warmAccent = PPPetCareViewerWarmAccentColor();
    UIColor *secondaryGlow = [UIColor colorWithRed:0.22 green:0.49 blue:0.86 alpha:1.0];

    

    self.backgroundGlowTopView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.16 : 0.11];
    self.backgroundGlowTopView.layer.shadowColor = accent.CGColor;
    self.backgroundGlowTopView.alpha = 1.0;

    self.backgroundGlowMiddleView.backgroundColor = [warmAccent colorWithAlphaComponent:dark ? 0.11 : 0.08];
    self.backgroundGlowMiddleView.layer.shadowColor = warmAccent.CGColor;
    self.backgroundGlowMiddleView.alpha = 1.0;

    self.backgroundGlowBottomView.backgroundColor = [secondaryGlow colorWithAlphaComponent:dark ? 0.14 : 0.10];
    self.backgroundGlowBottomView.layer.shadowColor = secondaryGlow.CGColor;
    self.backgroundGlowBottomView.alpha = 1.0;

    self.heroView.backgroundColor = PPPetCareViewerElevatedSurfaceColor();
    [self.heroView pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.20 : 0.10]];
    [self.heroView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:dark ? 0.55 : 0.18]];

    self.heroArtworkView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.14 : 0.10];
    [self.heroArtworkView pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.26 : 0.16]];
    self.heroGradientLayer.colors = @[
        (__bridge id)[accent colorWithAlphaComponent:dark ? 0.26 : 0.18].CGColor,
        (__bridge id)[warmAccent colorWithAlphaComponent:dark ? 0.20 : 0.13].CGColor,
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:dark ? 0.54 : 0.18].CGColor
    ];
    self.heroGradientLayer.locations = @[@0.0, @0.55, @1.0];
    self.heroIconPlateView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:dark ? 0.12 : 0.18];
    [self.heroIconPlateView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.24]];
    self.heroIconView.tintColor = UIColor.whiteColor;

    self.titleLabel.textColor = PPPetCareViewerTextColor();
    self.subtitleLabel.textColor = PPPetCareViewerSecondaryTextColor();
    self.priceLabel.textColor = accent;

    UIColor *statusTint = [self pp_isMedicineCurrentlyAvailable] ? accent : UIColor.systemRedColor;
    [self pp_applyTintPillToLabel:self.statusLabel
                             tint:statusTint
                         fillAlpha:(dark ? 0.24 : 0.14)
                       borderAlpha:(dark ? 0.34 : 0.20)
                         textColor:statusTint];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;

    [self pp_applyTintPillToLabel:self.categoryChipLabel
                             tint:accent
                         fillAlpha:(dark ? 0.18 : 0.10)
                       borderAlpha:(dark ? 0.28 : 0.18)
                         textColor:accent];
    [self pp_applyTintPillToLabel:self.petKindChipLabel
                             tint:PPPetCareViewerWarmAccentColor()
                         fillAlpha:(dark ? 0.16 : 0.10)
                       borderAlpha:(dark ? 0.24 : 0.16)
                         textColor:PPPetCareViewerTextColor()];

    [self pp_applySectionTheme:self.proofSectionView];
    [self pp_applySectionTheme:self.storySectionView];
    [self pp_applySectionTheme:self.careSectionView];
    self.proofTitleLabel.textColor = PPPetCareViewerTextColor();
    self.storyTitleLabel.textColor = PPPetCareViewerTextColor();
    self.storyBodyLabel.textColor = PPPetCareViewerTextColor();
    self.careTitleLabel.textColor = PPPetCareViewerTextColor();
    self.careBodyLabel.textColor = PPPetCareViewerSecondaryTextColor();

    [self pp_syncBottomBarState];
}

- (void)pp_applySectionTheme:(UIView *)section
{
    section.backgroundColor = PPPetCareViewerSurfaceColor();
    [section pp_setBorderColor:PPPetCareViewerBorderColor()];
    [section pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:0.10]];
    section.layer.shadowOpacity = 0.10;
    section.layer.shadowRadius = 26.0;
    section.layer.shadowOffset = CGSizeMake(0.0, 14.0);
}

#pragma mark - Cart

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

    [self pp_refreshCartStateLabelWithQuantity:existingQuantity remainingToAdd:remainingToAdd];

    NSString *careHint = nil;
    if (![self pp_isMedicineCurrentlyAvailable]) {
        careHint = PPPetCareViewerLocalized(@"pet_care_medicine_not_available", @"Not available");
    } else if (remainingToAdd <= 0) {
        careHint = PPPetCareViewerLocalized(@"pet_care_viewer_cart_limit_copy", @"All available stock is already in your cart.");
    } else if (remainingToAdd < stockQuantity) {
        careHint = [NSString stringWithFormat:@"%@ %ld %@",
                    kLang(@"Only"),
                    (long)remainingToAdd,
                    kLang(@"left in stock")];
    } else {
        careHint = PPPetCareViewerLocalized(@"pet_care_viewer_direct_add_copy", @"This medicine can be added directly from the shared pet-care catalog.");
    }
    self.careHintLabel.text = careHint;

    UIColor *accent = ![self pp_isMedicineCurrentlyAvailable]
        ? UIColor.systemRedColor
        : (self.bottomBar.addToCartButton.enabled ? PPPetCareViewerAccentColor() : UIColor.systemOrangeColor);
    [self pp_applyTintPillToLabel:self.careHintLabel
                             tint:accent
                         fillAlpha:0.10
                       borderAlpha:0.18
                         textColor:accent];
}

- (void)pp_refreshCartStateLabelWithQuantity:(NSInteger)existingQuantity remainingToAdd:(NSInteger)remainingToAdd
{
    UIColor *accent = PPPetCareViewerAccentColor();
    UIColor *warning = PPPetCareViewerWarmAccentColor();
    UIColor *danger = UIColor.systemRedColor;
    NSString *text = nil;
    UIColor *tint = accent;

    if (!self.medicine.isAvailable || self.medicine.stockQuantity <= 0) {
        text = PPPetCareViewerLocalized(@"pet_care_medicine_out_of_stock", @"Out of stock");
        tint = danger;
    } else if (remainingToAdd <= 0 && existingQuantity > 0) {
        text = [NSString stringWithFormat:PPPetCareViewerLocalized(@"pet_care_viewer_cart_quantity_format", @"%ld already in your cart"), (long)existingQuantity];
        tint = warning;
    } else if (existingQuantity > 0) {
        text = [NSString stringWithFormat:PPPetCareViewerLocalized(@"pet_care_viewer_cart_quantity_format", @"%ld already in your cart"), (long)existingQuantity];
        tint = accent;
    } else {
        text = PPPetCareViewerLocalized(@"pet_care_viewer_cart_empty", @"Add a dose to your cart.");
        tint = accent;
    }

    self.cartStateLabel.text = text;
    [self pp_applyTintPillToLabel:self.cartStateLabel
                             tint:tint
                         fillAlpha:0.11
                       borderAlpha:0.18
                         textColor:tint];
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
        [PPHUD showSuccess:kLang(@"AddedToCart") subtitle:message delay:1.25];
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
        activityVC.popoverPresentationController.sourceView = self.bottomBar.favButton ?: self.careSectionView;
        activityVC.popoverPresentationController.sourceRect = self.bottomBar.favButton ? self.bottomBar.favButton.bounds : self.careSectionView.bounds;
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

- (UILabel *)pp_sectionTitleLabelWithText:(NSString *)text
{
    UILabel *label = [self pp_labelWithFont:[GM boldFontWithSize:18.0] ?: [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold]
                                      color:PPPetCareViewerTextColor()
                                      lines:1];
    label.text = text;
    return label;
}

- (PPHomeInsetLabel *)pp_pillLabelWithFont:(UIFont *)font
{
    PPHomeInsetLabel *label = [[PPHomeInsetLabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textAlignment = NSTextAlignmentCenter;
    label.contentInsets = UIEdgeInsetsMake(8.0, 12.0, 8.0, 12.0);
    label.layer.cornerRadius = 16.0;
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

- (UIView *)pp_metricTileWithSymbol:(NSString *)symbol
                              title:(NSString *)title
                              value:(NSString *)value
                               tint:(UIColor *)tint
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = PPPetCareViewerQuietTileColor();
    container.layer.cornerRadius = 22.0;
    container.layer.borderWidth = 0.8;
    [container pp_setBorderColor:[tint colorWithAlphaComponent:0.14]];
    if (@available(iOS 13.0, *)) {
        container.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *iconShell = [[UIView alloc] init];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.backgroundColor = [tint colorWithAlphaComponent:0.12];
    iconShell.layer.cornerRadius = 18.0;
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

    UILabel *valueLabel = [self pp_labelWithFont:[GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold]
                                           color:PPPetCareViewerTextColor()
                                           lines:2];
    valueLabel.text = value.length > 0 ? value : PPPetCareViewerLocalized(@"pet_care_viewer_not_specified", @"Not specified");

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, valueLabel]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 4.0;
    [container addSubview:textStack];

    [NSLayoutConstraint activateConstraints:@[
        [container.heightAnchor constraintGreaterThanOrEqualToConstant:112.0],

        [iconShell.topAnchor constraintEqualToAnchor:container.topAnchor constant:16.0],
        [iconShell.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16.0],
        [iconShell.widthAnchor constraintEqualToConstant:36.0],
        [iconShell.heightAnchor constraintEqualToConstant:36.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:18.0],
        [iconView.heightAnchor constraintEqualToConstant:18.0],

        [textStack.topAnchor constraintEqualToAnchor:iconShell.bottomAnchor constant:14.0],
        [textStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16.0],
        [textStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16.0],
        [textStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-16.0]
    ]];
    return container;
}

- (UIView *)pp_highlightRowWithSymbol:(NSString *)symbol
                                 text:(NSString *)text
                                 tint:(UIColor *)tint
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = PPPetCareViewerQuietTileColor();
    container.layer.cornerRadius = 20.0;
    container.layer.borderWidth = 0.8;
    [container pp_setBorderColor:[tint colorWithAlphaComponent:0.14]];
    if (@available(iOS 13.0, *)) {
        container.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:symbol] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = tint;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [container addSubview:iconView];

    UILabel *label = [self pp_labelWithFont:[GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium]
                                      color:PPPetCareViewerTextColor()
                                      lines:0];
    label.text = text;
    [container addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [container.heightAnchor constraintGreaterThanOrEqualToConstant:58.0],
        [iconView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16.0],
        [iconView.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:18.0],
        [iconView.heightAnchor constraintEqualToConstant:18.0],

        [label.topAnchor constraintEqualToAnchor:container.topAnchor constant:14.0],
        [label.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:12.0],
        [label.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16.0],
        [label.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-14.0]
    ]];
    return container;
}

#pragma mark - Motion

- (void)pp_prepareEntranceState
{
    [self pp_prepareEntranceViews:[self pp_compactEntranceViews:@[
        self.heroView,
        self.proofSectionView,
        self.storySectionView,
        self.careSectionView
    ]]
                  verticalOffset:PPPetCareViewerEntranceCardOffset
                alternatingShift:0.0
                           scale:0.965
                        rotation:0.0];

    [self pp_prepareEntranceViews:[self pp_compactEntranceViews:@[self.bottomBar]]
                  verticalOffset:22.0
                alternatingShift:0.0
                           scale:0.98
                        rotation:0.0];

    [self pp_prepareEntranceViews:[self pp_compactEntranceViews:@[
        self.eyebrowLabel,
        self.titleLabel,
        self.subtitleLabel,
        self.heroChipsStackView,
        self.priceLabel,
        self.cartStateLabel
    ]]
                  verticalOffset:PPPetCareViewerEntranceContentOffset
                alternatingShift:0.0
                           scale:0.985
                        rotation:0.0];

    [self pp_prepareEntranceViews:[self pp_compactEntranceViews:@[self.heroImageView]]
                  verticalOffset:24.0
                alternatingShift:0.0
                           scale:0.90
                        rotation:0.0];

    [self pp_prepareEntranceViews:[self pp_compactEntranceViews:@[self.heroIconPlateView]]
                  verticalOffset:12.0
                alternatingShift:10.0
                           scale:0.76
                        rotation:0.10];

    [self pp_prepareEntranceViews:[self pp_compactEntranceViews:@[
        self.proofTitleLabel,
        self.storyTitleLabel,
        self.storyBodyLabel,
        self.careTitleLabel,
        self.careBodyLabel,
        self.careHintLabel
    ]]
                  verticalOffset:PPPetCareViewerEntranceContentOffset
                alternatingShift:0.0
                           scale:0.985
                        rotation:0.0];

    [self pp_prepareEntranceViews:[self pp_metricTileEntranceViews]
                  verticalOffset:PPPetCareViewerEntranceTileOffset
                alternatingShift:10.0
                           scale:0.94
                        rotation:0.0];

    [self pp_prepareEntranceViews:[self pp_storyHighlightEntranceViews]
                  verticalOffset:12.0
                alternatingShift:8.0
                           scale:0.965
                        rotation:0.0];
}

- (void)pp_beginEntranceAnimationIfNeeded
{
    if (self.didAnimateEntrance) {
        return;
    }
    self.didAnimateEntrance = YES;

    [self pp_animateEntranceViews:[self pp_compactEntranceViews:@[
        self.heroView,
        self.proofSectionView,
        self.storySectionView,
        self.careSectionView
    ]]
                    initialDelay:0.00
                       stepDelay:0.07
                        duration:PPPetCareViewerEntranceCardDuration
                         damping:0.82
                        velocity:0.22];

    [self pp_animateEntranceViews:[self pp_compactEntranceViews:@[self.bottomBar]]
                    initialDelay:0.12
                       stepDelay:0.00
                        duration:0.58
                         damping:0.84
                        velocity:0.16];

    [self pp_animateEntranceViews:[self pp_compactEntranceViews:@[self.heroImageView, self.heroIconPlateView]]
                    initialDelay:0.10
                       stepDelay:0.05
                        duration:0.56
                         damping:0.72
                        velocity:0.30];

    [self pp_animateEntranceViews:[self pp_compactEntranceViews:@[
        self.eyebrowLabel,
        self.titleLabel,
        self.subtitleLabel,
        self.heroChipsStackView,
        self.priceLabel,
        self.cartStateLabel
    ]]
                    initialDelay:0.14
                       stepDelay:0.04
                        duration:PPPetCareViewerEntranceContentDuration
                         damping:0.86
                        velocity:0.18];

    [self pp_animateEntranceViews:[self pp_compactEntranceViews:@[self.proofTitleLabel]]
                    initialDelay:0.20
                       stepDelay:0.00
                        duration:0.46
                         damping:0.88
                        velocity:0.16];

    [self pp_animateEntranceViews:[self pp_metricTileEntranceViews]
                    initialDelay:0.24
                       stepDelay:0.04
                        duration:0.50
                         damping:0.78
                        velocity:0.24];

    [self pp_animateEntranceViews:[self pp_compactEntranceViews:@[self.storyTitleLabel, self.storyBodyLabel]]
                    initialDelay:0.30
                       stepDelay:0.04
                        duration:0.46
                         damping:0.88
                        velocity:0.16];

    [self pp_animateEntranceViews:[self pp_storyHighlightEntranceViews]
                    initialDelay:0.34
                       stepDelay:0.04
                        duration:0.48
                         damping:0.82
                        velocity:0.20];

    [self pp_animateEntranceViews:[self pp_compactEntranceViews:@[
        self.careTitleLabel,
        self.careBodyLabel,
        self.careHintLabel
    ]]
                    initialDelay:0.40
                       stepDelay:0.04
                        duration:0.46
                         damping:0.88
                        velocity:0.16];
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
        self.backgroundGlowTopView.transform = CGAffineTransformMakeTranslation(-16.0, 12.0);
        self.backgroundGlowMiddleView.transform = CGAffineTransformMakeTranslation(12.0, -10.0);
    } completion:nil];

    [UIView animateWithDuration:7.2
                          delay:0.0
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.backgroundGlowBottomView.transform = CGAffineTransformMakeTranslation(20.0, -14.0);
    } completion:nil];
}

- (NSArray<UIView *> *)pp_compactEntranceViews:(NSArray<UIView *> *)views
{
    NSMutableArray<UIView *> *compactViews = [NSMutableArray array];
    for (UIView *view in views) {
        if (![view isKindOfClass:UIView.class]) {
            continue;
        }
        if (view.superview == nil) {
            continue;
        }
        [compactViews addObject:view];
    }
    return [compactViews copy];
}

- (NSArray<UIView *> *)pp_metricTileEntranceViews
{
    NSMutableArray<UIView *> *tileViews = [NSMutableArray array];
    for (UIView *rowView in self.proofGridStackView.arrangedSubviews) {
        if (![rowView isKindOfClass:UIStackView.class]) {
            continue;
        }
        UIStackView *rowStack = (UIStackView *)rowView;
        for (UIView *tileView in rowStack.arrangedSubviews) {
            if (tileView.superview != nil) {
                [tileViews addObject:tileView];
            }
        }
    }
    return [tileViews copy];
}

- (NSArray<UIView *> *)pp_storyHighlightEntranceViews
{
    NSMutableArray<UIView *> *highlightViews = [NSMutableArray array];
    for (UIView *view in self.storyHighlightsStackView.arrangedSubviews) {
        if (view.superview != nil) {
            [highlightViews addObject:view];
        }
    }
    return [highlightViews copy];
}

- (void)pp_prepareEntranceViews:(NSArray<UIView *> *)views
                 verticalOffset:(CGFloat)verticalOffset
               alternatingShift:(CGFloat)alternatingShift
                          scale:(CGFloat)scale
                       rotation:(CGFloat)rotation
{
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    CGFloat resolvedVerticalOffset = reduceMotion ? 0.0 : verticalOffset;
    CGFloat resolvedAlternatingShift = reduceMotion ? 0.0 : alternatingShift;
    CGFloat resolvedScale = reduceMotion ? 1.0 : scale;
    CGFloat resolvedRotation = reduceMotion ? 0.0 : rotation;

    [views enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        CGFloat direction = (idx % 2 == 0) ? -1.0 : 1.0;
        CGAffineTransform transform = CGAffineTransformMakeTranslation(resolvedAlternatingShift * direction, resolvedVerticalOffset);
        if (fabs(resolvedRotation) > 0.001) {
            transform = CGAffineTransformRotate(transform, resolvedRotation * direction);
        }
        if (fabs(resolvedScale - 1.0) > 0.001) {
            transform = CGAffineTransformScale(transform, resolvedScale, resolvedScale);
        }
        view.alpha = 0.0;
        view.transform = transform;
    }];
}

- (void)pp_animateEntranceViews:(NSArray<UIView *> *)views
                   initialDelay:(NSTimeInterval)initialDelay
                      stepDelay:(NSTimeInterval)stepDelay
                       duration:(NSTimeInterval)duration
                        damping:(CGFloat)damping
                       velocity:(CGFloat)velocity
{
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    [views enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        NSTimeInterval delay = initialDelay + (stepDelay * idx);
        if (reduceMotion) {
            [UIView animateWithDuration:PPPetCareViewerReducedMotionDuration
                                  delay:delay
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                view.alpha = 1.0;
                view.transform = CGAffineTransformIdentity;
            } completion:nil];
            return;
        }

        [UIView animateWithDuration:duration
                              delay:delay
             usingSpringWithDamping:damping
              initialSpringVelocity:velocity
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

@end
