//
//  PPPaymentSelectionViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/11/2025.
//

#import "PPSelectPaymentVC.h"
#import "PPSelectPaymentVC+Helper.h"
#import "PPAddressPickerView.h"
#import "PPCheckoutCoordinator.h"
#import "PPPaymentManager.h"
#import "CartManager.h"
#import "PPCartCalculator.h"
#import "PPAddressesManager.h"
#import "UserModel.h"
#import "AddressFormVC.h"
#import "UserManager.h"
#import "PPCommerceFeedbackManager.h"
#import "OrderDetailsViewController.h"

#import "PPSelectAddressVC.h"

@import FirebaseAuth;

#define PPORDERLog(fmt, ...) NSLog((@"[PPORDER] " fmt), ##__VA_ARGS__)

static NSString * const PPOrderCheckoutPreflightErrorDomain = @"PPOrderCheckoutPreflight";



#pragma mark - ViewController

@interface PPSelectPaymentVC ()
@property (nonatomic, strong, nullable) UIVisualEffectView *dimOverlay;
@property (nonatomic, strong) UILabel *collectionHintLabel;
@property (nonatomic, strong) NSArray<PPAddressModel *> *Addresses;
@property (nonatomic, strong) PPAddressModel *selectedAddress;
@property (nonatomic, strong) PPCheckoutCoordinator *checkoutCoordinator;
@property (nonatomic, assign) BOOL isCheckoutInProgress;
@property (nonatomic, strong) id<FIRListenerRegistration> addressesListener;
@property (nonatomic, strong) PPAddressPickerView *locView;
@property (nonatomic, strong) UIView *heroCardView;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) UILabel *heroEyebrowLabel;
@property (nonatomic, strong) UILabel *heroTitleLabel;
@property (nonatomic, strong) UILabel *heroSubtitleLabel;
@end

@implementation PPSelectPaymentVC

- (void)viewDidLoad {
    [super viewDidLoad];

    self.instrumentManager = [UserPaymentInstrumentManager sharedManager];
    self.availableMethods = [PaymentMethod defaultMethods];
    self.userInstruments = @[];
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.title = kLang(@"SelectPaymentMethod");
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    [self pp_configureNavigationChrome];
    [self setlocViewViewAtTop];
    [self pp_setupHeroSection];
    [self setSummuryViewAtBottom];
    [self setupPaymentCollection];
    [self pp_applyDefaultSelectionIfNeeded];
    [self pp_refreshCheckoutCallToAction];
    [self fetchUserPaymentInstruments];
    [self pp_refreshLatestAddressesForCheckout:nil];

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
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    self.heroGradientLayer.frame = self.heroCardView.bounds;
    if (!CGRectIsEmpty(self.heroCardView.bounds)) {
        self.heroCardView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.heroCardView.bounds
                                                                        cornerRadius:self.heroCardView.layer.cornerRadius].CGPath;
    }
}

- (void)pp_configureNavigationChrome
{
    UIButton *backButton = [PPButtonHelper pp_buttonWithTitleForBar:nil
                                                          imageName:PPChevronName
                                                             target:self
                                                             action:@selector(onBack:)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
}

- (void)setSummuryViewAtBottom
{
    self.summaryView = [[BBCheckoutSummaryView alloc] init];
    [self.view addSubview:self.summaryView];
    self.summaryView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.summaryView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
    [self.summaryView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [self.summaryView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;

    // Suppress the internal cardView entrance animation — this VC handles
    // the entrance on the whole summaryView itself (see animation below).
    // Without this, two overlapping animations cause a visible jump.
    [self.summaryView skipCardEntranceAnimation];

    // Start hidden; the outer spring animation below reveals it smoothly.
    self.summaryView.alpha = 0.0;
    self.summaryView.transform = CGAffineTransformMakeTranslation(0.0, 20.0);

    __weak typeof(self) weakSelf = self;
    self.summaryView.onTapCheckOut = ^{
        NSLog(@"🛒 Checkout tapped on PPSelectPaymentVC+Helper");
        [weakSelf finishPayments];
    };
    // Update summary with cart data via centralized calculator
    PPCartSummary *summary = [PPCartCalculator currentSummary];

    BOOL showShowCollectionPreview = CartManager.sharedManager.cartItems.count > 3;
    [self.summaryView updateTotalsWithItems:summary.subtotal shipping:summary.shippingFee showTitle:NO];
    self.summaryView.showDetails = !showShowCollectionPreview ;
    [self.summaryView updatePreviewItems:CartManager.sharedManager.cartItems];
    self.summaryView.showsItemsPreview = showShowCollectionPreview;
    [self.summaryView setCheckoutBTNTitle:kLang(@"payment_pay_now") image:[UIImage pp_symbolNamed:@"creditcard.fill" pointSize:18  //.fill.and.123
                                                                                   weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleLarge palette:@[AppForgroundColr,AppForgroundColr] makeTemplate:NO]];

    if ([CartManager sharedManager].cartItems.count > 0) {
        [_summaryView pp_startTrustBannerShimmer];
    }

    // Smooth entrance after layout settles
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.45
                              delay:0.08
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            weakSelf.summaryView.alpha = 1.0;
            weakSelf.summaryView.transform = CGAffineTransformIdentity;
        } completion:nil];
    });
}

