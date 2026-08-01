//
//  AdoptPetsViewController.m
//  Pure Pets
//
//  Adoption browse — redesigned from scratch.
//  UIKit (Obj-C), code-only.
//
//  Defects fixed vs. previous revision:
//  - Collection now sits BELOW filterView (pinned to filterView.bottomAnchor),
//    so expanding filters pushes the grid down with zero overlap.
//  - Search uses a UITextField (single icon, single border, single surface) —
//    no more duplicate magnifying glasses or stacked borders from UISearchBar.
//  - Hero rebuilt as an editorial brand-wash banner (watermark + eyebrow chip +
//    bottom stat row), not a card-with-icon-plate.
//
//  Behaviour contracts preserved:
//  - Real-time AdoptPetManager listener (retained/removed on lifecycle).
//  - PPSearchFilterView kind/gender filtering + free-text search.
//  - PPUniversalCell masonry grid with owner edit/delete/visibility actions.
//  - Presents AdoptPetDetailsViewController as a large page sheet.
//  - Permission/blocked/login gates for adding a pet.
//  - Reduce Motion gating for every signature moment.
//

#import "AdoptPetsViewController.h"
#import "AddAdoptPetViewController.h"
#import "CartViewController.h"
#import "PPRolePermission.h"
#import "UserModel.h"
#import "PPSearchFilterView.h"

static NSString * const PPAdoptFilterKindKey   = @"kindID";
static NSString * const PPAdoptFilterGenderKey = @"gender";
static NSString * const PPAdoptGenderMaleValue   = @"male";
static NSString * const PPAdoptGenderFemaleValue = @"female";

/// Normalises raw gender strings (en/ar) into a stable compare value.
static NSString *PPAdoptNormalizedGenderValue(NSString *gender) {
    if (![gender isKindOfClass:NSString.class]) {
        return @"";
    }
    NSString *normalized = [[gender stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    if (normalized.length == 0) {
        return @"";
    }
    if ([normalized containsString:@"female"] ||
        [normalized containsString:@"انث"] ||
        [normalized containsString:@"أنث"] ||
        [normalized containsString:@"بنت"]) {
        return PPAdoptGenderFemaleValue;
    }
    if ([normalized containsString:@"male"] ||
        [normalized containsString:@"ذكر"] ||
        [normalized containsString:@"ولد"]) {
        return PPAdoptGenderMaleValue;
    }
    return normalized;
}

@interface AdoptPetsViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, PPUniversalCellDelegate, UITextFieldDelegate, PPSearchFilterViewDelegate>

#pragma mark - Surfaces
@property (nonatomic, strong) UIView *heroHeaderView;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) UIImageView *heroWatermarkView;
@property (nonatomic, strong) UILabel *heroEyebrowChip;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@property (nonatomic, strong) UIView *heroStatContainer;
@property (nonatomic, strong) UIImageView *heroStatIconView;
@property (nonatomic, strong) UILabel *heroCountLabel;

@property (nonatomic, strong) UIView *searchSurfaceView;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *filterButton;
@property (nonatomic, strong) UILabel *filterBadgeLabel;
@property (nonatomic, strong) PPSearchFilterView *filterView;
@property (nonatomic, strong) NSLayoutConstraint *filterHeightConstraint;

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UIImageView *emptyStateIconView;
@property (nonatomic, strong) UILabel *emptyStateTitleLabel;
@property (nonatomic, strong) UILabel *emptyStateSubtitleLabel;
@property (nonatomic, strong) UIButton *emptyStateActionButton;
@property (nonatomic, strong) UIView *loadingStateView;
@property (nonatomic, strong) UIImageView *loadingStateIconView;
@property (nonatomic, strong) UILabel *loadingStateLabel;

#pragma mark - State
@property (nonatomic, strong) NSMutableArray<AdoptPetModel *> *items;
@property (nonatomic, strong) NSMutableArray<AdoptPetModel *> *filteredItems;
@property (nonatomic, strong) id<FIRListenerRegistration> listener;
@property (nonatomic, copy)   NSString *filterContentSignature;
@property (nonatomic, assign) BOOL isFilterExpanded;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) BOOL hasReceivedInitialSnapshot;
@property (nonatomic, assign) BOOL isShowingLoadError;
@property (nonatomic, copy)   NSString *loadErrorMessage;
@property (nonatomic, assign) NSInteger lastDisplayedCount;
@end

@implementation AdoptPetsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.items = [NSMutableArray array];
    self.filteredItems = [NSMutableArray array];
    self.lastDisplayedCount = 0;

    [self pp_setupHeroHeader];
    [self pp_setupSearchField];
    [self pp_setupFilterView];
    [self pp_setupCollectionView];
    [self pp_setupEmptyState];
    [self pp_setupLoadingState];
    [self pp_prepareEntranceStateIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"AdoptPet") showBack:YES];
    [self pp_updateChromeForCurrentTraits];
    [self pp_prepareEntranceStateIfNeeded];
    [self startListening];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_animateEntranceIfNeeded];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_updateCollectionInsetsForBottomBar];
    if (self.heroGradientLayer) {
        self.heroGradientLayer.frame = self.heroHeaderView.bounds;
    }
    self.searchSurfaceView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.searchSurfaceView.bounds
                                   cornerRadius:self.searchSurfaceView.layer.cornerRadius].CGPath;
    self.emptyStateView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.emptyStateView.bounds
                                   cornerRadius:self.emptyStateView.layer.cornerRadius].CGPath;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self pp_stopListening];
}

- (void)dealloc {
    [self pp_stopListening];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_updateChromeForCurrentTraits];
        }
    }
}


#pragma mark - Hero (editorial brand-wash banner)

