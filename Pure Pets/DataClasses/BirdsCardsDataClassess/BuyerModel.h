//
//  BuyerModel.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 17/03/2025.
//

#import <Foundation/Foundation.h>
@class CityModel;
NS_ASSUME_NONNULL_BEGIN

@interface BuyerModel : NSObject

@property (nonatomic, strong) NSString *ID;
@property (nonatomic, strong) NSString *UserID;
@property (nonatomic, strong) NSString *buyerName;
@property (nonatomic, strong) NSString *buyerMobile;
@property (nonatomic, strong) NSString *buyerPrice;
@property (nonatomic, strong) NSDate *sellDate;
@property (nonatomic, strong) NSString *buyerNote;
@property (nonatomic, assign) CardSection birdWasIn;
@property (nonatomic, strong) NSString *birdID;
@property (nonatomic, assign) NSInteger isDeleted;
- (CityModel *)resolvedCity;
@property (nonatomic, assign) NSInteger cityID;
@property (nonatomic, strong, nullable) CityModel *city;

@property (nonatomic, strong) NSString *birdRingId;
@property (nonatomic, strong) NSString *birdTitle;
@property (nonatomic, strong) NSString *birdBirdDate;
@property (nonatomic, strong) NSString *birdAge;


+ (void)createBuyer:(BuyerModel *)buyer completion:(void (^)(NSError * _Nullable))completion;
- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;
+ (NSMutableArray<BuyerModel *> *)fromSnapshot:(id)snapshotOrArray;
+ (void)modifyBuyer:(BuyerModel *)buyer documentID:(NSString *)documentID completion:(void (^)(NSError * _Nullable))completion;

+ (void)deleteBuyerWithDocumentID:(NSString *)documentID completion:(void (^)(NSError * _Nullable))completion;

+ (void)getAllBuyersWithCompletion:(void (^)(NSArray<BuyerModel *> * _Nullable, NSError * _Nullable))completion;
+ (BuyerModel *)buyerFromDictionary:(NSDictionary *)dictionary;

-(void)updateCageIsSoldForCard:(CardModel *)card withValue:(NSInteger)isSold completionHandler:(void (^)(int result))completionHandler;

-(void)updateArchiveIsSoldForCard:(CardModel *)card withValue:(NSInteger)isSold completionHandler:(void (^)(int result))completionHandler;

@end

NS_ASSUME_NONNULL_END



/*
 
 @property (nonatomic, strong) NSString *bird_ring_id;
 @property (nonatomic, strong) NSString *bird_title;
 @property (nonatomic, strong) NSString *bird_bird_date;
 @property (nonatomic, strong) NSString *bird_age;
 */
