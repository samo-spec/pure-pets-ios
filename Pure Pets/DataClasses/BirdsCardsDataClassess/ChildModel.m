//
//  ChildModel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//  Refactored to use ChildsCol subcollection
//

#import "ChildModel.h"

@implementation ChildModel

#pragma mark - Designated Initializer


-(CardModel *)card
{
    return  [[AppData.AllCardsDocs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@",self.CardID]] firstObject];

}
- (instancetype)init {
    self = [super init];
    if (self) {
        _isDeleted = 0;
        _isSold = 0;
        _childBox = ChildBoxHome;
        _cameFrom = CameFromChilds;
        _BirthDate = [NSDate date];
        _lastUpdated = [NSDate date];

    }
    return self;
}

#pragma mark - Init With Dictionary (Firestore-safe)

- (instancetype)initWithDictionary:(NSDictionary *)data {
    self = [self init];
    if (!self || !data) return nil;

    _ID               = data[@"ID"] ?: @"";
    _CageID           = data[@"CageID"] ?: @"";
    _UserID           = data[@"UserID"] ?: @"";
    _ChildRingID      = data[@"ChildRingID"] ?: @"";
    _CardID           = data[@"CardID"] ?: @"";

    _archiveID        = data[@"archiveID"] ?: @"";
    _masterArchiveID = data[@"masterArchiveID"] ?: @"";

    _isDeleted        = [data[@"isDeleted"] integerValue];
    _isSold           = [data[@"isSold"] integerValue];

    _childBox         = [data[@"childBox"] integerValue];
    _childBoxID       = data[@"childBoxID"] ?: @"";

    _cameFrom         = [data[@"cameFrom"] integerValue];

    id BirthDat = data[@"BirthDate"] ?: data[@"BirthDat"];
    if ([BirthDat isKindOfClass:[FIRTimestamp class]]) {
        _BirthDate = [(FIRTimestamp *)BirthDat dateValue];
    } else {
        _BirthDate = BirthDat;
    }
    
    
    id addDate = data[@"addingDate"];
    if ([addDate isKindOfClass:[FIRTimestamp class]]) {
        _addingDate = [(FIRTimestamp *)addDate dateValue];
    } else {
        _addingDate = addDate;
    }

    id lastUpdated = data[@"lastUpdated"];
    if ([lastUpdated isKindOfClass:[FIRTimestamp class]]) {
        _lastUpdated = [(FIRTimestamp *)lastUpdated dateValue];
    } else {
        _lastUpdated = lastUpdated;
    }

    return self;
}

#pragma mark - Init With Snapshot (RECOMMENDED)

- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot {
    if (!snapshot.exists) return nil;

    NSMutableDictionary *data = snapshot.data.mutableCopy ?: @{}.mutableCopy;
    data[@"ID"] = snapshot.documentID;

    return [self initWithDictionary:data];
}

+ (instancetype)fromSnapshot:(FIRDocumentSnapshot *)snapshot {
    return [[ChildModel alloc] initWithSnapshot:snapshot];
}

#pragma mark - Init From Card (New Child Shortcut)

- (instancetype)initWithCard:(CardModel *)card {
    self = [self init];
    if (!self || !card) return nil;

    _CardID = card.ID;
    _ChildRingID = card.RingID;
    _CageID = card.CageID;
    _UserID = card.UserID;
    _addingDate = [NSDate date];
    _lastUpdated = [NSDate date];
    _BirthDate = [NSDate date];

    return self;
}

#pragma mark - Firestore Export

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary new];

    dict[@"ID"]          = self.ID ?: @"";
    dict[@"CageID"]      = self.CageID ?: @"";
    dict[@"UserID"]      = self.UserID ?: @"";
    dict[@"ChildRingID"] = self.ChildRingID ?: @"";
    dict[@"CardID"]      = self.CardID ?: @"";

    dict[@"archiveID"]        = self.archiveID ?: @"";
    dict[@"masterArchiveID"] = self.masterArchiveID ?: @"";

    dict[@"isDeleted"]  = @(self.isDeleted);
    dict[@"isSold"]     = @(self.isSold);

    dict[@"childBox"]   = @(self.childBox);
    dict[@"childBoxID"] = self.childBoxID ?: @"";

    dict[@"cameFrom"]   = @(self.cameFrom);

    dict[@"addingDate"] = self.addingDate ?: [NSDate date];
    dict[@"lastUpdated"] = self.lastUpdated ?: [NSDate date];
    dict[@"BirthDate"] = self.BirthDate ?: [NSDate date];

    return dict;
}

@end