- (void)pp_setupHeroHeader {
    self.heroHeaderView = [[UIView alloc] init];
    self.heroHeaderView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroHeaderView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.heroHeaderView.clipsToBounds = YES;
    PPApplyContinuousCorners(self.heroHeaderView, PPCornerHero);
    [self.view addSubview:self.heroHeaderView];

    // Brand-wash gradient over the surface — warm canvas, single brand role.
    self.heroGradientLayer = [CAGradientLayer layer];
    self.heroGradientLayer.colors = @[
        (__bridge id)[AppPrimaryClr colorWithAlphaComponent:0.10].CGColor,
        (__bridge id)(AppForgroundColr ?: UIColor.secondarySystemBackgroundColor).CGColor
    ];
    self.heroGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.heroGradientLayer.endPoint = CGPointMake(0.9, 1.0);
    [self.heroHeaderView.layer insertSublayer:self.heroGradientLayer atIndex:0];

    // Faded paw watermark — brand proof, not accent spray.
    self.heroWatermarkView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"pawprint.fill"]];
    self.heroWatermarkView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroWatermarkView.contentMode = UIViewContentModeScaleAspectFit;
    self.heroWatermarkView.tintColor = [AppPrimaryClr colorWithAlphaComponent:0.07];
    [self.heroHeaderView addSubview:self.heroWatermarkView];

    // Eyebrow chip (pill with padded text container).
    self.heroEyebrowChip = [[UILabel alloc] init];
    self.heroEyebrowChip.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroEyebrowChip.font = [GM boldFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:PPFontCaption1 weight:UIFontWeightBold];
    self.heroEyebrowChip.textColor = AppPrimaryClr;
    self.heroEyebrowChip.textAlignment = NSTextAlignmentCenter;
    self.heroEyebrowChip.text = kLang(@"adopt_list_eyebrow");

    UIView *eyebrowContainer = [[UIView alloc] init];
    eyebrowContainer.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowContainer.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    eyebrowContainer.layer.cornerRadius = PPCornerPill;
    eyebrowContainer.layer.masksToBounds = YES;
    [eyebrowContainer addSubview:self.heroEyebrowChip];
    [self.heroHeaderView addSubview:eyebrowContainer];

    self.heroTitleLabel = [[UILabel alloc] init];
    self.heroTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTitleLabel.font = [GM boldFontWithSize:PPFontTitle1] ?: [UIFont systemFontOfSize:PPFontTitle1 weight:UIFontWeightBold];
    self.heroTitleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.heroTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroTitleLabel.numberOfLines = 1;
    self.heroTitleLabel.adjustsFontSizeToFitWidth = YES;
    self.heroTitleLabel.minimumScaleFactor = 0.8;
    self.heroTitleLabel.text = kLang(@"adopt_list_title");
    [self.heroHeaderView addSubview:self.heroTitleLabel];

    self.heroSubtitleLabel = [[UILabel alloc] init];
    self.heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSubtitleLabel.font = [GM MidFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:PPFontSubheadline weight:UIFontWeightMedium];
    self.heroSubtitleLabel.textColor = GM.SecondaryTextColor ?: UIColor.secondaryLabelColor;
    self.heroSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.heroSubtitleLabel.numberOfLines = 2;
    self.heroSubtitleLabel.text = kLang(@"adopt_list_subtitle");
    [self.heroHeaderView addSubview:self.heroSubtitleLabel];

    // Availability stat row — live brand proof.
    self.heroStatContainer = [[UIView alloc] init];
    self.heroStatContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroStatContainer.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    self.heroStatContainer.layer.cornerRadius = PPCornerPill;
    self.heroStatContainer.layer.masksToBounds = YES;
    [self.heroHeaderView addSubview:self.heroStatContainer];

    self.heroStatIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"heart.fill"]];
    self.heroStatIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroStatIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.heroStatIconView.tintColor = AppPrimaryClr;
    [self.heroStatContainer addSubview:self.heroStatIconView];

    self.heroCountLabel = [[UILabel alloc] init];
    self.heroCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroCountLabel.font = [GM boldFontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:PPFontFootnote weight:UIFontWeightBold];
    self.heroCountLabel.textColor = AppPrimaryClr;
    self.heroCountLabel.textAlignment = NSTextAlignmentCenter;
    NSString *countFormat = kLang(@"adopt_list_count_format");
    if (countFormat.length == 0) {
        countFormat = @"%ld";
    }
    self.heroCountLabel.text = [NSString stringWithFormat:countFormat, (long)0];
    [self.heroStatContainer addSubview:self.heroCountLabel];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.heroHeaderView.topAnchor constraintEqualToAnchor:safe.topAnchor constant:PPSpaceSM],
        [self.heroHeaderView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [self.heroHeaderView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [self.heroHeaderView.heightAnchor constraintEqualToConstant:156.0],

        [self.heroWatermarkView.trailingAnchor constraintEqualToAnchor:self.heroHeaderView.trailingAnchor constant:-PPSpaceBase],
        [self.heroWatermarkView.centerYAnchor constraintEqualToAnchor:self.heroHeaderView.centerYAnchor],
        [self.heroWatermarkView.widthAnchor constraintEqualToConstant:128.0],
        [self.heroWatermarkView.heightAnchor constraintEqualToConstant:128.0],

        [eyebrowContainer.topAnchor constraintEqualToAnchor:self.heroHeaderView.topAnchor constant:PPSpaceBase],
        [eyebrowContainer.leadingAnchor constraintEqualToAnchor:self.heroHeaderView.leadingAnchor constant:PPSpaceBase],
        [eyebrowContainer.heightAnchor constraintEqualToConstant:26.0],
        [eyebrowContainer.widthAnchor constraintGreaterThanOrEqualToConstant:76.0],

        [self.heroEyebrowChip.topAnchor constraintEqualToAnchor:eyebrowContainer.topAnchor],
        [self.heroEyebrowChip.bottomAnchor constraintEqualToAnchor:eyebrowContainer.bottomAnchor],
        [self.heroEyebrowChip.leadingAnchor constraintEqualToAnchor:eyebrowContainer.leadingAnchor constant:14.0],
        [self.heroEyebrowChip.trailingAnchor constraintEqualToAnchor:eyebrowContainer.trailingAnchor constant:-14.0],

        [self.heroTitleLabel.topAnchor constraintEqualToAnchor:eyebrowContainer.bottomAnchor constant:PPSpaceSM],
        [self.heroTitleLabel.leadingAnchor constraintEqualToAnchor:self.heroHeaderView.leadingAnchor constant:PPSpaceBase],
        [self.heroTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroWatermarkView.leadingAnchor constant:-PPSpaceSM],

        [self.heroSubtitleLabel.topAnchor constraintEqualToAnchor:self.heroTitleLabel.bottomAnchor constant:PPSpaceXS],
        [self.heroSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.heroHeaderView.leadingAnchor constant:PPSpaceBase],
        [self.heroSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.heroHeaderView.trailingAnchor constant:-PPSpaceBase],

        [self.heroStatContainer.bottomAnchor constraintEqualToAnchor:self.heroHeaderView.bottomAnchor constant:-PPSpaceBase],
        [self.heroStatContainer.leadingAnchor constraintEqualToAnchor:self.heroHeaderView.leadingAnchor constant:PPSpaceBase],
        [self.heroStatContainer.heightAnchor constraintEqualToConstant:30.0],

        [self.heroStatIconView.leadingAnchor constraintEqualToAnchor:self.heroStatContainer.leadingAnchor constant:10.0],
        [self.heroStatIconView.centerYAnchor constraintEqualToAnchor:self.heroStatContainer.centerYAnchor],
        [self.heroStatIconView.widthAnchor constraintEqualToConstant:14.0],
        [self.heroStatIconView.heightAnchor constraintEqualToConstant:14.0],

        [self.heroCountLabel.leadingAnchor constraintEqualToAnchor:self.heroStatIconView.trailingAnchor constant:6.0],
        [self.heroCountLabel.trailingAnchor constraintEqualToAnchor:self.heroStatContainer.trailingAnchor constant:-12.0],
        [self.heroCountLabel.centerYAnchor constraintEqualToAnchor:self.heroStatContainer.centerYAnchor]
    ]];

    [eyebrowContainer setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.heroStatContainer setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
}

