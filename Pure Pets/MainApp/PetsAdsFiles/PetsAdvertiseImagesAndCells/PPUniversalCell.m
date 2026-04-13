
//
//  PPUniversalCell.m
//  Pure Pets
//
//  Created by You on 2025-10-13.
//

#import "PPUniversalCell.h"
@import QuartzCore;
#import "PPUniversalCellHelper.h"
#import "PPImageLoaderManager.h"
#import "CartManager.h"
#import "PPHUD.h"
#import "PPChatsFunc.h"
#import "ServiceModel.h"

static CGFloat const PPAdsCellTopInset = 14.0;
static CGFloat const PPAdsCellSideInset = 14.0;
static CGFloat const PPAdsCellBottomInset = 10.0;
static CGFloat const PPAdsCellOverlayBottomInset = 12.0;
static CGFloat const PPAdsCellOverlayHeightSquare = 92.0;
static CGFloat const PPAdsCellOverlayHeightRegular = 96.0;
static CGFloat const PPAdsCellOverlayHeightFullWidth = 100.0;
static CGFloat const PPServiceOverlayFloatingInset = 4.0;
static CGFloat const PPServiceOverlayCornerRadius = 24.0;
static CGFloat const PPServiceTextInset = 12.0;
static CGFloat const PPServiceBottomTextInset = 12.0;
static CGFloat const PPServiceButtonHeight = 40.0;

static NSString *PPAdsLocalizedString(NSString *key, NSString *fallback)
{
    NSString *value = kLang(key);
    return value.length > 0 ? value : fallback;
}

#pragma mark - PPUniversalCell

@interface PPAdImageScrimView : UIView
@end

@implementation PPAdImageScrimView

+ (Class)layerClass
{
    return [CAGradientLayer class];
}

- (instancetype)init
{
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.userInteractionEnabled = NO;
    self.backgroundColor = UIColor.clearColor;

    CAGradientLayer *gradientLayer = (CAGradientLayer *)self.layer;
    gradientLayer.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:0.26].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.06].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.20].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.66].CGColor
    ];
    gradientLayer.locations = @[@0.0, @0.18, @0.56, @1.0];
    gradientLayer.startPoint = CGPointMake(0.5, 0.0);
    gradientLayer.endPoint = CGPointMake(0.5, 1.0);
    return self;
}

@end

@interface PPUniversalCell () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UITapGestureRecognizer *cardTapGR;
//- (void)tapShare;
//- (void)tapEdit;
//- (void)tapDelete;
//@property (nonatomic, strong) NSLayoutConstraint *overlayHeightConstraint;
 /// Callbacks
@property (nonatomic, copy, nullable) PPVoidHandler onTapCard;
@property (nonatomic, copy, nullable) PPVoidHandler onTapShare;
@property (nonatomic, copy, nullable) PPVoidHandler onTapFavorite;
@property (nonatomic, copy, nullable) PPVoidHandler onTapEdit;
@property (nonatomic, copy, nullable) PPVoidHandler onTapDelete;
@property (nonatomic, copy, nullable) PPVoidHandler onTapAdd; // "+" initial tap
@property (nonatomic, copy, nullable) PPQuantityChangedHandler onQuantityChanged;
@property (nonatomic, strong) UILabel *adLocationLabel;
@property (nonatomic, strong) UIImageView *locationIconView;
@property (nonatomic, strong) UIStackView *reasonBadgeStack;
@property (nonatomic, strong) UIImageView *reasonBadgeIconView;
@property (nonatomic, strong) UILabel *reasonBadgeLabel;
///@property (nonatomic, strong) NSLayoutConstraint *actionBarBottomToCardConstraint;
//@property (nonatomic, strong) NSLayoutConstraint *actionBarbuttomToAddButtonConstraint;
//@property (nonatomic, strong) NSLayoutConstraint *actionBarYConstraint;

@property (nonatomic, strong) UIButton *addButton;    // collapsed "+"
@property (nonatomic, strong) NSLayoutConstraint *addButtonWidthConstraint;
@property (nonatomic, strong) UIView *stepperView;    // expanded container
@property (nonatomic, strong) UIButton *minusBtn;
@property (nonatomic, strong) UILabel  *qtyLabel;
@property (nonatomic, strong) UIButton *plusBtn;
@property (nonatomic, strong) NSTimer *stepperCollapseTimer;
@property (nonatomic, strong) UIStackView *locationStack ;
@property (nonatomic, strong) UIStackView *topMetaRow;
@property (nonatomic, strong) UIView *topMetaSpacer;
@property (nonatomic, assign) BOOL isEditingQuantity;
// Image
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) PPAdImageScrimView *imageScrimView;

// Gradient (for square overlay mode)
@property (nonatomic, strong) PPBottomOverlayBlur *bottomOverlay;
@property (nonatomic, strong) NSLayoutConstraint *bottomOverlayHeightConstraint;

// Labels
@property (nonatomic, strong) UIStackView *textStack;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *serviceDetailsButton;

// Price / discount (bottom-right in overlay, or in details)
@property (nonatomic, strong) UIStackView *priceStack;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UILabel *discountLabel;
@property (nonatomic, strong) PPInsetLabel *discountValueLabel;
@property (nonatomic, strong) PPInsetLabel  *stockQtyLabel;
// Badges
@property (nonatomic, strong) UILabel *freshBadge;
@property (nonatomic, strong) UILabel *offerBadge;

// Owner actions
@property (nonatomic, strong) FavoriteFloatingButton *favButton;
@property (nonatomic, strong) UIButton *moreOptionsButton;
@property (nonatomic, strong) UIButton *shareButton;

// Share / favorite (optional, bottom-left overlay in square mode)
@property (nonatomic, strong) UIStackView *actionBar;

 

// Layout groups
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *fullWidthConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *pintrestConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *squareConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *marketConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *serviceConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *carouselConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *verticalConstraints;
@property (nonatomic, strong) NSLayoutConstraint *bottomOverlayLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bottomOverlayTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *bottomOverlayBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *textStackTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *textStackBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *textStackLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *textStackTrailingToEdgeConstraint;
@property (nonatomic, strong) NSLayoutConstraint *textStackTrailingToDiscountConstraint;
@property (nonatomic, strong) NSLayoutConstraint *discountValueTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *discountValueTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *actionBarTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *actionBarRightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *actionBarBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *actionBarTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *reasonBadgeServiceCenterYConstraint;
@property (nonatomic, strong) NSLayoutConstraint *reasonBadgeServiceTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *marketImageHeightConstraint;
@property (nonatomic, strong) UIView *card;
// Data
@property (nonatomic, copy)   PPImageLoader loader;
@property (nonatomic, strong) PPUniversalCellViewModel *vm;
@property (nonatomic, assign) BOOL didLayout;

- (void)pp_updateBottomOverlayTextWidthForDiscountBadgeVisible:(BOOL)isVisible;
- (void)pp_applyLayoutAppearanceForMarket:(BOOL)isMarket;
- (BOOL)pp_isServiceContext;
- (UIColor *)pp_serviceAccentColorForViewModel:(PPUniversalCellViewModel *)vm;
- (NSString *)pp_serviceSymbolNameForViewModel:(PPUniversalCellViewModel *)vm;
- (void)pp_updateServiceLayoutMetrics;
- (void)pp_updateTopMetaRowArrangementForService:(BOOL)isService;
- (void)pp_updateImageScrimAppearanceForViewModel:(PPUniversalCellViewModel *)vm;
- (void)pp_updateBottomOverlayMaterialForViewModel:(PPUniversalCellViewModel *)vm;
- (void)pp_updateServiceOverlayMaskIfNeeded;
- (void)pp_handlePrimaryTap;
- (void)pp_serviceDetailsButtonTapped;
- (UIColor *)pp_primaryTitleColorForCurrentContext;
- (UIColor *)pp_secondaryTextColorForCurrentContext;
- (UIColor *)pp_primaryPriceColorForCurrentContext;
- (UIColor *)pp_mutedPriceColorForCurrentContext;
- (UIFont *)pp_titleFontForCurrentContext;
- (CGFloat)pp_bottomOverlayHeightForLayoutMode:(PPManagerCellLayoutMode)layoutMode;
- (CGFloat)pp_bottomOverlayHeightForServiceLayoutMode:(PPManagerCellLayoutMode)layoutMode;
- (BOOL)pp_isSkeletonViewModel:(PPUniversalCellViewModel *)vm;
- (nullable PetAd *)pp_resolvedPetAdFromViewModel:(PPUniversalCellViewModel *)vm;
- (nullable ServiceModel *)pp_resolvedServiceFromViewModel:(PPUniversalCellViewModel *)vm;
- (NSString *)pp_shortAgeTextFromMonths:(NSNumber *)months;
- (NSString *)pp_adsSubtitleTextForViewModel:(PPUniversalCellViewModel *)vm;
- (NSString *)pp_serviceSubtitleTextForViewModel:(PPUniversalCellViewModel *)vm;
- (void)pp_configureServiceBadgeForViewModel:(PPUniversalCellViewModel *)vm;
- (void)pp_applyServiceStateForViewModel:(PPUniversalCellViewModel *)vm;
- (void)pp_applyServiceShadow;
- (void)pp_setPriceText:(NSString *)text
                  color:(UIColor *)color
                   font:(UIFont *)font;
- (BOOL)pp_isFeaturedAd:(nullable PetAd *)ad;
- (BOOL)pp_isTrendingAd:(nullable PetAd *)ad;
- (void)pp_configureAdsStatusBadgeForViewModel:(PPUniversalCellViewModel *)vm;
- (void)pp_applyAdsStateForViewModel:(PPUniversalCellViewModel *)vm;

@end

@implementation PPUniversalCell

#pragma mark - Init

- (void)setupBottomOverlay
{
    if (self.bottomOverlay) return;
    
    self.bottomOverlay =
    [[PPBottomOverlayBlur alloc] initWithHeight:64
                                   cornerRadius:0];
    
    [self.imageView addSubview:self.bottomOverlay];
    
    self.bottomOverlayHeightConstraint =
    [self.bottomOverlay.heightAnchor constraintEqualToConstant:64.0];

    self.bottomOverlayLeadingConstraint =
    [self.bottomOverlay.leadingAnchor constraintEqualToAnchor:self.imageView.leadingAnchor constant:0];
    self.bottomOverlayTrailingConstraint =
    [self.bottomOverlay.trailingAnchor constraintEqualToAnchor:self.imageView.trailingAnchor constant:0];
    self.bottomOverlayBottomConstraint =
    [self.bottomOverlay.bottomAnchor constraintEqualToAnchor:self.imageView.bottomAnchor constant:0];

    [NSLayoutConstraint activateConstraints:@[
        self.bottomOverlayLeadingConstraint,
        self.bottomOverlayTrailingConstraint,
        self.bottomOverlayBottomConstraint,
        self.bottomOverlayHeightConstraint
    ]];
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.didLayout = NO;
        [self buildUI];
        [self buildConstraints];
        self.discountStyle = PPDiscountStyleBadge;
        self.contentView.clipsToBounds = NO;
        self.clipsToBounds = NO;
        self.layer.shadowColor = AppShadowClr.CGColor;
        self.layer.shadowOpacity = 0.08;
        self.layer.shadowRadius = 14.0;
        self.layer.shadowOffset = CGSizeMake(0, 8.0);
        self.layer.backgroundColor = AppClearClr.CGColor;
        self.contentView.backgroundColor = AppClearClr;
        self.backgroundColor = AppClearClr;
        
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    // Remove old inner glow if exists
    
    [[PPImageLoaderManager shared] cancelImageLoadForImageView:self.imageView];
    self.imageView.image = nil;
    
    self.titleLabel.text = @"";
    self.subtitleLabel.text = @"";
    self.priceLabel.text = @"";
    self.discountLabel.text = @"";
    self.discountLabel.backgroundColor = UIColor.clearColor;
    self.discountLabel.layer.borderWidth = 0.0;
    self.discountLabel.layer.borderColor = UIColor.clearColor.CGColor;
    self.discountLabel.layer.shadowOpacity = 0.0;
    self.discountLabel.layer.shadowRadius = 0.0;
    self.discountLabel.layer.shadowOffset = CGSizeZero;
    if ([self.discountLabel isKindOfClass:PPInsetLabel.class]) {
        ((PPInsetLabel *)self.discountLabel).textInsets = UIEdgeInsetsMake(1.0, 2.0, 1.0, 2.0);
    }
    self.discountValueLabel.text = @"";
    self.discountValueLabel.hidden = YES;
    self.discountValueLabel.alpha = 1.0;
    self.discountValueLabel.transform = CGAffineTransformIdentity;
    self.stockQtyLabel.text = @"";
    self.freshBadge.hidden = YES;
    self.offerBadge.hidden = YES;
    self.moreOptionsButton.hidden = NO;
    self.favButton.hidden = NO;
    self.shareButton.hidden = YES;
    self.addButton.alpha = 1.0;
    self.addButton.hidden = NO;
    self.stepperView.alpha = 0.0;
    self.stepperView.hidden = YES;
    self.isEditingQuantity = NO;
    [self setQuantity:0 animated:NO];
    [self.stepperCollapseTimer invalidate];
    self.stepperCollapseTimer = nil;
    
    self.adLocationLabel.hidden = YES;
    self.locationIconView.hidden = YES;
    self.adLocationLabel.alpha = 0;
    self.locationIconView.alpha = 0;
    self.reasonBadgeStack.hidden = YES;
    self.reasonBadgeLabel.text = @"";
    self.reasonBadgeIconView.image = nil;
    self.reasonBadgeStack.layer.shadowOpacity = 0.0;
    self.reasonBadgeStack.layer.shadowRadius = 0.0;
    self.reasonBadgeStack.layer.shadowOffset = CGSizeZero;
    [self pp_updateBottomOverlayTextWidthForDiscountBadgeVisible:NO];
    self.bottomOverlay.hidden = NO;
    self.actionBar.hidden = NO;
    self.card.transform = CGAffineTransformIdentity;
    self.imageView.transform = CGAffineTransformIdentity;
    self.imageScrimView.alpha = 1.0;
    self.bottomOverlay.alpha = 1.0;
    self.locationStack.transform = CGAffineTransformIdentity;
    self.reasonBadgeStack.transform = CGAffineTransformIdentity;

    
    self.didLayout = NO;
    self.serviceDetailsButton.hidden = YES;
    self.serviceDetailsButton.alpha = 1.0;
  
 }


+ (NSString *)reuseIdentifier { return  @"PPUniversalCell";}
 

- (void)layoutSubviews {
    [super layoutSubviews];

    [self pp_updateServiceOverlayMaskIfNeeded];

    if (self.didLayout == NO) {
       // [self addParallaxToView:self.imageView intensity:0.8];
       
        self.didLayout = YES;
    }
}



