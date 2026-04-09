//
//  PPProfileBaseCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/9/26.
//


#import "PPProfileBaseCell.h"
@implementation PPProfileBaseCell

- (void)setFrame:(CGRect)frame
{
    frame.origin.x = kPPProfileCellHorizontalInset;
    frame.size.width -= kPPProfileCellHorizontalInset * 2.0;
    frame.origin.y += kPPProfileCellVerticalInset * 0.5;
    frame.size.height -= kPPProfileCellVerticalInset;
    if (frame.size.width  < 0.0) frame.size.width  = 0.0;
    if (frame.size.height < 0.0) frame.size.height = 0.0;
    [super setFrame:frame];
}

@end