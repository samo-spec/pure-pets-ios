//
//  PPPetCareViewerVC.m
//  Pure Pets
//
//  Medicine commerce/navigation owner. SwiftUI owns presentation only.
//

#import "PPPetCareViewerVC.h"
#import "VetManager.h"
#import "PetCareHelpers.h"
#import "PPBottomBar.h"
#import "CartManager.h"
#import "UIViewController+PPBottomSurface.h"
#import "PPNetworkRetryHelper.h"
#import "PPAlertHelper.h"
#import "PPHUD.h"
#import "PPFunc.h"
#import "PPRootTabBarController.h"
#import "PPNavigationController.h"
#import <Pure_Pets-Swift.h>
#import <math.h>

@interface PPPetCareViewerVC ()
@property (nonatomic, strong) VetMedicineModel *medicine;
@property (nonatomic, copy) NSString *mainKindName;
@property (nonatomic, strong) BBCartBottomBar *bottomBar;
@property (nonatomic, strong) NSLayoutConstraint *bottomBarHeightConstraint;
@property (nonatomic, strong) UIScrollView *dockViewport;
@property (nonatomic, strong) NSLayoutConstraint *dockViewportHeightConstraint;
@property (nonatomic, assign) BOOL dockWasScrollable;
@property (nonatomic, strong) PPMedicineViewerHostingController *medicineHost;
@end

@implementation PPPetCareViewerVC

- (PPBottomSurfaceKind)pp_preferredBottomSurfaceKind
{
    return PPBottomSurfaceKindViewerCartBottomBar;
}

- (UIView *)pp_bottomSurfaceView
{
    return self.dockViewport;
}

- (instancetype)initWithMedicine:(VetMedicineModel *)medicine
                    mainKindName:(NSString *)mainKindName
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) { return nil; }
    _medicine = medicine;
    _mainKindName = [PPPetCareSafeString(mainKindName)
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.hidesBottomBarWhenPushed = YES;
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.ppBackground;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    [self pp_setupLayout];
    [self pp_syncBottomBarState];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_handleCartUpdated:)
                                               name:kCartUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_languageDidChange:)
                                               name:PPLanguageDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pp_contentSizeDidChange:)
                                               name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:nil showBack:YES];
    self.navigationItem.title = kLang(@"pet_care_medicines");
    [self pp_syncBottomBarState];
    [self pp_applyBottomSurfaceAnimated:animated];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    CGFloat dockWidth = MAX(1.0, CGRectGetWidth(self.view.safeAreaLayoutGuide.layoutFrame));
    CGFloat height = [self.bottomBar preferredHeightForWidth:dockWidth
                                        bottomSafeAreaInset:self.view.safeAreaInsets.bottom];
    CGFloat availableHeight = MAX(0.0, CGRectGetHeight(self.view.bounds) - self.view.safeAreaInsets.top);
    CGFloat viewportHeight = MIN(height, availableHeight * 0.6);
    // Keep the complete dock scrollable in short/AX layouts and reserve space
    // for reading. Capping this viewport never truncates the dock's content.
    if (fabs(self.bottomBarHeightConstraint.constant - height) > 0.5) {
        self.bottomBarHeightConstraint.constant = height;
    }
    if (fabs(self.dockViewportHeightConstraint.constant - viewportHeight) > 0.5) {
        self.dockViewportHeightConstraint.constant = viewportHeight;
    }
    self.dockViewport.scrollEnabled = height > viewportHeight + 0.5;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGFloat maximumOffset = MAX(0.0, self.dockViewport.contentSize.height - CGRectGetHeight(self.dockViewport.bounds));
    if (!self.dockViewport.scrollEnabled) {
        self.dockViewport.contentOffset = CGPointZero;
    } else if (!self.dockWasScrollable) {
        // Reveal the primary action when large text first requires scrolling.
        self.dockViewport.contentOffset = CGPointMake(0.0, maximumOffset);
    } else if (self.dockViewport.contentOffset.y > maximumOffset) {
        self.dockViewport.contentOffset = CGPointMake(0.0, maximumOffset);
    }
    self.dockWasScrollable = self.dockViewport.scrollEnabled;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - SwiftUI Presentation

