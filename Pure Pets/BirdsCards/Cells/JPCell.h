//
//  JPVPNetEasyTableViewCell.h
//  JPVideoPlayerDemo
//
//  Created by Memet on 2018/4/24.
//  Copyright © 2018 NewPan. All rights reserved.
//



@class JPCell;

@protocol JPCellDelegate<NSObject>

@optional
- (void)cellPlayButtonDidClick:(JPCell *)cell;

@end

@interface JPCell : UICollectionViewCell

@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property NSString *VidThum;
@property (weak, nonatomic) IBOutlet UIImageView *videoPlayView;

@property(nonatomic, weak) id<JPCellDelegate> delegate;

@property(nonatomic, strong)NSIndexPath *indexPath;

@end


