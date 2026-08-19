//
//  PPOrderDetailsMissionControlBridge.m
//  Pure Pets
//


#import "PPOrderDetailsMissionControlBridge.h"

#import "PPOrderManager.h"
#import "PPFulfillmentOrder.h"
#import "PPOrderStatusAppearance.h"
#import "PPAddressesManager.h"
#import "PPAddressModel.h"
#import "AddressFormVC.h"
#import "PetAccessoryManager.h"
#import "PetAccessory.h"
#import "AccessViewerVC.h"
#import "UserManager.h"
#import "ChManager.h"
#import "CartManager.h"
#import "CountryModel.h"

#import <float.h>
#import <math.h>
#import <CoreFoundation/CoreFoundation.h>

@import FirebaseAuth;
@import FirebaseFirestore;

static NSString * const PPMissionBridgeErrorDomain = @"com.purepets.order-mission-control";
static NSString * const PPMissionSupportPhoneNumber = @"+97459997720";
static NSTimeInterval const PPMissionAuthorityTimeout = 15.0;

static NSString *PPMissionSafeString(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [[value stringValue] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    return @"";
}

static NSString *PPMissionNormalizedKey(id value)
{
    NSString *key = PPMissionSafeString(value).lowercaseString;
    key = [key stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    key = [key stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    while ([key containsString:@"__"]) {
        key = [key stringByReplacingOccurrencesOfString:@"__" withString:@"_"];
    }
    return key;
}

static BOOL PPMissionMatches(NSString *key, NSArray<NSString *> *tokens)
{
    NSString *normalized = PPMissionNormalizedKey(key);
    if (normalized.length == 0) return NO;
    NSString *wrapped = [NSString stringWithFormat:@"_%@_", normalized];
    for (NSString *tokenValue in tokens ?: @[]) {
        NSString *token = PPMissionNormalizedKey(tokenValue);
        if (token.length == 0) continue;
        if ([normalized isEqualToString:token]) return YES;
        if ([wrapped containsString:[NSString stringWithFormat:@"_%@_", token]]) return YES;
        if ([token containsString:@"_"] && [normalized containsString:token]) return YES;
    }
    return NO;
}

static NSString *PPMissionRequestStatusTitleIfKnown(id value)
{
    NSString *status = PPMissionNormalizedKey(value);
    if (![@[
        @"pending_review", @"approved", @"rejected", @"completed",
        @"refunded", @"partially_refunded", @"pending_settlement",
        @"settlement_retryable", @"settlement_failed", @"cancelled",
        @"closed"
    ] containsObject:status]) {
        return @"";
    }
    return [PPOrderManager displayTitleForRequestStatus:status] ?: @"";
}

static NSString *PPMissionRequestActionTitle(id value)
{
    NSString *action = PPMissionNormalizedKey(value);
    NSDictionary<NSString *, NSString *> *statusByAction = @{
        @"approve": @"approved",
        @"reject": @"rejected",
        @"complete": @"completed",
        @"refund": @"pending_settlement",
        @"partial_refund": @"pending_settlement",
        @"close": @"closed"
    };
    return PPMissionRequestStatusTitleIfKnown(statusByAction[action]);
}

static NSString *PPMissionRequestMetadataSummary(NSDictionary *metadata,
                                                 NSString *fallbackStatus)
{
    NSDictionary *safeMetadata = [metadata isKindOfClass:NSDictionary.class]
        ? metadata : @{};
    for (NSString *key in @[@"note", @"summary", @"notes", @"message"]) {
        NSString *value = PPMissionSafeString(safeMetadata[key]);
        if (value.length > 0) return value;
    }
    NSString *metadataStatusTitle =
        PPMissionRequestStatusTitleIfKnown(safeMetadata[@"status"]);
    if (metadataStatusTitle.length > 0) return metadataStatusTitle;
    NSString *fallbackTitle =
        PPMissionRequestStatusTitleIfKnown(fallbackStatus);
    if (fallbackTitle.length > 0) return fallbackTitle;
    return PPMissionRequestActionTitle(safeMetadata[@"action"]);
}

static double PPMissionDouble(id value, double fallback)
{
    return [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : fallback;
}

static NSInteger PPMissionInteger(id value, NSInteger fallback)
{
    return [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : fallback;
}

static BOOL PPMissionIsPositiveIntegerNumber(id value)
{
    if (![value isKindOfClass:NSNumber.class]) return NO;
    CFTypeRef reference = (__bridge CFTypeRef)value;
    if (CFGetTypeID(reference) == CFBooleanGetTypeID()) return NO;
    double number = [value doubleValue];
    return isfinite(number) && number > 0.0 && floor(number) == number;
}

static NSError *PPMissionError(NSInteger code, NSString *message)
{
    return [NSError errorWithDomain:PPMissionBridgeErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message.length > 0 ? message : kLang(@"SomethingWentWrong")}];
}

static void PPMissionOnMain(dispatch_block_t block)
{
    if (!block) return;
    if (NSThread.isMainThread) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

static NSString *PPMissionDateText(NSDate *date)
{
    if (![date isKindOfClass:NSDate.class]) return @"—";
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:
        [Language isRTL] ? @"ar_QA" : @"en_QA"];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [formatter stringFromDate:date] ?: @"—";
}

static NSString *PPMissionMoneyText(double value, NSString *currency)
{
    NSString *resolvedCurrency = PPMissionSafeString(currency);
    if (resolvedCurrency.length == 0) resolvedCurrency = @"QAR";
    NSNumberFormatter *formatter = [NSNumberFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:
        [Language isRTL] ? @"ar_QA" : @"en_QA"];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 2;
    NSString *number = [formatter stringFromNumber:@(MAX(0.0, value))] ?: @"0.00";
    return [NSString stringWithFormat:@"%@ %@", number, resolvedCurrency];
}

static NSString *PPMissionOrderStatusTitle(NSString *statusKey)
{
    NSString *key = PPMissionNormalizedKey(statusKey);
    if ([key isEqualToString:@"pending"]) return kLang(@"order_placed_title");
    if ([key isEqualToString:@"ready_for_delivery"]) return kLang(@"Ready for Delivery");
    if ([key isEqualToString:@"delivery_partner_assigned"]) return kLang(@"Delivery Partner Assigned");
    if ([key isEqualToString:@"on_the_way"]) return kLang(@"On the Way");
    if ([key isEqualToString:@"delivered"]) return kLang(@"Delivered");
    if ([key isEqualToString:@"completed"]) return kLang(@"Completed");
    if ([key isEqualToString:@"delivery_cancelled"]) return kLang(@"Delivery Cancelled");
    if ([key isEqualToString:@"delivery_failed"]) return kLang(@"Delivery Failed");
    if ([key isEqualToString:@"returned_to_store"]) return kLang(@"Returned to Store");
    if ([key isEqualToString:@"delivery_delayed"]) return kLang(@"Delivery Delayed");
    return kLang(@"Preparing for Shipment");
}

static NSString *PPMissionOrderStatusHint(NSString *statusKey)
{
    NSString *key = PPMissionNormalizedKey(statusKey);
    if ([key isEqualToString:@"pending"]) return kLang(@"order_delivery_hint_waiting_acceptance");
    if ([key isEqualToString:@"ready_for_delivery"]) return kLang(@"order_delivery_hint_ready");
    if ([key isEqualToString:@"delivery_partner_assigned"]) return kLang(@"order_delivery_hint_assigned");
    if ([key isEqualToString:@"on_the_way"]) return kLang(@"order_delivery_hint_on_the_way");
    if ([key isEqualToString:@"delivered"]) return kLang(@"order_delivery_hint_delivered");
    if ([key isEqualToString:@"completed"]) return kLang(@"order_delivery_hint_completed");
    if ([key isEqualToString:@"delivery_cancelled"]) return kLang(@"order_delivery_hint_cancelled");
    if ([key isEqualToString:@"delivery_failed"]) return kLang(@"order_delivery_hint_failed");
    if ([key isEqualToString:@"returned_to_store"]) return kLang(@"order_delivery_hint_returned");
    if ([key isEqualToString:@"delivery_delayed"]) return kLang(@"order_delivery_hint_delayed");
    return kLang(@"order_delivery_hint_preparing");
}

static NSString *PPMissionStatusSymbol(NSString *statusKey)
{
    switch (PPOrderStatusVisualPhaseForKey(statusKey)) {
        case PPOrderStatusVisualPhasePlaced: return @"checkmark.seal";
        case PPOrderStatusVisualPhasePaymentConfirmed: return @"creditcard.fill";
        case PPOrderStatusVisualPhasePreparing: return @"shippingbox.fill";
        case PPOrderStatusVisualPhaseReady: return @"package.fill";
        case PPOrderStatusVisualPhaseAssigned: return @"person.crop.circle.badge.checkmark";
        case PPOrderStatusVisualPhaseInTransit: return @"location.fill";
        case PPOrderStatusVisualPhaseDelivered: return @"house.fill";
        case PPOrderStatusVisualPhaseCompleted: return @"checkmark.circle.fill";
        case PPOrderStatusVisualPhaseCancelled: return @"xmark.circle.fill";
        case PPOrderStatusVisualPhaseDelayed: return @"exclamationmark.triangle.fill";
        case PPOrderStatusVisualPhaseReturned: return @"arrow.uturn.backward.circle.fill";
        case PPOrderStatusVisualPhaseNeutral: return @"clock.fill";
    }
    return @"clock.fill";
}

static double PPMissionStatusProgress(NSString *statusKey)
{
    NSString *key = PPMissionNormalizedKey(statusKey);
    NSArray<NSString *> *steps = @[
        @"pending", @"preparing_for_shipment", @"ready_for_delivery",
        @"delivery_partner_assigned", @"on_the_way", @"delivered", @"completed"
    ];
    NSUInteger index = [steps indexOfObject:key];
    if (index == NSNotFound) {
        if (PPMissionMatches(key, @[@"delivery_cancelled", @"delivery_failed", @"returned_to_store"])) return 0.08;
        return 0.24;
    }
    return (double)(index + 1) / (double)steps.count;
}

static NSString *PPMissionFulfillmentStatusTitle(NSString *status)
{
    NSString *key = PPMissionNormalizedKey(status);
    NSDictionary<NSString *, NSString *> *keys = @{
        @"new_request": @"fulfillment_status_new_request",
        @"accepted": @"fulfillment_status_accepted",
        @"rejected": @"fulfillment_status_rejected",
        @"preparing": @"fulfillment_status_preparing",
        @"ready_for_pickup": @"fulfillment_status_ready_for_pickup",
        @"delivery_requested": @"fulfillment_status_delivery_requested",
        @"delivery_assigned": @"fulfillment_status_delivery_assigned",
        @"awaiting_handover": @"fulfillment_status_awaiting_handover",
        @"handed_over": @"fulfillment_status_handed_over",
        @"in_transit": @"fulfillment_status_in_transit",
        @"delivered": @"fulfillment_status_delivered",
        @"payment_pending": @"fulfillment_status_payment_pending",
        @"payment_confirmed": @"fulfillment_status_payment_confirmed",
        @"completed": @"fulfillment_status_completed",
        @"cancelled": @"fulfillment_status_cancelled",
        @"failed": @"fulfillment_status_failed",
        @"returned": @"fulfillment_status_returned"
    };
    NSString *localizationKey = keys[key];
    return localizationKey.length > 0 ? kLang(localizationKey) : kLang(@"fulfillment_status_unknown");
}

static NSString *PPMissionActionKind(PPOrderCustomerActionType actionType)
{
    switch (actionType) {
        case PPOrderCustomerActionTypeTrack: return @"track";
        case PPOrderCustomerActionTypeCancel: return @"cancel";
        case PPOrderCustomerActionTypeReturn: return @"return";
        case PPOrderCustomerActionTypeRefund: return @"refund";
        case PPOrderCustomerActionTypeReplacement: return @"replacement";
        case PPOrderCustomerActionTypeComplaint: return @"complaint";
        case PPOrderCustomerActionTypeSupport: return @"support";
    }
    return @"support";
}

static NSString *PPMissionActionSymbol(PPOrderCustomerActionType actionType)
{
    switch (actionType) {
        case PPOrderCustomerActionTypeTrack: return @"point.topleft.down.to.point.bottomright.curvepath";
        case PPOrderCustomerActionTypeCancel: return @"xmark.circle";
        case PPOrderCustomerActionTypeReturn: return @"arrow.uturn.backward";
        case PPOrderCustomerActionTypeRefund: return @"creditcard.and.123";
        case PPOrderCustomerActionTypeReplacement: return @"arrow.triangle.2.circlepath";
        case PPOrderCustomerActionTypeComplaint: return @"exclamationmark.bubble";
        case PPOrderCustomerActionTypeSupport: return @"lifepreserver";
    }
    return @"lifepreserver";
}

@interface PPOrderDetailsMissionControlBridge ()

@property (nonatomic, strong, readwrite) PPOrder *order;
@property (nonatomic, strong) PPOrderManager *orderManager;
@property (nonatomic, copy, nullable) PPOrderMissionStateUpdate stateUpdate;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> orderListener;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> supportListener;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> timelineListener;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> requestEventsListener;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id<FIRListenerRegistration>> *fulfillmentListeners;
@property (nonatomic, strong) NSMutableDictionary<NSString *, PPFulfillmentOrder *> *fulfillmentByID;
@property (nonatomic, strong) NSMutableSet<NSString *> *missingFulfillmentIDs;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *accessoryCache;
@property (nonatomic, strong) NSMutableSet<NSString *> *accessoryLookups;
@property (nonatomic, copy) NSArray<NSMutableDictionary *> *lineItems;
@property (nonatomic, copy) NSArray<PPOrderSupportRequest *> *supportRequests;
@property (nonatomic, copy) NSArray<PPOrderTimelineEvent *> *timelineEvents;
@property (nonatomic, copy) NSArray<PPAddressModel *> *addresses;
@property (nonatomic, strong) NSMutableDictionary<NSString *, PPAddressModel *> *addressByID;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectableAddressIDs;
@property (nonatomic, copy) NSString *resolvingAddressID;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) BOOL screenVisible;
@property (nonatomic, assign) BOOL hasLoadedOrder;
@property (nonatomic, assign) BOOL ownershipVerified;
@property (nonatomic, assign) BOOL addressMutationContractSatisfied;
@property (nonatomic, copy) NSString *verifiedOwnerUID;
@property (nonatomic, strong, nullable) FIRAuthStateDidChangeListenerHandle authStateHandle;
@property (nonatomic, assign) BOOL isOffline;
@property (nonatomic, assign) BOOL supportLoading;
@property (nonatomic, assign) BOOL timelineLoading;
@property (nonatomic, assign) BOOL fulfillmentLoading;
@property (nonatomic, copy) NSString *streamErrorMessage;
@property (nonatomic, copy) NSString *supportErrorMessage;
@property (nonatomic, copy) NSString *timelineErrorMessage;
@property (nonatomic, copy) NSString *fulfillmentErrorMessage;
@property (nonatomic, copy) NSString *lastStatusKey;
@property (nonatomic, assign) NSInteger statusRevision;
@property (nonatomic, assign) NSInteger generation;

- (NSString *)addressIdentifier:(PPAddressModel *)address;
- (nullable PPAddressModel *)selectedSavedAddress;
- (void)resolveSelectedAddressIfNeededForGeneration:(NSInteger)generation;
- (void)scheduleAuthorityTimeoutForGeneration:(NSInteger)generation;
- (void)installAuthorizedDetailListenersForGeneration:(NSInteger)generation;
- (NSArray<NSString *> *)normalizedFulfillmentOrderIDs;
- (NSString *)resolvedCurrencyCode;
- (BOOL)hasCurrentOwnerAuthority;
- (void)installAuthStateListenerIfNeeded;
- (BOOL)isSelectableAddressData:(NSDictionary *)data
                      documentID:(NSString *)documentID
                           model:(PPAddressModel *)model;

@end

@implementation PPOrderDetailsMissionControlBridge

- (instancetype)initWithOrder:(PPOrder *)order
{
    self = [super init];
    if (self) {
        _order = order;
        _orderManager = PPOrderManager.shared;
        _fulfillmentListeners = [NSMutableDictionary dictionary];
        _fulfillmentByID = [NSMutableDictionary dictionary];
        _missingFulfillmentIDs = [NSMutableSet set];
        _accessoryCache = [NSMutableDictionary dictionary];
        _accessoryLookups = [NSMutableSet set];
        _lineItems = @[];
        _supportRequests = @[];
        _timelineEvents = @[];
        _addresses = @[];
        _addressByID = [NSMutableDictionary dictionary];
        _selectableAddressIDs = [NSMutableSet set];
        _resolvingAddressID = @"";
        _verifiedOwnerUID = @"";
        _streamErrorMessage = @"";
        _supportErrorMessage = @"";
        _timelineErrorMessage = @"";
        _fulfillmentErrorMessage = @"";
        _lastStatusKey = PPMissionNormalizedKey(order.customerVisibleStatusKey);
        _statusRevision = 0;
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}

#pragma mark - Lifecycle

- (void)startWithUpdate:(PPOrderMissionStateUpdate)update
{
    [self stopListeners];
    self.stateUpdate = update;
    self.running = YES;
    self.hasLoadedOrder = NO;
    self.ownershipVerified = NO;
    self.addressMutationContractSatisfied = NO;
    self.verifiedOwnerUID = @"";
    self.supportLoading = YES;
    self.timelineLoading = YES;
    self.generation += 1;
    self.resolvingAddressID = @"";
    [self.accessoryLookups removeAllObjects];
    [self rebuildLineItems];
    [self emitState];
    [self installAuthStateListenerIfNeeded];
    [self installListenersForGeneration:self.generation];
    [self scheduleAuthorityTimeoutForGeneration:self.generation];
}

- (void)setScreenVisible:(BOOL)visible
{
    _screenVisible = visible;
}

- (void)refresh
{
    if (!self.running) return;
    self.streamErrorMessage = @"";
    self.supportErrorMessage = @"";
    self.timelineErrorMessage = @"";
    self.fulfillmentErrorMessage = @"";
    self.hasLoadedOrder = NO;
    self.ownershipVerified = NO;
    self.addressMutationContractSatisfied = NO;
    self.verifiedOwnerUID = @"";
    self.supportLoading = YES;
    self.timelineLoading = YES;
    self.generation += 1;
    self.resolvingAddressID = @"";
    [self.accessoryLookups removeAllObjects];
    [self stopListeners];
    [self rebuildLineItems];
    [self emitState];
    [self installListenersForGeneration:self.generation];
    [self scheduleAuthorityTimeoutForGeneration:self.generation];
}

- (void)stop
{
    self.running = NO;
    self.generation += 1;
    [self stopListeners];
    if (self.authStateHandle) {
        [[FIRAuth auth] removeAuthStateDidChangeListener:self.authStateHandle];
        self.authStateHandle = nil;
    }
    self.ownershipVerified = NO;
    self.addressMutationContractSatisfied = NO;
    self.verifiedOwnerUID = @"";
    self.stateUpdate = nil;
}

- (BOOL)hasCurrentOwnerAuthority
{
    NSString *currentUID = FIRAuth.auth.currentUser.uid ?: @"";
    return self.ownershipVerified && currentUID.length > 0 &&
        self.verifiedOwnerUID.length > 0 &&
        [currentUID isEqualToString:self.verifiedOwnerUID];
}

- (void)installAuthStateListenerIfNeeded
{
    if (self.authStateHandle) return;
    __weak typeof(self) weakSelf = self;
    self.authStateHandle = [[FIRAuth auth] addAuthStateDidChangeListener:^(
        FIRAuth * _Nonnull auth,
        FIRUser * _Nullable user
    ) {
        (void)auth;
        PPMissionOnMain(^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || !self.running || !self.ownershipVerified) return;
            NSString *currentUID = user.uid ?: @"";
            if (currentUID.length > 0 &&
                [currentUID isEqualToString:self.verifiedOwnerUID]) {
                return;
            }
            self.generation += 1;
            [self stopListeners];
            self.ownershipVerified = NO;
            self.addressMutationContractSatisfied = NO;
            self.verifiedOwnerUID = @"";
            self.hasLoadedOrder = YES;
            self.streamErrorMessage = kLang(@"order_mission_permission_denied");
            self.supportLoading = NO;
            self.timelineLoading = NO;
            self.fulfillmentLoading = NO;
            self.supportRequests = @[];
            self.timelineEvents = @[];
            self.lineItems = @[];
            self.addresses = @[];
            [self.addressByID removeAllObjects];
            [self.selectableAddressIDs removeAllObjects];
            [self.fulfillmentByID removeAllObjects];
            [self.missingFulfillmentIDs removeAllObjects];
            [self.accessoryCache removeAllObjects];
            [self.accessoryLookups removeAllObjects];
            [self emitState];
        });
    }];
}

- (void)stopListeners
{
    [self.orderListener remove];
    [self.supportListener remove];
    [self.timelineListener remove];
    [self.requestEventsListener remove];
    self.orderListener = nil;
    self.supportListener = nil;
    self.timelineListener = nil;
    self.requestEventsListener = nil;
    for (id<FIRListenerRegistration> registration in self.fulfillmentListeners.allValues) {
        [registration remove];
    }
    [self.fulfillmentListeners removeAllObjects];
}

- (void)installListenersForGeneration:(NSInteger)generation
{
    NSString *orderID = PPMissionSafeString(self.order.orderId);
    if (orderID.length == 0) {
        self.streamErrorMessage = kLang(@"order_missing_id");
        self.hasLoadedOrder = YES;
        self.supportLoading = NO;
        self.timelineLoading = NO;
        [self emitState];
        return;
    }

    __weak typeof(self) weakSelf = self;
    FIRDocumentReference *orderReference = [[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:orderID];
    NSLog(@"PPBackend > ORDER_DETAILS : MissionControl realtime listener starting | orderID=%@ | generation=%ld", orderID, (long)generation);
    self.orderListener =
        [orderReference addSnapshotListenerWithIncludeMetadataChanges:YES
                                                              listener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        PPMissionOnMain(^{
            __strong typeof(weakSelf) self = weakSelf;
            // The parent snapshot establishes ownership. It must be allowed to
            // validate the authenticated UID and set ownershipVerified before
            // downstream listeners require current-owner authority.
            if (!self || !self.running || generation != self.generation) return;
            self.hasLoadedOrder = YES;
            if (error) {
                NSLog(@"PPBackend > ORDER_DETAILS : MissionControl snapshot error | orderID=%@ | error=%@", orderID, error.localizedDescription);
                NSString *currentUID = FIRAuth.auth.currentUser.uid ?: @"";
                NSString *knownOwnerUID = self.verifiedOwnerUID.length > 0
                    ? self.verifiedOwnerUID
                    : PPMissionSafeString(self.order.userId);
                BOOL permissionDenied =
                    [error.domain isEqualToString:FIRFirestoreErrorDomain] &&
                    error.code == FIRFirestoreErrorCodePermissionDenied;
                BOOL ownerChanged = currentUID.length == 0 ||
                    (knownOwnerUID.length > 0 &&
                     ![currentUID isEqualToString:knownOwnerUID]);
                if (permissionDenied || ownerChanged) {
                    self.ownershipVerified = NO;
                    self.addressMutationContractSatisfied = NO;
                    self.verifiedOwnerUID = @"";
                    self.streamErrorMessage = kLang(@"order_mission_permission_denied");
                } else {
                    self.isOffline = YES;
                    self.streamErrorMessage = kLang(@"order_mission_load_error");
                }
                [self emitState];
                return;
            }
            if (!snapshot.exists) {
                NSLog(@"PPBackend > ORDER_DETAILS : MissionControl snapshot not found | orderID=%@ | isFromCache=%d", orderID, snapshot.metadata.isFromCache);
                if (snapshot.metadata.isFromCache) {
                    self.isOffline = YES;
                    self.streamErrorMessage = self.ownershipVerified
                        ? kLang(@"order_mission_load_error")
                        : kLang(@"order_mission_offline_no_cache");
                } else {
                    self.ownershipVerified = NO;
                    self.addressMutationContractSatisfied = NO;
                    self.verifiedOwnerUID = @"";
                    self.streamErrorMessage = kLang(@"order_mission_not_found");
                }
                [self emitState];
                return;
            }

            NSDictionary *data = snapshot.data ?: @{};
            NSString *authenticatedUID = FIRAuth.auth.currentUser.uid ?: @"";
            NSString *ownerUID = PPMissionSafeString(data[@"userId"] ?: data[@"uid"]);
            if (authenticatedUID.length == 0 || ownerUID.length == 0 || ![authenticatedUID isEqualToString:ownerUID]) {
                NSLog(@"PPBackend > ORDER_DETAILS : MissionControl owner mismatch | authUID=%@ | ownerUID=%@", authenticatedUID, ownerUID);
                self.ownershipVerified = NO;
                self.addressMutationContractSatisfied = NO;
                self.verifiedOwnerUID = @"";
                self.streamErrorMessage = kLang(@"order_mission_permission_denied");
                [self emitState];
                return;
            }

            PPOrder *updatedOrder = [PPOrder orderFromSnapshot:snapshot];
            if (!updatedOrder) {
                NSLog(@"PPBackend > ORDER_DETAILS : MissionControl failed to parse order | orderID=%@", orderID);
                self.ownershipVerified = NO;
                self.addressMutationContractSatisfied = NO;
                self.verifiedOwnerUID = @"";
                self.streamErrorMessage = kLang(@"order_mission_load_error");
                [self emitState];
                return;
            }

            NSString *nextStatus = PPMissionNormalizedKey(updatedOrder.customerVisibleStatusKey);
            BOOL statusChanged = self.lastStatusKey.length > 0 && ![self.lastStatusKey isEqualToString:nextStatus];
            NSLog(@"PPBackend > ORDER_DETAILS : MissionControl order parsed | orderID=%@ | status=%ld | paymentStatus=%@ | itemsCount=%lu | statusChanged=%d",
                  updatedOrder.orderId,
                  (long)updatedOrder.status,
                  updatedOrder.paymentStatus,
                  (unsigned long)updatedOrder.items.count,
                  statusChanged);
            self.order = updatedOrder;
            self.ownershipVerified = YES;
            self.verifiedOwnerUID = ownerUID;
            NSString *canonicalOwnerUID = PPMissionSafeString(data[@"userId"]);
            NSString *embeddedOrderID = PPMissionSafeString(data[@"orderId"]);
            self.addressMutationContractSatisfied =
                canonicalOwnerUID.length > 0 &&
                [canonicalOwnerUID isEqualToString:ownerUID] &&
                embeddedOrderID.length > 0 && data[@"createdAt"] != nil;
            self.streamErrorMessage = @"";
            self.isOffline = snapshot.metadata.isFromCache;
            if (statusChanged) {
                self.statusRevision += 1;
                if (self.screenVisible) {
                    UINotificationFeedbackGenerator *feedback = [UINotificationFeedbackGenerator new];
                    [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
                }
            }
            self.lastStatusKey = nextStatus;
            [self rebuildLineItems];
            [self resolveSelectedAddressIfNeededForGeneration:generation];
            [self installAuthorizedDetailListenersForGeneration:generation];
            [self emitState];
            [self resolveLineItemsIfNeeded];
        });
    }];

}

- (void)installAuthorizedDetailListenersForGeneration:(NSInteger)generation
{
    if (!self.running || generation != self.generation || ![self hasCurrentOwnerAuthority]) return;

    NSString *orderID = PPMissionSafeString(self.order.orderId);
    if (orderID.length == 0) return;

    __weak typeof(self) weakSelf = self;
    if (!self.supportListener) {
        self.supportListener = [self.orderManager listenToSupportRequestsForOrderID:orderID
                                                                     metadataUpdate:^(NSArray<PPOrderSupportRequest *> *requests,
                                                                                      BOOL isFromCache,
                                                                                      NSError * _Nullable error) {
            PPMissionOnMain(^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self || !self.running || generation != self.generation ||
                    ![self hasCurrentOwnerAuthority]) return;
                self.supportLoading = !error && isFromCache;
                self.supportRequests = requests ?: @[];
                self.supportErrorMessage = error ? kLang(@"order_mission_support_load_error") : @"";
                [self emitState];
            });
        }];
    }

    if (!self.timelineListener) {
        self.timelineListener = [self.orderManager listenToTimelineEventsForOrder:self.order
                                                                    metadataUpdate:^(NSArray<PPOrderTimelineEvent *> *events,
                                                                                     BOOL isFromCache,
                                                                                     NSError * _Nullable error) {
            PPMissionOnMain(^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self || !self.running || generation != self.generation ||
                    ![self hasCurrentOwnerAuthority]) return;
                self.timelineLoading = !error && isFromCache;
                self.timelineEvents = events ?: @[];
                self.timelineErrorMessage = error ? kLang(@"order_mission_timeline_load_error") : @"";
                [self emitState];
            });
        }];
    }

    [self restartFulfillmentListenersForGeneration:generation];
}