#pragma mark - Search (single-surface UITextField — no duplicate chrome)

- (void)pp_setupSearchField {
    self.searchSurfaceView = [[UIView alloc] init];
    self.searchSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchSurfaceView.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    self.searchSurfaceView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    PPApplyContinuousCorners(self.searchSurfaceView, PPCornerCard);
    [self.searchSurfaceView pp_setShadowColor:UIColor.blackColor];
    self.searchSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    self.searchSurfaceView.layer.shadowRadius = 18.0;
    self.searchSurfaceView.layer.shadowOpacity = 0.07;
    self.searchSurfaceView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    [self.searchSurfaceView pp_setBorderColor:[[UIColor separatorColor] colorWithAlphaComponent:0.24]];
    [self.view addSubview:self.searchSurfaceView];

    // Single magnifying glass (leftView of the text field). RTL-safe.
    self.searchField = [[UITextField alloc] init];
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchField.delegate = self;
    self.searchField.borderStyle = UITextBorderStyleNone;
    self.searchField.backgroundColor = UIColor.clearColor;
    self.searchField.font = [GM MidFontWithSize:PPFontBody] ?: [UIFont systemFontOfSize:PPFontBody weight:UIFontWeightMedium];
    self.searchField.placeholder = kLang(@"SearchHere");
    self.searchField.returnKeyType = UIReturnKeySearch;
    self.searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.searchField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchField.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIImageView *searchIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]];
    searchIconView.tintColor = [GM.SecondaryTextColor colorWithAlphaComponent:0.70];
    searchIconView.contentMode = UIViewContentModeScaleAspectFit;
    searchIconView.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 20)];
    [leftView addSubview:searchIconView];
    [NSLayoutConstraint activateConstraints:@[
        [searchIconView.leadingAnchor constraintEqualToAnchor:leftView.leadingAnchor constant:4.0],
        [searchIconView.centerYAnchor constraintEqualToAnchor:leftView.centerYAnchor],
        [searchIconView.widthAnchor constraintEqualToConstant:18.0],
        [searchIconView.heightAnchor constraintEqualToConstant:18.0]
    ]];
    self.searchField.leftView = leftView;
    self.searchField.leftViewMode = UITextFieldViewModeAlways;
    [self.searchField addTarget:self action:@selector(pp_searchFieldDidChange) forControlEvents:UIControlEventEditingChanged];
    [self.searchSurfaceView addSubview:self.searchField];

    self.filterButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.filterButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.filterButton.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    UIImageSymbolConfiguration *filterSymbolCfg =
        [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightMedium];
    UIImage *filterSymbol = [[UIImage systemImageNamed:@"line.3.horizontal.decrease"]
        imageByApplyingSymbolConfiguration:filterSymbolCfg];
    [self.filterButton setImage:filterSymbol forState:UIControlStateNormal];
    PPApplyContinuousCorners(self.filterButton, PPCornerPill);
    self.filterButton.layer.masksToBounds = YES;
    self.filterButton.accessibilityLabel = kLang(@"Filter");
    [self.filterButton addTarget:self action:@selector(pp_filterButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.filterButton addTarget:self action:@selector(pp_filterButtonTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    [self.filterButton addTarget:self action:@selector(pp_filterButtonTouchUp:) forControlEvents:UIControlEventTouchDragExit | UIControlEventTouchCancel | UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self.searchSurfaceView addSubview:self.filterButton];

    self.filterBadgeLabel = [[UILabel alloc] init];
    self.filterBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.filterBadgeLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    self.filterBadgeLabel.textColor = UIColor.whiteColor;
    self.filterBadgeLabel.backgroundColor = AppErrorClr ?: UIColor.systemRedColor;
    self.filterBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.filterBadgeLabel.layer.cornerRadius = 8.0;
    self.filterBadgeLabel.layer.masksToBounds = YES;
    self.filterBadgeLabel.hidden = YES;
    [self.filterButton addSubview:self.filterBadgeLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.searchSurfaceView.topAnchor constraintEqualToAnchor:self.heroHeaderView.bottomAnchor constant:PPSpaceMD],
        [self.searchSurfaceView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [self.searchSurfaceView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [self.searchSurfaceView.heightAnchor constraintEqualToConstant:56.0],

        [self.searchField.leadingAnchor constraintEqualToAnchor:self.searchSurfaceView.leadingAnchor constant:PPSpaceBase],
        [self.searchField.topAnchor constraintEqualToAnchor:self.searchSurfaceView.topAnchor],
        [self.searchField.bottomAnchor constraintEqualToAnchor:self.searchSurfaceView.bottomAnchor],
        [self.searchField.trailingAnchor constraintEqualToAnchor:self.filterButton.leadingAnchor constant:-PPSpaceSM],

        [self.filterButton.trailingAnchor constraintEqualToAnchor:self.searchSurfaceView.trailingAnchor constant:-PPSpaceSM],
        [self.filterButton.centerYAnchor constraintEqualToAnchor:self.searchSurfaceView.centerYAnchor],
        [self.filterButton.widthAnchor constraintEqualToConstant:PPTouchTargetMin],
        [self.filterButton.heightAnchor constraintEqualToConstant:PPTouchTargetMin],

        [self.filterBadgeLabel.topAnchor constraintEqualToAnchor:self.filterButton.topAnchor constant:3.0],
        [self.filterBadgeLabel.trailingAnchor constraintEqualToAnchor:self.filterButton.trailingAnchor constant:-3.0],
        [self.filterBadgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:16.0],
        [self.filterBadgeLabel.heightAnchor constraintEqualToConstant:16.0]
    ]];
    [self pp_updateChromeForCurrentTraits];
    [self pp_updateFilterButtonAppearanceAnimated:NO];
}

- (void)pp_setupFilterView {
    self.filterView = [[PPSearchFilterView alloc] init];
    self.filterView.translatesAutoresizingMaskIntoConstraints = NO;
    self.filterView.delegate = self;
    self.filterView.clipsToBounds = YES;
    self.filterView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:self.filterView];

    self.filterHeightConstraint = [self.filterView.heightAnchor constraintEqualToConstant:0];
    [NSLayoutConstraint activateConstraints:@[
        [self.filterView.topAnchor constraintEqualToAnchor:self.searchSurfaceView.bottomAnchor constant:PPSpaceSM],
        [self.filterView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [self.filterView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        self.filterHeightConstraint
    ]];
}

#pragma mark - Chrome + Entrance

- (void)pp_updateChromeForCurrentTraits {
    if (!self.searchSurfaceView) {
        return;
    }
    self.searchField.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.searchField.tintColor = AppPrimaryClr;
    self.searchField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:kLang(@"SearchHere")
            attributes:@{
                NSForegroundColorAttributeName: AppTertiaryTextClr ?: UIColor.placeholderTextColor
            }];
}

- (void)pp_prepareEntranceStateIfNeeded {
    if (self.didAnimateEntrance || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    self.heroHeaderView.alpha = 0.0;
    self.heroHeaderView.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    self.searchSurfaceView.alpha = 0.0;
    self.searchSurfaceView.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
    self.collectionView.alpha = 0.0;
    self.collectionView.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
}

- (void)pp_animateEntranceIfNeeded {
    if (self.didAnimateEntrance || !self.searchSurfaceView) {
        return;
    }
    self.didAnimateEntrance = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.heroHeaderView.alpha = 1.0;
        self.heroHeaderView.transform = CGAffineTransformIdentity;
        self.searchSurfaceView.alpha = 1.0;
        self.searchSurfaceView.transform = CGAffineTransformIdentity;
        self.collectionView.alpha = 1.0;
        self.collectionView.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:PPAnimDurationSlow
                          delay:0.02
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.16
                         options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                      animations:^{
        self.heroHeaderView.alpha = 1.0;
        self.heroHeaderView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:PPAnimDurationSlow
                          delay:0.08
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.14
                         options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                      animations:^{
        self.searchSurfaceView.alpha = 1.0;
        self.searchSurfaceView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.34
                          delay:0.16
                         options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                      animations:^{
        self.collectionView.alpha = 1.0;
        self.collectionView.transform = CGAffineTransformIdentity;
    } completion:nil];
}


#pragma mark - Filter Button

- (void)pp_filterButtonTapped {
    self.isFilterExpanded = !self.isFilterExpanded;
    [self pp_rebuildFilterContentIfNeeded:YES];

    if (!self.isFilterExpanded) {
        [self.filterView resetAll];
        [self pp_applySearchAndFilter];
    }

    [self.view layoutIfNeeded];
    [UIView animateWithDuration:PPAnimDurationNormal
                          delay:0.0
         usingSpringWithDamping:PPAnimSpringDamping
          initialSpringVelocity:0.4
                         options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                      animations:^{
        if (self.isFilterExpanded) {
            self.filterHeightConstraint.constant = [self.filterView systemLayoutSizeFittingSize:CGSizeMake(self.view.bounds.size.width, UILayoutFittingCompressedSize.height)
                                                   withHorizontalFittingPriority:UILayoutPriorityRequired
                                                         verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
        } else {
            self.filterHeightConstraint.constant = 0;
        }
        [self.view layoutIfNeeded];
    } completion:nil];

    [self pp_updateFilterButtonAppearanceAnimated:YES];
}

- (void)pp_filterButtonTouchDown:(UIButton *)button {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    [UIView animateWithDuration:PPAnimDurationFast
                          delay:0.0
                         options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                      animations:^{
        button.transform = CGAffineTransformMakeScale(0.94, 0.94);
    } completion:nil];
}

- (void)pp_filterButtonTouchUp:(UIButton *)button {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        button.transform = CGAffineTransformIdentity;
        return;
    }
    [UIView animateWithDuration:PPAnimDurationNormal
                          delay:0.0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.28
                         options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                      animations:^{
        button.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_updateFilterButtonAppearanceAnimated:(BOOL)animated {
    NSUInteger activeCount = [self.filterView activeFilters].count;
    BOOL active = self.isFilterExpanded || activeCount > 0;
    UIColor *foreground = active ? UIColor.whiteColor : AppPrimaryClr;
    UIColor *background = active
        ? [AppPrimaryClr colorWithAlphaComponent:0.92]
        : [AppPrimaryClr colorWithAlphaComponent:0.10];

    void (^updates)(void) = ^{
        self.filterButton.backgroundColor = background;
        self.filterButton.tintColor = foreground;
        self.filterBadgeLabel.hidden = (activeCount == 0);
        self.filterBadgeLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)activeCount];
    };

    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:PPAnimDurationNormal animations:updates];
    } else {
        updates();
    }
}

#pragma mark - Filter Content

- (void)pp_rebuildFilterContentIfNeeded:(BOOL)force {
    NSArray<NSDictionary *> *kindItems = [self pp_kindFilterItems];
    NSArray<NSDictionary *> *genderItems = [self pp_genderFilterItems];
    NSString *signature = [self pp_filterSignatureForKindItems:kindItems genderItems:genderItems];

    if (!force && self.filterContentSignature && [self.filterContentSignature isEqualToString:signature]) {
        return;
    }

    self.filterContentSignature = signature;
    [self.filterView removeAllSections];
    if (kindItems.count > 0) {
        [self.filterView addSectionWithTitle:kLang(@"Kind") items:kindItems key:PPAdoptFilterKindKey allowMultiple:NO];
    }
    if (genderItems.count > 0) {
        [self.filterView addSectionWithTitle:kLang(@"Gender") items:genderItems key:PPAdoptFilterGenderKey allowMultiple:NO];
    }
    [self.filterView addResetButtonWithTitle:kLang(@"Reset")];
}

- (NSArray<NSDictionary *> *)pp_kindFilterItems {
    NSMutableArray<MainKindsModel *> *availableKinds = [NSMutableArray array];
    for (AdoptPetModel *pet in self.items) {
        if (pet.kindID <= 0) {
            continue;
        }
        MainKindsModel *kindModel = [MainKindsModel mainKindModelForID:pet.kindID];
        if (kindModel && !kindModel.isVisibleInUserApp) {
            continue;
        }
        if (![availableKinds containsObject:kindModel]) {
            [availableKinds addObject:kindModel];
        }
    }

    if (availableKinds.count > 0) {
        NSArray<MainKindsModel *> *sortedKinds = [availableKinds sortedArrayUsingComparator:^NSComparisonResult(MainKindsModel *first, MainKindsModel *second) {
            if (first.sortingKey != second.sortingKey) {
                return first.sortingKey < second.sortingKey ? NSOrderedAscending : NSOrderedDescending;
            }
            NSString *firstTitle = first.KindName ?: @"";
            NSString *secondTitle = second.KindName ?: @"";
            return [firstTitle localizedCaseInsensitiveCompare:secondTitle];
        }];

        NSMutableArray<NSDictionary *> *items = [NSMutableArray arrayWithCapacity:sortedKinds.count];
        for (MainKindsModel *kind in sortedKinds) {
            NSString *title = kind.KindName.length > 0 ? kind.KindName : [MainKindsModel kindNameForID:kind.ID];
            if (title.length > 0) {
                [items addObject:@{ @"id": @(kind.ID), @"title": title }];
            }
        }
        return items;
    }

    NSMutableDictionary<NSNumber *, NSString *> *fallbackKinds = [NSMutableDictionary dictionary];
    for (AdoptPetModel *pet in self.items) {
        if (pet.kindID <= 0) {
            continue;
        }
        MainKindsModel *kindModel = [MainKindsModel mainKindModelForID:pet.kindID];
        if (kindModel && !kindModel.isVisibleInUserApp) {
            continue;
        }
        NSString *title = [MainKindsModel kindNameForID:pet.kindID];
        if (title.length == 0) {
            title = kindModel.KindName.length > 0 ? kindModel.KindName : pet.mainKindModel.KindName;
        }
        if (title.length > 0) {
            fallbackKinds[@(pet.kindID)] = title;
        }
    }

    NSArray<NSNumber *> *sortedIDs = [fallbackKinds.allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray<NSDictionary *> *items = [NSMutableArray arrayWithCapacity:sortedIDs.count];
    for (NSNumber *kindID in sortedIDs) {
        NSString *title = fallbackKinds[kindID];
        if (title.length > 0) {
            [items addObject:@{ @"id": kindID, @"title": title }];
        }
    }
    return items;
}

- (NSArray<NSDictionary *> *)pp_genderFilterItems {
    return @[
        @{ @"id": PPAdoptGenderMaleValue,   @"title": kLang(@"Male") },
        @{ @"id": PPAdoptGenderFemaleValue, @"title": kLang(@"Female") },
    ];
}

- (NSString *)pp_filterSignatureForKindItems:(NSArray<NSDictionary *> *)kindItems genderItems:(NSArray<NSDictionary *> *)genderItems {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSDictionary *item in kindItems) {
        [parts addObject:[NSString stringWithFormat:@"k:%@:%@", item[@"id"] ?: @"", item[@"title"] ?: @""]];
    }
    for (NSDictionary *item in genderItems) {
        [parts addObject:[NSString stringWithFormat:@"g:%@:%@", item[@"id"] ?: @"", item[@"title"] ?: @""]];
    }
    return [parts componentsJoinedByString:@"|"];
}

#pragma mark - UITextFieldDelegate + Filtering

- (void)pp_searchFieldDidChange {
    [self pp_applySearchAndFilter];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)searchFilterView:(PPSearchFilterView *)view didSelectFilters:(NSDictionary *)filters {
    [self pp_applySearchAndFilterWithFilters:filters];
    [self pp_updateFilterButtonAppearanceAnimated:YES];
}

- (void)searchFilterViewDidReset:(PPSearchFilterView *)view {
    [self pp_applySearchAndFilter];
    [self pp_updateFilterButtonAppearanceAnimated:YES];
}

- (void)pp_applySearchAndFilter {
    [self pp_applySearchAndFilterWithFilters:nil];
}

- (void)pp_applySearchAndFilterWithFilters:(NSDictionary *)extraFilters {
    NSString *query = self.searchField.text ? [self.searchField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] : @"";
    NSDictionary *activeFilters = extraFilters ?: [self.filterView activeFilters];

    if (query.length == 0 && activeFilters.count == 0) {
        self.filteredItems = [self.items mutableCopy];
    } else {
        NSMutableArray *filtered = [NSMutableArray array];
        for (AdoptPetModel *pet in self.items) {
            BOOL matchesQuery = YES;
            if (query.length > 0) {
                NSString *kindName = pet.mainKindModel.KindName.length > 0 ? pet.mainKindModel.KindName : [MainKindsModel kindNameForID:pet.kindID];
                NSString *normalizedGender = PPAdoptNormalizedGenderValue(pet.gender);
                NSString *genderName = @"";
                if ([normalizedGender isEqualToString:PPAdoptGenderFemaleValue]) {
                    genderName = kLang(@"Female");
                } else if ([normalizedGender isEqualToString:PPAdoptGenderMaleValue]) {
                    genderName = kLang(@"Male");
                }
                NSString *searchSpace = [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@",
                    pet.name ?: @"",
                    pet.details ?: @"",
                    pet.mCityName ?: @"",
                    pet.subKindModel.SubKindName ?: @"",
                    kindName ?: @"",
                    genderName ?: @""].lowercaseString;
                matchesQuery = [searchSpace containsString:query.lowercaseString];
            }

            BOOL matchesFilters = YES;
            if (activeFilters[PPAdoptFilterKindKey]) {
                NSInteger filterKind = [activeFilters[PPAdoptFilterKindKey] integerValue];
                if (pet.kindID != filterKind) matchesFilters = NO;
            }
            if (activeFilters[PPAdoptFilterGenderKey]) {
                NSString *filterGender = PPAdoptNormalizedGenderValue(activeFilters[PPAdoptFilterGenderKey]);
                NSString *petGender = PPAdoptNormalizedGenderValue(pet.gender);
                if (filterGender.length > 0 && ![petGender isEqualToString:filterGender]) matchesFilters = NO;
            }

            if (matchesQuery && matchesFilters) {
                [filtered addObject:pet];
            }
        }
        self.filteredItems = filtered;
    }

    [self.collectionView reloadData];
    [self pp_updateEmptyState];
}


#pragma mark - Collection (pinned BELOW filterView — no overlap)

- (void)pp_setupCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = PPSpaceMD;
    layout.minimumLineSpacing = PPSpaceMD;
    layout.sectionInset = UIEdgeInsetsMake(PPSpaceMD, PPSpaceMD, PPSpaceMD, PPSpaceMD);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.alwaysBounceVertical = YES;
    [PPUniversalCell pp_registerInCollectionView:self.collectionView];
    self.collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.view addSubview:self.collectionView];

    // Clean vertical chain: hero → search → filterView → collection.
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.filterView.bottomAnchor constant:PPSpaceMD],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)pp_updateCollectionInsetsForBottomBar {
    self.collectionView.contentInset = UIEdgeInsetsMake(0, 0, 100.0, 0);
    self.collectionView.scrollIndicatorInsets = self.collectionView.contentInset;
}

