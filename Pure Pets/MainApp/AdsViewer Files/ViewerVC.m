//  ViewerVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//

#import "ViewerVC.h"
#import "PPPetsTitleView.h"
#import "PPAdSharingHelper.h"
#import "PPInfoPillsView.h"
#import "PPSimilarAdsView.h"
#import "PPOverlayCoordinator.h"
#import "PPUserSigningManager.h"
@interface ViewerVC()<UIGestureRecognizerDelegate,UIScrollViewDelegate>
@property (nonatomic, strong) CAGradientLayer *contactGradientLayer;
@property (nonatomic, strong) CAGradientLayer *galleryScrimLayer;
@property (nonatomic, strong) CAGradientLayer *contentSurfaceGradientLayer;
@property (nonatomic, strong) CAGradientLayer *descriptionSurfaceGradientLayer;
@property (nonatomic, strong) UIView *ambientGlowTopView;
@property (nonatomic, strong) UIView *ambientGlowBottomView;
@property PetImageGalleryView *imageGallery;
@property UserModel *ownerModel;
@property PPSimilarAdsView *similarAdsView;
@property PPSimilarAdsView *similarAccessView;
@property (nonatomic, assign) BOOL didAnimate;
@property (nonatomic, strong) UIScrollView *contentScrollView;
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, strong) UIView *heroContainerView;
@property (nonatomic, strong) UIView *titleCard;
@property (nonatomic, strong) UIVisualEffectView *titleBlurView;
@property PetAdCardView *petCard;
// Layout constraints
@property (nonatomic, strong) NSLayoutConstraint *tableViewTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *tableViewHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *imageGalleryHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *heroHeightConstraint;

@property (nonatomic, assign) BOOL isFavorite;
@property (nonatomic, strong) UserContactView *contactView;
@property (nonatomic, assign) float actionPadding;
@property (nonatomic, strong) PPPetsTitleView *petsTitleView;
@property (nonatomic, strong) PPQuickActionsView *actionsViewTop;
@property (nonatomic, strong) PPQuickActionsView *actionsViewBottom;

@property (nonatomic, strong) UIStackView *galleryLeadingStack;
@property (nonatomic, strong) UIButton *galleryShareButton;
@property (nonatomic, strong) UIButton *galleryFavoriteButton;
@property (nonatomic, strong) UIButton *galleryDismissButton;
@property (nonatomic, strong) UIButton *galleryReportButton;
@property (nonatomic, strong) UIView *descriptionSurfaceView;
@property (nonatomic, strong) UITextView *descriptionTextView;
@property (nonatomic, strong) NSLayoutConstraint *descriptionHeightConstraint;
@property (nonatomic, assign) CGFloat galleryMinHeight;
@property (nonatomic, assign) CGFloat galleryMaxHeight;
@property (nonatomic, assign) CGFloat lastScrollOffsetY;
@property (nonatomic, assign) BOOL isConsumingScroll;

@property (nonatomic, strong) PPInfoPillsView *infoView;
@property (nonatomic, strong) UIView *similarAdsSeparator;
@property (nonatomic, strong) UIView *similarAccessoriesSeparator;
@property (nonatomic, assign) BOOL didTrackViewInteraction;
@property (nonatomic, strong) NSLayoutConstraint *contactViewHeightConstraint;
@property (nonatomic, strong) UIView *contactDockView;
@property (nonatomic, strong) NSLayoutConstraint *contactDockHeightConstraint;
@property (nonatomic, strong) UIVisualEffectView *contactLockOverlayView;
@property (nonatomic, strong) UIButton *contactLockButton;
@property (nonatomic, assign) BOOL isLoadingOwnerModel;
@property (nonatomic, strong) UIView *galleryScrimView;
@property (nonatomic, assign) BOOL didCaptureNavigationBarState;
@property (nonatomic, assign) BOOL previousNavigationBarHidden;
@property (nonatomic, strong) UIBarButtonItem *favBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *shareBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *reportBarButtonItem;

@end

@implementation ViewerVC



- (void)viewDidLoad {
    [super viewDidLoad];
    self.actionPadding = 20.00;

    self.isFavorite = NO; // default
    [self initData];
    NSLog(@"USER ------>>> %@",self.ad.ownerID);
    NSLog(@"adID ------>>> %@",self.ad.adID);
}

- (UIView *)pp_makeAmbientGlowViewWithRadius:(CGFloat)radius
{
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.userInteractionEnabled = NO;
    view.layer.cornerRadius = radius;
    view.layer.shadowRadius = 58.0;
    view.layer.shadowOpacity = 0.22;
    view.layer.shadowOffset = CGSizeZero;
    return view;
}

- (void)pp_buildLiveBackgroundIfNeeded
{
    if (self.ambientGlowTopView || self.ambientGlowBottomView) {
        return;
    }

    UIColor *accent = AppPrimaryClr ?: UIColor.systemPinkColor;
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    self.ambientGlowTopView = [self pp_makeAmbientGlowViewWithRadius:132.0];
    self.ambientGlowTopView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.13 : 0.16];
    [self.ambientGlowTopView pp_setShadowColor:[accent colorWithAlphaComponent:dark ? 0.22 : 0.18]];
    [self.view addSubview:self.ambientGlowTopView];

    self.ambientGlowBottomView = [self pp_makeAmbientGlowViewWithRadius:156.0];
    self.ambientGlowBottomView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.09 : 0.11];
    [self.ambientGlowBottomView pp_setShadowColor:[accent colorWithAlphaComponent:dark ? 0.18 : 0.15]];
    [self.view addSubview:self.ambientGlowBottomView];

    [NSLayoutConstraint activateConstraints:@[
        [self.ambientGlowTopView.widthAnchor constraintEqualToConstant:264.0],
        [self.ambientGlowTopView.heightAnchor constraintEqualToConstant:264.0],
        [self.ambientGlowTopView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-74.0],
        [self.ambientGlowTopView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:92.0],

        [self.ambientGlowBottomView.widthAnchor constraintEqualToConstant:312.0],
        [self.ambientGlowBottomView.heightAnchor constraintEqualToConstant:312.0],
        [self.ambientGlowBottomView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-128.0],
        [self.ambientGlowBottomView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:122.0],
    ]];
}

- (void)pp_styleSeparator:(UIView *)separator
{
    if (!separator) {
        return;
    }

    UIColor *accent = AppPrimaryClr ?: UIColor.systemBlueColor;
    separator.backgroundColor = [accent colorWithAlphaComponent:0.16];
    separator.alpha = 1.0;
}

- (void)pp_applyViewerTheme
{
    UIColor *accent = AppPrimaryClr ?: UIColor.systemBlueColor;
    UIColor *surfaceColor = AppForgroundColr ?: UIColor.systemBackgroundColor;
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    self.view.backgroundColor = PPBackgroundColorForIOS26(NewBgColor);

    self.ambientGlowTopView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.12 : 0.15];
    self.ambientGlowBottomView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.08 : 0.10];
    [self.ambientGlowTopView pp_setShadowColor:[accent colorWithAlphaComponent:dark ? 0.20 : 0.17]];
    [self.ambientGlowBottomView pp_setShadowColor:[accent colorWithAlphaComponent:dark ? 0.18 : 0.14]];

    self.contentScrollView.backgroundColor = UIColor.clearColor;
    [self.contentScrollView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:dark ? 0.08 : 0.18]];
    self.contentSurfaceGradientLayer.colors = @[
        (__bridge id)[surfaceColor colorWithAlphaComponent:dark ? 0.76 : 0.94].CGColor,
        (__bridge id)[[UIColor systemBackgroundColor] colorWithAlphaComponent:dark ? 0.58 : 0.86].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:dark ? 0.035 : 0.060].CGColor
    ];
    self.contentSurfaceGradientLayer.locations = @[@0.0, @0.56, @1.0];
    self.contentSurfaceGradientLayer.startPoint = CGPointMake(0.5, 0.0);
    self.contentSurfaceGradientLayer.endPoint = CGPointMake(0.5, 1.0);

    self.titleCard.layer.shadowOpacity = dark ? 0.28 : 0.18;
    self.titleCard.layer.shadowRadius = dark ? 34.0 : 30.0;
    [self.titleCard pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:dark ? 0.10 : 0.18]];

    self.descriptionSurfaceView.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:dark ? 0.34 : 0.64];
    [self.descriptionSurfaceView pp_setBorderColor:[accent colorWithAlphaComponent:dark ? 0.13 : 0.10]];
    [self.descriptionSurfaceView pp_setShadowColor:UIColor.blackColor];
    self.descriptionSurfaceView.layer.shadowOpacity = dark ? 0.18 : 0.07;
    self.descriptionSurfaceView.layer.shadowRadius = dark ? 22.0 : 18.0;
    self.descriptionSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    self.descriptionSurfaceGradientLayer.colors = @[
        (__bridge id)[[UIColor systemBackgroundColor] colorWithAlphaComponent:dark ? 0.16 : 0.42].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:dark ? 0.045 : 0.065].CGColor
    ];
    self.descriptionSurfaceGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.descriptionSurfaceGradientLayer.endPoint = CGPointMake(1.0, 1.0);

    [self pp_styleSeparator:self.similarAdsSeparator];
    [self pp_styleSeparator:self.similarAccessoriesSeparator];

    self.contactDockView.layer.shadowOpacity = dark ? 0.26 : 0.18;
    self.contactDockView.layer.shadowRadius = dark ? 32.0 : 28.0;
    self.contactView.backgroundColor = [surfaceColor colorWithAlphaComponent:dark ? 0.52 : 0.74];
    [self.contactView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:dark ? 0.12 : 0.18]];
    self.contactGradientLayer.colors = @[
        (__bridge id)[[UIColor systemBackgroundColor] colorWithAlphaComponent:dark ? 0.42 : 0.90].CGColor,
        (__bridge id)[accent colorWithAlphaComponent:dark ? 0.13 : 0.16].CGColor,
        (__bridge id)[surfaceColor colorWithAlphaComponent:dark ? 0.24 : 0.46].CGColor
    ];

    self.contactLockOverlayView.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:dark ? 0.14 : 0.08];
    [self.contactLockOverlayView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:dark ? 0.12 : 0.18]];
    [self pp_styleContactActionButtons];
}

