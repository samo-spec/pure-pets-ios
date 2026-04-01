//
//  ChildsDataManager.m
//  Pure Pets
//
//  Refactored: ChildsCol subcollection ONLY
//

#import "ChildsDataManager.h"

@implementation ChildsDataManager

#pragma mark - Collection Helper

+ (FIRCollectionReference *)childsColForCage:(NSString *)cageID
{
    return [[[[FIRFirestore firestore]
              collectionWithPath:@"CagesCol"]
             documentWithPath:cageID]
            collectionWithPath:@"ChildsCol"];
}

#pragma mark - Fetch

+ (void)fetchChildrenForCageID:(NSString *)cageID
                    completion:(void(^)(NSArray<ChildModel *> *children,
                                         NSError *error))completion
{
    if (!cageID.length) {
        if (completion) completion(@[], nil);
        return;
    }

    [[[[self childsColForCage:cageID]
       queryWhereField:@"isDeleted" isEqualTo:@0]
      queryWhereField:@"childBox" in:@[@(ChildBoxHome)]] //@[@(ChildBoxHome), @(ChildBoxGuest)]
     getDocumentsWithCompletion:^(FIRQuerySnapshot *snap,
                                  NSError *error)
    {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }

        NSMutableArray *result = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snap.documents) {
            ChildModel *child = [ChildModel fromSnapshot:doc];
            if (child) [result addObject:child];
        }

        if (completion) completion(result, nil);
    }];
}



#pragma mark - Create

+ (void)addChild:(ChildModel *)child
       toCageID:(NSString *)cageID
      completion:(void(^)(NSError *error))completion
{
    if (!child || !child.ID.length || !cageID.length) {
        if (completion)
            completion([NSError errorWithDomain:@"ChildsDataManager"
                                           code:400
                                       userInfo:@{NSLocalizedDescriptionKey:@"Invalid child data"}]);
        return;
    }

    NSMutableDictionary *data =
    [[child dictionaryRepresentation] mutableCopy];

    data[@"CageID"] = cageID;
    data[@"isDeleted"] = @(child.isDeleted);

    [[[self childsColForCage:cageID]
      documentWithPath:child.ID]
     setData:data
     completion:completion];
}

#pragma mark - Soft Delete / Restore

+ (void)setChildDeleted:(BOOL)deleted
             forChildID:(NSString *)childID
                cageID:(NSString *)cageID
             completion:(void(^)(NSError *error))completion
{
    if (!childID.length || !cageID.length) {
        if (completion) completion(nil);
        return;
    }

    [[[self childsColForCage:cageID]
      documentWithPath:childID]
     updateData:@{ @"isDeleted": @(deleted) }
     completion:completion];
}

#pragma mark - Update by CardID (Sold / Restore)

+ (void)updateChildWithCardID:(NSString *)cardID
                      cageID:(NSString *)cageID
                        data:(NSDictionary *)data
                   completion:(void(^)(NSError *error))completion
{
    if (!cardID.length || !cageID.length || data.count == 0) {
        if (completion) completion(nil);
        return;
    }

    FIRCollectionReference *col = [self childsColForCage:cageID];

    [[col queryWhereField:@"CardID" isEqualTo:cardID]
     getDocumentsWithCompletion:^(FIRQuerySnapshot *snap,
                                  NSError *error)
    {
        if (error || snap.documents.count == 0) {
            if (completion) completion(error);
            return;
        }

        // One child per card (your rule)
        FIRDocumentReference *ref =
        snap.documents.firstObject.reference;

        [ref updateData:data completion:completion];
    }];
}

#pragma mark - Convenience APIs

+ (void)markChildSoldByCardID:(NSString *)cardID
                      cageID:(NSString *)cageID
                   completion:(void(^)(NSError *error))completion
{
    [self updateChildWithCardID:cardID
                        cageID:cageID
                          data:@{ @"isSold": @1 }
                     completion:completion];
}

+ (void)updateChildBox:(ChildBox)childBox
            childBoxID:(NSString *)childBoxID
              childID:(NSString *)childID
               cageID:(NSString *)cageID
           completion:(void(^)(NSError *error))completion
{
    if (!childID.length || !cageID.length) {
        if (completion) completion(nil);
        return;
    }

    [[[self childsColForCage:cageID]
      documentWithPath:childID]
     updateData:@{
        @"childBox": @(childBox),
        @"childBoxID": childBoxID ?: @""
     }
     completion:completion];
}

#pragma mark - Sync

+ (void)syncDetailsCountForCageID:(NSString *)cageID
                       completion:(void(^)(NSError * _Nullable error))completion
{
    if (!cageID.length) {
        if (completion) completion(nil);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];

    FIRCollectionReference *childsCol =
    [[[db collectionWithPath:@"CagesCol"]
      documentWithPath:cageID]
     collectionWithPath:@"ChildsCol"];

    FIRQuery *query =
    [[childsCol queryWhereField:@"isDeleted" isEqualTo:@0]
     queryWhereField:@"childBox"
     in:@[@(ChildBoxHome), @(ChildBoxGuest)]];

    [query getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot,
                                        NSError * _Nullable error)
    {
        if (error) {
            if (completion) completion(error);
            return;
        }

        NSInteger count = snapshot.documents.count;

        [[[db collectionWithPath:@"CagesCol"]
          documentWithPath:cageID]
         updateData:@{ @"childsCount": @(count) }
         completion:completion];
    }];
}

+ (NSInteger)indexOfChild:(ChildModel *)child inArray:(NSMutableArray<ChildModel *> *)childsArr
{
    if (!child.ID.length) return NSNotFound;

    __block NSInteger foundIndex = NSNotFound;

    [childsArr enumerateObjectsUsingBlock:
     ^(ChildModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop)
    {
        if ([obj.ID isEqualToString:child.ID]) {
            foundIndex = idx;
            *stop = YES;
        }
    }];

    return foundIndex;
}

@end