- (void)buildUI {
    
     
    // Card
    self.card = [UIView new];
    
    self.card.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.card];

    self.card.clipsToBounds = YES;
    
    CGFloat radius = PPCornerCard;

    self.card.layer.cornerRadius = radius;
    
    if (@available(iOS 13.0, *)) {
        self.card.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    self.card.layer.masksToBounds = NO;
    if (@available(iOS 13.0, *)) {
        self.card.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    
    // Image
    self.imageView = [self createImageView];
    [self.card addSubview:self.imageView];
    self.imageView.alpha = 1.0;
    self.imageScrimView = [[PPAdImageScrimView alloc] init];
    [self.imageView addSubview:self.imageScrimView];
    [NSLayoutConstraint activateConstraints:@[
        [self.imageScrimView.topAnchor constraintEqualToAnchor:self.imageView.topAnchor],
        [self.imageScrimView.leadingAnchor constraintEqualToAnchor:self.imageView.leadingAnchor],
        [self.imageScrimView.trailingAnchor constraintEqualToAnchor:self.imageView.trailingAnchor],
        [self.imageScrimView.bottomAnchor constraintEqualToAnchor:self.imageView.bottomAnchor]
    ]];
    self.card.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.98] ?: UIColor.whiteColor;
    self.card.layer.borderWidth = 0.75;
    self.card.layer.borderColor = [[UIColor labelColor] colorWithAlphaComponent:0.04].CGColor;
    self.imageView.clipsToBounds = YES;
     //self.overlay = [PPNavigationController  setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleLarge];
 
    [self setupBottomOverlay];
   
    self.priceLabel = [self createPriceLabel];
    self.discountLabel = [self createDiscountLabel];
    self.discountValueLabel = [self createDiscountValueLabel];
    self.discountValueLabel.hidden = YES;
    self.stockQtyLabel = [self createStockQtyLabel];

    // Only priceLabel and discountLabel in priceStack
    self.priceStack = [self createPriceStackWithSubviews:@[self.priceLabel, self.discountLabel]];
   // [self.priceStack setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
    //                                                forAxis:UILayoutConstraintAxisVertical];
   

   // [self.priceStack setContentHuggingPriority:UILayoutPriorityDefaultLow
     //                                  forAxis:UILayoutConstraintAxisVertical];
    
    // Texts
    self.titleLabel = [self createTitleLabel];
    self.subtitleLabel = [self createSubtitleLabel];
    self.serviceDetailsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.serviceDetailsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.serviceDetailsButton.hidden = YES;
    self.serviceDetailsButton.clipsToBounds = YES;
    self.serviceDetailsButton.layer.cornerRadius = 15.0;
    self.serviceDetailsButton.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.serviceDetailsButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.serviceDetailsButton addTarget:self
                                  action:@selector(pp_serviceDetailsButtonTapped)
                        forControlEvents:UIControlEventTouchUpInside];
    [self.serviceDetailsButton.heightAnchor constraintEqualToConstant:34].active = YES;
    
    // 📍 Location label (Home Ads)
    self.adLocationLabel = [UILabel new];
    self.adLocationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.adLocationLabel.font = [GM MidFontWithSize:10.5];
    self.adLocationLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    self.adLocationLabel.numberOfLines = 1;
    self.adLocationLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.adLocationLabel.textAlignment = GM.setAligment;
    self.adLocationLabel.hidden = YES;

    // Subtle contrast shadow (glass-friendly)
    self.adLocationLabel.layer.shadowColor = UIColor.blackColor.CGColor;
    self.adLocationLabel.layer.shadowOpacity = 0.24;
    self.adLocationLabel.layer.shadowRadius = 2.0;
    self.adLocationLabel.layer.shadowOffset = CGSizeMake(0, 1);

    // Pin icon
    UIImage *pin =
    [UIImage systemImageNamed:@"mappin.and.ellipse"];

    self.locationIconView = [[UIImageView alloc] initWithImage:pin];
    self.locationIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationIconView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    self.locationIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.locationIconView.hidden = YES;

    // Container for icon + label (glass style)
    self.locationStack =
    [[UIStackView alloc] initWithArrangedSubviews:@[
        self.locationIconView,
        self.adLocationLabel
    ]];

    self.locationStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.locationStack.axis = UILayoutConstraintAxisHorizontal;
    self.locationStack.alignment = UIStackViewAlignmentCenter;
    self.locationStack.spacing = 5;
    self.locationStack.backgroundColor =
    [[UIColor blackColor] colorWithAlphaComponent:0.30];
    self.locationStack.layer.cornerRadius = 13;
    self.locationStack.layer.borderWidth = 0.8;
    self.locationStack.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor;
    self.locationStack.layer.masksToBounds = YES;
    self.locationStack.layoutMargins =
    UIEdgeInsetsMake(6, 9, 6, 10);
    self.locationStack.layoutMarginsRelativeArrangement = YES;

    [self.locationStack setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                        forAxis:UILayoutConstraintAxisHorizontal];
    [self.locationStack setContentHuggingPriority:UILayoutPriorityRequired
                                          forAxis:UILayoutConstraintAxisHorizontal];
    [self.adLocationLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                        forAxis:UILayoutConstraintAxisHorizontal];
    [self.adLocationLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh
                                            forAxis:UILayoutConstraintAxisHorizontal];
    self.locationStack.hidden = YES;

    self.reasonBadgeIconView = [[UIImageView alloc] init];
    self.reasonBadgeIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.reasonBadgeIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.reasonBadgeIconView.tintColor = UIColor.whiteColor;

    self.reasonBadgeLabel = [[UILabel alloc] init];
    self.reasonBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.reasonBadgeLabel.font = [GM MidFontWithSize:10.5] ?: [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold];
    self.reasonBadgeLabel.textColor = UIColor.whiteColor;
    self.reasonBadgeLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.reasonBadgeLabel.numberOfLines = 1;
    self.reasonBadgeLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    self.reasonBadgeStack =
    [[UIStackView alloc] initWithArrangedSubviews:@[
        self.reasonBadgeIconView,
        self.reasonBadgeLabel
    ]];
    self.reasonBadgeStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.reasonBadgeStack.axis = UILayoutConstraintAxisHorizontal;
    self.reasonBadgeStack.alignment = UIStackViewAlignmentCenter;
    self.reasonBadgeStack.spacing = 4.0;
    self.reasonBadgeStack.backgroundColor =
        [[UIColor blackColor] colorWithAlphaComponent:0.34];
    self.reasonBadgeStack.layer.cornerRadius = 13.0;
    self.reasonBadgeStack.layer.cornerCurve = kCACornerCurveContinuous;
    self.reasonBadgeStack.layer.masksToBounds = YES;
    self.reasonBadgeStack.layer.borderWidth = 0.8;
    self.reasonBadgeStack.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.14].CGColor;
    self.reasonBadgeStack.layoutMargins = UIEdgeInsetsMake(6, 9, 6, 10);
    self.reasonBadgeStack.layoutMarginsRelativeArrangement = YES;
    [self.reasonBadgeStack setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                           forAxis:UILayoutConstraintAxisHorizontal];
    [self.reasonBadgeStack setContentHuggingPriority:UILayoutPriorityRequired
                                             forAxis:UILayoutConstraintAxisHorizontal];
    self.reasonBadgeStack.hidden = YES;
    self.topMetaSpacer = [[UIView alloc] init];
    self.topMetaSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.topMetaSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow
                                          forAxis:UILayoutConstraintAxisHorizontal];
    [self.topMetaSpacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                        forAxis:UILayoutConstraintAxisHorizontal];

    self.topMetaRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.locationStack,
        self.topMetaSpacer,
        self.reasonBadgeStack
    ]];
    self.topMetaRow.translatesAutoresizingMaskIntoConstraints = NO;
    self.topMetaRow.axis = UILayoutConstraintAxisHorizontal;
    self.topMetaRow.alignment = UIStackViewAlignmentCenter;
    self.topMetaRow.distribution = UIStackViewDistributionFill;
    self.topMetaRow.spacing = 10.0;
    [self.card addSubview:self.topMetaRow];

    [NSLayoutConstraint activateConstraints:@[
        [self.topMetaRow.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:PPAdsCellTopInset],
        [self.topMetaRow.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:PPAdsCellTopInset],
        [self.topMetaRow.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-PPAdsCellTopInset],
        [self.locationStack.widthAnchor constraintLessThanOrEqualToAnchor:self.card.widthAnchor multiplier:0.56],
        [self.reasonBadgeStack.widthAnchor constraintLessThanOrEqualToAnchor:self.card.widthAnchor multiplier:0.48],
        [self.locationIconView.widthAnchor constraintEqualToConstant:12.0],
        [self.locationIconView.heightAnchor constraintEqualToConstant:12.0],
        [self.reasonBadgeIconView.widthAnchor constraintEqualToConstant:11.0],
        [self.reasonBadgeIconView.heightAnchor constraintEqualToConstant:11.0],
        //[self.titleLabel.heightAnchor constraintEqualToConstant:14.0],
        

    ]];
    
    self.textStack = [self createTextStackWithElements:@[
        self.titleLabel,
        self.subtitleLabel,
        self.priceStack
    ]];
    [self.textStack addArrangedSubview:self.serviceDetailsButton];
    self.textStack.spacing = 4.0;
    self.textStack.alignment = UIStackViewAlignmentFill;
    self.textStack.distribution = UIStackViewDistributionFill;
    self.priceStack.alignment = UIStackViewAlignmentFirstBaseline;
    self.priceStack.spacing = 6.0;

    [self.card addSubview:self.textStack];
    [self.card addSubview:self.discountValueLabel];

    // Badges
    self.freshBadge   = [self badgeWithText:NSLocalizedString(@"NEW", nil) bg:[UIColor systemGreenColor]];
    self.offerBadge = [self badgeWithText:NSLocalizedString(@"OFFER", nil) bg:[UIColor systemOrangeColor]];
    self.freshBadge.hidden = YES;
    self.offerBadge.hidden = YES;

    [self.card addSubview:self.freshBadge];
    [self.card addSubview:self.offerBadge];
 
    self.favButton = [[FavoriteFloatingButton alloc] init];
    self.favButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_favorite", @"Favorite");
    self.favButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_favorite_hint", @"Double-tap to add or remove from favorites");

    self.shareButton =
    [self iconButton:@"square.and.arrow.up"
           buttonKind:ButtonKindImage
                 size:38.0
       baseForground:UIColor.labelColor
      baseBackground:[AppForgroundColr colorWithAlphaComponent:0.72]];
    [self.shareButton.widthAnchor constraintEqualToConstant:38.0].active = YES;
    [self.shareButton.heightAnchor constraintEqualToConstant:38.0].active = YES;
    self.shareButton.hidden = YES;
    self.shareButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_share", @"Share");
    self.shareButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_share_hint", @"Double-tap to share this listing");
    
    self.moreOptionsButton =
    [self iconButton:@"ellipsis"
           buttonKind:ButtonKindImage
                 size:38.0
       baseForground:UIColor.labelColor
      baseBackground:[AppForgroundColr colorWithAlphaComponent:0.72]];
    self.moreOptionsButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_more_options", @"More options");
    self.moreOptionsButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_more_options_hint", @"Double-tap to see edit and delete options");
    
    self.moreOptionsButton.menu = [self ownerActionsArray];
    self.moreOptionsButton.showsMenuAsPrimaryAction = YES;
    [self.moreOptionsButton addTarget:self
                          action:@selector(ownerMenuButtonTapped:)
                forControlEvents:UIControlEventTouchDown];

    [self.moreOptionsButton.widthAnchor constraintEqualToConstant:38.0].active = YES;
    [self.moreOptionsButton.heightAnchor constraintEqualToConstant:38.0].active = YES;
     
    
    self.actionBar =
    [[UIStackView alloc] init];
    [self.actionBar addArrangedSubview:self.favButton];
    [self.actionBar addArrangedSubview:self.moreOptionsButton];
 
    
    
    self.actionBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionBar.axis = UILayoutConstraintAxisHorizontal;
    self.actionBar.spacing = 10;
    self.actionBar.alignment = UIStackViewAlignmentCenter;

    [self.card addSubview:self.actionBar];

    self.addButton = [self iconButton:@"+"
                           buttonKind:ButtonKindText
                                 size:38.0
                        baseForground:UIColor.whiteColor
                       baseBackground:AppPrimaryClr];
    self.addButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.addButton.titleLabel.minimumScaleFactor = 0.7;
    self.addButton.titleLabel.lineBreakMode = NSLineBreakByClipping;
    self.addButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_add_to_cart", @"Add to cart");
    self.addButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_add_to_cart_hint", @"Double-tap to add this item to your cart");
    [self.addButton addTarget:self action:@selector(tapAddCollapsed) forControlEvents:UIControlEventTouchUpInside];
    [self.card addSubview:self.addButton];
    
    self.minusBtn = [self iconButton:@"-" buttonKind:ButtonKindText size:34.0 baseForground:AppPrimaryClr baseBackground:AppForgroundColr];
    self.minusBtn.accessibilityLabel = NSLocalizedString(@"a11y_btn_decrease_qty", @"Decrease quantity");
    [self.minusBtn addTarget:self action:@selector(tapMinus) forControlEvents:UIControlEventTouchUpInside];
    self.plusBtn = [self iconButton:@"+" buttonKind:ButtonKindText size:34.0 baseForground:AppPrimaryClr baseBackground:AppForgroundColr];
    self.plusBtn.accessibilityLabel = NSLocalizedString(@"a11y_btn_increase_qty", @"Increase quantity");
    [self.plusBtn addTarget:self action:@selector(tapPlus) forControlEvents:UIControlEventTouchUpInside];
    
    self.qtyLabel = [self createQtyLabel];
    self.stepperView = [self createStepperView];

    UIStackView *stepperStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.plusBtn, self.qtyLabel,self.minusBtn]];
    stepperStack.translatesAutoresizingMaskIntoConstraints = NO;
    stepperStack.axis = UILayoutConstraintAxisHorizontal;
    stepperStack.alignment = UIStackViewAlignmentCenter;
    stepperStack.distribution = UIStackViewDistributionFill;
    stepperStack.spacing = 4;

    [self.stepperView addSubview:stepperStack];
    [self.card addSubview:self.stepperView];

    [NSLayoutConstraint activateConstraints:@[
        [stepperStack.topAnchor constraintEqualToAnchor:self.stepperView.topAnchor constant:2.0],
        [stepperStack.leadingAnchor constraintEqualToAnchor:self.stepperView.leadingAnchor constant:4.0],
        [stepperStack.trailingAnchor constraintEqualToAnchor:self.stepperView.trailingAnchor constant:-4.0],
        [stepperStack.bottomAnchor constraintEqualToAnchor:self.stepperView.bottomAnchor constant:-2.0],
        [self.minusBtn.widthAnchor constraintEqualToConstant:34.0],
        [self.minusBtn.heightAnchor constraintEqualToConstant:34.0],
        [self.plusBtn.widthAnchor constraintEqualToConstant:34.0],
        [self.plusBtn.heightAnchor constraintEqualToConstant:34.0],
        [self.stepperView.heightAnchor constraintEqualToConstant:38.0]
    ]];
    self.addButtonWidthConstraint = [self.addButton.widthAnchor constraintEqualToConstant:38.0];
    self.addButtonWidthConstraint.active = YES;
    [self.addButton.heightAnchor constraintEqualToConstant:38.0].active = YES;

    // Taps
    // Add dedicated tap gesture recognizer for card tap (custom, does not interfere with controls)
    self.card.userInteractionEnabled = YES;
    self.cardTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    self.cardTapGR.cancelsTouchesInView = NO;
    self.cardTapGR.delaysTouchesBegan = NO;
    self.cardTapGR.delegate = self;
    [self.card addGestureRecognizer:self.cardTapGR];
    // (Old tapCard gesture is now removed)
    [self.card addSubview:self.stockQtyLabel];

   /* UIImageView *bannerImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"newBadge"]];
    bannerImageView.translatesAutoresizingMaskIntoConstraints = NO;
    bannerImageView.contentMode = UIViewContentModeScaleAspectFit;
    bannerImageView.backgroundColor = AppClearClr;
    [self.card addSubview:bannerImageView];

    // Add constraints
    [NSLayoutConstraint activateConstraints:@[
        [bannerImageView.centerXAnchor constraintEqualToAnchor:self.card.centerXAnchor],
        [bannerImageView.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:-5],
        [bannerImageView.widthAnchor constraintEqualToConstant:60],
        [bannerImageView.heightAnchor constraintEqualToConstant:40]
    ]];*/
    
    
    
    
    [self.bottomOverlay setNeedsLayout];
    
 }



