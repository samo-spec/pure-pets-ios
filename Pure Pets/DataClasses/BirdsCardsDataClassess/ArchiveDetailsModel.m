//
//  ArchiveDetailsModel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//  Refactored: ArchiveDetailsCol subcollection
//

#import "ArchiveDetailsModel.h"

@implementation ArchiveDetailsModel

#pragma mark - Factory

+ (instancetype)fromSnapshot:(FIRDocumentSnapshot *)snapshot
{
    if (!snapshot.exists) return nil;
    return [[ArchiveDetailsModel alloc] initWithSnapshot:snapshot];
}

#pragma mark - Designated Initializer

- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot
{
    self = [super init];
    if (!self || !snapshot.exists) return nil;

    NSDictionary *d = snapshot.data ?: @{};

    // IDs
    self.ID = snapshot.documentID;

    // IMPORTANT:
    // ArchiveDetailsCol/{detailID} is under ArchiveCol/{archiveID}
    self.masterArchiveID = snapshot.reference.parent.parent.documentID;

    self.CardID = d[@"CardID"];
    self.UserID = d[@"UserID"];
    self.CageID = d[@"CageID"];

    self.cardInfo = [d[@"cardInfo"] integerValue];
    self.isDeleted = [d[@"isDeleted"] integerValue];
    self.isSold = [d[@"isSold"] integerValue];
    self.isSold = [d[@"isSold"] integerValue];
 
    // Date
    id date = d[@"cardArchiveDate"];
    if ([date isKindOfClass:[FIRTimestamp class]]) {
        self.cardArchiveDate = [(FIRTimestamp *)date dateValue];
    } else if ([date isKindOfClass:[NSDate class]]) {
        self.cardArchiveDate = date;
    } else {
        self.cardArchiveDate = nil;
    }
    
    
    id datelastUpdated = d[@"lastUpdated"];
    if ([datelastUpdated isKindOfClass:[FIRTimestamp class]]) {
        self.lastUpdated = [(FIRTimestamp *)datelastUpdated dateValue];
    } else if ([datelastUpdated isKindOfClass:[NSDate class]]) {
        self.lastUpdated = datelastUpdated;
    } else {
        self.lastUpdated = nil;
    }

    return self;
}

#pragma mark - Copy

- (id)mutableCopyWithZone:(NSZone *)zone
{
    ArchiveDetailsModel *copy =
    [[[self class] allocWithZone:zone] init];

    copy.ID = self.ID;
    copy.masterArchiveID = self.masterArchiveID;
    copy.CardID = self.CardID;
    copy.UserID = self.UserID;
    copy.CageID = self.CageID;

    copy.cardArchiveDate = self.cardArchiveDate;
    copy.isDeleted = self.isDeleted;
    copy.cardInfo = self.cardInfo;
    copy.isSold = self.isSold;
    copy.lastUpdated = self.lastUpdated;
    return copy;
}

#pragma mark - Firestore Export

- (NSDictionary *)toDictionary
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    if (self.CardID) dict[@"CardID"] = self.CardID;
    if (self.UserID) dict[@"UserID"] = self.UserID;
    if (self.CageID) dict[@"CageID"] = self.CageID;

    dict[@"cardInfo"] = @(self.cardInfo);
    dict[@"isDeleted"] = @(self.isDeleted);
    dict[@"isSold"] = @(self.isSold);

    if (self.cardArchiveDate) {
        dict[@"cardArchiveDate"] =
        [FIRTimestamp timestampWithDate:self.cardArchiveDate];
    }

    if (self.lastUpdated) {
        dict[@"lastUpdated"] =
        [FIRTimestamp timestampWithDate:self.lastUpdated];
    }
    
    return dict;
}

@end
