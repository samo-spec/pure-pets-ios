//
//  PPInsetLabel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/08/2025.
//

#import "PPInsetLabel.h"
// PPInsetLabel.m
@implementation PPInsetLabel
- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)n {
    CGRect inset = UIEdgeInsetsInsetRect(bounds, self.textInsets);
    CGRect rect  = [super textRectForBounds:inset limitedToNumberOfLines:n];
    rect.origin.x -= self.textInsets.left;
    rect.origin.y -= self.textInsets.top;
    rect.size.width  += (self.textInsets.left + self.textInsets.right);
    rect.size.height += (self.textInsets.top  + self.textInsets.bottom);
    return rect;
}
- (void)drawTextInRect:(CGRect)rect {
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, self.textInsets)];
}
- (CGSize)intrinsicContentSize {
    CGSize s = [super intrinsicContentSize];
    s.width  += self.textInsets.left + self.textInsets.right;
    s.height += self.textInsets.top  + self.textInsets.bottom;
    return s;
}

@end






















//
//  UILabel+LineSpacing.m
//  PurePets
//

 

@implementation UILabel (LineSpacing)

- (void)setLineSpacing:(CGFloat)spacing {
    if (!self.text || self.text.length == 0) return;
    [self setLineSpacing:spacing text:self.text];
}

- (void)setLineSpacing:(CGFloat)spacing text:(NSString *)text {
    if (!text) return;

    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineSpacing = spacing;
    style.alignment = self.textAlignment;

    NSDictionary *attrs = @{
        NSFontAttributeName: self.font ?: [UIFont systemFontOfSize:17],
        NSForegroundColorAttributeName: self.textColor ?: UIColor.labelColor,
        NSParagraphStyleAttributeName: style
    };

    self.attributedText = [[NSAttributedString alloc] initWithString:text attributes:attrs];
}

@end