#pragma mark - Constraints

- (void)buildConstraints {

    

    // =========================
    // Card
    // =========================
    [NSLayoutConstraint activateConstraints:@[
        [self.card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
    ]];

    // =========================
    // Image (always fills card)
    // =========================
    NSLayoutConstraint *imgTop =
    [self.imageView.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:0];

    NSLayoutConstraint *imgLeading =
    [self.imageView.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:0];

    NSLayoutConstraint *imgTrailing =
    [self.imageView.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:0];

    NSLayoutConstraint *imgBottom =
    [self.imageView.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:0];

    NSLayoutConstraint *marketImgTop =
    [self.imageView.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:14.0];

    NSLayoutConstraint *marketImgLeading =
    [self.imageView.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:14.0];

    NSLayoutConstraint *marketImgTrailing =
    [self.imageView.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-14.0];

    self.marketImageHeightConstraint =
    [self.imageView.heightAnchor constraintEqualToAnchor:self.imageView.widthAnchor multiplier:0.72];

    // =========================
    // Bottom Overlay (already created)
    // =========================
    NSLayoutConstraint *minHeight =
    [self.bottomOverlay.heightAnchor constraintGreaterThanOrEqualToConstant:72];
    minHeight.priority = UILayoutPriorityRequired;
    minHeight.active = YES;

    
    
    // =========================
    // TEXT STACK (CRITICAL FIX)
    // =========================
    self.textStackTopConstraint =
    [self.textStack.topAnchor constraintEqualToAnchor:self.bottomOverlay.topAnchor constant:14];

    self.textStackBottomConstraint =
    [self.textStack.bottomAnchor constraintEqualToAnchor:self.bottomOverlay.bottomAnchor constant:-12.0];

    self.textStackLeadingConstraint =
    [self.textStack.leadingAnchor constraintEqualToAnchor:self.bottomOverlay.leadingAnchor constant:16.0];

    self.textStackTrailingToEdgeConstraint =
    [self.textStack.trailingAnchor constraintEqualToAnchor:self.bottomOverlay.trailingAnchor constant:-16.0];
    self.textStackTrailingToDiscountConstraint =
    [self.textStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.discountValueLabel.leadingAnchor constant:-12];

    NSLayoutConstraint *marketTxtTop =
    [self.textStack.topAnchor constraintEqualToAnchor:self.imageView.bottomAnchor constant:16.0];

    NSLayoutConstraint *marketTxtLeading =
    [self.textStack.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:16.0];

    NSLayoutConstraint *marketTxtTrailing =
    [self.textStack.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-16.0];
    NSLayoutConstraint *serviceTxtBottom =
    [self.textStack.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:-16.0];

    self.discountValueTrailingConstraint =
    [self.discountValueLabel.trailingAnchor constraintEqualToAnchor:self.bottomOverlay.trailingAnchor constant:-16.0];
    self.discountValueTopConstraint =
    [self.discountValueLabel.topAnchor constraintEqualToAnchor:self.bottomOverlay.topAnchor constant:14];
    self.discountValueTrailingConstraint.active = YES;
    self.discountValueTopConstraint.active = YES;
    [self pp_updateBottomOverlayTextWidthForDiscountBadgeVisible:NO];

    NSLayoutConstraint *marketDiscountTop =
    [self.discountValueLabel.topAnchor constraintEqualToAnchor:self.imageView.topAnchor constant:12.0];

    NSLayoutConstraint *marketDiscountLeading =
    [self.discountValueLabel.leadingAnchor constraintEqualToAnchor:self.imageView.leadingAnchor constant:12.0];

    // =========================
    // Floating actions
    // =========================
    self.actionBarTrailingConstraint =
    [self.actionBar.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-14.0];
    self.actionBarRightConstraint =
    [self.actionBar.rightAnchor constraintEqualToAnchor:self.card.rightAnchor constant:-14.0];

    self.actionBarBottomConstraint =
    [self.actionBar.bottomAnchor constraintEqualToAnchor:self.bottomOverlay.topAnchor constant:-14.0];
    self.actionBarTopConstraint =
    [self.actionBar.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:14.0];

    self.actionBarBottomConstraint.active = YES;
    self.actionBarTrailingConstraint.active = YES;

    NSLayoutConstraint *marketActionTop =
    [self.actionBar.topAnchor constraintEqualToAnchor:self.imageView.topAnchor constant:12.0];
 
    NSLayoutConstraint *marketActionTrailing =
    [self.actionBar.trailingAnchor constraintEqualToAnchor:self.imageView.trailingAnchor constant:-12.0];

    NSLayoutConstraint *serviceActionLeading =
    [self.actionBar.leadingAnchor constraintEqualToAnchor:self.imageView.leadingAnchor constant:12.0];

    // =========================
    // Add / Stepper footer
    // =========================
    NSLayoutConstraint *addTrailing =
    [self.addButton.trailingAnchor constraintEqualToAnchor:self.bottomOverlay.trailingAnchor constant:-10];
    NSLayoutConstraint *addBottom =
    [self.addButton.bottomAnchor constraintEqualToAnchor:self.bottomOverlay.topAnchor constant:-10];
    NSLayoutConstraint *stepperTrailing =
    [self.stepperView.trailingAnchor constraintEqualToAnchor:self.addButton.trailingAnchor];
    NSLayoutConstraint *stepperBottom =
    [self.stepperView.bottomAnchor constraintEqualToAnchor:self.addButton.bottomAnchor];

    NSLayoutConstraint *marketAddTop =
    [self.addButton.topAnchor constraintEqualToAnchor:self.textStack.bottomAnchor constant:16.0];
    NSLayoutConstraint *marketAddLeading =
    [self.addButton.leadingAnchor constraintEqualToAnchor:self.textStack.leadingAnchor];
    NSLayoutConstraint *marketAddTrailing =
    [self.addButton.trailingAnchor constraintEqualToAnchor:self.textStack.trailingAnchor];
    NSLayoutConstraint *marketStepperTop =
    [self.stepperView.topAnchor constraintEqualToAnchor:self.textStack.bottomAnchor constant:16.0];
    NSLayoutConstraint *marketStepperLeading =
    [self.stepperView.leadingAnchor constraintEqualToAnchor:self.textStack.leadingAnchor];
    NSLayoutConstraint *marketStepperTrailing =
    [self.stepperView.trailingAnchor constraintEqualToAnchor:self.textStack.trailingAnchor];

    // =========================
    // Service-Mode specific reasonBadge
    // =========================
    self.reasonBadgeServiceCenterYConstraint =
    [self.reasonBadgeStack.centerYAnchor constraintEqualToAnchor:self.favButton.centerYAnchor];
    self.reasonBadgeServiceTrailingConstraint =
    [self.reasonBadgeStack.trailingAnchor constraintEqualToAnchor:self.imageView.trailingAnchor constant:-14.0];

    // =========================
    // Badges
    // =========================
    [NSLayoutConstraint activateConstraints:@[
        [self.freshBadge.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:12],
        [self.freshBadge.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-12],

        [self.offerBadge.topAnchor constraintEqualToAnchor:self.freshBadge.bottomAnchor constant:8],
        [self.offerBadge.trailingAnchor constraintEqualToAnchor:self.freshBadge.trailingAnchor],
    ]];

    NSLayoutConstraint *stockTop =
    [self.stockQtyLabel.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:12.0];
    NSLayoutConstraint *stockTrailing =
    [self.stockQtyLabel.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-12.0];
    NSLayoutConstraint *stockHeight =
    [self.stockQtyLabel.heightAnchor constraintEqualToConstant:24.0];
    NSLayoutConstraint *marketStockTop =
    [self.stockQtyLabel.topAnchor constraintEqualToAnchor:self.addButton.bottomAnchor constant:14.0];
    NSLayoutConstraint *marketStockLeading =
    [self.stockQtyLabel.leadingAnchor constraintEqualToAnchor:self.textStack.leadingAnchor];
    NSLayoutConstraint *marketStockBottom =
    [self.stockQtyLabel.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:-16.0];

    stockHeight.active = YES;

    // =========================
    // Layout Groups
    // =========================

    self.fullWidthConstraints = @[
        imgTop, imgLeading, imgTrailing, imgBottom,
        self.textStackTopConstraint, self.textStackLeadingConstraint, self.textStackBottomConstraint,
        self.discountValueTrailingConstraint, self.discountValueTopConstraint,
        self.actionBarTrailingConstraint, self.actionBarBottomConstraint,
        addTrailing, addBottom, stepperTrailing, stepperBottom,
        stockTop, stockTrailing
    ];

    self.squareConstraints =
    self.pintrestConstraints =
    self.verticalConstraints =
    self.fullWidthConstraints;

    self.marketConstraints = @[
        marketImgTop, marketImgLeading, marketImgTrailing, self.marketImageHeightConstraint,
        marketTxtTop, marketTxtLeading, marketTxtTrailing,
        marketDiscountTop, marketDiscountLeading,
        marketActionTop, marketActionTrailing,
        marketAddTop, marketAddLeading, marketAddTrailing,
        marketStepperTop, marketStepperLeading, marketStepperTrailing,
        marketStockTop, marketStockLeading, marketStockBottom
    ];

    self.serviceConstraints = @[
        marketImgTop, marketImgLeading, marketImgTrailing, self.marketImageHeightConstraint,
        marketTxtTop, marketTxtLeading, marketTxtTrailing,
        marketActionTop, serviceActionLeading,
        serviceTxtBottom
    ];

    self.carouselConstraints = @[
        imgTop, imgLeading, imgTrailing, imgBottom
    ];

    // Default mode
    [self activateConstraintsForMode:PPCellLayoutModePinterest];
}

- (void)pp_updateBottomOverlayTextWidthForDiscountBadgeVisible:(BOOL)isVisible
{
    self.textStackTrailingToEdgeConstraint.active = !isVisible;
    self.textStackTrailingToDiscountConstraint.active = isVisible;
}

- (BOOL)pp_isServiceContext
{
    return self.context == PPCellForServices;
}

- (UIColor *)pp_serviceAccentColorForViewModel:(PPUniversalCellViewModel *)vm
{
    return AppPrimaryClr ?: [UIColor colorWithRed:0.89 green:0.31 blue:0.48 alpha:1.0];
}

- (NSString *)pp_serviceSymbolNameForViewModel:(PPUniversalCellViewModel *)vm
{
    ServiceModel *service = [self pp_resolvedServiceFromViewModel:vm];
    NSString *normalized = [[NSString stringWithFormat:@"%@ %@ %@",
                             PPSafeString(service.category),
                             PPSafeString(service.title),
                             PPSafeString(service.desc)] lowercaseString];

    if (service.type == ServiceTypeTraining || [normalized containsString:@"train"] || [normalized containsString:@"تدريب"]) {
        return @"figure.walk";
    }
    if (service.type == ServiceTypeGrooming ||
        [normalized containsString:@"groom"] ||
        [normalized containsString:@"clean"] ||
        [normalized containsString:@"تنظيف"] ||
        [normalized containsString:@"قص"]) {
        return @"scissors";
    }
    if ([normalized containsString:@"hotel"] ||
        [normalized containsString:@"boarding"] ||
        [normalized containsString:@"استضافة"]) {
        return @"house.fill";
    }
    if ([normalized containsString:@"vet"] ||
        [normalized containsString:@"doctor"] ||
        [normalized containsString:@"طبيب"]) {
        return @"cross.case.fill";
    }
    return @"star.fill";
}

- (void)pp_updateServiceLayoutMetrics
{
    BOOL isService = [self pp_isServiceContext];
    self.bottomOverlayLeadingConstraint.constant = isService ? PPServiceOverlayFloatingInset : 0.0;
    self.bottomOverlayTrailingConstraint.constant = isService ? -PPServiceOverlayFloatingInset : 0.0;
    self.bottomOverlayBottomConstraint.constant = isService ? -PPServiceOverlayFloatingInset : 0.0;

    self.textStackTopConstraint.constant = isService ? PPServiceTextInset : 12.0;
    self.textStackBottomConstraint.constant = isService ? -PPServiceBottomTextInset : -PPAdsCellBottomInset;
    self.textStackBottomConstraint.priority = isService ? UILayoutPriorityRequired : UILayoutPriorityDefaultLow;
    self.textStackLeadingConstraint.constant = isService ? PPServiceTextInset : PPAdsCellSideInset;
    self.textStackTrailingToEdgeConstraint.constant = isService ? -PPServiceTextInset : -PPAdsCellSideInset;
    self.textStackTrailingToDiscountConstraint.constant = isService ? -12.0 : -10.0;
    self.discountValueTopConstraint.constant = isService ? 14.0 : 12.0;
    self.discountValueTrailingConstraint.constant = isService ? -PPServiceTextInset : -PPAdsCellSideInset;

    self.actionBarBottomConstraint.active = !isService;
    self.actionBarTopConstraint.active = isService;
    self.actionBarTrailingConstraint.active = !isService;
    self.actionBarRightConstraint.active = isService;
    [self pp_updateTopMetaRowArrangementForService:isService];
    self.topMetaRow.semanticContentAttribute = UISemanticContentAttributeUnspecified;
    self.topMetaRow.spacing = isService ? 8.0 : 10.0;

    self.bottomOverlay.layer.cornerRadius = isService ? PPServiceOverlayCornerRadius : 0.0;
    self.bottomOverlay.layer.borderWidth = isService ? 1.0 : 0.0;
    self.bottomOverlay.layer.borderColor = UIColor.clearColor.CGColor;
    self.bottomOverlay.layer.masksToBounds = NO;
}

- (void)pp_updateTopMetaRowArrangementForService:(BOOL)isService
{
    if (!self.topMetaRow || !self.locationStack || !self.topMetaSpacer || !self.reasonBadgeStack) {
        return;
    }

    if (isService) {
        if (self.reasonBadgeStack.superview == self.topMetaRow) {
            [self.topMetaRow removeArrangedSubview:self.reasonBadgeStack];
        }
        if (self.reasonBadgeStack.superview != self.card) {
            [self.card addSubview:self.reasonBadgeStack];
        }
    } else {
        if (self.reasonBadgeStack.superview != self.topMetaRow) {
            [self.topMetaRow insertArrangedSubview:self.reasonBadgeStack atIndex:0]; // Standard order
        }
    }

    NSArray<UIView *> *desiredOrder = isService
        ? @[self.topMetaSpacer, self.locationStack]
        : @[self.locationStack, self.topMetaSpacer, self.reasonBadgeStack];

    if ([self.topMetaRow.arrangedSubviews isEqualToArray:desiredOrder]) {
        return;
    }

    NSArray<UIView *> *currentSubviews = self.topMetaRow.arrangedSubviews.copy;
    for (UIView *subview in currentSubviews) {
        [self.topMetaRow removeArrangedSubview:subview];
    }

    for (UIView *subview in desiredOrder) {
        [self.topMetaRow addArrangedSubview:subview];
    }
}

- (void)pp_updateImageScrimAppearanceForViewModel:(PPUniversalCellViewModel *)vm
{
    CAGradientLayer *gradientLayer = (CAGradientLayer *)self.imageScrimView.layer;
    if ([self pp_isServiceContext]) {
        self.imageScrimView.hidden = YES;
        return;
    }

    BOOL isAds = (self.context == PPCellForAds);
    self.imageScrimView.hidden = !isAds;
    gradientLayer.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:0.26].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.06].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.20].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.66].CGColor
    ];
    gradientLayer.locations = @[@0.0, @0.18, @0.56, @1.0];
    gradientLayer.startPoint = CGPointMake(0.5, 0.0);
    gradientLayer.endPoint = CGPointMake(0.5, 1.0);
}

