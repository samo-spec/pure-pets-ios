//
//  PPPaymentSelectionViewController+PPPaymentHelper.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/11/2025.
//

#import "PPSelectPaymentVC+Helper.h"
#import "UserPaymentInstrumentManager.h"
#import "CartManager.h"
#import "PPPaymentMethodCell.h"
#import "PPCommerceFeedbackManager.h"

@interface PPSelectPaymentVC (PPPaymentFlowBridge)
- (void)finishPayments;
@end

static NSString * const kPPBuiltInQIBInstrumentID = @"builtin_qib_gateway";
static NSString * const kPPBuiltInCashInstrumentID = @"builtin_cash_on_delivery";

static NSString *PPPaymentSelectionNormalizedMethodID(NSString *methodID)
{
    NSString *normalized = [[methodID ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].lowercaseString copy];
    if ([normalized isEqualToString:@"cash"] ||
        [normalized isEqualToString:@"cod"] ||
        [normalized isEqualToString:@"cash_on_delivery"]) {
        return @"cash";
    }
    return normalized;
}

@implementation PPSelectPaymentVC (PPPaymentHelper)
#pragma mark - TableView DataSource

- (BOOL)pp_isBuiltInInstrument:(UserPaymentInstrument *)instrument
{
    if (!instrument.instrumentID.length) {
        return NO;
    }
    return [instrument.instrumentID hasPrefix:@"builtin_"];
}

- (UserPaymentInstrument *)pp_makeBuiltInInstrumentWithID:(NSString *)instrumentID
                                                    method:(PaymentMethod *)method
                                                  subtitle:(NSString *)subtitle
{
    UserPaymentInstrument *instrument = [UserPaymentInstrument new];
    instrument.instrumentID = instrumentID;
    instrument.userID = PPCurrentUser.ID ?: @"";
    instrument.methodID = method.methodID ?: @"";
    instrument.method = method;
    instrument.maskedDetails = subtitle ?: @"";
    instrument.metaData = @{};
    instrument.originalData = @{};
    return instrument;
}

- (NSArray<UserPaymentInstrument *> *)pp_displayedInstruments
{
    PaymentMethod *qibMethod = [self methodForID:@"qib"] ?: [self methodForID:@"card"];
    PaymentMethod *cashMethod = [self methodForID:@"cash"];

    NSMutableArray<UserPaymentInstrument *> *result = [NSMutableArray array];
    if (qibMethod && [CartManager sharedManager].onlinePaymentEnabled) {
        NSString *qibSubtitle = qibMethod.methodDescription.length > 0
        ? qibMethod.methodDescription
        : kLang(@"payment_qib_gateway_desc");
        [result addObject:[self pp_makeBuiltInInstrumentWithID:kPPBuiltInQIBInstrumentID
                                                        method:qibMethod
                                                      subtitle:qibSubtitle]];
    }
    if (cashMethod && [CartManager sharedManager].cashOnDeliveryEnabled) {
        NSString *cashSubtitle = cashMethod.methodDescription.length > 0
        ? cashMethod.methodDescription
        : kLang(@"payment_cash_delivery_desc");
        [result addObject:[self pp_makeBuiltInInstrumentWithID:kPPBuiltInCashInstrumentID
                                                        method:cashMethod
                                                      subtitle:cashSubtitle]];
    }

    for (UserPaymentInstrument *instrument in self.userInstruments) {
        if (!instrument.instrumentID.length) { continue; }
        if ([self pp_isBuiltInInstrument:instrument]) { continue; }
        NSString *normalizedMethodID = PPPaymentSelectionNormalizedMethodID(instrument.methodID);
        BOOL isCashInstrument = [normalizedMethodID isEqualToString:@"cash"];
        if (isCashInstrument && ![CartManager sharedManager].cashOnDeliveryEnabled) {
            continue;
        }
        if (!isCashInstrument && ![CartManager sharedManager].onlinePaymentEnabled) {
            continue;
        }
        [result addObject:instrument];
    }
    return result;
}

