//
//  ViewerVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//

#import "AccessViewerVC.h"
#import "AccessoryCollectionViewCell.h"
#import "PPAdSharingHelper.h"
#import "CartManager.h"
#import "PPCommerceFeedbackManager.h"
#import "PPAlertHelper.h"
#import "PPHUD.h"
#import "PPImageLoaderManager.h"
#import "PPPetsTitleView.h"
#import "ChManager.h"
#import "PPNetworkRetryHelper.h"
#import "PPModernAvatarRenderer.h"

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
static const CGFloat kAVCardCornerRadius     = 24.0;    // Large section surfaces
static const CGFloat kAVButtonCornerRadius   = 18.0;    // Rounded action pills
static const CGFloat kAVBadgeCornerRadius    = 999.0;   // Badges: pill
static const CGFloat kAVHeroCornerRadius     = 28.0;   // Modern rounded hero corners
static const CGFloat kAVDetailRowCorner      = 18.0;    // Detail row bg

// Layout
static const CGFloat kAVSectionInset         = 20.0;    // horizontal screen margin
static const CGFloat kAVCardPadding          = 20.0;    // inner section padding
static const CGFloat kAVActionBarHeight      = 50.0;    // action button height
static const CGFloat kAVDetailRowMinHeight   = 66.0;    // minimum detail row height
static const CGFloat kAVBottomBarBase        = 106.0;   // sticky bottom bar base height
static const CGFloat kAVSectionSpacing       = 20.0;    // section gap
static const CGFloat kAVSuggestionBottomInset = 32.0;   // breathing room below collection
static const CGFloat kAVSellerAvatarSize     = 56.0;    // seller identity avatar size

// Elevation (shadows)
static const CGFloat kAVCardShadowOpacity    = 0.2f;
static const CGFloat kAVCardShadowRadius     = 6.0;
static const CGFloat kAVCardShadowOffsetY    = 3.0;
static const CGFloat kAVSectionBorderWidth   = 1.0;

@interface AccessViewerVC()<UICollectionViewDataSource,UICollectionViewDelegate,CartQuantityUpdateDelegate,UICollectionViewDelegateFlowLayout>

// ── Scaffold ──
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
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
@property (nonatomic, strong) UIImageView *sellerAvatarImageView;
@property (nonatomic, strong) UILabel *sellerNameLabel;
@property (nonatomic, strong) UILabel *sellerSubtitleLabel;
@property (nonatomic, strong) UIStackView *actionStackView;
@property (nonatomic, strong) UIButton *supportActionButton;
@property (nonatomic, strong) UIButton *chatActionButton;
@property (nonatomic, strong) UIButton *callActionButton;
@property (nonatomic, strong) UIButton *shareActionButton;

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
    self.view.backgroundColor = PPBackgroundColorForIOS26(NewBgColor);
    [self initData];
    [self initForms];
    [self designViews];
    [self applyAccessoryContent];
    [self loadOwnerModelIfNeeded];
    
    _brower = [[PPPhotoBrowserBridge alloc] init];
    _brower.useArabic = Language.isRTL;
}

- (void)initData {
    // Build the view hierarchy in clean, testable sections
    [self pp_buildScaffold];
    [self pp_buildHeroSection];
    [self pp_buildSummaryCard];
    [self pp_buildDetailsCard];
    [self pp_buildDescriptionSection];
    [self pp_buildSellerSection];
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
    self.scrollView.backgroundColor = AppBackgroundClr;
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
        [self.bottomBar.bottomAnchor   constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:PPIOS26() ? 22 : 10],
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
        [self.scrollView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],

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
        [self.heroContainerView.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor],
        [self.heroContainerView.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.heroContainerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
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

        [self.petsTitleView.topAnchor      constraintEqualToAnchor:self.titleCard.topAnchor],
        [self.petsTitleView.leadingAnchor  constraintEqualToAnchor:self.titleCard.leadingAnchor],
        [self.petsTitleView.trailingAnchor constraintEqualToAnchor:self.titleCard.trailingAnchor],
        [self.petsTitleView.bottomAnchor   constraintEqualToAnchor:self.titleCard.bottomAnchor],
    ]];
    
    self.titleCard.hidden = YES;
}

