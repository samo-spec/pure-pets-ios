
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

#pragma mark - PPUniversalCell

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
@property (nonatomic, assign) BOOL isEditingQuantity;
// Image
@property (nonatomic, strong) UIImageView *imageView;

// Gradient (for square overlay mode)
@property (nonatomic, strong) PPBottomOverlayBlur *bottomOverlay;

// Labels
@property (nonatomic, strong) UIStackView *textStack;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;

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
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *carouselConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *verticalConstraints;
@property (nonatomic, strong) NSLayoutConstraint *textStackTrailingToEdgeConstraint;
@property (nonatomic, strong) NSLayoutConstraint *textStackTrailingToDiscountConstraint;
@property (nonatomic, strong) NSLayoutConstraint *marketImageHeightConstraint;
@property (nonatomic, strong) UIView *card;
// Data
@property (nonatomic, copy)   PPImageLoader loader;
@property (nonatomic, strong) PPUniversalCellViewModel *vm;
@property (nonatomic, assign) BOOL didLayout;

- (void)pp_updateBottomOverlayTextWidthForDiscountBadgeVisible:(BOOL)isVisible;
- (void)pp_applyLayoutAppearanceForMarket:(BOOL)isMarket;

@end

@implementation PPUniversalCell

#pragma mark - Init

- (void)setupBottomOverlay
{
    if (self.bottomOverlay) return;
    
    self.bottomOverlay =
    [[PPBottomOverlayBlur alloc] initWithHeight:62
                                   cornerRadius:0];
    
    [self.imageView addSubview:self.bottomOverlay];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.bottomOverlay.leadingAnchor constraintEqualToAnchor:self.imageView.leadingAnchor constant:0],
        [self.bottomOverlay.trailingAnchor constraintEqualToAnchor:self.imageView.trailingAnchor constant:0],
        [self.bottomOverlay.bottomAnchor constraintEqualToAnchor:self.imageView.bottomAnchor constant:0],
        [self.bottomOverlay.heightAnchor constraintEqualToConstant:62]
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
    [self pp_updateBottomOverlayTextWidthForDiscountBadgeVisible:NO];
    self.bottomOverlay.hidden = NO;
    self.actionBar.hidden = NO;

    
    self.didLayout = NO;
  
 }


+ (NSString *)reuseIdentifier { return  @"PPUniversalCell";}
 

