//
//  UIButton.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 20/03/2025.
//


#import "UIButton+PressAnimation.h"

@implementation UIButton (TapAnimation)

- (void)addTapAnimation {
    [self addTarget:self action:@selector(animateButtonTouchDown) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(animateButtonTouchUp) forControlEvents:UIControlEventTouchUpInside];
    [self addTarget:self action:@selector(animateButtonTouchUp) forControlEvents:UIControlEventTouchUpOutside];
}

- (void)animateButtonTouchDown {
    [UIView animateWithDuration:0.1
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         self.transform = CGAffineTransformMakeScale(0.95, 0.95);
                     }
                     completion:nil];
}

- (void)animateButtonTouchUp {
    [UIView animateWithDuration:0.1
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         self.transform = CGAffineTransformIdentity;
                     }
                     completion:nil];
}

@end