- (void)pp_applyDefaultSelectionIfNeeded
{
    NSArray<UserPaymentInstrument *> *displayed = [self pp_displayedInstruments];
    if (displayed.count == 0) {
        PPCurrentUser.SelectedInstrument = nil;
        return;
    }

    NSString *selectedID = PPCurrentUser.SelectedInstrument.instrumentID;
    UserPaymentInstrument *resolved = nil;
    if (selectedID.length > 0) {
        for (UserPaymentInstrument *instrument in displayed) {
            if ([instrument.instrumentID isEqualToString:selectedID]) {
                resolved = instrument;
                break;
            }
        }
    }

    if (!resolved) {
        for (UserPaymentInstrument *instrument in displayed) {
            if (instrument.isDefault) {
                resolved = instrument;
                break;
            }
        }
    }

    if (!resolved) {
        resolved = displayed.firstObject; // Default to built-in QIB
    }

    PPCurrentUser.SelectedInstrument = resolved;
}

- (void)pp_updateVisibleSelectionForInstrumentID:(NSString *)instrumentID animated:(BOOL)animated
{
    NSString *selectedID = instrumentID ?: @"";
    for (PPPaymentMethodCell *visibleCell in self.paymentCollection.visibleCells) {
        if (![visibleCell isKindOfClass:[PPPaymentMethodCell class]]) {
            continue;
        }

        // Add-new tile has no instrument binding.
        if (!visibleCell.instrument.instrumentID.length) {
            [visibleCell updateSelectionState:NO animated:NO];
            continue;
        }

        BOOL isCurrent =
        (selectedID.length > 0 &&
         [visibleCell.instrument.instrumentID isEqualToString:selectedID]);
        [visibleCell updateSelectionState:isCurrent animated:animated];
    }
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath {
    
    if (kind == UICollectionElementKindSectionFooter) {
        UICollectionReusableView *footer = [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                                              withReuseIdentifier:@"FooterView"
                                                                                     forIndexPath:indexPath];
        for (UIView *v in footer.subviews) [v removeFromSuperview];
        
        UILabel *label = [[UILabel alloc] init];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.font = [GM MidFontWithSize:14];
        label.textColor = UIColor.secondaryLabelColor;
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 2;
        label.text = (self.userInstruments.count == 0)
        ? kLang(@"PaymentHintAddNew")
        : kLang(@"PaymentHintMoreOptions");
        
        [footer addSubview:label];
        [NSLayoutConstraint activateConstraints:@[
            [label.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:18],
            [label.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor constant:-18],
            [label.topAnchor constraintEqualToAnchor:footer.topAnchor constant:4],
            [label.bottomAnchor constraintEqualToAnchor:footer.bottomAnchor constant:-4],
        ]];
        
        if (@available(iOS 18.0, *)) {
            label.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.8];
            label.layer.cornerRadius = 12;
            label.layer.masksToBounds = YES;
            
            
        }
        
        
        return footer;
    }
    
    if (kind == UICollectionElementKindSectionHeader) {
        PPPaymentSectionHeaderView *header =
        [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                           withReuseIdentifier:@"PPPaymentSectionHeaderView"
                                                  forIndexPath:indexPath];
        
        [header configureWithTitle:kLang(@"payment_header_pay_through")];
        return header;
    }
    
    return [UICollectionReusableView new];
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
referenceSizeForFooterInSection:(NSInteger)section {
    return CGSizeMake(collectionView.bounds.size.width, 40);
}

#pragma mark - Section Header

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
referenceSizeForHeaderInSection:(NSInteger)section {
    return CGSizeMake(collectionView.bounds.size.width, 44);
}

#pragma mark - CollectionView Data Source

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    // TEMPORARILY HIDDEN: "Add New Payment Method" cell
    // Was: ...count + 1;
    return [self pp_displayedInstruments].count; // TEMP: was count + 1
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPPaymentMethodCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PaymentMethodCell" forIndexPath:indexPath];
    cell.delegate = self;
    NSArray<UserPaymentInstrument *> *displayed = [self pp_displayedInstruments];

    // TEMPORARILY HIDDEN: "Add New" cell branch removed (was at addNewIndex = displayed.count)

    NSInteger modelIndex = indexPath.item;
    if (modelIndex < 0 || modelIndex >= (NSInteger)displayed.count) {
        [cell configureAsAddNewIndexPath:indexPath];
        [cell updateSelectionState:NO animated:NO];
        return cell;
    }
    UserPaymentInstrument *instrument = displayed[modelIndex];
    PaymentMethod *method = [self methodForID:instrument.methodID];
    if (!method && [self pp_isBuiltInInstrument:instrument]) {
        method = [instrument.instrumentID isEqualToString:kPPBuiltInCashInstrumentID]
        ? [self methodForID:@"cash"]
        : ([self methodForID:@"qib"] ?: [self methodForID:@"card"]);
    }
    if (!method) {
        method = [self methodForID:@"card"] ?: self.availableMethods.firstObject;
    }
    if (!method) {
        [cell configureAsAddNewIndexPath:indexPath];
        [cell updateSelectionState:NO animated:NO];
        return cell;
    }
    [cell configureWithInstrument:instrument method:method indexPath:indexPath];

    NSString *selectedID = PPCurrentUser.SelectedInstrument.instrumentID;
    BOOL isSelected =
    (selectedID.length > 0)
    ? [instrument.instrumentID isEqualToString:selectedID]
    : instrument.isDefault;
    [cell updateSelectionState:isSelected animated:NO];
    
    return cell;
}

