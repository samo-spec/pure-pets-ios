//
//  PPPaymentSelectionViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/11/2025.
//

#import "PPSelectPaymentVC.h"
#import "PPSelectPaymentVC+Helper.h"
#import "PPBottomSurfaceCoordinator.h"
#import "PPAddressPickerView.h"
#import "PPCheckoutCoordinator.h"
#import "PPPaymentManager.h"
#import "CartManager.h"
#import "CartItem.h"
#import "PPCartCalculator.h"
#import "PPAddressesManager.h"
#import "UserModel.h"
#import "AddressFormVC.h"
#import "UserManager.h"
#import "CountryModel.h"
#import "CountryCodeModel.h"
#import "PPSelectOptionViewController.h"
#import "PPCommerceFeedbackManager.h"
#import "PPOrderDetailsRouter.h"

#import "PPSelectAddressVC.h"
#import <QuartzCore/QuartzCore.h>
#import <os/signpost.h>

@import FirebaseAuth;

#define PPORDERLog(fmt, ...) NSLog((@"PPBackend > SELECT_PAYMENT : " fmt), ##__VA_ARGS__)

static NSString * const PPOrderCheckoutPreflightErrorDomain = @"PPOrderCheckoutPreflight";
static NSInteger const PPOrderCheckoutPreflightCodeInvalidQIBPhone = 1004;

static os_log_t PPPaymentPresentationLog(void)
{
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.purepets", "CheckoutPresentation");
    });
    return log;
}

static BOOL PPPaymentUsesExpandedTextMetrics(UITraitCollection *traits)
{
    UIContentSizeCategory category = traits.preferredContentSizeCategory;
    return UIContentSizeCategoryIsAccessibilityCategory(category) ||
        [category isEqualToString:UIContentSizeCategoryExtraExtraLarge] ||
        [category isEqualToString:UIContentSizeCategoryExtraExtraExtraLarge];
}

#pragma mark - ViewController

@interface PPSelectPaymentVC () <AddressFormVCDelegate>
@property (nonatomic, strong, nullable) UIVisualEffectView *dimOverlay;
@property (nonatomic, strong) UILabel *collectionHintLabel;
@property (nonatomic, strong) NSArray<PPAddressModel *> *Addresses;
@property (nonatomic, strong) PPAddressModel *selectedAddress;
@property (nonatomic, strong) PPCheckoutCoordinator *checkoutCoordinator;
@property (nonatomic, copy, nullable) NSArray<CartItem *> *explicitCheckoutItems;
@property (nonatomic, assign) BOOL isCheckoutInProgress;
@property (nonatomic, assign) BOOL isAwaitingCheckoutCancellation;
@property (nonatomic, strong, nullable) PPOrder *pendingCheckoutCancellationOrder;
@property (nonatomic, strong) id<FIRListenerRegistration> addressesListener;
@property (nonatomic, strong) PPAddressPickerView *locView;
@property (nonatomic, strong) UIStackView *navTitleSubtitleStack;
@property (nonatomic, strong) UIButton *heroBackButton;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UIStackView *paymentPreludeView;
@property (nonatomic, strong) UIStackView *methodStatusStack;
@property (nonatomic, strong) UIStackView *methodStatusLine;
@property (nonatomic, strong) UILabel *methodStatusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *methodLoadingIndicator;
@property (nonatomic, strong) UIButton *retryMethodsButton;
@property (nonatomic, assign) BOOL isLoadingPaymentInstruments;
@property (nonatomic, assign) BOOL paymentInstrumentsLoadFailed;
@property (nonatomic, assign) NSUInteger paymentInstrumentLoadGeneration;
@property (nonatomic, assign) CGFloat paymentContentWidth;
@property (nonatomic, copy) NSString *addressesUserID;
@property (nonatomic, copy) NSString *selectedAddressID;
@property (nonatomic, assign) NSUInteger addressSessionGeneration;
@property (nonatomic, assign) NSUInteger addressRefreshGeneration;
@property (nonatomic, assign) NSUInteger checkoutPreflightGeneration;
@property (nonatomic, assign) BOOL isPreparingCheckout;
@property (nonatomic, assign) BOOL isLoadingAddresses;
@property (nonatomic, assign) BOOL addressesLoadFailed;
@property (nonatomic, assign) BOOL hasLoadedAddresses;
@property (nonatomic, strong) UILabel *checkoutNoticeLabel;
@property (nonatomic, strong) UIButton *retryAddressButton;
@property (nonatomic, strong) UIStackView *addressStatusStack;
@property (nonatomic, strong) UIButton *paymentContactButton;
@property (nonatomic, copy) NSString *checkoutReviewMessage;
@property (nonatomic, copy, nullable) void (^dismissPhoneEditor)(void);
@property (nonatomic, assign) BOOL phoneEditorPresented;
@property (nonatomic, assign) NSUInteger phoneEditorGeneration;
@property (nonatomic, assign) os_signpost_id_t presentationTraceID;


- (void)pp_applyPaymentHeroNavBar;
- (void)pp_applyPaymentHeroTheme;
- (void)pp_updatePaymentLayoutMetrics;
- (BOOL)pp_prefersCondensedCheckoutSummary;
- (void)pp_applyAdaptiveSummaryPresentation;
- (void)pp_updateMethodStatus;
- (NSString *)pp_normalizedValidPhoneFromString:(NSString *)rawPhone;
- (void)pp_showQIBMobileNumberSheetForAddress:(PPAddressModel *)address;
- (NSArray<CartItem *> *)pp_checkoutItems;
- (PPCartSummary *)pp_checkoutSummary;
+ (BOOL)pp_pushFromViewController:(UIViewController *)viewController
                     checkoutItems:(nullable NSArray<CartItem *> *)checkoutItems;
@end


@implementation PPSelectPaymentVC

+ (BOOL)pushFromViewController:(UIViewController *)viewController
{
    return [self pp_pushFromViewController:viewController
                             checkoutItems:nil];
}

+ (BOOL)pushFromViewController:(UIViewController *)viewController
                 checkoutItems:(NSArray<CartItem *> *)checkoutItems
{
    if (checkoutItems.count == 0) {
        return NO;
    }
    return [self pp_pushFromViewController:viewController
                             checkoutItems:checkoutItems];
}

+ (BOOL)pp_pushFromViewController:(UIViewController *)viewController
                     checkoutItems:(nullable NSArray<CartItem *> *)checkoutItems
{
    UINavigationController *navigationController = nil;
    if ([viewController isKindOfClass:UINavigationController.class]) {
        navigationController = (UINavigationController *)viewController;
    } else {
        navigationController = viewController.navigationController;
    }

    if (!navigationController) {
        return NO;
    }
    if ([navigationController.topViewController isKindOfClass:self]) {
        // A legacy caller may safely treat the existing cart payment screen
        // as open; a scoped request must never inherit that screen's items.
        return checkoutItems == nil;
    }

    PPSelectPaymentVC *paymentViewController = [[self alloc] init];
    paymentViewController.explicitCheckoutItems = checkoutItems.copy;
    [paymentViewController pp_beginPresentationTrace];
    [navigationController pushViewController:paymentViewController animated:YES];
    return YES;
}

- (NSArray<CartItem *> *)pp_checkoutItems
{
    return self.explicitCheckoutItems ?: CartManager.sharedManager.cartItems;
}

- (PPCartSummary *)pp_checkoutSummary
{
    NSArray<CartItem *> *items = [self pp_checkoutItems];
    double shippingFee = items.count > 0
        ? MAX(0.0, CartManager.sharedManager.deliveryFee)
        : 0.0;
    return [PPCartCalculator summaryForItems:items shippingFee:shippingFee];
}

- (void)pp_beginPresentationTrace
{
    if (self.presentationTraceID != OS_SIGNPOST_ID_INVALID) return;
    self.presentationTraceID = os_signpost_id_generate(PPPaymentPresentationLog());
    os_signpost_interval_begin(PPPaymentPresentationLog(), self.presentationTraceID, "CartToPaymentPresentation");
}

- (void)pp_endPresentationTrace:(BOOL)appeared
{
    if (self.presentationTraceID == OS_SIGNPOST_ID_INVALID) return;
    os_signpost_interval_end(PPPaymentPresentationLog(), self.presentationTraceID, "CartToPaymentPresentation",
                            "%{public}s", appeared ? "appeared" : "cancelled");
    self.presentationTraceID = OS_SIGNPOST_ID_INVALID;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_endPresentationTrace:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[CartManager sharedManager] refreshPricingConfiguration];
    [self pp_applyPaymentHeroNavBar];
    [self pp_applyPaymentHeroTheme];
    [self.summaryView setCheckoutLoading:self.isCheckoutInProgress || self.isPreparingCheckout];
    [_summaryView pp_startTrustBannerShimmer];
    [self pp_setupInitialAddressState];
    [self pp_updateCheckoutReview];
    [self pp_applyAdaptiveSummaryPresentation];

    self.navigationController.view.backgroundColor = AppBackgroundClr ?: UIColor.systemBackgroundColor;
    self.edgesForExtendedLayout = UIRectEdgeAll;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self pp_endPresentationTrace:NO];
    [self.summaryView pp_stopTrustBannerShimmer];

    [self pp_navBarSetVisible:YES animated:YES];
    // Leaving review invalidates unfinished preflight; QIB lifecycle remains with its coordinator.
    if (self.isPreparingCheckout) {
        self.checkoutPreflightGeneration += 1;
        [self pp_setPreparingCheckout:NO];
    }
    if (self.isMovingFromParentViewController && self.dismissPhoneEditor) self.dismissPhoneEditor();
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (PPBottomSurfaceKind)pp_preferredBottomSurfaceKind {
    return PPBottomSurfaceKindSummaryBottomBar;
}

- (void)viewDidLoad {
    os_signpost_id_t constructionTraceID = os_signpost_id_generate(PPPaymentPresentationLog());
    os_signpost_interval_begin(PPPaymentPresentationLog(), constructionTraceID, "PaymentViewConstruction");
    [super viewDidLoad];
    self.hidesBottomBarWhenPushed = YES;

    self.instrumentManager = [UserPaymentInstrumentManager sharedManager];
    self.availableMethods = [PaymentMethod defaultMethods];
    self.userInstruments = @[];
    self.initialPaymentSelectionID = PPCurrentUser.SelectedInstrument.instrumentID;
    self.view.backgroundColor = AppBackgroundClr;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.navigationItem.title = nil;

    [self pp_setupHeroSection];
    [self setlocViewViewAtTop];
    [self setSummuryViewAtBottom];
    [self setupPaymentCollection];
    [self pp_applyDefaultSelectionIfNeeded];
    [self pp_refreshCheckoutCallToAction];
    [self fetchUserPaymentInstruments];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleAddressDidChangeNotification:)
                                                 name:PPAddressesDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleUserDidSyncNotification:)
                                                 name:PPUserManagerDidSyncCurrentUserNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleUserDidSignOutNotification:)
                                                 name:PPUserManagerDidSignOutNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handlePricingConfigurationDidChangeNotification:)
                                                 name:kCartPricingConfigurationDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handlePricingConfigurationDidChangeNotification:)
                                                 name:kCartUpdatedNotification
                                               object:nil];
    os_signpost_interval_end(PPPaymentPresentationLog(), constructionTraceID, "PaymentViewConstruction");
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    [self pp_applyPaymentHeroTheme];
    [self pp_updatePaymentLayoutMetrics];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];

    BOOL appearanceChanged = !previousTraitCollection ||
        previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle ||
        previousTraitCollection.accessibilityContrast != self.traitCollection.accessibilityContrast;
    if (appearanceChanged) {
        [self pp_applyPaymentHeroTheme];
    }

    BOOL contentSizeChanged = !previousTraitCollection ||
        ![previousTraitCollection.preferredContentSizeCategory
            isEqualToString:self.traitCollection.preferredContentSizeCategory];
    if (contentSizeChanged) {
        [self pp_updatePaymentLayoutMetrics];
        [self pp_applyAdaptiveSummaryPresentation];
        [self.paymentCollection.collectionViewLayout invalidateLayout];
        [self.paymentCollection reloadData];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    __weak typeof(self) weakSelf = self;
    [coordinator animateAlongsideTransition:nil completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self pp_updatePaymentLayoutMetrics];
        [self pp_applyAdaptiveSummaryPresentation];
        [self.paymentCollection.collectionViewLayout invalidateLayout];
    }];
}

