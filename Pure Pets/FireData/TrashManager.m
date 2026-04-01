//
//  TrashManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/12/2025.
//


#import "TrashManager.h"

@implementation TrashManager

+ (instancetype)shared {
    static TrashManager *mgr;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [TrashManager new];
    });
    return mgr;
}

- (void)restoreTrashItem:(TrashModel *)trash
              completion:(void (^)(NSError * _Nullable))completion
{
    if (!trash || !trash.RefID.length) {
        if (completion) {
            completion([NSError errorWithDomain:@"TrashRestore"
                                           code:400
                                       userInfo:@{NSLocalizedDescriptionKey:@"Invalid trash item"}]);
        }
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    FIRWriteBatch *batch = [db batch];

    // ===============================
    // 1️⃣ Remove trash record
    // ===============================
    FIRDocumentReference *trashRef =
    [[db collectionWithPath:@"TrashCol"]
     documentWithPath:trash.ID];

    [batch deleteDocument:trashRef];

    // ===============================
    // 2️⃣ RESTORE CHILD (child.ID)
    // ===============================
    if (trash.RefType == RefTypeChild) {

        if (!trash.CageID.length) {
            if (completion) {
                completion([NSError errorWithDomain:@"TrashRestore"
                                               code:400
                                           userInfo:@{NSLocalizedDescriptionKey:@"Missing cageID"}]);
            }
            return;
        }

        FIRDocumentReference *childRef =
        [[[[db collectionWithPath:@"CagesCol"]
           documentWithPath:trash.CageID]
          collectionWithPath:@"ChildsCol"]
         documentWithPath:trash.RefID];   // ✅ child.ID

        [batch updateData:@{@"isDeleted": @0,@"lastUpdated" : [FIRTimestamp timestampWithDate:[NSDate date]]}
              forDocument:childRef];

        // ===============================
        // 3️⃣ RESTORE CARD (card.ID)
        // ===============================
        if (trash.CardID.length) {

            FIRDocumentReference *cardRef =
            [[db collectionWithPath:@"CardsCol"]
             documentWithPath:trash.CardID]; // ✅ card.ID

            [batch updateData:@{@"isDeleted": @0,@"lastUpdated" : [FIRTimestamp timestampWithDate:[NSDate date]]}
                  forDocument:cardRef];
        }
    }

    // ===============================
    // 4️⃣ CARD-ONLY RESTORE (future-safe)
    // ===============================
    if (trash.RefType == RefTypeCard) {

        FIRDocumentReference *cardRef =
        [[db collectionWithPath:@"CardsCol"]
         documentWithPath:trash.RefID];

        [batch updateData:@{@"isDeleted": @0,@"lastUpdated" : [FIRTimestamp timestampWithDate:[NSDate date]]}
              forDocument:cardRef];
    }

    // ===============================
    // 5️⃣ COMMIT
    // ===============================
    [batch commitWithCompletion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(error);
        });
    }];
}


+ (void)repairAllTrashOnce
{
    static BOOL didRun = NO;
    if (didRun) return;
    didRun = YES;

    FIRFirestore *db = [FIRFirestore firestore];

    [[db collectionWithPath:@"TrashCol"]
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                  NSError * _Nullable error) {

        if (error) {
            NSLog(@"❌ Trash repair failed to fetch: %@", error);
            return;
        }

        for (FIRDocumentSnapshot *doc in snapshot.documents) {

            TrashModel *trash = [[TrashModel alloc] initWithSnapshot:doc];
            if (!trash) continue;

            NSMutableDictionary *updates = [NSMutableDictionary dictionary];

            // 1️⃣ ID fallback (logical, not stored normally)
            if (!trash.ID.length) {
                trash.ID = doc.documentID;
            }

            // 2️⃣ ownerID from Card.UserID
            if ((!trash.ownerID || trash.ownerID.length == 0 || [trash.ownerID isEqualToString:@""]) && trash.CardID.length) {
                CardModel *card =
                [[AppData.AllCardsDocs filteredArrayUsingPredicate:
                  [NSPredicate predicateWithFormat:@"ID == %@", trash.CardID]] firstObject];

                if (card.UserID.length) {
                    trash.ownerID = card.UserID;
                    updates[@"ownerID"] = card.UserID;
                }
            }

            if ((!trash.ownerID || trash.ownerID.length == 0) &&
                trash.RefType == RefTypeArchive &&
                trash.CardID.length) {

                CardModel *card =
                [[AppData.AllCardsDocs filteredArrayUsingPredicate:
                  [NSPredicate predicateWithFormat:@"ID == %@", trash.CardID]] firstObject];

                if (card.UserID.length) {
                    trash.ownerID = card.UserID;
                    updates[@"ownerID"] = card.UserID;
                }
            }

            BOOL hasMasterArchive =
            (trash.masterArchiveID && trash.masterArchiveID.length > 0);

            if (!hasMasterArchive &&
                trash.archiveID.length > 0 &&
                trash.RefID.length > 0 &&
                ![trash.archiveID isEqualToString:trash.RefID]) {

                updates[@"masterArchiveID"] = trash.archiveID;
                updates[@"archiveID"] = trash.RefID;
            }

            if (updates.count == 0) {
                NSLog(@"ℹ️ Trash %@ already valid", doc.documentID);
                continue;
            }

            [[[db collectionWithPath:@"TrashCol"]
              documentWithPath:doc.documentID]
             updateData:updates
             completion:^(NSError * _Nullable err) {
                if (err) {
                    NSLog(@"❌ Trash repair failed %@: %@", doc.documentID, err);
                } else {
                    NSLog(@"✅ Trash repaired %@", doc.documentID);
                }
            }];
        }
    }];
}



@end
