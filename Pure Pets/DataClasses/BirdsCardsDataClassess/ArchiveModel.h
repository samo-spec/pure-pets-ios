//

//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//


#import "ArchiveDetailsModel.h"

@import FirebaseFirestore;
NS_ASSUME_NONNULL_BEGIN


@interface ArchiveModel : NSObject
 
@property (nonatomic, strong) NSString *ID;
@property (nonatomic, strong) NSString *archiveTitle;
@property (nonatomic, strong) NSDate *archiveDate;
@property (nonatomic, strong) NSString *archiveOwnerID;
@property (nonatomic, assign) NSInteger isDeleted;
@property (nonatomic, assign) NSInteger detailsCount;
// In-memory only (loaded from subcollection)
@property (nonatomic, strong) NSMutableArray<ArchiveDetailsModel *> *details;
@property (nonatomic, strong) NSMutableArray<ArchiveDetailsModel *> *deletedDetails;
@property (nonatomic, strong) NSMutableArray<ArchiveDetailsModel *> *AllArchiveDetArray;
- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;
- (BOOL)containsCardID:(NSString *)cardID;

@end

 
/*
@interface ArchiveModel : NSObject
// ArchiveModel.h
+ (NSMutableArray<ArchiveModel *> *)fromSnapshot:(FIRQuerySnapshot *)snapshot;
@property (nonatomic, strong) NSString *ID;
@property (nonatomic, strong) NSString *archiveTitle;
@property (nonatomic, strong) NSDate *archiveDate;
@property (nonatomic,strong) NSString *archiveOwnerID;
@property (nonatomic) NSInteger isDeleted;
@property (nonatomic, strong) NSMutableArray<ArchiveDetailsModel *> *ArchiveDetArray;
@property (nonatomic, strong) NSMutableArray<ArchiveDetailsModel *> *ArchiveDetDeletedArray;
@property (nonatomic, strong) NSMutableArray<ArchiveDetailsModel *> *AllArchiveDetArray;
- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;


- (void)replaceArchiveDetailArray:(NSMutableArray<ArchiveDetailsModel *> *)archiveDetailArray
              forArchiveWithID:(NSString *)archiveID
                       completion:(void(^)(NSError * _Nullable error))completion;

- (void)removeArchiveDetail:(ArchiveDetailsModel *)archiveDetail
        fromArchiveWithID:(NSString *)archiveID
                 completion:(void(^)(NSError * _Nullable error))completion;


-(ArchiveDetailsModel *)getArchiveDetailsModelWithArchiveDetID:(NSString *)archiveDetID archiveID:(NSString *)archiveID fromArray:(NSMutableArray<ArchiveModel *>*)archivesArray;
-(ArchiveDetailsModel *)getDeletedArchiveDetailsModelWithArchiveDetID:(NSString *)archiveDetID archiveID:(NSString *)archiveID fromArray:(NSMutableArray<ArchiveModel *>*)archivesArray;
-(NSMutableDictionary *)ConvertModelToDictionary:(ArchiveDetailsModel *) archiveDetailsModel;

- (void)UpdateArchiveDetail:(ArchiveDetailsModel *)archiveDetail
        fromArchiveWithID:(NSString *)archiveID
                 completion:(void(^)(NSError * _Nullable error))completion;


-(void)saveChangesToFirebaseWithArchiveModel:(ArchiveModel*)archiveModel completion:(void(^)(NSError * _Nullable error))completion;@end */


NS_ASSUME_NONNULL_END

/*
 
 @import FirebaseFirestore;

 @interface ArchiveModel : NSObject
 @property (nonatomic, strong) NSString *ID;
 @property (nonatomic, strong) NSString *archiveTitle;
 @property (nonatomic, strong) NSDate *archiveDate;
 @property (nonatomic,strong) NSString *archiveOwnerID;
 @property (nonatomic) NSInteger isDeleted;
 @property (nonatomic, strong) NSMutableArray<ArchiveDetailsModel *> *ArchiveDetArray; // FIRFieldValue
 @property (nonatomic, strong) NSMutableArray<ArchiveDetailsModel *> *ArchiveDetDeletedArray; //FIRFieldValue
 @property (nonatomic, strong) NSMutableArray<ArchiveDetailsModel *> *AllArchiveDetArray;  FIRFieldValue
 - (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;
 @end


 @interface ArchiveDetailsModel : NSObject
 @property (nonatomic, strong) NSString *ID;
 @property (nonatomic, strong) NSString *masterArchiveID;
 @property (nonatomic, strong) NSString *CardID;
 @property (nonatomic, strong) NSDate *cardArchiveDate;
 @property (nonatomic, assign) NSInteger isDeleted;
 @property (nonatomic, assign) NSInteger cardInfo;
 @property (nonatomic, strong) NSString *CageID;
 @property (nonatomic, assign) NSInteger isSold;
 - (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;
 - (instancetype)initWith:(NSMutableDictionary *)data;
 @end
 i need function to remove ArchiveDetailsModel by ArchiveDetailsModel.CardID  from ArchiveModelArry and collection ArchiveCol in firestore
 
 
 i need function to update ArchiveDetailsModel in ArchiveDetArray in ArchiveModel
 using ArchiveDetailsModel.CardID
 in firebase firestore with collection name 'ArchiveCol'
 opjective c
 
 i want to create archives manager to do :
 1- get all archives
 2- update ArchiveModel
 3- update one row on ArchiveDetArray archive details (ArchiveDetails is FirValueField)
 4- get archive my id
 5- get archive by CardID  its ID form CardCollections
 6- get archive by CageID its ID form CagesdCollections
 7-update by CardID  its ID form CardCollections
 */
