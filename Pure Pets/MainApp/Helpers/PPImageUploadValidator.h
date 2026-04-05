//
//  PPImageUploadValidator.h
//  Pure Pets
//
//  Pre-upload image validation utility.
//  Performs lightweight client-side checks before sending images to
//  Firebase Storage. This does NOT replace server-side moderation
//  (Cloud Vision SafeSearch) but prevents obviously invalid uploads
//  from consuming bandwidth and API quota.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Validation result codes returned by PPImageUploadValidator.
 */
typedef NS_ENUM(NSInteger, PPImageValidationResult) {
    /// Image passed all client-side checks.
    PPImageValidationResultValid = 0,
    /// Image reference is nil.
    PPImageValidationResultNilImage,
    /// Image dimensions are too small (likely not a real photo).
    PPImageValidationResultTooSmall,
    /// Compressed image data exceeds the maximum allowed size.
    PPImageValidationResultTooLarge,
    /// Image could not be encoded to JPEG (corrupt or unsupported format).
    PPImageValidationResultEncodingFailed,
    /// Image has a suspicious aspect ratio (extreme panorama or strip).
    PPImageValidationResultBadAspectRatio,
};

/**
 * PPImageUploadValidator
 *
 * Stateless utility for client-side image validation before upload.
 * All methods are class methods — no instantiation required.
 *
 * Usage:
 *   PPImageValidationResult result = [PPImageUploadValidator validateImage:image];
 *   if (result != PPImageValidationResultValid) {
 *       NSString *msg = [PPImageUploadValidator localizedMessageForResult:result];
 *       // show error to user
 *   }
 */
@interface PPImageUploadValidator : NSObject

/**
 * Validates an image for upload suitability.
 *
 * Checks performed:
 *  - Non-nil image
 *  - Minimum dimensions (100×100 pt)
 *  - Maximum compressed size (20 MB at 0.8 quality)
 *  - Aspect ratio sanity (max 5:1 ratio)
 *  - JPEG encoding feasibility
 *
 * @param image The UIImage to validate.
 * @return PPImageValidationResultValid if acceptable, otherwise a specific failure code.
 */
+ (PPImageValidationResult)validateImage:(nullable UIImage *)image;

/**
 * Validates an array of images. Returns the result of the first failing image.
 *
 * @param images Array of UIImages to validate.
 * @param failedIndex On failure, set to the index of the first invalid image. May be NULL.
 * @return PPImageValidationResultValid if ALL images pass, otherwise the first failure code.
 */
+ (PPImageValidationResult)validateImages:(NSArray<UIImage *> *)images
                              failedIndex:(nullable NSInteger *)failedIndex;

/**
 * Returns a user-facing localized error message for a validation result.
 *
 * @param result The validation result code.
 * @return A localized string suitable for display in an alert.
 */
+ (NSString *)localizedMessageForResult:(PPImageValidationResult)result;

/// Convenience: YES if the image passes all checks.
+ (BOOL)isImageValidForUpload:(nullable UIImage *)image;

@end

NS_ASSUME_NONNULL_END
