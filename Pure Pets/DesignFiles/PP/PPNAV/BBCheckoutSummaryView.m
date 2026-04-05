//
//  BBCheckoutSummaryView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 11/01/2026.
//

#import "BBCheckoutSummaryView.h"
#import "PPChatsFunc.h"
#import "CartManager.h"
#import "PPCartCalculator.h"


@interface BBCheckoutSummaryView () <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) UIView *animationContainerView;
@property (nonatomic, copy) void (^onRemovePreviewItem)(CartItem *item);
@property (nonatomic, strong) LOTAnimationView *animationView;
 
@property (nonatomic, strong) UIButton *cardView;
@property (nonatomic, strong) UIStackView *pricingStack;
 @property (nonatomic, strong) UILabel *itemsLabel;
@property (nonatomic, strong) UILabel *itemsValueLabel;
@property (nonatomic, assign) BOOL didRunCardEntranceAnimation;
@property (nonatomic, strong) UILabel *shippingLabel;
@property (nonatomic, strong) UILabel *shippingValueLabel;
 
@property (nonatomic, strong) UIView *separator;

@property (nonatomic, strong) UILabel *subtotalAttributedLabel;

@property (nonatomic, strong) UIButton *checkoutBTN;
@property (nonatomic, strong) UIActivityIndicatorView *checkoutFallbackIndicator;
@property (nonatomic, strong) UIImage *checkoutButtonImageForIdle;
@property (nonatomic, assign, getter=isCheckoutLoading) BOOL checkoutLoading;

@property (nonatomic, strong) UICollectionView *itemsPreviewCollection;
@property (nonatomic, strong) NSArray<CartItem *> *previewItems;
@property (nonatomic, assign) BOOL showsItemsPreview;

@property (nonatomic, strong) UIStackView *itemsRow;
@property (nonatomic, strong) UIStackView *shippingRow;
 @property (nonatomic, strong) NSLayoutConstraint *pricingStackBottomAnchor;

@property (nonatomic, strong) UIView *trustBannerView;
@property (nonatomic, strong) UILabel *trustBannerLabel;
@property (nonatomic, strong) CAGradientLayer *trustBannerShimmerLayer;
@property (nonatomic, assign) BOOL cardShadowApplied;
@property (nonatomic, assign) BOOL shadowSetted;
@property (nonatomic, assign) BOOL gradianAdded;
@end

@implementation BBCheckoutSummaryView

static NSString *PPCheckoutDecimalSeparatorFromFormattedPrice(NSString *formattedPrice) {
    if (formattedPrice.length == 0) return @".";
    if ([formattedPrice rangeOfString:@"٫"].location != NSNotFound) return @"٫";
    if ([formattedPrice rangeOfString:@"."].location != NSNotFound) return @".";
    return [NSLocale currentLocale].decimalSeparator ?: @".";
}

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.shadowSetted = NO;
        self.gradianAdded = NO;
        self.didRunCardEntranceAnimation = NO;
        [self buildUI];
        [self buildLayout];
        [self updateTotalsWithItems:0 shipping:0 showTitle:YES];
        self.previewItems = @[];
        self.showsItemsPreview = NO;
        // --- Cart observer for preview sync
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(pp_cartDidUpdate)
         name:kCartUpdatedNotification
         object:nil];
    }
    return self;
}


// --- Cart observer handler for syncing preview items with cart ---
- (void)pp_cartDidUpdate
{
    NSArray<CartItem *> *items =
        [CartManager sharedManager].cartItems;

    self.previewItems = items ?: @[];

    PPCartSummary *summary = [PPCartCalculator currentSummary];
    [self updateTotalsWithItems:summary.subtotal shipping:summary.shippingFee showTitle:self.showDetails];

    BOOL shouldShowPreview =
        self.showsItemsPreview && self.previewItems.count > 0;

    self.itemsPreviewCollection.hidden = !shouldShowPreview;
    self.itemsPreviewCollection.alpha = shouldShowPreview ? 1.0 : 0.0;

    [self.itemsPreviewCollection reloadData];
}

// --- Remove observer on dealloc ---
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


