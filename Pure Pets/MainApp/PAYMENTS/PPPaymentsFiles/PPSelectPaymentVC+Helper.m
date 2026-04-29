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

#define PPORDERLog(fmt, ...) NSLog((@"[PPORDER] " fmt), ##__VA_ARGS__)

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
        [self pp_refreshCheckoutCallToAction];
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
    [self pp_refreshCheckoutCallToAction];
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

- (UserPaymentInstrument *)pp_resolvedSelectedInstrument
{
    NSArray<UserPaymentInstrument *> *displayed = [self pp_displayedInstruments];
    if (displayed.count == 0) {
        return nil;
    }

    NSString *selectedID = PPCurrentUser.SelectedInstrument.instrumentID ?: @"";
    if (selectedID.length > 0) {
        for (UserPaymentInstrument *instrument in displayed) {
            if ([instrument.instrumentID isEqualToString:selectedID]) {
                return instrument;
            }
        }
    }

    return displayed.firstObject;
}

- (NSString *)pp_selectedCheckoutPaymentMethodID
{
    UserPaymentInstrument *instrument = [self pp_resolvedSelectedInstrument];
    return PPPaymentSelectionNormalizedMethodID(instrument.methodID);
}

- (void)pp_refreshCheckoutCallToAction
{
    NSString *paymentMethodID = [self pp_selectedCheckoutPaymentMethodID];
    BOOL isCash = [paymentMethodID isEqualToString:@"cash"];
    NSString *title = isCash ? kLang(@"payment_place_order") : kLang(@"payment_pay_now");
    NSString *symbolName = isCash ? @"shippingbox.fill" : @"creditcard.fill";
    UIImage *icon = [UIImage pp_symbolNamed:symbolName
                                  pointSize:18
                                     weight:UIImageSymbolWeightSemibold
                                      scale:UIImageSymbolScaleLarge
                                    palette:@[AppForgroundColr, AppForgroundColr]
                               makeTemplate:NO];
    [self.summaryView setCheckoutBTNTitle:title image:icon];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath {
    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        PPPaymentSectionHeaderView *header =
        [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                           withReuseIdentifier:@"PPPaymentSectionHeaderView"
                                                  forIndexPath:indexPath];
        [header configureWithTitle:kLang(@"payment_section_methods_title")
                          subtitle:kLang(@"payment_section_methods_subtitle")
                       actionTitle:nil];
        header.actionHandler = nil;
        return header;
    }
    
    return [UICollectionReusableView new];
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
referenceSizeForFooterInSection:(NSInteger)section {
    (void)collectionViewLayout;
    (void)section;
    return CGSizeZero;
}

#pragma mark - Section Header

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
referenceSizeForHeaderInSection:(NSInteger)section {
    (void)collectionViewLayout;
    (void)section;
    return CGSizeMake(collectionView.bounds.size.width, 78.0);
}

#pragma mark - CollectionView Data Source

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    (void)collectionView;
    (void)section;
    // Temporarily disabled add method
    return [self pp_displayedInstruments].count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPPaymentMethodCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PaymentMethodCell" forIndexPath:indexPath];
    cell.delegate = self;
    NSArray<UserPaymentInstrument *> *displayed = [self pp_displayedInstruments];

    NSInteger modelIndex = indexPath.item;
    if (modelIndex < 0 || modelIndex >= (NSInteger)displayed.count) {
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

    NSInteger modelIndex = indexPath.item;
    if (modelIndex < 0 || modelIndex >= (NSInteger)displayed.count) {
        return;
    }
    UserPaymentInstrument *selected = displayed[modelIndex];
    PPORDERLog(@"Payment method selected | instrumentId=%@ | methodId=%@",
               selected.instrumentID ?: @"",
               selected.methodID ?: @"");
    PPCurrentUser.SelectedInstrument = selected;
    [self pp_updateVisibleSelectionForInstrumentID:selected.instrumentID animated:YES];
    [self pp_refreshCheckoutCallToAction];
}


//self.paymentFormVC

#pragma mark - Layout Delegate

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    (void)collectionViewLayout;
    CGFloat availableWidth = collectionView.bounds.size.width;
    CGFloat spacing = 16.0;
    // 2 columns, account for margins if needed. The collection view might already have section insets.
    // If sectionInset is (12, 0, 24, 0) as seen before, width is full. So we subtract the spacing.
    // But let's check `PPSelectPaymentVC.m` for section inset, wait it has `layout.minimumInteritemSpacing = 0.0`.
    // We should make width = (availableWidth - spacing) / 2.0; and use itemHeight = 120.0
    CGFloat itemWidth = (availableWidth - 32.0 - spacing) / 2.0; // 32 is 16 on each side maybe?
    return CGSizeMake(MAX(0.0, itemWidth), 146.0);
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
    (void)cell;
    if (!instrument || !instrument.instrumentID) {
        [PPHUD showError:kLang(@"UnableToSetDefaultMethod")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];

    if ([self pp_isBuiltInInstrument:instrument]) {
        PPCurrentUser.SelectedInstrument = instrument;
        [self pp_updateVisibleSelectionForInstrumentID:instrument.instrumentID animated:YES];
        [self pp_refreshCheckoutCallToAction];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentSuccess];
        return;
    }
    
    DLog(@"🟢 Setting default payment method: %@ (%@)", method.displayName, instrument.instrumentID);
    
    PPCurrentUser.SelectedInstrument = instrument;
    [self pp_updateVisibleSelectionForInstrumentID:instrument.instrumentID animated:YES];
    [self pp_refreshCheckoutCallToAction];
    
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
                [weakSelf pp_refreshCheckoutCallToAction];
                [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentSuccess];
            } else {
                [PPHUD showError:kLang(@"FailedToUpdateDefault")];
                [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
                DLog(@"❌ Failed to set default: %@", error);
                [weakSelf.paymentCollection reloadData];
                [weakSelf pp_refreshCheckoutCallToAction];
            }
            
        });
    }];
}



