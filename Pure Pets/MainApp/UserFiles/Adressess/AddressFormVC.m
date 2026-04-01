//
//  AddressFormVC 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/10/2025.
//


#import "AddressFormVC.h"
#import "CountryModel.h"
#import "GM.h"
@import FirebaseAuth;
@import CoreLocation;
#import <math.h>
#import <float.h>

@interface AddressFormVC () <CLLocationManagerDelegate>
// (Optional: Add private properties or methods if needed)
@property NSArray<CountryModel*> *countriesArray;
@property NSArray<CityModel*> *citiesArray ;
@property NSArray<StateModel*> *statesArray ;
@property CountryModel *selectedCountry;
@property StateModel *selectedState ;
@property CityModel *selectedCity;
@property NSString *selectedLocationName;
@property NSString *selectedLocationPoints;
@property XLFormRowDescriptor *countryRow;
@property XLFormRowDescriptor *stateRow;
@property XLFormRowDescriptor *cityRow;
@property (nonatomic, assign) BOOL isSaving;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLGeocoder *reverseGeocoder;
@property (nonatomic, assign) CLLocationCoordinate2D currentDeviceCoordinate;
@property (nonatomic, assign) BOOL didApplyInitialLocation;
@property (nonatomic, strong) CountryModel *resolvedCountry;
@property (nonatomic, strong) UIView *formHeaderView;
@end

@implementation AddressFormVC

#pragma mark - Initialization

- (instancetype)initWithAddress:(PPAddressModel *)address {
    self = [super init];
    if (self) {
        _address = address;
        
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.currentDeviceCoordinate = kCLLocationCoordinate2DInvalid;
    self.reverseGeocoder = [[CLGeocoder alloc] init];
    self.countriesArray = CitiesManager.shared.countries ?: @[];
    self.resolvedCountry = [self pp_resolvedCountryForFormLoad];
    self.selectedCountry = self.resolvedCountry;
    _citiesArray = [self pp_citiesForCountryOrQatar:self.resolvedCountry];
    NSLog(@"_citiesArray %@",[_citiesArray valueForKey:@"enName"]);
    if (!self.title) {
        self.title = (_address ? kLang(@"EditAddress") : kLang(@"AddAddress"));
    }
    [self setForm];
    [self pp_applyModernAppearance];
    if (!self.address) {
        [self pp_applyResolvedCountryDefaultsIfNeeded];
        [self pp_startPrefillFromCurrentLocationIfNeeded];
    }
}

-(void)didSelectFormRow:(XLFormRowDescriptor *)formRow
{
    NSString *rawTag = [formRow.tagM isKindOfClass:NSString.class] ? formRow.tagM : @"";
    NSString *tag = [rawTag stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([tag isEqualToString:@"location"]) {
        [self pp_openLocationPickerForRow:formRow];
        return;
    }
    [super didSelectFormRow:formRow];
}

- (void)pp_openLocationPickerForRow:(XLFormRowDescriptor *)sender
{
    if (!sender) {
        return;
    }
    NSIndexPath *indexPath = [self.form indexPathOfFormRow:sender];
    if (indexPath) {
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    }

    LocationPickerViewController *pickerVC = [[LocationPickerViewController alloc] init];
    CLLocationCoordinate2D initialCoordinate = kCLLocationCoordinate2DInvalid;
    if (self.selectedLocationPoints.length > 0) {
        NSArray<NSString *> *parts = [self.selectedLocationPoints componentsSeparatedByString:@","];
        if (parts.count >= 2) {
            double lat = [parts[0] doubleValue];
            double lng = [parts[1] doubleValue];
            CLLocationCoordinate2D parsed = CLLocationCoordinate2DMake(lat, lng);
            if ([self pp_isValidCoordinate:parsed]) {
                initialCoordinate = parsed;
            }
        }
    }
    if (![self pp_isValidCoordinate:initialCoordinate] &&
        [self pp_isValidCoordinate:self.currentDeviceCoordinate]) {
        initialCoordinate = self.currentDeviceCoordinate;
    }
    if ([self pp_isValidCoordinate:initialCoordinate]) {
        pickerVC.initialCoordinate = initialCoordinate;
    }

    __weak typeof(self) weakSelf = self;
    pickerVC.onLocationConfirmed = ^(GMSAddress *gmsAddress) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !gmsAddress) {
            return;
        }
        CLLocationCoordinate2D coord = gmsAddress.coordinate;
        NSString *resolvedTitle = [self titleFromAddress:gmsAddress];
        [self pp_applyCoordinateToForm:coord suggestedTitle:resolvedTitle];
        [self pp_reverseGeocodeCoordinateForRowTitle:coord];
    };
    pickerVC.onCoordinateConfirmed = ^(CLLocationCoordinate2D coordinate, NSString *locationTitle) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        [self pp_applyCoordinateToForm:coordinate suggestedTitle:locationTitle];
        [self pp_reverseGeocodeCoordinateForRowTitle:coordinate];
    };

    if (self.navigationController) {
        [self.navigationController pushViewController:pickerVC animated:YES];
    } else {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:pickerVC];
        [self presentViewController:nav animated:YES completion:nil];
    }
}


- (NSString *)titleFromAddress:(GMSAddress *)address {
    if (!address) return @"";
    
    NSString *primary = address.subLocality ?: address.locality ?: address.thoroughfare ?: @"";
    NSString *secondary = address.locality ?: address.administrativeArea ?: address.country ?: @"";
    
    // Avoid repeating if same
    if ([primary isEqualToString:secondary]) secondary = @"";
    
    if (primary.length && secondary.length)
        return [NSString stringWithFormat:@"%@, %@", primary, secondary];
    else
        return primary.length ? primary : secondary;
}

- (BOOL)pp_isValidCoordinate:(CLLocationCoordinate2D)coordinate
{
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return NO;
    }
    return !(fabs(coordinate.latitude) < 0.000001 && fabs(coordinate.longitude) < 0.000001);
}

- (NSString *)pp_titleFromPlacemark:(CLPlacemark *)placemark
{
    if (!placemark) {
        return @"";
    }
    NSString *primary = placemark.subLocality ?: placemark.locality ?: placemark.thoroughfare ?: @"";
    NSString *secondary = placemark.locality ?: placemark.administrativeArea ?: placemark.country ?: @"";
    if ([primary isEqualToString:secondary]) {
        secondary = @"";
    }
    if (primary.length > 0 && secondary.length > 0) {
        return [NSString stringWithFormat:@"%@, %@", primary, secondary];
    }
    return primary.length > 0 ? primary : secondary;
}

