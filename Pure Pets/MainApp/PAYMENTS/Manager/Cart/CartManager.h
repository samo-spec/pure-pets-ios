//
//  CartManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/02/2026.
//


#import <Foundation/Foundation.h>
#import "PetAccessory.h"
#import "CartItem.h"
@class UIViewController;
NS_ASSUME_NONNULL_BEGIN

typedef void (^PPCartAddItemCompletion)(BOOL success, BOOL didCancel);

@interface CartManager : NSObject

@property (nonatomic, strong) NSMutableArray<CartItem *> *cartItems;
@property (nonatomic, assign, readonly) BOOL isLocked;
@property (nonatomic, assign, readonly) double deliveryFee;
@property (nonatomic, assign, readonly) BOOL cashOnDeliveryEnabled;
@property (nonatomic, assign, readonly) BOOL onlinePaymentEnabled;
@property (nonatomic, assign, readonly) BOOL applePayEnabled;
@property (nonatomic, assign, readonly) BOOL ooredooMoneyEnabled;
@property (nonatomic, assign, readonly) BOOL napsEnabled;
@property (nonatomic, assign, readonly) BOOL allowMultiProviderCart;

+ (instancetype)sharedManager;
- (BOOL)addItem:(CartItem *)item;
- (void)addItem:(CartItem *)item
presentingViewController:(UIViewController * _Nullable)presentingViewController
     completion:(PPCartAddItemCompletion _Nullable)completion;
- (void)syncCartToFirestore:(NSArray<CartItem *> *)items;
- (void)saveCart;
- (void)clearCart;
- (void)startListeningToCartChanges;
/// Stops the Firestore cart listener. Call on logout or when the listener is no longer needed.
- (void)stopListeningToCartChanges;
- (NSInteger)quantityForAccessory:(PetAccessory *)accessory;
- (void)updateQuantity:(NSInteger)newQuantity
              forItem:(CartItem *)item
           completion:(void (^ _Nullable)(BOOL success))completion;
- (void)removeItemForAccessory:(PetAccessory *)accessory;
- (PetAccessory *)accessoryForCartItem:(CartItem *)item inArray:(NSArray<PetAccessory *> *)accessories;
- (CartItem *)getCartItemForItemID:(NSString *)ItemID;

- (void)removeItem:(CartItem *)item;
- (NSInteger)totalItemsCount;
- (double)subtotalAmount;
- (double)totalAmount;
- (BOOL)isCartEmpty;
- (BOOL)shouldConfirmProviderSwitchForItem:(CartItem *)item;
- (void)clearCartAndSyncToFirestoreWithCompletion:(void (^ _Nullable)(BOOL success))completion;
- (void)clearCartAndSyncToFirestore;
- (void)refreshPricingConfiguration;
@end

NS_ASSUME_NONNULL_END