- (void)scheduleAuthorityTimeoutForGeneration:(NSInteger)generation
{
    __weak typeof(self) weakSelf = self;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(PPMissionAuthorityTimeout * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || !self.running || generation != self.generation) return;
            BOOL shouldEmit = NO;
            if (!self.hasLoadedOrder) {
                self.hasLoadedOrder = YES;
                self.ownershipVerified = NO;
                self.addressMutationContractSatisfied = NO;
                self.verifiedOwnerUID = @"";
                self.streamErrorMessage = kLang(@"order_mission_load_timeout");
                shouldEmit = YES;
            }
            if (self.supportLoading) {
                self.supportLoading = NO;
                self.supportErrorMessage = kLang(@"order_mission_support_load_error");
                shouldEmit = YES;
            }
            if (self.timelineLoading) {
                self.timelineLoading = NO;
                self.timelineErrorMessage = kLang(@"order_mission_timeline_load_error");
                shouldEmit = YES;
            }
            if (shouldEmit) [self emitState];
        }
    );
}

#pragma mark - Presentation Snapshot

- (NSString *)resolvedCurrencyCode
{
    NSString *currency = PPMissionSafeString(self.order.currency);
    if (currency.length == 0) {
        currency = PPMissionSafeString([CountryModel safeCurrentCurrencyCode]);
    }
    return currency.length > 0 ? currency : @"QAR";
}

