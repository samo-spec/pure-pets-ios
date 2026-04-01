//
//  TrashModel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 11/12/2025.
//
//
//  TrashModel.m
//  Pure Pets
//

#import "ArchivesManager.h"
#import "ArchiveDetailsModel.h"
#import "TrashModel.h"
 
@implementation TrashModel



- (NSString *)resolveTitle
{
    // 1️⃣ Cached
    if (self.title.length > 0) {
        return self.title;
    }

    // 2️⃣ Resolve by CardID (single source of truth)
    NSString *cardID = self.CardID.length ? self.CardID : self.RefID;
    if (!self.RefID.length && cardID.length) {
        self.RefID = cardID; // 🔁 heal missing RefID
    }
    if (!cardID.length) return @"";

    CardModel *card =
    [[AppData.AllCardsDocs filteredArrayUsingPredicate:
      [NSPredicate predicateWithFormat:@"ID == %@", cardID]] firstObject];

    if (!card) return @"";

    if (card.imagesUrls.count > 0) {
        self.imageUrl = PPSafeString(card.imagesUrls.firstObject.absoluteString);
    }

    self.CardID = PPSafeString(card.ID);
    self.title  = [NSString stringWithFormat:@"%@ (%@)",
                   card.CardTitle ?: @"",
                   PPSafeString(card.RingID)];

    return self.title;
}



- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot
{
    self = [super init];
    if (!self || !snapshot.exists) return nil;

    NSDictionary *data = snapshot.data;

    _ID          = snapshot.documentID;
    _ownerID     = data[@"ownerID"] ?: nil;
    _RefID = data[@"RefID"];
    if (!_RefID.length) {
        // 🔁 Re-get RefID from CardID or snapshot ID as fallback
        _RefID = PPSafeString(data[@"CardID"]);
        if (!_RefID.length) {
            _RefID = snapshot.documentID;
        }
    }
    _RefType     = [data[@"RefType"] integerValue];

    _CageID       = data[@"CageID"] ?: @"";
    _masterArchiveID       = data[@"masterArchiveID"] ?: @"";

    _deleteReason = data[@"deleteReason"] ?: @"";
    _isDeleted    = [data[@"isDeleted"] integerValue];
    _cameFrom     = [data[@"cameFrom"] integerValue];
    _CardID     = data[@"CardID"];
    id deletedValue = data[@"DeletedAt"];

    if ([deletedValue isKindOfClass:[FIRTimestamp class]]) {
        _DeletedAt = ((FIRTimestamp *)deletedValue).dateValue;
    }
    else if ([deletedValue isKindOfClass:[NSDate class]]) {
        _DeletedAt = (NSDate *)deletedValue;
    }
    else {
        _DeletedAt = [NSDate date];
    }
    //_title = data[@"title"];
    //if (!_title.length) {
        _title = [self resolveTitle];
    //}
    [self resolveRefIDIfNeeded];
    //[self persistHealedRefIDIfNeeded];

    return self;
}

+ (NSMutableArray<TrashModel *> *)fromSnapshot:(FIRQuerySnapshot *)snapshot
{
    NSMutableArray *result = [NSMutableArray array];

    for (FIRDocumentSnapshot *doc in snapshot.documents) {
        TrashModel *model = [[TrashModel alloc] initWithSnapshot:doc];
        if (model) [result addObject:model];
    }
    return result;
}


- (NSDictionary *)firestoreData
{
    return @{
        @"ID"              : PPSafeString(self.ID),
        @"ownerID"         : PPSafeString(self.ownerID),
        @"RefID"           : PPSafeString(self.RefID),
        @"CardID"          : PPSafeString(self.CardID),
        @"CageID"          : PPSafeString(self.CageID),
        @"masterArchiveID" : PPSafeString(self.masterArchiveID),
        @"title"           : PPSafeString(self.title),
        @"imageUrl"        : PPSafeString(self.imageUrl),
        @"RefType"         : @(self.RefType),
        @"cameFrom"        : @(self.cameFrom),
        @"isDeleted"       : @1,
        @"DeletedAt"       : [FIRTimestamp timestampWithDate:self.DeletedAt ?: [NSDate date]],
        @"deleteReason"    : PPSafeString(self.deleteReason),
    };
}

- (NSDictionary *)dictionaryRepresentation
{
    return [self firestoreData];
}

