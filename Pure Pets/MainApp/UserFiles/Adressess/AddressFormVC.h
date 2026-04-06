//
//  AddressFormVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/10/2025.
//

#import <UIKit/UIKit.h>
#import "PPAddressModel.h"
#import "PPAddressesManager.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AddressFormPresent) {
    AddressFormPresentPush,
    AddressFormPresentSheet,
};

@class AddressFormVC;
@protocol AddressFormVCDelegate <NSObject>
@optional
- (void)addressFormVC:(AddressFormVC *)controller didSaveAddress:(PPAddressModel *)address;
- (void)addressFormVC:(AddressFormVC *)controller didDeleteAddress:(PPAddressModel *)address;
@end

@interface AddressFormVC : UIViewController

@property (nonatomic, assign) AddressFormPresent addressFormPresent;
@property (nonatomic, strong, nullable) PPAddressModel *address;
@property (nonatomic, weak, nullable) id<AddressFormVCDelegate> delegate;
@property (nonatomic, strong, readonly) UITableView *tableView;

- (instancetype)initWithAddress:(nullable PPAddressModel *)address;

@end

NS_ASSUME_NONNULL_END
