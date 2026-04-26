
#import "PPBottomBar.h"

//
//  PPPaymentTabBar.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/11/2025.
//

#import "Styling.h"
#import "PPCommerceFeedbackManager.h"

@interface PPPaymentTabBar ()
@property (nonatomic, strong) NSArray<UIButton *> *tabButtons;
@property (nonatomic, assign, readwrite) PPPaymentTab selectedTab;
@end

@implementation PPPaymentTabBar

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = UIColor.clearColor;
        self.layer.masksToBounds = NO;

        [self setupTabs];
        [self setSelectedTab:PPPaymentTabCard animated:NO];
    }
    return self;
}

#pragma mark - Setup

- (void)setupTabs {
    NSArray *titles = @[ @"Card", @"Ooredoo Money", @"PayPal" ];
    NSArray *icons  = @[ @"creditcard.fill", @"q.circle.fill", @"p.circle.fill" ];
    NSArray *colors = @[ UIColor.systemBlueColor, UIColor.systemRedColor, UIColor.systemIndigoColor ];

    NSMutableArray *buttons = [NSMutableArray array];

    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *btn = [self createGlassButtonWithTitle:titles[i]
                                                    icon:icons[i]
                                                   color:colors[i]];
        btn.tag = i;
        [btn addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [buttons addObject:btn];
    }

    self.tabButtons = buttons;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:buttons];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 12;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [self addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
        [stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8],
        [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12]
    ]];
}

- (UIButton *)createGlassButtonWithTitle:(NSString *)title
                                    icon:(NSString *)icon
                                   color:(UIColor *)tint {
    UIButton *button;

    if (@available(iOS 26.0, *)) {
        // 🧊 iOS 26 Modern glass button
        UIButtonConfiguration *cfg = [UIButtonConfiguration prominentGlassButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.baseForegroundColor = tint;
        cfg.image = [UIImage systemImageNamed:icon];
        cfg.imagePadding = 6;
        cfg.imagePlacement = NSDirectionalRectEdgeTop;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(10, 14, 10, 14);

        NSMutableAttributedString *attrTitle = [[NSMutableAttributedString alloc] initWithString:title
                                                                                       attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:16],
            NSForegroundColorAttributeName: UIColor.labelColor
        }];
        cfg.attributedTitle = attrTitle;

        button = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.configuration = cfg;
    } else {
        // 🌫️ Legacy fallback
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.layer.cornerRadius = 16;
        button.layer.masksToBounds = YES;

        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        blurView.userInteractionEnabled = NO;
        [button insertSubview:blurView atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [blurView.topAnchor constraintEqualToAnchor:button.topAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:button.bottomAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:button.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:button.trailingAnchor]
        ]];

        [button setTitle:title forState:UIControlStateNormal];
        [button setImage:[UIImage systemImageNamed:icon] forState:UIControlStateNormal];
        [button setTintColor:tint];
        [button.titleLabel setFont:[UIFont boldSystemFontOfSize:15]];
    }

    return button;
}

#pragma mark - Actions

- (void)tabTapped:(UIButton *)sender {
    [self setSelectedTab:(PPPaymentTab)sender.tag animated:YES];
    if (self.onSelect) self.onSelect(self.selectedTab);
}

- (void)setSelectedTab:(PPPaymentTab)tab animated:(BOOL)animated {
    _selectedTab = tab;

    for (UIButton *btn in self.tabButtons) {
        BOOL isSelected = (btn.tag == tab);

        if (@available(iOS 26.0, *)) {
            UIButtonConfiguration *cfg = btn.configuration;
            cfg.baseBackgroundColor = isSelected
                ? [btn.configuration.baseForegroundColor colorWithAlphaComponent:0.15]
                : [UIColor clearColor];
            cfg.baseForegroundColor = btn.configuration.baseForegroundColor;
            btn.configuration = cfg;
        } else {
            btn.alpha = isSelected ? 1.0 : 0.6;
        }

        if (animated) {
            [UIView animateWithDuration:0.25 animations:^{
                btn.transform = isSelected ? CGAffineTransformMakeScale(1.05, 1.05)
                                           : CGAffineTransformIdentity;
            }];
        }
    }
}

@end












 










/* **********************************************************************************************************************************************************************************************************/
#pragma mark - BBCartBottomBar

static CGFloat PPBBCartBarCornerRadius(void) {
    return PPIOS26() ? 34.0 : 28.0;
}

static CGFloat PPBBCartBadgeCartButtonSize(void) {
    return 44.0;
}

static UIColor *PPBBCartColor(UIColor *color, UIColor *fallback) {
    return color ?: fallback ?: UIColor.systemBackgroundColor;
}

static UIColor *PPBBCartSurfaceFillColor(void) {
    UIColor *base = PPBBCartColor(AppForgroundColr, UIColor.secondarySystemBackgroundColor);
    return [base colorWithAlphaComponent:PPIOS26() ? 0.24 : 0.92];
}

static UIColor *PPBBCartSurfaceTintColor(void) {
    UIColor *base = PPBBCartColor(AppBackgroundClr, UIColor.systemBackgroundColor);
    return [base colorWithAlphaComponent:PPIOS26() ? 0.10 : 0.18];
}

static UIColor *PPBBCartSurfaceStrokeColor(void) {
    return [UIColor.whiteColor colorWithAlphaComponent:PPIOS26() ? 0.24 : 0.32];
}

static UIColor *PPBBCartBadgeFillColor(void) {
    UIColor *base = PPBBCartColor(AppForgroundColr, UIColor.secondarySystemBackgroundColor);
    return [base colorWithAlphaComponent:PPIOS26() ? 0.18 : 0.80];
}

static UIImage *PPBBCartSymbol(NSString *name, CGFloat pointSize, UIImageSymbolWeight weight, UIColor *color) {
    UIImageSymbolConfiguration *size =
    [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                    weight:weight
                                                     scale:UIImageSymbolScaleMedium];
    UIImage *image = [UIImage systemImageNamed:name withConfiguration:size];
    UIColor *resolved = color ?: UIColor.labelColor;
    return [[image imageWithTintColor:resolved] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

@interface BBCartBottomBar ()
{
    UIStackView *topRow;
    UIStackView *bottomRow;
}
@property (nonatomic, strong) UIView *separator;
@property (nonatomic, strong) UIVisualEffectView *blurBackground;
@property (nonatomic, strong) UIButton *BackgroundB;
@property (nonatomic, strong) UIView *surfaceTintView;
@property (nonatomic, strong) UIView *surfaceHighlightView;
@property (nonatomic, strong) CAGradientLayer *surfaceGradientLayer;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIStackView *priceStack;
@property (nonatomic, strong) UIView *successHaloView;
@property (nonatomic, strong) CAGradientLayer *buttonSheenLayer;
@property (nonatomic, copy) NSString *idleAddToCartTitle;
@property (nonatomic, strong) UIImage *idleAddToCartImage;
@property (nonatomic, assign) BOOL didRunEntranceAnimation;
@property (nonatomic, assign, getter=isRestoringButton) BOOL restoringButton;
@property (nonatomic, assign) BOOL usesCompactCartButton;
@end
@implementation BBCartBottomBar

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self setupUI];
    }
    return self;
}

