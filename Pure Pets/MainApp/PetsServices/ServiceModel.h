//
//  ServiceModel.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 14/07/2025.
//


typedef NS_ENUM(NSInteger, ServiceType) {
    ServiceTypeTraining,
    ServiceTypeGrooming
};

@interface ServiceModel : NSObject
NS_ASSUME_NONNULL_BEGIN
@property (nonatomic, copy) NSString *serviceID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *desc;
@property (nonatomic, assign) double price;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, copy) NSString *categoryID;
@property (nonatomic, assign) NSInteger petMainKindID;
@property (nonatomic, strong) NSDate *availableDate;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, copy, nullable) NSString *imageURL;
@property (nonatomic, copy, nullable) NSString *serviceOwnerID;
@property (nonatomic, assign) ServiceType type;
- (instancetype)initWithDictionary:(NSDictionary *)dict documentID:(nullable NSString *)documentID;
- (NSDictionary *)toDictionary;
@property (nonatomic, readonly) NSString *searchTitle;
@property (nonatomic, copy)   NSString *blurHash;

@end
NS_ASSUME_NONNULL_END
