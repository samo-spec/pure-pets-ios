//
//  CabelCollectionViewCell.h
//  collevtionViewWithSearchBar
//
//  Created by Homam on 2015-01-02.
//  Copyright (c) 2015 Homam. All rights reserved.
//


#import "ChildModel.h"


#import <Pure_Pets-Swift.h>
#import "FTPopOverMenu.h"
#import "ZMJTipView.h"

@protocol showCHildsDelegate <NSObject>
- (void)showChildsForCage:(CageModel *)cage;
-(void)showAddChild:(CageModel *)CageData rowIndex:(long)rowIndex ChildArr:(NSArray<ChildModel *> *)ChildsArray cardsArray:(NSArray<CardModel *> *)cardsArray indexPath:(NSIndexPath *)indexPath;
-(void)showParentData:(NSString *)ParentID;
-(void)showEggDateController:(CageModel *)CageData;
-(void)deleteEditCageOptions:(long)index CageData:(CageModel *)CageData cellView:(UIView *)cellView cellIndexPath:(NSIndexPath *)cellIndexPath;
@end

@interface CabelCollectionViewCell : UICollectionViewCell
@property (nonatomic, strong) ZMJTipView *tipView;
@property (strong, nonatomic) IBOutlet UIView *deletedView;
@property (strong, nonatomic) IBOutlet UILabel *deletedLabel;
@property (strong, nonatomic) NSString *fatherDeleteReason;
@property (strong, nonatomic) NSString *motherDeleteReason;
@property (strong, nonatomic) IBOutlet UIView *deletedViewFather;
@property (strong, nonatomic) IBOutlet UILabel *deletedLabelFather;

-(void)showDeletedTip;
-(void)showDeletedTipFather;

@property (nonatomic,strong) NSArray<CageModel *>        *CagedataSource;
@property NSArray<ChildModel *> *ChildsArray;
@property (nonatomic,strong) NSArray<CardModel *>    *cardsDataSource;
@property CageModel *CageData;
@property (nonatomic, weak) id <showCHildsDelegate> delegate;
@property long rowIndex;
@property NSIndexPath *indexPath;
- (IBAction)deleteInfoBTN:(id)sender;

@property (weak, nonatomic) IBOutlet UILabel *FatherRingID;
@property (weak, nonatomic) IBOutlet UILabel *MotherRingID;
@property (weak, nonatomic) IBOutlet UILabel *CageName;
@property (weak, nonatomic) IBOutlet UILabel *ChildsCount;
@property (weak, nonatomic) IBOutlet UIView *cellBottomView;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImage;
@property (weak, nonatomic) IBOutlet UIImageView *fatherImageView;
@property (weak, nonatomic) IBOutlet UIImageView *motherImageView;
@property (strong, nonatomic) IBOutlet UIButton *showChildBTN;
@property (strong, nonatomic) IBOutlet UIView *fatherTopView;
@property (strong, nonatomic) IBOutlet UIButton *addChildsBTN;
@property (strong, nonatomic) IBOutlet UILabel *remainDaysFirstEgg;
@property (strong, nonatomic) IBOutlet UIButton *editDatesBTN;

@property (strong, nonatomic) IBOutlet UIView *motherMovedView;
@property (strong, nonatomic) IBOutlet UILabel *motherMovedLabel;

@property (strong, nonatomic) IBOutlet UIView *fatherMovedView;
@property (strong, nonatomic) IBOutlet UILabel *fatherMovedLabel;
@end