#pragma mark - Loading State

- (void)pp_setupLoadingState {
    self.loadingStateView = [[UIView alloc] init];
    self.loadingStateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingStateView.hidden = YES;
    [self.view addSubview:self.loadingStateView];

    self.loadingStateIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"pawprint.fill"]];
    self.loadingStateIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingStateIconView.tintColor = AppPrimaryClr;
    self.loadingStateIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.loadingStateView addSubview:self.loadingStateIconView];

    self.loadingStateLabel = [[UILabel alloc] init];
    self.loadingStateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingStateLabel.font = [GM MidFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:PPFontSubheadline weight:UIFontWeightMedium];
    self.loadingStateLabel.textColor = GM.SecondaryTextColor ?: UIColor.secondaryLabelColor;
    self.loadingStateLabel.textAlignment = NSTextAlignmentCenter;
    self.loadingStateLabel.text = kLang(@"adopt_list_loading");
    [self.loadingStateView addSubview:self.loadingStateLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.loadingStateView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingStateView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:40.0],
        [self.loadingStateIconView.centerXAnchor constraintEqualToAnchor:self.loadingStateView.centerXAnchor],
        [self.loadingStateIconView.topAnchor constraintEqualToAnchor:self.loadingStateView.topAnchor],
        [self.loadingStateIconView.widthAnchor constraintEqualToConstant:34.0],
        [self.loadingStateIconView.heightAnchor constraintEqualToConstant:34.0],
        [self.loadingStateLabel.topAnchor constraintEqualToAnchor:self.loadingStateIconView.bottomAnchor constant:PPSpaceSM],
        [self.loadingStateLabel.leadingAnchor constraintEqualToAnchor:self.loadingStateView.leadingAnchor],
        [self.loadingStateLabel.trailingAnchor constraintEqualToAnchor:self.loadingStateView.trailingAnchor],
        [self.loadingStateLabel.bottomAnchor constraintEqualToAnchor:self.loadingStateView.bottomAnchor]
    ]];
}