- (void)emitState
{
    PPOrderMissionStateUpdate update = self.stateUpdate;
    if (!update) return;
    NSDictionary *state = [self presentationState];
    PPMissionOnMain(^{ update(state); });
}

- (NSDictionary *)presentationState
{
    BOOL hadVerifiedAuthority = self.ownershipVerified;
    if (![self hasCurrentOwnerAuthority]) {
        NSString *authorityError = self.streamErrorMessage ?: @"";
        if (hadVerifiedAuthority && authorityError.length == 0) {
            authorityError = kLang(@"order_mission_permission_denied");
        }
        return @{
            @"screenTitle": kLang(@"order_details_title"),
            @"statusColor": UIColor.systemGrayColor,
            @"statusProgress": @0,
            @"isAuthorized": @NO,
            @"isInitialLoading": @(!self.hasLoadedOrder),
            @"isOffline": @(self.isOffline),
            @"errorMessage": authorityError,
            @"supportErrorMessage": @"",
            @"timelineErrorMessage": @"",
            @"fulfillmentErrorMessage": @"",
            @"supportLoading": @(self.supportLoading),
            @"timelineLoading": @(self.timelineLoading),
            @"fulfillmentLoading": @NO,
            @"hasFulfillmentData": @NO,
            @"items": @[],
            @"timeline": @[],
            @"requests": @[],
            @"fulfillments": @[],
            @"actions": @[]
        };
    }

    PPOrder *order = self.order;
    NSString *statusKey = PPMissionNormalizedKey(order.customerVisibleStatusKey);
    if (statusKey.length == 0) statusKey = @"preparing_for_shipment";
    NSString *currency = [self resolvedCurrencyCode];
    double subtotal = MAX(0.0, order.amount);
    double shipping = MAX(0.0, order.shippingFee);
    double total = MAX(0.0, order.totalAmount);
    if (order.fulfillmentVersion != 1) {
        // Legacy orders predate the immutable checkout snapshot contract and
        // may still require the historical pricing fallback.
        if (shipping <= 0.0 && total <= subtotal + 0.009 && subtotal > 0.0) {
            shipping = MAX(0.0, CartManager.sharedManager.deliveryFee);
        }
        double recomputedTotal = subtotal + shipping;
        if (recomputedTotal > total) total = recomputedTotal;
        if (total <= 0.0) total = subtotal;
    }

    NSDictionary *coordinate = [self deliveryCoordinate];
    NSArray *requests = [self requestDictionaries];
    NSArray *timeline = [self timelineDictionaries:self.timelineEvents];
    NSArray *fulfillments = [self fulfillmentDictionaries];
    NSArray *actions = [self actionDictionaries];
    NSArray *items = [self itemDictionaries];
    NSDictionary *summary = [self fulfillmentSummaryWithVisibleCount:fulfillments.count];
    NSString *address = [self resolvedAddressText];
    BOOL addressEditable = [self isAddressEditable];
    NSString *paymentMethod = order.isCashOnDelivery ? kLang(@"payment_method_name_cash") : kLang(@"order_payment_provider_default");
    NSString *paymentStatus = [self paymentStatusText];
    NSString *payment = paymentStatus.length > 0
        ? [NSString stringWithFormat:@"%@ • %@", paymentMethod, paymentStatus]
        : paymentMethod;

    NSMutableDictionary *state = [@{
        @"orderID": PPMissionSafeString(order.orderId),
        @"reference": PPMissionSafeString(order.displayOrderReference).length > 0 ? order.displayOrderReference : @"—",
        @"rawStatus": PPMissionNormalizedKey(order.rawStatus),
        @"statusKey": statusKey,
        @"statusTitle": PPMissionOrderStatusTitle(statusKey),
        @"statusHint": PPMissionOrderStatusHint(statusKey),
        @"statusSymbol": PPMissionStatusSymbol(statusKey),
        @"statusColor": PPOrderStatusAccentColorForKey(statusKey),
        @"statusProgress": @(PPMissionStatusProgress(statusKey)),
        @"statusRevision": @(self.statusRevision),
        @"createdAtText": PPMissionDateText(order.createdAt),
        @"updatedAtText": PPMissionDateText(order.statusUpdatedAt ?: order.updatedAt),
        @"subtotalText": PPMissionMoneyText(subtotal, currency),
        @"shippingText": PPMissionMoneyText(shipping, currency),
        @"totalText": PPMissionMoneyText(total, currency),
        @"paymentText": payment ?: @"",
        @"currency": currency,
        @"addressText": address.length > 0 ? address : kLang(@"order_mission_address_unavailable"),
        @"addressEditable": @(addressEditable),
        @"addressEditMessage": addressEditable ? kLang(@"order_mission_address_edit_hint") : [self addressEditBlockedMessage],
        @"hasCoordinate": coordinate[@"hasCoordinate"] ?: @NO,
        @"latitude": coordinate[@"latitude"] ?: @0,
        @"longitude": coordinate[@"longitude"] ?: @0,
        @"items": items,
        @"timeline": timeline,
        @"requests": requests,
        @"fulfillments": fulfillments,
        @"fulfillmentSummary": summary,
        @"actions": actions,
        @"isAuthorized": @YES,
        @"isInitialLoading": @(!self.hasLoadedOrder),
        @"isOffline": @(self.isOffline),
        @"errorMessage": self.streamErrorMessage ?: @"",
        @"supportErrorMessage": self.supportErrorMessage ?: @"",
        @"timelineErrorMessage": self.timelineErrorMessage ?: @"",
        @"fulfillmentErrorMessage": self.fulfillmentErrorMessage ?: @"",
        @"supportLoading": @(self.supportLoading),
        @"timelineLoading": @(self.timelineLoading),
        @"fulfillmentLoading": @(self.fulfillmentLoading),
        @"fulfillmentVersion": @(order.fulfillmentVersion),
        @"hasFulfillmentData": @(order.fulfillmentVersion == 1 || order.fulfillmentOrderIDs.count > 0 || order.fulfillmentSummary.count > 0),
        @"screenTitle": kLang(@"order_details_title")
    } mutableCopy];
    if (order.createdAt) state[@"createdAt"] = order.createdAt;
    if (order.statusUpdatedAt ?: order.updatedAt) state[@"updatedAt"] = order.statusUpdatedAt ?: order.updatedAt;
    return state.copy;
}