#pragma mark - Helper Methods

- (PaymentMethod *)methodForID:(NSString *)methodID {
    for (PaymentMethod *m in self.availableMethods) {
        if ([m.methodID isEqualToString:methodID]) return m;
    }
    return nil;
}

#pragma mark - CollectionView Delegate
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<UserPaymentInstrument *> *displayed = [self pp_displayedInstruments];

    // TEMPORARILY HIDDEN: "Add New" tap handler
    // Was: if (indexPath.item == addNewIndex) { [self showPaymentSheetFull:YES]; }

    NSInteger modelIndex = indexPath.item;
    if (modelIndex < 0 || modelIndex >= (NSInteger)displayed.count) {
        return;
    }
    UserPaymentInstrument *selected = displayed[modelIndex];
    NSLog(@"✅ Selected instrument: %@", selected.displaySummary);
    PPCurrentUser.SelectedInstrument = selected;
    [self pp_updateVisibleSelectionForInstrumentID:selected.instrumentID animated:YES];
}


//self.paymentFormVC

#pragma mark - Layout Delegate

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    (void)collectionViewLayout;
    CGFloat totalPadding = 16 * 3; // 16 left + 16 right + 16 between columns
    CGFloat availableWidth = collectionView.bounds.size.width - totalPadding;
    CGFloat itemWidth = availableWidth / 2.0;
    return CGSizeMake(MAX(0.0, itemWidth), 110.0);
}




-(void)paymentMethodCellDidRequestDelete:(PPPaymentMethodCell *)cell instrument:(nonnull UserPaymentInstrument *)instrument method:(nonnull PaymentMethod *)method
{
    if ([self pp_isBuiltInInstrument:instrument]) {
        [PPHUD showInfo:kLang(@"payment_builtin_remove_blocked")];
        return;
    }

    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"DeletePaymentMethodTitle")
                             subtitle:kLang(@"DeletePaymentMethodSubtitle")

                        confirmButton:kLang(@"ConfirmDeleteButton")
                         cancelButton:kLang(@"CancelButton")
                                 icon:nil
                         confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
        if(!didConfirm) return;
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
        // ✅ User confirmed deletion
        [self.instrumentManager deleteInstrument:instrument
                                         forUser:PPCurrentUser.ID
                                      completion:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                [PPHUD showSuccess:kLang(@"PaymentMethodDeletedSuccess")];
                [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentSuccess];
                [self fetchUserPaymentInstruments];
            } else {
                [PPHUD showError:kLang(@"PaymentMethodDeletedFailed")];
                [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
            }
        }];
    } cancelBlock:^{
        // ❌ User canceled
        // [GM triggerHapticFeedbackLight];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    }];
    
    
}