-(void)layoutSubviews
{
    [super layoutSubviews];

    self.clipsToBounds = NO;
    [self pp_setShadowColor:AppShadowClr];
    self.layer.shadowOpacity = PPIOS26() ? 0.08 : 0.10;
    self.layer.shadowRadius = 22.0;
    self.layer.shadowOffset = CGSizeMake(0.0, -10.0);
    self.layer.shadowPath =
    [UIBezierPath bezierPathWithRoundedRect:self.bounds
                               cornerRadius:PPBBCartBarCornerRadius()].CGPath;

    CGFloat surfaceRadius = PPBBCartBarCornerRadius();
    self.BackgroundB.layer.cornerRadius = surfaceRadius;
    self.blurBackground.layer.cornerRadius = surfaceRadius;
    self.surfaceTintView.layer.cornerRadius = surfaceRadius;
    self.surfaceGradientLayer.frame = self.BackgroundB.bounds;
    self.buttonSheenLayer.frame = self.addToCartButton.bounds;
    if (!self.didRunEntranceAnimation && self.bounds.size.height > 0.0) {
        self.didRunEntranceAnimation = YES;
        self.alpha = 0.0;
        self.transform = CGAffineTransformMakeTranslation(0.0, 18.0);
        [UIView animateWithDuration:0.46
                              delay:0.04
             usingSpringWithDamping:0.86
              initialSpringVelocity:0.45
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.alpha = 1.0;
            self.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}


- (void)setupUI {
    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = GM.setSemantic;
    self.usesCompactCartButton = YES;

    [self pp_buildSurface];

    _minusButton = [self circleButtonWithTitle:@"-"];
    [_minusButton addTarget:self action:@selector(decreaseQuantity) forControlEvents:UIControlEventTouchUpInside];

    _plusButton = [self circleButtonWithTitle:@"+"];
    [_plusButton addTarget:self action:@selector(increaseQuantity) forControlEvents:UIControlEventTouchUpInside];

    _countLabel = [[UILabel alloc] init];
    _countLabel.text = @"1";
    _countLabel.font = [GM boldFontWithSize:18] ?: [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
    _countLabel.textAlignment = NSTextAlignmentCenter;
    _countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _countLabel.textColor = PPBBCartColor(AppPrimaryClr, UIColor.labelColor);
    _countLabel.adjustsFontSizeToFitWidth = YES;
    _countLabel.minimumScaleFactor = 0.72;
    [_countLabel.widthAnchor constraintGreaterThanOrEqualToConstant:34.0].active = YES;

    _totalLabel = [[PPInsetLabel alloc] init];
    _totalLabel.text = kLang(@"OrderTotal");
    _totalLabel.font = [GM MidFontWithSize:13] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    _totalLabel.textColor = PPBBCartColor(AppSecondaryTextClr, UIColor.secondaryLabelColor);
    _totalLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _totalLabel.textAlignment = Language.alignmentForCurrentLanguage;

    _amountLabel = [[PPInsetLabel alloc] init];
    _amountLabel.text = [self pp_priceStringFromAmount:_itemAmount];
    _amountLabel.font = [GM boldFontWithSize:24] ?: [UIFont systemFontOfSize:24.0 weight:UIFontWeightBold];
    _amountLabel.textColor = PPBBCartColor(AppPrimaryTextClr, UIColor.labelColor);
    _amountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _amountLabel.adjustsFontSizeToFitWidth = YES;
    _amountLabel.minimumScaleFactor = 0.72;

    _currencyLabel = [[PPInsetLabel alloc] init];
    _currencyLabel.text = kLang(@"Rials");
    _currencyLabel.font = [GM MidFontWithSize:13] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    _currencyLabel.textColor = PPBBCartColor(AppSecondaryTextClr, UIColor.secondaryLabelColor);
    _currencyLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _priceStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        _totalLabel,
        _amountLabel,
        _currencyLabel
    ]];
    _priceStack.axis = UILayoutConstraintAxisHorizontal;
    _priceStack.alignment = UIStackViewAlignmentFirstBaseline;
    _priceStack.spacing = PPSpaceXS;
    _priceStack.translatesAutoresizingMaskIntoConstraints = NO;
    _priceStack.semanticContentAttribute = GM.setSemantic;

    _totalContainer = [UIButton buttonWithType:UIButtonTypeCustom];
    _totalContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _totalContainer.userInteractionEnabled = YES;
    _totalContainer.isAccessibilityElement = NO;
    _totalContainer.backgroundColor = PPBBCartBadgeFillColor();
    PPApplyContinuousCorners(_totalContainer, 22.0);
    [_totalContainer pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:PPIOS26() ? 0.20 : 0.30]];
    _totalContainer.layer.borderWidth = 0.7;
    [_totalContainer addSubview:_priceStack];

    _addToCartButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _addToCartButton.translatesAutoresizingMaskIntoConstraints = NO;
    _addToCartButton.clipsToBounds = YES;
    _addToCartButton.layer.masksToBounds = YES;
    _addToCartButton.accessibilityTraits = UIAccessibilityTraitButton;
    _addToCartButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_add_to_cart", @"Add to cart");
    _addToCartButton.accessibilityHint = NSLocalizedString(@"a11y_btn_add_to_cart_hint", @"Double-tap to add this item to your cart");
    [_addToCartButton addTarget:self action:@selector(addToCartTapped)
               forControlEvents:UIControlEventTouchUpInside];
    self.idleAddToCartTitle = kLang(@"addToCart");
    self.idleAddToCartImage = PPBBCartSymbol(@"cart.badge.plus", 18.0, UIImageSymbolWeightSemibold, AppForgroundColr);
    [self pp_setAddToCartTitle:self.idleAddToCartTitle
                     imageName:@"cart.badge.plus"
                    foreground:PPBBCartColor(AppForgroundColr, UIColor.whiteColor)
                    background:PPBBCartColor(AppPrimaryClr, UIColor.systemBlueColor)];
    PPApplyButtonShadow(_addToCartButton);
    [_totalContainer addSubview:_addToCartButton];
    _totalContainer.accessibilityElements = @[
        _totalLabel,
        _amountLabel,
        _currencyLabel,
        _addToCartButton
    ];

    _qtyStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        _minusButton, _countLabel, _plusButton
    ]];
    _qtyStack.axis = UILayoutConstraintAxisHorizontal;
    _qtyStack.spacing = PPSpaceXS;
    _qtyStack.alignment = UIStackViewAlignmentCenter;
    _qtyStack.distribution = UIStackViewDistributionEqualCentering;
    _qtyStack.translatesAutoresizingMaskIntoConstraints = NO;
    _qtyStack.semanticContentAttribute = GM.setSemantic;

    _qtyContainer = [UIButton buttonWithType:UIButtonTypeCustom];
    _qtyContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _qtyContainer.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.12 : 0.82];
    PPApplyContinuousCorners(_qtyContainer, 25.0);
    [_qtyContainer pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:PPIOS26() ? 0.20 : 0.34]];
    _qtyContainer.layer.borderWidth = 0.8;
    _qtyContainer.accessibilityLabel = NSLocalizedString(@"a11y_cart_qty_stepper", @"Item quantity");
    [_qtyContainer addSubview:_qtyStack];

    self.favButton = [PPButtonHelper buttonWithSystemName:@"square.and.arrow.up" target:self action:@selector(sharaAccesee)];
    self.favButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.favButton.accessibilityLabel = kLang(@"Share");
    [self pp_styleUtilityButton:self.favButton];

    CGFloat size = 48.0;
    [_favButton.widthAnchor constraintEqualToConstant:size].active = YES;
    [_favButton.heightAnchor constraintEqualToConstant:size].active = YES;

    self.cartItemquantity = 1;
    [self pp_buildLayoutRows];
    [self updateQuantityUI];


}
-(void)sharaAccesee
{
    
}
//NSString *FavCollection = context == PPCellForAds ? @"favoritesAds" : context == PPCellForMarket? @"favoritesAccess" : context == PPCellForVets ? @"favoritesVets" : @"favoritesServices" ;
//[self setFavForCollection:FavCollection andID:vm.ModelID andButton:self.favButton];
-(void)setFavForCollection:(NSString *)collection andID:(NSString *)ID andButton:(FavoriteFixedSizeButton *)favButton
{//favoritesAds
    
    if(!UserManager.sharedManager.isUserLoggedIn) return;
    
    favButton.adID = ID;
    favButton.collection = collection;
    [favButton initValue];
}


#pragma mark - Button Factory

- (UIButton *)circleButtonWithTitle:(NSString *)title {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.accessibilityTraits = UIAccessibilityTraitButton;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.baseForegroundColor = PPBBCartColor(AppPrimaryClr, UIColor.labelColor);
        config.baseBackgroundColor = UIColor.clearColor;
        config.title = title;
        config.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey, id> * (NSDictionary<NSAttributedStringKey, id> *attrs) {
            NSMutableDictionary *m = [attrs mutableCopy];
            m[NSFontAttributeName] = [UIFont systemFontOfSize:21.0 weight:UIFontWeightSemibold];
            m[NSForegroundColorAttributeName] = PPBBCartColor(AppPrimaryClr, UIColor.labelColor);
            return m;
        };
        btn.configuration = config;
    } else {
        [btn setTitle:title forState:UIControlStateNormal];
        [btn setTitleColor:PPBBCartColor(AppPrimaryClr, UIColor.labelColor) forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:21.0 weight:UIFontWeightSemibold];
    }

    btn.backgroundColor = UIColor.clearColor;
    PPApplyContinuousCorners(btn, 22.0);
    CGFloat size = 42.0;
    [btn.widthAnchor constraintEqualToConstant:size].active = YES;
    [btn.heightAnchor constraintEqualToConstant:size].active = YES;

    return btn;
}