- (void)initData {
    self.view.backgroundColor = PPBackgroundColorForIOS26(NewBgColor);
    [self pp_buildLiveBackgroundIfNeeded];

    self.imageGallery = [[PetImageGalleryView alloc] initWithFrame:CGRectZero
                                                        imageItems:self.ad.imageItems
                                                       galleryType:PetImageGalleryTypePetAd
                                                        itemHeight:0
                                                          parentVC:self
                                                               obj:self.ad];

    self.imageGallery.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.imageGallery];
    self.imageGallery.layer.cornerRadius = 41.0;
    if (@available(iOS 13.0, *)) {
        self.imageGallery.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.imageGallery.clipsToBounds = YES;
    self.imageGallery.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    self.imageGallery.currentAd = self.ad;

    CGFloat galleryMaxHeight = self.view.hx_h * 0.5;
    CGFloat galleryHeight = self.view.bounds.size.height * 0.5;
    galleryHeight = MAX(galleryMaxHeight, 380);
    galleryHeight = MIN(galleryHeight, 540);
    self.galleryMaxHeight = galleryHeight;
    self.galleryMinHeight = MAX(320.0, galleryHeight - 84.0);

    // Setup imageGallery constraints

    self.imageGalleryHeightConstraint = [self.imageGallery.heightAnchor constraintEqualToConstant:galleryHeight];
    [NSLayoutConstraint activateConstraints:@[
        [self.imageGallery.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:0.5],
        [self.imageGallery.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:0.5],
        [self.imageGallery.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-0.5],
        self.imageGalleryHeightConstraint
    ]];

    self.galleryScrimView = [[UIView alloc] init];
    self.galleryScrimView.translatesAutoresizingMaskIntoConstraints = NO;
    self.galleryScrimView.userInteractionEnabled = NO;
    self.galleryScrimView.backgroundColor = UIColor.clearColor;
    self.galleryScrimView.layer.cornerRadius = self.imageGallery.layer.cornerRadius;
    self.galleryScrimView.layer.maskedCorners = self.imageGallery.layer.maskedCorners;
    if (@available(iOS 13.0, *)) {
        self.galleryScrimView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.galleryScrimView.clipsToBounds = YES;
    [self.view addSubview:self.galleryScrimView];

    [NSLayoutConstraint activateConstraints:@[
        [self.galleryScrimView.topAnchor constraintEqualToAnchor:self.imageGallery.topAnchor],
        [self.galleryScrimView.leadingAnchor constraintEqualToAnchor:self.imageGallery.leadingAnchor],
        [self.galleryScrimView.trailingAnchor constraintEqualToAnchor:self.imageGallery.trailingAnchor],
        [self.galleryScrimView.bottomAnchor constraintEqualToAnchor:self.imageGallery.bottomAnchor],
    ]];

    self.galleryScrimLayer = [CAGradientLayer layer];
    self.galleryScrimLayer.startPoint = CGPointMake(0.5, 0.0);
    self.galleryScrimLayer.endPoint = CGPointMake(0.5, 1.0);
    self.galleryScrimLayer.colors = @[
        (__bridge id)[[UIColor blackColor] colorWithAlphaComponent:0.16].CGColor,
        (__bridge id)[[UIColor blackColor] colorWithAlphaComponent:0.05].CGColor,
        (__bridge id)[[UIColor blackColor] colorWithAlphaComponent:0.34].CGColor
    ];
    [self.galleryScrimView.layer addSublayer:self.galleryScrimLayer];


    // --- Title Card Container ---
    self.titleCard = [[UIView alloc] init];
    self.titleCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleCard.backgroundColor = UIColor.clearColor;
    self.titleCard.layer.cornerRadius = 30.0;
    if (@available(iOS 13.0, *)) {
        self.titleCard.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.titleCard.layer.masksToBounds = NO;

    // Soft editorial lift above the hero.
    [self.titleCard pp_setShadowColor:UIColor.blackColor];
    self.titleCard.layer.shadowOpacity = 0.18;
    self.titleCard.layer.shadowRadius = 30;
    self.titleCard.layer.shadowOffset = CGSizeMake(0, 18);
    self.titleCard.layer.borderWidth = 0.75;
    [self.titleCard pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.16]];

    // ---- Blur background ----
    UIBlurEffect *blurEffect;
    if (@available(iOS 17.0, *)) {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    } else {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    }

    self.titleBlurView =
        [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.titleBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleBlurView.layer.cornerRadius = 30.0;
    self.titleBlurView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.titleBlurView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    // Optional subtle tint to stabilize contrast
    UIView *tintView = [[UIView alloc] init];
    tintView.translatesAutoresizingMaskIntoConstraints = NO;
    tintView.backgroundColor =
        [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.18];

    [self.titleBlurView.contentView addSubview:tintView];
    [self.titleCard addSubview:self.titleBlurView];

    // Blur constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.titleBlurView.topAnchor constraintEqualToAnchor:self.titleCard.topAnchor],
        [self.titleBlurView.leadingAnchor constraintEqualToAnchor:self.titleCard.leadingAnchor],
        [self.titleBlurView.trailingAnchor constraintEqualToAnchor:self.titleCard.trailingAnchor],
        [self.titleBlurView.bottomAnchor constraintEqualToAnchor:self.titleCard.bottomAnchor],
    ]];

    // Tint constraints
    [NSLayoutConstraint activateConstraints:@[
        [tintView.topAnchor constraintEqualToAnchor:self.titleBlurView.contentView.topAnchor],
        [tintView.leadingAnchor constraintEqualToAnchor:self.titleBlurView.contentView.leadingAnchor],
        [tintView.trailingAnchor constraintEqualToAnchor:self.titleBlurView.contentView.trailingAnchor],
        [tintView.bottomAnchor constraintEqualToAnchor:self.titleBlurView.contentView.bottomAnchor],
    ]];

    [self.view addSubview:self.titleCard];

    self.petsTitleView = [[PPPetsTitleView alloc] init];
    [self.petsTitleView configureWithTitle:self.ad.adTitle
                                  location:(self.ad.adLocation > 0
                                            ? [CitiesManager.shared cityNameForID:self.ad.adLocation]
                                            : nil) price:[GM formatPrice:self.ad.price
                                                            currencyCode:kLang(@"Rials")]];
    self.petsTitleView.translatesAutoresizingMaskIntoConstraints = NO;


    self.contentScrollView = [[UIScrollView alloc] init];
    self.contentScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentScrollView.showsVerticalScrollIndicator = NO;
    self.contentScrollView.alwaysBounceVertical = YES;
    self.contentScrollView.delegate = self;
    self.contentScrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    self.contentScrollView.backgroundColor = UIColor.clearColor;
    self.contentScrollView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    self.contentScrollView.layer.cornerRadius = 34.0;
    if (@available(iOS 13.0, *)) {
        self.contentScrollView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.contentScrollView.clipsToBounds = YES;
    self.contentScrollView.layer.borderWidth = 0.5;
    [self.contentScrollView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.08]];
    self.contentSurfaceGradientLayer = [CAGradientLayer layer];
    self.contentSurfaceGradientLayer.cornerRadius = self.contentScrollView.layer.cornerRadius;
    [self.contentScrollView.layer insertSublayer:self.contentSurfaceGradientLayer atIndex:0];
    [self.view addSubview:self.contentScrollView];

    [NSLayoutConstraint activateConstraints:@[
        [self.contentScrollView.topAnchor constraintEqualToAnchor:self.imageGallery.bottomAnchor constant:-36],
        [self.contentScrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.contentScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.contentScrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    self.contentContainer = [[UIView alloc] init];
    self.contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentScrollView addSubview:self.contentContainer];

    if (@available(iOS 11.0, *)) {
        [NSLayoutConstraint activateConstraints:@[
            [self.contentContainer.topAnchor constraintEqualToAnchor:self.contentScrollView.contentLayoutGuide.topAnchor],
            [self.contentContainer.leadingAnchor constraintEqualToAnchor:self.contentScrollView.contentLayoutGuide.leadingAnchor],
            [self.contentContainer.trailingAnchor constraintEqualToAnchor:self.contentScrollView.contentLayoutGuide.trailingAnchor],
            [self.contentContainer.bottomAnchor constraintEqualToAnchor:self.contentScrollView.contentLayoutGuide.bottomAnchor],
            [self.contentContainer.widthAnchor constraintEqualToAnchor:self.contentScrollView.frameLayoutGuide.widthAnchor]
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [self.contentContainer.topAnchor constraintEqualToAnchor:self.contentScrollView.topAnchor constant:0],
            [self.contentContainer.leadingAnchor constraintEqualToAnchor:self.contentScrollView.leadingAnchor],
            [self.contentContainer.trailingAnchor constraintEqualToAnchor:self.contentScrollView.trailingAnchor],
            [self.contentContainer.bottomAnchor constraintEqualToAnchor:self.contentScrollView.bottomAnchor],
            [self.contentContainer.widthAnchor constraintEqualToAnchor:self.contentScrollView.widthAnchor]
        ]];
    }


    [self.titleCard addSubview:self.petsTitleView];

    // Constraints for titleCard
    [NSLayoutConstraint activateConstraints:@[
        [self.titleCard.bottomAnchor constraintEqualToAnchor:self.imageGallery.bottomAnchor constant:-28],
        [self.titleCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18],
        [self.titleCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18],
        [self.titleCard.heightAnchor constraintEqualToConstant:86]
    ]];


    // Constraints for petsTitleView inside titleCard
    [NSLayoutConstraint activateConstraints:@[
        [self.petsTitleView.topAnchor constraintEqualToAnchor:self.titleCard.topAnchor constant:0],
        [self.petsTitleView.leadingAnchor constraintEqualToAnchor:self.titleCard.leadingAnchor constant:0],
        [self.petsTitleView.trailingAnchor constraintEqualToAnchor:self.titleCard.trailingAnchor constant:-0],
        [self.petsTitleView.bottomAnchor constraintEqualToAnchor:self.titleCard.bottomAnchor constant:-0]
    ]];




    //[self.view bringSubviewToFront:self.imageGallery];
    [self.view bringSubviewToFront:self.titleCard];
    // --- Gallery Overlay Controls ---




    [self initInfoView];
    [self initdescriptionTextView];
    [self initUserContactView];
    [self initSimilarAds];
    [self initSimilarAccess];
    [self initButtons];
    [self pp_applyViewerTheme];
    [self pp_prepareEntranceAnimationState];
}



-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_beginEntranceAnimationsIfNeeded];
    [self pp_startLiveMotionIfNeeded];
    if (!self.didTrackViewInteraction) {
        self.didTrackViewInteraction = YES;
        [self trackAdInteraction:PPItemInteractionTypeView];
    }
}

