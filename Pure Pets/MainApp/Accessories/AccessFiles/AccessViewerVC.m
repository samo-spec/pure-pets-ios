//
//  ViewerVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//

#import "AccessViewerVC.h"
#import "PPUniversalCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPAdSharingHelper.h"
#import "CartManager.h"
#import "PPCommerceFeedbackManager.h"
#import "PPAlertHelper.h"
#import "PPHUD.h"
#import "PPImageLoaderManager.h"
#import "PPPetsTitleView.h"
#import "ChManager.h"
#import "PPAnalytics.h"
#import "PPNetworkRetryHelper.h"
#import "PPModernAvatarRenderer.h"
#import "SellerProfileVC.h"

static NSString * const PPAccessoryOfficialSupportUserID = @"PUIDPOFFICILAL20262214";

// ─────────────────────────────────────────────────────────
// MARK: - Enterprise Design System Constants
// ─────────────────────────────────────────────────────────
// Spacing scale: 4 / 8 / 12 / 16 / 24 / 32
static const CGFloat kAVSpace4               = 4.0;
static const CGFloat kAVSpace8               = 8.0;
static const CGFloat kAVSpace12              = 12.0;
static const CGFloat kAVSpace16              = 16.0;
static const CGFloat kAVSpace24              = 24.0;
static const CGFloat kAVSpace32              = 32.0;

// Border Radius
static const CGFloat kAVCardCornerRadius     = 32.0;    // Large section surfaces
static const CGFloat kAVButtonCornerRadius   = 18.0;    // Rounded action pills
static const CGFloat kAVBadgeCornerRadius    = 999.0;   // Badges: pill
static const CGFloat kAVHeroCornerRadius     = 28.0;   // Modern rounded hero corners
static const CGFloat kAVDetailRowCorner      = 18.0;    // Detail row bg

// Layout
static const CGFloat kAVSectionInset         = 16.0;    // horizontal screen margin
static const CGFloat kAVCardPadding          = 20.0;    // inner section padding
static const CGFloat kAVActionBarHeight      = 50.0;    // action button height
static const CGFloat kAVDetailRowMinHeight   = 66.0;    // minimum detail row height
static const CGFloat kAVBottomBarBase        = 106.0;   // sticky bottom bar base height
static const CGFloat kAVSectionSpacing       = 20.0;    // section gap
static const CGFloat kAVSuggestionBottomInset = 32.0;   // breathing room below collection
static const CGFloat kAVSellerAvatarSize     = 64.0;    // seller identity avatar size
static const CGFloat kAVSellerAvatarRingSize = 74.0;    // premium avatar shell size
static const CGFloat kAVSellerPrimaryBtnHeight = 52.0;  // primary CTA button height
static const CGFloat kAVSellerStatusPillHeight = 22.0;  // seller badge pill height

// Elevation (shadows)
static const CGFloat kAVCardShadowOpacity    = 0.2f;
static const CGFloat kAVCardShadowRadius     = 6.0;
static const CGFloat kAVCardShadowOffsetY    = 3.0;
static const CGFloat kAVSectionBorderWidth   = 1.0;

static UIColor *AVSellerCardInkColor(void) {
    return AppPageColor() ?: [UIColor colorWithWhite:0.08 alpha:1.0];
}

static UIColor *AVSellerCardAccentColor(void) {
    return [AppPrimaryClrDarker colorWithAlphaComponent:1.0];
}

static UIColor *AVSellerCardGoldColor(void) {
    return [UIColor colorWithRed:0.78 green:0.62 blue:0.30 alpha:1.0];
}

static UIColor *AVSellerCardSurfaceColor(void) {
    return AppForgroundColr ?: UIColor.whiteColor;
}

@interface AccessViewerVC()<UICollectionViewDataSource,UICollectionViewDelegate,CartQuantityUpdateDelegate,UICollectionViewDelegateFlowLayout, SellerProfileVCDelegate>

// ── Scaffold ──
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *ambientGlowTopView;
@property (nonatomic, strong) UIView *ambientGlowBottomView;
@property (nonatomic, strong) BBCartBottomBar *bottomBar;
@property (nonatomic, strong) UIImageView *barBackgroundImageView;
@property (nonatomic, strong) NSLayoutConstraint *bottomBarHeightConstraint;

// ── Hero ──
@property (nonatomic, strong) UIView *heroContainerView;
@property (nonatomic, strong) PetImageGalleryView *imageGallery;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) UILabel *heroKindBadgeLabel;
@property (nonatomic, strong) UILabel *heroStockBadgeLabel;
@property (nonatomic, strong) NSLayoutConstraint *heroHeightConstraint;

// ── Summary Card ──
@property (nonatomic, strong) UIView *titleCard;
@property (nonatomic, strong) PPPetsTitleView *petsTitleView;

// ── Seller Section ──
@property (nonatomic, strong) UIView *sellerSectionView;
@property (nonatomic, strong) UIView *sellerInnerSurfaceView;
@property (nonatomic, strong) UIView *sellerAccentGlowView;
@property (nonatomic, strong) UIView *sellerAvatarRingView;
@property (nonatomic, strong) UIImageView *sellerAvatarImageView;
@property (nonatomic, strong) UILabel *sellerEyebrowLabel;
@property (nonatomic, strong) UILabel *sellerNameLabel;
@property (nonatomic, strong) UILabel *sellerSubtitleLabel;
@property (nonatomic, strong) UILabel *sellerStatusBadgeLabel;
@property (nonatomic, strong) UIStackView *actionStackView;
@property (nonatomic, strong) UIButton *chatActionButton;
@property (nonatomic, strong) UIButton *callActionButton;
@property (nonatomic, strong) UIButton *shareActionButton;
@property (nonatomic, strong) UIButton *supportActionButton;
@property (nonatomic, strong) UIButton *profileActionButton;
@property (nonatomic, strong) NSLayoutConstraint *sellerActionsTopToChatConstraint;

// ── Details Card ──
@property (nonatomic, strong) UIView *detailsCardView;
@property (nonatomic, strong) UIStackView *detailsStackView;
@property (nonatomic, strong) UILabel *typeValueLabel;
@property (nonatomic, strong) UILabel *conditionValueLabel;
@property (nonatomic, strong) UILabel *stockValueLabel;
@property (nonatomic, strong) UILabel *categoryValueLabel;

// ── Description ──
@property (nonatomic, strong) PPAccessoryDescriptionView *descView;

// ── Suggestions ──
@property (nonatomic, strong) UIView *suggestionsContainerView;
@property (nonatomic, strong) UILabel *suggestionsSubtitleLabel;
@property (nonatomic, strong) UILabel *emptySuggestionsLabel;
@property (nonatomic, strong) UICollectionView *accessoryCollectionView;
@property (nonatomic, strong) NSLayoutConstraint *accessoryCollectionHeightConstraint;
@property (nonatomic, copy) NSArray<PetAccessory *> *suggestedAccessories;
@property (nonatomic, strong) NSLayoutConstraint *contentBottomToSuggestionsConstraint;
@property (nonatomic, strong) NSLayoutConstraint *contentBottomToSellerConstraint;
@property (nonatomic, strong) UIVisualEffectView *titleBlurView;
// ── State ──
@property (nonatomic, strong) UserModel *ownerModel;
@property (nonatomic, strong) NSTimer *cartButtonTimer;
@property (nonatomic, strong) UIButton *cartButton;
@property (nonatomic, strong) UIBarButtonItem *favBarButtonItem;
@property (nonatomic, strong) UIButton *centerPPBarButton;
@property (nonatomic, assign) BOOL isFavorite;
@property (nonatomic, assign) BOOL didTrackViewInteraction;
@property (nonatomic, strong) PPPhotoBrowserBridge *brower;
@property (nonatomic, assign) BOOL isResolvingOwner;
@property (nonatomic, assign) BOOL ownerLookupFailed;
@property (nonatomic, assign) BOOL didAnimateSellerSection;
@end

@implementation AccessViewerVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}



- (void)viewDidLoad {
    [super viewDidLoad];
    self.isFavorite = NO;
    self.view.backgroundColor = AppBageColor();
    [self initData];
    [self initForms];
    [self designViews];
    [self applyAccessoryContent];
    [self loadOwnerModelIfNeeded];

    _brower = [[PPPhotoBrowserBridge alloc] init];
    _brower.useArabic = Language.isRTL;

    [PPAnalytics logViewItemForAccessory:self.accessAds];
}

- (void)initData {
    // Build the view hierarchy in clean, testable sections
    [self pp_buildScaffold];
    [self pp_buildHeroSection];
    [self pp_buildSummaryCard];
    [self pp_buildDetailsCard];
    [self pp_buildSellerSection];
    [self pp_buildDescriptionSection];
    [self pp_buildSuggestionsSection];
    [self pp_fetchSuggestions];
}

// ─────────────────────────────────────────────────────────
#pragma mark - Section Builders
// ─────────────────────────────────────────────────────────

/// Scroll view + content view + bottom bar chrome
- (void)pp_buildScaffold {

    // ── Bottom bar background ──
    self.barBackgroundImageView = [[UIImageView alloc] init];
    self.barBackgroundImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.barBackgroundImageView.contentMode = UIViewContentModeScaleToFill;
    self.barBackgroundImageView.alpha = 0.0;
    self.barBackgroundImageView.clipsToBounds = YES;
    self.barBackgroundImageView.userInteractionEnabled = NO;
    self.barBackgroundImageView.backgroundColor = AppForgroundColr;
    [self.view addSubview:self.barBackgroundImageView];

    // ── Bottom bar ──
    self.bottomBar = [[BBCartBottomBar alloc] init];
    self.bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.bottomBar];

    // ── Scroll view ──
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.backgroundColor = [AppBageColor() colorWithAlphaComponent:0.5];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    if (@available(iOS 11.0, *)) {
        self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [self.view addSubview:self.scrollView];

    // ── Content view ──
    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentView.backgroundColor = UIColor.clearColor;
    [self.scrollView addSubview:self.contentView];

    // ── Ambient glows ──
    UIColor *accent = AVSellerCardAccentColor();
    UIColor *gold = [UIColor colorWithRed:0.77 green:0.60 blue:0.21 alpha:1.0];
    BOOL dark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);

    self.ambientGlowTopView = [[UIView alloc] init];
    self.ambientGlowTopView.translatesAutoresizingMaskIntoConstraints = NO;
    self.ambientGlowTopView.userInteractionEnabled = NO;
    self.ambientGlowTopView.layer.cornerRadius = 140.0;
    self.ambientGlowTopView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.10 : 0.075];
    [self.contentView addSubview:self.ambientGlowTopView];

    self.ambientGlowBottomView = [[UIView alloc] init];
    self.ambientGlowBottomView.translatesAutoresizingMaskIntoConstraints = NO;
    self.ambientGlowBottomView.userInteractionEnabled = NO;
    self.ambientGlowBottomView.layer.cornerRadius = 168.0;
    self.ambientGlowBottomView.backgroundColor = [gold colorWithAlphaComponent:dark ? 0.10 : 0.085];
    [self.contentView addSubview:self.ambientGlowBottomView];

    [self.contentView sendSubviewToBack:self.ambientGlowBottomView];
    [self.contentView sendSubviewToBack:self.ambientGlowTopView];

    UILayoutGuide *contentGuide;
    UILayoutGuide *frameGuide;
    if (@available(iOS 11.0, *)) {
        contentGuide = self.scrollView.contentLayoutGuide;
        frameGuide   = self.scrollView.frameLayoutGuide;
    } else {
        contentGuide = (id)self.scrollView;
        frameGuide   = (id)self.scrollView;
    }

    // ── Scaffold constraints ──
    self.bottomBarHeightConstraint = [self.bottomBar.heightAnchor constraintEqualToConstant:kAVBottomBarBase];

    [NSLayoutConstraint activateConstraints:@[
        // Bottom bar
        [self.bottomBar.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomBar.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
        self.bottomBarHeightConstraint,

        // Bar background mirrors bottom bar exactly
        [self.barBackgroundImageView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.barBackgroundImageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.barBackgroundImageView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
        [self.barBackgroundImageView.heightAnchor   constraintEqualToAnchor:self.bottomBar.heightAnchor],

        // Scroll view fills space above bottom bar
        [self.scrollView.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor   constraintEqualToAnchor:self.bottomBar.topAnchor],

        // Content view == scrollable content
        [self.contentView.topAnchor      constraintEqualToAnchor:contentGuide.topAnchor],
        [self.contentView.leadingAnchor  constraintEqualToAnchor:contentGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor],
        [self.contentView.bottomAnchor   constraintEqualToAnchor:contentGuide.bottomAnchor],
        [self.contentView.widthAnchor    constraintEqualToAnchor:frameGuide.widthAnchor],
    ]];

    [self.view bringSubviewToFront:self.bottomBar];

    // ── Bottom bar bindings ──
    __weak typeof(self) weakSelf = self;
    __weak typeof(self.bottomBar) weakBottomBar = self.bottomBar;
    NSNumber *amountValue = self.accessAds.finalPrice ?: self.accessAds.price;
    CGFloat amount = amountValue.floatValue;

    self.bottomBar.itemAmount = amount;
    self.bottomBar.onAddToCart = ^(NSInteger quantity) {
        NSLog(@"Added %ld items to cart", (long)quantity);
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
        [weakSelf addToCartButtonTapped:quantity];
    };
    self.bottomBar.onQuantityChanged = ^(NSInteger quantity) {
        __strong typeof(weakBottomBar) bottomBar = weakBottomBar;
        bottomBar.totalAmount = quantity * amount;
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartQuantityChanged];
    };

    [self.bottomBar setInitItemAmount:amount];
    [self.bottomBar.favButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [self.bottomBar.favButton addTarget:self action:@selector(handleShareAction) forControlEvents:UIControlEventTouchUpInside];
    self.bottomBar.favButton.accessibilityLabel = kLang(@"Share");

    NSInteger existingQty = [[CartManager sharedManager] quantityForAccessory:self.accessAds];
    if (existingQty > 1) {
        self.bottomBar.cartItemquantity = existingQty;
        [self.bottomBar updateQuantityUI];
    }
}

/// Full-bleed image hero with kind + stock badges
- (void)pp_buildHeroSection {

    self.heroContainerView = [[UIView alloc] init];
    self.heroContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroContainerView.backgroundColor = AppForgroundColr;
    self.heroContainerView.layer.cornerRadius = 0;
    self.heroContainerView.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    if (@available(iOS 13.0, *)) {
        self.heroContainerView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.heroContainerView.layer.masksToBounds = YES;
    [self.contentView addSubview:self.heroContainerView];

    // ── Image gallery ──
    self.imageGallery = [[PetImageGalleryView alloc] initWithFrame:CGRectZero
                                                       imageItems:self.accessAds.imageItems
                                                      galleryType:PetImageGalleryTypeAccessory
                                                       itemHeight:[self pp_heroHeight]
                                                         parentVC:self
                                                              obj:self.accessAds];
    self.imageGallery.translatesAutoresizingMaskIntoConstraints = NO;
    if (self.accessAds.accessKindType == AccessTypeFood) {
        self.imageGallery.contentMode = UIViewContentModeScaleAspectFit;
    }
    [self.heroContainerView addSubview:self.imageGallery];

    // ── Gradient overlay ──
    self.heroGradientLayer = [CAGradientLayer layer];
    self.heroGradientLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.00].CGColor,
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.10].CGColor,
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.36].CGColor,
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.72].CGColor
    ];
    self.heroGradientLayer.locations = @[@0.0, @0.40, @0.72, @1.0];
    self.heroGradientLayer.startPoint = CGPointMake(0.5, 0.0);
    self.heroGradientLayer.endPoint   = CGPointMake(0.5, 1.0);
    [self.heroContainerView.layer addSublayer:self.heroGradientLayer];

    // ── Badges ──
    self.heroKindBadgeLabel = [self pp_badgeLabelWithFontSize:13.0];
    self.heroKindBadgeLabel.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.90];
    self.heroKindBadgeLabel.textColor = AppPrimaryTextClr;

    self.heroStockBadgeLabel = [self pp_badgeLabelWithFontSize:13.0];
    self.heroStockBadgeLabel.backgroundColor = [[AppPrimaryClr colorWithAlphaComponent:0.95] colorWithAlphaComponent:0.95];
    self.heroStockBadgeLabel.textColor = AppForgroundColr;

    [self.heroContainerView addSubview:self.heroKindBadgeLabel];
    [self.heroContainerView addSubview:self.heroStockBadgeLabel];

    // ── Constraints ──
    self.heroHeightConstraint = [self.heroContainerView.heightAnchor constraintEqualToConstant:[self pp_heroHeight]];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroContainerView.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor constant:0],
        [self.heroContainerView.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor constant:0],
        [self.heroContainerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-0],
        self.heroHeightConstraint,

        [self.imageGallery.topAnchor      constraintEqualToAnchor:self.heroContainerView.topAnchor],
        [self.imageGallery.leadingAnchor  constraintEqualToAnchor:self.heroContainerView.leadingAnchor],
        [self.imageGallery.trailingAnchor constraintEqualToAnchor:self.heroContainerView.trailingAnchor],
        [self.imageGallery.bottomAnchor   constraintEqualToAnchor:self.heroContainerView.bottomAnchor],

        [self.heroKindBadgeLabel.leadingAnchor constraintEqualToAnchor:self.heroContainerView.leadingAnchor constant:kAVSectionInset],
        [self.heroKindBadgeLabel.topAnchor     constraintEqualToAnchor:self.heroContainerView.topAnchor     constant:kAVSectionInset],

        [self.heroStockBadgeLabel.trailingAnchor constraintEqualToAnchor:self.heroContainerView.trailingAnchor constant:-kAVSectionInset],
        [self.heroStockBadgeLabel.bottomAnchor   constraintEqualToAnchor:self.heroContainerView.bottomAnchor   constant:-kAVSectionInset],
    ]];
}

