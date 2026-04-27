//
//  PPHomeInsetLabel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/26/26.
//

#import "PPHomeInsetLabel.h"
@implementation PPHomeInsetLabel

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _contentInsets = UIEdgeInsetsMake(6.0, 10.0, 6.0, 10.0);
    }
    return self;
}

- (CGSize)intrinsicContentSize
{
    CGSize size = [super intrinsicContentSize];
    size.width += self.contentInsets.left + self.contentInsets.right;
    size.height += self.contentInsets.top + self.contentInsets.bottom;
    return size;
}

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines
{
    CGRect insetBounds = UIEdgeInsetsInsetRect(bounds, self.contentInsets);
    CGRect textRect = [super textRectForBounds:insetBounds limitedToNumberOfLines:numberOfLines];
    textRect.origin.x -= self.contentInsets.left;
    textRect.origin.y -= self.contentInsets.top;
    textRect.size.width += self.contentInsets.left + self.contentInsets.right;
    textRect.size.height += self.contentInsets.top + self.contentInsets.bottom;
    return textRect;
}

- (void)drawTextInRect:(CGRect)rect
{
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, self.contentInsets)];
}

@end
