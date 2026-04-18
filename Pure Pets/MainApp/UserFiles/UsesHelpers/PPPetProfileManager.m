//
//  PPPetProfileManager.m
//  Pure Pets
//
//  Extracted from UserManager (Phase 2B) — owns all pet-profile and pet-reminder
//  Firestore operations for the current user.
//

#import "PPPetProfileManager.h"
#import "PPPetProfile.h"
#import "PPPetReminder.h"
#import "PPAuditLogger.h"

@import FirebaseAuth;
@import FirebaseFirestore;
@import FirebaseStorage;

static NSString *const kPPPetProfilesCollection = @"petProfiles";
static NSString *const kPPPetRemindersCollection = @"petReminders";

@implementation PPPetProfileManager

// MARK: - Singleton

+ (instancetype)sharedManager {
    static PPPetProfileManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[PPPetProfileManager alloc] init];
    });
    return shared;
}

// MARK: - Private Helpers

/// Resolve the current user's Firestore document reference.
/// Uses `currentUserUID` (set by UserManager) with fallback to FIRAuth.
- (nullable FIRDocumentReference *)pp_currentUserDocumentReference {
    NSString *uid = self.currentUserUID;
    if (uid.length == 0) {
        uid = [FIRAuth auth].currentUser.uid;
    }
    if (uid.length == 0) { return nil; }
    return [[[FIRFirestore firestore] collectionWithPath:@"UsersCol"] documentWithPath:uid];
}

/// Resolve the raw UID string (for Storage paths).
- (nullable NSString *)pp_resolvedUID {
    NSString *uid = self.currentUserUID;
    if (uid.length == 0) {
        uid = [FIRAuth auth].currentUser.uid;
    }
    return uid.length > 0 ? uid : nil;
}

// MARK: - Pet Profiles

- (void)fetchPetProfilesForCurrentUserWithCompletion:(void (^)(NSArray<PPPetProfile *> * _Nullable pets,
                                                               NSError * _Nullable error))completion
{
    FIRDocumentReference *userRef = [self pp_currentUserDocumentReference];
    if (!userRef) {
        if (completion) completion(@[], [NSError errorWithDomain:@"PPPetProfileManager"
                                                           code:401
                                                       userInfo:@{NSLocalizedDescriptionKey: @"Missing authenticated user"}]);
        return;
    }

    [[[userRef collectionWithPath:kPPPetProfilesCollection] queryOrderedByField:@"createdAt" descending:NO]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        NSMutableArray<PPPetProfile *> *items = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            PPPetProfile *pet = [[PPPetProfile alloc] initWithSnapshot:doc];
            if (pet) [items addObject:pet];
        }
        if (completion) completion(items.copy, error);
    }];
}