- (void)setlocViewViewAtTop
{
    self.locView = [PPAddressPickerView showInViewController:self width:self.view.hx_w - 32];
    [self.locView setAddressText:kLang(@"PleaseSelectDeliveryLocation")];
    __weak typeof(self) weakSelf = self;
    self.locView.onPickAddress = ^{
        [weakSelf pp_presentAddressPickerOrPrompt];
    };
    [self.locView expandAndLock];
    [self pp_setupInitialAddressState];
}

- (void)pp_setupHeroSection
{
    self.heroCardView = [[UIView alloc] init];
    self.heroCardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroCardView.layer.cornerRadius = 30.0;
    self.heroCardView.layer.cornerCurve = kCACornerCurveContinuous;
    self.heroCardView.layer.borderWidth = 1.0;
    self.heroCardView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.24].CGColor;
    self.heroCardView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.heroCardView.layer.shadowOpacity = 0.08;
    self.heroCardView.layer.shadowRadius = 18.0;
    self.heroCardView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    self.heroCardView.clipsToBounds = NO;
    [self.view addSubview:self.heroCardView];

    self.heroGradientLayer = [CAGradientLayer layer];
    self.heroGradientLayer.colors = @[
        (id)[AppPrimaryClr   colorWithAlphaComponent:0.16].CGColor,
        (id)[AppForgroundColr   colorWithAlphaComponent:0.98].CGColor,
        (id)[AppForgroundColr   colorWithAlphaComponent:1.0].CGColor
    ];
    self.heroGradientLayer.locations = @[@0.0, @0.45, @1.0];
    self.heroGradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.heroGradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.heroGradientLayer.cornerRadius = 30.0;
    [self.heroCardView.layer insertSublayer:self.heroGradientLayer atIndex:0];

    UIView *eyebrowContainer = [[UIView alloc] init];
    eyebrowContainer.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrowContainer.backgroundColor = [AppPrimaryClr ?: UIColor.brownColor colorWithAlphaComponent:0.10];
    eyebrowContainer.layer.cornerRadius = 14.0;
    eyebrowContainer.layer.cornerCurve = kCACornerCurveContinuous;
    [self.heroCardView addSubview:eyebrowContainer];

    self.heroEyebrowLabel = [[UILabel alloc] init];
    self.heroEyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroEyebrowLabel.font = [GM MidFontWithSize:12.0];
    self.heroEyebrowLabel.textColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    self.heroEyebrowLabel.textAlignment = NSTextAlignmentNatural;
    self.heroEyebrowLabel.text = kLang(@"payment_screen_eyebrow");
    [eyebrowContainer addSubview:self.heroEyebrowLabel];

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [AppForgroundColr ?: UIColor.whiteColor colorWithAlphaComponent:0.75];
    iconSurface.layer.cornerRadius = 22.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [self.heroCardView addSubview:iconSurface];

    UIImageView *heroIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"creditcard.and.123"]];
    heroIconView.translatesAutoresizingMaskIntoConstraints = NO;
    heroIconView.tintColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    heroIconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconSurface addSubview:heroIconView];

    self.heroTitleLabel = [[UILabel alloc] init];
    self.heroTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTitleLabel.font = [GM boldFontWithSize:28.0];
    self.heroTitleLabel.textColor = UIColor.labelColor;
    self.heroTitleLabel.numberOfLines = 2;
    self.heroTitleLabel.textAlignment = NSTextAlignmentNatural;
    self.heroTitleLabel.text = kLang(@"payment_screen_title");
    [self.heroCardView addSubview:self.heroTitleLabel];

    self.heroSubtitleLabel = [[UILabel alloc] init];
    self.heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSubtitleLabel.font = [GM MidFontWithSize:14.0];
    self.heroSubtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.heroSubtitleLabel.numberOfLines = 0;
    self.heroSubtitleLabel.textAlignment = NSTextAlignmentNatural;
    self.heroSubtitleLabel.text = kLang(@"payment_screen_subtitle");
    [self.heroCardView addSubview:self.heroSubtitleLabel];

    UILabel *deliveryLabel = [[UILabel alloc] init];
    deliveryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    deliveryLabel.font = [GM boldFontWithSize:16.0];
    deliveryLabel.textColor = UIColor.labelColor;
    deliveryLabel.textAlignment = NSTextAlignmentNatural;
    deliveryLabel.text = kLang(@"payment_section_delivery");
    [self.heroCardView addSubview:deliveryLabel];

    UILabel *deliverySubtitleLabel = [[UILabel alloc] init];
    deliverySubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    deliverySubtitleLabel.font = [GM MidFontWithSize:13.0];
    deliverySubtitleLabel.textColor = UIColor.secondaryLabelColor;
    deliverySubtitleLabel.numberOfLines = 2;
    deliverySubtitleLabel.textAlignment = NSTextAlignmentNatural;
    deliverySubtitleLabel.text = kLang(@"payment_section_delivery_subtitle");
    [self.heroCardView addSubview:deliverySubtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroCardView.topAnchor constraintEqualToAnchor:self.locView.bottomAnchor constant:18.0],
        [self.heroCardView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [self.heroCardView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],

        [eyebrowContainer.topAnchor constraintEqualToAnchor:self.heroCardView.topAnchor constant:20.0],
        [eyebrowContainer.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor constant:20.0],

        [self.heroEyebrowLabel.topAnchor constraintEqualToAnchor:eyebrowContainer.topAnchor constant:7.0],
        [self.heroEyebrowLabel.bottomAnchor constraintEqualToAnchor:eyebrowContainer.bottomAnchor constant:-7.0],
        [self.heroEyebrowLabel.leadingAnchor constraintEqualToAnchor:eyebrowContainer.leadingAnchor constant:12.0],
        [self.heroEyebrowLabel.trailingAnchor constraintEqualToAnchor:eyebrowContainer.trailingAnchor constant:-12.0],

        [iconSurface.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor constant:-20.0],
        [iconSurface.centerYAnchor constraintEqualToAnchor:eyebrowContainer.centerYAnchor],
        [iconSurface.widthAnchor constraintEqualToConstant:44.0],
        [iconSurface.heightAnchor constraintEqualToConstant:44.0],

        [heroIconView.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [heroIconView.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],
        [heroIconView.widthAnchor constraintEqualToConstant:22.0],
        [heroIconView.heightAnchor constraintEqualToConstant:22.0],

        [self.heroTitleLabel.topAnchor constraintEqualToAnchor:eyebrowContainer.bottomAnchor constant:16.0],
        [self.heroTitleLabel.leadingAnchor constraintEqualToAnchor:self.heroCardView.leadingAnchor constant:20.0],
        [self.heroTitleLabel.trailingAnchor constraintEqualToAnchor:self.heroCardView.trailingAnchor constant:-20.0],

        [self.heroSubtitleLabel.topAnchor constraintEqualToAnchor:self.heroTitleLabel.bottomAnchor constant:10.0],
        [self.heroSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.heroTitleLabel.leadingAnchor],
        [self.heroSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.heroTitleLabel.trailingAnchor],

        [deliveryLabel.topAnchor constraintEqualToAnchor:self.heroSubtitleLabel.bottomAnchor constant:18.0],
        [deliveryLabel.leadingAnchor constraintEqualToAnchor:self.heroTitleLabel.leadingAnchor],
        [deliveryLabel.trailingAnchor constraintEqualToAnchor:self.heroTitleLabel.trailingAnchor],

        [deliverySubtitleLabel.topAnchor constraintEqualToAnchor:deliveryLabel.bottomAnchor constant:6.0],
        [deliverySubtitleLabel.leadingAnchor constraintEqualToAnchor:self.heroTitleLabel.leadingAnchor],
        [deliverySubtitleLabel.trailingAnchor constraintEqualToAnchor:self.heroTitleLabel.trailingAnchor],
        [deliverySubtitleLabel.bottomAnchor constraintEqualToAnchor:self.heroCardView.bottomAnchor constant:-20.0],
    ]];
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

    NSString *displayName = [self pp_trimmedAddressString:address.displayName];
    if (displayName.length > 0) return displayName;

    NSString *legacyLocation = [self pp_trimmedAddressString:address.locatioName];
    if (legacyLocation.length > 0) return legacyLocation;

    NSString *line1 = [self pp_trimmedAddressString:address.addressLine1];
    if (line1.length > 0) return line1;

    NSString *fullName = [self pp_trimmedAddressString:address.fullName];
    if (fullName.length > 0) return fullName;

    return @"";
}