- (void)pp_updateLoadingStateVisible {
    BOOL showLoading = !self.hasReceivedInitialSnapshot && !self.isShowingLoadError;
    self.loadingStateView.hidden = !showLoading;
    if (showLoading && !UIAccessibilityIsReduceMotionEnabled() && self.loadingStateIconView.layer.animationKeys.count == 0) {
        [UIView animateWithDuration:0.7
                              delay:0.0
                            options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.loadingStateIconView.alpha = 0.25;
        } completion:nil];
    } else {
        [self.loadingStateIconView.layer removeAllAnimations];
        self.loadingStateIconView.alpha = 1.0;
    }
}

#pragma mark - Empty State

- (void)pp_setupEmptyState {
    self.emptyStateView = [[UIView alloc] init];
    self.emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyStateView.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    self.emptyStateView.hidden = YES;
    self.emptyStateView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    PPApplyContinuousCorners(self.emptyStateView, PPCornerHero);
    [self.emptyStateView pp_setShadowColor:UIColor.blackColor];
    self.emptyStateView.layer.shadowOpacity = 0.04;
    self.emptyStateView.layer.shadowRadius = 18.0;
    self.emptyStateView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [self.view addSubview:self.emptyStateView];

    UIView *iconPlate = [[UIView alloc] init];
    iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
    iconPlate.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    iconPlate.layer.cornerRadius = 25.0;
    iconPlate.layer.masksToBounds = YES;
    [self.emptyStateView addSubview:iconPlate];

    self.emptyStateIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"pawprint.fill"]];
    self.emptyStateIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyStateIconView.tintColor = AppPrimaryClr;
    self.emptyStateIconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconPlate addSubview:self.emptyStateIconView];

    self.emptyStateTitleLabel = [[UILabel alloc] init];
    self.emptyStateTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyStateTitleLabel.numberOfLines = 2;
    self.emptyStateTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyStateTitleLabel.font = [GM boldFontWithSize:PPFontTitle3] ?: [UIFont systemFontOfSize:PPFontTitle3 weight:UIFontWeightBold];
    self.emptyStateTitleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    [self.emptyStateView addSubview:self.emptyStateTitleLabel];

    self.emptyStateSubtitleLabel = [[UILabel alloc] init];
    self.emptyStateSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyStateSubtitleLabel.numberOfLines = 0;
    self.emptyStateSubtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyStateSubtitleLabel.font = [GM MidFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:PPFontSubheadline weight:UIFontWeightMedium];
    self.emptyStateSubtitleLabel.textColor = GM.SecondaryTextColor ?: UIColor.secondaryLabelColor;
    [self.emptyStateView addSubview:self.emptyStateSubtitleLabel];

    self.emptyStateActionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.emptyStateActionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyStateActionButton.titleLabel.font = [GM boldFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:PPFontSubheadline weight:UIFontWeightBold];
    [self.emptyStateActionButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.emptyStateActionButton.backgroundColor = AppPrimaryClr;
    PPApplyContinuousCorners(self.emptyStateActionButton, PPCornerPill);
    self.emptyStateActionButton.contentEdgeInsets = UIEdgeInsetsMake(10, 22, 10, 22);
    [self.emptyStateActionButton addTarget:self action:@selector(pp_emptyStateActionTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.emptyStateView addSubview:self.emptyStateActionButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.emptyStateView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyStateView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:24.0],
        [self.emptyStateView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:28.0],
        [self.emptyStateView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-28.0],

        [iconPlate.topAnchor constraintEqualToAnchor:self.emptyStateView.topAnchor constant:24.0],
        [iconPlate.centerXAnchor constraintEqualToAnchor:self.emptyStateView.centerXAnchor],
        [iconPlate.widthAnchor constraintEqualToConstant:50.0],
        [iconPlate.heightAnchor constraintEqualToConstant:50.0],

        [self.emptyStateIconView.centerXAnchor constraintEqualToAnchor:iconPlate.centerXAnchor],
        [self.emptyStateIconView.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],
        [self.emptyStateIconView.widthAnchor constraintEqualToConstant:24.0],
        [self.emptyStateIconView.heightAnchor constraintEqualToConstant:24.0],

        [self.emptyStateTitleLabel.topAnchor constraintEqualToAnchor:iconPlate.bottomAnchor constant:PPSpaceBase],
        [self.emptyStateTitleLabel.leadingAnchor constraintEqualToAnchor:self.emptyStateView.leadingAnchor constant:22.0],
        [self.emptyStateTitleLabel.trailingAnchor constraintEqualToAnchor:self.emptyStateView.trailingAnchor constant:-22.0],

        [self.emptyStateSubtitleLabel.topAnchor constraintEqualToAnchor:self.emptyStateTitleLabel.bottomAnchor constant:PPSpaceSM],
        [self.emptyStateSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.emptyStateView.leadingAnchor constant:24.0],
        [self.emptyStateSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.emptyStateView.trailingAnchor constant:-24.0],

        [self.emptyStateActionButton.topAnchor constraintEqualToAnchor:self.emptyStateSubtitleLabel.bottomAnchor constant:18.0],
        [self.emptyStateActionButton.centerXAnchor constraintEqualToAnchor:self.emptyStateView.centerXAnchor],
        [self.emptyStateActionButton.heightAnchor constraintEqualToConstant:40.0],
        [self.emptyStateActionButton.widthAnchor constraintGreaterThanOrEqualToConstant:142.0],
        [self.emptyStateActionButton.bottomAnchor constraintEqualToAnchor:self.emptyStateView.bottomAnchor constant:-24.0]
    ]];

    [self.view bringSubviewToFront:self.emptyStateView];
    [self.view bringSubviewToFront:self.loadingStateView];
}

