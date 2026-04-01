//
//  PPSearchViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 05/01/2026.
//

#import "PPSearchViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "BBNavigationBar.h"
#import "PPImageLoaderManager.h"
#import "PPOverlayCoordinator.h"
#import "PPInsetLabel.h"
#import "PPSearchHelper.h"
#import "PPUniversalCell.h"
#import "PPUniversalCellViewModel.h"
#import "PetAccessory.h"
#import "PetAd.h"
#import "SearchCacheManager.h"
#import "ServiceModel.h"

typedef NS_ENUM(NSUInteger, PPSearchSection) {
    PPSearchSectionResults = 0
};

typedef NS_ENUM(NSInteger, PPSearchSegment) {
    PPSearchSegmentAds = 0,
    PPSearchSegmentServices = 1,
    PPSearchSegmentAccessories = 2
};

static CGFloat const kPPSearchHorizontalInset = 16.0;
static CGFloat const kPPSearchInteritemSpacing = 14.0;
static CGFloat const kPPSearchLineSpacing = 18.0;
static NSInteger const kPPSearchMinimumQueryLength = 2;
static NSTimeInterval const kPPSearchDebounceDelay = 0.22;

@interface PPSearchViewController ()
<UISearchResultsUpdating,
UISearchControllerDelegate,
UISearchBarDelegate,
UICollectionViewDelegate,
UICollectionViewDelegateFlowLayout,
PPUniversalCellDelegate>

@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UICollectionViewDiffableDataSource<NSNumber *, PPUniversalCellViewModel *> *dataSource;

@property (nonatomic, copy) NSArray<PPUniversalCellViewModel *> *results;
@property (nonatomic, copy) NSArray<id> *allSearchResults;
@property (nonatomic, copy, nullable) NSString *lastQuery;

@property (nonatomic, strong) UIView *primaryGlowView;
@property (nonatomic, strong) UIView *secondaryGlowView;
@property (nonatomic, strong) UIView *heroCardView;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) CAGradientLayer *heroMeshLayer;
@property (nonatomic, strong) CAGradientLayer *heroShineLayer;
@property (nonatomic, strong) UIView *heroNoiseView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@property (nonatomic, strong) UIStackView *metaStackView;
@property (nonatomic, strong) UILabel *statusPillLabel;
@property (nonatomic, strong) UILabel *scopePillLabel;
@property (nonatomic, strong) UILabel *countPillLabel;
@property (nonatomic, strong) UILabel *queryPillLabel;

@property (nonatomic, strong) UISegmentedControl *searchSegment;
@property (nonatomic, strong) UIVisualEffectView *segmentGlassView;
@property (nonatomic, strong) UILabel *adsBadge;
@property (nonatomic, strong) UILabel *servicesBadge;
@property (nonatomic, strong) UILabel *accessoriesBadge;
@property (nonatomic, strong) NSLayoutConstraint *adsBadgeCenterX;
@property (nonatomic, strong) NSLayoutConstraint *servicesBadgeCenterX;
@property (nonatomic, strong) NSLayoutConstraint *accessoriesBadgeCenterX;

@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UIImageView *emptyStateIconView;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;

@property (nonatomic, assign) BOOL isSearching;
@property (nonatomic, assign) BOOL didAnimateHero;
@property (nonatomic, assign) NSInteger currentSearchRequestID;
@property (nonatomic, strong) dispatch_queue_t searchQueue;
@property (nonatomic, copy, nullable) dispatch_block_t pendingDebounceBlock;

@end

@implementation PPSearchViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClrDarker);
    self.results = @[];
    self.allSearchResults = @[];
    self.searchQueue = dispatch_queue_create("com.purepets.search.controller", DISPATCH_QUEUE_SERIAL);

    [self setupBackdrop];
    [self setupNavigation];
    [self setupSearch];
    [self setupHeroHeader];
    [self setupCollectionView];
    [self setupDataSource];
    [self setupSearchSegment];
    [self setupEmptyState];
    [self warmUpSearchCacheIfNeeded];
    [self updateHeaderStateAnimated:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self animateHeroIfNeeded];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGRect heroBounds = self.heroCardView.bounds;
    self.heroGradientLayer.frame = heroBounds;
    self.heroMeshLayer.frame = heroBounds;
    self.heroShineLayer.frame = heroBounds;
    self.primaryGlowView.layer.cornerRadius = CGRectGetWidth(self.primaryGlowView.bounds) * 0.5;
    self.secondaryGlowView.layer.cornerRadius = CGRectGetWidth(self.secondaryGlowView.bounds) * 0.5;
    [self updateBadgePositions];
}

- (void)dealloc
{
    if (self.pendingDebounceBlock) {
        dispatch_block_cancel(self.pendingDebounceBlock);
        self.pendingDebounceBlock = nil;
    }
}

#pragma mark - Public

- (void)focusSearchField
{
    [self loadViewIfNeeded];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.searchController.searchBar becomeFirstResponder];
    });
}

- (void)openAccessoriesAll
{
    [self loadViewIfNeeded];
    self.searchSegment.selectedSegmentIndex = PPSearchSegmentAccessories;
    [self applySegmentFilter];
    [self focusSearchField];
}

#pragma mark - Setup

