//
//  GM.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 05/01/2025.
//
/*
 F9F9F9
 F4F4ED
 */



#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCrypto.h>
#import "YYWebImageManager.h"
#import "YYImageCache.h"
#import "YYWebImageOperation.h"
#import "UIImageView+YYWebImage.h"
#import "YYMemoryCache.h"
#import "YYDiskCache.h"
//64605 1621158
 
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

NSString *const kUserNameRow = @"UserNameRow";
NSString *const kMobileNoRow = @"MobileNoRow";
NSString *const kuserIDRow = @"userIDRow";
NSString *const kuserImageRow = @"userImageRow";
NSString *const kfirstNameRow = @"firstNameRow";
NSString *const kLastNameRow = @"LastNameRow";
NSString *const kUserEmailRow = @"UserEmailRow";
NSString *const kUserAboutRow = @"UserAboutRow";
NSString *const kcodeRow = @"codeRow";

static char kGMActivityOverlayAssocKey;      // association key
static const NSInteger GMActivityAnimTag = 900001; // tag for the LOTAnimationView

typedef void (^ImageCompletionBlock)(UIImage * _Nullable image, NSError * _Nullable error);


@interface GM()
{
    FIRStorage *storage;
    FIRStorageReference *storageRef;
}
@end


@implementation GM

+(void)compressVideoAtURL:(NSURL *)inputURL completion:(void (^)(NSURL * _Nonnull, NSError * _Nonnull))completion
{
    
}
+ (void)pp_setImageURL:(NSString *)urlString
             imageView:(UIImageView *)imageView
           placeholder:(NSString *)placeholder
{
    NSURL *url = [NSURL URLWithString:urlString];
    
    // Add activity indicator
    imageView.sd_imageIndicator = [SDWebImageActivityIndicator mediumIndicator];
    
    // SD options
    SDWebImageOptions options =
        SDWebImageRetryFailed |
        SDWebImageHighPriority |
        SDWebImageScaleDownLargeImages |    // Avoid huge image crashes
        SDWebImageContinueInBackground |
        SDWebImageProgressiveLoad;          // Progressive JPEG loading
    
    [imageView sd_setImageWithURL:url
                 placeholderImage:[UIImage imageNamed:placeholder]
                          options:options
                         progress:nil
                        completed:^(UIImage * _Nullable image,
                                    NSError * _Nullable error,
                                    SDImageCacheType cacheType,
                                    NSURL * _Nullable imageURL)
    {
        if (error) {
            NSLog(@"SD Load error: %@", error);
            return;
        }
        
        // Fade-in animation ONLY when loaded from network
        if (cacheType == SDImageCacheTypeNone && image) {
            imageView.alpha = 0.0;
            imageView.transform = CGAffineTransformMakeScale(0.97, 0.97);
            
            [UIView animateWithDuration:0.25
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                imageView.alpha = 1.0;
                imageView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
    }];
}

static char kShimmerLayerKey;

+ (void)setImageFromFirebaseURLString:(NSString *)urlString
                            imageView:(UIImageView *)imageView
                              phImage:(NSString * _Nullable)phImage
                          showShimmer:(BOOL)showShimmer
                           completion:(_Nullable ImageCompletionBlock)completion
{
    ////NSLog(@"[ImageLoader] 🔥 setImageFromFirebaseURLString -> %@", urlString);

    if (!imageView) {
        ////NSLog(@"[ImageLoader] ❌ imageView is nil");
        if (completion) completion(nil, nil);
        return;
    }

    if (urlString.length == 0) {
        ////NSLog(@"[ImageLoader] ⚠️ Empty URL");
        if(phImage)
        {
            UIImage *placeholder = [UIImage imageNamed:phImage];
            dispatch_async(dispatch_get_main_queue(), ^{
                imageView.image = placeholder;
            });
        }
        
        if (completion) completion(nil, [NSError errorWithDomain:@"ImageLoader"
                                                            code:0
                                                        userInfo:@{NSLocalizedDescriptionKey:@"Empty URL"}]);
        return;
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        ////NSLog(@"[ImageLoader] ❌ Invalid URL format");
        UIImage *placeholder = [UIImage imageNamed:phImage];
        dispatch_async(dispatch_get_main_queue(), ^{
            imageView.image = placeholder;
        });
        if (completion) completion(nil, [NSError errorWithDomain:@"ImageLoader"
                                                            code:1
                                                        userInfo:@{NSLocalizedDescriptionKey:@"Invalid URL"}]);
        return;
    }

    __weak typeof(imageView) weakImageView = imageView;
    __weak typeof(self) weakSelf = self;

    // Cache check
    YYWebImageManager *manager = [YYWebImageManager sharedManager];
    NSString *imageKey = [manager cacheKeyForURL:url];
    UIImage *cachedImage = [manager.cache getImageForKey:imageKey];

    if (cachedImage) {
        ////NSLog(@"[ImageLoader] 📦 Loaded from cache -> %@", imageKey);
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakImageView) iv = weakImageView;
            if (iv) {
                [weakSelf pp_removeShimmerFromView:iv];
                [weakSelf pp_animateImageView:iv withImage:cachedImage];
            }
            if (completion) completion(cachedImage, nil);
        });
        return;
    }

    // Placeholder + shimmer
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakImageView) iv = weakImageView;
        if (iv) {
            iv.image = [UIImage imageNamed:phImage];
            if (showShimmer) {
                ////NSLog(@"[ImageLoader] ✨ Shimmer ON");
                [weakSelf pp_addShimmerToView:iv];
            }
        }
    });

    // Download from Firebase URL
    ////NSLog(@"[ImageLoader] 🌐 Downloading from Firebase...");
    [imageView setImageWithURL:url
                       placeholder:nil
                           options:(YYWebImageOptionSetImageWithFadeAnimation |
                                    YYWebImageOptionProgressiveBlur |
                                    YYWebImageOptionShowNetworkActivity)
                        completion:^(UIImage * _Nullable image,
                                     NSURL * _Nonnull imageURL,
                                     YYWebImageFromType from,
                                     YYWebImageStage stage,
                                     NSError * _Nullable error)
    {
        __strong typeof(weakImageView) iv = weakImageView;
        __strong typeof(weakSelf) strongSelf = weakSelf;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (iv) {
                [strongSelf pp_removeShimmerFromView:iv];
                ////NSLog(@"[ImageLoader] ✨ Shimmer OFF");
            }
        });

        if (error) {
            ////NSLog(@"[ImageLoader] ❌ Download error: %@", error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }

        if (image) {
            ////NSLog(@"[ImageLoader] ✅ Image loaded (From: %ld)", (long)from);
            [manager.cache setImage:image forKey:imageKey];
            if (completion) completion(image, nil);
        } else {
            ////NSLog(@"[ImageLoader] ⚠️ No image returned");
            if (completion) completion(nil, [NSError errorWithDomain:@"ImageLoader"
                                                                code:2
                                                            userInfo:@{NSLocalizedDescriptionKey:@"No image returned"}]);
        }
    }];
}

#pragma mark - Fancy show animation
+ (void)pp_animateImageView:(UIImageView *)imageView withImage:(UIImage *)image {
    imageView.image = image;
    imageView.alpha = 0.0;
    imageView.transform = CGAffineTransformMakeScale(0.96, 0.96);
    [UIView animateWithDuration:0.35
                          delay:0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.25
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        imageView.alpha = 1.0;
        imageView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Shimmer helpers
+ (void)pp_addShimmerToView:(UIView *)view {
    // Avoid duplicates
    if (objc_getAssociatedObject(view, &kShimmerLayerKey)) return;

    CAGradientLayer *shimmer = [CAGradientLayer layer];
    shimmer.frame = view.bounds;
    shimmer.startPoint = CGPointMake(0.0, 0.5);
    shimmer.endPoint   = CGPointMake(1.0, 0.5);

    UIColor *base = [UIColor colorWithWhite:0.90 alpha:1.0];
    UIColor *highlight = [UIColor colorWithWhite:1.00 alpha:1.0];
    shimmer.colors = @[(id)base.CGColor, (id)highlight.CGColor, (id)base.CGColor];
    shimmer.locations = @[@0.0, @0.5, @1.0];

    // Animation
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"locations"];
    anim.fromValue = @[@-0.3, @-0.1, @0.2];
    anim.toValue   = @[@0.8, @1.0, @1.2];
    anim.duration  = 1.2;
    anim.repeatCount = HUGE_VALF;

    [shimmer addAnimation:anim forKey:@"pp.shimmer"];
    shimmer.name = @"pp.shimmer.layer";

    // Insert above image contents
    [view.layer addSublayer:shimmer];

    // Keep a ref so we can remove later
    objc_setAssociatedObject(view, &kShimmerLayerKey, shimmer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Keep it sized correctly if bounds change (simple approach)
    dispatch_async(dispatch_get_main_queue(), ^{
        shimmer.frame = view.bounds;
    });
}

+ (void)pp_removeShimmerFromView:(UIView *)view {
    CAGradientLayer *shimmer = objc_getAssociatedObject(view, &kShimmerLayerKey);
    if (shimmer) {
        [shimmer removeAllAnimations];
        [shimmer removeFromSuperlayer];
        objc_setAssociatedObject(view, &kShimmerLayerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}



#pragma mark - Unified Loader (Thread-Safe, Smooth, No Flicker)

+ (void)fetchImageFromURLString:(NSString *)urlString
                        intoView:(UIImageView * _Nullable)imageView
                     placeholder:(NSString * _Nullable)placeholderName
                      completion:(ImageCompletionBlock _Nullable)completion
{
    if (!imageView) return;

    UIImage *placeholder = placeholderName.length ? [UIImage imageNamed:placeholderName] : nil;

    // Handle invalid URLs fast
    if (urlString.length == 0) {
        imageView.image = placeholder;
        if (completion) completion(placeholder, [NSError errorWithDomain:@"ImageLoader"
                                                                    code:0
                                                                userInfo:@{NSLocalizedDescriptionKey:@"Empty URL"}]);
        return;
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        imageView.image = placeholder;
        if (completion) completion(placeholder, [NSError errorWithDomain:@"ImageLoader"
                                                                    code:1
                                                                userInfo:@{NSLocalizedDescriptionKey:@"Invalid URL"}]);
        return;
    }

    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;

    YYWebImageOptions options =
        YYWebImageOptionProgressiveBlur |
        YYWebImageOptionSetImageWithFadeAnimation |
        YYWebImageOptionShowNetworkActivity |
        YYWebImageOptionAllowBackgroundTask |
        YYWebImageOptionAvoidSetImage; // We’ll set manually after decoding
   /* requestImageWithURL:url
                     placeholder:placeholder
                         options:options
                        progress:nil
                       transform:nil
                      completion:^(UIImage * _Nullable image, NSURL * _Nonnull url,
                                   YYWebImageFromType from, YYWebImageStage stage, NSError * _Nullable error)
    // Use YYWebImage’s built-in async decoding and cache/ */
    __weak typeof(imageView) weakImageView = imageView;
    [imageView setImageWithURL:url placeholder:placeholder options:options progress:nil transform:nil completion:^(UIImage * _Nullable image, NSURL * _Nonnull url, YYWebImageFromType from, YYWebImageStage stage, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(placeholder, error);
            return;
        }
        __strong typeof(weakImageView) imageView = weakImageView;
        if (image && stage == YYWebImageStageFinished) {
            // Smooth transition – no blocking decode
            imageView.image = image;
            if (completion) completion(image, nil);
        }
    }];
}

+ (void)setImageFromUrlString:(NSString *)urlString
                    imageView:(UIImageView *)imageView
                      phImage:(NSString * _Nullable)phImage
                  showShimmer:(BOOL)showShimmer
                   completion:(ImageCompletionBlock)completion
{
    if (!imageView) {
        if (completion) completion(nil, nil);
        return;
    }

    // Cancel any previous request tied to this imageView
    [imageView cancelCurrentImageRequest];

    __weak typeof(imageView) weakImageView = imageView;
    __weak typeof(self) weakSelf = self;

    // Handle empty or invalid URL quickly
    if (urlString.length == 0) {
        UIImage *ph = phImage.length ? ([UIImage imageNamed:phImage] ?: [UIImage systemImageNamed:phImage]) : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            weakImageView.image = ph;
            if (completion) completion(ph, nil);
        });
        return;
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        UIImage *ph = phImage.length ? ([UIImage imageNamed:phImage] ?: [UIImage systemImageNamed:phImage]) : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            weakImageView.image = ph;
            if (completion) completion(ph, nil);
        });
        return;
    }

    UIImage *placeholder = phImage.length ? ([UIImage imageNamed:phImage] ?: [UIImage systemImageNamed:phImage]) : nil;

    YYWebImageManager *manager = [YYWebImageManager sharedManager];
    NSString *imageKey = [manager cacheKeyForURL:url];

    // ✅ Check cache asynchronously to avoid blocking main thread
    [manager.cache getImageForKey:imageKey withType:YYImageCacheTypeAll withBlock:^(UIImage * _Nullable image, YYImageCacheType type) {
         

        if (image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                __strong typeof(weakImageView) iv = weakImageView;
                if (iv) {
                    [strongSelf pp_removeShimmerFromView:iv];
                    iv.image = image;
                }
                if (completion) completion(image, nil);
            });
            return;
        }

        // Not cached → set placeholder + shimmer
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            __strong typeof(weakImageView) iv = weakImageView;
            if (iv) {
                iv.image = placeholder;
                iv.alpha = 1.0;
                if (showShimmer) {
                    [strongSelf pp_addShimmerToView:iv];
                }
            }
        });

      
        YYWebImageOptions options =
           SDWebImageScaleDownLargeImages | YYWebImageOptionSetImageWithFadeAnimation; // We’ll set manually after decoding
         
        [imageView setImageWithURL:url placeholder:placeholder options:options progress:nil transform:nil completion:^(UIImage * _Nullable image, NSURL * _Nonnull url, YYWebImageFromType from, YYWebImageStage stage, NSError * _Nullable error) {
 
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                __strong typeof(weakImageView) iv = weakImageView;
                [strongSelf pp_removeShimmerFromView:iv];
            });

            if (error) {
                if (completion) completion(nil, error);
                return;
            }

            if (image && stage == YYWebImageStageFinished) {
                [manager.cache setImage:image forKey:imageKey];
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakImageView) iv = weakImageView;
                    if (iv) iv.image = image;
                    if (completion) completion(image, nil);
                });
            }
        }];
    }];
}

