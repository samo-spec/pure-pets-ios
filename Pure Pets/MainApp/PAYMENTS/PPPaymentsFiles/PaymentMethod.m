//
//  PaymentMethod.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/11/2025.
//


//
//  PaymentMethod.m
//  PurePets
//

#import "PaymentMethod.h"

@implementation PaymentMethod

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.methodID forKey:@"methodID"];
    [coder encodeObject:self.displayName forKey:@"displayName"];
    [coder encodeObject:self.iconName forKey:@"iconName"];
    [coder encodeObject:self.methodDescription forKey:@"methodDescription"];
    [coder encodeInteger:self.type forKey:@"type"];
    [coder encodeBool:self.supportsMultipleAccounts forKey:@"supportsMultipleAccounts"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        _methodID = [coder decodeObjectOfClass:[NSString class] forKey:@"methodID"];
        _displayName = [coder decodeObjectOfClass:[NSString class] forKey:@"displayName"];
        _iconName = [coder decodeObjectOfClass:[NSString class] forKey:@"iconName"];
        _methodDescription = [coder decodeObjectOfClass:[NSString class] forKey:@"methodDescription"];
        _type = [coder decodeIntegerForKey:@"type"];
        _supportsMultipleAccounts = [coder decodeBoolForKey:@"supportsMultipleAccounts"];
    }
    return self;
}

#pragma mark - Static Data

+ (NSArray<PaymentMethod *> *)defaultMethods {
    NSArray *raw = @[
        @{@"id": @"qib",        @"name": @"Credit / Debit Card",  @"icon": @"master",    @"desc": kLang(@"payment_qib_gateway_desc"),    @"type": @(PaymentMethodTypeQIB)},
        @{@"id": @"applepay",   @"name": @"Apple Pay",            @"icon": @"applepay",  @"desc": kLang(@"payment_applepay_desc"),        @"type": @(PaymentMethodTypeApplePay)},
        @{@"id": @"ooredoo",    @"name": @"Ooredoo Money",        @"icon": @"ooredoo",   @"desc": kLang(@"payment_ooredoo_desc"),         @"type": @(PaymentMethodTypeOoredoo)},
        @{@"id": @"naps",       @"name": @"NAPS Debit",           @"icon": @"naps",      @"desc": kLang(@"payment_naps_desc"),            @"type": @(PaymentMethodTypeQNB)},
        @{@"id": @"cash",       @"name": @"Cash on Delivery",     @"icon": @"cash2",     @"desc": kLang(@"payment_cash_delivery_desc"),   @"type": @(PaymentMethodTypeCash)}
    ];
    
    NSMutableArray *methods = [NSMutableArray array];
    for (NSDictionary *d in raw) {
        PaymentMethod *m = [[PaymentMethod alloc] init];
        m.methodID = d[@"id"];
        m.displayName = d[@"name"];
        m.iconName = d[@"icon"];
        m.methodDescription = d[@"desc"];
        m.type = [d[@"type"] integerValue];
        m.supportsMultipleAccounts = (m.type == PaymentMethodTypeCard ||
                                      m.type == PaymentMethodTypeQNB  ||
                                      m.type == PaymentMethodTypeQIB);
        [methods addObject:m];
    }
    return methods;
}

+ (nullable PaymentMethod *)methodForID:(NSString *)methodID {
    NSString *normalized = [[methodID ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].lowercaseString copy];
    if ([normalized isEqualToString:@"card"]) {
        normalized = @"qib";
    }
    for (PaymentMethod *m in [self defaultMethods]) {
        if ([m.methodID isEqualToString:normalized]) return m;
    }
    return nil;
}

@end