#pragma mark - Quick actions header


-(void)initInfoView
{

    NSString *ageString;
    if (Language.isRTL)
        ageString = [NSString stringWithFormat:@"%@ شهر",
                     self.ad.petAgeMonths];
    else
        ageString = [NSString stringWithFormat:@"%@ month %@",
                     self.ad.petAgeMonths,
                     self.ad.petAgeMonths .integerValue> 1 ? @"s" : @""];

    NSString *gender = self.ad.isFemale ? kLang(@"female") :  kLang(@"male");
    NSString *SubKindName = [SubKindModel getSubKindName:self.ad.subcategory subKindsArrayLocal:[MKM getSubKindArray:self.ad.category]];
    // --- Actions Container StackView ---


    self.infoView =
    [[PPInfoPillsView alloc] initWithItems:@[
        [PPInfoPill itemWithIcon:@"figure.dress.line.vertical.figure"
                            text:gender],
        [PPInfoPill itemWithIcon:@"clock"
                            text:ageString],
        [PPInfoPill itemWithIcon:@"pawprint.fill"
                            text:SubKindName],

    ]];
    [self.contentContainer addSubview:self.infoView];

    [NSLayoutConstraint activateConstraints:@[
        [self.infoView.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor constant:20],
        [self.infoView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:18],
        [self.infoView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-18],
        [self.infoView.heightAnchor constraintGreaterThanOrEqualToConstant:66]
    ]];
}


- (void)initdescriptionTextView {
    self.descriptionSurfaceView = [[UIView alloc] init];
    self.descriptionSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionSurfaceView.layer.cornerRadius = 26.0;
    if (@available(iOS 13.0, *)) {
        self.descriptionSurfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.descriptionSurfaceView.layer.borderWidth = 0.75;
    self.descriptionSurfaceView.clipsToBounds = NO;
    [self.contentContainer addSubview:self.descriptionSurfaceView];

    self.descriptionSurfaceGradientLayer = [CAGradientLayer layer];
    self.descriptionSurfaceGradientLayer.cornerRadius = self.descriptionSurfaceView.layer.cornerRadius;
    [self.descriptionSurfaceView.layer insertSublayer:self.descriptionSurfaceGradientLayer atIndex:0];

    self.descriptionTextView = [[UITextView alloc] init];
    self.descriptionTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionTextView.scrollEnabled = NO;   // ✅ key
    self.descriptionTextView.editable = NO;
    self.descriptionTextView.selectable = YES;
    self.descriptionTextView.backgroundColor = UIColor.clearColor;
    self.descriptionTextView.tintColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    self.descriptionTextView.textAlignment = NSTextAlignmentNatural;
    self.descriptionTextView.textContainerInset = UIEdgeInsetsMake(8, 0, 10, 0);
    self.descriptionTextView.textContainer.lineFragmentPadding = 0;
    self.descriptionTextView.font = [GM MidFontWithSize:16];
    self.descriptionTextView.adjustsFontForContentSizeCategory = YES;
    self.descriptionTextView.linkTextAttributes = @{
        NSForegroundColorAttributeName: AppPrimaryClr ?: UIColor.systemBlueColor,
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
    };

    NSString *desc = self.ad.adDescription;

    if (desc.length > 0) {
        self.descriptionTextView.attributedText =
        [self pp_styledDescriptionFromText:desc];
    } else {
        self.descriptionTextView.attributedText =
        [[NSAttributedString alloc] initWithString:
         kLang(@"No description added for this pet.")
                                        attributes:@{
            NSFontAttributeName:
                [UIFont preferredFontForTextStyle:UIFontTextStyleBody],
            NSForegroundColorAttributeName:
                UIColor.secondaryLabelColor
        }];
    }
    [self.descriptionSurfaceView addSubview:self.descriptionTextView];


    self.descriptionHeightConstraint =
    [self.descriptionTextView.heightAnchor
     constraintGreaterThanOrEqualToConstant:44];
    self.descriptionHeightConstraint.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [self.descriptionSurfaceView.topAnchor
         constraintEqualToAnchor:self.infoView.bottomAnchor constant:16],
        [self.descriptionSurfaceView.leadingAnchor
         constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:18],
        [self.descriptionSurfaceView.trailingAnchor
         constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-18],

        [self.descriptionTextView.topAnchor
         constraintEqualToAnchor:self.descriptionSurfaceView.topAnchor constant:12],
        [self.descriptionTextView.leadingAnchor
         constraintEqualToAnchor:self.descriptionSurfaceView.leadingAnchor constant:18],
        [self.descriptionTextView.trailingAnchor
         constraintEqualToAnchor:self.descriptionSurfaceView.trailingAnchor constant:-18],
        [self.descriptionTextView.bottomAnchor
         constraintEqualToAnchor:self.descriptionSurfaceView.bottomAnchor constant:-12],
        self.descriptionHeightConstraint
    ]];

}