- (NSString *)paymentStatusText
{
    NSString *status = PPMissionNormalizedKey(self.order.paymentStatus);
    if ([status isEqualToString:@"pending_collection"]) return kLang(@"order_payment_status_pending_collection");
    if ([status isEqualToString:@"paid"]) return kLang(@"Paid");
    if ([status isEqualToString:@"failed"]) return kLang(@"Failed");
    if ([status isEqualToString:@"cancelled"] || [status isEqualToString:@"canceled"]) return kLang(@"Canceled");
    if (status.length > 0) return kLang(@"Pending");
    return @"";
}

- (NSString *)resolvedAddressText
{
    NSDictionary *snapshot = [self.order.shippingAddressSnapshot isKindOfClass:NSDictionary.class]
        ? self.order.shippingAddressSnapshot : @{};
    for (NSString *key in @[@"displayName", @"address", @"locatioName", @"addressLine1"]) {
        NSString *value = PPMissionSafeString(snapshot[key]);
        if (value.length > 0) return value;
    }
    if (self.order.fulfillmentVersion == 1) return @"";
    PPAddressModel *savedAddress = [self selectedSavedAddress];
    if (savedAddress.displayName.length > 0) return savedAddress.displayName;
    if (savedAddress.locatioName.length > 0) return savedAddress.locatioName;
    if (savedAddress.addressLine1.length > 0) return savedAddress.addressLine1;
    return @"";
}

- (NSDictionary *)deliveryCoordinate
{
    NSDictionary *snapshot = [self.order.shippingAddressSnapshot isKindOfClass:NSDictionary.class]
        ? self.order.shippingAddressSnapshot : @{};
    double latitude = PPMissionDouble(snapshot[@"latitude"] ?: snapshot[@"lat"], NAN);
    double longitude = PPMissionDouble(snapshot[@"longitude"] ?: snapshot[@"lng"], NAN);
    if (!isfinite(latitude) || !isfinite(longitude)) {
        NSString *points = PPMissionSafeString(snapshot[@"locationPoints"]);
        NSArray<NSString *> *parts = [points componentsSeparatedByString:@","];
        if (parts.count >= 2) {
            latitude = PPMissionDouble(parts[0], NAN);
            longitude = PPMissionDouble(parts[1], NAN);
        }
    }
    if ((!isfinite(latitude) || !isfinite(longitude)) && self.order.fulfillmentVersion != 1) {
        NSString *points = PPMissionSafeString([self selectedSavedAddress].locationPoints);
        NSArray<NSString *> *parts = [points componentsSeparatedByString:@","];
        if (parts.count >= 2) {
            latitude = PPMissionDouble(parts[0], NAN);
            longitude = PPMissionDouble(parts[1], NAN);
        }
    }
    BOOL valid = isfinite(latitude) && isfinite(longitude) &&
        fabs(latitude) <= 90.0 && fabs(longitude) <= 180.0 &&
        !(fabs(latitude) < DBL_EPSILON && fabs(longitude) < DBL_EPSILON);
    return @{
        @"hasCoordinate": @(valid),
        @"latitude": @(valid ? latitude : 0.0),
        @"longitude": @(valid ? longitude : 0.0)
    };
}

- (PPAddressModel *)selectedSavedAddress
{
    NSString *identifier = PPMissionSafeString(self.order.shippingAddressId);
    if (identifier.length == 0 &&
        [self.order.shippingAddressSnapshot isKindOfClass:NSDictionary.class]) {
        identifier = PPMissionSafeString(
            self.order.shippingAddressSnapshot[@"addressID"]
        );
    }
    return identifier.length > 0 ? self.addressByID[identifier] : nil;
}

- (void)resolveSelectedAddressIfNeededForGeneration:(NSInteger)generation
{
    if (self.order.fulfillmentVersion == 1) return;
    NSString *identifier = PPMissionSafeString(self.order.shippingAddressId);
    if (identifier.length == 0 &&
        [self.order.shippingAddressSnapshot isKindOfClass:NSDictionary.class]) {
        identifier = PPMissionSafeString(
            self.order.shippingAddressSnapshot[@"addressID"]
        );
    }
    if (identifier.length == 0 || self.addressByID[identifier] ||
        [self.resolvingAddressID isEqualToString:identifier]) {
        return;
    }

    self.resolvingAddressID = identifier;
    __weak typeof(self) weakSelf = self;
    [PPAddressesManager.sharedManager getAllAddressesWithCompletion:^(
        NSArray<PPAddressModel *> * _Nullable addresses,
        NSError * _Nullable error
    ) {
        PPMissionOnMain(^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || !self.running || generation != self.generation) return;
            self.resolvingAddressID = @"";
            if (![self hasCurrentOwnerAuthority]) return;
            if (error) {
                NSLog(@"[PPOrderMission] selected address resolution failed: %@",
                      error.localizedDescription);
                return;
            }
            self.addresses = addresses ?: @[];
            [self.addressByID removeAllObjects];
            for (PPAddressModel *address in self.addresses) {
                NSString *addressID = [self addressIdentifier:address];
                if (addressID.length > 0) self.addressByID[addressID] = address;
            }
            [self emitState];
        });
    }];
}

- (BOOL)isAddressEditable
{
    NSString *status = PPMissionNormalizedKey(self.order.rawStatus);
    return [self hasCurrentOwnerAuthority] &&
        self.order.fulfillmentVersion != 1 &&
        !self.isOffline && self.addressMutationContractSatisfied &&
        ([status isEqualToString:@"pending"] || [status isEqualToString:@"failed"]);
}

- (NSString *)addressEditBlockedMessage
{
    if (![self hasCurrentOwnerAuthority]) {
        return kLang(@"order_mission_permission_denied");
    }
    if (self.isOffline) {
        return kLang(@"order_mission_address_online_required");
    }
    if (self.order.fulfillmentVersion == 1) {
        return kLang(@"order_mission_address_snapshot_locked");
    }
    if (!self.addressMutationContractSatisfied) {
        return kLang(@"order_mission_address_owner_unavailable");
    }
    return kLang(@"order_edit_location_pending_only");
}

