#import <Foundation/Foundation.h>
#import "PPUserKitCompatibility.h"

@class FIRUser;
@class FIRDocumentSnapshot;
@protocol FIRListenerRegistration;
@class PPAddressModel;
@class UserPaymentInstrument;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, UserLoginSource) {
    UserLoginSourceUnknown = 0,
    UserLoginSourcePPUsers = 1,
    UserLoginSourcePPAdmin = 2
};

typedef NS_ENUM(NSInteger, OnlineStatus) {
    OnlineStatusOffline = 0,
    OnlineStatusOnline
};

@interface UserModel : NSObject <NSSecureCoding>

@property (nonatomic, assign) OnlineStatus onlineStatus;
@property (nonatomic, strong, nullable) NSDate *lastSeen;
@property (nonatomic, copy) NSString *ID;
@property (nonatomic, copy) NSString *UserName;
@property (nonatomic, copy) NSString *UserEmail;
@property (nonatomic, copy, nullable) NSString *FirstName;
@property (nonatomic, copy, nullable) NSString *LastName;
@property (nonatomic, copy, nullable) NSString *MobileNo;
@property (nonatomic, copy, nullable) NSString *UserAbout;
@property (nonatomic, copy, nullable) NSString *UserImageName;
@property (nonatomic, strong, nullable) NSURL *UserImageUrl;
@property (nonatomic, assign) BOOL isOnline;
@property (nonatomic, strong, nullable) NSDate *loginDate;
@property (nonatomic, strong, nullable) NSDate *updatedAt;
@property (nonatomic, assign) NSInteger CountryID;
@property (nonatomic, copy) NSString *PPUserTokenID;
@property (nonatomic, copy) NSString *PPAdminTokenID;
@property (nonatomic, copy) NSString *PPProTokenID;
@property (nonatomic, assign) UserRole role;
@property (nonatomic, assign) BOOL isAdmin;
@property (nonatomic, assign) BOOL isSuperAdmin;
@property (nonatomic, assign) BOOL isBlocked;

@property (nonatomic, copy) NSString *accountStatus;
@property (nonatomic, copy) NSString *prodectionStatus;
@property (nonatomic, assign) BOOL canPostPetAdsFeature;
@property (nonatomic, assign) BOOL canPostAdoptionFeature;
@property (nonatomic, assign) BOOL canSellAccessoriesFeature;
@property (nonatomic, assign) BOOL canOfferServicesFeature;
@property (nonatomic, assign) BOOL canDeliveryFeature;
@property (nonatomic, assign) BOOL canPharmacyFeature;
@property (nonatomic, assign) BOOL canVetFeature;
@property (nonatomic, assign) BOOL canUseStoriesFeature;
@property (nonatomic, assign) BOOL canUseChatFeature;
@property (nonatomic, assign) BOOL canAccessPremiumMarketplaceFeature;
@property (nonatomic, assign) BOOL canAccessProviderMarketplaceFeature;
@property (nonatomic, assign) BOOL partnerOnboardingVisible;
@property (nonatomic, copy) NSString *partnerApplicationStatus;
@property (nonatomic, copy, nullable) NSString *selectedPartnerType;
@property (nonatomic, assign) BOOL canAccessPartnerAppPermission;
@property (nonatomic, assign) BOOL canManageDeliveryPermission;
@property (nonatomic, assign) BOOL canManageServiceProviderPermission;
@property (nonatomic, assign) BOOL canManageVetPermission;
@property (nonatomic, assign) BOOL canPostVetProfilePermission;
@property (nonatomic, assign) BOOL canEditVetInfoPermission;
@property (nonatomic, assign) BOOL canManagePetMedicinesPermission;
@property (nonatomic, copy) NSString *subscriptionPlan;
@property (nonatomic, copy) NSString *subscriptionStatus;
@property (nonatomic, copy) NSString *subscriptionSource;
@property (nonatomic, assign) BOOL postingBlocked;
@property (nonatomic, assign) BOOL chatBlocked;
@property (nonatomic, assign) BOOL purchaseBlocked;
@property (nonatomic, assign) BOOL withdrawalBlocked;
@property (nonatomic, readonly) BOOL isEffectivelyBlocked;
@property (nonatomic, readonly) BOOL isPostingEffectivelyBlocked;
@property (nonatomic, readonly) BOOL isChatEffectivelyBlocked;
@property (nonatomic, readonly) BOOL isPurchaseEffectivelyBlocked;
@property (nonatomic, copy) NSDictionary<NSString *, NSNumber *> *permissions;
@property (nonatomic, strong, nullable) id<FIRListenerRegistration> permissionsListener;

