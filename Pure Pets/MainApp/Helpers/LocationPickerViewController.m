#import "LocationPickerViewController.h"
#import "CitiesManager.h"
#import "CountryModel.h"
#import <math.h>
#import <float.h>
#import <CoreLocation/CoreLocation.h>

static inline BOOL PPLocationPickerCoordinateIsUsable(CLLocationCoordinate2D coordinate)
{
    return CLLocationCoordinate2DIsValid(coordinate) &&
           isfinite(coordinate.latitude) &&
           isfinite(coordinate.longitude);
}

@interface LocationPickerViewController ()
@property(nonatomic,strong) GMSMapView *mapView;
@property(nonatomic,strong) UIImageView *centerPinImageView;
@property(nonatomic,strong) UILabel *addressLabel;
@property(nonatomic,strong) UIActivityIndicatorView *spinner;
@property(nonatomic,strong) GMSGeocoder *geocoder;
@property(nonatomic,strong) CLGeocoder *appleGeocoder;
@property(nonatomic,strong) NSDate *lastGeocodeTime;
@property(nonatomic,strong) GMSAddress *selectedAddress;
@property(nonatomic,strong) CLLocationManager *locationManager;
@property(nonatomic,strong) GMSMarker *marker;

 @property(nonatomic,strong) BottomOptionsViewController *bottomSheet;

@property (nonatomic, strong)  UIButton *emptyCard;
@property(nonatomic,strong) UIButton *recenterButton;
@property(nonatomic,assign) CLLocationCoordinate2D lastKnownCoordinate;
@property(nonatomic,copy) dispatch_block_t geocodeTimeoutBlock;
@property(nonatomic,assign) BOOL geocodeRequestInFlight;
@property(nonatomic,copy) NSString *selectedLocationTitle;

@end
/*
 
 // AddressPickerViewController.h
 @protocol AddressPickerDelegate <NSObject>
 - (void)didSelectLocation:(NSString *)location;
 @end

 @interface AddressPickerViewController : UIViewController

 @property (nonatomic, weak) id<AddressPickerDelegate> delegate;

 @end

 // In your AddressPickerViewController.m
 - (void)locationSelected:(NSString *)location {
     if ([self.delegate respondsToSelector:@selector(didSelectLocation:)]) {
         [self.delegate didSelectLocation:location];
     }
     [self.navigationController popViewControllerAnimated:YES];
 }
 
 */
@implementation LocationPickerViewController

@synthesize rowDescriptor;
- (instancetype)initWithRowDescriptor:(XLFormRowDescriptor *)rowDescriptor {
    if (self = [super init]) {
        self.rowDescriptor = rowDescriptor;
    }
    return self;
}