- (NSString *)pp_trimmedString:(id)value
{
    if (![value isKindOfClass:[NSString class]]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (CountryModel *)pp_qatarCountry
{
    return [CitiesManager.shared qatarCountry];
}

- (NSArray<CountryModel *> *)pp_availableCountries
{
    NSArray<CountryModel *> *countries = self.countriesArray ?: CitiesManager.shared.countries;
    if (countries.count > 0) {
        return countries;
    }
    CountryModel *fallback = [self pp_qatarCountry];
    return fallback ? @[fallback] : @[];
}

- (NSString *)pp_localizedCountryName:(CountryModel *)country
{
    if (![country isKindOfClass:[CountryModel class]]) {
        return @"";
    }
    if (Language.isRTL && country.arName.length > 0) {
        return country.arName;
    }
    if (country.enName.length > 0) {
        return country.enName;
    }
    return country.name ?: @"";
}

- (NSArray<CityModel *> *)pp_citiesForCountryOrQatar:(CountryModel *)country
{
    NSArray<CityModel *> *cities = country.cities ?: @[];
    if (cities.count > 0) {
        return cities;
    }
    return [self pp_qatarCountry].cities ?: @[];
}

- (CountryModel *)pp_countryFromUserCountryID:(NSInteger)countryID
{
    if (countryID <= 0) {
        return nil;
    }

    NSArray<CountryCodeModel *> *countries = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.ID == %ld", countryID];
    CountryCodeModel *matchedCountry = [[countries filteredArrayUsingPredicate:predicate] firstObject];
    if (matchedCountry.isoCountryCode.length == 0) {
        return nil;
    }
    return [CitiesManager.shared countryWithCode:matchedCountry.isoCountryCode];
}

- (CountryModel *)pp_countryFromPhoneNumber:(NSString *)phoneNumber
{
    NSString *trimmedPhone = [self pp_trimmedString:phoneNumber];
    if (trimmedPhone.length == 0 || ![trimmedPhone hasPrefix:@"+"]) {
        return nil;
    }

    CountryModel *best = nil;
    NSUInteger bestLength = 0;
    for (CountryModel *country in CitiesManager.shared.countries ?: @[]) {
        NSString *dialCode = [self pp_trimmedString:country.countryCode];
        if (dialCode.length == 0) {
            continue;
        }
        if (![dialCode hasPrefix:@"+"]) {
            dialCode = [@"+" stringByAppendingString:dialCode];
        }
        if ([trimmedPhone hasPrefix:dialCode] && dialCode.length > bestLength) {
            best = country;
            bestLength = dialCode.length;
        }
    }
    return best;
}

- (CountryModel *)pp_resolvedCountryForFormLoad
{
    if (self.address.cityID > 0) {
        CityModel *addressCity = [CitiesManager.shared cityByID:self.address.cityID];
        if (addressCity.country) {
            return addressCity.country;
        }
    }

    CountryModel *country = [self pp_countryFromUserCountryID:PPCurrentUser.CountryID];
    if (!country) {
        country = [self pp_countryFromPhoneNumber:PPCurrentUser.MobileNo];
    }
    if (!country) {
        country = [self pp_countryFromPhoneNumber:[FIRAuth auth].currentUser.phoneNumber];
    }
    if (!country) {
        country = [CitiesManager.shared countryWithCode:[GM getCurrentCountryFromCarrier]];
    }
    if (!country) {
        country = [CitiesManager.shared countryWithCode:[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode]];
    }
    if (!country) {
        country = CitiesManager.shared.CurrentCountry;
    }
    return country ?: [self pp_qatarCountry];
}

- (void)pp_applyResolvedCountryDefaultsIfNeeded
{
    CountryModel *country = self.resolvedCountry ?: [self pp_qatarCountry];
    [self pp_applyCountry:country preferredCity:self.selectedCity preferredState:self.selectedState];
}

- (NSString *)pp_normalizedComparableName:(NSString *)value
{
    NSString *trimmed = [[self pp_trimmedString:value] lowercaseString];
    if (trimmed.length == 0) {
        return @"";
    }

    NSCharacterSet *stripSet = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    NSArray<NSString *> *parts = [trimmed componentsSeparatedByCharactersInSet:stripSet];
    return [[parts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]] componentsJoinedByString:@""];
}

- (CityModel *)pp_cityMatchingPlacemark:(CLPlacemark *)placemark inCities:(NSArray<CityModel *> *)cities
{
    NSArray<NSString *> *candidateNames = @[
        placemark.locality ?: @"",
        placemark.subAdministrativeArea ?: @"",
        placemark.administrativeArea ?: @"",
    ];

    for (NSString *candidateName in candidateNames) {
        NSString *normalizedCandidate = [self pp_normalizedComparableName:candidateName];
        if (normalizedCandidate.length == 0) {
            continue;
        }

        for (CityModel *city in cities ?: @[]) {
            NSArray<NSString *> *cityNames = @[city.enName ?: @"", city.arName ?: @""];
            for (NSString *cityName in cityNames) {
                NSString *normalizedCity = [self pp_normalizedComparableName:cityName];
                if (normalizedCity.length == 0) {
                    continue;
                }
                if ([normalizedCandidate isEqualToString:normalizedCity] ||
                    [normalizedCandidate containsString:normalizedCity] ||
                    [normalizedCity containsString:normalizedCandidate]) {
                    return city;
                }
            }
        }
    }

    return nil;
}

- (StateModel *)pp_stateMatchingPlacemark:(CLPlacemark *)placemark inStates:(NSArray<StateModel *> *)states
{
    NSArray<NSString *> *candidateNames = @[
        placemark.subLocality ?: @"",
        placemark.thoroughfare ?: @"",
        placemark.name ?: @"",
    ];

    for (NSString *candidateName in candidateNames) {
        NSString *normalizedCandidate = [self pp_normalizedComparableName:candidateName];
        if (normalizedCandidate.length == 0) {
            continue;
        }

        for (StateModel *state in states ?: @[]) {
            NSArray<NSString *> *stateNames = @[state.enName ?: @"", state.arName ?: @""];
            for (NSString *stateName in stateNames) {
                NSString *normalizedState = [self pp_normalizedComparableName:stateName];
                if (normalizedState.length == 0) {
                    continue;
                }
                if ([normalizedCandidate isEqualToString:normalizedState] ||
                    [normalizedCandidate containsString:normalizedState] ||
                    [normalizedState containsString:normalizedCandidate]) {
                    return state;
                }
            }
        }
    }

    return nil;
}

- (CityModel *)pp_nearestCityForCoordinate:(CLLocationCoordinate2D)coordinate
{
    if (![self pp_isValidCoordinate:coordinate]) {
        return nil;
    }
    NSArray<CityModel *> *cities = self.citiesArray ?: @[];
    if (cities.count == 0) {
        cities = [self pp_citiesForCountryOrQatar:self.resolvedCountry];
    }
    if (cities.count == 0) {
        return nil;
    }

    CLLocation *target = [[CLLocation alloc] initWithLatitude:coordinate.latitude
                                                     longitude:coordinate.longitude];
    CityModel *nearestCity = nil;
    CLLocationDistance bestDistance = DBL_MAX;

    for (CityModel *city in cities) {
        CLLocationCoordinate2D cityCoordinate = CLLocationCoordinate2DMake(city.latitude, city.longitude);
        if (![self pp_isValidCoordinate:cityCoordinate]) {
            continue;
        }
        CLLocation *cityLocation = [[CLLocation alloc] initWithLatitude:cityCoordinate.latitude
                                                               longitude:cityCoordinate.longitude];
        CLLocationDistance distance = [target distanceFromLocation:cityLocation];
        if (distance < bestDistance) {
            bestDistance = distance;
            nearestCity = city;
        }
    }

    return nearestCity ?: cities.firstObject;
}

- (StateModel *)pp_defaultStateForCity:(CityModel *)city
{
    if (![city isKindOfClass:[CityModel class]]) {
        return nil;
    }
    NSArray<StateModel *> *states = city.states ?: @[];
    return states.firstObject;
}

- (void)pp_applyCountry:(CountryModel *)country
          preferredCity:(CityModel *)preferredCity
         preferredState:(StateModel *)preferredState
{
    CountryModel *resolvedCountry = [country isKindOfClass:[CountryModel class]] ? country : [self pp_qatarCountry];
    self.resolvedCountry = resolvedCountry;
    self.selectedCountry = resolvedCountry;

    self.countriesArray = [self pp_availableCountries];
    self.countryRow.selectorOptions = self.countriesArray;
    self.countryRow.value = resolvedCountry;
    [self updateFormRow:self.countryRow];

    self.citiesArray = [self pp_citiesForCountryOrQatar:resolvedCountry];
    self.cityRow.selectorOptions = self.citiesArray;

    CityModel *resolvedCity = preferredCity;
    if (![resolvedCity isKindOfClass:[CityModel class]] || ![self.citiesArray containsObject:resolvedCity]) {
        resolvedCity = [CitiesManager.shared defaultCityForCountry:resolvedCountry];
    }
    if (![resolvedCity isKindOfClass:[CityModel class]]) {
        resolvedCity = self.citiesArray.firstObject;
    }
    if (![resolvedCity isKindOfClass:[CityModel class]]) {
        self.selectedCity = nil;
        self.cityRow.value = nil;
        [self updateFormRow:self.cityRow];
        self.statesArray = @[];
        self.selectedState = nil;
        self.stateRow.selectorOptions = self.statesArray;
        self.stateRow.value = nil;
        [self updateFormRow:self.stateRow];
        return;
    }

    [self pp_applyCity:resolvedCity state:preferredState];
}

- (void)pp_applyCity:(CityModel *)city state:(StateModel *)state
{
    if (![city isKindOfClass:[CityModel class]]) {
        return;
    }

    self.resolvedCountry = city.country ?: self.resolvedCountry ?: [self pp_qatarCountry];
    self.selectedCountry = self.resolvedCountry;
    self.countriesArray = [self pp_availableCountries];
    self.countryRow.selectorOptions = self.countriesArray;
    self.countryRow.value = self.selectedCountry;
    [self updateFormRow:self.countryRow];
    self.selectedCity = city;
    self.citiesArray = [self pp_citiesForCountryOrQatar:self.resolvedCountry];
    self.cityRow.selectorOptions = self.citiesArray;
    self.cityRow.value = city;
    [self updateFormRow:self.cityRow];

    self.statesArray = city.states ?: @[];
    self.stateRow.selectorOptions = self.statesArray;

    StateModel *resolvedState = state;
    if (![resolvedState isKindOfClass:[StateModel class]] || ![self.statesArray containsObject:resolvedState]) {
        resolvedState = [self pp_defaultStateForCity:city];
    }
    self.selectedState = resolvedState;
    self.stateRow.value = resolvedState;
    [self updateFormRow:self.stateRow];
}

- (void)pp_applyCoordinateToForm:(CLLocationCoordinate2D)coordinate
                   suggestedTitle:(NSString *)suggestedTitle
{
    if (![self pp_isValidCoordinate:coordinate]) {
        return;
    }

    self.didApplyInitialLocation = YES;
    self.currentDeviceCoordinate = coordinate;
    self.selectedLocationPoints = [NSString stringWithFormat:@"%f, %f",
                                   coordinate.latitude, coordinate.longitude];
    self.selectedLocationName = suggestedTitle.length > 0
        ? suggestedTitle
        : [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];

    XLFormRowDescriptor *locationRow = [self.form formRowWithTag:@"location"];
    if (locationRow) {
        locationRow.value = self.selectedLocationName;
        [self updateFormRow:locationRow];
    }

    CityModel *nearestCity = [self pp_nearestCityForCoordinate:coordinate];
    if (nearestCity) {
        [self pp_applyCity:nearestCity state:[self pp_defaultStateForCity:nearestCity]];
    }
}

- (void)pp_reverseGeocodeCoordinateForRowTitle:(CLLocationCoordinate2D)coordinate
{
    if (![self pp_isValidCoordinate:coordinate]) {
        return;
    }
    if (!self.reverseGeocoder) {
        self.reverseGeocoder = [[CLGeocoder alloc] init];
    }
    if (self.reverseGeocoder.isGeocoding) {
        [self.reverseGeocoder cancelGeocode];
    }

    CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude
                                                      longitude:coordinate.longitude];
    __weak typeof(self) weakSelf = self;
    [self.reverseGeocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        if (error || placemarks.count == 0) {
            return;
        }
        CLPlacemark *placemark = placemarks.firstObject;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            CountryModel *placemarkCountry = [CitiesManager.shared countryWithCode:placemark.ISOcountryCode];
            if (!placemarkCountry) {
                placemarkCountry = self.resolvedCountry ?: [self pp_qatarCountry];
            }
            self.resolvedCountry = placemarkCountry ?: [self pp_qatarCountry];
            self.selectedCountry = self.resolvedCountry;
            self.citiesArray = [self pp_citiesForCountryOrQatar:self.resolvedCountry];
            self.countryRow.selectorOptions = [self pp_availableCountries];
            self.countryRow.value = self.selectedCountry;
            self.cityRow.selectorOptions = self.citiesArray;

            CityModel *matchedCity = [self pp_cityMatchingPlacemark:placemark inCities:self.citiesArray];
            if (!matchedCity) {
                matchedCity = [self pp_nearestCityForCoordinate:coordinate];
            }
            if (matchedCity) {
                StateModel *matchedState = [self pp_stateMatchingPlacemark:placemark inStates:matchedCity.states];
                [self pp_applyCity:matchedCity state:matchedState];
            }

            NSString *resolvedTitle = [self pp_titleFromPlacemark:placemark];
            if (resolvedTitle.length == 0 && matchedCity) {
                resolvedTitle = Language.isRTL ? matchedCity.arName : matchedCity.enName;
            }
            if (resolvedTitle.length == 0 && self.resolvedCountry) {
                resolvedTitle = self.resolvedCountry.name;
            }
            if (resolvedTitle.length == 0) {
                resolvedTitle = self.selectedLocationName;
            }
            if (resolvedTitle.length == 0) {
                return;
            }
            self.selectedLocationName = resolvedTitle;
            XLFormRowDescriptor *locationRow = [self.form formRowWithTag:@"location"];
            if (locationRow) {
                locationRow.value = resolvedTitle;
                [self updateFormRow:locationRow];
            }
        });
    }];
}

