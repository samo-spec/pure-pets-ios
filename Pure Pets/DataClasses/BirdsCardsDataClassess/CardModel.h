//
//  UserModel.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//

#import "ImageModel.h"
#import "SubKindModel.h"
@import FirebaseFirestore;
#import "XLFormOptionsObject.h"
#import "subKindItemsModel.h"
#import "FileModel.h"
#import "PetImageItem.h"
NS_ASSUME_NONNULL_BEGIN




@interface AgeInfoModel : NSObject

@property (nonatomic, readonly) NSInteger years;
@property (nonatomic, readonly) NSInteger months;
@property (nonatomic, readonly) NSInteger days;
@property (nonatomic, readonly) NSInteger totalMonths;
@property (nonatomic, readonly) BOOL isAdult;

@property (nonatomic, copy, readonly) NSString *ageString;
@property (nonatomic, copy, readonly) NSString *readyString;

- (instancetype)initWithYears:(NSInteger)years
                        months:(NSInteger)months
                          days:(NSInteger)days
                   totalMonths:(NSInteger)totalMonths
                       isAdult:(BOOL)isAdult
                     ageString:(NSString *)ageString
                   readyString:(NSString *)readyString;

@end



typedef void (^VideoUrlCompletionBlock)(NSURL * _Nullable url, NSError * _Nullable error);

typedef NS_ENUM(NSInteger, CardLocation)
{
    CardLocationCards = 1,
    CardLocationCage = 2,
    CardLocationArchive = 3,
    CardLocationChilds = 4
};

typedef NS_ENUM(NSInteger, CardSection)
{
    CardSectionCards = 1,
    CardSectionCage = 2,
    CardSectionNewChild = 3,
    CardSectionArchive = 4,
    CardSectionSold = 5
};

typedef NS_ENUM(NSInteger, CardInfo)
{
    CardInfoKindFullCard = 1,
    CardInfoKindCHILDCard = 2,
    
};

// 1 = FULL CARD      2 = CHILD CARD


@interface CardModel : NSObject<XLFormOptionObject,NSCoding>
+ (NSMutableArray<CardModel *> *)fromSnapshot:(id)snapshotOrArray;
@property  (nonatomic , strong) NSString *ID;
@property (nonatomic, strong) NSString *docID;
@property  (nonatomic , assign) CardSection cardSection;
@property  (nonatomic , assign) CardSection oldCardSection;
@property  (nonatomic , strong) NSString *RingID;
@property  (nonatomic , assign) NSInteger SubKind;
@property  (nonatomic , assign) NSInteger subSubKindID;
@property  (nonatomic , strong) NSString *subKindItemsID;
@property  (nonatomic , strong) NSString *splitID;
@property  (nonatomic , assign) NSInteger attribute;
@property  (nonatomic , strong) NSString *AttributeNote;
@property  (nonatomic , assign) NSInteger Sexual;
@property  (nonatomic , strong) NSString *birdColor;
@property  (nonatomic , strong) NSDate *BirthDate;
@property  (nonatomic , strong) NSDate *lastUpdated;
@property  (nonatomic , strong) NSString *FatherRingID;
@property  (nonatomic , strong) NSString *MotherRingID;
@property  (nonatomic , strong) NSString *Dna;
@property  (nonatomic,strong,nonnull) NSString *AdDesc;
@property  (nonatomic , strong) NSDate *AddedDate;
@property  (nonatomic , strong) NSString *archiveID;
@property  (nonatomic , strong) NSString *masterArchiveID;
@property  (nonatomic , assign) NSInteger isDeleted;
@property  (nonatomic , strong) NSString *deleteReason;
@property  (nonatomic , strong) NSString *CageID;
@property  (nonatomic , strong) NSString *videoName;
@property  (nonatomic , strong)  NSMutableArray<FileModel *>  *FilesArray;
@property (nonatomic, readonly) NSArray<PetImageItem *> *imageItems;
@property  (nonatomic , strong) NSString *FatherRingIDString;
@property  (nonatomic , strong) NSString *MotherRingIDString;
@property  (nonatomic , strong) NSString *ClassificationString;
@property  (nonatomic , strong) NSString *AdDescString;
@property  (nonatomic , assign) NSInteger SexualString;
@property  (nonatomic , strong) NSString *splitIDString;
@property  (nonatomic , strong) NSString *attributeValue;
@property  (nonatomic , strong) NSString *subKindString;
@property  (nonatomic , strong) NSString *subSubKindString;
@property  (nonatomic , strong) NSString *SexualTXT;
@property (nonatomic) AgeInfoModel *ageInfo;

@property  (nonatomic , strong) NSString *UserID;
@property  (nonatomic , strong) NSString *CardTitle;
@property  (nonatomic , assign) NSInteger isSold;
@property  (nonatomic , strong) NSString *soldPrice;
@property (nonatomic , strong) NSString *CardLocation;
@property (nonatomic) CardLocation CardLocate;
@property (nonatomic) CardInfo cardInfo; // 1 = FULL CARD      2 = CHILD CARD
@property (nonatomic , strong) NSString *loanForUser;
@property (nonatomic , strong) NSMutableArray  *imagesNames;
@property (nonatomic , strong) NSMutableArray<NSURL *>  *imagesUrls;
@property (nonatomic , strong) NSMutableArray<NSString *>  *imagesUrlsStrings;
-(NSString *)getBirdSexual;
-(NSString *)getBirdAttribute;
@property (nonatomic , strong) NSURL *vidURL;
- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;
//- (instancetype)initWithDictionary:(NSMutableDictionary *)Dict  andFilesArray:(NSArray *)Files;

- (void)updateCardWithID:(NSString *)cardID
          updateDictionary:(NSDictionary *)updateDict
              completion:(void(^)(NSError *error))completion;

+(CardModel *)getCardForID:(NSString *)cardID;
@end






NS_ASSUME_NONNULL_END