/// Title / subtitle / price summary — uses reusable PPPetsTitleView (same as ViewerVC)
- (void)pp_buildSummaryCard {


    // --- Title Card Container ---
    self.titleCard = [[UIView alloc] init];
    self.titleCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleCard.backgroundColor = UIColor.clearColor;
    self.titleCard.layer.cornerRadius = 22;
    self.titleCard.layer.masksToBounds = NO;

    // Soft, modern shadow (Apple-style)
    [self.titleCard pp_setShadowColor:UIColor.blackColor];
    self.titleCard.layer.shadowOpacity = 0.12;
    self.titleCard.layer.shadowRadius = 22;
    self.titleCard.layer.shadowOffset = CGSizeMake(0, 10);

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
    self.titleBlurView.layer.cornerRadius = 16;
    self.titleBlurView.layer.masksToBounds = YES;

    // Optional subtle tint to stabilize contrast
    UIView *tintView = [[UIView alloc] init];
    tintView.translatesAutoresizingMaskIntoConstraints = NO;
    tintView.backgroundColor =
        [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.25];

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


  ;
    [self.contentView addSubview:self.titleCard];

    self.petsTitleView = [[PPPetsTitleView alloc] init];
    self.petsTitleView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.petsTitleView configureWithTitle:PPSafeString(self.accessAds.name)
                                  location:[self pp_summarySubtitleText]
                                     price:[self pp_priceText]];
    [self.titleCard addSubview:self.petsTitleView];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleCard.bottomAnchor      constraintEqualToAnchor:self.heroContainerView.bottomAnchor constant:-kAVSectionInset],
        [self.titleCard.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor  constant:kAVSectionInset],
        [self.titleCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kAVSectionInset],

        [self.petsTitleView.topAnchor      constraintEqualToAnchor:self.titleCard.topAnchor constant:8],
        [self.petsTitleView.leadingAnchor  constraintEqualToAnchor:self.titleCard.leadingAnchor constant:8],
        [self.petsTitleView.trailingAnchor constraintEqualToAnchor:self.titleCard.trailingAnchor constant:-8],
        [self.petsTitleView.bottomAnchor   constraintEqualToAnchor:self.titleCard.bottomAnchor],
    ]];

    self.titleCard.hidden = YES;
}

/// Category / type / condition / stock section
- (void)pp_buildDetailsCard {

    self.detailsCardView = [self pp_surfacepage];
    [self.contentView addSubview:self.detailsCardView];
    UIView *innerDetails = [self pp_innerCardOf:self.detailsCardView];

    UILabel *detailsTitleLabel = [[UILabel alloc] init];
    detailsTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    detailsTitleLabel.font = [GM boldFontWithSize:20];
    detailsTitleLabel.textColor = AppPrimaryTextClr;
    detailsTitleLabel.text = kLang(@"accessory_view_details_title");
    [innerDetails addSubview:detailsTitleLabel];

    self.detailsStackView = [[UIStackView alloc] init];
    self.detailsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailsStackView.axis    = UILayoutConstraintAxisVertical;
    self.detailsStackView.spacing = 16.0;
    [innerDetails addSubview:self.detailsStackView];

    UILabel *categoryValue  = nil;
    UILabel *typeValue      = nil;
    UILabel *conditionValue = nil;
    UILabel *stockValue     = nil;

    // ── 2-column grid with distinct modern tints ──
    UIStackView *topPair = [[UIStackView alloc] init];
    topPair.axis = UILayoutConstraintAxisHorizontal;
    topPair.spacing = 16.0;
    topPair.distribution = UIStackViewDistributionFillEqually;

    [topPair addArrangedSubview:[self pp_detailRowWithTitle:kLang(@"Category")
                                                systemName:@"square.grid.2x2.fill"
                                                 tintColor:[UIColor systemBlueColor]
                                                valueLabel:&categoryValue]];
    [topPair addArrangedSubview:[self pp_detailRowWithTitle:kLang(@"Type")
                                                systemName:@"shippingbox.fill"
                                                 tintColor:[UIColor systemOrangeColor]
                                                valueLabel:&typeValue]];

    UIStackView *bottomPair = [[UIStackView alloc] init];
    bottomPair.axis = UILayoutConstraintAxisHorizontal;
    bottomPair.spacing = 16.0;
    bottomPair.distribution = UIStackViewDistributionFillEqually;

    [bottomPair addArrangedSubview:[self pp_detailRowWithTitle:kLang(@"Condition")
                                                   systemName:@"checkmark.seal.fill"
                                                    tintColor:[UIColor systemGreenColor]
                                                   valueLabel:&conditionValue]];
    [bottomPair addArrangedSubview:[self pp_detailRowWithTitle:kLang(@"Availability")
                                                   systemName:@"shippingbox.circle.fill"
                                                    tintColor:[UIColor systemIndigoColor]
                                                   valueLabel:&stockValue]];

    [self.detailsStackView addArrangedSubview:topPair];
    [self.detailsStackView addArrangedSubview:bottomPair];

    self.categoryValueLabel  = categoryValue;
    self.typeValueLabel      = typeValue;
    self.conditionValueLabel = conditionValue;
    self.stockValueLabel     = stockValue;

    [NSLayoutConstraint activateConstraints:@[
        [self.detailsCardView.topAnchor      constraintEqualToAnchor:self.imageGallery.bottomAnchor   constant: -kAVSpace24],
        [self.detailsCardView.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor  constant:0],
        [self.detailsCardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-0],

        [detailsTitleLabel.topAnchor      constraintEqualToAnchor:innerDetails.topAnchor      constant:kAVCardPadding],
        [detailsTitleLabel.leadingAnchor  constraintEqualToAnchor:innerDetails.leadingAnchor  constant:kAVCardPadding + 8],
        [detailsTitleLabel.trailingAnchor constraintEqualToAnchor:innerDetails.trailingAnchor constant:-kAVCardPadding],

        [self.detailsStackView.topAnchor      constraintEqualToAnchor:detailsTitleLabel.bottomAnchor       constant:kAVSpace12],
        [self.detailsStackView.leadingAnchor  constraintEqualToAnchor:innerDetails.leadingAnchor  constant:kAVCardPadding],
        [self.detailsStackView.trailingAnchor constraintEqualToAnchor:innerDetails.trailingAnchor constant:-kAVCardPadding],
        [self.detailsStackView.bottomAnchor   constraintEqualToAnchor:innerDetails.bottomAnchor   constant:-8],
    ]];
}

/// Free-text description card
- (void)pp_buildDescriptionSection {

    self.descView = [[PPAccessoryDescriptionView alloc] init];
    self.descView.hostScrollView = self.scrollView;
    [self.contentView addSubview:self.descView];

    [NSLayoutConstraint activateConstraints:@[
        [self.descView.topAnchor      constraintEqualToAnchor:self.sellerSectionView.bottomAnchor   constant:kAVCardPadding],
        [self.descView.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor  constant:kAVCardPadding],
        [self.descView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kAVCardPadding],
    ]];
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [Styling applyCornerMaskToView:self.titleBlurView tl:32 tr:16 bl:32 br:28];
    [self updateCartQuantityBadge];
    [self.view bringSubviewToFront:_bottomBar];
}