- (void)setupBackdrop
{
    // Primary warm glow — larger, softer amber-rose orb
    UIView *primaryGlow = [UIView new];
    primaryGlow.translatesAutoresizingMaskIntoConstraints = NO;
    primaryGlow.userInteractionEnabled = NO;
    primaryGlow.backgroundColor = [[UIColor colorWithRed:0.92 green:0.50 blue:0.30 alpha:1.0] colorWithAlphaComponent:0.14];
    primaryGlow.layer.shadowColor = [UIColor colorWithRed:0.92 green:0.50 blue:0.30 alpha:1.0].CGColor;
    primaryGlow.layer.shadowOpacity = 0.22;
    primaryGlow.layer.shadowRadius = 100.0;
    primaryGlow.layer.shadowOffset = CGSizeZero;
    primaryGlow.layer.cornerRadius = 50.0;

    // Secondary cool glow — violet orb for depth contrast
    UIView *secondaryGlow = [UIView new];
    secondaryGlow.translatesAutoresizingMaskIntoConstraints = NO;
    secondaryGlow.userInteractionEnabled = NO;
    secondaryGlow.backgroundColor = [[UIColor colorWithRed:0.40 green:0.22 blue:0.66 alpha:1.0] colorWithAlphaComponent:0.10];
    secondaryGlow.layer.shadowColor = [UIColor colorWithRed:0.40 green:0.22 blue:0.66 alpha:1.0].CGColor;
    secondaryGlow.layer.shadowOpacity = 0.20;
    secondaryGlow.layer.shadowRadius = 90.0;
    secondaryGlow.layer.shadowOffset = CGSizeZero;
    secondaryGlow.layer.cornerRadius = 45.0;
    [self.view addSubview:primaryGlow];
    [self.view addSubview:secondaryGlow];

    [NSLayoutConstraint activateConstraints:@[
        [primaryGlow.widthAnchor constraintEqualToConstant:300.0],
        [primaryGlow.heightAnchor constraintEqualToConstant:300.0],
        [primaryGlow.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-90.0],
        [primaryGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:100.0],

        [secondaryGlow.widthAnchor constraintEqualToConstant:260.0],
        [secondaryGlow.heightAnchor constraintEqualToConstant:260.0],
        [secondaryGlow.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:180.0],
        [secondaryGlow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-100.0]
    ]];

    self.primaryGlowView = primaryGlow;
    self.secondaryGlowView = secondaryGlow;
}

- (void)setupNavigation
{
    self.navigationItem.title = kLang(@"searchOnly");
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    BBNavigationBar *bar = [BBNavigationBar new];
    [bar attachTo:self];
}

- (void)setupSearch
{
    UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.obscuresBackgroundDuringPresentation = NO;
    searchController.hidesNavigationBarDuringPresentation = NO;
    searchController.searchResultsUpdater = self;
    searchController.delegate = self;
    searchController.searchBar.delegate = self;
    searchController.searchBar.placeholder = kLang(@"SearchPlaceholder");

    UISearchBar *searchBar = searchController.searchBar;
    searchBar.searchBarStyle = UISearchBarStyleMinimal;
    searchBar.barTintColor = AppClearClr;
    searchBar.tintColor = AppPrimaryClr;

    if (@available(iOS 13.0, *)) {
        UITextField *textField = searchBar.searchTextField;
        textField.font = [GM MidFontWithSize:16];
        textField.textColor = UIColor.labelColor;
        textField.layer.cornerRadius = 16.0;
        textField.layer.masksToBounds = YES;
        textField.layer.borderWidth = 1.0;
        textField.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
        textField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];

        NSMutableAttributedString *placeholder =
        [[NSMutableAttributedString alloc] initWithString:kLang(@"SearchPlaceholder") attributes:@{
            NSForegroundColorAttributeName : [UIColor colorWithWhite:1.0 alpha:0.58],
            NSFontAttributeName : [GM MidFontWithSize:15]
        }];
        textField.attributedPlaceholder = placeholder;

        UIImageView *searchIcon = [textField valueForKey:@"leftView"];
        searchIcon.tintColor = [UIColor colorWithWhite:1.0 alpha:0.68];
    }

    self.searchController = searchController;
    self.navigationItem.searchController = searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
}

