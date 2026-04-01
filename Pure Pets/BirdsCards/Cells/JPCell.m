//
//  JPVPNetEasyTableViewCell.m
//  JPVideoPlayerDemo
//
//  Created by Memet on 2018/4/24.
//  Copyright © 2018 NewPan. All rights reserved.
//

#import "JPCell.h"
#import "UIView+HXExtension.h"

@implementation JPCell

- (void)setIndexPath:(NSIndexPath *)indexPath{
    _indexPath = indexPath;
    _playButton.hx_centerY = self.contentView.hx_centerY;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    _playButton.hx_centerY = self.contentView.hx_centerY;
}
-(void)prepareForReuse
{
    [super prepareForReuse];
    _playButton.hx_centerY = self.contentView.hx_centerY;
}

- (IBAction)playButtonDidClick:(id)sender {
    if (self.delegate && [self.delegate respondsToSelector:@selector(cellPlayButtonDidClick:)]) {
        [self.delegate cellPlayButtonDidClick:self];
    }
}

@end