- (void)viewDidLoad {
    [super viewDidLoad];
    //[AppClasses setTitle:kLang(@"LocationPicker") onController:self backgroundColor:GM.AppForegroundColor align:titleAlignRigth masked:kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner];
   

    // Map
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.geocoder = [[GMSGeocoder alloc] init];
    self.appleGeocoder = [[CLGeocoder alloc] init];
    self.lastGeocodeTime = [NSDate distantPast];
    self.lastKnownCoordinate = kCLLocationCoordinate2DInvalid;
    
    // Map
    CLLocationCoordinate2D startCoordinate = self.initialCoordinate;
    BOOL shouldUseDohaFallback = !PPLocationPickerCoordinateIsUsable(startCoordinate) ||
        (fabs(startCoordinate.latitude) < DBL_EPSILON && fabs(startCoordinate.longitude) < DBL_EPSILON);
    if (shouldUseDohaFallback) {
        startCoordinate = [self pp_dohaCoordinate];
    }
    self.lastKnownCoordinate = startCoordinate;

    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:startCoordinate.latitude
                                                             longitude:startCoordinate.longitude
                                                                  zoom:15];
    self.mapView = [GMSMapView mapWithFrame:CGRectZero camera:camera];
    self.mapView.delegate = self;
    self.mapView.myLocationEnabled = YES;
    self.mapView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.mapView];
    
    self.centerPinImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"standerpin"]];
    self.centerPinImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.centerPinImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.centerPinImageView.tintColor = AppPrimaryClr;
    [self.view addSubview:self.centerPinImageView];

    [NSLayoutConstraint activateConstraints:@[
        [self.centerPinImageView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.centerPinImageView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-12], // lift slightly
        [self.centerPinImageView.heightAnchor constraintEqualToConstant:40],
        [self.centerPinImageView.widthAnchor constraintEqualToConstant:40]
    ]];

    
    // Address label
    self.addressLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.addressLabel.font = [GM MidFontWithSize:16];
    self.addressLabel.backgroundColor = AppClearClr;
    self.addressLabel.numberOfLines = 0;
    self.addressLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.addressLabel.textAlignment = NSTextAlignmentCenter;
    self.addressLabel.textColor = AppSecondaryTextClr;
    
    [self.view addSubview:self.addressLabel];
    
    // Spinner
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    [self.view addSubview:self.spinner];
    
    self.recenterButton = [PPButtonHelper buttonWithSystemName:@"dot.scope" target:self action:@selector(centerToUserLocation)];
    self.recenterButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.recenterButton];
   

    // Location Manager
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    [self.locationManager requestWhenInUseAuthorization];
    [self.locationManager startUpdatingLocation];
    
    //CLLocationCoordinate2D defaultLocation = self.mapView.myLocation.coordinate;
    self.marker.title = @"...";
    
    //self.marker = [GMSMarker markerWithPosition:defaultLocation];
    //self.marker.draggable = YES;
    //self.marker.map = self.mapView;
    [[UIBarButtonItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : GM.SecondaryTextColor} forState:UIControlStateNormal];
    
    self.emptyCard = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleCapsule configType:PPButtonConfigrationGlass];
    //self.emptyCard.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];  // White background for the card

    [self.view addSubview:self.emptyCard];

    //__weak typeof(self) weakSelf = self;
    
    float emptyCardHeight = 64;
    if (@available(iOS 26.0, *)) emptyCardHeight = 64;
    // Set constraints for the empty card view to position it in the view
    [NSLayoutConstraint activateConstraints:@[
        [self.emptyCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.emptyCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.emptyCard.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
    ]];

    float pad = 12;
    self.addressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.emptyCard addSubview:self.addressLabel];
    [NSLayoutConstraint activateConstraints:@[ [self.addressLabel.leadingAnchor constraintEqualToAnchor:    self.emptyCard.leadingAnchor        constant:pad],
                                               [self.addressLabel.trailingAnchor constraintEqualToAnchor:   self.emptyCard.trailingAnchor       constant:-pad],
                                               [self.addressLabel.bottomAnchor constraintEqualToAnchor:     self.emptyCard.bottomAnchor         constant:-pad],
                                               [self.addressLabel.topAnchor constraintEqualToAnchor:        self.emptyCard.topAnchor            constant:pad], ]];
    
    
    [NSLayoutConstraint activateConstraints:@[
        [self.recenterButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant: 16],
        [self.recenterButton.topAnchor constraintEqualToAnchor:self.emptyCard.bottomAnchor constant: 12],
        [self.recenterButton.heightAnchor constraintEqualToConstant:44],
        [self.recenterButton.widthAnchor constraintEqualToConstant:44],
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [self.mapView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:0],
        [self.mapView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-0],
        [self.mapView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-0],
        [self.mapView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:0],
    ]];
    
    
  
    self.mapView.layer.cornerRadius = 0;
    self.mapView.clipsToBounds = YES;

    if (shouldUseDohaFallback) {
        [self pp_applyDohaFallbackAnimated:NO];
    } else {
        [self pp_updateMapCardWithFallbackCoordinate:startCoordinate];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self startReverseGeocodeForPosition:self.mapView.camera];
    });
}

- (NSString *)pp_compactAddressTitleFromGMSAddress:(GMSAddress *)address
{
    if (!address) return @"";
    NSString *t = [LocationPickerViewController titleFromAddress:address];
    if (t.length) return t;

    NSString *full = [address.lines componentsJoinedByString:@", "];
    return full ?: @"";
}

- (CLLocationCoordinate2D)pp_dohaCoordinate
{
    CountryModel *qatar = [CitiesManager.shared qatarCountry];
    CityModel *doha = [CitiesManager.shared defaultCityForCountry:qatar];
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(doha.latitude, doha.longitude);
    if (PPLocationPickerCoordinateIsUsable(coordinate) &&
        !(fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON)) {
        return coordinate;
    }
    return CLLocationCoordinate2DMake(25.285447, 51.531040);
}