- (void)setupHeroHeader
{
    UIView *heroCard = [UIView new];
    heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    heroCard.layer.cornerRadius = PPCornerHero;
    heroCard.layer.masksToBounds = YES;
    heroCard.layer.borderWidth = 0.5;
    heroCard.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;

    // --- Primary gradient: deep plum → rich berry → warm amber sweep ---
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = @[
        (id)[UIColor colorWithRed:0.10 green:0.05 blue:0.20 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.18 green:0.08 blue:0.24 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.28 green:0.12 blue:0.20 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.36 green:0.18 blue:0.10 alpha:1.0].CGColor
    ];
    gradient.locations = @[@0.0, @0.32, @0.66, @1.0];
    gradient.startPoint = CGPointMake(0.0, 0.0);
    gradient.endPoint = CGPointMake(1.0, 1.0);
    [heroCard.layer insertSublayer:gradient atIndex:0];

    // --- Mesh overlay: cool teal ↔ warm coral for dimensional depth ---
    CAGradientLayer *mesh = [CAGradientLayer layer];
    mesh.colors = @[
        (id)[UIColor colorWithRed:0.04 green:0.20 blue:0.32 alpha:0.40].CGColor,
        (id)[UIColor clearColor].CGColor,
        (id)[UIColor colorWithRed:0.40 green:0.16 blue:0.10 alpha:0.30].CGColor
    ];
    mesh.locations = @[@0.0, @0.45, @1.0];
    mesh.startPoint = CGPointMake(1.0, 0.0);
    mesh.endPoint = CGPointMake(0.0, 1.0);
    [heroCard.layer insertSublayer:mesh above:gradient];

    // --- Top-edge shine for glass material feel ---
    CAGradientLayer *shine = [CAGradientLayer layer];
    shine.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.14].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.05].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    shine.locations = @[@0.0, @0.04, @0.15];
    shine.startPoint = CGPointMake(0.0, 0.0);
    shine.endPoint = CGPointMake(0.0, 1.0);
    [heroCard.layer insertSublayer:shine above:mesh];

    // --- Noise texture overlay for material grain ---
    UIView *noiseView = [UIView new];
    noiseView.translatesAutoresizingMaskIntoConstraints = NO;
    noiseView.userInteractionEnabled = NO;
    noiseView.backgroundColor = [UIColor colorWithPatternImage:[self pp_noiseImageWithSize:CGSizeMake(64, 64) opacity:0.035]];
    [heroCard addSubview:noiseView];
    [NSLayoutConstraint activateConstraints:@[
        [noiseView.topAnchor constraintEqualToAnchor:heroCard.topAnchor],
        [noiseView.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor],
        [noiseView.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor],
        [noiseView.bottomAnchor constraintEqualToAnchor:heroCard.bottomAnchor]
    ]];

    // --- Eyebrow label with warm gold accent ---
    UILabel *eyebrow = [UILabel new];
    eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrow.font = [GM boldFontWithSize:PPFontFootnote];
    eyebrow.textColor = [UIColor colorWithRed:0.98 green:0.82 blue:0.56 alpha:0.94];
    eyebrow.text = kLang(@"SearchHeroEyebrow");

    // --- Hero title: large, bold, pure white ---
    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:30];
    titleLabel.textColor = UIColor.whiteColor;
    titleLabel.numberOfLines = 2;
    titleLabel.text = kLang(@"SearchHeroTitle");

    // --- Subtitle with improved readability ---
    UILabel *subtitleLabel = [UILabel new];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:PPFontSubheadline];
    subtitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
    subtitleLabel.numberOfLines = 3;

    UILabel *statusPill = [self makeHeroPillLabel];
    UILabel *scopePill = [self makeHeroPillLabel];
    UILabel *countPill = [self makeHeroPillLabel];
    UILabel *queryPill = [self makeHeroPillLabel];

    UIStackView *metaStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        statusPill,
        scopePill,
        countPill,
        queryPill
    ]];
    metaStack.translatesAutoresizingMaskIntoConstraints = NO;
    metaStack.axis = UILayoutConstraintAxisHorizontal;
    metaStack.spacing = PPSpaceSM;
    metaStack.alignment = UIStackViewAlignmentLeading;
    metaStack.distribution = UIStackViewDistributionFillProportionally;

    [heroCard addSubview:eyebrow];
    [heroCard addSubview:titleLabel];
    [heroCard addSubview:subtitleLabel];
    [heroCard addSubview:metaStack];
    [self.view addSubview:heroCard];

    CGFloat cardPadding = PPSpaceXL;
    [NSLayoutConstraint activateConstraints:@[
        [heroCard.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:PPSpaceSM],
        [heroCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPScreenMargin],
        [heroCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPScreenMargin],

        [eyebrow.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:cardPadding],
        [eyebrow.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:cardPadding],
        [eyebrow.trailingAnchor constraintLessThanOrEqualToAnchor:heroCard.trailingAnchor constant:-cardPadding],

        [titleLabel.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:PPSpaceSM],
        [titleLabel.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:cardPadding],
        [titleLabel.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-cardPadding],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:PPSpaceSM],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [metaStack.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:PPSpaceBase],
        [metaStack.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [metaStack.trailingAnchor constraintLessThanOrEqualToAnchor:titleLabel.trailingAnchor]
    ]];

    self.heroCardView = heroCard;
    self.heroGradientLayer = gradient;
    self.heroMeshLayer = mesh;
    self.heroShineLayer = shine;
    self.heroNoiseView = noiseView;
    self.eyebrowLabel = eyebrow;
    self.heroTitleLabel = titleLabel;
    self.heroSubtitleLabel = subtitleLabel;
    self.metaStackView = metaStack;
    self.statusPillLabel = statusPill;
    self.scopePillLabel = scopePill;
    self.countPillLabel = countPill;
    self.queryPillLabel = queryPill;
}

