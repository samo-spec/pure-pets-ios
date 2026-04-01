//
//  UIButton.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 10/08/2025.
//


// UIButton+TitlePosition.h
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, ButtonTitlePosition) {
    ButtonTitlePositionTop,
    ButtonTitlePositionBottom
};

@interface UIButton (TitlePosition)

- (void)setBtnTitle:(NSString *)title onPosition:(ButtonTitlePosition)position;

@end
