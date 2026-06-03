//
//  MyItemsViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 31/05/2025.
//  Refactored for iOS 26 Trending Modern UI — Immersive Hero
//

#import "MyItemsViewController.h"
#import "PetAdManager.h"
#import "PetAccessoryManager.h"
#import "AdoptPetManager.h"
#import "PetAd.h"
#import "PetAccessory.h"
#import "AdoptPetCell.h"
#import "AdoptPetModel.h"
#import "AppClasses.h"
#import "GM.h"
#import "PPImageLoaderManager.h"
#import "UserManager.h"
#import "PPUniversalCell.h"
#import "PPEmptyStateHelper.h"
#import "AddAdoptPetViewController.h"
#import "CitiesManager.h"
#import "AppManager.h"
#import "PPAdSharingHelper.h"
#import "AddNewAd.h"
#import "AddNewAccessory.h"

static const CGFloat kMyItemsCellHeight = 280.0;

@interface MyItemsViewController () <
    UICollectionViewDataSource,
    UICollectionViewDelegate,
    PPUniversalCellDelegate,
    AdoptCollectionViewCellDelegate,
    AddNewAdDelegate
>

@property (nonatomic, assign) MyItemsMode mode;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<PPUniversalCellViewModel *> *items;
@property (nonatomic, strong) CCActivityHUD *activityHUD;
@property (nonatomic, strong) NSArray *rawItems;

// Hero
@property (nonatomic, strong) UIView *heroShadowView;
@property (nonatomic, strong) UIView *heroCard;
@property (nonatomic, strong) CAGradientLayer *heroGradient;
@property (nonatomic, strong) CAGradientLayer *heroMesh;
@property (nonatomic, strong) CAGradientLayer *heroShine;
@property (nonatomic, strong) UILabel *heroEyebrow;
@property (nonatomic, strong) UILabel *heroTitle;
@property (nonatomic, strong) UILabel *heroSubtitle;
@property (nonatomic, strong) UIImageView *heroIconView;

@end

@implementation MyItemsViewController

#pragma mark - Initialization

- (instancetype)initWithMode:(MyItemsMode)mode {
    if (self = [super init]) {
        _mode = mode;
    }
    return self;
}

- (instancetype)initWithMode:(MyItemsMode)mode viewType:(ViewType)viewType {
    if (self = [self initWithMode:mode]) {
        _viewType = viewType;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupBaseUI];
    [self setupHeroHeader];
    [self setupSegmentedControl];
    [self setupCollectionView];
    [self setupActivityIndicator];

    [self fetchDataForCurrentSegment];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    NSString *title = (self.mode == MyItemsModeMyAds) ? kLang(@"myadsTitle") : kLang(@"myfavTitle");
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:title showBack:YES];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect cardBounds = self.heroCard.bounds;
    if (!CGRectIsEmpty(cardBounds)) {
        self.heroGradient.frame = cardBounds;
        self.heroMesh.frame     = cardBounds;
        self.heroShine.frame    = cardBounds;
    }
}

#pragma mark - UI Setup

- (void)setupBaseUI {
    self.view.backgroundColor = PPBackgroundColorForIOS26(GM.backOffwhileColor);
}

#pragma mark - Hero Header

