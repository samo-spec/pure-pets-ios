//
//  UIButton.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 10/08/2025.
//


// UIButton+TitlePosition.m
#import "UIButton.h"

@implementation UIButton (TitlePosition)

- (void)setBtnTitle:(NSString *)title onPosition:(ButtonTitlePosition)position {
    // Set title
    [self setTitle:title forState:UIControlStateNormal];
    self.titleLabel.font = [GM MidFontWithSize:13];
    // Reset insets
    self.titleEdgeInsets = UIEdgeInsetsZero;
    self.imageEdgeInsets = UIEdgeInsetsZero;
    
    [self bringSubviewToFront:self.titleLabel];
    // Force layout so we can get correct sizes
    [self layoutIfNeeded];
    
    CGFloat spacing = 2.0; // space between image & title
    CGSize imageSize = self.imageView.frame.size;
    CGSize titleSize = [self.titleLabel.text sizeWithAttributes:@{NSFontAttributeName:self.titleLabel.font}];
    
    switch (position) {
        case ButtonTitlePositionTop:
            self.titleEdgeInsets = UIEdgeInsetsMake(-(imageSize.height + spacing),
                                                    -imageSize.width,
                                                    0,
                                                    0);
            self.imageEdgeInsets = UIEdgeInsetsMake(0,
                                                    0,
                                                    -(titleSize.height + spacing),
                                                    -titleSize.width);
            break;
            
        case ButtonTitlePositionBottom:
            self.titleEdgeInsets = UIEdgeInsetsMake((imageSize.height + spacing),
                                                    -imageSize.width,
                                                    0,
                                                    0);
            self.imageEdgeInsets = UIEdgeInsetsMake(-(titleSize.height + spacing),
                                                    0,
                                                    0,
                                                    -titleSize.width);
            break;
    }
}

@end
