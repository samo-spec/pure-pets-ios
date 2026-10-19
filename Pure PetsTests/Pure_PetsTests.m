//
//  Pure_PetsTests.m
//  Pure PetsTests
//
//  Created by Mohammed Ahmed on 20/07/2024.
//

#import <XCTest/XCTest.h>
#import "UserModel.h"
#import "PPOrder.h"
#import "PPOrderManager.h"
#import "PPPaymentManager.h"
#import "PPPetCareViewController.h"
#import "PPPetCareDiscoveryView.h"
#import "VetModel.h"
#import "MainKindsModel.h"

@interface PPPetCareViewController (ClinicDiscoveryTests)
- (void)pp_applyFiltersAndReload;
- (void)pp_selectSection:(PPPetCareInitialSection)section;
- (void)pp_recoverDiscovery;
- (void)pp_updateDiscoveryAnimated:(BOOL)animated;
@end

@interface Pure_PetsTests : XCTestCase

@end

@interface PPPetCareClinicDiscoveryTests : XCTestCase
@end

@implementation PPPetCareClinicDiscoveryTests

- (VetModel *)clinicWithID:(NSString *)identifier type:(id)type overrides:(NSDictionary *)overrides
{
    NSMutableDictionary *data = [@{@"type": type, @"title": identifier,
                                  @"verificationStatus": @"approved"} mutableCopy];
    [data addEntriesFromDictionary:overrides];
    return [VetModel fromDictionary:data withID:identifier];
}

- (PPPetCareViewController *)controllerWithVets:(NSArray<VetModel *> *)vets
{
    // Do not load the view: these directory/state tests must never start Firebase reads.
    PPPetCareViewController *controller = [[PPPetCareViewController alloc]
        initWithInitialSection:PPPetCareInitialSectionClinics mainKind:nil];
    [controller setValue:vets forKey:@"allVets"];
    return controller;
}

- (NSArray<NSString *> *)visibleIDs:(PPPetCareViewController *)controller
{
    return [[controller valueForKey:@"visibleVets"] valueForKey:@"vetID"];
}

- (void)testClinicTabAcceptsCanonicalAndLegacyTypesAndExcludesDoctors
{
    NSMutableArray<VetModel *> *vets = [NSMutableArray array];
    NSArray *clinicTypes = @[@"clinic", @"company", @1, @"1", @" CLINIC "];
    for (NSUInteger index = 0; index < clinicTypes.count; index++) {
        [vets addObject:[self clinicWithID:[NSString stringWithFormat:@"clinic_%lu", (unsigned long)index]
                                     type:clinicTypes[index] overrides:@{}]];
    }
    [vets addObject:[self clinicWithID:@"doctor" type:@"doctor" overrides:@{}]];
    PPPetCareViewController *controller = [self controllerWithVets:vets];
    [controller pp_applyFiltersAndReload];

    XCTAssertEqual([self visibleIDs:controller].count, clinicTypes.count);
    XCTAssertFalse([[self visibleIDs:controller] containsObject:@"doctor"]);
    [controller pp_selectSection:PPPetCareInitialSectionVeterinarians];
    XCTAssertEqualObjects([self visibleIDs:controller], (@[@"doctor"]), @"Doctors and Clinics are exclusive tabs");
    XCTAssertFalse(controller.isViewLoaded);
}

- (void)testClinicTabExcludesModeratedAndUnapprovedProfiles
{
    NSArray<NSDictionary *> *hiddenStates = @[
        @{@"isDisabled": @YES}, @{@"isBlocked": @YES}, @{@"isDeleted": @YES},
        @{@"verificationStatus": @"pending"}, @{@"verificationStatus": @"rejected"}
    ];
    NSMutableArray<VetModel *> *vets = [NSMutableArray arrayWithObject:
        [self clinicWithID:@"visible" type:@"clinic" overrides:@{}]];
    for (NSDictionary *state in hiddenStates) {
        [vets addObject:[self clinicWithID:@"hidden" type:@"clinic" overrides:state]];
    }
    PPPetCareViewController *controller = [self controllerWithVets:vets];
    [controller pp_applyFiltersAndReload];
    XCTAssertEqualObjects([self visibleIDs:controller], (@[@"visible"]));
    [controller pp_selectSection:PPPetCareInitialSectionVeterinarians];
    XCTAssertEqualObjects([self visibleIDs:controller], @[]);
}