- (void)pp_setupLayout
{
    self.bottomBar = [[BBCartBottomBar alloc]
        initWithPresentationStyle:BBCartBottomBarPresentationStyleMedicineViewer];
    self.bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomBarHeightConstraint = [self.bottomBar.heightAnchor constraintEqualToConstant:108.0];
    self.dockViewport = [[UIScrollView alloc] init];
    self.dockViewport.translatesAutoresizingMaskIntoConstraints = NO;
    self.dockViewport.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.dockViewport.alwaysBounceVertical = NO;
    self.dockViewport.showsHorizontalScrollIndicator = NO;
    self.dockViewport.delaysContentTouches = NO;
    self.dockViewport.backgroundColor = UIColor.ppBackground;
    self.dockViewport.accessibilityIdentifier = @"medicine_record.cart_dock";
    self.dockViewportHeightConstraint = [self.dockViewport.heightAnchor constraintEqualToConstant:108.0];
    [self.view addSubview:self.dockViewport];
    [self.dockViewport addSubview:self.bottomBar];

    __weak typeof(self) weakSelf = self;
    self.medicineHost = [[PPMedicineViewerHostingController alloc]
        initWithContent:[self pp_presentationContent]
        onReturnToCare:^{ [weakSelf pp_returnToCareTapped]; }];
    [self addChildViewController:self.medicineHost];
    self.medicineHost.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view insertSubview:self.medicineHost.view belowSubview:self.dockViewport];
    [NSLayoutConstraint activateConstraints:@[
        [self.dockViewport.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.dockViewport.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [self.dockViewport.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        self.dockViewportHeightConstraint,
        [self.bottomBar.topAnchor constraintEqualToAnchor:self.dockViewport.contentLayoutGuide.topAnchor],
        [self.bottomBar.leadingAnchor constraintEqualToAnchor:self.dockViewport.contentLayoutGuide.leadingAnchor],
        [self.bottomBar.trailingAnchor constraintEqualToAnchor:self.dockViewport.contentLayoutGuide.trailingAnchor],
        [self.bottomBar.bottomAnchor constraintEqualToAnchor:self.dockViewport.contentLayoutGuide.bottomAnchor],
        [self.bottomBar.widthAnchor constraintEqualToAnchor:self.dockViewport.frameLayoutGuide.widthAnchor],
        self.bottomBarHeightConstraint,
        [self.medicineHost.view.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.medicineHost.view.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.medicineHost.view.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        // Physical separation from the measured dock avoids overlapping the last
        // text/button and counting its included home-indicator safe area twice.
        [self.medicineHost.view.bottomAnchor constraintEqualToAnchor:self.dockViewport.topAnchor]
    ]];
    [self.medicineHost didMoveToParentViewController:self];

    self.bottomBar.itemAmount = [self pp_unitAmount];
    self.bottomBar.onAddToCart = ^(NSInteger quantity) {
        [weakSelf pp_addToCartButtonTapped:quantity];
    };
    self.bottomBar.onQuantityChanged = ^(NSInteger quantity) {
        (void)quantity;
        [weakSelf pp_syncBottomBarState];
    };
    self.bottomBar.cartItemquantity = 1;
    [self.bottomBar setInitItemAmount:[self pp_unitAmount]];
    [self.bottomBar updateQuantityUI];
    [self.bottomBar.favButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [self.bottomBar.favButton addTarget:self action:@selector(pp_shareTapped)
                     forControlEvents:UIControlEventTouchUpInside];
    self.bottomBar.favButton.accessibilityLabel = kLang(@"pet_care_viewer_share");
}

- (PPMedicineViewerContent *)pp_presentationContent
{
    PPMedicineViewerContent *content = [[PPMedicineViewerContent alloc] init];
    content.identifier = PPPetCareMedicineItemIdentifier(self.medicine);
    content.title = PPPetCareSafeString(self.medicine.title);
    content.category = PPPetCareSafeString(self.medicine.category);
    NSMutableArray<NSString *> *species = [NSMutableArray array];
    for (id value in self.medicine.animalTypes) {
        NSString *name = [PPPetCareSafeString(value)
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length > 0) { [species addObject:name]; }
    }
    content.speciesNames = species;
    // This is browsing context, never evidence that a medicine suits a species.
    content.discoveryContext = self.mainKindName;
    content.descriptionText = PPPetCareSafeString(self.medicine.medicineDescription);
    content.imageURL = PPPetCareSafeString(self.medicine.imageUrl);
    content.displayPrice = [self pp_formattedPrice];
    content.stockQuantity = MAX(self.medicine.stockQuantity, 0);
    content.cartQuantity = PPPetCareCartQuantityForMedicine(self.medicine);
    content.purchaseEligible = [self pp_canPurchaseMedicine];
    content.canReturnToCare = self.navigationController.viewControllers.count > 1;
    if ([self.medicine.createdAt isKindOfClass:NSDate.class]) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:Language.currentLanguageCode];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterNoStyle;
        content.addedDateText = [formatter stringFromDate:self.medicine.createdAt] ?: @"";
    }
    return content;
}

- (void)pp_languageDidChange:(NSNotification *)notification
{
    (void)notification;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
        self.navigationItem.title = kLang(@"pet_care_medicines");
        self.bottomBar.favButton.accessibilityLabel = kLang(@"pet_care_viewer_share");
        [self pp_syncBottomBarState];
        [self.view setNeedsLayout];
    });
}

