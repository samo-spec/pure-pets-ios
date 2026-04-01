//
//  NewCardForm.h
//  projectxlforms
//
//  Created by IQRQA on 12/14/16.
//  Copyright © 2016 IQRQA. All rights reserved.
//




 
#import "importantFiles.h"
#import "CardModel.h"
#import "RelativeDateDescriptor.h"
#import "PPImageCollection.h"
#import "CardModel.h"
@protocol refreshNewDelegate <NSObject>
-(void)refreshView;
-(void)refreshSelectedChild;
-(void)updateViewDone;
-(void)referchChils:(BOOL)showHUD;
@end

//loadAllData

@interface NewCardForm : XLFormViewController<PPImageCollectionDelegate>
@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic, strong) PPImageCollection *imageCollection;
@property (nonatomic, weak) id <refreshNewDelegate> delegate;
@property (strong, nonatomic) CardModel *serverCardClass;
@property (strong, nonatomic) UIView *topView;
@property  (strong, nonatomic) NSString  *FromVC;
@property (copy, nonatomic) NSString *prefilledRingID;
@property (strong, nonatomic) UILabel *topTitle;

@end
