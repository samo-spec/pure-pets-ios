//
//  Watermark.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/02/2025.
//

#import <Foundation/Foundation.h>

@interface UIImage (Watermark)

- (UIImage *)imageWithWatermark:(UIImage *)watermark imageFrame:(CGRect)imageFrame watermarkFrame:(CGRect)watermarkFrame;
- (UIImage *)imageWithTextWatermark:(NSString *)text font:(UIFont *)font color:(UIColor *)color textFrame:(CGRect)textFrame;

@end
