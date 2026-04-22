#import "PPPetCareViewController.h"
#import "PPUniversalCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPImageLoaderManager.h"
#import "PPOverlayCoordinator.h"
#import "PetAccessory.h"
#import "PetAccessoryManager.h"
#import "VetManager.h"
#import "VetModel.h"
#import "MainKindsModel.h"
#import "ArabicNormalizer.h"

typedef NS_ENUM(NSInteger, PPPetCareMedicineFilter) {
    PPPetCareMedicineFilterAll = 0,
    PPPetCareMedicineFilterOffers,
    PPPetCareMedicineFilterInStock,
    PPPetCareMedicineFilterNew
};

typedef NS_ENUM(NSInteger, PPPetCareVetFilter) {
    PPPetCareVetFilterAll = 0,
    PPPetCareVetFilterWithPhone,
    PPPetCareVetFilterCompany,
    PPPetCareVetFilterPersonal
};

static NSString * const PPPetCareMedicineCellID = @"PPPetCareMedicineCellID";
static NSString * const PPPetCareVetCellID = @"PPPetCareVetCellID";

static NSString *PPPetCareLocalized(NSString *key, NSString *fallback)
{
    NSString *value = key.length ? kLang(key) : nil;
    return value.length > 0 ? value : fallback;
}

static NSString *PPPetCareSafeString(id value)
{
    return [value isKindOfClass:NSString.class] ? (NSString *)value : @"";
}

static UIColor *PPPetCareTextColor(void)
{
    return AppPrimaryTextClr ?: UIColor.labelColor;
}

static UIColor *PPPetCareSecondaryTextColor(void)
{
    return AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
}

static UIColor *PPPetCareAccentColor(void)
{
    return AppPrimaryClr ?: UIColor.systemTealColor;
}

static UIColor *PPPetCareSurfaceColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark
                ? [UIColor colorWithWhite:1.0 alpha:0.075]
                : [UIColor colorWithWhite:1.0 alpha:0.76];
        }];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.76];
}

static UIColor *PPPetCareBorderColor(void)
{
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            BOOL dark = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            return dark
                ? [UIColor colorWithWhite:1.0 alpha:0.11]
                : [UIColor colorWithRed:0.72 green:0.66 blue:0.62 alpha:0.22];
        }];
    }
    return [UIColor colorWithRed:0.72 green:0.66 blue:0.62 alpha:0.22];
}

static NSString *PPPetCareNormalizedText(NSString *value)
{
    NSString *trimmed = [PPPetCareSafeString(value) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        return @"";
    }
    NSString *normalized = [ArabicNormalizer normalize:trimmed] ?: trimmed;
    return normalized.lowercaseString;
}

@interface PPPetCareVetCell : UICollectionViewCell
@property (nonatomic, copy, nullable) void (^onDetailsTap)(void);
@property (nonatomic, copy, nullable) void (^onCallTap)(void);
+ (NSString *)reuseIdentifier;
- (void)configureWithVet:(VetModel *)vet mainKindName:(NSString *)mainKindName;
@end

@implementation PPPetCareVetCell {
    UIView *_surfaceView;
    UIView *_logoShellView;
    UIImageView *_logoImageView;
    UILabel *_titleLabel;
    UILabel *_descriptionLabel;
    UILabel *_kindPillLabel;
    UILabel *_typePillLabel;
    UILabel *_contactPillLabel;
    UIButton *_detailsButton;
    UIButton *_callButton;
    UIStackView *_pillStackView;
}

