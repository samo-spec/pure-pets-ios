
#import "PPBottomBar.h"

//
//  PPPaymentTabBar.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/11/2025.
//

 #import "Styling.h"

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

@interface BBCartBottomBar ()
{
    UIStackView *topRow;
    UIStackView *bottomRow;
}
@property (nonatomic, strong) UIView *separator;
@property (nonatomic, strong) UIVisualEffectView *blurBackground;
@property (nonatomic, strong) UIButton *BackgroundB;
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
    self.layer.shadowColor = AppShadowClr.CGColor;
    self.layer.shadowOpacity = 0.0;
    self.layer.shadowRadius = 0;
    self.layer.shadowOffset = CGSizeMake(0, -2);
}


- (void)setupUI {
    
    //UIColor *gb = [AppPrimaryClr colorWithAlphaComponent:1.2];
    self.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.0];
 
     
        self.BackgroundB = [UIButton buttonWithType:UIButtonTypeSystem];
        self.BackgroundB.translatesAutoresizingMaskIntoConstraints = NO;
        if (@available(iOS 26.0, *)) {
            UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
            cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
            cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
            cfg.background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.03];
            cfg.background.cornerRadius = 00;

            self.BackgroundB.configuration = cfg;
            [_BackgroundB updateConfiguration];
        }
         
        // ✅ Modern blur background
        if (@available(iOS 26.0, *)) {
            //UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
           
             //cfg.background.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.09];
             [self addSubview:self.BackgroundB];
            [NSLayoutConstraint activateConstraints:@[
                [self.BackgroundB.topAnchor constraintEqualToAnchor:self.topAnchor],
                [self.BackgroundB.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:0],
                [self.BackgroundB.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-0],
                [self.BackgroundB.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-0],
            ]];
        } else {
            self.backgroundColor = [UIColor systemBackgroundColor];

            // Allocate the blur backdrop for iOS < 26
            UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
            _blurBackground = [[UIVisualEffectView alloc] initWithEffect:blur];
            _blurBackground.translatesAutoresizingMaskIntoConstraints = NO;
            [self addSubview:_blurBackground];

            // Add BackgroundB to self so subviews share a common ancestor
            self.BackgroundB.backgroundColor = UIColor.clearColor;
            [self addSubview:self.BackgroundB];
            [NSLayoutConstraint activateConstraints:@[
                [self.BackgroundB.topAnchor constraintEqualToAnchor:self.topAnchor],
                [self.BackgroundB.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
                [self.BackgroundB.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
                [self.BackgroundB.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            ]];
        }
        
        if(!PPIOS26())
        {
            self.blurBackground.backgroundColor = AppClearClr;
            self.blurBackground.layer.cornerRadius = 42;
            
            [NSLayoutConstraint activateConstraints:@[
                [self.blurBackground.topAnchor constraintEqualToAnchor:self.topAnchor],
                [self.blurBackground.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
                [self.blurBackground.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
                [self.blurBackground.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
            ]];
            
            self.blurBackground.clipsToBounds = YES;
            self.blurBackground.layer.cornerRadius = PPCorners;

        }
         
     
 
    _minusButton = [self circleButtonWithTitle:@"–"];
    [_minusButton addTarget:self action:@selector(decreaseQuantity) forControlEvents:UIControlEventTouchUpInside];

    _plusButton = [self circleButtonWithTitle:@"+"];
    [_plusButton addTarget:self action:@selector(increaseQuantity) forControlEvents:UIControlEventTouchUpInside];

    _countLabel = [[UILabel alloc] init];
    _countLabel.text = @"1";
    _countLabel.font = [UIFont boldSystemFontOfSize:20];
    _countLabel.textAlignment = NSTextAlignmentCenter;
    _countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _countLabel.textColor = AppPrimaryClr;
    [_totalLabel removeFromSuperview];

    // === Create the labels ===
    _totalLabel = [[PPInsetLabel alloc] init];
    _totalLabel.text = kLang(@"OrderTotal");
    _totalLabel.font = [GM MidFontWithSize:16];
    _totalLabel.textColor = AppSecondaryTextClr;
    _totalLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_totalLabel sizeToFit];
    _amountLabel = [[PPInsetLabel alloc] init];
    _amountLabel.text = [NSString stringWithFormat:@"%.2f", _itemAmount];
    _amountLabel.font = [GM boldFontWithSize:26];
    _amountLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:1.1];
    _amountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_amountLabel sizeToFit];
    _currencyLabel = [[PPInsetLabel alloc] init];
    _currencyLabel.text = kLang(@"Rials");
    _currencyLabel.font = [GM MidFontWithSize:16];
    _currencyLabel.textColor = AppSecondaryTextClr;
    _currencyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_currencyLabel sizeToFit];
    // === Create a horizontal stack view ===
    UIStackView *totalStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        _totalLabel,
        _amountLabel,
        _currencyLabel
    ]];
    totalStack.axis = UILayoutConstraintAxisHorizontal;
    totalStack.alignment = UIStackViewAlignmentCenter;
    totalStack.spacing = 4;
    totalStack.translatesAutoresizingMaskIntoConstraints = NO;

   
    // === Add to Cart button ===
    _addToCartButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _addToCartButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_addToCartButton addTarget:self action:@selector(addToCartTapped)
               forControlEvents:UIControlEventTouchUpInside];

    // iOS 16+ Glass Button (modern style)
    if (@available(iOS 26.0, *)) {
        
        UIButtonConfiguration *config = [UIButtonConfiguration tintedButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        config.buttonSize = UIButtonConfigurationSizeLarge;
        config.baseForegroundColor = AppForgroundColr;
        config.baseBackgroundColor = [AppPrimaryClr colorWithAlphaComponent:1];
        config.background.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.1];
        config.background.cornerRadius = 30;
 
       
        config.title = kLang(@"addToCart");
            config.titleTextAttributesTransformer =
            ^NSDictionary<NSAttributedStringKey, id> * (NSDictionary<NSAttributedStringKey, id> *attrs) {
                NSMutableDictionary *m = [attrs mutableCopy];
                m[NSFontAttributeName] = [GM boldFontWithSize:18];
                m[NSForegroundColorAttributeName] = [AppForgroundColr colorWithAlphaComponent:1];
                return m;
            };
        
        
        // ✅ Stroke (supported in configuration)
        config.background.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.8];
        config.background.strokeWidth = 1.0;
 

            config.image = [UIImage systemImageNamed:@"cart.fill"];
            config.imagePlacement = NSDirectionalRectEdgeLeading;
            config.imagePadding = 6;
            config.preferredSymbolConfigurationForImage =
                [UIImageSymbolConfiguration configurationWithPointSize:18
                                                                weight:UIImageSymbolWeightSemibold
                                                                 scale:UIImageSymbolScaleMedium];

          config.background.strokeColor = [AppPrimaryClr colorWithAlphaComponent:0.3];
           config.background.strokeWidth = 1.3;
        _addToCartButton.configuration = config;
        [_addToCartButton setTintColor:AppForgroundColr];
    }
    // Older systems fallback (regular filled look)
    else {
        [_addToCartButton setTitle:kLang(@"addToCart") forState:UIControlStateNormal];
        _addToCartButton.titleLabel.font =  [GM boldFontWithSize:17];
        
        if (!PPIOS26()) {
            _addToCartButton.backgroundColor = AppPrimaryClr;
            [_addToCartButton setTitleColor:AppForgroundColr forState:UIControlStateNormal];
            [_addToCartButton setTintColor:AppForgroundColr];
        } else {
            _addToCartButton.backgroundColor = AppForgroundColr;
            [_addToCartButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        }
        
        _addToCartButton.layer.cornerRadius = 16;
    }
    
    _addToCartButton.clipsToBounds = YES;
    _addToCartButton.layer.masksToBounds = YES;
  
    
    // === Quantity stack ===
    UIStackView *qtyStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        _minusButton, _countLabel, _plusButton
    ]];
    qtyStack.axis = UILayoutConstraintAxisHorizontal;
    qtyStack.spacing = 3;
    qtyStack.alignment = UIStackViewAlignmentCenter;
    qtyStack.translatesAutoresizingMaskIntoConstraints = NO;
    qtyStack.semanticContentAttribute = GM.setSemantic;

    // === Container for qtyStack ===
    _qtyContainer = [Styling createContainerInParent:self withBgColor:nil];
    _qtyContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.BackgroundB addSubview:_qtyContainer];
    [_qtyContainer addSubview:qtyStack];

   

    
    [self.BackgroundB addSubview:_addToCartButton];
    
    self.favButton = [PPButtonHelper buttonWithSystemName:@"square.and.arrow.up" target:self action:@selector(sharaAccesee)];
    [self.BackgroundB addSubview:_favButton];
    
    
    CGFloat size = 44;
    [_favButton.widthAnchor constraintEqualToConstant:size].active = YES;
    [_favButton.heightAnchor constraintEqualToConstant:size].active = YES;
    // === Constraints ===
    _favButton.layer.cornerRadius = 22.0;
    _favButton.clipsToBounds = YES;
    self.semanticContentAttribute = GM.setSemantic;
    self.cartItemquantity = 1;
    
    
    [self.BackgroundB bringSubviewToFront:_addToCartButton];
    
    _addToCartButton.configurationUpdateHandler = ^(UIButton *btn) {
        if (btn.isHighlighted) {
            btn.configuration.baseBackgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.6];
        } else {
            btn.configuration.baseBackgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.9];
        }
    };
    
    
    // === Fixed size constants ===
    CGFloat qtyWidth = 140.0;
    CGFloat qtyHeight = 50;
    [self addSubview:totalStack];
    // === Constraints ===
    [NSLayoutConstraint activateConstraints:@[
        
        
        
        // FAV BTN
        [_favButton.trailingAnchor constraintEqualToAnchor:self.BackgroundB.trailingAnchor constant:-(PP_Padding+0)],
        [_favButton.topAnchor constraintEqualToAnchor:self.BackgroundB.topAnchor constant:PP_Padding],
     
        
        
        // qtyStack
        [totalStack.centerYAnchor constraintEqualToAnchor:_favButton.centerYAnchor constant:0],
        [totalStack.leadingAnchor constraintEqualToAnchor:self.BackgroundB.leadingAnchor constant:PP_Padding+10],

      
        // qtyStack
        [qtyStack.topAnchor constraintEqualToAnchor:_qtyContainer.topAnchor constant:0],
        [qtyStack.bottomAnchor constraintEqualToAnchor:_qtyContainer.bottomAnchor constant:-0],
        [qtyStack.leadingAnchor constraintEqualToAnchor:_qtyContainer.leadingAnchor],
        [qtyStack.trailingAnchor constraintEqualToAnchor:_qtyContainer.trailingAnchor],
        
        
        // Container position & size
        [_qtyContainer.leadingAnchor constraintEqualToAnchor:self.BackgroundB.leadingAnchor constant:PP_Padding],
        [_qtyContainer.topAnchor constraintEqualToAnchor:self.favButton.bottomAnchor constant:PP_Padding],
        [_qtyContainer.widthAnchor constraintEqualToConstant:qtyWidth],
        [_qtyContainer.heightAnchor constraintEqualToConstant:qtyHeight],
        
        
        // Add To Card Button
        [_addToCartButton.leadingAnchor constraintEqualToAnchor:_qtyContainer.trailingAnchor  constant:8],
        [_addToCartButton.topAnchor constraintEqualToAnchor:self.favButton.bottomAnchor constant:PP_Padding],
        [_addToCartButton.heightAnchor constraintEqualToConstant:50.0],
        [_addToCartButton.trailingAnchor constraintEqualToAnchor:self.BackgroundB.trailingAnchor constant:-PP_Padding],

    ]];
    
    UIButtonConfiguration *cfg = _favButton.configuration;
    cfg.background.backgroundColor = UIColor.whiteColor; // use background.backgroundColor
    cfg.baseBackgroundColor = UIColor.whiteColor;        // optional: backup for fallback
  //  _favButton.configuration = cfg;                      // reassign always!
   // [_favButton updateConfiguration];


}
-(void)sharaAccesee
{
    
}
//NSString *FavCollection = context == PPCellForAds ? @"favoritesAds" : context == PPCellForMarket? @"favoritesAccess" : context == PPCellForVets ? @"favoritesVets" : @"favoritesServices" ;
//[self setFavForCollection:FavCollection andID:vm.ModelID andButton:self.favButton];
-(void)setFavForCollection:(NSString *)collection andID:(NSString *)ID andButton:(FavoriteFloatingButton *)favButton
{//favoritesAds
    
    if(!UserManager.sharedManager.isUserLoggedIn) return;
    
    favButton.adID = ID;
    favButton.collection = collection;
    [favButton initValue];
}


