//
//  PPImageSearchService.m
//  Pure Pets
//
//  Direct search by photo service.
//  Sends compressed image to Firebase callable function: imageSearch.
//  Keep Gemini API key only on Firebase Functions, never in iOS.
//

#import "PPImageSearchService.h"
@import FirebaseFunctions;

@interface PPImageSearchService ()
@property (nonatomic, strong) FIRFunctions *functions;
@end

@implementation PPImageSearchService

static const CGFloat PPImageSearchInitialMaxSide = 1024.0;
static const CGFloat PPImageSearchMinimumMaxSide = 512.0;
static const CGFloat PPImageSearchInitialJPEGQuality = 0.72;
static const CGFloat PPImageSearchMinimumJPEGQuality = 0.48;
static const NSUInteger PPImageSearchMaxBase64Length = 1100000;
static const NSInteger PPImageSearchFunctionsErrorCodeResourceExhausted = 8;

static NSString *PPImageSearchDisplayMessageForError(NSError *error)
{
    NSString *rawMessage = error.localizedDescription ?: @"";
    NSString *normalized = rawMessage.lowercaseString;
    BOOL isRawInternal =
        [normalized isEqualToString:@"internal"] ||
        [normalized containsString:@"internal error"] ||
        [normalized containsString:@"image understanding"] ||
        [normalized containsString:@"gemini"] ||
        [normalized containsString:@"api key"] ||
        error.code == FIRFunctionsErrorCodeInternal ||
        error.code == FIRFunctionsErrorCodeFailedPrecondition ||
        error.code == FIRFunctionsErrorCodeUnavailable ||
        error.code == FIRFunctionsErrorCodeDeadlineExceeded ||
        error.code == PPImageSearchFunctionsErrorCodeResourceExhausted;

    if (isRawInternal) {
        NSString *message = kLang(@"ImageSearchServiceUnavailable");
        return message.length > 0 ? message : kLang(@"ImageSearchError");
    }

    return rawMessage.length > 0 ? rawMessage : kLang(@"ImageSearchError");
}

+ (instancetype)shared {
    static PPImageSearchService *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PPImageSearchService alloc] initPrivate];
    });
    return sharedInstance;
}

- (instancetype)init {
    return [PPImageSearchService shared];
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _functions = [FIRFunctions functionsForRegion:@"us-central1"];
    }
    return self;
}

+ (NSString *)stringForMode:(PPImageSearchMode)mode {
    switch (mode) {
        case PPImageSearchModeProducts:
            return @"products";
        case PPImageSearchModePets:
            return @"pets";
        case PPImageSearchModeAdoption:
            return @"adoption";
        case PPImageSearchModeAuto:
        default:
            return @"auto";
    }
}

- (UIImage *)pp_resizedImage:(UIImage *)image maxSide:(CGFloat)maxSide {
    if (!image) { return nil; }

    CGFloat width = image.size.width;
    CGFloat height = image.size.height;

    if (width <= 0 || height <= 0) { return image; }

    CGFloat scale = MIN(maxSide / width, maxSide / height);
    if (scale >= 1.0) { return image; }

    CGSize newSize = CGSizeMake(width * scale, height * scale);

    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return resized ?: image;
}

- (NSData *)pp_jpegDataForImage:(UIImage *)image {
    CGFloat maxSide = PPImageSearchInitialMaxSide;
    CGFloat quality = PPImageSearchInitialJPEGQuality;

    while (maxSide >= PPImageSearchMinimumMaxSide) {
        UIImage *resizedImage = [self pp_resizedImage:image maxSide:maxSide];

        while (quality >= PPImageSearchMinimumJPEGQuality) {
            NSData *data = UIImageJPEGRepresentation(resizedImage, quality);
            NSUInteger base64Length = ((data.length + 2) / 3) * 4;
            if (data && base64Length <= PPImageSearchMaxBase64Length) {
                return data;
            }

            quality -= 0.08;
        }

        maxSide -= 120.0;
        quality = PPImageSearchInitialJPEGQuality;
    }

    UIImage *fallbackImage = [self pp_resizedImage:image maxSide:PPImageSearchMinimumMaxSide];
    return UIImageJPEGRepresentation(fallbackImage, PPImageSearchMinimumJPEGQuality);
}

- (void)searchWithImage:(UIImage *)image
                   mode:(PPImageSearchMode)mode
                  limit:(NSNumber * _Nullable)limit
             completion:(void (^)(NSDictionary * _Nullable response,
                                   NSError * _Nullable error))completion {
    if (!image) {
        NSError *error = [NSError errorWithDomain:@"PPImageSearchService"
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"ImageSearchImageRequired")}];
        if (completion) { completion(nil, error); }
        return;
    }

    NSData *jpegData = [self pp_jpegDataForImage:image];

    if (!jpegData) {
        NSError *error = [NSError errorWithDomain:@"PPImageSearchService"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"ImageSearchCompressionFailed")}];
        if (completion) { completion(nil, error); }
        return;
    }

    NSString *base64 = [jpegData base64EncodedStringWithOptions:0];
    if (base64.length > PPImageSearchMaxBase64Length) {
        NSError *error = [NSError errorWithDomain:@"PPImageSearchService"
                                             code:1004
                                         userInfo:@{NSLocalizedDescriptionKey: kLang(@"ImageSearchImageTooLarge")}];
        if (completion) { completion(nil, error); }
        return;
    }

    NSDictionary *payload = @{
        @"imageBase64": base64,
        @"contentType": @"image/jpeg",
        @"searchMode": [PPImageSearchService stringForMode:mode],
        @"limit": limit ?: @20
    };

    FIRHTTPSCallable *callable = [self.functions HTTPSCallableWithName:@"imageSearch"];

    [callable callWithObject:payload completion:^(FIRHTTPSCallableResult * _Nullable result,
                                                  NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSString *message = PPImageSearchDisplayMessageForError(error);
                NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:error.userInfo ?: @{}];
                userInfo[NSLocalizedDescriptionKey] = message ?: @"";
                userInfo[NSUnderlyingErrorKey] = error;
                NSError *displayError = [NSError errorWithDomain:@"PPImageSearchService"
                                                            code:error.code
                                                        userInfo:userInfo.copy];
                if (completion) { completion(nil, displayError); }
                return;
            }

            NSDictionary *data = [result.data isKindOfClass:[NSDictionary class]]
                ? (NSDictionary *)result.data
                : nil;

            if (!data) {
                NSError *parseError = [NSError errorWithDomain:@"PPImageSearchService"
                                                          code:1003
                                                      userInfo:@{NSLocalizedDescriptionKey: kLang(@"ImageSearchInvalidResponse")}];
                if (completion) { completion(nil, parseError); }
                return;
            }

            if (completion) { completion(data, nil); }
        });
    }];
}

@end
