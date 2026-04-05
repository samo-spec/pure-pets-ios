//
//  PPOrderManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/02/2026.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PPOrder.h"
@class PPAddressModel;
@class FIRListenerRegistration;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPOrderCustomerActionType) {
    PPOrderCustomerActionTypeTrack,
    PPOrderCustomerActionTypeCancel,
    PPOrderCustomerActionTypeReturn,
    PPOrderCustomerActionTypeRefund,
    PPOrderCustomerActionTypeReplacement,
    PPOrderCustomerActionTypeComplaint,
    PPOrderCustomerActionTypeSupport
};

@interface PPOrderSupportAttachment : NSObject

@property (nonatomic, copy) NSString *attachmentURL;
@property (nonatomic, copy) NSString *storagePath;
@property (nonatomic, copy) NSString *mimeType;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, assign) NSInteger sizeBytes;

+ (instancetype)attachmentFromDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryValue;

@end

@interface PPOrderSupportRequest : NSObject

@property (nonatomic, copy) NSString *requestId;
@property (nonatomic, copy) NSString *orderId;
@property (nonatomic, copy) NSString *userId;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *reasonCode;
@property (nonatomic, copy) NSString *reasonTitle;
@property (nonatomic, copy) NSString *issueCategory;
@property (nonatomic, copy) NSString *subject;
@property (nonatomic, copy) NSString *notes;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, copy) NSString *finalResolution;
@property (nonatomic, copy) NSString *dedupeKey;
@property (nonatomic, copy) NSArray<NSString *> *itemIDs;
@property (nonatomic, copy) NSArray<NSDictionary *> *itemSnapshots;
@property (nonatomic, copy) NSArray<PPOrderSupportAttachment *> *attachments;
@property (nonatomic, strong, nullable) NSDictionary *resolutionMetadata;
@property (nonatomic, strong, nullable) NSDictionary *adminReview;
@property (nonatomic, strong, nullable) NSDate *submittedAt;
@property (nonatomic, strong, nullable) NSDate *resolvedAt;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSDate *updatedAt;

+ (instancetype)requestFromSnapshot:(FIRDocumentSnapshot *)snapshot;
+ (instancetype)requestFromDictionary:(NSDictionary *)dictionary documentID:(nullable NSString *)documentID;

@end

@interface PPOrderTimelineEvent : NSObject

@property (nonatomic, copy) NSString *eventId;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, copy) NSString *actorType;
@property (nonatomic, copy) NSString *summary;
@property (nonatomic, strong, nullable) NSDictionary *metadata;
@property (nonatomic, strong) NSDate *createdAt;

+ (instancetype)eventFromSnapshot:(FIRDocumentSnapshot *)snapshot;
+ (instancetype)eventFromDictionary:(NSDictionary *)dictionary documentID:(nullable NSString *)documentID;

@end

@interface PPOrderEligibilityDecision : NSObject

@property (nonatomic, assign) PPOrderCustomerActionType actionType;
@property (nonatomic, assign, getter=isEligible) BOOL eligible;
@property (nonatomic, copy) NSString *actionTitle;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) NSString *statusKey;

@end

@interface PPOrderSupportDraft : NSObject

@property (nonatomic, assign) PPOrderCustomerActionType actionType;
@property (nonatomic, copy) NSString *reasonCode;
@property (nonatomic, copy) NSString *reasonTitle;
@property (nonatomic, copy) NSString *issueCategory;
@property (nonatomic, copy) NSString *subject;
@property (nonatomic, copy) NSString *notes;
@property (nonatomic, copy) NSArray<NSString *> *selectedItemIDs;
@property (nonatomic, copy) NSArray<PPOrderSupportAttachment *> *attachments;

@end

@interface PPOrderManager : NSObject

+ (instancetype)shared;

+ (NSString *)displayTitleForActionType:(PPOrderCustomerActionType)actionType;
+ (NSString *)displayTitleForRequestType:(NSString *)requestType;
+ (NSString *)displayTitleForRequestStatus:(NSString *)status;

- (void)createPendingOrderWithItems:(NSArray<NSDictionary *> *)items
                              amount:(double)amount
                            address:(PPAddressModel * _Nullable)address
                           completion:(void (^)(PPOrder * _Nullable order, NSError * _Nullable error))completion;

- (void)createPendingOrderWithItems:(NSArray<NSDictionary *> *)items
                              amount:(double)amount
                            address:(PPAddressModel * _Nullable)address
                    paymentMethodId:(nullable NSString *)paymentMethodId
                          completion:(void (^)(PPOrder * _Nullable order, NSError * _Nullable error))completion;

