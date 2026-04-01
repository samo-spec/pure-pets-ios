//
//  UserContactView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 19/08/2025.
//


//
//  UserContactView.h
//  Pure Pets
//

#import <UIKit/UIKit.h>

@class UserModel;

NS_ASSUME_NONNULL_BEGIN

@interface UserContactView : UIButton

@property (nonatomic, strong) UIView *emptyCardBellowButtons;
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UIButton *chatButton;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UIImageView *avatarImageView;

/// Configure with UserModel
- (void)configureWithUser:(UserModel *)user
             chatCallback:(dispatch_block_t)chatBlock
             callCallback:(dispatch_block_t)callBlock;

@end


NS_ASSUME_NONNULL_END
