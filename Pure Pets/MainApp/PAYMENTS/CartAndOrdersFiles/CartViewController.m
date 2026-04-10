
//  CartViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 29/06/2025.

#import "CartViewController.h"
#import "BBCheckoutSummaryView.h"
#import "CartManager.h"
#import "PPCartCalculator.h"
#import "PPOrderManager.h"
#import "PPSPinnerView.h"
#import "ChManager.h"
#import "AppClasses.h"
#import "PPCommerceFeedbackManager.h"
#import "PPChatsFunc.h"

static NSString *const kCartSupportPhoneNumber = @"+97459997720";
static CGFloat const kCartScreenHorizontalInset = 16.0;
static CGFloat const kCartFloatingSummaryBottomInset = 12.0;

@interface CustomTextViewCell : XLFormTextViewCell @end

@implementation CustomTextViewCell
- (void)configure {
    [super configure];
    self.textView.layer.cornerRadius = 12;
    self.textView.layer.masksToBounds = YES;
    self.textView.backgroundColor = GM.AppForegroundColor;
}

@end
/*
@interface PPInsetLabel : UILabel
@property (nonatomic, assign) UIEdgeInsets textInsets;
@end

@implementation PPInsetLabel

- (instancetype)init
{
    self = [super init];
    if (self) {
        _textInsets = UIEdgeInsetsMake(12.0, 14.0, 12.0, 14.0);
    }
    return self;
}

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines
{
    CGRect insetBounds = UIEdgeInsetsInsetRect(bounds, self.textInsets);
    CGRect textRect = [super textRectForBounds:insetBounds limitedToNumberOfLines:numberOfLines];
    textRect.origin.x -= self.textInsets.left;
    textRect.origin.y -= self.textInsets.top;
    textRect.size.width += (self.textInsets.left + self.textInsets.right);
    textRect.size.height += (self.textInsets.top + self.textInsets.bottom);
    return textRect;
}

- (void)drawTextInRect:(CGRect)rect
{
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, self.textInsets)];
}

@end
*/
@interface CartViewController ()
@property (nonatomic, strong) PPSPinnerView *spinner;

@property (nonatomic, strong) UITableView *cartTableView;
@property (nonatomic, strong) BBCheckoutSummaryView *summaryView;
@property (nonatomic, strong) UIView *topGlowView;
@property (nonatomic, strong) UIView *bottomGlowView;
@property (nonatomic, strong) UIVisualEffectView *headerChromeView;
@property (nonatomic, strong) UIView *headerIconContainerView;
@property (nonatomic, strong) UIImageView *headerIconView;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerSubtitleLabel;
@property (nonatomic, strong) UIButton *headerSupportButton;
@property (nonatomic, strong) UILabel *itemsMetricLabel;
@property (nonatomic, strong) UILabel *subtotalMetricLabel;
@property (nonatomic, strong) UILabel *shippingMetricLabel;
@property (nonatomic, strong) UIView *undoContainerView;
@property (nonatomic, strong) UILabel *undoLabel;
@property (nonatomic, strong) UIButton *undoButton;
@property (nonatomic, strong) CartItem *lastRemovedCartItem;
@property (nonatomic, assign) NSInteger lastRemovedCartIndex;
@property (nonatomic, assign) NSUInteger undoPresentationToken;

@property (nonatomic,
           strong,
           nullable) NSLayoutConstraint *tableBottomConstraint;
@property (nonatomic, strong, readonly) PPEmptyStateConfig *config;
@property (nonatomic, assign) BOOL isPerformingTableMutation;
@property (nonatomic, assign) BOOL didRunEntranceAnimation;
@end

@implementation CartViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    [self pp_buildBackgroundDecor];
    [self pp_buildHeaderChrome];

    self.cartTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.cartTableView.dataSource = self;
    self.cartTableView.delegate = self;
    self.cartTableView.backgroundColor = UIColor.clearColor;
    self.cartTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.cartTableView.separatorColor = UIColor.clearColor;
    self.cartTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cartTableView.showsHorizontalScrollIndicator = NO;
    self.cartTableView.showsVerticalScrollIndicator = NO;
    self.cartTableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.cartTableView.contentInset = UIEdgeInsetsMake(14, 0, 26, 0);
    self.cartTableView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 26, 0);
    self.cartTableView.estimatedRowHeight = 120.0;
    if (@available(iOS 15.0, *)) {
        self.cartTableView.sectionHeaderTopPadding = 0.0;
    }

    [self.cartTableView registerClass:[CartTableViewCell class] forCellReuseIdentifier:@"CartTableViewCell"];
    [self.cartTableView registerClass:[PPCartTableCell class] forCellReuseIdentifier:@"PPCartTableCell"];

    [self.view addSubview:self.cartTableView];

    [self setSummuryViewAtBottom];
    [self pp_setupUndoBarIfNeeded];

    [NSLayoutConstraint activateConstraints:@[
        [self.cartTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.cartTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.cartTableView.topAnchor constraintEqualToAnchor:self.headerChromeView.bottomAnchor constant:18.0]
    ]];
    self.tableBottomConstraint =
    [self.cartTableView.bottomAnchor constraintEqualToAnchor:self.summaryView.topAnchor constant:-16.0];
    self.tableBottomConstraint.active = YES;

    // Empty state config (reused)
    [self emptyViewConfiger];

    // Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateViewFromSync)
                                                 name:kCartUpdatedNotification
                                               object:nil];
    
    // Initial UI
    [self setupFormFooterFrom:@"LOAD"];
    [self updateTotalLabel];
    [self pp_applyEmptyStateIfNeeded];
}

- (void)setSummuryViewAtBottom
{
    self.summaryView = [[BBCheckoutSummaryView alloc] init];
    
    [self.view addSubview:self.summaryView];
    [self.summaryView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-kCartFloatingSummaryBottomInset].active = YES;
    [self.summaryView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kCartScreenHorizontalInset].active = YES;
    [self.summaryView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kCartScreenHorizontalInset].active = YES;

    __weak typeof(self) weakSelf = self;
    self.summaryView.onTapCheckOut = ^{
        NSLog(@"🛒 Checkout tapped on CART      +Helper");
        [weakSelf checkoutTapped];
    };

    PPCartSummary *initSummary = [PPCartCalculator currentSummary];
    [self.summaryView updateTotalsWithItems:initSummary.subtotal shipping:initSummary.shippingFee showTitle:YES];
    self.summaryView.showDetails = YES;
    [self.summaryView updatePreviewItems:CartManager.sharedManager.cartItems];
    self.summaryView.showsItemsPreview = NO;
    [self.summaryView setCardBackgroundImage:PPImage(@"4444")];
    [self.summaryView setCheckoutBTNTitle:kLang(@"Checkout") image: [UIImage pp_symbolNamed:Language.isRTL ? @"arrow.left" : @"arrow.right" pointSize:18 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleLarge palette:@[AppForgroundColr,AppForgroundColr] makeTemplate:NO]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    [self.summaryView layoutIfNeeded];

    if (self.undoContainerView && !CGRectIsEmpty(self.undoContainerView.bounds)) {
        self.undoContainerView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.undoContainerView.bounds
                                      cornerRadius:self.undoContainerView.layer.cornerRadius].CGPath;
    }

    if (self.headerChromeView && !CGRectIsEmpty(self.headerChromeView.bounds)) {
        self.headerChromeView.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:self.headerChromeView.bounds
                                      cornerRadius:self.headerChromeView.layer.cornerRadius].CGPath;
    }
}

