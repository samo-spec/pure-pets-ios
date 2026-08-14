#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class PetAccessory;
@class UserModel;

NS_ASSUME_NONNULL_BEGIN

@interface PPProviderStorefrontProviderRecord : NSObject

@property (nonatomic, copy) NSString *ownerID;
@property (nonatomic, strong) NSArray<PetAccessory *> *items;
@property (nonatomic, strong, nullable) UserModel *user;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *aboutText;
@property (nonatomic, copy) NSString *cityText;
@property (nonatomic, copy) NSString *avatarURLString;
@property (nonatomic, copy) NSString *coverURLString;
@property (nonatomic, assign) NSInteger productCount;
@property (nonatomic, strong, nullable) NSDate *latestCreatedAt;
@property (nonatomic, assign) BOOL verified;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, assign) double ratingValue;
@property (nonatomic, assign) NSInteger reviewCount;

@end

/// Data and side-effect boundary for the SwiftUI provider storefront surfaces.
/// It intentionally retains the existing Objective-C managers as the authority
/// for inventory, user resolution, Firestore access, and chat navigation.
@interface PPProviderStorefrontDataBridge : NSObject

+ (void)fetchProviderRecordsForCategoryIdentifier:(NSString *)categoryIdentifier
                                        completion:(void (^)(NSArray<PPProviderStorefrontProviderRecord *> *records,
                                                             NSError * _Nullable error))completion
    NS_SWIFT_NAME(fetchProviderRecords(categoryIdentifier:completion:));

+ (void)fetchStorefrontItemsForOwnerID:(NSString *)ownerID
                    categoryIdentifier:(nullable NSString *)categoryIdentifier
                            seededItems:(NSArray<PetAccessory *> *)seededItems
                             completion:(void (^)(NSArray<PetAccessory *> *items,
                                                  NSError * _Nullable error))completion
    NS_SWIFT_NAME(fetchStorefrontItems(ownerID:categoryIdentifier:seededItems:completion:));

+ (NSString *)sellerIdentifierForUser:(nullable UserModel *)user
    NS_SWIFT_NAME(sellerIdentifier(for:));
+ (NSString *)sellerAboutForUser:(nullable UserModel *)user
    NS_SWIFT_NAME(sellerAbout(for:));
+ (BOOL)isSellerActive:(nullable UserModel *)user
    NS_SWIFT_NAME(isSellerActive(_:));
+ (void)openChatWithSeller:(UserModel *)seller
         fromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(openChat(seller:from:));

@end

NS_ASSUME_NONNULL_END
