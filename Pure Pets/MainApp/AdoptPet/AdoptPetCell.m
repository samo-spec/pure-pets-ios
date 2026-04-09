//
//  AdoptPetCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/08/2025.
//

#import "AdoptPetCell.h"
#import "PPInsetLabel.h"

static NSString *PPAdoptCellSafeString(id value)
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@interface AdoptPetCell ()
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIStackView *tagsStack;
@property (nonatomic, strong) UIStackView *actionsStack;
@property (nonatomic, strong) UIView *tagsActionsSpacer;
@property (nonatomic, strong) PPInsetLabel *ageTagLabel;
@property (nonatomic, strong) PPInsetLabel *genderTagLabel;
@property (nonatomic, strong) NSLayoutConstraint *imageHeightConstraint;
@property (nonatomic, strong) UIStackView *overlayTextStack;
@property (nonatomic, strong) UIView *imageOverlayView;
@property (nonatomic, strong) UIVisualEffectView *overlayPillView;
@property (nonatomic, strong) CAGradientLayer *imageGradient;
@property (nonatomic, strong) UIStackView *chipsStack;
@end

@implementation AdoptPetCell

#pragma mark - Button Actions

- (void)shareTapped {
    NSLog(@"BUTTON ----->>>> shareTapped");
    if ([self.delegate respondsToSelector:@selector(adoptCellDidTapShare:)]) {
        [self.delegate adoptCellDidTapShare:self];
    }
}

- (void)favoriteTapped {
    NSLog(@"BUTTON ----->>>> favoriteTapped");
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
}

- (void)deleteTapped {
    NSLog(@"BUTTON ----->>>> deleteTapped");
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    if ([self.delegate respondsToSelector:@selector(adoptCellDidTapDelete:onModel:)]) {
        [self.delegate adoptCellDidTapDelete:self onModel:self.adoptModel];
    }
}

- (void)editTapped {
    NSLog(@"BUTTON ----->>>> editTapped");
    if ([self.delegate respondsToSelector:@selector(adoptCellDidTapEdit:onModel:)]) {
        [self.delegate adoptCellDidTapEdit:self onModel:self.adoptModel];
    }
}

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = UIColor.clearColor;
        [self pp_setupViews];
        [self setupShadow];
    }
    return self;
}

-(void)prepareForReuse {
    [super prepareForReuse];
    self.imageView.image = nil;
    self.titleLabel.text = @"";
    self.subtitleLabel.text = @"";
    self.titleLabel.numberOfLines = 1;
    self.subtitleLabel.numberOfLines = 1;
    self.ageTagLabel.text = @"";
    self.genderTagLabel.text = @"";
    self.ageTagLabel.hidden = YES;
    self.genderTagLabel.hidden = YES;
    self.chipsStack.hidden = YES;
    self.titleLabel.textColor = UIColor.labelColor;
    self.subtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.adoptModel = nil;
}

#pragma mark - Setup Views