- (NSArray<NSDictionary *> *)actionDictionaries
{
    if (!self.order) return @[];
    NSString *raw = PPMissionNormalizedKey(self.order.rawStatus);
    NSString *visible = PPMissionNormalizedKey(self.order.customerVisibleStatusKey);
    BOOL deliveredLike = PPMissionMatches(raw, @[@"delivered", @"completed", @"fulfilled", @"payment_pending", @"payment_confirmed"]);
    BOOL shippedLike = PPMissionMatches(raw, @[@"shipped", @"shipping", @"in_transit", @"out_for_delivery", @"picked_up", @"handed_over"]);
    BOOL cancelledLike = PPMissionMatches(raw, @[@"cancelled", @"canceled", @"abandoned"]);
    BOOL failedLike = PPMissionMatches(raw, @[@"failed", @"rejected", @"declined", @"expired", @"voided", @"error"]);
    BOOL supportAuthorityReady = !self.supportLoading &&
        self.supportErrorMessage.length == 0 && !self.isOffline;
    if ([visible isEqualToString:@"delivered"] || [visible isEqualToString:@"completed"]) deliveredLike = YES;
    if ([visible isEqualToString:@"on_the_way"]) shippedLike = YES;

    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
    NSArray<NSNumber *> *types = @[
        @(PPOrderCustomerActionTypeTrack), @(PPOrderCustomerActionTypeSupport),
        @(PPOrderCustomerActionTypeCancel), @(PPOrderCustomerActionTypeReturn),
        @(PPOrderCustomerActionTypeReplacement), @(PPOrderCustomerActionTypeRefund),
        @(PPOrderCustomerActionTypeComplaint)
    ];
    for (NSNumber *number in types) {
        PPOrderCustomerActionType type = number.integerValue;
        PPOrderEligibilityDecision *decision = [self.orderManager eligibilityForAction:type
                                                                                  order:self.order
                                                                               requests:self.supportRequests
                                                                          referenceDate:NSDate.date];
        BOOL requiresSupportAuthority = type != PPOrderCustomerActionTypeTrack &&
            type != PPOrderCustomerActionTypeSupport;
        BOOL isEligible = type == PPOrderCustomerActionTypeSupport ||
            (decision.isEligible &&
             (!requiresSupportAuthority || supportAuthorityReady));
        NSString *message = decision.message ?: @"";
        if (requiresSupportAuthority && !supportAuthorityReady) {
            message = self.supportLoading
                ? kLang(@"order_mission_support_checking")
                : kLang(@"order_mission_support_state_unavailable");
        }
        BOOL isVisible = YES;
        switch (type) {
            case PPOrderCustomerActionTypeTrack:
            case PPOrderCustomerActionTypeSupport:
            case PPOrderCustomerActionTypeComplaint:
                isVisible = YES;
                break;
            case PPOrderCustomerActionTypeCancel:
                isVisible = !deliveredLike && !shippedLike && !cancelledLike &&
                    (!failedLike || (![self.order isCashOnDelivery] && ![self.order hasCapturedPayment] && [raw isEqualToString:@"failed"]));
                break;
            case PPOrderCustomerActionTypeReturn:
            case PPOrderCustomerActionTypeReplacement:
                isVisible = deliveredLike;
                break;
            case PPOrderCustomerActionTypeRefund:
                isVisible = [self.order hasCapturedPayment] && !shippedLike;
                break;
        }
        [result addObject:@{
            @"id": PPMissionActionKind(type),
            @"kind": PPMissionActionKind(type),
            @"actionType": @(type),
            @"title": decision.actionTitle ?: [PPOrderManager displayTitleForActionType:type],
            @"message": message,
            @"symbol": PPMissionActionSymbol(type),
            @"visible": @(isVisible),
            @"eligible": @(isEligible),
            @"destructive": @(type == PPOrderCustomerActionTypeCancel)
        }];
    }
    [result insertObject:@{
        @"id": @"requests",
        @"kind": @"requests",
        @"actionType": @(-1),
        @"title": kLang(@"order_requests_history_title"),
        @"message": kLang(@"order_mission_requests_hint"),
        @"symbol": @"tray.full",
        @"visible": @YES,
        @"eligible": @YES,
        @"destructive": @NO
    } atIndex:1];
    return result.copy;
}

#pragma mark - Items

- (NSString *)itemIdentifierFromDictionary:(NSDictionary *)item
{
    for (NSString *key in @[@"id", @"itemID", @"productId", @"productID"]) {
        NSString *identifier = PPMissionSafeString(item[key]);
        if (identifier.length > 0) return identifier;
    }
    return @"";
}

- (NSString *)imageURLFromDictionary:(NSDictionary *)data
{
    for (NSString *key in @[@"image", @"imageURL", @"imageUrl", @"photo", @"icon"]) {
        NSString *value = PPMissionSafeString(data[key]);
        if (value.length > 0) return value;
    }
    NSArray *images = [data[@"imageURLsArray"] isKindOfClass:NSArray.class] ? data[@"imageURLsArray"] : @[];
    return PPMissionSafeString(images.firstObject);
}

- (void)rebuildLineItems
{
    NSMutableArray<NSMutableDictionary *> *lines = [NSMutableArray array];
    NSInteger position = 0;
    for (id rawItem in self.order.items ?: @[]) {
        NSMutableDictionary *line = [@{
            @"stableID": [NSString stringWithFormat:@"line-%ld", (long)position],
            @"itemID": @"",
            @"name": @"",
            @"quantity": @1,
            @"price": @0,
            @"imageURL": @"",
            @"needsLookup": @NO
        } mutableCopy];
        position += 1;
        if ([rawItem isKindOfClass:NSString.class]) {
            NSString *identifier = PPMissionSafeString(rawItem);
            if (identifier.length == 0) continue;
            line[@"itemID"] = identifier;
            line[@"stableID"] = [NSString stringWithFormat:@"%@-%ld", identifier, (long)position];
            line[@"needsLookup"] = @YES;
            [lines addObject:line];
            continue;
        }
        if (![rawItem isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *item = rawItem;
        NSString *identifier = [self itemIdentifierFromDictionary:item];
        NSString *name = PPMissionSafeString(item[@"name"] ?: item[@"title"]);
        NSInteger quantity = MAX(1, PPMissionInteger(item[@"qty"] ?: item[@"quantity"], 1));
        double price = MAX(0.0, PPMissionDouble(item[@"price"] ?: item[@"unitPrice"] ?: item[@"finalPrice"], 0.0));
        NSString *imageURL = [self imageURLFromDictionary:item];
        if (identifier.length == 0 && name.length == 0) continue;
        line[@"itemID"] = identifier;
        line[@"stableID"] = identifier.length > 0
            ? [NSString stringWithFormat:@"%@-%ld", identifier, (long)position]
            : [NSString stringWithFormat:@"line-%ld", (long)position];
        line[@"name"] = name;
        line[@"quantity"] = @(quantity);
        line[@"price"] = @(price);
        line[@"imageURL"] = imageURL;
        line[@"needsLookup"] = @(identifier.length > 0 && (name.length == 0 || imageURL.length == 0 || price <= 0.0));
        NSDictionary *cached = self.accessoryCache[identifier];
        if (cached) [self applyAccessoryData:cached toLine:line];
        [lines addObject:line];
    }
    self.lineItems = lines.copy;
}

- (NSArray<NSDictionary *> *)itemDictionaries
{
    NSString *currency = [self resolvedCurrencyCode];
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *line in self.lineItems ?: @[]) {
        NSInteger quantity = MAX(1, PPMissionInteger(line[@"quantity"], 1));
        double price = MAX(0.0, PPMissionDouble(line[@"price"], 0.0));
        NSString *name = PPMissionSafeString(line[@"name"]);
        if (name.length == 0) name = kLang(@"order_item");
        [items addObject:@{
            @"id": PPMissionSafeString(line[@"stableID"]),
            @"itemID": PPMissionSafeString(line[@"itemID"]),
            @"name": name,
            @"quantity": @(quantity),
            @"unitPrice": @(price),
            @"lineTotalText": PPMissionMoneyText(price * quantity, currency),
            @"imageURL": PPMissionSafeString(line[@"imageURL"]),
            @"canOpen": @(PPMissionSafeString(line[@"itemID"]).length > 0)
        }];
    }
    return items.copy;
}

- (void)resolveLineItemsIfNeeded
{
    NSInteger generation = self.generation;
    for (NSMutableDictionary *line in self.lineItems ?: @[]) {
        NSString *identifier = PPMissionSafeString(line[@"itemID"]);
        if (![line[@"needsLookup"] boolValue] || identifier.length == 0) continue;
        NSDictionary *cached = self.accessoryCache[identifier];
        if (cached) {
            [self applyAccessoryData:cached toLine:line];
            continue;
        }
        if ([self.accessoryLookups containsObject:identifier]) continue;
        [self.accessoryLookups addObject:identifier];
        __weak typeof(self) weakSelf = self;
        [self fetchAccessoryDataForIdentifier:identifier completion:^(NSDictionary * _Nullable data) {
            PPMissionOnMain(^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self || generation != self.generation) return;
                [self.accessoryLookups removeObject:identifier];
                if (data.count > 0) self.accessoryCache[identifier] = data;
                for (NSMutableDictionary *candidate in self.lineItems) {
                    if ([PPMissionSafeString(candidate[@"itemID"]) isEqualToString:identifier]) {
                        [self applyAccessoryData:data ?: @{} toLine:candidate];
                    }
                }
                [self emitState];
            });
        }];
    }
}

- (void)applyAccessoryData:(NSDictionary *)data toLine:(NSMutableDictionary *)line
{
    NSString *name = PPMissionSafeString(data[@"name"] ?: data[@"title"]);
    NSString *image = [self imageURLFromDictionary:data];
    double price = MAX(0.0, PPMissionDouble(data[@"finalPrice"] ?: data[@"price"], 0.0));
    if (PPMissionSafeString(line[@"name"]).length == 0 && name.length > 0) line[@"name"] = name;
    if (PPMissionSafeString(line[@"imageURL"]).length == 0 && image.length > 0) line[@"imageURL"] = image;
    if (PPMissionDouble(line[@"price"], 0.0) <= 0.0 && price > 0.0) line[@"price"] = @(price);
    line[@"needsLookup"] = @NO;
}

- (void)fetchAccessoryDataForIdentifier:(NSString *)identifier
                              completion:(void (^)(NSDictionary * _Nullable data))completion
{
    if (identifier.length == 0) {
        if (completion) completion(nil);
        return;
    }
    FIRFirestore *firestore = FIRFirestore.firestore;
    [[[firestore collectionWithPath:@"petAccessories"] documentWithPath:identifier]
     getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (!error && snapshot.exists && snapshot.data.count > 0) {
            if (completion) completion(snapshot.data);
            return;
        }
        [[[firestore collectionWithPath:@"Accessories"] documentWithPath:identifier]
         getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable fallback, NSError * _Nullable fallbackError) {
            if (completion) completion(!fallbackError && fallback.exists ? fallback.data : nil);
        }];
    }];
}

#pragma mark - Timeline and Requests

- (NSArray<NSDictionary *> *)timelineDictionaries:(NSArray<PPOrderTimelineEvent *> *)events
{
    NSMutableArray *result = [NSMutableArray array];
    NSInteger index = 0;
    for (PPOrderTimelineEvent *event in events ?: @[]) {
        NSString *identifier = PPMissionSafeString(event.eventId);
        if (identifier.length == 0) identifier = [NSString stringWithFormat:@"timeline-%ld", (long)index];
        index += 1;
        [result addObject:@{
            @"id": identifier,
            @"title": PPOrderTimelineTitle(event) ?: event.summary ?: kLang(@"order_tracking_title"),
            @"subtitle": PPOrderTimelineSubtitle(event) ?: @"",
            @"status": PPMissionNormalizedKey(event.status),
            @"symbol": PPMissionStatusSymbol(event.status.length > 0 ? event.status : event.type),
            @"dateText": PPMissionDateText(event.createdAt),
            @"date": event.createdAt ?: NSDate.date
        }];
    }
    return result.copy;
}

- (NSDictionary *)requestDictionary:(PPOrderSupportRequest *)request
{
    NSMutableArray *attachments = [NSMutableArray array];
    for (PPOrderSupportAttachment *attachment in request.attachments ?: @[]) {
        [attachments addObject:@{
            @"url": attachment.attachmentURL ?: @"",
            @"fileName": attachment.fileName ?: @"",
            @"mimeType": attachment.mimeType ?: @"image/jpeg"
        }];
    }
    NSString *finalResolutionTitle =
        PPMissionRequestStatusTitleIfKnown(request.finalResolution);
    NSString *adminReviewSummary = PPMissionRequestMetadataSummary(
        request.adminReview,
        request.status
    );
    NSString *resolutionSummary = PPMissionRequestMetadataSummary(
        request.resolutionMetadata,
        request.finalResolution
    );
    return @{
        @"id": request.requestId ?: NSUUID.UUID.UUIDString,
        @"requestID": request.requestId ?: @"",
        @"type": request.type ?: @"support",
        @"typeTitle": [PPOrderManager displayTitleForRequestType:request.type] ?: kLang(@"order_action_support_case"),
        @"reasonTitle": request.reasonTitle.length > 0 ? request.reasonTitle : kLang(@"order_reason_other_title"),
        @"notes": request.notes ?: @"",
        @"status": request.status ?: @"pending_review",
        @"statusTitle": [PPOrderManager displayTitleForRequestStatus:request.status] ?: kLang(@"order_request_status_pending_review"),
        @"finalResolution": finalResolutionTitle,
        @"itemIDs": request.itemIDs ?: @[],
        @"itemSnapshots": request.itemSnapshots ?: @[],
        @"attachments": attachments,
        @"adminReview": adminReviewSummary.length > 0
            ? @{@"summary": adminReviewSummary} : @{},
        @"resolution": resolutionSummary.length > 0
            ? @{@"summary": resolutionSummary} : @{},
        @"createdAt": request.createdAt ?: NSDate.date,
        @"updatedAt": request.updatedAt ?: request.createdAt ?: NSDate.date,
        @"createdAtText": PPMissionDateText(request.createdAt),
        @"orderCancelled": @(request.orderCancelled),
        @"cancellationDisposition": request.cancellationDisposition ?: @""
    };
}

