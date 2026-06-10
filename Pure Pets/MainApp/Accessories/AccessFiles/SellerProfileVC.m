//
//  SellerProfileVC.m
//  Pure Pets
//
//  Minimal premium seller profile UI
//

#import "SellerProfileVC.h"
#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "PPUniversalCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPImageLoaderManager.h"
#import "PPModernAvatarRenderer.h"

static const CGFloat kSPSpace4 = 4.0;
static const CGFloat kSPSpace8 = 8.0;
static const CGFloat kSPSpace12 = 12.0;
static const CGFloat kSPSpace16 = 16.0;
static const CGFloat kSPSpace20 = 20.0;
static const CGFloat kSPSpace24 = 24.0;
static const CGFloat kSPSpace32 = 32.0;
static const CGFloat kSPAvatarSize = 92.0;
static const CGFloat kSPAvatarShellSize = 108.0;
static const CGFloat kSPSurfaceCornerRadius = 36.0;
static const CGFloat kSPButtonHeight = 50.0;

static UIColor *SPSellerInkColor(void) {
    return AppPrimaryClr ?: [UIColor colorWithWhite:0.08 alpha:1.0];
}

static UIColor *SPSellerSecondaryTextColor(void) {
    return AppSecondaryTextClr ?: [UIColor colorWithWhite:0.42 alpha:1.0];
}

static UIColor *SPSellerSurfaceColor(UITraitCollection *traitCollection) {
    if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return [UIColor colorWithWhite:0.105 alpha:1.0];
    }
    return [AppForgroundColr colorWithAlphaComponent:0.7] ?: UIColor.whiteColor;
}

static UIColor *SPSellerBackgroundColor(UITraitCollection *traitCollection) {
    if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return [UIColor colorWithWhite:0.055 alpha:1.0];
    }
    UIColor *appBackground = AppBageColor();
    return appBackground ?: [UIColor colorWithRed:0.982 green:0.976 blue:0.956 alpha:1.0];
}

static UIColor *SPSellerAccentTealColor(void) {
    return [AppPrimaryClr colorWithAlphaComponent:1.0];
}

static UIColor *SPSellerGoldColor(void) {
    return [UIColor colorWithRed:0.78 green:0.62 blue:0.30 alpha:1.0];
}

static UIColor *SPSellerRoseColor(void) {
    return [UIColor colorWithRed:0.72 green:0.28 blue:0.34 alpha:1.0];
}

@interface SellerProfileVC () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, PPUniversalCellDelegate>

@property (nonatomic, strong) UIView *glowTopView;
@property (nonatomic, strong) UIView *glowMiddleView;
@property (nonatomic, strong) UIView *glowBottomView;
@property (nonatomic, assign) BOOL livingBackgroundActive;
@property (nonatomic, assign) BOOL didAnimateEntrance;
@property (nonatomic, assign) BOOL didRequestSellerItems;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *heroSurfaceView;
@property (nonatomic, strong) UIView *avatarShellView;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *statusBadgeLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UIStackView *contactButtonStack;
@property (nonatomic, strong) UIButton *messageButton;
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UILabel *itemsTitleLabel;
@property (nonatomic, strong) UILabel *itemsStateLabel;
@property (nonatomic, strong) UIActivityIndicatorView *itemsActivityIndicator;
@property (nonatomic, strong) UICollectionView *itemsCollectionView;
@property (nonatomic, strong) NSMutableArray<PPUniversalCellViewModel *> *itemViewModels;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *animatedItemIndexes;
@property (nonatomic, strong) NSLayoutConstraint *collectionHeightConstraint;

@end

@implementation SellerProfileVC

- (instancetype)init {
    self = [super init];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
        _itemViewModels = [NSMutableArray array];
        _animatedItemIndexes = [NSMutableSet set];
    }
    return self;
}

- (void)setSeller:(UserModel *)seller {
    _seller = seller;
    if (self.isViewLoaded) {
        [self configureSellerIdentity];
        [self fetchSellerItemsIfNeeded];
    }
}