- (void)pp_buildSellerSection {

    self.sellerSectionView = [self pp_surfaceCard];
    [self.sellerSectionView pp_setShadowColor:UIColor.blackColor];
    self.sellerSectionView.layer.shadowOpacity = 0.10;
    self.sellerSectionView.layer.shadowRadius = 22.0;
    self.sellerSectionView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    self.sellerSectionView.alpha = UIAccessibilityIsReduceMotionEnabled() ? 1.0 : 0.0;
    self.sellerSectionView.transform = UIAccessibilityIsReduceMotionEnabled() ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0.0, 18.0);
    [self.contentView addSubview:self.sellerSectionView];
    UIView *innerSeller = [self pp_innerCardOf:self.sellerSectionView];
    self.sellerInnerSurfaceView = innerSeller;
    innerSeller.backgroundColor = AVSellerCardSurfaceColor();

    self.sellerAccentGlowView = [[UIView alloc] init];
    self.sellerAccentGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.sellerAccentGlowView.userInteractionEnabled = NO;
    self.sellerAccentGlowView.backgroundColor = [AVSellerCardAccentColor() colorWithAlphaComponent:0.105];
    self.sellerAccentGlowView.layer.shadowColor = AVSellerCardAccentColor().CGColor;
    self.sellerAccentGlowView.layer.shadowOpacity = 0.18;
    self.sellerAccentGlowView.layer.shadowRadius = 34.0;
    self.sellerAccentGlowView.layer.shadowOffset = CGSizeZero;
    [innerSeller addSubview:self.sellerAccentGlowView];

    self.sellerAvatarRingView = [[UIView alloc] init];
    self.sellerAvatarRingView.translatesAutoresizingMaskIntoConstraints = NO;
    self.sellerAvatarRingView.backgroundColor = [AVSellerCardAccentColor() colorWithAlphaComponent:0.09];
    self.sellerAvatarRingView.layer.cornerRadius = kAVSellerAvatarRingSize / 2.0;
    self.sellerAvatarRingView.layer.masksToBounds = YES;
    self.sellerAvatarRingView.layer.borderWidth = 1.0;
    [self.sellerAvatarRingView pp_setBorderColor:[AVSellerCardAccentColor() colorWithAlphaComponent:0.14]];
    [innerSeller addSubview:self.sellerAvatarRingView];

    self.sellerAvatarImageView = [[UIImageView alloc] initWithImage:PPSYSImage(@"person.crop.circle.fill")];
    self.sellerAvatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.sellerAvatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.sellerAvatarImageView.layer.cornerRadius = kAVSellerAvatarSize / 2.0;
    self.sellerAvatarImageView.layer.masksToBounds = YES;
    self.sellerAvatarImageView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.72];
    self.sellerAvatarImageView.tintColor = [AppSecondaryTextClr colorWithAlphaComponent:0.64];
    self.sellerAvatarImageView.layer.borderWidth = 2.0;
    [self.sellerAvatarImageView pp_setBorderColor:[AppForgroundColr colorWithAlphaComponent:0.96]];
    [self.sellerAvatarRingView addSubview:self.sellerAvatarImageView];

    self.sellerEyebrowLabel = [[UILabel alloc] init];
    self.sellerEyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.sellerEyebrowLabel.font = [GM boldFontWithSize:12];
    self.sellerEyebrowLabel.textColor = [AVSellerCardAccentColor() colorWithAlphaComponent:0.92];
    self.sellerEyebrowLabel.numberOfLines = 1;

    self.sellerNameLabel = [[UILabel alloc] init];
    self.sellerNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.sellerNameLabel.font = [GM boldFontWithSize:20];
    self.sellerNameLabel.textColor = AppPrimaryTextClr;
    self.sellerNameLabel.numberOfLines = 2;

    self.sellerSubtitleLabel = [[UILabel alloc] init];
    self.sellerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.sellerSubtitleLabel.font = [GM MidFontWithSize:13];
    self.sellerSubtitleLabel.textColor = [AppSecondaryTextClr colorWithAlphaComponent:0.72];
    self.sellerSubtitleLabel.numberOfLines = 2;

    UIStackView *sellerTextStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.sellerEyebrowLabel,
        self.sellerNameLabel,
        self.sellerSubtitleLabel
    ]];
    sellerTextStack.translatesAutoresizingMaskIntoConstraints = NO;
    sellerTextStack.axis = UILayoutConstraintAxisVertical;
    sellerTextStack.spacing = 3.0;
    sellerTextStack.alignment = UIStackViewAlignmentFill;
    [sellerTextStack setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [innerSeller addSubview:sellerTextStack];

    self.sellerStatusBadgeLabel = [[UILabel alloc] init];
    self.sellerStatusBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.sellerStatusBadgeLabel.font = [GM boldFontWithSize:12];
    self.sellerStatusBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.sellerStatusBadgeLabel.numberOfLines = 1;
    self.sellerStatusBadgeLabel.adjustsFontSizeToFitWidth = YES;
    self.sellerStatusBadgeLabel.minimumScaleFactor = 0.78;
    self.sellerStatusBadgeLabel.layer.cornerRadius = kAVSellerStatusPillHeight / 2.0;
    self.sellerStatusBadgeLabel.layer.masksToBounds = YES;
    [self.sellerStatusBadgeLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.sellerStatusBadgeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [innerSeller addSubview:self.sellerStatusBadgeLabel];

    self.profileActionButton = [self pp_primaryCTAWithTitle:kLang(@"View_Profile")
                                                 systemName:@"person.crop.circle.fill"
                                                   selector:@selector(viewProfileTapped:)
                                                 emphasized:YES];
    [innerSeller addSubview:self.profileActionButton];

    self.callActionButton  = [self pp_secondaryActionWithTitle:kLang(@"Call")
                                                    systemName:@"phone.fill"
                                                      selector:@selector(callOwnerBtn:)];
    self.shareActionButton = [self pp_secondaryActionWithTitle:kLang(@"Share")
                                                    systemName:@"square.and.arrow.up"
                                                      selector:@selector(handleShareAction)];
    self.supportActionButton = [self pp_secondaryActionWithTitle:kLang(@"Support")
                                                      systemName:@"headphones"
                                                        selector:@selector(supportTapped)];
    self.supportActionButton.hidden = YES;

    self.chatActionButton = [self pp_secondaryActionWithTitle:kLang(@"Chat")
                                                   systemName:@"message.fill"
                                                     selector:@selector(chatBTN:)];

    self.actionStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.callActionButton,
        self.shareActionButton,
        self.chatActionButton
    ]];
    self.actionStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionStackView.axis         = UILayoutConstraintAxisHorizontal;
    self.actionStackView.spacing      = kAVSpace8;
    self.actionStackView.distribution = UIStackViewDistributionFillEqually;
    self.actionStackView.alignment    = UIStackViewAlignmentCenter;
    [innerSeller addSubview:self.actionStackView];

    NSLayoutConstraint *profileTopPreferred = [self.profileActionButton.topAnchor constraintEqualToAnchor:self.sellerAvatarRingView.bottomAnchor constant:kAVSpace16];
    profileTopPreferred.priority = UILayoutPriorityDefaultHigh;
    self.sellerActionsTopToChatConstraint = [self.actionStackView.topAnchor constraintEqualToAnchor:self.profileActionButton.bottomAnchor constant:kAVSpace12];

    [NSLayoutConstraint activateConstraints:@[
        [self.sellerSectionView.topAnchor      constraintEqualToAnchor:self.detailsCardView.bottomAnchor constant:kAVCardPadding],
        [self.sellerSectionView.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor  constant:kAVCardPadding],
        [self.sellerSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kAVCardPadding],

        [self.sellerAccentGlowView.topAnchor constraintEqualToAnchor:innerSeller.topAnchor constant:-54.0],
        [self.sellerAccentGlowView.trailingAnchor constraintEqualToAnchor:innerSeller.trailingAnchor constant:42.0],
        [self.sellerAccentGlowView.widthAnchor constraintEqualToConstant:168.0],
        [self.sellerAccentGlowView.heightAnchor constraintEqualToConstant:168.0],

        [self.sellerAvatarRingView.leadingAnchor constraintEqualToAnchor:innerSeller.leadingAnchor constant:kAVCardPadding],
        [self.sellerAvatarRingView.topAnchor constraintEqualToAnchor:innerSeller.topAnchor constant:kAVCardPadding],
        [self.sellerAvatarRingView.widthAnchor constraintEqualToConstant:kAVSellerAvatarRingSize],
        [self.sellerAvatarRingView.heightAnchor constraintEqualToConstant:kAVSellerAvatarRingSize],

        [self.sellerAvatarImageView.centerXAnchor constraintEqualToAnchor:self.sellerAvatarRingView.centerXAnchor],
        [self.sellerAvatarImageView.centerYAnchor constraintEqualToAnchor:self.sellerAvatarRingView.centerYAnchor],
        [self.sellerAvatarImageView.widthAnchor constraintEqualToConstant:kAVSellerAvatarSize],
        [self.sellerAvatarImageView.heightAnchor constraintEqualToConstant:kAVSellerAvatarSize],

        [sellerTextStack.topAnchor constraintEqualToAnchor:self.sellerAvatarRingView.topAnchor constant:kAVSpace4],
        [sellerTextStack.leadingAnchor constraintEqualToAnchor:self.sellerAvatarRingView.trailingAnchor constant:kAVSpace16],
        [sellerTextStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.sellerStatusBadgeLabel.leadingAnchor constant:-kAVSpace8],

        [self.sellerStatusBadgeLabel.topAnchor constraintEqualToAnchor:self.sellerAvatarRingView.topAnchor constant:kAVSpace4],
        [self.sellerStatusBadgeLabel.trailingAnchor constraintEqualToAnchor:innerSeller.trailingAnchor constant:-kAVCardPadding],
        [self.sellerStatusBadgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:92.0],
        [self.sellerStatusBadgeLabel.heightAnchor constraintEqualToConstant:kAVSellerStatusPillHeight],

        profileTopPreferred,
        [self.profileActionButton.topAnchor constraintGreaterThanOrEqualToAnchor:sellerTextStack.bottomAnchor constant:kAVSpace16],
        [self.profileActionButton.leadingAnchor constraintEqualToAnchor:innerSeller.leadingAnchor constant:kAVCardPadding],
        [self.profileActionButton.trailingAnchor constraintEqualToAnchor:innerSeller.trailingAnchor constant:-kAVCardPadding],
        [self.profileActionButton.heightAnchor constraintEqualToConstant:kAVSellerPrimaryBtnHeight],

        [self.actionStackView.topAnchor constraintGreaterThanOrEqualToAnchor:sellerTextStack.bottomAnchor constant:kAVSpace16],
        [self.actionStackView.leadingAnchor constraintEqualToAnchor:innerSeller.leadingAnchor constant:kAVCardPadding],
        [self.actionStackView.trailingAnchor constraintEqualToAnchor:innerSeller.trailingAnchor constant:-kAVCardPadding],
        [self.actionStackView.bottomAnchor constraintEqualToAnchor:innerSeller.bottomAnchor constant:-kAVCardPadding],
    ]];

    self.sellerActionsTopToChatConstraint.active = YES;
    [self.sellerAvatarRingView.bottomAnchor constraintLessThanOrEqualToAnchor:self.actionStackView.topAnchor constant:-kAVSpace16].active = YES;
}

/// "You may also like" horizontal collection
- (void)pp_buildSuggestionsSection {

    // ── Container wraps the entire suggestion section ──
    self.suggestionsContainerView = [[UIView alloc] init];
    self.suggestionsContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.suggestionsContainerView.hidden = YES;
    [self.contentView addSubview:self.suggestionsContainerView];

    // ── Section header ──
    self.mayLikeLabel = [[UILabel alloc] init];
    self.mayLikeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.mayLikeLabel.text = kLang(@"SimilarAaccess");
    self.mayLikeLabel.font = [GM boldFontWithSize:24];
    self.mayLikeLabel.textColor = AppPrimaryTextClr;
    [self.suggestionsContainerView addSubview:self.mayLikeLabel];

    self.suggestionsSubtitleLabel = [[UILabel alloc] init];
    self.suggestionsSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.suggestionsSubtitleLabel.font = [GM MidFontWithSize:14];
    self.suggestionsSubtitleLabel.textColor = [AppSecondaryTextClr colorWithAlphaComponent:0.82];
    self.suggestionsSubtitleLabel.numberOfLines = 2;
    self.suggestionsSubtitleLabel.text = kLang(@"accessory_view_suggestions_subtitle");
    [self.suggestionsContainerView addSubview:self.suggestionsSubtitleLabel];

    CGFloat textInset = kAVSectionInset;

    // ── Collection view ──
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection   = UICollectionViewScrollDirectionHorizontal;
    layout.itemSize          = [self pp_suggestionItemSize];
    layout.minimumLineSpacing = kAVSpace16;
    layout.sectionInset      = UIEdgeInsetsMake(0, kAVSectionInset, 0, kAVSectionInset);

    self.accessoryCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero
                                                      collectionViewLayout:layout];
    self.accessoryCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.accessoryCollectionView.delegate       = self;
    self.accessoryCollectionView.dataSource     = self;
    self.accessoryCollectionView.backgroundColor = UIColor.clearColor;
    self.accessoryCollectionView.showsHorizontalScrollIndicator = NO;
    self.accessoryCollectionView.decelerationRate = UIScrollViewDecelerationRateFast;
    self.accessoryCollectionView.clipsToBounds    = NO;
    [self.accessoryCollectionView registerClass:[PPUniversalCell class]
                     forCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier];
    [self.suggestionsContainerView addSubview:self.accessoryCollectionView];

    // ── Empty-state label ──
    self.emptySuggestionsLabel = [[UILabel alloc] init];
    self.emptySuggestionsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptySuggestionsLabel.font          = [GM MidFontWithSize:14];
    self.emptySuggestionsLabel.textColor     = [AppSecondaryTextClr colorWithAlphaComponent:0.88];
    self.emptySuggestionsLabel.textAlignment = NSTextAlignmentNatural;
    self.emptySuggestionsLabel.numberOfLines = 0;
    self.emptySuggestionsLabel.text          = kLang(@"accessory_view_empty_suggestions");
    self.accessoryCollectionView.backgroundView = self.emptySuggestionsLabel;

    // ── Collection height ──
    self.accessoryCollectionHeightConstraint = [self.accessoryCollectionView.heightAnchor
                                                constraintEqualToConstant:[self pp_suggestionItemSize].height + 12.0];

    // ── Container internal layout ──
    [NSLayoutConstraint activateConstraints:@[
        [self.mayLikeLabel.topAnchor      constraintEqualToAnchor:self.suggestionsContainerView.topAnchor],
        [self.mayLikeLabel.leadingAnchor  constraintEqualToAnchor:self.suggestionsContainerView.leadingAnchor  constant:textInset],
        [self.mayLikeLabel.trailingAnchor constraintEqualToAnchor:self.suggestionsContainerView.trailingAnchor constant:-textInset],

        [self.suggestionsSubtitleLabel.topAnchor      constraintEqualToAnchor:self.mayLikeLabel.bottomAnchor          constant:kAVSpace8],
        [self.suggestionsSubtitleLabel.leadingAnchor  constraintEqualToAnchor:self.suggestionsContainerView.leadingAnchor  constant:textInset],
        [self.suggestionsSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.suggestionsContainerView.trailingAnchor constant:-textInset],

        [self.accessoryCollectionView.topAnchor      constraintEqualToAnchor:self.suggestionsSubtitleLabel.bottomAnchor constant:kAVSpace16],
        [self.accessoryCollectionView.leadingAnchor  constraintEqualToAnchor:self.suggestionsContainerView.leadingAnchor],
        [self.accessoryCollectionView.trailingAnchor constraintEqualToAnchor:self.suggestionsContainerView.trailingAnchor],
        self.accessoryCollectionHeightConstraint,
        [self.accessoryCollectionView.bottomAnchor   constraintEqualToAnchor:self.suggestionsContainerView.bottomAnchor],
    ]];

    // ── Container → contentView layout ──
    self.contentBottomToSuggestionsConstraint =
        [self.suggestionsContainerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-kAVSuggestionBottomInset];
    self.contentBottomToSellerConstraint =
        [self.descView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-kAVSuggestionBottomInset];

    // Start with description bottom (suggestions hidden by default)
    self.contentBottomToSellerConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [self.suggestionsContainerView.topAnchor      constraintEqualToAnchor:self.descView.bottomAnchor constant:kAVSpace32],
        [self.suggestionsContainerView.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.suggestionsContainerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    ]];
}