#pragma mark - Listening

- (void)pp_stopListening {
    if (self.listener) {
        [self.listener remove];
        self.listener = nil;
    }
}

- (void)startListening {
    [self pp_stopListening];
    [self pp_updateLoadingStateVisible];

    __weak typeof(self) weakSelf = self;
    self.listener = [AdoptPetManager.shared observeAllPetsWithUpdate:^(NSArray<AdoptPetModel *> * _Nonnull pets, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            NSLog(@"[AdoptPets] listener error: %@", error.localizedDescription);
            strongSelf.isShowingLoadError = YES;
            strongSelf.loadErrorMessage = error.localizedDescription;
            strongSelf.hasReceivedInitialSnapshot = YES;
            [strongSelf pp_updateLoadingStateVisible];
            [strongSelf pp_updateEmptyState];
            return;
        }

        strongSelf.isShowingLoadError = NO;
        strongSelf.loadErrorMessage = nil;
        strongSelf.hasReceivedInitialSnapshot = YES;
        strongSelf.items = pets.mutableCopy ?: [NSMutableArray array];
        [strongSelf pp_rebuildFilterContentIfNeeded:NO];
        [strongSelf pp_applySearchAndFilter];
        [strongSelf pp_updateFilterButtonAppearanceAnimated:NO];
        [strongSelf pp_updateLoadingStateVisible];
        [strongSelf pp_updateEmptyState];
    }];
}

