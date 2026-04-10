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


@interface BBCheckoutSummaryView () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UIView *animationContainerView;
@property (nonatomic, copy) void (^onRemovePreviewItem)(CartItem *item);
@property (nonatomic, strong) LOTAnimationView *animationView;
 
@property (nonatomic, strong) UIButton *cardView;
@property (nonatomic, strong) CAGradientLayer *cardGradientLayer;
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
@property (nonatomic, strong) NSLayoutConstraint *itemsPreviewHeightConstraint;

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

static CGFloat PPCheckoutCardCornerRadius(void) {
    return 28.0;
}

static CGFloat PPCheckoutButtonCornerRadius(void) {
    return 22.0;
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
    self.itemsPreviewCollection.transform = shouldShowPreview ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0.0, 10.0);
    self.itemsRow.hidden = shouldShowPreview;
    self.shippingRow.hidden = shouldShowPreview;
    self.itemsRow.alpha = shouldShowPreview ? 0.0 : 1.0;
    self.shippingRow.alpha = shouldShowPreview ? 0.0 : 1.0;
    self.itemsRow.transform = CGAffineTransformIdentity;
    self.shippingRow.transform = CGAffineTransformIdentity;

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

    [self.cardView bringSubviewToFront:self.pricingStack];
    [self.cardView bringSubviewToFront:self.checkoutBTN];

    self.cardGradientLayer.frame = self.cardView.bounds;
    self.cardGradientLayer.cornerRadius = self.cardView.layer.cornerRadius;
    self.cardView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.cardView.bounds
                                  cornerRadius:self.cardView.layer.cornerRadius].CGPath;
    self.checkoutBTN.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.checkoutBTN.bounds
                                  cornerRadius:self.checkoutBTN.layer.cornerRadius].CGPath;

    if (self.trustBannerShimmerLayer) {
        self.trustBannerShimmerLayer.frame = self.trustBannerView.bounds;
    }

    if (!self.didRunCardEntranceAnimation &&
        self.cardView.bounds.size.height > 0) {

        self.didRunCardEntranceAnimation = YES;

        self.cardView.alpha = 0.0;
        self.cardView.transform =
            CGAffineTransformConcat(
                CGAffineTransformMakeTranslation(0, 22),
                CGAffineTransformMakeScale(0.985, 0.985)
            );

        [UIView animateWithDuration:0.5
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

- (UIImage *)pp_defaultCheckoutImage
{
    return [UIImage pp_symbolNamed:PPIsRL ? @"arrow.left" : @"arrow.right"
                         pointSize:18
                            weight:UIImageSymbolWeightSemibold
                             scale:UIImageSymbolScaleLarge
                           palette:@[AppForgroundColr, AppForgroundColr]
                      makeTemplate:NO];
}

- (void)pp_applyCheckoutButtonStyleWithTitle:(NSString *)title image:(UIImage *)image
{
    UIImage *resolvedImage = image ?: [self pp_defaultCheckoutImage];
    self.checkoutButtonImageForIdle = resolvedImage;

    self.checkoutBTN.layer.cornerRadius = PPCheckoutButtonCornerRadius();
    self.checkoutBTN.layer.masksToBounds = NO;
    self.checkoutBTN.layer.shadowColor = (AppPrimaryClr ?: UIColor.blackColor).CGColor;
    self.checkoutBTN.layer.shadowOpacity = 0.18f;
    self.checkoutBTN.layer.shadowRadius = 16.0f;
    self.checkoutBTN.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    if (@available(iOS 13.0, *)) {
        self.checkoutBTN.layer.cornerCurve = kCACornerCurveContinuous;
    }

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = self.checkoutBTN.configuration ?: [UIButtonConfiguration filledButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        config.background.cornerRadius = PPCheckoutButtonCornerRadius();
        config.background.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
        config.baseBackgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
        config.baseForegroundColor = AppForgroundColr;
        config.image = self.isCheckoutLoading ? nil : resolvedImage;
        config.imagePlacement = NSDirectionalRectEdgeTrailing;
        config.imagePadding = (self.isCheckoutLoading || resolvedImage == nil) ? 0.0 : 8.0;
        config.contentInsets = NSDirectionalEdgeInsetsMake(14, 18, 14, 18);
        config.preferredSymbolConfigurationForImage =
            [UIImageSymbolConfiguration configurationWithPointSize:16
                                                            weight:UIImageSymbolWeightSemibold];

        NSMutableAttributedString *attrTitle =
            [[NSMutableAttributedString alloc] initWithString:title ?: kLang(@"Checkout")
                                                   attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:17],
            NSForegroundColorAttributeName: AppForgroundColr
        }];
        config.attributedTitle = attrTitle;

        if (@available(iOS 15.0, *)) {
            config.showsActivityIndicator = self.isCheckoutLoading;
        }

        self.checkoutBTN.configuration = config;
        self.checkoutBTN.tintColor = AppForgroundColr;
    } else {
        self.checkoutBTN.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
        [self.checkoutBTN setTitle:title ?: kLang(@"Checkout") forState:UIControlStateNormal];
        [self.checkoutBTN setTitleColor:AppForgroundColr forState:UIControlStateNormal];
        [self.checkoutBTN setImage:self.isCheckoutLoading ? nil : resolvedImage forState:UIControlStateNormal];
        self.checkoutBTN.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 8);
        self.checkoutBTN.contentEdgeInsets = UIEdgeInsetsMake(14, 18, 14, 18);
    }
}