- (void)fetchOrCreatePendingOrderWithItems:(NSArray<NSDictionary *> *)items
                                     amount:(double)amount
                                    address:(PPAddressModel * _Nullable)address
                                  completion:(void (^)(PPOrder * _Nullable order, NSError * _Nullable error))completion;

- (void)fetchOrCreatePendingOrderWithItems:(NSArray<NSDictionary *> *)items
                                     amount:(double)amount
                                    address:(PPAddressModel * _Nullable)address
                            paymentMethodId:(nullable NSString *)paymentMethodId
                                  completion:(void (^)(PPOrder * _Nullable order, NSError * _Nullable error))completion;

/// Idempotent variant – pass a UUID that uniquely identifies this checkout attempt.
/// If an order with the same key already exists for the current user, it is returned
/// instead of creating a duplicate.  Pass nil to fall back to the legacy behaviour.
- (void)createPendingOrderWithItems:(NSArray<NSDictionary *> *)items
                              amount:(double)amount
                            address:(PPAddressModel * _Nullable)address
                    paymentMethodId:(nullable NSString *)paymentMethodId
                     idempotencyKey:(nullable NSString *)idempotencyKey
                          completion:(void (^)(PPOrder * _Nullable order, NSError * _Nullable error))completion;

- (void)fetchOrCreatePendingOrderWithItems:(NSArray<NSDictionary *> *)items
                                     amount:(double)amount
                                    address:(PPAddressModel * _Nullable)address
                            paymentMethodId:(nullable NSString *)paymentMethodId
                             idempotencyKey:(nullable NSString *)idempotencyKey
                                  completion:(void (^)(PPOrder * _Nullable order, NSError * _Nullable error))completion;

/// Validate that requested quantities are currently available in `petAccessories`.
/// `issues` contains dictionaries with: itemID, name, requestedQty, availableQty.
- (void)validateInventoryForItems:(NSArray<NSDictionary *> *)items
                       completion:(void (^)(BOOL inStock,
                                            NSArray<NSDictionary *> *issues,
                                            NSError * _Nullable error))completion;

- (PPOrderEligibilityDecision *)eligibilityForAction:(PPOrderCustomerActionType)actionType
                                               order:(PPOrder *)order
                                            requests:(NSArray<PPOrderSupportRequest *> * _Nullable)requests
                                       referenceDate:(NSDate *)referenceDate;

- (NSArray<PPOrderEligibilityDecision *> *)eligibilityDecisionsForOrder:(PPOrder *)order
                                                               requests:(NSArray<PPOrderSupportRequest *> * _Nullable)requests
                                                          referenceDate:(NSDate *)referenceDate;

- (NSArray<NSDictionary *> *)reasonOptionsForAction:(PPOrderCustomerActionType)actionType;

- (id<FIRListenerRegistration> _Nullable)listenToSupportRequestsForOrderID:(NSString *)orderID
                                                                     update:(void (^)(NSArray<PPOrderSupportRequest *> *requests, NSError * _Nullable error))update;

- (void)fetchSupportRequestsForOrderID:(NSString *)orderID
                            completion:(void (^)(NSArray<PPOrderSupportRequest *> *requests, NSError * _Nullable error))completion;

- (id<FIRListenerRegistration> _Nullable)listenToTimelineEventsForOrder:(PPOrder *)order
                                                                 update:(void (^)(NSArray<PPOrderTimelineEvent *> *events, NSError * _Nullable error))update;

- (void)fetchTimelineEventsForOrder:(PPOrder *)order
                         completion:(void (^)(NSArray<PPOrderTimelineEvent *> *events, NSError * _Nullable error))completion;

- (id<FIRListenerRegistration> _Nullable)listenToRequestEventsForOrderID:(NSString *)orderID
                                                                requestID:(NSString *)requestID
                                                                   update:(void (^)(NSArray<PPOrderTimelineEvent *> *events, NSError * _Nullable error))update;

- (void)fetchRequestEventsForOrderID:(NSString *)orderID
                            requestID:(NSString *)requestID
                           completion:(void (^)(NSArray<PPOrderTimelineEvent *> *events, NSError * _Nullable error))completion;

- (void)submitSupportDraft:(PPOrderSupportDraft *)draft
                  forOrder:(PPOrder *)order
                completion:(void (^)(PPOrderSupportRequest * _Nullable request,
                                     BOOL deduplicated,
                                     NSError * _Nullable error))completion;

- (void)uploadEvidenceImages:(NSArray<UIImage *> *)images
                    forOrder:(PPOrder *)order
             draftIdentifier:(NSString *)draftIdentifier
                    progress:(void (^ _Nullable)(double progress))progress
                  completion:(void (^)(NSArray<PPOrderSupportAttachment *> *attachments,
                                       NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