- (void)savePetProfile:(PPPetProfile *)pet completion:(void (^)(NSError * _Nullable error))completion
{
    FIRDocumentReference *userRef = [self pp_currentUserDocumentReference];
    if (!userRef) {
        if (completion) completion([NSError errorWithDomain:@"PPPetProfileManager"
                                                      code:401
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Missing authenticated user"}]);
        return;
    }

    NSString *petID = pet.petID.length ? pet.petID : [NSUUID UUID].UUIDString;
    pet.petID = petID;
    pet.updatedAt = [NSDate date];
    if (!pet.createdAt) pet.createdAt = pet.updatedAt;

    FIRDocumentReference *petRef = [[userRef collectionWithPath:kPPPetProfilesCollection] documentWithPath:petID];
    NSDictionary *data = [pet toDictionary];

    [[FIRFirestore firestore] runTransactionWithBlock:^id _Nullable(FIRTransaction * _Nonnull transaction,
                                                                     NSError *__autoreleasing  _Nullable * _Nullable errorPointer) {

        FIRDocumentSnapshot *userSnap = [transaction getDocument:userRef error:errorPointer];
        if (*errorPointer) {
            return nil;
        }

        NSString *oldDefaultPetID = [userSnap.data[@"defaultPetProfileID"] isKindOfClass:NSString.class]
            ? userSnap.data[@"defaultPetProfileID"]
            : nil;

        if (pet.isDefaultPet) {
            if (oldDefaultPetID.length && ![oldDefaultPetID isEqualToString:petID]) {
                FIRDocumentReference *oldPetRef =
                    [[userRef collectionWithPath:kPPPetProfilesCollection] documentWithPath:oldDefaultPetID];

                FIRDocumentSnapshot *oldPetSnap = [transaction getDocument:oldPetRef error:errorPointer];
                if (*errorPointer) return nil;

                if (oldPetSnap.exists) {
                    PPPetProfile *oldPet = [[PPPetProfile alloc] initWithSnapshot:oldPetSnap];
                    oldPet.isDefaultPet = NO;
                    [transaction setData:[oldPet toDictionary] forDocument:oldPetRef merge:YES];
                }
            }

            [transaction setData:@{
                @"defaultPetProfileID": petID,
                @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp]
            } forDocument:userRef merge:YES];
        }

        [transaction setData:data forDocument:petRef merge:YES];
        return nil;

    } completion:^(id _Nullable result, NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}

- (void)deletePetProfileWithID:(NSString *)petID completion:(void (^)(NSError * _Nullable error))completion
{
    FIRDocumentReference *userRef = [self pp_currentUserDocumentReference];
    if (!userRef || petID.length == 0) {
        if (completion) completion([NSError errorWithDomain:@"PPPetProfileManager"
                                                      code:400
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Invalid pet id"}]);
        return;
    }

    [[[userRef collectionWithPath:kPPPetProfilesCollection] documentWithPath:petID] deleteDocumentWithCompletion:^(NSError * _Nullable error) {
        if (!error) {
            [PPAuditLogger writeAuditLogForAction:@"deletePetProfile" collection:kPPPetProfilesCollection documentId:petID data:nil];
        }
        if (completion) completion(error);
    }];
}

- (void)setDefaultPetProfileID:(NSString *)petID completion:(void (^)(NSError * _Nullable error))completion
{
    FIRDocumentReference *userRef = [self pp_currentUserDocumentReference];
    if (!userRef || petID.length == 0) {
        if (completion) completion([NSError errorWithDomain:@"PPPetProfileManager"
                                                      code:400
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Invalid pet id"}]);
        return;
    }

    [self fetchPetProfilesForCurrentUserWithCompletion:^(NSArray<PPPetProfile *> * _Nullable pets, NSError * _Nullable error) {
        if (error) { if (completion) completion(error); return; }

        FIRWriteBatch *batch = [[FIRFirestore firestore] batch];
        for (PPPetProfile *pet in pets) {
            FIRDocumentReference *ref = [[userRef collectionWithPath:kPPPetProfilesCollection] documentWithPath:pet.petID];
            pet.isDefaultPet = [pet.petID isEqualToString:petID];
            [batch setData:[pet toDictionary] forDocument:ref merge:YES];
        }
        [batch setData:@{ @"defaultPetProfileID": petID,
                          @"updatedAt": [FIRFieldValue fieldValueForServerTimestamp] }
           forDocument:userRef
                merge:YES];
        [batch commitWithCompletion:completion];
    }];
}

- (void)uploadPetImage:(UIImage *)image petID:(NSString *)petID completion:(void (^)(NSString * _Nullable imageURL, NSError * _Nullable error))completion
{
    NSString *uid = [self pp_resolvedUID];
    if (uid.length == 0 || petID.length == 0 || !image) {
        if (completion) completion(nil, [NSError errorWithDomain:@"PPPetProfileManager"
                                                           code:400
                                                       userInfo:@{NSLocalizedDescriptionKey: @"Missing pet image data"}]);
        return;
    }

    NSData *data = [GM compressImageToMaxSize:image maxSizeKB:600] ?: UIImageJPEGRepresentation(image, 0.82);
    FIRStorageReference *ref = [[[[[FIRStorage storage] reference] child:@"users"] child:uid]
                                child:[NSString stringWithFormat:@"pets/%@/avatar.jpg", petID]];

    FIRStorageMetadata *meta = [FIRStorageMetadata new];
    meta.contentType = @"image/jpeg";

    [ref putData:data metadata:meta completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
            if (completion) completion(URL.absoluteString, error);
        }];
    }];
}

// MARK: - Pet Reminders

- (void)fetchPetRemindersForCurrentUserWithCompletion:(void (^)(NSArray<PPPetReminder *> * _Nullable reminders,
                                                                NSError * _Nullable error))completion
{
    FIRDocumentReference *userRef = [self pp_currentUserDocumentReference];
    if (!userRef) {
        if (completion) completion(@[], [NSError errorWithDomain:@"PPPetProfileManager"
                                                           code:401
                                                       userInfo:@{NSLocalizedDescriptionKey: @"Missing authenticated user"}]);
        return;
    }

    [[[userRef collectionWithPath:kPPPetRemindersCollection] queryOrderedByField:@"fireDate" descending:NO]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        NSMutableArray<PPPetReminder *> *items = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            PPPetReminder *reminder = [[PPPetReminder alloc] initWithSnapshot:doc];
            if (reminder) [items addObject:reminder];
        }
        if (completion) completion(items.copy, error);
    }];
}

- (void)savePetReminder:(PPPetReminder *)reminder completion:(void (^)(NSError * _Nullable error))completion
{
    FIRDocumentReference *userRef = [self pp_currentUserDocumentReference];
    if (!userRef) {
        if (completion) completion([NSError errorWithDomain:@"PPPetProfileManager"
                                                      code:401
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Missing authenticated user"}]);
        return;
    }

    NSString *identifier = reminder.reminderID.length ? reminder.reminderID : [NSUUID UUID].UUIDString;
    reminder.reminderID = identifier;
    reminder.updatedAt = [NSDate date];
    if (!reminder.createdAt) reminder.createdAt = reminder.updatedAt;

    FIRDocumentReference *ref = [[userRef collectionWithPath:kPPPetRemindersCollection] documentWithPath:identifier];
    [ref setData:[reminder toDictionary] merge:YES completion:^(NSError * _Nullable error) {
        if (!error) {
            [PPAuditLogger writeAuditLogForAction:@"savePetReminder" collection:kPPPetRemindersCollection documentId:identifier data:[reminder toDictionary]];
        }
        if (completion) completion(error);
    }];
}

- (void)deletePetReminderWithID:(NSString *)reminderID completion:(void (^)(NSError * _Nullable error))completion
{
    FIRDocumentReference *userRef = [self pp_currentUserDocumentReference];
    if (!userRef || reminderID.length == 0) {
        if (completion) completion([NSError errorWithDomain:@"PPPetProfileManager"
                                                      code:400
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Invalid reminder id"}]);
        return;
    }

    [[[userRef collectionWithPath:kPPPetRemindersCollection] documentWithPath:reminderID] deleteDocumentWithCompletion:completion];
}

@end