- (void)setSellerItems:(NSArray<PetAccessory *> *)sellerItems {
    _sellerItems = [sellerItems copy] ?: @[];
    if (self.isViewLoaded) {
        [self applySellerItems:_sellerItems loading:NO];
    }
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupViews];
    [self setupConstraints];
    [self configureSellerIdentity];
    [self applySellerItems:self.sellerItems loading:self.sellerItems.count == 0];
    [self fetchSellerItemsIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applySemanticDirection];
    [self startLivingBackgroundIfNeeded];
    [self animateEntranceIfNeeded];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self stopLivingBackground];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutGlowViews];
    [self updateCollectionHeight];
    [self updateSurfaceShadowPaths];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self applyTheme];
}

#pragma mark - View Setup

- (void)setupViews {
    self.view.backgroundColor = SPSellerBackgroundColor(self.traitCollection);
    self.view.clipsToBounds = YES;

    [self setupLivingBackground];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = YES;
    if (@available(iOS 11.0, *)) {
        self.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    }
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentView.backgroundColor = UIColor.clearColor;
    [self.scrollView addSubview:self.contentView];

    [self setupHeroSurface];
    [self setupItemsSection];
    [self applyTheme];
}

- (void)setupLivingBackground {
    self.glowTopView = [self createGlowViewWithColor:SPSellerAccentTealColor()];
    self.glowMiddleView = [self createGlowViewWithColor:SPSellerRoseColor()];
    self.glowBottomView = [self createGlowViewWithColor:SPSellerGoldColor()];

    [self.view addSubview:self.glowTopView];
    [self.view addSubview:self.glowMiddleView];
    [self.view addSubview:self.glowBottomView];
}

- (UIView *)createGlowViewWithColor:(UIColor *)color {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.userInteractionEnabled = NO;
    view.backgroundColor = [color colorWithAlphaComponent:0.13];
    view.layer.shadowColor = color.CGColor;
    view.layer.shadowOpacity = 0.20;
    view.layer.shadowRadius = 44.0;
    view.layer.shadowOffset = CGSizeZero;
    view.alpha = 0.72;
    return view;
}

- (void)setupHeroSurface {
    self.heroSurfaceView = [self createSurfaceView];
    [self.contentView addSubview:self.heroSurfaceView];

    self.avatarShellView = [[UIView alloc] init];
    self.avatarShellView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarShellView.backgroundColor = [SPSellerSurfaceColor(self.traitCollection) colorWithAlphaComponent:0.94];
    self.avatarShellView.layer.cornerRadius = kSPAvatarShellSize / 2.0;
    self.avatarShellView.layer.borderWidth = 1.0;
    [self.avatarShellView pp_setBorderColor:[SPSellerInkColor() colorWithAlphaComponent:0.07]];
    [self.heroSurfaceView addSubview:self.avatarShellView];

    self.avatarImageView = [[UIImageView alloc] initWithImage:PPSYSImage(@"person.crop.circle.fill")];
    self.avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarImageView.layer.cornerRadius = kSPAvatarSize / 2.0;
    self.avatarImageView.layer.masksToBounds = YES;
    self.avatarImageView.backgroundColor = [SPSellerInkColor() colorWithAlphaComponent:0.045];
    self.avatarImageView.tintColor = [SPSellerSecondaryTextColor() colorWithAlphaComponent:0.72];
    [self.avatarShellView addSubview:self.avatarImageView];

    self.eyebrowLabel = [self labelWithFont:[GM boldFontWithSize:12] color:SPSellerAccentTealColor() lines:1];
    [self.heroSurfaceView addSubview:self.eyebrowLabel];

    self.nameLabel = [self labelWithFont:[GM boldFontWithSize:30] color:SPSellerInkColor() lines:2];
    self.nameLabel.adjustsFontSizeToFitWidth = YES;
    self.nameLabel.minimumScaleFactor = 0.78;
    [self.heroSurfaceView addSubview:self.nameLabel];

    self.subtitleLabel = [self labelWithFont:[GM MidFontWithSize:15] color:SPSellerSecondaryTextColor() lines:2];
    [self.heroSurfaceView addSubview:self.subtitleLabel];

    self.statusBadgeLabel = [self labelWithFont:[GM boldFontWithSize:12] color:SPSellerAccentTealColor() lines:1];
    self.statusBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.statusBadgeLabel.layer.cornerRadius = 14.0;
    self.statusBadgeLabel.layer.masksToBounds = YES;
    self.statusBadgeLabel.layer.borderWidth = 1.0;
    self.statusBadgeLabel.backgroundColor = [SPSellerAccentTealColor() colorWithAlphaComponent:0.10];
    [self.statusBadgeLabel pp_setBorderColor:[SPSellerAccentTealColor() colorWithAlphaComponent:0.16]];
    [self.heroSurfaceView addSubview:self.statusBadgeLabel];

    self.descriptionLabel = [self labelWithFont:[GM MidFontWithSize:14] color:SPSellerSecondaryTextColor() lines:0];
    [self.heroSurfaceView addSubview:self.descriptionLabel];

    self.messageButton = [self createActionButtonWithTitle:kLang(@"message")
                                                 imageName:@"message.fill"
                                                emphasized:YES
                                                  selector:@selector(handleMessageTap)];
    self.callButton = [self createActionButtonWithTitle:kLang(@"call")
                                              imageName:@"phone.fill"
                                             emphasized:NO
                                               selector:@selector(handleCallTap)];

    self.contactButtonStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.messageButton, self.callButton]];
    self.contactButtonStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contactButtonStack.axis = UILayoutConstraintAxisHorizontal;
    self.contactButtonStack.spacing = kSPSpace12;
    self.contactButtonStack.distribution = UIStackViewDistributionFillEqually;
    [self.heroSurfaceView addSubview:self.contactButtonStack];
}

