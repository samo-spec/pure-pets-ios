// PPAnalytics.h
// Pure Pets — GA4 ecommerce + intent event helper.
//
// Wraps FIRAnalytics with typed methods that emit the canonical GA4 schema
// expected by Nova's BigQuery behavior pipeline (analytics_467757932).
// Firebase Analytics auto-attaches user_pseudo_id — callers do not pass it.
//
// Currency defaults to QAR. Pass nil/0 to skip optional fields.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PetAccessory;
@class PetAd;
@class CartItem;

typedef NS_ENUM(NSInteger, PPContactChannel) {
    PPContactChannelCall      = 0,
    PPContactChannelChat      = 1,
    PPContactChannelWhatsapp  = 2,
    PPContactChannelSupport   = 3,
    PPContactChannelEmail     = 4,
};

@interface PPAnalytics : NSObject

// ---- single-item events ----
+ (void)logViewItemWithItemID:(NSString *)itemID
                         name:(nullable NSString *)name
                     category:(nullable NSString *)category
                        price:(double)price;

+ (void)logSelectItemWithItemID:(NSString *)itemID
                           name:(nullable NSString *)name
                       category:(nullable NSString *)category
                          price:(double)price
                     listName:(nullable NSString *)listName;

+ (void)logViewItemListWithCategory:(NSString *)category
                           listName:(nullable NSString *)listName
                          itemCount:(NSUInteger)itemCount;

+ (void)logViewCategoryWithCategory:(NSString *)category
                           listName:(nullable NSString *)listName;

+ (void)logSearchWithTerm:(NSString *)term resultCount:(NSUInteger)resultCount;

+ (void)logContactIntentForItemID:(nullable NSString *)itemID
                         category:(nullable NSString *)category
                          channel:(PPContactChannel)channel;

// ---- cart / checkout / purchase ----
+ (void)logAddToCartItemID:(NSString *)itemID
                       name:(nullable NSString *)name
                   category:(nullable NSString *)category
                      price:(double)price
                   quantity:(NSInteger)quantity;

+ (void)logBeginCheckoutWithCartItems:(NSArray<CartItem *> *)cartItems
                           grandTotal:(double)grandTotal;

+ (void)logPurchaseWithTransactionID:(NSString *)transactionID
                          cartItems:(NSArray<CartItem *> *)cartItems
                         grandTotal:(double)grandTotal;

// ---- model-friendly conveniences ----
+ (void)logViewItemForAccessory:(PetAccessory *)accessory;
+ (void)logViewItemForAd:(PetAd *)ad;
+ (void)logContactIntentForAd:(PetAd *)ad channel:(PPContactChannel)channel;
+ (void)logContactIntentForAccessory:(PetAccessory *)accessory channel:(PPContactChannel)channel;

// ---- Nova chat (custom GA4 events; Nova BigQuery pipeline maps these into the funnel) ----
+ (void)logNovaOpenedWithSessionID:(NSString *)sessionID;
+ (void)logNovaMessageSentWithCharCount:(NSUInteger)charCount
                                isArabic:(BOOL)isArabic
                              sessionID:(NSString *)sessionID;
+ (void)logNovaShowcaseShownWithItemCount:(NSUInteger)itemCount
                                sessionID:(NSString *)sessionID;
+ (void)logNovaShowcaseShownWithItemCount:(NSUInteger)itemCount
                                sessionID:(NSString *)sessionID
                                   source:(nullable NSString *)source;
+ (void)logNovaShowcaseResolutionFailedWithRequestedCount:(NSUInteger)requestedCount
                                             resolvedCount:(NSUInteger)resolvedCount
                                                 sessionID:(NSString *)sessionID;
+ (void)logNovaPreviewOpenedWithItemKind:(nullable NSString *)itemKind
                                  itemID:(nullable NSString *)itemID
                               sessionID:(NSString *)sessionID;
+ (void)logNovaErrorWithCode:(NSInteger)gRPCCode
                      domain:(nullable NSString *)domain
                     attempt:(NSInteger)attempt
                   sessionID:(NSString *)sessionID;
+ (void)logNovaClosedWithSessionID:(NSString *)sessionID
                      messageCount:(NSUInteger)messageCount;

@end

NS_ASSUME_NONNULL_END