- (void)initUserContactView {
    self.contactDockView = [[UIView alloc] init];
    self.contactDockView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contactDockView.backgroundColor = UIColor.clearColor;
    self.contactDockView.layer.cornerRadius = 32.0;
    if (@available(iOS 13.0, *)) {
        self.contactDockView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contactDockView pp_setShadowColor:UIColor.blackColor];
    self.contactDockView.layer.shadowOpacity = 0.18;
    self.contactDockView.layer.shadowRadius = 28.0;
    self.contactDockView.layer.shadowOffset = CGSizeMake(0.0, 16.0);
    [self.view addSubview:self.contactDockView];

    self.contactView = [[UserContactView alloc] initWithFrame:CGRectZero];
    self.contactView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contactDockView addSubview:self.contactView];

    self.contactView.layer.cornerRadius = 26.0;
    if (@available(iOS 13.0, *)) {
        self.contactView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.contactView.clipsToBounds = YES;
    self.contactView.layer.borderWidth = 0.75;
    [self.contactView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.14]];

    self.contactGradientLayer = [CAGradientLayer layer];
    self.contactGradientLayer.colors = @[
        (__bridge id)[[UIColor systemBackgroundColor] colorWithAlphaComponent:0.92].CGColor,
        (__bridge id)[(AppPrimaryClr ?: UIColor.systemPinkColor) colorWithAlphaComponent:0.18].CGColor
    ];
    self.contactGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.contactGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.contactGradientLayer.cornerRadius = 26.0;
    [self.contactView.layer insertSublayer:self.contactGradientLayer atIndex:0];

    self.contactView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.78];
    self.contactView.semanticContentAttribute = GM.setSemantic;
    self.contactViewHeightConstraint = [self.contactView.heightAnchor constraintEqualToConstant:64];
    self.contactDockHeightConstraint = [self.contactDockView.heightAnchor constraintEqualToConstant:84.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.contactDockView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:12],
        [self.contactDockView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-12],
        [self.contactDockView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10],
        self.contactDockHeightConstraint,

        [self.contactView.leadingAnchor constraintEqualToAnchor:self.contactDockView.leadingAnchor constant:8],
        [self.contactView.trailingAnchor constraintEqualToAnchor:self.contactDockView.trailingAnchor constant:-8],
        [self.contactView.topAnchor constraintEqualToAnchor:self.contactDockView.topAnchor constant:10],
        self.contactViewHeightConstraint,
    ]];
    [self.view bringSubviewToFront:self.contactDockView];
    [self pp_styleContactActionButtons];

    [self pp_updateContactAccessStateAnimated:NO];
}
- (void)initSimilarAds {

    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;

    [self pp_styleSeparator:separator];
    [self.contentContainer addSubview:separator];
    self.similarAdsSeparator = separator;
    self.similarAdsSeparator.hidden = YES;
    [NSLayoutConstraint activateConstraints:@[
        [separator.topAnchor constraintEqualToAnchor:self.descriptionSurfaceView.bottomAnchor constant:26],
        [separator.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:28],
        [separator.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-28],

        // Hairline thickness (1px, not 1pt)
        [separator.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
    ]];

    // petsTitleView,infoView,contactView,descriptionTextView,similarAdsView
    self.similarAdsView = [[PPSimilarAdsView alloc] initWithFrame:CGRectZero];
    self.similarAdsView.translatesAutoresizingMaskIntoConstraints = NO;
    self.similarAdsView.titleString =  kLang(@"Similar Ads");
    __weak typeof(self) weakSelf = self;
    self.similarAdsView.didSelectViewModel = ^(PPUniversalCellViewModel * _Nonnull vm) {
        __strong typeof(weakSelf) self = weakSelf;
        [PPOverlayCoordinator pp_openDetailForObject:vm.ModelObject
                                              fromVC:self
                                          routingNav:nil];
    };
    self.similarAdsView.didUpdateContentState = ^(BOOL hasContent, NSInteger itemCount) {
        __strong typeof(weakSelf) self = weakSelf;
        (void)itemCount;
        self.similarAdsSeparator.hidden = !hasContent;
    };
    // ✅ MUST be added before constraints
    [self.contentContainer addSubview:self.similarAdsView];

    [NSLayoutConstraint activateConstraints:@[
        [self.similarAdsView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:0],
        [self.similarAdsView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-0],

        // ⛔️ also fix this (see below)
        [self.similarAdsView.topAnchor constraintEqualToAnchor:separator.bottomAnchor constant:18],
    ]];


    PetAd *ad = [[PetAd alloc]init];
    ad.adID = self.ad.adID;
    ad.category = self.ad.category;
    ad.adTitle = self.ad.adTitle;
    ad.subcategory = 0;
    [[PetAdManager sharedManager]
     fetchSimilarAdsForAd:ad limit:15 completion:^(NSArray<PetAd *> * _Nonnull ads) {
        NSArray<PPUniversalCellViewModel *> *models = [self buildViewModelsFromModels:ads];
        //NSLog(@"models %@",[models modelToJSONString]);
        [self.similarAdsView updateWithViewModels:models];
    }];
}


- (void)initSimilarAccess {

    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;

    [self pp_styleSeparator:separator];
    [self.contentContainer addSubview:separator];
    self.similarAccessoriesSeparator = separator;
    self.similarAccessoriesSeparator.hidden = YES;
    [NSLayoutConstraint activateConstraints:@[
        [separator.topAnchor constraintEqualToAnchor:self.similarAdsView.bottomAnchor constant:24],
        [separator.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:28],
        [separator.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-28],

        // Hairline thickness (1px, not 1pt)
        [separator.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
    ]];


    // petsTitleView,infoView,contactView,descriptionTextView,similarAdsView
    self.similarAccessView = [[PPSimilarAdsView alloc] initWithFrame:CGRectZero];
    self.similarAccessView.translatesAutoresizingMaskIntoConstraints = NO;
    self.similarAccessView.titleString =  kLang(@"SimilarAaccess");
    __weak typeof(self) weakSelf = self;
    self.similarAccessView.didSelectViewModel = ^(PPUniversalCellViewModel * _Nonnull vm) {
        __strong typeof(weakSelf) self = weakSelf;
        [PPOverlayCoordinator pp_openDetailForObject:vm.ModelObject
                                              fromVC:self
                                          routingNav:nil];
    };
    self.similarAccessView.didUpdateContentState = ^(BOOL hasContent, NSInteger itemCount) {
        __strong typeof(weakSelf) self = weakSelf;
        (void)itemCount;
        self.similarAccessoriesSeparator.hidden = !hasContent;
    };
    // ✅ MUST be added before constraints
    [self.contentContainer addSubview:self.similarAccessView];

    [NSLayoutConstraint activateConstraints:@[
        [self.similarAccessView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:0],
        [self.similarAccessView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-0],

        // ⛔️ also fix this (see below)
        [self.similarAccessView.topAnchor constraintEqualToAnchor:separator.bottomAnchor constant:18],

        [self.similarAccessView.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor constant:-28],
    ]];


    PetAd *ad = [[PetAd alloc]init];
    ad.adID = self.ad.adID;
    ad.category = self.ad.category;
    ad.adTitle = self.ad.adTitle;
    ad.subcategory = 0;


    [[PetAccessoryManager sharedManager] fetchAccessoriesForMainCategoryID:self.ad.category subCategoryID:0 limit:15 completion:^(NSArray<PetAccessory *> * _Nonnull accessories) {

        NSArray<PPUniversalCellViewModel *> *models = [self buildViewModelsFromModels:accessories];
        //NSLog(@"models %@",[models modelToJSONString]);
        [self.similarAccessView updateWithViewModels:models];
    }];
}
#pragma mark - ViewModel Builder

- (NSArray<PPUniversalCellViewModel *> *) buildViewModelsFromModels:(NSArray *)models
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:models.count];

    for (id model in models) {
        PPUniversalCellViewModel *vm =
        [[PPUniversalCellViewModel alloc] initWithModel:model context:PPCellForAds];
        if (vm) [result addObject:vm];
    }

    return result;
}

-(void)initButtons
{
    self.galleryShareButton =
    [self pp_makeGlassCircleButtonWithSymbol:@"square.and.arrow.up"
                                      action:@selector(shareAdBTN:)];
    self.galleryShareButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_share_ad", @"Share ad");
    self.galleryShareButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_share_ad_hint", @"Double-tap to share this ad");

    self.galleryFavoriteButton =
    [self pp_makeGlassCircleButtonWithSymbol:@"heart"
                                      action:@selector(toggleFavorite)];
    self.galleryFavoriteButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_favorite", @"Favorite");
    self.galleryFavoriteButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_favorite_hint", @"Double-tap to add or remove from favorites");

    self.galleryReportButton =
    [self pp_makeGlassCircleButtonWithSymbol:@"flag"
                                      action:@selector(reportAdBTN:)];
    self.galleryReportButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_report_ad", @"Report ad");
    self.galleryReportButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_report_ad_hint", @"Double-tap to report this ad");

    self.galleryDismissButton =
    [self pp_makeGlassCircleButtonWithSymbol:@"xmark"
                                      action:@selector(dismiss)];
    self.galleryDismissButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_close", @"Close");
    self.galleryDismissButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_close_hint", @"Double-tap to close this screen");

    NSMutableArray *leadingButtons = [NSMutableArray arrayWithObjects:
        self.galleryShareButton,
        self.galleryFavoriteButton,
        nil
    ];

    // Only show report button if user is NOT the ad owner
    NSString *currentUID = [self trackingUserID];
    if (currentUID.length > 0 && ![currentUID isEqualToString:self.ad.ownerID]) {
        [leadingButtons addObject:self.galleryReportButton];
    }

    self.galleryLeadingStack =
    [[UIStackView alloc] initWithArrangedSubviews:leadingButtons];

    self.galleryLeadingStack.axis = UILayoutConstraintAxisVertical;
    self.galleryLeadingStack.spacing = 12;
    self.galleryLeadingStack.alignment = UIStackViewAlignmentCenter;
    self.galleryLeadingStack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:self.galleryLeadingStack];
    [self.view addSubview:self.galleryDismissButton];

    [NSLayoutConstraint activateConstraints:@[
        // Leading vertical buttons
        [self.galleryLeadingStack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-18],
        [self.galleryLeadingStack.topAnchor constraintEqualToAnchor:self.imageGallery.topAnchor constant:18],

        // Trailing dismiss
        [self.galleryDismissButton.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:18],
        [self.galleryDismissButton.topAnchor constraintEqualToAnchor:self.imageGallery.topAnchor constant:18],
    ]];

    for (UIButton *button in self.galleryLeadingStack.arrangedSubviews) {
        [self pp_styleInteractiveButton:button];
    }
    [self pp_styleInteractiveButton:self.galleryDismissButton];
}



- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDarkContent; // ✅ Always dark text
}
-(BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)favButtonTapped {
    NSLog(@"BUTTON ----->>>> FavoriteButton buttonTapped");
    if(!UserManager.sharedManager.isUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
    [self toggleFavorite];
}
- (void)setSymbol:(NSString *)symbol
        forButton:(UIButton *)button
           filled:(BOOL)filled {

    if (!button) return;

    UIButtonConfiguration *config = button.configuration;
    if (!config) return;

    NSString *finalSymbol = filled
    ? [symbol stringByAppendingString:@".fill"]
    : symbol;

    config.image = [UIImage systemImageNamed:finalSymbol];

    // Keep symbol size consistent
    config.preferredSymbolConfigurationForImage =
    [UIImageSymbolConfiguration configurationWithPointSize:16
                                                    weight:UIImageSymbolWeightSemibold];

    // Apply back (IMPORTANT – configuration is copied)
    button.configuration = config;
}
- (void)toggleFavorite {

    self.isFavorite = !self.isFavorite;

    if (self.isFavorite) {
        [self setSymbol:@"heart" forButton:self.galleryFavoriteButton filled:YES];
        self.galleryFavoriteButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_unfavorite", @"Remove from favorites");
        [GM triggerHapticFeedback]; // if you have haptic util
        [PetAdManager addFavoriteAdWithID:self.ad.adID collection:@"favoritesAds" forUserID:[UserManager sharedManager].currentUser.ID];
        NSLog(@"✅ Added to favorites");
    } else {
        [self setSymbol:@"heart" forButton:self.galleryFavoriteButton filled:NO];
        self.galleryFavoriteButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_favorite", @"Favorite");
        [PetAdManager removeFavoriteAdWithID:self.ad.adID collection:@"favoritesAds" forUserID:[UserManager sharedManager].currentUser.ID];
        NSLog(@"❌ Removed from favorites");
    }

}

-(void)dismiss
{
    if (self.navigationController && self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.navigationController && !self.didCaptureNavigationBarState) {
        self.previousNavigationBarHidden = self.navigationController.navigationBarHidden;
        self.didCaptureNavigationBarState = YES;
    }
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [self initValue];
    [self pp_applyViewerTheme];
    self.modalInPresentation = NO;
    [self pp_updateContactAccessStateAnimated:NO];
    [self pp_startLiveMotionIfNeeded];
}


- (IBAction)shareAdBTN:(id)sender {
    [PPAdSharingHelper sharePetAd:self.ad fromViewController:self];
    [self trackAdInteraction:PPItemInteractionTypeShare];
}

-(void)initValue
{
    if (PPCurrentUser && PPCurrentFIRAuthUser  ) {
        [PetAdManager isAdFavorited:self.ad.adID
                            forUser:PPCurrentUser.ID
                         collection:@"favoritesAds"
                         completion:^(BOOL favorited) {
            self.isFavorite = favorited;
            [self setSymbol:@"heart" forButton:self.galleryFavoriteButton filled:self.isFavorite];
            self.galleryFavoriteButton.accessibilityLabel = self.isFavorite
                ? NSLocalizedString(@"a11y_btn_unfavorite", @"Remove from favorites")
                : NSLocalizedString(@"a11y_btn_favorite", @"Favorite");
        }];
    }

}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    self.view.semanticContentAttribute = GM.setSemantic;
    self.imageGallery.semanticContentAttribute = GM.setSemantic;
    self.contentScrollView.semanticContentAttribute = GM.setSemantic;
    self.contentContainer.semanticContentAttribute = GM.setSemantic;
    self.descriptionSurfaceView.semanticContentAttribute = GM.setSemantic;
    self.descriptionTextView.semanticContentAttribute = GM.setSemantic;
    self.contactDockView.semanticContentAttribute = GM.setSemantic;
    self.galleryLeadingStack.semanticContentAttribute = GM.setSemantic;
    self.similarAdsView.semanticContentAttribute = GM.setSemantic;
    self.similarAccessView.semanticContentAttribute = GM.setSemantic;
    if (self.descriptionTextView && self.descriptionTextView.bounds.size.width > 0) {
        CGSize fittingSize =
        [self.descriptionTextView sizeThatFits:
         CGSizeMake(self.descriptionTextView.bounds.size.width,
                    CGFLOAT_MAX)];
        self.descriptionHeightConstraint.constant = MAX(44, fittingSize.height);
    }
    if (self.contactGradientLayer) {
        self.contactGradientLayer.frame = self.contactView.bounds;
        self.contactGradientLayer.cornerRadius = self.contactView.layer.cornerRadius;
    }
    if (self.galleryScrimLayer) {
        self.galleryScrimLayer.frame = self.galleryScrimView.bounds;
    }
    if (self.contentSurfaceGradientLayer) {
        self.contentSurfaceGradientLayer.frame = self.contentScrollView.bounds;
        self.contentSurfaceGradientLayer.cornerRadius = self.contentScrollView.layer.cornerRadius;
    }
    if (self.descriptionSurfaceGradientLayer) {
        self.descriptionSurfaceGradientLayer.frame = self.descriptionSurfaceView.bounds;
        self.descriptionSurfaceGradientLayer.cornerRadius = self.descriptionSurfaceView.layer.cornerRadius;
    }
    self.titleCard.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.titleCard.bounds
                                                                 cornerRadius:self.titleCard.layer.cornerRadius].CGPath;
    self.descriptionSurfaceView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.descriptionSurfaceView.bounds
                                                                              cornerRadius:self.descriptionSurfaceView.layer.cornerRadius].CGPath;
    self.contactView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.contactView.bounds
                                                                    cornerRadius:self.contactView.layer.cornerRadius].CGPath;
    self.contactDockView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.contactDockView.bounds
                                                                       cornerRadius:self.contactDockView.layer.cornerRadius].CGPath;
    self.ambientGlowTopView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:self.ambientGlowTopView.bounds].CGPath;
    self.ambientGlowBottomView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:self.ambientGlowBottomView.bounds].CGPath;
    [self pp_updatePinnedContactInsets];

    [Styling applyCornerMaskToView:self.titleBlurView tl:32 tr:16 bl:32 br:28];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    if (self.view.window) {
        [self pp_beginEntranceAnimationsIfNeeded];
        [self pp_startLiveMotionIfNeeded];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyViewerTheme];
            [self.view setNeedsLayout];
        }
    }
}

#pragma mark - Motion

- (void)pp_addAmbientTranslationToView:(UIView *)view
                                   key:(NSString *)key
                                     x:(CGFloat)x
                                     y:(CGFloat)y
                              duration:(NSTimeInterval)duration
{
    if (!view || key.length == 0 || [view.layer animationForKey:key]) {
        return;
    }

    CABasicAnimation *xAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    xAnimation.fromValue = @0.0;
    xAnimation.toValue = @(x);

    CABasicAnimation *yAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    yAnimation.fromValue = @0.0;
    yAnimation.toValue = @(y);

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[xAnimation, yAnimation];
    group.duration = duration;
    group.autoreverses = YES;
    group.repeatCount = HUGE_VALF;
    group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [view.layer addAnimation:group forKey:key];
}

- (void)pp_startLiveMotionIfNeeded
{
    if (!self.view.window || UIAccessibilityIsReduceMotionEnabled()) {
        [self pp_stopLiveMotion];
        return;
    }

    [self pp_addAmbientTranslationToView:self.ambientGlowTopView
                                     key:@"pp.viewer.ambient.top"
                                       x:-18.0
                                       y:14.0
                                duration:6.8];
    [self pp_addAmbientTranslationToView:self.ambientGlowBottomView
                                     key:@"pp.viewer.ambient.bottom"
                                       x:18.0
                                       y:-16.0
                                duration:7.6];

    if (self.contactDockView && ![self.contactDockView.layer animationForKey:@"pp.viewer.contactDock.breathe"]) {
        CABasicAnimation *shadowPulse = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
        shadowPulse.fromValue = @0.14;
        shadowPulse.toValue = @0.22;
        shadowPulse.duration = 4.8;
        shadowPulse.autoreverses = YES;
        shadowPulse.repeatCount = HUGE_VALF;
        shadowPulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.contactDockView.layer addAnimation:shadowPulse forKey:@"pp.viewer.contactDock.breathe"];
    }

    if (self.descriptionSurfaceView && ![self.descriptionSurfaceView.layer animationForKey:@"pp.viewer.descriptionSurface.breathe"]) {
        CABasicAnimation *surfacePulse = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
        surfacePulse.fromValue = @(self.descriptionSurfaceView.layer.shadowRadius);
        surfacePulse.toValue = @(self.descriptionSurfaceView.layer.shadowRadius + 4.0);
        surfacePulse.duration = 5.4;
        surfacePulse.autoreverses = YES;
        surfacePulse.repeatCount = HUGE_VALF;
        surfacePulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.descriptionSurfaceView.layer addAnimation:surfacePulse forKey:@"pp.viewer.descriptionSurface.breathe"];
    }
}

- (void)pp_stopLiveMotion
{
    [self.ambientGlowTopView.layer removeAnimationForKey:@"pp.viewer.ambient.top"];
    [self.ambientGlowBottomView.layer removeAnimationForKey:@"pp.viewer.ambient.bottom"];
    [self.contactDockView.layer removeAnimationForKey:@"pp.viewer.contactDock.breathe"];
    [self.descriptionSurfaceView.layer removeAnimationForKey:@"pp.viewer.descriptionSurface.breathe"];
    self.ambientGlowTopView.transform = CGAffineTransformIdentity;
    self.ambientGlowBottomView.transform = CGAffineTransformIdentity;
}

- (NSArray<UIView *> *)pp_primaryEntranceViews
{
    NSMutableArray<UIView *> *views = [NSMutableArray array];

    if (self.titleCard) {
        [views addObject:self.titleCard];
    }
    if (self.infoView) {
        [views addObject:self.infoView];
    }
    if (self.descriptionSurfaceView) {
        [views addObject:self.descriptionSurfaceView];
    }
    if (self.contactDockView) {
        [views addObject:self.contactDockView];
    }
    if (self.similarAdsView) {
        [views addObject:self.similarAdsView];
    }
    if (self.similarAccessView) {
        [views addObject:self.similarAccessView];
    }

    return views.copy;
}