- (void)paymentMethodCellDidRequestDefault:(PPPaymentMethodCell *)cell
                                instrument:(UserPaymentInstrument *)instrument
                                    method:(PaymentMethod *)method
{
    if (!instrument || !instrument.instrumentID) {
        [PPHUD showError:kLang(@"UnableToSetDefaultMethod")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];

    if ([self pp_isBuiltInInstrument:instrument]) {
        PPCurrentUser.SelectedInstrument = instrument;
        [self pp_updateVisibleSelectionForInstrumentID:instrument.instrumentID animated:YES];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentSuccess];
        return;
    }
    
    DLog(@"🟢 Setting default payment method: %@ (%@)", method.displayName, instrument.instrumentID);
    
    PPCurrentUser.SelectedInstrument = instrument;
    [self pp_updateVisibleSelectionForInstrumentID:instrument.instrumentID animated:YES];
    
    __weak typeof(self) weakSelf = self;
    [[UserPaymentInstrumentManager sharedManager] setDefaultInstrument:instrument
                                                               forUser:PPCurrentUser.ID
                                                            completion:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                for (UserPaymentInstrument *model in weakSelf.userInstruments) {
                    model.isDefault = [model.instrumentID isEqualToString:instrument.instrumentID];
                }
                [weakSelf pp_updateVisibleSelectionForInstrumentID:instrument.instrumentID animated:NO];
                [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentSuccess];
            } else {
                [PPHUD showError:kLang(@"FailedToUpdateDefault")];
                [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
                DLog(@"❌ Failed to set default: %@", error);
                [weakSelf.paymentCollection reloadData];
            }
            
        });
    }];
}