- (void)pp_setupInitialAddressState
{
    [self.addressesListener remove];
    self.addressesListener = nil;
    self.Addresses = @[];
    self.selectedAddress = nil;
    [self.locView setAddressText:kLang(@"PleaseSelectDeliveryLocation")];

    if (![self pp_hasAuthenticatedUser]) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    self.addressesListener = [PPADDRESS listenToAddressesWithBlock:^(NSArray<PPAddressModel *> * _Nullable addresses, NSError * _Nullable error) {
        if (error) {
            PPORDERLog(@"Address listener error | error=%@", error.localizedDescription ?: @"Unknown");
            return;
        }
        [weakSelf pp_applyAddresses:addresses ?: @[]];
    }];

    [self pp_refreshLatestAddressesForCheckout:nil];
}

- (void)pp_applyAddresses:(NSArray<PPAddressModel *> *)addresses
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.Addresses = addresses ?: @[];
        UserModel *currentUser = UsrMgr.currentUser;
        if (currentUser) {
            currentUser.Addresses = strongSelf.Addresses.mutableCopy;
            [UsrMgr cacheUser:currentUser];
        }
        PPAddressModel *preferred = [strongSelf pp_preferredAddressFrom:strongSelf.Addresses];
        strongSelf.selectedAddress = preferred;
        PPORDERLog(@"Addresses refreshed | count=%lu | selectedAddressId=%@",
                   (unsigned long)strongSelf.Addresses.count,
                   [strongSelf pp_effectiveAddressID:preferred]);

        NSString *addressText = [strongSelf pp_bestAddressDisplayText:preferred];
        if (addressText.length > 0) {
            [strongSelf.locView setAddressText:addressText];
        } else {
            [strongSelf.locView setAddressText:kLang(@"PleaseSelectDeliveryLocation")];
        }
    });
}