- (void)pp_buildSurface {
    self.BackgroundB = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleLarge configType:PPButtonConfigrationGlass];
    self.BackgroundB.translatesAutoresizingMaskIntoConstraints = NO;
    self.BackgroundB.userInteractionEnabled = YES;
    self.BackgroundB.isAccessibilityElement = NO;
    self.BackgroundB.backgroundColor = PPBBCartSurfaceFillColor();
    PPApplyContinuousCorners(self.BackgroundB, PPBBCartBarCornerRadius());
    [self.BackgroundB pp_setBorderColor:PPBBCartSurfaceStrokeColor()];
    self.BackgroundB.layer.borderWidth = PPIOS26() ? 0.9 : 0.8;
    self.BackgroundB.clipsToBounds = YES;
    [self addSubview:self.BackgroundB];

    if (!PPIOS26()) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        self.blurBackground = [[UIVisualEffectView alloc] initWithEffect:blur];
        self.blurBackground.translatesAutoresizingMaskIntoConstraints = NO;
        self.blurBackground.userInteractionEnabled = NO;
        self.blurBackground.clipsToBounds = YES;
        PPApplyContinuousCorners(self.blurBackground, PPBBCartBarCornerRadius());
        [self.BackgroundB addSubview:self.blurBackground];
    }

    self.surfaceTintView = [[UIView alloc] init];
    self.surfaceTintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceTintView.userInteractionEnabled = NO;
    self.surfaceTintView.backgroundColor = PPBBCartSurfaceTintColor();
    self.surfaceTintView.clipsToBounds = YES;
    PPApplyContinuousCorners(self.surfaceTintView, PPBBCartBarCornerRadius());
    [self.BackgroundB addSubview:self.surfaceTintView];

    self.surfaceGradientLayer = [CAGradientLayer layer];
    self.surfaceGradientLayer.startPoint = CGPointMake(0.18, 0.0);
    self.surfaceGradientLayer.endPoint = CGPointMake(0.82, 1.0);
    self.surfaceGradientLayer.colors = @[
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:PPIOS26() ? 0.30 : 0.22].CGColor,
        (__bridge id)[PPBBCartColor(AppPrimaryClr, UIColor.systemBlueColor) colorWithAlphaComponent:PPIOS26() ? 0.08 : 0.045].CGColor,
        (__bridge id)[UIColor.blackColor colorWithAlphaComponent:PPIOS26() ? 0.045 : 0.035].CGColor
    ];
    self.surfaceGradientLayer.locations = @[@0.0, @0.56, @1.0];
    [self.surfaceTintView.layer addSublayer:self.surfaceGradientLayer];

    self.surfaceHighlightView = [[UIView alloc] init];
    self.surfaceHighlightView.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceHighlightView.userInteractionEnabled = NO;
    self.surfaceHighlightView.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:PPIOS26() ? 0.34 : 0.22];
    [self.BackgroundB addSubview:self.surfaceHighlightView];

    self.separator = [[UIView alloc] init];
    self.separator.translatesAutoresizingMaskIntoConstraints = NO;
    self.separator.backgroundColor = [UIColor.separatorColor colorWithAlphaComponent:PPIOS26() ? 0.12 : 0.18];
    [self.BackgroundB addSubview:self.separator];

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray array];
    if (self.blurBackground) {
        [constraints addObjectsFromArray:@[
            [self.blurBackground.topAnchor constraintEqualToAnchor:self.BackgroundB.topAnchor],
            [self.blurBackground.leadingAnchor constraintEqualToAnchor:self.BackgroundB.leadingAnchor],
            [self.blurBackground.trailingAnchor constraintEqualToAnchor:self.BackgroundB.trailingAnchor],
            [self.blurBackground.bottomAnchor constraintEqualToAnchor:self.BackgroundB.bottomAnchor]
        ]];
    }

    [constraints addObjectsFromArray:@[
        [self.BackgroundB.topAnchor constraintEqualToAnchor:self.topAnchor constant:0.0],
        [self.BackgroundB.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:PPSpaceMD],
        [self.BackgroundB.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-PPSpaceMD],
        [self.BackgroundB.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-PPSpaceMD],

        [self.surfaceTintView.topAnchor constraintEqualToAnchor:self.BackgroundB.topAnchor],
        [self.surfaceTintView.leadingAnchor constraintEqualToAnchor:self.BackgroundB.leadingAnchor],
        [self.surfaceTintView.trailingAnchor constraintEqualToAnchor:self.BackgroundB.trailingAnchor],
        [self.surfaceTintView.bottomAnchor constraintEqualToAnchor:self.BackgroundB.bottomAnchor],

        [self.surfaceHighlightView.topAnchor constraintEqualToAnchor:self.BackgroundB.topAnchor],
        [self.surfaceHighlightView.leadingAnchor constraintEqualToAnchor:self.BackgroundB.leadingAnchor constant:PPSpaceXL],
        [self.surfaceHighlightView.trailingAnchor constraintEqualToAnchor:self.BackgroundB.trailingAnchor constant:-PPSpaceXL],
        [self.surfaceHighlightView.heightAnchor constraintEqualToConstant:0.8],

        [self.separator.topAnchor constraintEqualToAnchor:self.BackgroundB.topAnchor],
        [self.separator.leadingAnchor constraintEqualToAnchor:self.BackgroundB.leadingAnchor constant:PPSpaceXL],
        [self.separator.trailingAnchor constraintEqualToAnchor:self.BackgroundB.trailingAnchor constant:-PPSpaceXL],
        [self.separator.heightAnchor constraintEqualToConstant:0.6]
    ]];

    [NSLayoutConstraint activateConstraints:constraints];
}

- (void)pp_buildLayoutRows {
    [NSLayoutConstraint activateConstraints:@[
        [self.priceStack.topAnchor constraintEqualToAnchor:self.totalContainer.topAnchor constant:PPSpaceSM],
        [self.priceStack.bottomAnchor constraintEqualToAnchor:self.totalContainer.bottomAnchor constant:-PPSpaceSM],
        [self.priceStack.leadingAnchor constraintEqualToAnchor:self.totalContainer.leadingAnchor constant:PPSpaceMD],
        [self.priceStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.addToCartButton.leadingAnchor constant:-PPSpaceSM],

        [self.addToCartButton.centerYAnchor constraintEqualToAnchor:self.totalContainer.centerYAnchor],
        [self.addToCartButton.trailingAnchor constraintEqualToAnchor:self.totalContainer.trailingAnchor constant:-4.0],
        [self.addToCartButton.widthAnchor constraintEqualToConstant:PPBBCartBadgeCartButtonSize()],
        [self.addToCartButton.heightAnchor constraintEqualToConstant:PPBBCartBadgeCartButtonSize()],

        [self.qtyStack.topAnchor constraintEqualToAnchor:self.qtyContainer.topAnchor constant:PPSpaceSM],
        [self.qtyStack.bottomAnchor constraintEqualToAnchor:self.qtyContainer.bottomAnchor constant:-PPSpaceSM],
        [self.qtyStack.leadingAnchor constraintEqualToAnchor:self.qtyContainer.leadingAnchor constant:PPSpaceSM],
        [self.qtyStack.trailingAnchor constraintEqualToAnchor:self.qtyContainer.trailingAnchor constant:-PPSpaceSM],

        [self.qtyContainer.widthAnchor constraintEqualToConstant:136.0],
        [self.qtyContainer.heightAnchor constraintEqualToConstant:PPButtonHeightLG],
        [self.totalContainer.heightAnchor constraintEqualToConstant:52.0]
    ]];

    topRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.totalContainer
    ]];
    topRow.axis = UILayoutConstraintAxisHorizontal;
    topRow.spacing = 0.0;
    topRow.alignment = UIStackViewAlignmentCenter;
    topRow.distribution = UIStackViewDistributionFill;
    topRow.semanticContentAttribute = GM.setSemantic;
    topRow.translatesAutoresizingMaskIntoConstraints = NO;

    bottomRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.qtyContainer,
        self.favButton
    ]];
    bottomRow.axis = UILayoutConstraintAxisHorizontal;
    bottomRow.spacing = PPSpaceMD;
    bottomRow.alignment = UIStackViewAlignmentCenter;
    bottomRow.distribution = UIStackViewDistributionEqualSpacing;
    bottomRow.semanticContentAttribute = GM.setSemantic;
    bottomRow.translatesAutoresizingMaskIntoConstraints = NO;

    [self.totalContainer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.totalContainer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.addToCartButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.addToCartButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    self.contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        topRow,
        bottomRow
    ]];
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = PPSpaceSM;
    self.contentStack.alignment = UIStackViewAlignmentFill;
    self.contentStack.distribution = UIStackViewDistributionFill;
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.BackgroundB addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.contentStack.topAnchor constraintEqualToAnchor:self.BackgroundB.topAnchor constant:PPSpaceSM],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.BackgroundB.leadingAnchor constant:PPSpaceMD],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.BackgroundB.trailingAnchor constant:-PPSpaceMD],
        [self.contentStack.bottomAnchor constraintLessThanOrEqualToAnchor:self.BackgroundB.bottomAnchor constant:-PPSpaceSM]
    ]];
}

- (void)pp_styleUtilityButton:(UIButton *)button {
    button.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.12 : 0.78];
    button.tintColor = PPBBCartColor(AppPrimaryTextClr, UIColor.labelColor);
    PPApplyContinuousCorners(button, 24.0);
    [button pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:PPIOS26() ? 0.18 : 0.30]];
    button.layer.borderWidth = 0.8;
    button.clipsToBounds = YES;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = button.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
        cfg.baseForegroundColor = PPBBCartColor(AppPrimaryTextClr, UIColor.labelColor);
        cfg.baseBackgroundColor = UIColor.clearColor;
        cfg.background.backgroundColor = UIColor.clearColor;
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        button.configuration = cfg;
    }
}

- (NSString *)pp_priceStringFromAmount:(CGFloat)amount {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 2;
    formatter.locale = NSLocale.currentLocale;
    return [formatter stringFromNumber:@(amount)] ?: [NSString stringWithFormat:@"%.2f", amount];
}