- (NSString *)pp_dohaTitle
{
    CountryModel *qatar = [CitiesManager.shared qatarCountry];
    CityModel *doha = [CitiesManager.shared defaultCityForCountry:qatar];
    NSString *cityName = Language.isRTL ? doha.arName : doha.enName;
    NSString *countryName = qatar.name;
    if (cityName.length > 0 && countryName.length > 0) {
        return [NSString stringWithFormat:@"%@, %@", cityName, countryName];
    }
    return cityName.length > 0 ? cityName : (countryName.length > 0 ? countryName : @"Doha, Qatar");
}

- (void)pp_applyDohaFallbackAnimated:(BOOL)animated
{
    CLLocationCoordinate2D coordinate = [self pp_dohaCoordinate];
    self.lastKnownCoordinate = coordinate;
    self.selectedAddress = nil;
    self.selectedLocationTitle = [self pp_dohaTitle];

    if (animated) {
        [self.mapView animateToLocation:coordinate];
        [self.mapView animateToZoom:15];
    } else {
        self.mapView.camera = [GMSCameraPosition cameraWithLatitude:coordinate.latitude
                                                          longitude:coordinate.longitude
                                                               zoom:15];
    }

    [self pp_updateMapCardWithResolvedTitle:self.selectedLocationTitle coordinate:coordinate];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    self.spinner.center = self.view.center;

}


-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
     if(PPIOS26())
    {
        UIBarButtonItem *saveBtnButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"checkmark"] style:UIBarButtonItemStylePlain target:self action:@selector(confirmLocationTapped)];
        UIBarButtonItem *backBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:PPChevronName] style:UIBarButtonItemStylePlain target:self action:@selector(onBack:)];

        self.navigationItem.rightBarButtonItem = saveBtnButton;
        self.navigationItem.leftBarButtonItem = backBarButton;
         
        UIView *center =   [self pp_viewWithTitle:nil Subtitle:kLang(@"ChoseLocation") Image:nil showBackround:YES];
        [center setBackgroundColor:[AppBackgroundClrLigter colorWithAlphaComponent:0.5]];
        [self pp_navBarSetTitleViewCentered:center ];
        
    }
    else
    {
        UIButton *saveBtn = [PPButtonHelper pp_buttonWithTitleForBar:nil imageName:@"checkmark" target:self action:@selector(confirmLocationTapped)];
        saveBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [saveBtn.heightAnchor constraintEqualToConstant:40].active = YES;
        [saveBtn.widthAnchor constraintEqualToConstant:40].active = YES;
        saveBtn.layer.cornerRadius = 20 ;
        
        [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"ChoseLocation") showBack:YES];
        [self pp_navBarSetRightIcon:@"checkmark" key:@"checkmark" target:self action:@selector(confirmLocationTapped) tap:^{
        }];
        
    }
}
#pragma mark – CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)mgr didUpdateLocations:(NSArray<CLLocation *>*)locations {
    CLLocation *loc = locations.lastObject;
    if (!loc || !PPLocationPickerCoordinateIsUsable(loc.coordinate)) {
        return;
    }
    self.lastKnownCoordinate = loc.coordinate;
    [self pp_updateMapCardWithFallbackCoordinate:loc.coordinate];
    [self.mapView animateToLocation:loc.coordinate];
    [self.mapView animateToZoom:15];
    [self pp_tryAppleReverseGeocodeForCoordinate:loc.coordinate];
    
    [mgr stopUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    (void)manager;
    NSLog(@"[LocationPicker] location update failed: %@", error.localizedDescription);
    if (PPLocationPickerCoordinateIsUsable(self.lastKnownCoordinate)) {
        [self.mapView animateToLocation:self.lastKnownCoordinate];
    } else {
        [self pp_applyDohaFallbackAnimated:YES];
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusAuthorizedAlways ||
        status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [manager startUpdatingLocation];
    } else if (status == kCLAuthorizationStatusDenied ||
               status == kCLAuthorizationStatusRestricted) {
        [self pp_applyDohaFallbackAnimated:YES];
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
        [self pp_applyDohaFallbackAnimated:YES];
    }
}