- (void)pp_setupViews {
    self.contentView.backgroundColor = AppForgroundColr;
    self.contentView.layer.cornerRadius = 18.0;
    self.contentView.layer.masksToBounds = YES;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    if (@available(iOS 13.0, *)) {
        self.contentView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.topView = [[UIView alloc] init];
    self.topView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topView.backgroundColor = UIColor.clearColor;
    self.topView.clipsToBounds = YES;
    self.topView.layer.cornerRadius = 18.0;
    if (@available(iOS 13.0, *)) {
        self.topView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:self.topView];

    self.imageView = [[UIImageView alloc] init];
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.imageView.clipsToBounds = YES;
    [self.topView addSubview:self.imageView];

    self.imageOverlayView = [[UIView alloc] init];
    self.imageOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageOverlayView.backgroundColor = UIColor.clearColor;
    self.imageOverlayView.userInteractionEnabled = NO;
    [self.topView addSubview:self.imageOverlayView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [GM boldFontWithSize:17];
    self.titleLabel.textAlignment = NSTextAlignmentNatural;
    self.titleLabel.textColor = UIColor.labelColor;
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.adjustsFontSizeToFitWidth = NO;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.font = [GM MidFontWithSize:14];
    self.subtitleLabel.textAlignment = NSTextAlignmentNatural;
    self.subtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.subtitleLabel.numberOfLines = 1;
    self.subtitleLabel.adjustsFontSizeToFitWidth = NO;
    self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    self.overlayTextStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.titleLabel, self.subtitleLabel]];
    self.overlayTextStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.overlayTextStack.axis = UILayoutConstraintAxisVertical;
    self.overlayTextStack.spacing = 3.0;
    self.overlayTextStack.alignment = UIStackViewAlignmentFill;

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    self.overlayPillView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.overlayPillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.overlayPillView.layer.cornerRadius = 18.0;
    self.overlayPillView.layer.masksToBounds = YES;
    self.overlayPillView.userInteractionEnabled = NO;
    self.overlayPillView.alpha = 0.96;
    self.overlayPillView.layer.borderWidth = 0.0;
    self.overlayPillView.layer.borderColor = UIColor.clearColor.CGColor;

    [self.imageOverlayView addSubview:self.overlayPillView];

    self.ageTagLabel = [self pp_makeTagLabel];
    self.genderTagLabel = [self pp_makeTagLabel];

    self.chipsStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.ageTagLabel, self.genderTagLabel]];
    self.chipsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.chipsStack.axis = UILayoutConstraintAxisHorizontal;
    self.chipsStack.spacing = 6.0;
    self.chipsStack.alignment = UIStackViewAlignmentLeading;
    self.chipsStack.distribution = UIStackViewDistributionFillProportionally;

    self.contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.chipsStack, self.overlayTextStack]];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 8.0;
    self.contentStack.alignment = UIStackViewAlignmentLeading;
    self.contentStack.distribution = UIStackViewDistributionFill;
    [self.overlayPillView.contentView addSubview:self.contentStack];

    self.imageGradient = [CAGradientLayer layer];
    self.imageGradient.colors = @[
      (id)[UIColor colorWithWhite:0 alpha:0.0].CGColor,
      (id)[UIColor colorWithWhite:0 alpha:0.12].CGColor,
      (id)[UIColor colorWithWhite:0 alpha:0.34].CGColor
    ];
    self.imageGradient.locations = @[@0.0, @0.60, @1.0];
    [self.imageOverlayView.layer insertSublayer:self.imageGradient atIndex:0];

    self.shareButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self pp_configureActionButton:self.shareButton systemName:@"square.and.arrow.up"];
    [self.shareButton addTarget:self action:@selector(shareTapped) forControlEvents:UIControlEventTouchUpInside];

    self.favButton = [[FavoriteButton alloc] init];
    [self pp_configureActionButton:self.favButton systemName:nil];

    self.deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self pp_configureActionButton:self.deleteButton systemName:@"trash.fill"];
    [self.deleteButton addTarget:self action:@selector(deleteTapped) forControlEvents:UIControlEventTouchUpInside];

    self.editButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self pp_configureActionButton:self.editButton systemName:@"pencil"];
    [self.editButton addTarget:self action:@selector(editTapped) forControlEvents:UIControlEventTouchUpInside];

    self.actionsStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.favButton, self.shareButton, self.editButton, self.deleteButton]];
    self.actionsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionsStack.axis = UILayoutConstraintAxisVertical;
    self.actionsStack.spacing = 8.0;
    self.actionsStack.alignment = UIStackViewAlignmentCenter;
    [self.topView addSubview:self.actionsStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.topView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.topView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.topView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.topView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

        [self.imageView.topAnchor constraintEqualToAnchor:self.topView.topAnchor],
        [self.imageView.leadingAnchor constraintEqualToAnchor:self.topView.leadingAnchor],
        [self.imageView.trailingAnchor constraintEqualToAnchor:self.topView.trailingAnchor],
        [self.imageView.bottomAnchor constraintEqualToAnchor:self.topView.bottomAnchor],

        [self.imageOverlayView.topAnchor constraintEqualToAnchor:self.imageView.topAnchor],
        [self.imageOverlayView.leadingAnchor constraintEqualToAnchor:self.imageView.leadingAnchor],
        [self.imageOverlayView.trailingAnchor constraintEqualToAnchor:self.imageView.trailingAnchor],
        [self.imageOverlayView.bottomAnchor constraintEqualToAnchor:self.imageView.bottomAnchor],

        [self.overlayPillView.leadingAnchor constraintEqualToAnchor:self.imageOverlayView.leadingAnchor],
        [self.overlayPillView.trailingAnchor constraintEqualToAnchor:self.imageOverlayView.trailingAnchor],
        [self.overlayPillView.bottomAnchor constraintEqualToAnchor:self.imageOverlayView.bottomAnchor],
        [self.overlayPillView.heightAnchor constraintGreaterThanOrEqualToConstant:82],

        [self.contentStack.topAnchor constraintEqualToAnchor:self.overlayPillView.contentView.topAnchor constant:10],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.overlayPillView.contentView.leadingAnchor constant:10],
        [self.contentStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.overlayPillView.contentView.trailingAnchor constant:-12],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.overlayPillView.contentView.bottomAnchor constant:-10],

        [self.actionsStack.leadingAnchor constraintEqualToAnchor:self.topView.leadingAnchor constant:8],
        [self.actionsStack.topAnchor constraintEqualToAnchor:self.topView.topAnchor constant:8]
    ]];

    self.deleteButton.hidden = YES;
    self.deleteButton.alpha = 0.0;
    self.editButton.hidden = YES;
    self.editButton.alpha = 0.0;
    [self.favButton colosTintForAds];
}