- (void)setupHeroHeader {
    UISemanticContentAttribute sem = Language.semanticAttributeForCurrentLanguage;
    NSTextAlignment textAlign      = Language.alignmentForCurrentLanguage;

    // Shadow host
    UIView *shadowView = [UIView new];
    shadowView.translatesAutoresizingMaskIntoConstraints = NO;
    shadowView.backgroundColor     = UIColor.clearColor;
    shadowView.semanticContentAttribute = sem;
    shadowView.layer.cornerRadius  = PPCornerHero;
    [shadowView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    shadowView.layer.shadowOpacity = 0.16f;
    shadowView.layer.shadowRadius  = 26.0f;
    shadowView.layer.shadowOffset  = CGSizeMake(0.0, 14.0);
    if (@available(iOS 13.0, *)) {
        shadowView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.heroShadowView = shadowView;

    // Card
    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.semanticContentAttribute = sem;
    card.layer.cornerRadius  = PPCornerHero;
    card.layer.masksToBounds = YES;
    card.layer.borderWidth   = 1.0;
    [card pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.08]];
    if (@available(iOS 13.0, *)) {
        card.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.heroCard = card;

    // Gradient layers
    BOOL isMyAds = (self.mode == MyItemsModeMyAds);

    CAGradientLayer *gradient = [CAGradientLayer layer];
    if (isMyAds) {
        gradient.colors = @[
            (id)[UIColor colorWithRed:0.14 green:0.07 blue:0.16 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:0.23 green:0.10 blue:0.19 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:0.34 green:0.16 blue:0.17 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:0.46 green:0.23 blue:0.16 alpha:1.0].CGColor
        ];
    } else {
        gradient.colors = @[
            (id)[UIColor colorWithRed:0.08 green:0.10 blue:0.22 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:0.12 green:0.16 blue:0.30 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:0.18 green:0.22 blue:0.38 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:0.26 green:0.30 blue:0.48 alpha:1.0].CGColor
        ];
    }
    gradient.locations  = @[@0.0, @0.30, @0.72, @1.0];
    gradient.startPoint = CGPointMake(0.0, 0.1);
    gradient.endPoint   = CGPointMake(1.0, 1.0);
    [card.layer insertSublayer:gradient atIndex:0];
    self.heroGradient = gradient;

    CAGradientLayer *mesh = [CAGradientLayer layer];
    mesh.colors = @[
        (id)[UIColor colorWithRed:0.98 green:0.82 blue:0.56 alpha:0.26].CGColor,
        (id)[UIColor colorWithRed:0.66 green:0.30 blue:0.40 alpha:0.18].CGColor,
        (id)[UIColor clearColor].CGColor,
        (id)[UIColor colorWithRed:0.18 green:0.28 blue:0.34 alpha:0.18].CGColor
    ];
    mesh.locations  = @[@0.0, @0.28, @0.64, @1.0];
    mesh.startPoint = CGPointMake(1.0, 0.0);
    mesh.endPoint   = CGPointMake(0.0, 1.0);
    [card.layer insertSublayer:mesh above:gradient];
    self.heroMesh = mesh;

    CAGradientLayer *shine = [CAGradientLayer layer];
    shine.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.20].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.04].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    shine.locations  = @[@0.0, @0.06, @0.20];
    shine.startPoint = CGPointMake(0.0, 0.0);
    shine.endPoint   = CGPointMake(0.0, 1.0);
    [card.layer insertSublayer:shine above:mesh];
    self.heroShine = shine;

    // Pre-size gradients for first render
    CGFloat initW = UIScreen.mainScreen.bounds.size.width - (PPScreenMargin * 2);
    CGRect initFrame = CGRectMake(0, 0, initW, 200.0);
    gradient.frame = initFrame;
    mesh.frame     = initFrame;
    shine.frame    = initFrame;

    // Noise texture
    UIView *noiseView = [UIView new];
    noiseView.translatesAutoresizingMaskIntoConstraints = NO;
    noiseView.userInteractionEnabled = NO;
    noiseView.backgroundColor = [UIColor colorWithPatternImage:[self pp_noiseImageWithSize:CGSizeMake(64, 64) opacity:0.025]];
    [card addSubview:noiseView];
    [NSLayoutConstraint activateConstraints:@[
        [noiseView.topAnchor constraintEqualToAnchor:card.topAnchor],
        [noiseView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [noiseView.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [noiseView.bottomAnchor constraintEqualToAnchor:card.bottomAnchor]
    ]];

    // Decorative SF Symbol icon
    NSString *iconName = isMyAds ? @"bag.fill" : @"heart.fill";
    UIImageSymbolConfiguration *iconCfg = [UIImageSymbolConfiguration configurationWithPointSize:64 weight:UIImageSymbolWeightThin];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName withConfiguration:iconCfg]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.06];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:iconView];
    self.heroIconView = iconView;

    // Eyebrow
    UILabel *eyebrow = [UILabel new];
    eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrow.font      = [GM boldFontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:PPFontFootnote weight:UIFontWeightBold];
    eyebrow.textColor  = [UIColor colorWithRed:0.98 green:0.82 blue:0.56 alpha:0.94];
    eyebrow.textAlignment = textAlign;
    eyebrow.text = isMyAds ? kLang(@"myitems_hero_eyebrow_ads") : kLang(@"myitems_hero_eyebrow_fav");
    self.heroEyebrow = eyebrow;

    // Title
    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font      = [GM boldFontWithSize:PPFontTitle2] ?: [UIFont systemFontOfSize:PPFontTitle2 weight:UIFontWeightBold];
    titleLabel.textColor  = UIColor.whiteColor;
    titleLabel.numberOfLines = 2;
    titleLabel.textAlignment = textAlign;
    titleLabel.text = isMyAds ? kLang(@"myitems_hero_title_ads") : kLang(@"myitems_hero_title_fav");
    self.heroTitle = titleLabel;

    // Subtitle
    UILabel *subtitleLabel = [UILabel new];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font      = [GM MidFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:PPFontSubheadline weight:UIFontWeightMedium];
    subtitleLabel.textColor  = [UIColor colorWithWhite:1.0 alpha:0.72];
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.textAlignment = textAlign;
    subtitleLabel.text = isMyAds ? kLang(@"myitems_hero_subtitle_ads") : kLang(@"myitems_hero_subtitle_fav");
    self.heroSubtitle = subtitleLabel;

    // Assemble
    [shadowView addSubview:card];
    [card addSubview:eyebrow];
    [card addSubview:titleLabel];
    [card addSubview:subtitleLabel];
    [self.view addSubview:shadowView];

    CGFloat pad = PPSpaceXL;

    [NSLayoutConstraint activateConstraints:@[
        // Shadow host
        [shadowView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:PPSpaceSM],
        [shadowView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPScreenMargin],
        [shadowView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPScreenMargin],

        // Card fills shadow host
        [card.topAnchor constraintEqualToAnchor:shadowView.topAnchor],
        [card.leadingAnchor constraintEqualToAnchor:shadowView.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:shadowView.trailingAnchor],
        [card.bottomAnchor constraintEqualToAnchor:shadowView.bottomAnchor],

        // Icon — large, behind content
        [iconView.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-pad],
        [iconView.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-PPSpaceMD],
        [iconView.widthAnchor constraintEqualToConstant:80],
        [iconView.heightAnchor constraintEqualToConstant:80],

        // Eyebrow
        [eyebrow.topAnchor constraintEqualToAnchor:card.topAnchor constant:pad],
        [eyebrow.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:pad],
        [eyebrow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-pad],

        // Title
        [titleLabel.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:PPSpaceXS],
        [titleLabel.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:eyebrow.trailingAnchor],

        // Subtitle
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:PPSpaceXS],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:eyebrow.trailingAnchor],
    ]];
}