#pragma mark – Map Events

- (void)mapView:(GMSMapView *)mapView willMove:(BOOL)gesture {
    [UIView animateWithDuration:0.15 animations:^{
        self.centerPinImageView.transform = CGAffineTransformMakeTranslation(0, -15);
    }];
}

- (void)mapView:(GMSMapView *)mapView idleAtCameraPosition:(GMSCameraPosition *)position {
    [UIView animateWithDuration:0.2 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.8 options:0 animations:^{
        self.centerPinImageView.transform = CGAffineTransformIdentity;
    } completion:nil];

    self.lastKnownCoordinate = position.target;
    [self pp_updateMapCardWithFallbackCoordinate:position.target];
    [self startReverseGeocodeForPosition:position];
}

- (void)startReverseGeocodeForPosition:(GMSCameraPosition *)position {
    CLLocationCoordinate2D target = position.target;
    if (!PPLocationPickerCoordinateIsUsable(target)) {
        return;
    }

    NSDate *now = [NSDate date];
    if ([now timeIntervalSinceDate:self.lastGeocodeTime] < 0.8) return;
    self.lastGeocodeTime = now;
    self.lastKnownCoordinate = target;
    self.geocodeRequestInFlight = YES;

    [self pp_cancelPendingGeocodeTimeout];
    [self.spinner startAnimating];

    __weak typeof(self) weakSelf = self;
    dispatch_block_t timeoutBlock = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.geocodeRequestInFlight) return;
        self.geocodeRequestInFlight = NO;
        [self.spinner stopAnimating];
        [self pp_updateMapCardWithFallbackCoordinate:target];
        [self pp_tryAppleReverseGeocodeForCoordinate:target];
    });
    self.geocodeTimeoutBlock = timeoutBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), timeoutBlock);

    [self.geocoder reverseGeocodeCoordinate:target completionHandler:^(GMSReverseGeocodeResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            [self pp_cancelPendingGeocodeTimeout];
            self.geocodeRequestInFlight = NO;
            [self.spinner stopAnimating];

            if (resp.firstResult) {
                self.selectedAddress = resp.firstResult;
                self.lastKnownCoordinate = resp.firstResult.coordinate;
                [self updateMapCardWithGMSAddress:self.selectedAddress];
            } else {
                NSLog(@"[LocationPicker] reverse geocode fallback: %@",
                      err.localizedDescription ?: @"No result");
                self.selectedAddress = nil;
                [self pp_updateMapCardWithFallbackCoordinate:target];
                [self pp_tryAppleReverseGeocodeForCoordinate:target];
            }
        });
    }];
}

- (void)pp_cancelPendingGeocodeTimeout
{
    if (self.geocodeTimeoutBlock) {
        dispatch_block_cancel(self.geocodeTimeoutBlock);
        self.geocodeTimeoutBlock = nil;
    }
}

- (NSString *)pp_fallbackTitleForCoordinate:(CLLocationCoordinate2D)coordinate
{
    if (!PPLocationPickerCoordinateIsUsable(coordinate)) {
        return kLang(@"Select your location") ?: @"Select your location";
    }
    return [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
}

- (void)pp_updateMapCardWithFallbackCoordinate:(CLLocationCoordinate2D)coordinate
{
    BOOL isArabic = Language.isRTL;;
    self.selectedLocationTitle = [self pp_fallbackTitleForCoordinate:coordinate];
    NSString *title = isArabic ? @"📍 الموقع المحدد" : @"📍 Selected location";
    NSString *coordsLine =
        [NSString stringWithFormat:@"%@ %@", (isArabic ? @"🗺️ الإحداثيات:" : @"🗺️ Coordinates:"),
                                   self.selectedLocationTitle ?: @""];

    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] init];
    NSDictionary *titleAttrs = @{
        NSFontAttributeName: [GM MidFontWithSize:17],
        NSForegroundColorAttributeName: UIColor.labelColor
    };
    NSDictionary *coordsAttrs = @{
        NSFontAttributeName: [GM MidFontWithSize:15],
        NSForegroundColorAttributeName: UIColor.secondaryLabelColor
    };
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", title]
                                                                  attributes:titleAttrs]];
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:coordsLine attributes:coordsAttrs]];
    self.addressLabel.attributedText = attr;
}
#pragma mark - Map Card Update