- (void)pp_setAddToCartTitle:(NSString *)title
                   imageName:(NSString *)imageName
                  foreground:(UIColor *)foreground
                  background:(UIColor *)background {
    NSString *resolvedTitle = title.length ? title : kLang(@"addToCart");
    UIColor *resolvedForeground = PPBBCartColor(foreground, UIColor.whiteColor);
    UIColor *resolvedBackground = PPBBCartColor(background, UIColor.systemBlueColor);
    BOOL compact = self.usesCompactCartButton;
    UIImage *image = PPBBCartSymbol(imageName ?: @"cart.badge.plus",
                                    compact ? 19.0 : 18.0,
                                    UIImageSymbolWeightSemibold,
                                    resolvedForeground);
    self.addToCartButton.accessibilityLabel = resolvedTitle;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config;
        if (compact && PPIOS26()) {
            if (@available(iOS 26.0, *)) {
                config = [UIButtonConfiguration prominentGlassButtonConfiguration];
            } else {
                config = [UIButtonConfiguration filledButtonConfiguration];
            }
        } else {
            config = [UIButtonConfiguration filledButtonConfiguration];
        }
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.buttonSize = UIButtonConfigurationSizeLarge;
        config.baseForegroundColor = resolvedForeground;
        config.baseBackgroundColor = resolvedBackground;
        config.background.backgroundColor = [resolvedBackground colorWithAlphaComponent:(compact && PPIOS26()) ? 0.74 : 1.0];
        config.background.cornerRadius = (compact ? PPBBCartBadgeCartButtonSize() : PPButtonHeightLG) * 0.5;
        config.background.strokeColor = [UIColor.whiteColor colorWithAlphaComponent:PPIOS26() ? 0.22 : 0.30];
        config.background.strokeWidth = 0.8;
        config.title = compact ? nil : resolvedTitle;
        config.image = image;
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.imagePadding = compact ? 0.0 : PPSpaceSM;
        config.contentInsets = compact
        ? NSDirectionalEdgeInsetsMake(0.0, 0.0, 0.0, 0.0)
        : NSDirectionalEdgeInsetsMake(0.0, PPSpaceBase, 0.0, PPSpaceBase);
        config.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey, id> * (NSDictionary<NSAttributedStringKey, id> *attrs) {
            NSMutableDictionary *m = [attrs mutableCopy];
            m[NSFontAttributeName] = [GM boldFontWithSize:16] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
            m[NSForegroundColorAttributeName] = resolvedForeground;
            return m;
        };
        self.addToCartButton.configuration = config;
    } else {
        self.addToCartButton.backgroundColor = resolvedBackground;
        [self.addToCartButton setTitle:compact ? nil : resolvedTitle forState:UIControlStateNormal];
        [self.addToCartButton setTitleColor:resolvedForeground forState:UIControlStateNormal];
        [self.addToCartButton setImage:image forState:UIControlStateNormal];
        self.addToCartButton.titleLabel.font = [GM boldFontWithSize:16] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
        self.addToCartButton.contentEdgeInsets = compact
        ? UIEdgeInsetsZero
        : UIEdgeInsetsMake(0.0, PPSpaceBase, 0.0, PPSpaceBase);
        self.addToCartButton.layer.cornerRadius = (compact ? PPBBCartBadgeCartButtonSize() : PPButtonHeightLG) * 0.5;
        if (@available(iOS 13.0, *)) {
            self.addToCartButton.layer.cornerCurve = kCACornerCurveContinuous;
        }
    }
}

- (void)pp_animateViewTap:(UIView *)view completion:(void (^ _Nullable)(void))completion {
    [UIView animateWithDuration:PPAnimDurationFast
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        view.transform = CGAffineTransformMakeScale(0.965, 0.965);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.34
                              delay:0.0
             usingSpringWithDamping:0.72
              initialSpringVelocity:0.45
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.transform = CGAffineTransformIdentity;
        } completion:^(__unused BOOL done) {
            if (completion) completion();
        }];
    }];
}

- (void)pp_runConfirmedSheen {
    [self.buttonSheenLayer removeFromSuperlayer];
    self.buttonSheenLayer = [CAGradientLayer layer];
    self.buttonSheenLayer.colors = @[
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:0.0].CGColor,
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:0.30].CGColor,
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:0.0].CGColor
    ];
    self.buttonSheenLayer.locations = @[@0.0, @0.48, @1.0];
    self.buttonSheenLayer.startPoint = CGPointMake(0.0, 0.5);
    self.buttonSheenLayer.endPoint = CGPointMake(1.0, 0.5);
    self.buttonSheenLayer.frame = self.addToCartButton.bounds;
    self.buttonSheenLayer.transform = CATransform3DMakeTranslation(-CGRectGetWidth(self.addToCartButton.bounds), 0.0, 0.0);
    [self.addToCartButton.layer addSublayer:self.buttonSheenLayer];

    CABasicAnimation *sweep = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    sweep.fromValue = @(-CGRectGetWidth(self.addToCartButton.bounds));
    sweep.toValue = @(CGRectGetWidth(self.addToCartButton.bounds));
    sweep.duration = 0.72;
    sweep.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.buttonSheenLayer addAnimation:sweep forKey:@"pp_add_to_cart_sheen"];
}

- (void)pp_runSuccessHalo {
    [self.successHaloView removeFromSuperview];
    self.successHaloView = [[UIView alloc] initWithFrame:self.addToCartButton.frame];
    self.successHaloView.translatesAutoresizingMaskIntoConstraints = NO;
    self.successHaloView.userInteractionEnabled = NO;
    self.successHaloView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.16];
    PPApplyContinuousCorners(self.successHaloView, PPButtonHeightLG * 0.5);

    UIView *hostView = self.addToCartButton.superview ?: self.BackgroundB;
    if (self.addToCartButton.superview == hostView) {
        [hostView insertSubview:self.successHaloView belowSubview:self.addToCartButton];
    } else {
        [hostView addSubview:self.successHaloView];
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.successHaloView.topAnchor constraintEqualToAnchor:self.addToCartButton.topAnchor],
        [self.successHaloView.bottomAnchor constraintEqualToAnchor:self.addToCartButton.bottomAnchor],
        [self.successHaloView.leadingAnchor constraintEqualToAnchor:self.addToCartButton.leadingAnchor],
        [self.successHaloView.trailingAnchor constraintEqualToAnchor:self.addToCartButton.trailingAnchor]
    ]];

    self.successHaloView.alpha = 0.0;
    self.successHaloView.transform = CGAffineTransformMakeScale(0.92, 0.92);
    [UIView animateWithDuration:0.54
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.successHaloView.alpha = 1.0;
        self.successHaloView.transform = CGAffineTransformMakeScale(1.045, 1.08);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.28
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            self.successHaloView.alpha = 0.0;
        } completion:^(__unused BOOL done) {
            [self.successHaloView removeFromSuperview];
            self.successHaloView = nil;
        }];
    }];
}

- (void)pp_restoreAddToCartButton {
    self.restoringButton = YES;
    [self pp_setAddToCartTitle:self.idleAddToCartTitle
                     imageName:@"cart.badge.plus"
                    foreground:PPBBCartColor(AppForgroundColr, UIColor.whiteColor)
                    background:PPBBCartColor(AppPrimaryClr, UIColor.systemBlueColor)];
    [UIView transitionWithView:self.addToCartButton
                      duration:0.22
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self.addToCartButton.alpha = 1.0;
    } completion:^(__unused BOOL finished) {
        self.addToCartButton.userInteractionEnabled = YES;
        self.restoringButton = NO;
    }];
}


#pragma mark - Actions

- (void)increaseQuantity {
    self.cartItemquantity++;
    [self pp_animateViewTap:self.qtyContainer completion:nil];
    [self updateQuantityUI];
}

- (void)decreaseQuantity {
    if (self.cartItemquantity > 1) self.cartItemquantity--;
    [self pp_animateViewTap:self.qtyContainer completion:nil];
    [self updateQuantityUI];
}

- (void)addToCartTapped {
    self.addToCartButton.userInteractionEnabled = NO;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pp_restoreAddToCartButton) object:nil];

    [self pp_animateViewTap:self.addToCartButton completion:^{
        self.addToCartButton.userInteractionEnabled = YES;
        if (self.onAddToCart) {
            self.onAddToCart(MAX(self.cartItemquantity, 1));
        } else {
            [self performAddToCartSuccessAnimation];
        }
    }];
}

#pragma mark - Update UI

- (void)updateQuantityUI {
    NSInteger safeQuantity = MAX(self.cartItemquantity, 1);
    _cartItemquantity = safeQuantity;
    NSString *nextText = [NSString stringWithFormat:@"%ld", (long)safeQuantity];

    if (![self.countLabel.text isEqualToString:nextText]) {
        [UIView transitionWithView:self.countLabel
                          duration:0.18
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            self.countLabel.text = nextText;
        } completion:nil];
    } else {
        self.countLabel.text = nextText;
    }

    self.minusButton.enabled = safeQuantity > 1;
    self.minusButton.alpha = safeQuantity > 1 ? 1.0 : 0.36;

    if (self.onQuantityChanged) self.onQuantityChanged(self.cartItemquantity);
}

- (void)setInitItemAmount:(CGFloat)amount {
    _itemAmount = amount;
    [self setTotalAmount:amount * MAX(self.cartItemquantity, 1)];

}


- (void)setTotalAmount:(CGFloat)totalAmount {
    _totalAmount = totalAmount;
    NSString *price = [self pp_priceStringFromAmount:totalAmount];
    [UIView transitionWithView:self.amountLabel
                      duration:0.18
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self.amountLabel.text = price;
    } completion:nil];

}

- (void)setItemAmount:(CGFloat)itemAmount {
    _itemAmount = itemAmount;
}

- (void)performAddToCartSuccessAnimation {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pp_restoreAddToCartButton) object:nil];
        self.addToCartButton.userInteractionEnabled = NO;

        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentSuccess];
        [self pp_setAddToCartTitle:kLang(@"AddedToCart")
                         imageName:@"checkmark.circle.fill"
                        foreground:PPBBCartColor(AppForgroundColr, UIColor.whiteColor)
                        background:PPBBCartColor(AppSuccessClr, PPBBCartColor(AppPrimaryClr, UIColor.systemGreenColor))];
        [self pp_runSuccessHalo];
        [self pp_runConfirmedSheen];

        self.addToCartButton.transform = CGAffineTransformMakeScale(0.97, 0.97);
        self.qtyContainer.transform = CGAffineTransformMakeScale(0.985, 0.985);

        [UIView animateWithDuration:0.44
                              delay:0.0
             usingSpringWithDamping:0.70
              initialSpringVelocity:0.60
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.addToCartButton.transform = CGAffineTransformIdentity;
            self.qtyContainer.transform = CGAffineTransformIdentity;
            self.totalContainer.transform = CGAffineTransformMakeScale(1.012, 1.012);
        } completion:^(__unused BOOL finished) {
            [UIView animateWithDuration:0.18 animations:^{
                self.totalContainer.transform = CGAffineTransformIdentity;
            }];
        }];

        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, kLang(@"ItemAddedToCart"));
        [self performSelector:@selector(pp_restoreAddToCartButton) withObject:nil afterDelay:1.05];
    });
}

