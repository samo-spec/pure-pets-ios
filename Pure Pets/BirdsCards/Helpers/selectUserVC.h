//
//  selectUserVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/07/2024.
//


#import "selectTableViewCell.h"
 

NS_ASSUME_NONNULL_BEGIN

@protocol UserDataProtocol <NSObject>
-(void)selectUser:(UserModel *)selectedUserClass vcName:(NSString *)vcName;
@end

@interface selectUserVC : UIViewController <XLFormRowDescriptorViewController>
@property (strong, nonatomic) UITableView *selectTableView;
@property (strong, nonatomic) UISearchBar *searchBar;
@property (nonatomic, weak) id <UserDataProtocol> delegate;
@property (weak, nonatomic) NSString *vcName;
@property (strong, nonatomic) UILabel *titleLabel;
@property (strong, nonatomic) UIView *topBarView;

@end

NS_ASSUME_NONNULL_END