- (void)pp_updateEmptyState {
    [self pp_updateHeroCount];

    BOOL hasVisibleData = self.filteredItems.count > 0;
    BOOL showError = self.isShowingLoadError && !hasVisibleData;
    BOOL showEmpty = !hasVisibleData && self.hasReceivedInitialSnapshot;
    BOOL show = showError || showEmpty;
    self.emptyStateView.hidden = !show;
    self.collectionView.hidden = show && self.filteredItems.count == 0;
    if (!show) {
        return;
    }

    if (showError) {
        self.emptyStateIconView.image = [UIImage systemImageNamed:@"wifi.exclamationmark"];
        self.emptyStateTitleLabel.text = kLang(@"adopt_list_error_title");
        self.emptyStateSubtitleLabel.text = self.loadErrorMessage.length > 0 ? self.loadErrorMessage : kLang(@"adopt_list_error_subtitle");
        [self.emptyStateActionButton setTitle:kLang(@"KLang_Retry") forState:UIControlStateNormal];
        self.emptyStateActionButton.hidden = NO;
        return;
    }

    BOOL hasActiveFilters = self.searchField.text.length > 0 || [self.filterView activeFilters].count > 0;
    self.emptyStateIconView.image = [UIImage systemImageNamed:hasActiveFilters ? @"line.3.horizontal.decrease.circle" : @"pawprint.fill"];
    self.emptyStateTitleLabel.text = hasActiveFilters ? kLang(@"adopt_list_no_results_title") : kLang(@"adopt_list_empty_title");
    self.emptyStateSubtitleLabel.text = hasActiveFilters ? kLang(@"adopt_list_no_results_subtitle") : kLang(@"adopt_list_empty_subtitle");
    [self.emptyStateActionButton setTitle:(hasActiveFilters ? kLang(@"Reset") : kLang(@"adopt_list_add_action")) forState:UIControlStateNormal];
    self.emptyStateActionButton.hidden = NO;
}

#pragma mark - Hero Stat (Signature Moment — pulse on new arrivals)

- (void)pp_updateHeroCount {
    NSString *format = kLang(@"adopt_list_count_format");
    if (format.length == 0) {
        format = @"%ld";
    }
    NSInteger newCount = (NSInteger)self.items.count;
    self.heroCountLabel.text = [NSString stringWithFormat:format, (long)newCount];

    BOOL increased = (newCount > self.lastDisplayedCount) && self.lastDisplayedCount > 0;
    self.lastDisplayedCount = newCount;

    if (increased && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.16
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.heroStatContainer.transform = CGAffineTransformMakeScale(1.10, 1.10);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.30
                                  delay:0.0
                 usingSpringWithDamping:0.62
                  initialSpringVelocity:0.6
                                 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                              animations:^{
                self.heroStatContainer.transform = CGAffineTransformIdentity;
            } completion:nil];
        }];
    }
}

- (void)pp_emptyStateActionTapped {
    if (self.isShowingLoadError) {
        [self startListening];
        return;
    }

    BOOL hasActiveFilters = self.searchField.text.length > 0 || [self.filterView activeFilters].count > 0;
    if (hasActiveFilters) {
        self.searchField.text = @"";
        [self.filterView resetAll];
        [self pp_applySearchAndFilter];
        [self pp_updateFilterButtonAppearanceAnimated:YES];
        return;
    }

    [self addNewPetForAdopt];
}


#pragma mark - Navigation Actions