- (void)reloadFormData {
    // All pricing now flows through PPCartCalculator — no local math needed.
    // updateTotalLabel and pp_cartDidUpdate handle the UI refresh path.
}
- (void)setupFormFooterFrom:(NSString *)setupFrom {
    
  // // [self pp_applyEmptyStateIfNeeded];
}


-(void)startEditingCartItems
{
    UIAlertController *menu = [UIAlertController
                               alertControllerWithTitle:kLang(@"cart_support_menu_title")
                               message:nil
                               preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *callAction = [UIAlertAction actionWithTitle:kLang(@"Call")
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(__unused UIAlertAction * _Nonnull action) {
        [AppClasses callPhoneNumber:kCartSupportPhoneNumber fromViewController:self];
    }];
    [menu addAction:callAction];

    UIAlertAction *chatAction = [UIAlertAction actionWithTitle:kLang(@"cart_support_chat")
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(__unused UIAlertAction * _Nonnull action) {
        if (!UserManager.sharedManager.isUserLoggedIn) {
            [UserManager showPromptOnTopController];
            return;
        }
        [[ChManager sharedManager] openSupportChatFromController:self];
    }];
    [menu addAction:chatAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:kLang(@"cancel")
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [menu addAction:cancelAction];

    UIPopoverPresentationController *popover = menu.popoverPresentationController;
    if (popover) {
        UIBarButtonItem *sourceButton = self.navigationItem.rightBarButtonItem;
        if (sourceButton) {
            popover.barButtonItem = sourceButton;
        } else {
            popover.sourceView = self.view;
            popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                            CGRectGetMinY(self.view.bounds) + 44.0,
                                            1.0,
                                            1.0);
        }
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    [self presentViewController:menu animated:YES completion:nil];
}

-(void)viewWillAppear:(BOOL)animated
{
    [CartManager.sharedManager refreshPricingConfiguration];
    [super viewWillAppear:animated];

    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"cartTitle") showBack:NO];

    NSString *leadingSymbol = [self pp_cartCanNavigateBackInStack] ? PPChevronName : @"house.fill";
    self.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithImage:PPSYSImage(leadingSymbol)
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(pp_handleLeadingCartNavigation)];
    self.navigationItem.leftBarButtonItem.accessibilityLabel =
    [self pp_cartCanNavigateBackInStack]
    ? NSLocalizedString(@"Back", @"Navigate back")
    : NSLocalizedString(@"Home", @"Navigate home");

    self.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithImage:PPSYSImage(@"headphones.dots")
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(startEditingCartItems)];
    self.navigationItem.rightBarButtonItem.accessibilityLabel = NSLocalizedString(@"a11y_btn_cart_support", @"Contact support");
    self.navigationItem.rightBarButtonItem.accessibilityHint  = NSLocalizedString(@"a11y_btn_cart_support_hint", @"Double-tap to contact customer support");

    [self.summaryView setCheckoutLoading:NO];
    [self updateTotalLabel];
    [self.summaryView layoutIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_runEntranceAnimationIfNeeded];
}

- (BOOL)pp_cartCanNavigateBackInStack
{
    UINavigationController *navigationController = self.navigationController;
    if (![navigationController isKindOfClass:UINavigationController.class]) {
        return NO;
    }
    return navigationController.viewControllers.count > 1 &&
    navigationController.viewControllers.lastObject == self;
}

- (void)pp_handleLeadingCartNavigation
{
    if ([self pp_cartCanNavigateBackInStack]) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }

    UITabBarController *tabBarController = self.tabBarController;
    if (tabBarController.viewControllers.count > 0) {
        UIViewController *homeController = tabBarController.viewControllers.firstObject;
        if ([homeController isKindOfClass:UINavigationController.class]) {
            UINavigationController *homeNavigationController = (UINavigationController *)homeController;
            BOOL isCurrentNavigation = (homeNavigationController == self.navigationController);
            [homeNavigationController popToRootViewControllerAnimated:isCurrentNavigation];
            tabBarController.selectedIndex = 0;
            return;
        }
        tabBarController.selectedIndex = 0;
        return;
    }

    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    [self.navigationController popToRootViewControllerAnimated:YES];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    //[[NSNotificationCenter defaultCenter]   postNotificationName:PPExpandSystemTabBarNotification  object:nil];
    [_summaryView pp_stopTrustBannerShimmer];
    [self pp_hideUndoBarAnimated:NO clearPayload:NO];
}

- (void)continueShopping
{
    [self pp_handleLeadingCartNavigation];
}

- (void)pp_buildBackgroundDecor
{
    if (self.topGlowView || self.bottomGlowView) return;

    UIView *topGlow = [[UIView alloc] init];
    topGlow.translatesAutoresizingMaskIntoConstraints = NO;
    topGlow.userInteractionEnabled = NO;
    topGlow.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.12];
    topGlow.layer.cornerRadius = 120.0;
    topGlow.alpha = 0.9;

    UIView *bottomGlow = [[UIView alloc] init];
    bottomGlow.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlow.userInteractionEnabled = NO;
    bottomGlow.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:0.08];
    bottomGlow.layer.cornerRadius = 140.0;

    [self.view addSubview:topGlow];
    [self.view addSubview:bottomGlow];

    [NSLayoutConstraint activateConstraints:@[
        [topGlow.widthAnchor constraintEqualToConstant:240.0],
        [topGlow.heightAnchor constraintEqualToConstant:240.0],
        [topGlow.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-54.0],
        [topGlow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:78.0],

        [bottomGlow.widthAnchor constraintEqualToConstant:280.0],
        [bottomGlow.heightAnchor constraintEqualToConstant:280.0],
        [bottomGlow.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:92.0],
        [bottomGlow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-104.0]
    ]];

    self.topGlowView = topGlow;
    self.bottomGlowView = bottomGlow;
}

- (UILabel *)pp_buildMetricLabel
{
    PPInsetLabel *label = [[PPInsetLabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.numberOfLines = 0;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    label.layer.cornerRadius = 20.0;
    label.layer.masksToBounds = YES;
    label.layer.borderWidth = 1.0;
    label.layer.borderColor = [UIColor.labelColor colorWithAlphaComponent:0.06].CGColor;
    label.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.035];
    return label;
}

- (void)pp_applyMetricLabel:(UILabel *)label
                      title:(NSString *)title
                      value:(NSString *)value
                 valueColor:(UIColor *)valueColor
{
    if (!label) return;

    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = Language.alignmentForCurrentLanguage;
    paragraphStyle.lineSpacing = 2.0;

    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:title ?: @""
                                                                             attributes:@{
        NSFontAttributeName: [GM MidFontWithSize:11],
        NSForegroundColorAttributeName: [UIColor.labelColor colorWithAlphaComponent:0.55],
        NSParagraphStyleAttributeName: paragraphStyle
    }];

    NSString *valueLine = value.length > 0 ? [NSString stringWithFormat:@"\n%@", value] : @"";
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:valueLine
                                                                  attributes:@{
        NSFontAttributeName: [GM boldFontWithSize:16],
        NSForegroundColorAttributeName: valueColor ?: UIColor.labelColor,
        NSParagraphStyleAttributeName: paragraphStyle
    }]];

    label.attributedText = text;
}

