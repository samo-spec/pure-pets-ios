//
//  PPPetProfileManager.h
//  Pure Pets
//
//  Extracted from UserManager (Phase 2B) — owns all pet-profile and pet-reminder
//  Firestore operations for the current user.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class FIRAuth;
@class PPPetProfile;
@class PPPetReminder;

NS_ASSUME_NONNULL_BEGIN

@interface PPPetProfileManager : NSObject

/// Shared singleton instance.
+ (instancetype)sharedManager;

/// The UID of the currently authenticated user.
/// UserManager keeps this in sync whenever `currentUser` changes.
@property (nonatomic, copy, nullable) NSString *currentUserUID;

#pragma mark - Pet Profiles

/// Fetch all pet profiles for the current user, ordered by createdAt ascending.
- (void)fetchPetProfilesForCurrentUserWithCompletion:(void (^)(NSArray<PPPetProfile *> * _Nullable pets,
                                                               NSError * _Nullable error))completion;

/// Save (create or update) a pet profile. If petID is nil/empty a new UUID is generated.
/// When `isDefaultPet == YES`, the previous default pet is demoted inside a transaction.
- (void)savePetProfile:(PPPetProfile *)pet
            completion:(void (^)(NSError * _Nullable error))completion;

/// Delete a pet profile by its ID.
- (void)deletePetProfileWithID:(NSString *)petID
                    completion:(void (^)(NSError * _Nullable error))completion;

/// Set a specific pet as the default pet for the current user (batch write).
- (void)setDefaultPetProfileID:(NSString *)petID
                    completion:(void (^)(NSError * _Nullable error))completion;

/// Upload a pet avatar image to Firebase Storage under `users/{uid}/pets/{petID}/avatar.jpg`.
/// Returns the download URL string on success.
- (void)uploadPetImage:(UIImage *)image
                 petID:(NSString *)petID
            completion:(void (^)(NSString * _Nullable imageURL, NSError * _Nullable error))completion;

#pragma mark - Pet Reminders

/// Fetch all pet reminders for the current user, ordered by fireDate ascending.
- (void)fetchPetRemindersForCurrentUserWithCompletion:(void (^)(NSArray<PPPetReminder *> * _Nullable reminders,
                                                                NSError * _Nullable error))completion;

/// Save (create or update) a pet reminder.
- (void)savePetReminder:(PPPetReminder *)reminder
             completion:(void (^)(NSError * _Nullable error))completion;

/// Delete a pet reminder by its ID.
- (void)deletePetReminderWithID:(NSString *)reminderID
                     completion:(void (^)(NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