- (void)performAddToCartFailureAnimation {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pp_restoreAddToCartButton) object:nil];
        [self.buttonSheenLayer removeFromSuperlayer];
        self.addToCartButton.userInteractionEnabled = YES;

        CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
        shake.values = @[@0, @(-8), @(7), @(-5), @(3), @0];
        shake.duration = 0.34;
        shake.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [self.addToCartButton.layer addAnimation:shake forKey:@"pp_add_to_cart_failure"];

        [UIView animateWithDuration:0.20
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.addToCartButton.alpha = 0.88;
        } completion:^(__unused BOOL finished) {
            [UIView animateWithDuration:0.20 animations:^{
                self.addToCartButton.alpha = 1.0;
            }];
        }];
    });

}

@end























/* **********************************************************************************************************************************************************************************************************/


#pragma mark - PPNewBottomBar

@interface PPNewBottomBar ()<UITabBarDelegate>

@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) UIView *VIEWFORHOLE;
@property (nonatomic, strong) UIButton *emptyCard;
@property (nonatomic, strong) UIButton *lastSeletedbutton;
@property (nonatomic, strong) NSArray<UITabBarItem *> *items;
@property (nonatomic, strong) UITabBarItem *cart;
@end

@implementation PPNewBottomBar

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
       
    }
    return self;
}


- (UIButton *)createCategoriesBackground
{
    UIButton *bgButton;
    if (@available(iOS 26.0, *)) {
        // 🧊 iOS 26+ system glass button
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.background.backgroundColor = UIColor.clearColor;
        cfg.baseBackgroundColor = UIColor.clearColor;
        cfg.background.cornerRadius = 0;

        
        bgButton = [UIButton  buttonWithType:UIButtonTypeSystem];
        bgButton.configuration = cfg;
      } else {
         
 
        // 🌫️ Fallback for iOS <26
        bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
        bgButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        bgButton.layer.cornerRadius = 16;
        bgButton.layer.masksToBounds = YES;
        [bgButton pp_setShadowColor:AppShadowClr];
        bgButton.layer.shadowOpacity = 0.15;
        bgButton.layer.shadowRadius = 8;
        bgButton.layer.shadowOffset = CGSizeMake(0, 4);
    }

    bgButton.translatesAutoresizingMaskIntoConstraints = NO;
    return bgButton;
}

- (void)setupView {
    
   
    
    // Avoid duplicate setup
    if (self.emptyCard && self.actionButton) return;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.clearColor;
    CGFloat pad = 12.0;

    // Empty card (background glass)
    self.emptyCard = [self createCategoriesBackground];
    self.emptyCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.emptyCard];

    _lastSeletedbutton = [UIButton new];

    [NSLayoutConstraint activateConstraints:@[
        [self.emptyCard.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:0],
        [self.emptyCard.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-0],
        [self.emptyCard.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.emptyCard.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
    self.emptyCard.alpha = 0;
    self.emptyCard.backgroundColor = UIColor.clearColor;
    //self.emptyCard.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    //self.emptyCard.layer.shadowOpacity = 0.36;
    //self.emptyCard.layer.shadowOffset = CGSizeMake(0, 2);
    //self.emptyCard.layer.shadowRadius = 6.0;
    //self.emptyCard.layer.cornerRadius = PPCorners + 16;

   
    [self addSubview:_emptyCard];
 

    // Floating action button (trailing anchor)
    _actionButton = [self pp_BarButtonWithSystemName:@"plus" klangKey:nil withSide:54 isCenterBtn:YES];
    _actionButton.accessibilityIdentifier = @"plus";
    if (@available(iOS 18.0, *)) {
        [_actionButton.imageView addSymbolEffect: [NSSymbolWiggleEffect effect]];
    } else {
        // Fallback on earlier versions
    }
    _actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    _actionButton.tag = PPBarTagNewAd;
    [_actionButton addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_actionButton];
    
    
    _searchButton = [self pp_BarButtonWithSystemName:@"magnifyingglass" klangKey:nil withSide:54 isCenterBtn:YES];
    _searchButton.translatesAutoresizingMaskIntoConstraints = NO;
    _searchButton.tag = PPBarTagSearch;
    [_searchButton addTarget:self action:@selector(searchTapped:) forControlEvents:UIControlEventTouchUpInside];
    _searchButton.hidden = NO;
    [self addSubview:_searchButton];
    _searchButton.hidden = YES;
    // Layout: action button anchored to trailing, container fills from leading to before button
    CGFloat horizontalMargin = 16.0;
    CGFloat trailingMargin = -16.0;

    
    [NSLayoutConstraint activateConstraints:@[
        // Action button trailing & vertical alignment
       
        [_actionButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:horizontalMargin],
        [_searchButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:trailingMargin],
        
        
 
    ]];

    // Style action button
    _actionButton.layer.cornerRadius = (_blurBarViewHeight - 14) / 2.0;
    _actionButton.clipsToBounds = YES;
   
    [self layoutIfNeeded];
    if(PPIOS26()) {
        [self addTabbbar];
    } else {
        // iOS <26: create UIStackView for tab buttons (configureWithItems: adds buttons here)
        _stackView = [[UIStackView alloc] init];
        _stackView.axis = UILayoutConstraintAxisHorizontal;
        _stackView.distribution = UIStackViewDistributionFillEqually;
        _stackView.alignment = UIStackViewAlignmentCenter;
        _stackView.spacing = 4;
        _stackView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_stackView];

        [NSLayoutConstraint activateConstraints:@[
            [_stackView.leadingAnchor constraintEqualToAnchor:_actionButton.trailingAnchor constant:4],
            [_stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:0],
            [_stackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_stackView.heightAnchor constraintEqualToAnchor:self.heightAnchor],
        ]];
    }
    
    
 
}



- (void)configureTabBarItems:(NSArray<NSDictionary *> *)items {
    
    [self setupView];
    
    // 1. Clear old buttons

    NSMutableArray *tabbaritemsArr = [NSMutableArray array];

    // 2. Create each button
    for (NSInteger i = 0; i < items.count; i++) {
        NSDictionary *info = items[i];
        NSString *iconName = info[@"icon"];
        PPBarTag tag = [info[@"tag"] integerValue];
        
        NSString *iconNameFill = [NSString stringWithFormat:@"%@.fill",info[@"icon"]];
        NSString *title    = _hideTitles ? nil : info[@"title"];

        UIColor *clr = [AppPrimaryClr colorWithAlphaComponent:1.0];
        UIImage *img = [UIImage systemImageNamed:iconName] ? [UIImage pp_symbolNamed:iconName pointSize:19 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleMedium palette:@[AppButtonMixColorClr,AppButtonMixColorClr] makeTemplate:YES] : [UIImage imageNamed:iconName];
        
        UIImage *imgFill = [UIImage systemImageNamed:iconNameFill] ? [UIImage pp_symbolNamed:iconNameFill pointSize:20 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleMedium palette:@[clr,clr] makeTemplate:YES] : [UIImage imageNamed:iconNameFill];

        UITabBarItem *itm;

        //if(_hideTitles == NO)
        //    itm = [[UITabBarItem alloc] initWithTitle:title image:img  selectedImage:imgFill ];
        //else
           //itm = [[UITabBarItem alloc] initWithTitle:nil image:[self bar_symbolNamed:iconName]  selectedImage:imgFill ];
        itm = [[UITabBarItem alloc] initWithTitle:title image:img  selectedImage:imgFill ];
        itm.tag = tag;
        
        
        [tabbaritemsArr addObject:itm];
        if(tag == PPBarTagCart)
            self.cart = itm;
        
    }
    _items = tabbaritemsArr;
    self.tabBar.items = _items;
    
    // FIX: Force layout so titles do not disappear
    [self.tabBar setNeedsLayout];
    [self.tabBar layoutIfNeeded];
    
   //
   // self.tabBar.itemPositioning = UITabBarItemPositioningCentered;
       // self.tabBar.itemWidth = 110.0;    // العرض المطلوب لكل أيقونة/عنصر
       // self.tabBar.itemSpacing = 16.0;  // المسافة بين العناصر
    
     
    _lastSelectedBarItem = tabbaritemsArr.firstObject;
    //[self.tabBar setSelectedItem:tabbaritemsArr.firstObject];
}


-(void)addTabbbar
{
    // 1️⃣ Create tab bar
    self.tabBar = [[UITabBar alloc] init];
    self.tabBar.delegate = self;

    // 2️⃣ Create tab bar items
    self.cart = [[UITabBarItem alloc] initWithTitle:kLang(@"Cart") image:[self bar_symbolNamed:@"cart"] tag:0];
    [self configureAppearance];

    self.tabBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabBarState = TabBarStateExpanded;
    
    
    [self addSubview:self.tabBar];
    self.tabBar.translatesAutoresizingMaskIntoConstraints = NO;
    // ensure tabBar fills the same background area (in case it was added earlier)
    [NSLayoutConstraint activateConstraints:@[
        [_searchButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:0],
        [_actionButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:0],
        
        [self.tabBar.leadingAnchor constraintEqualToAnchor:_actionButton.trailingAnchor constant:-16],
        [self.tabBar.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:0],
        [self.tabBar.centerYAnchor constraintEqualToAnchor:self.actionButton.centerYAnchor constant:10],
    ]];
     
    
    
}


// Floating background (emulates iOS 26 look)
- (void)pp_configureFloatingBackgroundForAppearance:(UITabBarAppearance *)appearance {
    if (@available(iOS 26.0, *)) {
        [appearance configureWithTransparentBackground];
    } else if (@available(iOS 13.0, *)) {
        //UITabBarAppearance *appearance = [UITabBarAppearance new];
        [appearance configureWithTransparentBackground];
        

    } else {
        appearance.backgroundImage = [UIImage new];
        appearance.shadowImage = [UIImage new];
    }
}


- (void)configureAppearance {
    // WHY: Make selected title invisible while keeping normal visible.
    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *appearance = [UITabBarAppearance new];
        [self pp_configureFloatingBackgroundForAppearance:appearance];

        NSDictionary<NSAttributedStringKey, id> *clearSelectedTitle =
        @{ NSForegroundColorAttributeName: [AppPrimaryClr colorWithAlphaComponent:1.0] ,
           NSFontAttributeName: [GM boldFontWithSize:12]};

        appearance.stackedLayoutAppearance.selected.titleTextAttributes = clearSelectedTitle;
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = clearSelectedTitle;
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = clearSelectedTitle;

        NSDictionary<NSAttributedStringKey, id> *normalTitle =
        @{ NSForegroundColorAttributeName: AppButtonMixColorClr ,
           NSFontAttributeName: [GM boldFontWithSize:12]};
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalTitle;
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = normalTitle;
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = normalTitle;
        
    

        self.tabBar.standardAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            self.tabBar.scrollEdgeAppearance = appearance;
        }
         
    } else {
        NSDictionary<NSAttributedStringKey, id> *clearSelectedTitle =
            @{ NSForegroundColorAttributeName: UIColor.clearColor };
        [[UITabBarItem appearance] setTitleTextAttributes:clearSelectedTitle forState:UIControlStateSelected];
    }
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
    NSLog(@"Selected tab: %@ (tag:%ld)", item.title, (long)item.tag);
    
   
    if(item.tag == PPBarTagCart)
    {
        if (self.onTabBarTapped) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.onTabBarTapped(item.tag, item);
            });
        }
        [self.tabBar setSelectedItem:_lastSelectedBarItem];
        return;
    } else  _lastSelectedBarItem = item;

        if (self.onTabBarTapped) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.onTabBarTapped(item.tag, item);
            });
        }
    
}

