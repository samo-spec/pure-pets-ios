#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>
#import "BarcodeGenerator.h"


@implementation BarcodeGenerator

+ (UIImage *)generateBarcode:(NSString *)data width:(CGFloat)width height:(CGFloat)height {
    // 1. Create the barcode filter
    CIFilter *barcodeFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"]; // Or CICode128BarcodeGenerator, CIAztecCodeGenerator
    if (!barcodeFilter) {
        NSLog(@"Error: Could not create barcode filter.");
        return nil;
    }

    // 2. Set the input data
    NSData *dataForBarcode = [data dataUsingEncoding:NSUTF8StringEncoding];
    [barcodeFilter setValue:dataForBarcode forKey:@"inputMessage"];
    [barcodeFilter setValue:@"H" forKey:@"inputCorrectionLevel"]; // Optional error correction level (L, M, Q, H)

    // 3. Get the generated image
    CIImage *barcodeImage = [barcodeFilter outputImage];

    // 4. Scale the image to the desired size (VERY IMPORTANT!)
    //    If you don't scale, the image will be tiny and blurry
    CGRect extent = CGRectIntegral(barcodeImage.extent);
    CGFloat scale = MIN(width/CGRectGetWidth(extent), height/CGRectGetHeight(extent));

    // Create bitmap; draw into it
    size_t widthScale = CGRectGetWidth(extent) * scale;
    size_t heightScale = CGRectGetHeight(extent) * scale;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray(); // Monochromatic
    CGContextRef bitmapRef = CGBitmapContextCreate(nil, widthScale, heightScale, 8, 0, colorSpace, (CGBitmapInfo)kCGImageAlphaNone);
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef bitmapImage = [context createCGImage:barcodeImage fromRect:extent];
    CGContextSetInterpolationQuality(bitmapRef, kCGInterpolationNone);
    CGContextScaleCTM(bitmapRef, scale, scale);
    CGContextDrawImage(bitmapRef, extent, bitmapImage);

    // Get the image from the context
    CGImageRef scaledImage = CGBitmapContextCreateImage(bitmapRef);

    // Release resources
    CGContextRelease(bitmapRef);
    CGImageRelease(bitmapImage);
    CGColorSpaceRelease(colorSpace);

    // 5. Convert to UIImage
    UIImage *resultImage = [UIImage imageWithCGImage:scaledImage];

    // 6. Release scaled image
    CGImageRelease(scaledImage);

    return resultImage;
}

@end
