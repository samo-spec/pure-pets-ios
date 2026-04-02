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

@interface Pure_PetsTests : XCTestCase

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
    original.PPAdminTokenID = @"token_admin";
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