- (void)pp_styleInfoRow:(UIStackView *)row
{
    row.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.035];
    row.layer.cornerRadius = 18.0;
    row.layer.borderWidth = 1.0;
    row.layer.borderColor = [UIColor.labelColor colorWithAlphaComponent:0.06].CGColor;
    if (@available(iOS 13.0, *)) {
        row.layer.cornerCurve = kCACornerCurveContinuous;
    }
}


#pragma mark - UI

- (void)buildUI {
    self.backgroundColor = UIColor.clearColor;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.userInteractionEnabled = YES;
    self.semanticContentAttribute = GM.setSemantic;
     
    
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
    _animationView.layer.cornerRadius = 18.0;
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
    self.cardView.layer.cornerRadius = PPCheckoutCardCornerRadius();
    self.cardView.userInteractionEnabled = YES;
    self.cardView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.92];
    self.cardView.layer.masksToBounds = NO;
    self.cardView.layer.borderWidth = 1.0;
    self.cardView.layer.borderColor = [UIColor.labelColor colorWithAlphaComponent:0.08].CGColor;
    self.cardView.layer.shadowColor = (AppShadowClr ?: UIColor.blackColor).CGColor;
    self.cardView.layer.shadowOpacity = 0.14f;
    self.cardView.layer.shadowRadius = 24.0f;
    self.cardView.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    if (@available(iOS 13.0, *)) {
        self.cardView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
    cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
    cfg.background.cornerRadius = PPCheckoutCardCornerRadius();
    cfg.background.backgroundColor = UIColor.clearColor;
    cfg.baseBackgroundColor = UIColor.clearColor;
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(0, 0, 0, 0);
    self.cardView.configuration = cfg;
 
    [self addSubview:self.cardView];

    self.cardGradientLayer = [CAGradientLayer layer];
    self.cardGradientLayer.colors = @[
        (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:0.22].CGColor,
        (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:0.06].CGColor,
        (__bridge id)[UIColor.clearColor CGColor]
    ];
    self.cardGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.cardGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.cardGradientLayer.locations = @[@0.0, @0.42, @1.0];
    [self.cardView.layer insertSublayer:self.cardGradientLayer atIndex:0];

    self.layer.cornerRadius = PPCheckoutCardCornerRadius();
    self.clipsToBounds = NO;
    
    
    // Items Preview Collection
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 10.0;
    layout.sectionInset = UIEdgeInsetsMake(2, 0, 0, 0);
    layout.itemSize = CGSizeMake(82, 98);

    self.itemsPreviewCollection =
    [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.itemsPreviewCollection.translatesAutoresizingMaskIntoConstraints = NO;
    self.itemsPreviewCollection.backgroundColor = UIColor.clearColor;
    self.itemsPreviewCollection.showsHorizontalScrollIndicator = NO;
    self.itemsPreviewCollection.dataSource = self;
    self.itemsPreviewCollection.delegate = self;
    self.itemsPreviewCollection.hidden = NO;
    self.itemsPreviewCollection.clipsToBounds = NO;
    self.itemsPreviewCollection.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);

    [self.itemsPreviewCollection registerClass:[UICollectionViewCell class]
                    forCellWithReuseIdentifier:@"CheckoutPreviewCell"];

    [self.cardView addSubview:self.itemsPreviewCollection];
    
    // Labels and Values
    UIFont *labelFont =  [GM MidFontWithSize:13];
    UIColor *labelColor = [UIColor.labelColor colorWithAlphaComponent:0.58];
    UIColor *valueColor = [UIColor.labelColor colorWithAlphaComponent:0.92];
    
    self.itemsLabel = [[UILabel alloc] init];
    self.itemsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.itemsLabel.font = labelFont;
    self.itemsLabel.textColor = labelColor;
    self.itemsLabel.text = kLang(@"Selected Items" );
     
    self.itemsValueLabel = [[UILabel alloc] init];
    self.itemsValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.itemsValueLabel.font = [GM boldFontWithSize:14];
    self.itemsValueLabel.textColor = valueColor;
    self.itemsValueLabel.adjustsFontSizeToFitWidth = YES;
    self.itemsValueLabel.minimumScaleFactor = 0.72;

    
    self.shippingLabel = [[UILabel alloc] init];
    self.shippingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.shippingLabel.font = labelFont;
    self.shippingLabel.textColor = labelColor;
    self.shippingLabel.text = kLang(@"Shipping Fee");
    
    self.shippingValueLabel = [[UILabel alloc] init];
    self.shippingValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.shippingValueLabel.font = [GM boldFontWithSize:14];
    self.shippingValueLabel.textColor = valueColor;
    self.shippingValueLabel.textAlignment = NSTextAlignmentNatural;
    self.shippingValueLabel.adjustsFontSizeToFitWidth = YES;
    self.shippingValueLabel.minimumScaleFactor = 0.72;
     
    // Separator
    self.separator = [[UIView alloc] init];
    self.separator.translatesAutoresizingMaskIntoConstraints = NO;
    self.separator.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.08];
    
    // Subtotal
    self.subtotalAttributedLabel = [[UILabel alloc] init];
    self.subtotalAttributedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtotalAttributedLabel.numberOfLines = 0;
    self.subtotalAttributedLabel.textAlignment = Language.alignmentForCurrentLanguage;
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

    // Pricing Stack
    self.pricingStack = [[UIStackView alloc] init];
    self.pricingStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.pricingStack.axis = UILayoutConstraintAxisVertical;
    self.pricingStack.spacing = 14.0;
    [self.cardView addSubview:self.pricingStack];
    
    
    self.pricingStackBottomAnchor = [self.pricingStack.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-18];
   //shoppingCart
   
    // Checkout Button
    self.checkoutBTN = [UIButton buttonWithType:UIButtonTypeSystem];
    self.checkoutBTN.translatesAutoresizingMaskIntoConstraints = NO;
    self.checkoutBTN.layer.cornerRadius = PPCheckoutButtonCornerRadius();
    self.checkoutBTN.titleLabel.font = [GM boldFontWithSize:17];
    self.checkoutBTN.accessibilityLabel = NSLocalizedString(@"a11y_btn_checkout", @"Checkout");
    self.checkoutBTN.accessibilityHint  = NSLocalizedString(@"a11y_btn_checkout_hint", @"Double-tap to proceed to checkout");
    [self.checkoutBTN addTarget:self action:@selector(didTapCheckout) forControlEvents:UIControlEventTouchUpInside];
    [self pp_applyCheckoutButtonStyleWithTitle:kLang(@"Checkout") image:nil];
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
    self.trustBannerView.layer.cornerRadius =18.0;
    self.trustBannerView.layer.masksToBounds = YES;
    self.trustBannerView.layer.borderWidth = 1.0;
    self.trustBannerView.layer.borderColor = [[UIColor colorWithRed:1.00 green:0.84 blue:0.00 alpha:0.22] CGColor];
    [self.trustBannerView setBackgroundColor:[UIColor hx_colorWithHexStr:@"#FABB00" alpha:0.05]];
    if (@available(iOS 13.0, *)) {
        self.trustBannerView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    self.trustBannerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.trustBannerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.trustBannerLabel.numberOfLines = 1;
    self.trustBannerLabel.font = [GM MidFontWithSize:12];
    self.trustBannerLabel.textColor = [UIColor.labelColor colorWithAlphaComponent:0.66];
    self.trustBannerLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.trustBannerLabel.text =  kLang(@"Securecheckout");
    [self.trustBannerView addSubview:self.trustBannerLabel];

    [self.trustBannerView.heightAnchor constraintEqualToConstant:42.0].active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [self.trustBannerLabel.leadingAnchor constraintEqualToAnchor:self.trustBannerView.leadingAnchor constant:14.0],
        [self.trustBannerLabel.trailingAnchor constraintEqualToAnchor:self.trustBannerView.trailingAnchor constant:-52.0],
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
    subtotalRow.spacing = 16.0;

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
    self.itemsPreviewHeightConstraint =
        [self.itemsPreviewCollection.heightAnchor constraintEqualToConstant:98.0];
    self.itemsPreviewHeightConstraint.active = YES;
    
    [self.pricingStack addArrangedSubview:subtotalRow];
    [self.pricingStack addArrangedSubview:self.separator];
    [self.pricingStack addArrangedSubview:self.itemsRow];
    [self.pricingStack addArrangedSubview:self.shippingRow];
    [self.pricingStack addArrangedSubview:self.itemsPreviewCollection];
    [self.pricingStack addArrangedSubview:self.trustBannerView];
    
    
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

}
//kLang(@"Checkout")
-(void)setCheckoutBTNTitle:(NSString *)title image:(UIImage *)image
{
    [self pp_applyCheckoutButtonStyleWithTitle:title ?: kLang(@"Checkout") image:image];
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
    self.checkoutBTN.alpha = loading ? 0.9 : 1.0;

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
    UIView *spacer = [[UIView alloc] initWithFrame:CGRectZero];
    spacer.translatesAutoresizingMaskIntoConstraints = NO;

    NSMutableArray<UIView *> *arrangedSubviews = [NSMutableArray arrayWithObjects:label, spacer, value, nil];
    if (button) {
        [arrangedSubviews addObject:button];
    }

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:arrangedSubviews];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 10.0;
    row.alignment = UIStackViewAlignmentCenter;
    row.distribution = UIStackViewDistributionFill;
    row.semanticContentAttribute = GM.setSemantic;
    row.layoutMarginsRelativeArrangement = YES;
    row.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(12, 14, 12, 14);
    [self pp_styleInfoRow:row];

    [label setContentHuggingPriority:UILayoutPriorityDefaultHigh
                             forAxis:UILayoutConstraintAxisHorizontal];
    [label setContentCompressionResistancePriority:UILayoutPriorityRequired
                                           forAxis:UILayoutConstraintAxisHorizontal];

    [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow
                              forAxis:UILayoutConstraintAxisHorizontal];
    [spacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                            forAxis:UILayoutConstraintAxisHorizontal];

    [value setContentHuggingPriority:UILayoutPriorityRequired
                              forAxis:UILayoutConstraintAxisHorizontal];
    [value setContentCompressionResistancePriority:UILayoutPriorityRequired
                                            forAxis:UILayoutConstraintAxisHorizontal];

    return row;
}