- (UIImage *)pp_noiseImageWithSize:(CGSize)size opacity:(CGFloat)opacity {
    UIGraphicsBeginImageContextWithOptions(size, NO, 1.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    for (NSInteger y = 0; y < (NSInteger)size.height; y++) {
        for (NSInteger x = 0; x < (NSInteger)size.width; x++) {
            CGFloat white = (arc4random_uniform(256)) / 255.0;
            [[UIColor colorWithWhite:white alpha:opacity] setFill];
            CGContextFillRect(ctx, CGRectMake(x, y, 1, 1));
        }
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - Segmented Control

- (void)setupSegmentedControl {
    NSArray *titles = [GM getAdsAccessSegmentedTitleForLanguage:[Language languageVal]];
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:titles];
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];

    [self pp_styleSegment:self.segmentedControl];

    [self.heroCard addSubview:self.segmentedControl];

    CGFloat pad = PPSpaceXL;

    [NSLayoutConstraint activateConstraints:@[
        [self.segmentedControl.topAnchor constraintEqualToAnchor:self.heroSubtitle.bottomAnchor constant:PPSpaceMD],
        [self.segmentedControl.leadingAnchor constraintEqualToAnchor:self.heroCard.leadingAnchor constant:pad],
        [self.segmentedControl.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor constant:-pad],
        [self.segmentedControl.heightAnchor constraintEqualToConstant:PPButtonHeightMD],
        [self.segmentedControl.bottomAnchor constraintEqualToAnchor:self.heroCard.bottomAnchor constant:-pad],
    ]];

    switch (self.viewType) {
        case ViewTypeAds:    self.segmentedControl.selectedSegmentIndex = 0; break;
        case ViewTypeAccess:
        case ViewTypeFood:   self.segmentedControl.selectedSegmentIndex = 1; break;
        case ViewTypeAdopt:  self.segmentedControl.selectedSegmentIndex = 2; break;
        default:             self.segmentedControl.selectedSegmentIndex = 0; break;
    }

    self.segmentedControl.semanticContentAttribute = [GM setSemantic];
}

- (void)setupCollectionView {
    UICollectionViewCompositionalLayout *layout = [self createCompositionalLayout];

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.delegate   = self;
    self.collectionView.dataSource = self;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.contentInset = UIEdgeInsetsMake(0, 0, PPSpaceXL, 0);

    [self.collectionView registerClass:[PPUniversalCell class] forCellWithReuseIdentifier:@"PPUniversalCell"];
    [self.collectionView registerClass:[AdoptPetCell class] forCellWithReuseIdentifier:@"AdoptPetCell"];

    [self.view addSubview:self.collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.heroShadowView.bottomAnchor constant:PPSpaceMD],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (UICollectionViewCompositionalLayout *)createCompositionalLayout {
    return [[UICollectionViewCompositionalLayout alloc] initWithSectionProvider:^NSCollectionLayoutSection * _Nullable(NSInteger sectionIndex, id<NSCollectionLayoutEnvironment>  _Nonnull layoutEnvironment) {

        CGFloat spacing = PPSpaceMD;
        NSCollectionLayoutSize *itemSize =
            [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:0.5]
                                          heightDimension:[NSCollectionLayoutDimension absoluteDimension:kMyItemsCellHeight]];

        NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
        item.contentInsets = NSDirectionalEdgeInsetsMake(0, spacing / 2, 0, spacing / 2);

        NSCollectionLayoutSize *groupSize =
            [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0]
                                          heightDimension:[NSCollectionLayoutDimension absoluteDimension:kMyItemsCellHeight]];

        NSCollectionLayoutGroup *group = [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize subitems:@[item]];

        NSCollectionLayoutSection *section = [NSCollectionLayoutSection sectionWithGroup:group];
        section.contentInsets = NSDirectionalEdgeInsetsMake(spacing, spacing, spacing, spacing);
        section.interGroupSpacing = spacing;

        return section;
    }];
}