@property (nonatomic, readonly) BOOL canPostAds;
@property (nonatomic, readonly) BOOL canSellNew;
@property (nonatomic, readonly) BOOL canSellUsed;
@property (nonatomic, readonly) BOOL canAdoption;
@property (nonatomic, readonly) BOOL canManageStore;
@property (nonatomic, readonly) BOOL canModeration;
@property (nonatomic, readonly) BOOL canManageFood;
@property (nonatomic, readonly) BOOL canManageServices;
@property (nonatomic, readonly) BOOL canProduction;
@property (nonatomic, readonly) BOOL isAdminAll;
@property (nonatomic, readonly) BOOL isStoreManager;
@property (nonatomic, readonly) BOOL isFoodManager;
@property (nonatomic, readonly) BOOL isModerator;
@property (nonatomic, readonly) BOOL isOwner;
@property (nonatomic, readonly) BOOL isVet;
@property (nonatomic, assign, getter=isVerified) BOOL verified;
@property (nonatomic, copy, nullable) NSString *plan;
@property (nonatomic, assign) double providerRatingValue;
@property (nonatomic, assign) NSInteger providerReviewCount;
@property (nonatomic, strong, nullable) NSArray<NSString *> *coverImageUrls;
@property (nonatomic, assign) UserLoginSource loginSource;
@property (nonatomic, strong) NSMutableArray<PPAddressModel *> *Addresses;
@property (nonatomic, strong, nullable) UserPaymentInstrument *SelectedInstrument;

- (instancetype)initWithDict:(NSDictionary *)dict;
- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;
- (NSDictionary *)toDictionary;
- (void)syncToFirestoreWithCompletion:(void(^)(NSError * _Nullable error))completion;
- (void)SYNC:(void(^)(NSError * _Nullable error))completion;
- (void)fetchPermissionsWithCompletion:(void (^_Nullable)(NSDictionary<NSString *, NSNumber *> *perms,
                                                         NSError * _Nullable error))completion;
- (void)startListeningPermissionsWithChange:(void (^)(NSDictionary<NSString *, NSNumber *> *perms))changeBlock;
- (void)stopListeningPermissions;
- (void)setPermissionNamed:(NSString *)permName
                   allowed:(BOOL)allowed
                completion:(void (^)(NSError * _Nullable error))completion;
- (BOOL)hasPermissionNamed:(NSString *)permName;
- (BOOL)hasAnyPermissionInKeys:(NSArray<NSString *> *)permNames;

+ (nullable instancetype)loadSavedUserWithUID:(NSString *)uid;
- (void)saveToDisk;
+ (void)clearCachedUserWithUID:(NSString *)uid;

+ (instancetype)fromAuthUser:(FIRUser *)auth
                     rootDoc:(nullable NSDictionary *)root
                 permissions:(nullable NSDictionary<NSString *, NSNumber *> *)perms
                     claims:(nullable NSDictionary *)claims;
+ (void)loadCurrentUserModelWithCompletion:(void(^)(UserModel *_Nullable u,
                                                    NSError *_Nullable err))completion;

- (NSString *)bestDisplayName;
- (NSString *)PPBestDisplayName;
- (NSString *)userName;
- (NSString *)userEmail;
- (nullable NSString *)firstName;
- (nullable NSString *)lastName;
- (nullable NSString *)mobileNo;
- (nullable NSString *)userAbout;
- (nullable NSString *)userImageName;
- (nullable NSURL *)userImageUrl;
- (NSInteger)countryID;
- (NSString *)ppUserTokenID;
- (NSMutableArray<PPAddressModel *> *)addresses;
- (nullable UserPaymentInstrument *)selectedInstrument;

@end

NS_ASSUME_NONNULL_END