- (void)pp_updateBottomOverlayMaterialForViewModel:(PPUniversalCellViewModel *)vm
{
    BOOL isService = [self pp_isServiceContext];
    UIColor *accentColor = [self pp_serviceAccentColorForViewModel:vm];
    NSMutableArray<UIView *> *plainViews = [NSMutableArray array];
    UIVisualEffectView *blurView = nil;

    for (UIView *subview in self.bottomOverlay.subviews) {
        if ([subview isKindOfClass:UIVisualEffectView.class]) {
            blurView = (UIVisualEffectView *)subview;
        } else {
            [plainViews addObject:subview];
        }
    }

    if (@available(iOS 13.0, *)) {
        blurView.effect = [UIBlurEffect effectWithStyle:(isService ? UIBlurEffectStyleSystemThinMaterialLight
                                                                   : UIBlurEffectStyleSystemUltraThinMaterialDark)];
        blurView.alpha = isService ? 0.97 : 0.82;
    }

    UIView *tintView = plainViews.count > 0 ? plainViews.firstObject : nil;
    UIView *hairlineView = plainViews.count > 1 ? plainViews.lastObject : nil;
    tintView.backgroundColor = isService
        ? [UIColor colorWithWhite:1.0 alpha:0.88]
        : [UIColor colorWithWhite:0.0 alpha:0.08];
    hairlineView.backgroundColor = isService
        ? [accentColor colorWithAlphaComponent:0.30]
        : [UIColor colorWithWhite:1.0 alpha:0.08];
    self.bottomOverlay.layer.borderColor = isService
        ? [accentColor colorWithAlphaComponent:0.18].CGColor
        : UIColor.clearColor.CGColor;

    CAGradientLayer *gradientLayer = nil;
    for (CALayer *sublayer in self.bottomOverlay.layer.sublayers) {
        if ([sublayer isKindOfClass:CAGradientLayer.class]) {
            gradientLayer = (CAGradientLayer *)sublayer;
            break;
        }
    }

    if (gradientLayer) {
        gradientLayer.colors = isService ? @[
            (id)[UIColor colorWithWhite:1.0 alpha:0.02].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.20].CGColor,
            (id)[accentColor colorWithAlphaComponent:0.12].CGColor
        ] : @[
            (id)[UIColor colorWithWhite:0.0 alpha:0.00].CGColor,
            (id)[UIColor colorWithWhite:0.0 alpha:0.06].CGColor,
            (id)[UIColor colorWithWhite:0.0 alpha:0.22].CGColor
        ];
        gradientLayer.locations = isService ? @[@0.0, @0.52, @1.0] : @[@0.0, @0.35, @1.0];
        gradientLayer.startPoint = CGPointMake(0.5, 0.0);
        gradientLayer.endPoint = CGPointMake(0.5, 1.0);
    }
}

- (void)pp_updateServiceOverlayMaskIfNeeded
{
    if ([self pp_isServiceContext] && !self.bottomOverlay.hidden) {
        [self applyCornerMaskToView:self.bottomOverlay
                                 tl:PPServiceOverlayCornerRadius
                                 tr:PPServiceOverlayCornerRadius
                                 bl:PPServiceOverlayCornerRadius
                                 br:PPServiceOverlayCornerRadius];
    } else {
        self.bottomOverlay.layer.mask = nil;
    }
}

- (void)pp_applyLayoutAppearanceForMarket:(BOOL)isMarket
{
    BOOL isAds = (self.context == PPCellForAds);
    BOOL isService = [self pp_isServiceContext];
    BOOL usesCatalogCardLayout = isMarket || isService;
    
    self.bottomOverlay.hidden = usesCatalogCardLayout;
    
    self.imageView.backgroundColor = usesCatalogCardLayout
        ? [UIColor colorWithWhite:0.97 alpha:1.0]
        : UIColor.clearColor;
    
    self.imageView.layer.cornerRadius = usesCatalogCardLayout ? 16.0 : PPCornerCard;
    self.imageView.layer.borderColor = usesCatalogCardLayout
        ? [[UIColor labelColor] colorWithAlphaComponent:0.04].CGColor
        : UIColor.clearColor.CGColor;
    self.imageView.layer.borderWidth = 1.0;
    self.imageView.contentMode = isMarket ? UIViewContentModeScaleAspectFit : UIViewContentModeScaleAspectFill;
    
    [self pp_updateServiceLayoutMetrics];
    [self pp_updateImageScrimAppearanceForViewModel:self.vm];
    [self pp_updateBottomOverlayMaterialForViewModel:self.vm];
    
    self.bottomOverlay.backgroundColor = isService
        ? UIColor.clearColor
        : ((isAds && !isMarket)
           ? [UIColor colorWithWhite:1.0 alpha:0.04]
           : UIColor.clearColor);
    
    self.textStack.spacing = isMarket ? 10.0 : (isService ? 10.0 : (isAds ? 4.0 : 6.0));
    self.titleLabel.numberOfLines = (isAds ? 1 : 2);
    self.subtitleLabel.numberOfLines = isService ? 2 : 1;
    
    self.actionBar.axis = usesCatalogCardLayout ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    self.actionBar.spacing = usesCatalogCardLayout ? 10.0 : (isAds ? 9.0 : 10.0);
    
    self.priceStack.spacing = isService ? 8.0 : 10.0;
    self.priceStack.distribution = UIStackViewDistributionFill;
    self.priceStack.alignment = UIStackViewAlignmentFirstBaseline;
    
    self.titleLabel.font = [self pp_titleFontForCurrentContext];
    self.subtitleLabel.font = isMarket
        ? [GM MidFontWithSize:13.0]
        : (isService ? [GM MidFontWithSize:13.0] : (isAds ? [GM MidFontWithSize:12.5] : [GM MidFontWithSize:15.0]));
        
    if (@available(iOS 11.0, *)) {
        if (isService) {
            [self.textStack setCustomSpacing:6.0 afterView:self.titleLabel];
            [self.textStack setCustomSpacing:12.0 afterView:self.subtitleLabel];
            [self.textStack setCustomSpacing:14.0 afterView:self.priceStack];
        } else {
            [self.textStack setCustomSpacing:(isMarket ? 8.0 : (isAds ? 2.0 : 4.0)) afterView:self.titleLabel];
            [self.textStack setCustomSpacing:(isMarket ? 10.0 : (isAds ? 2.0 : 6.0)) afterView:self.subtitleLabel];
            [self.textStack setCustomSpacing:0.0 afterView:self.priceStack];
        }
    }
    
    self.addButtonWidthConstraint.active = !isMarket;
    self.card.layer.borderWidth = (isMarket || isService) ? 0.8 : (isAds ? 1.0 : 0.75);
    
    if (isMarket) {
        self.card.layer.borderColor = [[UIColor labelColor] colorWithAlphaComponent:0.05].CGColor;
        self.card.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.98] ?: UIColor.whiteColor;
    } else if (isService) {
        self.card.layer.borderColor = [[UIColor labelColor] colorWithAlphaComponent:0.05].CGColor;
        self.card.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.98];
    } else if (isAds) {
        self.card.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08].CGColor;
        self.card.backgroundColor = UIColor.secondarySystemBackgroundColor;
    } else {
        self.card.layer.borderColor = [[UIColor labelColor] colorWithAlphaComponent:0.04].CGColor;
        self.card.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.98] ?: UIColor.whiteColor;
    }
    
    if (!isService) {
        self.reasonBadgeStack.layer.shadowOpacity = 0.0;
        self.reasonBadgeStack.layer.shadowRadius = 0.0;
        self.reasonBadgeStack.layer.shadowOffset = CGSizeZero;

        self.favButton.layer.borderWidth = 0.0;
        self.favButton.layer.borderColor = UIColor.clearColor.CGColor;
        self.favButton.layer.shadowOpacity = 0.06;
        self.favButton.layer.shadowRadius = 8.0;
        self.favButton.layer.shadowOffset = CGSizeMake(0, 4.0);

        NSArray<UIButton *> *sharedButtons = @[self.moreOptionsButton, self.shareButton];
        for (UIButton *button in sharedButtons) {
            button.layer.borderWidth = 0.0;
            button.layer.borderColor = UIColor.clearColor.CGColor;
            button.layer.shadowOpacity = 0.06;
            button.layer.shadowRadius = 8.0;
            button.layer.shadowOffset = CGSizeMake(0, 4.0);
            
            if (@available(iOS 15.0, *)) {
                UIButtonConfiguration *config = button.configuration ?: [UIButtonConfiguration filledButtonConfiguration];
                config.baseBackgroundColor = [AppForgroundColr colorWithAlphaComponent:0.8];
                config.baseForegroundColor = UIColor.labelColor;
                config.background.cornerRadius = 19.0;
                config.preferredSymbolConfigurationForImage =
                [UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                weight:UIImageSymbolWeightMedium
                                                                 scale:UIImageSymbolScaleMedium];
                button.configuration = config;
            } else {
                button.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.8];
                button.tintColor = UIColor.labelColor;
            }
        }
    }
    [self pp_updateBottomOverlayTextWidthForDiscountBadgeVisible:(isAds && !isMarket && !self.discountValueLabel.hidden)];
}

- (UIColor *)pp_primaryTitleColorForCurrentContext
{
    if (self.context == PPCellForMarket || [self pp_isServiceContext]) {
        return UIColor.labelColor;
    }
    return [UIColor colorWithWhite:1.0 alpha:0.98];
}

- (UIColor *)pp_secondaryTextColorForCurrentContext
{
    if (self.context == PPCellForMarket || [self pp_isServiceContext]) {
        return UIColor.secondaryLabelColor;
    }
    return [UIColor colorWithWhite:1.0 alpha:0.72];
}

- (UIColor *)pp_primaryPriceColorForCurrentContext
{
    if (self.context == PPCellForMarket) {
        return UIColor.labelColor;
    }
    if ([self pp_isServiceContext]) {
        return AppPrimaryClr ?: UIColor.labelColor;
    }
    return [UIColor colorWithWhite:1.0 alpha:0.98];
}

- (UIColor *)pp_mutedPriceColorForCurrentContext
{
    if (self.context == PPCellForMarket || [self pp_isServiceContext]) {
        return [UIColor.secondaryLabelColor colorWithAlphaComponent:0.85];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.64];
}

- (UIFont *)pp_titleFontForCurrentContext
{
    if (self.context == PPCellForMarket) {
        return [GM boldFontWithSize:15.0];
    }
    if ([self pp_isServiceContext]) {
        return [GM boldFontWithSize:15.5];
    }
    return [GM boldFontWithSize:16.0];
}

- (CGFloat)pp_bottomOverlayHeightForLayoutMode:(PPManagerCellLayoutMode)layoutMode
{
    switch (layoutMode) {
        case PPCellLayoutModeFullWidth:
            return PPAdsCellOverlayHeightFullWidth;
        case PPCellLayoutModeVertical:
        case PPCellLayoutModePinterest:
            return PPAdsCellOverlayHeightRegular;
        case PPCellLayoutModeSquare:
        default:
            return PPAdsCellOverlayHeightSquare;
    }
}

- (CGFloat)pp_bottomOverlayHeightForServiceLayoutMode:(PPManagerCellLayoutMode)layoutMode
{
    switch (layoutMode) {
        case PPCellLayoutModeFullWidth:
            return 134.0;
        case PPCellLayoutModeVertical:
        case PPCellLayoutModePinterest:
            return 130.0;
        case PPCellLayoutModeSquare:
        default:
            return 128.0;
    }
}

- (BOOL)pp_isSkeletonViewModel:(PPUniversalCellViewModel *)vm
{
    return vm.ModelObject == nil &&
    vm.imageURL.length == 0 &&
    vm.title.length == 0 &&
    vm.subtitle.length == 0 &&
    vm.price == nil &&
    vm.finalPrice == nil;
}

- (nullable PetAd *)pp_resolvedPetAdFromViewModel:(PPUniversalCellViewModel *)vm
{
    if ([vm.ModelObject isKindOfClass:PetAd.class]) {
        return (PetAd *)vm.ModelObject;
    }
    return nil;
}

- (nullable ServiceModel *)pp_resolvedServiceFromViewModel:(PPUniversalCellViewModel *)vm
{
    if ([vm.ModelObject isKindOfClass:ServiceModel.class]) {
        return (ServiceModel *)vm.ModelObject;
    }
    return nil;
}