#pragma mark - Layout

- (void)buildLayout {
    CGFloat padding = 18.0;
  
    [NSLayoutConstraint activateConstraints:@[
        [self.checkoutBTN.heightAnchor constraintEqualToConstant:54.0],
        [self.cardView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
 
        [self.pricingStack.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:18.0],
        [self.pricingStack.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:padding],
        [self.pricingStack.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-padding],

        [self.separator.heightAnchor constraintEqualToConstant:1.0],
        self.pricingStackBottomAnchor,
     ]];

    self.animationView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.animationContainerView.heightAnchor constraintEqualToConstant:34.0].active = YES;
    [self.animationContainerView.widthAnchor constraintEqualToConstant:34.0].active = YES;
    [self.animationContainerView.centerYAnchor constraintEqualToAnchor:self.trustBannerView.centerYAnchor].active = YES;
    [self.animationContainerView.trailingAnchor constraintEqualToAnchor:self.trustBannerView.trailingAnchor constant:-8.0].active = YES;

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

    NSRange titleRange = [fullText rangeOfString:title];
    if (titleRange.location != NSNotFound) {
        [attr addAttributes:@{
            NSFontAttributeName: [GM MidFontWithSize:11],
            NSForegroundColorAttributeName: [UIColor.labelColor colorWithAlphaComponent:0.52],
            NSKernAttributeName: @(0.4)
        } range:titleRange];
    }

    NSRange integerRange =
    [fullText rangeOfString:integerPart options:NSBackwardsSearch];

    [attr addAttributes:@{
        NSFontAttributeName: [GM boldFontWithSize:PPIsRL ? 34 : 30],
        NSForegroundColorAttributeName: [UIColor.labelColor colorWithAlphaComponent:0.96]
    } range:integerRange];

    if (fractionPart) {
        NSRange fractionRange =
        [fullText rangeOfString:fractionPart options:NSBackwardsSearch];

        if (fractionRange.location != NSNotFound) {
            [attr addAttributes:@{
                NSFontAttributeName: [GM boldFontWithSize:14],
                NSForegroundColorAttributeName: [AppPrimaryClr colorWithAlphaComponent:0.92],
                NSBaselineOffsetAttributeName: @(9)
            } range:fractionRange];
        }
    }

    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineSpacing = showTitle ? 3.0 : 0.0;
    style.alignment = Language.alignmentForCurrentLanguage;

    [attr addAttribute:NSParagraphStyleAttributeName
                 value:style
                 range:NSMakeRange(0, attr.length)];

    self.subtotalAttributedLabel.numberOfLines = showTitle ? 2 : 1;
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

    if (showsItemsPreview) {
        self.itemsPreviewCollection.hidden = NO;
        self.itemsPreviewCollection.alpha = 0.0;
        self.itemsPreviewCollection.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
        self.itemsRow.hidden = NO;
        self.shippingRow.hidden = NO;
    }

    self.pricingStackBottomAnchor.constant = -18.0;
    [UIView animateWithDuration:0.3
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.itemsPreviewCollection.alpha = showsItemsPreview ? 1.0 : 0.0;
        self.itemsPreviewCollection.transform = showsItemsPreview ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0.0, 10.0);
        self.itemsRow.alpha = showsItemsPreview ? 0.0 : 1.0;
        self.itemsRow.transform = showsItemsPreview ? CGAffineTransformMakeTranslation(0.0, -6.0) : CGAffineTransformIdentity;
        self.shippingRow.alpha = showsItemsPreview ? 0.0 : 1.0;
        self.shippingRow.transform = showsItemsPreview ? CGAffineTransformMakeTranslation(0.0, -6.0) : CGAffineTransformIdentity;
    } completion:^(BOOL finished) {

        self.itemsRow.hidden = showsItemsPreview;
        self.shippingRow.hidden = showsItemsPreview;
        if (!showsItemsPreview) {
            self.itemsPreviewCollection.hidden = YES;
        }
    }];
}