- (PPAddressModel *)pp_preferredAddressFrom:(NSArray<PPAddressModel *> *)addresses
{
    if (addresses.count == 0) return nil;

    NSString *selectedID = [self pp_effectiveAddressID:self.selectedAddress];
    if (selectedID.length > 0) {
        for (PPAddressModel *address in addresses) {
            NSString *candidateID = [self pp_effectiveAddressID:address];
            if ([candidateID isEqualToString:selectedID]) {
                return address;
            }
        }
    }

    for (PPAddressModel *address in addresses) {
        if (address.isDefault) {
            return address;
        }
    }

    return addresses.firstObject;
}

- (void)pp_presentAddressPickerOrPrompt
{
    __weak typeof(self) weakSelf = self;
    void (^presentPicker)(NSArray<PPAddressModel *> *) = ^(NSArray<PPAddressModel *> *addresses) {
        PPSelectAddressVC *vc =
        [[PPSelectAddressVC alloc] initWithOptions:addresses
                                                        title:kLang(@"select_delivery_location_title")
                                                          row:nil
                                            presentationStyle:PPSelectOptionPresentationSheet
                                                    completion:^(id  _Nullable selectedObject) {
            PPAddressModel *selected = (PPAddressModel *)selectedObject;
            if (!selected) return;
            weakSelf.selectedAddress = selected;
            NSString *selectedText = [weakSelf pp_bestAddressDisplayText:selected];
            [weakSelf.locView setAddressText:selectedText.length > 0 ? selectedText : kLang(@"PleaseSelectDeliveryLocation")];
        }];
        [PPFunc presentSheetFrom:weakSelf sheetVC:vc detentStyle:PPSheetDetentStyle80];
        
    };

    if (self.Addresses.count > 0) {
        presentPicker(self.Addresses);
        return;
    }

    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nonnull addresses, NSError * _Nullable error) {
        if (!error && addresses.count > 0) {
            [weakSelf pp_applyAddresses:addresses];
            presentPicker(weakSelf.Addresses);
            return;
        }

        [weakSelf.locView setAddressText:kLang(@"PleaseSelectDeliveryLocation")];
        [PPAlertHelper showConfirmationIn:weakSelf
                                    title:kLang(@"addr_empty_title")
                                 subtitle:kLang(@"addr_empty_subtitle")
                            confirmButton:kLang(@"addr_empty_btn_add")
                             cancelButton:kLang(@"addr_empty_btn_notnow")
                                     icon:[UIImage systemImageNamed:@"house.circle"]
                             confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
            if (!didConfirm) return;
            [weakSelf pp_goToAddNewAddressScreen];
        } cancelBlock:^{}];
    }];
}
- (void)pp_goToAddNewAddressScreen {
    AddressFormVC *formVC = [[AddressFormVC alloc] initWithAddress:nil];
    [self.navigationController pushViewController:formVC animated:YES];
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
    [self pp_refreshLatestAddressesForCheckout:nil];
}