- (void)setupItemsSection {
    self.itemsTitleLabel = [self labelWithFont:[GM boldFontWithSize:22] color:SPSellerInkColor() lines:1];
    [self.contentView addSubview:self.itemsTitleLabel];

    self.itemsStateLabel = [self labelWithFont:[GM MidFontWithSize:14] color:SPSellerSecondaryTextColor() lines:0];
    self.itemsStateLabel.textAlignment = NSTextAlignmentCenter;
    [self.contentView addSubview:self.itemsStateLabel];

    self.itemsActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.itemsActivityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.itemsActivityIndicator.hidesWhenStopped = YES;
    self.itemsActivityIndicator.color = SPSellerAccentTealColor();
    [self.contentView addSubview:self.itemsActivityIndicator];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumLineSpacing = kSPSpace12;
    layout.minimumInteritemSpacing = kSPSpace12;

    self.itemsCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.itemsCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.itemsCollectionView.backgroundColor = UIColor.clearColor;
    self.itemsCollectionView.scrollEnabled = NO;
    self.itemsCollectionView.showsVerticalScrollIndicator = NO;
    self.itemsCollectionView.dataSource = self;
    self.itemsCollectionView.delegate = self;
    [self.itemsCollectionView registerClass:PPUniversalCell.class forCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier];
    [self.contentView addSubview:self.itemsCollectionView];
}