- (void)setupCollectionView
{
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.minimumInteritemSpacing = kPPSearchInteritemSpacing;
    layout.minimumLineSpacing = kPPSearchLineSpacing;
    layout.sectionInset = UIEdgeInsetsMake(0.0,
                                           kPPSearchHorizontalInset,
                                           28.0,
                                           kPPSearchHorizontalInset);

    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero
                                                           collectionViewLayout:layout];
    collectionView.backgroundColor = UIColor.clearColor;
    collectionView.alwaysBounceVertical = YES;
    collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    collectionView.delegate = self;
    collectionView.showsVerticalScrollIndicator = NO;
    collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    [collectionView registerClass:PPUniversalCell.class forCellWithReuseIdentifier:@"PPUniversalCell"];

    [self.view addSubview:collectionView];
    [NSLayoutConstraint activateConstraints:@[
        [collectionView.topAnchor constraintEqualToAnchor:self.heroCardView.bottomAnchor constant:14.0],
        [collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    self.collectionView = collectionView;
}

- (void)setupDataSource
{
    __weak typeof(self) weakSelf = self;
    self.dataSource = [[UICollectionViewDiffableDataSource alloc]
                       initWithCollectionView:self.collectionView
                       cellProvider:^UICollectionViewCell * _Nullable(UICollectionView *collectionView,
                                                                      NSIndexPath *indexPath,
                                                                      PPUniversalCellViewModel *viewModel) {
        PPUniversalCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PPUniversalCell"
                                                                           forIndexPath:indexPath];
        viewModel.indexPath = indexPath;
        [cell applyViewModel:viewModel
                     context:viewModel.modelContext
                  layoutMode:PPCellLayoutModePinterest
                discountMode:PPDiscountStylePlain
                 imageLoader:^(UIImageView *imageView, NSString *url, UIImage *placeholder, UIView *card) {
            [[PPImageLoaderManager shared] setImageOnImageView:imageView url:url complation:nil];
        }];
        cell.delegate = weakSelf;
        return cell;
    }];

    [self applyResultsAnimated:NO];
}

- (void)setupSearchSegment
{
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    UIVisualEffectView *glassView = [[UIVisualEffectView alloc] initWithEffect:blur];
    glassView.translatesAutoresizingMaskIntoConstraints = NO;
    glassView.layer.cornerRadius = 24.0;
    glassView.layer.masksToBounds = YES;
    glassView.layer.borderWidth = 1.0;
    glassView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.14].CGColor;

    UISegmentedControl *segment = [[UISegmentedControl alloc] initWithItems:@[
        kLang(@"Ads"),
        kLang(@"services"),
        kLang(@"Accessories")
    ]];
    segment.selectedSegmentIndex = PPSearchSegmentAds;
    segment.translatesAutoresizingMaskIntoConstraints = NO;
    segment.backgroundColor = UIColor.clearColor;
    segment.selectedSegmentTintColor = [UIColor colorWithWhite:1.0 alpha:0.88];
    [segment addTarget:self action:@selector(searchSegmentChanged) forControlEvents:UIControlEventValueChanged];

    NSDictionary *normalAttrs = @{
        NSFontAttributeName : [GM MidFontWithSize:14],
        NSForegroundColorAttributeName : [UIColor colorWithWhite:1.0 alpha:0.68]
    };
    NSDictionary *selectedAttrs = @{
        NSFontAttributeName : [GM boldFontWithSize:14],
        NSForegroundColorAttributeName : UIColor.labelColor
    };
    [segment setTitleTextAttributes:normalAttrs forState:UIControlStateNormal];
    [segment setTitleTextAttributes:selectedAttrs forState:UIControlStateSelected];

    [glassView.contentView addSubview:segment];

    self.adsBadge = [self makeBadgeLabel];
    self.servicesBadge = [self makeBadgeLabel];
    self.accessoriesBadge = [self makeBadgeLabel];
    [glassView.contentView addSubview:self.adsBadge];
    [glassView.contentView addSubview:self.servicesBadge];
    [glassView.contentView addSubview:self.accessoriesBadge];

    [self.heroCardView addSubview:glassView];

    self.adsBadgeCenterX = [self.adsBadge.centerXAnchor constraintEqualToAnchor:segment.leadingAnchor];
    self.servicesBadgeCenterX = [self.servicesBadge.centerXAnchor constraintEqualToAnchor:segment.leadingAnchor];
    self.accessoriesBadgeCenterX = [self.accessoriesBadge.centerXAnchor constraintEqualToAnchor:segment.leadingAnchor];

    [NSLayoutConstraint activateConstraints:@[
        [glassView.topAnchor constraintEqualToAnchor:self.metaStackView.bottomAnchor constant:18.0],
        [glassView.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor constant:16.0],
        [glassView.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor constant:-16.0],
        [glassView.heightAnchor constraintEqualToConstant:48.0],
        [glassView.bottomAnchor constraintEqualToAnchor:self.heroCardView.bottomAnchor constant:-16.0],

        [segment.leadingAnchor constraintEqualToAnchor:glassView.contentView.leadingAnchor constant:0.5],
        [segment.trailingAnchor constraintEqualToAnchor:glassView.contentView.trailingAnchor constant:-0.5],
        [segment.topAnchor constraintEqualToAnchor:glassView.contentView.topAnchor constant:0.5],
        [segment.bottomAnchor constraintEqualToAnchor:glassView.contentView.bottomAnchor constant:-0.5],

        self.adsBadgeCenterX,
        self.servicesBadgeCenterX,
        self.accessoriesBadgeCenterX,

        [self.adsBadge.topAnchor constraintEqualToAnchor:glassView.contentView.topAnchor constant:-2.0],
        [self.adsBadge.widthAnchor constraintGreaterThanOrEqualToConstant:20.0],
        [self.adsBadge.heightAnchor constraintEqualToConstant:20.0],

        [self.servicesBadge.topAnchor constraintEqualToAnchor:glassView.contentView.topAnchor constant:-2.0],
        [self.servicesBadge.widthAnchor constraintGreaterThanOrEqualToConstant:20.0],
        [self.servicesBadge.heightAnchor constraintEqualToConstant:20.0],

        [self.accessoriesBadge.topAnchor constraintEqualToAnchor:glassView.contentView.topAnchor constant:-2.0],
        [self.accessoriesBadge.widthAnchor constraintGreaterThanOrEqualToConstant:20.0],
        [self.accessoriesBadge.heightAnchor constraintEqualToConstant:20.0]
    ]];

    self.searchSegment = segment;
    self.segmentGlassView = glassView;
    [self pp_hideAllBadges];
}

- (void)setupEmptyState
{
    UIView *container = [UIView new];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.hidden = YES;
    container.alpha = 0.0;

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sparkle.magnifyingglass"]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = [[UIColor colorWithRed:0.98 green:0.80 blue:0.54 alpha:1.0] colorWithAlphaComponent:0.92];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightSemibold];

    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [GM boldFontWithSize:22];
    titleLabel.textColor = UIColor.whiteColor;
    titleLabel.numberOfLines = 2;

    UILabel *subtitleLabel = [UILabel new];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.font = [GM MidFontWithSize:14];
    subtitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.70];
    subtitleLabel.numberOfLines = 3;

    [container addSubview:iconView];
    [container addSubview:titleLabel];
    [container addSubview:subtitleLabel];
    [self.view addSubview:container];

    [NSLayoutConstraint activateConstraints:@[
        [container.centerXAnchor constraintEqualToAnchor:self.collectionView.centerXAnchor],
        [container.centerYAnchor constraintEqualToAnchor:self.collectionView.centerYAnchor constant:-18.0],
        [container.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:36.0],
        [container.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-36.0],

        [iconView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [iconView.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [iconView.widthAnchor constraintEqualToConstant:48.0],
        [iconView.heightAnchor constraintEqualToConstant:48.0],

        [titleLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:18.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    self.emptyStateView = container;
    self.emptyStateIconView = iconView;
    self.emptyTitleLabel = titleLabel;
    self.emptySubtitleLabel = subtitleLabel;
}

#pragma mark - UISearchControllerDelegate

- (void)didDismissSearchController:(UISearchController *)searchController
{
    [self resetSearchState];
}

#pragma mark - UISearchBarDelegate

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self resetSearchState];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    NSString *query = [self normalizedQueryFromRawString:searchController.searchBar.text];

    if (query.length < kPPSearchMinimumQueryLength) {
        [self resetSearchState];
        return;
    }

    if ([query isEqualToString:self.lastQuery]) {
        return;
    }

    self.lastQuery = query;
    [self updateHeaderStateAnimated:YES];
    [self performSearchDebounced:query];
}

#pragma mark - Search Flow

- (void)warmUpSearchCacheIfNeeded
{
    __weak typeof(self) weakSelf = self;
    [[SearchCacheManager shared] warmUpCacheIfNeeded:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        NSString *query = [strongSelf normalizedQueryFromRawString:strongSelf.searchController.searchBar.text];
        if (query.length >= kPPSearchMinimumQueryLength &&
            ![query isEqualToString:strongSelf.lastQuery]) {
            strongSelf.lastQuery = query;
            [strongSelf updateHeaderStateAnimated:NO];
            [strongSelf executeSearchForQuery:query];
        }
    }];
}

- (void)performSearchDebounced:(NSString *)query
{
    if (self.pendingDebounceBlock) {
        dispatch_block_cancel(self.pendingDebounceBlock);
        self.pendingDebounceBlock = nil;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_block_t block = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf executeSearchForQuery:query];
    });

    self.pendingDebounceBlock = block;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPPSearchDebounceDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   block);
}