- (void)pp_handleUserDidSignOutNotification:(NSNotification *)notification
{
    (void)notification;
    [self pp_applyAddresses:@[]];
}

- (void)pp_handlePricingConfigurationDidChangeNotification:(NSNotification *)notification
{
    (void)notification;
    [self pp_refreshCheckoutPricingPresentation];
}

- (void)pp_refreshCheckoutPricingPresentation
{
    PPCartSummary *summary = [PPCartCalculator currentSummary];

    [self.summaryView updateTotalsWithItems:summary.subtotal shipping:summary.shippingFee showTitle:NO];
    [self.summaryView updatePreviewItems:CartManager.sharedManager.cartItems];

    [self pp_applyDefaultSelectionIfNeeded];
    [self.paymentCollection reloadData];
}

- (void)setupPaymentCollection {
    if (self.paymentCollection) return;
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumInteritemSpacing = 0.0;
    layout.minimumLineSpacing = 14.0;
    layout.sectionInset = UIEdgeInsetsMake(12.0, 0.0, 24.0, 0.0);
    layout.estimatedItemSize = CGSizeZero;
    
    self.paymentCollection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.paymentCollection.translatesAutoresizingMaskIntoConstraints = NO;
    self.paymentCollection.delegate = self;
    self.paymentCollection.dataSource = self;
    self.paymentCollection.backgroundColor = UIColor.clearColor;
    self.paymentCollection.alwaysBounceVertical = YES;
    self.paymentCollection.showsVerticalScrollIndicator = NO;
    [self.paymentCollection registerClass:[PPPaymentMethodCell class] forCellWithReuseIdentifier:@"PaymentMethodCell"];
    [self.paymentCollection registerClass:[PPPaymentSectionHeaderView class]
               forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                      withReuseIdentifier:@"PPPaymentSectionHeaderView"];
    [self.paymentCollection registerClass:[UICollectionReusableView class]
               forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                      withReuseIdentifier:@"FooterView"];
    
    
    
    [self.view addSubview:self.paymentCollection];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.paymentCollection.topAnchor constraintEqualToAnchor:self.heroCardView.bottomAnchor constant:18.0],
        [self.paymentCollection.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.paymentCollection.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.paymentCollection.bottomAnchor constraintEqualToAnchor:self.summaryView.topAnchor constant:-10.0]
    ]];
    
    [self.locView attachToScrollView:self.paymentCollection];
}
#pragma mark - Setup Payment Collection

