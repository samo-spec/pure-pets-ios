//
//  LoginViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/08/2024.
//

#import "BKCircularLoadingButton.h"
#import <Pure_Pets-Swift.h>
 
#import "YYAnimatedImageView.h"

#import "LocationPickerViewController.h"
#import "XLFormPhoneCodeItem.h"
#import "RoundedImageViewWithShadow.h"
#import "CountryCodeModel.h"
#import "LeaveFeedbackViewController.h"
#import "AddressFormVC.h"



@protocol ProfileDelegate <NSObject>
- (void)logout;
- (void)refereshAvatar;
@end

@interface ProfileVC : XLFormViewController<XLFormViewControllerDelegate>
@property (nonatomic, weak) id <ProfileDelegate> delegate;
@property (weak, nonatomic)  TTGSnackbar *snakBar;
@property(weak, nonatomic) XLFormRowDescriptor *addressPickerRow;
@end