- (void)executeSearchForQuery:(NSString *)query
{
    if (query.length < kPPSearchMinimumQueryLength) {
        [self resetSearchState];
        return;
    }

    [self pp_showSkeletonIfNeeded];

    NSInteger requestID = self.currentSearchRequestID + 1;
    self.currentSearchRequestID = requestID;
    NSString *searchToken = [query copy];

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.searchQueue, ^{
        NSArray *items = [[SearchCacheManager shared] searchWithQuery:searchToken];
        NSArray *rankedItems = [self rankedResultsFromItems:items query:searchToken];

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            BOOL isStaleRequest = (requestID != strongSelf.currentSearchRequestID);
            BOOL isDifferentQuery = ![strongSelf.lastQuery isEqualToString:searchToken];
            if (isStaleRequest || isDifferentQuery) {
                return;
            }

            strongSelf.allSearchResults = rankedItems ?: @[];
            [strongSelf updateSegmentBadgesWithItems:strongSelf.allSearchResults];
            [strongSelf applySegmentFilter];
            [strongSelf pp_hideSkeleton];
        });
    });
}

- (NSArray<id> *)rankedResultsFromItems:(NSArray<id> *)items query:(NSString *)query
{
    if (items.count <= 1) {
        return items ?: @[];
    }

    return [items sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        PPSearchRank rank1 = [PPSearchHelper pp_rankForText:[self searchableTextForObject:obj1] query:query];
        PPSearchRank rank2 = [PPSearchHelper pp_rankForText:[self searchableTextForObject:obj2] query:query];

        if (rank1 < rank2) return NSOrderedAscending;
        if (rank1 > rank2) return NSOrderedDescending;

        NSString *title1 = [self displayTitleForObject:obj1];
        NSString *title2 = [self displayTitleForObject:obj2];
        NSComparisonResult titleCompare = [title1 localizedCaseInsensitiveCompare:title2];
        if (titleCompare != NSOrderedSame) {
            return titleCompare;
        }

        NSString *id1 = [self stableIdentifierForObject:obj1];
        NSString *id2 = [self stableIdentifierForObject:obj2];
        return [id1 compare:id2];
    }];
}