/// Async fetch for suggested accessories
- (void)pp_fetchSuggestions {
    __weak typeof(self) weakSelf = self;

    void (^showCategorySuggestions)(void) = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.mayLikeLabel.text = kLang(@"SimilarAaccess");
        [PetAccessoryManager fetchSuggestedAccessoriesForAccess:strongSelf.accessAds
                                                    completion:^(NSArray<PetAccessory *> *accessories) {
            __strong typeof(weakSelf) s = weakSelf;
            if (!s) return;
            s.suggestedAccessories = accessories ?: @[];
            [s refreshSuggestedAccessoriesUI];
            [s.accessoryCollectionView reloadData];
        }];
    };

    if ([self pp_isProviderMarketplaceItem]) {
        [PetAccessoryManager fetchProviderMarketplaceAccessoriesForOwnerID:self.accessAds.ownerID
                                                        excludingAccessory:self.accessAds
                                                               completion:^(NSArray<PetAccessory *> *results) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (results.count >= 2) {
                strongSelf.suggestedAccessories = results;
                strongSelf.mayLikeLabel.text = kLang(@"accessory_view_more_from_provider");
                [strongSelf refreshSuggestedAccessoriesUI];
                [strongSelf.accessoryCollectionView reloadData];
            } else {
                showCategorySuggestions();
            }
        }];
    } else {
        showCategorySuggestions();
    }
}

- (UIView *)pp_surfaceCard {
    UIView *wrapper = [[UIView alloc] init];
    wrapper.translatesAutoresizingMaskIntoConstraints = NO;
    wrapper.backgroundColor = UIColor.clearColor;

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = AppForgroundColr;
    card.layer.cornerRadius = kAVCardCornerRadius;
    card.layer.masksToBounds = YES;
    card.layer.borderWidth = kAVSectionBorderWidth;
    [card pp_setBorderColor:[AppPrimaryTextClr colorWithAlphaComponent:0.06]];
    if (@available(iOS 13.0, *)) {
        card.layer.cornerCurve = kCACornerCurveContinuous;
    }
    card.tag = 100;

    [wrapper addSubview:card];
    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor      constraintEqualToAnchor:wrapper.topAnchor],
        [card.leadingAnchor  constraintEqualToAnchor:wrapper.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor],
        [card.bottomAnchor   constraintEqualToAnchor:wrapper.bottomAnchor],
    ]];
    return wrapper;
}

- (UIView *)pp_surfaceCardClean {
    UIView *wrapper = [[UIView alloc] init];
    wrapper.translatesAutoresizingMaskIntoConstraints = NO;
    wrapper.backgroundColor = UIColor.clearColor;

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = AppBackgroundClr;
    card.layer.cornerRadius = 26;
    card.layer.masksToBounds = YES;
    card.layer.borderWidth = kAVSectionBorderWidth;
    [card pp_setBorderColor:[AppPrimaryTextClr colorWithAlphaComponent:0.00]];
    if (@available(iOS 13.0, *)) {
        card.layer.cornerCurve = kCACornerCurveContinuous;
    }
    card.tag = 100;

    [wrapper addSubview:card];
    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor      constraintEqualToAnchor:wrapper.topAnchor],
        [card.leadingAnchor  constraintEqualToAnchor:wrapper.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor],
        [card.bottomAnchor   constraintEqualToAnchor:wrapper.bottomAnchor],
    ]];
    return wrapper;
}


- (UIView *)pp_surfacepage {
    UIView *wrapper = [[UIView alloc] init];
    wrapper.translatesAutoresizingMaskIntoConstraints = NO;
    wrapper.backgroundColor = UIColor.clearColor;

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = AppPageColor();
    card.layer.cornerRadius = 26;
    card.layer.masksToBounds = YES;
    card.layer.borderWidth = kAVSectionBorderWidth;
    [card pp_setBorderColor:[AppPrimaryTextClr colorWithAlphaComponent:0.00]];
    if (@available(iOS 13.0, *)) {
        card.layer.cornerCurve = kCACornerCurveContinuous;
    }
    card.tag = 100;

    [wrapper addSubview:card];
    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor      constraintEqualToAnchor:wrapper.topAnchor],
        [card.leadingAnchor  constraintEqualToAnchor:wrapper.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor],
        [card.bottomAnchor   constraintEqualToAnchor:wrapper.bottomAnchor],
    ]];
    return wrapper;
}

/// Returns the inner card view (the clipped content container) from a surface card wrapper
- (UIView *)pp_innerCardOf:(UIView *)wrapper {
    UIView *inner = [wrapper viewWithTag:100];
    return inner ?: wrapper;
}

- (UILabel *)pp_badgeLabelWithFontSize:(CGFloat)fontSize {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM boldFontWithSize:fontSize];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 1;
    label.layer.cornerRadius = kAVBadgeCornerRadius; // pill
    label.layer.masksToBounds = YES;
    label.textColor = UIColor.whiteColor;
    // Height constraint drives the pill shape
    [label.heightAnchor constraintGreaterThanOrEqualToConstant:28.0].active = YES;
    return label;
}

- (void)pp_addSellerPressMotionToButton:(UIButton *)button
{
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.78;
    button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [button addTarget:self action:@selector(pp_sellerActionTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_sellerActionTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
}

- (void)pp_sellerActionTouchDown:(UIButton *)button
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        button.transform = CGAffineTransformMakeScale(0.975, 0.975);
        button.alpha = 0.92;
    } completion:nil];
}

- (void)pp_sellerActionTouchUp:(UIButton *)button
{
    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.10 : 0.18;
    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:UIAccessibilityIsReduceMotionEnabled() ? 1.0 : 0.78
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        button.transform = CGAffineTransformIdentity;
        button.alpha = button.enabled ? 1.0 : 0.55;
    } completion:nil];
}

- (UIButton *)pp_actionButtonWithTitle:(NSString *)title
                            systemName:(NSString *)systemName
                              selector:(SEL)selector
                            emphasized:(BOOL)emphasized {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    button.layer.cornerRadius = kAVButtonCornerRadius;
    button.layer.masksToBounds = YES;

    UIImage *icon = [UIImage pp_symbolNamed:systemName
                                  pointSize:16
                                     weight:UIImageSymbolWeightSemibold
                                      scale:UIImageSymbolScaleMedium
                                    palette:emphasized ? @[AppForgroundColr, AppForgroundColr] : @[AppPrimaryTextClr, AppPrimaryTextClr]
                               makeTemplate:NO];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        config.background.cornerRadius = kAVButtonCornerRadius;
        config.image = icon;
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.imagePadding = 6.0;
        config.contentInsets = NSDirectionalEdgeInsetsMake(12.0, 16.0, 12.0, 16.0);
        config.title = title;
        config.baseForegroundColor = emphasized ? AppForgroundColr : AppPrimaryTextClr;
        config.baseBackgroundColor = emphasized ? AVSellerCardInkColor() : [AVSellerCardSurfaceColor() colorWithAlphaComponent:PPIOS26() ? 0.55 : 0.92];
        config.background.strokeColor = [AppPrimaryTextClr colorWithAlphaComponent:emphasized ? 0.0 : 0.08];
        config.background.strokeWidth = emphasized ? 0.0 : 1.0;
        config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
            NSMutableDictionary *attrs = [incoming mutableCopy];
            attrs[NSFontAttributeName] = [GM boldFontWithSize:13];
            return attrs;
        };
        button.configuration = config;
    } else {
        button.backgroundColor = emphasized ? AVSellerCardInkColor() : [AVSellerCardSurfaceColor() colorWithAlphaComponent:0.9];
        button.layer.borderWidth = emphasized ? 0.0 : 1.0;
        [button pp_setBorderColor:[AppPrimaryTextClr colorWithAlphaComponent:0.08]];
        [button setTitleColor:emphasized ? AppForgroundColr : AppPrimaryTextClr forState:UIControlStateNormal];
        [button setTitle:title forState:UIControlStateNormal];
        [button setImage:icon forState:UIControlStateNormal];
        button.tintColor = emphasized ? AppForgroundColr : AppPrimaryTextClr;
        button.titleLabel.font = [GM boldFontWithSize:13];
        button.contentEdgeInsets = UIEdgeInsetsMake(12.0, 16.0, 12.0, 16.0);
    }

    [self pp_addSellerPressMotionToButton:button];
    return button;
}

/// Premium primary CTA — full-width filled pill, single dominant action
- (UIButton *)pp_primaryCTAWithTitle:(NSString *)title
                          systemName:(NSString *)systemName
                            selector:(SEL)selector
                          emphasized:(BOOL)emphasized {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    button.layer.cornerRadius = kAVSellerPrimaryBtnHeight / 2.0;
    button.layer.masksToBounds = YES;

    UIImage *icon = [UIImage pp_symbolNamed:systemName
                                  pointSize:17
                                     weight:UIImageSymbolWeightSemibold
                                      scale:UIImageSymbolScaleMedium
                                    palette:emphasized ? @[UIColor.whiteColor, UIColor.whiteColor] : @[AppPrimaryTextClr, AppPrimaryTextClr]
                               makeTemplate:NO];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.image = icon;
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.imagePadding = 10.0;
        config.contentInsets = NSDirectionalEdgeInsetsMake(14.0, 24.0, 14.0, 24.0);
        config.title = title;
        config.baseForegroundColor = emphasized ? UIColor.whiteColor : AppPrimaryTextClr;
        config.baseBackgroundColor = emphasized ? AppPrimaryClr : [AVSellerCardSurfaceColor() colorWithAlphaComponent:0.64];
        config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
            NSMutableDictionary *attrs = [incoming mutableCopy];
            attrs[NSFontAttributeName] = [GM boldFontWithSize:15];
            return attrs;
        };
        button.configuration = config;
    } else {
        button.backgroundColor = emphasized ? AppPrimaryClr : [AVSellerCardSurfaceColor() colorWithAlphaComponent:0.9];
        [button setTitleColor:emphasized ? UIColor.whiteColor : AppPrimaryTextClr forState:UIControlStateNormal];
        [button setTitle:title forState:UIControlStateNormal];
        [button setImage:icon forState:UIControlStateNormal];
        button.tintColor = emphasized ? UIColor.whiteColor : AppPrimaryTextClr;
        button.titleLabel.font = [GM boldFontWithSize:15];
        button.contentEdgeInsets = UIEdgeInsetsMake(14.0, 24.0, 14.0, 24.0);
    }
    [self pp_addSellerPressMotionToButton:button];
    return button;
}

/// Compact secondary action — icon+text pill, subdued
- (UIButton *)pp_secondaryActionWithTitle:(NSString *)title
                               systemName:(NSString *)systemName
                                 selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    button.layer.cornerRadius = kAVButtonCornerRadius;
    button.layer.masksToBounds = YES;

    UIImage *icon = [UIImage pp_symbolNamed:systemName
                                  pointSize:14
                                     weight:UIImageSymbolWeightMedium
                                      scale:UIImageSymbolScaleSmall
                                    palette:@[AppSecondaryTextClr, AppSecondaryTextClr]
                               makeTemplate:NO];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        config.background.cornerRadius = kAVButtonCornerRadius;
        config.image = icon;
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.imagePadding = 5.0;
        config.contentInsets = NSDirectionalEdgeInsetsMake(10.0, 10.0, 10.0, 10.0);
        config.title = title;
        config.baseForegroundColor = [AppSecondaryTextClr colorWithAlphaComponent:0.82];
        config.baseBackgroundColor = [AppPrimaryTextClr colorWithAlphaComponent:0.045];
        config.background.strokeColor = [AppPrimaryTextClr colorWithAlphaComponent:0.07];
        config.background.strokeWidth = 1.0;
        config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
            NSMutableDictionary *attrs = [incoming mutableCopy];
            attrs[NSFontAttributeName] = [GM MidFontWithSize:13];
            return attrs;
        };
        button.configuration = config;
    } else {
        button.backgroundColor = [AppPrimaryTextClr colorWithAlphaComponent:0.045];
        button.layer.borderWidth = 1.0;
        [button pp_setBorderColor:[AppPrimaryTextClr colorWithAlphaComponent:0.07]];
        [button setTitleColor:[AppSecondaryTextClr colorWithAlphaComponent:0.82] forState:UIControlStateNormal];
        [button setTitle:title forState:UIControlStateNormal];
        [button setImage:icon forState:UIControlStateNormal];
        button.tintColor = [AppSecondaryTextClr colorWithAlphaComponent:0.82];
        button.titleLabel.font = [GM MidFontWithSize:13];
        button.contentEdgeInsets = UIEdgeInsetsMake(8.0, 12.0, 8.0, 12.0);
    }
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44.0].active = YES;
    [self pp_addSellerPressMotionToButton:button];
    return button;
}