- (void)testLegacyClinicWithoutModerationFieldsRemainsVisible
{
    VetModel *legacy = [VetModel fromDictionary:@{@"type": @1, @"title": @"Legacy clinic",
                                                 @"isBlocked": NSNull.null, @"isDeleted": NSNull.null}
                                         withID:@"legacy"];
    PPPetCareViewController *controller = [self controllerWithVets:@[legacy]];
    [controller pp_applyFiltersAndReload];
    XCTAssertEqualObjects([self visibleIDs:controller], (@[@"legacy"]));
}

- (void)testClinicQueryAndContactFilterDoNotChangeTheDoctorsTab
{
    PPPetCareViewController *controller = [self controllerWithVets:@[
        [self clinicWithID:@"Alpha clinic" type:@"clinic" overrides:@{@"phone": @"+97400000000"}],
        [self clinicWithID:@"Beta clinic" type:@1 overrides:@{}],
        [self clinicWithID:@"Doctor" type:@0 overrides:@{}]
    ]];
    [controller setValue:@"alpha" forKey:@"clinicQuery"];
    [controller setValue:@"doctor" forKey:@"vetQuery"];
    [controller setValue:@1 forKey:@"clinicFilter"];
    [controller pp_applyFiltersAndReload];
    XCTAssertEqualObjects([self visibleIDs:controller], (@[@"Alpha clinic"]));
    [controller pp_selectSection:PPPetCareInitialSectionVeterinarians];
    XCTAssertEqualObjects([self visibleIDs:controller], (@[@"Doctor"]));
    [controller pp_selectSection:PPPetCareInitialSectionClinics];
    XCTAssertEqualObjects([self visibleIDs:controller], (@[@"Alpha clinic"]));
}

- (void)testDoctorsTabAcceptsLegacyPersonalTypesAndNeverIncludesClinics
{
    NSArray *types = @[@"doctor", @"personal", @0, @"0", @" DOCTOR "];
    NSMutableArray<VetModel *> *vets = [NSMutableArray array];
    for (NSUInteger index = 0; index < types.count; index++) {
        [vets addObject:[self clinicWithID:[NSString stringWithFormat:@"doctor_%lu", (unsigned long)index]
                                     type:types[index] overrides:@{}]];
    }
    [vets addObject:[self clinicWithID:@"clinic" type:@1 overrides:@{}]];
    [vets addObject:[self clinicWithID:@"blocked_doctor" type:@0 overrides:@{@"isBlocked": @YES}]];
    [vets addObject:[self clinicWithID:@"pending_doctor" type:@0 overrides:@{@"verificationStatus": @"pending"}]];
    PPPetCareViewController *controller = [self controllerWithVets:vets];
    [controller pp_selectSection:PPPetCareInitialSectionVeterinarians];
    XCTAssertEqual([self visibleIDs:controller].count, types.count);
    XCTAssertFalse([[self visibleIDs:controller] containsObject:@"clinic"]);
    XCTAssertFalse([[self visibleIDs:controller] containsObject:@"blocked_doctor"]);
    XCTAssertFalse([[self visibleIDs:controller] containsObject:@"pending_doctor"]);
    [controller pp_selectSection:PPPetCareInitialSectionClinics];
    XCTAssertEqualObjects([self visibleIDs:controller], (@[@"clinic"]));
}