- (NSArray<NSDictionary *> *)requestDictionaries
{
    NSMutableArray *result = [NSMutableArray array];
    for (PPOrderSupportRequest *request in self.supportRequests ?: @[]) {
        [result addObject:[self requestDictionary:request]];
    }
    return result.copy;
}

- (void)startRequestEventsForRequestID:(NSString *)requestID
                                 update:(PPOrderMissionListResult)update
{
    [self.requestEventsListener remove];
    self.requestEventsListener = nil;
    if (![self hasCurrentOwnerAuthority]) {
        if (update) update(@[], PPMissionError(403, kLang(@"order_mission_permission_denied")));
        return;
    }
    NSString *orderID = PPMissionSafeString(self.order.orderId);
    NSString *safeRequestID = PPMissionSafeString(requestID);
    if (orderID.length == 0 || safeRequestID.length == 0) {
        if (update) update(@[], PPMissionError(400, kLang(@"order_mission_request_not_found")));
        return;
    }
    __weak typeof(self) weakSelf = self;
    self.requestEventsListener = [self.orderManager listenToRequestEventsForOrderID:orderID
                                                                          requestID:safeRequestID
                                                                             update:^(NSArray<PPOrderTimelineEvent *> *events, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        PPMissionOnMain(^{
            if (![self hasCurrentOwnerAuthority]) {
                if (update) update(@[], PPMissionError(403, kLang(@"order_mission_permission_denied")));
                return;
            }
            NSArray *mapped = [self timelineDictionaries:events ?: @[]];
            if (update) update(mapped, error);
        });
    }];
}

- (void)stopRequestEvents
{
    [self.requestEventsListener remove];
    self.requestEventsListener = nil;
}

#pragma mark - Fulfillment

- (NSArray<NSString *> *)normalizedFulfillmentOrderIDs
{
    NSMutableOrderedSet<NSString *> *identifiers = [NSMutableOrderedSet orderedSet];
    for (id rawIdentifier in self.order.fulfillmentOrderIDs ?: @[]) {
        NSString *identifier = PPMissionSafeString(rawIdentifier);
        if (identifier.length > 0) [identifiers addObject:identifier];
    }
    return identifiers.array;
}

- (void)restartFulfillmentListenersForGeneration:(NSInteger)generation
{
    NSArray<NSString *> *identifiers = [self normalizedFulfillmentOrderIDs];
    NSSet *desired = [NSSet setWithArray:identifiers];
    for (NSString *existing in self.fulfillmentListeners.allKeys.copy) {
        if (![desired containsObject:existing]) {
            [self.fulfillmentListeners[existing] remove];
            [self.fulfillmentListeners removeObjectForKey:existing];
            [self.fulfillmentByID removeObjectForKey:existing];
            [self.missingFulfillmentIDs removeObject:existing];
        }
    }
    if (identifiers.count == 0) {
        self.fulfillmentLoading = NO;
        [self emitState];
        return;
    }
    self.fulfillmentLoading = self.fulfillmentByID.count + self.missingFulfillmentIDs.count < identifiers.count;
    __weak typeof(self) weakSelf = self;
    for (NSString *rawIdentifier in identifiers) {
        NSString *identifier = PPMissionSafeString(rawIdentifier);
        if (identifier.length == 0 || self.fulfillmentListeners[identifier]) continue;
        FIRDocumentReference *reference = [[[FIRFirestore firestore] collectionWithPath:@"FulfillmentOrders"] documentWithPath:identifier];
        id<FIRListenerRegistration> listener = [reference addSnapshotListener:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
            PPMissionOnMain(^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self || !self.running || generation != self.generation ||
                    ![self hasCurrentOwnerAuthority]) return;
                if (error) {
                    self.fulfillmentErrorMessage = kLang(@"order_mission_fulfillment_load_error");
                    [self.missingFulfillmentIDs addObject:identifier];
                } else if (!snapshot.exists) {
                    [self.fulfillmentByID removeObjectForKey:identifier];
                    [self.missingFulfillmentIDs addObject:identifier];
                } else {
                    NSString *parentID = PPMissionSafeString(snapshot.data[@"parentOrderId"] ?: snapshot.data[@"orderId"]);
                    NSString *parentUserID = PPMissionSafeString(snapshot.data[@"parentUserId"]);
                    if (parentID.length == 0 || ![parentID isEqualToString:self.order.orderId] ||
                        parentUserID.length == 0 || ![parentUserID isEqualToString:self.verifiedOwnerUID]) {
                        self.fulfillmentErrorMessage = kLang(@"order_mission_permission_denied");
                        [self.missingFulfillmentIDs addObject:identifier];
                    } else {
                        PPFulfillmentOrder *fulfillment = [PPFulfillmentOrder fromDictionary:snapshot.data ?: @{}
                                                                                 fulfillmentID:snapshot.documentID];
                        if (fulfillment) self.fulfillmentByID[identifier] = fulfillment;
                        [self.missingFulfillmentIDs removeObject:identifier];
                    }
                }
                if (self.missingFulfillmentIDs.count == 0) {
                    self.fulfillmentErrorMessage = @"";
                }
                self.fulfillmentLoading = self.fulfillmentByID.count + self.missingFulfillmentIDs.count < identifiers.count;
                [self emitState];
            });
        }];
        self.fulfillmentListeners[identifier] = listener;
    }
}

- (NSArray<NSDictionary *> *)fulfillmentDictionaries
{
    NSMutableArray *result = [NSMutableArray array];
    NSArray<NSString *> *identifiers = [self normalizedFulfillmentOrderIDs];
    NSInteger sequence = 0;
    for (NSString *identifier in identifiers) {
        PPFulfillmentOrder *fulfillment = self.fulfillmentByID[identifier];
        if (!fulfillment) continue;
        sequence += 1;
        NSString *currency = PPMissionSafeString(fulfillment.currency);
        if (currency.length == 0) currency = [self resolvedCurrencyCode];
        [result addObject:@{
            @"id": fulfillment.fulfillmentID ?: identifier,
            @"sequence": @(sequence),
            @"ownerType": fulfillment.ownerType ?: @"platform",
            @"ownerTitle": [PPMissionNormalizedKey(fulfillment.ownerType) isEqualToString:@"platform"]
                ? kLang(@"fulfillment_owner_platform") : kLang(@"fulfillment_owner_partner"),
            @"status": PPMissionNormalizedKey(fulfillment.status),
            @"statusTitle": PPMissionFulfillmentStatusTitle(fulfillment.status),
            @"statusColor": PPOrderStatusAccentColorForKey(fulfillment.status),
            @"itemCount": @(MAX(0, fulfillment.itemCount)),
            @"itemCountText": [NSString stringWithFormat:kLang(@"fulfillment_items_count"), (long)MAX(0, fulfillment.itemCount)],
            // Customer UI intentionally uses the customer-facing subtotal.
            // providerNet is provider-private commercial information.
            @"subtotalText": PPMissionMoneyText(fulfillment.subtotal, currency)
        }];
    }
    return result.copy;
}

- (NSDictionary *)fulfillmentSummaryWithVisibleCount:(NSInteger)visibleCount
{
    NSDictionary *serverSummary = [self.order.fulfillmentSummary isKindOfClass:NSDictionary.class]
        ? self.order.fulfillmentSummary : @{};
    NSDictionary *serverByStatus = [serverSummary[@"byStatus"] isKindOfClass:NSDictionary.class]
        ? serverSummary[@"byStatus"] : @{};
    NSInteger total = PPMissionInteger(
        serverSummary[@"total"] ?: serverSummary[@"totalCount"],
        [self normalizedFulfillmentOrderIDs].count
    );
    total = MAX(total, (NSInteger)[self normalizedFulfillmentOrderIDs].count);
    NSInteger pending = 0;
    NSInteger accepted = 0;
    NSInteger preparing = 0;
    NSInteger ready = 0;
    NSInteger inDelivery = 0;
    NSInteger delivered = 0;
    NSInteger completed = 0;
    NSInteger cancelled = 0;
    NSInteger rejected = 0;
    NSInteger failed = 0;
    NSInteger returned = 0;

    if (visibleCount > 0) {
        // Live child snapshots win over the eventually-consistent parent
        // summary. If some children are unreadable, the UI marks the summary
        // partial instead of inventing states for the unseen groups.
        for (PPFulfillmentOrder *fulfillment in self.fulfillmentByID.allValues) {
            NSString *status = PPMissionNormalizedKey(fulfillment.status);
            if ([status isEqualToString:@"new_request"]) pending += 1;
            if ([status isEqualToString:@"accepted"] ||
                [status isEqualToString:@"preparing"]) accepted += 1;
            if ([status isEqualToString:@"preparing"]) preparing += 1;
            if ([status isEqualToString:@"ready_for_pickup"] ||
                [status isEqualToString:@"delivery_requested"]) ready += 1;
            if (PPMissionMatches(status, @[
                @"delivery_assigned", @"awaiting_handover", @"handed_over",
                @"in_transit"
            ])) inDelivery += 1;
            if (PPMissionMatches(status, @[
                @"delivered", @"payment_pending", @"payment_confirmed"
            ])) delivered += 1;
            if ([status isEqualToString:@"completed"]) completed += 1;
            if ([status isEqualToString:@"cancelled"]) cancelled += 1;
            if ([status isEqualToString:@"rejected"]) rejected += 1;
            if ([status isEqualToString:@"failed"]) failed += 1;
            if ([status isEqualToString:@"returned"]) returned += 1;
        }
    } else {
        pending = PPMissionInteger(serverSummary[@"pendingCount"], 0);
        accepted = PPMissionInteger(serverSummary[@"acceptedCount"], 0);
        preparing = PPMissionInteger(serverSummary[@"preparingCount"], 0);
        ready = PPMissionInteger(serverSummary[@"readyForDeliveryCount"], 0);
        inDelivery = PPMissionInteger(serverSummary[@"inDeliveryCount"], 0);
        delivered = PPMissionInteger(serverByStatus[@"delivered"], 0) +
            PPMissionInteger(serverByStatus[@"payment_pending"], 0) +
            PPMissionInteger(serverByStatus[@"payment_confirmed"], 0);
        completed = PPMissionInteger(serverSummary[@"completedCount"], 0);
        cancelled = PPMissionInteger(serverSummary[@"cancelledCount"], 0);
        rejected = PPMissionInteger(serverSummary[@"rejectedCount"], 0);
        failed = PPMissionInteger(serverSummary[@"failedCount"], 0);
        returned = PPMissionInteger(serverSummary[@"returnedCount"], 0);
    }
    return @{
        @"total": @(MAX(total, visibleCount)),
        @"visible": @(visibleCount),
        @"pending": @(MAX(0, pending)),
        @"accepted": @(MAX(0, accepted)),
        @"preparing": @(MAX(0, preparing)),
        @"ready": @(MAX(0, ready)),
        @"inDelivery": @(MAX(0, inDelivery)),
        @"delivered": @(MAX(0, delivered)),
        @"completed": @(MAX(0, completed)),
        @"cancelled": @(MAX(0, cancelled)),
        @"rejected": @(MAX(0, rejected)),
        @"failed": @(MAX(0, failed)),
        @"returned": @(MAX(0, returned)),
        @"missing": @(self.missingFulfillmentIDs.count),
        @"isPartial": @(self.missingFulfillmentIDs.count > 0 || (total > 0 && visibleCount < total))
    };
}

