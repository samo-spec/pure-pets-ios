//

//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//


#import "ChildModel.h"

@import FirebaseFirestore;
#import "XLFormOptionsObject.h"
/*
       
 typedef NS_ENUM(NSInteger, ParentIs)
 {
     ParentIsFather = 1,
     ParentIsMother = 2
 };

 */

NS_ASSUME_NONNULL_BEGIN
@interface CageModel : NSObject
+ (NSMutableArray<CageModel *> *)fromSnapshot:(id)snapshotOrArray;
@property (nonatomic, strong) NSString *ID;
@property (nonatomic, strong) NSString *CageName;
@property (nonatomic, strong) NSString *FatherRingID;
@property (nonatomic, strong) NSString *MotherRingID;
@property (nonatomic, strong) NSString *UserID;
@property (nonatomic, strong) NSDate *CreateDate;
@property (nonatomic, assign) NSInteger isDeleted;
@property (nonatomic, strong) NSDate *FristEggDate;
@property (nonatomic, strong) NSDate *ReminderDate;
@property (nonatomic, assign) NSInteger childsCount;
- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;
-(NSInteger)getFirstEggRemaingDays;
 

+ (void)updateCage:(CageModel *)cageModel completion:(nullable void (^)(NSError * _Nullable error))completion;

@property (nonatomic, strong) CardModel *FatherCard;
@property (nonatomic, strong) CardModel *MotherCard;
@end
NS_ASSUME_NONNULL_END
 
/*
 
 CardModel *FatherCard = [[self.allCardsArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", cageData.FatherRingID]] firstObject];
 
 
// Cage or Box
@interface CageModel : NSObject
@property (nonatomic, strong) NSString *ID;
@property (nonatomic, strong) NSString *CageName;
@property (nonatomic, strong) NSString *FatherRingID;
@property (nonatomic, strong) NSString *MotherRingID;
@property (nonatomic, strong) NSDate *CreateDate;
@property (nonatomic, assign) NSInteger isDeleted;
@property (nonatomic, strong) NSDate *FristEggDate;
@property (nonatomic, strong) NSDate *ReminderDate;
@property (nonatomic, strong) NSMutableArray<ChildModel *> *ChildsArray;
@end

@interface ChildModel : NSObject
@property (nonatomic, strong) NSString *ID;
@property (nonatomic, strong) NSString *CageID;
@property (nonatomic, strong) NSString *ChildRingID;
@property (nonatomic, strong) NSDate *addingDate;
@property (nonatomic) NSInteger isDeleted;
@property (nonatomic, strong) NSString *CardID;
@property (nonatomic, strong) NSString *archiveID;
@property (nonatomic, strong) NSString *masterArchiveID;
@property (nonatomic, assign) CameFrom cameFrom;
@property (nonatomic, assign) ChildBox childBox;
@property (nonatomic, strong) NSString *childBoxID;

@end

 . get CageModel by ChildModel.CardID from CageModel.ChildsArray in CageModelsArray
 using opjective c
 
*/




/*
 
 
 
 @interface CageModel : NSObject
 @property (nonatomic, strong) NSString *ID;
 @property (nonatomic, strong) NSString *CageName;
 @property (nonatomic, strong) NSString *FatherRingID;
 @property (nonatomic, strong) NSString *MotherRingID;
 @property (nonatomic, strong) NSDate *CreateDate;
 @property (nonatomic, assign) NSInteger isDeleted;
 @property (nonatomic, strong) NSDate *FristEggDate;
 @property (nonatomic, strong) NSDate *ReminderDate;
 @property (nonatomic, strong) NSMutableArray<ChildModel *> *ChildsArray;
 @end
 
 i want to check dialy if ReminderDate came push local notification to user
 using opjective c and firestore

 @interface ChildModel : NSObject
 @property (nonatomic, strong) NSString *ID;
 @property (nonatomic, strong) NSString *CageID;
 @property (nonatomic, strong) NSString *ChildRingID;
 @property (nonatomic, strong) NSDate *addingDate;
 @property (nonatomic) NSInteger isDeleted;
 @property (nonatomic, strong) NSString *CardID;
 @end
 i have collection names CagesCol in firestore that include a sub collection Called  Childs ,
 i want to create CagesManager to
 1- get all cages
 1- add new child
 2- modify child
 2- remove child
 2- Transferring child to another cage
 2- modify child
 
 
 
 */
