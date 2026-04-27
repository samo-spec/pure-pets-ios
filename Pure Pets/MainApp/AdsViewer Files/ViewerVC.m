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
@property PetImageGalleryView *imageGallery;
@property UserModel *ownerModel;
@property PPSimilarAdsView *similarAdsView;
@property PPSimilarAdsView *similarAccessView;
@property (nonatomic, assign) BOOL didAnimate;
@property (nonatomic, strong) UIScrollView *contentScrollView;
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, strong) UIView *titleCard;
@property (nonatomic, strong) UIVisualEffectView *titleBlurView;
@property PetAdCardView *petCard;
// Layout constraints
@property (nonatomic, strong) NSLayoutConstraint *tableViewTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *tableViewHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *imageGalleryHeightConstraint;

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
@property (nonatomic, strong) UIVisualEffectView *contactLockOverlayView;
@property (nonatomic, strong) UIButton *contactLockButton;
@property (nonatomic, assign) BOOL isLoadingOwnerModel;
@property (nonatomic, strong) UIView *galleryScrimView;

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

- (void)initData {
    
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
    self.contentScrollView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.98];
    self.contentScrollView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    self.contentScrollView.layer.cornerRadius = 34.0;
    if (@available(iOS 13.0, *)) {
        self.contentScrollView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.contentScrollView.layer.borderWidth = 0.5;
    [self.contentScrollView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.08]];
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
    [self pp_prepareEntranceAnimationState];
}



-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_beginEntranceAnimationsIfNeeded];
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
        [self.infoView.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor constant:18],
        [self.infoView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:18],
        [self.infoView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-18],
        [self.infoView.heightAnchor constraintGreaterThanOrEqualToConstant:64]
    ]];
}


- (void)initdescriptionTextView {
    self.descriptionTextView = [[UITextView alloc] init];
    self.descriptionTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionTextView.scrollEnabled = NO;   // ✅ key
    self.descriptionTextView.editable = NO;
    self.descriptionTextView.selectable = YES;
    self.descriptionTextView.backgroundColor = UIColor.clearColor;
    self.descriptionTextView.tintColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    self.descriptionTextView.textAlignment = NSTextAlignmentNatural;
    self.descriptionTextView.textContainerInset = UIEdgeInsetsMake(12, 0, 14, 0);
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
    [self.contentContainer addSubview:self.descriptionTextView];
    
    
    self.descriptionHeightConstraint =
    [self.descriptionTextView.heightAnchor
     constraintGreaterThanOrEqualToConstant:44];
    self.descriptionHeightConstraint.priority = UILayoutPriorityDefaultHigh;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.descriptionTextView.topAnchor
         constraintEqualToAnchor:self.infoView.bottomAnchor constant:14],
        [self.descriptionTextView.leadingAnchor
         constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:24],
        [self.descriptionTextView.trailingAnchor
         constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-24],
        self.descriptionHeightConstraint
    ]];
   
}