- (IBAction)showHome {
    CompanyLocationVC *vc = [[CompanyLocationVC alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)showSupport {
    CompanyLocationVC *vc = [[CompanyLocationVC alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)notificationsBtnTapped:(UIButton *)sender {}

- (void)chatsBtnTapped:(UIButton *)sender {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    UserChatsViewController *vc = [[UserChatsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)shoppingCartClicked:(UIButton *)sender {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    OrderHistoryViewController *vc = [[OrderHistoryViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)cartClicked:(UIButton *)sender {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    CartViewController *vc = [[CartViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)addNewPetForAdopt {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    if (UserManager.sharedManager.isCurrentUserBlocked) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"Account blocked")
                          subtitle:kLang(@"Your account is blocked. You can't add adoption posts right now.")];
        return;
    }

    if (![self pp_currentUserHasAnyPermissionInKeys:@[kPermAdoption, kPermAdminAll]]) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"Permission denied")
                          subtitle:kLang(@"You don't have permission to add adoption posts.")];
        return;
    }

    AddAdoptPetViewController *vc = [[AddAdoptPetViewController alloc] init];
    vc.modalInPresentation = NO;

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.navigationBar.layer.cornerRadius = PPCornerCard;
    nav.navigationBar.clipsToBounds = YES;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)favTapped {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    MyItemsViewController *vc = [[MyItemsViewController alloc] initWithMode:MyItemsModeFavorites
                                                                    viewType:ViewTypeAdopt];
    vc.modalInPresentation = NO;
    vc.navigationItem.backButtonTitle = @"";
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - UICollectionView

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.filteredItems.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPUniversalCell *cell = (PPUniversalCell *)[PPUniversalCell pp_dequeueFromCollectionView:collectionView indexPath:indexPath];
    if (indexPath.item >= (NSInteger)self.filteredItems.count) return cell;

    AdoptPetModel *model = self.filteredItems[indexPath.item];
    PPUniversalCellViewModel *vm = [[PPUniversalCellViewModel alloc] initWithModel:model context:PPCellForAdopt];
    vm.indexPath = indexPath;

    cell.delegate = self;
    cell.showsSubtitle = YES;
    cell.hideTopBadge = NO;
    [cell applyViewModel:vm
                 context:PPCellForAdopt
              layoutMode:PPCellLayoutModePinterest
            discountMode:PPDiscountStyleBadge
             imageLoader:^(UIImageView * _Nullable iv, NSString * _Nullable url, UIImage * _Nullable ph, UIView * _Nullable card) {
        if (url.length > 0) {
            [GM setImageFromFirebaseURLString:url imageView:iv phImage:@"PawPlacerS" showShimmer:YES completion:nil];
        }
    }];

    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                   layout:(UICollectionViewLayout *)layout
   sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat available = collectionView.bounds.size.width - (PPSpaceMD * 3);
    CGFloat width = floor(available / 2.0);
    return CGSizeMake(width, width + 65.0);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item >= self.filteredItems.count) return;
    AdoptPetModel *selected = self.filteredItems[indexPath.item];
    BOOL isOwner = [self pp_isOwnerForModel:selected];
    AdoptPetDetailsViewController *vc = [[AdoptPetDetailsViewController alloc] initWithModel:selected isOwner:isOwner];
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = vc.sheetPresentationController;
        sheet.detents = @[[UISheetPresentationControllerDetent largeDetent]];
        sheet.prefersGrabberVisible = NO;
        sheet.preferredCornerRadius = PPCornerHero;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
        sheet.prefersEdgeAttachedInCompactHeight = YES;
        sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = NO;
    }
    [self presentViewController:vc animated:YES completion:nil];
}

#pragma mark - PPUniversalCellDelegate

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel {
    NSIndexPath *ip = universalModel.indexPath;
    if (!ip || ip.item >= (NSInteger)self.filteredItems.count) return;
    [self collectionView:self.collectionView didSelectItemAtIndexPath:ip];
}

- (void)PPUniversalCell_tapShare:(PPUniversalCellViewModel *)universalModel {
    AdoptPetModel *model = universalModel.ModelObject;
    if (![model isKindOfClass:[AdoptPetModel class]]) return;

    NSMutableArray *shareItems = [NSMutableArray array];
    NSString *title = model.name.length > 0 ? model.name : kLang(@"AdoptPet");
    [shareItems addObject:title];

    NSString *firstImage = model.imageURLs.firstObject;
    if (firstImage.length > 0) {
        NSURL *url = [NSURL URLWithString:firstImage];
        if (url) {
            [shareItems addObject:url];
        }
    }

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:shareItems applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0, 1, 1);
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)PPUniversalCell_tapEdit:(PPUniversalCellViewModel *)universalModel {
    AdoptPetModel *model = universalModel.ModelObject;
    if (![model isKindOfClass:[AdoptPetModel class]]) return;
    if (![self pp_isOwnerForModel:model]) return;

    AddAdoptPetViewController *vc = [[AddAdoptPetViewController alloc] initWithPet:model];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)PPUniversalCell_tapDelete:(PPUniversalCellViewModel *)universalModel {
    AdoptPetModel *model = universalModel.ModelObject;
    if (![model isKindOfClass:[AdoptPetModel class]]) return;
    if (![self pp_isOwnerForModel:model] || model.documentID.length == 0) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"Delete")
                                                                    message:kLang(@"Are you sure you want to delete this post?")
                                                             preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Delete")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [[AdoptPetManager shared] deletePetWithID:model.documentID completion:^(BOOL success, NSError * _Nullable error) {
            if (!success && error) {
                [PPAlertHelper showErrorIn:strongSelf title:kLang(@"error") subtitle:error.localizedDescription ?: kLang(@"unknownError")];
            }
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)PPUniversalCell_tapVisibilityToggle:(PPUniversalCellViewModel *)universalModel {
    AdoptPetModel *model = universalModel.ModelObject;
    if (![model isKindOfClass:[AdoptPetModel class]]) return;
    if (![self pp_isOwnerForModel:model] || model.documentID.length == 0) return;

    BOOL nextVisible = !universalModel.isPubliclyVisible;
    __weak typeof(self) weakSelf = self;
    [[AdoptPetManager shared] updatePetVisibilityWithID:model.documentID
                                             visibility:(nextVisible ? 0 : 1)
                                             completion:^(BOOL success, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (!success || error) {
            [PPAlertHelper showErrorIn:strongSelf title:kLang(@"Error") subtitle:error.localizedDescription ?: kLang(@"listing_visibility_failed")];
            return;
        }
        NSString *message = nextVisible ? kLang(@"listing_visible_success") : kLang(@"listing_hidden_success");
        [AppManager.sharedInstance showSnakBar:message withColor:GM.appPrimaryColor andDuration:0.6 containerView:strongSelf.view];
    }];
}

#pragma mark - Helpers

- (BOOL)pp_isOwnerForModel:(AdoptPetModel *)model {
    NSString *currentUserID = UserManager.sharedManager.currentUser.ID;
    if (currentUserID.length == 0 || model.ownerID.length == 0) return NO;
    return [model.ownerID isEqualToString:currentUserID];
}

- (BOOL)pp_currentUserHasAnyPermissionInKeys:(NSArray<NSString *> *)permissionKeys {
    UserModel *currentUser = UserManager.sharedManager.currentUser;
    if (!currentUser) return NO;
    return [currentUser hasAnyPermissionInKeys:permissionKeys];
}

@end