#pragma mark - Tab -> ViewController factory

- (UIViewController *)viewControllerForTabTag:(PPBarTag)tag {
    switch (tag) {
        case PPBarTagHome: {
             NewAppVC *vc = [[NewAppVC alloc] init];
            // configure vc if needed
            return vc;
        }
        case PPBarTagCart: {
            CartViewController *vc = [[CartViewController alloc] init];
            // If Cart should be a different VC, change class here
            return vc;
        }
        case PPBarTagChats: {
            UserChatsViewController *vc = [[UserChatsViewController alloc] init];
            return vc;
        }
        case PPBarTagOrdersHistory: {
            OrderHistoryViewController *vc = [[OrderHistoryViewController alloc] init];
            return vc;
        }
        default:
            return nil;
    }
}

- (void)deselectTabberItems
{

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
        self.tabBar.selectedItem = nil;
            });
}
// PPTabBarController.m

- (void)selectItemWithTag:(PPBarTag)tag animated:(BOOL)animated {
    NSArray<UITabBarItem *> *items = self.tabBar.items;
    NSUInteger index = NSNotFound;

    // Find tab by tag
    for (NSUInteger i = 0; i < items.count; i++) {
        if (items[i].tag == tag) {
            index = i;
            break;
        }
    }

    if (index == NSNotFound) {
        NSLog(@"Tab not found for tag %ld", (long)tag);
        return;
    }

    if (animated) {
        [UIView transitionWithView:self.tabBar
                          duration:0.25
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
          //  self.selectedIndex = index;
            self.tabBar.selectedItem = items[tag];
            
        } completion:nil];
    } else {
      //  self.selectedIndex = index;
    }
}


/*
 -(void)layoutSubviews
 {
     
     [super layoutSubviews];
     
     
     CGRect selfFrame = CGRectMake(0,
                                   -50,
                                   self.hx_w,
                                   self.hx_h + GM.bottomPadding + 50);
     self.backgroundColor = UIColor.clearColor;
     
     [PPFunc removeOldGradientsFromView:self];
     
     {
    
     PPGradientDirection direction =
     (_barBackStyle == BarBackStyleGardLTR)
     ? PPGradientDirectionRightToLeft
     : (_barBackStyle == BarBackStyleGardRTL)
     ? PPGradientDirectionLeftToRight
     : (_barBackStyle == BarBackStyleFadeTopToBottom)
     ? PPGradientDirectionTopToBottom
     : PPGradientDirectionBottomToTop;
   
         PPGradientDirection direction ;
     CAGradientLayer *mainGradient =
         [UIView gradientLayerWithFadeForColor:[AppShadowClr colorWithAlphaComponent:0.6]
                                 direction:direction
                                     frame:selfFrame];
     mainGradient.cornerRadius = PPCorners + 10;
     
     // 🔹 5. Add gradient based on style
     if (_barBackStyle == BarBackStyleFade || _barBackStyle == BarBackStyleLongFade) {
         
         mainGradient = [UIView halfGradientLayerWithFadeForColor:[AppForgroundColr colorWithAlphaComponent:0.1]
                                                        direction:PPGradientDirectionBottomToTop
                                                            frame:selfFrame];
         mainGradient.cornerRadius = PPCorners + 10;
         mainGradient.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
         [self.layer insertSublayer:mainGradient atIndex:0];
         
         
     }
     else if (_barBackStyle == BarBackStyleFadeTopToBottom) {
         mainGradient = [UIView gradientLayerWithFadeForColor:AppForgroundColr
                                                    direction:PPGradientDirectionTopToBottom
                                                        frame:selfFrame];
         mainGradient.cornerRadius = PPCorners + 10;
          [self.layer insertSublayer:mainGradient atIndex:0];
     }
     else if (_barBackStyle == BarBackStyleGardRTL) {
         mainGradient = [UIView gradientLayerWithFadeForColor:AppForgroundColr
                                                    direction:PPGradientDirectionRightToLeft
                                                        frame:selfFrame];
         mainGradient.cornerRadius = PPCorners + 10;
          [self.layer insertSublayer:mainGradient atIndex:0];
     }
     
     //CAGradientLayer *cardGradient =
     //   [UIView gradientLayerWithFadeForColor:AppBackgroundClr
     //           direction:PPGradientDirectionTopToBottom
     //        frame:emptyFrame];
     //cardGradient.cornerRadius = PPCorners + 15;
     //[self.emptyCard.layer insertSublayer:cardGradient atIndex:0];
     
     // 🔹 7. Semantic direction (RTL/LTR)
     self.semanticContentAttribute = GM.setSemantic;
 }
     //[_tabBar.heightAnchor constraintEqualToConstant:86].active = YES;
    // [_tabBar.widthAnchor constraintEqualToAnchor:self.widthAnchor constant:-60].active = YES;
     //[_tabBar.leadingAnchor constraintEqualToAnchor:_actionButton.trailingAnchor constant:-10].active = YES;
    // [_tabBar.centerYAnchor constraintEqualToAnchor:_actionButton.centerYAnchor constant:10].active = YES;
    
     //[_tabBar.bottomAnchor constraintEqualToAnchor:_actionButton.bottomAnchor constant:8].active = YES;

     [self.tabBar setTintColor:AppPrimaryClr];
     [self.tabBar setUnselectedItemTintColor:UIColor.grayColor];

     [self.tabBar setNeedsLayout];
     [self.tabBar layoutIfNeeded];
     [self.emptyCard bringSubviewToFront:_tabBar];

    
 }
 */




- (void)configureWithItems:(NSArray<NSDictionary *> *)items {
    
    [self setupView];
    
    // 1. Clear old buttons
    for (UIView *v in _stackView.arrangedSubviews) [v removeFromSuperview];

    NSMutableArray *btns = [NSMutableArray array];

    // 2. Create each button
    for (NSInteger i = 0; i < items.count; i++) {
        NSDictionary *info = items[i];
        NSString *iconName = info[@"icon"];
        NSString *title    = _hideTitles ? nil : info[@"title"];

    
        UIImage *img = [UIImage systemImageNamed:iconName] ? [UIImage pp_symbolNamed:iconName pointSize:20 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleMedium palette:@[AppPrimaryClrShiner,AppPrimaryClr] makeTemplate:YES] : [UIImage imageNamed:iconName];

        // --- Button configuration ---
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.image = img;
        cfg.imagePlacement = _hideTitles ? NSDirectionalRectEdgeAll : NSDirectionalRectEdgeTop;
        cfg.imagePadding = 4;
        cfg.background.backgroundColor = UIColor.clearColor;
         cfg.contentInsets = NSDirectionalEdgeInsetsMake(4, 4, 4, 4);

        if(_hideTitles == NO)
        {
            // Title styling (separate text color)
            NSAttributedString *attrTitle =
            [[NSAttributedString alloc] initWithString:title
                                            attributes:@{
                NSFontAttributeName: [GM MidFontWithSize:12],
                NSForegroundColorAttributeName: AppPrimaryTextClr
            }];
            cfg.attributedTitle = attrTitle;
        }
     
        
        // --- Create button ---
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        btn.configuration = cfg;
        btn.accessibilityIdentifier = iconName; // <– add this line

        // Tint color fallback (for iOS < 15)
        [btn.titleLabel setTextColor:AppPrimaryTextClr];
        [btn setTintColor:AppPrimaryTextClr];
        UIImage *fillicon = [UIImage systemImageNamed:iconName] ? [UIImage pp_symbolNamed:iconName pointSize:20 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleMedium palette:@[AppPrimaryClrShiner,AppPrimaryClr] makeTemplate:YES] : [UIImage imageNamed:iconName];
      
        [btn setImage:fillicon forState:UIControlStateSelected];
        [btn setImage:fillicon forState:UIControlStateHighlighted];
        
        [btn setImage:img forState:UIControlStateNormal];
        btn.tag = i;
        [btn addTarget:self
                 action:@selector(tabTapped:)
         
       forControlEvents:UIControlEventTouchUpInside];
        
        if([iconName isEqualToString:@"cart"])
        {
            self.cartButton = btn;
        }
        [btns addObject:btn];
        [_stackView addArrangedSubview:btn];
        
    }

    self.tabButtons = btns;
    //[self addBlurToView:_container style:UIBlurEffectStyleSystemUltraThinMaterial cornerRadius:_blurBarViewHeight/2];
    [self setNeedsLayout];
}