#pragma mark - Convenience wrappers

// Drop-in replacement for your old "get" (no imageView, returns image or placeholder; no cancel)
+ (void)getImageFromUrlString:(NSString *)urlString
                      phImage:(NSString * _Nullable)phImage
                   completion:(ImageCompletionBlock)completion
{
    [self fetchImageFromURLString:urlString
                         intoView:nil
                      placeholder:phImage
                       completion:completion];
}

// Drop-in replacement for your old "set" (into a view, cancels ongoing, fade-in anim)
+ (void)setImageFromUrlString:(NSString *)urlString
                    imageView:(UIImageView *)imageView
                      phImage:(NSString * _Nullable)phImage
                   completion:(ImageCompletionBlock)completion
{
    /*
     [self fetchImageFromURLString:urlString
                          intoView:imageView
                       placeholder:phImage
                        completion:completion];
     
     */
    [self setImageFromUrlString:urlString imageView:imageView phImage:phImage showShimmer:NO completion:completion];
}

// Drop-in replacement for your old "set" (into a view, cancels ongoing, fade-in anim)
+ (void)PPSDImageWithURL:(NSString *)urlString
                    imageView:(UIImageView *)imageView
                      phImage:(NSString * _Nullable)phImage
                   completion:(ImageCompletionBlock)completion
{
   
    [imageView sd_setImageWithURL:[NSURL URLWithString:urlString] placeholderImage:[UIImage imageNamed:@"placeholder"] options:SDWebImageRetryFailed | SDWebImageHighPriority | SDWebImageScaleDownLargeImages completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
        completion(image,nil);
    }];
}


- (void)roundCornersWithTopLeft:(CGFloat)topLeft topRight:(CGFloat)topRight bottomLeft:(CGFloat)bottomLeft bottomRight:(CGFloat)bottomRight toView:(UIView *)view {
   // UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:view.bounds
   //                                                byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight | UIRectCornerBottomLeft | UIRectCornerBottomRight)
   //                                                      cornerRadii:CGSizeMake(topLeft, topLeft)]; // Initial radius for all corners

    // Modify the path to have different radii for each corner
    UIBezierPath *path = [UIBezierPath bezierPath];

    // Top Left
    [path moveToPoint:CGPointMake(topLeft, 0)];
    [path addArcWithCenter:CGPointMake(topLeft, topLeft) radius:topLeft startAngle:-M_PI_2 endAngle:-M_PI clockwise:YES];

    // Top Right
    [path addLineToPoint:CGPointMake(view.bounds.size.width - topRight, 0)];
    [path addArcWithCenter:CGPointMake(view.bounds.size.width - topRight, topRight) radius:topRight startAngle:-M_PI endAngle:-M_PI_2 clockwise:YES];

    // Bottom Right
    [path addLineToPoint:CGPointMake(view.bounds.size.width, view.bounds.size.height - bottomRight)];
    [path addArcWithCenter:CGPointMake(view.bounds.size.width - bottomRight, view.bounds.size.height - bottomRight) radius:bottomRight startAngle:-M_PI_2 endAngle:0 clockwise:YES];

    // Bottom Left
    [path addLineToPoint:CGPointMake(bottomLeft, view.bounds.size.height)];
    [path addArcWithCenter:CGPointMake(bottomLeft, view.bounds.size.height - bottomLeft) radius:bottomLeft startAngle:0 endAngle:M_PI_2 clockwise:YES];

    [path closePath]; // Close the path to complete the shape

    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = view.bounds;
    maskLayer.path = path.CGPath;

    view.layer.mask = maskLayer;
}

+ (UIImage *)setWatermarkImage:(UIImage *)watermarkImage toImage:(UIImage *)originalImage
{
    watermarkImage = [self tintImage:watermarkImage withColor:[UIColor hx_colorWithHexStr:@"#FFFFFF" alpha:0.7]]; // Replace with your watermark

    CGSize imgSize = getImageSizeSafely(originalImage);

    // Calculate the watermark size as 25% of the original image size (adjust as needed)
    CGFloat watermarkWidth = imgSize.width * 0.35; // Reduced to 25% for top-right corner
    CGFloat watermarkHeight = imgSize.width * 0.25; // Reduced to 25% for top-right corner

    // Calculate the top-right position for the watermark
    CGFloat watermarkX = imgSize.width - watermarkWidth; // 10 points padding from the right
    CGFloat watermarkY = 0; // 10 points padding from the top
    watermarkX += 10;
    // Define the frames for the original image and the watermark.
    CGRect imageFrame = CGRectMake(0, 0, imgSize.width, imgSize.height);
    CGRect watermarkFrame = CGRectMake(watermarkX, watermarkY, watermarkWidth, watermarkHeight);

    UIImage *watermarkedImage = [originalImage imageWithWatermark:watermarkImage imageFrame:imageFrame watermarkFrame:watermarkFrame];
    return watermarkedImage;
}

CGSize getImageSizeSafely(UIImage *image) {
  if (image) {
    return image.size;
  } else {
    // Handle the case where the image is nil.  Return a default size or log an error.
    //NSLog(@"Error: Image is nil!");
    return CGSizeZero; // Or return a default size like CGSizeMake(0, 0);
  }
}

+ (UIImage *)tintImage:(UIImage *)image withColor:(UIColor *)color {
    if (!image) {
        return nil;
    }

    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();

    // Flip the image vertically (UIKit's coordinate system is different from Core Graphics)
    CGContextTranslateCTM(context, 0, image.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);

    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
    CGContextDrawImage(context, rect, image.CGImage);

    CGContextSetBlendMode(context, kCGBlendModeSourceIn);
    [color setFill];
    CGContextFillRect(context, rect);

    UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return tintedImage;
}


+ (void)setUserDefaultsFromUserModel:(UserModel *)userModel {
  NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

  // Check if the userModel is nil to avoid crashes
  if (userModel) {
    [prefs setValue:userModel.UserName forKey:@"UserName"];
    [prefs setValue:userModel.MobileNo forKey:@"MobileNo"];
    [prefs setValue:userModel.ID forKey:@"userID"];
    [prefs setValue:userModel.UserImageName forKey:@"UserImageName"];
    [prefs setValue:userModel.FirstName forKey:@"firstName"];
    [prefs setValue:userModel.LastName forKey:@"LastName"];
    [prefs setValue:userModel.UserEmail forKey:@"UserEmail"];
    [prefs setValue:userModel.UserAbout forKey:@"UserAbout"];
    [prefs setValue:userModel.UserImageUrl.absoluteString forKey:@"UserImageUrl"];
    [prefs setValue:@(userModel.CountryID) forKey:@"CountryID"];
  } else {
    //NSLog(@"Warning: userModel is nil.  Not setting user defaults.");
    // Optionally, you could clear the user defaults here if that's the desired behavior
    // when the user model is nil.  For example:
    // [self clearUserDefaults];
  }

  [prefs synchronize]; // Important:  Saves the changes to disk.
}

// Optional:  A helper function to clear all user defaults.  Useful for logout.
+ (void)clearUserProfileDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSArray *userKeys = @[
        @"authVerificationID",
        @"PPUserTokenID",
        @"PPAdminTokenID",
        @"UserEmail",
        @"UserName",
        @"FirstName",
        @"LastName",
        @"MobileNo",
        @"UserImageName",
        @"UserAbout",
        @"CountryID",
        @"photoURL",
        @"displayName",
        @"uid",
        @"ID",
        @"userID",
        @"UserID",
    ];

    for (NSString *key in userKeys) {
        if ([defaults objectForKey:key] != nil) {
            [defaults removeObjectForKey:key];
        }
    }
}




+ (NSString *)getCurrentCountryFromCarrier {
 
#if TARGET_OS_SIMULATOR
    //NSLog(@"Skipping telephony access on simulator.");
#else
        CTTelephonyNetworkInfo *networkInfo = [[CTTelephonyNetworkInfo alloc] init];
        CTCarrier *carrier = [networkInfo subscriberCellularProvider];

        if (carrier) {
         
            NSString *isoCountryCode = [carrier isoCountryCode];

            //NSLog(@"Carrier Name: %@", carrierName);
            //NSLog(@"Mobile Country Code: %@", mobileCountryCode);
            //NSLog(@"Mobile Network Code: %@", mobileNetworkCode);
            //NSLog(@"ISO Country Code: %@", isoCountryCode);
            return isoCountryCode;
        } else {
            //NSLog(@"NYES carrier information available.");
            return @"";
        }
    
#endif
    return @"";
}