- (void)setupActivityIndicator {
    self.activityHUD = [CCActivityHUD new];
    self.activityHUD.isTheOnlyActiveView = YES;
    self.activityHUD.backColor      = [UIColor clearColor];
    self.activityHUD.indicatorColor  = [GM appPrimaryColor];
    self.activityHUD.overlayType     = CCActivityHUDOverlayTypeShadow;
}

#pragma mark - Actions

- (void)segmentChanged:(UISegmentedControl *)sender {
    [self.activityHUD show];

    switch (sender.selectedSegmentIndex) {
        case 0: _viewType = ViewTypeAds;    break;
        case 1: _viewType = ViewTypeAccess; break;
        case 2: _viewType = ViewTypeAdopt;  break;
        default: _viewType = ViewTypeAds;   break;
    }

    [self fetchDataForCurrentSegment];
}

#pragma mark - Data Fetching

- (void)fetchDataForCurrentSegment {
    NSString *userID = [UserManager sharedManager].currentUser.ID;
    if (!userID) {
        [self.activityHUD dismiss];
        return;
    }

    __weak typeof(self) weakSelf = self;
    void (^completion)(NSArray *) = ^(NSArray *fetchedItems) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.rawItems = fetchedItems ?: @[];
            weakSelf.items = [weakSelf pp_generateUniversalModelsArrayFromArray:weakSelf.rawItems];
            [weakSelf.collectionView reloadData];
            [weakSelf.activityHUD dismiss];
            [weakSelf updateEmptyState];
        });
    };

    if (self.mode == MyItemsModeMyAds) {
        switch (self.viewType) {
            case ViewTypeAds:    [PetAdManager fetchAdsForUserID:userID completion:completion]; break;
            case ViewTypeAccess: [PetAccessoryManager fetchAccessoriesForUserID:userID accessKindType:AccessTypeAccessory completion:completion]; break;
            case ViewTypeFood:   [PetAccessoryManager fetchAccessoriesForUserID:userID accessKindType:AccessTypeFood completion:completion]; break;
            case ViewTypeAdopt:  [AdoptPetManager.shared fetchPetsForUserID:userID completion:^(NSArray *pets, NSError *error) { completion(pets); }]; break;
        }
    } else {
        NSString *collection = @"";
        switch (self.viewType) {
            case ViewTypeAds:    collection = @"favoritesAds"; break;
            case ViewTypeAccess: collection = @"favoritesAccessories"; break;
            case ViewTypeFood:   collection = @"favoritesAccessories"; break;
            case ViewTypeAdopt:  collection = @"favoritesAdoptPets"; break;
        }

        [PetAdManager fetchFavoriteAdIDsForUserID:userID collection:collection completion:^(NSArray<NSString *> *adIDs) {
            if (adIDs.count == 0) {
                completion(@[]);
                return;
            }

            switch (weakSelf.viewType) {
                case ViewTypeAds:    [PetAdManager fetchAdsWithIDs:adIDs completion:completion]; break;
                case ViewTypeAccess:
                case ViewTypeFood:   [PetAccessoryManager fetchAccessoriesWithIDs:adIDs completion:completion]; break;
                case ViewTypeAdopt:  [AdoptPetManager.shared fetchPetsWithIDs:adIDs completion:^(NSArray *pets, NSError *error) { completion(pets); }]; break;
            }
        }];
    }
}

