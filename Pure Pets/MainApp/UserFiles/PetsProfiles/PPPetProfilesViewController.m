//
//  PPPetProfilesViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//  Modern UI refactor — card cells, skeleton loading, empty state, context menus.
//

#import "PPPetProfilesViewController.h"
#import "PPPetProfileEditorViewController.h"
#import "PPPetRemindersViewController.h"
#import "PPPetProfile.h"
#import "PPModernAvatarRenderer.h"
#import "UserManager.h"
#import "Language.h"
 

// ─── Helpers ──────────────────────────────────────────────

static NSCache<NSString *, UIImage *> *PPPetImageCache(void) {
    static NSCache *cache;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ cache = [NSCache new]; cache.countLimit = 60; });
    return cache;
}

static NSURLSession *PPPetURLSession(void) {
    static NSURLSession *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 30;
        cfg.timeoutIntervalForResource = 60;
        s = [NSURLSession sessionWithConfiguration:cfg];
    });
    return s;
}

static void PPLoadPetImage(UIImageView *iv, NSString *url, UIImage *placeholder) {
    iv.image = placeholder;
    if (!url.length) return;
    UIImage *cached = [PPPetImageCache() objectForKey:url];
    if (cached) { iv.image = cached; return; }
    NSURL *u = [NSURL URLWithString:url];
    if (!u) return;
    __weak UIImageView *wiv = iv;
    [[PPPetURLSession() dataTaskWithURL:u completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (!d) return;
        UIImage *img = [UIImage imageWithData:d];
        if (!img) return;
        [PPPetImageCache() setObject:img forKey:url];
        dispatch_async(dispatch_get_main_queue(), ^{ wiv.image = img; });
    }] resume];
}

// ─── Skeleton Cell ────────────────────────────────────────

@interface PPPetProfileSkeletonCell : UITableViewCell
@property (nonatomic, strong) UIView *cardContainer;
@end

@implementation PPPetProfileSkeletonCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:style reuseIdentifier:rid];
    if (!self) return nil;
    self.selectionStyle  = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    _cardContainer = [UIView new];
    _cardContainer.translatesAutoresizingMaskIntoConstraints = NO;
    PPPetsApplySurfaceStyle(_cardContainer, PPCornerCard);
    _cardContainer.layer.shadowOpacity = 0.04;
    _cardContainer.layer.shadowRadius = 16.0;
    _cardContainer.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    [self.contentView addSubview:_cardContainer];

    UIView *imgPH  = [self pp_shimmer:56 h:56 r:28];
    UIView *line1  = [self pp_shimmer:120 h:14 r:7];
    UIView *line2  = [self pp_shimmer:160 h:12 r:6];
    UIView *line3  = [self pp_shimmer:80  h:10 r:5];
    [_cardContainer addSubview:imgPH];
    [_cardContainer addSubview:line1];
    [_cardContainer addSubview:line2];
    [_cardContainer addSubview:line3];

    [NSLayoutConstraint activateConstraints:@[
        [_cardContainer.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor      constant:PPSpaceXS],
        [_cardContainer.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor  constant:PPScreenMargin],
        [_cardContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPScreenMargin],
        [_cardContainer.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor   constant:-PPSpaceXS],

        [imgPH.leadingAnchor  constraintEqualToAnchor:_cardContainer.leadingAnchor constant:PPSpaceBase],
        [imgPH.centerYAnchor  constraintEqualToAnchor:_cardContainer.centerYAnchor],
        [imgPH.widthAnchor    constraintEqualToConstant:56],
        [imgPH.heightAnchor   constraintEqualToConstant:56],

        [line1.topAnchor     constraintEqualToAnchor:imgPH.topAnchor constant:PPSpaceXXS],
        [line1.leadingAnchor constraintEqualToAnchor:imgPH.trailingAnchor constant:PPSpaceMD],
        [line2.topAnchor     constraintEqualToAnchor:line1.bottomAnchor constant:PPSpaceSM],
        [line2.leadingAnchor constraintEqualToAnchor:line1.leadingAnchor],
        [line3.topAnchor     constraintEqualToAnchor:line2.bottomAnchor constant:PPSpaceSM],
        [line3.leadingAnchor constraintEqualToAnchor:line1.leadingAnchor],
    ]];
    return self;
}

- (UIView *)pp_shimmer:(CGFloat)w h:(CGFloat)h r:(CGFloat)r {
    UIView *v = [UIView new];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    v.backgroundColor = UIColor.tertiarySystemFillColor;
    PPApplyContinuousCorners(v, r);
    [v.widthAnchor  constraintEqualToConstant:w].active = YES;
    [v.heightAnchor constraintEqualToConstant:h].active = YES;

    CAGradientLayer *g = [CAGradientLayer layer];
    g.colors     = @[(id)[UIColor.tertiarySystemFillColor colorWithAlphaComponent:0.4].CGColor,
                      (id)[UIColor.tertiarySystemFillColor colorWithAlphaComponent:0.1].CGColor,
                      (id)[UIColor.tertiarySystemFillColor colorWithAlphaComponent:0.4].CGColor];
    g.startPoint = CGPointMake(0, 0.5);
    g.endPoint   = CGPointMake(1, 0.5);
    g.frame      = CGRectMake(0, 0, w * 3, h);
    [v.layer addSublayer:g];

    CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    a.fromValue       = @(-w * 2);
    a.toValue         = @(w);
    a.duration        = 1.5;
    a.repeatCount     = HUGE_VALF;
    a.timingFunction  = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [g addAnimation:a forKey:@"shimmer"];
    return v;
}

@end

// ─── Card Cell ────────────────────────────────────────────

@interface PPPetProfileCardCell : UITableViewCell
@property (nonatomic, strong) UIView      *cardContainer;
@property (nonatomic, strong) UIImageView *petImageView;
@property (nonatomic, strong) UIImageView *defaultBadge;
@property (nonatomic, strong) UILabel     *nameLabel;
@property (nonatomic, strong) UILabel     *detailLabel;
@property (nonatomic, strong) UILabel     *vaccineLabel;
@property (nonatomic, strong) UIImageView *chevronView;
- (void)configureWithPet:(PPPetProfile *)pet;
@end