- (void)setSummuryViewAtBottom
{
    self.summaryView = [[PPContextAwareCheckoutView alloc] init];
    self.summaryView.presentationMode = PPContextAwareCheckoutModePayment;
    [self.view addSubview:self.summaryView];
    self.summaryView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.summaryView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-PPSpaceXS].active = YES;
    [self.summaryView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [self.summaryView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;

    // Keep the existing checkout dock immediately available during navigation.
    [self.summaryView skipCardEntranceAnimation];

    __weak typeof(self) weakSelf = self;
    self.summaryView.onTapCheckOut = ^{
        NSLog(@"Checkout tapped on PPSelectPaymentVC+Helper");
        [weakSelf finishPayments];
    };

    // Configure all data inside performWithoutAnimation so internal
    // setters (e.g. setShowsItemsPreview:) don't fire their own
    // UIView animations that conflict with the entrance reveal.
    NSArray<CartItem *> *checkoutItems = [self pp_checkoutItems];
    PPCartSummary *summary = [self pp_checkoutSummary];

    [UIView performWithoutAnimation:^{
        [self.summaryView updateTotalsWithItems:summary.subtotal shipping:summary.shippingFee showTitle:NO];
        [self.summaryView updatePreviewItems:checkoutItems];
        [self.summaryView setCheckoutBTNTitle:kLang(@"payment_pay_now") image:[UIImage pp_symbolNamed:@"creditcard.fill" pointSize:18
                                                                                        weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleLarge palette:@[AppForgroundColr,AppForgroundColr] makeTemplate:NO]];
    }];
    [self pp_applyAdaptiveSummaryPresentation];

    if (checkoutItems.count > 0) {
        [_summaryView pp_startTrustBannerShimmer];
    }

    // The consequential action is visible as soon as the screen is ready.
    self.summaryView.alpha = 1.0;
    self.summaryView.accessibilityIdentifier = @"paymentSelection.checkout";
}

#pragma mark - Payment Review Presentation

- (UILabel *)pp_reviewLabelWithText:(NSString *)text
                              font:(UIFont *)font
                             style:(UIFontTextStyle)style
                             color:(UIColor *)color
{
    UILabel *label = [UILabel new];
    label.font = [[UIFontMetrics metricsForTextStyle:style]
        scaledFontForFont:font ?: [UIFont systemFontOfSize:PPFontBody weight:UIFontWeightRegular]];
    label.adjustsFontForContentSizeCategory = YES;
    label.text = text;
    label.textColor = color;
    label.numberOfLines = 0;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    label.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    return label;
}

- (void)pp_setupHeroSection
{
    self.heroTitleLabel = [self pp_reviewLabelWithText:kLang(@"payment_review_navigation")
                                                font:[GM boldFontWithSize:PPFontHeadline]
                                               style:UIFontTextStyleHeadline color:AppPrimaryTextClr];
    self.heroTitleLabel.numberOfLines = 1;
    // The full-size heading lives in the scroll content; the navigation bar is fixed-height.
    self.heroTitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline]
        scaledFontForFont:[GM boldFontWithSize:PPFontHeadline] maximumPointSize:24.0];
    self.heroTitleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    self.navTitleSubtitleStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.heroTitleLabel]];
    self.navTitleSubtitleStack.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *title = [self pp_reviewLabelWithText:kLang(@"payment_review_title")
                                           font:[GM boldFontWithSize:PPFontTitle1]
                                          style:UIFontTextStyleTitle1 color:AppPrimaryTextClr];
    title.accessibilityTraits = UIAccessibilityTraitHeader;
    title.accessibilityIdentifier = @"paymentSelection.title";
    UILabel *subtitle = [self pp_reviewLabelWithText:kLang(@"payment_review_subtitle")
                                              font:[GM MidFontWithSize:PPFontCallout]
                                             style:UIFontTextStyleCallout color:AppSecondaryTextClr];
    UIStackView *intro = [[UIStackView alloc] initWithArrangedSubviews:@[title, subtitle]];
    intro.axis = UILayoutConstraintAxisVertical;
    intro.spacing = PPSpaceSM;

    self.paymentPreludeView = [[UIStackView alloc] initWithArrangedSubviews:@[intro]];
    self.paymentPreludeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.paymentPreludeView.axis = UILayoutConstraintAxisVertical;
    self.paymentPreludeView.alignment = UIStackViewAlignmentFill;
    self.paymentPreludeView.spacing = PPSpaceXL;
    self.paymentPreludeView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self pp_applyPaymentHeroNavBar];
}

- (void)setlocViewViewAtTop
{
    self.locView = [PPAddressPickerView new];
    [self.locView configureForInlineCheckout];
    self.locView.accessibilityIdentifier = @"paymentSelection.address";
    __weak typeof(self) weakSelf = self;
    self.locView.onPickAddress = ^{ [weakSelf pp_presentAddressPickerOrPrompt]; };
    self.locView.onLayoutHeightChange = ^{
        [weakSelf.paymentCollection.collectionViewLayout invalidateLayout];
    };
    [self.paymentPreludeView addArrangedSubview:self.locView];

    self.checkoutNoticeLabel = [self pp_reviewLabelWithText:@""
        font:[GM MidFontWithSize:PPFontFootnote] style:UIFontTextStyleFootnote color:AppSecondaryTextClr];
    self.checkoutNoticeLabel.accessibilityIdentifier = @"checkout.reviewNotice";
    self.retryAddressButton = [self pp_reviewActionButtonWithTitle:kLang(@"payment_review_retry")
                                                         action:@selector(pp_retryAddresses)];
    UIStackView *addressStatus = [[UIStackView alloc] initWithArrangedSubviews:@[self.checkoutNoticeLabel, self.retryAddressButton]];
    self.addressStatusStack = addressStatus;
    addressStatus.axis = UILayoutConstraintAxisVertical;
    addressStatus.spacing = PPSpaceXS;
    [self.paymentPreludeView addArrangedSubview:addressStatus];

    self.paymentContactButton = [self pp_reviewActionButtonWithTitle:@"" action:@selector(pp_editPaymentContact)];
    self.paymentContactButton.accessibilityIdentifier = @"checkout.paymentContact";
    [self.paymentPreludeView addArrangedSubview:self.paymentContactButton];

    UILabel *methodsTitle = [self pp_reviewLabelWithText:kLang(@"payment_section_methods_title")
                                                  font:[GM boldFontWithSize:PPFontTitle3]
                                                 style:UIFontTextStyleTitle3 color:AppPrimaryTextClr];
    methodsTitle.accessibilityTraits = UIAccessibilityTraitHeader;
    methodsTitle.accessibilityIdentifier = @"paymentSelection.methodsTitle";
    self.methodStatusLabel = [self pp_reviewLabelWithText:@""
                                                    font:[GM MidFontWithSize:PPFontFootnote]
                                                   style:UIFontTextStyleFootnote color:AppSecondaryTextClr];
    [self.methodStatusLabel setContentCompressionResistancePriority:UILayoutPriorityRequired - 1.0
                                                            forAxis:UILayoutConstraintAxisVertical];
    self.methodLoadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.methodLoadingIndicator.hidesWhenStopped = YES;
    self.methodLoadingIndicator.isAccessibilityElement = NO;
    UIStackView *statusLine = [[UIStackView alloc] initWithArrangedSubviews:@[self.methodLoadingIndicator, self.methodStatusLabel]];
    statusLine.axis = UILayoutConstraintAxisHorizontal;
    statusLine.alignment = UIStackViewAlignmentCenter;
    statusLine.spacing = PPSpaceSM;
    statusLine.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.methodStatusLine = statusLine;

    self.retryMethodsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.retryMethodsButton.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCallout]
        scaledFontForFont:[GM boldFontWithSize:PPFontCallout]];
    self.retryMethodsButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.retryMethodsButton.titleLabel.numberOfLines = 0;
    [self.retryMethodsButton setTitle:kLang(@"payment_review_retry") forState:UIControlStateNormal];
    [self.retryMethodsButton setTitleColor:AppPrimaryTextClr forState:UIControlStateNormal];
    self.retryMethodsButton.contentHorizontalAlignment = Language.isRTL
        ? UIControlContentHorizontalAlignmentRight : UIControlContentHorizontalAlignmentLeft;
    self.retryMethodsButton.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    NSLayoutConstraint *retryMinimumHeight = [self.retryMethodsButton.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin];
    retryMinimumHeight.priority = UILayoutPriorityRequired - 1.0;
    retryMinimumHeight.active = YES;
    [self.retryMethodsButton addTarget:self action:@selector(fetchUserPaymentInstruments) forControlEvents:UIControlEventTouchUpInside];
    self.retryMethodsButton.accessibilityIdentifier = @"paymentSelection.retryMethods";
    self.methodStatusStack = [[UIStackView alloc] initWithArrangedSubviews:@[statusLine, self.retryMethodsButton]];
    self.methodStatusStack.axis = UILayoutConstraintAxisVertical;
    self.methodStatusStack.spacing = PPSpaceXS;
    UIStackView *methodHeading = [[UIStackView alloc] initWithArrangedSubviews:@[methodsTitle, self.methodStatusStack]];
    methodHeading.axis = UILayoutConstraintAxisVertical;
    methodHeading.spacing = PPSpaceSM;
    [self.paymentPreludeView addArrangedSubview:methodHeading];
    [self pp_updateMethodStatus];
    [self pp_setupInitialAddressState];
}

- (UIButton *)pp_reviewActionButtonWithTitle:(NSString *)title action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCallout]
        scaledFontForFont:[GM MidFontWithSize:PPFontCallout]];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    button.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    button.contentHorizontalAlignment = Language.isRTL ? UIControlContentHorizontalAlignmentRight : UIControlContentHorizontalAlignmentLeft;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
    NSLayoutConstraint *minimumHeight = [button.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin];
    // UIStackView requires zero height when retry/contact is hidden.
    minimumHeight.priority = UILayoutPriorityRequired - 1.0;
    minimumHeight.active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (BOOL)pp_checkoutInteractionLocked
{
    return self.isPreparingCheckout || self.isCheckoutInProgress || self.isAwaitingCheckoutCancellation;
}

- (NSString *)pp_checkoutRequiredActionTitle
{
    if (self.isAwaitingCheckoutCancellation) return kLang(@"checkout_payment_cancellation_retry");
    if (self.addressesLoadFailed && !self.selectedAddress) return kLang(@"payment_review_retry");
    if (!self.selectedAddress) {
        return kLang(self.hasLoadedAddresses && self.Addresses.count == 0
            ? @"checkout_add_delivery_address" : @"checkout_choose_delivery_address");
    }
    if (![self pp_isAddressCheckoutValid:self.selectedAddress]) return kLang(@"checkout_complete_address");
    NSString *method = [self pp_selectedCheckoutPaymentMethodID];
    if (!method.length) return kLang(@"checkout_choose_payment");
    if ([self pp_checkoutMethodRequiresPhone:method] && ![self pp_validQIBPhoneForAddress:self.selectedAddress].length) {
        return kLang(@"payment_mobile_required_title");
    }
    return nil;
}