- (PPInsetLabel *)pp_makeTagLabel {
    PPInsetLabel *label = [[PPInsetLabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.textInsets = UIEdgeInsetsMake(2, 7, 2, 7);
    label.font = [GM MidFontWithSize:10];
    label.textColor = UIColor.labelColor;
    label.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat alpha = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.18 : 0.10;
        return [GM.appPrimaryColor colorWithAlphaComponent:alpha];
    }];
    label.layer.cornerRadius = 10.0;
    label.layer.masksToBounds = YES;
    label.hidden = YES;
    return label;
}

-(void)pp_configureActionButton:(UIButton *)button systemName:(NSString *)systemName {
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:28],
        [button.heightAnchor constraintEqualToConstant:28]
    ]];

    BOOL isFavoriteButton = [button isKindOfClass:FavoriteButton.class];

    if (!isFavoriteButton && systemName.length > 0) {
        if (@available(iOS 15.0, *)) {
            UIButtonConfiguration *cfg = [UIButtonConfiguration filledButtonConfiguration];
            cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
            cfg.baseBackgroundColor = [AppForgroundColr colorWithAlphaComponent:0.74];
            cfg.baseForegroundColor = UIColor.labelColor;
            cfg.background.visualEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
            cfg.image = [UIImage systemImageNamed:systemName];
            cfg.contentInsets = NSDirectionalEdgeInsetsMake(5, 5, 5, 5);
            cfg.preferredSymbolConfigurationForImage =
            [UIImageSymbolConfiguration configurationWithPointSize:14
                                                            weight:UIImageSymbolWeightRegular
                                                             scale:UIImageSymbolScaleMedium];
            button.configuration = cfg;
        } else {
            UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightRegular scale:UIImageSymbolScaleMedium];
            UIImage *image = [UIImage systemImageNamed:systemName withConfiguration:config];
            [button setImage:image forState:UIControlStateNormal];
        }
    }

    button.tintColor = UIColor.labelColor;
    if (!isFavoriteButton && systemName.length == 0) {
        if (@available(iOS 15.0, *)) {
            UIButtonConfiguration *cfg = [UIButtonConfiguration filledButtonConfiguration];
            cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
            cfg.baseBackgroundColor = [AppForgroundColr colorWithAlphaComponent:0.74];
            cfg.baseForegroundColor = GM.appPrimaryColor;
            cfg.background.visualEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
            cfg.contentInsets = NSDirectionalEdgeInsetsMake(5, 5, 5, 5);
            button.configuration = cfg;
        } else {
            button.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.74];
        }
    }

    button.layer.cornerRadius = 14.0;
    button.layer.masksToBounds = NO;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = 0.15;
    button.layer.shadowRadius = 6.0;
    button.layer.shadowOffset = CGSizeMake(0, 3);
    button.adjustsImageWhenHighlighted = NO;

    if (isFavoriteButton) {
        FavoriteButton *favButton = (FavoriteButton *)button;
        [favButton refreshAppearance];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.imageGradient.frame = self.imageOverlayView.bounds;
    if (@available(iOS 11.0, *)) {
        self.overlayPillView.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    }
    [self pp_updateAppearanceForTraitCollection:self.traitCollection];
}

