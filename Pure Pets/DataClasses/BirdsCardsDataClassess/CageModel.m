//
//  CageModel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//  Refactored: Childs moved to ChildsCol subcollection
//

#import "CageModel.h"

@implementation CageModel

#pragma mark - Factory

+ (NSMutableArray<CageModel *> *)fromSnapshot:(id)snapshotOrArray
{
    NSMutableArray<CageModel *> *result = [NSMutableArray array];
    if (!snapshotOrArray || snapshotOrArray == (id)kCFNull) return result;

    // FIRQuerySnapshot
    if ([snapshotOrArray respondsToSelector:@selector(documents)]) {
        for (id doc in [snapshotOrArray valueForKey:@"documents"]) {
            CageModel *m = [[CageModel alloc] initWithSnapshot:doc];
            if (m) [result addObject:m];
        }
        return result;
    }

    // NSArray<FIRDocumentSnapshot *>
    if ([snapshotOrArray isKindOfClass:[NSArray class]]) {
        for (id doc in snapshotOrArray) {
            CageModel *m = [[CageModel alloc] initWithSnapshot:doc];
            if (m) [result addObject:m];
        }
        return result;
    }

    // Single snapshot
    if ([snapshotOrArray respondsToSelector:@selector(documentID)]) {
        CageModel *m = [[CageModel alloc] initWithSnapshot:snapshotOrArray];
        if (m) [result addObject:m];
    }

    return result;
}

#pragma mark - Init

- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot
{
    self = [super init];
    if (!self || !snapshot.exists) return nil;

    NSDictionary *d = snapshot.data;

    self.ID           = snapshot.documentID;
    self.CageName     = d[@"CageName"];
    self.FatherRingID = d[@"FatherRingID"];
    self.MotherRingID = d[@"MotherRingID"];
    self.UserID       = d[@"UserID"];
    self.isDeleted    = [d[@"isDeleted"] integerValue];
    self.childsCount  = [d[@"childsCount"] integerValue];
    // Dates
    FIRTimestamp *createTS = d[@"CreateDate"];
    self.CreateDate = createTS ? createTS.dateValue : nil;

    FIRTimestamp *firstEggTS = d[@"FristEggDate"];
    self.FristEggDate = firstEggTS ? firstEggTS.dateValue : nil;

    FIRTimestamp *reminderTS = d[@"ReminderDate"];
    self.ReminderDate = reminderTS ? reminderTS.dateValue : nil;

    return self;
}

#pragma mark - Helpers

- (NSInteger)getFirstEggRemaingDays
{
    if (!self.ReminderDate) return 0;

    NSCalendar *calendar =
    [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];

    NSDateComponents *components =
    [calendar components:NSCalendarUnitDay
                fromDate:[NSDate date]
                  toDate:self.ReminderDate
                 options:0];

    return components.day;
}

#pragma mark - Relations (READ ONLY)

- (CardModel *)FatherCard
{
    return [[AppData.AllCardsDocs
             filteredArrayUsingPredicate:
             [NSPredicate predicateWithFormat:@"ID == %@", self.FatherRingID]]
            firstObject];
}

- (CardModel *)MotherCard
{
    return [[AppData.AllCardsDocs
             filteredArrayUsingPredicate:
             [NSPredicate predicateWithFormat:@"ID == %@", self.MotherRingID]]
            firstObject];
}

#pragma mark - Update Cage (NO CHILDREN)

+ (void)updateCage:(CageModel *)cageModel
        completion:(void (^)(NSError * _Nullable error))completion
{
    if (!cageModel.ID.length) {
        if (completion) {
            completion([NSError errorWithDomain:@"CageModel"
                                           code:400
                                       userInfo:@{NSLocalizedDescriptionKey:@"Missing cage ID"}]);
        }
        return;
    }

    NSDictionary *data = @{
        @"CageName": cageModel.CageName ?: @"",
        @"FatherRingID": cageModel.FatherRingID ?: @"",
        @"MotherRingID": cageModel.MotherRingID ?: @"",
        @"isDeleted": @(cageModel.isDeleted),
        @"childsCount": @(cageModel.childsCount)
    };

    [[[[FIRFirestore firestore]
          collectionWithPath:@"CagesCol"]
         documentWithPath:cageModel.ID] setData:data merge:YES completion:completion];
}


@end