- (void)pp_updateCheckoutReview
{
    NSString *addressText = [self pp_bestAddressDisplayText:self.selectedAddress];
    [self.locView setAddressText:addressText.length ? addressText : kLang(@"PleaseSelectDeliveryLocation")];
    NSString *message = self.checkoutReviewMessage;
    if (!message.length && self.addressesLoadFailed) message = kLang(@"checkout_address_refresh_failed");
    if (!message.length && self.isLoadingAddresses && !self.selectedAddress) message = kLang(@"checkout_loading_addresses");
    if (!message.length && self.selectedAddressID.length && !self.selectedAddress && self.hasLoadedAddresses) {
        message = kLang(@"checkout_address_changed_review");
    }
    self.checkoutNoticeLabel.text = message ?: @"";
    self.checkoutNoticeLabel.hidden = message.length == 0;
    self.retryAddressButton.hidden = !self.addressesLoadFailed || self.isLoadingAddresses;
    self.addressStatusStack.hidden = self.checkoutNoticeLabel.hidden && self.retryAddressButton.hidden;
    NSString *method = [self pp_selectedCheckoutPaymentMethodID];
    self.paymentContactButton.hidden = !method.length || ![self pp_checkoutMethodRequiresPhone:method];
    NSString *phone = [self pp_validQIBPhoneForAddress:self.selectedAddress];
    NSString *contact = phone.length
        ? [NSString stringWithFormat:kLang(@"checkout_payment_contact_format"),
           [NSString stringWithFormat:@"\u2066%@\u2069", phone]]
        : kLang(@"checkout_payment_contact_missing");
    [self.paymentContactButton setTitle:contact forState:UIControlStateNormal];
    self.paymentContactButton.accessibilityHint = kLang(@"checkout_payment_contact_hint");
    BOOL locked = [self pp_checkoutInteractionLocked];
    self.paymentCollection.userInteractionEnabled = !locked;
    self.paymentContactButton.enabled = !locked;
    self.retryAddressButton.enabled = !locked;
    [self pp_refreshCheckoutCallToAction];
    [self.paymentCollection.collectionViewLayout invalidateLayout];
}

- (void)pp_retryAddresses
{
    if ([self pp_checkoutInteractionLocked]) return;
    self.checkoutReviewMessage = nil;
    [self pp_refreshLatestAddressesForCheckout:nil];
}

- (void)pp_editPaymentContact
{
    if ([self pp_checkoutInteractionLocked] || self.phoneEditorPresented) return;
    [self pp_showQIBMobileNumberSheetForAddress:self.selectedAddress];
}

- (void)pp_setPreparingCheckout:(BOOL)preparing
{
    self.isPreparingCheckout = preparing;
    [self.summaryView setCheckoutLoading:preparing || self.isCheckoutInProgress];
    [self pp_updateCheckoutReview];
}

- (void)pp_showCheckoutReviewMessage:(NSString *)message
{
    self.checkoutReviewMessage = message;
    [self pp_updateCheckoutReview];
    [self.paymentCollection setContentOffset:CGPointZero animated:!UIAccessibilityIsReduceMotionEnabled()];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message);
}

- (NSArray<NSDictionary *> *)pp_checkoutReviewItemsSnapshot
{
    NSMutableArray *snapshot = [NSMutableArray array];
    for (CartItem *item in [self pp_checkoutItems]) {
        [snapshot addObject:@{@"item":item.itemID ?: @"", @"sellable":item.sellableUnitId ?: @"",
            @"variant":item.variantId ?: @"", @"options":item.selectedOptions.copy ?: @{},
            @"quantity":@(item.quantity), @"price":@(item.price)}];
    }
    return snapshot.copy;
}

- (void)pp_applyPaymentHeroNavBar
{
    UIView *bar = [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:@"" showBack:NO];
    if (!bar) return;
    bar.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    if (!self.heroBackButton) {
        self.heroBackButton = [self pp_ButtonWithSystemName:PPChevronName action:@selector(onBack)];
        self.heroBackButton.accessibilityIdentifier = @"paymentSelection.back";
        self.heroBackButton.accessibilityLabel = kLang(@"Back");
        // The shared helper uses a 38pt button before iOS 26; keep a 44pt target here.
        for (NSLayoutConstraint *constraint in self.heroBackButton.constraints) {
            if (constraint.firstItem == self.heroBackButton && constraint.secondItem == nil &&
                (constraint.firstAttribute == NSLayoutAttributeWidth || constraint.firstAttribute == NSLayoutAttributeHeight)) {
                constraint.constant = MAX(PPTouchTargetMin, constraint.constant);
            }
        }
    }
    if (self.heroBackButton.superview != bar || self.navTitleSubtitleStack.superview != bar) {
        [self.heroBackButton removeFromSuperview];
        [self.navTitleSubtitleStack removeFromSuperview];
        [bar addSubview:self.heroBackButton];
        [bar addSubview:self.navTitleSubtitleStack];
        [NSLayoutConstraint activateConstraints:@[
            [self.heroBackButton.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
            [self.heroBackButton.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
            [self.navTitleSubtitleStack.leadingAnchor constraintEqualToAnchor:self.heroBackButton.trailingAnchor constant:PPSpaceSM],
            [self.navTitleSubtitleStack.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-PPSpaceSM],
            [self.navTitleSubtitleStack.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor]
        ]];
    }
}

- (CGFloat)pp_paymentHeaderHeightForWidth:(CGFloat)width
{
    CGFloat contentWidth = MAX(1.0, MIN(680.0, width - 2.0 * PPScreenMargin));
    CGSize size = [self.paymentPreludeView systemLayoutSizeFittingSize:CGSizeMake(contentWidth, UILayoutFittingCompressedSize.height)
                                      withHorizontalFittingPriority:UILayoutPriorityRequired
                                            verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    return ceil(size.height) + PPSpaceBase + PPSpaceSM;
}

- (void)pp_configurePaymentHeader:(PPPaymentSectionHeaderView *)header
{
    if (self.paymentPreludeView.superview == header) return;
    [self.paymentPreludeView removeFromSuperview];
    [header addSubview:self.paymentPreludeView];
    NSLayoutConstraint *preferredWidth = [self.paymentPreludeView.widthAnchor constraintEqualToAnchor:header.widthAnchor constant:-2.0 * PPScreenMargin];
    preferredWidth.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [self.paymentPreludeView.topAnchor constraintEqualToAnchor:header.topAnchor constant:PPSpaceBase],
        [self.paymentPreludeView.centerXAnchor constraintEqualToAnchor:header.centerXAnchor],
        [self.paymentPreludeView.widthAnchor constraintLessThanOrEqualToConstant:680.0],
        preferredWidth,
        [self.paymentPreludeView.bottomAnchor constraintLessThanOrEqualToAnchor:header.bottomAnchor constant:-PPSpaceSM]
    ]];
}

- (void)pp_updateMethodStatus
{
    BOOL empty = [self pp_displayedInstruments].count == 0;
    self.methodStatusLine.hidden = !self.isLoadingPaymentInstruments && !self.paymentInstrumentsLoadFailed && !empty;
    self.methodStatusLabel.text = self.isLoadingPaymentInstruments
        ? kLang(@"payment_review_loading")
        : kLang(empty ? @"payment_review_unavailable" : @"payment_load_methods_failed");
    self.retryMethodsButton.hidden = self.isLoadingPaymentInstruments || (!self.paymentInstrumentsLoadFailed && !empty);
    self.methodLoadingIndicator.hidden = !self.isLoadingPaymentInstruments;
    if (self.isLoadingPaymentInstruments) [self.methodLoadingIndicator startAnimating];
    else [self.methodLoadingIndicator stopAnimating];
    [self.paymentCollection.collectionViewLayout invalidateLayout];
}

- (void)pp_updatePaymentLayoutMetrics
{
    CGFloat width = CGRectGetWidth(self.paymentCollection.bounds);
    if (width <= 0 || fabs(width - self.paymentContentWidth) < 0.5) return;
    self.paymentContentWidth = width;
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.paymentCollection.collectionViewLayout;
    CGFloat margin = MAX(PPScreenMargin, (width - 680.0) / 2.0);
    layout.sectionInset = UIEdgeInsetsMake(PPSpaceXS, margin, PPSpaceXL, margin);
    [layout invalidateLayout];
}

- (BOOL)pp_prefersCondensedCheckoutSummary
{
    BOOL usesCompactHeight = CGRectGetHeight(self.view.bounds) > 0.0 &&
        CGRectGetHeight(self.view.bounds) < 760.0;
    return usesCompactHeight || PPPaymentUsesExpandedTextMetrics(self.traitCollection);
}

- (void)pp_applyAdaptiveSummaryPresentation
{
    if (!self.summaryView) return;
    BOOL usesCondensedSummary = [self pp_prefersCondensedCheckoutSummary];
    BOOL showsPreview = !usesCondensedSummary && [self pp_checkoutItems].count > 3;
    [UIView performWithoutAnimation:^{
        self.summaryView.showDetails = !usesCondensedSummary && !showsPreview;
        self.summaryView.showsItemsPreview = showsPreview;
        [self.summaryView setNeedsLayout];
    }];
}

- (void)pp_applyPaymentHeroTheme
{
    self.view.backgroundColor = AppBackgroundClr;
    self.heroTitleLabel.textColor = AppPrimaryTextClr;
}

- (NSString *)pp_trimmedAddressString:(id)value
{
    if (![value isKindOfClass:NSString.class]) return @"";
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)pp_effectiveAddressID:(PPAddressModel *)address
{
    if (!address) return @"";
    NSString *documentID = [self pp_trimmedAddressString:address.documentID];
    if (documentID.length > 0) return documentID;
    return [self pp_trimmedAddressString:address.addressID];
}

- (NSString *)pp_bestAddressDisplayText:(PPAddressModel *)address
{
    if (!address) return @"";
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (id raw in @[address.fullName ?: @"", address.addressLine1 ?: @"",
                     address.addressLine2 ?: @"", address.displayName ?: address.locatioName ?: @""]) {
        NSString *part = [self pp_trimmedAddressString:raw];
        if (part.length > 0 && ![parts containsObject:part]) [parts addObject:part];
    }
    return [parts componentsJoinedByString:@"\n"];
}

- (void)pp_setupInitialAddressState
{
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if ([self.addressesUserID isEqualToString:uid] && self.addressesListener) return;
    [self.addressesListener remove];
    self.addressesListener = nil;
    self.addressesUserID = uid;
    NSUInteger generation = ++self.addressSessionGeneration;
    self.addressRefreshGeneration += 1;
    self.Addresses = @[];
    self.selectedAddress = nil;
    self.selectedAddressID = nil;
    self.hasLoadedAddresses = NO;
    self.addressesLoadFailed = NO;
    self.isLoadingAddresses = uid.length > 0;
    [self pp_updateCheckoutReview];
    if (uid.length == 0) return;

    __weak typeof(self) weakSelf = self;
    self.addressesListener = [PPADDRESS listenToAddressesWithBlock:^(NSArray<PPAddressModel *> *addresses, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || generation != self.addressSessionGeneration ||
                ![[FIRAuth auth].currentUser.uid isEqualToString:uid]) return;
            self.isLoadingAddresses = NO;
            self.addressesLoadFailed = error != nil;
            if (!error) [self pp_applyAddresses:addresses ?: @[]];
            [self pp_updateCheckoutReview];
        });
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.addressSessionGeneration || self.hasLoadedAddresses ||
            ![[FIRAuth auth].currentUser.uid isEqualToString:uid]) return;
        self.isLoadingAddresses = NO;
        self.addressesLoadFailed = YES;
        [self pp_updateCheckoutReview];
    });
}

- (void)pp_applyAddresses:(NSArray<PPAddressModel *> *)addresses
{
    NSAssert(NSThread.isMainThread, @"Checkout review updates belong on the main thread");
    self.Addresses = addresses ?: @[];
    self.hasLoadedAddresses = YES;
    self.selectedAddress = [self pp_preferredAddressFrom:self.Addresses];
    if (self.selectedAddress) self.selectedAddressID = [self pp_effectiveAddressID:self.selectedAddress];
    // A deleted choice remains unresolved. Never substitute another delivery address silently.
    [self pp_updateCheckoutReview];
}