- (void)updateEmptyState {
    PPEmptyStateConfig *cfg = [PPEmptyStateConfig new];
    cfg.animationName = @"Emptyred.json";
    cfg.title = kLang(@"nodata");
    cfg.target = self;
    cfg.isNetworkFile = YES;
    [PPEmptyStateHelper updateEmptyStateForListView:self.collectionView dataCount:self.items.count config:cfg];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.items.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPUniversalCellViewModel *viewModel = self.items[indexPath.item];

    if (self.viewType == ViewTypeAdopt) {
        AdoptPetCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AdoptPetCell" forIndexPath:indexPath];
        AdoptPetModel *model = (AdoptPetModel *)viewModel.ModelObject;
        cell.adoptModel = model;
        cell.delegate = self;
        NSString *cityName = [CitiesManager.shared cityNameForID:model.cityID];
        [cell configureWithName:model.name imageURL:model.imageURLs.firstObject subtitle:cityName adoptPetModel:model];
        [cell pp_applyOwnerMode:(self.mode == MyItemsModeMyAds) animated:NO];
        return cell;
    }

    PPUniversalCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PPUniversalCell" forIndexPath:indexPath];
    cell.delegate = self;
    cell.forceShowsOwnerMenuButton = (self.mode == MyItemsModeMyAds);
    viewModel.indexPath = indexPath;
    [cell applyViewModel:viewModel
                 context:viewModel.modelContext
              layoutMode:PPCellLayoutModePinterest
            discountMode:PPDiscountStyleBadge
             imageLoader:^(UIImageView *imageView, NSString *urlString, UIImage *placeholder, UIView *card) {
        [[PPImageLoaderManager shared] setImageOnImageView:imageView url:urlString complation:nil];
    }];

    return cell;
}

#pragma mark - PPUniversalCellDelegate

- (void)PPUniversalCell_tapEdit:(PPUniversalCellViewModel *)universalModel {
    if (!universalModel.ModelObject) return;

    if ([universalModel.ModelObject isKindOfClass:[PetAd class]]) {
        PetAd *ad = (PetAd *)universalModel.ModelObject;
        AddNewAd *vc = [[AddNewAd alloc] initWithStyle:UITableViewStyleGrouped];
        vc.mode = AdEditorModeEdit;
        vc.editingAd = ad;
        vc.delegate = self;
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        [self presentViewController:nav animated:YES completion:nil];
    } else if ([universalModel.ModelObject isKindOfClass:[PetAccessory class]]) {
        PetAccessory *acc = (PetAccessory *)universalModel.ModelObject;
        AddNewAccessory *vc = [[AddNewAccessory alloc] init];
        vc.editingAccessory = acc;
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        [self presentViewController:nav animated:YES completion:nil];
    }
}