- (void)updateMapCardWithGMSAddress:(GMSAddress *)address {
    if (!address) return;
    
    // 🔹 تحديد لغة النظام الحالية
    BOOL isArabic = Language.isRTL;;

    
    // 🔹 العنوان الكامل
    NSString *fullAddress = [self pp_compactAddressTitleFromGMSAddress:address];
    if (!fullAddress.length) fullAddress = isArabic ? @"العنوان غير متاح" : @"Address not available";
    self.selectedLocationTitle = fullAddress;
    
    // 🔹 الإحداثيات
    NSString *coords = [NSString stringWithFormat:@"%.6f, %.6f",
                        address.coordinate.latitude,
                        address.coordinate.longitude];
    
    // 🔹 الرموز حسب اللغة
    NSString *addressIcon = isArabic ? @"📍 العنوان:" : @"📍 Address:";
    NSString *coordsIcon  = isArabic ? @"🗺️ الإحداثيات:" : @"🗺️ Coordinates:";
    
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.alignment = self.addressLabel.textAlignment;
    ps.lineBreakMode = NSLineBreakByTruncatingTail;

    // 🔹 نص منسّق داخل البطاقة
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] init];
    
    NSDictionary *titleAttrs = @{
        NSFontAttributeName: [GM MidFontWithSize:17],
        NSForegroundColorAttributeName: UIColor.labelColor,
        NSParagraphStyleAttributeName: ps
    };

    NSDictionary *coordsAttrs = @{
        NSFontAttributeName: [GM MidFontWithSize:15],
        NSForegroundColorAttributeName: UIColor.secondaryLabelColor,
        NSParagraphStyleAttributeName: ps
    };
    
    
    NSString *addressLine = [NSString stringWithFormat:@"%@ %@\n", addressIcon, fullAddress];
    NSString *coordsLine = [NSString stringWithFormat:@"%@ %@", coordsIcon, coords];
    
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:addressLine attributes:titleAttrs]];
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:coordsLine attributes:coordsAttrs]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.addressLabel.attributedText = attr;
    });
}

- (NSString *)pp_compactTitleFromPlacemark:(CLPlacemark *)placemark
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

- (void)pp_updateMapCardWithResolvedTitle:(NSString *)resolvedTitle
                               coordinate:(CLLocationCoordinate2D)coordinate
{
    BOOL isArabic = Language.isRTL;
    NSString *addressLabelText = isArabic ? @"📍 العنوان:" : @"📍 Address:";
    NSString *coordsLabelText = isArabic ? @"🗺️ الإحداثيات:" : @"🗺️ Coordinates:";
    NSString *coords = [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];

    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.alignment = self.addressLabel.textAlignment;
    ps.lineBreakMode = NSLineBreakByTruncatingTail;

    NSDictionary *titleAttrs = @{
        NSFontAttributeName: [GM MidFontWithSize:17],
        NSForegroundColorAttributeName: UIColor.labelColor,
        NSParagraphStyleAttributeName: ps
    };
    NSDictionary *coordsAttrs = @{
        NSFontAttributeName: [GM MidFontWithSize:15],
        NSForegroundColorAttributeName: UIColor.secondaryLabelColor,
        NSParagraphStyleAttributeName: ps
    };

    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] init];
    NSString *addressLine = [NSString stringWithFormat:@"%@ %@\n", addressLabelText, resolvedTitle ?: @""];
    NSString *coordsLine = [NSString stringWithFormat:@"%@ %@", coordsLabelText, coords];
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:addressLine attributes:titleAttrs]];
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:coordsLine attributes:coordsAttrs]];
    self.addressLabel.attributedText = attr;
}

- (void)pp_tryAppleReverseGeocodeForCoordinate:(CLLocationCoordinate2D)coordinate
{
    if (!PPLocationPickerCoordinateIsUsable(coordinate)) {
        return;
    }
    if (!self.appleGeocoder) {
        self.appleGeocoder = [[CLGeocoder alloc] init];
    }
    if (self.appleGeocoder.isGeocoding) {
        [self.appleGeocoder cancelGeocode];
    }

    CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude
                                                      longitude:coordinate.longitude];
    __weak typeof(self) weakSelf = self;
    [self.appleGeocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || error || placemarks.count == 0) {
                return;
            }
            NSString *resolvedTitle = [self pp_compactTitleFromPlacemark:placemarks.firstObject];
            if (resolvedTitle.length == 0) {
                return;
            }
            self.selectedAddress = nil;
            self.selectedLocationTitle = resolvedTitle;
            [self pp_updateMapCardWithResolvedTitle:resolvedTitle coordinate:coordinate];
        });
    }];
}