- (PPAddressModel *)pp_preferredAddressFrom:(NSArray<PPAddressModel *> *)addresses
{
    NSString *selectedID = self.selectedAddressID ?: [self pp_effectiveAddressID:self.selectedAddress];
    if (selectedID.length > 0) {
        for (PPAddressModel *address in addresses) {
            if ([[self pp_effectiveAddressID:address] isEqualToString:selectedID]) return address;
        }
        return nil;
    }
    for (PPAddressModel *address in addresses) {
        if (address.isDefault && [self pp_isAddressCheckoutValid:address]) return address;
    }
    for (PPAddressModel *address in addresses) {
        if ([self pp_isAddressCheckoutValid:address]) return address;
    }
    return addresses.firstObject;
}

- (void)pp_presentAddressPickerOrPrompt
{
    if ([self pp_checkoutInteractionLocked]) return;
    if (self.Addresses.count > 0) {
        __weak typeof(self) weakSelf = self;
        PPSelectAddressVC *vc = [[PPSelectAddressVC alloc] initWithOptions:self.Addresses
            title:kLang(@"select_delivery_location_title") row:nil
            presentationStyle:PPSelectOptionPresentationSheet completion:^(id selectedObject) {
                __strong typeof(weakSelf) self = weakSelf;
                if (!self || ![selectedObject isKindOfClass:PPAddressModel.class] ||
                    ![[FIRAuth auth].currentUser.uid isEqualToString:self.addressesUserID]) return;
                self.selectedAddress = selectedObject;
                self.selectedAddressID = [self pp_effectiveAddressID:selectedObject];
                self.checkoutReviewMessage = nil;
                [self pp_updateCheckoutReview];
            }];
        vc.selectedOption = self.selectedAddress;
        [PPFunc presentSheetFrom:self sheetVC:vc detentStyle:PPSheetDetentStyle80];
        return;
    }
    if (self.hasLoadedAddresses && !self.addressesLoadFailed) {
        [self pp_goToAddNewAddressScreen];
        return;
    }
    if (self.isLoadingAddresses) return;
    __weak typeof(self) weakSelf = self;
    [self pp_refreshLatestAddressesForCheckout:^(NSArray<PPAddressModel *> *addresses, NSError *error) {
        if (!error && weakSelf.navigationController.topViewController == weakSelf) {
            [weakSelf pp_presentAddressPickerOrPrompt];
        }
    }];
}

- (void)pp_goToAddNewAddressScreen {
    AddressFormVC *formVC = [[AddressFormVC alloc] initWithAddress:nil];
    formVC.delegate = self;
    [self.navigationController pushViewController:formVC animated:YES];
}

- (void)addressFormVC:(AddressFormVC *)controller didSaveAddress:(PPAddressModel *)address
{
    (void)controller;
    if (![address isKindOfClass:PPAddressModel.class]) {
        return;
    }

    self.selectedAddress = address;
    self.selectedAddressID = [self pp_effectiveAddressID:address];
    self.checkoutReviewMessage = nil;
    [self pp_updateCheckoutReview];
    NSString *selectedText = [self pp_bestAddressDisplayText:address];
    [self.locView setAddressText:selectedText.length > 0 ? selectedText : kLang(@"PleaseSelectDeliveryLocation")];
    [self pp_refreshLatestAddressesForCheckout:nil];
}

- (void)addressFormVC:(AddressFormVC *)controller didDeleteAddress:(PPAddressModel *)address
{
    (void)controller;
    (void)address;
    [self pp_refreshLatestAddressesForCheckout:nil];
}

- (void)pp_handleAddressDidChangeNotification:(NSNotification *)notification
{
    NSString *uid = [notification.userInfo[@"uid"] isKindOfClass:NSString.class] ? notification.userInfo[@"uid"] : @"";
    NSString *currentUID = [PPADDRESS currentAuthenticatedUserID] ?: @"";
    if (uid.length > 0 &&
        currentUID.length > 0 &&
        ![uid isEqualToString:currentUID]) {
        return;
    }
    [self pp_refreshLatestAddressesForCheckout:nil];
}

- (void)pp_handleUserDidSyncNotification:(NSNotification *)notification
{
    (void)notification;
    [self pp_setupInitialAddressState];
    [self pp_updateCheckoutReview];
}

- (void)pp_handleUserDidSignOutNotification:(NSNotification *)notification
{
    (void)notification;
    self.checkoutPreflightGeneration += 1;
    [self pp_setPreparingCheckout:NO];
    if (self.dismissPhoneEditor) self.dismissPhoneEditor();
    [self pp_setupInitialAddressState];
    self.initialPaymentSelectionID = nil;
    self.paymentSelectionWasExplicit = NO;
    [self.instrumentManager resetForSignOut];
    self.paymentInstrumentLoadGeneration += 1;
    self.isLoadingPaymentInstruments = NO;
    self.paymentInstrumentsLoadFailed = NO;
    self.userInstruments = @[];
    [self pp_applyAddresses:@[]];
    [self.paymentCollection reloadData];
    [self pp_refreshCheckoutCallToAction];
    [self pp_updateMethodStatus];
}

- (void)pp_handlePricingConfigurationDidChangeNotification:(NSNotification *)notification
{
    (void)notification;
    [self pp_refreshCheckoutPricingPresentation];
}

- (void)pp_refreshCheckoutPricingPresentation
{
    PPCartSummary *summary = [self pp_checkoutSummary];

    [self.summaryView updateTotalsWithItems:summary.subtotal shipping:summary.shippingFee showTitle:NO];
    [self.summaryView updatePreviewItems:[self pp_checkoutItems]];
    [self pp_applyAdaptiveSummaryPresentation];

    if (![self pp_checkoutInteractionLocked]) [self pp_applyDefaultSelectionIfNeeded];
    [self.paymentCollection reloadData];
    [self pp_updateMethodStatus];
    [self pp_updateCheckoutReview];
}

- (void)setupPaymentCollection {
    if (self.paymentCollection) return;

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumInteritemSpacing = PPSpaceMD;
    layout.minimumLineSpacing = PPSpaceMD;
    layout.sectionInset = UIEdgeInsetsMake(
        PPSpaceSM,
        PPScreenMargin,
        PPSpaceXL,
        PPScreenMargin
    );
    layout.estimatedItemSize = CGSizeZero;
    self.paymentCollection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.paymentCollection.translatesAutoresizingMaskIntoConstraints = NO;
    self.paymentCollection.delegate = self;
    self.paymentCollection.dataSource = self;
    self.paymentCollection.backgroundColor = UIColor.clearColor;
    self.paymentCollection.accessibilityIdentifier = @"paymentSelection.methods";
    self.paymentCollection.alwaysBounceVertical = YES;
    self.paymentCollection.showsVerticalScrollIndicator = YES;
    self.paymentCollection.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.paymentCollection.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.paymentCollection registerClass:[PPPaymentMethodCell class] forCellWithReuseIdentifier:@"PaymentMethodCell"];
    [self.paymentCollection registerClass:[PPPaymentSectionHeaderView class]
               forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                      withReuseIdentifier:@"PPPaymentSectionHeaderView"];
    [self.paymentCollection registerClass:[UICollectionReusableView class]
               forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                      withReuseIdentifier:@"FooterView"];
    
    
    
    [self.view addSubview:self.paymentCollection];

    NSLayoutConstraint *minimumMethodViewport =
        [self.paymentCollection.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin * 2.0];
    minimumMethodViewport.priority = UILayoutPriorityRequired - 1.0;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.paymentCollection.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.paymentCollection.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.paymentCollection.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.paymentCollection.bottomAnchor constraintEqualToAnchor:self.summaryView.topAnchor constant:-PPSpaceSM],
        minimumMethodViewport
    ]];
    
    [self pp_updatePaymentLayoutMetrics];
}
#pragma mark - Setup Payment Collection

- (void)fetchUserPaymentInstruments
{
    NSUInteger generation = ++self.paymentInstrumentLoadGeneration;
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (uid.length == 0) {
        self.userInstruments = @[];
        self.isLoadingPaymentInstruments = NO;
        self.paymentInstrumentsLoadFailed = NO;
        [self.paymentCollection reloadData];
        [self pp_refreshCheckoutCallToAction];
        [self pp_updateMethodStatus];
        return;
    }
    self.isLoadingPaymentInstruments = YES;
    self.paymentInstrumentsLoadFailed = NO;
    [self pp_updateMethodStatus];
    __weak typeof(self) weakSelf = self;
    [self.instrumentManager listenForInstrumentsForUser:uid
                                             completion:^(NSArray<UserPaymentInstrument *> * _Nullable instruments, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.paymentInstrumentLoadGeneration != generation ||
                ![[FIRAuth auth].currentUser.uid isEqualToString:uid]) return;
            [PPHUD dismiss];
            self.isLoadingPaymentInstruments = NO;
            self.paymentInstrumentsLoadFailed = error != nil;
            if (!error) {
                self.userInstruments = instruments ?: @[];
                if (![self pp_checkoutInteractionLocked]) [self pp_applyDefaultSelectionIfNeeded];
                [self.paymentCollection reloadData];
                [self pp_updateCheckoutReview];
            }
            [self pp_updateMethodStatus];
        });
    }];
}

-(void)showPaymentSheetFull:(BOOL)showFull
{
    (void)showFull;
    PPPaymentFormViewController *paymentFormVC = [PPPaymentFormViewController new];
    paymentFormVC.mode = PPPaymentFormModeAdd;
    paymentFormVC.isEditingExisting = NO;
    self.paymentFormVC = paymentFormVC;
    [self.navigationController pushViewController:paymentFormVC animated:YES];
}

- (void)setupHint
{
    self.collectionHintLabel = [[UILabel alloc] init];
    self.collectionHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionHintLabel.font = [GM MidFontWithSize:14];
    self.collectionHintLabel.textColor = UIColor.secondaryLabelColor;
    self.collectionHintLabel.textAlignment = NSTextAlignmentCenter;
    self.collectionHintLabel.numberOfLines = 2;
}
- (void)updateCollectionHintText {
    if (self.userInstruments.count == 0) {
        self.collectionHintLabel.text = nil;//kLang(@"PaymentHintAddNew");
    } else {
        self.collectionHintLabel.text = nil;//kLang(@"PaymentHintMoreOptions");
    }
}

- (BOOL)pp_isAddressCheckoutValid:(PPAddressModel *)address
{
    if (!address) return NO;
    NSString *effectiveID = [self pp_effectiveAddressID:address];
    if (effectiveID.length == 0) return NO;
    if (address.documentID.length == 0) {
        address.documentID = effectiveID;
    }
    if (address.addressID.length == 0) {
        address.addressID = effectiveID;
    }

    if (![address isSemanticallyValid]) return NO;

    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (uid.length > 0 &&
        address.userID.length > 0 &&
        ![address.userID isEqualToString:uid]) {
        return NO;
    }
    return YES;
}

- (BOOL)pp_checkoutMethodRequiresPhone:(NSString *)paymentMethodID
{
    NSString *normalized = [[paymentMethodID ?: @"" lowercaseString] copy];
    return ![normalized isEqualToString:@"cash"];
}

