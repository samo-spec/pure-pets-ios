//
//  KBSwipeCell.h
//  KBSwipeTableviewCell
//
//  Created by kobe on 2017/3/28.
//  Copyright © 2017年 kobe. All rights reserved.
//



@protocol  KBSwipeCellDelegate <NSObject>
- (void)resetCellCloseStatusIndexPath:(NSIndexPath *)indexPath;
@end

@interface KBSwipeCell : UITableViewCell
@property (nonatomic, weak) id<KBSwipeCellDelegate> delegate;
@property (nonatomic, strong) NSIndexPath *indexPath;
- (void)resetCellCloseStatus;
- (void)setConstraintsToShowAllButtons:(BOOL)animated notifyDelegateDidOpen:(BOOL)notifyDelegate;
@property (nonatomic, strong) UIView *myContentView;
@end
