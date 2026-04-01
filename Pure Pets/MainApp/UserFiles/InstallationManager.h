//
//  InstallationManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/10/2025.
//


//
//  InstallationManager.h
//  PurePets
//
//  Created by ChatGPT on 2025-10-03.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface InstallationManager : NSObject

@property (nonatomic, strong, readonly, nullable) NSString *cachedInstallationID;
@property (nonatomic, strong, readonly, nullable) NSString *cachedAuthToken;
@property (nonatomic, strong, readonly, nullable) NSDate *cachedTokenExpiration;

+ (instancetype)shared;

- (void)getInstallationIDWithCompletion:(void(^)(NSString * _Nullable installationID, NSError * _Nullable error))completion;
- (void)getAuthTokenWithCompletion:(void(^)(NSString * _Nullable token, NSDate * _Nullable expirationDate, NSError * _Nullable error))completion;
- (void)refreshAuthTokenWithCompletion:(void(^)(NSString * _Nullable token, NSDate * _Nullable expirationDate, NSError * _Nullable error))completion;
- (void)deleteInstallationWithCompletion:(void(^)(BOOL success, NSError * _Nullable error))completion;

@end


NS_ASSUME_NONNULL_END
