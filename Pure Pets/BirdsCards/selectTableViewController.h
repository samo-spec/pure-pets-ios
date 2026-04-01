//
//  selectTableViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/07/2024.
//

#import <UIKit/UIKit.h>
#import "XLForm.h"
#import "CardModel.h"

NS_ASSUME_NONNULL_BEGIN

@protocol getdataback <NSObject>
- (void)setMotherId:(NSString *)motherID fromVC:(NSString *)fromVc;
- (void)setParentClass:(CardModel *)ParentClass fromVC:(NSString *)fromVc;
@end

@interface selectTableViewController : UIViewController <XLFormRowDescriptorViewController>

@property (strong, nonatomic) UITableView *selectTableView;
@property (nonatomic, weak) id <getdataback> delegate;
@property (weak, nonatomic) NSString *vcName;

// Legacy properties for compatibility
@property (strong, nonatomic) UISearchBar *searchBar;
@property (strong, nonatomic) UILabel *titleLabel;
@property (strong, nonatomic) UIView *topBarView;

@end

NS_ASSUME_NONNULL_END