- (void)updateMapCardWithAddress:(GMSAddress *)address {
    if (!address) return;
    
    // 1. العنوان الكامل
    NSString *fullAddress = address.lines ? [address.lines componentsJoinedByString:@", "] : @"";
    
    // 2. الإحداثيات
    NSString *coords = [NSString stringWithFormat:@"%.6f, %.6f",
                        address.coordinate.latitude,
                        address.coordinate.longitude];
    
    // 3. إنشاء النص المنسّق
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] init];
    
    NSDictionary *titleAttrs = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:17],
        NSForegroundColorAttributeName: UIColor.labelColor
    };
    
    NSDictionary *coordsAttrs = @{
        NSFontAttributeName: [UIFont systemFontOfSize:14],
        NSForegroundColorAttributeName: UIColor.secondaryLabelColor
    };
    
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", fullAddress] attributes:titleAttrs]];
    [attr appendAttributedString:[[NSAttributedString alloc] initWithString:coords attributes:coordsAttrs]];
    
    self.addressLabel.attributedText = attr;
}

#pragma mark – Actions

- (void)centerToUserLocation {
    CLLocation *loc = self.mapView.myLocation;
    if (loc && PPLocationPickerCoordinateIsUsable(loc.coordinate)) {
        [self.mapView animateToLocation:loc.coordinate];
        return;
    }
    if (PPLocationPickerCoordinateIsUsable(self.lastKnownCoordinate)) {
        [self.mapView animateToLocation:self.lastKnownCoordinate];
        return;
    }
    [self pp_applyDohaFallbackAnimated:YES];
}