+ (NSMutableArray<CountryCodeModel *> *)getMiddleEastCountriesForLanguage:(NSString *)languageCode {
      
    NSMutableArray<CountryCodeModel *> *allCountries = [NSMutableArray array];

    // --- Create once (English ID order) ---
    CountryCodeModel *codeModel;

    codeModel = [[CountryCodeModel alloc] init];
    codeModel.ID = 2; codeModel.country = kLang(@"Bahrain"); codeModel.phoneCode = @"+973"; codeModel.isoCountryCode = @"BH";
    [allCountries addObject:codeModel];

    codeModel = [[CountryCodeModel alloc] init];
    codeModel.ID = 8; codeModel.country = kLang(@"Egypt"); codeModel.phoneCode = @"+20"; codeModel.isoCountryCode = @"EG";
    [allCountries addObject:codeModel];
    
    codeModel = [[CountryCodeModel alloc] init];
    codeModel.ID = 9; codeModel.country = kLang(@"Iraq"); codeModel.phoneCode = @"+964"; codeModel.isoCountryCode = @"IQ";
    [allCountries addObject:codeModel];

    codeModel = [[CountryCodeModel alloc] init];
    codeModel.ID = 10; codeModel.country = kLang(@"Jordan"); codeModel.phoneCode = @"+962"; codeModel.isoCountryCode = @"JO";
    [allCountries addObject:codeModel];

    codeModel = [[CountryCodeModel alloc] init];
    codeModel.ID = 3; codeModel.country = kLang(@"Kuwait"); codeModel.phoneCode = @"+965"; codeModel.isoCountryCode = @"KW";
    [allCountries addObject:codeModel];

    codeModel = [[CountryCodeModel alloc] init];
    codeModel.ID =11 ; codeModel.country = kLang(@"Lebanon"); codeModel.phoneCode = @"+961"; codeModel.isoCountryCode = @"LB";
    [allCountries addObject:codeModel];
    
    codeModel = [[CountryCodeModel alloc] init];
    codeModel.ID = 4; codeModel.country = kLang(@"Oman"); codeModel.phoneCode = @"+968"; codeModel.isoCountryCode = @"OM";
    [allCountries addObject:codeModel];

    codeModel = [[CountryCodeModel alloc] init];
    codeModel.ID =12; codeModel.country = kLang(@"Palestine"); codeModel.phoneCode = @"+970"; codeModel.isoCountryCode = @"PS";
    [allCountries addObject:codeModel];

    codeModel = [[CountryCodeModel alloc] init];
    codeModel.ID = 1; codeModel.country = kLang(@"Qatar"); codeModel.phoneCode = @"+974"; codeModel.isoCountryCode = @"QA";
    [allCountries addObject:codeModel];

    codeModel = [[CountryCodeModel alloc] init];
    codeModel.ID = 5; codeModel.country = kLang(@"SaudiArabia"); codeModel.phoneCode = @"+966"; codeModel.isoCountryCode = @"SA";
    [allCountries addObject:codeModel];

    codeModel = [[CountryCodeModel alloc] init];
    codeModel.ID = 13; codeModel.country = kLang(@"Syria"); codeModel.phoneCode = @"+963"; codeModel.isoCountryCode = @"SY";
    [allCountries addObject:codeModel];

    codeModel = [[CountryCodeModel alloc] init];
    codeModel.ID = 6; codeModel.country = kLang(@"UnitedArabEmirates"); codeModel.phoneCode = @"+971"; codeModel.isoCountryCode = @"AE";
    [allCountries addObject:codeModel];

    codeModel = [[CountryCodeModel alloc] init];
    codeModel.ID = 7; codeModel.country = kLang(@"Yemen"); codeModel.phoneCode = @"+967"; codeModel.isoCountryCode = @"YE";
    [allCountries addObject:codeModel];

    // --- Now reorder for Arabic if needed ---
    NSMutableArray<CountryCodeModel *> *arr = [NSMutableArray arrayWithArray:allCountries];

    if ([Language languageVal] == 1) { // Assuming 1 = Arabic
        [arr sortUsingComparator:^NSComparisonResult(CountryCodeModel *obj1, CountryCodeModel *obj2) {
            return [obj1.country localizedCompare:obj2.country];
        }];
    }
    
    
    
    
    
    return arr;
    
    
}


+ (void)generateImageLink:(NSString *)imageName storagePath:(NSString *)storagePath completion:(void(^)(NSString * _Nullable downloadURL, NSError * _Nullable error))completion {
    
    // 1. Create a Storage Reference
    FIRStorage *storage = [FIRStorage storage];
    FIRStorageReference *storageRef = [storage reference];
    
    // 2. Build the Full Storage Path
    NSString *fullPath = [[NSString stringWithFormat:@"%@",storagePath] stringByAppendingString:[NSString stringWithFormat:@"%@",imageName]];
    FIRStorageReference *imageRef = [storageRef child:fullPath];
    
    // 3. Get the Download URL
    [imageRef downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
        
        if (error) {
            completion(nil, error);
            return;
        }
        
        completion(URL.absoluteString, nil);
    }];
}

+ (void)shareOnWhatsApp:(UIImage *)imageToShare textToShare:(NSString *)textToShare fromView:(UIView *)fromView andController:(UIViewController *)controller{
    // 1. Prepare the data to share

    NSURL *appLink = [NSURL URLWithString:@"https://apps.apple.com/1594016239"]; // Replace with your app's App Store link

    // Make sure the app link exists (if you don't have one remove it)
    if (!appLink){
        //NSLog(@"App URL is invalid");
        return;
    }

    // 2. Create array of items to share.
    NSMutableArray *itemsToShare = [[NSMutableArray alloc] init];
    [itemsToShare addObject:textToShare]; // Add the text first
    
    if (imageToShare) { // Check if image is available before adding it
        [itemsToShare addObject:imageToShare];
    }
    
     if (appLink) { // Check if app link is available before adding it
         [itemsToShare addObject:appLink];
     }

    // 3. Create activity view controller.
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];

    // 4. Specify the excluded activities if needed (Optional).
    // For example, exclude printing and copying:
    activityViewController.excludedActivityTypes = @[UIActivityTypePrint, UIActivityTypeCopyToPasteboard];
    
    // 5. Present the activity view controller
    // For iPad: use a popover
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityViewController.popoverPresentationController.sourceView = fromView;
        activityViewController.popoverPresentationController.sourceRect = CGRectMake(fromView.frame.size.width / 2, fromView.frame.size.height / 2, 0, 0);
    }

    [controller presentViewController:activityViewController animated:YES completion:nil];

    // (Optional) Handle completion if needed
        [activityViewController setCompletionWithItemsHandler:^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
            if (completed) {
                //NSLog(@"Share completed successfully with %@", activityType);
            } else {
                //NSLog(@"Share was not completed or failed");
                if (activityError)
                {
                 //NSLog(@"Error %@", activityError);
                }
            }
        }];

}



//This function return the card object itself with  cardID
+ (CardModel *)cardWithID:(NSString *)cardID inCardsArray:(NSArray<CardModel *> *)cardsArray {
    if (!cardsArray || !cardID) {
        return nil; // Handle nil input
    }

    for (CardModel *card in cardsArray) {
        if ([card.ID isEqualToString:cardID]) {
            return card;
        }
    }

    return nil; // Card not found
}



//Helper function to generate unique file URL
+ (NSURL *)generateUniqueOutputURL {
    // 1. Get a temporary directory URL
    NSURL *tempDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    if (!tempDirURL) {
        //NSLog(@"Error getting temp directory");
        return nil;
    }
    
    // 2. Generate a unique file name
    NSString *uniqueFileName = [[NSUUID UUID] UUIDString];
    NSString *filePath = [NSString stringWithFormat:@"%@.mp4", uniqueFileName];

    // 3. Create the full output URL
    NSURL *outputURL = [tempDirURL URLByAppendingPathComponent:filePath];

    return outputURL;
}




+ (void)getVideoThumbnail:(NSURL *)videoURL toImageView:(UIImageView *)imageView{
    
    // 1. Check URL valid
    if(!videoURL) {
        //NSLog(@"Error: Invalid video URL");
        return;
    }
    
    
    
    NSString *imageKey = [[YYWebImageManager sharedManager] cacheKeyForURL:videoURL];
    if ([[YYWebImageManager sharedManager].cache getImageForKey:imageKey withType:YYImageCacheTypeAll]) {
        dispatch_async_on_main_queue(^{
            //NSLog(@"thumbnail  ----->>> toImageView From: [[YYWebImageManager sharedManager].cache");
            imageView.image = [[YYWebImageManager sharedManager].cache getImageForKey:imageKey];
        });
    }
    else
    {
        
        // 1. Create AVAsset from video URL
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
        
        // 2. Create AVAssetImageGenerator
        AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        imageGenerator.appliesPreferredTrackTransform = YES; // Ensures correct image orientation.
        
        // 3. Set a time ///////////////////////////////////////////////////////////////for the thumbnail (e.g., 1 second into the video)
        CMTime thumbnailTime = CMTimeMakeWithSeconds(1.0, 600); // 1 second at 600 frames per second
        
        // 4. Generate the thumbnail asynchronously
        [imageGenerator generateCGImagesAsynchronouslyForTimes:@[[NSValue valueWithCMTime:thumbnailTime]]
                                             completionHandler:^(CMTime requestedTime, CGImageRef _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
            
            if (result == AVAssetImageGeneratorSucceeded) {
                // 5. Success: Convert CGImage to UIImage and display
                if(image){
                    UIImage *thumbnailImage = [[UIImage alloc] initWithCGImage:image];
                    //NSLog(@"thumbnail  ----->>> toImageView From: result == AVAssetImageGeneratorSucceeded");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[YYWebImageManager sharedManager].cache setImage:thumbnailImage forKey:imageKey];
                    });
                }
            } else {
                // Error handling
                //NSLog(@"Error generating thumbnail: %@", error);
            }
        }];
        
    }
}


+ (void)uploadImage:(UIImage *)image andName:(NSString *)name
      withCompletion:(void (^)(NSString *downloadURL, NSError *error))completion {

      // 1. Resize the Image (Main Goal: Size Reduction)
      UIImage *resizedImage = [self resizeImage:image
                            withMaxDimension:600];  // Adjust 800 as needed

      // 2. Compress the Image (JPEG compression)
      NSData *imageData = [self compressImage:resizedImage
                            withQuality:0.7];  // Adjust quality from 0.0 (min) - 1.0 (max)

      if (!imageData) {
          NSError *compressionError = [NSError errorWithDomain:@"ImageUploader"
                                                       code:1
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Failed to compress image"}];
          completion(nil, compressionError);
          return;
      }
      
      // 3. Prepare the Firebase Storage Upload
      NSString *imageName = [NSString stringWithFormat:@"%@.jpg", name];

      FIRStorageReference *storageRef = [[FIRStorage storage] referenceWithPath:[NSString stringWithFormat:@"CardsImages/%@", imageName]];

  
    [storageRef putData:imageData metadata:nil completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
          if (error) {
              completion(nil, error);
          } else {
              // Get the download URL
              [storageRef downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
                  if (error) {
                      completion(nil, error);
                  } else if (URL) {
                      completion([URL absoluteString], nil);
                  } else {
                      NSError *downloadURLError = [NSError errorWithDomain:@"ImageUploader"
                                                                  code:2
                                                              userInfo:@{NSLocalizedDescriptionKey: @"Failed to get download URL"}];
                     completion(nil, downloadURLError);
                   }
               }];
           }
       }];
  }

  // MARK: Image Helper Methods

+ (UIImage *)resizeImage:(UIImage *)image withMaxDimension:(CGFloat)maxDimension {
      
      CGFloat imageWidth = image.size.width;
      CGFloat imageHeight = image.size.height;

      // Determine the scale factor to resize the image while maintaining aspect ratio
      CGFloat scaleFactor;
      if (imageWidth > imageHeight) {
          scaleFactor = maxDimension / imageWidth;
      } else {
          scaleFactor = maxDimension / imageHeight;
      }
      
      // Create the new size
      CGSize newSize = CGSizeMake(imageWidth * scaleFactor, imageHeight * scaleFactor);
      
      // Draw the scaled image into the context
      UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
      [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
      UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
      UIGraphicsEndImageContext();

      return newImage;
  }

 + (NSData *)compressImage:(UIImage *)image withQuality:(CGFloat)quality {
      return UIImageJPEGRepresentation(image, quality);
  }


+ (void)setImageFromUrlString:(NSString *)urlString
                   imageView:(UIImageView *)imageView
                     phImage:(NSString * _Nullable)phImage {

    [GM setImageFromUrlString:urlString imageView:imageView phImage:phImage completion:nil];
}

#pragma mark - Animation Helper
+ (void)animateImageView:(UIImageView *)imageView withImage:(UIImage *)image {
    imageView.image = image;
    imageView.alpha = 0.0;
    imageView.transform = CGAffineTransformMakeScale(0.95, 0.95);

    [UIView animateWithDuration:0.35
                          delay:0
         usingSpringWithDamping:0.8
          initialSpringVelocity:0.3
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        imageView.alpha = 1.0;
        imageView.transform = CGAffineTransformIdentity;
    } completion:nil];
}


+ (void)fadeInImage:(UIImage *)image inImageView:(UIImageView *)imageView {
    imageView.alpha = 1.0;
    imageView.image = image;

    [UIView animateWithDuration:0.3 // Adjust duration as needed
                     animations:^{
                         imageView.alpha = 1.0;
                     }];
}




+ (void)setShadow:(UIView *)view sh_Color:(UIColor *)color cGSize:(CGSize)size  sh_Opacity:(float)Opacity radius:(float)radus
{
    [view.layer setShadowColor:color.CGColor];
    [view.layer setShadowOffset:size];
    [view.layer setShadowOpacity:Opacity];
    [view.layer setShadowRadius:radus];
}