/// Category / type / condition / stock section
- (void)pp_buildDetailsCard {

    self.detailsCardView = [self pp_surfaceCardClean];
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
    self.detailsStackView.spacing = 12.0;
    [innerDetails addSubview:self.detailsStackView];

    UILabel *categoryValue  = nil;
    UILabel *typeValue      = nil;
    UILabel *conditionValue = nil;
    UILabel *stockValue     = nil;

    // ── 2-column grid with distinct modern tints ──
    UIStackView *topPair = [[UIStackView alloc] init];
    topPair.axis = UILayoutConstraintAxisHorizontal;
    topPair.spacing = 12.0;
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
    bottomPair.spacing = 12.0;
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
        [detailsTitleLabel.leadingAnchor  constraintEqualToAnchor:innerDetails.leadingAnchor  constant:kAVCardPadding],
        [detailsTitleLabel.trailingAnchor constraintEqualToAnchor:innerDetails.trailingAnchor constant:-kAVCardPadding],

        [self.detailsStackView.topAnchor      constraintEqualToAnchor:detailsTitleLabel.bottomAnchor       constant:kAVSpace12],
        [self.detailsStackView.leadingAnchor  constraintEqualToAnchor:innerDetails.leadingAnchor  constant:kAVCardPadding],
        [self.detailsStackView.trailingAnchor constraintEqualToAnchor:innerDetails.trailingAnchor constant:-kAVCardPadding],
        [self.detailsStackView.bottomAnchor   constraintEqualToAnchor:innerDetails.bottomAnchor   constant:-kAVCardPadding],
    ]];
}

