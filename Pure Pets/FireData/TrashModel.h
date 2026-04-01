//
//  TrashModel.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 11/12/2025.
//


//
//  TrashModel.h
//  Pure Pets
//
 

typedef NS_ENUM(NSInteger, RefType) {
    RefTypeCard = 0,
    RefTypeCage,
    RefTypeChild,
    RefTypeArchive
};

//
//  TrashModel.h
//  Pure Pets
//


#import <Foundation/Foundation.h>
@import FirebaseFirestore;

NS_ASSUME_NONNULL_BEGIN

@interface TrashModel : NSObject
- (void)resolveRefIDIfNeeded;
- (void)persistHealedRefIDIfNeeded;
@property (nonatomic, strong) NSString *ID;
@property (nonatomic, strong) NSString *ownerID;
@property (nonatomic, strong) NSString *title;
/**
 Reference ID (CardID / CageID / ChildID / ArchiveID)
 */
@property (nonatomic, strong) NSString *RefID;
@property (nonatomic, strong) NSString *CageID;
@property (nonatomic, strong) NSString *CardID;
@property (nonatomic, strong) NSString *masterArchiveID;
@property (nonatomic, strong) NSString *archiveID;
/**
 Reference Type
 */
@property (nonatomic, strong) NSString *imageUrl;

@property (nonatomic, assign) RefType RefType;

@property (nonatomic, strong) NSString *deleteReason;
@property (nonatomic, strong) NSDate   *DeletedAt;

@property (nonatomic, assign) NSInteger isDeleted;
@property (nonatomic, assign) CameFrom cameFrom;

// Init from Firestore snapshot
- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;

// Convert QuerySnapshot → models
+ (NSMutableArray<TrashModel *> *)fromSnapshot:(FIRQuerySnapshot *)snapshot;

// Convert to Firestore dictionary
- (NSDictionary *)dictionaryRepresentation;

+ (instancetype)trashFromCard:(nullable CardModel *)card
                        child:(nullable ChildModel *)child
                         cage:(nullable CageModel *)cage
               archiveDetails:(nullable ArchiveDetailsModel *)archiveDetails
               archiveMaster:(nullable ArchiveModel *)archiveMaster
                deleteReason:(nullable NSString *)reason;

- (NSDictionary *)firestoreData;

@end

NS_ASSUME_NONNULL_END
