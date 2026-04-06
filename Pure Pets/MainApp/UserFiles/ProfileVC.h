//
//  ProfileVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/08/2024.
//

#import <UIKit/UIKit.h>
#import <Pure_Pets-Swift.h>
#import "RoundedImageViewWithShadow.h"
#import "CountryCodeModel.h"
#import "LeaveFeedbackViewController.h"
#import "AddressFormVC.h"

@protocol ProfileDelegate <NSObject>
- (void)logout;
- (void)refereshAvatar;
@end

@interface ProfileVC : UIViewController
@property (nonatomic, weak) id<ProfileDelegate> delegate;
@property (nonatomic, weak) TTGSnackbar *snakBar;
@end