-(void)layoutSubviews
{
    [super layoutSubviews];
  
   
    
    self.userInteractionEnabled = YES;
    self.cardView.userInteractionEnabled = YES;
    self.checkoutBTN.userInteractionEnabled = YES;
   
    //self.backgroundColor = AppBackgroundClrDarker;
    [self.cardView bringSubviewToFront:self.pricingStack];
    [self.cardView bringSubviewToFront:self.checkoutBTN];
    
    if (self.trustBannerShimmerLayer) {
        self.trustBannerShimmerLayer.frame = self.trustBannerView.bounds;
    }
    if(!self.shadowSetted)
    {
        //[self setBlackShadowOffset:CGSizeMake(0, -3) radius:10 alpha:0.08];
        self.shadowSetted = YES;
    }
    
 
   
    if (!self.didRunCardEntranceAnimation &&
        self.cardView.bounds.size.height > 0) {

        self.didRunCardEntranceAnimation = YES;

        // Initial state: wide + down + faded
        self.cardView.alpha = 0.0;
        self.cardView.transform =
            CGAffineTransformConcat(
                CGAffineTransformMakeTranslation(0, 28),   // from bottom
                CGAffineTransformMakeScale(1.05, 0.96)     // slightly wide
            );

        [UIView animateWithDuration:0.45
                              delay:0.06
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.cardView.alpha = 1.0;
            self.cardView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
    [self bringSubviewToFront:self.animationContainerView];
    
     
 }




#pragma mark - Trust Banner Animation

- (void)pp_startTrustBannerShimmer {
    if (!self.trustBannerView) return;

    // Respect accessibility
    if (UIAccessibilityIsReduceMotionEnabled()) return;

    if (!self.trustBannerShimmerLayer) {
        CAGradientLayer *g = [CAGradientLayer layer];
        g.frame = self.trustBannerView.bounds;
        g.startPoint = CGPointMake(0.0, 0.5);
        g.endPoint = CGPointMake(1.0, 0.5);

        // Gold shimmer (visible)
        UIColor *c0 = [UIColor colorWithRed:1.00 green:0.84 blue:0.00 alpha:0.00];
        UIColor *c1 = [UIColor colorWithRed:1.00 green:0.84 blue:0.00 alpha:0.38];
        UIColor *c2 = [UIColor colorWithRed:1.00 green:0.84 blue:0.00 alpha:0.00];

        g.colors = @[(id)c0.CGColor, (id)c1.CGColor, (id)c2.CGColor];
        g.locations = @[@0.0, @0.5, @1.0];
        g.cornerRadius = self.trustBannerView.layer.cornerRadius;
        g.masksToBounds = YES;

        [self.trustBannerView.layer insertSublayer:g atIndex:0];
        self.trustBannerShimmerLayer = g;
    }

    // Shimmer sweep
    [self.trustBannerShimmerLayer removeAnimationForKey:@"pp_trust_banner_shimmer"];

    CABasicAnimation *shimmer = [CABasicAnimation animationWithKeyPath:@"locations"];
    shimmer.fromValue = @[@(-0.9), @(-0.45), @(0.0)];
    shimmer.toValue   = @[@(1.0),  @(1.45),  @(1.9)];
    shimmer.duration = 3.45;
    shimmer.repeatCount = HUGE_VALF;
    shimmer.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    shimmer.beginTime = CACurrentMediaTime() + 0.5;

    [self.trustBannerShimmerLayer addAnimation:shimmer forKey:@"pp_trust_banner_shimmer"];
    
    [self.trustBannerView setBackgroundColor:[UIColor hx_colorWithHexStr:@"#FABB00" alpha:0.05]];
    
    [Styling addLiquidGlassBorderToView:self.trustBannerView cornerRadius:16 color:[UIColor colorWithHexString:@"#FABB00"]];
}

- (void)pp_stopTrustBannerShimmer {
    [self.trustBannerShimmerLayer removeAnimationForKey:@"pp_trust_banner_shimmer"];
}

 

#pragma mark - UI

- (void)buildUI {
    self.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.8];
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.userInteractionEnabled = YES;
     
    
    // --- Animation View ---
    self.animationView = [[LOTAnimationView alloc] init];
    self.animationView.loopAnimation = YES;
    self.animationView.animationSpeed = 0.6;
    self.animationView.contentMode = UIViewContentModeScaleAspectFit;

        [AppClasses fetchLottieJSONFromFirebasePath:[NSString stringWithFormat:@"LottieAnimations/shield.json"]
                                         completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    NSLog(@"❌ Failed to fetch Lottie JSON: %@", error.localizedDescription);
                    return;
                }
                LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
                if (composition) {
                    [self.animationView setSceneModel:composition];
                    [self.animationView play];
                }
            });
        }];
    _animationView.layer.cornerRadius = 22.0;
    
    _animationView.backgroundColor = [AppPrimaryClrDarker colorWithAlphaComponent:0.00];
 
    self.animationContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.animationContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.animationContainerView.userInteractionEnabled = NO;
    self.animationContainerView.backgroundColor = UIColor.clearColor;

    [self addSubview:self.animationContainerView];

    self.animationView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.animationContainerView addSubview:self.animationView];
    
        
     
    self.cardView =
    [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleLarge configType:PPButtonConfigrationGlass];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.layer.cornerRadius = 22.0;
     self.cardView.userInteractionEnabled = YES;
    
    UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
    cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
    cfg.background.cornerRadius = 16;
    self.cardView.configuration = cfg;
    // Card View
 
    [self addSubview:self.cardView];

    self.layer.cornerRadius = 22.0;
    self.clipsToBounds = NO;
    
    
    // Items Preview Collection
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 4;
    layout.sectionInset = UIEdgeInsetsMake(4, 4, 0, 4);
    layout.itemSize = CGSizeMake(64, 78);

    self.itemsPreviewCollection =
    [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.itemsPreviewCollection.translatesAutoresizingMaskIntoConstraints = NO;
    self.itemsPreviewCollection.backgroundColor = UIColor.clearColor;
    self.itemsPreviewCollection.showsHorizontalScrollIndicator = NO;
    self.itemsPreviewCollection.dataSource = self;
    self.itemsPreviewCollection.delegate = self;
    self.itemsPreviewCollection.hidden = NO;

    [self.itemsPreviewCollection registerClass:[UICollectionViewCell class]
                    forCellWithReuseIdentifier:@"CheckoutPreviewCell"];

    [self.cardView addSubview:self.itemsPreviewCollection];
    
    // Labels and Values
    UIFont *labelFont =  [GM MidFontWithSize:15];
    UIColor *labelColor = UIColor.secondaryLabelColor;
    UIColor *valueColor = [UIColor.labelColor colorWithAlphaComponent:0.95];
    
    self.itemsLabel = [[UILabel alloc] init];
    self.itemsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.itemsLabel.font = labelFont;
    self.itemsLabel.textColor = labelColor;
    self.itemsLabel.text = kLang(@"Selected Items" );
     
    self.itemsValueLabel = [[UILabel alloc] init];
    self.itemsValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.itemsValueLabel.font = [GM MidFontWithSize:15];
    self.itemsValueLabel.textColor = valueColor;

    
    self.shippingLabel = [[UILabel alloc] init];
    self.shippingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.shippingLabel.font = labelFont;
    self.shippingLabel.textColor = labelColor;
    self.shippingLabel.text = kLang(@"Shipping Fee");
    
    self.shippingValueLabel = [[UILabel alloc] init];
    self.shippingValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.shippingValueLabel.font = [GM MidFontWithSize:15];
    self.shippingValueLabel.textColor = valueColor;
    self.shippingValueLabel.textAlignment = NSTextAlignmentNatural;
     
    // Separator
    self.separator = [[UIView alloc] init];
    self.separator.translatesAutoresizingMaskIntoConstraints = NO;
    self.separator.backgroundColor = [UIColor separatorColor];
    
    // Subtotal
    self.subtotalAttributedLabel = [[UILabel alloc] init];
    self.subtotalAttributedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtotalAttributedLabel.numberOfLines = 0;
    self.subtotalAttributedLabel.textAlignment = GM.setAligment;
    self.subtotalAttributedLabel.semanticContentAttribute =GM.setSemantic;
    
    [self.subtotalAttributedLabel setContentHuggingPriority:UILayoutPriorityDefaultLow
                                                    forAxis:UILayoutConstraintAxisHorizontal];

    [self.subtotalAttributedLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                                 forAxis:UILayoutConstraintAxisHorizontal];

    [self.subtotalAttributedLabel setContentHuggingPriority:UILayoutPriorityRequired
                                                    forAxis:UILayoutConstraintAxisVertical];

    [self.subtotalAttributedLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                                 forAxis:UILayoutConstraintAxisVertical];
    
     

    self.shippingValueLabel.textAlignment = NSTextAlignmentNatural;
    self.shippingLabel.textAlignment = NSTextAlignmentNatural;

    self.subtotalAttributedLabel.textAlignment = NSTextAlignmentNatural;
    // Pricing Stack
    self.pricingStack = [[UIStackView alloc] init];
    self.pricingStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.pricingStack.axis = UILayoutConstraintAxisVertical;
    self.pricingStack.spacing = 12.0;
    [self.cardView addSubview:self.pricingStack];
    
    
    self.pricingStackBottomAnchor = [self.pricingStack.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-16];
   //shoppingCart
   
    // Checkout Button
    self.checkoutBTN = [UIButton buttonWithType:UIButtonTypeSystem];
    self.checkoutBTN.translatesAutoresizingMaskIntoConstraints = NO;
    self.checkoutBTN.layer.cornerRadius = 22.0;
    //self.checkoutBTN.clipsToBounds = YES;
    //[self.checkoutBTN setTitle:kLang(@"Checkout") forState:UIControlStateNormal];
    self.checkoutBTN.titleLabel.font = [GM boldFontWithSize:16];
    self.checkoutBTN.accessibilityLabel = NSLocalizedString(@"a11y_btn_checkout", @"Checkout");
    self.checkoutBTN.accessibilityHint  = NSLocalizedString(@"a11y_btn_checkout_hint", @"Double-tap to proceed to checkout");
    [self.checkoutBTN addTarget:self action:@selector(didTapCheckout) forControlEvents:UIControlEventTouchUpInside];

    // Glass / frosted configuration for iOS 16+, fallback for older
    if (@available(iOS 16.0, *)) {
        UIButtonConfiguration *config;
        if (@available(iOS 26.0, *)) {
            config = [UIButtonConfiguration glassButtonConfiguration];
        } else {
            config = [UIButtonConfiguration filledButtonConfiguration];
        }
        // Attributed title & shopping cart image
        NSString *title = kLang(@"Checkout");
        NSMutableAttributedString *attrTitle =
        [[NSMutableAttributedString alloc] initWithString:title
                                               attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:16],
            NSForegroundColorAttributeName: AppForgroundColr
        }];
        config.attributedTitle = attrTitle;
        // Shopping cart image (SF Symbol or asset named "shoppingCart")
        UIImage *cartImage =
        [UIImage systemImageNamed:PPIsRL ? @"arrow.left" : @"arrow.right"]; // fallback-safe
        if (cartImage) {
    
            config.image = cartImage;
            //config.image = [UIImage pp_symbolNamed:@"shopping" pointSize:18 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleLarge palette:@[AppForgroundColr,AppForgroundColr] makeTemplate:YES];
            config.imagePlacement = NSDirectionalRectEdgeTrailing;
            config.imagePadding =0.0;
            config.preferredSymbolConfigurationForImage =
            [UIImageSymbolConfiguration configurationWithPointSize:16
                                                             weight:UIImageSymbolWeightSemibold];
        }
        // Glass / frosted effect
        config.background.cornerRadius = 22.0;
        config.baseForegroundColor = AppForgroundColr;
        
        config.background.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
        config.baseBackgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];

        
        // Subtle stroke for definition
        
        // Padding
        config.contentInsets = NSDirectionalEdgeInsetsMake(6, 16, 6, 1);
        
        // Image
        config.image = [UIImage pp_symbolNamed:PPIsRL ? @"arrow.left" : @"arrow.right" pointSize:18 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleLarge palette:@[AppForgroundColr,AppForgroundColr] makeTemplate:NO];
        self.checkoutButtonImageForIdle = config.image;
        config.imagePlacement = NSDirectionalRectEdgeTrailing;
        config.imagePadding = 6.0;

        // Symbol size & weight
        config.preferredSymbolConfigurationForImage =
        [UIImageSymbolConfiguration configurationWithPointSize:16
                                                         weight:UIImageSymbolWeightSemibold];

        // ✅ Tint BOTH text & icon
        config.baseForegroundColor = AppForgroundColr;

    // Keep subtotal aligned to the trailing edge in both RTL/LTR
        self.subtotalAttributedLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.subtotalAttributedLabel.numberOfLines = 1;
        
        self.checkoutBTN.configuration = config;
        self.checkoutBTN.tintColor = AppForgroundColr;
        if (@available(iOS 18.0, *)) {
            [self.checkoutBTN.imageView addSymbolEffect: [[NSSymbolWiggleEffect effect] effectWithByLayer] options: [NSSymbolEffectOptions optionsWithRepeatBehavior:[NSSymbolEffectOptionsRepeatBehavior behaviorPeriodicWithDelay:2.0]]];
        } else {
            // Fallback on earlier versions
        }
    }
    else {
        // Fallback for older iOS
        self.checkoutBTN.backgroundColor =
            [AppForgroundColr colorWithAlphaComponent:0.95];
        [self.checkoutBTN setTitleColor:AppPrimaryClr
                               forState:UIControlStateNormal];
    }
    [self.checkoutBTN setContentHuggingPriority:UILayoutPriorityRequired
                                        forAxis:UILayoutConstraintAxisHorizontal];

    [self.checkoutBTN setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                     forAxis:UILayoutConstraintAxisHorizontal];

    self.checkoutFallbackIndicator =
    [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.checkoutFallbackIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.checkoutFallbackIndicator.hidesWhenStopped = YES;
    self.checkoutFallbackIndicator.color = AppForgroundColr;
    [self.checkoutBTN addSubview:self.checkoutFallbackIndicator];
    [NSLayoutConstraint activateConstraints:@[
        [self.checkoutFallbackIndicator.centerXAnchor constraintEqualToAnchor:self.checkoutBTN.centerXAnchor],
        [self.checkoutFallbackIndicator.centerYAnchor constraintEqualToAnchor:self.checkoutBTN.centerYAnchor]
    ]];
    // Rows: items, shipping, separator, subtotal
    
    self.itemsRow =
    [self horizontalRowWithLabel:self.itemsLabel value:self.itemsValueLabel];

    self.shippingRow =
    [self horizontalRowWithLabel:self.shippingLabel value:self.shippingValueLabel];
    
    
    
    // Trust banner (between table and summary)
    self.trustBannerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.trustBannerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.trustBannerView.layer.cornerRadius =16.0;
    self.trustBannerView.layer.masksToBounds = YES;
     self.trustBannerView.layer.borderWidth = 1.0;
    self.trustBannerView.layer.borderColor = [[UIColor colorWithRed:1.00 green:0.84 blue:0.00 alpha:0.22] CGColor];
    [self.trustBannerView setBackgroundColor:[UIColor hx_colorWithHexStr:@"#FABB00" alpha:0.05]];
    self.trustBannerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.trustBannerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.trustBannerLabel.numberOfLines = 1;
    self.trustBannerLabel.font = [GM MidFontWithSize:13];
    self.trustBannerLabel.textColor = UIColor.secondaryLabelColor;
    self.trustBannerLabel.textAlignment = Language.alignmentForCurrentLanguage;;
    self.trustBannerLabel.text =  kLang(@"Securecheckout");
 //   "Securecheckout" ="🔒 Secure checkout — your data is protected";
    [self.trustBannerView addSubview:self.trustBannerLabel];

    // Banner height
    [self.trustBannerView.heightAnchor constraintEqualToConstant:34.0].active = YES;

    // Label padding inside banner
    [NSLayoutConstraint activateConstraints:@[
        [self.trustBannerLabel.leadingAnchor constraintEqualToAnchor:self.trustBannerView.leadingAnchor constant:12.0],
        [self.trustBannerLabel.trailingAnchor constraintEqualToAnchor:self.trustBannerView.trailingAnchor constant:-12.0],
        [self.trustBannerLabel.topAnchor constraintEqualToAnchor:self.trustBannerView.topAnchor constant:0.0],
        [self.trustBannerLabel.bottomAnchor constraintEqualToAnchor:self.trustBannerView.bottomAnchor constant:0.0]
    ]];
    
    UIView *subtotalSpacer = [[UIView alloc] initWithFrame:CGRectZero];
    subtotalSpacer.translatesAutoresizingMaskIntoConstraints = NO;

    // Subtotal row: button on the left, subtotal on the right
    UIStackView *subtotalRow =
    [[UIStackView alloc] initWithArrangedSubviews:@[ self.subtotalAttributedLabel, subtotalSpacer,self.checkoutBTN]];
    subtotalRow.axis = UILayoutConstraintAxisHorizontal;
    subtotalRow.alignment = UIStackViewAlignmentCenter;
    subtotalRow.distribution = UIStackViewDistributionFill;
    subtotalRow.spacing = 12.0;

    // Let spacer expand
    [subtotalSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow
                                     forAxis:UILayoutConstraintAxisHorizontal];
    [subtotalSpacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                   forAxis:UILayoutConstraintAxisHorizontal];

    // Keep button fixed; let subtotal take remaining space
    [self.checkoutBTN setContentHuggingPriority:UILayoutPriorityRequired
                                        forAxis:UILayoutConstraintAxisHorizontal];
    [self.checkoutBTN setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                     forAxis:UILayoutConstraintAxisHorizontal];

    [self.subtotalAttributedLabel setContentHuggingPriority:UILayoutPriorityDefaultLow
                                                    forAxis:UILayoutConstraintAxisHorizontal];
    [self.subtotalAttributedLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                                 forAxis:UILayoutConstraintAxisHorizontal];
    
    
    self.itemsPreviewCollection.alpha = 0.0;
    self.itemsPreviewCollection.hidden = YES;
    [self.itemsPreviewCollection.heightAnchor constraintEqualToConstant:74].active = YES;
    
    [self.pricingStack addArrangedSubview:self.itemsRow];
    [self.pricingStack addArrangedSubview:self.shippingRow];
    [self.pricingStack addArrangedSubview:self.itemsPreviewCollection];
    [self.pricingStack addArrangedSubview:self.trustBannerView];
    [self.pricingStack addArrangedSubview:self.separator];
    
    [self.pricingStack addArrangedSubview:subtotalRow];
   
    
    
    if(Language.isRTL)
    {
        self.itemsLabel.textAlignment = NSTextAlignmentRight;
        self.itemsValueLabel.textAlignment = NSTextAlignmentLeft;
        
        self.shippingLabel.textAlignment = NSTextAlignmentRight;
        self.shippingValueLabel.textAlignment = NSTextAlignmentLeft;
        
    }
    else
    {
        self.itemsLabel.textAlignment = NSTextAlignmentLeft;
        self.itemsValueLabel.textAlignment = NSTextAlignmentRight;
        
        self.shippingLabel.textAlignment = NSTextAlignmentLeft;
        self.shippingValueLabel.textAlignment = NSTextAlignmentRight;
    }
   // self.cardView.layer.borderWidth = 0.5;
   // self.cardView.layer.borderColor =
   // [[UIColor secondaryLabelColor] colorWithAlphaComponent:0.15].CGColor;
    
    
    
    
}
//kLang(@"Checkout")
-(void)setCheckoutBTNTitle:(NSString *)title image:(UIImage *)image
{
    self.checkoutButtonImageForIdle = image;

    if (@available(iOS 16.0, *)) {
        UIButtonConfiguration *config = self.checkoutBTN.configuration;
        
         NSMutableAttributedString *attrTitle =
        [[NSMutableAttributedString alloc] initWithString:title
                                               attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:16],
            NSForegroundColorAttributeName: AppForgroundColr
        }];
        config.attributedTitle = attrTitle;
        // Shopping cart image (SF Symbol or asset named "shoppingCart")
       
        if (image) {
    
            config.image = image;
            //config.image = [UIImage pp_symbolNamed:@"shopping" pointSize:18 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleLarge palette:@[AppForgroundColr,AppForgroundColr] makeTemplate:YES];
            config.imagePlacement = NSDirectionalRectEdgeTrailing;
            config.imagePadding =0.0;
            config.preferredSymbolConfigurationForImage =
            [UIImageSymbolConfiguration configurationWithPointSize:16
                                                             weight:UIImageSymbolWeightSemibold];
        }
        // Glass / frosted effect
        config.background.cornerRadius = 22.0;
        config.baseForegroundColor = AppForgroundColr;
        
        config.background.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
        config.baseBackgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
 
        config.contentInsets = NSDirectionalEdgeInsetsMake(6, 12, 6, 12);
        
        // Image
        config.image = self.isCheckoutLoading ? nil : image;
        config.imagePlacement = NSDirectionalRectEdgeTrailing;
        config.imagePadding = (self.isCheckoutLoading || image == nil) ? 0.0 : 6.0;

        // Symbol size & weight
        config.preferredSymbolConfigurationForImage =
        [UIImageSymbolConfiguration configurationWithPointSize:16
                                                         weight:UIImageSymbolWeightSemibold];

        // ✅ Tint BOTH text & icon
        config.baseForegroundColor = AppForgroundColr;

    // Keep subtotal aligned to the trailing edge in both RTL/LTR
        self.subtotalAttributedLabel.textAlignment = NSTextAlignmentCenter;
    self.subtotalAttributedLabel.numberOfLines = 2;
        
        if (@available(iOS 15.0, *)) {
            config.showsActivityIndicator = self.isCheckoutLoading;
        }
        self.checkoutBTN.configuration = config;
        self.checkoutBTN.tintColor = AppForgroundColr;
        if (@available(iOS 18.0, *)) {
            [self.checkoutBTN.imageView addSymbolEffect: [[NSSymbolWiggleEffect effect] effectWithByLayer] options: [NSSymbolEffectOptions optionsWithRepeatBehavior:[NSSymbolEffectOptionsRepeatBehavior behaviorPeriodicWithDelay:2.0]]];
        } else {
            // Fallback on earlier versions
        }
    } else {
        [self.checkoutBTN setTitle:title forState:UIControlStateNormal];
        [self.checkoutBTN setImage:image forState:UIControlStateNormal];
    }
}