#pragma mark - Button Factory

- (UIButton *)circleButtonWithTitle:(NSString *)title {
    // === Circle background view (below button) ===
    UIView *circleView = [[UIView alloc] init];
    circleView.translatesAutoresizingMaskIntoConstraints = NO;
    circleView.layer.cornerRadius = 14;
    circleView.layer.masksToBounds = YES;
    circleView.backgroundColor = [UIColor clearColor]; // placeholder color, can update later

    // === Button ===
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
   
    btn.translatesAutoresizingMaskIntoConstraints = NO;
  

    if (@available(iOS 26.0, *)) {
        // ✅ Use Apple's Glass button style if available
        UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;

       // config.baseForegroundColor =  [AppPrimaryClr colorWithAlphaComponent:1.2];
        
        config.baseBackgroundColor = [UIColor clearColor];
      //  config.background.strokeColor = [AppPrimaryClr colorWithAlphaComponent:0.3];
      //   config.background.strokeWidth = 1.0;
        
        //config.baseBackgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
        config.title = title;
        config.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey, id> * (NSDictionary<NSAttributedStringKey, id> *attrs) {
            NSMutableDictionary *m = [attrs mutableCopy];
            m[NSFontAttributeName] = [UIFont systemFontOfSize:20];
            m[NSForegroundColorAttributeName] = [AppPrimaryClr colorWithAlphaComponent:1.2];
            return m;
        };
        
        [btn setConfiguration:config];
    } else {
        // ✅ Fallback for older iOS versions
        btn.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
        btn.layer.cornerRadius = 14;
        btn.layer.masksToBounds = YES;
        btn.tintColor = [UIColor labelColor];
        [btn setTitle:title forState:UIControlStateNormal];
        btn.titleLabel.font = [GM MidFontWithSize:22];
    }

    // === Size constraints ===
    CGFloat size = 44.0;
    [btn.widthAnchor constraintEqualToConstant:size].active = YES;
    [btn.heightAnchor constraintEqualToConstant:size].active = YES;
    [circleView.widthAnchor constraintEqualToConstant:size].active = YES;
    [circleView.heightAnchor constraintEqualToConstant:size].active = YES;
 
    // 💡 Store reference for later use
    circleView.tag = 900; // or you can create a property to track it if needed

    return btn;
}


#pragma mark - Actions

- (void)increaseQuantity {
    self.cartItemquantity++;
    [self updateQuantityUI];
}

- (void)decreaseQuantity {
    if (self.cartItemquantity > 1) self.cartItemquantity--;
    [self updateQuantityUI];
}

- (void)addToCartTapped {
    if (self.onAddToCart) self.onAddToCart(self.cartItemquantity);
}

#pragma mark - Update UI

- (void)updateQuantityUI {
    self.countLabel.text = [NSString stringWithFormat:@"%ld", (long)self.cartItemquantity];
    if (self.onQuantityChanged) self.onQuantityChanged(self.cartItemquantity);
}

- (void)setInitItemAmount:(CGFloat)amount {
    //_totalAmount = totalAmount;
    _amountLabel.text = [NSString stringWithFormat:@"%.2f",amount];

}


- (void)setTotalAmount:(CGFloat)totalAmount {
    _totalAmount = totalAmount;
    _amountLabel.text = [NSString stringWithFormat:@"%.2f",totalAmount];

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
        bgButton.layer.shadowColor = AppShadowClr.CGColor;
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
        badge.layer.borderColor = borderColor.CGColor;
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
    badge.layer.borderColor = borderColor.CGColor;
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