- (void)searchTapped:(UIButton *)sender {
     
    NSLog(@"[NEW BOTTOM BAR] searchTapped: %ld", (long)sender.tag);

    if(PPIOS26())
    {
            if (self.onTabBarTapped)  self.onTabBarTapped(PPBarTagSearch,(UIBarItem *)sender);
    }
    else
    {
        // 🔹 Animate tap + callback
        [self performButtonTapAnimation:sender animCompletion:^(BOOL finished) {
            if (self.onTabBarTapped)  self.onTabBarTapped(PPBarTagSearch, (UIBarItem *)sender);
        }];
        // 🔹 Highlight tapped button
        sender.selected = YES;
    }
    
}


- (void)tabTapped:(UIButton *)sender {
    NSLog(@"[NEW BOTTOM BAR] tabTapped: %ld", (long)sender.tag);

    if([AppMgr.topViewController isKindOfClass: MainController.class])
    {
        NewCardForm *vc = [NewCardForm new];
        vc.FromVC =  @"main";
       
        [AppMgr.topViewController.navigationController pushViewController:vc animated:YES];
        return;
    }
    if(PPIOS26())
    {
            if (self.onTabBarTapped)  self.onTabBarTapped(PPBarTagNewAd, (UIBarItem *)sender);
    }
    else
    {
        [self performButtonTapAnimation:sender animCompletion:^(BOOL finished) {
            if (self.onTabBarTapped) self.onTabBarTapped(PPBarTagNewAd, (UIBarItem *)sender);
        }];
        
        // 🔹 Highlight tapped button
        sender.selected = YES;
        [sender setTintColor:AppPrimaryClr];
    }
      
    
 

    
}
 
 

- (void)showTitles:(BOOL)show {
    for (UITabBarItem *item in self.tabBar.items) {
        if (show) {
            [item setTitlePositionAdjustment:UIOffsetMake(0, 0)];
            item.imageInsets = UIEdgeInsetsZero;
        } else {
            [item setTitlePositionAdjustment:UIOffsetMake(0, 10)];
            item.imageInsets = UIEdgeInsetsMake(6, 0, -6, 0);
        }
    }
}




















































































































































- (void)performButtonTapAnimation:(UIButton *)button animCompletion:(void (^ __nullable)(BOOL finished))animCompletion {
    AudioServicesPlaySystemSound(1104); // "Tock" – Apple system tap sound

    UIImpactFeedbackGenerator *feedback =
    [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
    [feedback impactOccurred];

    [UIView animateWithDuration:0.12
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        button.transform = CGAffineTransformMakeScale(0.90, 0.90);
        button.alpha = 0.9;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.20
                              delay:0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            button.transform = CGAffineTransformIdentity;
            button.alpha = 1.0;
        } completion:^(BOOL finished) {
            animCompletion(finished);
        }];
    }];
}

// ✅ Remove badge
- (void)removeBadgeAtIndex:(NSInteger)index {
    UILabel *badge = [self badgeLabels][@(index)];
    if (badge) {
        [badge removeFromSuperview];
        [[self badgeLabels] removeObjectForKey:@(index)];
    }
}

// ✅ Get the button safely
- (UIButton *)getButtonAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.tabButtons.count) return nil;
    return self.tabButtons[index];
}


-(void)setTabBarHidden:(BOOL)tabBarHidden
{
    if(tabBarHidden)
    {
        //[self setTabBarState:TabBarStateHidden animated:YES];
         //[self.tabBar setItems:@[self.cart] animated:YES];
    }
    else
    {
        //[self.tabBar setItems:_items animated:YES];
       // [self setTabBarState:TabBarStateExpanded animated:YES];
    }
    
}


- (void)applyFadeMaskToView:(UIView *)view
                  direction:(PPGradientDirection)direction
                  fadeStart:(CGFloat)start
                    fadeEnd:(CGFloat)end {
    // Remove any existing mask
    view.layer.mask = nil;
    
    // Create a gradient layer that will serve as the mask
    CAGradientLayer *maskLayer = [CAGradientLayer layer];
    maskLayer.frame = view.bounds;
    
    // White = visible, Black = transparent
    maskLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor
    ];
    
    // Define start/end based on direction
    switch (direction) {
        case PPGradientDirectionTopToBottom:
            maskLayer.startPoint = CGPointMake(0.5, start);
            maskLayer.endPoint   = CGPointMake(0.5, end);
            break;
        case PPGradientDirectionBottomToTop:
            maskLayer.startPoint = CGPointMake(0.5, 1.0 - start);
            maskLayer.endPoint   = CGPointMake(0.5, 1.0 - end);
            break;
        case PPGradientDirectionLeftToRight:
            maskLayer.startPoint = CGPointMake(start, 0.5);
            maskLayer.endPoint   = CGPointMake(end, 0.5);
            break;
        case PPGradientDirectionRightToLeft:
            maskLayer.startPoint = CGPointMake(1.0 - start, 0.5);
            maskLayer.endPoint   = CGPointMake(1.0 - end, 0.5);
            break;
    }
    
    // Apply mask
    view.layer.mask = maskLayer;
    
    // Keep mask updated during layout
    view.layer.masksToBounds = YES;
    view.layer.needsDisplayOnBoundsChange = YES;
}


#pragma mark - Toggle Action Button Visibility

- (void)setActionButtonHidden:(BOOL)hidden {
    if (_actionButton.hidden == hidden) return; // no change

    [UIView transitionWithView:_actionButton
                      duration:0.25
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        self.actionButton.hidden = hidden;
                    } completion:nil];

    // Remove old leading constraint for container
    for (NSLayoutConstraint *constraint in self.constraints) {
        if ((constraint.firstItem == _emptyCard && constraint.firstAttribute == NSLayoutAttributeLeading) ||
            (constraint.secondItem == _emptyCard && constraint.secondAttribute == NSLayoutAttributeLeading)) {
            [constraint setActive:NO];
        }
    }

    // Create new constraint depending on hidden state
    NSLayoutConstraint *newLeading;
    NSLayoutConstraint *newTabBarLeading;
    if (hidden) {
        // Expand to full width
        newLeading = [_emptyCard.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14];
        newTabBarLeading = [_tabBar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14];
    } else {
        // Normal mode (next to button)
        newLeading = [_emptyCard.leadingAnchor constraintEqualToAnchor:_actionButton.trailingAnchor constant:14];
        newTabBarLeading = [_tabBar.leadingAnchor constraintEqualToAnchor:_actionButton.trailingAnchor constant:14];
    }

    newLeading.active = YES;
    newTabBarLeading.active = YES;
    // Animate layout change smoothly
    [UIView animateWithDuration:0.3
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [self layoutIfNeeded];
                     } completion:nil];
}
- (UIButton *)pp_BarButtonWithSystemName:(NSString *)imageName
                                klangKey:(NSString *)klangKey
                                withSide:(CGFloat)btnSize
                             isCenterBtn:(BOOL)isCenterBtn
{
    // Create config
    UIButtonConfiguration *cfg;
    UIButton *btn = [[UIButton alloc]init];
    
    //UIImage *icon;
    //NSMutableAttributedString *attributedTitle;
        // --- Center (main action) button ---
    if (@available(iOS 26.0, *)) {
        cfg = [UIButtonConfiguration glassButtonConfiguration];
        UIImage *img = [UIImage systemImageNamed:imageName] ? [UIImage pp_symbolNamed:imageName pointSize:18 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleLarge palette:@[[AppPrimaryClr colorWithAlphaComponent:1.2],[AppPrimaryClr colorWithAlphaComponent:1.2]] makeTemplate:YES] : [UIImage imageNamed:imageName];
            //cfg.baseForegroundColor=[AppPrimaryClr colorWithAlphaComponent:1.2];
          
            cfg.image = img;
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
            btn.configuration = cfg;
            btn.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
            [btn.widthAnchor constraintEqualToConstant:btnSize].active = YES;
            [btn.heightAnchor constraintEqualToConstant:btnSize].active = YES;
            return btn;
        }
        else
        {
            cfg = [UIButtonConfiguration filledButtonConfiguration];
            UIImage *img;
            if([imageName isEqualToString:@"plus"])
                img = [UIImage systemImageNamed:imageName] ? [UIImage pp_symbolNamed:imageName pointSize:18 weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleMedium palette:@[AppForgroundColr,AppForgroundColr] makeTemplate:YES] : [UIImage imageNamed:imageName];
            else
                img = [UIImage systemImageNamed:imageName] ? [UIImage pp_symbolNamed:imageName pointSize:18 weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleMedium palette:@[AppForgroundColr,AppForgroundColr] makeTemplate:YES] : [UIImage imageNamed:imageName];
                
            cfg.baseForegroundColor=AppForgroundColr;
            cfg.baseBackgroundColor=[AppPrimaryClr colorWithAlphaComponent:0.8];
            cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;

            cfg.image = img;
            UIButton *btn = [UIButton  buttonWithConfiguration:cfg primaryAction:nil];
            //btn.configuration = cfg;
            btn.translatesAutoresizingMaskIntoConstraints = NO;
            btn.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

            // --- Size behavior ---
            if (isCenterBtn) {
                [btn.widthAnchor constraintEqualToConstant:btnSize].active = YES;
                [btn.heightAnchor constraintEqualToConstant:btnSize].active = YES;
            }
        
            btn.layer.cornerRadius = btnSize / 2;
            btn.clipsToBounds= YES;
            [btn setImage:img forState:UIControlStateNormal];
            [btn setTintColor:AppForgroundColr];
            [btn.imageView setTintColor:AppForgroundColr];
            return btn;
        }
        

    
    
  

    return btn;
}