- (BOOL)pp_isQIBMethodID:(NSString *)paymentMethodID
{
    NSString *normalized = [[paymentMethodID ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString copy];
    return [normalized isEqualToString:@"qib"] || [normalized isEqualToString:@"card"];
}

- (NSString *)pp_defaultDialCodeDigits
{
    CountryModel *country = [CountryModel safeUserCountryModel];
    NSString *dialCode = [country.countryCode isKindOfClass:NSString.class] ? country.countryCode : @"";
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSString *digits = [[dialCode componentsSeparatedByCharactersInSet:nonDigits] componentsJoinedByString:@""];
    return digits.length > 0 ? digits : @"974";
}

- (void)pp_phoneFieldEditingChanged:(UITextField *)textField {
    NSString *converted = [self pp_arabicToEnglishDigits:textField.text ?: @""];
    if (![converted isEqualToString:textField.text]) {
        textField.text = converted;
    }
}

- (NSString *)pp_arabicToEnglishDigits:(NSString *)string {
    if (string.length == 0) return string;
    unichar chars[string.length];
    [string getCharacters:chars range:NSMakeRange(0, string.length)];
    for (NSUInteger i = 0; i < string.length; i++) {
        unichar c = chars[i];
        if (c >= 0x0660 && c <= 0x0669) {
            chars[i] = '0' + (c - 0x0660);
        } else if (c >= 0x06F0 && c <= 0x06F9) {
            chars[i] = '0' + (c - 0x06F0);
        }
    }
    return [NSString stringWithCharacters:chars length:string.length];
}

- (NSString *)pp_normalizedValidPhoneFromString:(NSString *)rawPhone
{
    return [[PPPaymentManager shared] normalizedCheckoutPhoneFromString:rawPhone];
}

- (NSString *)pp_validQIBPhoneForAddress:(PPAddressModel *)address
{
    return [[PPPaymentManager shared] normalizedCheckoutPhoneForAddress:address];
}

- (void)pp_showQIBMobileNumberSheetForAddress:(PPAddressModel *)address
{
    if (self.phoneEditorPresented) return;
    self.phoneEditorPresented = YES;
    NSUInteger editorGeneration = ++self.phoneEditorGeneration;
    NSString *editorUserID = [FIRAuth auth].currentUser.uid ?: @"";
    __weak typeof(self) weakSelf = self;
    UIView *overlay = [[UIView alloc] init];
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    overlay.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.0];
    overlay.alpha = 0.0;
    overlay.accessibilityViewIsModal = YES;

    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.alpha = 0.0;
    [overlay addSubview:blurView];

    UIView *sheet = [[UIView alloc] init];
    sheet.translatesAutoresizingMaskIntoConstraints = NO;
    sheet.backgroundColor = [(AppForgroundColr ?: UIColor.secondarySystemBackgroundColor) colorWithAlphaComponent:0.82];
    sheet.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    sheet.layer.cornerRadius = 42.0;
    sheet.layer.cornerCurve = kCACornerCurveContinuous;
    sheet.layer.shadowColor = UIColor.blackColor.CGColor;
    sheet.layer.shadowOpacity = 0.16;
    sheet.layer.shadowRadius = 28.0;
    sheet.layer.shadowOffset = CGSizeMake(0.0, -10.0);
    [overlay addSubview:sheet];

    UIView *handle = [[UIView alloc] init];
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    handle.backgroundColor = [UIColor.tertiaryLabelColor colorWithAlphaComponent:0.30];
    handle.layer.cornerRadius = 2.5;
    [sheet addSubview:handle];

    UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:26.0
                                                                                              weight:UIImageSymbolWeightSemibold
                                                                                               scale:UIImageSymbolScaleMedium];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"iphone.gen2.badge.checkmark"] imageByApplyingSymbolConfiguration:iconConfig]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [sheet addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle2] scaledFontForFont:[GM boldFontWithSize:22.0]];
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.text = kLang(@"checkout_payment_contact_title");
    titleLabel.numberOfLines = 0;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [sheet addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:[GM MidFontWithSize:14.0]];
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.text = kLang(@"payment_mobile_required_subtitle");
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [sheet addSubview:subtitleLabel];

    NSArray<CountryCodeModel *> *countries = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    NSString *existingMobile = [self pp_validQIBPhoneForAddress:address] ?: @"";
    NSString *existingDigits = [[existingMobile componentsSeparatedByCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] componentsJoinedByString:@""];
    __block CountryCodeModel *selectedCountry = countries.firstObject;
    NSInteger bestDialLength = 0;
    for (CountryCodeModel *country in countries ?: @[]) {
        NSString *dialDigits = [[country.phoneCode ?: @"" stringByReplacingOccurrencesOfString:@"+" withString:@""]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (dialDigits.length > bestDialLength && [existingDigits hasPrefix:dialDigits]) {
            selectedCountry = country;
            bestDialLength = dialDigits.length;
        }
    }
    if (!selectedCountry) {
        CountryCodeModel *fallback = [[CountryCodeModel alloc] init];
        fallback.phoneCode = @"+974";
        fallback.isoCountryCode = @"QA";
        fallback.country = @"Qatar";
        selectedCountry = fallback;
    }

    UIButton *countryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    countryButton.translatesAutoresizingMaskIntoConstraints = NO;
    countryButton.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[GM boldFontWithSize:16.0]];
    countryButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    countryButton.titleLabel.numberOfLines = 0;
    countryButton.accessibilityLabel = kLang(@"code_Palce");
    countryButton.tintColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    countryButton.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.88];
    countryButton.layer.cornerRadius = 18.0;
    countryButton.layer.cornerCurve = kCACornerCurveContinuous;
    countryButton.layer.borderWidth = 1.0;
    countryButton.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.18].CGColor;
    countryButton.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    countryButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    countryButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    countryButton.titleLabel.minimumScaleFactor = 0.78;
    NSString *(^countryTitle)(CountryCodeModel *) = ^NSString *(CountryCodeModel *country) {
        NSString *flag = country.flag ?: @"";
        NSString *phoneCode = country.phoneCode.length > 0 ? country.phoneCode : @"+974";
        return flag.length > 0 ? [NSString stringWithFormat:@"%@ %@", flag, phoneCode] : phoneCode;
    };
    [countryButton setTitle:countryTitle(selectedCountry) forState:UIControlStateNormal];

    UITextField *phoneField = [[UITextField alloc] init];
    phoneField.translatesAutoresizingMaskIntoConstraints = NO;
    phoneField.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[GM boldFontWithSize:18.0]];
    phoneField.adjustsFontForContentSizeCategory = YES;
    phoneField.accessibilityLabel = kLang(@"payment_mobile_placeholder");
    phoneField.placeholder = kLang(@"payment_mobile_placeholder");
    phoneField.keyboardType = UIKeyboardTypePhonePad;
    phoneField.textContentType = UITextContentTypeTelephoneNumber;
    phoneField.inputAccessoryView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 1.0, 0.01)];
    if (@available(iOS 9.0, *)) {
        phoneField.inputAssistantItem.leadingBarButtonGroups = @[];
        phoneField.inputAssistantItem.trailingBarButtonGroups = @[];
    }
    phoneField.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    phoneField.textAlignment = NSTextAlignmentLeft;
    phoneField.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.88];
    phoneField.layer.cornerRadius = 18.0;
    phoneField.layer.cornerCurve = kCACornerCurveContinuous;
    phoneField.layer.borderWidth = 1.0;
    phoneField.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.18].CGColor;
    phoneField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 16.0, 1.0)];
    phoneField.leftViewMode = UITextFieldViewModeAlways;
    phoneField.rightView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 16.0, 1.0)];
    phoneField.rightViewMode = UITextFieldViewModeAlways;
    NSString *dialDigits = [[selectedCountry.phoneCode ?: @"" stringByReplacingOccurrencesOfString:@"+" withString:@""]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *localDigits = existingDigits ?: @"";
    if (dialDigits.length > 0 && [localDigits hasPrefix:dialDigits]) {
        localDigits = [localDigits substringFromIndex:dialDigits.length];
    }
    phoneField.text = localDigits;

    [phoneField addTarget:self action:@selector(pp_phoneFieldEditingChanged:) forControlEvents:UIControlEventEditingChanged];

    UIStackView *phoneStack = [[UIStackView alloc] initWithArrangedSubviews:@[countryButton, phoneField]];
    phoneStack.translatesAutoresizingMaskIntoConstraints = NO;
    phoneStack.axis = UILayoutConstraintAxisHorizontal;
    phoneStack.alignment = UIStackViewAlignmentFill;
    phoneStack.distribution = UIStackViewDistributionFill;
    phoneStack.spacing = 10.0;
    phoneStack.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [sheet addSubview:phoneStack];

    __weak UIButton *weakCountryButton = countryButton;
    [countryButton addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        [phoneField resignFirstResponder];
        PPSelectOptionViewController *vc =
        [[PPSelectOptionViewController alloc] initWithOptions:[countries mutableCopy]
                                                        title:kLang(@"code_Palce")
                                                          row:nil
                                            presentationStyle:PPSelectOptionPresentationSheet
                                                    completion:^(id  _Nullable selectedObject) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (![selectedObject isKindOfClass:CountryCodeModel.class] ||
                    weakSelf.phoneEditorGeneration != editorGeneration) {
                    return;
                }
                selectedCountry = (CountryCodeModel *)selectedObject;
                [weakCountryButton setTitle:countryTitle(selectedCountry) forState:UIControlStateNormal];
                [phoneField becomeFirstResponder];
            });
        }];
        vc.optionCellBackgroundColor = UIColor.secondarySystemBackgroundColor;
        [weakSelf presentViewController:vc animated:YES completion:nil];
    }] forControlEvents:UIControlEventTouchUpInside];

    UILabel *errorLabel = [[UILabel alloc] init];
    errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    errorLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote] scaledFontForFont:[GM MidFontWithSize:12.5]];
    errorLabel.adjustsFontForContentSizeCategory = YES;
    errorLabel.textColor = UIColor.systemRedColor;
    errorLabel.text = @"";
    errorLabel.numberOfLines = 0;
    errorLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [sheet addSubview:errorLabel];

    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    cancelButton.titleLabel.font = [GM MidFontWithSize:16.0];
    [cancelButton setTitle:kLang(@"CancelButton") forState:UIControlStateNormal];
    cancelButton.tintColor = UIColor.secondaryLabelColor;
    cancelButton.backgroundColor = [UIColor.secondarySystemFillColor colorWithAlphaComponent:0.60];
    cancelButton.layer.cornerRadius = 18.0;
    cancelButton.layer.cornerCurve = kCACornerCurveContinuous;
    [sheet addSubview:cancelButton];

    UIButton *continueButton = [UIButton buttonWithType:UIButtonTypeSystem];
    continueButton.translatesAutoresizingMaskIntoConstraints = NO;
    continueButton.titleLabel.font = [GM boldFontWithSize:16.0];
    [continueButton setTitle:kLang(@"checkout_save_contact") forState:UIControlStateNormal];
    continueButton.tintColor = UIColor.whiteColor;
    continueButton.backgroundColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    continueButton.layer.cornerRadius = 18.0;
    continueButton.layer.cornerCurve = kCACornerCurveContinuous;
    [sheet addSubview:continueButton];

    UIView *hostView = self.navigationController.view ?: self.view.window ?: self.view;
    [hostView addSubview:overlay];
    [hostView bringSubviewToFront:overlay];
    NSLayoutConstraint *sheetBottomConstraint = [sheet.bottomAnchor constraintEqualToAnchor:hostView.safeAreaLayoutGuide.bottomAnchor constant:-12.0];
    UIScrollView *formScroll = [UIScrollView new];
    formScroll.translatesAutoresizingMaskIntoConstraints = NO;
    formScroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [sheet addSubview:formScroll];
    UIStackView *actions = [[UIStackView alloc] initWithArrangedSubviews:@[continueButton, cancelButton]];
    actions.axis = UILayoutConstraintAxisVertical;
    actions.spacing = PPSpaceXS;
    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel, phoneStack, errorLabel, actions]];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = PPSpaceMD;
    [formScroll addSubview:content];
    handle.hidden = YES;
    iconView.hidden = YES;
    for (UIButton *button in @[continueButton, cancelButton]) {
        button.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[GM boldFontWithSize:16.0]];
        button.titleLabel.adjustsFontForContentSizeCategory = YES;
        button.titleLabel.numberOfLines = 0;
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:54.0].active = YES;
    }
    NSLayoutConstraint *naturalHeight = [formScroll.heightAnchor constraintEqualToAnchor:content.heightAnchor constant:44.0];
    naturalHeight.priority = UILayoutPriorityDefaultHigh;
    NSLayoutConstraint *preferredWidth = [sheet.widthAnchor constraintEqualToAnchor:overlay.widthAnchor constant:-32.0];
    preferredWidth.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [overlay.topAnchor constraintEqualToAnchor:hostView.topAnchor],
        [overlay.leadingAnchor constraintEqualToAnchor:hostView.leadingAnchor],
        [overlay.trailingAnchor constraintEqualToAnchor:hostView.trailingAnchor],
        [overlay.bottomAnchor constraintEqualToAnchor:hostView.bottomAnchor],
        [blurView.topAnchor constraintEqualToAnchor:overlay.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor],
        [sheet.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
        preferredWidth, [sheet.widthAnchor constraintLessThanOrEqualToConstant:560.0],
        [sheet.topAnchor constraintGreaterThanOrEqualToAnchor:hostView.safeAreaLayoutGuide.topAnchor constant:12.0],
        sheetBottomConstraint,
        [formScroll.topAnchor constraintEqualToAnchor:sheet.topAnchor],
        [formScroll.bottomAnchor constraintEqualToAnchor:sheet.bottomAnchor],
        [formScroll.leadingAnchor constraintEqualToAnchor:sheet.leadingAnchor],
        [formScroll.trailingAnchor constraintEqualToAnchor:sheet.trailingAnchor], naturalHeight,
        [content.topAnchor constraintEqualToAnchor:formScroll.contentLayoutGuide.topAnchor constant:22.0],
        [content.bottomAnchor constraintEqualToAnchor:formScroll.contentLayoutGuide.bottomAnchor constant:-22.0],
        [content.leadingAnchor constraintEqualToAnchor:formScroll.contentLayoutGuide.leadingAnchor constant:22.0],
        [content.trailingAnchor constraintEqualToAnchor:formScroll.contentLayoutGuide.trailingAnchor constant:-22.0],
        [content.widthAnchor constraintEqualToAnchor:formScroll.frameLayoutGuide.widthAnchor constant:-44.0],
        [phoneStack.heightAnchor constraintGreaterThanOrEqualToConstant:58.0],
        [countryButton.widthAnchor constraintGreaterThanOrEqualToConstant:88.0],
        [countryButton.widthAnchor constraintLessThanOrEqualToAnchor:phoneStack.widthAnchor multiplier:0.40]
    ]];

    __block id keyboardWillChangeObserver = nil;
    __block id keyboardWillHideObserver = nil;
    void (^applyKeyboardFrame)(NSNotification *) = ^(NSNotification *note) {
        CGRect keyboardScreenFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
        CGRect keyboardFrame = [hostView convertRect:keyboardScreenFrame fromView:nil];
        CGFloat overlap = MAX(0.0, CGRectGetMaxY(hostView.bounds) - CGRectGetMinY(keyboardFrame));
        CGFloat safeBottom = hostView.safeAreaInsets.bottom;
        CGFloat liftedOffset = MAX(12.0, overlap - safeBottom + 12.0);
        sheetBottomConstraint.constant = -liftedOffset;

        NSTimeInterval duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
        if (duration <= 0.0) duration = 0.22;
        UIViewAnimationOptions options = UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction;
        NSNumber *curveNumber = note.userInfo[UIKeyboardAnimationCurveUserInfoKey];
        if (curveNumber) {
            options = ([curveNumber unsignedIntegerValue] << 16) | UIViewAnimationOptionAllowUserInteraction;
        }
        [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.12 : duration
                              delay:0.0
                            options:options
                         animations:^{
            [hostView layoutIfNeeded];
        } completion:nil];
    };

    keyboardWillChangeObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillChangeFrameNotification
                                                      object:nil
                                                       queue:NSOperationQueue.mainQueue
                                                  usingBlock:applyKeyboardFrame];
    keyboardWillHideObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillHideNotification
                                                      object:nil
                                                       queue:NSOperationQueue.mainQueue
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        sheetBottomConstraint.constant = -12.0;
        NSTimeInterval duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
        if (duration <= 0.0) duration = 0.18;
        [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.12 : duration
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            [hostView layoutIfNeeded];
        } completion:nil];
    }];

    __weak UIView *weakOverlay = overlay;
    __weak UIVisualEffectView *weakBlurView = blurView;
    __weak UIView *weakSheet = sheet;
    __block BOOL dismissed = NO;
    void (^dismissSheet)(void) = ^{
        if (dismissed) return;
        dismissed = YES;
        if (weakSelf.phoneEditorGeneration == editorGeneration) {
            [PPHUD dismiss];
            weakSelf.phoneEditorGeneration += 1;
            weakSelf.phoneEditorPresented = NO;
            weakSelf.dismissPhoneEditor = nil;
        }
        if (keyboardWillChangeObserver) {
            [[NSNotificationCenter defaultCenter] removeObserver:keyboardWillChangeObserver];
            keyboardWillChangeObserver = nil;
        }
        if (keyboardWillHideObserver) {
            [[NSNotificationCenter defaultCenter] removeObserver:keyboardWillHideObserver];
            keyboardWillHideObserver = nil;
        }
        [phoneField resignFirstResponder];
        [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.12 : 0.22
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            weakOverlay.alpha = 0.0;
            weakBlurView.alpha = 0.0;
            weakSheet.transform = UIAccessibilityIsReduceMotionEnabled() ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0.0, 36.0);
        } completion:^(BOOL finished) {
            [weakOverlay removeFromSuperview];
            UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, weakSelf.paymentContactButton);
        }];
    };

    [cancelButton addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        dismissSheet();
    }] forControlEvents:UIControlEventTouchUpInside];

    self.dismissPhoneEditor = dismissSheet;
    __weak UIButton *weakContinueButton = continueButton;
    __weak UIButton *weakCancelButton = cancelButton;
    [continueButton addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        __strong typeof(weakSelf) self = weakSelf;
        UIButton *continueButton = weakContinueButton;
        UIButton *cancelButton = weakCancelButton;
        UIButton *countryButton = weakCountryButton;
        if (!self || self.phoneEditorGeneration != editorGeneration ||
            ![editorUserID isEqualToString:[FIRAuth auth].currentUser.uid]) {
            dismissSheet();
            return;
        }

        NSString *entered = [self pp_trimmedAddressString:phoneField.text];
        NSString *rawPhone = ([entered hasPrefix:@"+"] || [entered hasPrefix:@"00"])
            ? entered : [NSString stringWithFormat:@"%@%@", selectedCountry.phoneCode ?: @"", entered ?: @""];
        NSString *normalized = [self pp_normalizedValidPhoneFromString:rawPhone];
        if (normalized.length == 0) {
            errorLabel.text = kLang(@"payment_mobile_invalid");
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, errorLabel.text);
            phoneField.layer.borderColor = UIColor.systemRedColor.CGColor;
            if (!UIAccessibilityIsReduceMotionEnabled()) {
                phoneField.transform = CGAffineTransformMakeTranslation(Language.isRTL ? 5.0 : -5.0, 0.0);
                [UIView animateWithDuration:0.28
                                      delay:0.0
                     usingSpringWithDamping:0.42
                      initialSpringVelocity:0.0
                                    options:UIViewAnimationOptionAllowUserInteraction
                                 animations:^{
                    phoneField.transform = CGAffineTransformIdentity;
                } completion:nil];
            }
            return;
        }

        continueButton.enabled = NO;
        cancelButton.enabled = NO;
        countryButton.enabled = NO;
        phoneField.enabled = NO;
        continueButton.alpha = 0.72;
        [PPHUD showLoading:kLang(@"Save")];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (weakSelf.phoneEditorGeneration != editorGeneration || continueButton.enabled) return;
            [PPHUD dismiss];
            errorLabel.text = kLang(@"checkout_contact_save_waiting");
            cancelButton.enabled = YES;
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, errorLabel.text);
        });
        [UsrMgr updateCurrentUserProfileWithValues:@{@"MobileNo": normalized}
                                        completion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self || self.phoneEditorGeneration != editorGeneration) return;
                [PPHUD dismiss];
                if (![[FIRAuth auth].currentUser.uid isEqualToString:editorUserID]) { dismissSheet(); return; }
                cancelButton.enabled = YES;
                countryButton.enabled = YES;
                phoneField.enabled = YES;
                continueButton.enabled = YES;
                continueButton.alpha = 1.0;
                if (error) {
                    errorLabel.text = error.localizedDescription ?: kLang(@"checkout_generic_error");
                    phoneField.layer.borderColor = UIColor.systemRedColor.CGColor;
                    return;
                }
                PPCurrentUser.MobileNo = normalized;
                dismissSheet();
                [self pp_updateCheckoutReview];
            });
        }];
    }] forControlEvents:UIControlEventTouchUpInside];

    sheet.transform = CGAffineTransformMakeTranslation(0.0, 44.0);
    if (UIAccessibilityIsReduceMotionEnabled()) {
        overlay.alpha = 1.0;
        overlay.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.22];
        blurView.alpha = 1.0;
        sheet.transform = CGAffineTransformIdentity;
        [phoneField becomeFirstResponder];
        return;
    }

    [UIView animateWithDuration:0.26
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        overlay.alpha = 1.0;
        overlay.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.22];
        blurView.alpha = 1.0;
        sheet.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        [phoneField becomeFirstResponder];
    }];
}

