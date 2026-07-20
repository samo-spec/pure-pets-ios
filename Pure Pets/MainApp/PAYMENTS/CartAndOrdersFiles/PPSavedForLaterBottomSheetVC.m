#import "PPSavedForLaterBottomSheetVC.h"
#import "PPSaveForLaterManager.h"
#import "CartManager.h"
#import "PetAccessoryManager.h"
#import "PPHUD.h"
#import <Pure_Pets-Swift.h>

static NSString * const PPSavedForLaterUpdatedNotificationName = @"PPSaveForLaterUpdatedNotification";

@interface PPSavedForLaterBottomSheetVC () <PPSavedForLaterSheetContentControllerDelegate, UIAdaptivePresentationControllerDelegate>
@property (nonatomic, strong) PPSavedForLaterSheetContentController *contentController;
@property (nonatomic, strong) NSArray<CartItem *> *savedItems;
@property (nonatomic, assign) BOOL isDismissingSheet;
@property (nonatomic, assign) BOOL didNotifyDismiss;
@end

@implementation PPSavedForLaterBottomSheetVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationPageSheet;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.clearColor;
    self.view.opaque = NO;
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.view.accessibilityViewIsModal = YES;

    [self pp_embedSwiftUIContent];
    [self pp_observeSavedItems];
    [self pp_loadSavedItemsAnimated:NO];
    [self pp_applyClearSheetChrome];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self pp_applyClearSheetChrome];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.presentationController.delegate = self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Setup

- (void)pp_embedSwiftUIContent
{
    self.contentController = [[PPSavedForLaterSheetContentController alloc] init];
    self.contentController.delegate = self;

    [self addChildViewController:self.contentController];
    self.contentController.view.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentController.view.backgroundColor = UIColor.clearColor;
    self.contentController.view.opaque = NO;
    [self.view addSubview:self.contentController.view];
    [NSLayoutConstraint activateConstraints:@[
        [self.contentController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.contentController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.contentController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.contentController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
     ]];
    [self.contentController didMoveToParentViewController:self];
}

- (void)pp_applyClearSheetChrome
{
    self.view.backgroundColor = UIColor.clearColor;
    self.view.opaque = NO;
    self.view.superview.backgroundColor = UIColor.clearColor;
    self.view.superview.opaque = NO;
    self.contentController.view.backgroundColor = UIColor.clearColor;
    self.contentController.view.opaque = NO;
}

- (void)pp_observeSavedItems
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_savedItemsDidChange:)
                                                 name:PPSavedForLaterUpdatedNotificationName
                                               object:nil];
}

#pragma mark - Data

- (CartItem *)pp_copySavedCartItem:(CartItem *)item
{
    CartItem *copy = [[CartItem alloc] init];
    copy.itemID = item.itemID ?: @"";
    copy.name = item.name ?: @"";
    copy.quantity = MAX(1, item.quantity);
    copy.stockQuantity = item.stockQuantity;
    copy.price = item.price;
    copy.originalPrice = item.originalPrice;
    copy.imageURL = item.imageURL ?: @"";
    copy.providerID = item.providerID ?: @"";
    copy.type = item.type ?: @"";
    return copy;
}

- (CartItem *)pp_cartItemFromSavedItem:(CartItem *)savedItem
                             accessory:(PetAccessory *)accessory
{
    CartItem *resolvedItem = [[CartItem alloc] initWithAccessory:accessory
                                                        quantity:MAX(1, savedItem.quantity)];
    if (savedItem.type.length > 0) {
        resolvedItem.type = savedItem.type;
    }
    return resolvedItem;
}