+ (NSString *)reuseIdentifier
{
    return PPPetCareVetCellID;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    _surfaceView = [[UIView alloc] init];
    _surfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    _surfaceView.clipsToBounds = NO;
    _surfaceView.layer.cornerRadius = 28.0;
    _surfaceView.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        _surfaceView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    _surfaceView.layer.shadowRadius = 22.0;
    _surfaceView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    [self.contentView addSubview:_surfaceView];

    _logoShellView = [[UIView alloc] init];
    _logoShellView.translatesAutoresizingMaskIntoConstraints = NO;
    _logoShellView.layer.cornerRadius = 28.0;
    _logoShellView.layer.borderWidth = 0.8;
    _logoShellView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _logoShellView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_surfaceView addSubview:_logoShellView];

    _logoImageView = [[UIImageView alloc] init];
    _logoImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _logoImageView.contentMode = UIViewContentModeScaleAspectFill;
    _logoImageView.clipsToBounds = YES;
    _logoImageView.tintColor = PPPetCareAccentColor();
    [_logoShellView addSubview:_logoImageView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:18.0] ?: [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
    _titleLabel.textColor = PPPetCareTextColor();
    _titleLabel.numberOfLines = 1;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.82;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_surfaceView addSubview:_titleLabel];

    _descriptionLabel = [[UILabel alloc] init];
    _descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _descriptionLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    _descriptionLabel.textColor = PPPetCareSecondaryTextColor();
    _descriptionLabel.numberOfLines = 2;
    _descriptionLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_surfaceView addSubview:_descriptionLabel];

    _pillStackView = [[UIStackView alloc] init];
    _pillStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _pillStackView.axis = UILayoutConstraintAxisHorizontal;
    _pillStackView.alignment = UIStackViewAlignmentCenter;
    _pillStackView.spacing = 7.0;
    _pillStackView.distribution = UIStackViewDistributionFillProportionally;
    [_surfaceView addSubview:_pillStackView];

    _kindPillLabel = [self pp_makePillLabel];
    _typePillLabel = [self pp_makePillLabel];
    _contactPillLabel = [self pp_makePillLabel];
    [_pillStackView addArrangedSubview:_kindPillLabel];
    [_pillStackView addArrangedSubview:_typePillLabel];
    [_pillStackView addArrangedSubview:_contactPillLabel];

    _detailsButton = [self pp_makeActionButtonPrimary:YES];
    [_detailsButton setTitle:PPPetCareLocalized(@"pet_care_details", @"Details") forState:UIControlStateNormal];
    [_detailsButton addTarget:self action:@selector(pp_detailsTapped) forControlEvents:UIControlEventTouchUpInside];
    [_surfaceView addSubview:_detailsButton];

    _callButton = [self pp_makeActionButtonPrimary:NO];
    [_callButton setTitle:PPPetCareLocalized(@"pet_care_call", @"Call") forState:UIControlStateNormal];
    [_callButton addTarget:self action:@selector(pp_callTapped) forControlEvents:UIControlEventTouchUpInside];
    [_surfaceView addSubview:_callButton];

    [NSLayoutConstraint activateConstraints:@[
        [_surfaceView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
        [_surfaceView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_surfaceView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_surfaceView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],

        [_logoShellView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:14.0],
        [_logoShellView.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:14.0],
        [_logoShellView.widthAnchor constraintEqualToConstant:56.0],
        [_logoShellView.heightAnchor constraintEqualToConstant:56.0],

        [_logoImageView.topAnchor constraintEqualToAnchor:_logoShellView.topAnchor],
        [_logoImageView.leadingAnchor constraintEqualToAnchor:_logoShellView.leadingAnchor],
        [_logoImageView.trailingAnchor constraintEqualToAnchor:_logoShellView.trailingAnchor],
        [_logoImageView.bottomAnchor constraintEqualToAnchor:_logoShellView.bottomAnchor],

        [_titleLabel.topAnchor constraintEqualToAnchor:_surfaceView.topAnchor constant:16.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_logoShellView.trailingAnchor constant:14.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-16.0],

        [_descriptionLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:5.0],
        [_descriptionLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_descriptionLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

        [_pillStackView.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:14.0],
        [_pillStackView.trailingAnchor constraintLessThanOrEqualToAnchor:_surfaceView.trailingAnchor constant:-14.0],
        [_pillStackView.topAnchor constraintEqualToAnchor:_logoShellView.bottomAnchor constant:14.0],
        [_pillStackView.heightAnchor constraintEqualToConstant:28.0],

        [_detailsButton.leadingAnchor constraintEqualToAnchor:_surfaceView.leadingAnchor constant:14.0],
        [_detailsButton.bottomAnchor constraintEqualToAnchor:_surfaceView.bottomAnchor constant:-14.0],
        [_detailsButton.heightAnchor constraintEqualToConstant:38.0],

        [_callButton.leadingAnchor constraintEqualToAnchor:_detailsButton.trailingAnchor constant:10.0],
        [_callButton.trailingAnchor constraintEqualToAnchor:_surfaceView.trailingAnchor constant:-14.0],
        [_callButton.widthAnchor constraintEqualToAnchor:_detailsButton.widthAnchor],
        [_callButton.centerYAnchor constraintEqualToAnchor:_detailsButton.centerYAnchor],
        [_callButton.heightAnchor constraintEqualToAnchor:_detailsButton.heightAnchor],
    ]];

    [self pp_applyTheme];
    return self;
}

- (UILabel *)pp_makePillLabel
{
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.78;
    label.layer.cornerRadius = 14.0;
    label.layer.masksToBounds = YES;
    label.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        label.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [label.widthAnchor constraintGreaterThanOrEqualToConstant:70.0].active = YES;
    return label;
}

- (UIButton *)pp_makeActionButtonPrimary:(BOOL)primary
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    button.layer.cornerRadius = 19.0;
    button.layer.borderWidth = primary ? 0.0 : 0.8;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return button;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:_logoImageView];
    _logoImageView.image = nil;
    _titleLabel.text = nil;
    _descriptionLabel.text = nil;
    _kindPillLabel.text = nil;
    _typePillLabel.text = nil;
    _contactPillLabel.text = nil;
    self.onDetailsTap = nil;
    self.onCallTap = nil;
    self.transform = CGAffineTransformIdentity;
    self.alpha = 1.0;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _surfaceView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:_surfaceView.bounds
                                   cornerRadius:_surfaceView.layer.cornerRadius].CGPath;
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

- (void)pp_applyTheme
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    _surfaceView.backgroundColor = PPPetCareSurfaceColor();
    [_surfaceView pp_setBorderColor:PPPetCareBorderColor()];
    _surfaceView.layer.shadowOpacity = dark ? 0.0 : 0.08;
    [_logoShellView pp_setBorderColor:PPPetCareBorderColor()];
    _logoShellView.backgroundColor = [PPPetCareAccentColor() colorWithAlphaComponent:dark ? 0.13 : 0.09];
    _titleLabel.textColor = PPPetCareTextColor();
    _descriptionLabel.textColor = PPPetCareSecondaryTextColor();

    for (UILabel *pill in @[_kindPillLabel, _typePillLabel, _contactPillLabel]) {
        pill.textColor = PPPetCareTextColor();
        pill.backgroundColor = [PPPetCareAccentColor() colorWithAlphaComponent:dark ? 0.13 : 0.075];
        [pill pp_setBorderColor:[PPPetCareAccentColor() colorWithAlphaComponent:dark ? 0.20 : 0.12]];
    }

    [_detailsButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _detailsButton.backgroundColor = PPPetCareAccentColor();
    [_callButton setTitleColor:PPPetCareTextColor() forState:UIControlStateNormal];
    _callButton.backgroundColor = [PPPetCareAccentColor() colorWithAlphaComponent:dark ? 0.13 : 0.08];
    [_callButton pp_setBorderColor:[PPPetCareAccentColor() colorWithAlphaComponent:dark ? 0.24 : 0.15]];
}