- (NSString *)pp_shortAgeTextFromMonths:(NSNumber *)months
{
    NSInteger totalMonths = MAX(months.integerValue, 0);
    if (totalMonths <= 0) {
        return @"";
    }

    NSString *monthsUnit = PPAdsLocalizedString(@"pet_age_months_short", @"mo");
    NSString *yearsUnit = PPAdsLocalizedString(@"pet_age_years_short", @"yr");
    if (totalMonths >= 12) {
        NSInteger years = MAX(1, totalMonths / 12);
        return [NSString stringWithFormat:@"%ld %@", (long)years, yearsUnit];
    }
    return [NSString stringWithFormat:@"%ld %@", (long)totalMonths, monthsUnit];
}

- (NSString *)pp_adsSubtitleTextForViewModel:(PPUniversalCellViewModel *)vm
{
    PetAd *ad = [self pp_resolvedPetAdFromViewModel:vm];
    if (!ad) {
        return PPSafeString(vm.subtitle);
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *descriptor = @"";
    if (ad.subcategory > 0) {
        NSArray *subKinds = [MKM getSubKindArray:ad.category] ?: @[];
        descriptor = PPSafeString([SubKindModel getSubKindName:ad.subcategory subKindsArrayLocal:subKinds]);
    }
    if (descriptor.length == 0 && ad.category > 0) {
        descriptor = PPSafeString([MainKindsModel kindNameForID:ad.category]);
    }
    if (descriptor.length > 0) {
        [parts addObject:descriptor];
    }

    NSString *ageText = [self pp_shortAgeTextFromMonths:ad.petAgeMonths];
    if (ageText.length > 0) {
        [parts addObject:ageText];
    }

    NSString *genderKey = ad.isFemale ? @"Female" : @"Male";
    NSString *genderText = PPAdsLocalizedString(genderKey, genderKey);
    if (genderText.length > 0) {
        [parts addObject:genderText];
    }

    if (parts.count == 0) {
        return PPSafeString(vm.subtitle);
    }
    return [parts componentsJoinedByString:@" • "];
}

- (NSString *)pp_serviceSubtitleTextForViewModel:(PPUniversalCellViewModel *)vm
{
    ServiceModel *service = [self pp_resolvedServiceFromViewModel:vm];
    if (!service) {
        return PPSafeString(vm.subtitle);
    }

    NSString *descriptionText = [[PPSafeString(service.desc)
                                  stringByReplacingOccurrencesOfString:@"\n"
                                  withString:@" "]
                                 stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (descriptionText.length > 0) {
        return descriptionText;
    }

    NSString *categoryText = PPSafeString(service.category);
    if (categoryText.length > 0) {
        return categoryText;
    }

    return PPSafeString(vm.subtitle);
}

- (void)pp_setPriceText:(NSString *)text
                  color:(UIColor *)color
                   font:(UIFont *)font
{
    NSString *resolvedText = PPSafeString(text);
    self.priceLabel.attributedText =
    [[NSAttributedString alloc] initWithString:resolvedText
                                    attributes:@{
        NSFontAttributeName : font,
        NSForegroundColorAttributeName : color
    }];
    self.discountLabel.attributedText = nil;
    self.discountLabel.hidden = YES;
}

- (BOOL)pp_isFeaturedAd:(nullable PetAd *)ad
{
    return ad.priorityScore.doubleValue > 0.01;
}

- (BOOL)pp_isTrendingAd:(nullable PetAd *)ad
{
    if (!ad) return NO;
    if ([self pp_isFeaturedAd:ad]) return NO;
    return ad.rankScore.doubleValue > 0.01 ||
    ad.viewsCount.integerValue >= 50 ||
    ad.favoritesCount.integerValue >= 4;
}

- (void)pp_configureAdsStatusBadgeForViewModel:(PPUniversalCellViewModel *)vm
{
    if (self.context != PPCellForAds || [self pp_isSkeletonViewModel:vm]) {
        self.reasonBadgeStack.hidden = YES;
        self.reasonBadgeLabel.text = @"";
        self.reasonBadgeIconView.image = nil;
        return;
    }

    PetAd *ad = [self pp_resolvedPetAdFromViewModel:vm];
    NSString *badgeText = @"";
    NSString *iconName = @"";
    UIColor *backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.34];
    UIColor *borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.14];
    UIColor *textColor = UIColor.whiteColor;

    BOOL isSold = ad.isSold || ad.status == PetAdStatusSold;
    if (isSold) {
        badgeText = PPAdsLocalizedString(@"Sold", @"Sold");
        iconName = @"checkmark.seal.fill";
        backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.48];
        borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10];
    } else if (PPSafeString(vm.contextualReasonText).length > 0) {
        badgeText = PPSafeString(vm.contextualReasonText);
        iconName = PPSafeString(vm.contextualReasonIconName);
        if (iconName.length == 0) {
            iconName = [badgeText isEqualToString:PPAdsLocalizedString(@"home_suggestion_reason_nearby", @"Near you")]
                ? @"location.fill"
                : @"sparkles";
        }
        if ([badgeText isEqualToString:PPAdsLocalizedString(@"home_suggestion_reason_nearby", @"Near you")]) {
            backgroundColor = [(AppPrimaryClr ?: UIColor.systemPinkColor) colorWithAlphaComponent:0.92];
            borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.18];
        }
    } else if ([self pp_isFeaturedAd:ad]) {
        badgeText = PPAdsLocalizedString(@"home_nav_search_trending", @"Trending");
        iconName = @"sparkles";
        backgroundColor = [(AppPrimaryClr ?: UIColor.systemOrangeColor) colorWithAlphaComponent:0.92];
        borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.20];
    } else if ([self pp_isTrendingAd:ad]) {
        badgeText = PPAdsLocalizedString(@"home_nav_search_trending", @"Trending");
        iconName = @"chart.line.uptrend.xyaxis";
    } else if (ad.isNew) {
        badgeText = PPAdsLocalizedString(@"New", @"New");
        iconName = @"clock.badge.checkmark";
    }

    self.reasonBadgeLabel.text = badgeText;
    self.reasonBadgeLabel.textColor = textColor;
    self.reasonBadgeStack.backgroundColor = backgroundColor;
    self.reasonBadgeStack.layer.borderColor = borderColor.CGColor;
    self.reasonBadgeStack.hidden = (badgeText.length == 0);

    if (badgeText.length > 0) {
        self.reasonBadgeIconView.image =
        [UIImage pp_symbolNamed:iconName
                      pointSize:11
                         weight:UIImageSymbolWeightBold
                          scale:UIImageSymbolScaleSmall
                        palette:@[textColor]
                   makeTemplate:YES];
    } else {
        self.reasonBadgeIconView.image = nil;
    }
}

- (void)pp_applyAdsStateForViewModel:(PPUniversalCellViewModel *)vm
{
    if (self.context != PPCellForAds) {
        return;
    }

    BOOL isSkeleton = [self pp_isSkeletonViewModel:vm];
    PetAd *ad = [self pp_resolvedPetAdFromViewModel:vm];
    BOOL isSold = ad.isSold || ad.status == PetAdStatusSold;
    BOOL isFeatured = [self pp_isFeaturedAd:ad];
    BOOL hasImageSource = vm.imageURL.length > 0 || vm.image != nil;
    UIColor *baseBorder = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    UIColor *featuredBorder = [(AppPrimaryClr ?: UIColor.systemOrangeColor) colorWithAlphaComponent:0.24];
    UIColor *favoritedBorder = [[UIColor systemPinkColor] colorWithAlphaComponent:0.20];

    self.card.layer.borderWidth = isFeatured ? 1.15 : 1.0;
    self.card.layer.borderColor = (isFeatured
                                   ? featuredBorder
                                   : (ad.isFavorite ? favoritedBorder : baseBorder)).CGColor;
    self.layer.shadowColor = (isFeatured ? (AppPrimaryClr ?: UIColor.systemOrangeColor) : UIColor.blackColor).CGColor;
    self.layer.shadowOpacity = isFeatured ? 0.18 : (isSold ? 0.08 : 0.12);
    self.layer.shadowRadius = isFeatured ? 22.0 : 18.0;
    self.layer.shadowOffset = CGSizeMake(0, isFeatured ? 12.0 : 10.0);
    self.imageView.alpha = isSold ? 0.92 : 1.0;
    self.imageScrimView.alpha = isSkeleton ? 0.76 : 1.0;
    self.bottomOverlay.alpha = isSold ? 0.98 : 1.0;
    self.actionBar.alpha = isSkeleton ? 0.0 : 1.0;

    if (!hasImageSource) {
        self.imageView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
        self.imageScrimView.alpha = 0.82;
    }

    if (isSold) {
        [self pp_setPriceText:PPAdsLocalizedString(@"Sold", @"Sold")
                        color:[UIColor colorWithWhite:1.0 alpha:0.96]
                         font:[GM boldFontWithSize:17.0]];
        self.discountValueLabel.hidden = YES;
        self.discountLabel.hidden = YES;
        [self pp_updateBottomOverlayTextWidthForDiscountBadgeVisible:NO];
    }
}

- (void)pp_configureServiceBadgeForViewModel:(PPUniversalCellViewModel *)vm
{
    if (![self pp_isServiceContext] || [self pp_isSkeletonViewModel:vm]) {
        self.reasonBadgeStack.hidden = YES;
        self.reasonBadgeLabel.text = @"";
        self.reasonBadgeIconView.image = nil;
        return;
    }

    ServiceModel *service = [self pp_resolvedServiceFromViewModel:vm];
    NSString *badgeText = PPSafeString(service.category);
    if (badgeText.length == 0) {
        badgeText = kLang(@"service_view_default_title");
        if (badgeText.length == 0) {
            badgeText = @"Service";
        }
    }

    UIColor *tintColor = [self pp_serviceAccentColorForViewModel:vm];
    self.reasonBadgeLabel.font = [GM boldFontWithSize:10.5] ?: [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold];
    self.reasonBadgeLabel.text = badgeText;
    self.reasonBadgeLabel.textColor = tintColor;
    self.reasonBadgeStack.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.86];
    self.reasonBadgeStack.layer.borderColor = [tintColor colorWithAlphaComponent:0.18].CGColor;
    self.reasonBadgeStack.layer.shadowColor = tintColor.CGColor;
    self.reasonBadgeStack.layer.shadowOpacity = 0.10;
    self.reasonBadgeStack.layer.shadowRadius = 10.0;
    self.reasonBadgeStack.layer.shadowOffset = CGSizeMake(0, 4.0);
    self.reasonBadgeStack.hidden = NO;
    self.reasonBadgeIconView.image =
    [UIImage pp_symbolNamed:[self pp_serviceSymbolNameForViewModel:vm]
                  pointSize:11
                     weight:UIImageSymbolWeightSemibold
                      scale:UIImageSymbolScaleSmall
                    palette:@[tintColor]
               makeTemplate:YES];
}

- (void)pp_applyServiceStateForViewModel:(PPUniversalCellViewModel *)vm
{
    if (![self pp_isServiceContext]) {
        return;
    }

    BOOL isSkeleton = [self pp_isSkeletonViewModel:vm];
    BOOL hasImageSource = vm.imageURL.length > 0 || vm.image != nil;
    UIColor *accentColor = [self pp_serviceAccentColorForViewModel:vm];

    self.card.layer.borderWidth = 0.75;
    self.card.layer.borderColor = [[UIColor labelColor] colorWithAlphaComponent:0.04].CGColor;
    self.imageView.alpha = 1.0;
    self.imageScrimView.alpha = 1.0;
    self.bottomOverlay.alpha = 1.0;
    self.actionBar.alpha = isSkeleton ? 0.0 : 1.0;
    self.reasonBadgeStack.alpha = isSkeleton ? 0.0 : 1.0;
    self.serviceDetailsButton.alpha = isSkeleton ? 0.0 : 1.0;
    self.reasonBadgeStack.layer.shadowOpacity = 0.06;
    self.reasonBadgeStack.layer.shadowRadius = 6.0;
    self.reasonBadgeStack.layer.shadowOffset = CGSizeMake(0, 3.0);

    self.favButton.layer.borderWidth = 0.0;
    self.favButton.layer.borderColor = UIColor.clearColor.CGColor;
    self.favButton.layer.shadowOpacity = 0.08;
    self.favButton.layer.shadowRadius = 6.0;
    self.favButton.layer.shadowOffset = CGSizeMake(0, 3.0);

    NSArray<UIButton *> *serviceButtons = @[self.moreOptionsButton, self.shareButton];
    for (UIButton *button in serviceButtons) {
        button.layer.borderWidth = 0.0;
        button.layer.borderColor = UIColor.clearColor.CGColor;
        button.layer.shadowOpacity = 0.08;
        button.layer.shadowRadius = 6.0;
        button.layer.shadowOffset = CGSizeMake(0, 3.0);
        if (@available(iOS 15.0, *)) {
            UIButtonConfiguration *config = button.configuration ?: [UIButtonConfiguration filledButtonConfiguration];
            config.baseBackgroundColor = [AppForgroundColr colorWithAlphaComponent:0.72];
            config.baseForegroundColor = UIColor.labelColor;
            config.background.cornerRadius = 19.0;
            config.preferredSymbolConfigurationForImage =
            [UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                            weight:UIImageSymbolWeightMedium
                                                             scale:UIImageSymbolScaleMedium];
            button.configuration = config;
        } else {
            button.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.72];
            button.tintColor = UIColor.labelColor;
        }
    }

    if (!hasImageSource) {
        self.imageView.backgroundColor = AppBackgroundClr ?: [UIColor secondarySystemBackgroundColor];
        self.imageView.tintColor = [accentColor colorWithAlphaComponent:0.18];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
}

- (void)pp_applyServiceShadow
{
    UIColor *accentColor = [self pp_serviceAccentColorForViewModel:self.vm];
    self.layer.masksToBounds = NO;
    self.clipsToBounds = NO;
    self.layer.shadowColor = [accentColor colorWithAlphaComponent:0.34].CGColor;
    self.layer.shadowOpacity = 0.16;
    self.layer.shadowRadius = 24.0;
    self.layer.shadowOffset = CGSizeMake(0, 14.0);
}

