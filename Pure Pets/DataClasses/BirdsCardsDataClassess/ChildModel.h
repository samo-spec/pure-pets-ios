//
//  ChildModel.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//  Refactored to use ChildsCol subcollection
//

@import FirebaseFirestore;
#import "XLFormOptionsObject.h"

typedef NS_ENUM(NSInteger, CameFrom)
{
    CameFromCards = 0,
    CameFromChilds,
    CameFromArchive
};

typedef NS_ENUM(NSInteger, ChildBox)
{
    ChildBoxHome = 0,   // same cage
    ChildBoxAway,      // moved to another cage
    ChildBoxGuest      // coming from another cage
};

NS_ASSUME_NONNULL_BEGIN

@interface ChildModel : NSObject

#pragma mark - Identifiers
@property (nonatomic, copy) NSString *ID;
@property (nonatomic, copy) NSString *CageID;
@property (nonatomic, copy) NSString *UserID;
@property (nonatomic, copy) CardModel *card;


#pragma mark - Ring / Card
@property (nonatomic, copy) NSString *ChildRingID;
@property (nonatomic, copy) NSString *CardID;

#pragma mark - Dates
@property (nonatomic, strong) NSDate *addingDate;
@property (nonatomic, strong) NSDate *lastUpdated;
@property (nonatomic, strong) NSDate *BirthDate;
#pragma mark - Archive
@property (nonatomic, copy) NSString *archiveID;
@property (nonatomic, copy) NSString *masterArchiveID;

#pragma mark - Status Flags
@property (nonatomic, assign) NSInteger isDeleted;
@property (nonatomic, assign) NSInteger isSold;

#pragma mark - Box Transfer
@property (nonatomic, assign) ChildBox childBox;
@property (nonatomic, copy) NSString *childBoxID;

#pragma mark - UI / Flow
@property (nonatomic, assign) CameFrom cameFrom;

#pragma mark - Initializers
- (instancetype)initWithDictionary:(NSDictionary *)data;
- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;
- (instancetype)initWithCard:(CardModel *)card;

#pragma mark - Firestore Helpers
+ (instancetype)fromSnapshot:(FIRDocumentSnapshot *)snapshot;
- (NSDictionary *)dictionaryRepresentation;

@end

NS_ASSUME_NONNULL_END