- (void)layoutSubviews {
    [super layoutSubviews];

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
    [self.priceStack setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                     forAxis:UILayoutConstraintAxisVertical];
   

    [self.priceStack setContentHuggingPriority:UILayoutPriorityDefaultLow
                                       forAxis:UILayoutConstraintAxisVertical];
    
    // Texts
    self.titleLabel = [self createTitleLabel];
    self.subtitleLabel = [self createSubtitleLabel];
    
    // 📍 Location label (Home Ads)
    self.adLocationLabel = [UILabel new];
    self.adLocationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.adLocationLabel.font = [GM MidFontWithSize:12];
    self.adLocationLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    self.adLocationLabel.numberOfLines = 3; // allow up to 3 lines
    self.adLocationLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.adLocationLabel.textAlignment = NSTextAlignmentNatural;
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
    self.locationStack.spacing = 4;
    self.locationStack.backgroundColor =
    [[UIColor blackColor] colorWithAlphaComponent:0.38];
    self.locationStack.layer.cornerRadius = 10;
    self.locationStack.layer.borderWidth = 0.75;
    self.locationStack.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10].CGColor;
    self.locationStack.layer.masksToBounds = YES;
    self.locationStack.layoutMargins =
    UIEdgeInsetsMake(4, 6, 4, 8);
    self.locationStack.layoutMarginsRelativeArrangement = YES;

    // Ensure proper layout wrapping for location label and stack
    self.locationStack.alignment = UIStackViewAlignmentTop;
    [self.adLocationLabel setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                        forAxis:UILayoutConstraintAxisVertical];
    [self.adLocationLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh
                                            forAxis:UILayoutConstraintAxisVertical];

    [self.card addSubview:self.locationStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.locationStack.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:10],
        [self.locationStack.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-10],

        // Max width = card width - 12
        [self.locationStack.widthAnchor constraintLessThanOrEqualToAnchor:self.card.widthAnchor constant:-12],

        [self.locationIconView.widthAnchor constraintEqualToConstant:14],
        [self.locationIconView.heightAnchor constraintEqualToConstant:14],
    ]];
    self.locationStack.hidden = YES;

    self.reasonBadgeIconView = [[UIImageView alloc] init];
    self.reasonBadgeIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.reasonBadgeIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.reasonBadgeIconView.tintColor = UIColor.whiteColor;

    self.reasonBadgeLabel = [[UILabel alloc] init];
    self.reasonBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.reasonBadgeLabel.font = [GM MidFontWithSize:11] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
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
    self.reasonBadgeStack.spacing = 5.0;
    self.reasonBadgeStack.backgroundColor =
        [[UIColor blackColor] colorWithAlphaComponent:0.34];
    self.reasonBadgeStack.layer.cornerRadius = 10.0;
    self.reasonBadgeStack.layer.cornerCurve = kCACornerCurveContinuous;
    self.reasonBadgeStack.layer.masksToBounds = YES;
    self.reasonBadgeStack.layoutMargins = UIEdgeInsetsMake(5, 8, 5, 10);
    self.reasonBadgeStack.layoutMarginsRelativeArrangement = YES;
    self.reasonBadgeStack.hidden = YES;
    [self.card addSubview:self.reasonBadgeStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.reasonBadgeStack.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:10.0],
        [self.reasonBadgeStack.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:10.0],
        [self.reasonBadgeStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.card.trailingAnchor constant:-74.0],
        [self.reasonBadgeIconView.widthAnchor constraintEqualToConstant:12.0],
        [self.reasonBadgeIconView.heightAnchor constraintEqualToConstant:12.0]
    ]];
    
    self.textStack = [self createTextStackWithElements:@[
        self.titleLabel,
        self.priceStack
    ]];
    self.textStack.spacing = 6;
    self.textStack.alignment = UIStackViewAlignmentFill;
    self.textStack.distribution = UIStackViewDistributionFill;

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
    self.actionBar.axis = UILayoutConstraintAxisVertical;
    self.actionBar.spacing = 8;
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

    UIStackView *stepperStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.minusBtn, self.qtyLabel, self.plusBtn]];
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
    [self.imageView.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:12.0];

    NSLayoutConstraint *marketImgLeading =
    [self.imageView.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:12.0];

    NSLayoutConstraint *marketImgTrailing =
    [self.imageView.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-12.0];

    self.marketImageHeightConstraint =
    [self.imageView.heightAnchor constraintEqualToAnchor:self.imageView.widthAnchor multiplier:0.68];

    // =========================
    // Bottom Overlay (already created)
    // =========================
    NSLayoutConstraint *minHeight =
    [self.bottomOverlay.heightAnchor constraintGreaterThanOrEqualToConstant:52];
    minHeight.priority = UILayoutPriorityRequired;
    minHeight.active = YES;

    
    
    // =========================
    // TEXT STACK (CRITICAL FIX)
    // =========================
    NSLayoutConstraint *txtTop =
    [self.textStack.topAnchor constraintEqualToAnchor:self.bottomOverlay.topAnchor constant:8];

    NSLayoutConstraint *txtBottom =
    [self.textStack.bottomAnchor constraintEqualToAnchor:self.bottomOverlay.bottomAnchor constant:0];

    NSLayoutConstraint *txtLeading =
    [self.textStack.leadingAnchor constraintEqualToAnchor:self.bottomOverlay.leadingAnchor constant:10];

    self.textStackTrailingToEdgeConstraint =
    [self.textStack.trailingAnchor constraintEqualToAnchor:self.bottomOverlay.trailingAnchor constant:-10];
    self.textStackTrailingToDiscountConstraint =
    [self.textStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.discountValueLabel.leadingAnchor constant:-2];

    NSLayoutConstraint *marketTxtTop =
    [self.textStack.topAnchor constraintEqualToAnchor:self.imageView.bottomAnchor constant:12.0];

    NSLayoutConstraint *marketTxtLeading =
    [self.textStack.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:12.0];

    NSLayoutConstraint *marketTxtTrailing =
    [self.textStack.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-12.0];

    NSLayoutConstraint *discountTrailing =
    [self.discountValueLabel.trailingAnchor constraintEqualToAnchor:self.bottomOverlay.trailingAnchor constant:-10];
    NSLayoutConstraint *discountCenterY =
    [self.discountValueLabel.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor];
    discountTrailing.active = YES;
    discountCenterY.active = YES;
    [self pp_updateBottomOverlayTextWidthForDiscountBadgeVisible:NO];

    NSLayoutConstraint *marketDiscountTop =
    [self.discountValueLabel.topAnchor constraintEqualToAnchor:self.imageView.topAnchor constant:10.0];

    NSLayoutConstraint *marketDiscountLeading =
    [self.discountValueLabel.leadingAnchor constraintEqualToAnchor:self.imageView.leadingAnchor constant:10.0];

    // =========================
    // Floating actions
    // =========================
    NSLayoutConstraint *actionLeading =
    [self.actionBar.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:10];

    NSLayoutConstraint *actionBottom =
    [self.actionBar.bottomAnchor constraintEqualToAnchor:self.bottomOverlay.topAnchor constant:-10];

    actionBottom.active = YES;
    actionLeading.active = YES;

    NSLayoutConstraint *marketActionTop =
    [self.actionBar.topAnchor constraintEqualToAnchor:self.imageView.topAnchor constant:10.0];

    NSLayoutConstraint *marketActionTrailing =
    [self.actionBar.trailingAnchor constraintEqualToAnchor:self.imageView.trailingAnchor constant:-10.0];

    // =========================
    // Add / Stepper footer
    // =========================
    NSLayoutConstraint *addTrailing =
    [self.addButton.trailingAnchor constraintEqualToAnchor:self.bottomOverlay.trailingAnchor constant:-8];
    NSLayoutConstraint *addBottom =
    [self.addButton.bottomAnchor constraintEqualToAnchor:self.bottomOverlay.topAnchor constant:-8];
    NSLayoutConstraint *stepperTrailing =
    [self.stepperView.trailingAnchor constraintEqualToAnchor:self.addButton.trailingAnchor];
    NSLayoutConstraint *stepperBottom =
    [self.stepperView.bottomAnchor constraintEqualToAnchor:self.addButton.bottomAnchor];

    NSLayoutConstraint *marketAddTop =
    [self.addButton.topAnchor constraintEqualToAnchor:self.textStack.bottomAnchor constant:12.0];
    NSLayoutConstraint *marketAddLeading =
    [self.addButton.leadingAnchor constraintEqualToAnchor:self.textStack.leadingAnchor];
    NSLayoutConstraint *marketAddTrailing =
    [self.addButton.trailingAnchor constraintEqualToAnchor:self.textStack.trailingAnchor];
    NSLayoutConstraint *marketStepperTop =
    [self.stepperView.topAnchor constraintEqualToAnchor:self.textStack.bottomAnchor constant:12.0];
    NSLayoutConstraint *marketStepperLeading =
    [self.stepperView.leadingAnchor constraintEqualToAnchor:self.textStack.leadingAnchor];
    NSLayoutConstraint *marketStepperTrailing =
    [self.stepperView.trailingAnchor constraintEqualToAnchor:self.textStack.trailingAnchor];

    // =========================
    // Badges
    // =========================
    [NSLayoutConstraint activateConstraints:@[
        [self.freshBadge.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:10],
        [self.freshBadge.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-10],

        [self.offerBadge.topAnchor constraintEqualToAnchor:self.freshBadge.bottomAnchor constant:6],
        [self.offerBadge.trailingAnchor constraintEqualToAnchor:self.freshBadge.trailingAnchor],
    ]];

    NSLayoutConstraint *stockTop =
    [self.stockQtyLabel.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:10.0];
    NSLayoutConstraint *stockTrailing =
    [self.stockQtyLabel.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-10.0];
    NSLayoutConstraint *stockHeight =
    [self.stockQtyLabel.heightAnchor constraintEqualToConstant:22.0];
    NSLayoutConstraint *marketStockTop =
    [self.stockQtyLabel.topAnchor constraintEqualToAnchor:self.addButton.bottomAnchor constant:10.0];
    NSLayoutConstraint *marketStockLeading =
    [self.stockQtyLabel.leadingAnchor constraintEqualToAnchor:self.textStack.leadingAnchor];
    NSLayoutConstraint *marketStockBottom =
    [self.stockQtyLabel.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:-12.0];

    stockHeight.active = YES;

    // =========================
    // Layout Groups
    // =========================

    self.fullWidthConstraints = @[
        imgTop, imgLeading, imgTrailing, imgBottom,
        txtTop, txtLeading, txtBottom,
        discountTrailing, discountCenterY,
        actionLeading, actionBottom,
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

- (void)pp_applyLayoutAppearanceForMarket:(BOOL)isMarket
{
    self.bottomOverlay.hidden = isMarket;
    self.imageView.backgroundColor = isMarket ? UIColor.secondarySystemBackgroundColor : UIColor.clearColor;
    self.imageView.layer.cornerRadius = isMarket ? 18.0 : PPCornerCard;
    self.imageView.contentMode = isMarket ? UIViewContentModeScaleAspectFit : UIViewContentModeScaleAspectFill;
    self.textStack.spacing = isMarket ? 8.0 : 2.0;
    self.titleLabel.numberOfLines = isMarket ? 2 : 1;
    self.addButtonWidthConstraint.active = !isMarket;
    [self pp_updateBottomOverlayTextWidthForDiscountBadgeVisible:(!isMarket && !self.discountValueLabel.hidden)];
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
    for (NSLayoutConstraint *c in self.carouselConstraints) c.active = NO;

    

    self.layoutMode = mode;
    [self.discountValueLabel sizeToFit];
    
    
    if (mode == PPCellLayoutModeCarousel) {

      //  NSLog(@"[UniversalCell][Layout] Carousel mode");

        // Hide non-carousel UI
        self.titleLabel.hidden = YES;
        self.priceLabel.hidden = YES;
        self.offerBadge.hidden = YES;
        self.stepperView.hidden = YES;
        [self pp_applyLayoutAppearanceForMarket:NO];
        
        [NSLayoutConstraint activateConstraints:self.carouselConstraints];
        return;
    }
    BOOL isMarket = (self.context == PPCellForMarket);
    [self pp_applyLayoutAppearanceForMarket:isMarket];

    if(isMarket)
    {
        for (NSLayoutConstraint *c in self.marketConstraints) c.active = YES;
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
    }
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
    
    
    UIColor *primaryPriceColor = UIColor.labelColor;
    self.priceLabel.textColor = primaryPriceColor;
    self.vm = vm;
    self.context = context;
    self.discountStyle = discountStyle;
    self.loader = loader;
    BOOL isMarket = (context == PPCellForMarket);
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
    self.titleLabel.text = vm.title;
    NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
    p.lineHeightMultiple = 0.9;
    p.maximumLineHeight = self.titleLabel.font.lineHeight * 1.05;

    self.titleLabel.attributedText =
    [[NSAttributedString alloc] initWithString:self.titleLabel.text
                                    attributes:@{
        NSParagraphStyleAttributeName : p,
        NSFontAttributeName : self.titleLabel.font,
        NSForegroundColorAttributeName : UIColor.labelColor
    }];
    self.titleLabel.textAlignment = GM.setAligment;
    self.subtitleLabel.text = vm.subtitle;
    self.titleLabel.numberOfLines = isMarket ? 2 : 1;
    self.subtitleLabel.hidden = isMarket || (vm.subtitle.length == 0);

    NSString *reasonText = PPSafeString(vm.contextualReasonText);
    self.reasonBadgeLabel.text = reasonText;
    self.reasonBadgeStack.hidden = isMarket || (reasonText.length == 0);
    if (!self.reasonBadgeStack.hidden) {
        NSString *iconName = PPSafeString(vm.contextualReasonIconName);
        if (iconName.length == 0) {
            iconName = @"sparkles";
        }
        self.reasonBadgeIconView.image =
            [UIImage pp_symbolNamed:iconName
                          pointSize:11
                             weight:UIImageSymbolWeightBold
                              scale:UIImageSymbolScaleSmall
                            palette:@[UIColor.whiteColor]
                       makeTemplate:YES];
    } else {
        self.reasonBadgeIconView.image = nil;
    }
 
    // 4️⃣ Async load real image
    if (vm.imageURL.length > 0 && loader) {
        loader(self.imageView, vm.imageURL, nil, self.card);
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
        
        self.discountValueLabel.hidden = YES;
        self.stockQtyLabel.hidden = YES;
        [self setPriceToLabel:self.priceLabel
                        price:self.vm.finalPrice
                     currency:kLang(@"Rials")  priceColor:UIColor.labelColor];
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

    BOOL hasLocation = (!isMarket && locationText.length > 0);
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
    
    [self applyHomeAdShadow];
 
    [self activateConstraintsForMode:layout];
    self.userInteractionEnabled = YES;
    self.contentView.userInteractionEnabled = YES;
    
    // ── Accessibility: Composite cell label ──
    [self pp_updateAccessibilityLabel];
    
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
    
    if (self.onTap) {
        self.onTap();
    }
    
    if ([self.delegate respondsToSelector:@selector(PPUniversalCell_tapCard:)]) {
        [self.delegate PPUniversalCell_tapCard:self.vm];
    }
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
    NSString *reason = PPSafeString(self.vm.contextualReasonText);
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
    self.layer.shadowOpacity = 0.08;
    self.layer.shadowRadius = 14.0;
    self.layer.shadowOffset = CGSizeMake(0, 8.0);
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
    NSString *availableText = kLang(@"Available") ?: @"Available";
    
    if (qty <= 0) {
        text = kLang(@"Out of stock");
        fgColor = [UIColor systemOrangeColor];
        bgColor = [fgColor colorWithAlphaComponent:0.14];
        borderColor = [fgColor colorWithAlphaComponent:0.18];
    }
    else if (qty < 5) {
        if (Language.isRTL) {
            text = [NSString stringWithFormat:@"%@ %ld %@", kLang(@"Only"), (long)qty, kLang(@"leftInStock")];
        } else {
            text = [NSString stringWithFormat:@"%@ %ld %@", kLang(@"Only"), (long)qty, kLang(@"left in stock")];
        }
        fgColor = [UIColor systemOrangeColor];
        bgColor = [fgColor colorWithAlphaComponent:0.14];
        borderColor = [fgColor colorWithAlphaComponent:0.18];
    }
    else {
        if (Language.isRTL) {
            text = [NSString stringWithFormat:@"%@ %ld", availableText, (long)qty];
        } else {
            text = [NSString stringWithFormat:@"%ld %@", (long)qty, availableText];
        }
        fgColor = [UIColor systemGreenColor];
        bgColor = [fgColor colorWithAlphaComponent:0.14];
        borderColor = [fgColor colorWithAlphaComponent:0.18];
    }
    
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:text];
    NSString *numStr = [NSString stringWithFormat:@"%ld", (long)qty];
    NSRange numRange = [text rangeOfString:numStr];
    UIFont *baseFont = [GM MidFontWithSize:11];
    if (numRange.location != NSNotFound) {
        UIFont *boldFont = [GM boldFontWithSize:11.5];
        [attr addAttribute:NSFontAttributeName value:boldFont range:numRange];
        [attr addAttribute:NSForegroundColorAttributeName value:fgColor range:numRange];
    }
    [attr addAttribute:NSFontAttributeName value:baseFont range:NSMakeRange(0, text.length)];
    [attr addAttribute:NSForegroundColorAttributeName value:fgColor range:NSMakeRange(0, text.length)];

    label.font = baseFont;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = fgColor;
    label.attributedText = attr;
    label.backgroundColor = bgColor;
    label.layer.masksToBounds = YES;
    label.layer.shadowOpacity = 0.0;
    label.layer.borderWidth = 0.8;
    label.layer.borderColor = borderColor.CGColor;
    label.layer.cornerRadius = 10.0;
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

    UIColor *primaryPriceColor = UIColor.labelColor;
   //UIColor *secondaryPriceColor = [UIColor colorWithWhite:1.0 alpha:0.65];
    UIColor *mutedPriceColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.85];
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

    UIFont *priceFont    = [GM boldFontWithSize:PPFontTitle2];
    UIFont *currencyFont = [GM MidFontWithSize:PPFontCaption1];

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
    BOOL isMarket = (self.context == PPCellForMarket);
    BOOL showsCount = self.quantity > 0;
    UIButtonConfiguration *config = self.addButton.configuration ?: [UIButtonConfiguration filledButtonConfiguration];
    if (isMarket) {
        NSString *title = showsCount
        ? [NSString stringWithFormat:@"%@ • %ld", (kLang(@"InCart") ?: @"In cart"), (long)self.quantity]
        : (kLang(@"addToCart") ?: @"Add to Cart");
        UIFont *titleFont = [GM boldFontWithSize:showsCount ? 14.0 : 15.0];
        UIColor *foregroundColor = showsCount ? AppPrimaryClr : UIColor.whiteColor;
        UIColor *backgroundColor = showsCount ? [AppPrimaryClr colorWithAlphaComponent:0.12] : AppPrimaryClr;

        config.title = title;
        config.image = [UIImage systemImageNamed:(showsCount ? @"checkmark.circle.fill" : @"plus.circle.fill")];
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.imagePadding = 8.0;
        config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        config.contentInsets = NSDirectionalEdgeInsetsMake(11.0, 14.0, 11.0, 14.0);
        config.baseBackgroundColor = backgroundColor;
        config.baseForegroundColor = foregroundColor;
        config.background.cornerRadius = 18;
        config.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey,id> * _Nonnull(NSDictionary<NSAttributedStringKey,id> * _Nonnull incoming) {
            NSMutableDictionary *attrs = [incoming mutableCopy];
            attrs[NSFontAttributeName] = titleFont;
            attrs[NSForegroundColorAttributeName] = foregroundColor;
            return attrs;
        };
        self.addButton.layer.shadowOpacity = 0.05;
        self.addButton.layer.shadowRadius = 8.0;
        self.addButton.layer.shadowOffset = CGSizeMake(0, 4.0);
    } else {
        NSString *title = showsCount
        ? [NSString stringWithFormat:@"%ld", (long)self.quantity]
        : @"+";
        UIFont *titleFont = showsCount ? [GM boldFontWithSize:PPFontCallout] : [GM boldFontWithSize:PPFontTitle3];

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


/*
 
 
 Bro, I want you to do a full production-ready implementation for my Pure Pets app.

 Current status:
 - The app flow is complete until payment success.
 - I want you now to build everything that should happen AFTER payment success, with all real-world cases covered.
 - This must be done carefully because after this work I want this version to be ready to ship as an update to Google Play.

 Main objective:
 Build a complete post-payment order management system, modern, polished, production-safe, and fully integrated with my existing app style, my font, my Firestore structure, and my current architecture.

 Scope:
 1) Post-payment order lifecycle
 Add all important post-payment cases and screens that a real modern commerce app should have after payment success, including at minimum:
 - Order success state
 - Order details state
 - Order tracking / fulfillment states
 - Cancel request flow if order is still eligible
 - Return request flow
 - Refund request flow if applicable
 - Exchange / replacement request flow if applicable
 - Complaint / issue reporting flow
 - Damaged item / wrong item / missing item / late delivery / duplicate payment / payment issue cases
 - Support/contact case from order details
 - Status timeline for each request
 - Final resolution states: approved, rejected, pending review, completed, refunded, partially refunded, cancelled, closed

 Do not implement this in a shallow way.
 I want the full end-to-end system with proper business logic, data models, Firestore integration, validation, loading/error/empty states, and admin-friendly structure for future extension.

 2) Best-practice UX and product behavior
 Research and follow strong modern e-commerce best practices for account self-service, returns, and post-order support.
 The UX should prioritize:
 - Clear self-service actions from order details
 - Easy return/complaint initiation
 - Transparent status communication
 - Eligibility rules shown clearly
 - Reason selection and optional notes/photos if useful
 - Confirmation screens
 - Friendly but premium UX
 - Reduced support confusion
 A lot of users use account areas specifically to manage returns, and poor returns UX hurts conversion, so design this carefully and not as an afterthought.  [oai_citation:0‡Baymard Institute](https://baymard.com/ecommerce-design-examples/64-order-returns?utm_source=chatgpt.com)

 3) UI / design requirements
 - Keep everything aligned with my app branding, current typography, spacing, and component style
 - Use my existing font and design system
 - Make it feel premium and modern for 2026
 - If compatible with my current app style, use elegant glass-style buttons/cards inspired by modern iOS-like aesthetics, but do NOT break Android usability or accessibility
 - Keep Android native quality high
 - Add polished animations only where they improve UX
 - No messy, oversized, or inconsistent components
 - Every state must look intentional and finished

 4) Return / complaint / refund architecture
 Implement a full structure for:
 - Return reasons
 - Complaint reasons
 - Request status
 - Eligibility rules
 - Evidence attachments if the project already supports uploads, otherwise scaffold cleanly for future support
 - Notes / user explanation
 - Admin review fields
 - Resolution metadata
 - Timestamps
 - Audit/history trail
 - Idempotent request creation
 - Prevention of duplicate accidental submissions

 Suggested entities / collections can include something like:
 - orders
 - order_events
 - return_requests
 - complaint_requests
 - refund_requests
 - support_threads or support_cases
 But do not blindly use these names if the project already has a better structure. Reuse existing architecture where possible and extend it cleanly.

 5) Firestore and backend safety
 Integrate properly with Firestore and make the data model production-safe:
 - Use secure structure
 - Keep reads/writes efficient
 - Avoid duplicated inconsistent sources of truth
 - Use transactions/batched writes where needed
 - Add or update Firestore Security Rules as needed
 - Validate ownership so users can only access their own orders/requests
 - Validate allowed status transitions
 - Make request creation and order state updates safe against race conditions
 Firestore security rules should enforce user-based access and validation, not just UI checks.  [oai_citation:1‡Firebase](https://firebase.google.com/docs/firestore/security/get-started?utm_source=chatgpt.com)

 6) Functional requirements in the app
 From the user side, I want:
 - Order details screen updated with post-payment actions
 - Dynamic action buttons based on order status and eligibility
 - Return request form
 - Complaint request form
 - Refund-related request form where applicable
 - Request history list
 - Request details screen
 - Order timeline / status tracker
 - Proper success / failure / pending states
 - Empty states
 - Retry states
 - Offline-friendly behavior if applicable in the current app architecture
 - Snackbar/toast/dialog handling done professionally

 7) Eligibility engine
 Implement clear business rules for when actions are allowed, for example:
 - Can return only within allowed window
 - Can cancel only before certain fulfillment state
 - Can complain for delivered orders or payment issues
 - Prevent invalid flows
 - Show human-readable explanation when an action is unavailable
 Make this engine centralized, testable, and easy to change later.

 8) Debug / temporary testing flag
 Add a TEMPORARY flag starting from the current user test flow so I can easily test without real QIB verification every time.

 Important behavior of this flag:
 - When OFF: app works as full production behavior
 - When ON: app skips QIB verification and simulates payment success / fake verification success so I can test the full post-payment flow quickly

 Very important safety rules for this flag:
 - It must be impossible to ship this unsafe behavior accidentally in release production builds
 - The bypass must be debug-only or protected by build config / internal environment gating / clearly isolated feature flag architecture
 - Release build must default to real production path only
 - Do not leave insecure shortcuts reachable by normal users
 - Add clear naming and comments so this is easy to remove later
 Android officially distinguishes debuggable/testing behavior from release behavior; follow that pattern and keep this isolated safely.  [oai_citation:2‡Android Developers](https://developer.android.com/guide/app-compatibility/restrictions-non-sdk-interfaces?utm_source=chatgpt.com)

 9) Production-readiness expectations
 I do NOT want a prototype.
 I want:
 - clean architecture
 - no hacks
 - no dead code
 - no broken navigation
 - no placeholder logic pretending to be done
 - no TODOs left in critical paths
 - no UI inconsistencies
 - no crashes
 - no memory leaks
 - no duplicated business logic spread across screens
 - no unsafe Firestore writes
 - no weak validation

 10) Testing
 Add/update tests for the important logic:
 - eligibility rules
 - request creation
 - status transitions
 - fake payment flag behavior
 - Firestore mapping / serialization where relevant
 - ViewModel or state logic if architecture uses it

 11) Performance and polish
 - Keep screens fast
 - Minimize unnecessary Firestore reads/writes
 - Use proper loading strategies
 - Avoid janky transitions
 - Keep forms responsive
 - Keep list rendering efficient
 - Make the implementation maintainable and scalable

 12) Deliverables
 I want you to:
 - inspect the existing project structure first
 - understand current payment success flow
 - extend it cleanly instead of rewriting randomly
 - implement the full feature
 - update navigation
 - update models/repositories/use-cases/viewmodels/controllers as needed
 - update Firestore rules if needed
 - update any enums/status mapping/constants
 - add any missing reusable UI components
 - remove redundant old code if replaced
 - ensure the app builds cleanly

 13) Final handoff requirements
 When finished, give me:
 - concise summary of what was added
 - list of all new screens/components/models/collections
 - all feature flags added
 - exact places where QIB bypass test flag is controlled
 - any Firestore rules added/changed
 - any manual setup required from my side
 - release-risk notes if anything must be double-checked before Play Store submission

 Important implementation mindset:
 Think like a senior production engineer and product designer, not like a code generator.
 Do not miss edge cases.
 Do not do partial work.
 Do not stop at UI only.
 Do the full user flow, data flow, state flow, and failure handling.

 If there is any conflict between my existing architecture and a better implementation, keep compatibility where possible but prefer the cleaner long-term production-safe structure.

 Make it feel like a complete real app feature, not an add-on.

7.
 */