- (void)setCheckoutLoading:(BOOL)loading
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setCheckoutLoading:loading];
        });
        return;
    }

    if (_checkoutLoading == loading) return;
    _checkoutLoading = loading;

    self.checkoutBTN.enabled = !loading;
    self.checkoutBTN.userInteractionEnabled = !loading;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = self.checkoutBTN.configuration;
        if (!config) {
            config = [UIButtonConfiguration filledButtonConfiguration];
        }
        config.showsActivityIndicator = loading;
        config.image = loading ? nil : self.checkoutButtonImageForIdle;
        config.imagePadding = (loading || self.checkoutButtonImageForIdle == nil) ? 0.0 : 6.0;
        self.checkoutBTN.configuration = config;
    } else {
        if (loading) {
            [self.checkoutFallbackIndicator startAnimating];
        } else {
            [self.checkoutFallbackIndicator stopAnimating];
        }
    }
}
- (UIStackView *)horizontalRowWithLabel:(UILabel *)label value:(UILabel *)value {
    return [self horizontalRowWithLabel:label value:value button:nil];
}

- (UIStackView *)horizontalRowWithLabel:(UILabel *)label value:(UILabel *)value button:(nullable UIButton *)button{
    UIStackView *row;
    if(button)
       row = [[UIStackView alloc] initWithArrangedSubviews:@[label, value,button]];
    else
        row = [[UIStackView alloc] initWithArrangedSubviews:@[label, value]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 8.0;
    row.alignment = UIStackViewAlignmentLeading;
    row.distribution = UIStackViewDistributionFillEqually;

    [label setContentHuggingPriority:UILayoutPriorityDefaultHigh
                             forAxis:UILayoutConstraintAxisHorizontal];
    [label setContentCompressionResistancePriority:UILayoutPriorityRequired
                                           forAxis:UILayoutConstraintAxisHorizontal];

    [value setContentHuggingPriority:UILayoutPriorityDefaultLow
                              forAxis:UILayoutConstraintAxisHorizontal];
    [value setContentCompressionResistancePriority:UILayoutPriorityRequired
                                            forAxis:UILayoutConstraintAxisHorizontal];

    return row;
}

#pragma mark - Layout

- (void)buildLayout {
    CGFloat padding = 16.0;
    // Card background image view constraints (same size as cardView)
  
    [NSLayoutConstraint activateConstraints:@[
        [self.checkoutBTN.heightAnchor constraintEqualToConstant:48],
        [self.cardView.topAnchor constraintEqualToAnchor:self.topAnchor constant:0],

        [self.cardView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-0],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:-1],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:1],
 
        [self.pricingStack.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:12],
        [self.pricingStack.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:padding],
        [self.pricingStack.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-padding],

        // Separator height fixed
        [self.separator.heightAnchor constraintEqualToConstant:1.2],
        self.pricingStackBottomAnchor,
        // Subtotal row bottom spacing to card bottom
     ]];
    
    [self.itemsPreviewCollection.heightAnchor constraintEqualToConstant:74].active = YES;

   
    
    
    self.animationView.translatesAutoresizingMaskIntoConstraints = NO;
    // Container — same size & position as old animationView
    [self.animationContainerView.heightAnchor constraintEqualToConstant:40].active = YES;
    [self.animationContainerView.widthAnchor constraintEqualToConstant:40].active = YES;
    [self.animationContainerView.centerYAnchor constraintEqualToAnchor:self.trustBannerView.centerYAnchor].active = YES;
    [self.animationContainerView.trailingAnchor constraintEqualToAnchor:self.trustBannerView.trailingAnchor  constant:-2.0].active = YES;

    // AnimationView fills container
    [NSLayoutConstraint activateConstraints:@[
        [self.animationView.topAnchor constraintEqualToAnchor:self.animationContainerView.topAnchor],
        [self.animationView.bottomAnchor constraintEqualToAnchor:self.animationContainerView.bottomAnchor],
        [self.animationView.leadingAnchor constraintEqualToAnchor:self.animationContainerView.leadingAnchor],
        [self.animationView.trailingAnchor constraintEqualToAnchor:self.animationContainerView.trailingAnchor],
    ]];
    [self setNeedsLayout];
    [self layoutIfNeeded];
  
}