- (void)pp_resolveCartItemForMoveToCart:(CartItem *)savedItem
                              completion:(void (^)(CartItem * _Nullable resolvedItem,
                                                   BOOL isOutOfStock))completion
{
    if (savedItem.stockQuantity != NSNotFound) {
        if (savedItem.stockQuantity <= 0) {
            completion(nil, YES);
            return;
        }
        if (savedItem.price >= 0.01) {
            completion([self pp_copySavedCartItem:savedItem], NO);
            return;
        }
    }

    PetAccessory *cachedAccessory = [[PetAccessoryManager sharedManager] getAccessoryID:savedItem.itemID];
    if (cachedAccessory) {
        if (cachedAccessory.quantity <= 0) {
            completion(nil, YES);
            return;
        }
        completion([self pp_cartItemFromSavedItem:savedItem accessory:cachedAccessory], NO);
        return;
    }

    [PetAccessoryManager fetchAccessoriesWithIDs:@[savedItem.itemID ?: @""]
                                      completion:^(NSArray<PetAccessory *> *accessories) {
        PetAccessory *freshAccessory = accessories.firstObject;
        if (!freshAccessory) {
            completion(nil, NO);
            return;
        }
        if (freshAccessory.quantity <= 0) {
            completion(nil, YES);
            return;
        }
        completion([self pp_cartItemFromSavedItem:savedItem accessory:freshAccessory], NO);
    }];
}

- (void)pp_savedItemsDidChange:(NSNotification *)notification
{
    (void)notification;
    [self pp_loadSavedItemsAnimated:YES];
}

- (void)pp_loadSavedItemsAnimated:(BOOL)animated
{
    self.savedItems = [[PPSaveForLaterManager sharedManager] savedItems] ?: @[];
    [self.contentController configureWithSavedItems:self.savedItems animated:animated];
}

- (void)pp_finishSavedItemsRefreshAfterMutationFromController:(PPSavedForLaterSheetContentController *)controller
{
    [controller setPendingItemID:nil operation:nil];
    [self pp_loadSavedItemsAnimated:YES];
    if (self.savedItems.count == 0) {
        [self dismissSheet];
    }
}

- (void)pp_deleteSavedItem:(CartItem *)item
                controller:(PPSavedForLaterSheetContentController *)controller
{
    [controller setPendingItemID:item.itemID operation:@"remove"];
    [PPHUD showLoading:kLang(@"saved_for_later_deleting")];

    __weak typeof(self) weakSelf = self;
    [[PPSaveForLaterManager sharedManager] removeItem:item completion:^(NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { return; }

        [PPHUD dismiss];
        if (error) {
            [controller setPendingItemID:nil operation:nil];
            [PPHUD showError:kLang(@"saved_for_later_delete_failed")];
            [controller showStatusMessage:kLang(@"saved_for_later_delete_failed") success:NO];
            [strongSelf pp_loadSavedItemsAnimated:YES];
            return;
        }

        [PPHUD showSuccess:kLang(@"saved_for_later_delete_success")];
        [controller showStatusMessage:kLang(@"saved_for_later_delete_success") success:YES];
        [strongSelf pp_finishSavedItemsRefreshAfterMutationFromController:controller];
    }];
}

#pragma mark - Dismissal

- (void)dismissSheet
{
    if (self.isDismissingSheet) {
        return;
    }
    self.isDismissingSheet = YES;

    [self dismissViewControllerAnimated:YES completion:^{
        [self pp_notifyDismissIfNeeded];
    }];
}

- (void)pp_notifyDismissIfNeeded
{
    if (self.didNotifyDismiss) {
        return;
    }
    self.didNotifyDismiss = YES;
    if (self.onDismiss) {
        self.onDismiss();
    }
}

#pragma mark - UIAdaptivePresentationControllerDelegate

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController
{
    (void)presentationController;
    [self pp_notifyDismissIfNeeded];
}

#pragma mark - PPSavedForLaterSheetContentControllerDelegate

- (void)savedForLaterSheetContentControllerDidRequestDismiss:(PPSavedForLaterSheetContentController *)controller
{
    (void)controller;
    [self dismissSheet];
}