- (void)pp_startPrefillFromCurrentLocationIfNeeded
{
    if (self.address || self.didApplyInitialLocation) {
        return;
    }

    if (!self.locationManager) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    }

    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = self.locationManager.authorizationStatus;
    } else {
        status = [CLLocationManager authorizationStatus];
    }

    if (status == kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestWhenInUseAuthorization];
        return;
    }
    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        [self pp_applyResolvedCountryDefaultsIfNeeded];
        return;
    }

    CLLocation *cachedLocation = self.locationManager.location;
    if (cachedLocation && [self pp_isValidCoordinate:cachedLocation.coordinate]) {
        [self pp_applyCoordinateToForm:cachedLocation.coordinate suggestedTitle:nil];
        [self pp_reverseGeocodeCoordinateForRowTitle:cachedLocation.coordinate];
        return;
    }

    [self.locationManager startUpdatingLocation];
}

- (NSString *)pp_formSubtitleText
{
    if (self.address) {
        return kLang(@"AddressFormEditSubtitle") ?: @"Update your delivery details and location.";
    }
    return kLang(@"AddressFormAddSubtitle") ?: @"Add a delivery address with country, city, area, and map pin.";
}

- (UIView *)pp_buildHeaderView
{
    UIButton *container =
        [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleLarge
                                                         configType:PPButtonConfigrationGlass];
    container.userInteractionEnabled = NO;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.layer.cornerRadius = 28.0;

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"mappin.and.ellipse"]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = AppPrimaryClr;
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:22] ?: [UIFont boldSystemFontOfSize:22];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.text = self.title ?: kLang(@"AddAddress");

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:14] ?: [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.text = [self pp_formSubtitleText];

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 6.0;
    textStack.alignment = UIStackViewAlignmentFill;

    [container addSubview:iconView];
    [container addSubview:textStack];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20.0],
        [iconView.topAnchor constraintEqualToAnchor:container.topAnchor constant:20.0],
        [iconView.widthAnchor constraintEqualToConstant:28.0],
        [iconView.heightAnchor constraintEqualToConstant:28.0],

        [textStack.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:14.0],
        [textStack.topAnchor constraintEqualToAnchor:container.topAnchor constant:18.0],
        [textStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20.0],
        [textStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-18.0],
    ]];

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), 124.0)];
    header.backgroundColor = UIColor.clearColor;
    [header addSubview:container];
    [NSLayoutConstraint activateConstraints:@[
        [container.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16.0],
        [container.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16.0],
        [container.topAnchor constraintEqualToAnchor:header.topAnchor constant:8.0],
        [container.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-12.0],
    ]];

    return header;
}