- (void)PPUniversalCell_tapDelete:(PPUniversalCellViewModel *)universalModel {
    if (!universalModel.ModelObject) return;

    [GM showDeleteConfirmationFrom:self
                             title:kLang(@"Confirm Deletion")
                           message:kLang(@"Are you sure you want to delete this item?")
                        completion:^(BOOL confirmed) {
        if (!confirmed) return;

        if ([universalModel.ModelObject isKindOfClass:[PetAd class]]) {
            PetAd *ad = (PetAd *)universalModel.ModelObject;
            [[PetAdManager sharedManager] deletePetAd:ad completion:^(NSError * _Nullable error) {
                if (!error) [self fetchDataForCurrentSegment];
            }];
        } else if ([universalModel.ModelObject isKindOfClass:[PetAccessory class]]) {
            PetAccessory *acc = (PetAccessory *)universalModel.ModelObject;
            [[PetAccessoryManager sharedManager] deleteAccessory:acc.accessoryID completion:^(NSError *error) {
                if (!error) [self fetchDataForCurrentSegment];
            }];
        }
    }];
}

- (void)PPUniversalCell_tapVisibilityToggle:(PPUniversalCellViewModel *)universalModel {
    if (!universalModel.ModelObject) return;

    BOOL nextVisible = !universalModel.isPubliclyVisible;
    NSString *successMessage = nextVisible ? kLang(@"listing_visible_success") : kLang(@"listing_hidden_success");
    void (^showResult)(NSError * _Nullable) = ^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [PPAlertHelper showErrorIn:self title:kLang(@"Error") subtitle:error.localizedDescription ?: kLang(@"listing_visibility_failed")];
                return;
            }
            [self fetchDataForCurrentSegment];
            [AppManager.sharedInstance showSnakBar:successMessage withColor:GM.appPrimaryColor andDuration:0.6 containerView:self.view];
        });
    };

    if ([universalModel.ModelObject isKindOfClass:[PetAd class]]) {
        PetAd *ad = (PetAd *)universalModel.ModelObject;
        if (ad.adID.length == 0) return;
        [[PetAdManager sharedManager] updatePetAdID:ad.adID
                                         visibility:(nextVisible ? PetAdVisibilityPublic : PetAdVisibilityHidden)
                                         completion:showResult];
    } else if ([universalModel.ModelObject isKindOfClass:[PetAccessory class]]) {
        PetAccessory *acc = (PetAccessory *)universalModel.ModelObject;
        if (acc.accessoryID.length == 0) return;
        [[PetAccessoryManager sharedManager] updateAccessoryID:acc.accessoryID
                                               showInAppMarket:nextVisible
                                                    completion:showResult];
    } else if ([universalModel.ModelObject isKindOfClass:[AdoptPetModel class]]) {
        AdoptPetModel *model = (AdoptPetModel *)universalModel.ModelObject;
        if (model.documentID.length == 0) return;
        [[AdoptPetManager shared] updatePetVisibilityWithID:model.documentID
                                                 visibility:(nextVisible ? 0 : 1)
                                                 completion:^(BOOL success, NSError * _Nullable error) {
            showResult(success ? nil : error);
        }];
    }
}

- (void)PPUniversalCell_tapShare:(PPUniversalCellViewModel *)universalModel {
    if (!universalModel.ModelObject) return;
    [PPAdSharingHelper shareItem:universalModel.ModelObject fromViewController:self];
}

#pragma mark - AddNewAdDelegate

- (void)addNewAd:(AddNewAd *)vc didCreateAd:(PetAd *)ad {
    [self fetchDataForCurrentSegment];
}

- (void)addNewAd:(AddNewAd *)vc didUpdateAd:(PetAd *)ad {
    [self fetchDataForCurrentSegment];
}

