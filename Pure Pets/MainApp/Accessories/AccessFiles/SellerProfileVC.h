//
//  SellerProfileVC.h
//  Pure Pets
//
//  Premium Seller Profile UI
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PetAccessory;
@class UserModel;

@protocol SellerProfileVCDelegate <NSObject>
@optional
- (void)sellerProfileDidTapContact:(UserModel *)seller;
- (void)sellerProfileDidTapCall:(UserModel *)seller;
- (void)sellerProfileDidSelectItem:(id)item;
@end

@interface SellerProfileVC : UIViewController

@property (nonatomic, strong) UserModel *seller;
@property (nonatomic, strong) NSArray<PetAccessory *> *sellerItems;
@property (nonatomic, copy, nullable) NSString *providerCategoryIdentifier;
@property (nonatomic, weak) id<SellerProfileVCDelegate> delegate;
@property (nonatomic, weak) UIViewController *parentVC;

@end

NS_ASSUME_NONNULL_END