- (void)activateConstraintsForMode:(PPManagerCellLayoutMode)mode {
    
   // NSLog(@"[UniversalCell][Layout] mode=%ld context=%ld",
      //    (long)mode,
      //    (long)self.context);
    
    
    // Disable all
    for (NSLayoutConstraint *c in self.fullWidthConstraints) c.active = NO;
    for (NSLayoutConstraint *c in self.verticalConstraints) c.active = NO;
    for (NSLayoutConstraint *c in self.squareConstraints) c.active = NO;
    for (NSLayoutConstraint *c in self.pintrestConstraints) c.active = NO;
    for (NSLayoutConstraint *c in self.marketConstraints) c.active = NO;
    for (NSLayoutConstraint *c in self.serviceConstraints) c.active = NO;
    for (NSLayoutConstraint *c in self.carouselConstraints) c.active = NO;

    self.reasonBadgeServiceCenterYConstraint.active = NO;
    self.reasonBadgeServiceTrailingConstraint.active = NO;

    self.layoutMode = mode;
    [self.discountValueLabel sizeToFit];
    
    /*
     if (isAds) {
     
         self.titleLabel.hidden = NO;
         self.priceLabel.hidden = NO;
         self.subtitleLabel.hidden = NO;
         
     }
     
     if (isService) {
         self.titleLabel.hidden = NO;
         self.priceLabel.hidden = NO;
     }
     
     if (isMarket) {
         self.titleLabel.hidden = YES;
         self.priceLabel.hidden = NO;
     }
     */
    
    BOOL isMarket = (self.context == PPCellForMarket || self.context == PPCellForFood);
    BOOL isService = [self pp_isServiceContext];
    
    
    [self pp_applyLayoutAppearanceForMarket:isMarket];
    self.bottomOverlayHeightConstraint.constant = (self.context == PPCellForAds)
        ? [self pp_bottomOverlayHeightForLayoutMode:mode]
        : (isService ? [self pp_bottomOverlayHeightForServiceLayoutMode:mode] : 74.0);

    if(isMarket)
    {
        for (NSLayoutConstraint *c in self.marketConstraints) c.active = YES;
        
        self.titleLabel.hidden = YES;
        self.priceLabel.hidden = NO;
    }
    else if (isService)
    {
        for (NSLayoutConstraint *c in self.serviceConstraints) c.active = YES;
        self.reasonBadgeServiceCenterYConstraint.active = YES;
        self.reasonBadgeServiceTrailingConstraint.active = YES;
        
        self.titleLabel.hidden = NO;
        self.subtitleLabel.hidden = NO;
        self.priceLabel.hidden = NO;
    }
    else
    {
        switch (mode) {
            case PPCellLayoutModeFullWidth:
                for (NSLayoutConstraint *c in self.fullWidthConstraints) c.active = YES;
                 break;

            case PPCellLayoutModeVertical:
                for (NSLayoutConstraint *c in self.verticalConstraints) c.active = YES;
                 break;
                
            case PPCellLayoutModePinterest:
                for (NSLayoutConstraint *c in self.pintrestConstraints) c.active = YES;
                 break;
                
            case PPCellLayoutModeMarket:
                for (NSLayoutConstraint *c in self.marketConstraints) c.active = YES;
                 break;

            case PPCellLayoutModeSquare:
            default:
                for (NSLayoutConstraint *c in self.squareConstraints) c.active = YES;
                 break;
        }
        
        self.titleLabel.hidden = NO;
        self.priceLabel.hidden = NO;
        self.subtitleLabel.hidden = NO;
    }
    [self pp_updateServiceLayoutMetrics];
    if (isService) {
        self.actionBarBottomConstraint.active = NO;
        self.actionBarTopConstraint.active = NO;
        self.actionBarTrailingConstraint.active = NO;
        self.actionBarRightConstraint.active = NO;
    }
    [self pp_updateServiceOverlayMaskIfNeeded];
   // [self setNeedsUpdateConstraints];
   // [self layoutIfNeeded];
}




#pragma mark - 🧠 Universal Model Builders

#pragma mark - Configure
- (void)applyViewModel:(PPUniversalCellViewModel *)vm
               context:(PPCellContext)context
            layoutMode:(PPManagerCellLayoutMode)layout
          discountMode:(PPDiscountStyle)discountStyle
           imageLoader:(PPImageLoader)loader {

    // 1️⃣ Try BlurHash first (if model supports it)
    
    
    self.vm = vm;
    self.context = context;
    self.discountStyle = discountStyle;
    self.loader = loader;
    PetAd *petAd = [self pp_resolvedPetAdFromViewModel:vm];
    if (context == PPCellForAds && petAd) {
        self.vm.price = petAd.price;
        self.vm.finalPrice = petAd.price ?: petAd.price;
        self.vm.discountPercent = petAd.discountPercent;
    }
    BOOL isMarket = (context == PPCellForMarket);
    BOOL isFood   = (context == PPCellForFood);
    BOOL isAds = (context == PPCellForAds);
    BOOL isService = (context == PPCellForServices);
    UIColor *primaryPriceColor = isService
        ? [self pp_serviceAccentColorForViewModel:vm]
        : [self pp_primaryPriceColorForCurrentContext];
    self.priceLabel.textColor = primaryPriceColor;
    self.serviceDetailsButton.hidden = !isService;
    self.priceLabel.adjustsFontSizeToFitWidth = isService;
    self.priceLabel.minimumScaleFactor = isService ? 0.76 : 1.0;
    self.priceLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.priceLabel setContentCompressionResistancePriority:(isService ? UILayoutPriorityDefaultLow : UILayoutPriorityRequired)
                                                     forAxis:UILayoutConstraintAxisHorizontal];
    [self.discountLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                        forAxis:UILayoutConstraintAxisHorizontal];
    [self.discountLabel setContentHuggingPriority:UILayoutPriorityRequired
                                          forAxis:UILayoutConstraintAxisHorizontal];
    BOOL isSkeleton = [self pp_isSkeletonViewModel:vm];
    NSInteger cartQty = 0;
    NSInteger stockQty = MAX(vm.itemQuantitiy, 0);
    if([vm.ModelObject isKindOfClass:PetAccessory.class])
    {
        PetAccessory *access =  (PetAccessory *)vm.ModelObject;
        stockQty = MAX(access.quantity, 0);
       cartQty =
        [CartManager.sharedManager quantityForAccessory:access];
    }
    NSInteger displayCartQty = (stockQty > 0) ? MIN(cartQty, stockQty) : 0;
    self.isEditingQuantity = NO;
    [self setQuantity:displayCartQty animated:NO];
    
    if(vm.isOwner)
    {
        self.moreOptionsButton.hidden = NO;
    }
    else
    {
        self.moreOptionsButton.hidden = YES;
    }
    // Texts
    NSString *titleText = PPSafeString(vm.title);
    if (isSkeleton && titleText.length == 0) {
        titleText = @" ";
    }
    self.titleLabel.font = [self pp_titleFontForCurrentContext];
    self.titleLabel.text = titleText;
    NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
    p.lineHeightMultiple = isService ? 0.96 : 0.92;
    p.maximumLineHeight = self.titleLabel.font.lineHeight * (isService ? 1.08 : 1.04);

    self.titleLabel.attributedText =
    [[NSAttributedString alloc] initWithString:self.titleLabel.text
                                    attributes:@{
        NSParagraphStyleAttributeName : p,
        NSFontAttributeName : self.titleLabel.font,
        NSForegroundColorAttributeName : [self pp_primaryTitleColorForCurrentContext]
    }];
    self.titleLabel.textAlignment = GM.setAligment;
    self.subtitleLabel.textAlignment = GM.setAligment;

    NSString *resolvedSubtitle = isAds
        ? [self pp_adsSubtitleTextForViewModel:vm]
        : (isService ? [self pp_serviceSubtitleTextForViewModel:vm] : PPSafeString(vm.subtitle));
    if (isSkeleton && resolvedSubtitle.length == 0) {
        resolvedSubtitle = @" ";
    }
    self.subtitleLabel.text = resolvedSubtitle;
    self.titleLabel.numberOfLines = 2;
    self.subtitleLabel.numberOfLines = 1;
    self.subtitleLabel.textColor = [self pp_secondaryTextColorForCurrentContext];
    if (isService && resolvedSubtitle.length > 0) {
        NSMutableParagraphStyle *subtitleStyle = [[NSMutableParagraphStyle alloc] init];
        subtitleStyle.lineSpacing = 2.0;
        subtitleStyle.lineBreakMode = NSLineBreakByTruncatingTail;
        subtitleStyle.alignment = GM.setAligment;
        self.subtitleLabel.attributedText =
        [[NSAttributedString alloc] initWithString:resolvedSubtitle
                                        attributes:@{
            NSParagraphStyleAttributeName : subtitleStyle,
            NSFontAttributeName : self.subtitleLabel.font,
            NSForegroundColorAttributeName : self.subtitleLabel.textColor
        }];
    } else if (isAds && resolvedSubtitle.length > 0) {
        NSMutableParagraphStyle *adsSubStyle = [[NSMutableParagraphStyle alloc] init];
        adsSubStyle.lineBreakMode = NSLineBreakByTruncatingTail;
        adsSubStyle.alignment = GM.setAligment;
        self.subtitleLabel.attributedText =
        [[NSAttributedString alloc] initWithString:resolvedSubtitle
                                        attributes:@{
            NSParagraphStyleAttributeName : adsSubStyle,
            NSFontAttributeName : self.subtitleLabel.font,
            NSForegroundColorAttributeName : self.subtitleLabel.textColor
        }];
    } else {
        self.subtitleLabel.attributedText = nil;
    }
    self.subtitleLabel.textAlignment = GM.setAligment;
    self.subtitleLabel.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    // Show subtitle for Ads and Services; hide only for Market/Food or when empty
    self.subtitleLabel.hidden = (isMarket || isFood) || (resolvedSubtitle.length == 0);

    if (isService) {
        NSString *detailsText = kLang(@"Details");
        if (detailsText.length == 0) {
            detailsText = @"Details";
        }
        if (@available(iOS 15.0, *)) {
            UIButtonConfiguration *detailsConfig = [UIButtonConfiguration filledButtonConfiguration];
            detailsConfig.title = detailsText;
            detailsConfig.cornerStyle = UIButtonConfigurationCornerStyleFixed;
            detailsConfig.baseBackgroundColor = primaryPriceColor;
            detailsConfig.baseForegroundColor = UIColor.whiteColor;
            detailsConfig.contentInsets = NSDirectionalEdgeInsetsMake(11.0, 16.0, 11.0, 16.0);
            detailsConfig.background.cornerRadius = 15.0;
            detailsConfig.titleTextAttributesTransformer =
            ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
                NSMutableDictionary *attrs = [incoming mutableCopy];
                attrs[NSFontAttributeName] = [GM boldFontWithSize:13.0];
                attrs[NSForegroundColorAttributeName] = UIColor.whiteColor;
                return attrs;
            };
            self.serviceDetailsButton.configuration = detailsConfig;
            self.serviceDetailsButton.backgroundColor = UIColor.clearColor;
        } else {
            [self.serviceDetailsButton setTitle:detailsText forState:UIControlStateNormal];
            [self.serviceDetailsButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
            self.serviceDetailsButton.titleLabel.font = [GM boldFontWithSize:13.0];
            self.serviceDetailsButton.backgroundColor = primaryPriceColor;
            self.serviceDetailsButton.contentEdgeInsets = UIEdgeInsetsMake(11.0, 16.0, 11.0, 16.0);
        }
        self.serviceDetailsButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        self.serviceDetailsButton.accessibilityLabel = detailsText;
    } else {
        self.serviceDetailsButton.configuration = nil;
        self.serviceDetailsButton.backgroundColor = UIColor.clearColor;
    }
    self.priceStack.hidden = isService;

    self.reasonBadgeStack.hidden = YES;
    self.reasonBadgeLabel.text = @"";
    self.reasonBadgeIconView.image = nil;
 
    // 4️⃣ Async load real image
    UIImage *fallbackImage = vm.image ?: vm.placeholder ?: [UIImage imageNamed:@"placeholder"];
    self.imageView.image = fallbackImage;
    if (isAds) {
        self.imageView.contentMode = (vm.image != nil || vm.imageURL.length > 0)
            ? UIViewContentModeScaleAspectFill
            : UIViewContentModeScaleAspectFit;
        self.imageView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.34];
    } else if (isService) {
        self.imageView.contentMode = (vm.image != nil || vm.imageURL.length > 0)
            ? UIViewContentModeScaleAspectFill
            : UIViewContentModeScaleAspectFit;
        self.imageView.tintColor = [primaryPriceColor colorWithAlphaComponent:0.22];
    } else {
        self.imageView.contentMode = UIViewContentModeScaleAspectFill;
        self.imageView.tintColor = nil;
    }
    if (vm.imageURL.length > 0 && loader) {
        loader(self.imageView, vm.imageURL, fallbackImage, self.card);
    } else if (vm.image != nil) {
        self.imageView.image = vm.image;
    }
    
    

    // Keep the floating controls minimal: favorite for everyone, owner menu only when needed.
    self.freshBadge.hidden = YES;
    self.offerBadge.hidden = YES;

    
    BOOL showAdd = isMarket;
    if (layout == PPCellLayoutModeFullWidth && context == PPCellForMarket) {
        [self setQuantityToLabel:self.stockQtyLabel qty:stockQty];
        [self collapseStepper:NO];
        
        [self setDiscountValueLabel];
        [self setPriceAndDiscountLabels];
        [self setQuantity:displayCartQty animated:NO];
        
    }
    else if (layout != PPCellLayoutModeFullWidth && context == PPCellForMarket) {
        [self setQuantityToLabel:self.stockQtyLabel qty:stockQty];
        [self collapseStepper:NO];
        
        [self setDiscountValueLabel];
        [self setPriceAndDiscountLabels];
     }
    else
    {
        self.stockQtyLabel.hidden = YES;
        self.discountValueLabel.hidden = YES;
        self.discountLabel.backgroundColor = UIColor.clearColor;
        self.discountLabel.layer.borderWidth = 0.0;
        self.discountLabel.layer.borderColor = UIColor.clearColor.CGColor;
        if (isAds) {
            BOOL hasNumericPrice = (self.vm.finalPrice != nil || self.vm.price != nil);
            if (hasNumericPrice) {
                [self setDiscountValueLabel];
                [self setPriceAndDiscountLabels];
            } else {
                NSString *fallbackPriceText = PPSafeString(self.vm.priceText);
                if (fallbackPriceText.length == 0 || [fallbackPriceText isEqualToString:@"0"]) {
                    fallbackPriceText = PPAdsLocalizedString(@"NoPrice", @"No price");
                }
                [self pp_setPriceText:fallbackPriceText
                                color:[self pp_primaryPriceColorForCurrentContext]
                                 font:[GM boldFontWithSize:16.0]];
            }
        } else if (isService) {
            [self setPriceToLabel:self.priceLabel
                            price:self.vm.finalPrice
                         currency:kLang(@"Rials")
                       priceColor:primaryPriceColor];
            self.discountLabel.hidden = YES;
        } else {
            [self setPriceToLabel:self.priceLabel
                            price:self.vm.finalPrice
                         currency:kLang(@"Rials")
                        priceColor:[self pp_primaryPriceColorForCurrentContext]];
        }
        [self collapseStepper:NO];
      }
    
    self.favButton.hidden = NO;
    if (!showAdd) {
        self.addButton.hidden = YES;
        self.stepperView.hidden = YES;
        
        self.stepperView.alpha = 0.0;
    } else if (self.isEditingQuantity && self.quantity > 0) {
        self.addButton.hidden = YES;
        self.stepperView.hidden = NO;
        self.stepperView.alpha = 1.0;
    } else {
        self.addButton.hidden = NO;
        self.favButton.hidden = YES;
        self.stepperView.hidden = YES;
        self.stepperView.alpha = 0.0;
    }
    if (isSkeleton) {
        self.favButton.hidden = YES;
        self.moreOptionsButton.hidden = YES;
    }
    self.actionBar.hidden = showAdd ? self.moreOptionsButton.hidden : (self.favButton.hidden && self.moreOptionsButton.hidden);
    [self updateAddButton];
    
    if(!self.favButton.hidden)
    {
        NSString *FavCollection = context == PPCellForAds ? @"favoritesAds" : context == PPCellForMarket? @"favoritesAccessories" : context == PPCellForVets ? @"favoritesVets" : @"favoritesServices" ;
        [self setFavForCollection:FavCollection andID:vm.ModelID andButton:self.favButton];
    }
    
    // 📍 Home Ads location
    
    NSString *locationText = vm.location ?: @"";
    self.adLocationLabel.text = locationText;

    BOOL hasLocation = (!isMarket && !isService && !isSkeleton && locationText.length > 0);
    self.adLocationLabel.hidden = !hasLocation;
    self.locationIconView.hidden = !hasLocation;
    
    if(hasLocation)
    {
        self.locationStack.hidden = NO;
        self.adLocationLabel.alpha = 1;
        self.locationIconView.alpha = 1;
    }
    else
    {
        self.locationStack.hidden = YES;
        self.adLocationLabel.alpha = 0;
        self.locationIconView.alpha = 0;
    }

    if (isAds) {
        [self pp_configureAdsStatusBadgeForViewModel:vm];
    } else if (isService) {
        [self pp_configureServiceBadgeForViewModel:vm];
    }
    
    if (isMarket) {
        [self applyDefaultShadow];
    } else if (isService) {
        [self applyDefaultShadow];
    } else {
        [self applyHomeAdShadow];
    }
  
    [self activateConstraintsForMode:layout];
    if (isAds) {
        [self pp_applyAdsStateForViewModel:vm];
    } else if (isService) {
        [self pp_applyServiceStateForViewModel:vm];
    }
    self.userInteractionEnabled = YES;
    self.contentView.userInteractionEnabled = YES;
    
    // ── Accessibility: Composite cell label ──
    [self pp_updateAccessibilityLabel];
    
    
    
    //self.titleLabel.hidden = NO;
    //self.priceLabel.hidden = NO;
    
   
    
}