#pragma mark - AdoptCollectionViewCellDelegate

- (void)adoptCellDidTapEdit:(AdoptPetCell *)cell onModel:(AdoptPetModel *)adoptModel {
    AddAdoptPetViewController *vc = [[AddAdoptPetViewController alloc] init];
    vc.editingPet = adoptModel;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)adoptCellDidTapDelete:(AdoptPetCell *)cell onModel:(AdoptPetModel *)adoptModel {
    [GM showDeleteConfirmationFrom:self
                             title:kLang(@"Confirm Deletion")
                           message:kLang(@"Are you sure you want to delete this item?")
                        completion:^(BOOL confirmed) {
        if (!confirmed) return;
        [AdoptPetManager.shared deletePetWithID:adoptModel.documentID completion:^(BOOL success, NSError *error) {
            if (success) {
                [self fetchDataForCurrentSegment];
                [AppManager.sharedInstance showSnakBar:kLang(@"Trash") withColor:GM.appPrimaryColor andDuration:0.3 containerView:self.view];
            }
        }];
    }];
}

#pragma mark - Styling

- (void)pp_styleSegment:(UISegmentedControl *)seg {
    if (!seg) return;

    PPApplyContinuousCorners(seg, PPCornerCard);
    seg.clipsToBounds = YES;

    NSDictionary *normalAttrs = @{
        NSForegroundColorAttributeName : AppSecondaryTextClr ?: [UIColor darkGrayColor],
        NSFontAttributeName : [GM fontWithSize:PPFontFootnote]
    };
    NSDictionary *selectedAttrs = @{
        NSForegroundColorAttributeName : [UIColor whiteColor],
        NSFontAttributeName : [GM boldFontWithSize:PPFontFootnote]
    };

    [seg setTitleTextAttributes:normalAttrs forState:UIControlStateNormal];
    [seg setTitleTextAttributes:selectedAttrs forState:UIControlStateSelected];

    if (@available(iOS 13.0, *)) {
        seg.selectedSegmentTintColor = [GM appPrimaryColor];
        seg.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.65];
        [seg setDividerImage:[UIImage new] forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    } else {
        seg.tintColor = [GM appPrimaryColor];
    }
}

#pragma mark - ViewModel Generation

- (NSArray<PPUniversalCellViewModel *> *)pp_generateUniversalModelsArrayFromArray:(NSArray *)objectsArray {
    NSMutableArray<PPUniversalCellViewModel *> *result = [NSMutableArray array];

    for (id obj in objectsArray) {
        PPCellContext context = PPCellForAds;
        if ([obj isKindOfClass:[PetAccessory class]]) {
            context = (self.viewType == ViewTypeFood) ? PPCellForFood : PPCellForMarket;
        } else if ([obj isKindOfClass:[AdoptPetModel class]]) {
            context = PPCellForAdopt;
        }

        PPUniversalCellViewModel *vm = [[PPUniversalCellViewModel alloc] initWithModel:obj context:context];

        if ([obj isKindOfClass:[PetAd class]]) {
            PetAd *ad = (PetAd *)obj;
            if (self.mode == MyItemsModeMyAds) {
                vm.isOwner = YES;
            } else {
                vm.isOwner = [[UserManager sharedManager].currentUser.ID isEqualToString:ad.ownerID];
            }
        }
        else if ([obj isKindOfClass:[PetAccessory class]]) {
            PetAccessory *acc = (PetAccessory *)obj;
            if (self.mode == MyItemsModeMyAds) {
                vm.isOwner = YES;
            } else {
                vm.isOwner = [[UserManager sharedManager].currentUser.ID isEqualToString:acc.ownerID];
            }
        }
        else if ([obj isKindOfClass:[AdoptPetModel class]]) {
            AdoptPetModel *model = (AdoptPetModel *)obj;
            if (self.mode == MyItemsModeMyAds) {
                vm.isOwner = YES;
            } else {
                vm.isOwner = [[UserManager sharedManager].currentUser.ID isEqualToString:model.ownerID];
            }
        }

        [result addObject:vm];
    }
    return [result copy];
}

@end
