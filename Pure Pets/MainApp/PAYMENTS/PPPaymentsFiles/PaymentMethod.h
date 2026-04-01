//
//  PaymentMethod.h
//  PurePets
//
//  Created by Mohammed Ahmed on 2025-11-04.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PaymentMethodType) {
    PaymentMethodTypeCard = 0,
    PaymentMethodTypeOoredoo,
    PaymentMethodTypeQNB,
    PaymentMethodTypeApplePay,
    PaymentMethodTypeFawryQatar,
    PaymentMethodTypeCash,
    PaymentMethodTypeQIB
};

NS_ASSUME_NONNULL_BEGIN

@interface PaymentMethod : NSObject <NSSecureCoding>

@property (nonatomic, copy) NSString *methodID;             // e.g. "qnb"
@property (nonatomic, copy) NSString *displayName;          // e.g. "QNB"
@property (nonatomic, copy) NSString *iconName;             // e.g. "qnb_icon"
@property (nonatomic, copy, nullable) NSString *methodDescription;
@property (nonatomic, assign) PaymentMethodType type;
@property (nonatomic, assign) BOOL supportsMultipleAccounts;
@property (nonatomic, copy) UIColor *tintColor;
// MARK: - Helpers
+ (NSArray<PaymentMethod *> *)defaultMethods;
+ (nullable PaymentMethod *)methodForID:(NSString *)methodID;

@end

NS_ASSUME_NONNULL_END