- (void)testContactFilterRequiresAUsableNumberRatherThanAReadinessFlag
{
    PPPetCareViewController *controller = [self controllerWithVets:@[
        [self clinicWithID:@"flag_only" type:@0 overrides:@{@"readyToContact": @YES}],
        [self clinicWithID:@"invalid" type:@0 overrides:@{@"phone": @"please call"}],
        [self clinicWithID:@"arabic_number" type:@0 overrides:@{@"phone": @"+٩٧٤٣٣١٢٤٥٦٧"}]
    ]];
    [controller setValue:@1 forKey:@"vetFilter"];
    [controller pp_selectSection:PPPetCareInitialSectionVeterinarians];
    XCTAssertEqualObjects([self visibleIDs:controller], (@[@"arabic_number"]));
}

- (void)testClinicPetKindFilterUsesTheExistingModelContract
{
    PPPetCareViewController *controller = [self controllerWithVets:@[
        [self clinicWithID:@"matching" type:@"clinic" overrides:@{@"petMainKindID": @7}],
        [self clinicWithID:@"other" type:@"clinic" overrides:@{@"petMainKindID": @8}],
        [self clinicWithID:@"multiSpecies" type:@1 overrides:@{@"animalTypes": @[@"7", @"8"]}]
    ]];
    MainKindsModel *kind = [MainKindsModel new];
    kind.ID = 7;
    [controller setValue:kind forKey:@"selectedMainKind"];
    [controller pp_applyFiltersAndReload];
    XCTAssertEqualObjects([self visibleIDs:controller], (@[@"matching", @"multiSpecies"]));
}

- (void)testClearingClinicSearchKeepsClinicIdentityAndOtherSectionQueries
{
    PPPetCareViewController *controller = [self controllerWithVets:@[
        [self clinicWithID:@"clinic" type:@1 overrides:@{}],
        [self clinicWithID:@"doctor" type:@0 overrides:@{}]
    ]];
    PPPetCareDiscoveryView *discovery = [PPPetCareDiscoveryView new];
    [controller setValue:discovery forKey:@"discoveryView"];
    [controller setValue:discovery.searchField forKey:@"searchField"];
    discovery.searchField.text = @"no match";
    [controller setValue:@"no match" forKey:@"clinicQuery"];
    [controller setValue:@"doctor" forKey:@"vetQuery"];
    [controller setValue:@"medicine" forKey:@"medicineQuery"];
    [controller pp_applyFiltersAndReload];
    XCTAssertEqual([self visibleIDs:controller].count, 0U);
    [controller pp_recoverDiscovery];
    XCTAssertEqualObjects([self visibleIDs:controller], (@[@"clinic"]));
    XCTAssertEqualObjects([controller valueForKey:@"clinicQuery"], @"");
    XCTAssertEqualObjects([controller valueForKey:@"vetQuery"], @"doctor");
    XCTAssertEqualObjects([controller valueForKey:@"medicineQuery"], @"medicine");
    XCTAssertTrue(discovery.clinicsButton.isSelected);
    XCTAssertFalse(controller.isViewLoaded);
}

- (void)testClinicDiscoveryRetainsResultsAndExposesRecoveryOnSharedLoadFailure
{
    PPPetCareViewController *controller = [self controllerWithVets:@[
        [self clinicWithID:@"clinic" type:@1 overrides:@{}]
    ]];
    PPPetCareDiscoveryView *discovery = [PPPetCareDiscoveryView new];
    [controller setValue:discovery forKey:@"discoveryView"];
    [controller setValue:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]
                  forKey:@"vetLoadError"];
    [controller pp_applyFiltersAndReload];
    XCTAssertEqualObjects([self visibleIDs:controller], (@[@"clinic"]));
    XCTAssertEqual([[discovery valueForKey:@"state"] integerValue], PPPetCareDiscoveryStateRetainedError);

    [controller setValue:@[] forKey:@"allVets"];
    [controller pp_applyFiltersAndReload];
    XCTAssertEqual([[discovery valueForKey:@"state"] integerValue], PPPetCareDiscoveryStateError);
    XCTAssertFalse(discovery.primaryButton.isHidden);
    [controller setValue:nil forKey:@"vetLoadError"];
    [controller setValue:@YES forKey:@"loadingVets"];
    [controller pp_updateDiscoveryAnimated:NO];
    XCTAssertEqual([[discovery valueForKey:@"state"] integerValue], PPPetCareDiscoveryStateLoading);
    XCTAssertTrue(discovery.primaryButton.isHidden);
}