- (void)pp_styleHeaderSupportButton:(UIButton *)button
{
    if (!button) return;

    UIImage *supportImage = [UIImage pp_symbolNamed:@"headphones.dots"
                                          pointSize:14
                                             weight:UIImageSymbolWeightSemibold
                                              scale:UIImageSymbolScaleMedium
                                            palette:@[AppPrimaryTextClr ?: UIColor.labelColor,
                                                      AppPrimaryTextClr ?: UIColor.labelColor]
                                       makeTemplate:YES];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.image = supportImage;
        config.imagePlacement = NSDirectionalRectEdgeLeading;
        config.imagePadding = 6.0;
        config.contentInsets = NSDirectionalEdgeInsetsMake(10.0, 12.0, 10.0, 12.0);
        config.baseForegroundColor = AppPrimaryTextClr ?: UIColor.labelColor;
        config.background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.82];
        config.background.strokeColor = [UIColor.labelColor colorWithAlphaComponent:0.06];
        config.background.strokeWidth = 1.0;
        config.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"Support")
                                                                  attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:13],
            NSForegroundColorAttributeName: AppPrimaryTextClr ?: UIColor.labelColor
        }];
        button.configuration = config;
    } else {
        [button setTitle:kLang(@"Support") forState:UIControlStateNormal];
        [button setImage:supportImage forState:UIControlStateNormal];
        [button setTitleColor:AppPrimaryTextClr ?: UIColor.labelColor forState:UIControlStateNormal];
        button.tintColor = AppPrimaryTextClr ?: UIColor.labelColor;
        button.titleLabel.font = [GM boldFontWithSize:13];
        button.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.82];
        button.layer.cornerRadius = 19.0;
        button.layer.borderWidth = 1.0;
        button.layer.borderColor = [UIColor.labelColor colorWithAlphaComponent:0.06].CGColor;
        button.contentEdgeInsets = UIEdgeInsetsMake(10.0, 12.0, 10.0, 12.0);
    }

    button.accessibilityLabel = NSLocalizedString(@"a11y_btn_cart_support", @"Contact support");
    button.accessibilityHint = NSLocalizedString(@"a11y_btn_cart_support_hint", @"Double-tap to contact customer support");
}

- (void)pp_setUndoButtonTitle:(NSString *)title
{
    NSString *resolvedTitle = title ?: kLang(@"cart_undo_action");
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = self.undoButton.configuration;
        config.attributedTitle = [[NSAttributedString alloc] initWithString:resolvedTitle
                                                                  attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:14],
            NSForegroundColorAttributeName: AppPrimaryClr ?: UIColor.labelColor
        }];
        self.undoButton.configuration = config;
    } else {
        [self.undoButton setTitle:resolvedTitle forState:UIControlStateNormal];
    }
}

