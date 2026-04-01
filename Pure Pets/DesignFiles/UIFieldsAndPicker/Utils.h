//
//  Utils.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/08/2025.
//


// Utils.h
#import <UIKit/UIKit.h>

@interface Utils : NSObject

+ (UIButton *_Nullable)createButtonWithTitle:(nullable NSString *)title
                            iconName:(NSString *)iconName 
                          iconScale:(UIImageSymbolScale)iconScale
                        cornerRadius:(CGFloat)cornerRadius
                          tintColor:(nullable UIColor *)tintColor
                     backgroundColor:(nullable UIColor *)backgroundColor
                         useAutoLayout:(BOOL)useAutoLayout
                               target:(nullable id)target
                               action:(nullable SEL)action;

+ (UIImage *)imageWithName:(NSString *)imageName  Weight:(UIImageSymbolWeight)weight andScale:(UIImageSymbolScale)scale andSize:(float)size;


@end