/// Free-text description card
- (void)pp_buildDescriptionSection {

    self.descView = [[PPAccessoryDescriptionView alloc] init];
    [self.contentView addSubview:self.descView];

    [NSLayoutConstraint activateConstraints:@[
        [self.descView.topAnchor      constraintEqualToAnchor:self.detailsCardView.bottomAnchor   constant:kAVSpace8],
        [self.descView.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor  constant:kAVSectionInset],
        [self.descView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kAVSectionInset],
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
    [self.contentView addSubview:self.sellerSectionView];
    UIView *innerSeller = [self pp_innerCardOf:self.sellerSectionView];

    self.sellerAvatarImageView = [[UIImageView alloc] initWithImage:PPSYSImage(@"person.crop.circle.fill")];
    self.sellerAvatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.sellerAvatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.sellerAvatarImageView.layer.cornerRadius = kAVSellerAvatarSize / 2.0;
    self.sellerAvatarImageView.layer.masksToBounds = YES;
    self.sellerAvatarImageView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.72];
    self.sellerAvatarImageView.tintColor = [AppSecondaryTextClr colorWithAlphaComponent:0.64];
    [innerSeller addSubview:self.sellerAvatarImageView];

    self.sellerNameLabel = [[UILabel alloc] init];
    self.sellerNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.sellerNameLabel.font = [GM boldFontWithSize:18];
    self.sellerNameLabel.textColor = AppPrimaryTextClr;
    self.sellerNameLabel.numberOfLines = 2;
    [innerSeller addSubview:self.sellerNameLabel];

    self.sellerSubtitleLabel = [[UILabel alloc] init];
    self.sellerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.sellerSubtitleLabel.font = [GM MidFontWithSize:12];
    self.sellerSubtitleLabel.textColor = [AppSecondaryTextClr colorWithAlphaComponent:0.82];
    self.sellerSubtitleLabel.numberOfLines = 2;
    [innerSeller addSubview:self.sellerSubtitleLabel];

    self.supportActionButton = [self pp_actionButtonWithTitle:kLang(@"Support")
                                                   systemName:@"headphones"
                                                     selector:@selector(supportTapped)
                                                   emphasized:YES];
    self.chatActionButton  = [self pp_actionButtonWithTitle:kLang(@"Chat")
                                                systemName:@"message.fill"
                                                  selector:@selector(chatBTN:)
                                                emphasized:YES];
    self.callActionButton  = [self pp_actionButtonWithTitle:kLang(@"Call")
                                                systemName:@"phone.fill"
                                                  selector:@selector(callOwnerBtn:)
                                                emphasized:NO];
    self.shareActionButton = [self pp_actionButtonWithTitle:kLang(@"Share")
                                                systemName:@"square.and.arrow.up"
                                                  selector:@selector(handleShareAction)
                                                emphasized:NO];

    self.actionStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.supportActionButton,
        self.chatActionButton,
        self.callActionButton,
        self.shareActionButton
    ]];
    self.actionStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionStackView.axis         = UILayoutConstraintAxisHorizontal;
    self.actionStackView.spacing      = kAVSpace8;
    self.actionStackView.distribution = UIStackViewDistributionFillEqually;
    [innerSeller addSubview:self.actionStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.sellerSectionView.topAnchor      constraintEqualToAnchor:self.descView.bottomAnchor constant:kAVSectionSpacing],
        [self.sellerSectionView.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor  constant:kAVSectionInset],
        [self.sellerSectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kAVSectionInset],

        [self.sellerAvatarImageView.leadingAnchor constraintEqualToAnchor:innerSeller.leadingAnchor constant:kAVCardPadding],
        [self.sellerAvatarImageView.topAnchor constraintEqualToAnchor:innerSeller.topAnchor constant:kAVCardPadding],
        [self.sellerAvatarImageView.widthAnchor constraintEqualToConstant:kAVSellerAvatarSize],
        [self.sellerAvatarImageView.heightAnchor constraintEqualToConstant:kAVSellerAvatarSize],

        [self.sellerNameLabel.topAnchor constraintEqualToAnchor:innerSeller.topAnchor constant:kAVCardPadding],
        [self.sellerNameLabel.leadingAnchor constraintEqualToAnchor:self.sellerAvatarImageView.trailingAnchor constant:kAVSpace12],
        [self.sellerNameLabel.trailingAnchor constraintEqualToAnchor:innerSeller.trailingAnchor constant:-kAVCardPadding],

        [self.sellerSubtitleLabel.topAnchor constraintEqualToAnchor:self.sellerNameLabel.bottomAnchor constant:kAVSpace4],
        [self.sellerSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.sellerNameLabel.leadingAnchor],
        [self.sellerSubtitleLabel.trailingAnchor constraintEqualToAnchor:innerSeller.trailingAnchor constant:-kAVCardPadding],

        [self.actionStackView.topAnchor constraintGreaterThanOrEqualToAnchor:self.sellerAvatarImageView.bottomAnchor constant:kAVSpace16],
        [self.actionStackView.topAnchor constraintEqualToAnchor:self.sellerSubtitleLabel.bottomAnchor constant:kAVSpace16],
        [self.actionStackView.leadingAnchor constraintEqualToAnchor:innerSeller.leadingAnchor constant:kAVCardPadding],
        [self.actionStackView.trailingAnchor constraintEqualToAnchor:innerSeller.trailingAnchor constant:-kAVCardPadding],
        [self.actionStackView.heightAnchor constraintEqualToConstant:kAVActionBarHeight],
        [self.actionStackView.bottomAnchor constraintEqualToAnchor:innerSeller.bottomAnchor constant:-kAVCardPadding],
    ]];
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
    [self.accessoryCollectionView registerClass:[AccessoryCollectionViewCell class]
                     forCellWithReuseIdentifier:@"AccessoryCollectionViewCell"];
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
        [self.sellerSectionView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-kAVSuggestionBottomInset];

    // Start with seller bottom (suggestions hidden by default)
    self.contentBottomToSellerConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [self.suggestionsContainerView.topAnchor      constraintEqualToAnchor:self.sellerSectionView.bottomAnchor constant:kAVSpace32],
        [self.suggestionsContainerView.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.suggestionsContainerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    ]];
}

