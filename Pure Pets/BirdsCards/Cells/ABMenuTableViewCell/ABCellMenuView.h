//
//  ABCellMenuView.h
//  Test
//
//  Created by Alex Bumbu on 17/02/15.
//  Copyright (c) 2015 Alex Bumbu. All rights reserved.
//


#import "UIView+XIB.h"
#import "importantFiles.h"

@protocol ABCellMenuViewDelegate;

@interface ABCellMenuView : UIView

@property (nonatomic, assign) id<ABCellMenuViewDelegate> _Nullable delegate;
@property (nonatomic, strong) NSIndexPath * _Nullable indexPath;
@property NSArray<ImageModel *> * _Nullable ImagesArr;
@property  CardModel* _Nullable cardmodel;

@end


@protocol ABCellMenuViewDelegate <NSObject>

@optional
- (void)cellMenuViewMoreBtnTapped:(ABCellMenuView *_Nullable)menuView;
- (void)cellMenuViewFlagBtnTapped:(ABCellMenuView *_Nullable)menuView;
- (void)cellMenuViewDeleteBtnTapped:(ABCellMenuView *_Nullable)menuView;
-(void)goToviewDataVC:(NSArray<ImageModel *> *_Nullable)ImagesArr cardClass:(CardModel *_Nullable)cardClass;
@end
