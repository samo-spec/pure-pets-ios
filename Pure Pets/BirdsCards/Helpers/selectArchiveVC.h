//
//  selectArchiveVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/07/2024.
//


#import "selectChildCell.h"

#import "viewDataVC.h"
#import <Pure_Pets-Swift.h>
#import "ABMenuTableViewCell.h"
#import "ABCellMenuView.h"
#import "FORScrollViewEmptyAssistant.h"
#import "CCActivityHUD.h"



NS_ASSUME_NONNULL_BEGIN
@protocol ReloadFromArchieSelectDelegate <NSObject>
-(void)ReloadDataSourseDelegate;
@end

@interface selectArchiveVC : UIViewController<goToNewCardDelegate>
@property (nonatomic, weak) id <ReloadFromArchieSelectDelegate> delegate;

@property (strong, nonatomic) UITableView *selectTableView;
@property (weak, nonatomic) NSString *vcName;
@property (strong, nonatomic) UILabel *titleLabel;
@property (strong, nonatomic) UIView *topBarView;
@property (nonatomic,strong) NSArray<CardModel *> *cardsArray;
@property (nonatomic,strong) ArchiveModel *archiveClass;
@property (strong, nonatomic) UIView *addConteinerView;
@property (strong, nonatomic) UITextField *RingID;
@property (strong, nonatomic) UILabel *archiveDate;
@property (strong, nonatomic) UIButton *AddBTN;
@property (strong, nonatomic) UITableView *archiveTableView;
@property (strong, nonatomic) UIView *archiveView;
@property (nonatomic,strong) NSMutableArray<ArchiveModel *>   *archiveArray;
@property (strong, nonatomic) UILabel *titleLa;

@end

NS_ASSUME_NONNULL_END