- (void)pp_contentSizeDidChange:(NSNotification *)notification
{
    (void)notification;
    dispatch_async(dispatch_get_main_queue(), ^{ [self.view setNeedsLayout]; });
}

#pragma mark - Localized Commerce Presentation

- (CGFloat)pp_unitAmount
{
    return isfinite(self.medicine.price) ? MAX(self.medicine.price, 0.0) : 0.0;
}

- (BOOL)pp_canPurchaseMedicine
{
    return self.medicine.isAvailable && self.medicine.isPublished && !self.medicine.isDisabled
        && PPPetCareMedicineItemIdentifier(self.medicine).length > 0 && isfinite(self.medicine.price);
}

- (NSNumberFormatter *)pp_numberFormatter
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:Language.currentLanguageCode];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    return formatter;
}

- (NSString *)pp_numberString:(NSInteger)value
{
    NSNumberFormatter *formatter = [self pp_numberFormatter];
    formatter.maximumFractionDigits = 0;
    return [formatter stringFromNumber:@(value)] ?: @"";
}

- (NSString *)pp_amountString:(CGFloat)value
{
    NSNumberFormatter *formatter = [self pp_numberFormatter];
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 2;
    return [formatter stringFromNumber:@(value)] ?: @"";
}

- (NSString *)pp_formattedPrice
{
    NSNumberFormatter *formatter = [self pp_numberFormatter];
    formatter.numberStyle = NSNumberFormatterCurrencyISOCodeStyle;
    formatter.currencyCode = PPPetCareMedicineCurrencyCode(self.medicine);
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 2;
    return [formatter stringFromNumber:@([self pp_unitAmount])] ?: @"";
}

#pragma mark - Cart & Actions

- (void)pp_handleCartUpdated:(NSNotification *)notification
{
    (void)notification;
    dispatch_async(dispatch_get_main_queue(), ^{ [self pp_syncBottomBarState]; });
}

- (void)pp_syncBottomBarState
{
    NSInteger existingQuantity = PPPetCareCartQuantityForMedicine(self.medicine);
    NSInteger stockQuantity = MAX(self.medicine.stockQuantity, 0);
    NSInteger remainingToAdd = MAX(0, stockQuantity - existingQuantity);
    NSInteger selectedQuantity = MAX(self.bottomBar.cartItemquantity, 1);
    if (remainingToAdd > 0 && selectedQuantity > remainingToAdd) {
        self.bottomBar.cartItemquantity = remainingToAdd;
        // updateQuantityUI re-enters through the callback once, now within bounds.
        [self.bottomBar updateQuantityUI];
        return;
    }

    CGFloat itemAmount = [self pp_unitAmount];
    CGFloat total = itemAmount * selectedQuantity;
    self.bottomBar.itemAmount = itemAmount;
    if (fabs(self.bottomBar.totalAmount - total) > 0.001) {
        self.bottomBar.totalAmount = total;
    }
    [self.bottomBar setPurchaseAvailable:[self pp_canPurchaseMedicine] && remainingToAdd > 0];
    BOOL canIncrease = self.bottomBar.plusButton.enabled && selectedQuantity < remainingToAdd;
    self.bottomBar.plusButton.enabled = canIncrease;
    self.bottomBar.plusButton.alpha = canIncrease ? 1.0 : 0.36;
    // The shared dock keeps its established layout and action state machine.
    // Format only this medicine instance with the app's active language.
    self.bottomBar.countLabel.text = [self pp_numberString:selectedQuantity];
    self.bottomBar.countLabel.accessibilityValue = self.bottomBar.countLabel.text;
    self.bottomBar.amountLabel.text = [self pp_amountString:total];
    self.bottomBar.currencyLabel.text = PPPetCareMedicineCurrencyCode(self.medicine);
    self.bottomBar.totalContainer.accessibilityValue = [NSString stringWithFormat:@"\u2068%@\u2069 \u2068%@\u2069",
        self.bottomBar.amountLabel.text, self.bottomBar.currencyLabel.text];
    [self.medicineHost updateWithContent:[self pp_presentationContent]];
    [self.view setNeedsLayout];
}