- (UIView *)pp_detailRowWithTitle:(NSString *)title
                       systemName:(NSString *)systemName
                        tintColor:(UIColor *)tintColor
                       valueLabel:(UILabel * __autoreleasing *)valueLabel {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = [tintColor colorWithAlphaComponent:0.08];
    row.layer.cornerRadius = kAVDetailRowCorner;
    row.layer.masksToBounds = YES;
    row.layer.borderWidth = 1.0;
    [row pp_setBorderColor:[tintColor colorWithAlphaComponent:0.12]];
    if (@available(iOS 13.0, *)) {
        row.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIView *iconShell = [[UIView alloc] init];
    iconShell.translatesAutoresizingMaskIntoConstraints = NO;
    iconShell.backgroundColor = [tintColor colorWithAlphaComponent:0.18];
    iconShell.layer.cornerRadius = 22.0;
    iconShell.layer.masksToBounds = YES;

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:systemName
                                                                              pointSize:15
                                                                                 weight:UIImageSymbolWeightSemibold
                                                                                  scale:UIImageSymbolScaleMedium
                                                                                palette:@[tintColor, tintColor]
                                                                           makeTemplate:NO]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM MidFontWithSize:11];
    titleLabel.textColor = [AppSecondaryTextClr colorWithAlphaComponent:0.82];
    titleLabel.text = title;

    UILabel *value = [[UILabel alloc] init];
    value.translatesAutoresizingMaskIntoConstraints = NO;
    value.font = [GM boldFontWithSize:15];
    value.textColor = AppPrimaryTextClr;
    value.numberOfLines = 2;
    value.textAlignment = NSTextAlignmentNatural;
    value.adjustsFontSizeToFitWidth = YES;
    value.minimumScaleFactor = 0.8;

    [row addSubview:iconShell];
    [iconShell addSubview:iconView];
    [row addSubview:titleLabel];
    [row addSubview:value];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:kAVDetailRowMinHeight],

        [iconShell.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12.0],
        [iconShell.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [iconShell.widthAnchor constraintEqualToConstant:44.0],
        [iconShell.heightAnchor constraintEqualToConstant:44.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconShell.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconShell.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:16.0],
        [iconView.heightAnchor constraintEqualToConstant:16.0],

        [titleLabel.topAnchor constraintEqualToAnchor:row.topAnchor constant:12.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconShell.trailingAnchor constant:10.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-10.0],

        [value.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:3.0],
        [value.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [value.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-10.0],
        [value.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-12.0]
    ]];

    if (valueLabel != NULL) {
        *valueLabel = value;
    }

    return row;
}

- (CGFloat)pp_heroHeight {
    CGFloat width = UIScreen.mainScreen.bounds.size.width;
    return MIN(MAX(width * 1.06, 360.0), 500.0) + 30.0;
}

- (CGSize)pp_suggestionItemSize {
    CGFloat width = UIScreen.mainScreen.bounds.size.width;
    CGFloat itemWidth = width * 0.45;
    return CGSizeMake(floor(itemWidth), floor(itemWidth * 1.74));
}

- (NSString *)pp_categorySummary {
    MainKindsModel *mainModel = [MainKindsModel mainKindModelForID:self.accessAds.petMainCategoryID];
    if (mainModel.KindName.length > 0) {
        return mainModel.KindName;
    }
    return [PetAccessory typeTextForAccessory:self.accessAds];
}

- (NSString *)pp_navigationSubtitle {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *typeText = [PetAccessory typeTextForAccessory:self.accessAds];
    NSString *categoryText = [self pp_categorySummary];
    if (typeText.length > 0) {
        [parts addObject:typeText];
    }
    if (categoryText.length > 0) {
        [parts addObject:categoryText];
    }
    if (parts.count == 0) {
        return @"";
    }
    return [NSString stringWithFormat:@"(%@)", [parts componentsJoinedByString:@", "]];
}

- (NSString *)pp_priceText {
    NSNumber *amount = self.accessAds.finalPrice ?: self.accessAds.price;
    NSString *formatted = [GM formatPrice:amount currencyCode:kLang(@"Rials")];
    return formatted.length > 0 ? formatted : [NSString stringWithFormat:@"%@ %@", amount ?: @(0), kLang(@"Rials")];
}

- (NSString *)pp_summarySubtitleText {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *categoryText = [self pp_categorySummary];
    NSString *conditionText = [PetAccessory conditionTextForAccessory:self.accessAds];

    if (categoryText.length > 0) {
        [parts addObject:categoryText];
    }
    if (conditionText.length > 0) {
        [parts addObject:conditionText];
    }

    return [parts componentsJoinedByString:@" • "];
}

- (BOOL)pp_isUsedAccessory
{
    return self.accessAds.condition == AccessConditionsUsed;
}

- (BOOL)pp_hasRealAccessoryOwnerID
{
    NSString *ownerID = PPSafeString(self.accessAds.ownerID);
    return ownerID.length > 0 && ![ownerID isEqualToString:@"unknown"];
}

- (BOOL)pp_isOfficialSupportOwnerID
{
    return [PPSafeString(self.accessAds.ownerID) isEqualToString:PPAccessoryOfficialSupportUserID];
}

- (UserModel *)pp_officialSupportOwnerModel
{
    UserModel *user = [UserModel new];
    user.ID = PPAccessoryOfficialSupportUserID;
    user.UserName = kLang(@"accessory_view_store_name");
    return user;
}

- (BOOL)pp_isOwnAccessory
{
    NSString *ownerID = PPSafeString(self.accessAds.ownerID);
    NSString *currentUID = [UserManager sharedManager].currentUser.ID ?: PPCurrentFIRAuthUser.uid;
    return ownerID.length > 0 && currentUID.length > 0 && [ownerID isEqualToString:currentUID];
}

- (UserModel *)pp_resolvedOwnerModel
{
    if (self.ownerModel) return self.ownerModel;

    if ([self pp_isOfficialSupportOwnerID]) {
        self.ownerModel = [self pp_officialSupportOwnerModel];
        return self.ownerModel;
    }

    if (self.ownerLookupFailed) return nil;

    UserModel *currentUser = [UserManager sharedManager].currentUser;
    if (currentUser && [currentUser.ID isEqualToString:self.accessAds.ownerID]) {
        return currentUser;
    }

    return nil;
}

- (NSString *)pp_ownerDisplayName
{
    UserModel *owner = [self pp_resolvedOwnerModel];
    if (owner) {
        // Prioritize FirstName and LastName for a more accurate display name
        NSMutableArray<NSString *> *nameParts = [NSMutableArray array];
        if (owner.FirstName.length > 0) {
            [nameParts addObject:owner.FirstName];
        }
        if (owner.LastName.length > 0) {
            [nameParts addObject:owner.LastName];
        }

        if (nameParts.count > 0) {
            return [nameParts componentsJoinedByString:@" "];
        }

        // Fallback to bestDisplayName if available
        if ([owner respondsToSelector:@selector(bestDisplayName)]) {
            NSString *name = [owner bestDisplayName];
            if (name.length > 0) return name;
        }
        if ([owner respondsToSelector:@selector(PPBestDisplayName)]) {
            NSString *name = [owner PPBestDisplayName];
            if (name.length > 0) return name;
        }

        // Fallback to UserName
        if (owner.UserName.length > 0) return owner.UserName;
    }

    if ([self pp_isOfficialSupportOwnerID]) return kLang(@"accessory_view_store_name");
    return [self pp_hasRealAccessoryOwnerID] ? kLang(@"accessory_view_seller_title") : kLang(@"accessory_view_store_name");
}

- (BOOL)pp_isProviderMarketplaceItem
{
    if (self.accessAds.ownerID.length == 0) return NO;
    if ([[UserManager sharedManager].currentUser.ID isEqualToString:self.accessAds.ownerID]) return NO;
    if ([self pp_isUsedAccessory]) return NO;
    if ([self.accessAds.ownerType isEqualToString:@"partner"]) return YES;
    if ([self.accessAds.source isEqualToString:@"provider_marketplace"]) return YES;
    return self.accessAds.ownerID.length > 0 && ![self pp_isUsedAccessory];
}

- (BOOL)pp_shouldShowCartBar
{
    return ![self pp_isUsedAccessory];
}

- (NSString *)pp_sellerMetaText
{
    if ([self pp_isOfficialSupportOwnerID]) {
        NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithObject:kLang(@"accessory_view_store_badge")];
        NSString *conditionText = [PetAccessory conditionTextForAccessory:self.accessAds];
        if (conditionText.length > 0) {
            [parts addObject:conditionText];
        }
        return [parts componentsJoinedByString:@" • "];
    }
    if ([self pp_isProviderMarketplaceItem]) {
        return kLang(@"accessory_view_sold_by");
    }
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *sellerTitle = [self pp_isUsedAccessory] ? kLang(@"accessory_view_seller_title") : kLang(@"accessory_view_store_badge");
    NSString *conditionText = [PetAccessory conditionTextForAccessory:self.accessAds];
    if (sellerTitle.length > 0) {
        [parts addObject:sellerTitle];
    }
    if (conditionText.length > 0) {
        [parts addObject:conditionText];
    }
    return [parts componentsJoinedByString:@" • "];
}

- (NSString *)pp_sellerEyebrowText
{
    if ([self pp_isOfficialSupportOwnerID]) return kLang(@"accessory_view_store_badge");
    if ([self pp_isProviderMarketplaceItem]) {
        return kLang(@"accessory_view_sold_by");
    }
    if ([self pp_hasRealAccessoryOwnerID]) {
        return kLang(@"accessory_view_seller_contact");
    }
    return kLang(@"accessory_view_store_support");
}

- (NSString *)pp_sellerStatusBadgeText
{
    if ([self pp_isOfficialSupportOwnerID]) return kLang(@"accessory_view_store_badge");
    if ([self pp_isProviderMarketplaceItem]) return kLang(@"accessory_view_market_badge");
    if ([self pp_hasRealAccessoryOwnerID]) return kLang(@"accessory_view_private_seller");
    return [self pp_isUsedAccessory] ? kLang(@"accessory_view_private_seller") : kLang(@"accessory_view_store_badge");
}

- (void)pp_updateSellerStatusBadgeStyle
{
    UIColor *accent;
    if ([self pp_isProviderMarketplaceItem]) {
        accent = AVSellerCardAccentColor();
    } else if ([self pp_hasRealAccessoryOwnerID]) {
        accent = AVSellerCardAccentColor();
    } else {
        BOOL isUsedAccessory = [self pp_isUsedAccessory];
        accent = isUsedAccessory ? AVSellerCardAccentColor() : AVSellerCardGoldColor();
    }
    self.sellerStatusBadgeLabel.text = [self pp_sellerStatusBadgeText];
    self.sellerStatusBadgeLabel.textColor = accent;
    self.sellerStatusBadgeLabel.backgroundColor = [accent colorWithAlphaComponent:0.11];
    self.sellerStatusBadgeLabel.layer.borderWidth = 1.0;
    [self.sellerStatusBadgeLabel pp_setBorderColor:[accent colorWithAlphaComponent:0.16]];
}

- (void)pp_updateSellerAvatar
{
    if ([self pp_isOfficialSupportOwnerID]) {
        self.sellerAvatarImageView.image = [UIImage imageNamed:@"PPLogo"];
        self.sellerAvatarImageView.contentMode = UIViewContentModeScaleAspectFill;
        return;
    }

    UserModel *owner = [self pp_resolvedOwnerModel];

    if ([self pp_hasRealAccessoryOwnerID]) {
        UIImage *placeholder = owner
            ? [PPModernAvatarRenderer avatarImageForName:owner.UserName size:kAVSellerAvatarSize]
            : PPSYSImage(@"person.crop.circle.fill");
        self.sellerAvatarImageView.image = placeholder;
        self.sellerAvatarImageView.contentMode = UIViewContentModeScaleAspectFill;

        NSString *imageURL = PPSafeString(owner.UserImageUrl.absoluteString);
        if (imageURL.length > 0) {
            [PPImageLoaderManager.shared setImageOnImageView:self.sellerAvatarImageView
                                                         url:imageURL
                                                 placeholder:placeholder
                                                  complation:^(UIImage * _Nonnull image, NSString * _Nullable urlString) {
            }];
        }
        return;
    }

    self.sellerAvatarImageView.image = [UIImage imageNamed:@"PPLogo"];
    self.sellerAvatarImageView.contentMode = UIViewContentModeScaleAspectFill;
}

- (void)pp_updateSellerActions
{
    BOOL hasRealOwner = [self pp_hasRealAccessoryOwnerID];
    BOOL isOwnItem = [self pp_isOwnAccessory];

    if (hasRealOwner) {
        UserModel *owner = [self pp_resolvedOwnerModel];
        BOOL hasPhone = owner && owner.MobileNo.length > 0;
        self.chatActionButton.hidden = NO;
        self.callActionButton.hidden = isOwnItem || !hasPhone;
        self.shareActionButton.hidden = NO;
        return;
    }

    self.chatActionButton.hidden = NO;
    self.callActionButton.hidden = YES;
    self.shareActionButton.hidden = NO;
}

- (void)pp_applySellerSemanticDirection
{
    UISemanticContentAttribute semantic = [Language semanticAttributeForCurrentLanguage];
    self.sellerSectionView.semanticContentAttribute = semantic;
    self.sellerAvatarRingView.semanticContentAttribute = semantic;
    self.actionStackView.semanticContentAttribute = semantic;

    NSArray<UIButton *> *buttons = @[
        self.chatActionButton,
        self.callActionButton,
        self.shareActionButton
    ];
    for (UIButton *button in buttons) {
        button.semanticContentAttribute = semantic;
        button.titleLabel.textAlignment = NSTextAlignmentCenter;
    }
}

- (void)pp_updateSellerAccessibility
{
    NSString *sellerName = self.sellerNameLabel.text.length > 0 ? self.sellerNameLabel.text : kLang(@"accessory_view_seller_title");
    self.sellerAvatarImageView.accessibilityLabel = sellerName;
    self.sellerStatusBadgeLabel.accessibilityLabel = self.sellerStatusBadgeLabel.text;
    self.chatActionButton.accessibilityLabel = [NSString stringWithFormat:@"%@ %@", kLang(@"Chat"), sellerName];
    self.callActionButton.accessibilityLabel = [NSString stringWithFormat:@"%@ %@", kLang(@"Call"), sellerName];
    self.shareActionButton.accessibilityLabel = kLang(@"Share");
}