@implementation PPPetProfileCardCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:style reuseIdentifier:rid];
    if (!self) return nil;
    self.selectionStyle  = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    CGFloat imgSize = 56;

    // Card
    _cardContainer = [UIView new];
    _cardContainer.translatesAutoresizingMaskIntoConstraints = NO;
    PPPetsApplySurfaceStyle(_cardContainer, PPCornerCard);
    [self.contentView addSubview:_cardContainer];

    // Pet image
    _petImageView = [UIImageView new];
    _petImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _petImageView.contentMode   = UIViewContentModeScaleAspectFill;
    _petImageView.clipsToBounds = YES;
    _petImageView.layer.cornerRadius = imgSize / 2.0;
    _petImageView.layer.borderWidth  = 1.5;
    [_petImageView pp_setBorderColor:[PPPetsUIBrandColor() colorWithAlphaComponent:0.2]];
    _petImageView.backgroundColor    = UIColor.tertiarySystemFillColor;
    _petImageView.tintColor          = PPPetsUIBrandColor();
    [_cardContainer addSubview:_petImageView];

    // Default star badge
    _defaultBadge = [UIImageView new];
    _defaultBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _defaultBadge.image     = [[UIImage systemImageNamed:@"star.circle.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _defaultBadge.tintColor = UIColor.systemYellowColor;
    _defaultBadge.hidden    = YES;
    [_cardContainer addSubview:_defaultBadge];

    // Name
    _nameLabel = [UILabel new];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font          = [GM boldFontWithSize:PPFontHeadline];
    _nameLabel.textColor     = AppPrimaryTextClr;
    _nameLabel.numberOfLines = 1;
    [_cardContainer addSubview:_nameLabel];

    // Breed · Age
    _detailLabel = [UILabel new];
    _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _detailLabel.font          = [UIFont systemFontOfSize:PPFontSubheadline weight:UIFontWeightRegular];
    _detailLabel.textColor     = PPPetsUISecondaryTextColor();
    _detailLabel.numberOfLines = 1;
    [_cardContainer addSubview:_detailLabel];

    // Vaccine count
    _vaccineLabel = [UILabel new];
    _vaccineLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _vaccineLabel.font          = [UIFont systemFontOfSize:PPFontFootnote weight:UIFontWeightMedium];
    _vaccineLabel.textColor     = PPPetsUIBrandColor();
    _vaccineLabel.numberOfLines = 1;
    [_cardContainer addSubview:_vaccineLabel];

    // Chevron
    _chevronView = [UIImageView new];
    _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *chevCfg = [UIImageSymbolConfiguration configurationWithPointSize:PPFontFootnote weight:UIImageSymbolWeightMedium];
    _chevronView.image     = [UIImage systemImageNamed:PPPetsForwardChevronSymbolName() withConfiguration:chevCfg];
    _chevronView.tintColor = UIColor.tertiaryLabelColor;
    [_cardContainer addSubview:_chevronView];

    [NSLayoutConstraint activateConstraints:@[
        [_cardContainer.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor      constant:PPSpaceXS],
        [_cardContainer.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor  constant:PPScreenMargin],
        [_cardContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPScreenMargin],
        [_cardContainer.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor   constant:-PPSpaceXS],

        [_petImageView.leadingAnchor constraintEqualToAnchor:_cardContainer.leadingAnchor constant:PPSpaceBase],
        [_petImageView.centerYAnchor constraintEqualToAnchor:_cardContainer.centerYAnchor],
        [_petImageView.widthAnchor   constraintEqualToConstant:imgSize],
        [_petImageView.heightAnchor  constraintEqualToConstant:imgSize],
        [_petImageView.topAnchor     constraintGreaterThanOrEqualToAnchor:_cardContainer.topAnchor    constant:PPSpaceMD],
        [_petImageView.bottomAnchor  constraintLessThanOrEqualToAnchor:_cardContainer.bottomAnchor constant:-PPSpaceMD],

        [_defaultBadge.widthAnchor    constraintEqualToConstant:20],
        [_defaultBadge.heightAnchor   constraintEqualToConstant:20],
        [_defaultBadge.trailingAnchor constraintEqualToAnchor:_petImageView.trailingAnchor constant:2],
        [_defaultBadge.topAnchor      constraintEqualToAnchor:_petImageView.topAnchor      constant:-2],

        [_chevronView.trailingAnchor constraintEqualToAnchor:_cardContainer.trailingAnchor constant:-PPSpaceBase],
        [_chevronView.centerYAnchor  constraintEqualToAnchor:_cardContainer.centerYAnchor],
        [_chevronView.widthAnchor    constraintEqualToConstant:12],

        [_nameLabel.topAnchor      constraintEqualToAnchor:_petImageView.topAnchor      constant:PPSpaceXXS],
        [_nameLabel.leadingAnchor  constraintEqualToAnchor:_petImageView.trailingAnchor constant:PPSpaceMD],
        [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronView.leadingAnchor constant:-PPSpaceSM],

        [_detailLabel.topAnchor     constraintEqualToAnchor:_nameLabel.bottomAnchor constant:PPSpaceXXS],
        [_detailLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_detailLabel.trailingAnchor constraintEqualToAnchor:_nameLabel.trailingAnchor],

        [_vaccineLabel.topAnchor     constraintEqualToAnchor:_detailLabel.bottomAnchor constant:PPSpaceXS],
        [_vaccineLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_vaccineLabel.trailingAnchor constraintEqualToAnchor:_nameLabel.trailingAnchor],
    ]];
    return self;
}

- (void)configureWithPet:(PPPetProfile *)pet {
    self.nameLabel.text = pet.name.length ? pet.name : (kLang(@"pet_name_placeholder") ?: @"Pet");

    NSMutableArray *parts = [NSMutableArray array];
    if (pet.breed.length) [parts addObject:pet.breed];
    NSString *age = [pet displayAgeText];
    if (age.length) [parts addObject:age];
    self.detailLabel.text = parts.count ? [parts componentsJoinedByString:@" · "] : @"—";

    self.vaccineLabel.text = [NSString stringWithFormat:@"💉 %ld %@",
                              (long)pet.vaccinations.count,
                              kLang(@"pet_vaccines_short") ?: @"vaccines"];

    self.defaultBadge.hidden = !pet.isDefaultPet;

    UIImage *ph = (pet.imageURL.length == 0)
        ? [PPModernAvatarRenderer avatarImageForName:(pet.name ?: @"") size:72]
        : [[UIImage systemImageNamed:@"pawprint.circle.fill"]
           imageWithConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightLight]];
    PPLoadPetImage(self.petImageView, pet.imageURL, ph);

    // RTL
    self.cardContainer.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    self.nameLabel.textAlignment    = Language.alignmentForCurrentLanguage;
    self.detailLabel.textAlignment  = Language.alignmentForCurrentLanguage;
    self.vaccineLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.chevronView.image = [UIImage systemImageNamed:PPPetsForwardChevronSymbolName()
                                     withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:PPFontFootnote weight:UIImageSymbolWeightMedium]];

    // Accessibility
    self.isAccessibilityElement = YES;
    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@",
        self.nameLabel.text ?: @"",
        self.detailLabel.text ?: @"",
        self.vaccineLabel.text ?: @""];
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.accessibilityHint = kLang(@"pet_profile_tap_hint") ?: @"Double tap to view pet profile";
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    highlighted ? PPTapFeedbackDown(self.cardContainer) : PPTapFeedbackUp(self.cardContainer);
}

