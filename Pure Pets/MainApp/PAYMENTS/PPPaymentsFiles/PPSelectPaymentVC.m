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
@property (nonatomic, strong,nullable) UIVisualEffectView *dimOverlay;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) UILabel *collectionHintLabel;
@property (nonatomic, strong) NSArray<PPAddressModel *> *Addresses;
@property (nonatomic, strong) PPAddressModel *selectedAddress;
@property (nonatomic, strong) PPCheckoutCoordinator *checkoutCoordinator;
@property (nonatomic, assign) BOOL isCheckoutInProgress;
@property (nonatomic, strong) id<FIRListenerRegistration> addressesListener;
@property (nonatomic, strong) PPAddressPickerView *locView;;
@end

@implementation PPSelectPaymentVC
- (void)setPaymentFormVC:(PPPaymentFormViewController *)paymentFormVC
{
    PPPaymentFormViewController *paymentFormVCC = [PPPaymentFormViewController new]  ;
    paymentFormVCC.mode = PPPaymentFormModeAdd;
    paymentFormVCC.isEditingExisting = NO;
    [PPFunc presentSheetFrom:paymentFormVC sheetVC:self detentStyle:PPSheetDetentStyleSemiLargAndLarge];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // @property (nonatomic, strong, nullable) PPPaymentFormViewController *paymentFormVC;
    
    self.instrumentManager = [UserPaymentInstrumentManager sharedManager];
    self.availableMethods = [PaymentMethod defaultMethods];
    
    NSLog(@" self.availableMethod %@" , self.availableMethods);
    self.userInstruments = @[];
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    
    self.title = kLang(@"SelectPaymentMethod");
    
    self.instrumentManager = [UserPaymentInstrumentManager sharedManager];
    self.userInstruments = @[];
    
    [self setlocViewViewAtTop];
    [self setSummuryViewAtBottom];
    
    
    [self setupPaymentCollection];
    [self pp_applyDefaultSelectionIfNeeded];
    [self pp_refreshCheckoutCallToAction];
    [self fetchUserPaymentInstruments];
    
    
    [self setupHint];
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
- (void)setSummuryViewAtBottom
{
    self.summaryView = [[BBCheckoutSummaryView alloc] init];
    
    [self.view addSubview:self.summaryView];
    //[self.summaryView.heightAnchor constraintGreaterThanOrEqualToConstant:200].active = YES;
    [self.summaryView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
    [self.summaryView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [self.summaryView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
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
    //[self.summaryView setCardBackgroundImage:PPImage(@"5555")];
    [self.summaryView setCheckoutBTNTitle:kLang(@"payment_pay_now") image:[UIImage pp_symbolNamed:@"creditcard.fill" pointSize:18  //.fill.and.123
                                                                                   weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleLarge palette:@[AppForgroundColr,AppForgroundColr] makeTemplate:NO]];
    
    
    if ([CartManager sharedManager].cartItems.count > 0) {
        [_summaryView pp_startTrustBannerShimmer];
    }
}

- (void)setlocViewViewAtTop
{
    
    UILabel *locationHeaderLabel = [[UILabel alloc]init];
    locationHeaderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    locationHeaderLabel.text = kLang(@"");
    locationHeaderLabel.font = [GM MidFontWithSize:14.0];
    locationHeaderLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.view addSubview:locationHeaderLabel];
    
    [locationHeaderLabel sizeToFit];
    
    self.locView = [PPAddressPickerView showInViewController:self width:self.view.hx_w - 32];
    [self.locView setAddressText:kLang(@"PleaseSelectDeliveryLocation")];
    __weak typeof(self) weakSelf = self;
    self.locView.onPickAddress = ^{
        [weakSelf pp_presentAddressPickerOrPrompt];
    };
    
    [NSLayoutConstraint activateConstraints:@[
        [locationHeaderLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [locationHeaderLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [locationHeaderLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
    ]];
    [self.locView expandAndLock];
    [self pp_setupInitialAddressState];
    
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
    layout.minimumInteritemSpacing = 16;
    layout.minimumLineSpacing = 16;
    layout.sectionInset = UIEdgeInsetsMake(16, 16, 16, 16);
    layout.estimatedItemSize = CGSizeZero;
    
    self.paymentCollection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.paymentCollection.translatesAutoresizingMaskIntoConstraints = NO;
    self.paymentCollection.delegate = self;
    self.paymentCollection.dataSource = self;
    self.paymentCollection.backgroundColor = UIColor.clearColor;
    [self.paymentCollection registerClass:[PPPaymentMethodCell class] forCellWithReuseIdentifier:@"PaymentMethodCell"];
    [self.paymentCollection registerClass:[PPPaymentSectionHeaderView class]
               forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                      withReuseIdentifier:@"PPPaymentSectionHeaderView"];
    [self.paymentCollection registerClass:[UICollectionReusableView class]
               forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                      withReuseIdentifier:@"FooterView"];
    
    
    
    [self.view addSubview:self.paymentCollection];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.paymentCollection.topAnchor constraintEqualToAnchor:self.locView.bottomAnchor constant:16],
        [self.paymentCollection.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.paymentCollection.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.paymentCollection.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-200]
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
    
    PPPaymentFormViewController *paymentFormVCC = [PPPaymentFormViewController new]  ;
    paymentFormVCC.mode = PPPaymentFormModeAdd;
    paymentFormVCC.isEditingExisting = NO;
    //[PPFunc presentSheetFrom:paymentFormVCC sheetVC:self detentStyle:PPSheetDetentStyleSemiLargAndLarge];
    NSLog(@"NavigationController pushViewController paymentFormVCC");
    //[PPFunc presentSheetFrom:self.paymentFormVC sheetVC:self detentStyle:PPSheetDetentStyleSemiLargAndLarge];   //
    [self.navigationController pushViewController:paymentFormVCC animated:YES];
}

- (void)setupHint
{
    self.collectionHintLabel = [[UILabel alloc] init];
        self.collectionHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.collectionHintLabel.font = [GM MidFontWithSize:14];
        self.collectionHintLabel.textColor = UIColor.secondaryLabelColor;
        self.collectionHintLabel.textAlignment = NSTextAlignmentCenter;
        self.collectionHintLabel.numberOfLines = 2;
        /*
         [self.view addSubview:self.collectionHintLabel];
         
         // Layout below your paymentCollection
         [NSLayoutConstraint activateConstraints:@[
             [self.collectionHintLabel.bottomAnchor constraintEqualToAnchor:self.summaryView.topAnchor constant:-8],
             [self.collectionHintLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
             [self.collectionHintLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
             [self.collectionHintLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8]
         ]];
         
         [self updateCollectionHintText];
         */
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

            self.isCheckoutInProgress = YES;
            [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
            [self.summaryView setCheckoutLoading:YES];
            PPORDERLog(@"Checkout starting | paymentMethod=%@ | addressId=%@",
                       selectedPaymentMethodID,
                       [self pp_effectiveAddressID:self.selectedAddress]);
            __weak typeof(self) weakSelf = self;
            [self.checkoutCoordinator startCheckoutWithAddress:self.selectedAddress
                                               paymentMethodId:selectedPaymentMethodID
                                                    completion:^(PPCheckoutResult result,
                                                                 PPOrder *order,
                                                                 NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) return;
                    strongSelf.isCheckoutInProgress = NO;
                    [strongSelf.summaryView setCheckoutLoading:NO];
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
                        [strongSelf pp_openOrderDetailsForOrder:order
                                           successMessage:successMessage
                                        presentationState:PPOrderDetailsEntryPresentationStateCheckoutSuccess];
                    } else if (result == PPCheckoutResultPendingVerification) {
                        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
                        [strongSelf pp_openOrderDetailsForOrder:order
                                           successMessage:(error.localizedDescription.length > 0 ? error.localizedDescription : kLang(@"checkout_payment_verification_pending"))
                                        presentationState:PPOrderDetailsEntryPresentationStateVerificationPending];
                    } else if (result == PPCheckoutResultCancelled) {
                        PPORDERLog(@"Payment cancelled by user | orderId=%@", order.orderId ?: @"");
                        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
                        [PPHUD showInfo:kLang(@"payment_cancelled_by_user")];
                    } else {
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
                        PPORDERLog(@"Checkout failed | rawError=%@", rawReason);
                        [PPAlertHelper showErrorIn:strongSelf title:kLang(@"checkout_failed_title") subtitle:reason];
                        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
                    }
                });
            }];
        });
    }];
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
