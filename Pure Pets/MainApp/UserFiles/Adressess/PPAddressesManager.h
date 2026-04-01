//
//  PPAddressesManager.h
//  Pure Pets
//
//  Created by ChatGPT on 30/10/2025.
//

#import <Foundation/Foundation.h>
#import "PPAddressModel.h"
@import FirebaseFirestore;

NS_ASSUME_NONNULL_BEGIN

typedef void (^PPAddressCompletion)(PPAddressModel * _Nullable address, NSError * _Nullable error);
typedef void (^PPAddressesCompletion)(NSArray<PPAddressModel *> * _Nullable addresses, NSError * _Nullable error);
typedef void (^PPVoidCompletion)(BOOL success, NSError * _Nullable error);
extern NSString * const PPAddressesDidChangeNotification;

/// 🏠 Manages user shipping addresses stored in Firestore under:
/// UsersCol/{userID}/Addresses/{addressDocID}
@interface PPAddressesManager : NSObject

/// Singleton
+ (instancetype)sharedManager;

/// The Firestore collection reference for the current user's addresses.
@property (nonatomic, readonly, nullable) FIRCollectionReference *userAddressesCollection;
/// Currently authenticated UID for address operations.
- (NSString * _Nullable)currentAuthenticatedUserID;

/// Get all addresses for the current user
- (void)getAllAddressesWithCompletion:(PPAddressesCompletion _Nullable)completion;

/// Add a new address
- (void)addAddress:(PPAddressModel *)address completion:(PPAddressCompletion _Nullable)completion;

/// Update an existing address
- (void)updateAddress:(PPAddressModel *)address completion:(PPAddressCompletion _Nullable)completion;

/// Delete an address
- (void)deleteAddress:(PPAddressModel *)address completion:(PPVoidCompletion _Nullable)completion;

/// Mark a specific address as default (and unmark others)
- (void)setDefaultAddress:(PPAddressModel *)address completion:(PPVoidCompletion _Nullable)completion;

/// Listen for live updates (real-time sync)
- (id<FIRListenerRegistration>)listenToAddressesWithBlock:(PPAddressesCompletion _Nullable)updateBlock;

@end

NS_ASSUME_NONNULL_END
