#import "CountryCodeModel.h"

@implementation CountryCodeModel

- (id)formValue {
    return self;
}

- (NSString *)formDisplayText {
    return self.country;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.ID = 0;
        self.country = @"";
        self.phoneCode = @"";
        self.isoCountryCode = @"";
    }
    return self;
}

#pragma mark - Auto flag generator
// Converts "EG" into 🇪🇬
// Converts "US" into 🇺🇸
- (NSString *)flag
{
    if (self.isoCountryCode.length != 2) {
        return @"";
    }

    NSString *upper = [self.isoCountryCode uppercaseString];

    // Regional Indicator Symbol Letter A code point
    uint32_t base = 0x1F1E6;

    // Helper block to convert a code point to a UTF-16 pair (surrogates)
    unichar (^surrogateHigh)(uint32_t) = ^unichar(uint32_t cp) {
        return (unichar)(0xD800 + ((cp - 0x10000) >> 10));
    };
    unichar (^surrogateLow)(uint32_t) = ^unichar(uint32_t cp) {
        return (unichar)(0xDC00 + ((cp - 0x10000) & 0x3FF));
    };

    // Compute the two regional indicator code points
    unichar a = 'A';
    uint32_t cp1 = base + ((uint32_t)[upper characterAtIndex:0] - (uint32_t)a);
    uint32_t cp2 = base + ((uint32_t)[upper characterAtIndex:1] - (uint32_t)a);

    // Each regional indicator is outside BMP, so represent each as a surrogate pair
    unichar buffer[4];
    buffer[0] = surrogateHigh(cp1);
    buffer[1] = surrogateLow(cp1);
    buffer[2] = surrogateHigh(cp2);
    buffer[3] = surrogateLow(cp2);

    return [NSString stringWithCharacters:buffer length:4];
}

#pragma mark - Serializer

- (NSDictionary *)serialized {
    return @{
        @"ID": [NSString stringWithFormat:@"%ld", self.ID],
        @"country": self.country ?: @"",
        @"phoneCode": self.phoneCode ?: @"",
        @"isoCountryCode": self.isoCountryCode ?: @"",
        // no need to store flag; it generates automatically
    };
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt64:(NSInteger)self.ID forKey:@"ID"];
    [coder encodeObject:self.country forKey:@"country"];
    [coder encodeObject:self.phoneCode forKey:@"phoneCode"];
    [coder encodeObject:self.isoCountryCode forKey:@"isoCountryCode"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.ID = [coder decodeInt64ForKey:@"ID"];
        self.country = [coder decodeObjectForKey:@"country"];
        self.phoneCode = [coder decodeObjectForKey:@"phoneCode"];
        self.isoCountryCode = [coder decodeObjectForKey:@"isoCountryCode"];
    }
    return self;
}

@end