- (NSString *)normalizedQueryFromRawString:(nullable NSString *)rawText
{
    if (![rawText isKindOfClass:NSString.class]) {
        return @"";
    }

    NSString *trimmed = [rawText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed ?: @"";
}

- (void)resetSearchState
{
    if (self.pendingDebounceBlock) {
        dispatch_block_cancel(self.pendingDebounceBlock);
        self.pendingDebounceBlock = nil;
    }

    self.currentSearchRequestID += 1;
    self.lastQuery = nil;
    self.allSearchResults = @[];
    self.results = @[];
    [self pp_hideSkeleton];
    [self pp_hideAllBadges];
    [self applyResultsAnimated:NO];
    [self updateEmptyState];
    [self updateHeaderStateAnimated:YES];
}

#pragma mark - Segment Filtering

- (void)searchSegmentChanged
{
    [self applySegmentFilter];
}

- (void)applySegmentFilter
{
    NSInteger selectedIndex = self.searchSegment.selectedSegmentIndex;
    if (selectedIndex < PPSearchSegmentAds || selectedIndex > PPSearchSegmentAccessories) {
        selectedIndex = PPSearchSegmentAds;
    }

    NSMutableArray<id> *filteredItems = [NSMutableArray array];
    for (id obj in self.allSearchResults) {
        if ([self object:obj belongsToSegment:selectedIndex]) {
            [filteredItems addObject:obj];
        }
    }

    [self buildViewModelsFromResults:filteredItems];
}

- (BOOL)object:(id)obj belongsToSegment:(PPSearchSegment)segment
{
    switch (segment) {
        case PPSearchSegmentAds:
            return [obj isKindOfClass:PetAd.class];
        case PPSearchSegmentServices:
            return [obj isKindOfClass:ServiceModel.class];
        case PPSearchSegmentAccessories:
            return [obj isKindOfClass:PetAccessory.class];
    }
    return NO;
}

- (void)updateSegmentBadgesWithItems:(NSArray<id> *)items
{
    NSInteger adsCount = 0;
    NSInteger servicesCount = 0;
    NSInteger accessoriesCount = 0;

    for (id obj in items) {
        if ([obj isKindOfClass:PetAd.class]) {
            adsCount += 1;
        } else if ([obj isKindOfClass:ServiceModel.class]) {
            servicesCount += 1;
        } else if ([obj isKindOfClass:PetAccessory.class]) {
            accessoriesCount += 1;
        }
    }

    [self pp_updateBadge:self.adsBadge count:adsCount];
    [self pp_updateBadge:self.servicesBadge count:servicesCount];
    [self pp_updateBadge:self.accessoriesBadge count:accessoriesCount];
}

#pragma mark - View Models

- (void)buildViewModelsFromResults:(NSArray<id> *)results
{
    NSMutableArray<PPUniversalCellViewModel *> *viewModels = [NSMutableArray arrayWithCapacity:results.count];
    NSMutableSet<NSString *> *seenIdentifiers = [NSMutableSet setWithCapacity:results.count];

    for (id obj in results) {
        NSString *identifier = [self stableIdentifierForObject:obj];
        if (identifier.length > 0) {
            if ([seenIdentifiers containsObject:identifier]) {
                continue;
            }
            [seenIdentifiers addObject:identifier];
        }

        PPUniversalCellViewModel *viewModel = [self viewModelForObject:obj];
        if (viewModel) {
            [viewModels addObject:viewModel];
        }
    }

    self.results = viewModels.copy;
    [self applyResultsAnimated:YES];
    [self updateEmptyState];
    [self updateHeaderStateAnimated:YES];
}

- (nullable PPUniversalCellViewModel *)viewModelForObject:(id)obj
{
    if ([obj isKindOfClass:PetAd.class]) {
        return [[PPUniversalCellViewModel alloc] initWithModel:obj context:PPCellForAds];
    }

    if ([obj isKindOfClass:ServiceModel.class]) {
        return [[PPUniversalCellViewModel alloc] initWithModel:obj context:PPCellForServices];
    }

    if ([obj isKindOfClass:PetAccessory.class]) {
        return [[PPUniversalCellViewModel alloc] initWithModel:obj context:PPCellForMarket];
    }

    return nil;
}

- (void)applyResultsAnimated:(BOOL)animated
{
    NSDiffableDataSourceSnapshot<NSNumber *, PPUniversalCellViewModel *> *snapshot = [NSDiffableDataSourceSnapshot new];
    [snapshot appendSectionsWithIdentifiers:@[@(PPSearchSectionResults)]];
    if (self.results.count > 0) {
        [snapshot appendItemsWithIdentifiers:self.results];
    }
    [self.dataSource applySnapshot:snapshot animatingDifferences:animated];
}

#pragma mark - Helpers

- (void)updateHeaderStateAnimated:(BOOL)animated
{
    BOOL hasValidQuery = self.lastQuery.length >= kPPSearchMinimumQueryLength;
    NSString *segmentTitle = [self selectedSegmentTitle];
    NSString *statusText = nil;
    NSString *subtitleText = nil;
    NSString *countText = nil;
    BOOL showQueryPill = hasValidQuery;
    BOOL showCountPill = YES;

    self.eyebrowLabel.text = kLang(@"SearchHeroEyebrow");
    self.heroTitleLabel.text = kLang(@"SearchHeroTitle");

    if (!hasValidQuery) {
        statusText = kLang(@"SearchHeroReady");
        subtitleText = kLang(@"SearchHeroIdleSubtitle");
        countText = kLang(@"SearchHeroTypingHint");
    } else if (self.isSearching) {
        statusText = kLang(@"SearchHeroSearchingBadge");
        subtitleText = kLang(@"SearchHeroSearching");
        countText = [NSString stringWithFormat:kLang(@"SearchHeroResultsCountFormat"), (long)self.results.count];
    } else if (self.results.count > 0) {
        statusText = kLang(@"SearchHeroLive");
        subtitleText = [NSString stringWithFormat:kLang(@"SearchHeroResultsSubtitleFormat"),
                        (long)self.results.count,
                        self.lastQuery ?: @""];
        countText = [NSString stringWithFormat:kLang(@"SearchHeroResultsCountFormat"), (long)self.results.count];
    } else {
        statusText = kLang(@"SearchHeroReady");
        subtitleText = [NSString stringWithFormat:kLang(@"SearchNoResultsMessage_fmt"), self.lastQuery ?: @""];
        countText = [NSString stringWithFormat:kLang(@"SearchHeroResultsCountFormat"), (long)0];
    }

    [self setLabel:self.heroSubtitleLabel text:subtitleText animated:animated];
    [self setLabel:self.statusPillLabel text:statusText animated:animated];
    [self setLabel:self.scopePillLabel text:segmentTitle animated:animated];
    [self setLabel:self.countPillLabel text:countText animated:animated];
    [self setLabel:self.queryPillLabel text:(hasValidQuery ? self.lastQuery : @"") animated:animated];
    [self setPill:self.queryPillLabel hidden:!showQueryPill animated:animated];
    [self setPill:self.countPillLabel hidden:!showCountPill animated:animated];

    UIColor *statusBackground = self.isSearching
        ? [[UIColor colorWithRed:0.98 green:0.69 blue:0.31 alpha:1.0] colorWithAlphaComponent:0.24]
        : [AppPrimaryClr colorWithAlphaComponent:0.22];
    UIColor *statusForeground = self.isSearching
        ? [UIColor colorWithRed:1.0 green:0.94 blue:0.80 alpha:1.0]
        : [UIColor colorWithWhite:1.0 alpha:0.96];

    self.statusPillLabel.backgroundColor = statusBackground;
    self.statusPillLabel.textColor = statusForeground;
    self.scopePillLabel.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.countPillLabel.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.queryPillLabel.backgroundColor = [[UIColor colorWithRed:0.98 green:0.81 blue:0.54 alpha:1.0] colorWithAlphaComponent:0.18];
    self.queryPillLabel.textColor = [[UIColor colorWithRed:1.0 green:0.95 blue:0.83 alpha:1.0] colorWithAlphaComponent:0.95];
}

- (void)updateEmptyState
{
    BOOL hasValidQuery = self.lastQuery.length >= kPPSearchMinimumQueryLength;
    BOOL shouldShow = hasValidQuery && !self.isSearching && self.results.count == 0;

    if (shouldShow) {
        self.emptyTitleLabel.text = kLang(@"SearchNoResultsTitle");
        self.emptySubtitleLabel.text = [NSString stringWithFormat:kLang(@"SearchNoResultsMessage_fmt"), self.lastQuery ?: @""];
    }

    [self setEmptyStateVisible:shouldShow animated:YES];
}

- (NSString *)searchableTextForObject:(id)obj
{
    if ([obj isKindOfClass:PetAd.class]) {
        PetAd *ad = (PetAd *)obj;
        return ad.searchTitle ?: ad.adTitle ?: @"";
    }

    if ([obj isKindOfClass:PetAccessory.class]) {
        PetAccessory *accessory = (PetAccessory *)obj;
        return accessory.searchTitle ?: accessory.name ?: @"";
    }

    if ([obj isKindOfClass:ServiceModel.class]) {
        ServiceModel *service = (ServiceModel *)obj;
        return service.searchTitle ?: service.title ?: @"";
    }

    return @"";
}

- (NSString *)displayTitleForObject:(id)obj
{
    if ([obj isKindOfClass:PetAd.class]) {
        return ((PetAd *)obj).adTitle ?: @"";
    }

    if ([obj isKindOfClass:PetAccessory.class]) {
        return ((PetAccessory *)obj).name ?: @"";
    }

    if ([obj isKindOfClass:ServiceModel.class]) {
        return ((ServiceModel *)obj).title ?: @"";
    }

    return @"";
}

- (NSString *)stableIdentifierForObject:(id)obj
{
    if ([obj isKindOfClass:PetAd.class]) {
        return ((PetAd *)obj).adID ?: [NSString stringWithFormat:@"%p", obj];
    }

    if ([obj isKindOfClass:PetAccessory.class]) {
        return ((PetAccessory *)obj).accessoryID ?: [NSString stringWithFormat:@"%p", obj];
    }

    if ([obj isKindOfClass:ServiceModel.class]) {
        return ((ServiceModel *)obj).serviceID ?: [NSString stringWithFormat:@"%p", obj];
    }

    return [NSString stringWithFormat:@"%p", obj];
}

- (UILabel *)makeHeroPillLabel
{
    PPInsetLabel *label = [PPInsetLabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textInsets = UIEdgeInsetsMake(PPSpaceXS + 2.0, PPSpaceMD, PPSpaceXS + 2.0, PPSpaceMD);
    label.font = [GM MidFontWithSize:PPFontCaption1];
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor colorWithWhite:1.0 alpha:0.92];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    [label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [label setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    label.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    label.layer.cornerRadius = 14.0;
    label.layer.masksToBounds = YES;
    label.layer.borderWidth = 0.5;
    label.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.06].CGColor;
    [NSLayoutConstraint activateConstraints:@[
        [label.heightAnchor constraintEqualToConstant:28.0]
    ]];
    return label;
}

- (UILabel *)makeBadgeLabel
{
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [GM boldFontWithSize:11];
    label.textColor = UIColor.whiteColor;
    label.backgroundColor = AppPrimaryClr;
    label.layer.cornerRadius = 10.0;
    label.layer.masksToBounds = YES;
    label.alpha = 0.0;
    return label;
}

- (void)updateBadgePositions
{
    if (self.searchSegment.numberOfSegments <= 0) {
        return;
    }

    CGFloat segmentWidth = self.searchSegment.bounds.size.width / (CGFloat)self.searchSegment.numberOfSegments;
    self.adsBadgeCenterX.constant = segmentWidth * 0.5;
    self.servicesBadgeCenterX.constant = segmentWidth * 1.5;
    self.accessoriesBadgeCenterX.constant = segmentWidth * 2.5;
}

- (void)pp_hideAllBadges
{
    [self pp_updateBadge:self.adsBadge count:0];
    [self pp_updateBadge:self.servicesBadge count:0];
    [self pp_updateBadge:self.accessoriesBadge count:0];
}

- (void)pp_updateBadge:(UILabel *)badge count:(NSInteger)count
{
    if (count <= 0) {
        [UIView animateWithDuration:0.2 animations:^{
            badge.alpha = 0.0;
            badge.transform = CGAffineTransformMakeScale(0.8, 0.8);
        }];
        return;
    }

    badge.text = (count > 99) ? @"99+" : [NSString stringWithFormat:@"%ld", (long)count];
    if (badge.alpha > 0.01) {
        badge.transform = CGAffineTransformIdentity;
        return;
    }

    badge.transform = CGAffineTransformMakeScale(0.6, 0.6);
    [UIView animateWithDuration:0.25
                          delay:0.0
         usingSpringWithDamping:0.55
          initialSpringVelocity:0.8
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        badge.alpha = 1.0;
        badge.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        if (finished) {
            [PPFunc triggerLightHaptic];
        }
    }];
}

- (void)pp_showSkeletonIfNeeded
{
    if (self.isSearching) {
        return;
    }

    self.isSearching = YES;
    [self updateEmptyState];
    [self updateHeaderStateAnimated:YES];
}

- (void)pp_hideSkeleton
{
    self.isSearching = NO;
    [self updateEmptyState];
    [self updateHeaderStateAnimated:YES];
}

- (NSString *)selectedSegmentTitle
{
    NSInteger selectedIndex = self.searchSegment.selectedSegmentIndex;
    switch (selectedIndex) {
        case PPSearchSegmentServices:
            return kLang(@"services");
        case PPSearchSegmentAccessories:
            return kLang(@"Accessories");
        case PPSearchSegmentAds:
        default:
            return kLang(@"Ads");
    }
}

- (void)setLabel:(UILabel *)label text:(NSString *)text animated:(BOOL)animated
{
    NSString *safeText = text ?: @"";
    if ([label.text isEqualToString:safeText]) {
        return;
    }

    void (^changes)(void) = ^{
        label.text = safeText;
    };

    if (!animated) {
        changes();
        return;
    }

    [UIView transitionWithView:label
                      duration:0.22
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState
                    animations:changes
                    completion:nil];
}

- (void)setPill:(UILabel *)pill hidden:(BOOL)hidden animated:(BOOL)animated
{
    if (pill.hidden == hidden && fabs(pill.alpha - (hidden ? 0.0 : 1.0)) < 0.01) {
        return;
    }

    void (^changes)(void) = ^{
        pill.hidden = NO;
        pill.alpha = hidden ? 0.0 : 1.0;
        pill.transform = hidden ? CGAffineTransformMakeScale(0.92, 0.92) : CGAffineTransformIdentity;
    };

    void (^completion)(BOOL) = ^(BOOL finished) {
        if (finished) {
            pill.hidden = hidden;
        }
    };

    if (!animated) {
        changes();
        completion(YES);
        return;
    }

    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:changes
                     completion:completion];
}