+(FIRStorageReference *)CardsImagesRefrence
{
    NSString *userPath = @"UnknowUsers";
   // NSUserDefaults *userD = [NSUserDefaults standardUserDefaults];
    NSString *UserID = PPCurrentUser.ID;
    if(UserID)
        userPath = UserID;

    FIRStorage *storage = [FIRStorage storage];
    FIRStorageReference *storageRef = [storage reference];
    FIRStorageReference *CardsImagesRef = [storageRef child:[NSString stringWithFormat:@"CardsImages/%@",userPath]]; // Create a folder called "images"
    //FIRStorageReference *CardsImagesRef = [storageRef child:[NSString stringWithFormat:@"CardsImages"]]; // Create a folder called "images"
    return CardsImagesRef;
}

+(NSString *)CardsImagesRefStr
{
    return @"CardsImages";
}

+(FIRStorageReference *)UserImagesRefrence
{
    //NSUserDefaults *userD = [NSUserDefaults standardUserDefaults];
    FIRStorage *storage = [FIRStorage storage];
    FIRStorageReference *storageRef = [storage reference];
    FIRStorageReference *UsersImagesRef = [storageRef child:[NSString stringWithFormat:@"UsersImages"]]; // Create a folder called "images"
    return UsersImagesRef;
}

// Upload Video
#pragma mark - Video Upload Logic
+ (void)uploadMedia:(NSMutableArray *)MediaFiles CardID:(NSString *)CardID completion:(nonnull MediaCompletionBlock)completion {
    FIRStorage *storage = [FIRStorage storage];
    FIRStorageReference *storageRef = [storage reference];
    NSMutableArray *FilesDictArr = [[NSMutableArray alloc] init];

    if (MediaFiles.count == 0) {
        completion(FilesDictArr);
        return;
    }
  __block int i = 0;
  
    void (^__block uploadFile)(void) = ^{
        if (i >= MediaFiles.count) {
           completion(FilesDictArr);
           return;
        }

        NSDictionary *dict = MediaFiles[i];
        __block NSDictionary *FilesDict = [[NSDictionary alloc] init];
        NSString *fileName ;
      
        if([[dict valueForKey:@"fileType"] integerValue] == FileTypeImage){
            
          NSURL *FileUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@",[dict valueForKey:@"FileUrl"]]];
            
            fileName = [NSString stringWithFormat:@"IMG_%@_%d.jpeg", CardID, i + 1];
            FIRStorageReference *imageRef = [storageRef child:[NSString stringWithFormat:@"CardsImages/%@", fileName]];
            
            NSData *imageData = [NSData dataWithContentsOfURL:FileUrl];
            if (!imageData) {
                //NSLog(@"Error: Could not load image data from file path.");
                i++;
                uploadFile();
              return;
            }
            
            FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
            metadata.contentType = @"image/jpeg";
            
            FIRStorageUploadTask *uploadTask = [imageRef putData:imageData metadata:metadata completion:^(FIRStorageMetadata *metadata, NSError *error) {
                if (error) {
                    //NSLog(@"Error uploading image: %@", error.localizedDescription);
                  i++;
                   uploadFile();
                } else {
                    //NSLog(@"Image uploaded successfully!");
                    FilesDict = @{
                        @"FileType":  @(FileTypeImage),
                        @"FileName": fileName,
                        @"CardID": CardID
                    };
                    [FilesDictArr addObject:FilesDict];
                  i++;
                    uploadFile();
                }
            }];
            
            [uploadTask observeStatus:FIRStorageTaskStatusProgress handler:^(FIRStorageTaskSnapshot *snapshot) {
                double progress = 100.0 * (snapshot.progress.completedUnitCount) / (snapshot.progress.totalUnitCount);
                NSLog(@"Upload progress: %.2f%%", progress);
            }];
        }
      else if([[dict valueForKey:@"fileType"] integerValue] == FileTypeVideo){
            NSURL *FileUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@",[dict valueForKey:@"FileUrl"]]];
            fileName = [NSString stringWithFormat:@"VID_%@_%d.mov", CardID, i + 1];
            NSString *videoPath = [NSString stringWithFormat:@"CardsVideosTST/%@", fileName];
            FIRStorageReference *videoRef = [storageRef child:videoPath];
            
            FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
            metadata.contentType = @"video/quicktime";

          
            FIRStorageUploadTask *uploadTask = [videoRef putFile:FileUrl metadata:metadata completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
                if (error) {
                    //NSLog(@"Error uploading video: %@", error.localizedDescription);
                  i++;
                    uploadFile();
                    return;
                }
                //NSLog(@"Video uploaded successfully");
                FilesDict = @{
                  @"FileType":  @(FileTypeVideo),
                  @"FileName": fileName,
                  @"CardID": CardID
                };
                [FilesDictArr addObject:FilesDict];
               i++;
                uploadFile();
            }];
           [uploadTask observeStatus:FIRStorageTaskStatusProgress handler:^(FIRStorageTaskSnapshot *snapshot) {
              double progress = 100.0 * snapshot.progress.completedUnitCount / snapshot.progress.totalUnitCount;
               NSLog(@"Upload Progress: %.2f%%", progress);
            }];

        }
    };

  uploadFile();
}

+ (void)uploadVideo:(NSString *)videoName videoArray:(NSArray *)videoArray completion:(nonnull VCompletionBlock)completion{
    
    NSURL *videoURL;
    if(videoArray.count > 0)
    {
        videoURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@",[videoArray objectAtIndex:0]]];
      
    FIRStorage *storage;
    FIRStorageReference *storageRef;
    
    storage = [FIRStorage storage];
    storageRef = [storage reference];
    
    // 1. Create a Storage Reference
    //NSString *fileName = [[NSUUID UUID] UUIDString];
    NSString *videoPath = [NSString stringWithFormat:@"CardsVideos/%@.mov",videoName]; // Choose a path and file extension
    FIRStorageReference *videoRef = [storageRef child:videoPath];


    // 2. Create Upload Metadata (optional)
    FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
    metadata.contentType = @"video/quicktime";  // Adjust MIME type as needed


     // 3. Upload the Video
    FIRStorageUploadTask *uploadTask = [videoRef putFile:videoURL metadata:metadata completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
        if (error != nil) {
          //NSLog(@"Error uploading video: %@", error.localizedDescription);
            completion(0,@"",@"");
          return; // Exit if there's an error
        }
        //NSLog(@"Video uploaded successfully");
        // You can get the download URL:
        [videoRef downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
          if(error){
             //NSLog(@"Error getting download URL: %@", error.localizedDescription);
              completion(0,@"",@"");
             return;
          }
          if(URL){
              //NSLog(@"Download URL: %@", URL.absoluteString);
              completion(1,videoName,URL.absoluteString);
          }
        }];
    }];

     // 4. Monitor Upload Progress (Optional)
     [uploadTask observeStatus:FIRStorageTaskStatusProgress handler:^(FIRStorageTaskSnapshot *snapshot) {
          //NSLog(@"Upload Progress: %.2f%%", progress);
      }];
        
       
    }
    else
    {
        completion(0,@"",@"");
    }

}

/*
+ (NSMutableArray<ArchiveModel *> *) replaceArchiveModel:(ArchiveModel *)newArchiveModel  inArray:(NSMutableArray<ArchiveModel *> *)array error:(NSError *__autoreleasing*)error
{

    if (!newArchiveModel || !array ||  newArchiveModel.ID == nil ) {
        NSString *errormessage = @"Invalid Parameters newArchiveModel, Array  or newArchiveModel.ID  is Null";
        NSError * myerror=  [NSError errorWithDomain:@"MyDomain"
                        code:-1
                            userInfo:@{NSLocalizedDescriptionKey:errormessage}];

               if(error != NULL ) *error= myerror;
             return  nil;
        }
   __block ArchiveModel* replaceObject= nil;

   
    NSUInteger index=[array indexOfObjectPassingTest:^BOOL(ArchiveModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if( [obj.ID isEqualToString: newArchiveModel.ID])
        {
          replaceObject =obj;
           *stop =YES;
           return  YES;
         }
         return  NO;
    }];

  if(index != NSNotFound){

       [array replaceObjectAtIndex:index withObject:newArchiveModel];
      //NSLog(@"Archive Replace  Sucsses : %@", newArchiveModel.archiveTitle);
      return array;

   }
   else
   {

         NSString *errormessage = [NSString stringWithFormat: @"Unable to find Object with ID %@ In Array", newArchiveModel.ID ];

        NSError * myerror=  [NSError errorWithDomain:@"MyDomain"
                             code:-2
                        userInfo:@{NSLocalizedDescriptionKey:errormessage}];

        if(error != NULL )  *error= myerror;

         return  nil;


  }
}
*/

+ (void)sendRequestWithURLString:(NSString *)urlString
                       httpMethod:(NSString *)httpMethod
                      jsonBody:(NSDictionary *)jsonBody
                       headers:(NSDictionary *)headers
                  completion:(CompletionBlock)completion {

    // 1. URL Creation
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        NSError *error = [NSError errorWithDomain:@"HTTPRequestErrorDomain" code:1001 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}];
        if (completion) {
            completion(nil, nil, error);
        }
        return;
    }

    // 2. Request Creation
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:httpMethod];

    // 3. Set Headers
    if (headers) {
        for (NSString *headerField in headers) {
            [request setValue:headers[headerField] forHTTPHeaderField:headerField];
        }
    }
    
    //Set Content-Type header for json body
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    // 4. Encode JSON Body
    if (jsonBody) {
        NSError *jsonError;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonBody options:0 error:&jsonError];
        if (jsonError) {
            if (completion) {
                completion(nil, nil, jsonError);
            }
            return;
        }
        [request setHTTPBody:jsonData];
    }

    // 5. Session Configuration and Task Creation
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
          // 6. Completion Handler (back on the main thread)
            if (completion) {
                completion(data, response, error);
            }
        });
    }];


    // 7. Start the Task
    [dataTask resume];
}

+ (UIEdgeInsets)getSafeAreaInsets {

    UIWindow *window = nil;
    UIEdgeInsets safeArea = UIEdgeInsetsMake(0, 0, 0, 0);
    // Attempt to get the key window first. This is the most common scenario.
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                 window = [scene.windows firstObject];
                 break;
            }
        }
    } else {
        window = [[UIApplication sharedApplication] keyWindow];
    }

    if (!window) {
        //NSLog(@"Error: Could not find a valid UIWindow.");
        return safeArea;
    }

    //NSLog(@"Top Safe Area: %f", window.safeAreaInsets.top);
    //NSLog(@"Bottom Safe Area: %f", window.safeAreaInsets.bottom);
    
    return window.safeAreaInsets;

    
}




+ (NSString *)ageFromBirthday:(NSDate *)birthdate {
    NSString *monthString = kLang(@"month");
    NSString *yearString = kLang(@"year");
    NSString *redyString = kLang(@"readyToMarrage");
    NSString *stringDate;
    NSDate *today = [NSDate date];
    NSDateComponents *ageComponents = [[NSCalendar currentCalendar]components:NSCalendarUnitMonth
                                       fromDate:birthdate
                                       toDate:today
                                       options:0];
    ////NSLog(@"birthdate %@ \n today %@",birthdate,today);
    if(ageComponents.month < 12)
    {
        stringDate = [NSString stringWithFormat:@"%ld %@   %@",ageComponents.month,monthString,ageComponents.month >= 7 ? redyString : @""];
        return stringDate;
    }
    else if (ageComponents.month == 12)
    {
        stringDate = [NSString stringWithFormat:@"1 %@ %@",yearString,redyString];
        return stringDate;
    }
    else
    {
        NSInteger aboveMonths = ageComponents.month % 12;
        if(ageComponents.month % 12 == 0)
        {
            ageComponents = [[NSCalendar currentCalendar]components:NSCalendarUnitYear
                                               fromDate:birthdate
                                               toDate:today
                                               options:0];
            stringDate = [NSString stringWithFormat:@"%ld %@",ageComponents.year,yearString];
            return stringDate;
        }
        ageComponents = [[NSCalendar currentCalendar]components:NSCalendarUnitYear
                                           fromDate:birthdate
                                           toDate:today
                                           options:0];
        stringDate = [NSString stringWithFormat:@"%ld %@ %ld %@    %@",ageComponents.year,yearString,aboveMonths,monthString,redyString];
        return stringDate;
    }
}