#pragma mark - API

// Subtotal label now supports showTitle YES/NO, with vertical centering and alignment options
- (void)updateTotalsWithItems:(CGFloat)itemsTotal
                     shipping:(CGFloat)shippingFee
                    showTitle:(BOOL)showTitle
{
   
    
    _itemsTotal = itemsTotal;
    _shippingFee = shippingFee;
    _subtotal = itemsTotal + shippingFee;

    self.itemsValueLabel.text = [PPChatsFunc formattedCurrency:itemsTotal];
    self.shippingValueLabel.text = [PPChatsFunc formattedCurrency:shippingFee];

    NSString *title = kLang(@"Subtotal");
    NSString *price = [PPChatsFunc formattedCurrency:_subtotal];

    // Split integer / fraction (locale-safe)
    NSString *decimalSeparator = PPCheckoutDecimalSeparatorFromFormattedPrice(price);

    NSString *integerPart = price;
    NSString *fractionPart = nil;

    NSRange sepRange =
    [price rangeOfString:decimalSeparator options:NSBackwardsSearch];

    if (sepRange.location != NSNotFound) {
        integerPart = [price substringToIndex:sepRange.location];
        fractionPart = [price substringFromIndex:sepRange.location];
    }

    NSString *fullText = nil;
    showTitle=YES;
    if (showTitle) {
        fullText = fractionPart
        ? [NSString stringWithFormat:@"%@\n%@%@", title, integerPart, fractionPart]
        : [NSString stringWithFormat:@"%@\n%@", title, integerPart];
    } else {
        fullText = fractionPart
        ? [NSString stringWithFormat:@"%@%@", integerPart, fractionPart]
        : integerPart;
    }

    NSMutableAttributedString *attr =
    [[NSMutableAttributedString alloc] initWithString:fullText];

    // Title styling (only if shown)
   // if (showTitle) {
        NSRange titleRange = [fullText rangeOfString:title];
        if (titleRange.location != NSNotFound) {
            [attr addAttributes:@{
                NSFontAttributeName: [GM MidFontWithSize:11],
                NSForegroundColorAttributeName: UIColor.secondaryLabelColor
            } range:titleRange];
        }
    //}

    // Integer (main amount)
    NSRange integerRange =
    [fullText rangeOfString:integerPart options:NSBackwardsSearch];

    [attr addAttributes:@{
        NSFontAttributeName: [GM boldFontWithSize:PPIsRL ? 32 : 26],
        NSForegroundColorAttributeName: AppPrimaryClr
    } range:integerRange];

    // Fraction (.00) — SMALL + TOP-ALIGNED
    if (fractionPart) {
        NSRange fractionRange =
        [fullText rangeOfString:fractionPart options:NSBackwardsSearch];

        if (fractionRange.location != NSNotFound) {
            [attr addAttributes:@{
                NSFontAttributeName: [GM boldFontWithSize:12],
                NSForegroundColorAttributeName: AppSecondaryTextClr,
                NSBaselineOffsetAttributeName: @(8)
            } range:fractionRange];
        }
    }

    // Paragraph style
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineSpacing = showTitle ? 0.0 : 0.0;
    style.alignment = GM.setAligment;

    [attr addAttribute:NSParagraphStyleAttributeName
                 value:style
                 range:NSMakeRange(0, attr.length)];

    self.subtotalAttributedLabel.attributedText = attr;
}

