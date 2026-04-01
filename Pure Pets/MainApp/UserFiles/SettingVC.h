//
//  SettingVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/08/2024.
//


#import "BKCircularLoadingButton.h"
#import <Pure_Pets-Swift.h>
 


NS_ASSUME_NONNULL_BEGIN
//static NSString * const kUserInterfaceStyleKey = @"UserInterfaceStyle";


@protocol settingDelegate <NSObject>
-(void)changeLanguageWithCode:(int)code;
@end
 
@interface SettingVC : XLFormViewController
@property (nonatomic, weak) id <settingDelegate> delegate;
@property (strong, nonatomic) IBOutlet UILabel *mTitleLabel;
@property ( nonatomic,strong) TTGSnackbar *snakBar;
@property (strong, nonatomic) IBOutlet UIButton *loginBurron;
@property (weak, nonatomic) IBOutlet UIView *topView;

- (UIUserInterfaceStyle)loadUserInterfaceStyle;
- (void)saveUserInterfaceStyle:(UIUserInterfaceStyle)style;

@end
NS_ASSUME_NONNULL_END