+ (void)shareToWhatsApp:(NSString *)textToShare sharingImage:(UIImage *)sharingImage inViewController:(UIViewController *)VC {
    // 1. Prepare the items to share
    UIImage *imageToShare = sharingImage;  // Replace "your_image_name" with your image's name in Assets.xcassets
    NSURL *appLinkURL = [NSURL URLWithString:@"https://apps.apple.com/1594016239"]; // Replace with your actual app link (e.g., App Store link)

    if (!imageToShare) {
        //NSLog(@"Error: Image not found!");
        return; // Stop if the image isn't loaded
    }

    NSMutableArray *itemsToShare = [[NSMutableArray alloc] init];

    if (textToShare) {
        [itemsToShare addObject:textToShare];
    }
    if (imageToShare) {
        [itemsToShare addObject:imageToShare];
    }
    if (appLinkURL) {
        [itemsToShare addObject:appLinkURL];
    }

    if ([itemsToShare count] == 0) {
        //NSLog(@"Error: Nothing to share!");
        return; // Stop if there's nothing to share
    }

    // 2. Create UIActivityViewController
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare
                                                                                       applicationActivities:nil];

    // 3. Exclude activities if needed (Optional - You might not need this for basic WhatsApp sharing)
    activityViewController.excludedActivityTypes = @[
        UIActivityTypePostToFacebook,
        UIActivityTypePostToTwitter,
        UIActivityTypePostToWeibo,
        UIActivityTypeMessage,
        UIActivityTypeMail,
        UIActivityTypePrint,
        UIActivityTypeCopyToPasteboard,
        UIActivityTypeAssignToContact,
        UIActivityTypeSaveToCameraRoll,
        UIActivityTypeAddToReadingList,
        UIActivityTypePostToFlickr,
        UIActivityTypePostToVimeo,
        UIActivityTypePostToTencentWeibo,
        UIActivityTypeAirDrop,
        UIActivityTypeOpenInIBooks,
        UIActivityTypeMarkupAsPDF
    ];


    // iPad requires popover presentation for UIActivityViewController
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityViewController.popoverPresentationController.sourceView = VC.view;
        activityViewController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(VC.view.bounds),
                                                                                     CGRectGetMidY(VC.view.bounds),
                                                                                     0, 0);
        activityViewController.popoverPresentationController.permittedArrowDirections = 0;
    }

    // Dismiss any existing presented VC to avoid "already presenting" crash
    if (VC.presentedViewController) {
        [VC dismissViewControllerAnimated:NO completion:^{
            [VC presentViewController:activityViewController animated:YES completion:nil];
        }];
    } else {
        [VC presentViewController:activityViewController animated:YES completion:nil];
    }

    activityViewController.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        if (completed) {
            //NSLog(@"Shared to activity: %@", activityType);
            // You can add code here to handle successful sharing (e.g., track analytics)
        } else {
            //NSLog(@"Sharing cancelled or failed: %@", activityError);
            // Handle cancelled or failed sharing
        }
    };
}



+ (void)uploadImageToStories:(UIImage *)image forUserID:(NSString *)userID completion:(void (^_Nullable)(NSURL * _Nullable url))completion {

    if (!completion) {
        completion = ^(NSURL * _Nullable __unused u) {};
    }

    if (userID.length == 0) {
        NSLog(@"⚠️ [Stories] uploadImageToStories: userID is empty");
        completion(nil);
        return;
    }

    // Resize before compression to keep uploads fast and prevent timeouts
    UIImage *resizedImage = [self resizeImage:image withMaxDimension:1080];

    NSData *imageData = UIImageJPEGRepresentation(resizedImage, 0.7);
    if (!imageData) {
        NSLog(@"⚠️ [Stories] Failed to create JPEG data from image");
        completion(nil);
        return;
    }

    // Protect upload when app is backgrounded
    __block UIBackgroundTaskIdentifier bgTask =
        [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [[UIApplication sharedApplication] endBackgroundTask:bgTask];
            bgTask = UIBackgroundTaskInvalid;
        }];

    NSString *uniqueFileName = [[NSUUID UUID] UUIDString];
    NSString *fileName = [NSString stringWithFormat:@"STORY_%@.jpeg", uniqueFileName];

    // Path must match storage.rules: stories/{userId}/{allPaths=**}
    FIRStorage *storage = [FIRStorage storage];
    FIRStorageReference *storageRef = [storage reference];
    FIRStorageReference *userStoriesRef = [storageRef child:[NSString stringWithFormat:@"stories/%@", userID]];
    FIRStorageReference *imageRef = [userStoriesRef child:fileName];

    FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
    metadata.contentType = @"image/jpeg";

    [imageRef putData:imageData metadata:metadata completion:^(FIRStorageMetadata * _Nullable meta, NSError * _Nullable error) {
        (void)meta;
        if (error) {
            NSLog(@"⚠️ [Stories] Storage upload error: %@", error.localizedDescription);
            completion(nil);
            if (bgTask != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                bgTask = UIBackgroundTaskInvalid;
            }
            return;
        }

        [imageRef downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable dlError) {
            if (dlError) {
                NSLog(@"⚠️ [Stories] Download URL error: %@", dlError.localizedDescription);
            }
            completion(dlError ? nil : URL);
            if (bgTask != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:bgTask];
                bgTask = UIBackgroundTaskInvalid;
            }
        }];
    }];
}

+(NSMutableArray *)getAdsSegmentedTitleForLanguage:(NSInteger)languageCode
{
    NSMutableArray *segmTitles = [NSMutableArray new];
    if ([Language languageVal] == 0 ) {
        // 10 15 375 40
        [segmTitles addObject:kLang(@"services")];
        [segmTitles addObject:kLang(@"Veterinary")];
        [segmTitles addObject:kLang(@"food")];
        [segmTitles addObject:kLang(@"Accessories")];
        [segmTitles addObject:kLang(@"Ads")];
    }
    else
    {
        [segmTitles addObject:kLang(@"Ads")];
        [segmTitles addObject:kLang(@"Accessories")];
        [segmTitles addObject:kLang(@"food")];
        [segmTitles addObject:kLang(@"Veterinary")];
        [segmTitles addObject:kLang(@"services")];
    }
    return segmTitles;
}

+(NSMutableArray *)getAdsAccessSegmentedTitleForLanguage:(NSInteger)languageCode
{
    NSMutableArray *segmTitles = [NSMutableArray new];
    
    [segmTitles addObject:kLang(@"Ads")];
    [segmTitles addObject:kLang(@"Accessories")];
    [segmTitles addObject:kLang(@"food")];
    [segmTitles addObject:kLang(@"For Adoption")];
    
    
    return segmTitles;
}

+(NSMutableArray *)getSegmentedTitleForLanguage:(NSInteger)languageCode
{
    NSMutableArray *segmTitles = [NSMutableArray new];
    
    if ([Language languageVal] == 0 ) {
        // 10 15 375 40
        [segmTitles addObject:kLang(@"Cards")];
        [segmTitles addObject:kLang(@"Boxes")];
        [segmTitles addObject:kLang(@"Archive")];
        [segmTitles addObject:kLang(@"Trash")];
    }
    else
    {
        [segmTitles addObject:kLang(@"Trash")];
        [segmTitles addObject:kLang(@"Archive")];
        [segmTitles addObject:kLang(@"Boxes")];
        [segmTitles addObject:kLang(@"Cards")];
    }
    return segmTitles;
}

+(void)ConfigEmptyViewForCollection:(UICollectionView *)collectionView Title:(NSString *)title Subtitle:(NSString *)Subtitle imageName:(NSString *)imageName completion:(void (^)( NSInteger complete))completion {
    
    PPEmptyStateConfig *cfg = [PPEmptyStateConfig new];
    cfg.animationName = imageName; ;
    cfg.title      = title;
    cfg.subTitle      = Subtitle;
    cfg.buttonTitle  = kLang(@"SearchNoResultsCTA");
    cfg.target       = self;
    //cfg.action       = @selector(retrySegment);
    cfg.isNetworkFile = YES;
    NSInteger totalItems = [collectionView numberOfItemsInSection:0];

    [PPEmptyStateHelper updateEmptyStateForListView:collectionView
                                          dataCount:totalItems
                                             config:cfg];
    
    completion(1);
}

+ (NSString *)getArchiveTitleByID:(NSString *)archiveID fromArchiveArray:(NSArray<ArchiveModel *> *)archiveArray {
    for (ArchiveModel *archive in archiveArray) {
        if ([archive.ID isEqualToString:archiveID]) {
            return archive.archiveTitle;
        }
    }

    // If no ArchiveModel with the matching ID is found, return nil or an empty string
    return nil; // Or @"" depending on your needs.
}

+ (ArchiveModel *)findArchiveModelWithMasterID:(NSString *)masterID {
    for (ArchiveModel *model in AppData.AllArchivesDocs) {
        if ([model.ID isEqualToString:masterID]) {
            return model;
        }
    }

    return nil;
}

 

+(NSString *)formatDateFromDate:(NSDate *)date
{
      NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
      [dateFormatter setDateFormat:@"dd-MM-yyyy"];
      [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en"]];
      return [dateFormatter stringFromDate:date];
}


+(NSString *)movedPlacerUrl
{
    return @"https://firebasestorage.googleapis.com/v0/b/pure-pets-49199.firebasestorage.app/o/Placers%2FmovedPlacer.png?alt=media&token=f1e996c0-85ab-46ef-9d59-771c8374eab4";
}



+ (NSData *)compressImageToMaxSize:(UIImage *)image maxSizeKB:(NSInteger)maxSizeKB {
    CGFloat compression = 0.9; // Start with high quality
    NSData *imageData = UIImageJPEGRepresentation(image, compression);
    
    while ([imageData length] > maxSizeKB * 1024 && compression > 0.1) {
        compression -= 0.1;
        imageData = UIImageJPEGRepresentation(image, compression);
    }
    
    return imageData;
}



+ (NSCache *)thumbnailCache {
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
    });
    return cache;
}

+ (void)getVideoThumbnail:(NSURL *)url completion:(void (^)(UIImage * _Nullable image, NSError * _Nullable error))completion {
    if (!url) {
        if (completion) completion(nil, [NSError errorWithDomain:@"GMError" code:0 userInfo:@{NSLocalizedDescriptionKey: @"URL is nil"}]);
        return;
    }
    
   
    if ([[YYWebImageManager sharedManager].cache getImageForKey:url.absoluteString withType:YYImageCacheTypeAll]) {
        //NSLog(@"thumbnail  ----->>> toImageView From: YYImageCacheTypeAll");
        completion([[YYWebImageManager sharedManager].cache getImageForKey:url.absoluteString], nil);
        return;
    }
      
   

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AVAsset *asset = [AVAsset assetWithURL:url];
        AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        imageGenerator.appliesPreferredTrackTransform = YES;

        CMTime time = CMTimeMakeWithSeconds(1.0, 600); // Thumbnail at 1 second
        NSError *error = nil;
        CGImageRef imageRef = [imageGenerator copyCGImageAtTime:time actualTime:NULL error:&error];

        UIImage *thumbnail = nil;
        if (imageRef) {
            thumbnail = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);

            if (thumbnail) {
                [[YYWebImageManager sharedManager].cache setImage:thumbnail forKey:url.absoluteString];
                [[self thumbnailCache] setObject:thumbnail forKey:url.absoluteString];
                //NSLog(@"thumbnail  ----->>> From: AVAssetImageGenerator");
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(thumbnail, error);
            }
        });
    });
}

+ (NSCache *)durationCache {
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
    });
    return cache;
}

+ (void)videoDurationFromURL:(NSURL *)videoURL completion:(void (^)(NSString *durationString))completion {
    NSString *cacheKey = videoURL.absoluteString;
    
    NSString *cachedDuration = [self.durationCache objectForKey:cacheKey];
    if (cachedDuration) {
        if (completion) {
            completion(cachedDuration);
        }
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AVAsset *asset = [AVAsset assetWithURL:videoURL];
        [asset loadValuesAsynchronouslyForKeys:@[@"duration"] completionHandler:^{
            NSError *error = nil;
            AVKeyValueStatus status = [asset statusOfValueForKey:@"duration" error:&error];
            if (status == AVKeyValueStatusLoaded) {
                CMTime time = asset.duration;
                NSTimeInterval durationInSeconds = CMTimeGetSeconds(time);
                NSString *durationString = [self stringFromTimeInterval:durationInSeconds];

                // Cache it
                [self.durationCache setObject:durationString forKey:cacheKey];

                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(durationString);
                    }
                });
            } else {
                //NSLog(@"Error loading duration: %@", error);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(nil);
                    }
                });
            }
        }];
    });
}