#pragma mark - Action

- (void)didTapCheckout {
    NSLog(@"🛒 Checkout tapped");
    
    if (self.onTapCheckOut) {
        self.onTapCheckOut();
    }
    
    
}

 
- (void)setShowsItemsPreview:(BOOL)showsItemsPreview
{
    if (_showsItemsPreview == showsItemsPreview) return;
    _showsItemsPreview = showsItemsPreview;

    // Prepare for show
    if (showsItemsPreview) {
        self.itemsPreviewCollection.hidden = NO;
        self.itemsPreviewCollection.alpha = 0.0;

        // IMPORTANT: keep rows visible during animation
        self.itemsRow.hidden = NO;
        self.shippingRow.hidden = NO;
    }
    
    //self.shippingRow.hidden = NO;
    //self.itemsPreviewCollection.alpha = 0.0;
    
    self.pricingStackBottomAnchor.constant = showsItemsPreview ? 0 : 0;
    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.itemsPreviewCollection.alpha = showsItemsPreview ? 1.0 : 0.0;
        self.itemsRow.alpha = showsItemsPreview ? 0.0 : 1.0;
        self.shippingRow.alpha = showsItemsPreview ? 0.0 : 1.0;
    } completion:^(BOOL finished) {

        [UIView animateWithDuration:0.25 animations:^{
            // NOW change visibility (after animation)
            self.itemsRow.hidden = showsItemsPreview;
            self.shippingRow.hidden = showsItemsPreview;

            if (!showsItemsPreview) {
                self.itemsPreviewCollection.hidden = YES;
            }
        }];
    }];
}