- (void)configureWithVet:(VetModel *)vet mainKindName:(NSString *)mainKindName
{
    [self pp_applyTheme];
    self.semanticContentAttribute = Language.isRTL ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    _titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    _descriptionLabel.textAlignment = [Language alignmentForCurrentLanguage];

    _titleLabel.text = vet.title.length > 0 ? vet.title : PPPetCareLocalized(@"pet_care_vet_untitled", @"Veterinarian");
    _descriptionLabel.text = vet.descriptionText.length > 0
        ? vet.descriptionText
        : PPPetCareLocalized(@"pet_care_vet_default_subtitle", @"Care provider ready for pet health support.");
    _kindPillLabel.text = mainKindName.length > 0 ? mainKindName : PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
    _typePillLabel.text = vet.type == VetTypeCompany
        ? PPPetCareLocalized(@"pet_care_vet_company", @"Clinic")
        : PPPetCareLocalized(@"pet_care_vet_personal", @"Doctor");
    _contactPillLabel.text = (vet.phone.length > 0 || vet.whatsapp.length > 0)
        ? PPPetCareLocalized(@"pet_care_vet_contact_ready", @"Contact ready")
        : PPPetCareLocalized(@"pet_care_vet_no_phone", @"Details only");
    [_detailsButton setTitle:PPPetCareLocalized(@"pet_care_details", @"Details") forState:UIControlStateNormal];
    [_callButton setTitle:PPPetCareLocalized(@"pet_care_call", @"Call") forState:UIControlStateNormal];
    _callButton.enabled = (vet.phone.length > 0 || vet.whatsapp.length > 0);
    _callButton.alpha = _callButton.enabled ? 1.0 : 0.52;

    UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:24.0
                                                        weight:UIImageSymbolWeightSemibold];
    UIImage *placeholder =
        [[UIImage systemImageNamed:@"cross.case.fill" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _logoImageView.image = placeholder;
    _logoImageView.tintColor = PPPetCareAccentColor();
    _logoImageView.backgroundColor = [PPPetCareAccentColor() colorWithAlphaComponent:0.08];

    if (vet.logoURL.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:_logoImageView
                                                       url:vet.logoURL
                                               placeholder:placeholder
                                          transitionStyle:PPImageTransitionStyleFade
                                                complation:nil];
    }

    self.accessibilityLabel = [NSString stringWithFormat:@"%@. %@. %@",
                               _titleLabel.text ?: @"",
                               _descriptionLabel.text ?: @"",
                               _kindPillLabel.text ?: @""];
}

- (void)pp_detailsTapped
{
    if (self.onDetailsTap) {
        self.onDetailsTap();
    }
}

- (void)pp_callTapped
{
    if (self.onCallTap) {
        self.onCallTap();
    }
}

@end

@interface PPPetCareViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITextFieldDelegate, PPUniversalCellDelegate>
@property (nonatomic, assign) PPPetCareInitialSection selectedSection;
@property (nonatomic, assign) PPPetCareMedicineFilter medicineFilter;
@property (nonatomic, assign) PPPetCareVetFilter vetFilter;
@property (nonatomic, strong, nullable) MainKindsModel *selectedMainKind;
@property (nonatomic, copy) NSArray<MainKindsModel *> *mainKinds;
@property (nonatomic, copy) NSArray<PetAccessory *> *allMedicines;
@property (nonatomic, copy) NSArray<PetAccessory *> *filteredMedicines;
@property (nonatomic, copy) NSArray<VetModel *> *allVets;
@property (nonatomic, copy) NSArray<VetModel *> *filteredVets;
@property (nonatomic, strong) UIView *heroView;
@property (nonatomic, strong) UILabel *eyebrowLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *counterLabel;
@property (nonatomic, strong) UISegmentedControl *sectionControl;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIScrollView *kindScrollView;
@property (nonatomic, strong) UIStackView *kindStackView;
@property (nonatomic, strong) UIScrollView *filterScrollView;
@property (nonatomic, strong) UIStackView *filterStackView;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptySubtitleLabel;
@property (nonatomic, assign) BOOL loadingMedicines;
@property (nonatomic, assign) BOOL loadingVets;
@end

@implementation PPPetCareViewController

- (instancetype)initWithInitialSection:(PPPetCareInitialSection)section
                              mainKind:(MainKindsModel *)mainKind
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) {
        return nil;
    }
    _selectedSection = section;
    _selectedMainKind = mainKind;
    _medicineFilter = PPPetCareMedicineFilterAll;
    _vetFilter = PPPetCareVetFilterAll;
    _mainKinds = @[];
    _allMedicines = @[];
    _filteredMedicines = @[];
    _allVets = @[];
    _filteredVets = @[];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr ?: UIColor.systemBackgroundColor;
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto
                      button:nil
                       title:PPPetCareLocalized(@"pet_care_title", @"Pet Care")
                    showBack:YES];
    [self pp_setupViews];
    [self pp_loadFilters];
    [self pp_updateLocalizedText];
    [self pp_applyTheme];
    [self pp_loadData];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_appWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_updateLocalizedText];
    [self pp_applyTheme];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_applyTheme];
            [self.collectionView reloadData];
        }
    }
}

- (void)pp_appWillEnterForeground
{
    [self pp_applyTheme];
    [self.collectionView.visibleCells makeObjectsPerformSelector:@selector(setNeedsLayout)];
}

#pragma mark - Setup

