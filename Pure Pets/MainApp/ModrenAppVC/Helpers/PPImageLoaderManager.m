//
//  PPImageLoaderManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/01/2026.
//

//
//  PPImageLoaderManager.m
//  PurePets
//

#import "PPImageLoaderManager.h"
#import <SDWebImage/SDWebImage.h>

@implementation PPImageLoaderManager

+ (instancetype)shared {
    static PPImageLoaderManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PPImageLoaderManager alloc] init];
        [instance configureGlobalCache];
    });
    return instance;
}

#pragma mark - Global Configuration (ONE TIME)

- (void)configureGlobalCache {
    SDImageCacheConfig *config = SDImageCache.sharedImageCache.config;
    config.shouldCacheImagesInMemory = YES;
    config.shouldUseWeakMemoryCache = NO;
    config.diskCacheExpireType = SDImageCacheConfigExpireTypeAccessDate;
    config.maxDiskAge = 60 * 60 * 24 * 14; // 14 days
    config.maxDiskSize = 500 * 1024 * 1024; // 500 MB

    SDWebImageDownloader.sharedDownloader.config.downloadTimeout = 20;
    SDWebImageDownloader.sharedDownloader.config.executionOrder =
        SDWebImageDownloaderFIFOExecutionOrder;
}

#pragma mark - Public API

- (void)fetchImageWithURL:(nullable NSString *)urlString
               completion:(void (^)(UIImage * _Nullable image))completion
{
    if (urlString.length == 0) {
        if (completion) completion(nil);
        return;
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (completion) completion(nil);
        return;
    }

    SDWebImageOptions options =
        SDWebImageRetryFailed |
        SDWebImageHighPriority |
        SDWebImageScaleDownLargeImages;

    [[SDWebImageManager sharedManager]
        loadImageWithURL:url
                 options:options
                progress:nil
               completed:^(UIImage * _Nullable image,
                           NSData * _Nullable data,
                           NSError * _Nullable error,
                           SDImageCacheType cacheType,
                           BOOL finished,
                           NSURL * _Nullable imageURL)
    {
        if (!finished || error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil);
            });
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(image);
        });
    }];
}

- (void)setImageOnImageView:(UIImageView *)imageView
                        url:(nullable NSString *)urlString
                placeholder:(nullable UIImage *)placeholder
           transitionStyle:(PPImageTransitionStyle)transitionStyle
                 complation:(nullable PPImageLoaderManagerComplation)complation {

    if (!imageView) return;
    imageView.layer.actions = @{
        @"contents": [NSNull null]
    };
    [self cancelImageLoadForImageView:imageView];

    if (urlString.length == 0) {
        imageView.image = placeholder;
        return;
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        imageView.image = placeholder;
        return;
    }

    SDWebImageOptions options =
        SDWebImageRetryFailed |
        SDWebImageHighPriority |
        SDWebImageScaleDownLargeImages |
        SDWebImageAvoidAutoSetImage;

    __weak UIImageView *weakImageView = imageView;

    [imageView sd_setImageWithURL:url
                  placeholderImage:placeholder
                           options:options
                         completed:^(UIImage * _Nullable image,
                                     NSError * _Nullable error,
                                     SDImageCacheType cacheType,
                                     NSURL * _Nullable imageURL) {

        if (!image || !weakImageView) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self applyImage:image
                 toImageView:weakImageView
               transitionStyle:transitionStyle
                     fromCache:(cacheType != SDImageCacheTypeNone)];
        });
    }];
}

