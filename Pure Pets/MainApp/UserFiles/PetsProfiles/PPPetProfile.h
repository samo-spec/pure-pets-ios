//
//  PPPetVaccinationRecord.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//


#import <Foundation/Foundation.h>
@import FirebaseFirestore;

NS_ASSUME_NONNULL_BEGIN

@interface PPPetVaccinationRecord : NSObject
@property (nonatomic, copy) NSString *recordID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong, nullable) NSDate *appliedAt;
@property (nonatomic, strong, nullable) NSDate *nextDueDate;
@property (nonatomic, copy, nullable) NSString *notes;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)toDictionary;
@end

@interface PPPetProfile : NSObject
@property (nonatomic, copy) NSString *petID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy, nullable) NSString *breed;
@property (nonatomic, assign) NSInteger ageInMonths;
@property (nonatomic, copy, nullable) NSString *imageURL;
@property (nonatomic, assign) BOOL isDefaultPet;
@property (nonatomic, strong) NSArray<PPPetVaccinationRecord *> *vaccinations;
@property (nonatomic, strong, nullable) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *updatedAt;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (instancetype)initWithSnapshot:(FIRDocumentSnapshot *)snapshot;
- (NSDictionary *)toDictionary;
- (NSString *)displayAgeText;
@end

NS_ASSUME_NONNULL_END