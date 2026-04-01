//

//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//
#import "ArchiveModel.h"



@implementation ArchiveModel

// ArchiveModel.m
+ (NSMutableArray<ArchiveModel *> *)fromSnapshot:(FIRQuerySnapshot *)snapshot {
    NSMutableArray<ArchiveModel *> *result = [NSMutableArray array];
    for (FIRDocumentSnapshot *doc in snapshot.documents) {
        ArchiveModel *m = [[ArchiveModel alloc] initWithSnapshot:doc];
        if (m) [result addObject:m];
    }
    return result;
}
- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot
{
    self = [super init];
    if (!self) return nil;

    NSDictionary *data = snapshot.data;
    if (!data) return self;

    self.ID = data[@"ID"] ?: snapshot.documentID;
    self.archiveTitle = data[@"archiveTitle"];
    self.archiveOwnerID = data[@"archiveOwnerID"];

    FIRTimestamp *ts = data[@"archiveDate"];
    self.archiveDate = ts ? ts.dateValue : nil;

    self.isDeleted = [data[@"isDeleted"] integerValue];

    // In-memory only (loaded from subcollection when needed)
    self.details = [NSMutableArray array];
    self.deletedDetails = [NSMutableArray array];
    self.detailsCount = [data[@"detailsCount"] integerValue];
    return self;
}
- (BOOL)containsCardID:(NSString *)cardID
{
    if (!cardID.length || self.details.count == 0) {
        return NO;
    }

    for (ArchiveDetailsModel *detail in self.details) {
        if ([detail.CardID isEqualToString:cardID]) {
            return YES;
        }
    }

    return NO;
}

- (void)loadArchiveDetailsWithCompletion:(void(^)(NSError * _Nullable error))completion
{
    FIRFirestore *db = [FIRFirestore firestore];

    [[[[db collectionWithPath:@"ArchiveCol"]
       documentWithPath:self.ID]
      collectionWithPath:@"ArchiveDetailsCol"]
     getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error)
     {
         if (error) {
             if (completion) completion(error);
             return;
         }

         [self.details removeAllObjects];
         [self.deletedDetails removeAllObjects];

         for (FIRDocumentSnapshot *doc in snapshot.documents) {

             ArchiveDetailsModel *detail =
             [[ArchiveDetailsModel alloc] initWithSnapshot:doc];
             
             detail.masterArchiveID = self.ID;
             
             if (detail.isDeleted == 1) {
                 [self.deletedDetails addObject:detail];
             } else {
                 [self.details addObject:detail];
             }
         }

         if (completion) completion(nil);
     }];
}

@end