- (NSArray<UIView *> *)pp_secondaryEntranceViews
{
    NSMutableArray<UIView *> *views = [NSMutableArray array];

    if (self.petsTitleView) {
        [views addObject:self.petsTitleView];
    }

    if (self.contactLockOverlayView && !self.contactLockOverlayView.hidden) {
        [views addObject:self.contactLockOverlayView];
    } else {
        if (self.contactView.avatarImageView) {
            [views addObject:self.contactView.avatarImageView];
        }
        if (self.contactView.nameLabel) {
            [views addObject:self.contactView.nameLabel];
        }
        if (self.contactView.callButton) {
            [views addObject:self.contactView.callButton];
        }
        if (self.contactView.chatButton) {
            [views addObject:self.contactView.chatButton];
        }
    }

    return views.copy;
}

- (NSArray<UIView *> *)pp_galleryEntranceViews
{
    NSMutableArray<UIView *> *views = [NSMutableArray array];

    for (UIView *button in self.galleryLeadingStack.arrangedSubviews) {
        [views addObject:button];
    }
    if (self.galleryDismissButton) {
        [views addObject:self.galleryDismissButton];
    }

    return views.copy;
}

- (CGFloat)pp_initialEntranceAlphaForView:(UIView *)view
                             reduceMotion:(BOOL)reduceMotion
{
    if (reduceMotion) {
        return 1.0;
    }

    if (view == self.titleCard) {
        return 0.76;
    }
    if (view == self.infoView) {
        return 0.42;
    }
    if (view == self.descriptionSurfaceView) {
        return 0.28;
    }
    if (view == self.petsTitleView) {
        return 0.20;
    }
    if (view == self.contactDockView) {
        return 0.12;
    }

    return 0.0;
}

- (void)pp_prepareView:(UIView *)view
      translationY:(CGFloat)translationY
             scale:(CGFloat)scale
      reduceMotion:(BOOL)reduceMotion
{
    if (!view) {
        return;
    }

    view.alpha = [self pp_initialEntranceAlphaForView:view reduceMotion:reduceMotion];
    if (reduceMotion) {
        view.transform = CGAffineTransformIdentity;
        return;
    }

    CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, translationY);
    CGAffineTransform shrink = CGAffineTransformMakeScale(scale, scale);
    view.transform = CGAffineTransformConcat(translate, shrink);
}

- (void)pp_prepareEntranceAnimationState
{
    if (self.didAnimate) {
        return;
    }

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    for (UIView *glowView in @[self.ambientGlowTopView ?: [UIView new],
                               self.ambientGlowBottomView ?: [UIView new]]) {
        glowView.alpha = reduceMotion ? 1.0 : 0.0;
        glowView.transform = reduceMotion ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.94, 0.94);
    }

    NSArray<UIView *> *primaryViews = [self pp_primaryEntranceViews];
    [primaryViews enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        CGFloat translationY = 16.0 + MIN((CGFloat)idx * 2.0, 8.0);
        CGFloat scale = 0.985;
        if (view == self.titleCard) {
            translationY = 8.0;
            scale = 0.992;
        } else if (view == self.infoView) {
            translationY = 10.0;
            scale = 0.988;
        } else if (view == self.descriptionSurfaceView) {
            translationY = 8.0;
            scale = 0.992;
        } else if (view == self.contactDockView) {
            translationY = 12.0;
            scale = 0.986;
        }
        [self pp_prepareView:view
                translationY:translationY
                       scale:scale
                reduceMotion:reduceMotion];
    }];

    for (UIView *view in [self pp_secondaryEntranceViews]) {
        CGFloat translationY = (view == self.petsTitleView) ? 5.0 : 8.0;
        CGFloat scale = (view == self.petsTitleView) ? 0.992 : 0.97;
        [self pp_prepareView:view
                translationY:translationY
                       scale:scale
                reduceMotion:reduceMotion];
    }

    for (UIView *view in [self pp_galleryEntranceViews]) {
        [self pp_prepareView:view
                translationY:-12.0
                       scale:0.92
                reduceMotion:reduceMotion];
    }
}

- (void)pp_beginEntranceAnimationsIfNeeded
{
    if (self.didAnimate) {
        return;
    }
    self.didAnimate = YES;

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    [self.view layoutIfNeeded];

    NSArray<UIView *> *glowViews = @[self.ambientGlowTopView ?: [UIView new],
                                     self.ambientGlowBottomView ?: [UIView new]];
    [glowViews enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        [UIView animateWithDuration:reduceMotion ? 0.16 : 0.62
                              delay:0.02 + (0.04 * idx)
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    NSArray<UIView *> *primaryViews = [self pp_primaryEntranceViews];
    [primaryViews enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        NSTimeInterval delay = 0.08 + (0.05 * idx);
        NSTimeInterval duration = 0.46;

        if (view == self.titleCard) {
            delay = 0.0;
            duration = 0.40;
        } else if (view == self.infoView) {
            delay = 0.03;
            duration = 0.34;
        } else if (view == self.descriptionSurfaceView) {
            delay = 0.06;
            duration = 0.36;
        } else if (view == self.contactDockView) {
            delay = 0.10;
            duration = 0.40;
        }

        if (reduceMotion) {
            [UIView animateWithDuration:0.18
                                  delay:delay
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                view.alpha = 1.0;
                view.transform = CGAffineTransformIdentity;
            } completion:nil];
            return;
        }

        [UIView animateWithDuration:duration
                              delay:delay
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    NSArray<UIView *> *secondaryViews = [self pp_secondaryEntranceViews];
    [secondaryViews enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        NSTimeInterval delay = (view == self.petsTitleView) ? 0.02 : (0.12 + (0.04 * idx));
        NSTimeInterval duration = (view == self.petsTitleView) ? 0.26 : 0.32;
        if (reduceMotion) {
            [UIView animateWithDuration:0.16
                                  delay:delay
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                view.alpha = 1.0;
                view.transform = CGAffineTransformIdentity;
            } completion:nil];
            return;
        }

        [UIView animateWithDuration:duration
                              delay:delay
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    NSArray<UIView *> *galleryViews = [self pp_galleryEntranceViews];
    [galleryViews enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        NSTimeInterval delay = 0.08 + (0.035 * idx);
        if (reduceMotion) {
            [UIView animateWithDuration:0.16
                                  delay:delay
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                view.alpha = 1.0;
                view.transform = CGAffineTransformIdentity;
            } completion:nil];
            return;
        }

        [UIView animateWithDuration:0.30
                              delay:delay
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    NSTimeInterval pillsDelay = reduceMotion ? 0.04 : 0.08;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(pillsDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.petsTitleView animatePillsIn];
    });
}

#pragma mark - Contact Access

- (void)pp_updatePinnedContactInsets
{
    if (!self.contentScrollView || !self.contactDockHeightConstraint) {
        return;
    }

    CGFloat dockHeight = MAX(self.contactDockHeightConstraint.constant, 84.0);
    CGFloat bottomInset = dockHeight + 26.0;
    UIEdgeInsets inset = self.contentScrollView.contentInset;
    inset.bottom = bottomInset;
    self.contentScrollView.contentInset = inset;

    UIEdgeInsets indicatorInset = self.contentScrollView.scrollIndicatorInsets;
    indicatorInset.bottom = bottomInset;
    self.contentScrollView.scrollIndicatorInsets = indicatorInset;
}

- (void)pp_updateContactAccessStateAnimated:(BOOL)animated
{
    BOOL isLoggedIn = UserManager.sharedManager.isUserLoggedIn;
    CGFloat contactHeight = isLoggedIn ? 64.0 : 86.0;
    self.contactViewHeightConstraint.constant = contactHeight;
    self.contactDockHeightConstraint.constant = contactHeight + 20.0;
    [self pp_updatePinnedContactInsets];

    if (isLoggedIn) {
        self.contactLockOverlayView.hidden = YES;
        self.contactView.accessibilityHint = nil;
        [self pp_loadOwnerContactIfNeeded];
    } else {
        [self pp_buildGuestContactOverlayIfNeeded];
        self.contactLockOverlayView.hidden = NO;
        self.ownerModel = nil;
        self.contactView.nameLabel.text = kLang(@"Contact Advertiser");
        self.contactView.avatarImageView.image = PPSYSImage(@"person.crop.circle.fill");
        self.contactView.callButton.enabled = NO;
        self.contactView.chatButton.enabled = NO;
        self.contactView.callButton.alpha = 0.35;
        self.contactView.chatButton.alpha = 0.35;
        self.contactView.accessibilityHint = kLang(@"AdOwnerInfoGuestSubtitle");
    }

    [self pp_styleContactActionButtons];

    if (animated) {
        [UIView animateWithDuration:0.24 animations:^{
            [self.view layoutIfNeeded];
        }];
    } else {
        [self.view layoutIfNeeded];
    }
}

- (void)pp_buildGuestContactOverlayIfNeeded
{
    if (self.contactLockOverlayView) {
        return;
    }

    UIBlurEffect *blurEffect;
    if (@available(iOS 17.0, *)) {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    } else {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    }

    self.contactLockOverlayView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.contactLockOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contactLockOverlayView.layer.cornerRadius = 18.0;
    self.contactLockOverlayView.layer.masksToBounds = YES;
    self.contactLockOverlayView.userInteractionEnabled = YES;
    self.contactLockOverlayView.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.08];
    self.contactLockOverlayView.layer.borderWidth = 0.75;
    [self.contactLockOverlayView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.16]];

    [self.contactView addSubview:self.contactLockOverlayView];

    [NSLayoutConstraint activateConstraints:@[
        [self.contactLockOverlayView.leadingAnchor constraintEqualToAnchor:self.contactView.leadingAnchor constant:4],
        [self.contactLockOverlayView.trailingAnchor constraintEqualToAnchor:self.contactView.trailingAnchor constant:-4],
        [self.contactLockOverlayView.topAnchor constraintEqualToAnchor:self.contactView.topAnchor constant:4],
        [self.contactLockOverlayView.bottomAnchor constraintEqualToAnchor:self.contactView.bottomAnchor constant:-4],
    ]];

    UIView *contentView = self.contactLockOverlayView.contentView;

    UIView *iconBadge = [[UIView alloc] init];
    iconBadge.translatesAutoresizingMaskIntoConstraints = NO;
    iconBadge.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.16];
    iconBadge.layer.cornerRadius = 18.0;
    [contentView addSubview:iconBadge];

    UIImageView *lockIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.fill"]];
    lockIcon.translatesAutoresizingMaskIntoConstraints = NO;
    lockIcon.tintColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    lockIcon.contentMode = UIViewContentModeScaleAspectFit;
    [iconBadge addSubview:lockIcon];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:14];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.textAlignment = NSTextAlignmentNatural;
    titleLabel.numberOfLines = 1;
    titleLabel.text = kLang(@"AdOwnerInfoGuestTitle");
    [contentView addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:11];
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.textAlignment = NSTextAlignmentNatural;
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.text = kLang(@"AdOwnerInfoGuestSubtitle");
    [contentView addSubview:subtitleLabel];

    self.contactLockButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.contactLockButton setTitle:kLang(@"AdOwnerInfoGuestCTA") forState:UIControlStateNormal];
    [self.contactLockButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.contactLockButton.backgroundColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    self.contactLockButton.layer.cornerRadius = 18.0;
    self.contactLockButton.layer.masksToBounds = YES;
    self.contactLockButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.contactLockButton.titleLabel.font = [GM boldFontWithSize:13];
    [self.contactLockButton addTarget:self action:@selector(pp_contactRegisterTapped) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:self.contactLockButton];
    [self pp_styleInteractiveButton:self.contactLockButton];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_contactRegisterTapped)];
    [self.contactLockOverlayView addGestureRecognizer:tap];

    [NSLayoutConstraint activateConstraints:@[
        [iconBadge.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:12],
        [iconBadge.centerYAnchor constraintEqualToAnchor:contentView.centerYAnchor],
        [iconBadge.widthAnchor constraintEqualToConstant:36],
        [iconBadge.heightAnchor constraintEqualToConstant:36],

        [lockIcon.centerXAnchor constraintEqualToAnchor:iconBadge.centerXAnchor],
        [lockIcon.centerYAnchor constraintEqualToAnchor:iconBadge.centerYAnchor],
        [lockIcon.widthAnchor constraintEqualToConstant:16],
        [lockIcon.heightAnchor constraintEqualToConstant:16],

        [self.contactLockButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-12],
        [self.contactLockButton.centerYAnchor constraintEqualToAnchor:contentView.centerYAnchor],
        [self.contactLockButton.heightAnchor constraintEqualToConstant:36],

        [titleLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:12],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconBadge.trailingAnchor constant:12],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contactLockButton.leadingAnchor constant:-10],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:2],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contactLockButton.leadingAnchor constant:-10],
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:contentView.bottomAnchor constant:-12],
    ]];
}