- (void)setImageOnImageView:(UIImageView *)imageView
                        url:(nullable NSString *)urlString
                   blurHash:(nullable NSString *)blurHash
           transitionStyle:(PPImageTransitionStyle)transitionStyle
                 complation:(nullable PPImageLoaderManagerComplation)complation
{
    if (!imageView) return;

    [self cancelImageLoadForImageView:imageView];

    // 1️⃣ BlurHash placeholder (instant, lightweight)
    if (blurHash.length > 0) {
        [PPBlurHashBridge setImageFrom:blurHash into:imageView size:imageView.size duration:0.0];
    }

    // 2️⃣ Continue with normal image loading pipeline
    [self setImageOnImageView:imageView
                          url:urlString
                  placeholder:blurHash.length > 0 ? nil : PPImage(@"placeholder")
              transitionStyle:transitionStyle complation:nil];
}

- (void)cancelImageLoadForImageView:(UIImageView *)imageView {
    [imageView sd_cancelCurrentImageLoad];
}

#pragma mark - Prefetching

- (void)prefetchURLs:(NSArray<NSString *> *)urlStrings {
    NSMutableArray<NSURL *> *urls = [NSMutableArray array];
    for (NSString *string in urlStrings) {
        NSURL *url = [NSURL URLWithString:string];
        if (url) [urls addObject:url];
    }

    if (urls.count == 0) return;

    [[SDWebImagePrefetcher sharedImagePrefetcher] prefetchURLs:urls];
}

- (void)cancelAllPrefetching {
    [[SDWebImagePrefetcher sharedImagePrefetcher] cancelPrefetching];
}

#pragma mark - Cache Control

- (void)clearMemoryCache {
    [SDImageCache.sharedImageCache clearMemory];
}

- (void)clearDiskCache {
    [SDImageCache.sharedImageCache clearDiskOnCompletion:nil];
}

#pragma mark - Animation

- (void)applyImage:(UIImage *)image
       toImageView:(UIImageView *)imageView
     transitionStyle:(PPImageTransitionStyle)transitionStyle
           fromCache:(BOOL)fromCache {

    // Never animate cached images (best practice)
    if (fromCache || transitionStyle == PPImageTransitionStyleNone) {
        imageView.image = image;
        return;
    }

    switch (transitionStyle) {
        case PPImageTransitionStyleFade: {
            imageView.alpha = 0.0;
            imageView.image = image;
            [UIView animateWithDuration:0.25
                             animations:^{
                imageView.alpha = 1.0;
            }];
            break;
        }

        case PPImageTransitionStyleCrossDissolve: {
            [UIView transitionWithView:imageView
                              duration:0.3
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                imageView.image = image;
            } completion:nil];
            break;
        }

        default:
            imageView.image = image;
            break;
    }
}


- (void)setImageOnImageView:(UIImageView *)imageView url:(NSString *_Nullable)urlString{
    [self setImageOnImageView:imageView url:urlString placeholder:PPImage(@"placeholder") complation:nil];
}


- (void)setImageOnImageView:(UIImageView *)imageView url:(NSString *_Nullable)urlString complation:(nullable PPImageLoaderManagerComplation)complation {
    [self setImageOnImageView:imageView url:urlString placeholder:PPImage(@"placeholder") complation:complation];
}

- (void)setImageOnImageView:(UIImageView *)imageView
                         url:(NSString *_Nullable)urlString
                 placeholder:(UIImage *_Nullable)placeholder
                 complation:(nullable PPImageLoaderManagerComplation)complation{

    [self setImageOnImageView:imageView url:urlString placeholder:placeholder transitionStyle:PPImageTransitionStyleCrossDissolve  complation:complation];
}


- (void)backfillBlurHashIfNeededForImage:(UIImage *)image
                                 itemID:(NSString *)itemID
                            blurHashKey:(NSString *)blurHashKey
                             collection:(NSString *)collectionName
{
    if (!image || itemID.length == 0) return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSString *blurHash = [PPBlurHashGenerator generateFrom:image];
        if (blurHash.length == 0) return;

        // Firestore update (ONE TIME)
        [[[[FIRFirestore firestore] collectionWithPath:collectionName] documentWithPath:itemID] updateData:@{ blurHashKey : blurHash }];
    });
}
@end