- (void)pp_addToCartButtonTapped:(NSInteger)quantity
{
    if (![PPNetworkRetryHelper isNetworkAvailable]) {
        [self.bottomBar performAddToCartFailureAnimation];
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"offline_action_title")
                            subtitle:kLang(@"offline_action_message")
                          completion:nil];
        return;
    }

    if (![self pp_ensureSignedInForAction]) {
        [self.bottomBar performAddToCartFailureAnimation];
        return;
    }

    NSInteger stockQuantity = MAX(self.medicine.stockQuantity, 0);
    NSInteger existingQuantity = PPPetCareCartQuantityForMedicine(self.medicine);
    NSInteger requestedQuantity = MAX(quantity, 1);
    NSInteger availableToAdd = MAX(0, stockQuantity - existingQuantity);

    if (![self pp_canPurchaseMedicine] || stockQuantity <= 0 || availableToAdd <= 0) {
        [self.bottomBar performAddToCartFailureAnimation];
        [PPHUD showError:kLang(@"Out of stock")];
        [PPFunc triggerWarningHaptic];
        return;
    }

    NSInteger safeQuantity = MIN(requestedQuantity, availableToAdd);
    CartItem *item = PPPetCareCartItemForMedicine(self.medicine, safeQuantity);
    if (!item) {
        [self.bottomBar performAddToCartFailureAnimation];
        [PPHUD showError:kLang(@"Out of stock")];
        [PPFunc triggerWarningHaptic];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [[CartManager sharedManager] addItem:item
                presentingViewController:self
                               completion:^(BOOL didAdd, BOOL didCancel) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        if (didCancel) {
            [self.bottomBar cancelAddToCartPendingState];
            return;
        }
        if (!didAdd) {
            [self.bottomBar performAddToCartFailureAnimation];
            [PPHUD showError:kLang(@"Out of stock")];
            [PPFunc triggerWarningHaptic];
            return;
        }

        NSString *message = safeQuantity < requestedQuantity
            ? [NSString stringWithFormat:kLang(@"medicine_record_partial_add_format"),
               [self pp_numberString:availableToAdd]]
            : kLang(@"ItemAddedToYourCart");

        [self.bottomBar performAddToCartSuccessAnimation];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [PPAddToCartSuccessToast showWithTitle:kLang(@"AddedToCart") subtitle:message];
        });
        if (safeQuantity == 1) {
            [PPFunc triggerLightHaptic];
        } else {
            [PPFunc triggerMediumHaptic];
        }

        self.bottomBar.cartItemquantity = 1;
        [self.bottomBar updateQuantityUI];
        [self pp_syncBottomBarState];
    }];
}

- (BOOL)pp_ensureSignedInForAction
{
    if (UserManager.sharedManager.isUserLoggedIn) {
        return YES;
    }
    [PPFunc triggerWarningHaptic];
    [UserManager showPromptOnTopController];
    return NO;
}

- (void)pp_shareTapped
{
    if (self.presentedViewController || !self.view.window) { return; }
    [PPFunc triggerLightHaptic];
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *title = PPPetCareSafeString(self.medicine.title);
    [parts addObject:title.length > 0 ? title : kLang(@"pet_care_medicine_untitled")];
    NSString *description = PPPetCareSafeString(self.medicine.medicineDescription);
    if (description.length > 0) { [parts addObject:description]; }
    [parts addObject:[NSString stringWithFormat:kLang(@"medicine_record_share_price_format"),
        [self pp_formattedPrice]]];

    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
        initWithActivityItems:@[[parts componentsJoinedByString:@"\n"]] applicationActivities:nil];
    UIPopoverPresentationController *popover = activityVC.popoverPresentationController;
    popover.sourceView = self.bottomBar.favButton ?: self.view;
    popover.sourceRect = popover.sourceView.bounds;
    [self presentViewController:activityVC animated:!UIAccessibilityIsReduceMotionEnabled() completion:nil];
}

- (void)pp_returnToCareTapped
{
    // Preserve the existing pop. This action does not initiate a consultation.
    [PPFunc triggerLightHaptic];
    [self.navigationController popViewControllerAnimated:!UIAccessibilityIsReduceMotionEnabled()];
}

@end