- (void)fetchUserPaymentInstruments {
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    if (uid.length == 0) {
        self.userInstruments = @[];
        [self.paymentCollection reloadData];
        [self pp_refreshCheckoutCallToAction];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self.instrumentManager listenForInstrumentsForUser:uid
                                             completion:^(NSArray<UserPaymentInstrument *> * _Nullable instruments, NSError * _Nullable error) {
        [PPHUD dismiss];
        if (!error) {
            PPORDERLog(@"Payment instruments loaded | count=%lu", (unsigned long)instruments.count);
            weakSelf.userInstruments = instruments ?: @[];
            [weakSelf pp_applyDefaultSelectionIfNeeded];
            [weakSelf.paymentCollection reloadData];
            [weakSelf pp_refreshCheckoutCallToAction];
            [UIView performWithoutAnimation:^{
                
            }];

        } else {
            PPORDERLog(@"Payment instruments failed to load | error=%@", error.localizedDescription ?: @"Unknown");
            [PPHUD showError:kLang(@"payment_load_methods_failed")];
        }
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

    NSString *line1 = [self pp_trimmedAddressString:address.addressLine1];
    NSString *fullName = [self pp_trimmedAddressString:address.fullName];
    NSString *legacyLocation = [self pp_trimmedAddressString:address.locatioName];
    NSString *displayName = [self pp_trimmedAddressString:[address displayName]];
    BOOL hasUsableText = line1.length > 0 || fullName.length > 0 || legacyLocation.length > 0 || displayName.length > 0;
    if (!hasUsableText) return NO;

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

    return nil;
}

- (BOOL)pp_hasAuthenticatedUser
{
    return [FIRAuth auth].currentUser.uid.length > 0;
}

- (void)pp_refreshLatestAddressesForCheckout:(void (^)(NSArray<PPAddressModel *> * _Nullable addresses, NSError * _Nullable error))completion
{
    if (![self pp_hasAuthenticatedUser]) {
        [self pp_applyAddresses:@[]];
        if (completion) {
            completion(@[], nil);
        }
        return;
    }

    [PPADDRESS getAllAddressesWithCompletion:^(NSArray<PPAddressModel *> * _Nonnull addresses, NSError * _Nullable error) {
        if (!error) {
            [self pp_applyAddresses:addresses ?: @[]];
        }
        if (completion) completion(addresses, error);
    }];
}


- (void)finishPayments
{
    PPORDERLog(@"Checkout tapped | items=%lu | inProgress=%d",
               (unsigned long)CartManager.sharedManager.cartItems.count,
               self.isCheckoutInProgress);
    if (![self pp_hasAuthenticatedUser]) {
        [PPAlertHelper showWarningIn:self
                               title:kLang(@"auth_register_required_title")
                            subtitle:kLang(@"auth_register_required_subtitle")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        PPORDERLog(@"Checkout blocked | reason=unauthenticated");
        return;
    }
    if (self.isCheckoutInProgress) {
        [PPHUD showInfo:kLang(@"payment_request_in_progress")];
        PPORDERLog(@"Checkout blocked | reason=already_in_progress");
        return;
    }

    NSString *selectedPaymentMethodID = [self pp_selectedCheckoutPaymentMethodID];
    if (selectedPaymentMethodID.length == 0) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"checkout_failed_title")
                          subtitle:kLang(@"checkout_payment_method_unavailable")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        PPORDERLog(@"Checkout blocked | reason=no_payment_method");
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self pp_refreshLatestAddressesForCheckout:^(NSArray<PPAddressModel *> * _Nullable addresses, NSError * _Nullable addressError) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (addressError) {
                [PPAlertHelper showErrorIn:self
                                     title:kLang(@"checkout_failed_title")
                                  subtitle:addressError.localizedDescription ?: kLang(@"SomethingWentWrong")];
                [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
                PPORDERLog(@"Checkout blocked | reason=address_refresh_failed | error=%@",
                           addressError.localizedDescription ?: @"Unknown");
                return;
            }

            PPAddressModel *resolvedAddress = [self pp_preferredAddressFrom:addresses ?: @[]];
            NSString *selectedID = [self pp_effectiveAddressID:self.selectedAddress];
            if (selectedID.length > 0) {
                for (PPAddressModel *candidate in addresses ?: @[]) {
                    NSString *candidateID = [self pp_effectiveAddressID:candidate];
                    if ([candidateID isEqualToString:selectedID]) {
                        resolvedAddress = candidate;
                        break;
                    }
                }
            }

            NSError *validationError = [self pp_checkoutValidationErrorForAddress:resolvedAddress
                                                                  paymentMethodId:selectedPaymentMethodID];
            if (validationError) {
                NSString *title = validationError.code == 1001
                    ? kLang(@"select_delivery_location_title")
                    : kLang(@"checkout_failed_title");
                [PPAlertHelper showWarningIn:self
                                       title:title
                                    subtitle:validationError.localizedDescription ?: kLang(@"SomethingWentWrong")];
                [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
                PPORDERLog(@"Checkout blocked | reason=preflight_failed | paymentMethod=%@ | error=%@",
                           selectedPaymentMethodID,
                           validationError.localizedDescription ?: @"Unknown");
                return;
            }
            self.selectedAddress = resolvedAddress;
            NSString *resolvedText = [self pp_bestAddressDisplayText:resolvedAddress];
            [self.locView setAddressText:resolvedText.length > 0 ? resolvedText : kLang(@"PleaseSelectDeliveryLocation")];

            if (!self.checkoutCoordinator) {
                self.checkoutCoordinator =
                [[PPCheckoutCoordinator alloc] initWithPresentingViewController:self];
            }

            [self pp_startCheckoutWithPaymentMethodId:selectedPaymentMethodID];
        });
    }];
}