- (UIVisualEffectView *)addBlurToView:(UIView *)view
                                 style:(UIBlurEffectStyle)style
                           cornerRadius:(CGFloat)cornerRadius
{
    
    
    if (@available(iOS 26.0, *)) return nil;
    // 1. Create the blur effect
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:style];

    // 2. Create the blur view
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;

    // 3. Create vibrancy effect for extra transparency
    UIVibrancyEffect *vibrancyEffect = [UIVibrancyEffect effectForBlurEffect:blurEffect];
    UIVisualEffectView *vibrancyView = [[UIVisualEffectView alloc] initWithEffect:vibrancyEffect];
    vibrancyView.translatesAutoresizingMaskIntoConstraints = NO;

    // Add vibrancy view to blur view's content
    [blurView.contentView addSubview:vibrancyView];

    // 4. Round the corners (optional)
    blurView.layer.cornerRadius = cornerRadius;
    blurView.layer.masksToBounds = YES;
   // blurView.alpha = 0.7;
    // 5. Insert into your view hierarchy
    [view insertSubview:blurView atIndex:0];

    // 6. Pin blur view to edges
    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:view.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
    ]];

    // 7. Pin vibrancy view to blur view's content
    [NSLayoutConstraint activateConstraints:@[
        [vibrancyView.topAnchor constraintEqualToAnchor:blurView.contentView.topAnchor],
        [vibrancyView.leadingAnchor constraintEqualToAnchor:blurView.contentView.leadingAnchor],
        [vibrancyView.trailingAnchor constraintEqualToAnchor:blurView.contentView.trailingAnchor],
        [vibrancyView.bottomAnchor constraintEqualToAnchor:blurView.contentView.bottomAnchor]
    ]];

    return blurView;
  
}

- (UIView *)pp_createGlassBlurFadeViewWithHeight:(CGFloat)height {
    
    // Container view
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.clipsToBounds = YES;
    container.userInteractionEnabled = NO;

    // 🧊 1. Blur background (glass)
    UIVisualEffectView *blurView =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:blurView];

    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    // 🌫 2. Add gradient fade (bottom → transparent)
    CAGradientLayer *fade = [CAGradientLayer layer];
    fade.colors = @[
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.6].CGColor,
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.15].CGColor,
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.0].CGColor
    ];
    
    fade.locations = @[@0.0, @0.5, @1.0];
    fade.startPoint = CGPointMake(0.5, 1.0);
    fade.endPoint = CGPointMake(0.5, 0.0);
    fade.frame = CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, height);
    fade.name = @"BottomFadeLayer";
    [container.layer addSublayer:fade];

    // 🧷 Optional: subtle border line
    CALayer *line = [CALayer layer];
    line.backgroundColor = [UIColor colorWithWhite:0.9 alpha:0.4].CGColor;
    line.frame = CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, 0.5);
    [container.layer addSublayer:line];

    return container;
}


#pragma mark - Badge Support

// Store badges in a dictionary
- (NSMutableDictionary<NSNumber *, UILabel *> *)badgeLabels {
    static char kBadgeLabelsKey;
    NSMutableDictionary *badges = objc_getAssociatedObject(self, &kBadgeLabelsKey);
    if (!badges) {
        badges = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &kBadgeLabelsKey, badges, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return badges;
}

- (void)setBadge:(NSString *)value forTag:(PPBarTag)tag {
    for (UITabBarItem *it in self.tabBar.items) {
        if (it.tag == tag) {
            it.badgeValue = value;
            return;
        }
    }
}

// ✅ Add or update badge
- (void)setBadgeOnButtonAtIndex:(NSInteger)index
                          value:(NSString *)value
                backgroundColor:(UIColor *)bgColor
                    borderColor:(UIColor *)borderColor
{
    
    if(PPIOS26())
    {
        
        [self setBadge:value forTag:PPBarTagChats];
        return;
    }
    UIButton *button = [self getButtonAtIndex:index];
    if (!button) return;

    UILabel *badge = [self badgeLabels][@(index)];
    if (!badge) {
        badge = [[UILabel alloc] init];
        badge.translatesAutoresizingMaskIntoConstraints = NO;
        badge.textAlignment = NSTextAlignmentCenter;
        badge.font = [UIFont boldSystemFontOfSize:11];
        badge.textColor = UIColor.whiteColor;
        badge.backgroundColor = bgColor ?: UIColor.systemRedColor;
        badge.layer.cornerRadius = 9;
        badge.layer.masksToBounds = YES;
        [badge pp_setBorderColor:borderColor];
        badge.layer.borderWidth = borderColor ? 1.0 : 0.0;
        badge.adjustsFontSizeToFitWidth = YES;
        badge.minimumScaleFactor = 0.7;
        [button addSubview:badge];
        [self badgeLabels][@(index)] = badge;

        // 🧩 Constraints: top-right corner of button
        [NSLayoutConstraint activateConstraints:@[
            [badge.centerXAnchor constraintEqualToAnchor:button.trailingAnchor constant:-20],
            [badge.centerYAnchor constraintEqualToAnchor:button.topAnchor constant:6],
            [badge.heightAnchor constraintEqualToConstant:18],
            [badge.widthAnchor constraintGreaterThanOrEqualToConstant:18]
        ]];
    }

    badge.text = value;
    badge.backgroundColor = bgColor ?: badge.backgroundColor;
    [badge pp_setBorderColor:borderColor];
    badge.hidden = (value.length == 0);
}
- (UIImage *)bar_symbolNamed:(NSString *)name
{
    UIImage *img = [UIImage systemImageNamed:name];
    if (!img) return nil;

    // Build symbol configuration
    UIImageSymbolConfiguration *colorCfg =
    [UIImageSymbolConfiguration configurationWithHierarchicalColor:[AppPrimaryClr colorWithAlphaComponent:1.2]];

    UIImageSymbolConfiguration *sizeCfg =
    [UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                    weight:UIImageSymbolWeightSemibold
                                                     scale:UIImageSymbolScaleMedium];

    // Merge color + size configs
    UIImageSymbolConfiguration *finalCfg =
        [colorCfg configurationByApplyingConfiguration:sizeCfg];

    UIImage *configured = [img imageByApplyingSymbolConfiguration:finalCfg];
    if (configured) return configured;

    // Fallback for non-symbol images
    UIImage *templ = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    return [self pp_resizedImage:templ toPointSize:18.0];
}


- (UIImage *)pp_symbolNamed:(NSString *)name
{
    UIImage *img = [UIImage imageNamed:name];
#if __IPHONE_13_0
    if (!img) { img = [UIImage systemImageNamed:name]; } // allow using a real SF symbol name too
#endif
    if (!img) { return nil; }
    
#if __IPHONE_13_0
    // Try to apply symbol configuration (has effect only for symbol images)
    UIImageSymbolConfiguration *cfg =
    [UIImageSymbolConfiguration configurationWithPointSize:22.0
                                                    weight:UIImageSymbolWeightSemibold
                                                     scale:UIImageSymbolScaleLarge];
    //NSArray *palette =@[AppSecondaryTextClr,AppSecondaryTextClr];
#if __IPHONE_15_0
   // if (palette.count > 0) {
   //     UIImageSymbolConfiguration *pal = [UIImageSymbolConfiguration configurationWithPaletteColors:palette];
   //     cfg = [cfg configurationByApplyingConfiguration:pal];
   // }
#endif
    
    UIImage *configured = [img imageByApplyingSymbolConfiguration:cfg];
    if (configured) {
        return configured;
    }
#endif
    
    // Not a symbol → make it a template so tint works, and optionally resize to approx. point size.
    UIImage *templ = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] ;
    return [self pp_resizedImage:templ toPointSize:18.0];
}

- (UIImage *)pp_resizedImage:(UIImage *)image toPointSize:(CGFloat)pointSize {
    if (!image) return nil;
    
    // Treat pointSize as target height; keep aspect
    CGFloat targetH = MAX(pointSize, 1.0);
    CGFloat aspect = image.size.width / MAX(image.size.height, 0.001);
    CGSize targetSize = CGSizeMake(targetH * aspect, targetH);
    
    UIGraphicsImageRenderer *renderer =
    [[UIGraphicsImageRenderer alloc] initWithSize:targetSize];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
        [image drawInRect:(CGRect){.origin=CGPointZero, .size=targetSize}];
    }];
}


@end

