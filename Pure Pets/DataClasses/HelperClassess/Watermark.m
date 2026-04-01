//
//  Watermark.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 18/02/2025.
//

#import "Watermark.h"

@implementation UIImage (Watermark)

// MARK: - Image Watermark

- (UIImage *)imageWithWatermark:(UIImage *)watermark imageFrame:(CGRect)imageFrame watermarkFrame:(CGRect)watermarkFrame {
    UIGraphicsBeginImageContextWithOptions(imageFrame.size, NO, 0.0); // Use scale 0.0 for retina
    [self drawInRect:imageFrame];
    [watermark drawInRect:watermarkFrame];

    UIImage *watermarkedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return watermarkedImage;
}

// MARK: - Text Watermark

- (UIImage *)imageWithTextWatermark:(NSString *)text font:(UIFont *)font color:(UIColor *)color textFrame:(CGRect)textFrame {
    UIGraphicsBeginImageContextWithOptions(self.size, NO, 0.0); // Use scale 0.0 for retina
    [self drawInRect:CGRectMake(0, 0, self.size.width, self.size.height)];

    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color
    };

    [text drawInRect:textFrame withAttributes:attributes];

    UIImage *watermarkedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return watermarkedImage;
}

@end
