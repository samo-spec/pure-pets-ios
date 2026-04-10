//
//  UserChatsViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/07/2025.
//


// UserChatsViewController.h
// Pure Pets
//
// Created by Mohamed Ahmed on 26/07/2025.
//

#import <UIKit/UIKit.h>
#import "selectUserVC.h"
#import "ChCell.h"


typedef NS_ENUM(NSInteger, UserChatsState) {
    UserChatsStateLoading,
    UserChatsStateEmpty,
    UserChatsStateLoaded,
    UserChatsStateError
};

@interface UserChatsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSMutableArray<UserModel *> *availableUsers; // header animation (150)
@property (nonatomic, strong) UserModel *selectedUser;
- (void)startNewChat;
@end
