//
//  CitiesManager 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 29/10/2025.
//


// CitiesManager.m
#import "CitiesManager.h"
#import "CountryModel.h"
#import "GM.h"

@interface CitiesManager ()
@property (nonatomic, strong) NSArray<CountryModel *> *countries;
@end

@implementation CitiesManager

+ (instancetype)shared {
    static CitiesManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[CitiesManager alloc] init];
        [sharedInstance loadData];
    });
    return sharedInstance;
}

- (void)loadData {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"cities" ofType:@"json"];
    if (!path) {
        NSLog(@"❌ [CitiesManager] cities.json not found in bundle!");
        self.countries = @[];
        return;
    }

    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        NSLog(@"❌ [CitiesManager] Failed to load data from path: %@", path);
        self.countries = @[];
        return;
    }

    NSError *error = nil;
    NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (error || ![jsonArray isKindOfClass:[NSArray class]]) {
        NSLog(@"❌ [CitiesManager] JSON parse error: %@", error);
        self.countries = @[];
        return;
    }

    NSMutableArray *countriesArray = [NSMutableArray array];
     for (NSDictionary *countryDict in jsonArray) {
        CountryModel *country = [CountryModel new];
        country.countryID = [countryDict[@"id"] integerValue];
        country.iso = countryDict[@"iso"];
        country.countryCode = countryDict[@"countryCode"];
        country.enName = countryDict[@"en"];
        country.arName = countryDict[@"ar"];
        country.defaultCountry = [countryDict[@"default"] boolValue];
        country.defualtCityID = [countryDict[@"defualtCityID"] integerValue];

         
        NSMutableArray *cities = [NSMutableArray array];
        for (NSDictionary *cityDict in countryDict[@"cities"]) {
            CityModel *city = [CityModel new];
            city.cityID = [cityDict[@"id"] integerValue];
            city.enName = cityDict[@"en"];
            city.arName = cityDict[@"ar"];
            city.latitude = [cityDict[@"lat"] doubleValue];
            city.longitude = [cityDict[@"lng"] doubleValue];
            city.country = country;

            NSMutableArray *states = [NSMutableArray array];
            for (NSDictionary *stateDict in cityDict[@"states"]) {
                StateModel *state = [StateModel new];
                state.stateID = [stateDict[@"id"] integerValue];
                state.enName = stateDict[@"en"];
                state.arName = stateDict[@"ar"];
                [states addObject:state];
            }
            city.states = states;
            [cities addObject:city];
        }
        country.cities = cities;
        [countriesArray addObject:country];
    }
    self.countries = countriesArray;
}


- (NSArray<CityModel *> *)citiesForCountryCode:(NSString *)isoCode {
    NSString *normalizedISO = [[isoCode ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if (normalizedISO.length == 0) {
        return @[];
    }
    for (CountryModel *country in self.countries) {
        if ([country.iso.uppercaseString isEqualToString:normalizedISO]) {
            return country.cities;
        }
    }
    return @[];
}

// Returns the default city for the specified country, or the first city as fallback.
- (CityModel *)defaultCityForCountry:(CountryModel *)country
{
    if (!country) {
        return nil;
    }

    // Use defualtCityID from CountryModel (intentional spelling)
    if (country.defualtCityID > 0) {
        CityModel *city = [self cityByID:country.defualtCityID];
        if (city) {
            return city;
        }
    }

    // Fallback: first city in country
    return country.cities.firstObject;
}

-(CountryModel *)CurrentCountry
{
    NSArray<NSString *> *candidateISOCodes = @[
        [GM getCurrentCountryFromCarrier] ?: @"",
        [[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode] description] ?: @"",
    ];

    for (NSString *candidateISO in candidateISOCodes) {
        CountryModel *country = [self countryWithCode:candidateISO];
        if (country) {
            return country;
        }
    }

    return [self qatarCountry];
}
- (NSArray<CityModel *> *)citiesForCurrentCountry {
    CountryModel *country = [self CurrentCountry] ?: [self qatarCountry];
    if (country.cities.count > 0) {
        return country.cities;
    }
    return [self qatarCountry].cities ?: @[];
}

- (CityModel *)cityByID:(NSInteger)cityID {
    for (CountryModel *country in self.countries) {
        for (CityModel *city in country.cities) {
            if (city.cityID == cityID) {
                return city;
            }
        }
    }
    return nil;
}

- (StateModel *)stateByID:(NSInteger)stateID {
    for (CountryModel *country in self.countries) {
        for (CityModel *city in country.cities) {
            for (StateModel *state in city.states) {
                if (state.stateID == stateID) {
                    return state;
                }
            }
        }
    }
    return nil;
}

- (CountryModel *)countryByID:(NSInteger)countryID {
    for (CountryModel *country in self.countries) {
        if (country.countryID == countryID) {
            return country;
        }
    }
    return nil;
}

- (CountryModel *)countryWithCode:(NSString *)isoCode
{
    if (![isoCode isKindOfClass:NSString.class] || isoCode.length == 0) {
        return nil;
    }

    NSString *normalized = isoCode.uppercaseString;

    for (CountryModel *country in self.countries) {
        if ([country.iso.uppercaseString isEqualToString:normalized]) {
            return country;
        }
    }

    return nil;
}

- (CountryModel *)countryWithDialCode:(NSString *)dialCode
{
    if (![dialCode isKindOfClass:NSString.class] || dialCode.length == 0) {
        return nil;
    }

    NSString *normalized = [[dialCode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (normalized.length == 0) {
        return nil;
    }
    if (![normalized hasPrefix:@"+"]) {
        normalized = [@"+" stringByAppendingString:normalized];
    }

    for (CountryModel *country in self.countries) {
        NSString *candidate = [[country.countryCode ?: @""
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
            stringByReplacingOccurrencesOfString:@" " withString:@""];
        if (candidate.length == 0) {
            continue;
        }
        if (![candidate hasPrefix:@"+"]) {
            candidate = [@"+" stringByAppendingString:candidate];
        }
        if ([candidate isEqualToString:normalized]) {
            return country;
        }
    }

    return nil;
}

- (CountryModel *)qatarCountry
{
    CountryModel *qatar = [self countryWithCode:@"QA"];
    if (qatar) {
        return qatar;
    }
    return self.countries.firstObject;
}

- (NSString *)cityNameForID:(NSInteger)cityID {
    CityModel *city = [self cityByID:cityID];
    return city ? [LocalizationHelper localizedNameWithEnglish:city.enName arabic:city.arName] : @"";
}

- (NSString *)stateNameForID:(NSInteger)stateID {
    StateModel *state = [self stateByID:stateID];
    return state ? [LocalizationHelper localizedNameWithEnglish:state.enName arabic:state.arName] : @"";
}

- (NSString *)countryNameForID:(NSInteger)countryID {
    CountryModel *country = [self countryByID:countryID];
    return country ? [LocalizationHelper localizedNameWithEnglish:country.enName arabic:country.arName] : @"";
}

@end


@implementation LocalizationHelper

+ (NSString *)localizedNameWithEnglish:(NSString *)enName arabic:(NSString *)arName {
    return [self isArabicLanguage] ? arName : enName;
}

+ (BOOL)isArabicLanguage {
    NSString *lang = [[NSLocale preferredLanguages].firstObject substringToIndex:2];
    return [lang isEqualToString:@"ar"];
}

@end