- (void)pp_applyModernAppearance
{
    self.view.backgroundColor = PPBackgroundColorForIOS26([AppBackgroundClr colorWithAlphaComponent:1.0]);
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.contentInset = UIEdgeInsetsMake(4.0, 0.0, 24.0, 0.0);
    self.tableView.sectionFooterHeight = 12.0;
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 10.0;
    }

    self.formHeaderView = [self pp_buildHeaderView];
    self.tableView.tableHeaderView = self.formHeaderView;
}


#pragma mark - Actions

/// Invoked when the Save button is tapped. Validates and saves the address.
- (void)saveButtonPressed:(id)sender {
    if (self.isSaving) {
        return;
    }
    // End editing to ensure all fields are updated
    [self.view endEditing:YES];
    
    // Trim whitespace in required fields to avoid accepting only-space input
    NSArray<NSString *> *requiredTags = @[@"fullName", @"addressLine1", @"postalCode"];
    for (NSString *tag in requiredTags) {
        XLFormRowDescriptor *row = [self.form formRowWithTag:tag];
        if ([row.value isKindOfClass:[NSString class]]) {
            NSString *trimmed = [(NSString *)row.value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmed.length == 0) {
                row.value = nil; // mark as empty to trigger validation
            } else {
                row.value = trimmed;
            }
        }
    }
    
    
    // Validate the form
    NSArray *errors = [self formValidationErrors];
    if (errors.count > 0) {
        for (NSError *error in errors) {
            NSLog(@"Validation error: %@", error.localizedDescription);
        }
        
        [errors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            XLFormValidationStatus *validationStatus = [[obj userInfo] objectForKey:XLValidationStatusErrorKey];
            XLFormBaseCell *cell = [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:validationStatus.rowDescriptor]];
            [self animateCell:cell];
            
        }];
        
        [PPHUD showInfo:kLang(@"PleaseFillFields")];
        return;
    }
    
    if ([self.form formRowWithTag:@"country"].value && [self.form formRowWithTag:@"country"].value != [NSNull null]) {
        self.selectedCountry = (CountryModel *)[self.form formRowWithTag:@"country"].value;
    }
    if ([self.form formRowWithTag:@"city"].value && [self.form formRowWithTag:@"city"].value != [NSNull null]) {
        self.selectedCity = (CityModel *)[self.form formRowWithTag:@"city"].value;
    }
    if ([self.form formRowWithTag:@"state"].value && [self.form formRowWithTag:@"state"].value != [NSNull null]) {
        self.selectedState = (StateModel *)[self.form formRowWithTag:@"state"].value;
    }

    if (self.selectedCity.cityID <= 0 || self.selectedState.stateID <= 0) {
        [PPHUD showInfo:kLang(@"PleaseFillFields")];
        return;
    }
    
    [self pp_setSavingState:YES];
    [PPHUD showLoading:kLang(@"Saving")];
    
    
    // Validation passed, proceed to save the data
    PPAddressModel *addressToSave = self.address;
    BOOL isNewAddress = NO;
    if (!addressToSave) {
        addressToSave = [[PPAddressModel alloc] init];
        isNewAddress = YES;
    }
    // Get form values and update the PPAddressModel
    NSDictionary *formValues = [self.form formValues];
    addressToSave.fullName    = [[formValues[@"fullName"] ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    NSString *trimmedPhone = [[formValues[@"phoneNumber"] ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    NSString *fallbackPhone = (PPCurrentUser.MobileNo.length > 0)
        ? PPCurrentUser.MobileNo
        : ([FIRAuth auth].currentUser.phoneNumber ?: @"");
    addressToSave.phoneNumber = trimmedPhone.length > 0 ? trimmedPhone : fallbackPhone;
    addressToSave.addressLine1 = [[formValues[@"addressLine1"] ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    // Handle optional Address Line 2
    if (formValues[@"addressLine2"] == nil || [formValues[@"addressLine2"] isKindOfClass:[NSNull class]]) {
        addressToSave.addressLine2 = nil;
    } else {
        NSString *addr2Trimmed = [formValues[@"addressLine2"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        addressToSave.addressLine2 = addr2Trimmed.length > 0 ? [addr2Trimmed copy] : nil;
    }
    
    if (self.selectedCity) {
        addressToSave.cityID =  self.selectedCity.cityID;
        NSLog(@"Saving address: cityID: %ld", self.selectedCity.cityID);
    }
    
    if (self.selectedState) {
        addressToSave.stateID = self.selectedState.stateID;
        NSLog(@"Saving address: stateID: %ld", self.selectedState.stateID);
    }
    
    addressToSave.locatioName = self.selectedLocationName;
    addressToSave.locationPoints = self.selectedLocationPoints;
    
    addressToSave.postalCode  = [[formValues[@"postalCode"] ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    addressToSave.isDefault   = [formValues[@"isDefault"] boolValue];
    NSString *currentUID = [PPAddressesManager.sharedManager currentAuthenticatedUserID];
    if (currentUID.length > 0) {
        addressToSave.userID = currentUID;
    }
    
    __weak typeof(self) weakSelf = self;
    void (^handleResult)(PPAddressModel * _Nullable, NSError * _Nullable) =
    ^(PPAddressModel * _Nullable savedAddress, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self pp_setSavingState:NO];
            [PPHUD dismiss];

            if (error || !savedAddress) {
                [PPAlertHelper showErrorIn:self
                                     title:kLang(@"StatusSaveFailed")
                                  subtitle:error.localizedDescription ?: kLang(@"SomethingWentWrong")];
                return;
            }

            if ([self.delegate respondsToSelector:@selector(addressFormVC:didSaveAddress:)]) {
                [self.delegate addressFormVC:self didSaveAddress:savedAddress];
            }
            [PPHUD showSuccess:kLang(@"Saved")];
            if (self.addressFormPresent == AddressFormPresentSheet) {
                [self.navigationController dismissViewControllerAnimated:YES completion:nil];
            } else {
                [self.navigationController popViewControllerAnimated:YES];
            }
        });
    };

    if (isNewAddress) {
        [[PPAddressesManager sharedManager] addAddress:addressToSave completion:handleResult];
    } else {
        [[PPAddressesManager sharedManager] updateAddress:addressToSave completion:handleResult];
    }
}


#pragma mark - Helper

- (void)animateCell:(UITableViewCell *)cell
{
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
    
    animation.keyPath = @"position.x";
    animation.values =  @[ @0, @20, @-20, @10, @0];
    animation.keyTimes = @[@0, @(1 / 6.0), @(3 / 6.0), @(5 / 6.0), @1];
    animation.duration = 0.3;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    animation.additive = YES;
    
    [cell.layer addAnimation:animation forKey:@"shake"];
}

- (void)pp_setSavingState:(BOOL)isSaving
{
    self.isSaving = isSaving;
    self.navigationItem.rightBarButtonItem.enabled = !isSaving;
    self.navigationItem.leftBarButtonItem.enabled = !isSaving;
    self.view.userInteractionEnabled = !isSaving;
}



NSString * stringFromInteger(NSInteger vlaue)
{
    NSString *str = PPSafeString([NSString stringWithFormat:@"%ld",vlaue]);
    return str;
}

- (void)integerFromString:(NSString *)str
{
    
}
/// Presents a confirmation alert and deletes the address if confirmed (for edit mode).
- (void)showDeleteConfirmation {
    if (!self.address || self.address.documentID.length == 0) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"DeleteAddress")
                                                                   message:kLang(@"DeleteConfirmMessage")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    // Cancel action
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:kLang(@"Cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        NSLog(@"Delete canceled");
    }];
    // Delete action
    __weak typeof(self) weakSelf = self;
    UIAlertAction *delete = [UIAlertAction actionWithTitle:kLang(@"Delete") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self pp_setSavingState:YES];
        [PPHUD showLoading];
        [[PPAddressesManager sharedManager] deleteAddress:self.address completion:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self pp_setSavingState:NO];
                [PPHUD dismiss];
                if (!success || error) {
                    [PPAlertHelper showErrorIn:self
                                         title:kLang(@"DeleteFailed")
                                      subtitle:error.localizedDescription ?: kLang(@"SomethingWentWrong")];
                    return;
                }
                if ([self.delegate respondsToSelector:@selector(addressFormVC:didDeleteAddress:)]) {
                    [self.delegate addressFormVC:self didDeleteAddress:self.address];
                }
                [PPHUD showSuccess:kLang(@"AddressesDeleted")];
                if (self.addressFormPresent == AddressFormPresentSheet) {
                    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
                } else {
                    [self.navigationController popViewControllerAnimated:YES];
                }
            });
        }];
    }];
    [alert addAction:cancel];
    [alert addAction:delete];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.tableView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    if (self.formHeaderView) {
        CGRect frame = self.formHeaderView.frame;
        CGFloat targetWidth = CGRectGetWidth(self.tableView.bounds);
        if (fabs(frame.size.width - targetWidth) > 0.5) {
            frame.size.width = targetWidth;
            self.formHeaderView.frame = frame;
            self.tableView.tableHeaderView = self.formHeaderView;
        }
    }
}