- (UIView *)createSurfaceView {
    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = [SPSellerSurfaceColor(self.traitCollection) colorWithAlphaComponent:0.75];
    surface.layer.cornerRadius = kSPSurfaceCornerRadius;
    surface.layer.masksToBounds = NO;
    surface.layer.borderWidth = 1.0;
    [surface pp_setBorderColor:[SPSellerInkColor() colorWithAlphaComponent:0.06]];
    [surface pp_setShadowColor:UIColor.blackColor];
    surface.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.24 : 0.08;
    surface.layer.shadowRadius = 24.0;
    surface.layer.shadowOffset = CGSizeMake(0.0, 12.0);

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
    if (@available(iOS 13.0, *)) {
        blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    }
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.layer.cornerRadius = kSPSurfaceCornerRadius;
    blurView.layer.masksToBounds = YES;
    blurView.userInteractionEnabled = NO;
    [surface addSubview:blurView];

    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:surface.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor],
    ]];

    return surface;
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (UIButton *)createActionButtonWithTitle:(NSString *)title
                                imageName:(NSString *)imageName
                               emphasized:(BOOL)emphasized
                                 selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = 17.0;
    button.layer.masksToBounds = YES;
    button.titleLabel.font = [GM boldFontWithSize:15];
    button.tintColor = emphasized ? SPSellerSurfaceColor(self.traitCollection) : SPSellerInkColor();
    button.backgroundColor = emphasized ? SPSellerInkColor() : [SPSellerInkColor() colorWithAlphaComponent:0.045];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:(emphasized ? SPSellerSurfaceColor(self.traitCollection) : SPSellerInkColor()) forState:UIControlStateNormal];
    UIImage *image = PPSYSImage(imageName);
    [button setImage:image forState:UIControlStateNormal];
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 16.0, 0.0, 16.0);
    button.imageEdgeInsets = UIEdgeInsetsMake(0.0, -6.0, 0.0, 6.0);
    button.titleEdgeInsets = UIEdgeInsetsMake(0.0, 6.0, 0.0, -6.0);
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(handleButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(handleButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    return button;
}

- (void)setupConstraints {
    UILayoutGuide *contentGuide;
    UILayoutGuide *frameGuide;
    if (@available(iOS 11.0, *)) {
        contentGuide = self.scrollView.contentLayoutGuide;
        frameGuide = self.scrollView.frameLayoutGuide;
    } else {
        contentGuide = (id)self.scrollView;
        frameGuide = (id)self.scrollView;
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:contentGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:contentGuide.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:frameGuide.widthAnchor],

        [self.heroSurfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:kSPSpace24],
        [self.heroSurfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kSPSpace16],
        [self.heroSurfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kSPSpace16],

        [self.avatarShellView.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:kSPSpace24],
        [self.avatarShellView.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:kSPSpace20],
        [self.avatarShellView.widthAnchor constraintEqualToConstant:kSPAvatarShellSize],
        [self.avatarShellView.heightAnchor constraintEqualToConstant:kSPAvatarShellSize],

        [self.avatarImageView.centerXAnchor constraintEqualToAnchor:self.avatarShellView.centerXAnchor],
        [self.avatarImageView.centerYAnchor constraintEqualToAnchor:self.avatarShellView.centerYAnchor],
        [self.avatarImageView.widthAnchor constraintEqualToConstant:kSPAvatarSize],
        [self.avatarImageView.heightAnchor constraintEqualToConstant:kSPAvatarSize],

        [self.statusBadgeLabel.topAnchor constraintEqualToAnchor:self.heroSurfaceView.topAnchor constant:kSPSpace24],
        [self.statusBadgeLabel.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-kSPSpace20],
        [self.statusBadgeLabel.heightAnchor constraintEqualToConstant:28.0],
        [self.statusBadgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:96.0],

        [self.eyebrowLabel.topAnchor constraintEqualToAnchor:self.avatarShellView.bottomAnchor constant:kSPSpace20],
        [self.eyebrowLabel.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:kSPSpace20],
        [self.eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-kSPSpace20],

        [self.nameLabel.topAnchor constraintEqualToAnchor:self.eyebrowLabel.bottomAnchor constant:kSPSpace8],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.eyebrowLabel.leadingAnchor],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-kSPSpace20],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:kSPSpace8],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.nameLabel.trailingAnchor],

        [self.descriptionLabel.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:kSPSpace20],
        [self.descriptionLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.descriptionLabel.trailingAnchor constraintEqualToAnchor:self.nameLabel.trailingAnchor],

        [self.contactButtonStack.topAnchor constraintEqualToAnchor:self.descriptionLabel.bottomAnchor constant:kSPSpace20],
        [self.contactButtonStack.leadingAnchor constraintEqualToAnchor:self.heroSurfaceView.leadingAnchor constant:kSPSpace20],
        [self.contactButtonStack.trailingAnchor constraintEqualToAnchor:self.heroSurfaceView.trailingAnchor constant:-kSPSpace20],
        [self.contactButtonStack.bottomAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:-kSPSpace20],
        [self.messageButton.heightAnchor constraintEqualToConstant:kSPButtonHeight],

        [self.itemsTitleLabel.topAnchor constraintEqualToAnchor:self.heroSurfaceView.bottomAnchor constant:kSPSpace32],
        [self.itemsTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kSPSpace20],
        [self.itemsTitleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kSPSpace20],

        [self.itemsActivityIndicator.topAnchor constraintEqualToAnchor:self.itemsTitleLabel.bottomAnchor constant:kSPSpace24],
        [self.itemsActivityIndicator.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],

        [self.itemsStateLabel.topAnchor constraintEqualToAnchor:self.itemsTitleLabel.bottomAnchor constant:kSPSpace20],
        [self.itemsStateLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kSPSpace32],
        [self.itemsStateLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kSPSpace32],

        [self.itemsCollectionView.topAnchor constraintEqualToAnchor:self.itemsTitleLabel.bottomAnchor constant:kSPSpace16],
        [self.itemsCollectionView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kSPSpace16],
        [self.itemsCollectionView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kSPSpace16],
        [self.itemsCollectionView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-kSPSpace32],
    ]];

    self.collectionHeightConstraint = [self.itemsCollectionView.heightAnchor constraintEqualToConstant:0.0];
    self.collectionHeightConstraint.active = YES;
}