- (void)resolveRefIDIfNeeded
{
    if (self.RefID.length > 0) return;

    switch (self.RefType) {

        case RefTypeCard: {
            // Card → RefID = CardID
            self.RefID = PPSafeString(self.CardID);
        } break;

        case RefTypeChild: {
            // Child → find child inside cage by CardID
            if (!self.CageID.length || !self.CardID.length) break;
            
            [ChildsDataManager fetchChildrenForCageID:self.CageID completion:^(NSArray<ChildModel *> * _Nonnull children, NSError * _Nullable error) {
                for (ChildModel *child in children) {
                    if ([child.CardID isEqualToString:self.CardID]) {
                        self.RefID = PPSafeString(child.ID);
                        [self persistHealedRefIDIfNeeded];
                        break;
                    }
                }
            }];

            

            
        } break;

        case RefTypeArchive: {
            // Archive → find archive detail by CardID
            if (!self.CardID.length) break;
            
            [ArchivesManager.shared fetchArchiveDetailsForCardID:self.CardID completion:^(NSArray<ArchiveDetailsModel *> * _Nonnull details, NSError * _Nullable error) {
                NSLog(@"ArchiveDetailsModel Founded %@",details.modelToJSONString);
                for (ArchiveDetailsModel *detail in details) {
                    if ([detail.CardID isEqualToString:self.CardID]) {
                        self.RefID = PPSafeString(detail.ID);
                        [self persistHealedRefIDIfNeeded];
                        break;
                    }
                }
            }];

             
        } break;

        default:
            break;
    }
}

- (void)persistHealedRefIDIfNeeded
{
    // Only persist if RefID was missing in Firestore but resolved locally
    if (!self.ID.length || !self.RefID.length) return;

    // Guard: do not spam writes
    static NSMutableSet *persistedIDs;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        persistedIDs = [NSMutableSet set];
    });

    if ([persistedIDs containsObject:self.ID]) return;
    [persistedIDs addObject:self.ID];

    NSMutableDictionary *updates = [NSMutableDictionary dictionary];
    updates[@"RefID"] = self.RefID;

    if (self.masterArchiveID.length) {
        updates[@"masterArchiveID"] = self.masterArchiveID;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    [[[db collectionWithPath:@"TrashCol"]
      documentWithPath:self.ID]
     updateData:updates
     completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"❌ Failed to persist healed RefID %@ : %@", self.ID, error);
        } else {
            NSLog(@"✅ Healed RefID persisted for trash %@", self.ID);
        }
    }];
}

+ (instancetype)trashFromCard:(nullable CardModel *)card
                        child:(nullable ChildModel *)child
                         cage:(nullable CageModel *)cage
               archiveDetails:(nullable ArchiveDetailsModel *)archiveDetails
               archiveMaster:(nullable ArchiveModel *)archiveMaster
                deleteReason:(nullable NSString *)reason
{
    TrashModel *t = [TrashModel new];

    // -------- Owner --------
    t.ownerID = PPSafeString(PPCurrentUser.ID);

    // -------- Card --------
    t.CardID = PPSafeString(card.ID);
    t.CageID = PPSafeString(card.CageID);
    t.title  = PPSafeString(card.CardTitle);

    if (card.imagesUrls.count > 0) {
        t.imageUrl = PPSafeString(card.imagesUrls.firstObject.absoluteString);
    } else {
        t.imageUrl = @"";
    }

    // -------- Resolve Reference (priority-based) --------
    // Child > ArchiveDetails > ArchiveMaster > Card
    if (child) {
        t.RefType = RefTypeChild;
        t.RefID   = PPSafeString(child.ID);
        t.CageID  = PPSafeString(child.CageID ?: cage.ID);
        t.cameFrom = CameFromChilds;

    } else if (archiveDetails) {
        t.RefType = RefTypeArchive;
        t.RefID   = PPSafeString(archiveDetails.ID);
        t.masterArchiveID = PPSafeString(archiveDetails.masterArchiveID);
        t.cameFrom = CameFromArchive;

    } else if (archiveMaster) {
        t.RefType = RefTypeArchive;
        t.RefID   = PPSafeString(archiveMaster.ID);
        t.masterArchiveID = PPSafeString(archiveMaster.ID);
        t.cameFrom = CameFromArchive;

    } else {
        // Fallback (should not normally happen)
        t.RefType = RefTypeCard;
        t.RefID   = PPSafeString(card.ID);
        t.cameFrom = CameFromCards;
    }

    // -------- Common --------
    t.deleteReason = PPSafeString(reason);
    t.isDeleted = YES;
    t.DeletedAt = [NSDate date];

    // -------- Stable Trash ID --------
    t.ID = [NSString stringWithFormat:@"TRASH_%@_%@",
            t.ownerID,
            t.RefID.length ? t.RefID : t.CardID];

    return t;
}


@end
