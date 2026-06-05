//
//  UserPaymentInstrumentManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/11/2025.
//


//
//  UserPaymentInstrumentManager.h
//  PurePets
//

#import <Foundation/Foundation.h>

@class UserPaymentInstrument;
NS_ASSUME_NONNULL_BEGIN

@interface UserPaymentInstrumentManager : NSObject

@property (nonatomic, strong, nullable) id<FIRListenerRegistration> listener;
+ (instancetype)sharedManager;

- (void)listenForInstrumentsForUser:(NSString *)userID
                         completion:(void(^)(NSArray<UserPaymentInstrument *> * _Nullable instruments, NSError * _Nullable error))completion;

- (void)stopListening;
- (void)resetForSignOut;

- (void)updateInstrument:(UserPaymentInstrument *)instrument
                 forUser:(NSString *)userID
              completion:(void (^)(BOOL success, NSError * _Nullable error))completion ;
@property (nonatomic, strong, readonly) NSArray<UserPaymentInstrument *> *cachedInstruments;

// 🔹 CRUD
- (void)fetchInstrumentsForUser:(NSString *)userID
                     completion:(void (^)(NSArray<UserPaymentInstrument *> * _Nullable instruments, NSError * _Nullable error))completion;

- (void)addInstrument:(UserPaymentInstrument *)instrument
              forUser:(NSString *)userID
           completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

- (void)setDefaultInstrument:(UserPaymentInstrument *)instrument
                    forUser:(NSString *)userID
                 completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

- (void)deleteInstrument:(UserPaymentInstrument *)instrument
                forUser:(NSString *)userID
             completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