+ (NSString *)stringFromTimeInterval:(NSTimeInterval)interval {
    NSInteger ti = (NSInteger)interval;
    NSInteger seconds = ti % 60;
    NSInteger minutes = (ti / 60) % 60;
    return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)seconds];
}

#pragma mark - Helper

+ (void)animateCell:(UITableViewCell *)cell
{
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];

    animation.keyPath = @"position.x";
    animation.values =  @[ @0, @20, @-20, @10, @0];
    animation.keyTimes = @[@0, @(1 / 6.0), @(3 / 6.0), @(5 / 6.0), @1];
    animation.duration = 0.3;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    animation.additive = YES;

    [cell.layer addAnimation:animation forKey:@"shake"];
}

+ (void)gardToView:(UIView *)theView colorOne:(UIColor *)colorOne colorTwo:(UIColor *)colorTwo colorThree:(UIColor *)colorThree rds:(float )rds
{
    
    // Remove existing gradient layers (identified by name)
    NSArray<CALayer *> *sublayers = [theView.layer.sublayers copy];
    for (CALayer *layer in sublayers) {
        if ([layer.name isEqualToString:@"PurePetsGradientLayer"]) {
            [layer removeFromSuperlayer];
        }
    }
            
    // Create the gradient
    CAGradientLayer *theViewGradient = [CAGradientLayer layer];
    theViewGradient.colors = [NSArray arrayWithObjects: (id)colorOne.CGColor, (id)colorTwo.CGColor,(id)colorThree.CGColor, nil];
    theViewGradient.frame = theView.bounds;
    theViewGradient.cornerRadius = rds;
    theViewGradient.name = @"PurePetsGradientLayer";
    [theView.layer insertSublayer:theViewGradient atIndex:0];
    
}
+(void)logoutFromConroller:(UIViewController *)VC
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"stopAllListener"
                                                        object:self
                                                      userInfo:nil];
    //[[LocalStorage sharedLocalStorage] initArrays];
    // Put your action here
    [GM clearUserProfileDefaults];

    // Logout from Firebase Auth
    NSError *signOutError;
    BOOL status = [[FIRAuth auth] signOut:&signOutError];

    if (!status) {
        //NSLog(@"AppManager: Error signing out: %@", signOutError);
    } else {
        //NSLog(@"AppManager: Sign out successfull auth");
    }

    // After all tasks are complete, perform the segue
    //NSLog(@"AppManager: Sign out Complete");
    //[VC performSegueWithIdentifier:@"showUserLogin" sender:self];
}


+ (void)callPhoneNumber:(NSString *)phoneNumber fromViewController:(UIViewController *)viewController {
    // Validate input
    if (!phoneNumber || [phoneNumber length] == 0) {
        [self showAlertWithTitle:@"Invalid Number"
                        message:@"Please provide a valid phone number"
              inViewController:viewController];
        return;
    }
    
    // Clean the number
    NSString *cleanedNumber = [self cleanPhoneNumber:phoneNumber];
    
    // Additional validation
    if (cleanedNumber.length < 3) {  // Minimum length check
        [self showAlertWithTitle:@"Invalid Number"
                        message:@"The phone number is too short"
              inViewController:viewController];
        return;
    }
    
    // Create the phone URL
    NSString *phoneURLString = [NSString stringWithFormat:@"telprompt://%@", cleanedNumber];
    NSURL *phoneURL = [NSURL URLWithString:phoneURLString];
    
    // Check calling capability
    if (![[UIApplication sharedApplication] canOpenURL:phoneURL]) {
        [self showAlertWithTitle:@"Cannot Call"
                        message:@"This device is not capable of making phone calls"
              inViewController:viewController];
        return;
    }
    
    // Present confirmation alert
    UIAlertController *alert = [UIAlertController
                               alertControllerWithTitle:@"Call Number"
                               message:[NSString stringWithFormat:@"Call %@?", cleanedNumber]
                               preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Call" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (@available(iOS 10.0, *)) {
            [[UIApplication sharedApplication] openURL:phoneURL options:@{} completionHandler:nil];
        } else {
            [[UIApplication sharedApplication] openURL:phoneURL];
        }
    }]];
    
    [viewController presentViewController:alert animated:YES completion:nil];
}

// Helper method to clean phone number
+ (NSString *)cleanPhoneNumber:(NSString *)phoneNumber {
    NSCharacterSet *allowedChars = [NSCharacterSet characterSetWithCharactersInString:@"+0123456789"];
    return [[phoneNumber componentsSeparatedByCharactersInSet:[allowedChars invertedSet]] componentsJoinedByString:@""];
}

// Helper method to show alerts
+ (void)showAlertWithTitle:(NSString *)title
                  message:(NSString *)message
                   imageName:(NSString *)imageName
        inViewController:(UIViewController *)viewController {
    
    FCAlertView *alert = [[FCAlertView alloc] init];

 
    [alert showAlertInView:viewController
                 withTitle:title // "Not Logged In"
              withSubtitle:message // "Do you want to login now?"
           withCustomImage:imageName ? [UIImage imageNamed:imageName] : nil
       withDoneButtonTitle:kLang(@"ok") // "Login"
                andButtons:@[]]; // "Cancel"

    [alert doneActionBlock:^{}];

}

// Helper method to show alerts
+ (void)showAlertWithTitle:(NSString *)title
                  message:(NSString *)message
        inViewController:(UIViewController *)viewController {
    
    FCAlertView *alert = [[FCAlertView alloc] init];

 
    [alert showAlertInView:viewController
                 withTitle:title // "Not Logged In"
              withSubtitle:message // "Do you want to login now?"
           withCustomImage:nil
       withDoneButtonTitle:kLang(@"ok") // "Login"
                andButtons:@[]]; // "Cancel"

    [alert doneActionBlock:^{}];

}


+ (CGFloat)topPadding {
    if (@available(iOS 11.0, *)) {
        UIWindow *window = [[[UIApplication sharedApplication] windows] firstObject]; // Get the first window
        if (window) { // Ensure the window is valid
            UIEdgeInsets safeAreaInsets = window.safeAreaInsets;
            return safeAreaInsets.top;
        } else {
            // Fallback if window is nil (unlikely in most cases)
            return  20.0;
        }

    }
    else
        return 20.0;
}

+ (CGFloat)navBarPadding {
    if (@available(iOS 11.0, *)) {
        UIWindow *window = [[[UIApplication sharedApplication] windows] firstObject]; // Get the first window
        if (window) { // Ensure the window is valid
            UIEdgeInsets safeAreaInsets = window.safeAreaInsets;
            return safeAreaInsets.top + 44;
        } else {
            // Fallback if window is nil (unlikely in most cases)
            return  20.0;
        }

    }
    else
        return 20.0;
}

+ (CGFloat)bottomPadding {
    if (@available(iOS 11.0, *)) {
        UIWindow *window = [[[UIApplication sharedApplication] windows] firstObject]; // Get the first window
        if (window) { // Ensure the window is valid
            UIEdgeInsets safeAreaInsets = window.safeAreaInsets;
            return safeAreaInsets.bottom;
        } else {
            // Fallback if window is nil (unlikely in most cases)
            return 0.0;
        }

    } else {
        return 0.0;
    }
}

+(FTPopOverMenuConfiguration *)configMenu:(FTPopOverMenuConfiguration *)configuration
{
    configuration = [FTPopOverMenuConfiguration defaultConfiguration];
    configuration.menuRowHeight = 44;
    configuration.backgroundColor = AppForgroundColr; //[UIColor whiteColor];
    configuration.menuWidth = 200;
    configuration.textColor = AppSecondaryTextClr;//[UIColor blackColor];
    configuration.textFont = [GM MidFontWithSize:14];
    configuration.borderColor =  [AppBackgroundClr  colorWithAlphaComponent:0.9];;
    configuration.borderWidth = 0.1;
    configuration.textAlignment = NSTextAlignmentCenter;
    configuration.ignoreImageOriginalColor = NO;// set 'ignoreImageOriginalColor' to YES, images color will be same as textColor
    configuration.allowRoundedArrow = YES;
    configuration.menuCornerRadius = 16;
    configuration.selectedCellBackgroundColor = AppBackgroundClr;
    configuration.selectedTextColor = GM.AppWhiteColor;//[UIColor blackColor];
    configuration.separatorColor =  [AppBackgroundClrLigter  colorWithAlphaComponent:0.5];
    configuration.separatorInset = UIEdgeInsetsMake(0, 50, 0, 7);
    return configuration;
}


+(UIFont *)fontWithSize:(float)fontSize
{
    return [UIFont fontWithName:@"Beiruti-Regular" size:fontSize + 1];
   // return [GM MidFontWithSize:fontSize];
}

+(UIFont *)boldFontWithSize:(float)fontSize
{
    return [UIFont fontWithName:@"Beiruti-Bold" size:fontSize + 1];
    
}

+(UIFont *)MidFontWithSize:(float)fontSize
{
    return [UIFont fontWithName:@"Beiruti-Medium" size:fontSize + 1];
}

+ (void)setXForView:(UILabel *)view inSuperview:(UIView *)superview padding:(CGFloat)padding {
    BOOL isRTL = [Language languageVal] == 0 ? NO : YES;
    
    view.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    CGFloat newX = isRTL
        ? superview.bounds.size.width - view.bounds.size.width - padding
        : padding;

    CGRect frame = view.frame;
    frame.origin.x = newX;
    view.frame = frame;
}


+ (NSString *)formattedDate:(NSDate *)date {
    if (!date) return @"—";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd";
    return [formatter stringFromDate:date];
}


+ (void)playSoundWithName:(NSString *)name type:(NSString *)type {
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:type];
    if (!path) return;

    NSURL *url = [NSURL fileURLWithPath:path];
    static AVAudioPlayer *player;

    player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    player.volume = 0.6; // 60%

    [player prepareToPlay];
    [player play];
}


+ (BOOL)thereIsUser {
    //NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSString *userID = UserManager.sharedManager.currentUser.ID;
    return (userID != nil && userID.length > 0);
}

// GEMINI AIzaSyAhMN0yFCCAJgcZ9jpPp5uLv3gpOBidbLI

+ (void)sendPromptToGemini:(NSString *)prompt
                completion:(void (^)(NSString *responseText, NSError *error))completion {

    NSString *apiKey = @"AIzaSyAhMN0yFCCAJgcZ9jpPp5uLv3gpOBidbLI";
    NSString *urlString = [NSString stringWithFormat:
        @"https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=%@",
        apiKey];

    NSURL *url = [NSURL URLWithString:urlString];

    NSDictionary *requestBody = @{
        @"contents": @[
            @{@"parts": @[@{@"text": prompt}]}
        ]
    };

    NSError *jsonError = nil;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:requestBody options:0 error:&jsonError];
    if (jsonError) {
        if (completion) completion(nil, jsonError);
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody = bodyData;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            //NSLog(@"❌ Network error: %@", error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSLog(@"🌐 HTTP Status Code: %ld", (long)httpResponse.statusCode);

        NSString *rawResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"📩 Raw Response:\n%@", rawResponse);

        NSError *parseError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        if (parseError) {
            if (completion) completion(nil, parseError);
            return;
        }

        NSArray *candidates = json[@"candidates"];
        if (candidates.count > 0) {
            NSDictionary *firstCandidate = candidates[0];
            NSDictionary *content = firstCandidate[@"content"];
            NSArray *parts = content[@"parts"];
            NSString *resultText = parts.firstObject[@"text"];
            if (completion) completion(resultText, nil);
        } else {
            if (completion) completion(@"No response", nil);
        }
    }];

    [task resume];

}

+ (void)goToRegistrationFromController:(UIViewController *)controller {
    FCAlertView *alert = [[FCAlertView alloc] init];

 
    [alert showAlertInView:controller
                 withTitle:kLang(@"not_logged_in") // "Not Logged In"
              withSubtitle:kLang(@"do_you_want_to_login") // "Do you want to login now?"
           withCustomImage:[UIImage imageNamed:@"warning"]
       withDoneButtonTitle:kLang(@"login") // "Login"
                andButtons:@[kLang(@"cancel")]]; // "Cancel"

    [alert doneActionBlock:^{
        //NSLog(@"USER ----->> Tapped Login");

        //PPUserSigningController
    }];

    
}


