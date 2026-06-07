#import "PPSoundEffectPlayer.h"
@import FirebaseStorage;

static AVAudioPlayer *_currentPlayer = nil;

static NSString *_Nonnull pp_soundsCachePath(void) {
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *cachesDir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        path = [cachesDir stringByAppendingPathComponent:@"pp_sounds"];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:path]) {
            [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        }
    });
    return path;
}

static NSURL *_Nonnull pp_localURLForSoundNamed(NSString *fileName) {
    NSString *localPath = [pp_soundsCachePath() stringByAppendingPathComponent:fileName];
    return [NSURL fileURLWithPath:localPath];
}

static BOOL pp_soundIsCached(NSString *fileName) {
    return [[NSFileManager defaultManager] fileExistsAtPath:[pp_soundsCachePath() stringByAppendingPathComponent:fileName]];
}

@implementation PPSoundEffectPlayer

#pragma mark - Public

+ (void)playSoundNamed:(NSString *)fileName
           storagePath:(NSString *)storagePath
            completion:(void (^)(NSError *_Nullable error))completion {
    if (!fileName.length) {
        if (completion) {
            completion([NSError errorWithDomain:@"PPSoundEffectPlayer" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"File name is empty"}]);
        }
        return;
    }
    NSURL *localURL = pp_localURLForSoundNamed(fileName);
    if (pp_soundIsCached(fileName)) {
        [self pp_playFileAtURL:localURL completion:completion];
        return;
    }
    [self pp_downloadSoundNamed:fileName storagePath:storagePath completion:^(NSURL * _Nullable downloadedURL, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(error);
            return;
        }
        [self pp_playFileAtURL:downloadedURL completion:completion];
    }];
}

+ (void)preloadSoundNamed:(NSString *)fileName
              storagePath:(NSString *)storagePath
               completion:(void (^)(NSError *_Nullable error))completion {
    if (!fileName.length) {
        if (completion) {
            completion([NSError errorWithDomain:@"PPSoundEffectPlayer" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"File name is empty"}]);
        }
        return;
    }
    if (pp_soundIsCached(fileName)) {
        if (completion) completion(nil);
        return;
    }
    [self pp_downloadSoundNamed:fileName storagePath:storagePath completion:^(NSURL * _Nullable downloadedURL, NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}

+ (void)clearCache {
    NSString *cachePath = pp_soundsCachePath();
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:cachePath error:nil];
    for (NSString *file in contents) {
        [fm removeItemAtPath:[cachePath stringByAppendingPathComponent:file] error:nil];
    }
}

#pragma mark - Private

+ (void)pp_downloadSoundNamed:(NSString *)fileName
                  storagePath:(NSString *)storagePath
                   completion:(void (^)(NSURL *_Nullable localURL, NSError *_Nullable error))completion {
    FIRStorage *storage = [FIRStorage storage];
    FIRStorageReference *storageRef = [storage reference];
    NSString *fullPath = [storagePath stringByAppendingString:fileName];
    FIRStorageReference *soundRef = [storageRef child:fullPath];

    [soundRef downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSData *data = [NSData dataWithContentsOfURL:URL];
            if (!data) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(nil, [NSError errorWithDomain:@"PPSoundEffectPlayer" code:-2
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Failed to download sound data"}]);
                    }
                });
                return;
            }
            NSURL *localURL = pp_localURLForSoundNamed(fileName);
            NSError *writeError = nil;
            [data writeToURL:localURL options:NSDataWritingAtomic error:&writeError];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(writeError ? nil : localURL, writeError);
            });
        });
    }];
}

+ (void)pp_playFileAtURL:(NSURL *)fileURL
              completion:(void (^_Nullable)(NSError *_Nullable error))completion {
    if (_currentPlayer && _currentPlayer.isPlaying) {
        [_currentPlayer stop];
    }
    NSError *error = nil;
    _currentPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:&error];
    if (error) {
        _currentPlayer = nil;
        if (completion) completion(error);
        return;
    }
    _currentPlayer.volume = 0.8;
    [_currentPlayer prepareToPlay];
    [_currentPlayer play];
    if (completion) completion(nil);
}

@end
