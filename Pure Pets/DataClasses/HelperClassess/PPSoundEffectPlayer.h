#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPSoundEffectPlayer : NSObject

+ (void)playSoundNamed:(NSString *)fileName
           storagePath:(NSString *)storagePath
            completion:(void (^_Nullable)(NSError *_Nullable error))completion;

+ (void)preloadSoundNamed:(NSString *)fileName
              storagePath:(NSString *)storagePath
               completion:(void (^_Nullable)(NSError *_Nullable error))completion;

+ (void)clearCache;

@end

NS_ASSUME_NONNULL_END
