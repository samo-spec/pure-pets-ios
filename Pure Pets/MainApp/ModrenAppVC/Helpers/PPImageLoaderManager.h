//
//  PPImageLoaderManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/01/2026.
//


//
//  PPImageLoaderManager.h
//  PurePets
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PPImageTransitionStyle) {
    PPImageTransitionStyleNone,
    PPImageTransitionStyleFade,
    PPImageTransitionStyleCrossDissolve
};
 

@interface PPImageLoaderManager : NSObject

+ (instancetype)shared;

/// Main image loader (recommended)
- (void)setImageOnImageView:(UIImageView *)imageView
                        url:(nullable NSString *)urlString complation:(nullable PPImageLoaderManagerComplation)complation;
- (void)fetchImageWithURL:(nullable NSString *)urlString
               completion:(void (^)(UIImage * _Nullable image))completion;
/// Main image loader (recommended)
- (void)setImageOnImageView:(UIImageView *)imageView
                        url:(nullable NSString *)urlString
                placeholder:(nullable UIImage *)placeholder
                 complation:(nullable PPImageLoaderManagerComplation)complation;

/// Main image loader (recommended)
- (void)setImageOnImageView:(UIImageView *)imageView
                        url:(nullable NSString *)urlString
                placeholder:(nullable UIImage *)placeholder
           transitionStyle:(PPImageTransitionStyle)transitionStyle
                 complation:(nullable PPImageLoaderManagerComplation)complation;

/// Cancel loading safely (cell reuse)
- (void)cancelImageLoadForImageView:(UIImageView *)imageView;

/// Prefetch for feeds / galleries
- (void)prefetchURLs:(NSArray<NSString *> *)urlStrings;
/// Cancel in-flight prefetch batch work (used when fast scrolling changes direction)
- (void)cancelAllPrefetching;

/// Cache management
- (void)clearMemoryCache;
- (void)clearDiskCache;
- (void)setImageOnImageView:(UIImageView *)imageView url:(NSString *_Nullable)urlString;
- (void)backfillBlurHashIfNeededForImage:(UIImage *)image
                                 itemID:(NSString *)itemID
                            blurHashKey:(NSString *)blurHashKey
                              collection:(NSString *)collectionName;
- (void)setImageOnImageView:(UIImageView *)imageView
                        url:(nullable NSString *)urlString
                   blurHash:(nullable NSString *)blurHash
           transitionStyle:(PPImageTransitionStyle)transitionStyle
                 complation:(nullable PPImageLoaderManagerComplation)complation;
@end

NS_ASSUME_NONNULL_END
