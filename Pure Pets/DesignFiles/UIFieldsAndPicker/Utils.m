//
//  Utils.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/08/2025.
//


// Utils.m
// Utils.m
#import "Utils.h"

@implementation Utils

+ (UIButton *)createButtonWithTitle:(NSString *)title iconName:(NSString *)iconName iconScale:(UIImageSymbolScale)iconScale cornerRadius:(CGFloat)cornerRadius tintColor:(UIColor *)tintColor backgroundColor:(UIColor *)backgroundColor useAutoLayout:(BOOL)useAutoLayout target:(id)target action:(SEL)action
{
    
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        
        // Frame or Auto Layout
        if (useAutoLayout) {
            button.translatesAutoresizingMaskIntoConstraints = NO;
        } else {
            button.frame = CGRectMake(0, 0, 120, 44); // default size
        }
        
        // Title
        if (title.length > 0) {
            [button setTitle:title forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        }
        
        // Tint color (apply if set)
        if (tintColor) {
            button.tintColor = tintColor;
        }
        
        // Image
        if (iconName) {
           
            
            // Set symbol size (e.g. 16pt)
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16
                                                                                                   weight:UIImageSymbolWeightRegular
                                                                                                    scale:iconScale];

            UIImage *image = [UIImage systemImageNamed:iconName withConfiguration:config];
            
            if (tintColor) {
                // Make sure image uses template rendering
                image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            }
            
            
            [button setImage:image forState:UIControlStateNormal];
            button.imageView.contentMode = UIViewContentModeScaleAspectFit;
            
            if (title.length > 0) {
                button.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
                button.imageEdgeInsets = UIEdgeInsetsMake(0, -6, 0, 0);
            }
        }
        
        // Corner radius
        if (cornerRadius > 0) {
            button.layer.cornerRadius = cornerRadius;
            button.layer.masksToBounds = YES;
        }
        
        // Background color (default clear)
        if (backgroundColor) {
            button.backgroundColor = backgroundColor;
        } else {
            button.backgroundColor = UIColor.clearColor;
        }
        
        // Add action if provided
        if (target && action) {
            [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
        }
        
        return button;
}

+ (UIImage *)imageWithName:(NSString *)imageName  Weight:(UIImageSymbolWeight)weight andScale:(UIImageSymbolScale)scale andSize:(float)size
{
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:size
                                                                                           weight:weight
                                                                                            scale:scale];

    return  [UIImage systemImageNamed:imageName withConfiguration:config];
}
@end