- (void)pp_contactRegisterTapped
{
    if (UserManager.sharedManager.isUserLoggedIn) {
        [self pp_updateContactAccessStateAnimated:YES];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [PPUserSigningManager presentSignInFrom:self
                                    success:^(UserModel *user) {
        __strong typeof(weakSelf) self = weakSelf;
        (void)user;
        [self pp_updateContactAccessStateAnimated:YES];
    }
                                    failure:nil
                                  cancelled:nil];
}

- (void)pp_loadOwnerContactIfNeeded
{
    if (!UserManager.sharedManager.isUserLoggedIn ||
        self.ownerModel ||
        self.isLoadingOwnerModel ||
        self.ad.ownerID.length == 0) {
        return;
    }

    self.isLoadingOwnerModel = YES;
    __weak typeof(self) weakSelf = self;
    [UsrMgr getOtherUserModelFromFirestoreWithUID:self.ad.ownerID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        self.isLoadingOwnerModel = NO;
        if (error || !user || !UserManager.sharedManager.isUserLoggedIn) {
            return;
        }

        self.ownerModel = user;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.contactView configureWithUser:user
                                   chatCallback:^{ [self startChatWith:user]; }
                                   callCallback:^{
                if (!user.MobileNo.length) {
                    [PPAlertHelper showInfoIn:self
                                        title:kLang(@"No Number")
                                     subtitle:kLang(@"This user has no phone number")];
                    return;
                }

                [self trackAdInteraction:PPItemInteractionTypeCall];
                [AppClasses callPhoneNumber:user.MobileNo fromViewController:self];
            }];
            [self pp_styleContactActionButtons];

            [UIView animateWithDuration:0.30 animations:^{
                self.contactView.alpha = 1.0;
            }];
        });
    }];
}

#pragma mark - Actions

- (IBAction)callOwnerBtn:(id)sender {
    if (self.ownerModel) {
        [self trackAdInteraction:PPItemInteractionTypeCall];
        [AppClasses callPhoneNumber:self.ownerModel.MobileNo fromViewController:self];
    }
}

- (void)handleShareAction  {
    [PPAdSharingHelper sharePetAd:self.ad fromViewController:self];
    [self trackAdInteraction:PPItemInteractionTypeShare];
}

- (IBAction)dissmissMe:(id)sender {
    if (self.navigationController &&
           self.navigationController.viewControllers.count > 1) {

           // Pushed → pop
           [self.navigationController popViewControllerAnimated:YES];

       } else {

           // Presented (modal / sheet / popover) → dismiss
           [self dismissViewControllerAnimated:YES completion:nil];
       }
}

#pragma mark - Chat Methods
- (void)startChatWith:(UserModel *)user
{
    NSLog(@"💬 [Chat] Start chat requested with userID=%@", user.ID);

    [ChManager.sharedManager createOrGetChatThreadWithUser:user
                                                completion:^(ChatThreadModel * _Nullable thread,
                                                             NSError * _Nullable error)
    {
        if (error) {
            NSLog(@"❌ [Chat] Failed to create/get chat thread for userID=%@ | error=%@",
                  user.ID,
                  error.localizedDescription);
            return;
        }

        if (!thread) {
            NSLog(@"⚠️ [Chat] Thread is nil for userID=%@", user.ID);
            return;
        }

        NSLog(@"✅ [Chat] Thread ready | threadID=%@ | messagesCount=%ld",
              thread.ID,
              (long)thread.messagesCount);

        [self trackAdInteraction:PPItemInteractionTypeChat];

        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"➡️ [Chat] Opening chat UI for threadID=%@", thread.ID);

            // Coordinator is optional here, but keeping for consistency
            //PPOverlayCoordinator *over = [[PPOverlayCoordinator alloc] initWithPresenter:self];
            [PPOverlayCoordinator pp_openChatThread:thread fromVC:self];
        });
    }];
}


#pragma mark - Memory Management

- (void)dealloc {
    // Clean up any observers or timers if needed
}

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

- (void)trackAdInteraction:(PPItemInteractionType)interaction {
    if (self.ad.adID.length == 0) return;
    [PetAdManager trackInteraction:interaction
                         forItemID:self.ad.adID
                        collection:kPetAdsCollection
                            userID:[self trackingUserID]
                        completion:nil];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self pp_stopLiveMotion];
    if ((self.isMovingFromParentViewController || self.isBeingDismissed) &&
        self.navigationController &&
        self.didCaptureNavigationBarState) {
        [self.navigationController setNavigationBarHidden:self.previousNavigationBarHidden animated:animated];
        self.didCaptureNavigationBarState = NO;
    }
    self.modalInPresentation = YES;
}

- (UIButton *)pp_makeGlassCircleButtonWithSymbol:(NSString *)symbol
                                          action:(SEL)action {

    UIButtonConfiguration *config;

    if (@available(iOS 26.0, *)) {
        config = [UIButtonConfiguration glassButtonConfiguration];
        config.baseForegroundColor = UIColor.whiteColor;
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    } else {
        config = [UIButtonConfiguration filledButtonConfiguration];
        config.baseForegroundColor = UIColor.whiteColor;
        config.baseBackgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.20];
        UIBackgroundConfiguration *background = config.background;
        background.visualEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
        background.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.22];
        background.strokeWidth = 0.8;
        config.background = background;
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    }

    config.image = [UIImage systemImageNamed:symbol];
    config.preferredSymbolConfigurationForImage =
    [UIImageSymbolConfiguration configurationWithPointSize:16.5
                                                    weight:UIImageSymbolWeightSemibold];
    config.contentInsets = NSDirectionalEdgeInsetsMake(12.0, 12.0, 12.0, 12.0);

    UIButton *btn =
    [UIButton buttonWithConfiguration:config primaryAction:nil];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.clipsToBounds = NO;
    btn.adjustsImageWhenHighlighted = YES;

    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    [NSLayoutConstraint activateConstraints:@[
        [btn.widthAnchor constraintEqualToConstant:46],
        [btn.heightAnchor constraintEqualToConstant:46],
    ]];

    return btn;
}