- (NSError *)pp_checkoutValidationErrorForAddress:(PPAddressModel *)address paymentMethodId:(NSString *)paymentMethodID
{
    if (paymentMethodID.length == 0) {
        return [NSError errorWithDomain:PPOrderCheckoutPreflightErrorDomain
                                   code:1000
                               userInfo:@{NSLocalizedDescriptionKey: kLang(@"checkout_payment_method_unavailable")}];
    }

    if (![self pp_isAddressCheckoutValid:address]) {
        return [NSError errorWithDomain:PPOrderCheckoutPreflightErrorDomain
                                   code:1001
                               userInfo:@{NSLocalizedDescriptionKey: kLang(@"checkout_invalid_address")}];
    }

    if ([self pp_checkoutMethodRequiresPhone:paymentMethodID]) {
        if ([self pp_isQIBMethodID:paymentMethodID]) {
            NSString *validPhone = [self pp_validQIBPhoneForAddress:address];
            if (validPhone.length == 0) {
                return [NSError errorWithDomain:PPOrderCheckoutPreflightErrorDomain
                                           code:PPOrderCheckoutPreflightCodeInvalidQIBPhone
                                       userInfo:@{NSLocalizedDescriptionKey: kLang(@"payment_qib_phone_invalid")}];
            }
        } else {
            NSString *phone = [self pp_trimmedAddressString:address.phoneNumber];
            if (phone.length == 0) {
                phone = [self pp_trimmedAddressString:PPCurrentUser.MobileNo];
            }
            if (phone.length == 0) {
                return [NSError errorWithDomain:PPOrderCheckoutPreflightErrorDomain
                                           code:1002
                                       userInfo:@{NSLocalizedDescriptionKey: kLang(@"payment_phone_required")}];
            }
        }
    }

    return nil;
}

- (BOOL)pp_hasAuthenticatedUser
{
    return [FIRAuth auth].currentUser.uid.length > 0;
}

