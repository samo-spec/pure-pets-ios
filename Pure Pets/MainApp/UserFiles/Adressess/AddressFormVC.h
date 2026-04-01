//
//  AddressFormVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/10/2025.
//


#import <UIKit/UIKit.h>
#import "XLForm.h"
#import "PPAddressModel.h"
#import "PPAddressesManager.h"
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AddressFormPresent) {
    AddressFormPresentPush,
    AddressFormPresentSheet,
};

// Delegate protocol for address form events
@class AddressFormVC;
@protocol AddressFormVCDelegate <NSObject>
@optional
/// Called when the user saves (adds or updates) an address.
- (void)addressFormVC:(AddressFormVC *)controller didSaveAddress:(PPAddressModel *)address;
/// Called when the user deletes an address.
- (void)addressFormVC:(AddressFormVC *)controller didDeleteAddress:(PPAddressModel *)address;
@end

/// View controller for adding/editing a shipping address using XLForm.
@interface AddressFormVC : XLFormViewController
@property (nonatomic, assign) AddressFormPresent addressFormPresent;

/// The address model being edited. If nil, the form is for adding a new address.
@property (nonatomic, strong, nullable) PPAddressModel *address;
/// Delegate to handle save/delete actions (e.g. inform a list view controller).
@property (nonatomic, weak, nullable) id<AddressFormVCDelegate> delegate;

// Designated initializer (if not using Storyboards).
// If `address` is nil, the form will be set up for adding a new address.
- (instancetype)initWithAddress:(nullable PPAddressModel *)address;

@end

NS_ASSUME_NONNULL_END