-(void)paymentMethodCellDidRequestEdit:(PPPaymentMethodCell *)cell instrument:(UserPaymentInstrument *)instrument method:(PaymentMethod *)method
{
    if ([self pp_isBuiltInInstrument:instrument]) {
        [PPHUD showInfo:kLang(@"payment_builtin_edit_blocked")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    //self.paymentFormVC = [[PPPaymentFormViewController alloc] initForEditingInstrument:instrument];
    //self.paymentFormVC.mode = PPPaymentFormModeEdit;
    //self.paymentFormVC.isEditingExisting = YES;
    //self.paymentFormVC.editingInstrument = instrument;
    [self showPaymentSheetFull:YES];
}


























#pragma mark - Public Interface

/// Presents the bottom confirmation sheet when user selects a payment option
- (void)pp_showPaymentConfirmationForMethod:(NSString *)methodName {
    NSLog(@"💳 [PPPaymentHelper] Preparing confirmation for payment method: %@", methodName);
    
    PPBottomAlertSheet *sheet = [PPBottomAlertSheet new];
    sheet.sheetTitle = kLang(@"payment_confirm_title");
    sheet.message = [NSString stringWithFormat:kLang(@"payment_confirm_message_format"), methodName ?: @""];
    
    __weak typeof(self) weakSelf = self;
    sheet.onConfirm = ^{
        __strong typeof(weakSelf) self = weakSelf;
        [self pp_processPaymentForMethod:methodName];
    };
    sheet.onCancel = ^{
        NSLog(@"❌ [PPPaymentHelper] Payment cancelled for %@", methodName);
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    };
    
    [sheet presentIn:self];
}

/// Handles payment process by delegating to the real checkout pipeline.
- (void)pp_processPaymentForMethod:(NSString *)methodName {
    NSLog(@"🚀 [PPPaymentHelper] Starting real payment process for %@", methodName);
    [self finishPayments];
}

/// Displays success confirmation alert
- (void)pp_showPaymentSuccessForMethod:(NSString *)methodName {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"payment_success_title")
                                                                   message:[NSString stringWithFormat:kLang(@"payment_success_message_format"), methodName ?: @""]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:kLang(@"OK")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"[PPPaymentHelper] Dismissed success alert");
    }];
    
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Example Integration with PPPaymentTabBar
/// Called when user selects a tab in PPPaymentTabBar
- (void)pp_handleTabSelection:(PPPaymentTab)tab {
    NSString *methodName = @"";
    switch (tab) {
        case PPPaymentTabCard:
            methodName = kLang(@"payment_method_name_card");
            break;
            
        case PPPaymentTabOoredooMoney:
            methodName = kLang(@"payment_method_name_ooredoo");
            break;
            
        case PPPaymentTabPayPal:
            methodName = kLang(@"payment_method_name_paypal");
            break;
            
        case PPPaymentTabFawry:
            methodName = kLang(@"payment_method_name_fawry");
            break;
            
        case PPPaymentTabQNB:
            methodName = kLang(@"payment_method_name_qnb");
            break;
            
        case PPPaymentTabCash:
            methodName = kLang(@"payment_method_name_cash");
            break;
            
        default:
            methodName = kLang(@"payment_method_name_unknown");
            break;
    }
    
    NSLog(@"💰 [PPPaymentHelper] User selected payment method: %@", methodName);
    
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [self pp_showPaymentConfirmationForMethod:methodName];
}




#pragma mark - Data
/*
 
 typedef NS_ENUM(NSInteger, PaymentMethodType) {
 PaymentMethodTypeCard = 0,
 PaymentMethodTypeOoredoo,
 PaymentMethodTypeQNB,
 PaymentMethodTypeApplePay,
 paymentMethodTypeFawryQatar,
 PaymentMethodTypeCash
 };
 
 PaymentMethod *paymentMethodTypeCard = [self method:@"Pay" icon:@"logo" color:UIColor.blackColor];
 PaymentMethod *paymentMethodTypeOoredoo = [self method:@"Pay" icon:@"logo" color:UIColor.blackColor];
 PaymentMethod *paymentMethodTypeQNB = [self method:@"Pay" icon:@"logo" color:UIColor.blackColor];
 PaymentMethod *paymentMethodTypeApplePay = [self method:@"Pay" icon:@"logo" color:UIColor.blackColor];
 PaymentMethod *paymentMethodTypeFawryQatar= [self method:@"Pay" icon:@"logo" color:UIColor.blackColor];
 PaymentMethod *paymentMethodTypeCash = [self method:@"Pay" icon:@"logo" color:UIColor.blackColor];
 
 */

- (PaymentMethod *)method:(NSString *)title icon:(NSString *)icon color:(UIColor *)color {
    PaymentMethod *m = [PaymentMethod new];
    m.displayName = title;
    m.methodDescription = kLang(@"payment_method_tap_to_choose");
    m.iconName = icon;
    m.tintColor = color;
    return m;
}


#pragma mark - Update Payment Sheet Height
-(void)updatePaymentHeight:(CGFloat)newHeight animated:(BOOL)animated
{
    //[self updatePaymentSheetHeight:newHeight animated:animated];
}