#pragma mark - Theme

- (void)applyTheme {
    self.view.backgroundColor = SPSellerBackgroundColor(self.traitCollection);
    self.heroSurfaceView.backgroundColor = SPSellerSurfaceColor(self.traitCollection);
    [self.heroSurfaceView pp_setBorderColor:[SPSellerInkColor() colorWithAlphaComponent:0.06]];
    self.avatarShellView.backgroundColor = [SPSellerSurfaceColor(self.traitCollection) colorWithAlphaComponent:0.94];
    self.messageButton.backgroundColor = SPSellerInkColor();
    [self.messageButton setTitleColor:SPSellerSurfaceColor(self.traitCollection) forState:UIControlStateNormal];
    self.messageButton.tintColor = SPSellerSurfaceColor(self.traitCollection);
    self.callButton.backgroundColor = [SPSellerInkColor() colorWithAlphaComponent:0.045];
    [self.callButton setTitleColor:SPSellerInkColor() forState:UIControlStateNormal];
    self.callButton.tintColor = SPSellerInkColor();
    self.glowTopView.backgroundColor = [SPSellerAccentTealColor() colorWithAlphaComponent:self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.16 : 0.11];
    self.glowMiddleView.backgroundColor = [SPSellerRoseColor() colorWithAlphaComponent:self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.13 : 0.08];
    self.glowBottomView.backgroundColor = [SPSellerGoldColor() colorWithAlphaComponent:self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.14 : 0.10];
}

- (void)applySemanticDirection {
    UISemanticContentAttribute semantic = [Language semanticAttributeForCurrentLanguage];
    self.view.semanticContentAttribute = semantic;
    self.heroSurfaceView.semanticContentAttribute = semantic;
    self.contactButtonStack.semanticContentAttribute = semantic;
    self.itemsCollectionView.semanticContentAttribute = semantic;

    NSArray<UILabel *> *labels = @[
        self.eyebrowLabel,
        self.nameLabel,
        self.subtitleLabel,
        self.descriptionLabel,
        self.itemsTitleLabel,
        self.itemsStateLabel
    ];
    for (UILabel *label in labels) {
        label.textAlignment = Language.alignmentForCurrentLanguage;
    }

    self.messageButton.semanticContentAttribute = semantic;
    self.callButton.semanticContentAttribute = semantic;
}

#pragma mark - Data

- (void)configureSellerIdentity {
    self.eyebrowLabel.text = kLang(@"premium_seller");
    self.nameLabel.text = [self sellerDisplayName];
    self.subtitleLabel.text = self.seller.UserAbout.length > 0 ? self.seller.UserAbout : kLang(@"premium_seller_on_platform");
    self.statusBadgeLabel.text = kLang(@"verified");
    self.descriptionLabel.text = kLang(@"premium_seller_description");
    self.itemsTitleLabel.text = kLang(@"seller_items");

    UIImage *placeholder = [PPModernAvatarRenderer avatarImageForName:[self sellerDisplayName] size:kSPAvatarSize];
    self.avatarImageView.image = placeholder ?: PPSYSImage(@"person.crop.circle.fill");

    NSString *imageURL = PPSafeString(self.seller.UserImageUrl.absoluteString);
    if (imageURL.length > 0) {
        [PPImageLoaderManager.shared setImageOnImageView:self.avatarImageView
                                                     url:imageURL
                                             placeholder:self.avatarImageView.image
                                              complation:nil];
    }

    BOOL canContact = self.seller != nil;
    BOOL canCall = self.seller.MobileNo.length > 0;
    self.messageButton.enabled = canContact;
    self.callButton.enabled = canCall;
    self.messageButton.alpha = canContact ? 1.0 : 0.48;
    self.callButton.alpha = canCall ? 1.0 : 0.48;
    [self updateAccessibility];
}