@end

// ─── View Controller ──────────────────────────────────────

@interface PPPetProfilesViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<PPPetProfile *> *pets;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasAppearedOnce;
@property (nonatomic, strong) UIView *backgroundGlowViewTop;
@property (nonatomic, strong) UIView *backgroundGlowViewBottom;
@property (nonatomic, strong) NSArray<UIView *> *floatingCircles;
@property (nonatomic, strong) UIView *headerRoot;
@property (nonatomic, strong) UIView *headerCardView;
@property (nonatomic, strong) PPInsetLabel *headerEyebrowLabel;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerSubtitleLabel;
@property (nonatomic, strong) PPInsetLabel *headerMetaLabel;
@property (nonatomic, strong) LOTAnimationView *headerAnimationView;
@property (nonatomic, strong) UIButton *headerPrimaryButton;
@property (nonatomic, strong) UIButton *headerSecondaryButton;

// iPad-only: hero is 70% width with a promo/info side card
@property (nonatomic, strong) UIView  *iPadSideCard;
@property (nonatomic, strong) UILabel *iPadSideTitle;
@property (nonatomic, strong) UILabel *iPadSideBody;
@property (nonatomic, strong) UIImageView *iPadSideIcon;
@property (nonatomic, strong) UIView  *iPadSideAccent;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *iPadConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *iPhoneConstraints;
@end

static BOOL PPPetsIsIPad(void) {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

static NSString *const kCardCellID     = @"PPPetProfileCardCell";
static NSString *const kSkeletonCellID = @"PPPetProfileSkeletonCell";

static NSString *const kEmptyCellID    = @"PPPetProfileEmptyCell";

@implementation PPPetProfilesViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = kLang(@"pet_profiles_title") ?: @"Pet Profiles";
    self.pets  = @[];
    self.isLoading = YES;

    // Nav — AddressFormVC style
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:PPSYSImage(PPChevronName)
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(pp_handleBack)];
    UIBarButtonItem *addBtn = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"plus.circle.fill"]
                style:UIBarButtonItemStylePlain target:self action:@selector(pp_addPet)];
    addBtn.tintColor = AppPrimaryClr;

    UIBarButtonItem *remBtn = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"bell.badge"]
                style:UIBarButtonItemStylePlain target:self action:@selector(pp_openReminders)];
    remBtn.tintColor = AppPrimaryClr;
    self.navigationItem.rightBarButtonItems = @[addBtn, remBtn];

    // Table
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource       = self;
    self.tableView.delegate         = self;
    self.tableView.backgroundColor  = UIColor.clearColor;
    self.tableView.separatorStyle   = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset     = UIEdgeInsetsMake(6.0, 0.0, 24.0, 0.0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
    [self.tableView registerClass:PPPetProfileCardCell.class     forCellReuseIdentifier:kCardCellID];
    [self.tableView registerClass:PPPetProfileSkeletonCell.class forCellReuseIdentifier:kSkeletonCellID];
    [self.tableView registerClass:UITableViewCell.class          forCellReuseIdentifier:kEmptyCellID];
    [self.view addSubview:self.tableView];

    [self pp_setupBackdrop];
    [self pp_buildHeroHeader];
    [self pp_applyCanvasBackground];
    [self pp_refreshHeroHeaderContent];

    // Pull-to-refresh
    UIRefreshControl *rc = [UIRefreshControl new];
    [rc addTarget:self action:@selector(pp_pullRefresh) forControlEvents:UIControlEventValueChanged];
    rc.tintColor = AppPrimaryClr;
    self.tableView.refreshControl = rc;

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.view.semanticContentAttribute      = PPPetsCurrentSemanticAttribute();
    self.tableView.semanticContentAttribute = PPPetsCurrentSemanticAttribute();
    [self pp_applyCanvasBackground];
    [self pp_refreshHeroHeaderContent];
    [self pp_reload];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    PPPetsBeginFloatingAnimations(self.backgroundGlowViewTop, self.backgroundGlowViewBottom, self.floatingCircles);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_applyCanvasBackground];
    self.backgroundGlowViewTop.layer.cornerRadius = CGRectGetWidth(self.backgroundGlowViewTop.bounds) * 0.5;
    self.backgroundGlowViewBottom.layer.cornerRadius = CGRectGetWidth(self.backgroundGlowViewBottom.bounds) * 0.5;
    [self.view sendSubviewToBack:self.backgroundGlowViewBottom];
    [self.view sendSubviewToBack:self.backgroundGlowViewTop];
    [self pp_updateHeaderLayout];
}

#pragma mark - Appearance

- (void)pp_applyCanvasBackground {
    PPPetsApplyCanvasBackground(self, nil);
    self.tableView.backgroundColor = UIColor.clearColor;
}

