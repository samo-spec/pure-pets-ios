//
//  PPOrder.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/02/2026.
//


#import <Foundation/Foundation.h>
#import <FirebaseFirestore/FirebaseFirestore.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPOrderStatus) {
    PPOrderStatusPending,
    PPOrderStatusPaid,
    PPOrderStatusFailed,
    PPOrderStatusCancelled,
    PPOrderStatusAbandoned
};

@interface PPOrder : NSObject

@property (nonatomic, copy) NSString *orderId;
@property (nonatomic, copy, nullable) NSString *orderNumber;
@property (nonatomic, copy) NSString *userId;

@property (nonatomic, assign) PPOrderStatus status;
/// Original status value coming from Firestore (normalized, lowercase).
@property (nonatomic, copy) NSString *rawStatus;
@property (nonatomic, copy) NSString *deliveryStatus;

@property (nonatomic, assign) double amount;
@property (nonatomic, assign) double shippingFee;
@property (nonatomic, copy) NSString *currency;
@property (nonatomic, assign) double totalAmount;
@property (nonatomic, copy) NSString *paymentMethodId; // "qib" / "cash"
@property (nonatomic, copy) NSString *paymentStatus; // pending / pending_collection / paid / failed / cancelled
@property (nonatomic, copy) NSString *paymentProvider; // "QIB"
@property (nonatomic, copy) NSString *verificationStatus;

/// Can contain dictionaries (current schema) and/or string IDs (legacy schema).
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, copy, nullable) NSString *shippingAddressId;
@property (nonatomic, strong, nullable) NSDictionary *shippingAddressSnapshot;

@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSDate *updatedAt;
@property (nonatomic, strong, nullable) NSDate *statusUpdatedAt;
@property (nonatomic, strong, nullable) NSDate *paidAt;
@property (nonatomic, strong, nullable) NSDate *processedAt;
@property (nonatomic, strong, nullable) NSDate *readyAt;
@property (nonatomic, strong, nullable) NSDate *readyToShipAt;
@property (nonatomic, strong, nullable) NSDate *deliveryRequestedAt;
@property (nonatomic, strong, nullable) NSDate *deliveryAcceptedAt;
@property (nonatomic, strong, nullable) NSDate *pickedUpAt;
@property (nonatomic, strong, nullable) NSDate *inTransitAt;
@property (nonatomic, strong, nullable) NSDate *shippedAt;
@property (nonatomic, strong, nullable) NSDate *deliveredAt;
@property (nonatomic, strong, nullable) NSDate *paymentPendingAt;
@property (nonatomic, strong, nullable) NSDate *paymentConfirmedAt;
@property (nonatomic, strong, nullable) NSDate *completedAt;
@property (nonatomic, strong, nullable) NSDate *deliveryFailedAt;
@property (nonatomic, strong, nullable) NSDate *returnedToStoreAt;
@property (nonatomic, strong, nullable) NSDate *cancelledAt;
@property (nonatomic, strong, nullable) NSDate *paymentCollectedAt;
@property (nonatomic, strong, nullable) NSDate *estimatedDeliveryAt;

// Payment result
@property (nonatomic, copy, nullable) NSString *transactionId;
@property (nonatomic, strong, nullable) NSDictionary *paymentResponse;
@property (nonatomic, copy, nullable) NSString *failureReason;
@property (nonatomic, copy, nullable) NSString *paymentAttemptId;
@property (nonatomic, copy, nullable) NSString *qibSessionId;

- (NSDictionary *)firestoreData;

+ (instancetype)orderFromSnapshot:(FIRDocumentSnapshot *)snapshot;
+ (PPOrderStatus)statusFromRawValue:(nullable id)value;
+ (NSString *)normalizedStatusFromRawValue:(nullable id)value;
+ (NSString *)normalizedPaymentMethodFromRawValue:(nullable id)value provider:(nullable id)provider;
+ (NSString *)normalizedPaymentStatusFromRawValue:(nullable id)value
                                      paymentMethod:(nullable id)paymentMethod
                                             status:(nullable id)status
                                        transaction:(nullable id)transactionId
                                             paidAt:(nullable id)paidAt
                                  paymentCollectedAt:(nullable id)paymentCollectedAt;

- (BOOL)isCashOnDelivery;
- (BOOL)hasCapturedPayment;
- (BOOL)requiresPostDeliveryPaymentConfirmation;
- (NSString *)effectiveDeliveryStatus;
- (NSString *)customerVisibleStatusKey;
- (NSString *)displayOrderReference;

@end

NS_ASSUME_NONNULL_END
