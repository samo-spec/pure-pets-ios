//
//  AdoptPetModel.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/08/2025.
//


//
//  AdoptPetModel.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/08/2024.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AdoptPetModel : NSObject

@property (nonatomic, copy) NSString *documentID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic) NSInteger kindID;                 // from MainKindsModel.ID
@property (nonatomic, copy) NSString *ownerID;
@property (nonatomic) NSInteger breedID;
@property (nonatomic) NSInteger ageMonths;
@property (nonatomic, copy) NSString *gender;           // "Male" / "Female"
@property (nonatomic) NSInteger cityID;
@property (nonatomic, copy) NSString *details;
@property (nonatomic, strong) NSArray<NSString *> *imageURLs;
@property (nonatomic, copy, nullable) NSArray<NSDictionary *> *imageMeta;
@property (nonatomic, strong) NSDate *createdAt;
/// 0 = public, 1 = hidden by owner. Missing legacy values default to public.
@property (nonatomic) NSInteger visibility;

- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;
- (NSDictionary *)toFirestoreDictionary;


@property (nonatomic, copy) NSString *mCityName;
@property (nonatomic, strong) MainKindsModel *mainKindModel;
@property (nonatomic, strong) SubKindModel *subKindModel;

@end

NS_ASSUME_NONNULL_END
