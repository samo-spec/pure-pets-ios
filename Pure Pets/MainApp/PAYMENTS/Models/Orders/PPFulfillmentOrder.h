#import <Foundation/Foundation.h>

@interface PPFulfillmentOrder : NSObject

@property (nonatomic, copy) NSString *fulfillmentID;
@property (nonatomic, copy) NSString *parentOrderId;
@property (nonatomic, copy) NSString *ownerID;
@property (nonatomic, copy) NSString *ownerType;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, assign) NSInteger itemCount;
@property (nonatomic, assign) double subtotal;
@property (nonatomic, assign) double providerNet;
@property (nonatomic, copy) NSString *currency;

+ (instancetype)fromDictionary:(NSDictionary *)dict fulfillmentID:(NSString *)fulfillmentID;

@end