- (void)pp_closePicker
{
    if (self.navigationController) {
        BOOL isRootOfPresentedNav =
            (self.navigationController.viewControllers.firstObject == self &&
             self.navigationController.presentingViewController != nil);
        if (isRootOfPresentedNav) {
            [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        } else {
            [self.navigationController popViewControllerAnimated:YES];
        }
    } else if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)confirmLocationTapped {
    
    
  
   // AddressModel *add = [AddressModel addressModelFromGMSAddress:self.selectedAddress coordinate:self.selectedAddress.coordinate addressTitleId:self.selectedAddressTitleModel.titleID customLabel:@"" ];
        
   /*
    if (self.rowDescriptor) {

          
            
            //self.rowDescriptor.value = add;
            [self.delegate didSelectLocationAddressModel:add];
            
            [self.navigationController popViewControllerAnimated:YES];
            return;
        }
    */
    NSLog(@"_selectedAddress %@",_selectedAddress);
    if ( self.selectedAddress) {
        NSLog(@"onLocationConfirmed %@",_selectedAddress);
        if (self.onLocationConfirmed) {
            self.onLocationConfirmed(self.selectedAddress);
        }
        if (self.onCoordinateConfirmed) {
            NSString *resolvedTitle =
                [LocationPickerViewController titleFromAddress:self.selectedAddress];
            if (resolvedTitle.length == 0) {
                resolvedTitle = self.selectedLocationTitle;
            }
            self.onCoordinateConfirmed(self.selectedAddress.coordinate, resolvedTitle ?: @"");
        }
        if(self.rowDescriptor)
        {
            self.rowDescriptor.value = [LocationPickerViewController titleFromAddress:_selectedAddress];
            
            if ([self.delegate respondsToSelector:@selector(didSelectGMSAddress:forRowDescriptor:)]) {
                [self.delegate didSelectGMSAddress:_selectedAddress forRowDescriptor:self.rowDescriptor];
            }
           
        }

        [self pp_closePicker];
        return;
    }

    CLLocationCoordinate2D fallbackCoordinate = self.mapView.camera.target;
    if (!PPLocationPickerCoordinateIsUsable(fallbackCoordinate)) {
        fallbackCoordinate = self.lastKnownCoordinate;
    }
    if (PPLocationPickerCoordinateIsUsable(fallbackCoordinate)) {
        NSString *fallbackTitle = self.selectedLocationTitle.length > 0
            ? self.selectedLocationTitle
            : [self pp_fallbackTitleForCoordinate:fallbackCoordinate];
        BOOL handled = NO;
        if (self.onCoordinateConfirmed) {
            self.onCoordinateConfirmed(fallbackCoordinate, fallbackTitle);
            handled = YES;
        }
        if (self.rowDescriptor) {
            self.rowDescriptor.value = fallbackTitle;
            handled = YES;
        }
        if (handled) {
            [self pp_closePicker];
            return;
        }
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Select a location"
                                                                   message:@"Pan map to choose"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
+ (NSString *)titleFromAddress:(GMSAddress *)address {
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


- (void)shakeView:(UIView *)view {
    CABasicAnimation *shake = [CABasicAnimation animationWithKeyPath:@"position"];
    shake.duration = 0.05;
    shake.repeatCount = 4;
    shake.autoreverses = YES;
    shake.fromValue = [NSValue valueWithCGPoint:CGPointMake(view.center.x - 5, view.center.y)];
    shake.toValue = [NSValue valueWithCGPoint:CGPointMake(view.center.x + 5, view.center.y)];
    [view.layer addAnimation:shake forKey:@"position"];
}


#pragma mark - GMSMapViewDelegate

- (UIView *)mapView:(GMSMapView *)mapView markerInfoWindow:(GMSMarker *)marker {
    UIView *infoWindow = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 250, 60)];
    infoWindow.backgroundColor = GM.AppForegroundColor;
    infoWindow.layer.cornerRadius = 8;
    infoWindow.layer.borderWidth = 1;
    infoWindow.layer.borderColor = GM.AppShadowColor.CGColor;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(8, 8, 230, 44)];
   // label.text = marker.title ?: @"";
    label.numberOfLines = 2;
    label.font = [GM fontWithSize:14];
    [infoWindow addSubview:label];

    return infoWindow;
}

- (void)mapView:(GMSMapView *)mapView didEndDraggingMarker:(GMSMarker *)marker {
    [self reverseGeocodeCoordinate:marker.position];
}

- (void)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate {
    GMSGeocoder *geocoder = [[GMSGeocoder alloc] init];
    [geocoder reverseGeocodeCoordinate:coordinate completionHandler:^(GMSReverseGeocodeResponse *response, NSError *error) {
        if (response.firstResult) {
            NSString *address = response.firstResult.lines.firstObject;
            self.marker.title = address;
            [self.marker map]; // Force refresh of info window
            [self.mapView selectedMarker]; // Re-select to show new info window
        }
    }];
}

// Safer version: check for nil/empty path before using fileURLWithPath
- (void)applyDarkModeToMapView:(GMSMapView *)mapView {
    // Get path to the JSON file in the bundle
    NSString *stylePath = [[NSBundle mainBundle] pathForResource:@"map_dark_style" ofType:@"json"];
    if (stylePath.length == 0) {
        NSLog(@"❌ map_dark_style.json not found in main bundle. Make sure it is added to the app target and Copy Bundle Resources.");
        mapView.mapStyle = nil;
        return;
    }

    NSError *error = nil;
    NSURL *url = [NSURL fileURLWithPath:stylePath];
    GMSMapStyle *mapStyle = [GMSMapStyle styleWithContentsOfFileURL:url error:&error];
    if (!mapStyle) {
        NSLog(@"❌ Failed to load map style from %@: %@", stylePath, error.localizedDescription);
        mapView.mapStyle = nil;
        return;
    }

    mapView.mapStyle = mapStyle;
}


- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        [self applyDarkModeToMapView:self.mapView];
    } else {
        self.mapView.mapStyle = nil; // Remove style for light mode, or apply a light style
    }
}

@end

/*
 
 
 /Users/mohammedahmed/Desktop/PureData/Pure Pets Firebase/Pure Pets/MainApp/ModrenAppVC/PPHomeViewController.m:497 This method can cause UI unresponsiveness if invoked on the main thread. Instead, consider waiting for the `-locationManagerDidChangeAuthorization:` callback and checking `authorizationStatus` first.

 */