- (void)handleTap:(UITapGestureRecognizer *)gesture {
    
    // Safety: Only respond to gesture when not tapping on a control
    //UIView *touchedView = gesture.view;
    // Defensive: Get the touch location and hit-test to find the touched subview
    CGPoint location = [gesture locationInView:self.card];
    UIView *hitView = [self.card hitTest:location withEvent:nil];
    if ([hitView isKindOfClass:[UIControl class]]) {
        // Ignore tap if user tapped a control (button, etc)
        return;
    }

    [self pp_handlePrimaryTap];
}

- (void)pp_handlePrimaryTap
{
    if (self.onTap) {
        self.onTap();
    }

    if ([self.delegate respondsToSelector:@selector(PPUniversalCell_tapCard:)]) {
        [self.delegate PPUniversalCell_tapCard:self.vm];
    }
}

- (void)pp_serviceDetailsButtonTapped
{
    [self pp_handlePrimaryTap];
}

/*
// Dedicated tap handler for card tap gesture recognizer
- (void)handleTap:(UITapGestureRecognizer *)gesture
{
    // Safety: Only respond to gesture when not tapping on a control
    UIView *touchedView = gesture.view;
    // Defensive: Get the touch location and hit-test to find the touched subview
    CGPoint location = [gesture locationInView:self.card];
    UIView *hitView = [self.card hitTest:location withEvent:nil];
    if ([hitView isKindOfClass:[UIControl class]]) {
        // Ignore tap if user tapped a control (button, etc)
        return;
    }
    // Forward to delegate as Home VC expects
    if ([self.delegate respondsToSelector:@selector(PPUniversalCell_tapCard:)]) {
        [self.delegate PPUniversalCell_tapCard:self.vm];
    }
}- (void)PPUniversalCell_tapShare:(PPUniversalCellViewModel *)vm
 {
     NSLog(@"[DataVC][Share] %@", vm.payload);
 }

 - (void)PPUniversalCell_tapFavorite:(PPUniversalCellViewModel *)vm
 {
     NSLog(@"[DataVC][Favorite] %@", vm.payload);
 }

 - (void)PPUniversalCell_tapEdit:(PPUniversalCellViewModel *)vm {}
 - (void)PPUniversalCell_tapDelete:(PPUniversalCellViewModel *)vm {}
*/


#pragma mark - Shadow Styles

#pragma mark - Accessibility

- (void)pp_updateAccessibilityLabel
{
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;

    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    // Title (pet name, accessory name, etc.)
    NSString *title = PPSafeString(self.vm.title);
    if (title.length > 0) {
        [parts addObject:title];
    }

    // Price
    NSString *priceText = self.priceLabel.attributedText.string ?: self.priceLabel.text;
    if (priceText.length > 0) {
        [parts addObject:priceText];
    }

    // Discount
    NSString *discountText = PPSafeString(self.vm.discountText);
    if (discountText.length > 0) {
        NSString *discountFormat = NSLocalizedString(@"a11y_cell_discount_format", @"Discount: %@");
        [parts addObject:[NSString stringWithFormat:discountFormat, discountText]];
    }

    // Location
    NSString *location = PPSafeString(self.vm.location);
    if (!self.locationStack.hidden && location.length > 0) {
        [parts addObject:location];
    }

    // Stock status
    NSString *stockText = self.stockQtyLabel.text;
    if (!self.stockQtyLabel.hidden && stockText.length > 0) {
        [parts addObject:stockText];
    }

    // Cart quantity
    if (self.context == PPCellForMarket && self.quantity > 0) {
        NSString *qtyFormat = NSLocalizedString(@"a11y_cell_qty_in_cart_format", @"%ld in cart");
        [parts addObject:[NSString stringWithFormat:qtyFormat, (long)self.quantity]];
    }

    // Contextual reason (e.g. "Near you")
    NSString *reason = [self pp_isServiceContext]
        ? PPSafeString(self.reasonBadgeLabel.text)
        : PPSafeString(self.vm.contextualReasonText);
    if (!self.reasonBadgeStack.hidden && reason.length > 0) {
        [parts addObject:reason];
    }

    self.accessibilityLabel = [parts componentsJoinedByString:@", "];
    self.accessibilityHint  = NSLocalizedString(@"a11y_cell_tap_hint", @"Double-tap to view details");
}

- (void)applyHomeAdShadow {
    self.layer.masksToBounds = NO;
    self.clipsToBounds = NO;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = 0.11;
    self.layer.shadowRadius = 18.0;
    self.layer.shadowOffset = CGSizeMake(0, 10.0);
}

- (void)applyDefaultShadow {
    self.layer.masksToBounds = NO;
    self.clipsToBounds = NO;
    self.layer.shadowColor = AppShadowClr.CGColor;
    self.layer.shadowOpacity = 0.06;
    self.layer.shadowRadius = 12.0;
    self.layer.shadowOffset = CGSizeMake(0, 7.0);
}

- (void)setQuantityToLabel:(PPInsetLabel *)label qty:(NSInteger)qty {
    NSString *text = @"";
    UIColor *bgColor = UIColor.clearColor;
    UIColor *fgColor = UIColor.labelColor;
    UIColor *borderColor = UIColor.clearColor;
    
    if (qty <= 0) {
        // State: Out of Stock
        text = kLang(@"Out of stock") ?: @"Out of stock";
        fgColor = [UIColor systemRedColor];
        bgColor = [fgColor colorWithAlphaComponent:0.08];
        borderColor = [fgColor colorWithAlphaComponent:0.12];
    }
    else if (qty < 5) {
        // State: Low Stock
        if (Language.isRTL) {
            text = [NSString stringWithFormat:@"%@ %ld %@", kLang(@"Only"), (long)qty, kLang(@"leftInStock")];
        } else {
            text = [NSString stringWithFormat:@"%@ %ld %@", kLang(@"Only"), (long)qty, kLang(@"left in stock")];
        }
        fgColor = [UIColor systemOrangeColor];
        bgColor = [fgColor colorWithAlphaComponent:0.08];
        borderColor = [fgColor colorWithAlphaComponent:0.12];
    }
    else {
        // State: Available
        NSString *availableText = kLang(@"Available") ?: @"Available";
        if (Language.isRTL) {
            text = [NSString stringWithFormat:@"%@ %ld", availableText, (long)qty];
        } else {
            text = [NSString stringWithFormat:@"%ld %@", (long)qty, availableText];
        }
        fgColor = [UIColor systemGreenColor];
        bgColor = [fgColor colorWithAlphaComponent:0.08];
        borderColor = [fgColor colorWithAlphaComponent:0.12];
    }
    
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:text];
    UIFont *baseFont = [GM MidFontWithSize:10.5];
    UIFont *boldFont = [GM boldFontWithSize:11.0];
    
    [attr addAttributes:@{
        NSFontAttributeName : baseFont,
        NSForegroundColorAttributeName : fgColor
    } range:NSMakeRange(0, text.length)];
    
    // Bold the number part if it exists
    NSString *numStr = [NSString stringWithFormat:@"%ld", (long)qty];
    NSRange numRange = [text rangeOfString:numStr];
    if (numRange.location != NSNotFound) {
        [attr addAttribute:NSFontAttributeName value:boldFont range:numRange];
    }

    label.attributedText = attr;
    label.backgroundColor = bgColor;
    label.layer.borderWidth = 1.0;
    label.layer.borderColor = borderColor.CGColor;
    label.layer.cornerRadius = 8.0;
    label.textInsets = UIEdgeInsetsMake(4, 10, 4, 10);
    label.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        label.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    label.hidden = NO;
}



#pragma mark - 💬 Discount Label Generator
- (double)pp_resolvedOriginalPriceForDiscountDisplay {
    if (self.vm.price != nil) {
        return MAX(0.0, self.vm.price.doubleValue);
    }
    if (self.vm.finalPrice != nil) {
        return MAX(0.0, self.vm.finalPrice.doubleValue);
    }
    return 0.0;
}

- (double)pp_resolvedFinalPriceForDiscountDisplayFromOriginalPrice:(double)originalPrice {
    double finalPrice = MAX(0.0, originalPrice);

    // Match PetAccessory.calculateFinalPrice: apply percent first, then amount.
    if (self.vm.discountPercent.doubleValue > 0) {
        finalPrice = finalPrice * (1.0 - self.vm.discountPercent.doubleValue / 100.0);
    }
    if (self.vm.discountAmount.doubleValue > 0) {
        finalPrice = finalPrice - self.vm.discountAmount.doubleValue;
    }
    finalPrice = MAX(finalPrice, 0.0);

    // Prefer the view-model finalPrice when provided (already computed by the model/backend).
    if (self.vm.finalPrice != nil) {
        double vmFinalPrice = MAX(0.0, self.vm.finalPrice.doubleValue);
        BOOL canTrustVMFinal = (self.vm.price == nil) || (vmFinalPrice <= originalPrice + 0.0001);
        if (canTrustVMFinal) {
            finalPrice = vmFinalPrice;
        }
    }

    return finalPrice;
}

- (void)setPriceAndDiscountLabels {

    double originalPrice = [self pp_resolvedOriginalPriceForDiscountDisplay];
    double finalPrice = [self pp_resolvedFinalPriceForDiscountDisplayFromOriginalPrice:originalPrice];

    UIColor *primaryPriceColor = [self pp_primaryPriceColorForCurrentContext];
    UIColor *mutedPriceColor = [self pp_mutedPriceColorForCurrentContext];
    // 🔻 Discounted
    if (finalPrice + 0.0001 < originalPrice) {

        [self setPriceToLabel:self.priceLabel price:@(finalPrice) currency:kLang(@"Rials") priceColor:primaryPriceColor];

        NSString *oldPriceString = [PPChatsFunc formattedCurrency:MAX(0.0, originalPrice)];
        if (oldPriceString.length == 0) {
            oldPriceString = [NSString stringWithFormat:@"%@ %@", @(originalPrice), kLang(@"Rials")];
        }

        NSMutableAttributedString *attr =
        [[NSMutableAttributedString alloc] initWithString:oldPriceString];

        [attr addAttribute:NSStrikethroughStyleAttributeName
                     value:@(NSUnderlineStyleSingle)
                     range:NSMakeRange(0, oldPriceString.length)];

        [attr addAttribute:NSForegroundColorAttributeName
                     value:mutedPriceColor
                     range:NSMakeRange(0, oldPriceString.length)];

        self.discountLabel.attributedText = attr;
        self.discountLabel.hidden = NO;
        
    }
    // 🔹 No discount
    else {

        [self setPriceToLabel:self.priceLabel
                         price:@(originalPrice)
                      currency:kLang(@"Rials")
                    priceColor:primaryPriceColor];

        self.discountLabel.attributedText = nil;
        self.discountLabel.hidden = YES;
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];

    CGAffineTransform cardTransform = highlighted ? CGAffineTransformMakeScale(0.982, 0.982) : CGAffineTransformIdentity;
    CGAffineTransform imageTransform = highlighted ? CGAffineTransformMakeScale(1.035, 1.035) : CGAffineTransformIdentity;
    CGFloat shadowOpacity = highlighted
        ? 0.18
        : ((self.context == PPCellForMarket) ? 0.06 : ([self pp_isServiceContext] ? 0.10 : 0.14));
    CGFloat overlayAlpha = highlighted ? 0.94 : 1.0;

    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.card.transform = cardTransform;
        self.imageView.transform = imageTransform;
        self.layer.shadowOpacity = shadowOpacity;
        self.bottomOverlay.alpha = overlayAlpha;
        self.locationStack.transform = highlighted ? CGAffineTransformMakeScale(0.98, 0.98) : CGAffineTransformIdentity;
        self.reasonBadgeStack.transform = highlighted ? CGAffineTransformMakeScale(0.98, 0.98) : CGAffineTransformIdentity;
    } completion:nil];
}