- (void)pp_buildHeaderChrome
{
    if (self.headerChromeView) return;

    UIBlurEffect *effect = nil;
    if (@available(iOS 13.0, *)) {
        effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    }

    UIVisualEffectView *chromeView = [[UIVisualEffectView alloc] initWithEffect:effect];
    chromeView.translatesAutoresizingMaskIntoConstraints = NO;
    chromeView.layer.cornerRadius = 30.0;
    chromeView.clipsToBounds = NO;
    chromeView.layer.borderWidth = 1.0;
    chromeView.layer.borderColor = [UIColor.labelColor colorWithAlphaComponent:0.06].CGColor;
    chromeView.layer.shadowColor = UIColor.blackColor.CGColor;
    chromeView.layer.shadowOpacity = 0.08;
    chromeView.layer.shadowOffset = CGSizeMake(0.0, 18.0);
    chromeView.layer.shadowRadius = 28.0;
    chromeView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.54];
    chromeView.contentView.layer.cornerRadius = 30.0;
    chromeView.contentView.clipsToBounds = YES;

    UIView *tintOverlay = [[UIView alloc] init];
    tintOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    tintOverlay.userInteractionEnabled = NO;
    tintOverlay.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.58];

    UIView *iconContainer = [[UIView alloc] init];
    iconContainer.translatesAutoresizingMaskIntoConstraints = NO;
    iconContainer.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.12];
    iconContainer.layer.cornerRadius = 24.0;

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:@"bag.fill"
                                                                              pointSize:20
                                                                                 weight:UIImageSymbolWeightSemibold
                                                                                  scale:UIImageSymbolScaleLarge
                                                                                palette:@[AppPrimaryClr ?: UIColor.labelColor,
                                                                                          AppPrimaryClr ?: UIColor.labelColor]
                                                                           makeTemplate:YES]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = AppPrimaryClr ?: UIColor.labelColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:28];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.text = kLang(@"cartTitle");

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.font = [GM MidFontWithSize:14];
    subtitleLabel.textColor = [UIColor.labelColor colorWithAlphaComponent:0.62];
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;

    UIButton *supportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    supportButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self pp_styleHeaderSupportButton:supportButton];
    [supportButton addTarget:self action:@selector(startEditingCartItems) forControlEvents:UIControlEventTouchUpInside];

    UILabel *itemsMetricLabel = [self pp_buildMetricLabel];
    UILabel *subtotalMetricLabel = [self pp_buildMetricLabel];
    UILabel *shippingMetricLabel = [self pp_buildMetricLabel];

    UIStackView *metricsStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        itemsMetricLabel,
        subtotalMetricLabel,
        shippingMetricLabel
    ]];
    metricsStack.translatesAutoresizingMaskIntoConstraints = NO;
    metricsStack.axis = UILayoutConstraintAxisHorizontal;
    metricsStack.alignment = UIStackViewAlignmentFill;
    metricsStack.distribution = UIStackViewDistributionFillEqually;
    metricsStack.spacing = 10.0;

    UIView *spacer = [[UIView alloc] init];
    spacer.translatesAutoresizingMaskIntoConstraints = NO;
    [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [spacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *topRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        iconContainer,
        spacer,
        supportButton
    ]];
    topRow.translatesAutoresizingMaskIntoConstraints = NO;
    topRow.axis = UILayoutConstraintAxisHorizontal;
    topRow.alignment = UIStackViewAlignmentCenter;
    topRow.spacing = 12.0;

    [self.view addSubview:chromeView];
    [chromeView.contentView addSubview:tintOverlay];
    [chromeView.contentView addSubview:topRow];
    [chromeView.contentView addSubview:titleLabel];
    [chromeView.contentView addSubview:subtitleLabel];
    [chromeView.contentView addSubview:metricsStack];
    [iconContainer addSubview:iconView];

    [NSLayoutConstraint activateConstraints:@[
        [chromeView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8.0],
        [chromeView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kCartScreenHorizontalInset],
        [chromeView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kCartScreenHorizontalInset],

        [tintOverlay.topAnchor constraintEqualToAnchor:chromeView.contentView.topAnchor],
        [tintOverlay.leadingAnchor constraintEqualToAnchor:chromeView.contentView.leadingAnchor],
        [tintOverlay.trailingAnchor constraintEqualToAnchor:chromeView.contentView.trailingAnchor],
        [tintOverlay.bottomAnchor constraintEqualToAnchor:chromeView.contentView.bottomAnchor],

        [topRow.topAnchor constraintEqualToAnchor:chromeView.contentView.topAnchor constant:16.0],
        [topRow.leadingAnchor constraintEqualToAnchor:chromeView.contentView.leadingAnchor constant:16.0],
        [topRow.trailingAnchor constraintEqualToAnchor:chromeView.contentView.trailingAnchor constant:-16.0],

        [iconContainer.widthAnchor constraintEqualToConstant:48.0],
        [iconContainer.heightAnchor constraintEqualToConstant:48.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconContainer.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconContainer.centerYAnchor],

        [supportButton.heightAnchor constraintEqualToConstant:38.0],

        [titleLabel.topAnchor constraintEqualToAnchor:topRow.bottomAnchor constant:16.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:chromeView.contentView.leadingAnchor constant:16.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:chromeView.contentView.trailingAnchor constant:-16.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

        [metricsStack.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:18.0],
        [metricsStack.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [metricsStack.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [metricsStack.bottomAnchor constraintEqualToAnchor:chromeView.contentView.bottomAnchor constant:-16.0],

        [itemsMetricLabel.heightAnchor constraintGreaterThanOrEqualToConstant:68.0]
    ]];

    self.headerChromeView = chromeView;
    self.headerIconContainerView = iconContainer;
    self.headerIconView = iconView;
    self.headerTitleLabel = titleLabel;
    self.headerSubtitleLabel = subtitleLabel;
    self.headerSupportButton = supportButton;
    self.itemsMetricLabel = itemsMetricLabel;
    self.subtotalMetricLabel = subtotalMetricLabel;
    self.shippingMetricLabel = shippingMetricLabel;
}

- (NSString *)pp_shippingMetricValueForSummary:(PPCartSummary *)summary
{
    if (!summary || summary.shippingFee <= 0.009) {
        return kLang(@"Free");
    }
    return [PPChatsFunc formattedCurrency:summary.shippingFee];
}

- (void)pp_refreshHeaderChromeWithSummary:(PPCartSummary *)summary
{
    NSInteger itemsCount = summary.totalQuantity;
    UIColor *accentColor = AppPrimaryClr ?: UIColor.labelColor;

    self.headerTitleLabel.text = kLang(@"cartTitle");
    self.headerSubtitleLabel.text = itemsCount > 0 ? kLang(@"Securecheckout") : kLang(@"empty_cart_subtitle");
    self.headerIconContainerView.backgroundColor =
        [accentColor colorWithAlphaComponent:itemsCount > 0 ? 0.14 : 0.08];

    [self pp_applyMetricLabel:self.itemsMetricLabel
                        title:kLang(@"Selected Items")
                        value:[NSString stringWithFormat:@"%ld", (long)itemsCount]
                   valueColor:AppPrimaryTextClr ?: UIColor.labelColor];

    [self pp_applyMetricLabel:self.subtotalMetricLabel
                        title:kLang(@"Subtotal")
                        value:[PPChatsFunc formattedCurrency:summary.subtotal]
                   valueColor:AppPrimaryTextClr ?: UIColor.labelColor];

    [self pp_applyMetricLabel:self.shippingMetricLabel
                        title:kLang(@"Shipping Fee")
                        value:[self pp_shippingMetricValueForSummary:summary]
                   valueColor:summary.shippingFee <= 0.009 ? accentColor : (AppPrimaryTextClr ?: UIColor.labelColor)];
}

- (void)pp_runEntranceAnimationIfNeeded
{
    if (self.didRunEntranceAnimation) return;
    self.didRunEntranceAnimation = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    BOOL shouldShowSummary = self.summaryView.alpha > 0.01;
    self.headerChromeView.alpha = 0.0;
    self.cartTableView.alpha = 0.0;
    self.summaryView.alpha = shouldShowSummary ? 0.0 : self.summaryView.alpha;

    self.headerChromeView.transform = CGAffineTransformMakeTranslation(0.0, 20.0);
    self.cartTableView.transform = CGAffineTransformMakeTranslation(0.0, 32.0);
    self.summaryView.transform = CGAffineTransformMakeTranslation(0.0, 26.0);

    [UIView animateWithDuration:0.62
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.headerChromeView.alpha = 1.0;
        self.headerChromeView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.62
                          delay:0.04
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.cartTableView.alpha = 1.0;
        self.cartTableView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.58
                          delay:0.08
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.summaryView.alpha = shouldShowSummary ? 1.0 : self.summaryView.alpha;
        self.summaryView.transform = CGAffineTransformIdentity;
    } completion:nil];
}


- (void)emptyViewConfiger {

    _config = [PPEmptyStateConfig new];
    _config.animationName = @"Shopping Cart Empty.json";
    _config.title =  kLang(@"empty_cart_title");
    _config.subTitle = kLang(@"empty_cart_subtitle");
    _config.buttonTitle = kLang(@"continue_shopping");
    _config.target = self;
    _config.action = @selector(continueShopping);
    _config.isNetworkFile = YES;
    
    if ([CartManager sharedManager].cartItems.count == 0) {
        // self.checkoutButton.alpha = 0;
    } else {
        // self.checkoutButton.alpha = 1;
    }
}

#pragma mark - Empty State (Reusable Block)

- (void)pp_applyEmptyStateIfNeeded
{
    if (!self.cartTableView) return;

    NSInteger itemsCount = [CartManager sharedManager].cartItems.count;
    if (itemsCount > 0) {
        self.cartTableView.backgroundView = nil;
        return;
    }

    UIView *container = [[UIView alloc] initWithFrame:self.cartTableView.bounds];
    container.backgroundColor = UIColor.clearColor;
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UIView *orbView = [[UIView alloc] init];
    orbView.translatesAutoresizingMaskIntoConstraints = NO;
    orbView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
    orbView.layer.cornerRadius = 42.0;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage pp_symbolNamed:@"bag"
                                                                         pointSize:34
                                                                            weight:UIImageSymbolWeightMedium
                                                                             scale:UIImageSymbolScaleLarge
                                                                           palette:@[AppPrimaryClr ?: UIColor.labelColor,
                                                                                     AppPrimaryClr ?: UIColor.labelColor]
                                                                      makeTemplate:YES]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = AppPrimaryClr ?: UIColor.labelColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = kLang(@"empty_cart_title");
    titleLabel.font = [GM boldFontWithSize:24];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = kLang(@"empty_cart_subtitle");
    subtitleLabel.font = [GM MidFontWithSize:15];
    subtitleLabel.textColor = [UIColor.labelColor colorWithAlphaComponent:0.62];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 0;

    UIButton *actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self pp_styleHeaderSupportButton:actionButton];
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = actionButton.configuration;
        config.image = [UIImage pp_symbolNamed:Language.isRTL ? @"arrow.left" : @"arrow.right"
                                     pointSize:14
                                        weight:UIImageSymbolWeightSemibold
                                         scale:UIImageSymbolScaleMedium
                                       palette:@[AppForgroundColr ?: UIColor.whiteColor,
                                                 AppForgroundColr ?: UIColor.whiteColor]
                                  makeTemplate:YES];
        config.baseForegroundColor = AppForgroundColr ?: UIColor.whiteColor;
        config.background.backgroundColor = AppPrimaryClr ?: UIColor.labelColor;
        config.background.strokeWidth = 0.0;
        config.imagePlacement = NSDirectionalRectEdgeTrailing;
        config.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"continue_shopping")
                                                                  attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:15],
            NSForegroundColorAttributeName: AppForgroundColr ?: UIColor.whiteColor
        }];
        actionButton.configuration = config;
    } else {
        [actionButton setTitle:kLang(@"continue_shopping") forState:UIControlStateNormal];
        [actionButton setTitleColor:AppForgroundColr ?: UIColor.whiteColor forState:UIControlStateNormal];
        actionButton.backgroundColor = AppPrimaryClr ?: UIColor.labelColor;
        actionButton.layer.borderWidth = 0.0;
    }
    [actionButton addTarget:self
                     action:@selector(continueShopping)
           forControlEvents:UIControlEventTouchUpInside];
    actionButton.accessibilityLabel = kLang(@"continue_shopping");
    actionButton.accessibilityHint = nil;

    [orbView addSubview:icon];
    [stack addArrangedSubview:titleLabel];
    [stack addArrangedSubview:subtitleLabel];
    [stack addArrangedSubview:actionButton];

    [container addSubview:stack];
    [container addSubview:orbView];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:container.centerYAnchor constant:18.0],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:container.leadingAnchor constant:24],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-24],

        [orbView.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [orbView.bottomAnchor constraintEqualToAnchor:stack.topAnchor constant:-18.0],
        [orbView.widthAnchor constraintEqualToConstant:84.0],
        [orbView.heightAnchor constraintEqualToConstant:84.0],

        [icon.centerXAnchor constraintEqualToAnchor:orbView.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:orbView.centerYAnchor]
    ]];

    self.cartTableView.backgroundView = container;
}

 
- (void)showOders {
    OrderHistoryViewController *vc = [[OrderHistoryViewController alloc] init];
    vc.pp_transitionStyle = PPTransitionStyleNone;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)updateTotalLabel {
    PPCartSummary *summary = [PPCartCalculator currentSummary];

    [self.summaryView updateTotalsWithItems:summary.subtotal shipping:summary.shippingFee showTitle:YES];
    [self.summaryView updatePreviewItems:CartManager.sharedManager.cartItems];
    [self pp_refreshHeaderChromeWithSummary:summary];

    self.summaryView.alpha = (summary.uniqueItems > 0) ? 1.0 : 0.0;
    if (summary.uniqueItems > 0) {
        [self.summaryView pp_startTrustBannerShimmer];
    } else {
        [self.summaryView pp_stopTrustBannerShimmer];
    }

    [self pp_applyEmptyStateIfNeeded];
}