- (void)setEmptyStateVisible:(BOOL)visible animated:(BOOL)animated
{
    if (visible == !self.emptyStateView.hidden &&
        fabs(self.emptyStateView.alpha - (visible ? 1.0 : 0.0)) < 0.01) {
        return;
    }

    void (^changes)(void) = ^{
        self.emptyStateView.hidden = NO;
        self.emptyStateView.alpha = visible ? 1.0 : 0.0;
        self.emptyStateView.transform = visible ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0.0, 10.0);
    };

    void (^completion)(BOOL) = ^(BOOL finished) {
        if (finished) {
            self.emptyStateView.hidden = !visible;
        }
    };

    if (!animated) {
        changes();
        completion(YES);
        return;
    }

    [UIView animateWithDuration:0.24
                          delay:0.0
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.42
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:changes
                     completion:completion];
}

- (void)animateHeroIfNeeded
{
    if (self.didAnimateHero) {
        return;
    }

    self.didAnimateHero = YES;
    NSArray<UIView *> *stagedViews = @[
        self.eyebrowLabel,
        self.heroTitleLabel,
        self.heroSubtitleLabel,
        self.metaStackView,
        self.segmentGlassView
    ];

    [stagedViews enumerateObjectsUsingBlock:^(UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 18.0 + (CGFloat)idx * 2.0);
        [UIView animateWithDuration:0.52
                              delay:0.05 * idx
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.72
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    self.primaryGlowView.alpha = 1.0;
    self.secondaryGlowView.alpha = 1.0;
    [UIView animateWithDuration:0.6 animations:^{
        self.primaryGlowView.alpha = 0.0;
        self.secondaryGlowView.alpha = 0.0;
    } completion:^(BOOL finished) {
        if (!finished) return;
        // Breathing animation — slow opacity pulse for ambient life
        CABasicAnimation *breathePrimary = [CABasicAnimation animationWithKeyPath:@"opacity"];
        breathePrimary.fromValue = @(0.14);
        breathePrimary.toValue = @(0.64);
        breathePrimary.duration = 3.8;
        breathePrimary.autoreverses = YES;
        breathePrimary.repeatCount = HUGE_VALF;
        breathePrimary.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.primaryGlowView.layer addAnimation:breathePrimary forKey:@"breathe"];

        CABasicAnimation *breatheSecondary = [CABasicAnimation animationWithKeyPath:@"opacity"];
        breatheSecondary.fromValue = @(0.10);
        breatheSecondary.toValue = @(0.68);
        breatheSecondary.duration = 4.2;
        breatheSecondary.autoreverses = YES;
        breatheSecondary.repeatCount = HUGE_VALF;
        breatheSecondary.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.secondaryGlowView.layer addAnimation:breatheSecondary forKey:@"breathe"];
        
        self.primaryGlowView.alpha = 1.0;
        self.secondaryGlowView.alpha = 1.0;
    }];
}

