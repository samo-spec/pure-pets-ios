//
//  PPFirebaseSessionBridge.h
//  Pure Pets
//
//  Centralized Firebase Auth/App Check request preparation for iOS.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, PPFirebaseSessionAuthorizationOptions) {
    PPFirebaseSessionAuthorizationOptionRequireSignedIn = 1 << 0,
    PPFirebaseSessionAuthorizationOptionForceRefreshAuth = 1 << 1,
    PPFirebaseSessionAuthorizationOptionIncludeAppCheck = 1 << 2,
    PPFirebaseSessionAuthorizationOptionForceRefreshAppCheck = 1 << 3
};

FOUNDATION_EXPORT NSErrorDomain const PPFirebaseSessionBridgeErrorDomain;

typedef NS_ENUM(NSInteger, PPFirebaseSessionBridgeErrorCode) {
    PPFirebaseSessionBridgeErrorCodeUnauthenticated = 401,
    PPFirebaseSessionBridgeErrorCodeAppCheckUnavailable = 403,
    PPFirebaseSessionBridgeErrorCodeInvalidRequest = 422
};

@interface PPFirebaseSessionBridge : NSObject

+ (void)ensureFreshAuthSessionForcingRefresh:(BOOL)forceRefresh
                                  completion:(void (^)(NSError * _Nullable error))completion;

+ (void)authorizeRequest:(NSMutableURLRequest *)request
                 options:(PPFirebaseSessionAuthorizationOptions)options
              completion:(void (^)(NSError * _Nullable error))completion;

+ (BOOL)isAuthOrAppCheckError:(NSError *)error;

+ (NSError *)publicErrorForError:(NSError *)error
                     fallbackKey:(NSString *)fallbackKey;

+ (NSString *)publicMessageForError:(NSError *)error
                         fallbackKey:(NSString *)fallbackKey;

@end

NS_ASSUME_NONNULL_END