- (NSString *)sellerDisplayName {
    if (!self.seller) return kLang(@"premium_seller");

    NSMutableArray<NSString *> *nameParts = [NSMutableArray array];
    if (self.seller.FirstName.length > 0) [nameParts addObject:self.seller.FirstName];
    if (self.seller.LastName.length > 0) [nameParts addObject:self.seller.LastName];
    if (nameParts.count > 0) return [nameParts componentsJoinedByString:@" "];

    if ([self.seller respondsToSelector:@selector(bestDisplayName)]) {
        NSString *name = [self.seller bestDisplayName];
        if (name.length > 0) return name;
    }
    if ([self.seller respondsToSelector:@selector(PPBestDisplayName)]) {
        NSString *name = [self.seller PPBestDisplayName];
        if (name.length > 0) return name;
    }
    if (self.seller.UserName.length > 0) return self.seller.UserName;
    return kLang(@"premium_seller");
}

- (NSString *)sellerID {
    return PPSafeString(self.seller.ID);
}

- (void)fetchSellerItemsIfNeeded {
    NSString *sellerID = [self sellerID];
    if (sellerID.length == 0 || self.didRequestSellerItems) {
        if (self.sellerItems.count == 0) {
            [self applySellerItems:@[] loading:NO];
        }
        return;
    }

    self.didRequestSellerItems = YES;
    if (self.sellerItems.count == 0) {
        [self applySellerItems:@[] loading:YES];
    }

    __weak typeof(self) weakSelf = self;
    [PetAccessoryManager fetchProviderMarketplaceAccessoriesForOwnerID:sellerID
                                                     excludingAccessory:nil
                                                            completion:^(NSArray<PetAccessory *> *accessories) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            NSArray<PetAccessory *> *mergedItems = [strongSelf mergedItemsWithFetchedItems:accessories ?: @[]];
            strongSelf->_sellerItems = [mergedItems copy];
            [strongSelf applySellerItems:mergedItems loading:NO];
        });
    }];
}

- (NSArray<PetAccessory *> *)mergedItemsWithFetchedItems:(NSArray<PetAccessory *> *)fetchedItems {
    NSMutableArray<PetAccessory *> *items = [NSMutableArray array];
    NSMutableSet<NSString *> *seenIDs = [NSMutableSet set];

    void (^appendItem)(PetAccessory *) = ^(PetAccessory *item) {
        if (![self shouldDisplayAccessory:item]) return;
        NSString *itemID = PPSafeString(item.accessoryID);
        if (itemID.length > 0 && [seenIDs containsObject:itemID]) return;
        if (itemID.length > 0) [seenIDs addObject:itemID];
        [items addObject:item];
    };

    for (PetAccessory *item in self.sellerItems) appendItem(item);
    for (PetAccessory *item in fetchedItems) appendItem(item);
    return items.copy;
}

- (BOOL)shouldDisplayAccessory:(PetAccessory *)item {
    if (![item isKindOfClass:PetAccessory.class]) return NO;
    if (item.isBlocked || item.isDeleted || item.isDisabled) return NO;
    NSString *sellerID = [self sellerID];
    if (sellerID.length > 0 && item.ownerID.length > 0 && ![item.ownerID isEqualToString:sellerID]) {
        return NO;
    }
    return YES;
}

- (void)applySellerItems:(NSArray<PetAccessory *> *)items loading:(BOOL)loading {
    [self.itemViewModels removeAllObjects];
    [self.animatedItemIndexes removeAllObjects];

    for (PetAccessory *item in items) {
        if (![self shouldDisplayAccessory:item]) continue;
        PPCellContext context = item.accessKindType == AccessTypeFood ? PPCellForFood : PPCellForMarket;
        PPUniversalCellViewModel *viewModel = [[PPUniversalCellViewModel alloc] initWithModel:item context:context];
        [self.itemViewModels addObject:viewModel];
    }

    BOOL hasItems = self.itemViewModels.count > 0;
    self.itemsCollectionView.hidden = !hasItems;
    self.itemsStateLabel.hidden = hasItems || loading;
    self.itemsStateLabel.text = hasItems ? @"" : kLang(@"seller_profile_empty_items");

    if (loading) {
        [self.itemsActivityIndicator startAnimating];
    } else {
        [self.itemsActivityIndicator stopAnimating];
    }

    [self.itemsCollectionView reloadData];
    [self updateCollectionHeight];
}

#pragma mark - Layout Helpers

