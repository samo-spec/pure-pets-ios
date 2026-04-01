//

//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//


#import "ChildModel.h"

@import FirebaseFirestore;
NS_ASSUME_NONNULL_BEGIN

@interface ArchiveDetailsModel : NSObject <NSMutableCopying>

@property (nonatomic, strong) NSString *ID;
@property (nonatomic, strong) NSString *masterArchiveID;
@property (nonatomic, strong) NSString *CardID;
@property (nonatomic, strong,nullable) NSDate *cardArchiveDate;
@property  (nonatomic , strong,nullable) NSDate *lastUpdated;

@property (nonatomic, strong) NSString *UserID;
@property (nonatomic, assign) NSInteger isDeleted;
@property (nonatomic, assign) CardInfo cardInfo;
@property (nonatomic, strong) NSString *CageID;
@property (nonatomic, assign) NSInteger isSold;


- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END
