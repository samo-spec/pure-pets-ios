//
//  CitiesManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 29/10/2025.
//



// CitiesManager.h
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
@class CityModel, CountryModel, StateModel;

@interface CitiesManager : NSObject

@property (nonatomic, strong, readonly) NSArray<CountryModel *> *countries;

+ (instancetype)shared;

- (NSArray<CityModel *> *)citiesForCountryCode:(NSString *)isoCode;
- (NSArray<CityModel *> *)citiesForCurrentCountry;
- (CountryModel *)CurrentCountry;
- (CountryModel *)qatarCountry;
- (CityModel *)cityByID:(NSInteger)cityID;
- (StateModel *)stateByID:(NSInteger)stateID;
- (CountryModel *)countryByID:(NSInteger)countryID;
- (CountryModel *)countryWithCode:(NSString *)isoCode;
- (CountryModel *)countryWithDialCode:(NSString *)dialCode;
- (NSString *)cityNameForID:(NSInteger)cityID;
- (NSString *)stateNameForID:(NSInteger)stateID;
- (NSString *)countryNameForID:(NSInteger)countryID;
- (CityModel *)defaultCityForCountry:(CountryModel *)country;
@end

// LocalizationHelper.h
#import <Foundation/Foundation.h>

@interface LocalizationHelper : NSObject

+ (NSString *)localizedNameWithEnglish:(NSString *)enName arabic:(NSString *)arName;
+ (BOOL)isArabicLanguage;

@end
