//
//  UIScreen.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/08/2025.
//


// UIScreen+CornerRadius.m
#import "UIScreen.h"

@implementation UIScreen (CornerRadius)

- (CGFloat)displayCornerRadius {
    // KVC for the underscored ivar
    NSNumber *radius = [self valueForKey:@"_displayCornerRadius"];
    return radius ? radius.floatValue : 0.0;
}

@end
