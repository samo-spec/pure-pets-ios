#import "PPSavedForLaterBottomSheetVC.h"
#import "PPSaveForLaterManager.h"
#import "CartManager.h"
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

    CartManager *cartManager = [CartManager sharedManager];
    BOOL requiresProviderSwitch = [cartManager shouldConfirmProviderSwitchForItem:item];
    if (!requiresProviderSwitch) {
        [PPHUD showLoading:kLang(@"moving_to_cart")];
    } else {
        [PPHUD dismiss];
    }

    __weak typeof(self) weakSelf = self;
    [cartManager addItem:item
     presentingViewController:self
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

        [[PPSaveForLaterManager sharedManager] removeItem:item];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.24 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [PPHUD showSuccess:kLang(@"moved_to_cart_success")];
            [controller setPendingItemID:nil operation:nil];
            [controller showStatusMessage:kLang(@"moved_to_cart_success") success:YES];
            [strongSelf pp_loadSavedItemsAnimated:YES];
            if (strongSelf.onItemsMovedToCart) {
                strongSelf.onItemsMovedToCart();
            }
            if (strongSelf.savedItems.count == 0) {
                [strongSelf dismissSheet];
            }
        });
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

    [controller setPendingItemID:item.itemID operation:@"remove"];
    [[PPSaveForLaterManager sharedManager] removeItem:item];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [controller setPendingItemID:nil operation:nil];
        [self pp_loadSavedItemsAnimated:YES];
        if (self.savedItems.count == 0) {
            [self dismissSheet];
        }
    });
}

@end