- (void)pp_setupViews
{
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.backgroundColor = UIColor.clearColor;
    [self.view addSubview:contentView];

    _heroView = [[UIView alloc] init];
    _heroView.translatesAutoresizingMaskIntoConstraints = NO;
    _heroView.layer.cornerRadius = 32.0;
    _heroView.layer.borderWidth = 0.8;
    _heroView.clipsToBounds = NO;
    if (@available(iOS 13.0, *)) {
        _heroView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_heroView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    _heroView.layer.shadowRadius = 26.0;
    _heroView.layer.shadowOffset = CGSizeMake(0.0, 16.0);
    [contentView addSubview:_heroView];

    UIView *heroFill = [[UIView alloc] init];
    heroFill.translatesAutoresizingMaskIntoConstraints = NO;
    heroFill.layer.cornerRadius = 32.0;
    heroFill.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        heroFill.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_heroView addSubview:heroFill];

    _eyebrowLabel = [[UILabel alloc] init];
    _eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _eyebrowLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    _eyebrowLabel.numberOfLines = 1;
    [_heroView addSubview:_eyebrowLabel];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM boldFontWithSize:28.0] ?: [UIFont systemFontOfSize:28.0 weight:UIFontWeightBold];
    _titleLabel.numberOfLines = 1;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.78;
    [_heroView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [GM MidFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    _subtitleLabel.numberOfLines = 2;
    [_heroView addSubview:_subtitleLabel];

    _counterLabel = [[UILabel alloc] init];
    _counterLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _counterLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    _counterLabel.textAlignment = NSTextAlignmentCenter;
    _counterLabel.layer.cornerRadius = 18.0;
    _counterLabel.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        _counterLabel.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_heroView addSubview:_counterLabel];

    _sectionControl = [[UISegmentedControl alloc] initWithItems:@[@"", @""]];
    _sectionControl.translatesAutoresizingMaskIntoConstraints = NO;
    _sectionControl.selectedSegmentIndex = self.selectedSection == PPPetCareInitialSectionVeterinarians ? 1 : 0;
    [_sectionControl addTarget:self action:@selector(pp_sectionChanged:) forControlEvents:UIControlEventValueChanged];
    [contentView addSubview:_sectionControl];

    _searchField = [[UITextField alloc] init];
    _searchField.translatesAutoresizingMaskIntoConstraints = NO;
    _searchField.delegate = self;
    _searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _searchField.returnKeyType = UIReturnKeySearch;
    _searchField.layer.cornerRadius = 24.0;
    _searchField.layer.borderWidth = 0.8;
    _searchField.leftViewMode = UITextFieldViewModeAlways;
    _searchField.rightViewMode = UITextFieldViewModeAlways;
    _searchField.font = [GM MidFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    if (@available(iOS 13.0, *)) {
        _searchField.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [_searchField addTarget:self action:@selector(pp_searchTextChanged:) forControlEvents:UIControlEventEditingChanged];
    [contentView addSubview:_searchField];

    UIImageView *searchIcon = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"magnifyingglass"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    searchIcon.tintColor = PPPetCareSecondaryTextColor();
    searchIcon.contentMode = UIViewContentModeCenter;
    searchIcon.frame = CGRectMake(0.0, 0.0, 44.0, 44.0);
    _searchField.leftView = searchIcon;

    _kindScrollView = [self pp_makeHorizontalScrollView];
    _kindStackView = [self pp_makeHorizontalStackView];
    [_kindScrollView addSubview:_kindStackView];
    [contentView addSubview:_kindScrollView];

    _filterScrollView = [self pp_makeHorizontalScrollView];
    _filterStackView = [self pp_makeHorizontalStackView];
    [_filterScrollView addSubview:_filterStackView];
    [contentView addSubview:_filterScrollView];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumLineSpacing = 12.0;
    layout.minimumInteritemSpacing = 12.0;
    layout.sectionInset = UIEdgeInsetsMake(6.0, 18.0, 24.0, 18.0);

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.backgroundColor = UIColor.clearColor;
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [_collectionView registerClass:PPUniversalCell.class forCellWithReuseIdentifier:PPPetCareMedicineCellID];
    [_collectionView registerClass:PPPetCareVetCell.class forCellWithReuseIdentifier:PPPetCareVetCell.reuseIdentifier];
    [contentView addSubview:_collectionView];

    _emptyView = [[UIView alloc] init];
    _emptyView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyView.userInteractionEnabled = NO;
    _emptyView.hidden = YES;

    UIImageView *emptyIcon = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"heart.text.square.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    emptyIcon.translatesAutoresizingMaskIntoConstraints = NO;
    emptyIcon.tintColor = [PPPetCareAccentColor() colorWithAlphaComponent:0.72];
    [_emptyView addSubview:emptyIcon];

    _emptyTitleLabel = [[UILabel alloc] init];
    _emptyTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyTitleLabel.font = [GM boldFontWithSize:18.0] ?: [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
    _emptyTitleLabel.textColor = PPPetCareTextColor();
    _emptyTitleLabel.textAlignment = NSTextAlignmentCenter;
    _emptyTitleLabel.numberOfLines = 2;
    [_emptyView addSubview:_emptyTitleLabel];

    _emptySubtitleLabel = [[UILabel alloc] init];
    _emptySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptySubtitleLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    _emptySubtitleLabel.textColor = PPPetCareSecondaryTextColor();
    _emptySubtitleLabel.textAlignment = NSTextAlignmentCenter;
    _emptySubtitleLabel.numberOfLines = 3;
    [_emptyView addSubview:_emptySubtitleLabel];
    [contentView addSubview:_emptyView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [contentView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [heroFill.topAnchor constraintEqualToAnchor:_heroView.topAnchor],
        [heroFill.leadingAnchor constraintEqualToAnchor:_heroView.leadingAnchor],
        [heroFill.trailingAnchor constraintEqualToAnchor:_heroView.trailingAnchor],
        [heroFill.bottomAnchor constraintEqualToAnchor:_heroView.bottomAnchor],

        [_heroView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:12.0],
        [_heroView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:18.0],
        [_heroView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-18.0],
        [_heroView.heightAnchor constraintEqualToConstant:146.0],

        [_eyebrowLabel.leadingAnchor constraintEqualToAnchor:_heroView.leadingAnchor constant:20.0],
        [_eyebrowLabel.topAnchor constraintEqualToAnchor:_heroView.topAnchor constant:18.0],
        [_eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_counterLabel.leadingAnchor constant:-12.0],

        [_counterLabel.trailingAnchor constraintEqualToAnchor:_heroView.trailingAnchor constant:-18.0],
        [_counterLabel.centerYAnchor constraintEqualToAnchor:_eyebrowLabel.centerYAnchor],
        [_counterLabel.widthAnchor constraintGreaterThanOrEqualToConstant:72.0],
        [_counterLabel.heightAnchor constraintEqualToConstant:36.0],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_eyebrowLabel.leadingAnchor],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_heroView.trailingAnchor constant:-20.0],
        [_titleLabel.topAnchor constraintEqualToAnchor:_eyebrowLabel.bottomAnchor constant:10.0],

        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_heroView.trailingAnchor constant:-20.0],
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8.0],

        [_sectionControl.topAnchor constraintEqualToAnchor:_heroView.bottomAnchor constant:14.0],
        [_sectionControl.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:18.0],
        [_sectionControl.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-18.0],
        [_sectionControl.heightAnchor constraintEqualToConstant:42.0],

        [_searchField.topAnchor constraintEqualToAnchor:_sectionControl.bottomAnchor constant:12.0],
        [_searchField.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:18.0],
        [_searchField.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-18.0],
        [_searchField.heightAnchor constraintEqualToConstant:48.0],

        [_kindScrollView.topAnchor constraintEqualToAnchor:_searchField.bottomAnchor constant:12.0],
        [_kindScrollView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [_kindScrollView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [_kindScrollView.heightAnchor constraintEqualToConstant:38.0],

        [_kindStackView.topAnchor constraintEqualToAnchor:_kindScrollView.contentLayoutGuide.topAnchor],
        [_kindStackView.leadingAnchor constraintEqualToAnchor:_kindScrollView.contentLayoutGuide.leadingAnchor constant:18.0],
        [_kindStackView.trailingAnchor constraintEqualToAnchor:_kindScrollView.contentLayoutGuide.trailingAnchor constant:-18.0],
        [_kindStackView.bottomAnchor constraintEqualToAnchor:_kindScrollView.contentLayoutGuide.bottomAnchor],
        [_kindStackView.heightAnchor constraintEqualToAnchor:_kindScrollView.frameLayoutGuide.heightAnchor],

        [_filterScrollView.topAnchor constraintEqualToAnchor:_kindScrollView.bottomAnchor constant:8.0],
        [_filterScrollView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [_filterScrollView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [_filterScrollView.heightAnchor constraintEqualToConstant:38.0],

        [_filterStackView.topAnchor constraintEqualToAnchor:_filterScrollView.contentLayoutGuide.topAnchor],
        [_filterStackView.leadingAnchor constraintEqualToAnchor:_filterScrollView.contentLayoutGuide.leadingAnchor constant:18.0],
        [_filterStackView.trailingAnchor constraintEqualToAnchor:_filterScrollView.contentLayoutGuide.trailingAnchor constant:-18.0],
        [_filterStackView.bottomAnchor constraintEqualToAnchor:_filterScrollView.contentLayoutGuide.bottomAnchor],
        [_filterStackView.heightAnchor constraintEqualToAnchor:_filterScrollView.frameLayoutGuide.heightAnchor],

        [_collectionView.topAnchor constraintEqualToAnchor:_filterScrollView.bottomAnchor constant:8.0],
        [_collectionView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [_collectionView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [_collectionView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],

        [_emptyView.centerXAnchor constraintEqualToAnchor:_collectionView.centerXAnchor],
        [_emptyView.centerYAnchor constraintEqualToAnchor:_collectionView.centerYAnchor constant:-20.0],
        [_emptyView.leadingAnchor constraintGreaterThanOrEqualToAnchor:_collectionView.leadingAnchor constant:36.0],
        [_emptyView.trailingAnchor constraintLessThanOrEqualToAnchor:_collectionView.trailingAnchor constant:-36.0],

        [emptyIcon.topAnchor constraintEqualToAnchor:_emptyView.topAnchor],
        [emptyIcon.centerXAnchor constraintEqualToAnchor:_emptyView.centerXAnchor],
        [emptyIcon.widthAnchor constraintEqualToConstant:38.0],
        [emptyIcon.heightAnchor constraintEqualToConstant:38.0],

        [_emptyTitleLabel.topAnchor constraintEqualToAnchor:emptyIcon.bottomAnchor constant:12.0],
        [_emptyTitleLabel.leadingAnchor constraintEqualToAnchor:_emptyView.leadingAnchor],
        [_emptyTitleLabel.trailingAnchor constraintEqualToAnchor:_emptyView.trailingAnchor],

        [_emptySubtitleLabel.topAnchor constraintEqualToAnchor:_emptyTitleLabel.bottomAnchor constant:7.0],
        [_emptySubtitleLabel.leadingAnchor constraintEqualToAnchor:_emptyView.leadingAnchor],
        [_emptySubtitleLabel.trailingAnchor constraintEqualToAnchor:_emptyView.trailingAnchor],
        [_emptySubtitleLabel.bottomAnchor constraintEqualToAnchor:_emptyView.bottomAnchor],
    ]];

    heroFill.backgroundColor = PPPetCareSurfaceColor();
}

- (UIScrollView *)pp_makeHorizontalScrollView
{
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.alwaysBounceHorizontal = YES;
    scrollView.backgroundColor = UIColor.clearColor;
    return scrollView;
}

- (UIStackView *)pp_makeHorizontalStackView
{
    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.axis = UILayoutConstraintAxisHorizontal;
    stackView.alignment = UIStackViewAlignmentCenter;
    stackView.spacing = 8.0;
    return stackView;
}

#pragma mark - Data

- (void)pp_loadFilters
{
    NSArray *kinds = [MKM.MainKindsArray isKindOfClass:NSArray.class] ? MKM.MainKindsArray : @[];
    self.mainKinds = kinds;
    [self pp_reloadKindChips];
    [self pp_reloadModeChips];
}

- (void)pp_loadData
{
    self.loadingMedicines = YES;
    self.loadingVets = YES;
    [self pp_updateEmptyState];

    __weak typeof(self) weakSelf = self;
    [[PetAccessoryManager sharedManager] fetchAccessoriesOfKind:AccessTypePetMedicine
                                                   MainCategory:0
                                                      subKindID:0
                                                     completion:^(NSArray<PetAccessory *> *accessories) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.loadingMedicines = NO;
        self.allMedicines = accessories ?: @[];
        [self pp_applyFiltersAndReload];
    }];

    [[VetManager sharedManager] fetchAllVetsWithCompletion:^(NSArray<VetModel *> *vetsArray, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.loadingVets = NO;
        NSArray *vets = vetsArray ?: @[];
        self.allVets = [vets sortedArrayUsingComparator:^NSComparisonResult(VetModel *a, VetModel *b) {
            return [PPPetCareSafeString(a.title) localizedCaseInsensitiveCompare:PPPetCareSafeString(b.title)];
        }];
        [self pp_applyFiltersAndReload];
    }];
}

- (void)pp_applyFiltersAndReload
{
    NSString *query = PPPetCareNormalizedText(self.searchField.text);
    NSInteger kindID = self.selectedMainKind ? self.selectedMainKind.ID : 0;

    NSMutableArray<PetAccessory *> *medicines = [NSMutableArray array];
    for (PetAccessory *item in self.allMedicines) {
        if (kindID > 0 && item.petMainCategoryID != kindID) {
            continue;
        }
        if (![self pp_medicine:item matchesFilter:self.medicineFilter]) {
            continue;
        }
        if (query.length > 0) {
            NSString *haystack = PPPetCareNormalizedText([@[PPPetCareSafeString(item.name),
                                                           PPPetCareSafeString(item.desc)]
                                                         componentsJoinedByString:@" "]);
            if (![haystack containsString:query]) {
                continue;
            }
        }
        [medicines addObject:item];
    }
    self.filteredMedicines = medicines.copy;

    NSMutableArray<VetModel *> *vets = [NSMutableArray array];
    for (VetModel *vet in self.allVets) {
        if (kindID > 0 && vet.petMainKindID != kindID) {
            continue;
        }
        if (![self pp_vet:vet matchesFilter:self.vetFilter]) {
            continue;
        }
        if (query.length > 0) {
            NSString *haystack = PPPetCareNormalizedText([@[PPPetCareSafeString(vet.title),
                                                           PPPetCareSafeString(vet.descriptionText),
                                                           PPPetCareSafeString(vet.phone),
                                                           PPPetCareSafeString(vet.whatsapp)]
                                                         componentsJoinedByString:@" "]);
            if (![haystack containsString:query]) {
                continue;
            }
        }
        [vets addObject:vet];
    }
    self.filteredVets = vets.copy;

    [self.collectionView reloadData];
    [self pp_updateCounter];
    [self pp_updateEmptyState];
}

- (BOOL)pp_medicine:(PetAccessory *)medicine matchesFilter:(PPPetCareMedicineFilter)filter
{
    switch (filter) {
        case PPPetCareMedicineFilterOffers:
            return medicine.hasOffer ||
                   medicine.discountPercent.doubleValue > 0.0 ||
                   medicine.discountAmount.doubleValue > 0.0;
        case PPPetCareMedicineFilterInStock:
            return medicine.quantity > 0;
        case PPPetCareMedicineFilterNew:
            return medicine.isNew;
        case PPPetCareMedicineFilterAll:
        default:
            return YES;
    }
}

- (BOOL)pp_vet:(VetModel *)vet matchesFilter:(PPPetCareVetFilter)filter
{
    switch (filter) {
        case PPPetCareVetFilterWithPhone:
            return vet.phone.length > 0 || vet.whatsapp.length > 0;
        case PPPetCareVetFilterCompany:
            return vet.type == VetTypeCompany;
        case PPPetCareVetFilterPersonal:
            return vet.type == VetTypePersonal;
        case PPPetCareVetFilterAll:
        default:
            return YES;
    }
}

#pragma mark - Localization and Theme

- (void)pp_updateLocalizedText
{
    [self.sectionControl setTitle:PPPetCareLocalized(@"pet_care_medicines", @"Medicines") forSegmentAtIndex:0];
    [self.sectionControl setTitle:PPPetCareLocalized(@"pet_care_veterinarians", @"Veterinarians") forSegmentAtIndex:1];
    self.searchField.placeholder = self.selectedSection == PPPetCareInitialSectionMedicines
        ? PPPetCareLocalized(@"pet_care_search_medicines", @"Search medicines")
        : PPPetCareLocalized(@"pet_care_search_vets", @"Search veterinarians");
    self.eyebrowLabel.text = PPPetCareLocalized(@"pet_care_eyebrow", @"Premium care");
    self.titleLabel.text = self.selectedSection == PPPetCareInitialSectionMedicines
        ? PPPetCareLocalized(@"pet_care_medicine_title", @"Pet medicines")
        : PPPetCareLocalized(@"pet_care_vets_title", @"Veterinarians");
    self.subtitleLabel.text = self.selectedSection == PPPetCareInitialSectionMedicines
        ? PPPetCareLocalized(@"pet_care_medicine_subtitle", @"Curated treatment, wellness, and care supplies from the shared store catalog.")
        : PPPetCareLocalized(@"pet_care_vets_subtitle", @"Find veterinarians matched to pet kind, contact readiness, and clinic type.");
    self.sectionControl.selectedSegmentIndex = self.selectedSection == PPPetCareInitialSectionVeterinarians ? 1 : 0;
    self.view.semanticContentAttribute = Language.isRTL ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    self.searchField.textAlignment = [Language alignmentForCurrentLanguage];
    self.eyebrowLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.titleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    self.subtitleLabel.textAlignment = [Language alignmentForCurrentLanguage];
    [self pp_reloadKindChips];
    [self pp_reloadModeChips];
    [self pp_updateCounter];
    [self pp_updateEmptyState];
}

- (void)pp_applyTheme
{
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    self.view.backgroundColor = AppBackgroundClr ?: UIColor.systemBackgroundColor;
    self.heroView.backgroundColor = PPPetCareSurfaceColor();
    [self.heroView pp_setBorderColor:PPPetCareBorderColor()];
    self.heroView.layer.shadowOpacity = dark ? 0.0 : 0.09;
    self.eyebrowLabel.textColor = [PPPetCareAccentColor() colorWithAlphaComponent:dark ? 0.92 : 0.82];
    self.titleLabel.textColor = PPPetCareTextColor();
    self.subtitleLabel.textColor = PPPetCareSecondaryTextColor();
    self.counterLabel.textColor = PPPetCareTextColor();
    self.counterLabel.backgroundColor = [PPPetCareAccentColor() colorWithAlphaComponent:dark ? 0.15 : 0.09];
    self.searchField.textColor = PPPetCareTextColor();
    self.searchField.backgroundColor = PPPetCareSurfaceColor();
    [self.searchField pp_setBorderColor:PPPetCareBorderColor()];
    [self pp_styleAllChips];
}

- (void)pp_updateCounter
{
    NSInteger count = self.selectedSection == PPPetCareInitialSectionMedicines
        ? self.filteredMedicines.count
        : self.filteredVets.count;
    NSString *format = self.selectedSection == PPPetCareInitialSectionMedicines
        ? PPPetCareLocalized(@"pet_care_medicine_count_format", @"%ld medicines")
        : PPPetCareLocalized(@"pet_care_vet_count_format", @"%ld vets");
    self.counterLabel.text = [NSString stringWithFormat:format, (long)count];
}

- (void)pp_updateEmptyState
{
    BOOL isLoading = self.selectedSection == PPPetCareInitialSectionMedicines ? self.loadingMedicines : self.loadingVets;
    NSInteger count = self.selectedSection == PPPetCareInitialSectionMedicines ? self.filteredMedicines.count : self.filteredVets.count;
    self.emptyView.hidden = isLoading || count > 0;
    if (isLoading) {
        return;
    }
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        self.emptyTitleLabel.text = PPPetCareLocalized(@"pet_care_empty_medicines_title", @"No medicines found");
        self.emptySubtitleLabel.text = PPPetCareLocalized(@"pet_care_empty_medicines_subtitle", @"Try another pet kind, remove filters, or search with a shorter word.");
    } else {
        self.emptyTitleLabel.text = PPPetCareLocalized(@"pet_care_empty_vets_title", @"No veterinarians found");
        self.emptySubtitleLabel.text = PPPetCareLocalized(@"pet_care_empty_vets_subtitle", @"Try all pet kinds, contact-ready filters, or a different search term.");
    }
}

#pragma mark - Chips

- (void)pp_reloadKindChips
{
    [self.kindStackView.arrangedSubviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    UIButton *all = [self pp_makeChipWithTitle:PPPetCareLocalized(@"pet_care_all_pets", @"All pets") tag:0 action:@selector(pp_kindChipTapped:)];
    [self.kindStackView addArrangedSubview:all];

    NSInteger index = 1;
    for (MainKindsModel *kind in self.mainKinds) {
        NSString *title = kind.KindName.length > 0 ? kind.KindName : kind.KindNameEn ?: kind.KindNameAr ?: @"";
        UIButton *chip = [self pp_makeChipWithTitle:title tag:index action:@selector(pp_kindChipTapped:)];
        [self.kindStackView addArrangedSubview:chip];
        index += 1;
    }
    [self pp_styleAllChips];
}

- (void)pp_reloadModeChips
{
    [self.filterStackView.arrangedSubviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    NSArray<NSDictionary *> *items = self.selectedSection == PPPetCareInitialSectionMedicines
        ? @[
            @{@"title": PPPetCareLocalized(@"pet_care_filter_all", @"All"), @"tag": @(PPPetCareMedicineFilterAll)},
            @{@"title": PPPetCareLocalized(@"pet_care_filter_offers", @"Offers"), @"tag": @(PPPetCareMedicineFilterOffers)},
            @{@"title": PPPetCareLocalized(@"pet_care_filter_in_stock", @"In stock"), @"tag": @(PPPetCareMedicineFilterInStock)},
            @{@"title": PPPetCareLocalized(@"pet_care_filter_new", @"New"), @"tag": @(PPPetCareMedicineFilterNew)}
        ]
        : @[
            @{@"title": PPPetCareLocalized(@"pet_care_filter_all", @"All"), @"tag": @(PPPetCareVetFilterAll)},
            @{@"title": PPPetCareLocalized(@"pet_care_filter_with_phone", @"Contact ready"), @"tag": @(PPPetCareVetFilterWithPhone)},
            @{@"title": PPPetCareLocalized(@"pet_care_filter_clinics", @"Clinics"), @"tag": @(PPPetCareVetFilterCompany)},
            @{@"title": PPPetCareLocalized(@"pet_care_filter_doctors", @"Doctors"), @"tag": @(PPPetCareVetFilterPersonal)}
        ];

    for (NSDictionary *item in items) {
        UIButton *chip = [self pp_makeChipWithTitle:item[@"title"]
                                                tag:[item[@"tag"] integerValue]
                                             action:@selector(pp_filterChipTapped:)];
        [self.filterStackView addArrangedSubview:chip];
    }
    [self pp_styleAllChips];
}

- (UIButton *)pp_makeChipWithTitle:(NSString *)title tag:(NSInteger)tag action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = tag;
    button.titleLabel.font = [GM boldFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    button.contentEdgeInsets = UIEdgeInsetsMake(7.0, 14.0, 7.0, 14.0);
    button.layer.cornerRadius = 18.0;
    button.layer.borderWidth = 0.8;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:36.0].active = YES;
    [button.widthAnchor constraintGreaterThanOrEqualToConstant:58.0].active = YES;
    return button;
}

- (void)pp_styleAllChips
{
    for (UIButton *button in self.kindStackView.arrangedSubviews) {
        if (![button isKindOfClass:UIButton.class]) continue;
        BOOL selected = NO;
        if (button.tag == 0) {
            selected = self.selectedMainKind == nil;
        } else {
            NSInteger index = button.tag - 1;
            if (index >= 0 && index < (NSInteger)self.mainKinds.count && self.selectedMainKind) {
                selected = self.selectedMainKind.ID == self.mainKinds[index].ID;
            }
        }
        [self pp_styleChip:button selected:selected];
    }

    for (UIButton *button in self.filterStackView.arrangedSubviews) {
        if (![button isKindOfClass:UIButton.class]) continue;
        BOOL selected = self.selectedSection == PPPetCareInitialSectionMedicines
            ? button.tag == self.medicineFilter
            : button.tag == self.vetFilter;
        [self pp_styleChip:button selected:selected];
    }
}

- (void)pp_styleChip:(UIButton *)button selected:(BOOL)selected
{
    UIColor *accent = PPPetCareAccentColor();
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    button.backgroundColor = selected
        ? [accent colorWithAlphaComponent:dark ? 0.28 : 0.17]
        : PPPetCareSurfaceColor();
    [button setTitleColor:selected ? accent : PPPetCareTextColor() forState:UIControlStateNormal];
    [button pp_setBorderColor:selected ? [accent colorWithAlphaComponent:0.42] : PPPetCareBorderColor()];
}

#pragma mark - Actions

- (void)pp_sectionChanged:(UISegmentedControl *)sender
{
    self.selectedSection = sender.selectedSegmentIndex == 1
        ? PPPetCareInitialSectionVeterinarians
        : PPPetCareInitialSectionMedicines;
    [self pp_updateLocalizedText];
    [self pp_applyFiltersAndReload];
}

- (void)pp_kindChipTapped:(UIButton *)sender
{
    if (sender.tag == 0) {
        self.selectedMainKind = nil;
    } else {
        NSInteger index = sender.tag - 1;
        self.selectedMainKind = (index >= 0 && index < self.mainKinds.count) ? self.mainKinds[index] : nil;
    }
    [self pp_applyFiltersAndReload];
    [self pp_styleAllChips];
}

- (void)pp_filterChipTapped:(UIButton *)sender
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        self.medicineFilter = (PPPetCareMedicineFilter)sender.tag;
    } else {
        self.vetFilter = (PPPetCareVetFilter)sender.tag;
    }
    [self pp_applyFiltersAndReload];
    [self pp_styleAllChips];
}

- (void)pp_searchTextChanged:(UITextField *)textField
{
    [self pp_applyFiltersAndReload];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Collection

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        return self.filteredMedicines.count;
    }
    return self.filteredVets.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                          cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        PPUniversalCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPPetCareMedicineCellID
                                                                          forIndexPath:indexPath];
        cell.delegate = self;
        if (indexPath.item < self.filteredMedicines.count) {
            PetAccessory *medicine = self.filteredMedicines[indexPath.item];
            PPUniversalCellViewModel *vm =
                [[PPUniversalCellViewModel alloc] initWithModel:medicine context:PPCellForMarket];
            vm.indexPath = indexPath;
            vm.ModelObject = medicine;
            [cell applyViewModel:vm
                         context:PPCellForMarket
                      layoutMode:PPCellLayoutModeSquare
                    discountMode:PPDiscountStyleBadge
                     imageLoader:^(UIImageView *imageView, NSString *url, UIImage *placeholder, UIView *card) {
                UIImage *fallback = placeholder ?: [UIImage imageNamed:@"placeholder"];
                [[PPImageLoaderManager shared] setImageOnImageView:imageView
                                                               url:url
                                                       placeholder:fallback
                                                  transitionStyle:PPImageTransitionStyleNone
                                                        complation:nil];
            }];
            [cell refreshThemeAppearance];
        }
        return cell;
    }

    PPPetCareVetCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PPPetCareVetCell.reuseIdentifier
                                                                       forIndexPath:indexPath];
    if (indexPath.item < self.filteredVets.count) {
        VetModel *vet = self.filteredVets[indexPath.item];
        [cell configureWithVet:vet mainKindName:[self pp_mainKindNameForID:vet.petMainKindID]];
        __weak typeof(self) weakSelf = self;
        cell.onDetailsTap = ^{
            __strong typeof(weakSelf) self = weakSelf;
            [self pp_openObject:vet];
        };
        cell.onCallTap = ^{
            __strong typeof(weakSelf) self = weakSelf;
            [self pp_callVet:vet];
        };
    }
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat width = CGRectGetWidth(collectionView.bounds);
    UIEdgeInsets inset = ((UICollectionViewFlowLayout *)collectionViewLayout).sectionInset;
    CGFloat available = width - inset.left - inset.right;
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        BOOL twoColumns = available >= 330.0;
        CGFloat itemWidth = twoColumns ? floor((available - 12.0) / 2.0) : available;
        return CGSizeMake(itemWidth, MAX(246.0, itemWidth * 1.54));
    }
    return CGSizeMake(available, 184.0);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.selectedSection == PPPetCareInitialSectionMedicines) {
        if (indexPath.item < self.filteredMedicines.count) {
            [self pp_openObject:self.filteredMedicines[indexPath.item]];
        }
    } else {
        if (indexPath.item < self.filteredVets.count) {
            [self pp_openObject:self.filteredVets[indexPath.item]];
        }
    }
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [UIView animateWithDuration:0.12 animations:^{
        cell.transform = CGAffineTransformMakeScale(0.985, 0.985);
        cell.alpha = 0.92;
    }];
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [UIView animateWithDuration:0.20
                          delay:0.0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        cell.transform = CGAffineTransformIdentity;
        cell.alpha = 1.0;
    } completion:nil];
}