- (void)pp_setupBackdrop {
    if (self.backgroundGlowViewTop || self.backgroundGlowViewBottom) {
        return;
    }

    UIView *topGlow = PPPetsBuildGlowView(PPPetsGlowFill(0.93, 0.80, 0.69, 0.12),
                                          PPPetsGlowFill(0.98, 0.82, 0.60, 1.0),
                                          0.10,
                                          64.0);
    UIView *bottomGlow = PPPetsBuildGlowView(PPPetsGlowFill(0.72, 0.45, 0.42, 0.06),
                                             PPPetsGlowFill(0.68, 0.27, 0.33, 1.0),
                                             0.08,
                                             72.0);

    [self.view insertSubview:topGlow belowSubview:self.tableView];
    [self.view insertSubview:bottomGlow belowSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [topGlow.widthAnchor constraintEqualToConstant:220.0],
        [topGlow.heightAnchor constraintEqualToConstant:220.0],
        [topGlow.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-72.0],
        [topGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:84.0],

        [bottomGlow.widthAnchor constraintEqualToConstant:200.0],
        [bottomGlow.heightAnchor constraintEqualToConstant:200.0],
        [bottomGlow.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:48.0],
        [bottomGlow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-64.0],
    ]];

    self.backgroundGlowViewTop = topGlow;
    self.backgroundGlowViewBottom = bottomGlow;

    self.floatingCircles = PPPetsBuildFloatingCircles(self.view);
}