@end

@implementation Pure_PetsTests

- (PPOrder *)testOrderWithStatus:(NSString *)rawStatus createdAt:(NSDate *)createdAt
{
    PPOrder *order = [PPOrder new];
    order.orderId = @"ORD_TEST";
    order.userId = @"user_123";
    order.status = [PPOrder statusFromRawValue:rawStatus];
    order.rawStatus = rawStatus ?: @"";
    order.amount = 50.0;
    order.totalAmount = 50.0;
    order.currency = @"QAR";
    order.paymentProvider = @"QIB";
    order.items = @[
        @{@"id": @"item_1", @"name": @"Harness", @"qty": @1, @"price": @50.0}
    ];
    order.createdAt = createdAt ?: [NSDate date];
    order.updatedAt = createdAt ?: [NSDate date];
    order.statusUpdatedAt = createdAt ?: [NSDate date];
    return order;
}

- (void)testOrderStatusParsingSupportsDifferentPaidStates {
    NSArray<NSString *> *paidLike = @[
        @"paid",
        @"success",
        @"simulator_success",
        @"payment_success",
        @"processing",
        @"preparing",
        @"packed",
        @"shipped",
        @"out_for_delivery",
        @"delivered",
        @"fulfilled"
    ];

    for (NSString *raw in paidLike) {
        PPOrderStatus status = [PPOrder statusFromRawValue:raw];
        XCTAssertEqual(status, PPOrderStatusPaid, @"Expected '%@' to map to Paid", raw);
    }
}

- (void)testOrderStatusParsingSupportsDifferentFailureStates {
    NSArray<NSString *> *failureLike = @[
        @"failed",
        @"rejected",
        @"cancelled",
        @"canceled",
        @"cancelled_by_user",
        @"payment_rejected",
        @"expired"
    ];

    for (NSString *raw in failureLike) {
        PPOrderStatus status = [PPOrder statusFromRawValue:raw];
        XCTAssertEqual(status, PPOrderStatusFailed, @"Expected '%@' to map to Failed", raw);
    }
}

- (void)testOrderStatusParsingDefaultsToPendingForUnknownStates {
    NSArray *pendingLike = @[
        @"pending",
        @"created",
        @"queued",
        @"",
        [NSNull null]
    ];

    for (id raw in pendingLike) {
        PPOrderStatus status = [PPOrder statusFromRawValue:raw];
        XCTAssertEqual(status, PPOrderStatusPending);
    }
}

- (void)testOrderStatusNormalizationHandlesSpacingAndHyphen {
    NSString *normalized = [PPOrder normalizedStatusFromRawValue:@"Out For-Delivery"];
    XCTAssertEqualObjects(normalized, @"out_for_delivery");
}

- (void)testFirestoreDataUsesNormalizedRawStatusWhenAvailable {
    PPOrder *order = [PPOrder new];
    order.orderId = @"ORD_123";
    order.userId = @"user_123";
    order.status = PPOrderStatusPending;
    order.rawStatus = @"Out For Delivery";
    order.amount = 10.0;
    order.totalAmount = 10.0;
    order.currency = @"QAR";
    order.paymentProvider = @"QIB";
    order.items = @[];
    order.shippingAddressId = @"addr_1";
    order.shippingAddressSnapshot = @{};
    order.createdAt = [NSDate dateWithTimeIntervalSince1970:1000];
    order.updatedAt = [NSDate dateWithTimeIntervalSince1970:1000];

    NSDictionary *data = [order firestoreData];
    XCTAssertEqualObjects(data[@"status"], @"out_for_delivery");
}

