//
//  ServiceModel.h
//  Pure Pets
//
//  Service offer model — maps to "serviceOffers" Firestore collection.
//  Upgraded to match PPServiceModel architecture (availability, status, subscription).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ServiceType) {
    ServiceTypeTraining = 0,
    ServiceTypeGrooming = 1
};

@interface ServiceModel : NSObject <NSCopying>

// ── Core Fields ──
@property (nonatomic, copy)   NSString *serviceID;
@property (nonatomic, copy)   NSString *serviceOwnerID;
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *desc;              ///< Maps to Firestore "description"
@property (nonatomic, copy, readonly) NSString *descriptionText; ///< Alias for desc (PPServiceModel compat)
@property (nonatomic, assign) double price;
@property (nonatomic, copy)   NSString *currency;
@property (nonatomic, copy)   NSString *category;
@property (nonatomic, copy)   NSString *categoryID;
@property (nonatomic, assign) NSInteger petMainKindID;
@property (nonatomic, assign) ServiceType type;
@property (nonatomic, copy, nullable) NSString *serviceTypeText;
@property (nonatomic, copy, nullable) NSString *imageURL;
@property (nonatomic, copy)   NSString *blurHash;
@property (nonatomic, assign) BOOL isAvailable;            ///< Provider-controlled availability toggle

// ── Rating / Reviews ──
@property (nonatomic, strong, nullable) NSNumber *ratingValue;
@property (nonatomic, assign) NSInteger reviewCount;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *reviews;

// ── System Status (read-only — set by admin/backend) ──
@property (nonatomic, assign, readonly) BOOL isDisabled;
@property (nonatomic, assign, readonly) BOOL isBlocked;
@property (nonatomic, assign, readonly) BOOL isDeleted;
@property (nonatomic, copy, readonly)   NSString *verificationStatus;

// ── Subscription (read-only — managed by backend/admin) ──
@property (nonatomic, copy, readonly)   NSString *subscriptionPlan;
@property (nonatomic, copy, readonly)   NSString *subscriptionStatus;
@property (nonatomic, assign, readonly) BOOL subscriptionActive;
@property (nonatomic, strong, readonly, nullable) NSDate *subscriptionStartDate;
@property (nonatomic, strong, readonly, nullable) NSDate *subscriptionEndDate;

// ── Timestamps ──
@property (nonatomic, strong, nullable) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *updatedAt;

// ── Backward Compat (kept for Firestore round-trip) ──
@property (nonatomic, strong, nullable) NSDate *availableDate;  ///< Legacy — superseded by isAvailable
@property (nonatomic, strong, nullable) NSDate *timestamp;      ///< Legacy creation marker
@property (nonatomic, copy, nullable)   NSString *availabilityStatus; ///< Legacy string status
@property (nonatomic, strong) NSDictionary<NSString *, id> *extraFields;

// ── Search ──
@property (nonatomic, readonly) NSString *searchTitle;

// ── Serialization ──
- (instancetype)initWithDictionary:(NSDictionary *)dict documentID:(nullable NSString *)documentID;
+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(nullable NSString *)serviceID;
- (NSDictionary *)toDictionary;
- (NSDictionary *)providerToDictionary;

// ── Helpers ──
- (NSString *)localizedTypeName;
- (NSString *)localizedVerificationStatus;
- (NSString *)localizedAvailabilityStatus;
- (BOOL)hasDisplayableRating;
- (NSString *)localizedRatingBadgeText;
- (NSString *)localizedRatingSummaryText;
/// YES if not deleted, not blocked, not disabled, and provider has set available.
- (BOOL)isLive;

@end

NS_ASSUME_NONNULL_END