- (void)layoutGlowViews {
    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);

    self.glowTopView.frame = CGRectMake(-118.0, 72.0, 246.0, 246.0);
    self.glowMiddleView.frame = CGRectMake(width - 132.0, height * 0.30, 226.0, 226.0);
    self.glowBottomView.frame = CGRectMake(width * 0.15, MAX(height - 236.0, 320.0), 286.0, 286.0);

    self.glowTopView.layer.cornerRadius = CGRectGetWidth(self.glowTopView.bounds) / 2.0;
    self.glowMiddleView.layer.cornerRadius = CGRectGetWidth(self.glowMiddleView.bounds) / 2.0;
    self.glowBottomView.layer.cornerRadius = CGRectGetWidth(self.glowBottomView.bounds) / 2.0;
}

- (void)updateSurfaceShadowPaths {
    if (!CGRectIsEmpty(self.heroSurfaceView.bounds)) {
        self.heroSurfaceView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.heroSurfaceView.bounds
                                       cornerRadius:kSPSurfaceCornerRadius].CGPath;
    }
}

- (CGSize)itemSizeForCollectionWidth:(CGFloat)collectionWidth {
    NSInteger columns = collectionWidth < 330.0 ? 1 : 2;
    CGFloat spacing = columns == 1 ? 0.0 : kSPSpace12;
    CGFloat itemWidth = floor((collectionWidth - spacing) / columns);
    return CGSizeMake(itemWidth, itemWidth + 84.0);
}

- (void)updateCollectionHeight {
    if (!self.collectionHeightConstraint) return;
    if (self.itemViewModels.count == 0) {
        self.collectionHeightConstraint.constant = 0.0;
        return;
    }

    CGFloat width = CGRectGetWidth(self.itemsCollectionView.bounds);
    if (width <= 0.0) {
        width = CGRectGetWidth(self.view.bounds) - (kSPSpace16 * 2.0);
    }
    CGSize itemSize = [self itemSizeForCollectionWidth:width];
    NSInteger columns = width < 330.0 ? 1 : 2;
    NSInteger rows = (self.itemViewModels.count + columns - 1) / columns;
    CGFloat spacing = kSPSpace12 * MAX(rows - 1, 0);
    self.collectionHeightConstraint.constant = rows * itemSize.height + spacing;
}

#pragma mark - Motion

- (void)startLivingBackgroundIfNeeded {
    if (self.livingBackgroundActive || UIAccessibilityIsReduceMotionEnabled()) return;
    self.livingBackgroundActive = YES;
    [self animateGlowView:self.glowTopView
                  keyPath:@"seller.profile.glow.top"
                    scale:1.08
              translation:CGPointMake(14.0, -10.0)
                 duration:6.8
                    delay:0.0];
    [self animateGlowView:self.glowMiddleView
                  keyPath:@"seller.profile.glow.middle"
                    scale:1.10
              translation:CGPointMake(-16.0, 18.0)
                 duration:7.6
                    delay:0.35];
    [self animateGlowView:self.glowBottomView
                  keyPath:@"seller.profile.glow.bottom"
                    scale:1.07
              translation:CGPointMake(18.0, 12.0)
                 duration:8.4
                    delay:0.18];
}

- (void)animateGlowView:(UIView *)view
                keyPath:(NSString *)key
                  scale:(CGFloat)scale
            translation:(CGPoint)translation
               duration:(NSTimeInterval)duration
                  delay:(NSTimeInterval)delay {
    view.transform = CGAffineTransformIdentity;
    [UIView animateWithDuration:duration
                          delay:delay
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        view.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(translation.x, translation.y),
                                                 CGAffineTransformMakeScale(scale, scale));
        view.alpha = 0.92;
    } completion:nil];
    (void)key;
}

- (void)stopLivingBackground {
    self.livingBackgroundActive = NO;
    NSArray<UIView *> *glows = @[self.glowTopView, self.glowMiddleView, self.glowBottomView];
    for (UIView *view in glows) {
        [view.layer removeAllAnimations];
        view.transform = CGAffineTransformIdentity;
    }
}

