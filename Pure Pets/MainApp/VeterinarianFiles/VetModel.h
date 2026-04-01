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

- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict withID:(NSString *)vetID;

@end