#pragma mark - Checkout Execution & Retry (H-07)

/// Starts the QIB checkout flow.  Called both from the initial checkout tap
/// and from the "Retry Payment" action after a retryable failure or timeout.
/// The coordinator's checkoutIdempotencyKey is preserved across failures,
/// so the backend safely deduplicates order creation on retry.
- (void)pp_startCheckoutWithPaymentMethodId:(NSString *)paymentMethodId
{
    self.isCheckoutInProgress = YES;
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
        NSString *pendingMessage = error.localizedDescription.length > 0
            ? error.localizedDescription
            : kLang(@"checkout_payment_verification_pending");

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

    } else if (result == PPCheckoutResultCancelled) {
        PPORDERLog(@"Payment cancelled by user | orderId=%@", order.orderId ?: @"");
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"payment_cancelled_title")
                         subtitle:kLang(@"payment_cancelled_message")];

    } else {
        // PPCheckoutResultFailed
        NSString *rawReason = error.localizedDescription ?: @"";
        NSString *reason;
        if ([rawReason rangeOfString:@"must be a positive number" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            reason = kLang(@"checkout_item_price_invalid") ?: @"One or more items have an invalid price. Please remove them and try again.";
        } else if (rawReason.length > 0 && [rawReason rangeOfString:@"-" options:0].location != NSNotFound && rawReason.length > 30) {
            // Raw SDK error with UUIDs — show generic user-friendly message
            reason = kLang(@"checkout_generic_error") ?: kLang(@"SomethingWentWrong");
        } else {
            reason = rawReason.length > 0 ? rawReason : kLang(@"SomethingWentWrong");
        }

        // H-07: Offer retry for QIB payment failures (SDK error, verification
        // failure, Firestore-confirmed decline).  Validation errors (out-of-stock,
        // invalid address, etc.) remain non-retryable.
        BOOL isRetryable = [error.userInfo[PPCheckoutErrorIsRetryableKey] boolValue];
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


-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_configureNavigationChrome];
    [[CartManager sharedManager] refreshPricingConfiguration];
    [self.summaryView setCheckoutLoading:self.isCheckoutInProgress];
    [_summaryView pp_startTrustBannerShimmer];
    [self pp_setupInitialAddressState];
    [self pp_refreshCheckoutCallToAction];

}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
  // [_summaryView pp_stopTrustBannerShimmer];
}

- (void)dealloc
{
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

    OrderDetailsViewController *detailsVC = [[OrderDetailsViewController alloc] initWithOrder:order];
    detailsVC.entryPresentationState = presentationState;
    detailsVC.entryPresentationMessage = message ?: @"";
    [self.navigationController pushViewController:detailsVC animated:YES];
}
@end
