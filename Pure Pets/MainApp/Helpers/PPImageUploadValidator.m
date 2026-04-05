//
//  PPImageUploadValidator.m
//  Pure Pets
//
//  Pre-upload image validation utility.
//  Lightweight client-side gate before Firebase Storage uploads.
//

#import "PPImageUploadValidator.h"

/// Minimum dimension in points — rejects tiny/blank images.
static CGFloat const kPPMinImageDimension = 100.0;

/// Maximum compressed JPEG size in bytes (20 MB).
static NSUInteger const kPPMaxCompressedBytes = 20 * 1024 * 1024;

/// JPEG compression quality used for size estimation.
static CGFloat const kPPSizeCheckCompressionQuality = 0.80;

/// Maximum allowed aspect ratio (width/height or height/width).
/// Anything wider/taller than 5:1 is suspicious (strip images, glitches).
static CGFloat const kPPMaxAspectRatio = 5.0;

@implementation PPImageUploadValidator

#pragma mark - Public API

+ (PPImageValidationResult)validateImage:(nullable UIImage *)image {
    if (!image) {
        return PPImageValidationResultNilImage;
    }

    // --- Dimension check ---
    CGSize size = image.size;
    if (size.width < kPPMinImageDimension || size.height < kPPMinImageDimension) {
        return PPImageValidationResultTooSmall;
    }

    // --- Aspect ratio check ---
    CGFloat ratio = (size.width > size.height)
        ? (size.width / size.height)
        : (size.height / size.width);
    if (ratio > kPPMaxAspectRatio) {
        return PPImageValidationResultBadAspectRatio;
    }

    // --- Encoding & size check ---
    // UIImageJPEGRepresentation is the same encoder used before actual upload,
    // so this gives a realistic byte-size estimate.
    NSData *jpeg = UIImageJPEGRepresentation(image, kPPSizeCheckCompressionQuality);
    if (!jpeg) {
        return PPImageValidationResultEncodingFailed;
    }

    if (jpeg.length > kPPMaxCompressedBytes) {
        return PPImageValidationResultTooLarge;
    }

    return PPImageValidationResultValid;
}

+ (PPImageValidationResult)validateImages:(NSArray<UIImage *> *)images
                              failedIndex:(nullable NSInteger *)failedIndex {
    for (NSInteger i = 0; i < (NSInteger)images.count; i++) {
        PPImageValidationResult result = [self validateImage:images[i]];
        if (result != PPImageValidationResultValid) {
            if (failedIndex) {
                *failedIndex = i;
            }
            return result;
        }
    }
    return PPImageValidationResultValid;
}

+ (BOOL)isImageValidForUpload:(nullable UIImage *)image {
    return [self validateImage:image] == PPImageValidationResultValid;
}

#pragma mark - Localized Messages

+ (NSString *)localizedMessageForResult:(PPImageValidationResult)result {
    switch (result) {
        case PPImageValidationResultValid:
            return @"";

        case PPImageValidationResultNilImage:
            return NSLocalizedString(
                @"No image was selected. Please pick a photo and try again.",
                @"PPImageUploadValidator — nil image"
            );

        case PPImageValidationResultTooSmall:
            return NSLocalizedString(
                @"The selected image is too small. Please use a photo that is at least 100×100 pixels.",
                @"PPImageUploadValidator — too small"
            );

        case PPImageValidationResultTooLarge:
            return NSLocalizedString(
                @"The selected image is too large (over 20 MB). Please choose a smaller photo or reduce its quality.",
                @"PPImageUploadValidator — too large"
            );

        case PPImageValidationResultEncodingFailed:
            return NSLocalizedString(
                @"This image format is not supported. Please use a JPEG or PNG photo.",
                @"PPImageUploadValidator — encoding failed"
            );

        case PPImageValidationResultBadAspectRatio:
            return NSLocalizedString(
                @"The selected image has an unusual shape. Please use a standard photo.",
                @"PPImageUploadValidator — bad aspect ratio"
            );
    }

    return NSLocalizedString(
        @"The selected image could not be validated. Please try a different photo.",
        @"PPImageUploadValidator — unknown"
    );
}

@end