- (void)updatePreviewItems:(NSArray<CartItem *> *)items
{
    self.previewItems = items ?: @[];
    BOOL shouldShowPreview = self.showsItemsPreview && self.previewItems.count > 0;
    self.itemsPreviewCollection.hidden = !shouldShowPreview;
    self.itemsPreviewCollection.alpha = shouldShowPreview ? 1.0 : 0.0;
    self.itemsPreviewCollection.transform = shouldShowPreview ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0.0, 10.0);
    self.itemsRow.hidden = shouldShowPreview;
    self.shippingRow.hidden = shouldShowPreview;
    self.itemsRow.alpha = shouldShowPreview ? 0.0 : 1.0;
    self.shippingRow.alpha = shouldShowPreview ? 0.0 : 1.0;
    self.itemsRow.transform = CGAffineTransformIdentity;
    self.shippingRow.transform = CGAffineTransformIdentity;
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
        img.layer.cornerRadius = 14.0;
        img.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.05];
        if (@available(iOS 13.0, *)) {
            img.layer.cornerCurve = kCACornerCurveContinuous;
        }
        cell.contentView.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.035];
        cell.contentView.layer.cornerRadius = 20.0;
        cell.contentView.layer.borderWidth = 1.0;
        cell.contentView.layer.borderColor = [UIColor.labelColor colorWithAlphaComponent:0.06].CGColor;
        cell.contentView.layer.masksToBounds = YES;
        if (@available(iOS 13.0, *)) {
            cell.contentView.layer.cornerCurve = kCACornerCurveContinuous;
        }
        [cell.contentView addSubview:img];

        price = [[UILabel alloc] init];
        price.tag = 12;
        price.translatesAutoresizingMaskIntoConstraints = NO;
        price.font = [GM boldFontWithSize:11];
        price.textAlignment = NSTextAlignmentCenter;
        price.textColor = [UIColor.labelColor colorWithAlphaComponent:0.72];
        price.adjustsFontSizeToFitWidth = YES;
        price.minimumScaleFactor = 0.7;
        price.numberOfLines = 1;
        [cell.contentView addSubview:price];

        UIButton *removeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        removeBtn.tag = 13;
        removeBtn.translatesAutoresizingMaskIntoConstraints = NO;
        removeBtn.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.92];
        removeBtn.layer.cornerRadius = 11.0;
        removeBtn.clipsToBounds = YES;
        removeBtn.layer.borderWidth = 1.0;
        removeBtn.layer.borderColor = [UIColor.labelColor colorWithAlphaComponent:0.06].CGColor;
        if (@available(iOS 13.0, *)) {
            removeBtn.layer.cornerCurve = kCACornerCurveContinuous;
        }

        [removeBtn setImage:[UIImage systemImageNamed:@"xmark"]
                   forState:UIControlStateNormal];
        removeBtn.tintColor = [UIColor.labelColor colorWithAlphaComponent:0.78];
        removeBtn.contentEdgeInsets = UIEdgeInsetsMake(3, 3, 3, 3);

        [removeBtn addTarget:self
                      action:@selector(didTapRemovePreviewItem:)
            forControlEvents:UIControlEventTouchUpInside];

        [cell.contentView addSubview:removeBtn];

        [NSLayoutConstraint activateConstraints:@[
            [img.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:10.0],
            [img.centerXAnchor constraintEqualToAnchor:cell.contentView.centerXAnchor],
            [img.widthAnchor constraintEqualToConstant:56.0],
            [img.heightAnchor constraintEqualToConstant:56.0],

            [price.topAnchor constraintEqualToAnchor:img.bottomAnchor constant:8.0],
            [price.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:6.0],
            [price.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-6.0],
            [price.bottomAnchor constraintLessThanOrEqualToAnchor:cell.contentView.bottomAnchor constant:-8.0],

            [removeBtn.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:6.0],
            [removeBtn.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-6.0],
            [removeBtn.widthAnchor constraintEqualToConstant:22.0],
            [removeBtn.heightAnchor constraintEqualToConstant:22.0],
        ]];
    }

    // Tag the remove button with the current index (for every reuse)
    UIButton *removeBtn = [cell.contentView viewWithTag:13];
    removeBtn.accessibilityIdentifier =
        [NSString stringWithFormat:@"%ld", (long)indexPath.item];

    NSString *url = item.imageURL;
    if (url.length > 0) {
        [img sd_setImageWithURL:[NSURL URLWithString:url]];
    } else {
        img.image = nil;
    }

    price.text = [PPChatsFunc formattedCurrency:item.price];

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