- (void)animateEntranceIfNeeded {
    if (self.didAnimateEntrance || UIAccessibilityIsReduceMotionEnabled()) {
        self.heroSurfaceView.alpha = 1.0;
        self.itemsTitleLabel.alpha = 1.0;
        self.itemsCollectionView.alpha = 1.0;
        return;
    }
    self.didAnimateEntrance = YES;

    NSArray<UIView *> *views = @[self.heroSurfaceView, self.itemsTitleLabel, self.itemsCollectionView];
    [views enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 18.0);
        [UIView animateWithDuration:0.52
                              delay:0.06 * idx
             usingSpringWithDamping:0.92
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)animateCellIfNeeded:(UICollectionViewCell *)cell index:(NSInteger)index {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
        return;
    }

    NSNumber *key = @(index);
    if ([self.animatedItemIndexes containsObject:key]) {
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
        return;
    }
    [self.animatedItemIndexes addObject:key];

    cell.alpha = 0.0;
    cell.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
    NSTimeInterval delay = MIN(index * 0.035, 0.18);
    [UIView animateWithDuration:0.36
                          delay:delay
         usingSpringWithDamping:0.95
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)handleButtonTouchDown:(UIButton *)sender {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.965, 0.965);
    } completion:nil];
}

- (void)handleButtonTouchUp:(UIButton *)sender {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.20
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        sender.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Collection View

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.itemViewModels.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPUniversalCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPUniversalCell.reuseIdentifier
                                                                      forIndexPath:indexPath];
    if (indexPath.item >= self.itemViewModels.count) return cell;

    PPUniversalCellViewModel *viewModel = self.itemViewModels[indexPath.item];
    viewModel.indexPath = indexPath;
    cell.delegate = self;
    cell.showsSubtitle = YES;
    cell.hideTopBadge = NO;

    PetAccessory *item = (PetAccessory *)viewModel.ModelObject;
    PPCellContext context = item.accessKindType == AccessTypeFood ? PPCellForFood : PPCellForMarket;
    [cell applyViewModel:viewModel
                 context:context
              layoutMode:PPCellLayoutModeVertical
            discountMode:PPDiscountStyleBadge
             imageLoader:^void(UIImageView *imageView, NSString *url, UIImage *placeholder, UIView *card) {
        (void)card;
        [PPImageLoaderManager.shared setImageOnImageView:imageView
                                                     url:url
                                             placeholder:placeholder
                                              complation:nil];
    }];

    [self animateCellIfNeeded:cell index:indexPath.item];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [self itemSizeForCollectionWidth:CGRectGetWidth(collectionView.bounds)];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item >= self.itemViewModels.count) return;
    PPUniversalCellViewModel *viewModel = self.itemViewModels[indexPath.item];
    [self notifySelectedItem:viewModel.ModelObject];

    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    if (!cell || UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        cell.transform = CGAffineTransformMakeScale(0.97, 0.97);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.20
                              delay:0.0
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            cell.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel {
    [self notifySelectedItem:universalModel.ModelObject];
}

- (void)notifySelectedItem:(id)item {
    if ([self.delegate respondsToSelector:@selector(sellerProfileDidSelectItem:)]) {
        [self.delegate sellerProfileDidSelectItem:item];
    }
}

#pragma mark - Actions

- (void)handleMessageTap {
    if ([self.delegate respondsToSelector:@selector(sellerProfileDidTapContact:)]) {
        [self.delegate sellerProfileDidTapContact:self.seller];
    }
    [self playLightFeedback];
}

- (void)handleCallTap {
    if ([self.delegate respondsToSelector:@selector(sellerProfileDidTapCall:)]) {
        [self.delegate sellerProfileDidTapCall:self.seller];
    } else if ([self.delegate respondsToSelector:@selector(sellerProfileDidTapContact:)]) {
        [self.delegate sellerProfileDidTapContact:self.seller];
    }
    [self playLightFeedback];
}

- (void)playLightFeedback {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator prepare];
        [generator impactOccurred];
    }
}

- (void)updateAccessibility {
    NSString *sellerName = self.nameLabel.text.length > 0 ? self.nameLabel.text : kLang(@"premium_seller");
    self.avatarImageView.accessibilityLabel = sellerName;
    self.statusBadgeLabel.accessibilityLabel = self.statusBadgeLabel.text;
    self.messageButton.accessibilityLabel = [NSString stringWithFormat:@"%@ %@", kLang(@"message"), sellerName];
    self.callButton.accessibilityLabel = [NSString stringWithFormat:@"%@ %@", kLang(@"call"), sellerName];
}

@end
