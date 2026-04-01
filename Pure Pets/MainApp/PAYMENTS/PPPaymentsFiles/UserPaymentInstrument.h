

#import <Foundation/Foundation.h>
#import "XLForm.h"
@class XLFormOptionsObject;
NS_ASSUME_NONNULL_BEGIN

@interface UserPaymentInstrument : NSObject <NSSecureCoding, XLFormOptionObject>
@property (nonatomic, strong) NSString *instrumentID;
@property (nonatomic, strong) NSString *userID;
@property (nonatomic, strong) NSString *methodID;
@property (nonatomic, strong) PaymentMethod *method;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSDate *updatedAt;
@property (nonatomic, assign) BOOL isDefault;

// 🔹 Original unmasked data (stored securely)
@property (nonatomic, strong, nullable) NSDictionary *originalData;

// 🔹 Derived or display metadata
@property (nonatomic, strong, nullable) NSDictionary *metaData;
 // 🔹 Display helper
@property (nonatomic, readonly) NSString *displaySummary;
@property (nonatomic, strong) NSString *maskedDetails;

// 🔹 Methods
- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;
- (NSString *)maskString:(NSString *)rawString;
- (NSString *)detectCardIssuerFromNumber:(NSString *)cardNumber ;
// 🔹 For Firestore
+ (instancetype)fromDocument:(NSDictionary *)dict documentID:(NSString *)docID;

@end

NS_ASSUME_NONNULL_END