- (void)savedForLaterSheetContentControllerDidRequestRetry:(PPSavedForLaterSheetContentController *)controller
{
    (void)controller;
    [self pp_loadSavedItemsAnimated:YES];
}

- (void)savedForLaterSheetContentController:(PPSavedForLaterSheetContentController *)controller
                       didRequestMoveToCart:(CartItem *)item
{
    if (!item || item.itemID.length == 0) {
        [controller setPendingItemID:nil operation:nil];
        [controller showErrorMessage:kLang(@"SomethingWentWrong")];
        return;
    }

    [controller setPendingItemID:item.itemID operation:@"move"];
    [PPHUD showLoading:kLang(@"moving_to_cart")];

    __weak typeof(self) weakSelf = self;
    [self pp_resolveCartItemForMoveToCart:item
                                completion:^(CartItem * _Nullable resolvedItem,
                                             BOOL isOutOfStock) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { return; }

        if (!resolvedItem) {
            [PPHUD dismiss];
            [controller setPendingItemID:nil operation:nil];
            NSString *message = isOutOfStock ? kLang(@"Out of stock") : kLang(@"SomethingWentWrong");
            [PPHUD showError:message];
            [controller showErrorMessage:message];
            [strongSelf pp_loadSavedItemsAnimated:YES];
            return;
        }

        CartManager *cartManager = [CartManager sharedManager];
        if ([cartManager shouldConfirmProviderSwitchForItem:resolvedItem]) {
            [PPHUD dismiss];
        }

        [cartManager addItem:resolvedItem
         presentingViewController:strongSelf
                      completion:^(BOOL success, BOOL didCancel) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) { return; }

            if (!success) {
                [PPHUD dismiss];
                [controller setPendingItemID:nil operation:nil];
                if (!didCancel) {
                    [PPHUD showError:kLang(@"SomethingWentWrong")];
                    [controller showErrorMessage:kLang(@"SomethingWentWrong")];
                }
                [strongSelf pp_loadSavedItemsAnimated:YES];
                return;
            }

            [controller markMoveSucceededForItemID:item.itemID];
            if (strongSelf.onItemsMovedToCart) {
                strongSelf.onItemsMovedToCart();
            }

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[PPSaveForLaterManager sharedManager] removeItem:item completion:^(NSError * _Nullable error) {
                    [PPHUD dismiss];
                    if (error) {
                        [controller setPendingItemID:nil operation:nil];
                        [PPHUD showError:kLang(@"saved_for_later_move_partial_error")];
                        [controller showStatusMessage:kLang(@"saved_for_later_move_partial_error") success:NO];
                        [strongSelf pp_loadSavedItemsAnimated:YES];
                        return;
                    }

                    [PPHUD showSuccess:kLang(@"moved_to_cart_success")];
                    [controller showStatusMessage:kLang(@"moved_to_cart_success") success:YES];
                    [strongSelf pp_finishSavedItemsRefreshAfterMutationFromController:controller];
                }];
            });
        }];
    }];
}

- (void)savedForLaterSheetContentController:(PPSavedForLaterSheetContentController *)controller
                           didRequestRemove:(CartItem *)item
{
    if (!item || item.itemID.length == 0) {
        [controller setPendingItemID:nil operation:nil];
        [controller showErrorMessage:kLang(@"SomethingWentWrong")];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"saved_for_later_delete_confirm_title")
                             subtitle:kLang(@"saved_for_later_delete_confirm_message")
                        confirmButton:kLang(@"saved_for_later_delete_confirm_action")
                         cancelButton:kLang(@"cancel")
                                 icon:[UIImage systemImageNamed:@"trash"]
                         confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
        (void)text;
        if (!didConfirm) { return; }

        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { return; }
        [strongSelf pp_deleteSavedItem:item controller:controller];
    } cancelBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [controller setPendingItemID:nil operation:nil];
        }
    }];
}

@end