- (void)testFirestoreDataFallsBackToEnumWhenRawStatusMissing {
    PPOrder *order = [PPOrder new];
    order.orderId = @"ORD_124";
    order.userId = @"user_124";
    order.status = PPOrderStatusFailed;
    order.rawStatus = @"";
    order.amount = 10.0;
    order.totalAmount = 10.0;
    order.currency = @"QAR";
    order.paymentProvider = @"QIB";
    order.items = @[];
    order.shippingAddressId = @"";
    order.shippingAddressSnapshot = @{};
    order.createdAt = [NSDate dateWithTimeIntervalSince1970:1000];
    order.updatedAt = [NSDate dateWithTimeIntervalSince1970:1000];

    NSDictionary *data = [order firestoreData];
    XCTAssertEqualObjects(data[@"status"], @"failed");
}

- (void)testQIBProcessingStateDoesNotInferCapturedPaymentWithoutFinalEvidence {
    PPOrder *order = [PPOrder new];
    order.orderId = @"ORD_QIB_PENDING";
    order.userId = @"user_123";
    order.paymentMethodId = @"qib";
    order.paymentProvider = @"QIB";
    order.rawStatus = @"processing";
    order.status = [PPOrder statusFromRawValue:order.rawStatus];
    order.paymentStatus = [PPOrder normalizedPaymentStatusFromRawValue:nil
                                                         paymentMethod:order.paymentMethodId
                                                                status:order.rawStatus
                                                           transaction:nil
                                                                paidAt:nil
                                                     paymentCollectedAt:nil];

    XCTAssertEqualObjects(order.paymentStatus, @"pending");
    XCTAssertFalse([order hasCapturedPayment]);
}

- (void)testQIBPaidEvidenceStillMarksCapturedPayment {
    PPOrder *order = [PPOrder new];
    order.orderId = @"ORD_QIB_PAID";
    order.userId = @"user_123";
    order.paymentMethodId = @"qib";
    order.paymentProvider = @"QIB";
    order.rawStatus = @"processing";
    order.status = [PPOrder statusFromRawValue:order.rawStatus];
    order.transactionId = @"txn_123";
    order.paymentStatus = [PPOrder normalizedPaymentStatusFromRawValue:nil
                                                         paymentMethod:order.paymentMethodId
                                                                status:order.rawStatus
                                                           transaction:order.transactionId
                                                                paidAt:nil
                                                     paymentCollectedAt:nil];

    XCTAssertEqualObjects(order.paymentStatus, @"paid");
    XCTAssertTrue([order hasCapturedPayment]);
}

- (void)testEligibilityAllowsCancelBeforeShipment {
    PPOrderManager *manager = [PPOrderManager shared];
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:1710000000];
    PPOrder *order = [self testOrderWithStatus:@"processing" createdAt:now];

    PPOrderEligibilityDecision *decision =
    [manager eligibilityForAction:PPOrderCustomerActionTypeCancel
                            order:order
                         requests:@[]
                    referenceDate:now];

    XCTAssertTrue(decision.isEligible);
}

- (void)testEligibilityBlocksReturnBeforeDelivery {
    PPOrderManager *manager = [PPOrderManager shared];
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:1710000000];
    PPOrder *order = [self testOrderWithStatus:@"shipped" createdAt:[NSDate dateWithTimeIntervalSince1970:1709900000]];

    PPOrderEligibilityDecision *decision =
    [manager eligibilityForAction:PPOrderCustomerActionTypeReturn
                            order:order
                         requests:@[]
                    referenceDate:now];

    XCTAssertFalse(decision.isEligible);
}

- (void)testEligibilityBlocksRefundAfterShipment {
    PPOrderManager *manager = [PPOrderManager shared];
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:1710000000];
    PPOrder *order = [self testOrderWithStatus:@"shipped" createdAt:[NSDate dateWithTimeIntervalSince1970:1709900000]];
    order.transactionId = @"txn_123";
    order.paidAt = [NSDate dateWithTimeIntervalSince1970:1709901000];
    order.statusUpdatedAt = now;

    PPOrderEligibilityDecision *decision =
    [manager eligibilityForAction:PPOrderCustomerActionTypeRefund
                            order:order
                         requests:@[]
                    referenceDate:now];

    XCTAssertFalse(decision.isEligible);
}