- (void)pp_refreshLatestAddressesForCheckout:(void (^)(NSArray<PPAddressModel *> *, NSError *))completion
{
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (uid.length == 0) {
        if (completion) completion(@[], [NSError errorWithDomain:PPOrderCheckoutPreflightErrorDomain code:1003
            userInfo:@{NSLocalizedDescriptionKey:kLang(@"auth_register_required_title")}]);
        return;
    }
    NSUInteger generation = ++self.addressRefreshGeneration;
    self.isLoadingAddresses = YES;
    self.addressesLoadFailed = NO;
    [self pp_updateCheckoutReview];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.addressRefreshGeneration || !self.isLoadingAddresses ||
            ![[FIRAuth auth].currentUser.uid isEqualToString:uid]) return;
        self.addressRefreshGeneration += 1;
        self.isLoadingAddresses = NO;
        self.addressesLoadFailed = YES;
        [self pp_updateCheckoutReview];
    });
    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> *addresses, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || ![[FIRAuth auth].currentUser.uid isEqualToString:uid]) return;
            if (generation != self.addressRefreshGeneration) {
                if (completion) completion(@[], [NSError errorWithDomain:PPOrderCheckoutPreflightErrorDomain code:1004
                    userInfo:@{NSLocalizedDescriptionKey:kLang(@"checkout_details_changed_review")}]);
                return;
            }
            if (generation == self.addressRefreshGeneration) {
                self.isLoadingAddresses = NO;
                self.addressesLoadFailed = error != nil;
                if (!error) [self pp_applyAddresses:addresses ?: @[]];
                [self pp_updateCheckoutReview];
            }
            if (completion) completion(addresses, error);
        });
    }];
}

- (NSString *)pp_trimmedCheckoutMessage:(NSString *)message
{
    if (![message isKindOfClass:NSString.class]) return @"";
    return [message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL)pp_checkoutMessage:(NSString *)message containsAnyToken:(NSArray<NSString *> *)tokens
{
    NSString *lowercase = [self pp_trimmedCheckoutMessage:message].lowercaseString;
    if (lowercase.length == 0) return NO;
    for (NSString *token in tokens ?: @[]) {
        if (![token isKindOfClass:NSString.class] || token.length == 0) continue;
        if ([lowercase containsString:token.lowercaseString]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)pp_checkoutMessageContainsTechnicalIdentifier:(NSString *)message
{
    NSString *trimmed = [self pp_trimmedCheckoutMessage:message];
    if (trimmed.length == 0) return NO;

    static NSRegularExpression *uuidExpression;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        uuidExpression = [NSRegularExpression regularExpressionWithPattern:@"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
                                                                    options:0
                                                                      error:nil];
    });
    NSRange fullRange = NSMakeRange(0, trimmed.length);
    if ([uuidExpression firstMatchInString:trimmed options:0 range:fullRange]) {
        return YES;
    }

    return [self pp_checkoutMessage:trimmed containsAnyToken:@[
        @"firebase",
        @"firebasefunctions",
        @"functions",
        @"exception",
        @"internal error",
        @"print and inspect",
        @"app check",
        @"appcheck",
        @"app attest",
        @"appattest",
        @"devicecheck",
        @"unauthenticated",
        @"auth token",
        @"id token",
        @"qibsessionid",
        @"paymentattemptid",
        @"backend response",
        @"payload",
        @"domain=",
        @"code="
    ]];
}

- (NSString *)pp_userFacingCheckoutFailureMessageForError:(NSError *)error retryable:(BOOL)retryable
{
    NSString *rawReason = [self pp_trimmedCheckoutMessage:error.localizedDescription];
    if (rawReason.length == 0) {
        return retryable ? kLang(@"payment_retryable_failure_message") : kLang(@"checkout_generic_error");
    }

    if ([error.domain isEqualToString:@"Checkout"] && error.code == 1001) {
        return kLang(@"checkout_cart_empty_message");
    }

    if ([error.domain isEqualToString:@"Checkout"] && error.code == 1005) {
        return kLang(@"checkout_invalid_address");
    }

    if ([error.domain isEqualToString:@"Checkout"] && error.code == 1003 &&
        [self pp_checkoutMessageContainsTechnicalIdentifier:rawReason]) {
        return kLang(@"checkout_items_unavailable_review_cart");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"must be a positive number", @"invalid price"]]) {
        return kLang(@"checkout_item_price_invalid");
    }

    BOOL mentionsItem = [self pp_checkoutMessage:rawReason containsAnyToken:@[@"item ", @"cart item", @"product"]];
    BOOL unavailable = [self pp_checkoutMessage:rawReason containsAnyToken:@[@"unavailable", @"not available", @"no longer available", @"out of stock"]];
    if (mentionsItem && unavailable) {
        return kLang(@"checkout_item_unavailable_review_cart");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"inventory", @"stock"]]) {
        return kLang(@"checkout_items_unavailable_review_cart");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"cart is empty", @"empty cart"]]) {
        return kLang(@"checkout_cart_empty_message");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"address"]]) {
        return kLang(@"checkout_invalid_address");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"phone"]]) {
        return kLang(@"payment_phone_required");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"payment request already", @"already in progress"]]) {
        return kLang(@"payment_request_in_progress");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"payment method"]]) {
        return kLang(@"checkout_payment_method_unavailable");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"offline", @"internet", @"network"]]) {
        return kLang(@"offline_action_message");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"permission denied", @"not allowed"]]) {
        return kLang(@"payment_backend_permission_denied");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"app check", @"appcheck", @"app attest", @"appattest", @"devicecheck"]]) {
        return kLang(@"pp_app_check_unavailable");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"unauthenticated", @"auth token", @"id token", @"refresh your session"]]) {
        return kLang(@"pp_auth_session_refresh_failed");
    }

    if ([self pp_checkoutMessage:rawReason containsAnyToken:@[@"internal error", @"print and inspect"]]) {
        return kLang(@"payment_backend_unreachable");
    }

    if ([self pp_checkoutMessageContainsTechnicalIdentifier:rawReason]) {
        return retryable ? kLang(@"payment_retryable_failure_message") : kLang(@"checkout_generic_error");
    }

    if (retryable && [self pp_checkoutMessage:rawReason containsAnyToken:@[@"payment failed", @"gateway", @"sdk"]]) {
        return kLang(@"payment_retryable_failure_message");
    }

    return rawReason;
}

- (NSString *)pp_userFacingCheckoutPendingMessageForError:(NSError *)error
{
    NSString *rawReason = [self pp_trimmedCheckoutMessage:error.localizedDescription];
    if (rawReason.length == 0 || [self pp_checkoutMessageContainsTechnicalIdentifier:rawReason]) {
        return kLang(@"checkout_payment_verification_pending");
    }
    return rawReason;
}

- (BOOL)pp_checkoutFailureNeedsCartReviewForError:(NSError *)error userMessage:(NSString *)message
{
    NSString *rawReason = [self pp_trimmedCheckoutMessage:error.localizedDescription];
    NSString *safeMessage = [self pp_trimmedCheckoutMessage:message];
    if ([error.domain isEqualToString:@"Checkout"] && (error.code == 1001 || error.code == 1003)) {
        return YES;
    }
    if ([safeMessage isEqualToString:kLang(@"checkout_item_unavailable_review_cart")] ||
        [safeMessage isEqualToString:kLang(@"checkout_items_unavailable_review_cart")] ||
        [safeMessage isEqualToString:kLang(@"checkout_item_price_invalid")] ||
        [safeMessage isEqualToString:kLang(@"checkout_cart_empty_message")]) {
        return YES;
    }
    return [self pp_checkoutMessage:rawReason containsAnyToken:@[
        @"item ",
        @"cart item",
        @"inventory",
        @"stock",
        @"invalid price",
        @"positive number"
    ]];
}


- (void)finishPayments
{
    if (![self pp_hasAuthenticatedUser]) {
        [PPAlertHelper showWarningIn:self title:kLang(@"auth_register_required_title")
                            subtitle:kLang(@"auth_register_required_subtitle")];
        return;
    }
    if (self.isCheckoutInProgress || self.isPreparingCheckout) return;
    if (self.isAwaitingCheckoutCancellation) {
        [self pp_presentCheckoutCancellationPendingPromptForOrder:self.pendingCheckoutCancellationOrder];
        return;
    }
    if (!self.selectedAddress) {
        [self pp_presentAddressPickerOrPrompt];
        return;
    }
    if (![self pp_isAddressCheckoutValid:self.selectedAddress]) {
        AddressFormVC *editor = [[AddressFormVC alloc] initWithAddress:self.selectedAddress];
        editor.delegate = self;
        [self.navigationController pushViewController:editor animated:YES];
        return;
    }
    NSString *methodID = [self pp_selectedCheckoutPaymentMethodID];
    if (!methodID.length) {
        [self pp_showCheckoutReviewMessage:kLang(@"checkout_choose_payment")];
        [self fetchUserPaymentInstruments];
        return;
    }
    if ([self pp_checkoutMethodRequiresPhone:methodID] && ![self pp_validQIBPhoneForAddress:self.selectedAddress].length) {
        [self pp_editPaymentContact];
        return;
    }
    if (!self.explicitCheckoutItems && CartManager.sharedManager.hasPendingSyncOperations) {
        [self pp_showCheckoutReviewMessage:kLang(@"checkout_wait_for_cart")];
        return;
    }

    // Freeze the customer's actual confirmation before the first asynchronous operation.
    NSString *uid = [FIRAuth auth].currentUser.uid;
    NSString *addressID = [self pp_effectiveAddressID:self.selectedAddress];
    NSString *instrumentID = [self pp_resolvedSelectedInstrument].instrumentID;
    NSString *phoneSnapshot = [self pp_validQIBPhoneForAddress:self.selectedAddress] ?: @"";
    NSDictionary *addressSnapshot = [self.selectedAddress toDictionary].copy;
    NSArray *itemsSnapshot = [self pp_checkoutReviewItemsSnapshot];
    double total = [self pp_checkoutSummary].finalTotal;
    NSUInteger generation = ++self.checkoutPreflightGeneration;
    self.checkoutReviewMessage = nil;
    [self pp_setPreparingCheckout:YES];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.checkoutPreflightGeneration || !self.isPreparingCheckout) return;
        self.checkoutPreflightGeneration += 1;
        self.isLoadingAddresses = NO;
        self.addressesLoadFailed = YES;
        [self pp_setPreparingCheckout:NO];
        [self pp_showCheckoutReviewMessage:kLang(@"checkout_address_refresh_failed")];
    });
    [self pp_refreshLatestAddressesForCheckout:^(NSArray<PPAddressModel *> *addresses, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.checkoutPreflightGeneration || !self.isPreparingCheckout ||
            ![[FIRAuth auth].currentUser.uid isEqualToString:uid]) return;
        if (!self.view.window || self.navigationController.topViewController != self) {
            [self pp_setPreparingCheckout:NO];
            return;
        }
        [self pp_setPreparingCheckout:NO];
        if (error) {
            [self pp_showCheckoutReviewMessage:([error.domain isEqualToString:PPOrderCheckoutPreflightErrorDomain] && error.code == 1004)
                ? kLang(@"checkout_details_changed_review") : kLang(@"checkout_address_refresh_failed")];
            return;
        }
        PPAddressModel *confirmedAddress = nil;
        for (PPAddressModel *candidate in addresses) {
            if ([[self pp_effectiveAddressID:candidate] isEqualToString:addressID]) { confirmedAddress = candidate; break; }
        }
        // Selection removal, edits, price changes and pending cart writes require a new review.
        BOOL changed = !confirmedAddress || ![self.selectedAddressID isEqualToString:addressID] ||
            ![([self pp_validQIBPhoneForAddress:confirmedAddress] ?: @"") isEqualToString:phoneSnapshot] ||
            ![[self pp_resolvedSelectedInstrument].instrumentID isEqualToString:instrumentID] ||
            ![[self pp_selectedCheckoutPaymentMethodID] isEqualToString:methodID] ||
            ![[self pp_checkoutReviewItemsSnapshot] isEqualToArray:itemsSnapshot] ||
            fabs([self pp_checkoutSummary].finalTotal - total) > 0.0001 ||
            (!self.explicitCheckoutItems && CartManager.sharedManager.hasPendingSyncOperations);
        if (confirmedAddress) {
            // Timestamps/default preference do not change where a parcel goes.
            for (NSString *key in @[@"fullName", @"phoneNumber", @"addressLine1", @"addressLine2", @"postalCode", @"cityID", @"stateID", @"locationPoints"]) {
                id before = addressSnapshot[key] ?: @"";
                id after = [confirmedAddress toDictionary][key] ?: @"";
                id visible = [self.selectedAddress toDictionary][key] ?: @"";
                if (![before isEqual:after] || ![before isEqual:visible]) { changed = YES; break; }
            }
        }
        if (changed) {
            [self pp_refreshCheckoutPricingPresentation];
            [self pp_showCheckoutReviewMessage:kLang(@"checkout_details_changed_review")];
            return;
        }
        NSError *validation = [self pp_checkoutValidationErrorForAddress:confirmedAddress paymentMethodId:methodID];
        if (validation) {
            [self pp_showCheckoutReviewMessage:validation.localizedDescription];
            return;
        }
        self.selectedAddress = confirmedAddress;
        if (!self.checkoutCoordinator) {
            self.checkoutCoordinator = self.explicitCheckoutItems.count > 0
                ? [[PPCheckoutCoordinator alloc] initWithPresentingViewController:self checkoutItems:self.explicitCheckoutItems]
                : [[PPCheckoutCoordinator alloc] initWithPresentingViewController:self];
        }
        [self pp_startCheckoutWithPaymentMethodId:methodID];
    }];
}