// Guard: Only reload if not mutating table (prevents reload/deleteRows conflict)
- (void)updateViewFromSync
{
    if (self.isPerformingTableMutation) {
        NSLog(@"[CART] 🔁 Skipping reload during table mutation");
        return;
    }

    [self.cartTableView reloadData];
    [self updateTotalLabel];
}

- (void)pp_notifyCartBadgeAndCollections
{
    if ([self.delegate respondsToSelector:@selector(loadItemsCountInBadge)]) {
        [self.delegate loadItemsCountInBadge];
    }
    if ([self.delegate respondsToSelector:@selector(updateCartAndReloadCollection)]) {
        [self.delegate updateCartAndReloadCollection];
    }
}

- (CartItem *)pp_cloneCartItem:(CartItem *)item
{
    if (!item) return nil;
    CartItem *copy = [[CartItem alloc] init];
    copy.itemID = item.itemID ?: @"";
    copy.name = item.name ?: @"";
    copy.quantity = item.quantity;
    copy.price = item.price;
    copy.imageURL = item.imageURL ?: @"";
    copy.type = item.type ?: @"";
    return copy;
}

- (void)pp_setupUndoBarIfNeeded
{
    if (self.undoContainerView) return;

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.94];
    container.layer.cornerRadius = 20.0;
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [UIColor.labelColor colorWithAlphaComponent:0.06].CGColor;
    container.layer.shadowColor = UIColor.blackColor.CGColor;
    container.layer.shadowOpacity = 0.10;
    container.layer.shadowOffset = CGSizeMake(0, 10);
    container.layer.shadowRadius = 18;
    container.layer.masksToBounds = NO;
    container.alpha = 0.0;
    container.hidden = YES;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM MidFontWithSize:15];
    label.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    label.numberOfLines = 2;
    label.text = kLang(@"cart_undo_message");
    label.textAlignment = Language.alignmentForCurrentLanguage;

    UIButton *undoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    undoButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self pp_styleHeaderSupportButton:undoButton];
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = undoButton.configuration;
        config.baseForegroundColor = AppPrimaryClr ?: UIColor.labelColor;
        config.background.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
        config.background.strokeWidth = 0.0;
        config.image = nil;
        config.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"cart_undo_action")
                                                                  attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:14],
            NSForegroundColorAttributeName: AppPrimaryClr ?: UIColor.labelColor
        }];
        undoButton.configuration = config;
    } else {
        undoButton.titleLabel.font = [GM boldFontWithSize:14];
        [undoButton setTitle:kLang(@"cart_undo_action") forState:UIControlStateNormal];
        [undoButton setTitleColor:AppPrimaryClr ?: UIColor.labelColor forState:UIControlStateNormal];
        undoButton.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
        undoButton.layer.borderWidth = 0.0;
    }
    [undoButton addTarget:self action:@selector(pp_undoLastRemovalTapped) forControlEvents:UIControlEventTouchUpInside];
    undoButton.accessibilityLabel = NSLocalizedString(@"a11y_btn_undo_remove", @"Undo remove");
    undoButton.accessibilityHint  = NSLocalizedString(@"a11y_btn_undo_remove_hint", @"Double-tap to restore the removed item");

    [container addSubview:label];
    [container addSubview:undoButton];
    [self.view addSubview:container];

    [NSLayoutConstraint activateConstraints:@[
        [container.leadingAnchor constraintEqualToAnchor:self.summaryView.leadingAnchor],
        [container.trailingAnchor constraintEqualToAnchor:self.summaryView.trailingAnchor],
        [container.bottomAnchor constraintEqualToAnchor:self.summaryView.topAnchor constant:-14],
        [container.heightAnchor constraintGreaterThanOrEqualToConstant:58],

        [label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16],
        [label.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:undoButton.leadingAnchor constant:-12],

        [undoButton.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-14],
        [undoButton.centerYAnchor constraintEqualToAnchor:container.centerYAnchor]
    ]];

    self.undoContainerView = container;
    self.undoLabel = label;
    self.undoButton = undoButton;
    self.lastRemovedCartIndex = NSNotFound;
    [self pp_setUndoButtonTitle:kLang(@"cart_undo_action")];
}