- (void)setPriceToLabel:(UILabel *)label
                  price:(NSNumber *)price
               currency:(NSString *)currency
             priceColor:(UIColor *)priceColor
{
    CGFloat amountValue = MAX(0.0, price.doubleValue);
    NSString *fullText = [PPChatsFunc formattedCurrency:amountValue];
    if (fullText.length == 0) {
        NSString *priceText = price.stringValue ?: @"0";
        fullText = [NSString stringWithFormat:@"%@ %@", priceText, (currency ?: @"QAR")];
    }

    CGFloat priceFontSize = [self pp_isServiceContext] ? 17.0 : PPFontTitle2;
    CGFloat currencyFontSize = [self pp_isServiceContext] ? MAX(PPFontCaption1, 11.0) : PPFontCaption1;
    UIFont *priceFont    = [GM boldFontWithSize:priceFontSize];
    UIFont *currencyFont = [GM MidFontWithSize:currencyFontSize];

    NSMutableAttributedString *attr =
    [[NSMutableAttributedString alloc] initWithString:fullText];

    // Default style for the whole formatted price (locale-aware + QAR-forced via PPChatsFunc).
    [attr addAttributes:@{
        NSFontAttributeName : priceFont,
        NSForegroundColorAttributeName : priceColor
    } range:NSMakeRange(0, fullText.length)];

    // When the formatter returns a visible currency token (e.g. QAR), render it slightly smaller.
    NSArray<NSString *> *currencyCandidates = @[
        @"QAR",
        currency ?: @""
    ];
    
    for (NSString *candidate in currencyCandidates) {
        if (candidate.length == 0) continue;
        NSRange currencyRange = [fullText rangeOfString:candidate options:NSCaseInsensitiveSearch];
        if (currencyRange.location == NSNotFound) continue;
        [attr addAttributes:@{
            NSFontAttributeName : currencyFont,
            NSForegroundColorAttributeName : [priceColor colorWithAlphaComponent:0.65]
        } range:currencyRange];
        break;
    }

    label.attributedText = attr;
}


- (void)setDiscountValueLabel {

    BOOL hasPercentDiscount = self.vm.discountPercent.doubleValue > 0;
    BOOL hasAmountDiscount = self.vm.discountAmount.doubleValue > 0;
    NSString *badgeText = nil;

    if (hasPercentDiscount) {
        badgeText = [NSString stringWithFormat:@"%@%%", self.vm.discountPercent];
    } else if (hasAmountDiscount) {
        NSString *formattedAmount = [PPChatsFunc formattedCurrency:MAX(0.0, self.vm.discountAmount.doubleValue)];
        NSString *savePrefix = kLang(@"SaveAmountPrefix") ?: @"Save";
        badgeText = [NSString stringWithFormat:@"%@ %@", savePrefix, formattedAmount];
    }

    self.vm.discountText = badgeText ?: @"";
    self.discountValueLabel.text = badgeText;

    if (badgeText.length > 0) {
        [self showDiscountBadgeAnimated];
    }
    
    else {
        [self hideDiscountBadgeAnimated];
    }
}

- (void)showDiscountBadgeAnimated {
    if (self.context != PPCellForMarket) {
        [self pp_updateBottomOverlayTextWidthForDiscountBadgeVisible:YES];
    }
    if (!self.discountValueLabel.hidden) return;

    self.discountValueLabel.hidden = NO;
    self.discountValueLabel.alpha = 0.0;
    self.discountValueLabel.transform = CGAffineTransformMakeScale(0.85, 0.85);
    UIView *layoutHost = (self.context == PPCellForMarket) ? self.card : self.bottomOverlay;
    [layoutHost layoutIfNeeded];

    [UIView animateWithDuration:0.22
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        [layoutHost layoutIfNeeded];
        self.discountValueLabel.alpha = 1.0;
        self.discountValueLabel.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)hideDiscountBadgeAnimated {
    if (self.discountValueLabel.hidden) {
        if (self.context != PPCellForMarket) {
            [self pp_updateBottomOverlayTextWidthForDiscountBadgeVisible:NO];
        }
        return;
    }

    if (self.context != PPCellForMarket) {
        [self pp_updateBottomOverlayTextWidthForDiscountBadgeVisible:NO];
    }
    UIView *layoutHost = (self.context == PPCellForMarket) ? self.card : self.bottomOverlay;

    [UIView animateWithDuration:0.18
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        [layoutHost layoutIfNeeded];
        self.discountValueLabel.alpha = 0.0;
        self.discountValueLabel.transform = CGAffineTransformMakeScale(0.85, 0.85);
    } completion:^(BOOL finished) {
        self.discountValueLabel.hidden = YES;
        self.discountValueLabel.transform = CGAffineTransformIdentity;
    }];
}

#pragma mark - Quantity

- (void)setQuantity:(NSInteger)quantity animated:(BOOL)animated {
    _quantity = MAX(0, quantity);
    self.qtyLabel.text = [NSString stringWithFormat:@"%ld", (long)_quantity];

    // Saved cart quantity should stay collapsed until the user actively edits it.
    if (_quantity == 0) {
        self.isEditingQuantity = NO;
    }

    if (self.isEditingQuantity && _quantity > 0) {
        [self expandStepper:animated];
    } else {
        [self collapseStepper:animated];
    }
}

- (NSInteger)pp_stockLimitForCurrentItem
{
    if ([self.vm.ModelObject isKindOfClass:PetAccessory.class]) {
        PetAccessory *accessory = (PetAccessory *)self.vm.ModelObject;
        return MAX(accessory.quantity, 0);
    }
    return MAX(self.vm.itemQuantitiy, 0);
}

- (void)pp_showOutOfStockFeedback
{
    [PPHUD showError:(kLang(@"Out of stock") ?: @"Out of stock")];
    [PPFunc triggerWarningHaptic];
}

- (void)pp_showStockLimitFeedback:(NSInteger)stockLimit
{
    if (stockLimit <= 0) {
        [self pp_showOutOfStockFeedback];
        return;
    }
    NSString *text = [NSString stringWithFormat:@"%@ %ld %@",
                      (kLang(@"Only") ?: @"Only"),
                      (long)stockLimit,
                      (kLang(@"left in stock") ?: @"left in stock")];
    [PPHUD showInfo:text];
    [PPFunc triggerMediumHaptic];
}

- (void)pp_animateAddToCartAffordance
{
    self.addButton.transform = CGAffineTransformMakeScale(0.95, 0.95);
    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.72
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.addButton.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)expandStepper:(BOOL)animated {
    self.isEditingQuantity = YES;
    self.stepperView.hidden = NO;
    self.stepperView.transform = CGAffineTransformMakeScale(animated ? 0.95 : 1.0,
                                                            animated ? 0.95 : 1.0);
    if (animated) {
        self.stepperView.alpha = 0.0;
        [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.stepperView.alpha = 1.0;
            self.stepperView.transform = CGAffineTransformIdentity;
            self.addButton.alpha = 0.0;
        } completion:^(__unused BOOL finished) {
            self.addButton.hidden = YES;
        }];
    } else {
        self.stepperView.alpha = 1.0;
        self.stepperView.transform = CGAffineTransformIdentity;
        self.addButton.alpha = 0.0;
        self.addButton.hidden = YES;
    }
}

- (void)updateAddButton
{
    BOOL isMarket = (self.context == PPCellForMarket || self.context == PPCellForFood);
    BOOL showsCount = self.quantity > 0;
    UIButtonConfiguration *config = self.addButton.configuration ?: [UIButtonConfiguration filledButtonConfiguration];
    
    if (isMarket) {
        NSString *title = showsCount
        ? [NSString stringWithFormat:@"%@ • %ld", (kLang(@"InCart") ?: @"In cart"), (long)self.quantity]
        : (kLang(@"addToCart") ?: @"Add to Cart");
        
        UIFont *titleFont = [GM boldFontWithSize:showsCount ? 13.5 : 14.5];
        UIColor *foregroundColor = showsCount ? AppPrimaryClr : UIColor.whiteColor;
        UIColor *backgroundColor = showsCount ? [AppPrimaryClr colorWithAlphaComponent:0.08] : AppPrimaryClr;
        UIColor *borderColor = showsCount ? [AppPrimaryClr colorWithAlphaComponent:0.15] : UIColor.clearColor;

        config.title = title;
        config.image = [UIImage systemImageNamed:(showsCount ? @"cart.fill.badge.plus" : @"plus.cart.fill")];
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.imagePadding = 8.0;
        config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        config.contentInsets = NSDirectionalEdgeInsetsMake(10.0, 14.0, 10.0, 14.0);
        config.baseBackgroundColor = backgroundColor;
        config.baseForegroundColor = foregroundColor;
        config.background.cornerRadius = 14.0;
        config.background.strokeWidth = showsCount ? 1.0 : 0.0;
        config.background.strokeColor = borderColor;
        
        config.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
            NSMutableDictionary *attrs = [incoming mutableCopy];
            attrs[NSFontAttributeName] = titleFont;
            attrs[NSForegroundColorAttributeName] = foregroundColor;
            return attrs;
        };
        
        self.addButton.layer.shadowColor = AppPrimaryClr.CGColor;
        self.addButton.layer.shadowOpacity = showsCount ? 0.0 : 0.12;
        self.addButton.layer.shadowRadius = 10.0;
        self.addButton.layer.shadowOffset = CGSizeMake(0, 4.0);
    } else {
        NSString *title = showsCount
        ? [NSString stringWithFormat:@"%ld", (long)self.quantity]
        : @"+";
        UIFont *titleFont = showsCount ? [GM boldFontWithSize:15] : [GM boldFontWithSize:18];

        config.title = title;
        config.image = nil;
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.contentInsets = NSDirectionalEdgeInsetsZero;
        config.baseBackgroundColor = AppPrimaryClr;
        config.baseForegroundColor = UIColor.whiteColor;
        config.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
            NSMutableDictionary *attrs = [incoming mutableCopy];
            attrs[NSFontAttributeName] = titleFont;
            attrs[NSForegroundColorAttributeName] = UIColor.whiteColor;
            return attrs;
        };
        self.addButtonWidthConstraint.constant = 38.0;
    }
    self.addButton.configuration = config;
}
- (void)collapseStepper:(BOOL)animated {
    self.isEditingQuantity = NO;
    self.addButton.hidden = NO;
    [self updateAddButton];
    if (animated) {
        [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.stepperView.alpha = 0.0;
            self.stepperView.transform = CGAffineTransformMakeScale(0.95, 0.95);
            self.addButton.alpha = 1.0;
            [self.card layoutIfNeeded];
        } completion:^(BOOL finished) {
            self.stepperView.hidden = YES;
            self.stepperView.transform = CGAffineTransformIdentity;
        }];
    } else {
        self.stepperView.alpha = 0.0;
        self.stepperView.hidden = YES;
        self.addButton.alpha = 1.0;
        self.stepperView.transform = CGAffineTransformIdentity;
        [self.card layoutIfNeeded];
    }
}

#pragma mark - Actions

// (No longer used, replaced by handleTap gesture recognizer)
//- (void)tapCard {
//    //if (self.onTapCard) self.onTapCard(self.vm);
//    [self.delegate PPUniversalCell_tapCard:self.vm];
//}

- (void)tapShare {
    
    NSLog(@"[TAP] tap Share ");
    [self.delegate PPUniversalCell_tapShare:self.vm];
}

- (void)tapFavorite {
    if(!UserManager.sharedManager.isUserLoggedIn) { [UserManager showPromptOnTopController]; return; }
 
}

- (void)tapEdit {
    if(!UserManager.sharedManager.isUserLoggedIn) { [UserManager showPromptOnTopController]; return; }

    NSLog(@"[TAP] tap Edit ");
    //if (self.onTapEdit) self.onTapEdit(self.vm);
    [self.delegate PPUniversalCell_tapEdit:self.vm];
}

- (void)tapDelete {
    if(!UserManager.sharedManager.isUserLoggedIn) { [UserManager showPromptOnTopController]; return; }

    NSLog(@"[TAP] tap Delete ");
   // self.onTapDelete(self.vm);
    [self.delegate PPUniversalCell_tapDelete:self.vm];
}


- (void)tapAddCollapsed
{
    NSLog(@"[TAP] tapAddCollapsed");

    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    NSInteger stockLimit = [self pp_stockLimitForCurrentItem];
    if (stockLimit <= 0) {
        [self pp_showOutOfStockFeedback];
        [self setQuantity:0 animated:YES];
        [self restartStepperCollapseTimer];
        return;
    }
    [self pp_animateAddToCartAffordance];
    if (self.quantity > 0) {
        [self expandStepper:YES];
        [self restartStepperCollapseTimer];
        return;
    }

    NSInteger nextQuantity = MAX(1, MIN(self.quantity, stockLimit));
    self.isEditingQuantity = YES;
    [self setQuantity:nextQuantity animated:YES];
    if ([self.delegate respondsToSelector:@selector(PPUniversalCell_changeQuantity:quantity:)]) {
        [self.delegate PPUniversalCell_changeQuantity:self.vm quantity:nextQuantity];
    }
    if (self.onQuantityChanged) self.onQuantityChanged(nextQuantity);

    [self restartStepperCollapseTimer];
}

- (void)tapMinus {
    if(!UserManager.sharedManager.isUserLoggedIn) { [UserManager showPromptOnTopController]; return; }

    
    NSLog(@"[TAP] tapMinus ");
    NSInteger q = MAX(0, self.quantity - 1);
    [self setQuantity:q animated:YES];
    if ([self.delegate respondsToSelector:@selector(PPUniversalCell_changeQuantity:quantity:)]) {
        [self.delegate PPUniversalCell_changeQuantity:self.vm quantity:q];
    }
    if (self.onQuantityChanged) self.onQuantityChanged(q);

    [self restartStepperCollapseTimer];
}

- (void)tapPlus {
    if(!UserManager.sharedManager.isUserLoggedIn) { [UserManager showPromptOnTopController]; return; }

    
    NSLog(@"[TAP] tapPlus ");
    NSInteger stockLimit = [self pp_stockLimitForCurrentItem];
    if (stockLimit <= 0) {
        [self pp_showOutOfStockFeedback];
        [self setQuantity:0 animated:YES];
        [self restartStepperCollapseTimer];
        return;
    }

    if (self.quantity >= stockLimit) {
        [self pp_showStockLimitFeedback:stockLimit];
        [self restartStepperCollapseTimer];
        return;
    }

    NSInteger q = MIN(stockLimit, MIN(999, self.quantity + 1));
    [self setQuantity:q animated:YES];
    if ([self.delegate respondsToSelector:@selector(PPUniversalCell_changeQuantity:quantity:)]) {
        [self.delegate PPUniversalCell_changeQuantity:self.vm quantity:q];
    }
    if (self.onQuantityChanged) self.onQuantityChanged(q);

    [self restartStepperCollapseTimer];
}


- (void)ownerMenuButtonTapped:(UIButton *)sender {
    NSLog(@"📍 User tapped menu button before menu appears");
    // Optional: provide haptic feedback, highlight, etc.
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen impactOccurred];
}
 
@end