- (void)pp_updateBottomBarVisibility
{
    BOOL shouldShowCartBar = [self pp_shouldShowCartBar];
    self.bottomBar.hidden = !shouldShowCartBar;
    self.bottomBar.userInteractionEnabled = shouldShowCartBar;
    self.barBackgroundImageView.hidden = !shouldShowCartBar;
    self.barBackgroundImageView.alpha = shouldShowCartBar ? 1.0 : 0.0;
    self.bottomBarHeightConstraint.constant = shouldShowCartBar ? (kAVBottomBarBase + self.view.safeAreaInsets.bottom) : 0.0;

    CGFloat bottomInset = shouldShowCartBar ? (kAVBottomBarBase + self.view.safeAreaInsets.bottom) : 0.0;
    self.scrollView.contentInset = UIEdgeInsetsMake(0.0, 0.0, bottomInset, 0.0);
    self.scrollView.verticalScrollIndicatorInsets = UIEdgeInsetsMake(0.0, 0.0, bottomInset, 0.0);

    if (!shouldShowCartBar) {
        self.bottomBar.alpha = 0.0;
        self.bottomBar.transform = CGAffineTransformIdentity;
    }
}

- (UIColor *)pp_stockAccentColor {
    if (self.accessAds.quantity <= 0) {
        return [UIColor systemRedColor];
    }
    if (self.accessAds.quantity <= 5) {
        return [UIColor colorWithRed:0.89 green:0.52 blue:0.10 alpha:1.0];
    }
    return AppPrimaryClr;
}

- (void)applyAccessoryContent {
    self.heroKindBadgeLabel.text = [NSString stringWithFormat:@"  %@  ", [PetAccessory typeTextForAccessory:self.accessAds]];
    self.heroStockBadgeLabel.text = [NSString stringWithFormat:@"  %@  ", [self.accessAds stockStatusText]];

    UIColor *stockBadgeColor = [self pp_stockAccentColor];
    self.heroStockBadgeLabel.backgroundColor = [stockBadgeColor colorWithAlphaComponent:0.96];

    [self.petsTitleView configureWithTitle:PPSafeString(self.accessAds.name)
                                   location:[self pp_summarySubtitleText]
                                      price:[self pp_priceText]];

    NSString *ownerName = [self pp_ownerDisplayName];
    self.sellerEyebrowLabel.text = [self pp_sellerEyebrowText];
    self.sellerNameLabel.text = ownerName.length > 0 ? ownerName : kLang(@"accessory_view_seller_pending");
    self.sellerSubtitleLabel.text = [self pp_sellerMetaText];
    self.categoryValueLabel.text = [self pp_categorySummary];
    self.typeValueLabel.text = [PetAccessory typeTextForAccessory:self.accessAds];
    self.conditionValueLabel.text = [PetAccessory conditionTextForAccessory:self.accessAds];
    self.stockValueLabel.text = [self.accessAds stockStatusText];
    self.stockValueLabel.textColor = stockBadgeColor;
    self.descView.accessory = self.accessAds;

    [self pp_updateSellerAvatar];
    [self pp_updateSellerStatusBadgeStyle];
    [self pp_updateSellerActions];
    [self pp_updateBottomBarVisibility];
    [self pp_applySellerSemanticDirection];
    [self pp_updateSellerAccessibility];

    self.sellerEyebrowLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.sellerNameLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.sellerSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.categoryValueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.typeValueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.conditionValueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.stockValueLabel.textAlignment = Language.alignmentForCurrentLanguage;

}

- (void)refreshSuggestedAccessoriesUI {
    BOOL hasSuggestions = self.suggestedAccessories.count > 0;

    self.suggestionsContainerView.hidden = !hasSuggestions;
    self.emptySuggestionsLabel.hidden = hasSuggestions;
    self.accessoryCollectionView.backgroundView.hidden = hasSuggestions;

    // Swap bottom constraint: suggestions visible → pin to container, else → pin to seller
    self.contentBottomToSuggestionsConstraint.active = hasSuggestions;
    self.contentBottomToSellerConstraint.active = !hasSuggestions;

    [self.view setNeedsLayout];
}

// In AccessViewerVC.m
- (void)handleShareAction {
    // Get the current accessory being viewed


    PetAccessory *currentAccessory = self.accessAds;

    // Share the accessory
    [PetAccessory sharePetAccessory:currentAccessory
                 fromViewController:self
                         sourceView:self.view];
    [self trackAccessoryInteraction:PPItemInteractionTypeShare];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
}


-(void)initForms {
    [self updateCartQuantityBadge];
}

-(void)updateCartQuantityBadge
{
    [self loadItemsCountInBadge];
    [self checkCartAndAnimateIfNeeded];
}

- (void)checkCartAndAnimateIfNeeded {
    if (![self pp_shouldShowCartBar]) {
        self.bottomBar.alpha = 0.0;
        self.bottomBar.transform = CGAffineTransformIdentity;
        return;
    }
    NSInteger cartCount = [CartManager sharedManager].cartItems.count;
    CGFloat targetAlpha = cartCount > 0 ? 1.0 : 0.96;
    CGAffineTransform targetTransform = cartCount > 0 ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.985, 0.985);
    [UIView animateWithDuration:0.20 animations:^{
        self.bottomBar.alpha = targetAlpha;
        self.bottomBar.transform = targetTransform;
    }];
}

- (void)shoppingCartClicked {
    NSLog(@"Custom button tapped");
    CartViewController *vc = [[CartViewController alloc] init];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:YES];
}

-(void)loadItemsCountInBadge
{
    [self.cartButton removeBadge];
    NSInteger totalQty = [[CartManager sharedManager] totalItemsCount];
    [self.cartButton addBadgeWithContent:[NSString stringWithFormat:@"%ld", (long)totalQty] contentFont:[GM MidFontWithSize:12] contentColor:UIColor.whiteColor badgeColor:GM.appPrimaryColor offset:CGPointMake(-10, 9) badgeRadius:totalQty == 0 ? 0 : 11];
}

- (void)updateCartAndReloadCollection {
    [self loadItemsCountInBadge];
    [self checkCartAndAnimateIfNeeded];
}



- (void)startShakingWithPause:(UIButton *)button {
    [self shakeButton:button];
}

- (void)shakeButton:(UIButton *)button {

    CABasicAnimation *shake = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    shake.fromValue = @(-0.05);  // small angle in radians
    shake.toValue = @(0.05);
    shake.duration = 0.50;
    shake.autoreverses = YES;
    shake.repeatCount = HUGE_VALF; // infinite
    [button.layer addAnimation:shake forKey:@"shake"];


}

- (void)addToCartButtonTapped:(NSInteger)quantity{
    // M-11: Offline pre-check — prevent Firestore writes when offline
    if (![PPNetworkRetryHelper isNetworkAvailable]) {
        [self.bottomBar performAddToCartFailureAnimation];
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"offline_action_title")
                            subtitle:kLang(@"offline_action_message")
                          completion:nil];
        return;
    }

    // H-01: Auth gate — prevent unauthenticated users from creating orphaned cart documents
    if (![self pp_ensureSignedInForAction]) {
        [self.bottomBar performAddToCartFailureAnimation];
        return;
    }

    NSInteger stockQty = MAX(self.accessAds.quantity, 0);
    NSInteger existingQty = [[CartManager sharedManager] quantityForAccessory:self.accessAds];
    NSInteger requestedQty = MAX(quantity, 1);
    NSInteger availableToAdd = MAX(0, stockQty - existingQty);

    if (stockQty <= 0 || availableToAdd <= 0) {
        [self.bottomBar performAddToCartFailureAnimation];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        UIAlertController *outOfStockAlert =
            [UIAlertController alertControllerWithTitle:kLang(@"Out of stock")
                                                message:nil
                                         preferredStyle:UIAlertControllerStyleAlert];
        [outOfStockAlert addAction:[UIAlertAction actionWithTitle:kLang(@"OK")
                                                            style:UIAlertActionStyleDefault
                                                          handler:nil]];
        [self presentViewController:outOfStockAlert animated:YES completion:nil];
        return;
    }

    NSInteger safeQty = MIN(requestedQty, availableToAdd);
    CartItem *item = [[CartItem alloc] initWithAccessory:self.accessAds quantity:safeQty];
    __weak typeof(self) weakSelf = self;
    [[CartManager sharedManager] addItem:item
                presentingViewController:self
                              completion:^(BOOL didAdd, BOOL didCancel) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || didCancel) { return; }
        if (!didAdd) {
            [self.bottomBar performAddToCartFailureAnimation];
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
            UIAlertController *outOfStockAlert =
                [UIAlertController alertControllerWithTitle:kLang(@"Out of stock")
                                                    message:nil
                                             preferredStyle:UIAlertControllerStyleAlert];
            [outOfStockAlert addAction:[UIAlertAction actionWithTitle:kLang(@"OK")
                                                                style:UIAlertActionStyleDefault
                                                              handler:nil]];
            [self presentViewController:outOfStockAlert animated:YES completion:nil];
            return;
        }

        NSString *message = safeQty < requestedQty
            ? [NSString stringWithFormat:@"%@ %ld %@",
               kLang(@"Only"),
               (long)availableToAdd,
               kLang(@"left in stock")]
            : kLang(@"ItemAddedToYourCart");

        [PPAnalytics logAddToCartItemID:self.accessAds.accessoryID
                                   name:self.accessAds.name
                               category:[NSString stringWithFormat:@"acc-%ld", (long)self.accessAds.petMainCategoryID]
                                  price:self.accessAds.finalPrice.doubleValue
                               quantity:safeQty];

        [self.bottomBar performAddToCartSuccessAnimation];
        [PPHUD showSuccess:kLang(@"AddedToCart") subtitle:message delay:1.25];
        [self.QtyDelegate updateCartAndReloadCollection];
        [self loadItemsCountInBadge];
        [self checkCartAndAnimateIfNeeded];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartQuantityChanged];
    }];
}

-(void)supportTapped
{
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [[ChManager sharedManager] openSupportChatFromController:self];
}

-(void)cartTapped
{
    CartViewController *vc = [[CartViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - 🧩 Data + Layout Setup




- (void)addStrokeToView:(UIView *)view
              withColor:(UIColor *)color
                  width:(CGFloat)width
           cornerRadius:(CGFloat)cornerRadius {

    CAShapeLayer *borderLayer = [CAShapeLayer layer];
    borderLayer.strokeColor = color.CGColor;
    borderLayer.fillColor = UIColor.clearColor.CGColor;
    borderLayer.lineWidth = width;

    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:view.bounds
                                                    cornerRadius:cornerRadius];
    borderLayer.path = path.CGPath;
    borderLayer.frame = view.bounds;
    borderLayer.name = @"PPStrokeLayer";

    // Remove old stroke if exists
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer.name isEqualToString:@"PPStrokeLayer"]) {
            [layer removeFromSuperlayer];
            break;
        }
    }

    [view.layer addSublayer:borderLayer];
}



- (IBAction)callOwnerBtn:(id)sender {
    if (![self pp_ensureSignedInForAction]) {
        return;
    }
    [self loadOwnerModelIfNeeded];
    if (!self.ownerModel) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"error")
                         subtitle:kLang(@"service_view_contact_loading")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }
    [self trackAccessoryInteraction:PPItemInteractionTypeCall];
    if (self.ownerModel.MobileNo.length == 0) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"No Number")
                         subtitle:kLang(@"This user has no phone number")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }
    [AppClasses callPhoneNumber:self.ownerModel.MobileNo fromViewController:self];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
}


-(void)dismiss
{
    [self.navigationController popViewControllerAnimated:YES];
}


-(void)designViews
{
    // Push navigation — no modal chrome needed
}



- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_setPremiumTabDockHidden:YES animated:animated];

    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:@"" showBack:YES];
    if (@available(iOS 26.0, *))
        [self ios26Bar];
    else
        [self ios15Bar];

    NSString *title = PPSafeString(self.accessAds.name);
    NSString *subTitle = [self pp_navigationSubtitle];

    // ── Modern blur title card (matches ViewerVC pattern) ──
    UIView *titleCard = [[UIView alloc] init];
    titleCard.translatesAutoresizingMaskIntoConstraints = NO;
    titleCard.layer.cornerRadius = 22;
    titleCard.layer.masksToBounds = NO;
    [titleCard pp_setShadowColor:UIColor.blackColor];
    titleCard.layer.shadowOpacity = 0.12;
    titleCard.layer.shadowRadius  = 22;
    titleCard.layer.shadowOffset  = CGSizeMake(0, 10);

    UIBlurEffect *blurEffect;
    if (@available(iOS 17.0, *)) {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    } else {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    }

    self.titleBlurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.titleBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleBlurView.layer.cornerRadius  = 16;
    self.titleBlurView.layer.masksToBounds = YES;

    UIView *tintOverlay = [[UIView alloc] init];
    tintOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    tintOverlay.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.25];
    [self.titleBlurView.contentView addSubview:tintOverlay];
    [titleCard addSubview:self.titleBlurView];

    UILabel *blurTitleLabel = [[UILabel alloc] init];
    blurTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    blurTitleLabel.text          = title;
    blurTitleLabel.font          = [GM boldFontWithSize:14];
    blurTitleLabel.textColor     = AppPrimaryTextClr;
    blurTitleLabel.textAlignment = NSTextAlignmentCenter;
    blurTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.titleBlurView.contentView addSubview:blurTitleLabel];

    UILabel *blurSubtitleLabel = [[UILabel alloc] init];
    blurSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    blurSubtitleLabel.text          = subTitle;
    blurSubtitleLabel.font          = [GM MidFontWithSize:11];
    blurSubtitleLabel.textColor     = [AppSecondaryTextClr colorWithAlphaComponent:0.8];
    blurSubtitleLabel.textAlignment = NSTextAlignmentCenter;
    blurSubtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.titleBlurView.contentView addSubview:blurSubtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        // Blur → titleCard
        [self.titleBlurView.topAnchor      constraintEqualToAnchor:titleCard.topAnchor],
        [self.titleBlurView.leadingAnchor  constraintEqualToAnchor:titleCard.leadingAnchor],
        [self.titleBlurView.trailingAnchor constraintEqualToAnchor:titleCard.trailingAnchor],
        [self.titleBlurView.bottomAnchor   constraintEqualToAnchor:titleCard.bottomAnchor],
        // Tint → blur contentView
        [tintOverlay.topAnchor      constraintEqualToAnchor:self.titleBlurView.contentView.topAnchor],
        [tintOverlay.leadingAnchor  constraintEqualToAnchor:self.titleBlurView.contentView.leadingAnchor],
        [tintOverlay.trailingAnchor constraintEqualToAnchor:self.titleBlurView.contentView.trailingAnchor],
        [tintOverlay.bottomAnchor   constraintEqualToAnchor:self.titleBlurView.contentView.bottomAnchor],
        // Labels inside blur
        [blurTitleLabel.topAnchor      constraintEqualToAnchor:self.titleBlurView.contentView.topAnchor      constant:8],
        [blurTitleLabel.leadingAnchor  constraintEqualToAnchor:self.titleBlurView.contentView.leadingAnchor  constant:16],
        [blurTitleLabel.trailingAnchor constraintEqualToAnchor:self.titleBlurView.contentView.trailingAnchor constant:-16],
        [blurSubtitleLabel.topAnchor      constraintEqualToAnchor:blurTitleLabel.bottomAnchor constant:2],
        [blurSubtitleLabel.leadingAnchor  constraintEqualToAnchor:blurTitleLabel.leadingAnchor],
        [blurSubtitleLabel.trailingAnchor constraintEqualToAnchor:blurTitleLabel.trailingAnchor],
        [blurSubtitleLabel.bottomAnchor   constraintEqualToAnchor:self.titleBlurView.contentView.bottomAnchor constant:-8],
        // Card size
        [titleCard.widthAnchor constraintLessThanOrEqualToConstant:220],
    ]];

    titleCard.backgroundColor = AppClearClr;
    [self pp_navBarSetTitleViewCentered:titleCard];

    if (PPCurrentUser && PPCurrentFIRAuthUser) {
        [PetAdManager isAdFavorited:self.accessAds.accessoryID
                            forUser:PPCurrentUser.ID
                         collection:@"favoritesAccessories"
                         completion:^(BOOL favorited) {
            self.isFavorite = favorited;
            self.favBarButtonItem.image = favorited ? [UIImage systemImageNamed:@"heart.fill"] : [UIImage systemImageNamed:@"heart"];
            self.favBarButtonItem.tintColor = favorited ? [AppPrimaryClr colorWithAlphaComponent:1.2] : UIColor.labelColor;


        }];
	}
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    BOOL exiting = self.isMovingFromParentViewController || self.isBeingDismissed || self.navigationController.isBeingDismissed;
    if (exiting) {
        [self pp_setPremiumTabDockHidden:NO animated:animated];
    }
}

- (void)pp_setPremiumTabDockHidden:(BOOL)hidden animated:(BOOL)animated
{
    if ([self.tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(id)self.tabBarController setPremiumTabDockViewHidden:hidden animation:animated];
    }
}


-(void)ios26Bar
{
    _favBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"heart"]  style:UIBarButtonItemStylePlain target:self action:@selector(toggleFavorite)];
    self.navigationItem.rightBarButtonItems = @[_favBarButtonItem];
    // Back button is provided natively by the navigation controller
}


- (void)toggleFavorite {
    if (![self pp_ensureSignedInForAction]) {
        return;
    }

    self.isFavorite = !self.isFavorite;

    if (self.isFavorite) {
        self.favBarButtonItem.image = [UIImage systemImageNamed:@"heart.fill"];
        self.favBarButtonItem.tintColor = [AppPrimaryClr colorWithAlphaComponent:1.3];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentSuccess];
        NSLog(@"✅ Added to favorites");
    } else {
        self.favBarButtonItem.image = [UIImage systemImageNamed:@"heart"];
        self.favBarButtonItem.tintColor = [AppPrimaryTextClr colorWithAlphaComponent:1.0];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
        NSLog(@"❌ Removed from favorites");
    }

    if(self.isFavorite)
        [PetAdManager addFavoriteAdWithID:self.accessAds.accessoryID collection:@"favoritesAccessories" forUserID:[UserManager sharedManager].currentUser.ID];
    else
        [PetAdManager removeFavoriteAdWithID:self.accessAds.accessoryID collection:@"favoritesAccessories" forUserID:[UserManager sharedManager].currentUser.ID];


}


-(void)ios15Bar
{
    // Back button is provided natively by the navigation controller
    [self pp_navBarSetRightIcon:@"heart" key:@"favButton" target:self action:@selector(toggleFavorite) tap:nil];
}

- (void)pp_updateSellerCardShadowPath
{
    if (CGRectIsEmpty(self.sellerSectionView.bounds)) {
        return;
    }
    self.sellerSectionView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.sellerSectionView.bounds
                                   cornerRadius:kAVCardCornerRadius].CGPath;
}

- (void)pp_updateSellerBackgroundAppearance
{
    if (!self.sellerInnerSurfaceView) {
        return;
    }

    self.sellerInnerSurfaceView.backgroundColor = AVSellerCardSurfaceColor();
    [self.sellerInnerSurfaceView pp_setBorderColor:[AppPrimaryTextClr colorWithAlphaComponent:0.055]];
    if (self.sellerAccentGlowView) {
        BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        self.sellerAccentGlowView.layer.cornerRadius = CGRectGetWidth(self.sellerAccentGlowView.bounds) / 2.0;
        self.sellerAccentGlowView.backgroundColor = [AVSellerCardAccentColor() colorWithAlphaComponent:dark ? 0.16 : 0.105];
    }
}

- (void)pp_animateSellerCardEntranceIfNeeded
{
    if (self.didAnimateSellerSection || !self.sellerSectionView || !self.view.window) {
        return;
    }
    self.didAnimateSellerSection = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.sellerSectionView.alpha = 1.0;
        self.sellerSectionView.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.42
                          delay:0.04
         usingSpringWithDamping:0.84
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.sellerSectionView.alpha = 1.0;
        self.sellerSectionView.transform = CGAffineTransformIdentity;
    } completion:nil];
}


- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self pp_updateBottomBarVisibility];
    self.heroHeightConstraint.constant = [self pp_heroHeight];
    self.heroGradientLayer.frame = self.heroContainerView.bounds;
    [self pp_updateSellerCardShadowPath];
    [self pp_updateSellerBackgroundAppearance];
    [self pp_animateSellerCardEntranceIfNeeded];

    // Position ambient glows off-screen like ViewerVC
    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    CGFloat bottomY = MAX(100.0, CGRectGetHeight(self.contentView.bounds) - 336.0 + 110.0);
    self.ambientGlowTopView.frame = CGRectMake(-132.0, -92.0, 280.0, 280.0);
    self.ambientGlowBottomView.frame = CGRectMake(width - 336.0 + 138.0, bottomY, 336.0, 336.0);

    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.accessoryCollectionView.collectionViewLayout;
    layout.itemSize = [self pp_suggestionItemSize];
    self.accessoryCollectionHeightConstraint.constant = [self pp_suggestionItemSize].height + 12.0;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    BOOL dark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    UIColor *accent = AVSellerCardAccentColor();
    UIColor *gold = [UIColor colorWithRed:0.77 green:0.60 blue:0.21 alpha:1.0];
    self.ambientGlowTopView.backgroundColor = [accent colorWithAlphaComponent:dark ? 0.10 : 0.075];
    self.ambientGlowBottomView.backgroundColor = [gold colorWithAlphaComponent:dark ? 0.10 : 0.085];
    [self pp_updateSellerBackgroundAppearance];
}

- (IBAction)shareAdBTN:(id)sender {
    [self handleShareAction];
}

- (IBAction)dissmissMe:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)chatBTN:(id)sender {
    if (![self pp_ensureSignedInForAction]) {
        return;
    }
    [self loadOwnerModelIfNeeded];
    if (!self.ownerModel) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"error")
                         subtitle:kLang(@"service_view_contact_loading")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }
    [self startChatWith:self.ownerModel];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
}

- (IBAction)viewProfileTapped:(id)sender {
    if (![self pp_ensureSignedInForAction]) {
        return;
    }
    [self loadOwnerModelIfNeeded];
    if (!self.ownerModel) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"error")
                         subtitle:kLang(@"service_view_contact_loading")];
        return;
    }
    
    // Create and show seller profile VC
    SellerProfileVC *profileVC = [[SellerProfileVC alloc] init];
    profileVC.seller = self.ownerModel;
    profileVC.sellerItems = [self pp_initialSellerProfileItems];
    profileVC.delegate = self;
    profileVC.parentVC = self;
    [self.navigationController pushViewController:profileVC animated:YES];
}

- (NSArray<PetAccessory *> *)pp_initialSellerProfileItems
{
    NSString *ownerID = PPSafeString(self.accessAds.ownerID);
    if (ownerID.length == 0) return @[];

    NSMutableArray<PetAccessory *> *items = [NSMutableArray array];
    NSMutableSet<NSString *> *seenIDs = [NSMutableSet set];

    void (^appendItem)(PetAccessory *) = ^(PetAccessory *item) {
        if (![item isKindOfClass:PetAccessory.class]) return;
        if (item.isBlocked || item.isDeleted || item.isDisabled) return;
        if (item.ownerID.length > 0 && ![item.ownerID isEqualToString:ownerID]) return;
        NSString *itemID = PPSafeString(item.accessoryID);
        if (itemID.length > 0 && [seenIDs containsObject:itemID]) return;
        if (itemID.length > 0) [seenIDs addObject:itemID];
        [items addObject:item];
    };

    appendItem(self.accessAds);
    for (PetAccessory *item in self.suggestedAccessories) {
        appendItem(item);
    }
    return items.copy;
}

- (UIViewController *)pp_visibleSellerProfilePresenter
{
    return self.navigationController.topViewController ?: self;
}

- (void)sellerProfileDidTapContact:(UserModel *)seller
{
    if (!seller) return;
    [GM chatWith:seller FromController:[self pp_visibleSellerProfilePresenter]];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
}

- (void)sellerProfileDidTapCall:(UserModel *)seller
{
    if (!seller) return;
    [self trackAccessoryInteraction:PPItemInteractionTypeCall];
    if (seller.MobileNo.length == 0) {
        [PPAlertHelper showInfoIn:[self pp_visibleSellerProfilePresenter]
                            title:kLang(@"No Number")
                         subtitle:kLang(@"This user has no phone number")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }
    [AppClasses callPhoneNumber:seller.MobileNo fromViewController:[self pp_visibleSellerProfilePresenter]];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
}

- (void)sellerProfileDidSelectItem:(id)item
{
    if (![item isKindOfClass:PetAccessory.class]) return;
    PetAccessory *accessory = (PetAccessory *)item;
    if ([PPSafeString(accessory.accessoryID) isEqualToString:PPSafeString(self.accessAds.accessoryID)]) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }

    AccessViewerVC *viewer = [[AccessViewerVC alloc] init];
    viewer.accessAds = accessory;
    viewer.QtyDelegate = self.QtyDelegate;
    viewer.ParentVC = self;
    [self.navigationController pushViewController:viewer animated:YES];
}

// MARK: - startChatWith SelectUser
- (void)startChatWith:(UserModel *)user {
    [self trackAccessoryInteraction:PPItemInteractionTypeChat];
    [GM chatWith:user FromController:self];
}


- (void)showMessagesControllerWithChat:(ChatThreadModel *)chat
{
    [GM showMessagingWithChat:chat FromController: self];
}

// seg Delegate
#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.suggestedAccessories.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPUniversalCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier forIndexPath:indexPath];
    if (indexPath.item >= (NSInteger)self.suggestedAccessories.count) return cell;

    PetAccessory *accessory = self.suggestedAccessories[indexPath.item];
    PPCellContext context = accessory.accessKindType == AccessTypeFood ? PPCellForFood : PPCellForMarket;
    PPUniversalCellViewModel *vm = [[PPUniversalCellViewModel alloc] initWithModel:accessory context:context];
    cell.showsSubtitle = YES;
    cell.hideTopBadge = NO;
    [cell applyViewModel:vm
                 context:context
              layoutMode:PPCellLayoutModeSquare
            discountMode:PPDiscountStyleBadge
             imageLoader:^(UIImageView *imageView,
                           NSString *url,
                           UIImage *placeholder,
                           UIView *card) {
        (void)card;
        UIImage *resolvedPlaceholder = placeholder ?: imageView.image ?: [UIImage imageNamed:@"placeholder"];
        [[PPImageLoaderManager shared] setImageOnImageView:imageView
                                                       url:url
                                               placeholder:resolvedPlaceholder
                                           transitionStyle:PPImageTransitionStyleNone
                                                complation:nil];
    }];
    return cell;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [self pp_suggestionItemSize];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.petsTitleView animatePillsIn];
    [self pp_animateSellerCardEntranceIfNeeded];
    if (!self.didTrackViewInteraction) {
        self.didTrackViewInteraction = YES;
        [self trackAccessoryInteraction:PPItemInteractionTypeView];
    }
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

- (void)trackAccessoryInteraction:(PPItemInteractionType)interaction {
    if (self.accessAds.accessoryID.length == 0) return;
    [PetAdManager trackInteraction:interaction
                         forItemID:self.accessAds.accessoryID
                        collection:@"petAccessories"
                            userID:[self trackingUserID]
                        completion:nil];
}

- (BOOL)pp_ensureSignedInForAction
{
    if (UserManager.sharedManager.isUserLoggedIn) {
        return YES;
    }
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
    [UserManager showPromptOnTopController];
    return NO;
}