- (void)pp_presentUndoForItem:(CartItem *)item originalIndex:(NSInteger)index
{
    self.lastRemovedCartItem = [self pp_cloneCartItem:item];
    self.lastRemovedCartIndex = index;
    self.undoLabel.text = kLang(@"cart_undo_message");
    [self pp_setUndoButtonTitle:kLang(@"cart_undo_action")];

    self.undoPresentationToken += 1;
    NSUInteger token = self.undoPresentationToken;

    self.undoContainerView.hidden = NO;
    [UIView animateWithDuration:0.22 animations:^{
        self.undoContainerView.alpha = 1.0;
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (token != self.undoPresentationToken) return;
        [self pp_hideUndoBarAnimated:YES clearPayload:YES];
    });
}

- (void)pp_hideUndoBarAnimated:(BOOL)animated clearPayload:(BOOL)clearPayload
{
    self.undoPresentationToken += 1;
    if (clearPayload) {
        self.lastRemovedCartItem = nil;
        self.lastRemovedCartIndex = NSNotFound;
    }

    if (!animated) {
        self.undoContainerView.alpha = 0.0;
        self.undoContainerView.hidden = YES;
        return;
    }

    [UIView animateWithDuration:0.2 animations:^{
        self.undoContainerView.alpha = 0.0;
    } completion:^(__unused BOOL finished) {
        self.undoContainerView.hidden = YES;
    }];
}

- (void)pp_undoLastRemovalTapped
{
    if (!self.lastRemovedCartItem) return;

    CartItem *restored = [self pp_cloneCartItem:self.lastRemovedCartItem];
    NSInteger preferredIndex = self.lastRemovedCartIndex;
    [self pp_hideUndoBarAnimated:YES clearPayload:YES];

    CartManager *manager = [CartManager sharedManager];
    CartItem *existing = [manager getCartItemForItemID:restored.itemID];
    if (existing) {
        NSInteger mergedQuantity = existing.quantity + restored.quantity;
        [manager updateQuantity:mergedQuantity forItem:existing completion:nil];
    } else {
        NSInteger safeIndex = MIN(MAX(preferredIndex, 0), manager.cartItems.count);
        [manager.cartItems insertObject:restored atIndex:safeIndex];
        [manager saveCart];

        if (UserManager.sharedManager.currentUser.ID.length > 0) {
            [manager syncCartToFirestore:@[restored]];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:kCartUpdatedNotification object:nil];
        }
    }

    [self pp_notifyCartBadgeAndCollections];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartUndo];
}

- (void)pp_removeItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!indexPath) return;
    if (indexPath.row >= CartManager.sharedManager.cartItems.count) return;
    if (self.isPerformingTableMutation) return;

    self.isPerformingTableMutation = YES;

    CartItem *item = CartManager.sharedManager.cartItems[indexPath.row];
    CartItem *removedSnapshot = [self pp_cloneCartItem:item];
    NSInteger removedIndex = indexPath.row;

    [[CartManager sharedManager] removeItem:item];
    [[CartManager sharedManager] saveCart];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartItemRemoved];

    [self.cartTableView performBatchUpdates:^{
        [self.cartTableView deleteRowsAtIndexPaths:@[indexPath]
                                  withRowAnimation:UITableViewRowAnimationFade];
    } completion:^(__unused BOOL finished) {
        self.isPerformingTableMutation = NO;
        [self updateTotalLabel];
        [self pp_notifyCartBadgeAndCollections];
        [self pp_presentUndoForItem:removedSnapshot originalIndex:removedIndex];
    }];
}