- (void)setupShadow {
    BOOL isDark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    self.layer.cornerRadius = 18.0;
    self.layer.shadowColor = GM.AppShadowColor.CGColor;
    self.layer.shadowOffset = CGSizeMake(0, isDark ? 2 : 4);
    self.layer.shadowRadius = isDark ? 6 : 10;
    self.layer.shadowOpacity = isDark ? 0.30 : 0.12;
    self.layer.masksToBounds = NO;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.contentView.bounds cornerRadius:18.0].CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self pp_updateAppearanceForTraitCollection:self.traitCollection];
    }
}

- (void)pp_updateAppearanceForTraitCollection:(UITraitCollection *)tc {
    BOOL isDark = (tc.userInterfaceStyle == UIUserInterfaceStyleDark);

    // Overlay pill border — subtle edge in dark, hidden in light
    self.overlayPillView.layer.borderWidth = isDark ? 0.5 : 0.0;
    self.overlayPillView.layer.borderColor = isDark
        ? [UIColor colorWithWhite:1.0 alpha:0.12].CGColor
        : UIColor.clearColor.CGColor;

    // Shadow adapts for dark mode
    [self setupShadow];

    // Tag chip backgrounds — slightly stronger in dark
    CGFloat chipAlpha = isDark ? 0.18 : 0.10;
    UIColor *chipBg = [GM.appPrimaryColor colorWithAlphaComponent:chipAlpha];
    self.ageTagLabel.backgroundColor = chipBg;
    self.genderTagLabel.backgroundColor = chipBg;
}

#pragma mark - Public Configure

- (void)configureWithName:(NSString *)name imageURL:(NSString *)url subtitle:(NSString *)subtitle adoptPetModel:(AdoptPetModel *)adoptPetModel {
    self.adoptModel = adoptPetModel ?: [[AdoptPetModel alloc] init];
    [self setFavForCollection:@"favoritesAdoptPets" andID:self.adoptModel.documentID];

    NSString *title = PPAdoptCellSafeString(name);
    if (title.length == 0) {
        @try {
            id modelTitle = [self.adoptModel valueForKey:@"name"];
            if ([modelTitle isKindOfClass:NSString.class] && ((NSString *)modelTitle).length > 0) {
                title = PPAdoptCellSafeString(modelTitle);
            }
        } @catch (__unused NSException *e) {}
    }
    if (title.length == 0) {
        NSString *fallback = @"";
        @try { fallback = PPAdoptCellSafeString(self.adoptModel.subKindModel.SubKindName); } @catch (__unused NSException *e) {}
        title = fallback;
    }
    self.titleLabel.text = title;

    NSString *safeSubtitle = PPAdoptCellSafeString(subtitle);
    if (safeSubtitle.length == 0) {
        @try {
            id cityName = [self.adoptModel valueForKey:@"cityName"];
            if ([cityName isKindOfClass:NSString.class] && ((NSString *)cityName).length > 0) {
                safeSubtitle = PPAdoptCellSafeString(cityName);
            }
        } @catch (__unused NSException *e) {}

        @try {
            if (safeSubtitle.length == 0) {
                id city = [self.adoptModel valueForKey:@"city"];
                if ([city isKindOfClass:NSString.class] && ((NSString *)city).length > 0) {
                    safeSubtitle = PPAdoptCellSafeString(city);
                }
            }
        } @catch (__unused NSException *e) {}
    }

    NSString *finalSubtitle = (safeSubtitle.length > 0) ? safeSubtitle : kLang(@"City Undefined");
    self.subtitleLabel.text = finalSubtitle;

    [self pp_updateTagsForModel:self.adoptModel];

    self.imageView.backgroundColor = GM.backOffwhileColor;
    self.imageView.tintColor = UIColor.tertiaryLabelColor;
    if (url.length > 0) {
        [GM setImageFromFirebaseURLString:url
                                imageView:self.imageView
                                  phImage:@"PawPlacerS"
                              showShimmer:YES
                               completion:nil];
    } else {
        self.imageView.image = [UIImage imageNamed:@"PawPlacerS"];
    }
}