+(NSTextAlignment)setAligment
{
    if([Language languageVal] == 0)
        return NSTextAlignmentLeft;
    else
        return NSTextAlignmentRight;
}
+(UISemanticContentAttribute)setSemantic
{
    if([Language languageVal] == 0)
        return UISemanticContentAttributeForceLeftToRight;
    else
        return UISemanticContentAttributeForceRightToLeft;
}


+(NSString *)cleanID
{
    NSString *uniqueID = [[NSUUID UUID] UUIDString];

    // Lowercase version
    //NSString *lowerID = [uniqueID lowercaseString];

    // Remove dashes
    NSString *cleanID = [uniqueID stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return cleanID;
}


+(UIColor *)AppForegroundColor
{ return UIColor.secondarySystemBackgroundColor; //[UIColor colorNamed:@"AppForegroundColor"];
}

+(UIColor *)backOffwhileColor
{ return UIColor.systemBackgroundColor ; //[UIColor colorNamed:@"AppBackgroundColor"];
}

+ (UIColor *)appPrimaryColor { return [UIColor colorNamed:@"AppPrimaryColor"];
}

+ (UIColor *)AppPrimaryColorShainer { return [UIColor colorNamed:@"AppPrimaryColorShainer"];
}

+ (UIColor *)AppWhiteColor {  return [UIColor colorNamed:@"AppWhiteColor"];
}


+ (UIColor *)AppShadowColor { return [UIColor colorNamed:@"AppShadowColor"];
}

+ (UIColor *)AppPrimaryColorDarker { return [UIColor colorNamed:@"AppPrimaryColorDarker"];
}

+ (UIColor *)PrimaryTextColor {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:0.95 alpha:1.0]; // Light text for dark mode
        } else {
            return [UIColor blackColor]; // Dark text for light mode
        }
    }];
}

+ (UIColor *)AccentsColor {
    return [UIColor colorNamed:@"AccentsColor"];
}


+ (UIColor *)SecondaryTextColor {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:0.7 alpha:1.0]; // Light text for dark mode
        } else {
            return [UIColor darkGrayColor]; // Dark text for light mode
        }
    }];
}

+ (UIColor *)PlaceholderTextColor {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:0.5 alpha:1.0]; // Light text for dark mode
        } else {
            return [UIColor lightGrayColor]; // Dark text for light mode
        }
    }];
}



+ (void)showLanguageSetupAlertFromForFirstTime:(UIViewController *)viewController {
    
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (![defaults objectForKey:@"LgAlreadySet"]) {
        //NSLog(@"🔤 First time language setup, setting LgAlreadySet flag.");
        
        // Set the value (you can use YES or a timestamp or whatever makes sense)
        [defaults setBool:YES forKey:@"LgAlreadySet"];
        [defaults synchronize]; // not strictly required, but safe if you want immediate persistence
        
    //NSLog(@"LANG ----->> showLanguageSetupAlertFrom");
    
    NSString *title = kLang(@"Language Setup");
    NSString *currentLangName = ([Language languageVal] == 0) ? @"English" : @"العربية";
    NSString *detail = [NSString stringWithFormat:@"%@ %@",
                        kLang(@"We detected this is your first time using the app, so we set your app language to"),
                        currentLangName];

    NSString *changeTitle = ([Language languageVal] == 0) ? @"تغيير للغة العربية" : @"Change to English";
    NSString *cancelTitle = kLang(@"cancel");

    //NSLog(@"LANG ----->> detail : %@",detail);
    
    FCAlertView *alert = [[FCAlertView alloc] init];

    //[alert makeAlertTypeSuccess];
    alert.dismissOnOutsideTouch = 0;
    alert.hideDoneButton = 0;
        alert.colorScheme = alert.flatRed;
    alert.avoidCustomImageTint = YES;
    [alert showAlertInView:viewController
                 withTitle:title // "Not Logged In"
              withSubtitle:detail
           withCustomImage:[UIImage imageNamed:@"arabic1"]
       withDoneButtonTitle:changeTitle // "Login"
                andButtons:@[cancelTitle]]; // "Cancel"

    [alert doneActionBlock:^{
        //NSLog(@"USER ----->> changeTitle");

        
        NSInteger newLangVal = ([Language languageVal] == 0) ? 1 : 0;
        [Language userSelectedLanguage:LanguageCode[newLangVal]];
       // [self reloadAppUI];

    }];
        
        
    } else {
        //NSLog(@"✅ Language was already set before. Skipping setup alert.");
    }
}




+ (void)showLanguageAlert:(UIViewController *)viewController {
    //NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSString *title = kLang(@"Language Setup");
    //NSString *currentLangName = ([Language languageVal] == 0) ? @"English" : @"العربية";

    FCAlertView *alert = [[FCAlertView alloc] init];
    alert.dismissOnOutsideTouch = NO;
    alert.hideDoneButton = NO;
    alert.colorScheme = alert.flatRed;
    alert.avoidCustomImageTint = YES;
    
    // Subsequent runs: offer to change the language
    NSString *detail = ([Language languageVal] == 0) ? @"Do you want to change Pure Pets app language?" : @"هل تريد تغيير لغة تطبيق Pure Pets؟";
    NSString *changeTitle = ([Language languageVal] == 0) ? @"تغيير للغة العربية" : @"Change to English";
    NSString *cancelTitle = kLang(@"cancel");

    [alert showAlertInView:viewController
                 withTitle:title
              withSubtitle:detail
           withCustomImage:[UIImage imageNamed:@"arabic1"]
       withDoneButtonTitle:changeTitle
                andButtons:@[cancelTitle]];

    [alert doneActionBlock:^{
        NSInteger newLangVal = ([Language languageVal] == 0) ? 1 : 0;
        [Language userSelectedLanguage:LanguageCode[newLangVal]];
         
    }];
}


+ (NSString *)safeString:(id)value {
    return ([value isKindOfClass:[NSString class]] && value != nil) ? value : @"";
}


+ (void)chatWith:(UserModel *)user FromController:(UIViewController *)controller
{
    [ChManager chatWith:user FromController:controller];
}

+(void)showMessagingWithChat:(ChatThreadModel *)chat FromController:(UIViewController *)controller
{
    ChMessagingController *chatVC = [[ChMessagingController alloc] initWithChatThread:chat];
    [PPFunc presentSheetFrom:controller
                     sheetVC:chatVC
                 detentStyle:PPSheetDetentStyleSemiLargAndLarge];
}


+ (void)addTapAnimationToView:(UIView *)view {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleCardTap:)];
    [view addGestureRecognizer:tap];
    view.userInteractionEnabled = YES;
}

+ (void)handleCardTap:(UITapGestureRecognizer *)tap {
    UIView *view = tap.view;
    [UIView animateWithDuration:0.1 animations:^{
        view.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            view.transform = CGAffineTransformIdentity;
        }];
        
        // TODO: Handle actual navigation or action here
    }];
}


+ (void)triggerHapticFeedback {
    AudioServicesPlaySystemSound(1519); // Light impact
}

+ (UIColor *)randomLightColor {
    CGFloat hue = (arc4random() % 256 / 256.0); // 0.0 to 1.0
    CGFloat saturation = ((arc4random() % 128 / 256.0) + 0.3); // 0.3 to 0.8
    CGFloat brightness = ((arc4random() % 128 / 256.0) + 0.7); // 0.7 to 1.0
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
}



// GM.m
+ (NSString *)formatPrice:(id)price {
    return [self formatPrice:price currencyCode:nil freeLabel:kLang(@"Free")];
}

+ (NSString *)formatPrice:(id)price currencyCode:(NSString * _Nullable)currencyCode {
    return [self formatPrice:price currencyCode:currencyCode freeLabel:kLang(@"Free")];
}

+ (NSString *)formatPrice:(id)price
             currencyCode:(NSString * _Nullable)currencyCode
                freeLabel:(NSString * _Nullable)freeLabel
{
    NSNumber *number = [self pp_coerceNumber:price];
    if (!number) return @"";

    if (fabs(number.doubleValue) < DBL_EPSILON) {
        return freeLabel ?: kLang(@"Free");
    }

    NSNumberFormatter *fmt = [NSNumberFormatter new];
    fmt.numberStyle = NSNumberFormatterCurrencyStyle;

    // Locale by app language (Arabic vs device default)
    NSString *localeID = ([Language languageVal] == 1) ? @"ar_QA" : NSLocale.currentLocale.localeIdentifier;
    fmt.locale = [NSLocale localeWithLocaleIdentifier:localeID];

    if (currencyCode.length) {
        fmt.currencyCode = currencyCode;
    }

    // Show decimals only when needed, up to 2
    double v = fabs(number.doubleValue);
    BOOL hasCents = fmod(v, 1.0) > 0.0001;
    fmt.minimumFractionDigits = hasCents ? 2 : 0;
    fmt.maximumFractionDigits = 2;

    return [fmt stringFromNumber:number] ?: @"";
}

// Helpers
+ (NSNumber *)pp_coerceNumber:(id)price {
    if (!price || price == (id)kCFNull) return nil;

    if ([price isKindOfClass:[NSNumber class]]) {
        return (NSNumber *)price;
    }

    if ([price isKindOfClass:[NSString class]]) {
        NSString *s = [(NSString *)price stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (s.length == 0) return nil;

        // Keep digits, separators, minus
        NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"0123456789.,-"];
        NSMutableString *filtered = [NSMutableString stringWithCapacity:s.length];
        for (NSUInteger i = 0; i < s.length; i++) {
            unichar c = [s characterAtIndex:i];
            if ([allowed characterIsMember:c]) [filtered appendFormat:@"%C", c];
        }

        // Normalize comma to dot for parsing
        NSString *normalized = [filtered stringByReplacingOccurrencesOfString:@"," withString:@"."];
        return @([normalized doubleValue]);
    }

    return nil;
}



+ (void)showDeleteConfirmationFrom:(UIViewController *)viewController
                             title:(NSString *)title
                           message:(NSString *)message
                        completion:(void (^)(BOOL confirmed))completion {
    
    NSString *deleteTitle = kLang(@"Delete");
    NSString *cancelTitle = kLang(@"Cancel");
    
    FCAlertView *alert = [[FCAlertView alloc] init];
    alert.dismissOnOutsideTouch = 0;
    alert.hideDoneButton = 0;
    alert.colorScheme = GM.appPrimaryColor; // Or your app primary color
    alert.avoidCustomImageTint = YES;
    
    [alert showAlertInView:viewController
                 withTitle:title
              withSubtitle:message
           withCustomImage:[UIImage imageNamed:@"warning_icon"] // Replace with your warning image
       withDoneButtonTitle:deleteTitle
                andButtons:@[]];
    
    [alert doneActionBlock:^{
        //NSLog(@"✅ User confirmed delete");
        if (completion) completion(YES);
    }];
    
    [alert addButton:cancelTitle withActionBlock:^{
        //NSLog(@"❌ User cancelled delete");
        if (completion) completion(NO);
    }];
}

+ (void)ActivityLoadingAnimationView:(BOOL)show onController:(UIViewController *)vc {
    if (!vc) return;
    [self ActivityLoadingAnimationView:show onView:vc.view];
}