- (void)updateBackdropForOffset:(CGFloat)offset
{
    CGFloat positiveOffset = MAX(0.0, offset);
    CGFloat drift = MIN(positiveOffset, 180.0);

    self.primaryGlowView.transform = CGAffineTransformConcat(
        CGAffineTransformMakeTranslation(-drift * 0.12, drift * 0.10),
        CGAffineTransformMakeScale(1.0 + drift / 1200.0, 1.0 + drift / 1200.0)
    );
    self.secondaryGlowView.transform = CGAffineTransformConcat(
        CGAffineTransformMakeTranslation(drift * 0.10, -drift * 0.08),
        CGAffineTransformMakeScale(1.0 + drift / 1500.0, 1.0 + drift / 1500.0)
    );
}

#pragma mark - Visual Helpers

- (UIImage *)pp_noiseImageWithSize:(CGSize)size opacity:(CGFloat)opacity
{
    UIGraphicsBeginImageContextWithOptions(size, NO, 1.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) {
        UIGraphicsEndImageContext();
        return [UIImage new];
    }
    for (NSInteger y = 0; y < (NSInteger)size.height; y++) {
        for (NSInteger x = 0; x < (NSInteger)size.width; x++) {
            CGFloat v = arc4random_uniform(256) / 255.0;
            CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:v alpha:opacity].CGColor);
            CGContextFillRect(ctx, CGRectMake(x, y, 1.0, 1.0));
        }
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image ?: [UIImage new];
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat availableWidth = collectionView.bounds.size.width - (kPPSearchHorizontalInset * 2.0);
    NSInteger itemCount = [collectionView numberOfItemsInSection:indexPath.section];

    if (indexPath.item == 0) {
        CGFloat heroHeight = MIN(availableWidth * 0.78, 286.0);
        if (itemCount == 1) {
            heroHeight = MIN(availableWidth * 0.82, 310.0);
        }
        return CGSizeMake(availableWidth, MAX(heroHeight, 224.0));
    }

    CGFloat gridWidth = floor((availableWidth - kPPSearchInteritemSpacing) / 2.0);
    CGFloat itemHeight = gridWidth + 62.0;
    return CGSizeMake(gridWidth, itemHeight);
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self updateBackdropForOffset:scrollView.contentOffset.y];
}

#pragma mark - PPUniversalCellDelegate

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel
{
    if (!universalModel || !universalModel.ModelObject) {
        NSLog(@"[Search][TapCard] payload is nil");
        return;
    }

    [PPOverlayCoordinator pp_openDetailForObject:universalModel.ModelObject
                                          fromVC:self
                                      routingNav:nil];
}

@end
