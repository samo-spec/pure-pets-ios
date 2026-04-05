//
//  SettingVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/08/2024.
//


#import <Pure_Pets-Swift.h>



NS_ASSUME_NONNULL_BEGIN

@protocol settingDelegate <NSObject>
-(void)changeLanguageWithCode:(int)code;
@end
 
@interface SettingVC : UIViewController
@property (nonatomic, weak) id <settingDelegate> delegate;

- (UIUserInterfaceStyle)loadUserInterfaceStyle;
- (void)saveUserInterfaceStyle:(UIUserInterfaceStyle)style;
@property IBOutlet  UILabel *mTitleLabel;
@end
NS_ASSUME_NONNULL_END
