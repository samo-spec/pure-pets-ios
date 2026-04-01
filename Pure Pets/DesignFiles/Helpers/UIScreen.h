//
//  UIScreen.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 06/08/2025.
//


// UIScreen+CornerRadius.h
#import <UIKit/UIKit.h>

@interface UIScreen (CornerRadius)
/// Reads the private `_displayCornerRadius` value (in points)
@property (nonatomic, readonly) CGFloat displayCornerRadius;
@end