/// Async fetch for suggested accessories
- (void)pp_fetchSuggestions {
    __weak typeof(self) weakSelf = self;
    [PetAccessoryManager fetchSuggestedAccessoriesForAccess:self.accessAds
                                                 completion:^(NSArray<PetAccessory *> *accessories) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.suggestedAccessories = accessories ?: @[];
        [strongSelf refreshSuggestedAccessoriesUI];
        [strongSelf.accessoryCollectionView reloadData];
    }];
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
        config.baseBackgroundColor = emphasized ? AppPrimaryClr : [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.55 : 0.92];
        config.background.strokeColor = [AppPrimaryTextClr colorWithAlphaComponent:emphasized ? 0.0 : 0.08];
        config.background.strokeWidth = emphasized ? 0.0 : 1.0;
        config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
            NSMutableDictionary *attrs = [incoming mutableCopy];
            attrs[NSFontAttributeName] = [GM boldFontWithSize:13];
            return attrs;
        };
        button.configuration = config;
    } else {
        button.backgroundColor = emphasized ? AppPrimaryClr : [AppForgroundColr colorWithAlphaComponent:0.9];
        button.layer.borderWidth = emphasized ? 0.0 : 1.0;
        [button pp_setBorderColor:[AppPrimaryTextClr colorWithAlphaComponent:0.08]];
        [button setTitleColor:emphasized ? AppForgroundColr : AppPrimaryTextClr forState:UIControlStateNormal];
        [button setTitle:title forState:UIControlStateNormal];
        [button setImage:icon forState:UIControlStateNormal];
        button.tintColor = emphasized ? AppForgroundColr : AppPrimaryTextClr;
        button.titleLabel.font = [GM boldFontWithSize:13];
        button.contentEdgeInsets = UIEdgeInsetsMake(12.0, 16.0, 12.0, 16.0);
    }

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
    iconShell.layer.cornerRadius = 16.0;
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
        [iconShell.widthAnchor constraintEqualToConstant:32.0],
        [iconShell.heightAnchor constraintEqualToConstant:32.0],

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
    CGFloat itemWidth = MIN(MAX(width * 0.56, 210.0), 248.0);
    return CGSizeMake(floor(itemWidth), floor(itemWidth * 1.14));
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

- (BOOL)pp_shouldShowCartBar
{
    return ![self pp_isUsedAccessory];
}

- (NSString *)pp_sellerMetaText
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *sellerTitle = kLang(@"accessory_view_seller_title");
    NSString *conditionText = [PetAccessory conditionTextForAccessory:self.accessAds];
    if (sellerTitle.length > 0) {
        [parts addObject:sellerTitle];
    }
    if (conditionText.length > 0) {
        [parts addObject:conditionText];
    }
    return [parts componentsJoinedByString:@" • "];
}

- (void)pp_updateSellerAvatar
{
    // For new accessories, show Pure Pets Store branding
    if (![self pp_isUsedAccessory]) {
        self.sellerAvatarImageView.image = [UIImage imageNamed:@"PPLogo"];
        self.sellerAvatarImageView.contentMode = UIViewContentModeScaleAspectFill;
        return;
    }

    UIImage *placeholder = self.ownerModel
        ? [PPModernAvatarRenderer avatarImageForName:self.ownerModel.UserName size:kAVSellerAvatarSize]
        : PPSYSImage(@"person.crop.circle.fill");
    self.sellerAvatarImageView.image = placeholder;

    NSString *imageURL = PPSafeString(self.ownerModel.UserImageUrl.absoluteString);
    if (imageURL.length == 0) {
        return;
    }

    [PPImageLoaderManager.shared setImageOnImageView:self.sellerAvatarImageView
                                                 url:imageURL
                                         placeholder:placeholder
                                          complation:^(UIImage * _Nonnull image, NSString * _Nullable urlString) {
    }];
}

- (void)pp_updateSellerActions
{
    BOOL isUsedAccessory = [self pp_isUsedAccessory];
    self.supportActionButton.hidden = isUsedAccessory;
    self.chatActionButton.hidden = !isUsedAccessory;
    self.callActionButton.hidden = !isUsedAccessory;
    self.shareActionButton.hidden = NO;
}

