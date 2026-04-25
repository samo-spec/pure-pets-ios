//
//  VetModel.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 15/07/2025.
//


typedef NS_ENUM(NSInteger, VetType) {
    VetTypePersonal,
    VetTypeCompany
};

@interface VetModel : NSObject

@property (nonatomic, strong) NSString *vetID;
@property (nonatomic, assign) VetType type;
@property (nonatomic, strong) NSString *userID;
@property (nonatomic, assign) NSInteger petMainKindID;
@property (nonatomic, strong) NSString *logoURL;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *descriptionText;
@property (nonatomic, strong) NSString *phone;
@property (nonatomic, strong) NSString *whatsapp;
@property (nonatomic, strong) NSDate *availableDate;
@property (nonatomic, assign) double vetCost;
@property (nonatomic, readonly) NSString *name_lowercase;
@property (nonatomic, copy)   NSString *blurHash;
@property (nonatomic, copy) NSArray<NSString *> *animalTypes;
@property (nonatomic, assign) BOOL readyToContact;
@property (nonatomic, assign) BOOL isDisabled;
@property (nonatomic, copy) NSString *verificationStatus;
@property (nonatomic, assign) BOOL subscriptionActive;
@property (nonatomic, assign) NSInteger subscriptionTier;
@property (nonatomic, strong, nullable) NSDate *subscriptionStartDate;
@property (nonatomic, strong, nullable) NSDate *subscriptionEndDate;
@property (nonatomic, assign) BOOL canEditProfile;
@property (nonatomic, assign) BOOL canPostServices;
@property (nonatomic, assign) BOOL canPostMedicines;
@property (nonatomic, strong, nullable) NSDate *createdAt;
@property (nonatomic, strong, nullable) NSDate *updatedAt;

- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(NSString *)vetID;
- (NSString *)normalizedTypeValue;

@end