- (XLFormRowDescriptor *)generateRawWithType:(NSString *)rowType
                                   inputType:(XLFormFullWidthTextFieldType)inputType
                                         tag:(NSString *)tag
                                       title:(NSString *)title
                                 placeholder:(NSString *)placeholder
                                    required:(BOOL)required
                                       value:(id)value
{
    XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:tag
                                                                     rowType:rowType
                                                                       title:title];
    [row.cellConfigAtConfigure setObject:placeholder forKey:@"textField.placeholder"];
    [row.cellConfig setObject:[GM MidFontWithSize:14] forKey:@"textField.font"];
    
    [row.cellConfig setObject:[GM MidFontWithSize:14] forKey:@"textLabel.font"];
    [row.cellConfig setObject:[GM MidFontWithSize:14] forKey:@"detailTextLabel.font"];
    
    
    [row.cellConfig setObject:@(GM.setAligment) forKey:@"detailTextLabel.textAlignment"];
    row.cellConfig[@"inputType"] = @(inputType);
    row.cellConfig[@"TitlePos"] = @(XLFormFullWidthTextFieldFull);
    
    row.required = required;
    if (value) row.value = value;
    row.height = 50;
    return row;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    
    if (@available(iOS 16.0, *)) {
        UIBarButtonItem *saveBarButton = [[UIBarButtonItem alloc] initWithTitle:kLang(@"Save") image:[UIImage systemImageNamed:@"checkmark"] target:self action:@selector(saveButtonPressed:) menu:nil];
        // 🔹 Set custom font + color
        UIFont *customFont = [GM boldFontWithSize:16];
        NSDictionary *attributes = @{
            NSFontAttributeName: customFont,
            NSForegroundColorAttributeName: [AppPrimaryClr colorWithAlphaComponent:1.2]
        };
        
        [saveBarButton setTitleTextAttributes:attributes forState:UIControlStateNormal];
        [saveBarButton setTitleTextAttributes:attributes forState:UIControlStateHighlighted];
        
        self.navigationItem.rightBarButtonItem = saveBarButton;
    } else {
        UIBarButtonItem *saveBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"checkmark"] style:UIBarButtonItemStylePlain target:self action:@selector(saveButtonPressed:)];
        self.navigationItem.rightBarButtonItem = saveBarButton;
    }
    UIBarButtonItem *backBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:self.addressFormPresent == AddressFormPresentSheet ? @"multiply" : PPChevronName ] style:UIBarButtonItemStylePlain target:self action:self.addressFormPresent == AddressFormPresentSheet ? @selector(onDissmiss) : @selector(onBack:)];
    self.navigationItem.leftBarButtonItem = backBarButton;
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
}