-(void)paymentMethodCellDidRequestEdit:(PPPaymentMethodCell *)cell instrument:(UserPaymentInstrument *)instrument method:(PaymentMethod *)method
{
    (void)cell;
    (void)method;
    if ([self pp_isBuiltInInstrument:instrument]) {
        [PPHUD showInfo:kLang(@"payment_builtin_edit_blocked")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    PPPaymentFormViewController *paymentFormVC = [[PPPaymentFormViewController alloc] initForEditingInstrument:instrument];
    paymentFormVC.mode = PPPaymentFormModeEdit;
    paymentFormVC.isEditingExisting = YES;
    paymentFormVC.editingInstrument = instrument;
    self.paymentFormVC = paymentFormVC;
    [self.navigationController pushViewController:paymentFormVC animated:YES];
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
@interface PPPaymentSectionHeaderView ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *actionButton;

@end

@implementation PPPaymentSectionHeaderView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = UIColor.clearColor;

        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.titleLabel.font = [GM boldFontWithSize:20.0];
        self.titleLabel.textColor = UIColor.labelColor;

        self.subtitleLabel = [[UILabel alloc] init];
        self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.subtitleLabel.font = [GM MidFontWithSize:13.0];
        self.subtitleLabel.textColor = UIColor.secondaryLabelColor;
        self.subtitleLabel.numberOfLines = 2;

        self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
        self.actionButton.titleLabel.font = [GM MidFontWithSize:13.0];
        self.actionButton.tintColor = AppPrimaryClr ?: UIColor.systemBlueColor;
        self.actionButton.backgroundColor = [AppPrimaryClr ?: UIColor.systemBlueColor colorWithAlphaComponent:0.10];
        self.actionButton.layer.cornerRadius = 18.0;
        self.actionButton.layer.cornerCurve = kCACornerCurveContinuous;
        self.actionButton.contentEdgeInsets = UIEdgeInsetsMake(9.0, 12.0, 9.0, 12.0);
        [self.actionButton addTarget:self action:@selector(pp_didTapAction) forControlEvents:UIControlEventTouchUpInside];

        [self addSubview:self.titleLabel];
        [self addSubview:self.subtitleLabel];
        [self addSubview:self.actionButton];

        [NSLayoutConstraint activateConstraints:@[
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20.0],
            [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:6.0],
            [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.actionButton.leadingAnchor constant:-12.0],

            [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4.0],
            [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
            [self.subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.actionButton.leadingAnchor constant:-12.0],
            [self.subtitleLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8.0],

            [self.actionButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20.0],
            [self.actionButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.actionButton.heightAnchor constraintGreaterThanOrEqualToConstant:36.0],
        ]];
    }
    return self;
}

- (void)configureWithTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
               actionTitle:(NSString *)actionTitle
{
    self.titleLabel.text = title;
    self.subtitleLabel.text = subtitle;

    BOOL hasAction = actionTitle.length > 0;
    self.actionButton.hidden = !hasAction;
    if (hasAction) {
        UIImage *plusIcon = [UIImage systemImageNamed:@"plus"];
        [self.actionButton setTitle:actionTitle forState:UIControlStateNormal];
        [self.actionButton setImage:plusIcon forState:UIControlStateNormal];
        self.actionButton.imageEdgeInsets = UIEdgeInsetsMake(0.0, 0.0, 0.0, 6.0);
        self.actionButton.accessibilityElementsHidden = NO;
    } else {
        [self.actionButton setTitle:nil forState:UIControlStateNormal];
        [self.actionButton setImage:nil forState:UIControlStateNormal];
        self.actionButton.accessibilityElementsHidden = YES;
    }
}

- (void)pp_didTapAction
{
    if (self.actionHandler) {
        self.actionHandler();
    }
}

@end