#pragma mark - Support Actions

- (NSArray<NSDictionary *> *)reasonOptionsForAction:(PPOrderCustomerActionType)actionType
{
    return [self.orderManager reasonOptionsForAction:actionType] ?: @[];
}

- (void)cancelOrderWithCompletion:(PPOrderMissionResult)completion
{
    if (![self hasCurrentOwnerAuthority]) {
        if (completion) completion(nil, PPMissionError(403, kLang(@"order_mission_permission_denied")));
        return;
    }
    if (self.supportLoading || self.supportErrorMessage.length > 0 ||
        self.isOffline) {
        NSString *message = self.supportLoading
            ? kLang(@"order_mission_support_checking")
            : kLang(@"order_mission_support_state_unavailable");
        if (completion) completion(nil, PPMissionError(409, message));
        return;
    }
    PPOrderEligibilityDecision *decision = [self.orderManager eligibilityForAction:PPOrderCustomerActionTypeCancel
                                                                              order:self.order
                                                                           requests:self.supportRequests
                                                                      referenceDate:NSDate.date];
    if (!decision.isEligible) {
        if (completion) completion(nil, PPMissionError(409, decision.message));
        return;
    }
    NSString *status = PPMissionNormalizedKey(self.order.rawStatus);
    BOOL pendingCheckout = !self.order.isCashOnDelivery && !self.order.hasCapturedPayment &&
        ([status isEqualToString:@"pending"] || [status isEqualToString:@"failed"]);
    if (pendingCheckout) {
        [self.orderManager cancelPendingCheckoutOrder:self.order completion:^(BOOL success, BOOL alreadyCancelled, NSError * _Nullable error) {
            PPMissionOnMain(^{
                if (![self hasCurrentOwnerAuthority]) {
                    if (completion) completion(nil, PPMissionError(403, kLang(@"order_mission_permission_denied")));
                    return;
                }
                if (!success || error) {
                    if (completion) completion(nil, error ?: PPMissionError(500, kLang(@"order_cancel_checkout_failed")));
                    return;
                }
                if (completion) completion(@{
                    @"outcome": alreadyCancelled ? @"already_cancelled" : @"cancelled",
                    @"title": kLang(@"order_mission_command_complete"),
                    @"message": alreadyCancelled ? kLang(@"order_action_cancel_unavailable_closed") : kLang(@"OrderCanceled")
                }, nil);
            });
        }];
        return;
    }

    PPOrderSupportDraft *draft = [PPOrderSupportDraft new];
    draft.actionType = PPOrderCustomerActionTypeCancel;
    draft.reasonCode = @"cancelled_by_user";
    draft.reasonTitle = kLang(@"order_cancel_button");
    draft.issueCategory = @"cancelled_by_user";
    draft.subject = [PPOrderManager displayTitleForActionType:PPOrderCustomerActionTypeCancel];
    [self.orderManager submitSupportDraft:draft forOrder:self.order completion:^(PPOrderSupportRequest * _Nullable request, BOOL deduplicated, NSError * _Nullable error) {
        PPMissionOnMain(^{
            if (![self hasCurrentOwnerAuthority]) {
                if (completion) completion(nil, PPMissionError(403, kLang(@"order_mission_permission_denied")));
                return;
            }
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            NSString *outcome = deduplicated ? @"existing_request" : (request.orderCancelled ? @"cancelled" : @"pending_review");
            NSString *message = nil;
            if (deduplicated) {
                message = kLang(@"order_existing_request_opened");
            } else if (request.orderCancelled) {
                message = kLang(@"OrderCanceled");
            } else {
                message = kLang(@"order_mission_cancellation_pending_review");
            }
            NSMutableDictionary *result = [@{
                @"outcome": outcome,
                @"title": request.orderCancelled ? kLang(@"order_mission_command_complete") : kLang(@"order_mission_review_opened"),
                @"message": message
            } mutableCopy];
            if (request) result[@"request"] = [self requestDictionary:request];
            if (completion) completion(result.copy, nil);
        });
    }];
}

- (void)submitAction:(PPOrderCustomerActionType)actionType
           reasonCode:(NSString *)reasonCode
          reasonTitle:(NSString *)reasonTitle
                notes:(NSString *)notes
      selectedItemIDs:(NSArray<NSString *> *)selectedItemIDs
               images:(NSArray<UIImage *> *)images
           completion:(PPOrderMissionResult)completion
{
    if (![self hasCurrentOwnerAuthority]) {
        if (completion) completion(nil, PPMissionError(403, kLang(@"order_mission_permission_denied")));
        return;
    }
    if (actionType != PPOrderCustomerActionTypeSupport &&
        (self.supportLoading || self.supportErrorMessage.length > 0 ||
         self.isOffline)) {
        NSString *message = self.supportLoading
            ? kLang(@"order_mission_support_checking")
            : kLang(@"order_mission_support_state_unavailable");
        if (completion) completion(nil, PPMissionError(409, message));
        return;
    }
    PPOrderEligibilityDecision *decision = [self.orderManager eligibilityForAction:actionType
                                                                              order:self.order
                                                                           requests:self.supportRequests
                                                                      referenceDate:NSDate.date];
    if (!decision.isEligible &&
        actionType != PPOrderCustomerActionTypeSupport) {
        if (completion) completion(nil, PPMissionError(409, decision.message));
        return;
    }
    NSArray<NSDictionary *> *options = [self reasonOptionsForAction:actionType];
    NSDictionary *selectedReason = nil;
    for (NSDictionary *option in options) {
        if ([PPMissionSafeString(option[@"code"]) isEqualToString:PPMissionSafeString(reasonCode)]) {
            selectedReason = option;
            break;
        }
    }
    if (options.count > 0 && !selectedReason) {
        if (completion) completion(nil, PPMissionError(422, kLang(@"order_request_select_reason")));
        return;
    }
    if ([selectedReason[@"requiresItemSelection"] boolValue] && selectedItemIDs.count == 0) {
        if (completion) completion(nil, PPMissionError(422, kLang(@"order_request_select_items_error")));
        return;
    }
    if (images.count > 4) {
        if (completion) completion(nil, PPMissionError(422, kLang(@"order_support_too_many_photos")));
        return;
    }

    NSString *draftIdentifier = NSUUID.UUID.UUIDString;
    __weak typeof(self) weakSelf = self;
    void (^submit)(NSArray<PPOrderSupportAttachment *> *) = ^(NSArray<PPOrderSupportAttachment *> *attachments) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (![self hasCurrentOwnerAuthority]) {
            if (completion) completion(nil, PPMissionError(403, kLang(@"order_mission_permission_denied")));
            return;
        }
        PPOrderSupportDraft *draft = [PPOrderSupportDraft new];
        draft.actionType = actionType;
        draft.reasonCode = PPMissionSafeString(reasonCode).length > 0 ? PPMissionSafeString(reasonCode) : @"other";
        draft.reasonTitle = PPMissionSafeString(reasonTitle);
        draft.issueCategory = draft.reasonCode;
        draft.subject = [PPOrderManager displayTitleForActionType:actionType];
        draft.notes = PPMissionSafeString(notes);
        draft.selectedItemIDs = selectedItemIDs ?: @[];
        draft.attachments = attachments ?: @[];
        [self.orderManager submitSupportDraft:draft forOrder:self.order completion:^(PPOrderSupportRequest * _Nullable request, BOOL deduplicated, NSError * _Nullable error) {
            PPMissionOnMain(^{
                if (![self hasCurrentOwnerAuthority]) {
                    if (completion) completion(nil, PPMissionError(403, kLang(@"order_mission_permission_denied")));
                    return;
                }
                if (error) {
                    if (completion) completion(nil, error);
                    return;
                }
                NSMutableDictionary *result = [@{
                    @"outcome": deduplicated ? @"existing_request" : @"submitted",
                    @"title": kLang(@"order_mission_review_opened"),
                    @"message": deduplicated ? kLang(@"order_existing_request_opened") : kLang(@"order_mission_request_submitted")
                } mutableCopy];
                if (request) result[@"request"] = [self requestDictionary:request];
                if (completion) completion(result.copy, nil);
            });
        }];
    };

    if (images.count == 0) {
        submit(@[]);
        return;
    }
    [self.orderManager uploadEvidenceImages:images
                                   forOrder:self.order
                            draftIdentifier:draftIdentifier
                                   progress:nil
                                 completion:^(NSArray<PPOrderSupportAttachment *> *attachments, NSError * _Nullable error) {
        PPMissionOnMain(^{
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            submit(attachments ?: @[]);
        });
    }];
}

#pragma mark - Addresses

- (NSString *)addressIdentifier:(PPAddressModel *)address
{
    NSString *identifier = PPMissionSafeString(address.documentID);
    if (identifier.length == 0) identifier = PPMissionSafeString(address.addressID);
    return identifier;
}

- (BOOL)isSelectableAddressData:(NSDictionary *)data
                      documentID:(NSString *)documentID
                           model:(PPAddressModel *)model
{
    NSString *rawOwnerUID = PPMissionSafeString(data[@"userID"]);
    NSString *rawAddressID = PPMissionSafeString(data[@"addressID"]);
    return [self hasCurrentOwnerAuthority] && model.isSemanticallyValid &&
        documentID.length > 0 && [model.documentID isEqualToString:documentID] &&
        [rawOwnerUID isEqualToString:self.verifiedOwnerUID] &&
        [rawAddressID isEqualToString:documentID] &&
        PPMissionIsPositiveIntegerNumber(data[@"cityID"]) &&
        PPMissionIsPositiveIntegerNumber(data[@"stateID"]);
}

- (NSDictionary *)addressDictionary:(PPAddressModel *)address
                          selectable:(BOOL)selectable
{
    NSString *identifier = [self addressIdentifier:address];
    return @{
        @"id": identifier,
        @"title": address.displayName ?: address.locatioName ?: kLang(@"DeliveryAddress"),
        @"subtitle": address.locatioName ?: address.addressLine1 ?: @"",
        @"isDefault": @(address.isDefault),
        @"isSelected": @([identifier isEqualToString:PPMissionSafeString(self.order.shippingAddressId)]),
        @"isSelectable": @(selectable),
        @"availabilityMessage": selectable
            ? @"" : kLang(@"order_mission_address_not_selectable")
    };
}