#pragma mark - Universal Cell

- (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel
{
    [self pp_openObject:universalModel.ModelObject];
}

#pragma mark - Routing

- (void)pp_openObject:(id)object
{
    if (!object) {
        return;
    }
    [PPOverlayCoordinator pp_openDetailForObject:object
                                         fromVC:self
                                     routingNav:(PPNavigationController *)self.navigationController];
}

- (void)pp_callVet:(VetModel *)vet
{
    NSString *rawPhone = vet.phone.length > 0 ? vet.phone : vet.whatsapp;
    if (rawPhone.length == 0) {
        return;
    }

    NSMutableString *clean = [NSMutableString string];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"+0123456789"];
    for (NSUInteger idx = 0; idx < rawPhone.length; idx++) {
        unichar ch = [rawPhone characterAtIndex:idx];
        if ([allowed characterIsMember:ch]) {
            [clean appendFormat:@"%C", ch];
        }
    }
    if (clean.length == 0) {
        return;
    }

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"telprompt:%@", clean]];
    if (!url) {
        return;
    }
    UIApplication *application = UIApplication.sharedApplication;
    if ([application canOpenURL:url]) {
        [application openURL:url options:@{} completionHandler:nil];
    }
}

- (NSString *)pp_mainKindNameForID:(NSInteger)kindID
{
    if (kindID <= 0) {
        return PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
    }
    for (MainKindsModel *kind in self.mainKinds) {
        if (kind.ID == kindID) {
            return kind.KindName.length > 0 ? kind.KindName : kind.KindNameEn ?: kind.KindNameAr ?: @"";
        }
    }
    return PPPetCareLocalized(@"pet_care_all_pets", @"All pets");
}

@end
