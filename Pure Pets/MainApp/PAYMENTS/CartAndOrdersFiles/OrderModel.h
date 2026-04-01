//
//  OrderItem.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/07/2025.
//


#import <Foundation/Foundation.h>
#import "CartItem.h"
NS_ASSUME_NONNULL_BEGIN
@interface OrderModel : NSObject

@property (nonatomic, strong) NSString *orderID;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, assign) OrderStatus status;
@property (nonatomic, assign) float totalPrice;
@property (nonatomic, assign) NSInteger totalQuantity;
@property (nonatomic, strong) NSArray<CartItem *> *items;

- (instancetype)initWithDocumentID:(NSString *)docID dictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