- (void)checkoutTapped {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [self.summaryView setCheckoutLoading:NO];
        [UserManager showPromptOnTopController];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    if ([CartManager sharedManager].cartItems.count == 0) {
        [self.summaryView setCheckoutLoading:NO];
        [PPHUD showError:kLang(@"empty_cart_title")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    [self.summaryView setCheckoutLoading:YES];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];

    // Order is created in PPCheckoutCoordinator from payment screen.
    PPSelectPaymentVC *vc = [[PPSelectPaymentVC alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [CartManager sharedManager].cartItems.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    PPCartTableCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPCartTableCell"];
        if (!cell) cell = [[PPCartTableCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"PPCartTableCell"];
        
        CartItem *item = [CartManager sharedManager].cartItems[indexPath.row];
        [cell configureWithItem:item];
    __weak typeof(cell) weakCell = cell;
    cell.onAction = ^(CartItem *item, NSString *action) {
        if ([action isEqualToString:@"plus"] || [action isEqualToString:@"minus"]) {
            __strong typeof(weakCell) strongCell = weakCell;
            NSIndexPath *currentIndexPath = [tableView indexPathForCell:strongCell];
            if (currentIndexPath) {
                [tableView reloadRowsAtIndexPaths:@[currentIndexPath]
                                 withRowAnimation:UITableViewRowAnimationAutomatic];
            }

            [[CartManager sharedManager] updateQuantity:item.quantity
                                                forItem:item
                                             completion:nil];
            [self updateTotalLabel];
            return;
        }
        if ([action isEqualToString:@"remove"]) {
            __strong typeof(weakCell) cell = weakCell;
            NSIndexPath *currentIndexPath =
                [tableView indexPathForCell:cell];
            if (!currentIndexPath) return;
            [self pp_removeItemAtIndexPath:currentIndexPath];
        }
    };

    cell.layer.masksToBounds = NO;
    cell.clipsToBounds = NO;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    (void)indexPath;
    return 118.0;
}

// Enable swipe-to-delete (SAFE)
- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)style
forRowAtIndexPath:(NSIndexPath *)indexPath {

    if (style != UITableViewCellEditingStyleDelete) return;
    [self pp_removeItemAtIndexPath:indexPath];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= CartManager.sharedManager.cartItems.count) return nil;

    UIContextualAction *removeAction =
    [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                            title:kLang(@"cart_swipe_remove")
                                          handler:^(__unused UIContextualAction * _Nonnull action,
                                                    __unused UIView * _Nonnull sourceView,
                                                    void (^ _Nonnull completionHandler)(BOOL)) {
        [self pp_removeItemAtIndexPath:indexPath];
        completionHandler(YES);
    }];

    if (@available(iOS 13.0, *)) {
        removeAction.image = [UIImage systemImageNamed:@"trash.fill"];
    }
    removeAction.backgroundColor = [UIColor systemRedColor];

    UISwipeActionsConfiguration *config =
    [UISwipeActionsConfiguration configurationWithActions:@[removeAction]];
    config.performsFirstActionWithFullSwipe = YES;
    return config;
}

- (NSString *)tableView:(UITableView *)tableView
titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    (void)indexPath;
    return kLang(@"cart_swipe_remove");
}
/*
 // Remove from CartManager (single source of truth)
 [[CartManager sharedManager] removeItem:item];
 [[CartManager sharedManager] saveCart];
 */
- (void)syncCartToFirestore:(NSArray<CartItem *> *)items {
    // U8: Use authenticated UID from FIRAuth as primary source, with UserManager fallback
    NSString *userID = PPCurrentFIRAuthUser.uid;
    if (userID.length == 0) {
        userID = UserManager.sharedManager.currentUser.ID;
    }

    if (!userID || userID.length == 0) {
        NSLog(@"⚠️ [Cart] Cannot sync — no authenticated user");
        return;
    }

    // U6: Validate cart items before Firestore write
    if (items.count == 0) {
        NSLog(@"⚠️ [Cart] syncCartToFirestore called with empty items array");
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    NSString *orderID = [NSString stringWithFormat:@"order_%@", [[NSUUID UUID] UUIDString]];

    FIRDocumentReference *orderRef = [[[[db collectionWithPath:@"UsersCol"]
                                        documentWithPath:userID]
                                       collectionWithPath:@"orders"]
                                      documentWithPath:orderID];

    NSMutableDictionary *orderSummary = [NSMutableDictionary dictionary];
    NSMutableArray *itemData = [NSMutableArray array];
    NSInteger totalQty = 0;
    double totalPrice = 0;

    for (CartItem *item in items) {
        // U6: Validate each item before including in order
        if (item.itemID.length == 0 || item.name.length == 0) {
            NSLog(@"⚠️ [Cart] Skipping invalid item (missing ID or name)");
            continue;
        }
        NSInteger safeQty = MAX(1, MIN(item.quantity, 9999));
        double safePrice = MAX(0.0, MIN(item.price, 999999.0));
        totalQty += safeQty;
        totalPrice += safePrice * safeQty;
        [itemData addObject:@{
             @"itemID": item.itemID,
             @"name": item.name,
             @"quantity": @(safeQty),
             @"price": @(safePrice)
        }];
    }

    if (itemData.count == 0) {
        NSLog(@"⚠️ [Cart] No valid items to sync after validation");
        return;
    }

    orderSummary[@"totalQuantity"] = @(totalQty);
    orderSummary[@"totalPrice"] = @(totalPrice);
    orderSummary[@"createdAt"] = [FIRTimestamp timestamp];
    orderSummary[@"items"] = itemData;
    orderSummary[@"status"] = @(0);

    FIRWriteBatch *batch = [db batch];
    [batch setData:orderSummary forDocument:orderRef];

    [batch commitWithCompletion:^(NSError *_Nullable error) {
        if (error) {
            NSLog(@"❌ Batch upload failed: %@", error.localizedDescription);
        } else {
            NSLog(@"✅ Order %@ uploaded successfully", orderID);
            [[CartManager sharedManager] clearCart];
            [self.cartTableView reloadData];
            [self updateTotalLabel];
            
            [self.delegate loadItemsCountInBadge];

            if ([self.delegate respondsToSelector:@selector(updateCartAndReloadCollection)]) {
                [self.delegate updateCartAndReloadCollection];
            }
            
        }
    }];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    (void)indexPath;

    cell.layer.mask = nil;
    cell.contentView.layer.mask = nil;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    cell.alpha = 0.0;
    cell.transform = CGAffineTransformMakeTranslation(0.0, 10.0);

    [UIView animateWithDuration:0.34
                          delay:0.02
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end























//
//  PPPaymentSheettHelper.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/11/2025.
//

@implementation PPPaymentSheettHelper

#pragma mark - Public API

+ (void)showPaymentSheetIn:(UIViewController *)vc
             selectedMethod:(NSString *)methodName
                  onConfirm:(dispatch_block_t)confirm
                   onCancel:(dispatch_block_t)cancel {

    if (@available(iOS 15.0, *)) {
        // 🧊 Modern iOS Action Sheet
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"payment_confirm_title")
                                                                       message:[NSString stringWithFormat:kLang(@"payment_pay_using_format"), methodName ?: @""]
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

        UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:kLang(@"payment_confirm_action")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
            if (confirm) confirm();
        }];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:kLang(@"payment_cancel_action")
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction * _Nonnull action) {
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
            if (cancel) cancel();
        }];

        [alert addAction:confirmAction];
        [alert addAction:cancelAction];

        // 🧭 Customize sheet appearance (iOS 15+)
        if (@available(iOS 15.0, *)) {
            alert.sheetPresentationController.detents = @[
                [UISheetPresentationControllerDetent mediumDetent],
                [UISheetPresentationControllerDetent largeDetent]
            ];
            alert.sheetPresentationController.prefersGrabberVisible = YES;
            alert.sheetPresentationController.preferredCornerRadius = 22;
        }

        // iPad: actionSheet requires sourceView to avoid crash
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = vc.view;
            alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(vc.view.bounds), CGRectGetMidY(vc.view.bounds), 0, 0);
        }
        [vc presentViewController:alert animated:YES completion:nil];
    }
    else {
        // 🌫️ Fallback custom blur alert
        [self showLegacyBlurSheetIn:vc methodName:methodName onConfirm:confirm onCancel:cancel];
    }
}

#pragma mark - Legacy Blur Implementation

