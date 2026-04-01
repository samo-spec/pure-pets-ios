//
//  CartItem.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 29/06/2025.
//

typedef NS_ENUM(NSInteger, OrderStatus)
{
    OrderStatusPending = 0,
    OrderStatusApproved,
    OrderStatusRejected,
    OrderStatusShipped,
    OrderStatusCanceled,
    OrderStatusDelivered
};



#import <Foundation/Foundation.h>
@class PetAccessory;

@interface CartItem : NSObject

@property (nonatomic, strong) NSString *itemID;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) NSInteger quantity;
@property (nonatomic, assign) NSInteger stockQuantity; // NSNotFound when unknown
@property (nonatomic, assign) float price;
@property (nonatomic, strong) NSString *imageURL;
@property (nonatomic, strong) NSString *type;


- (NSDictionary *)firestoreDictionary;
- (instancetype)initWithAccessory:(PetAccessory *)accessory quantity:(NSInteger)qty;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
// In your header file (.h)
+ (NSString *)stringFromOrderStatus:(OrderStatus)status;

@end
