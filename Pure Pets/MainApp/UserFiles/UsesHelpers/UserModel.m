#import "UserModel.h"
#import <Pure_Pets-Swift.h>
#import <FirebaseAuth/FirebaseAuth.h>
#import <FirebaseFirestore/FirebaseFirestore.h>
#import <objc/runtime.h>

static const void *PPUserModelCoreKey = &PPUserModelCoreKey;

@interface UserModel ()
+ (instancetype)pp_modelWithCore:(PPUserKitUserModel *)core;
@end

@implementation UserModel

@dynamic onlineStatus, lastSeen, ID, UserName, UserEmail, FirstName, LastName, MobileNo;
@dynamic UserAbout, UserImageName, UserImageUrl, isOnline, loginDate, updatedAt, CountryID;
@dynamic PPUserTokenID, PPAdminTokenID, PPProTokenID, role, isAdmin, isSuperAdmin, isBlocked;
@dynamic accountStatus, prodectionStatus, canPostPetAdsFeature, canPostAdoptionFeature;
@dynamic canSellAccessoriesFeature, canOfferServicesFeature, canDeliveryFeature;
@dynamic canPharmacyFeature, canVetFeature, canUseStoriesFeature, canUseChatFeature;
@dynamic canAccessPremiumMarketplaceFeature, canAccessProviderMarketplaceFeature;
@dynamic partnerOnboardingVisible, partnerApplicationStatus, selectedPartnerType;
@dynamic canAccessPartnerAppPermission, canManageDeliveryPermission;
@dynamic canManageServiceProviderPermission, canManageVetPermission;
@dynamic canPostVetProfilePermission, canEditVetInfoPermission, canManagePetMedicinesPermission;
@dynamic subscriptionPlan, subscriptionStatus, subscriptionSource, postingBlocked;
@dynamic chatBlocked, purchaseBlocked, withdrawalBlocked, isEffectivelyBlocked;
@dynamic isPostingEffectivelyBlocked, isChatEffectivelyBlocked, isPurchaseEffectivelyBlocked;
@dynamic permissions, permissionsListener, canPostAds, canSellNew, canSellUsed, canAdoption;
@dynamic canManageStore, canModeration, canManageFood, canManageServices, canProduction;
@dynamic isAdminAll, isStoreManager, isFoodManager, isModerator, isOwner, isVet, plan;
@dynamic providerRatingValue, providerReviewCount, coverImageUrls, loginSource, Addresses;
@dynamic SelectedInstrument;

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self pp_setCore:[[PPUserKitUserModel alloc] init]];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [self init];
    if (self) {
        [self pp_setCore:[[PPUserKitUserModel alloc] initWithCoder:coder]];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [[self pp_core] encodeWithCoder:coder];
}

- (void)pp_setCore:(PPUserKitUserModel *)core {
    objc_setAssociatedObject(self, PPUserModelCoreKey, core, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (PPUserKitUserModel *)pp_core {
    PPUserKitUserModel *core = objc_getAssociatedObject(self, PPUserModelCoreKey);
    if (!core) {
        core = [[PPUserKitUserModel alloc] init];
        [self pp_setCore:core];
    }
    return core;
}

- (BOOL)isVerified {
    return [self pp_core].verified;
}

- (void)setVerified:(BOOL)verified {
    [self pp_core].verified = verified;
}

- (id)valueForKey:(NSString *)key {
    PPUserKitUserModel *core = [self pp_core];
    if ([core respondsToSelector:NSSelectorFromString(key)]) {
        return [core valueForKey:key];
    }
    return [super valueForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key {
    PPUserKitUserModel *core = [self pp_core];
    NSString *capitalizedKey = key.length > 0
        ? [key stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                       withString:[[key substringToIndex:1] uppercaseString]]
        : @"";
    SEL setter = capitalizedKey.length > 0
        ? NSSelectorFromString([NSString stringWithFormat:@"set%@:", capitalizedKey])
        : NULL;
    if (setter && [core respondsToSelector:setter]) {
        [core setValue:value forKey:key];
        return;
    }
    [super setValue:value forKey:key];
}

- (id)forwardingTargetForSelector:(SEL)selector {
    PPUserKitUserModel *core = [self pp_core];
    if ([core respondsToSelector:selector]) return core;
    return [super forwardingTargetForSelector:selector];
}

- (BOOL)respondsToSelector:(SEL)selector {
    return [super respondsToSelector:selector] || [[self pp_core] respondsToSelector:selector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *signature = [[self pp_core] methodSignatureForSelector:selector];
    return signature ?: [super methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    PPUserKitUserModel *core = [self pp_core];
    if ([core respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:core];
        return;
    }
    [self doesNotRecognizeSelector:invocation.selector];
}

+ (instancetype)pp_modelWithCore:(PPUserKitUserModel *)core {
    UserModel *model = [[self alloc] init];
    [model pp_setCore:core];
    return model;
}

- (instancetype)initWithDict:(NSDictionary *)dict {
    self = [self init];
    if (self) [self pp_setCore:[[PPUserKitUserModel alloc] initWithDict:dict ?: @{}]];
    return self;
}

- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot {
    self = [self init];
    if (self) [self pp_setCore:[[PPUserKitUserModel alloc] initWithSnapshot:snapshot]];
    return self;
}

+ (nullable instancetype)loadSavedUserWithUID:(NSString *)uid {
    PPUserKitUserModel *core = [[PPUserKitRuntime shared] loadCachedUserModelSynchronouslyFor:uid];
    return core ? [self pp_modelWithCore:core] : nil;
}

- (void)saveToDisk {
    // PPUserKit persists authenticated snapshots through its repository cache.
}

+ (void)clearCachedUserWithUID:(NSString *)uid {
    [[PPUserKitRuntime shared] removeCachedUserFor:uid completion:nil];
}

+ (instancetype)fromAuthUser:(FIRUser *)auth
                     rootDoc:(NSDictionary *)root
                 permissions:(NSDictionary<NSString *,NSNumber *> *)perms
                     claims:(NSDictionary *)claims {
    if (!auth) return nil;
    NSMutableDictionary *values = [root mutableCopy] ?: [NSMutableDictionary dictionary];
    values[@"ID"] = auth.uid ?: @"";
    if (auth.email.length > 0) values[@"UserEmail"] = auth.email;
    if (auth.displayName.length > 0) values[@"UserName"] = auth.displayName;
    if (auth.photoURL.absoluteString.length > 0) values[@"UserImageUrl"] = auth.photoURL.absoluteString;
    if (perms) values[@"permissions"] = perms;
    if (claims) values[@"claims"] = claims;
    return [[self alloc] initWithDict:values];
}

+ (void)loadCurrentUserModelWithCompletion:(void (^)(UserModel * _Nullable, NSError * _Nullable))completion {
    [[PPUserKitRuntime shared] loadCurrentUserModelWithCompletion:^(PPUserKitUserModel * _Nullable core, NSError * _Nullable error) {
        UserModel *model = core ? [self pp_modelWithCore:core] : nil;
        if (completion) completion(model, error);
    }];
}

@end