+ (void)ActivityLoadingAnimationView:(BOOL)show onView:(UIView *)view {
    if (!view) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (show) {
            // If overlay already exists, just show & play
            UIView *overlay = objc_getAssociatedObject(view, &kGMActivityOverlayAssocKey);
            if (overlay) {
                LOTAnimationView *anim = (LOTAnimationView *)[overlay viewWithTag:GMActivityAnimTag];
                if ([anim isKindOfClass:LOTAnimationView.class]) {
                    anim.loopAnimation = YES;
                    [anim play];
                }
                overlay.alpha = 1.0;
                return;
            }

            // Create overlay
            UIView *overlayView = [[UIView alloc] initWithFrame:view.bounds];
            overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            overlayView.backgroundColor = [UIColor clearColor]; // or dim color if you prefer
            overlayView.userInteractionEnabled = YES;           // block touches
            overlayView.alpha = 0.0;

            // Lottie view
            CGFloat size = 70.0;
            CGRect box = CGRectMake((CGRectGetWidth(view.bounds)-size)/2.0,
                                    (CGRectGetHeight(view.bounds)-size)/2.0,
                                    size,
                                    size);

            LOTAnimationView *activity = [[LOTAnimationView alloc] init];
            activity.tag = GMActivityAnimTag;
            activity.frame = box;
            activity.contentMode = UIViewContentModeScaleAspectFill;
            activity.loopAnimation = YES;
            activity.userInteractionEnabled = NO;

            [overlayView addSubview:activity];
            [view addSubview:overlayView];

            // Associate overlay to the host view so we can remove it later
            objc_setAssociatedObject(view, &kGMActivityOverlayAssocKey, overlayView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            // Fade in
            [UIView animateWithDuration:0.2 animations:^{
                overlayView.alpha = 1.0;
            }];

            // Load JSON then play
            __weak LOTAnimationView *weakAnim = activity;
            [AppClasses fetchLottieJSONFromFirebasePath:@"LottieAnimations/ActivityLoadingAnimation.json"
                                             completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    LOTAnimationView *anim = weakAnim;
                    if (!anim) return;

                    if (error) {
                        //NSLog(@"Lottie ❌ %@", error.localizedDescription);
                        return;
                    }
                    if (![jsonDict isKindOfClass:NSDictionary.class]) {
                        //NSLog(@"Lottie ❌ Invalid JSON");
                        return;
                    }

                    LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
                    if (composition) {
                        [anim setSceneModel:composition];
                        [anim play];
                    } else {
                        //NSLog(@"Lottie ❌ Failed to create composition");
                    }
                });
            }];

        } else {
            // Hide/remove overlay
            UIView *overlay = objc_getAssociatedObject(view, &kGMActivityOverlayAssocKey);
            if (!overlay) return;

            LOTAnimationView *anim = (LOTAnimationView *)[overlay viewWithTag:GMActivityAnimTag];
            [anim stop];

            [UIView animateWithDuration:0.2 animations:^{
                overlay.alpha = 0.0;
            } completion:^(BOOL finished) {
                [overlay removeFromSuperview];
                objc_setAssociatedObject(view, &kGMActivityOverlayAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }];
        }
    });
}





- (void)migrateMainKindsImages {
    FIRFirestore *db = [FIRFirestore firestore];
    FIRStorage *storage = [FIRStorage storage];
    
    [[db collectionWithPath:@"MainKindsCollection"] getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) {
            //NSLog(@"❌ Failed to fetch MainKinds: %@", error.localizedDescription);
            return;
        }
        
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            NSDictionary *data = doc.data;
            //NSString *kindName = data[@"KindNameAr"] ?: @"";
            NSString *imageNamed = data[@"KindImageNamed"];
            NSString *existingUrl = data[@"KindImageUrl"];
            
            if (existingUrl.length > 0) {
                //NSLog(@"📦 Skipping %@ (already has KindImageUrl)", kindName);
                continue; // already has URL
            }
            
            if (imageNamed.length == 0) {
                //NSLog(@"⏭ No image name for %@", kindName);
                continue;
            }
            
            // Create storage ref
            FIRStorageReference *ref = [[storage reference] child:[NSString stringWithFormat:@"MainDataImages/%@.png", imageNamed]];
            
            // Fetch download URL
            [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
                if (error) {
                    //NSLog(@"❌ Failed to get URL for %@: %@", imageNamed, error.localizedDescription);
                    return;
                }
                
                if (URL) {
                    //NSLog(@"✅ Got URL for %@ (%@)", kindName, URL.absoluteString);
                    
                    // Update Firestore document
                    [[[db collectionWithPath:@"MainKindsCollection"] documentWithPath:doc.documentID]
                        setData:@{@"KindImageUrl": URL.absoluteString}
                        merge:YES
                        completion:^(NSError * _Nullable error) {
                            if (error) {
                                //NSLog(@"❌ Failed to update %@: %@", kindName, error.localizedDescription);
                            } else {
                                //NSLog(@"🔥 Updated Firestore with URL for %@", kindName);
                            }
                        }];
                }
            }];
        }
    }];
}



+ (void)refershProfilePhoto:(nonnull UIViewController *)VC {
    
}


+ (void)fetchDownloadURLForPath:(NSString *)path
                     imageName:(NSString *)imageName
                    completion:(void (^)(NSURL * _Nullable url, NSError * _Nullable error))completion
{
    // ✅ Validate inputs
    if (path.length == 0 || imageName.length == 0) {
        NSError *error = [NSError errorWithDomain:@"PPFirebaseHelperError"
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey : @"Invalid path or image name."}];
        if (completion) completion(nil, error);
        return;
    }
    
    // ✅ Get a reference to the storage service
    FIRStorage *storage = [FIRStorage storage];
    FIRStorageReference *rootRef = [storage reference];
    
    // ✅ Build full file reference
    NSString *fullPath = [NSString stringWithFormat:@"%@/%@", path, imageName];
    FIRStorageReference *fileRef = [rootRef child:fullPath];
    
    NSLog(@"📡 [PPFirebaseHelper] Fetching download URL for %@", fullPath);
    
    // ✅ Download URL request
    [fileRef downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ [PPFirebaseHelper] Failed to get URL for %@: %@", fullPath, error.localizedDescription);
            if (completion) completion(nil, error);
            return;
        }
        
        NSLog(@"✅ [PPFirebaseHelper] Success: %@", URL.absoluteString);
        if (completion) completion(URL, nil);
    }];
}

















// Image

#pragma mark - Image Fetcher (No UIImageView Dependency)

+ (void)fetchImageFromURLString:(NSString *)urlString
                     completion:(ImageCompletionBlock)completion
{
    [self fetchImageFromURLString:urlString
                      placeholder:nil
                       completion:completion];
}

+ (void)fetchImageFromURLString:(NSString *)urlString
                    placeholder:(NSString * _Nullable)placeholderName
                     completion:(ImageCompletionBlock)completion
{
    // Validate completion block
    if (!completion) return;
    
    // Handle invalid URLs immediately
    if (urlString.length == 0) {
        UIImage *placeholder = placeholderName.length ? [UIImage imageNamed:placeholderName] : nil;
        completion(placeholder, [NSError errorWithDomain:@"ImageLoader"
                                                    code:0
                                                userInfo:@{NSLocalizedDescriptionKey:@"Empty URL"}]);
        return;
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        UIImage *placeholder = placeholderName.length ? [UIImage imageNamed:placeholderName] : nil;
        completion(placeholder, [NSError errorWithDomain:@"ImageLoader"
                                                    code:1
                                                userInfo:@{NSLocalizedDescriptionKey:@"Invalid URL"}]);
        return;
    }
    
    // Check memory cache first (fastest)
    UIImage *cachedImage = [self cachedImageForURL:url];
    if (cachedImage) {
        completion(cachedImage, nil);
        return;
    }
    
    // Use YYWebImage's manager directly
    YYWebImageManager *manager = [YYWebImageManager sharedManager];
    
    // Check disk cache
    [manager.cache getImageForKey:[manager cacheKeyForURL:url]
                         withType:YYImageCacheTypeAll
                            withBlock:^(UIImage * _Nullable image, YYImageCacheType type) {
        
        if (image) {
            // Found in disk cache, also store in memory for next time
            [manager.cache setImage:image
                            forKey:[manager cacheKeyForURL:url] ];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(image, nil);
            });
            return;
        }
        
        // Not in cache, download from network
        [self downloadImageFromURL:url
                       placeholder:placeholderName
                        completion:completion];
    }];
}

+ (UIImage *)cachedImageForURL:(NSURL *)url {
    YYWebImageManager *manager = [YYWebImageManager sharedManager];
    return [manager.cache getImageForKey:[manager cacheKeyForURL:url]
                                withType:YYImageCacheTypeAll];
}

+ (void)downloadImageFromURL:(NSURL *)url
                 placeholder:(NSString * _Nullable)placeholderName
                  completion:(ImageCompletionBlock)completion
{
    YYWebImageOptions options =
        YYWebImageOptionProgressiveBlur |
        YYWebImageOptionShowNetworkActivity |
        YYWebImageOptionAllowBackgroundTask |
        YYWebImageOptionAvoidSetImage; // We handle setting image manually
    
    // Create a request
    YYWebImageOperation *operation =
    [[YYWebImageManager sharedManager] requestImageWithURL:url
                                                   options:options
                                                  progress:nil
                                                 transform:nil
                                                completion:^(UIImage * _Nullable image,
                                                            NSURL * _Nonnull url,
                                                            YYWebImageFromType from,
                                                            YYWebImageStage stage,
                                                            NSError * _Nullable error) {
        
        UIImage *resultImage = image;
        
        if (error) {
            NSLog(@"❌ Image download failed: %@", error.localizedDescription);
            resultImage = placeholderName.length ? [UIImage imageNamed:placeholderName] : nil;
        }
        
        // Always cache the result (even if it's placeholder)
        if (resultImage) {
            [[YYWebImageManager sharedManager].cache setImage:resultImage
                                                      forKey:[[YYWebImageManager sharedManager] cacheKeyForURL:url]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(resultImage, error);
        });
    }];
    
    // Optional: Store operation for potential cancellation
    [self storeOperation:operation forURL:url];
}

#pragma mark - Batch Image Fetching

+ (void)fetchImagesFromURLStrings:(NSArray<NSString *> *)urlStrings
                       completion:(ImageCompletionBlock)completion
{
    if (!completion) return;
    
    dispatch_group_t group = dispatch_group_create();
    NSMutableDictionary<NSString *, UIImage *> *images = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSError *> *errors = [NSMutableDictionary dictionary];
    
    for (NSString *urlString in urlStrings) {
        dispatch_group_enter(group);
        
        [self fetchImageFromURLString:urlString completion:^(UIImage * _Nullable image, NSError * _Nullable error) {
            @synchronized(images) {
                if (image) {
                    images[urlString] = image;
                }
                if (error) {
                    errors[urlString] = error;
                }
            }
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        completion([images copy], [errors copy]);
    });
}

#pragma mark - Prefetching

+ (void)prefetchImagesForURLStrings:(NSArray<NSString *> *)urlStrings
{
    for (NSString *urlString in urlStrings) {
        NSURL *url = [NSURL URLWithString:urlString];
        if (!url) continue;
        
        YYWebImageManager *manager = [YYWebImageManager sharedManager];
        
        // Skip if already in memory cache
        if ([manager.cache containsImageForKey:[manager cacheKeyForURL:url]
                                     withType:YYImageCacheTypeMemory]) {
            continue;
        }
        
        // Prefetch with low priority
        [manager requestImageWithURL:url
                             options:YYWebImageOptionIgnoreImageDecoding
                            progress:nil
                           transform:nil
                          completion:nil]; // No completion needed for prefetch
    }
}

#pragma mark - Cache Management

+ (void)clearMemoryCache {
    [[YYWebImageManager sharedManager].cache.memoryCache removeAllObjects];
    NSLog(@"[YYWebImageManager]: memoryCache Cleared");
}

+ (void)clearImagesDiskCache {
    [self clearDiskCache];
    [self clearMemoryCache];
 
}


+ (void)clearDiskCache {
    [[YYWebImageManager sharedManager].cache.diskCache removeAllObjects];
    NSLog(@"[YYWebImageManager]: memoryCache Cleared");

}

+ (NSUInteger)getMemoryCacheSize {
    return [[YYWebImageManager sharedManager].cache.memoryCache totalCost];
}

+ (NSUInteger)getDiskCacheSize {
    return [[YYWebImageManager sharedManager].cache.diskCache totalCost];
}

#pragma mark - Operation Tracking (Optional)

static NSMapTable<NSURL *, YYWebImageOperation *> *_operations;

+ (void)storeOperation:(YYWebImageOperation *)operation forURL:(NSURL *)url {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _operations = [NSMapTable strongToWeakObjectsMapTable];
    });
    
    @synchronized(_operations) {
        [_operations setObject:operation forKey:url];
    }
}

+ (void)cancelImageFetchForURL:(NSURL *)url {
    @synchronized(_operations) {
        YYWebImageOperation *operation = [_operations objectForKey:url];
        [operation cancel];
        [_operations removeObjectForKey:url];
    }
}

+ (void)cancelAllImageFetches {
    @synchronized(_operations) {
        for (YYWebImageOperation *operation in _operations.objectEnumerator) {
            [operation cancel];
        }
        [_operations removeAllObjects];
    }
}
@end


































/* ======================================================= ==================FBStorageURLProvider     =============== ======================  */
