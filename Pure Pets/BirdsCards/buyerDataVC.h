//
//  buyerDataVC.h
//  projectxlforms
//
//  Created by IQRQA on 12/14/16.
//  Copyright © 2016 IQRQA. All rights reserved.
//


#import "GSIndeterminateProgressView.h"

 
#import "importantFiles.h"
#import "BuyerCell.h"
#import "RelativeDateDescriptor.h"
#import "CardModel.h"


@interface buyerDataVC : XLFormViewController
@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (strong, nonatomic) UIButton *closeBtnIB;
@property (strong, nonatomic) CardModel *serverCardClass;
@property (strong, nonatomic) UIView *topView;
@property  CardSection  lastLocation;
@property (strong, nonatomic) UILabel *topTitle;
@end

