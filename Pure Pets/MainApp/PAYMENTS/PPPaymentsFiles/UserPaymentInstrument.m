#import "UserPaymentInstrument.h"
#import <FirebaseFirestore/FirebaseFirestore.h>
 
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
        _userID = dict[@"userID"];
        _methodID = dict[@"methodID"];
        _createdAt = PPInstrumentDateFromValue(dict[@"createdAt"]) ?: [NSDate date];
        _updatedAt = PPInstrumentDateFromValue(dict[@"updatedAt"]) ?: [NSDate date];
        _isDefault = [dict[@"isDefault"] boolValue];
        _originalData = [dict[@"originalData"] isKindOfClass:NSDictionary.class] ? dict[@"originalData"] : @{};
        NSDictionary *meta = [dict[@"metaData"] isKindOfClass:NSDictionary.class] ? dict[@"metaData"] : nil;
        if (!meta && [dict[@"metadata"] isKindOfClass:NSDictionary.class]) {
            // Backward compatibility for legacy key typo.
            meta = dict[@"metadata"];
        }
        _metaData = meta ?: @{};
        _maskedDetails = dict[@"maskedDetails"];

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
    if (self.maskedDetails.length > 0)
        return self.maskedDetails;
    if (self.metaData[@"maskedCard"])
        return self.metaData[@"maskedCard"];
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