- (void)updatePreviewItems:(NSArray<CartItem *> *)items
{
    self.previewItems = items ?: @[];
    self.itemsPreviewCollection.hidden =
        !self.showsItemsPreview || self.previewItems.count == 0;
    [self.itemsPreviewCollection reloadData];
     
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return self.previewItems.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                          cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell =
    [collectionView dequeueReusableCellWithReuseIdentifier:@"CheckoutPreviewCell"
                                              forIndexPath:indexPath];

    CartItem *item = self.previewItems[indexPath.item];

    UIImageView *img = [cell.contentView viewWithTag:11];
    UILabel *price = [cell.contentView viewWithTag:12];

    if (!img) {
        img = [[UIImageView alloc] init];
        img.tag = 11;
        img.translatesAutoresizingMaskIntoConstraints = NO;
        img.contentMode = UIViewContentModeScaleAspectFill;
        img.clipsToBounds = YES;
        img.layer.cornerRadius = 6;
        [cell.contentView addSubview:img];

        price = [[UILabel alloc] init];
        price.tag = 12;
        price.translatesAutoresizingMaskIntoConstraints = NO;
        price.font = [GM MidFontWithSize:11];
        price.textAlignment = NSTextAlignmentCenter;
        price.textColor = UIColor.secondaryLabelColor;
        [cell.contentView addSubview:price];

        UIButton *removeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        removeBtn.tag = 13;
        removeBtn.translatesAutoresizingMaskIntoConstraints = NO;
        removeBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
        removeBtn.layer.cornerRadius = 9;
        removeBtn.clipsToBounds = YES;

        [removeBtn setImage:[UIImage systemImageNamed:@"xmark"]
                   forState:UIControlStateNormal];
        removeBtn.tintColor = UIColor.whiteColor;
        removeBtn.contentEdgeInsets = UIEdgeInsetsMake(2, 2, 2, 2);

        [removeBtn addTarget:self
                      action:@selector(didTapRemovePreviewItem:)
            forControlEvents:UIControlEventTouchUpInside];

        [cell.contentView addSubview:removeBtn];

        [NSLayoutConstraint activateConstraints:@[
            [img.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
            [img.centerXAnchor constraintEqualToAnchor:cell.contentView.centerXAnchor],
            [img.widthAnchor constraintEqualToConstant:48],
            [img.heightAnchor constraintEqualToConstant:48],

            [price.topAnchor constraintEqualToAnchor:img.bottomAnchor constant:4],
            [price.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
            [price.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],

            [removeBtn.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:2],
            [removeBtn.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-2],
            [removeBtn.widthAnchor constraintEqualToConstant:18],
            [removeBtn.heightAnchor constraintEqualToConstant:18],
        ]];
    }

    // Tag the remove button with the current index (for every reuse)
    UIButton *removeBtn = [cell.contentView viewWithTag:13];
    removeBtn.accessibilityIdentifier =
        [NSString stringWithFormat:@"%ld", (long)indexPath.item];

    NSString *url = item.imageURL;
    if (url.length > 0) {
        [img sd_setImageWithURL:[NSURL URLWithString:url]];
    }

    price.text = [NSString stringWithFormat:@"%.2f",
                  item.price];

    return cell;
}


#pragma mark - Helpers

// Helper: Create a CALayer from UIImage with frame and corner radius
- (CALayer *)layerFromImage:(UIImage *)image
                      frame:(CGRect)frame
                cornerRadius:(CGFloat)cornerRadius
{
    if (!image) return nil;

    CALayer *layer = [CALayer layer];
    layer.frame = frame;
    layer.contents = (__bridge id)image.CGImage;
    layer.contentsGravity = kCAGravityResizeAspectFill;
    layer.masksToBounds = YES;
    layer.cornerRadius = cornerRadius;
    layer.contentsScale = UIScreen.mainScreen.scale;

    return layer;
}

#pragma mark - Public API (optional)

// Optional: Setter for card background image
- (void)setCardBackgroundImage:(UIImage *)image
{
    
}

#pragma mark - Remove Preview Item Action

- (void)didTapRemovePreviewItem:(UIButton *)sender
{
    NSIndexPath *indexPath = nil;
    UIView *view = sender;
    while (view && ![view isKindOfClass:[UICollectionViewCell class]]) {
        view = view.superview;
    }
    if ([view isKindOfClass:[UICollectionViewCell class]]) {
        indexPath = [self.itemsPreviewCollection indexPathForCell:(UICollectionViewCell *)view];
    }
    if (!indexPath) {
        NSInteger index = sender.accessibilityIdentifier.integerValue;
        if (index >= 0 && index < self.previewItems.count) {
            indexPath = [NSIndexPath indexPathForItem:index inSection:0];
        }
    }
    if (!indexPath || indexPath.item < 0 || indexPath.item >= self.previewItems.count) return;

    CartItem *item = self.previewItems[indexPath.item];
    if (!item) return;

    [[CartManager sharedManager] removeItem:item];

    if (self.onRemovePreviewItem) {
        self.onRemovePreviewItem(item);
    }
}


- (void)applyBubbleMask:(UIView *)bubble
            
{
    // ⚠️ Must layout first
    [bubble layoutIfNeeded];

    CGRect b = bubble.bounds;
    if (CGRectIsEmpty(b)) return;

    // === Radius system ===
    CGFloat R = 42;   // main bubble radius
    CGFloat S = 12.0;    // stacked / connected radius

    CGFloat tl = R, tr = R, bl = R, br = R;

    tl = S;
    tr = S;
    bl = R;
    br = R;
    
    // Build bubble path FIRST
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = b.size.width;
    CGFloat h = b.size.height;

    [path moveToPoint:CGPointMake(0, tl)];
    [path addQuadCurveToPoint:CGPointMake(tl, 0) controlPoint:CGPointZero];

    [path addLineToPoint:CGPointMake(w - tr, 0)];
    [path addQuadCurveToPoint:CGPointMake(w, tr)
                 controlPoint:CGPointMake(w, 0)];

    [path addLineToPoint:CGPointMake(w, h - br)];
    [path addQuadCurveToPoint:CGPointMake(w - br, h)
                 controlPoint:CGPointMake(w, h)];

    [path addLineToPoint:CGPointMake(bl, h)];
    [path addQuadCurveToPoint:CGPointMake(0, h - bl)
                 controlPoint:CGPointMake(0, h)];

    [path closePath];
    
    
    CAShapeLayer *mask = (CAShapeLayer *)bubble.layer.mask;
    if (![mask isKindOfClass:CAShapeLayer.class]) {
        mask = [CAShapeLayer layer];
        bubble.layer.mask = mask;
    }

    CGPathRef newPath = path.CGPath;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    mask.frame = b;
    [CATransaction commit];

    if (mask.path) {
        CABasicAnimation *anim =
            [CABasicAnimation animationWithKeyPath:@"path"];
        anim.fromValue = (__bridge id)mask.path;
        anim.toValue   = (__bridge id)newPath;
        anim.duration  = 0.28;
        anim.timingFunction =
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [mask addAnimation:anim forKey:@"pp_liquid_merge"];
    }

    mask.path = newPath;

    // === Optional glowing / liquid border ===
    [PPChatsFunc applyGlowIfNeededToBubble:bubble
                               path:path
                                  showGlow:YES
                         isIncoming:YES];
}
@end