- (void)loadAddressesWithCompletion:(PPOrderMissionListResult)completion
{
    if (![self hasCurrentOwnerAuthority]) {
        if (completion) completion(@[], PPMissionError(403, kLang(@"order_mission_permission_denied")));
        return;
    }
    NSString *ownerUID = self.verifiedOwnerUID;
    FIRCollectionReference *collection = [[[
        FIRFirestore.firestore collectionWithPath:@"UsersCol"
    ] documentWithPath:ownerUID] collectionWithPath:@"Addresses"];
    __weak typeof(self) weakSelf = self;
    [(FIRQuery *)collection getDocumentsWithSource:FIRFirestoreSourceServer
                                        completion:^(FIRQuerySnapshot * _Nullable querySnapshot,
                                                     NSError * _Nullable error) {
        PPMissionOnMain(^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (![self hasCurrentOwnerAuthority]) {
                if (completion) completion(@[], PPMissionError(403, kLang(@"order_mission_permission_denied")));
                return;
            }
            if (error || !querySnapshot) {
                if (completion) completion(@[], error ?: PPMissionError(500, kLang(@"order_mission_addresses_load_error")));
                return;
            }
            NSMutableArray<PPAddressModel *> *addresses = [NSMutableArray array];
            NSMutableDictionary<NSString *, NSDictionary *> *rawByID = [NSMutableDictionary dictionary];
            for (FIRDocumentSnapshot *document in querySnapshot.documents ?: @[]) {
                NSString *documentID = PPMissionSafeString(document.documentID);
                if (documentID.length == 0) continue;
                NSDictionary *data = document.data ?: @{};
                NSMutableDictionary *safeData = [data mutableCopy];
                for (NSString *key in @[
                    @"addressID", @"userID", @"fullName", @"addressLine1",
                    @"addressLine2", @"postalCode", @"locatioName",
                    @"locationPoints", @"phoneNumber"
                ]) {
                    safeData[key] = PPMissionSafeString(data[key]);
                }
                PPAddressModel *model = [[PPAddressModel alloc] initWithDictionary:safeData
                                                                         documentID:documentID];
                [addresses addObject:model];
                rawByID[documentID] = data;
            }
            [addresses sortUsingComparator:^NSComparisonResult(PPAddressModel *left, PPAddressModel *right) {
                if (left.isDefault != right.isDefault) {
                    return left.isDefault ? NSOrderedAscending : NSOrderedDescending;
                }
                NSDate *leftDate = left.updatedAt ?: left.createdAt ?: [NSDate distantPast];
                NSDate *rightDate = right.updatedAt ?: right.createdAt ?: [NSDate distantPast];
                return [rightDate compare:leftDate];
            }];
            self.addresses = addresses.copy;
            [self.addressByID removeAllObjects];
            [self.selectableAddressIDs removeAllObjects];
            NSMutableArray *mapped = [NSMutableArray array];
            for (PPAddressModel *address in self.addresses) {
                NSString *identifier = [self addressIdentifier:address];
                if (identifier.length == 0) continue;
                self.addressByID[identifier] = address;
                BOOL selectable = [self isSelectableAddressData:rawByID[identifier] ?: @{}
                                                     documentID:identifier
                                                          model:address];
                if (selectable) [self.selectableAddressIDs addObject:identifier];
                [mapped addObject:[self addressDictionary:address selectable:selectable]];
            }
            if (completion) completion(mapped.copy, nil);
        });
    }];
}

- (void)selectAddressWithIdentifier:(NSString *)identifier
                         completion:(PPOrderMissionResult)completion
{
    if (![self isAddressEditable]) {
        if (completion) completion(nil, PPMissionError(403, [self addressEditBlockedMessage]));
        return;
    }
    NSString *safeIdentifier = PPMissionSafeString(identifier);
    if (safeIdentifier.length == 0 ||
        ![self.selectableAddressIDs containsObject:safeIdentifier]) {
        if (completion) completion(nil, PPMissionError(422, kLang(@"order_mission_address_not_selectable")));
        return;
    }
    NSString *ownerUID = self.verifiedOwnerUID;
    FIRDocumentReference *addressReference = [[[[FIRFirestore.firestore
        collectionWithPath:@"UsersCol"] documentWithPath:ownerUID]
        collectionWithPath:@"Addresses"] documentWithPath:safeIdentifier];
    __weak typeof(self) weakSelf = self;
    [addressReference getDocumentWithSource:FIRFirestoreSourceServer
                                  completion:^(FIRDocumentSnapshot * _Nullable document,
                                               NSError * _Nullable fetchError) {
        PPMissionOnMain(^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (![self hasCurrentOwnerAuthority]) {
                if (completion) completion(nil, PPMissionError(403, kLang(@"order_mission_permission_denied")));
                return;
            }
            if (![self isAddressEditable]) {
                if (completion) completion(nil, PPMissionError(403, [self addressEditBlockedMessage]));
                return;
            }
            if (fetchError || !document.exists) {
                if (completion) completion(nil, fetchError ?: PPMissionError(404, kLang(@"order_mission_address_not_selectable")));
                return;
            }
            NSDictionary *data = document.data ?: @{};
            NSMutableDictionary *safeData = [data mutableCopy];
            for (NSString *key in @[
                @"addressID", @"userID", @"fullName", @"addressLine1",
                @"addressLine2", @"postalCode", @"locatioName",
                @"locationPoints", @"phoneNumber"
            ]) {
                safeData[key] = PPMissionSafeString(data[key]);
            }
            PPAddressModel *address = [[PPAddressModel alloc] initWithDictionary:safeData
                                                                       documentID:document.documentID];
            if (![self isSelectableAddressData:data documentID:safeIdentifier model:address]) {
                if (completion) completion(nil, PPMissionError(422, kLang(@"order_mission_address_not_selectable")));
                return;
            }
            NSMutableDictionary *snapshot = [[address toDictionary] mutableCopy];
            snapshot[@"addressID"] = safeIdentifier;
            snapshot[@"displayName"] = address.displayName ?: @"";
            if (address.locatioName.length > 0) snapshot[@"address"] = address.locatioName;
            NSString *points = PPMissionSafeString(address.locationPoints);
            NSArray *parts = [points componentsSeparatedByString:@","];
            if (parts.count >= 2) {
                double latitude = PPMissionDouble(parts[0], NAN);
                double longitude = PPMissionDouble(parts[1], NAN);
                if (isfinite(latitude) && isfinite(longitude)) {
                    snapshot[@"latitude"] = @(latitude);
                    snapshot[@"longitude"] = @(longitude);
                }
            }
            NSDictionary *payload = @{
                @"shippingAddressId": safeIdentifier,
                @"shippingAddressSnapshot": snapshot.copy,
                @"updatedAt": [FIRTimestamp timestamp]
            };
            NSString *orderID = PPMissionSafeString(self.order.orderId);
            FIRDocumentReference *orderReference = [[[FIRFirestore firestore]
                collectionWithPath:@"Orders"] documentWithPath:orderID];
            [orderReference updateData:payload completion:^(NSError * _Nullable updateError) {
                PPMissionOnMain(^{
                    if (![self hasCurrentOwnerAuthority]) {
                        if (completion) completion(nil, PPMissionError(403, kLang(@"order_mission_permission_denied")));
                    } else if (updateError) {
                        if (completion) completion(nil, updateError);
                    } else if (completion) {
                        completion(@{
                            @"outcome": @"updated",
                            @"title": kLang(@"order_mission_command_complete"),
                            @"message": kLang(@"LocationUpdated")
                        }, nil);
                    }
                });
            }];
        });
    }];
}

#pragma mark - UIKit Destinations

- (void)openAccessoryWithIdentifier:(NSString *)identifier
                  fromViewController:(UIViewController *)viewController
                          completion:(void (^)(NSError * _Nullable error))completion
{
    if (![self hasCurrentOwnerAuthority]) {
        if (completion) completion(PPMissionError(403, kLang(@"order_mission_permission_denied")));
        return;
    }
    NSString *safeIdentifier = PPMissionSafeString(identifier);
    if (safeIdentifier.length == 0 || !viewController) {
        if (completion) completion(PPMissionError(400, kLang(@"SomethingWentWrong")));
        return;
    }
    void (^presentAccessory)(PetAccessory *) = ^(PetAccessory *accessory) {
        if (![self hasCurrentOwnerAuthority]) {
            if (completion) completion(PPMissionError(403, kLang(@"order_mission_permission_denied")));
            return;
        }
        if (!accessory) {
            if (completion) completion(PPMissionError(404, kLang(@"SomethingWentWrong")));
            return;
        }
        AccessViewerVC *viewer = [AccessViewerVC new];
        viewer.accessAds = accessory;
        viewer.ParentVC = viewController;
        viewer.hidesBottomBarWhenPushed = YES;
        if (viewController.navigationController) {
            [viewController.navigationController pushViewController:viewer animated:YES];
        } else {
            UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:viewer];
            navigation.modalPresentationStyle = UIModalPresentationFullScreen;
            [viewController presentViewController:navigation animated:YES completion:nil];
        }
        if (completion) completion(nil);
    };

    PetAccessory *cached = [PetAccessoryManager.sharedManager getAccessoryID:safeIdentifier];
    if (cached) {
        presentAccessory(cached);
        return;
    }
    [PetAccessoryManager fetchAccessoriesWithIDs:@[safeIdentifier] completion:^(NSArray<PetAccessory *> *accessories) {
        PPMissionOnMain(^{
            if (accessories.firstObject) {
                presentAccessory(accessories.firstObject);
                return;
            }
            [self fetchAccessoryDataForIdentifier:safeIdentifier completion:^(NSDictionary * _Nullable data) {
                PPMissionOnMain(^{
                    PetAccessory *fallback = data.count > 0
                        ? [[PetAccessory alloc] initWithDictionary:data documentID:safeIdentifier] : nil;
                    presentAccessory(fallback);
                });
            }];
        });
    }];
}

- (void)openAddressEditorFromViewController:(UIViewController *)viewController
{
    AddressFormVC *editor = [[AddressFormVC alloc] initWithAddress:nil];
    if (viewController.navigationController) {
        [viewController.navigationController pushViewController:editor animated:YES];
    } else {
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:editor];
        [viewController presentViewController:navigation animated:YES completion:nil];
    }
}

- (void)openSupportChatFromViewController:(UIViewController *)viewController
{
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    [ChManager.sharedManager openSupportChatFromController:viewController];
}

- (void)requestSupportCallFromViewController:(UIViewController *)viewController
{
    NSString *digits = [PPMissionSupportPhoneNumber stringByReplacingOccurrencesOfString:@"+" withString:@""];
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"telprompt://%@", digits]];
    if (URL && [UIApplication.sharedApplication canOpenURL:URL]) {
        [UIApplication.sharedApplication openURL:URL options:@{} completionHandler:nil];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"order_support_request_call")
                                                                   message:kLang(@"order_mission_call_unavailable")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK") style:UIAlertActionStyleDefault handler:nil]];
    [viewController presentViewController:alert animated:YES completion:nil];
}

@end