- (void)testEligibilityBlocksDuplicateOpenReturnRequest {
    PPOrderManager *manager = [PPOrderManager shared];
    NSDate *deliveredAt = [NSDate dateWithTimeIntervalSince1970:1710000000];
    PPOrder *order = [self testOrderWithStatus:@"delivered" createdAt:[NSDate dateWithTimeIntervalSince1970:1709800000]];
    order.deliveredAt = deliveredAt;
    order.statusUpdatedAt = deliveredAt;

    PPOrderSupportRequest *request = [PPOrderSupportRequest requestFromDictionary:@{
        @"requestId": @"req_1",
        @"orderId": @"ORD_TEST",
        @"userId": @"user_123",
        @"type": @"return",
        @"status": @"pending_review",
        @"finalResolution": @"pending_review",
        @"createdAt": deliveredAt,
        @"updatedAt": deliveredAt
    } documentID:@"req_1"];

    PPOrderEligibilityDecision *decision =
    [manager eligibilityForAction:PPOrderCustomerActionTypeReturn
                            order:order
                         requests:@[request]
                    referenceDate:[NSDate dateWithTimeIntervalSince1970:1710003600]];

    XCTAssertFalse(decision.isEligible);
}

- (void)testSupportRequestDictionaryMappingParsesAttachmentsAndStatus {
    PPOrderSupportRequest *request = [PPOrderSupportRequest requestFromDictionary:@{
        @"requestId": @"req_map",
        @"orderId": @"ORD_1",
        @"userId": @"user_1",
        @"type": @"refund",
        @"reasonCode": @"duplicate_payment",
        @"reasonTitle": @"Duplicate payment",
        @"status": @"pending_review",
        @"finalResolution": @"pending_review",
        @"attachments": @[
            @{
                @"url": @"https://example.com/evidence.jpg",
                @"storagePath": @"orderSupport/user_1/ORD_1/evidence.jpg",
                @"mimeType": @"image/jpeg",
                @"fileName": @"evidence.jpg",
                @"sizeBytes": @1200
            }
        ],
        @"createdAt": [NSDate dateWithTimeIntervalSince1970:1710000000],
        @"updatedAt": [NSDate dateWithTimeIntervalSince1970:1710000000]
    } documentID:@"req_map"];

    XCTAssertEqualObjects(request.type, @"refund");
    XCTAssertEqualObjects(request.status, @"pending_review");
    XCTAssertEqual(request.attachments.count, 1);
    XCTAssertEqualObjects(request.attachments.firstObject.mimeType, @"image/jpeg");
}

- (void)testSimulatedPaymentSuccessDefaultsToOffAndCanToggleInDebug {
    [PPPaymentManager setSimulatedPaymentSuccessEnabled:NO];
    XCTAssertFalse([PPPaymentManager isSimulatedPaymentSuccessEnabled]);

#if DEBUG
    [PPPaymentManager setSimulatedPaymentSuccessEnabled:YES];
    XCTAssertTrue([PPPaymentManager isSimulatedPaymentSuccessEnabled]);
    [PPPaymentManager setSimulatedPaymentSuccessEnabled:NO];
#endif
}

- (void)testInitWithDictBackfillsCanonicalFieldsFromLegacyAliases {
    NSDictionary *payload = @{
        @"uid": @"uid_123",
        @"displayName": @"Legacy Name",
        @"email": @"legacy@example.com",
        @"photoURL": @"https://example.com/avatar.jpg",
        @"online": @YES
    };

    UserModel *user = [[UserModel alloc] initWithDict:payload];

    XCTAssertEqualObjects(user.ID, @"uid_123");
    XCTAssertEqualObjects(user.UserName, @"Legacy Name");
    XCTAssertEqualObjects(user.UserEmail, @"legacy@example.com");
    XCTAssertEqualObjects(user.UserImageUrl.absoluteString, @"https://example.com/avatar.jpg");
    XCTAssertEqual(user.onlineStatus, OnlineStatusOnline);
    XCTAssertTrue(user.isOnline);
}

