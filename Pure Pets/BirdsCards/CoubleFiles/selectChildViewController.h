//
//  selectChildViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/07/2024.
//

#import <UIKit/UIKit.h>
#import "selectChildCell.h"
#import "ChildModel.h"
#import "viewDataVC.h"
#import <Pure_Pets-Swift.h>
#import "Language.h"
#import "buyerDataVC.h"
#import "PPChildCell.h"
#import "PPS.h"
@class CardModel;
@class CageModel;
NS_ASSUME_NONNULL_BEGIN



@interface selectChildViewController : UIViewController
 @property (strong, nonatomic) NSString *vcName;
@property (strong, nonatomic) UILabel *titleLabel;
@property (strong, nonatomic) UIView *topBarView;
@property (nonatomic,strong) NSMutableArray<ChildModel *> *ChildsdataSource;
@property (nonatomic,strong) NSArray<CardModel *>  *cardsArray;
 
@property  (nonatomic,strong)CageModel *CageData;
@property (strong, nonatomic) UILabel *descLabel;
@property (strong, nonatomic) UIButton *closeButton;
@property (strong, nonatomic) UIButton *closeBTN;
  @end

NS_ASSUME_NONNULL_END