- (void)loadOwnerModelIfNeeded
{
    if (self.ownerModel || self.isResolvingOwner || self.ownerLookupFailed || ![self pp_hasRealAccessoryOwnerID]) {
        return;
    }

    if ([self pp_isOfficialSupportOwnerID]) {
        self.ownerModel = [self pp_officialSupportOwnerModel];
        [self applyAccessoryContent];
        return;
    }

    self.isResolvingOwner = YES;
    __weak typeof(self) weakSelf = self;
    [UsrMgr getOtherUserModelFromFirestoreWithUID:self.accessAds.ownerID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        strongSelf.isResolvingOwner = NO;
        if (error || !user) {
            strongSelf.ownerLookupFailed = YES;
            [strongSelf applyAccessoryContent];
            return;
        }

        strongSelf.ownerModel = user;
        [strongSelf applyAccessoryContent];
    }];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section
{
    return 0.00001;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0.00001;
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section
{
    return 0.00001;
}
-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 0.00001;
}

@end











static const NSInteger kPPAccessoryDescCollapsedLines = 8;

@interface PPAccessoryDescriptionView ()
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIButton *moreButton;
@property (nonatomic, strong) NSLayoutConstraint *textViewHeightConstraint;
@property (nonatomic, copy) NSString *fullDescriptionText;
@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, assign) CGFloat lastMeasuredTextWidth;
@end

@implementation PPAccessoryDescriptionView

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupView];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self setupView];
    }
    return self;
}

#pragma mark - Setup

- (void)setupView {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;

    self.surfaceView = [[UIView alloc] init];
    self.surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceView.backgroundColor = AppBackgroundClrDarker;
    self.surfaceView.layer.cornerRadius = kAVCardCornerRadius;
    self.surfaceView.layer.masksToBounds = YES;
    self.surfaceView.layer.borderWidth = kAVSectionBorderWidth;
    [self.surfaceView pp_setBorderColor:[UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.1]];
    if (@available(iOS 13.0, *)) {
        self.surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:20];
    self.titleLabel.textColor = AppPrimaryTextClr;
    self.titleLabel.text = kLang(@"Description");

    UIView *divider = [[UIView alloc] init];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.backgroundColor = [AppPrimaryTextClr colorWithAlphaComponent:0.08];

    _textView = [[UITextView alloc] init];
    _textView.translatesAutoresizingMaskIntoConstraints = NO;
    _textView.scrollEnabled = NO;
    _textView.editable = NO;
    _textView.textContainerInset = UIEdgeInsetsZero;
    _textView.textContainer.lineFragmentPadding = 0.0;
    _textView.backgroundColor = UIColor.clearColor;
    _textView.font = [GM MidFontWithSize:15];
    _textView.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.78];
    _textView.textAlignment = NSTextAlignmentNatural;
    _textView.adjustsFontForContentSizeCategory = YES;
    _textView.clipsToBounds = YES;
    _textView.textContainer.maximumNumberOfLines = 0;
    _textView.textContainer.lineBreakMode = NSLineBreakByWordWrapping;

    _moreButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _moreButton.translatesAutoresizingMaskIntoConstraints = NO;
    _moreButton.titleLabel.font = [GM boldFontWithSize:14];
    [_moreButton addTarget:self action:@selector(pp_toggleExpanded) forControlEvents:UIControlEventTouchUpInside];
    [_moreButton addTarget:self action:@selector(pp_moreButtonTouchDown) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [_moreButton addTarget:self action:@selector(pp_moreButtonTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    _moreButton.hidden = YES;

    UIImageSymbolConfiguration *symConfig = [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold];
    UIImage *chevron = [UIImage systemImageNamed:@"chevron.down" withConfiguration:symConfig];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        config.contentInsets = NSDirectionalEdgeInsetsMake(8, 16, 8, 16);
        config.image = chevron;
        config.imagePlacement = NSDirectionalRectEdgeTrailing;
        config.imagePadding = 6;
        config.baseForegroundColor = AppPrimaryClr;
        config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> * _Nonnull(NSDictionary<NSAttributedStringKey, id> * _Nonnull incoming) {
            NSMutableDictionary *attrs = [incoming mutableCopy];
            attrs[NSFontAttributeName] = [GM boldFontWithSize:14];
            return attrs;
        };
        UIBackgroundConfiguration *bg = [UIBackgroundConfiguration clearConfiguration];
        bg.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.1];
        bg.cornerRadius = 17;
        config.background = bg;
        _moreButton.configuration = config;
    } else {
        [_moreButton setImage:chevron forState:UIControlStateNormal];
        _moreButton.tintColor = AppPrimaryClr;
        _moreButton.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.1];
        _moreButton.layer.cornerRadius = 17;
        _moreButton.clipsToBounds = YES;
    }
    [self pp_updateMoreButtonTitle:kLang(@"ReadMore")];
    _moreButton.accessibilityHint = kLang(@"ReadMore");

    [self addSubview:self.surfaceView];
    [self.surfaceView addSubview:self.titleLabel];
    [self.surfaceView addSubview:divider];
    [self.surfaceView addSubview:_textView];
    [self.surfaceView addSubview:_moreButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.surfaceView.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [self.surfaceView.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [self.surfaceView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.surfaceView.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],

        [self.titleLabel.topAnchor      constraintEqualToAnchor:self.surfaceView.topAnchor      constant:kAVCardPadding],
        [self.titleLabel.leadingAnchor  constraintEqualToAnchor:self.surfaceView.leadingAnchor  constant:kAVCardPadding],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-kAVCardPadding],

        [divider.topAnchor      constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:kAVSpace12],
        [divider.leadingAnchor  constraintEqualToAnchor:self.surfaceView.leadingAnchor constant:kAVCardPadding],
        [divider.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-kAVCardPadding],
        [divider.heightAnchor   constraintEqualToConstant:1.0],

        [_textView.topAnchor      constraintEqualToAnchor:divider.bottomAnchor                constant:kAVSpace12],
        [_textView.leadingAnchor  constraintEqualToAnchor:self.surfaceView.leadingAnchor  constant:kAVCardPadding],
        [_textView.trailingAnchor constraintEqualToAnchor:self.surfaceView.trailingAnchor constant:-kAVCardPadding],
    ]];

    self.textViewHeightConstraint = [_textView.heightAnchor constraintEqualToConstant:44.0];
    self.textViewHeightConstraint.priority = UILayoutPriorityRequired;
    self.textViewHeightConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [_moreButton.topAnchor      constraintEqualToAnchor:_textView.bottomAnchor constant:kAVSpace12],
        [_moreButton.centerXAnchor  constraintEqualToAnchor:self.surfaceView.centerXAnchor],
        [_moreButton.bottomAnchor   constraintEqualToAnchor:self.surfaceView.bottomAnchor constant:-kAVCardPadding],
    ]];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = [self pp_textLayoutWidth];
    if (width > 0.0 && fabs(width - self.lastMeasuredTextWidth) > 1.0) {
        self.lastMeasuredTextWidth = width;
        [self pp_applyLineLimitAnimated:NO];
    }
}

#pragma mark - Toggle

- (void)pp_toggleExpanded {
    if (![self pp_needsTruncation]) {
        return;
    }

    self.isExpanded = !self.isExpanded;
    [self pp_applyLineLimitAnimated:YES];

    CGFloat rotation = self.isExpanded ? (CGFloat)M_PI : 0.0;
    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.16 : 0.28;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut |
                                UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.moreButton.imageView.transform = CGAffineTransformMakeRotation(rotation);
    }
                     completion:nil];
}

- (void)pp_applyLineLimit {
    [self pp_applyLineLimitAnimated:NO];
}

- (void)pp_applyLineLimitAnimated:(BOOL)animated {
    BOOL needsTruncation = [self pp_needsTruncation];
    self.moreButton.hidden = !needsTruncation;
    self.moreButton.alpha = needsTruncation ? 1.0 : 0.0;
    self.moreButton.userInteractionEnabled = needsTruncation;

    if (!needsTruncation) {
        self.isExpanded = NO;
    }

    NSString *toggleTitle = self.isExpanded ? kLang(@"ShowLess") : kLang(@"ReadMore");
    [self pp_updateMoreButtonTitle:toggleTitle];

    if (!self.isExpanded) {
        _textView.contentOffset = CGPointZero;
        self.moreButton.imageView.transform = CGAffineTransformIdentity;
    }

    [self pp_setTextViewHeight:[self pp_targetTextViewHeight] animated:animated];
}

- (void)pp_updateMoreButtonTitle:(NSString *)title {
    UIFont *toggleFont = [GM boldFontWithSize:14];
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = self.moreButton.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
        config.title = title;
        config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> * _Nonnull(NSDictionary<NSAttributedStringKey, id> * _Nonnull incoming) {
            NSMutableDictionary *attrs = [incoming mutableCopy];
            attrs[NSFontAttributeName] = toggleFont;
            return attrs;
        };
        self.moreButton.configuration = config;
        return;
    }
    [self.moreButton setTitle:title forState:UIControlStateNormal];
    self.moreButton.titleLabel.font = toggleFont;
}

- (void)pp_setTextViewHeight:(CGFloat)targetHeight animated:(BOOL)animated {
    UIScrollView *scrollView = self.hostScrollView;
    CGFloat anchorScreenY = 0.0;
    BOOL shouldAnchorScroll = scrollView != nil;

    if (shouldAnchorScroll) {
        CGRect anchorFrame = [self.moreButton convertRect:self.moreButton.bounds toView:scrollView];
        anchorScreenY = CGRectGetMinY(anchorFrame) - scrollView.contentOffset.y;
    }

    void (^layoutUpdates)(void) = ^{
        self.textViewHeightConstraint.constant = targetHeight;
        [self.superview setNeedsLayout];
        [self.superview layoutIfNeeded];

        if (!shouldAnchorScroll) {
            return;
        }

        CGRect anchorFrameAfter = [self.moreButton convertRect:self.moreButton.bounds toView:scrollView];
        CGFloat drift = (CGRectGetMinY(anchorFrameAfter) - scrollView.contentOffset.y) - anchorScreenY;
        if (fabs(drift) <= 0.5) {
            return;
        }

        CGPoint offset = scrollView.contentOffset;
        offset.y += drift;
        CGFloat minY = -scrollView.adjustedContentInset.top;
        CGFloat maxY = MAX(minY, scrollView.contentSize.height - scrollView.bounds.size.height + scrollView.adjustedContentInset.bottom);
        offset.y = MIN(MAX(minY, offset.y), maxY);
        scrollView.contentOffset = offset;
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        layoutUpdates();
        return;
    }

    [UIView animateWithDuration:0.28
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut |
                                UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:layoutUpdates
                     completion:nil];
}

- (CGFloat)pp_textLayoutWidth {
    CGFloat width = CGRectGetWidth(self.bounds) - (kAVCardPadding * 2.0);
    if (width > 0.0) {
        return width;
    }
    return UIScreen.mainScreen.bounds.size.width - (kAVSectionInset * 2.0) - (kAVCardPadding * 2.0);
}

- (CGFloat)pp_targetTextViewHeight {
    NSString *text = self.fullDescriptionText.length > 0 ? self.fullDescriptionText : _textView.text;
    CGFloat width = [self pp_textLayoutWidth];
    if (text.length == 0 || width <= 0.0) {
        return 44.0;
    }

    NSInteger lineLimit = self.isExpanded ? 0 : kPPAccessoryDescCollapsedLines;
    return [self pp_textHeightForText:text width:width lineLimit:lineLimit];
}

- (CGFloat)pp_textHeightForText:(NSString *)text width:(CGFloat)width lineLimit:(NSInteger)lineLimit {
    UIFont *font = _textView.font ?: [GM MidFontWithSize:15];
    CGRect rect = [text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                     options:NSStringDrawingUsesLineFragmentOrigin
                                  attributes:@{NSFontAttributeName: font}
                                     context:nil];
    CGFloat fullHeight = ceil(CGRectGetHeight(rect));
    if (lineLimit <= 0) {
        return MAX(fullHeight, font.lineHeight);
    }

    CGFloat collapsedHeight = ceil(font.lineHeight * (CGFloat)lineLimit);
    return MAX(MIN(fullHeight, collapsedHeight), font.lineHeight);
}

- (void)pp_moreButtonTouchDown {
    PPTapFeedbackDown(self.moreButton);
}

- (void)pp_moreButtonTouchUp {
    PPTapFeedbackUp(self.moreButton);
}

- (BOOL)pp_needsTruncation {
    NSString *text = self.fullDescriptionText.length > 0 ? self.fullDescriptionText : _textView.text;
    if (text.length == 0) {
        return NO;
    }

    CGFloat width = [self pp_textLayoutWidth];
    if (width <= 0.0) {
        return NO;
    }

    CGFloat fullHeight = [self pp_textHeightForText:text width:width lineLimit:0];
    CGFloat collapsedHeight = [self pp_textHeightForText:text width:width lineLimit:kPPAccessoryDescCollapsedLines];
    return fullHeight > collapsedHeight + 1.0;
}

- (void)pp_bindDescriptionText:(NSString *)text {
    self.fullDescriptionText = text.length > 0 ? text : kLang(@"accessory_view_no_description");
    _textView.text = self.fullDescriptionText;
    self.isExpanded = NO;
    self.lastMeasuredTextWidth = 0.0;
    [self pp_applyLineLimit];
}

#pragma mark - Binding

- (void)setAccessory:(PetAccessory *)accessory {
    _accessory = accessory;
    [self pp_bindDescriptionText:accessory.desc];
}

- (void)setDescriptionText:(NSString *)descriptionText {
    _descriptionText = descriptionText;
    [self pp_bindDescriptionText:descriptionText];
}

- (void)handleShareAction {
    // Implemented by the hosting AccessViewerVC; this stub satisfies the protocol.
}

@end