- (void)expandToLargeDetent:(BOOL)animated {
    
    NSLog(@"- (void)expandToLargeDetent:(BOOL)animated ");
    
    if (@available(iOS 17.0, *)) {
        UIViewController *vc = self.presentedViewController;
        UISheetPresentationController *sheet = vc.sheetPresentationController;
        
        CGFloat newHeight = self.view.hx_h * 0.9;
        
        UISheetPresentationControllerDetent *newDetent =
        [UISheetPresentationControllerDetent customDetentWithIdentifier:@"dynamic"
                                                               resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext>  _Nonnull context) {
            return newHeight;
        }];
        
        [sheet animateChanges:^{
            sheet.detents = @[newDetent];
            sheet.selectedDetentIdentifier = @"dynamic";
        }];
    }
    
    else
    {
        [UIView animateWithDuration:0.35
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            self.paymentFormVC.sheetPresentationController.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
            [self.paymentFormVC.view layoutIfNeeded];
        } completion:nil];
    }
    
}
 
#pragma mark - UISheetPresentationControllerDelegate
- (void)presentationController:(UIPresentationController *)presentationController
didChangeSelectedDetentIdentifier:(UISheetPresentationControllerDetentIdentifier)selectedDetentIdentifier {
    // 🎚 Fade overlay depending on sheet position
   
}





- (void)toggleEditing {
    
}

#pragma mark - UI Setup
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    UIButton *backBTN = [PPButtonHelper pp_buttonWithTitleForBar:nil imageName:PPChevronName target:self action:@selector(onBack:)];
    UIBarButtonItem *backBarButton = [[UIBarButtonItem alloc] initWithCustomView:backBTN];
    self.navigationItem.leftBarButtonItem = backBarButton;
    
    self.navigationItem.rightBarButtonItems = @[
        // [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showAddPayments)],
        // [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(toggleEditing)]
    ];
    
    
}


#pragma mark - Action

- (void)onSelectPayment:(UIButton *)sender {
    PaymentMethod *method = self.availableMethods[sender.tag];
    NSLog(@"💳 Selected Payment Method: %@", method.displayName);
    
    // Optional selection animation
    [UIView animateWithDuration:0.2 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.25 animations:^{
            sender.transform = CGAffineTransformIdentity;
        }];
    }];
}





@end






/*
 
 PPPaymentTabBar *tabBar = [[PPPaymentTabBar alloc] init];
 [self.view addSubview:tabBar];
 
 [NSLayoutConstraint activateConstraints:@[
 [tabBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
 [tabBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
 [tabBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
 [tabBar.heightAnchor constraintEqualToConstant:90]
 ]];
 
 tabBar.onSelect = ^(PPPaymentTab selectedTab) {
 switch (selectedTab) {
 case PPPaymentTabCard:
 NSLog(@"💳 Card selected");
 break;
 case PPPaymentTabOoredooMoney:
 NSLog(@"💰 Ooredoo Money selected");
 break;
 case PPPaymentTabPayPal:
 NSLog(@"🅿️ PayPal selected");
 break;
 }
 };
 */

/*
 
 PPPaymentTabBar *tabBar = [[PPPaymentTabBar alloc] init];
 [self.view addSubview:tabBar];
 
 [NSLayoutConstraint activateConstraints:@[
 [tabBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
 [tabBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
 [tabBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
 [tabBar.heightAnchor constraintEqualToConstant:90]
 ]];
 
 tabBar.onSelect = ^(PPPaymentTab selectedTab) {
 switch (selectedTab) {
 case PPPaymentTabCard:
 NSLog(@"💳 Card selected");
 break;
 case PPPaymentTabOoredooMoney:
 NSLog(@"💰 Ooredoo Money selected");
 break;
 case PPPaymentTabPayPal:
 NSLog(@"🅿️ PayPal selected");
 break;
 }
 };
 */





@implementation PPPaymentSectionHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = UIColor.clearColor;
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [GM boldFontWithSize:18];
        _titleLabel.textColor = UIColor.labelColor;
        _titleLabel.numberOfLines = 2;
        
        [self addSubview:_titleLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:22],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-22],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
        ]];
    }
    return self;
}

- (void)configureWithTitle:(NSString *)title {
    _titleLabel.text = title;
}
@end