- (void)pp_buildHeroHeader {
    self.headerRoot = [[UIView alloc] init];
    self.headerRoot.backgroundColor = UIColor.clearColor;

    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    PPPetsApplySurfaceStyle(cardView, 34.0);
    [self.headerRoot addSubview:cardView];

    UIView *tintView = [[UIView alloc] init];
    tintView.translatesAutoresizingMaskIntoConstraints = NO;
    tintView.backgroundColor = PPPetsUISurfaceTintColor();
    tintView.layer.cornerRadius = 34.0;
    tintView.layer.masksToBounds = YES;
    [cardView addSubview:tintView];

    UIView *ambientGlow = PPPetsBuildGlowView([PPPetsUIBrandColor() colorWithAlphaComponent:0.16],
                                              [PPPetsUIBrandColor() colorWithAlphaComponent:0.50],
                                              0.16,
                                              42.0);
    ambientGlow.layer.cornerRadius = 94.0;
    [cardView addSubview:ambientGlow];

    UIView *secondaryGlow = PPPetsBuildGlowView(PPPetsCardOverlay(0.40),
                                                PPPetsCardOverlay(0.45),
                                                0.20,
                                                22.0);
    secondaryGlow.layer.cornerRadius = 58.0;
    [cardView addSubview:secondaryGlow];

    UIView *accentBar = [[UIView alloc] init];
    accentBar.translatesAutoresizingMaskIntoConstraints = NO;
    accentBar.backgroundColor = PPPetsUIBrandColor();
    accentBar.layer.cornerRadius = 3.0;
    [cardView addSubview:accentBar];

    UIView *eyebrowPill = [[UIView alloc] init];
    eyebrowPill.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowPill.backgroundColor = PPPetsCardOverlay(0.74);
    eyebrowPill.layer.cornerRadius = 14.0;
    eyebrowPill.layer.borderWidth = 1.0;
    [eyebrowPill pp_setBorderColor:[PPPetsUIBrandColor() colorWithAlphaComponent:0.10]];
    eyebrowPill.layer.masksToBounds = YES;
    [cardView addSubview:eyebrowPill];

    PPInsetLabel *eyebrowLabel = [[PPInsetLabel alloc] init];
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    eyebrowLabel.textColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.92];
    eyebrowLabel.textAlignment = NSTextAlignmentCenter;
    eyebrowLabel.textInsets = UIEdgeInsetsMake(2.0, 2.0, 2.0, 2.0);
    [eyebrowPill addSubview:eyebrowLabel];

    UIView *avatarHalo = [[UIView alloc] init];
    avatarHalo.translatesAutoresizingMaskIntoConstraints = NO;
    avatarHalo.backgroundColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.12];
    avatarHalo.layer.cornerRadius = 62.0;
    avatarHalo.layer.borderWidth = 1.0;
    [avatarHalo pp_setBorderColor:PPPetsCardOverlay(0.48)];
    [avatarHalo pp_setShadowColor:[PPPetsUIBrandColor() colorWithAlphaComponent:0.30]];
    avatarHalo.layer.shadowOpacity = 0.12;
    avatarHalo.layer.shadowRadius = 22.0;
    avatarHalo.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [cardView addSubview:avatarHalo];

    LOTAnimationView *headerAnimView = [[LOTAnimationView alloc] init];
    headerAnimView.translatesAutoresizingMaskIntoConstraints = NO;
    headerAnimView.contentMode = UIViewContentModeScaleAspectFit;
    headerAnimView.clipsToBounds = YES;
    headerAnimView.layer.cornerRadius = 54.0;
    headerAnimView.layer.borderWidth = 3.0;
    [headerAnimView pp_setBorderColor:PPPetsCardOverlay(0.86)];
    headerAnimView.backgroundColor = PPPetsCardOverlay(0.60);
    headerAnimView.loopAnimation = YES;
    headerAnimView.animationSpeed = 0.7;
    [avatarHalo addSubview:headerAnimView];

    __weak LOTAnimationView *weakAnim = headerAnimView;
    [AppClasses setAnimationNamed:@"petprofile"//Womanlovingpetcats
                           ToView:headerAnimView
                        withSpeed:0.7
                       completion:^(BOOL success) {
        if (success) [weakAnim play];
    }];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:29.0] ?: [UIFont systemFontOfSize:29.0 weight:UIFontWeightBold];
    titleLabel.textColor = AppPrimaryTextClr;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 2;
    [cardView addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = PPPetsUISecondaryTextColor();
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 2;
    [cardView addSubview:subtitleLabel];

    PPInsetLabel *metaLabel = [[PPInsetLabel alloc] init];
    metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    metaLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    metaLabel.textColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.92];
    metaLabel.textAlignment = NSTextAlignmentCenter;
    metaLabel.numberOfLines = 2;
    metaLabel.backgroundColor = PPPetsCardOverlay(0.78);
    metaLabel.layer.cornerRadius = 17.0;
    metaLabel.layer.borderWidth = 1.0;
    [metaLabel pp_setBorderColor:[PPPetsUIBrandColor() colorWithAlphaComponent:0.10]];
    metaLabel.layer.masksToBounds = YES;
    metaLabel.textInsets = UIEdgeInsetsMake(6.0, 12.0, 6.0, 12.0);
    [cardView addSubview:metaLabel];

    UIButton *primaryButton = PPPetsBuildHeroButton(kLang(@"pet_add_title") ?: @"Add Pet",
                                                    @"plus.circle.fill",
                                                    YES);
    [primaryButton addTarget:self action:@selector(pp_addPet) forControlEvents:UIControlEventTouchUpInside];
    [cardView addSubview:primaryButton];

    UIButton *secondaryButton = PPPetsBuildHeroButton(kLang(@"pet_reminders_tab") ?: @"Reminders",
                                                      @"bell.badge.fill",
                                                      NO);
    [secondaryButton addTarget:self action:@selector(pp_openReminders) forControlEvents:UIControlEventTouchUpInside];
    [cardView addSubview:secondaryButton];

    // ── Internal card constraints (shared between iPhone & iPad) ──
    [NSLayoutConstraint activateConstraints:@[
        [tintView.topAnchor constraintEqualToAnchor:cardView.topAnchor],
        [tintView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
        [tintView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
        [tintView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],

        [ambientGlow.widthAnchor constraintEqualToConstant:188.0],
        [ambientGlow.heightAnchor constraintEqualToConstant:188.0],
        [ambientGlow.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:-82.0],
        [ambientGlow.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:82.0],

        [secondaryGlow.widthAnchor constraintEqualToConstant:116.0],
        [secondaryGlow.heightAnchor constraintEqualToConstant:116.0],
        [secondaryGlow.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:42.0],
        [secondaryGlow.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:-34.0],

        [accentBar.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:22.0],
        [accentBar.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [accentBar.widthAnchor constraintEqualToConstant:72.0],
        [accentBar.heightAnchor constraintEqualToConstant:6.0],

        [eyebrowPill.topAnchor constraintEqualToAnchor:accentBar.bottomAnchor constant:16.0],
        [eyebrowPill.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [eyebrowPill.trailingAnchor constraintLessThanOrEqualToAnchor:cardView.trailingAnchor constant:-24.0],
        [eyebrowPill.heightAnchor constraintGreaterThanOrEqualToConstant:28.0],

        [eyebrowLabel.topAnchor constraintEqualToAnchor:eyebrowPill.topAnchor constant:6.0],
        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:eyebrowPill.leadingAnchor constant:12.0],
        [eyebrowLabel.trailingAnchor constraintEqualToAnchor:eyebrowPill.trailingAnchor constant:-12.0],
        [eyebrowLabel.bottomAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:-6.0],

        [avatarHalo.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [avatarHalo.topAnchor constraintEqualToAnchor:eyebrowPill.bottomAnchor constant:20.0],
        [avatarHalo.widthAnchor constraintEqualToConstant:124.0],
        [avatarHalo.heightAnchor constraintEqualToConstant:124.0],

        [headerAnimView.centerXAnchor constraintEqualToAnchor:avatarHalo.centerXAnchor],
        [headerAnimView.centerYAnchor constraintEqualToAnchor:avatarHalo.centerYAnchor],
        [headerAnimView.widthAnchor constraintEqualToConstant:108.0],
        [headerAnimView.heightAnchor constraintEqualToConstant:108.0],

        [titleLabel.topAnchor constraintEqualToAnchor:avatarHalo.bottomAnchor constant:22.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [metaLabel.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:14.0],
        [metaLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:cardView.leadingAnchor constant:34.0],
        [metaLabel.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [metaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:cardView.trailingAnchor constant:-34.0],

        [primaryButton.topAnchor constraintEqualToAnchor:metaLabel.bottomAnchor constant:24.0],
        [primaryButton.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
        [primaryButton.trailingAnchor constraintEqualToAnchor:cardView.centerXAnchor constant:-6.0],
        [primaryButton.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-24.0],

        [secondaryButton.topAnchor constraintEqualToAnchor:primaryButton.topAnchor],
        [secondaryButton.leadingAnchor constraintEqualToAnchor:cardView.centerXAnchor constant:6.0],
        [secondaryButton.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],
        [secondaryButton.bottomAnchor constraintEqualToAnchor:primaryButton.bottomAnchor],
    ]];

    // ── Card-to-headerRoot positioning: iPad vs iPhone ──
    if (PPPetsIsIPad()) {
        [self pp_buildIPadSideCard];

        UIView *sc = self.iPadSideCard;
        self.iPadConstraints = @[
            [cardView.topAnchor constraintEqualToAnchor:self.headerRoot.topAnchor constant:10.0],
            [cardView.bottomAnchor constraintEqualToAnchor:self.headerRoot.bottomAnchor constant:-14.0],
            [cardView.leadingAnchor constraintEqualToAnchor:self.headerRoot.leadingAnchor constant:20.0],
            [cardView.widthAnchor constraintEqualToAnchor:self.headerRoot.widthAnchor multiplier:0.55 constant:-30.0],

            [sc.topAnchor constraintEqualToAnchor:cardView.topAnchor],
            [sc.leadingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:14.0],
            [sc.trailingAnchor constraintEqualToAnchor:self.headerRoot.trailingAnchor constant:-20.0],
            [sc.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],
        ];
        [NSLayoutConstraint activateConstraints:self.iPadConstraints];
    } else {
        self.iPhoneConstraints = @[
            [cardView.topAnchor constraintEqualToAnchor:self.headerRoot.topAnchor constant:10.0],
            [cardView.leadingAnchor constraintEqualToAnchor:self.headerRoot.leadingAnchor constant:20.0],
            [cardView.trailingAnchor constraintEqualToAnchor:self.headerRoot.trailingAnchor constant:-20.0],
            [cardView.bottomAnchor constraintEqualToAnchor:self.headerRoot.bottomAnchor constant:-14.0],
        ];
        [NSLayoutConstraint activateConstraints:self.iPhoneConstraints];
    }

    self.headerCardView = cardView;
    self.headerEyebrowLabel = eyebrowLabel;
    self.headerTitleLabel = titleLabel;
    self.headerSubtitleLabel = subtitleLabel;
    self.headerMetaLabel = metaLabel;
    self.headerAnimationView = headerAnimView;
    self.headerPrimaryButton = primaryButton;
    self.headerSecondaryButton = secondaryButton;

    self.tableView.tableHeaderView = self.headerRoot;
}

// ── iPad Side Card ────────────────────────────────────────

- (void)pp_buildIPadSideCard {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    PPPetsApplySurfaceStyle(card, 28.0);
    card.clipsToBounds = YES;
    [self.headerRoot addSubview:card];

    // Subtle gradient tint overlay
    UIView *tint = [[UIView alloc] init];
    tint.translatesAutoresizingMaskIntoConstraints = NO;
    tint.backgroundColor = [PPPetsUIBrandColor() colorWithAlphaComponent:0.04];
    tint.layer.cornerRadius = 28.0;
    tint.layer.masksToBounds = YES;
    [card addSubview:tint];

    // Top decorative accent bar
    UIView *accent = [[UIView alloc] init];
    accent.translatesAutoresizingMaskIntoConstraints = NO;
    accent.backgroundColor = PPPetsUIBrandColor();
    accent.layer.cornerRadius = 2.0;
    [card addSubview:accent];
    self.iPadSideAccent = accent;

    // Large icon
    UIImageView *icon = [[UIImageView alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.tintColor = PPPetsUIBrandColor();
    icon.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:44.0
                                                       weight:UIImageSymbolWeightLight
                                                        scale:UIImageSymbolScaleLarge];
    [card addSubview:icon];
    self.iPadSideIcon = icon;

    // Title
    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [GM boldFontWithSize:20.0] ?: [UIFont systemFontOfSize:20.0 weight:UIFontWeightBold];
    title.textColor = AppPrimaryTextClr;
    title.textAlignment = Language.alignmentForCurrentLanguage;
    title.numberOfLines = 2;
    [card addSubview:title];
    self.iPadSideTitle = title;

    // Body
    UILabel *body = [[UILabel alloc] init];
    body.translatesAutoresizingMaskIntoConstraints = NO;
    body.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    body.textColor = PPPetsUISecondaryTextColor();
    body.textAlignment = Language.alignmentForCurrentLanguage;
    body.numberOfLines = 0;
    [card addSubview:body];
    self.iPadSideBody = body;

    // Decorative glow dot
    UIView *glow = PPPetsBuildGlowView([PPPetsUIBrandColor() colorWithAlphaComponent:0.10],
                                       [PPPetsUIBrandColor() colorWithAlphaComponent:0.30],
                                       0.12, 36.0);
    glow.layer.cornerRadius = 60.0;
    [card addSubview:glow];

    [NSLayoutConstraint activateConstraints:@[
        [tint.topAnchor constraintEqualToAnchor:card.topAnchor],
        [tint.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [tint.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [tint.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],

        [accent.topAnchor constraintEqualToAnchor:card.topAnchor constant:24.0],
        [accent.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24.0],
        [accent.widthAnchor constraintEqualToConstant:48.0],
        [accent.heightAnchor constraintEqualToConstant:4.0],

        [icon.topAnchor constraintEqualToAnchor:accent.bottomAnchor constant:20.0],
        [icon.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24.0],
        [icon.widthAnchor constraintEqualToConstant:52.0],
        [icon.heightAnchor constraintEqualToConstant:52.0],

        [title.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:18.0],
        [title.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24.0],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24.0],

        [body.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10.0],
        [body.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [body.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [body.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-24.0],

        [glow.widthAnchor constraintEqualToConstant:120.0],
        [glow.heightAnchor constraintEqualToConstant:120.0],
        [glow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:30.0],
        [glow.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:30.0],
    ]];

    self.iPadSideCard = card;
}

- (void)pp_refreshHeroHeaderContent {
    // Eyebrow shows contextual count; title stays as the page heading
    if (self.pets.count > 0) {
        self.headerEyebrowLabel.text = [NSString stringWithFormat:@"🐾 %ld %@",
                                        (long)self.pets.count,
                                        (self.pets.count == 1
                                         ? (kLang(@"pet_profile_single") ?: @"companion")
                                         : (kLang(@"pet_companions") ?: @"companions"))];
    } else {
        self.headerEyebrowLabel.text = kLang(@"pet_profiles_get_started") ?: @"🐾 Get Started";
    }
    self.headerTitleLabel.text = kLang(@"pet_profiles_title") ?: @"Pet Profiles";

    PPPetProfile *featuredPet = nil;
    for (PPPetProfile *pet in self.pets) {
        if (pet.isDefaultPet) {
            featuredPet = pet;
            break;
        }
    }
    featuredPet = featuredPet ?: self.pets.firstObject;

    NSInteger vaccineCount = 0;
    for (PPPetProfile *pet in self.pets) {
        vaccineCount += pet.vaccinations.count;
    }

    if (self.isLoading) {
        self.headerSubtitleLabel.text = kLang(@"please_wait") ?: @"Loading your pet profiles…";
        self.headerMetaLabel.text = kLang(@"please_wait") ?: @"Loading…";
    } else if (featuredPet) {
        NSString *defaultLine = featuredPet.isDefaultPet
            ? [NSString stringWithFormat:@"%@: %@", kLang(@"pet_default_action") ?: @"Default pet", featuredPet.name ?: @""]
            : [NSString stringWithFormat:@"%@: %@", kLang(@"pet_field_name") ?: @"Featured", featuredPet.name ?: @""];
        self.headerSubtitleLabel.text = defaultLine;
        self.headerMetaLabel.text = [NSString stringWithFormat:@"%ld %@ · %ld %@",
                                     (long)self.pets.count,
                                     (self.pets.count == 1 ? (kLang(@"pet_profile_single") ?: @"profile") : (kLang(@"pet_profiles_title") ?: @"profiles")),
                                     (long)vaccineCount,
                                     (kLang(@"pet_vaccines_short") ?: @"vaccines")];
    } else {
        self.headerSubtitleLabel.text = kLang(@"pet_profiles_empty_subtitle") ?: @"Add your first pet profile to keep routines, vaccines, and reminders in one polished place.";
        self.headerMetaLabel.text = kLang(@"pet_add_title") ?: @"Start with your first pet";
    }

    // Lottie animation plays in place of the old pet image
    if (!self.headerAnimationView.isAnimationPlaying) {
        [self.headerAnimationView play];
    }

    // ── iPad side card content ──
    [self pp_refreshIPadSideCard:featuredPet vaccineCount:vaccineCount];

    [self pp_updateHeaderLayout];
}

- (void)pp_refreshIPadSideCard:(PPPetProfile *)featuredPet vaccineCount:(NSInteger)vaccineCount {
    if (!self.iPadSideCard) return;

    if (self.isLoading) {
        self.iPadSideIcon.image = [UIImage systemImageNamed:@"hourglass.circle"];
        self.iPadSideTitle.text = kLang(@"please_wait") ?: @"Loading…";
        self.iPadSideBody.text = @"";
        return;
    }

    if (featuredPet) {
        // Show default/featured pet details
        self.iPadSideIcon.image = [UIImage systemImageNamed:@"pawprint.circle.fill"];

        NSString *petName = featuredPet.name ?: (kLang(@"pet_field_name") ?: @"Pet");
        NSString *breed = featuredPet.breed.length
            ? featuredPet.breed
            : (kLang(@"pet_breed_unknown") ?: @"Unknown breed");

        self.iPadSideTitle.text = petName;

        NSMutableString *details = [NSMutableString string];
        [details appendFormat:@"🏷 %@", breed];

        if (featuredPet.ageInMonths > 0) {
            NSInteger years  = featuredPet.ageInMonths / 12;
            NSInteger months = featuredPet.ageInMonths % 12;
            if (years > 0 && months > 0) {
                [details appendFormat:@"\n📅 %ld %@ · %ld %@",
                 (long)years, (kLang(@"pet_years") ?: @"yr"),
                 (long)months, (kLang(@"pet_months") ?: @"mo")];
            } else if (years > 0) {
                [details appendFormat:@"\n📅 %ld %@", (long)years, (kLang(@"pet_years") ?: @"yr")];
            } else {
                [details appendFormat:@"\n📅 %ld %@", (long)months, (kLang(@"pet_months") ?: @"mo")];
            }
        }

        NSInteger petVacc = featuredPet.vaccinations.count;
        [details appendFormat:@"\n💉 %ld %@", (long)petVacc, (kLang(@"pet_vaccines_short") ?: @"vaccines")];

        if (featuredPet.isDefaultPet) {
            [details appendFormat:@"\n⭐️ %@", kLang(@"pet_default_action") ?: @"Default pet"];
        }

        self.iPadSideBody.text = details;
    } else {
        // Promo card — encourage adding a pet
        self.iPadSideIcon.image = [UIImage systemImageNamed:@"plus.circle.fill"];
        self.iPadSideTitle.text = kLang(@"ipad_promo_title") ?: @"Why Pet Profiles?";
        self.iPadSideBody.text  = kLang(@"ipad_promo_body")
            ?: @"🐾 Keep all your pet details in one place\n💉 Track vaccinations & next-due dates\n⏰ Set reminders for food, vet visits & grooming\n📋 Quick access to breed, age & health notes";
    }
}

- (void)pp_updateHeaderLayout {
    if (!self.headerRoot) {
        return;
    }

    CGFloat headerWidth = CGRectGetWidth(self.tableView.bounds);
    if (headerWidth <= 0.0) {
        headerWidth = CGRectGetWidth(self.view.bounds);
    }

    CGRect bounds = self.headerRoot.bounds;
    if (ABS(bounds.size.width - headerWidth) > 0.5) {
        bounds.size.width = headerWidth;
        self.headerRoot.bounds = bounds;
    }

    [self.headerRoot setNeedsLayout];
    [self.headerRoot layoutIfNeeded];
    CGFloat headerHeight = [self.headerRoot systemLayoutSizeFittingSize:CGSizeMake(headerWidth, UILayoutFittingCompressedSize.height)
                                         withHorizontalFittingPriority:UILayoutPriorityRequired
                                               verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
    CGRect frame = self.headerRoot.frame;
    frame.size.width = headerWidth;
    frame.size.height = headerHeight;
    self.headerRoot.frame = frame;
    self.tableView.tableHeaderView = self.headerRoot;
}

#pragma mark - Data

- (void)pp_reload {
    if (!self.tableView.refreshControl.isRefreshing && self.pets.count == 0) {
        self.isLoading = YES;
        [self.tableView reloadData];
    }

    __weak typeof(self) ws = self;
    [[UserManager sharedManager] fetchPetProfilesForCurrentUserWithCompletion:^(NSArray<PPPetProfile *> *pets, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ws.tableView.refreshControl endRefreshing];
            ws.isLoading = NO;

            if (error) {
                [PPHUD showError:(kLang(@"SomethingWentWrong") ?: @"Error") subtitle:error.localizedDescription];
                [ws.tableView reloadData];
                [ws pp_updateEmptyState];
                return;
            }

            ws.pets = pets ?: @[];
            ws.hasAppearedOnce = NO;
            [ws pp_refreshHeroHeaderContent];
            [ws.tableView reloadData];
            [ws pp_updateEmptyState];
        });
    }];
}

- (void)pp_pullRefresh { [self pp_reload]; }

- (void)pp_updateEmptyState {
    // Empty state handled inline via table rows below hero
}

#pragma mark - Actions

- (void)pp_handleBack {
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)pp_addPet {
    PPPetProfileEditorViewController *ed = [[PPPetProfileEditorViewController alloc] initWithPet:nil];
    [self.navigationController pushViewController:ed animated:YES];
}

- (void)pp_openReminders {
    PPPetRemindersViewController *vc = [PPPetRemindersViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)pp_deletePetAtIndex:(NSInteger)idx {
    if (idx < 0 || idx >= (NSInteger)self.pets.count) return;
    PPPetProfile *pet = self.pets[idx];

    __weak typeof(self) ws = self;
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"pet_delete_confirm_title") ?: @"Delete Pet"
                             subtitle:[NSString stringWithFormat:kLang(@"pet_delete_confirm_msg") ?: @"Are you sure you want to delete %@?", pet.name ?: @""]
                        confirmButton:kLang(@"Delete") ?: @"Delete"
                         cancelButton:kLang(@"Cancel") ?: @"Cancel"
                                 icon:[UIImage systemImageNamed:@"trash.circle.fill"]
                         confirmBlock:^(__unused NSString *t, __unused BOOL c) {
        [PPHUD showIndeterminateIn:ws.view title:(kLang(@"please_wait") ?: @"Deleting…") subtitle:nil];
        [[UserManager sharedManager] deletePetProfileWithID:pet.petID completion:^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    [PPHUD showError:(kLang(@"SomethingWentWrong") ?: @"Error") subtitle:error.localizedDescription];
                } else {
                    [PPHUD showSuccess:(kLang(@"Done") ?: @"Deleted") subtitle:nil];
                    [ws pp_reload];
                }
            });
        }];
    } cancelBlock:nil];
}

- (void)pp_makeDefaultAtIndex:(NSInteger)idx {
    if (idx < 0 || idx >= (NSInteger)self.pets.count) return;
    PPPetProfile *pet = self.pets[idx];

    __weak typeof(self) ws = self;
    [PPHUD showIndeterminateIn:self.view title:(kLang(@"please_wait") ?: @"Please wait") subtitle:nil];
    [[UserManager sharedManager] setDefaultPetProfileID:pet.petID completion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [PPHUD showError:(kLang(@"SomethingWentWrong") ?: @"Error") subtitle:error.localizedDescription];
            } else {
                [PPHUD showSuccess:(kLang(@"Done") ?: @"Done") subtitle:nil];
                [ws pp_reload];
            }
        });
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.isLoading) return 5;
    return self.pets.count > 0 ? (NSInteger)self.pets.count : 1; // 1 = empty-message row
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isLoading) {
        return [tableView dequeueReusableCellWithIdentifier:kSkeletonCellID forIndexPath:indexPath];
    }

    // Empty-message row
    if (self.pets.count == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kEmptyCellID forIndexPath:indexPath];
        cell.selectionStyle  = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = UIColor.clearColor;
        cell.contentView.backgroundColor = UIColor.clearColor;

        static NSInteger const kEmptyTag = 9920;
        UILabel *lbl = [cell.contentView viewWithTag:kEmptyTag];
        if (!lbl) {
            lbl = [[UILabel alloc] init];
            lbl.tag = kEmptyTag;
            lbl.translatesAutoresizingMaskIntoConstraints = NO;
            lbl.numberOfLines = 0;
            lbl.textAlignment = NSTextAlignmentCenter;
            lbl.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
            [cell.contentView addSubview:lbl];
            [NSLayoutConstraint activateConstraints:@[
                [lbl.topAnchor      constraintEqualToAnchor:cell.contentView.topAnchor      constant:32.0],
                [lbl.leadingAnchor  constraintEqualToAnchor:cell.contentView.leadingAnchor  constant:32.0],
                [lbl.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-32.0],
                [lbl.bottomAnchor   constraintEqualToAnchor:cell.contentView.bottomAnchor   constant:-32.0],
            ]];
        }
        lbl.textColor = PPPetsUISecondaryTextColor();
        lbl.text = kLang(@"pet_profiles_empty_subtitle") ?: @"You haven't added any pets yet.\nTap + to create your first pet profile 🐾";
        return cell;
    }

    PPPetProfileCardCell *cell = [tableView dequeueReusableCellWithIdentifier:kCardCellID forIndexPath:indexPath];
    if (indexPath.row < (NSInteger)self.pets.count) {
        [cell configureWithPet:self.pets[indexPath.row]];
    }
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.isLoading ? 88.0 : UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 88.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isLoading || indexPath.row >= (NSInteger)self.pets.count) return;
    PPPetProfileEditorViewController *ed = [[PPPetProfileEditorViewController alloc] initWithPet:self.pets[indexPath.row]];
    [self.navigationController pushViewController:ed animated:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    if (self.isLoading || self.pets.count == 0) return nil;

    __weak typeof(self) ws = self;
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                     title:kLang(@"Delete") ?: @"Delete"
                                                                   handler:^(__unused UIContextualAction *a, __unused UIView *sv, void (^ch)(BOOL)) {
        [ws pp_deletePetAtIndex:indexPath.row];
        ch(YES);
    }];
    del.image = [UIImage systemImageNamed:@"trash.fill"];

    UIContextualAction *def = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                     title:kLang(@"pet_default_action") ?: @"Default"
                                                                   handler:^(__unused UIContextualAction *a, __unused UIView *sv, void (^ch)(BOOL)) {
        [ws pp_makeDefaultAtIndex:indexPath.row];
        ch(YES);
    }];
    def.backgroundColor = UIColor.systemYellowColor;
    def.image = [UIImage systemImageNamed:@"star.fill"];

    return [UISwipeActionsConfiguration configurationWithActions:@[del, def]];
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView
    contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
                                       point:(CGPoint)point API_AVAILABLE(ios(13.0)) {
    if (self.isLoading || indexPath.row >= (NSInteger)self.pets.count) return nil;

    __weak typeof(self) ws = self;
    PPPetProfile *pet = self.pets[indexPath.row];

    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil
        actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        UIAction *editAct = [UIAction actionWithTitle:kLang(@"Edit") ?: @"Edit"
                                                image:[UIImage systemImageNamed:@"pencil.circle"]
                                           identifier:nil handler:^(__unused UIAction *a) {
            PPPetProfileEditorViewController *ed = [[PPPetProfileEditorViewController alloc] initWithPet:pet];
            [ws.navigationController pushViewController:ed animated:YES];
        }];
        UIAction *defAct = [UIAction actionWithTitle:kLang(@"pet_default_action") ?: @"Make Default"
                                               image:[UIImage systemImageNamed:@"star.circle"]
                                          identifier:nil handler:^(__unused UIAction *a) {
            [ws pp_makeDefaultAtIndex:indexPath.row];
        }];
        UIAction *delAct = [UIAction actionWithTitle:kLang(@"Delete") ?: @"Delete"
                                               image:[UIImage systemImageNamed:@"trash.circle"]
                                          identifier:nil handler:^(__unused UIAction *a) {
            [ws pp_deletePetAtIndex:indexPath.row];
        }];
        delAct.attributes = UIMenuElementAttributesDestructive;

        return [UIMenu menuWithTitle:@"" children:@[editAct, defAct, delAct]];
    }];
}

#pragma mark - Entrance Animation

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isLoading || self.hasAppearedOnce) return;
    __weak typeof(self) ws = self;

    cell.alpha     = 0;
    cell.transform = CGAffineTransformMakeTranslation(0, 30);

    [UIView animateWithDuration:PPAnimDurationNormal
                          delay:indexPath.row * 0.06
         usingSpringWithDamping:PPAnimSpringDamping
          initialSpringVelocity:PPAnimSpringVelocity
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        cell.alpha     = 1;
        cell.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        __strong typeof(ws) ss = ws;
        if (!ss) return;
        if (indexPath.row >= (NSInteger)ss.pets.count - 1) {
            ss.hasAppearedOnce = YES;
        }
    }];
}

#pragma mark - Dark Mode

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        PPPetsApplyCanvasBackground(self, self.tableView);
        PPPetsRefreshDynamicLayerColors(self.tableView);
    }
}

@end