// Keep background stable to avoid flashing / empty space
- (void)keyboardWillShow:(NSNotification *)note {
    self.view.backgroundColor = PPBackgroundColorForIOS26([AppBackgroundClr colorWithAlphaComponent:1.0]);
}

// Restore original background (no transparency)
- (void)keyboardWillHide:(NSNotification *)note {
    self.view.backgroundColor = PPBackgroundColorForIOS26([AppBackgroundClr colorWithAlphaComponent:1.0]);
}
-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [PPHUD dismiss];
    [self.locationManager stopUpdatingLocation];
    [self.reverseGeocoder cancelGeocode];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    CLLocation *location = locations.lastObject;
    if (!location || ![self pp_isValidCoordinate:location.coordinate]) {
        return;
    }
    [manager stopUpdatingLocation];
    [self pp_applyCoordinateToForm:location.coordinate suggestedTitle:nil];
    [self pp_reverseGeocodeCoordinateForRowTitle:location.coordinate];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [manager stopUpdatingLocation];
    NSLog(@"[AddressFormVC] Current location failed: %@", error.localizedDescription ?: @"Unknown error");
    [self pp_applyResolvedCountryDefaultsIfNeeded];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusAuthorizedAlways ||
        status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [manager startUpdatingLocation];
    } else if (status == kCLAuthorizationStatusDenied ||
               status == kCLAuthorizationStatusRestricted) {
        [self pp_applyResolvedCountryDefaultsIfNeeded];
    }
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager API_AVAILABLE(ios(14.0))
{
    CLAuthorizationStatus status = manager.authorizationStatus;
    if (status == kCLAuthorizationStatusAuthorizedAlways ||
        status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [manager startUpdatingLocation];
    } else if (status == kCLAuthorizationStatusDenied ||
               status == kCLAuthorizationStatusRestricted) {
        [self pp_applyResolvedCountryDefaultsIfNeeded];
    }
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [super tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    cell.separatorInset = UIEdgeInsetsMake(0.0, 18.0, 0.0, 18.0);
    cell.layoutMargins = UIEdgeInsetsMake(0.0, 18.0, 0.0, 18.0);
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
}


-(void)setForm
{
    XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:self.title];
    
    XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    // Full Name
    XLFormRowDescriptor *nameRow = [self generateRawWithType:XLFormRowDescriptorTypeFullWidthTextField
                                                   inputType:XLFormFullWidthTextFieldTypeDefault
                                                         tag:@"fullName"
                                                       title:kLang(@"FullName")
                                                 placeholder:kLang(@"FullNamePlaceholder")
                                                    required:YES
                                                       value:nil];
    nameRow.requireMsg = kLang(@"PleaseFillFields");
    [section addFormRow:nameRow];

    XLFormRowDescriptor *phoneRow = [self generateRawWithType:XLFormRowDescriptorTypeFullWidthTextField
                                                    inputType:XLFormFullWidthTextFieldTypePhone
                                                          tag:@"phoneNumber"
                                                        title:kLang(@"MobileNo_Palce")
                                                  placeholder:kLang(@"MobileNo_Palce")
                                                     required:YES
                                                        value:nil];
    phoneRow.height = 50;
    [section addFormRow:phoneRow];
    
    // Address Line 1
    XLFormRowDescriptor *line1Row = [self generateRawWithType:XLFormRowDescriptorTypeFullWidthTextField
                                                    inputType:XLFormFullWidthTextFieldTypeDefault
                                                          tag:@"addressLine1"
                                                        title:kLang(@"AddressLine1")
                                                  placeholder:kLang(@"AddressLine1Placeholder")
                                                     required:YES
                                                        value:nil];
    line1Row.requireMsg = kLang(@"PleaseFillFields");
    [section addFormRow:line1Row];
    
    
    
    
    XLFormRowDescriptor *line2Row = [self generateRawWithType:XLFormRowDescriptorTypeFullWidthTextField
                                                    inputType:XLFormFullWidthTextFieldTypeDefault
                                                          tag:@"addressLine2"
                                                        title:kLang(@"AddressLine2Optional")
                                                  placeholder:kLang(@"AddressLine2Placeholder")
                                                     required:NO
                                                        value:nil];
    [section addFormRow:line2Row];
    
    __weak typeof(self) weakSelf = self;
    self.countryRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"country"
                                                            rowType:XLFormRowDescriptorTypeSelectorPush
                                                              title:(kLang(@"Country") ?: kLang(@"SelectCountryTitle"))];
    self.countryRow.selectorOptions = [self pp_availableCountries];
    self.countryRow.noValueDisplayText = kLang(@"TapToSelect");
    self.countryRow.required = YES;
    self.countryRow.requireMsg = kLang(@"CountryRequired") ?: kLang(@"TapToSelect");
    self.countryRow.onChangeBlock = ^(id  _Nullable oldValue, id  _Nullable newValue, XLFormRowDescriptor * _Nonnull rowDescriptor) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![newValue isKindOfClass:[CountryModel class]]) {
            return;
        }
        self.selectedCountry = (CountryModel *)newValue;
        [self pp_applyCountry:self.selectedCountry
                preferredCity:nil
               preferredState:nil];
    };
    self.countryRow.height = 50;
    [section addFormRow:self.countryRow];

    _cityRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"city" rowType:XLFormRowDescriptorTypeSelectorPush title:kLang(@"City")];
    _cityRow.selectorOptions =  _citiesArray;
    _cityRow.noValueDisplayText = kLang(@"TapToSelect");
    _cityRow.required = YES;
    _cityRow.requireMsg = kLang(@"TapToSelect");
    _cityRow.onChangeBlock = ^(id  _Nullable oldValue, id  _Nullable newValue, XLFormRowDescriptor * _Nonnull rowDescriptor) {
        if([newValue isKindOfClass:[CityModel class]]) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            self.selectedCity = (CityModel *)newValue;
            [self pp_applyCity:self.selectedCity state:nil];
        }
    };
    self.cityRow.height = 50;
    [section addFormRow:_cityRow];
    
    self.stateRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"state" rowType:XLFormRowDescriptorTypeSelectorPush
                                                            title:kLang(@"State")];
    self.stateRow.required = YES;
    self.stateRow.noValueDisplayText = kLang(@"TapToSelect");
    self.stateRow.requireMsg = kLang(@"CityRequired");
    self.stateRow.onChangeBlock = ^(id  _Nullable oldValue, id  _Nullable newValue, XLFormRowDescriptor * _Nonnull rowDescriptor) {
        if([newValue isKindOfClass:[StateModel class]])
        {
            __strong typeof(weakSelf) self = weakSelf;
            self.selectedState = (StateModel *)newValue;
            NSLog(@"self.selectedState %@ self.selectedState.stateID %ld",
                  self.selectedState.enName,
                  self.selectedState.stateID);
            
            [weakSelf updateFormRow:weakSelf.stateRow];
        }
    };
    self.stateRow.height = 50;
    [section addFormRow:self.stateRow];
    
    
    
    // Postal Code
    XLFormRowDescriptor *postalRow = [self generateRawWithType:XLFormRowDescriptorTypeFullWidthTextField
                                                     inputType:XLFormFullWidthTextFieldTypeDefault
                                                           tag:@"postalCode"
                                                         title:kLang(@"PostalCode")
                                                   placeholder:kLang(@"PostalCodePlaceholder")
                                                      required:YES
                                                         value:nil];
    postalRow.requireMsg = kLang(@"PostalCodeRequired");
    [section addFormRow:postalRow];
    
    XLFormSectionDescriptor *optionsSection = [XLFormSectionDescriptor formSection];
    [form addFormSection:optionsSection];
    
    // Default Address Switch
    XLFormRowDescriptor *defaultRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"isDefault"
                                                                            rowType:XLFormRowDescriptorTypeBooleanSwitch
                                                                              title:kLang(@"DefaultShippingAddress")];
    BOOL isFirstAddress = (!self.address && PPCurrentUser.Addresses.count == 0);
    defaultRow.value = @(self.address ? self.address.isDefault : isFirstAddress);
    defaultRow.height = 50;
    
    [optionsSection addFormRow:defaultRow];
    
    // Map Location Picker
    XLFormRowDescriptor *locationRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"location"
                                                                             rowType:XLFormRowDescriptorTypeSelectorPush
                                                                               title:kLang(@"MapLocation")];
    locationRow.noValueDisplayText = kLang(@"TapToSelect");
    locationRow.height = 50;
    locationRow.action.formBlock = ^(XLFormRowDescriptor * _Nonnull sender) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf pp_openLocationPickerForRow:sender];
    };
    //locationRow.selectorControllerClass = LocationPickerViewController.class;
    [optionsSection addFormRow:locationRow];
    
    if (self.address) {
        XLFormSectionDescriptor *deleteSection = [XLFormSectionDescriptor formSection];
        [form addFormSection:deleteSection];
        
        XLFormRowDescriptor *deleteRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"delete"
                                                                               rowType:XLFormRowDescriptorTypeButton
                                                                                 title:kLang(@"DeleteAddress")];
        [deleteRow.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
        [deleteRow.cellConfig setObject:@(NSTextAlignmentCenter) forKey:@"textLabel.textAlignment"];
        deleteRow.action.formBlock = ^(XLFormRowDescriptor * _Nonnull sender) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf showDeleteConfirmation];
            NSIndexPath *indexPath = [strongSelf.form indexPathOfFormRow:sender];
            if (indexPath) {
                [strongSelf.tableView deselectRowAtIndexPath:indexPath animated:YES];
            }
        };
        [deleteSection addFormRow:deleteRow];
    }
    
    self.form = form;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:kLang(@"Save")
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self
                                                                             action:@selector(saveButtonPressed:)];
    
    NSLog(@"AddressFormVC loaded (%@ mode)", (self.address ? kLang(@"Edit") : kLang(@"Add")));
    
    NSString *preferredName = (self.address.fullName.length > 0)
        ? self.address.fullName
        : ((PPCurrentUser.UserName.length > 0)
           ? PPCurrentUser.UserName
           : ([FIRAuth auth].currentUser.displayName ?: @""));
    nameRow.value = preferredName;

    NSString *preferredPhone = (self.address.phoneNumber.length > 0)
        ? self.address.phoneNumber
        : ((PPCurrentUser.MobileNo.length > 0)
           ? PPCurrentUser.MobileNo
           : ([FIRAuth auth].currentUser.phoneNumber ?: @""));
    phoneRow.value = preferredPhone;

    if (self.address) {
        nameRow.value    = self.address.fullName;
        line1Row.value   = self.address.addressLine1;
        line2Row.value   = self.address.addressLine2;
        self.selectedCity = [CitiesManager.shared cityByID:self.address.cityID];
        self.selectedState = [CitiesManager.shared stateByID:self.address.stateID];
        self.selectedCountry = self.selectedCity.country ?: self.resolvedCountry ?: [self pp_qatarCountry];
        [self pp_applyCountry:self.selectedCountry
                preferredCity:self.selectedCity
               preferredState:self.selectedState];
        postalRow.value  = self.address.postalCode;
        
        locationRow.value  = self.address.locatioName;
        self.selectedLocationName  = self.address.locatioName;
        self.selectedLocationPoints  = self.address.locationPoints;
        
        [self.tableView reloadData];
    }
    
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.tableView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    
    
}
@end