+ (void)showLegacyBlurSheetIn:(UIViewController *)vc
                   methodName:(NSString *)methodName
                    onConfirm:(dispatch_block_t)confirm
                     onCancel:(dispatch_block_t)cancel {

    UIView *container = [[UIView alloc] initWithFrame:vc.view.bounds];
    container.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    container.alpha = 0;
    [vc.view addSubview:container];

    // Blur background card
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    blurView.layer.cornerRadius = 18;
    blurView.layer.masksToBounds = YES;
    blurView.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *title = [[UILabel alloc] init];
    title.text = kLang(@"payment_confirm_title");
    title.font = [GM boldFontWithSize:20];
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *message = [[UILabel alloc] init];
    message.text = [NSString stringWithFormat:kLang(@"payment_pay_using_format"), methodName ?: @""];
    message.textAlignment = NSTextAlignmentCenter;
    message.textColor = UIColor.secondaryLabelColor;
    message.numberOfLines = 0;
    message.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *confirmBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [confirmBtn setTitle:kLang(@"payment_confirm_action") forState:UIControlStateNormal];
    confirmBtn.titleLabel.font = [GM boldFontWithSize:17];
    confirmBtn.translatesAutoresizingMaskIntoConstraints = NO;
    confirmBtn.backgroundColor = AppPrimaryClr;
    confirmBtn.tintColor = UIColor.whiteColor;
    confirmBtn.layer.cornerRadius = 10;
    [confirmBtn addTarget:self action:@selector(_confirmTap:) forControlEvents:UIControlEventTouchUpInside];
    confirmBtn.tag = 1; // tag to identify action

    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancelBtn setTitle:kLang(@"payment_cancel_action") forState:UIControlStateNormal];
    cancelBtn.titleLabel.font = [GM MidFontWithSize:16];
    cancelBtn.translatesAutoresizingMaskIntoConstraints = NO;
    cancelBtn.backgroundColor = [UIColor.systemGray5Color colorWithAlphaComponent:0.6];
    cancelBtn.tintColor = UIColor.labelColor;
    cancelBtn.layer.cornerRadius = 10;
    [cancelBtn addTarget:self action:@selector(_confirmTap:) forControlEvents:UIControlEventTouchUpInside];
    cancelBtn.tag = 2;

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:container];
    [container addSubview:blurView];
    [blurView.contentView addSubview:title];
    [blurView.contentView addSubview:message];
    [blurView.contentView addSubview:confirmBtn];
    [blurView.contentView addSubview:cancelBtn];

    [NSLayoutConstraint activateConstraints:@[
        [blurView.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [blurView.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [blurView.widthAnchor constraintEqualToAnchor:container.widthAnchor multiplier:0.85],
        [title.topAnchor constraintEqualToAnchor:blurView.topAnchor constant:24],
        [title.leadingAnchor constraintEqualToAnchor:blurView.leadingAnchor constant:16],
        [title.trailingAnchor constraintEqualToAnchor:blurView.trailingAnchor constant:-16],
        [message.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12],
        [message.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [message.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [confirmBtn.topAnchor constraintEqualToAnchor:message.bottomAnchor constant:20],
        [confirmBtn.leadingAnchor constraintEqualToAnchor:blurView.leadingAnchor constant:20],
        [confirmBtn.trailingAnchor constraintEqualToAnchor:blurView.trailingAnchor constant:-20],
        [confirmBtn.heightAnchor constraintEqualToConstant:44],
        [cancelBtn.topAnchor constraintEqualToAnchor:confirmBtn.bottomAnchor constant:12],
        [cancelBtn.leadingAnchor constraintEqualToAnchor:confirmBtn.leadingAnchor],
        [cancelBtn.trailingAnchor constraintEqualToAnchor:confirmBtn.trailingAnchor],
        [cancelBtn.heightAnchor constraintEqualToConstant:42],
        [cancelBtn.bottomAnchor constraintEqualToAnchor:blurView.bottomAnchor constant:-24]
    ]];

    // Fade-in animation
    [UIView animateWithDuration:0.25 animations:^{
        container.alpha = 1.0;
    }];

    // Store actions in associated objects
    objc_setAssociatedObject(confirmBtn, @"confirmBlock", confirm, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(cancelBtn, @"cancelBlock", cancel, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(container, @"containerView", container, OBJC_ASSOCIATION_ASSIGN);
}

#pragma mark - Button Actions

+ (void)_confirmTap:(UIButton *)sender {
    dispatch_block_t confirmBlock = objc_getAssociatedObject(sender, @"confirmBlock");
    dispatch_block_t cancelBlock = objc_getAssociatedObject(sender, @"cancelBlock");
    UIView *container = objc_getAssociatedObject(sender, @"containerView");

    [UIView animateWithDuration:0.25 animations:^{
        container.alpha = 0.0;
    } completion:^(BOOL finished) {
        [container removeFromSuperview];
        if (sender.tag == 1 && confirmBlock) confirmBlock();
        else if (sender.tag == 2 && cancelBlock) cancelBlock();
    }];
}

@end



























//
//  PPBottomAlertSheet.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/11/2025.
//

 #import "Styling.h"
#import "Language.h"

@interface PPBottomAlertSheet ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) UIButton *cancelButton;
@end

@implementation PPBottomAlertSheet

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

#pragma mark - UI Setup

- (void)setupUI {
   
    
    self.view.backgroundColor = PPBackgroundColorForIOS26([UIColor systemBackgroundColor]);
    self.view.layer.cornerRadius = 24;
    self.view.layer.masksToBounds = YES;

    // 📄 Title
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.text = self.sheetTitle ?: kLang(@"payment_confirm_title");
    _titleLabel.font = [UIFont boldSystemFontOfSize:20];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // 📜 Message
    _messageLabel = [[UILabel alloc] init];
    _messageLabel.text = self.message ?: @"";
    _messageLabel.font = [UIFont systemFontOfSize:16];
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.textColor = UIColor.secondaryLabelColor;
    _messageLabel.numberOfLines = 0;
    _messageLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // ✅ Confirm button
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration tintedButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.baseBackgroundColor = AppPrimaryClr;
        cfg.baseForegroundColor = UIColor.whiteColor;
        cfg.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"payment_confirm_action")
                                                              attributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:17]}];
        _confirmButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        _confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_confirmButton setTitle:kLang(@"payment_confirm_action") forState:UIControlStateNormal];
        _confirmButton.backgroundColor = AppPrimaryClr;
        _confirmButton.tintColor = UIColor.whiteColor;
        _confirmButton.layer.cornerRadius = 12;
    }
    _confirmButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_confirmButton addTarget:self action:@selector(confirmTapped) forControlEvents:UIControlEventTouchUpInside];

    // ❌ Cancel button
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration grayButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.baseForegroundColor = UIColor.labelColor;
        cfg.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(@"payment_cancel_action")
                                                              attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:17]}];
        _cancelButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_cancelButton setTitle:kLang(@"payment_cancel_action") forState:UIControlStateNormal];
        _cancelButton.backgroundColor = [UIColor systemGray5Color];
        _cancelButton.layer.cornerRadius = 12;
    }
    _cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_cancelButton addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:_titleLabel];
    [self.view addSubview:_messageLabel];
    [self.view addSubview:_confirmButton];
    [self.view addSubview:_cancelButton];

    // 📐 Constraints
    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:28],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        [_messageLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8],
        [_messageLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [_messageLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],

        [_confirmButton.topAnchor constraintEqualToAnchor:_messageLabel.bottomAnchor constant:24],
        [_confirmButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:30],
        [_confirmButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-30],
        [_confirmButton.heightAnchor constraintEqualToConstant:48],

        [_cancelButton.topAnchor constraintEqualToAnchor:_confirmButton.bottomAnchor constant:12],
        [_cancelButton.leadingAnchor constraintEqualToAnchor:_confirmButton.leadingAnchor],
        [_cancelButton.trailingAnchor constraintEqualToAnchor:_confirmButton.trailingAnchor],
        [_cancelButton.heightAnchor constraintEqualToConstant:46],
        [_cancelButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20]
    ]];
}

#pragma mark - Presentation

- (void)presentIn:(UIViewController *)parentVC {
    if (@available(iOS 15.0, *)) {
        self.modalPresentationStyle = UIModalPresentationPageSheet;
        UISheetPresentationController *sheet = self.sheetPresentationController;
        sheet.detents = @[
            [UISheetPresentationControllerDetent mediumDetent],
            [UISheetPresentationControllerDetent largeDetent]
        ];
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 24;
        [parentVC presentViewController:self animated:YES completion:nil];
    } else {
        // Legacy fallback — fade from bottom
        self.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        self.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        [parentVC presentViewController:self animated:YES completion:nil];
    }
}

#pragma mark - Actions

- (void)confirmTapped {
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.onConfirm) self.onConfirm();
    }];
}

- (void)cancelTapped {
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.onCancel) self.onCancel();
    }];
}


// Remove notification observer on dealloc
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end