- (void)configureWithName:(NSString *)name imageURL:(NSString * _Nullable)urlString {
    self.titleLabel.text = name ?: @"";
    if (urlString.length > 0) {
        [GM setImageFromFirebaseURLString:urlString
                                imageView:self.imageView
                                  phImage:@"pawPlaceholder"
                              showShimmer:YES
                               completion:nil];
    } else {
        self.imageView.image = [UIImage imageNamed:@"pawPlaceholder"];
    }
}

- (void)pp_updateTagsForModel:(AdoptPetModel *)model {
    NSString *ageText = [self pp_ageTextForModel:model];
    self.ageTagLabel.text = ageText;
    self.ageTagLabel.hidden = (ageText.length == 0);

    NSString *genderText = [self pp_genderTextForModel:model];
    self.genderTagLabel.text = genderText;
    self.genderTagLabel.hidden = (genderText.length == 0);

    self.chipsStack.hidden = (self.ageTagLabel.hidden && self.genderTagLabel.hidden);
}

- (NSString *)pp_ageTextForModel:(AdoptPetModel *)model {
    NSInteger months = model.ageMonths;
    if (months <= 0) return @"";
    NSString *unit = (months == 1) ? kLang(@"month") : kLang(@"months");
    return [NSString stringWithFormat:@"%ld %@", (long)months, unit];
}

- (NSString *)pp_genderTextForModel:(AdoptPetModel *)model {
    NSString *raw = [PPAdoptCellSafeString(model.gender) lowercaseString];
    if (raw.length == 0) return @"";

    if ([raw containsString:@"female"] || [raw isEqualToString:@"f"]) {
        return kLang(@"Female");
    }
    if ([raw containsString:@"male"] || [raw isEqualToString:@"m"]) {
        return kLang(@"Male");
    }
    return model.gender;
}

- (void)pp_applyOwnerMode:(BOOL)isOwner animated:(BOOL)animated {
    void (^changes)(void) = ^{
        self.shareButton.alpha = isOwner ? 0.0 : 1.0;
        self.favButton.alpha = isOwner ? 0.0 : 1.0;
        self.deleteButton.alpha = isOwner ? 1.0 : 0.0;
        self.editButton.alpha = isOwner ? 1.0 : 0.0;

        self.shareButton.hidden = isOwner;
        self.favButton.hidden = isOwner;
        self.deleteButton.hidden = !isOwner;
        self.editButton.hidden = !isOwner;
    };

    if (animated) {
        [UIView animateWithDuration:0.22 animations:changes];
    } else {
        changes();
    }
}

-(void)setFavForCollection:(NSString *)collection andID:(NSString *)ID {
    self.favButton.adID = ID ?: @"";
    self.favButton.collection = collection ?: @"favoritesAdoptPets";
    self.favButton.isFavorite = NO;
    self.favButton.selected = NO;
    [self.favButton refreshAppearance];
    [self.favButton initValue];
    [self.favButton colosTintForAds];
}

@end