- (void)pp_updateBottomBarVisibility
{
    BOOL shouldShowCartBar = [self pp_shouldShowCartBar];
    self.bottomBar.hidden = !shouldShowCartBar;
    self.bottomBar.userInteractionEnabled = shouldShowCartBar;
    self.barBackgroundImageView.hidden = !shouldShowCartBar;
    self.barBackgroundImageView.alpha = shouldShowCartBar ? 1.0 : 0.0;
    self.bottomBarHeightConstraint.constant = shouldShowCartBar ? (kAVBottomBarBase + self.view.safeAreaInsets.bottom) : 0.0;

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
    
    NSString *ownerName;
    if (![self pp_isUsedAccessory]) {
        ownerName = [Language isRTL] ? @"متجر بيور بتس" : @"Pure Pets Store";
    } else {
        ownerName = [self.ownerModel respondsToSelector:@selector(PPBestDisplayName)] ? [self.ownerModel PPBestDisplayName] : @"";
    }
    self.sellerNameLabel.text = ownerName.length > 0 ? ownerName : kLang(@"accessory_view_seller_pending");
    self.sellerSubtitleLabel.text = [self pp_sellerMetaText];
    self.categoryValueLabel.text = [self pp_categorySummary];
    self.typeValueLabel.text = [PetAccessory typeTextForAccessory:self.accessAds];
    self.conditionValueLabel.text = [PetAccessory conditionTextForAccessory:self.accessAds];
    self.stockValueLabel.text = [self.accessAds stockStatusText];
    self.stockValueLabel.textColor = stockBadgeColor;
    self.descView.accessory = self.accessAds;
    
    [self pp_updateSellerAvatar];
    [self pp_updateSellerActions];
    [self pp_updateBottomBarVisibility];

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
    CGFloat targetAlpha = cartCount > 0 ? 1.0 : 0.72;
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
    BOOL didAdd = [[CartManager sharedManager] addItem:item];
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

    NSString *message = nil;
    if (safeQty < requestedQty) {
        message = [NSString stringWithFormat:@"%@ %ld %@",
                   kLang(@"Only"),
                   (long)availableToAdd,
                   kLang(@"left in stock")];
    } else {
        message = kLang(@"ItemAddedToYourCart");
    }

    [self.bottomBar performAddToCartSuccessAnimation];
    [PPHUD showSuccess:kLang(@"AddedToCart") subtitle:message delay:1.25];
    
    [self.QtyDelegate updateCartAndReloadCollection];
    [self loadItemsCountInBadge];
    [self checkCartAndAnimateIfNeeded];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartQuantityChanged];
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


- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self pp_updateBottomBarVisibility];
    self.heroHeightConstraint.constant = [self pp_heroHeight];
    self.heroGradientLayer.frame = self.heroContainerView.bounds;
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.accessoryCollectionView.collectionViewLayout;
    layout.itemSize = [self pp_suggestionItemSize];
    self.accessoryCollectionHeightConstraint.constant = [self pp_suggestionItemSize].height + 12.0;
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
    AccessoryCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AccessoryCollectionViewCell" forIndexPath:indexPath];
    if (indexPath.item >= (NSInteger)self.suggestedAccessories.count) return cell;
    PetAccessory *accessory = self.suggestedAccessories[indexPath.item];
    [cell configureWithAccessory:accessory];
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
    if (self.ownerModel || self.isResolvingOwner || self.accessAds.ownerID.length == 0) {
        return;
    }
    self.isResolvingOwner = YES;
    __weak typeof(self) weakSelf = self;
    [UsrMgr getOtherUserModelFromFirestoreWithUID:self.accessAds.ownerID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.isResolvingOwner = NO;
        if (error || !user) {
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











@interface PPAccessoryDescriptionView ()
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextView *textView;
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
    [self.surfaceView pp_setBorderColor:[AppPrimaryTextClr colorWithAlphaComponent:0.06]];
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

    [self addSubview:self.surfaceView];
    [self.surfaceView addSubview:self.titleLabel];
    [self.surfaceView addSubview:divider];
    [self.surfaceView addSubview:_textView];

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
        [_textView.bottomAnchor   constraintEqualToAnchor:self.surfaceView.bottomAnchor   constant:-kAVCardPadding],
    ]];
}

#pragma mark - Binding

- (void)setAccessory:(PetAccessory *)accessory {
    _accessory = accessory;
    self.textView.text = accessory.desc.length > 0 ? accessory.desc : kLang(@"accessory_view_no_description");
}

- (void)setDescriptionText:(NSString *)descriptionText {
    _descriptionText = descriptionText;
    self.textView.text = descriptionText.length > 0 ? descriptionText : kLang(@"accessory_view_no_description");
}

- (void)handleShareAction {
    // Implemented by the hosting AccessViewerVC; this stub satisfies the protocol.
}

@end
