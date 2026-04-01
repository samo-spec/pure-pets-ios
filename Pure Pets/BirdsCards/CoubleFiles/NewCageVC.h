//
//  NewCageVC.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/07/2024.
//


#import <TZImagePickerController/TZImagePickerController.h>

#import "CageModel.h"
#import "selectTableViewController.h"
#import "importantFiles.h"

#import "importantFiles.h"
#import <Pure_Pets-Swift.h>
#import "FORScrollViewEmptyAssistant.h"

NS_ASSUME_NONNULL_BEGIN


@interface NewCageVC : UIViewController

@property (nonatomic, copy) NSArray<CageModel *> *CagedataSource;
@property (nonatomic, strong) CageModel *CageData;
@property (nonatomic, copy) NSString *FromAction;
@property (strong, nonatomic)  UIView *headerView;
@property (strong, nonatomic)  UIButton *FatherBTN;
@property (strong, nonatomic)  UIButton *MotherBTN;
@property (strong, nonatomic)  UIView *tioView;
@property (strong, nonatomic)  UIView *MotherView;
@property (strong, nonatomic)  UITableView *childsTableView;

@property (strong, nonatomic)  UILabel *noteLablel;
 
@property (copy, nonatomic) NSString *returnedMotherId;
@property (strong, nonatomic)  UIView *bottomBarView;
@property (strong, nonatomic)  UIImageView *imageView;


@property (strong, nonatomic)  UILabel *MotherKind;
@property (strong, nonatomic)  UIImageView *MotherImageView;

@property (strong, nonatomic)  UILabel *FatherKind;
@property (strong, nonatomic)  UIImageView *FatherImageView;
@property (strong, nonatomic)  UILabel *fatherRingID;
@property (strong, nonatomic)  UILabel *motherRingID;

@property (strong, nonatomic)  UITextField *RingID;
@property (strong, nonatomic)  UIButton *tempSaveBTN;
@property (strong, nonatomic)  UIImageView *DNAImageViw;

@property (strong, nonatomic)  UITextField *CageName;
@property (strong, nonatomic)  UILabel *headerTitleLabel;

@end

NS_ASSUME_NONNULL_END