#pragma mark - Checkout Execution & Retry (H-07)

/// Starts the QIB checkout flow.  Called both from the initial checkout tap
/// and from the "Retry Payment" action after a retryable failure or timeout.
/// The coordinator's checkoutIdempotencyKey is preserved across failures,
/// so the backend safely deduplicates order creation on retry.
- (void)pp_startCheckoutWithPaymentMethodId:(NSString *)paymentMethodId
{
    if (self.isAwaitingCheckoutCancellation) {
        [self pp_presentCheckoutCancellationPendingPromptForOrder:self.pendingCheckoutCancellationOrder];
        return;
    }

    if (self.isCheckoutInProgress || self.isPreparingCheckout) return;
    self.isCheckoutInProgress = YES;
    [self pp_updateCheckoutReview];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [self.summaryView setCheckoutLoading:YES];
    PPORDERLog(@"Checkout starting | paymentMethod=%@ | addressId=%@",
               paymentMethodId,
               [self pp_effectiveAddressID:self.selectedAddress]);

    __weak typeof(self) weakSelf = self;
    [self.checkoutCoordinator startCheckoutWithAddress:self.selectedAddress
                                        paymentMethodId:paymentMethodId
                                             completion:^(PPCheckoutResult result,
                                                          PPOrder *order,
                                                          NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf pp_handleCheckoutResult:result
                                          order:order
                                          error:error
                                paymentMethodId:paymentMethodId];
        });
    }];
}

- (void)pp_presentCheckoutCancellationPendingPromptForOrder:(PPOrder * _Nullable)order
{
    PPOrder *orderToResolve = order ?: self.pendingCheckoutCancellationOrder;
    if (!orderToResolve || !self.checkoutCoordinator) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"checkout_payment_cancellation_pending_title")
                          subtitle:kLang(@"checkout_payment_cancellation_pending_message")];
        return;
    }

    self.pendingCheckoutCancellationOrder = orderToResolve;
    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"checkout_payment_cancellation_pending_title")
                             subtitle:kLang(@"checkout_payment_cancellation_pending_message")
                        confirmButton:kLang(@"checkout_payment_cancellation_retry")
                         cancelButton:kLang(@"view_order_status")
                                 icon:nil
                         confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.isCheckoutInProgress = YES;
        [strongSelf.summaryView setCheckoutLoading:YES];
        [strongSelf.checkoutCoordinator retryCancellationForOrder:orderToResolve];
    }
                              cancelBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_openOrderDetailsForOrder:orderToResolve
                                  successMessage:kLang(@"checkout_payment_cancellation_pending_message")
                               presentationState:PPOrderDetailsEntryPresentationStateVerificationPending];
    }];
}

/// Handles every terminal checkout result.  Success, cancellation, and
/// non-retryable failures behave exactly as before.  For retryable QIB
/// payment failures and timeouts a "Retry Payment" button is offered.
- (void)pp_handleCheckoutResult:(PPCheckoutResult)result
                          order:(PPOrder * _Nullable)order
                          error:(NSError * _Nullable)error
                paymentMethodId:(NSString *)paymentMethodId
{
    self.isCheckoutInProgress = NO;
    [self.summaryView setCheckoutLoading:NO];
    [self pp_updateCheckoutReview];
    PPORDERLog(@"Checkout completed | result=%ld | orderId=%@ | error=%@",
               (long)result,
               order.orderId ?: @"",
               error.localizedDescription ?: @"");

    if (result == PPCheckoutResultSuccess) {
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentSuccess];
        NSString *successMessage = error.localizedDescription.length > 0
            ? error.localizedDescription
            : ((order && [order isCashOnDelivery])
               ? kLang(@"checkout_cod_success_subtitle")
               : kLang(@"order_paid_success_subtitle"));
        [self pp_openOrderDetailsForOrder:order
                           successMessage:successMessage
                        presentationState:PPOrderDetailsEntryPresentationStateCheckoutSuccess];

    } else if (result == PPCheckoutResultPendingVerification) {
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];

        // H-07: Offer retry for timeout / pending-verification states.
        BOOL isRetryable = [error.userInfo[PPCheckoutErrorIsRetryableKey] boolValue];
        NSString *pendingMessage = [self pp_userFacingCheckoutPendingMessageForError:error];

        if (isRetryable) {
            __weak typeof(self) weakRetry = self;
            [PPAlertHelper showConfirmationIn:self
                                        title:kLang(@"payment_pending_title")
                                     subtitle:pendingMessage
                                confirmButton:kLang(@"retry_payment")
                                 cancelButton:kLang(@"view_order_status")
                                         icon:nil
                                 confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
                __strong typeof(weakRetry) retryStrong = weakRetry;
                if (!retryStrong) return;
                PPORDERLog(@"User chose retry after pending verification | paymentMethod=%@", paymentMethodId);
                [retryStrong pp_startCheckoutWithPaymentMethodId:paymentMethodId];
            }
                                  cancelBlock:^{
                __strong typeof(weakRetry) retryStrong = weakRetry;
                if (!retryStrong) return;
                PPORDERLog(@"User chose view order after pending verification | orderId=%@", order.orderId ?: @"");
                [retryStrong pp_openOrderDetailsForOrder:order
                                          successMessage:pendingMessage
                                       presentationState:PPOrderDetailsEntryPresentationStateVerificationPending];
            }];
        } else {
            [self pp_openOrderDetailsForOrder:order
                               successMessage:pendingMessage
                            presentationState:PPOrderDetailsEntryPresentationStateVerificationPending];
        }

    } else if (result == PPCheckoutResultCancellationPending) {
        // Do not permit a second method while the server still owns an unpaid
        // QIB order. The customer can retry the abandonment or inspect its
        // real state, but cannot create a duplicate checkout from this screen.
        self.isAwaitingCheckoutCancellation = YES;
        self.pendingCheckoutCancellationOrder = order;
        [self pp_updateCheckoutReview];
        PPORDERLog(@"Checkout cancellation is not yet server-confirmed | orderId=%@ | error=%@",
                   order.orderId ?: @"",
                   error.localizedDescription ?: @"");
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        [self pp_presentCheckoutCancellationPendingPromptForOrder:order];

    } else if (result == PPCheckoutResultCancelled) {
        PPORDERLog(@"Payment cancelled by user | orderId=%@", order.orderId ?: @"");
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
        self.isAwaitingCheckoutCancellation = NO;
        self.pendingCheckoutCancellationOrder = nil;
        [self pp_updateCheckoutReview];
        // The abandoned order cannot be replayed for cash or another card.
        // Create a new coordinator only after its server cancellation succeeds.
        self.checkoutCoordinator = nil;

        // Return user to the payment screen with a clear choice:
        // choose another payment method or cancel the order entirely.
        __weak typeof(self) weakCancel = self;
        [PPAlertHelper showConfirmationIn:self
                                    title:kLang(@"payment_cancelled_title")
                                 subtitle:kLang(@"payment_cancelled_choose_method_message")
                            confirmButton:kLang(@"payment_cancelled_choose_another")
                             cancelButton:kLang(@"payment_cancelled_cancel_order")
                                     icon:nil
                             confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
            // User wants to pick a different payment method — stay on this screen.
            PPORDERLog(@"User chose to select another payment method after cancel");
        }
                              cancelBlock:^{
            __strong typeof(weakCancel) strongCancel = weakCancel;
            if (!strongCancel) return;
            PPORDERLog(@"User chose to cancel order after payment cancel");
            [strongCancel.navigationController popViewControllerAnimated:YES];
        }];

    } else {
        // PPCheckoutResultFailed
        // H-07: Offer retry for QIB payment failures (SDK error, verification
        // failure, Firestore-confirmed decline).  Validation errors (out-of-stock,
        // invalid address, etc.) remain non-retryable.
        BOOL isRetryable = [error.userInfo[PPCheckoutErrorIsRetryableKey] boolValue];
        NSString *rawReason = error.localizedDescription ?: @"";
        NSString *reason = [self pp_userFacingCheckoutFailureMessageForError:error retryable:isRetryable];
        BOOL needsCartReview = [self pp_checkoutFailureNeedsCartReviewForError:error userMessage:reason];
        PPORDERLog(@"Checkout failed | rawError=%@ | retryable=%d", rawReason, isRetryable);

        if (isRetryable) {
            __weak typeof(self) weakRetry = self;
            [PPAlertHelper showConfirmationIn:self
                                        title:kLang(@"payment_failed_title")
                                     subtitle:reason
                                confirmButton:kLang(@"retry_payment")
                                 cancelButton:kLang(@"cancel")
                                         icon:nil
                                 confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
                __strong typeof(weakRetry) retryStrong = weakRetry;
                if (!retryStrong) return;
                PPORDERLog(@"User chose retry after payment failure | paymentMethod=%@", paymentMethodId);
                [retryStrong pp_startCheckoutWithPaymentMethodId:paymentMethodId];
            }
                                  cancelBlock:nil];
        } else if (needsCartReview) {
            __weak typeof(self) weakReview = self;
            [PPAlertHelper showConfirmationIn:self
                                        title:kLang(@"checkout_review_cart_title")
                                     subtitle:reason
                                confirmButton:kLang(@"checkout_review_cart_action")
                                 cancelButton:kLang(@"OK")
                                         icon:nil
                                 confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
                if (!didConfirm) return;
                __strong typeof(weakReview) strongReview = weakReview;
                [strongReview.navigationController popViewControllerAnimated:YES];
            }
                                  cancelBlock:nil];
        } else {
            [PPAlertHelper showErrorIn:self title:kLang(@"checkout_failed_title") subtitle:reason];
        }
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
    }
}


-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self.view bringSubviewToFront:self.summaryView];
    self.summaryView.userInteractionEnabled = YES;
 }


- (void)dealloc
{
    [self pp_endPresentationTrace:NO];
    [self.addressesListener remove];
    self.addressesListener = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)pp_openOrderDetailsForOrder:(PPOrder *)order
                     successMessage:(NSString *)message
                  presentationState:(PPOrderDetailsEntryPresentationState)presentationState
{
    if (!order) {
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"order_placed_title")
                            subtitle:message.length > 0 ? message : kLang(@"order_paid_success_subtitle")];
        return;
    }

    UIViewController *detailsVC =
        [PPOrderDetailsRouter controllerWithOrder:order
                          entryPresentationState:presentationState
                                         message:message ?: @""];

    UINavigationController *nav = self.navigationController;
    if (nav) {
        [nav pushViewController:detailsVC animated:YES];

        // Clean up navigation stack: remove payment selection screen so that popping or
        // navigating back from order details returns directly to Home/previous root rather
        // than landing back on the payment screen after the order has already been placed.
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableArray<UIViewController *> *viewControllers = [nav.viewControllers mutableCopy];
            if ([viewControllers containsObject:self]) {
                [viewControllers removeObject:self];
                nav.viewControllers = viewControllers;
            }
        });
    }
}
@end
