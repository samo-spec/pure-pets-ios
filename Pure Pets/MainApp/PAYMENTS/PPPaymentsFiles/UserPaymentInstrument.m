#import "UserPaymentInstrument.h"
#import <FirebaseFirestore/FirebaseFirestore.h>

static NSString *PPInstrumentStringFromValue(id value) {
    return [value isKindOfClass:NSString.class] ? [value copy] : @"";
}

static BOOL PPInstrumentBoolFromValue(id value) {
    // Preserve legacy string booleans without sending boolValue to NSNull/maps.
    return ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class])
        ? [value boolValue] : NO;
}

static NSDate *PPInstrumentDateFromValue(id value) {
    if ([value isKindOfClass:NSDate.class]) {
        return (NSDate *)value;
    }
    if ([value isKindOfClass:FIRTimestamp.class]) {
        return ((FIRTimestamp *)value).dateValue;
    }
    return nil;
}

@implementation UserPaymentInstrument

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.userID forKey:@"userID"];
    [coder encodeObject:self.methodID forKey:@"methodID"];
    [coder encodeObject:self.method forKey:@"method"];
    [coder encodeObject:self.createdAt forKey:@"createdAt"];
    [coder encodeObject:self.updatedAt forKey:@"updatedAt"];
    [coder encodeBool:self.isDefault forKey:@"isDefault"];
    [coder encodeObject:self.originalData forKey:@"originalData"];
    [coder encodeObject:self.metaData forKey:@"metaData"];
    [coder encodeObject:self.maskedDetails forKey:@"maskedDetails"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        _userID = [coder decodeObjectOfClass:[NSString class] forKey:@"userID"];
        _methodID = [coder decodeObjectOfClass:[NSString class] forKey:@"methodID"];
        _method = [coder decodeObjectOfClass:[PaymentMethod class] forKey:@"method"];
        _createdAt = [coder decodeObjectOfClass:[NSDate class] forKey:@"createdAt"];
        _updatedAt = [coder decodeObjectOfClass:[NSDate class] forKey:@"updatedAt"];
        _isDefault = [coder decodeBoolForKey:@"isDefault"];
        _originalData = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"originalData"];
        _metaData = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"metaData"];
        _maskedDetails = [coder decodeObjectOfClass:[NSString class] forKey:@"maskedDetails"];
    }
    return self;
}

#pragma mark - Init

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        NSDictionary *payload = [dict isKindOfClass:NSDictionary.class] ? dict : @{};
        _userID = PPInstrumentStringFromValue(payload[@"userID"]);
        _methodID = PPInstrumentStringFromValue(payload[@"methodID"]);
        _createdAt = PPInstrumentDateFromValue(payload[@"createdAt"]) ?: [NSDate date];
        _updatedAt = PPInstrumentDateFromValue(payload[@"updatedAt"]) ?: [NSDate date];
        _isDefault = PPInstrumentBoolFromValue(payload[@"isDefault"]);
        _originalData = [payload[@"originalData"] isKindOfClass:NSDictionary.class] ? payload[@"originalData"] : @{};
        NSDictionary *meta = [payload[@"metaData"] isKindOfClass:NSDictionary.class] ? payload[@"metaData"] : nil;
        if (!meta && [payload[@"metadata"] isKindOfClass:NSDictionary.class]) {
            // Backward compatibility for legacy key typo.
            meta = payload[@"metadata"];
        }
        _metaData = meta ?: @{};
        _maskedDetails = PPInstrumentStringFromValue(payload[@"maskedDetails"]);

        // Build PaymentMethod if possible
        _method = [PaymentMethod methodForID:_methodID];
    }
    return self;
}

#pragma mark - Serialization

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"userID"] = self.userID ?: @"";
    dict[@"methodID"] = self.methodID ?: @"";
    dict[@"createdAt"] = self.createdAt ?: [NSDate date];
    dict[@"updatedAt"] = self.updatedAt ?: [NSDate date];
    dict[@"isDefault"] = @(self.isDefault);
    dict[@"originalData"] = self.originalData ?: @{};
    dict[@"metaData"] = self.metaData ?: @{};
    dict[@"maskedDetails"] = self.maskedDetails ?: @"";

    return dict;
}

+ (instancetype)fromDocument:(NSDictionary *)dict documentID:(NSString *)docID {
    NSMutableDictionary *merged = [dict mutableCopy];
    merged[@"documentID"] = docID;
    return [[UserPaymentInstrument alloc] initWithDictionary:merged];
}

#pragma mark - Masking Logic

- (NSString *)maskString:(NSString *)rawString {
    if (rawString.length < 4) return @"••••";
    NSString *last4 = [rawString substringFromIndex:MAX(0, rawString.length - 4)];
    return [NSString stringWithFormat:@"•••• %@", last4];
}

#pragma mark - Display

- (NSString *)displaySummary {
    NSString *maskedDetails = PPInstrumentStringFromValue(self.maskedDetails);
    if (maskedDetails.length > 0) return maskedDetails;
    NSDictionary *metadata = [self.metaData isKindOfClass:NSDictionary.class] ? self.metaData : @{};
    NSString *maskedCard = PPInstrumentStringFromValue(metadata[@"maskedCard"]);
    if (maskedCard.length > 0) return maskedCard;
    return kLang(@"Unknown Payment Method");
}

-(id)formValue
{
    return self;
}

- (NSString *)detectCardIssuerFromNumber:(NSString *)cardNumber {
    if ([cardNumber hasPrefix:@"4"]) return @"Visa";
    if ([cardNumber hasPrefix:@"5"]) return @"MasterCard";
    if ([cardNumber hasPrefix:@"34"] || [cardNumber hasPrefix:@"37"]) return @"American Express";
    if ([cardNumber hasPrefix:@"6"]) return @"Discover";
    return kLang(@"Unknown");
}



-(NSString *)formDisplayText
{
    return self.displaySummary;
}
@end