- (void)pp_styleInteractiveButton:(UIButton *)button
{
    if (!button) {
        return;
    }

    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    button.layer.masksToBounds = NO;
    [button pp_setShadowColor:UIColor.blackColor];
    button.layer.shadowOpacity = 0.18;
    button.layer.shadowRadius = 18.0;
    button.layer.shadowOffset = CGSizeMake(0, 10);
    button.layer.borderWidth = 0.75;
    [button pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.16]];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = button.configuration;
        if (config) {
            UIBackgroundConfiguration *background = config.background;
            if (button == self.contactLockButton) {
                background.backgroundColor = AppPrimaryClr ?: UIColor.systemBlueColor;
                background.visualEffect = nil;
                background.strokeColor = UIColor.clearColor;
                background.strokeWidth = 0.0;
                config.baseForegroundColor = UIColor.whiteColor;
            }
            config.background = background;
            button.configuration = config;
        }
    }

    [button removeTarget:self action:@selector(pp_interactiveButtonTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [button removeTarget:self action:@selector(pp_interactiveButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    [button addTarget:self action:@selector(pp_interactiveButtonTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [button addTarget:self action:@selector(pp_interactiveButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
}

- (void)pp_styleContactActionButtons
{
    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    if (self.contactView.callButton) {
        [buttons addObject:self.contactView.callButton];
    }
    if (self.contactView.chatButton) {
        [buttons addObject:self.contactView.chatButton];
    }
    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemBlueColor;

    for (UIButton *button in buttons) {
        button.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.50];
        button.tintColor = accentColor;
        button.layer.cornerRadius = 18.0;
        if (@available(iOS 13.0, *)) {
            button.layer.cornerCurve = kCACornerCurveContinuous;
        }
        button.layer.borderWidth = 0.5;
        [button pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.12]];
        [self pp_styleInteractiveButton:button];
    }
}

- (void)pp_interactiveButtonTouchDown:(UIButton *)sender
{
    [UIView animateWithDuration:0.14
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.94, 0.94);
        sender.alpha = 0.96;
    } completion:nil];
}

- (void)pp_interactiveButtonTouchUp:(UIButton *)sender
{
    [UIView animateWithDuration:0.22
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.28
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = 1.0;
    } completion:nil];
}

- (void)pp_updateHeroDepthForScrollOffset:(CGFloat)offsetY
{
    CGFloat upwardTravel = MIN(MAX(offsetY, 0.0), 96.0);
    CGFloat pullDownTravel = MIN(fabs(MIN(offsetY, 0.0)), 72.0);
    CGFloat heroScale = 1.0 + (pullDownTravel / 720.0);
    CGFloat heroLift = upwardTravel * 0.12;

    CGAffineTransform heroTransform = CGAffineTransformIdentity;
    heroTransform = CGAffineTransformTranslate(heroTransform, 0.0, -heroLift);
    heroTransform = CGAffineTransformScale(heroTransform, heroScale, heroScale);
    self.imageGallery.transform = heroTransform;
    self.galleryScrimView.transform = heroTransform;

    self.titleCard.transform = CGAffineTransformMakeTranslation(0.0, -(upwardTravel * 0.18));
    self.titleCard.alpha = 1.0 - MIN(0.16, upwardTravel / 460.0);

    if (self.didAnimate && self.contactDockView) {
        CGFloat dockLift = MIN(upwardTravel, 80.0) * 0.035;
        self.contactDockView.transform = CGAffineTransformMakeTranslation(0.0, -dockLift);
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView != self.contentScrollView) {
        return;
    }

    [self pp_updateHeroDepthForScrollOffset:scrollView.contentOffset.y];
}

#pragma mark - Description Styling Helper

- (NSAttributedString *)pp_styledDescriptionFromText:(NSString *)text {

    UIFont *bodyFont = [GM MidFontWithSize:17];
    UIColor *textColor = UIColor.labelColor;
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineSpacing = 5.0;
    paragraphStyle.paragraphSpacing = 10.0;
    paragraphStyle.alignment = NSTextAlignmentNatural;

    NSMutableAttributedString *attr =
    [[NSMutableAttributedString alloc] initWithString:text ?: @""];

    [attr addAttributes:@{
        NSFontAttributeName: bodyFont,
        NSForegroundColorAttributeName: textColor,
        NSParagraphStyleAttributeName: paragraphStyle
    } range:NSMakeRange(0, attr.length)];

    // Detect links automatically
    NSDataDetector *detector =
    [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];

    [detector enumerateMatchesInString:attr.string
                               options:0
                                 range:NSMakeRange(0, attr.length)
                            usingBlock:^(NSTextCheckingResult *result,
                                         NSMatchingFlags flags,
                                         BOOL *stop) {

        if (result.resultType == NSTextCheckingTypeLink) {
            [attr addAttributes:@{
                NSForegroundColorAttributeName: AppPrimaryClr,
                NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
            } range:result.range];
        }
    }];

    // Very light markdown: **bold**
    NSRegularExpression *boldRegex =
    [NSRegularExpression regularExpressionWithPattern:@"\\*\\*(.*?)\\*\\*"
                                              options:0 error:nil];

    NSArray *matches =
    [boldRegex matchesInString:attr.string
                       options:0
                         range:NSMakeRange(0, attr.length)];

    for (NSTextCheckingResult *match in matches.reverseObjectEnumerator) {
        NSRange boldRange = [match rangeAtIndex:1];
        [attr addAttribute:NSFontAttributeName
                     value:[UIFont boldSystemFontOfSize:bodyFont.pointSize]
                     range:boldRange];

        // Remove ** markers
        [attr replaceCharactersInRange:NSMakeRange(match.range.location, 2)
                            withString:@""];
        [attr replaceCharactersInRange:NSMakeRange(match.range.location + boldRange.length, 2)
                            withString:@""];
    }

    return attr;
}


#pragma mark - Report Ad

- (void)reportAdBTN:(UIButton *)sender {
    if (![UserManager sharedManager].isUserLoggedIn) {
         [UserManager showPromptOnTopController];
        return;
    }

    NSString *currentUID = [self trackingUserID];
    if ([currentUID isEqualToString:self.ad.ownerID]) {
        return;
    }

    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:kLang(@"report_alert_title")
        message:kLang(@"report_alert_message")
        preferredStyle:UIAlertControllerStyleActionSheet];

    NSDictionary *reasons = @{
        @"inappropriate_content": kLang(@"report_reason_inappropriate"),
        @"scam_fraud": kLang(@"report_reason_fraud"),
        @"wrong_category": kLang(@"report_reason_wrong_category"),
        @"spam": kLang(@"report_reason_spam"),
        @"other": kLang(@"report_reason_other")
    };

    for (NSString *code in @[@"inappropriate_content", @"scam_fraud", @"wrong_category", @"spam", @"other"]) {
        [sheet addAction:[UIAlertAction actionWithTitle:reasons[code]
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {
                [self submitAdReportWithReason:code collection:kPetAdsCollection documentID:self.ad.adID];
            }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
        style:UIAlertActionStyleCancel handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = sender;
        sheet.popoverPresentationController.sourceRect = sender.bounds;
    }

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)submitAdReportWithReason:(NSString *)reason
                      collection:(NSString *)collection
                      documentID:(NSString *)docID {
    if (docID.length == 0) return;

    NSString *currentUID = [self trackingUserID];
    if (currentUID.length == 0) return;

    FIRFirestore *db = [FIRFirestore firestore];

    // 1. Flag on the content document (array-union for multi-reporter support)
    FIRDocumentReference *docRef =
        [[db collectionWithPath:collection] documentWithPath:docID];

    [docRef updateData:@{
        @"reportedBy"    : [FIRFieldValue fieldValueForArrayUnion:@[currentUID]],
        @"reportCount"   : [FIRFieldValue fieldValueForIntegerIncrement:1],
        @"lastReportedAt": [FIRFieldValue fieldValueForServerTimestamp]
    } completion:nil];

    // 2. Write a dedicated report document for audit trail
    NSString *reportID = [NSString stringWithFormat:@"%@_%@", docID, currentUID];
    FIRDocumentReference *reportRef = [[db collectionWithPath:@"reports"] documentWithPath:reportID];

    NSDictionary *reportData = @{
        @"reportId"         : reportID,
        @"contentId"        : docID,
        @"contentType"      : @"pet_ad",
        @"collection"       : collection,
        @"reason"           : reason,
        @"reporterUid"      : currentUID,
        @"reportedOwnerUid" : self.ad.ownerID ?: @"",
        @"status"           : @"pending",
        @"platform"         : @"ios",
        @"createdAt"        : [FIRFieldValue fieldValueForServerTimestamp],
        @"updatedAt"        : [FIRFieldValue fieldValueForServerTimestamp]
    };

    [reportRef setData:reportData merge:YES completion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [GM showAlertWithTitle:kLang(@"Error") message:kLang(@"report_submit_failed_message") imageName:@"" inViewController:self];
            } else {
                [PPAlertHelper showSuccessIn:self title:kLang(@"report_submit_title") subtitle:kLang(@"report_submit_message")];
            }
        });
    }];
}



@end
