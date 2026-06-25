//
//  ProviderStorefrontProductsVC.h
//  Pure Pets
//

#import "SellerProfileVC.h"

NS_ASSUME_NONNULL_BEGIN

@class PetAccessory;
@class UserModel;

@interface ProviderStorefrontProductsVC : SellerProfileVC

- (instancetype)initWithSeller:(nullable UserModel *)seller
                         items:(NSArray<PetAccessory *> *)items
            categoryIdentifier:(nullable NSString *)categoryIdentifier NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