- (void)testOnlineStatusKeyHasPriorityOverLegacyOnlineFlags {
    NSDictionary *payload = @{
        @"ID": @"user_1",
        @"onlineStatus": @(OnlineStatusOffline),
        @"online": @YES,
        @"isOnline": @YES
    };

    UserModel *user = [[UserModel alloc] initWithDict:payload];
    XCTAssertEqual(user.onlineStatus, OnlineStatusOffline);
    XCTAssertFalse(user.isOnline);
}

- (void)testToDictionaryIncludesCanonicalFieldsOnly {
    UserModel *user = [UserModel new];
    user.ID = @"user_9";
    user.UserName = @"Pure Pets";
    user.UserEmail = @"user9@example.com";
    user.UserImageUrl = [NSURL URLWithString:@"https://example.com/user9.png"];

    NSDictionary *dict = [user toDictionary];

    XCTAssertEqualObjects(dict[@"ID"], @"user_9");
    XCTAssertEqualObjects(dict[@"UserName"], @"Pure Pets");
    XCTAssertEqualObjects(dict[@"UserEmail"], @"user9@example.com");
    XCTAssertEqualObjects(dict[@"UserImageUrl"], @"https://example.com/user9.png");
    XCTAssertNil(dict[@"uid"]);
    XCTAssertNil(dict[@"displayName"]);
    XCTAssertNil(dict[@"email"]);
    XCTAssertNil(dict[@"photoURL"]);
}

- (void)testSecureCodingRoundTripPreservesNormalizedData {
    UserModel *original = [UserModel new];
    original.ID = @"user_roundtrip";
    original.UserName = @"Round Trip";
    original.UserEmail = @"roundtrip@example.com";
    original.UserImageUrl = [NSURL URLWithString:@"https://example.com/roundtrip.jpg"];
    original.CountryID = 974;
    original.isAdmin = YES;
    original.isSuperAdmin = NO;
    original.isBlocked = NO;
    original.role = UserRoleStoreManager;
    original.verified = YES;
    original.plan = @"pro";
    original.loginSource = UserLoginSourcePPUsers;
    original.PPUserTokenID = @"token_user";
    original.onlineStatus = OnlineStatusOnline;
    original.lastSeen = [NSDate dateWithTimeIntervalSince1970:1710000000];
    original.permissions = [@{@"postAds": @YES, @"moderate": @NO} mutableCopy];

    NSError *archiveError = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original
                                         requiringSecureCoding:YES
                                                         error:&archiveError];
    XCTAssertNil(archiveError);
    XCTAssertNotNil(data);

    NSError *unarchiveError = nil;
    UserModel *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:UserModel.class
                                                            fromData:data
                                                               error:&unarchiveError];
    XCTAssertNil(unarchiveError);
    XCTAssertNotNil(decoded);

    XCTAssertEqualObjects(decoded.ID, original.ID);
    XCTAssertEqualObjects(decoded.UserName, original.UserName);
    XCTAssertEqualObjects(decoded.UserEmail, original.UserEmail);
    XCTAssertEqualObjects(decoded.UserImageUrl.absoluteString, original.UserImageUrl.absoluteString);
    XCTAssertEqual(decoded.CountryID, original.CountryID);
    XCTAssertEqual(decoded.onlineStatus, OnlineStatusOnline);
    XCTAssertTrue(decoded.isOnline);
    XCTAssertEqualObjects(decoded.permissions[@"postAds"], @YES);
    XCTAssertEqualObjects(decoded.permissions[@"moderate"], @NO);
}

@end