/*
 - (void)viewDidLoad {
 [super viewDidLoad];
 
 
 // etc.
 
 // Create the form descriptor
 XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:self.title];
 
 // Section 1: Address fields
 XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSection];
 [form addFormSection:section];
 
 // Full Name (required)
 XLFormRowDescriptor *nameRow = [self generateRawWithType:XLFormRowDescriptorTypeFullWidthTextField
 inputType:XLFormFullWidthTextFieldTypeDefault
 tag:@"fullName"
 title:kLang(@"Full Name")
 placeholder:kLang(@"Full Name")
 required:YES
 value:PPCurrentUser.UserName];
 
 nameRow.requireMsg = kLang(@"Full Name is required");
 // Optimize keyboard for name input
 //[nameRow.cellConfigAtConfigure setObject:@(UIText Words) forKey:@"textField.autocapitalizationType"];
 [section addFormRow:nameRow];
 
 // Address Line 1 (required)
 XLFormRowDescriptor *line1Row = [XLFormRowDescriptor formRowDescriptorWithTag:@"addressLine1"
 rowType:XLFormRowDescriptorTypeText
 title:nil];
 [line1Row.cellConfigAtConfigure setObject:kLang(@"Address Line 1") forKey:@"textField.placeholder"];
 line1Row.required = YES;
 line1Row.requireMsg = kLang(@"Address Line 1 is required");
 // Capitalize words (common for addresses)
 //[line1Row.cellConfigAtConfigure setObject:@(UITextAutocapitalizationTypeWords) forKey:@"textField.autocapitalizationType"];
 [section addFormRow:line1Row];
 
 // Address Line 2 (optional)
 XLFormRowDescriptor *line2Row = [XLFormRowDescriptor formRowDescriptorWithTag:@"addressLine2"
 rowType:XLFormRowDescriptorTypeText
 title:nil];
 [line2Row.cellConfigAtConfigure setObject:kLang(@"Address Line 2 (Optional)") forKey:@"textField.placeholder"];
 // Not required (optional field), but still no autocorrect
 //[line2Row.cellConfigAtConfigure setObject:@(UITextAutocorrectionTypeNo) forKey:@"textField.autocorrectionType"];
 //[line2Row.cellConfigAtConfigure setObject:@(UITextAutocapitalizationTypeWords) forKey:@"textField.autocapitalizationType"];
 [section addFormRow:line2Row];
 
 // City (required)
 XLFormRowDescriptor *cityRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"city"
 rowType:XLFormRowDescriptorTypeText
 title:nil];
 [cityRow.cellConfigAtConfigure setObject:kLang(@"City") forKey:@"textField.placeholder"];
 cityRow.required = YES;
 cityRow.requireMsg = kLang(@"City is required");
 //[cityRow.cellConfigAtConfigure setObject:@(UITextAutocorrectionTypeNo) forKey:@"textField.autocorrectionType"];
 //[cityRow.cellConfigAtConfigure setObject:@(UITextAutocapitalizationTypeWords) forKey:@"textField.autocapitalizationType"];
 [section addFormRow:cityRow];
 
 // State (required) - could be state code or full state name
 XLFormRowDescriptor *stateRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"state"
 rowType:XLFormRowDescriptorTypeText
 title:nil];
 [stateRow.cellConfigAtConfigure setObject:kLang(@"State") forKey:@"textField.placeholder"];
 stateRow.required = YES;
 stateRow.requireMsg = kLang(@"State is required");
 // If expecting state code, force uppercase for all characters
 //[stateRow.cellConfigAtConfigure setObject:@(UITextAutocapitalizationTypeAllCharacters) forKey:@"textField.autocapitalizationType"];
 [section addFormRow:stateRow];
 
 // Postal Code (required)
 XLFormRowDescriptor *postalRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"postalCode"
 rowType:XLFormRowDescriptorTypeText
 title:nil];
 [postalRow.cellConfigAtConfigure setObject:kLang(@"Postal Code") forKey:@"textField.placeholder"];
 postalRow.required = YES;
 postalRow.requireMsg = kLang(@"Postal Code is required");
 // Use number/punctuation keyboard for postal code (allows digits and common symbols like dash)
 //[postalRow.cellConfigAtConfigure setObject:@(UIKeyboardTypeNumbersAndPunctuation) forKey:@"textField.keyboardType"];
 //[postalRow.cellConfigAtConfigure setObject:@(UITextAutocapitalizationTypeNone) forKey:@"textField.autocapitalizationType"];
 [section addFormRow:postalRow];
 
 // Section 2: Options (Default address switch and Map location picker)
 XLFormSectionDescriptor *optionsSection = [XLFormSectionDescriptor formSection];
 [form addFormSection:optionsSection];
 
 // Default Shipping Address toggle
 XLFormRowDescriptor *defaultRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"isDefault"
 rowType:XLFormRowDescriptorTypeBooleanSwitch
 title:kLang(@"Default Shipping Address")];
 defaultRow.value = @(self.address ? self.address.isDefault : NO); // set initial switch state
 [optionsSection addFormRow:defaultRow];
 
 // Map Location picker (stubbed out - to be implemented by user later)
 XLFormRowDescriptor *locationRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"location"
 rowType:XLFormRowDescriptorTypeSelectorPush
 title:kLang(@"Map Location")];
 locationRow.noValueDisplayText = kLang(@"Tap to select");
 // Provide a placeholder action for now (user will integrate their map picker later)
 __weak typeof(self) weakSelf = self;
 locationRow.action.formBlock = ^(XLFormRowDescriptor * _Nonnull sender) {
 __strong typeof(weakSelf) strongSelf = weakSelf;
 if (!strongSelf) return;
 // Placeholder action: In a real scenario, push a map picker here
 NSLog(@"Location picker tapped (to be implemented)");
 // Deselect the row to remove the highlight
 NSIndexPath *indexPath = [strongSelf.form indexPathOfFormRow:sender];
 if (indexPath) {
 [strongSelf.tableView deselectRowAtIndexPath:indexPath animated:YES];
 }
 };
 [optionsSection addFormRow:locationRow];
 
 // Section 3 (only if editing): Delete Address button
 if (self.address) {
 XLFormSectionDescriptor *deleteSection = [XLFormSectionDescriptor formSection];
 [form addFormSection:deleteSection];
 
 XLFormRowDescriptor *deleteRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"delete"
 rowType:XLFormRowDescriptorTypeButton
 title:kLang(@"Delete Address")];
 // Style the delete button: red, centered text
 [deleteRow.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
 [deleteRow.cellConfig setObject:@(NSTextAlignmentCenter) forKey:@"textLabel.textAlignment"];
 // Define deletion action
 deleteRow.action.formBlock = ^(XLFormRowDescriptor * _Nonnull sender) {
 __strong typeof(weakSelf) strongSelf = weakSelf;
 if (!strongSelf) return;
 [strongSelf showDeleteConfirmation];
 // Deselect row after tapping
 NSIndexPath *indexPath = [strongSelf.form indexPathOfFormRow:sender];
 if (indexPath) {
 [strongSelf.tableView deselectRowAtIndexPath:indexPath animated:YES];
 }
 };
 [deleteSection addFormRow:deleteRow];
 }
 
 // Assign the constructed form to this form view controller
 self.form = form;
 
 // Add a Save button on the navigation bar
 // UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithTitle:kLang(@"Save") style:UIBarButtonItemStyleDone target:self action:@selector(saveButtonPressed:)];
 //self.navigationItem.rightBarButtonItem = saveButton;
 
 NSLog(@"AddressFormVC loaded (%@ mode)", (self.address ? kLang(@"Edit") : kLang(@"Add")));
 
 // Pre-fill form fields if editing an existing address
 if (self.address) {
 nameRow.value    = self.address.fullName;
 line1Row.value   = self.address.addressLine1;
 line2Row.value   = self.address.addressLine2;   // might be nil if not provided
 cityRow.value    = self.address.city;
 stateRow.value   = self.address.state;
 postalRow.value  = self.address.postalCode;
 // (The defaultRow switch value was already set above)
 [self.tableView reloadData];
 }
 
 self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
 self.tableView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
 
 }
 #
 
 
 create for me a reusable view call PPDefultLocationView
 that will be a view with modren blur background in available ios 26 other create legacy blur
 
 this view will be like
 uiview[[deliver to icon][defult location               ][change icon]]
 
 on tap change use this to show and pick another location to delive to
 
 
 
 
 
 
 */
