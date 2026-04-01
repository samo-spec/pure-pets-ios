//
//  CardsCell.h
//  collevtionViewWithSearchBar
//
//  Created by Homam on 2015-01-02.
//  Copyright (c) 2015 Homam. All rights reserved.
//


#import "importantFiles.h"
#import <Pure_Pets-Swift.h>
#import "FTPopOverMenu.h"
#import "TQImageViewer.h"
#import "CCActivityHUD.h"
#import "YIInnerShadowView.h"
#import "PressButton.h"
#import <AVFoundation/AVFoundation.h>
#import "PPSalesPDFGenerator.h"

@class BuyerCell;
#import "GSIndeterminateProgressView.h"
 

@protocol BuyerCellDelegate <NSObject>
-(void)BuyerWhatsAppMessage:(BuyerModel *)b_model;
-(void)Buyercall:(BuyerModel *)b_model;
-(void)returnCard:(BuyerModel *)b_model  buyerCell:(BuyerCell *)buyerCell;
-(void)showDetails:(BuyerModel *)b_model cardModel:(CardModel *)cardModel;
- (void)exportSalesBillForBuyer:(BuyerModel *)buyer card:(CardModel *)card  sender:(UIButton *)sender;
-(void)shareCard:(CardModel *)card andImage:(UIImage *)image;
@end

@interface BuyerCell : UICollectionViewCell
@property(nonatomic, weak) id<BuyerCellDelegate> delegate;
@property (weak, nonatomic) IBOutlet UILabel *cardTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *buyerNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *cellDateLabel;
@property (weak, nonatomic) IBOutlet UILabel *mobileNumberLabel;
@property (weak, nonatomic) IBOutlet UILabel *RingIDLabel;
@property (strong, nonatomic) UIButton *cardDetailsBTN;
@property (strong, nonatomic) UIImageView *mainImageView;

@property (weak, nonatomic) IBOutlet UIView *topView;
@property (weak, nonatomic)  BuyerModel *B_model;
@property (weak, nonatomic) IBOutlet UILabel *cellAmountLabel;
@property (weak, nonatomic)  CardModel *cardModel;
@property (nonatomic, strong) GSIndeterminateProgressView *uploadProgressView;


@end






