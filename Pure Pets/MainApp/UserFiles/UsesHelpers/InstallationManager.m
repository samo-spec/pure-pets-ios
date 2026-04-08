//
//  InstallationManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/10/2025.
//


//
//  InstallationManager.m
//  PurePets
//
//  Created by ChatGPT on 2025-10-03.
//

#import "InstallationManager.h"
@implementation InstallationManager {
    NSString *_cachedInstallationID;
    NSString *_cachedAuthToken;
    NSDate *_cachedTokenExpiration;
}

+ (instancetype)shared {
    static InstallationManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[InstallationManager alloc] init];
    });
    return instance;
}

#pragma mark - Public Methods

- (void)getInstallationIDWithCompletion:(void(^)(NSString * _Nullable installationID, NSError * _Nullable error))completion {
    if (_cachedInstallationID) {
        if (completion) completion(_cachedInstallationID, nil);
        return;
    }
    
    [[FIRInstallations installations] installationIDWithCompletion:^(NSString * _Nullable identifier, NSError * _Nullable error) {
        if (!error && identifier) {
            self->_cachedInstallationID = identifier;
        }
        if (completion) completion(identifier, error);
    }];
}

- (void)getAuthTokenWithCompletion:(void(^)(NSString * _Nullable token, NSDate * _Nullable expirationDate, NSError * _Nullable error))completion {
    if (_cachedAuthToken && _cachedTokenExpiration && [_cachedTokenExpiration timeIntervalSinceNow] > 60) {
        // ✅ Token is still valid (60s buffer)
        if (completion) completion(_cachedAuthToken, _cachedTokenExpiration, nil);
        return;
    }
    
    [[FIRInstallations installations] authTokenWithCompletion:^(FIRInstallationsAuthTokenResult * _Nullable tokenResult, NSError * _Nullable error) {
        if (!error && tokenResult) {
            self->_cachedAuthToken = tokenResult.authToken;
            self->_cachedTokenExpiration = tokenResult.expirationDate;
        }
        if (completion) completion(tokenResult.authToken, tokenResult.expirationDate, error);
    }];
}

- (void)refreshAuthTokenWithCompletion:(void(^)(NSString * _Nullable token, NSDate * _Nullable expirationDate, NSError * _Nullable error))completion {
    [[FIRInstallations installations] authTokenForcingRefresh:YES completion:^(FIRInstallationsAuthTokenResult * _Nullable tokenResult, NSError * _Nullable error) {
        if (!error && tokenResult) {
            self->_cachedAuthToken = tokenResult.authToken;
            self->_cachedTokenExpiration = tokenResult.expirationDate;
        }
        if (completion) completion(tokenResult.authToken, tokenResult.expirationDate, error);
    }];
}

- (void)deleteInstallationWithCompletion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    [[FIRInstallations installations] deleteWithCompletion:^(NSError * _Nullable error) {
        if (!error) {
            self->_cachedInstallationID = nil;
            self->_cachedAuthToken = nil;
            self->_cachedTokenExpiration = nil;
        }
        if (completion) completion(error == nil, error);
    }];
    
    
}

#pragma mark - Readonly Properties

- (NSString *)cachedInstallationID { return _cachedInstallationID; }
- (NSString *)cachedAuthToken { return _cachedAuthToken; }
- (NSDate *)cachedTokenExpiration { return _cachedTokenExpiration; }

@end