- (void)initUserContactView {
   
    self.contactView = [[UserContactView alloc] initWithFrame:CGRectZero];
    self.contactView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentContainer addSubview:self.contactView];
    
    // Style
    self.contactView.layer.cornerRadius = 26.0;
    if (@available(iOS 13.0, *)) {
        self.contactView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.contactView.layer.shadowOpacity = 0.08;
    self.contactView.layer.shadowRadius = 18;
    self.contactView.layer.shadowOffset = CGSizeMake(0, 12);
    self.contactView.layer.borderWidth = 0.5;
    [self.contactView pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.10]];
    
    // ✅ NOW add gradient
    self.contactGradientLayer = [CAGradientLayer layer];
    self.contactGradientLayer.colors = @[
        (__bridge id)[[UIColor systemBackgroundColor] colorWithAlphaComponent:0.92].CGColor,
        (__bridge id)[AppPrimaryClr ?: UIColor.systemPinkColor colorWithAlphaComponent:0.18].CGColor
    ];
    self.contactGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.contactGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.contactGradientLayer.cornerRadius = 26.0;
    
    [self.contactView.layer insertSublayer:self.contactGradientLayer atIndex:0];
    
    
    self.contactView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.78];
    self.contactView.semanticContentAttribute = GM.setSemantic;
    // Style
    self.contactViewHeightConstraint = [self.contactView.heightAnchor constraintEqualToConstant:64];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.contactView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor constant:18],
        [self.contactView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor constant:-18],
        [self.contactView.topAnchor constraintEqualToAnchor:self.descriptionTextView.bottomAnchor constant:16],
        self.contactViewHeightConstraint,
    ]];
    self.contactView.layer.shouldRasterize = YES;
    self.contactView.layer.rasterizationScale = UIScreen.mainScreen.scale;
    [self pp_styleContactActionButtons];

    [self pp_updateContactAccessStateAnimated:NO];
}
- (void)initSimilarAds {
    
    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Dynamic separator color (Apple-style)
    separator.backgroundColor = [UIColor separatorColor];
    separator.alpha = 0.9;
    [self.contentContainer addSubview:separator];
    self.similarAdsSeparator = separator;
    self.similarAdsSeparator.hidden = YES;
    [NSLayoutConstraint activateConstraints:@[
        [separator.topAnchor constraintEqualToAnchor:self.contactView.bottomAnchor constant:24],
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
    
    // Dynamic separator color (Apple-style)
    separator.backgroundColor = [UIColor separatorColor];
    separator.alpha = 0.9;
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
    [self dismissViewControllerAnimated:YES completion:^{ }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self initValue];
    self.view.backgroundColor = PPBackgroundColorForIOS26(NewBgColor);//[AppForgroundColr colorWithAlphaComponent:0.6];
    self.modalInPresentation = NO;
    [self pp_updateContactAccessStateAnimated:NO];
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
    self.galleryLeadingStack.semanticContentAttribute = GM.setSemantic;
    if (self.descriptionTextView && self.descriptionTextView.bounds.size.width > 0) {
        CGSize fittingSize =
        [self.descriptionTextView sizeThatFits:
         CGSizeMake(self.descriptionTextView.bounds.size.width,
                    CGFLOAT_MAX)];
        self.descriptionHeightConstraint.constant = MAX(44, fittingSize.height);
    }
    if (self.contactGradientLayer) {
        self.contactGradientLayer.frame = self.contactView.bounds;
    }
    if (self.galleryScrimLayer) {
        self.galleryScrimLayer.frame = self.galleryScrimView.bounds;
    }
    self.titleCard.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.titleCard.bounds
                                                                 cornerRadius:self.titleCard.layer.cornerRadius].CGPath;
    self.contactView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.contactView.bounds
                                                                    cornerRadius:self.contactView.layer.cornerRadius].CGPath;
  
    [Styling applyCornerMaskToView:self.titleBlurView tl:32 tr:16 bl:32 br:28];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    if (self.view.window) {
        [self pp_beginEntranceAnimationsIfNeeded];
    }
}

#pragma mark - Motion

- (NSArray<UIView *> *)pp_primaryEntranceViews
{
    NSMutableArray<UIView *> *views = [NSMutableArray array];

    if (self.titleCard) {
        [views addObject:self.titleCard];
    }
    if (self.infoView) {
        [views addObject:self.infoView];
    }
    if (self.descriptionTextView) {
        [views addObject:self.descriptionTextView];
    }
    if (self.contactView) {
        [views addObject:self.contactView];
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
    if (view == self.descriptionTextView) {
        return 0.28;
    }
    if (view == self.petsTitleView) {
        return 0.20;
    }
    if (view == self.contactView) {
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
        } else if (view == self.descriptionTextView) {
            translationY = 8.0;
            scale = 0.992;
        } else if (view == self.contactView) {
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
        } else if (view == self.descriptionTextView) {
            delay = 0.06;
            duration = 0.36;
        } else if (view == self.contactView) {
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

- (void)pp_updateContactAccessStateAnimated:(BOOL)animated
{
    BOOL isLoggedIn = UserManager.sharedManager.isUserLoggedIn;
    self.contactViewHeightConstraint.constant = isLoggedIn ? 64.0 : 86.0;

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
    [self.navigationController popViewControllerAnimated:YES];
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
        config.baseBackgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.18];
        UIBackgroundConfiguration *background = config.background;
        background.visualEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
        background.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.18];
        background.strokeWidth = 0.8;
        config.background = background;
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    }
    
    config.image = [UIImage systemImageNamed:symbol];
    config.preferredSymbolConfigurationForImage =
    [UIImageSymbolConfiguration configurationWithPointSize:16
                                                    weight:UIImageSymbolWeightSemibold];
    
    UIButton *btn =
    [UIButton buttonWithConfiguration:config primaryAction:nil];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.clipsToBounds = NO;
    btn.adjustsImageWhenHighlighted = YES;
    
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    
    [NSLayoutConstraint activateConstraints:@[
        [btn.widthAnchor constraintEqualToConstant:44],
        [btn.heightAnchor constraintEqualToConstant:44],
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
