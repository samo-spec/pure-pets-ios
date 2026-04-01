//
//  PPVetLocator 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/09/2025.
//


// PPVetLocator.m
#import "PPVetLocator.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import "PPVetCell.h"
#import "PPMapPreviewCell.h"

static NSTimeInterval const kLocationTimeout = 8.0;
static CLLocationCoordinate2D const kSampleLocationCoordinate = {30.0444, 31.2357}; // Cairo center — change if you want

@interface PPVetLocator () <CLLocationManagerDelegate, UITableViewDelegate, UITableViewDataSource, MKMapViewDelegate>
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLLocation *currentLocation;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSArray<MKMapItem *> *mapItems;
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<MKMapItem *> *> *sections;
@property (nonatomic, strong) NSArray<NSString *> *sectionTitles;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSTimer *locationTimer;
@end

@implementation PPVetLocator

#pragma mark - Lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"[PPVETLOCATOR] viewDidLoad");
    if(!PPIOS26())
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    

    [self setupTableView];
    [self setupStatusViews];
    [self setupLocationManagerAndRequest];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.locationTimer invalidate];
    self.locationTimer = nil;
    
    
}


-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    //[self pp_navBarSetTitle:kLang(@"KLang_Title")];
    //[self pp_navBarSetLeftIcon:@"multiply" key:kPPKeyBaseBack target:self action:@selector(fullscreenCloseTapped:) tap:^{ }];
}
#pragma mark - Setup UI
- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.separatorColor = AppClearClr;
    self.tableView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.0];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self.tableView registerClass:[PPVetCell class] forCellReuseIdentifier:[PPVetCell reuseIdentifier]];
    [self.tableView registerClass:[PPMapPreviewCell class] forCellReuseIdentifier:[PPMapPreviewCell reuseIdentifier]];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;

    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(pullToRefreshTriggered) forControlEvents:UIControlEventValueChanged];
    if (@available(iOS 10.0, *)) {
        self.tableView.refreshControl = self.refreshControl;
    } else {
        [self.tableView addSubview:self.refreshControl];
    }
}

- (void)setupStatusViews {
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:self.statusLabel];
    [self.view addSubview:self.spinner];

    [NSLayoutConstraint activateConstraints:@[
        [self.statusLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-20],
        [self.statusLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.spinner.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:12],
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    ]];

    self.statusLabel.hidden = YES;
    self.spinner.hidden = YES;
}

#pragma mark - Location
- (void)setupLocationManagerAndRequest {
    NSLog(@"[PPVETLOCATOR] setupLocationManagerAndRequest");
    if (![CLLocationManager locationServicesEnabled]) {
        NSLog(@"[PPVETLOCATOR] Location services disabled");
        [self showStatus:NSLocalizedString(@"KLang_LocationDisabled", @"Location services are disabled. Please enable them in Settings.") showSpinner:NO showAction:YES];
        return;
    }

    self.locationManager = [CLLocationManager new];
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;

    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = self.locationManager.authorizationStatus;
    } else {
        status = [CLLocationManager authorizationStatus];
    }

    if (status == kCLAuthorizationStatusNotDetermined) {
        NSLog(@"[PPVETLOCATOR] Requesting when-in-use authorization");
        [self.locationManager requestWhenInUseAuthorization];
        [self showStatus:NSLocalizedString(@"KLang_LocationWaiting", @"Waiting for location permission...") showSpinner:YES showAction:NO];
    } else {
        [self handleAuthorizationStatus:status];
    }
}

- (void)handleAuthorizationStatus:(CLAuthorizationStatus)status {
    NSLog(@"[PPVETLOCATOR] Authorization status: %d", (int)status);
    switch (status) {
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse: {
            [self startUpdatingLocation];
            break;
        }
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted: {
            [self showStatus:NSLocalizedString(@"KLang_LocationDenied", @"Location permission denied. Open Settings to allow access.") showSpinner:NO showAction:YES];
            break;
        }
        default:
            [self showStatus:NSLocalizedString(@"KLang_LocationWaiting", @"Waiting for location permission...") showSpinner:YES showAction:NO];
            break;
    }
}

- (void)startUpdatingLocation {
    NSLog(@"[PPVETLOCATOR] startUpdatingLocation");
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.hidden = YES;
        [self.spinner startAnimating];
        self.spinner.hidden = NO;
    });
    [self.locationManager startUpdatingLocation];

    // start timeout to avoid infinite wait in simulator
    [self.locationTimer invalidate];
    self.locationTimer = [NSTimer scheduledTimerWithTimeInterval:kLocationTimeout target:self selector:@selector(locationTimeoutFired) userInfo:nil repeats:NO];
}

- (void)locationTimeoutFired {
    NSLog(@"[PPVETLOCATOR] location timeout fired");
    [self.locationManager stopUpdatingLocation];
    [self.spinner stopAnimating];
    self.spinner.hidden = YES;
    [self showStatus:NSLocalizedString(@"KLang_LocationTimeout", @"Taking too long to get location. Try again or use sample location.") showSpinner:NO showAction:YES];
}

#pragma mark - CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    NSLog(@"[PPVETLOCATOR] didChangeAuthorizationStatus: %d", (int)status);
    [self handleAuthorizationStatus:status];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager API_AVAILABLE(ios(14.0)){
    CLAuthorizationStatus status = manager.authorizationStatus;
    NSLog(@"[PPVETLOCATOR] locationManagerDidChangeAuthorization: %d", (int)status);
    [self handleAuthorizationStatus:status];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"[PPVETLOCATOR] locationManager didFailWithError: %@", error);
    [self.locationTimer invalidate];
    self.locationTimer = nil;
    [self showStatus:NSLocalizedString(@"KLang_LocationFailed", @"Unable to determine location.") showSpinner:NO showAction:YES];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *loc = locations.lastObject;
    if (!loc) return;
    NSLog(@"[PPVETLOCATOR] got location: %.6f, %.6f", loc.coordinate.latitude, loc.coordinate.longitude);
    self.currentLocation = loc;
    [self.locationTimer invalidate];
    self.locationTimer = nil;
    [self.locationManager stopUpdatingLocation];
    [self.spinner stopAnimating];
    self.spinner.hidden = YES;

    [self fetchNearbyVetsUsingMapKitAtLocation:loc];
}

#pragma mark - Pull to refresh
- (void)pullToRefreshTriggered {
    NSLog(@"[PPVETLOCATOR] pullToRefreshTriggered");
    if (self.currentLocation) {
        [self fetchNearbyVetsUsingMapKitAtLocation:self.currentLocation];
    } else {
        [self setupLocationManagerAndRequest];
    }
    [self.refreshControl endRefreshing];
}

#pragma mark - MKLocalSearch
- (void)fetchNearbyVetsUsingMapKitAtLocation:(CLLocation *)location {
    NSLog(@"[PPVETLOCATOR] fetchNearbyVetsUsingMapKitAtLocation");
    [self showStatus:NSLocalizedString(@"KLang_Searching", @"Searching nearby vets...") showSpinner:YES showAction:NO];

    MKLocalSearchRequest *request = [MKLocalSearchRequest new];
    request.naturalLanguageQuery = [Language isRTL] ? @"عيادة بيطرية" : @"veterinarian";
    request.region = MKCoordinateRegionMakeWithDistance(location.coordinate, 15000, 15000);

    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    [search startWithCompletionHandler:^(MKLocalSearchResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || response.mapItems.count == 0) {
                NSLog(@"[PPVETLOCATOR] MKLocalSearch error: %@ items: %lu", error, (unsigned long)response.mapItems.count);
                self.mapItems = @[];
                self.sections = @{};
                self.sectionTitles = @[];
                [self.tableView reloadData];
                [self showStatus:NSLocalizedString(@"KLang_NoResults", @"No nearby vets found.") showSpinner:NO showAction:YES];
                return;
            }
            NSLog(@"[PPVETLOCATOR] MKLocalSearch results: %lu", (unsigned long)response.mapItems.count);
            self.mapItems = response.mapItems;
            [self groupResultsByDistanceAndReload];
        });
    }];
}

#pragma mark - Grouping
- (void)groupResultsByDistanceAndReload {
    NSLog(@"[PPVETLOCATOR] groupResultsByDistanceAndReload");
    if (!self.currentLocation || self.mapItems.count == 0) {
        [self showStatus:NSLocalizedString(@"KLang_NoResults", @"No nearby vets found.") showSpinner:NO showAction:YES];
        return;
    }

    NSMutableArray<MKMapItem *> *near = [NSMutableArray array];
    NSMutableArray<MKMapItem *> *mid = [NSMutableArray array];
    NSMutableArray<MKMapItem *> *far = [NSMutableArray array];

    for (MKMapItem *item in self.mapItems) {
        CLLocation *loc = [[CLLocation alloc] initWithLatitude:item.placemark.coordinate.latitude longitude:item.placemark.coordinate.longitude];
        CLLocationDistance d = [loc distanceFromLocation:self.currentLocation];
        if (d <= 1000) {
            [near addObject:item];
        } else if (d <= 5000) {
            [mid addObject:item];
        } else {
            [far addObject:item];
        }
        NSLog(@"[PPVETLOCATOR] item: %@ distance: %.0f meters", item.name, d);
    }

    NSMutableDictionary *s = [NSMutableDictionary dictionary];
    NSMutableArray *titles = [NSMutableArray array];

    if (near.count) { s[@"<1km"] = near; [titles addObject:@"<1km"]; }
    if (mid.count)  { s[@"1-5km"] = mid;  [titles addObject:@"1-5km"]; }
    if (far.count)  { s[@">5km"] = far;   [titles addObject:@">5km"]; }

    self.sections = s;
    self.sectionTitles = titles;
    self.statusLabel.hidden = YES;
    self.spinner.hidden = YES;
    [self.tableView reloadData];
}

#pragma mark - UI Helpers
- (void)showStatus:(NSString *)msg showSpinner:(BOOL)show showAction:(BOOL)showAction {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = msg;
        self.statusLabel.hidden = NO;
        if (show) {
            [self.spinner startAnimating];
            self.spinner.hidden = NO;
        } else {
            [self.spinner stopAnimating];
            self.spinner.hidden = YES;
        }

        // Table is visible if we have results
        BOOL haveResults = (self.mapItems.count > 0);
        self.tableView.hidden = NO; // always show table (map preview cell handles empty)
        [self.tableView reloadData];

        if (showAction) {
            // add a small toolbar-like action under status (Retry / Use Sample)
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"KLang_Retry", @"Retry") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSLog(@"[PPVETLOCATOR] user tapped Retry");
                [self setupLocationManagerAndRequest];
            }]];
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"KLang_UseSampleLocation", @"Use Sample Location") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSLog(@"[PPVETLOCATOR] user tapped Use Sample Location");
                CLLocation *c = [[CLLocation alloc] initWithLatitude:kSampleLocationCoordinate.latitude longitude:kSampleLocationCoordinate.longitude];
                self.currentLocation = c;
                [self fetchNearbyVetsUsingMapKitAtLocation:c];
            }]];
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"KLang_Cancel", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:ac animated:YES completion:nil];
        }
    });
}

#pragma mark - TableView datasource / delegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Section 0 is always the map preview
    return 1 + self.sectionTitles.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @""; // no header for map preview
    NSString *key = self.sectionTitles[section - 1];
    if ([key isEqualToString:@"<1km"]) return kLang(@"KLang_Section_Near");
    if ([key isEqualToString:@"1-5km"]) return kLang(@"KLang_Section_Mid" );
    return kLang(@"KLang_Section_Far" );
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1; // map preview
    NSString *key = self.sectionTitles[section - 1];
    NSArray *arr = self.sections[key];
    return arr.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) return 200; // map preview height
    return 130;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        PPMapPreviewCell *cell = [tv dequeueReusableCellWithIdentifier:[PPMapPreviewCell reuseIdentifier] forIndexPath:indexPath];
        [cell updatePins:self.mapItems userLocation:self.currentLocation];
        return cell;
    }

    PPVetCell *cell = [tv dequeueReusableCellWithIdentifier:[PPVetCell reuseIdentifier] forIndexPath:indexPath];
    MKMapItem *item = [self mapItemForIndexPath:indexPath];
    NSString *name = item.name ?: kLang(@"KLang_Unknown");
    NSString *desc = item.placemark.title ?: @"";
    BOOL hasPhone = (item.phoneNumber != nil && item.phoneNumber.length > 0);
    [cell configureWithName:name description:desc hasPhone:hasPhone];

    __weak typeof(self) weak = self;
    cell.onCall = ^(UITableViewCell *c) {
        __strong typeof(weak) strong = weak;
        [strong makeCallForMapItem:item];
    };
    cell.onDirections = ^(UITableViewCell *c) {
        __strong typeof(weak) strong = weak;
        [strong openDirectionsForMapItem:item];
    };

    return cell;
}

- (MKMapItem *)mapItemForIndexPath:(NSIndexPath *)indexPath {
    NSString *key = self.sectionTitles[indexPath.section - 1];
    NSArray *arr = self.sections[key];
    return arr[indexPath.row];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
   [tableView deselectRowAtIndexPath:indexPath animated:YES];
   if (indexPath.section == 0) return;
   MKMapItem *item = [self mapItemForIndexPath:indexPath];
   [self showFullscreenMapForMapItem:item];
}

#pragma mark - Call & Directions
- (void)makeCallForMapItem:(MKMapItem *)item {
    NSString *phone = item.phoneNumber;
    if (!phone || phone.length == 0) {
        NSLog(@"[PPVETLOCATOR] No phone available for %@", item.name);
        [self showSimpleAlertWithTitle:NSLocalizedString(@"KLang_NoPhoneTitle", @"No phone") message:NSLocalizedString(@"KLang_NoPhoneMsg", @"Phone number not available.")];
        return;
    }
    NSString *digits = [[phone componentsSeparatedByCharactersInSet:
                         [[NSCharacterSet decimalDigitCharacterSet] invertedSet]] componentsJoinedByString:@""];
    NSString *tel = [NSString stringWithFormat:@"tel://%@", digits];
    NSURL *url = [NSURL URLWithString:tel];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        NSLog(@"[PPVETLOCATOR] making call to %@", phone);
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
            NSLog(@"[PPVETLOCATOR] call opened: %d", success);
        }];
    } else {
        NSLog(@"[PPVETLOCATOR] cannot open tel URL");
        [self showSimpleAlertWithTitle:NSLocalizedString(@"KLang_CannotCallTitle", @"Cannot Call") message:NSLocalizedString(@"KLang_CannotCallMsg", @"Unable to initiate call on this device.")];
    }
}

- (void)openDirectionsForMapItem:(MKMapItem *)item {
    MKPlacemark *placemark = item.placemark;
    MKMapItem *dest = [[MKMapItem alloc] initWithPlacemark:placemark];
    dest.name = item.name;
    NSDictionary *options = @{ MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDriving };
    NSLog(@"[PPVETLOCATOR] opening directions to %@", item.name);
    [dest openInMapsWithLaunchOptions:options];
}

#pragma mark - Fullscreen map


- (void)showFullscreenMapForMapItem:(MKMapItem *)item {
    NSLog(@"[PPVETLOCATOR] showFullscreenMapForMapItem: %@", item.name);
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = [UIColor systemBackgroundColor];
    vc.title = item.name ?: kLang(@"KLang_Unknown");

    // Map
    MKMapView *map = [[MKMapView alloc] initWithFrame:CGRectZero];
    map.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:map];
    [NSLayoutConstraint activateConstraints:@[
        [map.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor],
        [map.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor],
        [map.topAnchor constraintEqualToAnchor:vc.view.topAnchor],
        [map.bottomAnchor constraintEqualToAnchor:vc.view.bottomAnchor],
    ]];

    // Annotation
    MKPointAnnotation *ann = [MKPointAnnotation new];
    ann.coordinate = item.placemark.coordinate;
    ann.title = item.name;
    ann.subtitle = item.placemark.title;
    [map addAnnotation:ann];

    MKCoordinateRegion r = MKCoordinateRegionMakeWithDistance(item.placemark.coordinate, 2000, 2000);
    [map setRegion:r animated:NO];

    // ✅ Add "Directions" button
    UIBarButtonItem *dir = [[UIBarButtonItem alloc] initWithTitle:kLang(@"KLang_Directions")
                                                            style:UIBarButtonItemStylePlain
                                                           target:self
                                                           action:@selector(fullscreenDirectionsTapped:)];
    vc.navigationItem.rightBarButtonItem = dir;

    // ✅ Add "Close" (back) button
    UIBarButtonItem *close = [[UIBarButtonItem alloc] initWithTitle:kLang(@"KLang_Close")
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(fullscreenCloseTapped:)];
    vc.navigationItem.leftBarButtonItem = close;

    // Store item
    objc_setAssociatedObject(vc, "PPVETLOCATOR_MAPITEM", item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Wrap in nav controller
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)fullscreenCloseTapped:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}



/*
 UIButton *directionsBtn = [PPButtonHelper pp_buttonWithTitle:kLang(@"KLang_Directions")
                                                imageName:nil
                                                   target:self
                                                   action:@selector(fullscreenDirectionsTapped:)];
 [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:directionsBtn title:NSLocalizedString(@"KLang_Title", @"Nearby Vets") showBack:YES];
 */
/*
 UIButton *directionsBtn = [PPButtonHelper pp_buttonWithTitle:kLang(@"KLang_Directions")
                                                imageName:nil
                                                   target:self
                                                   action:@selector(fullscreenDirectionsTapped:)];
 [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:directionsBtn title:NSLocalizedString(@"KLang_Title", @"Nearby Vets") showBack:YES];
 */
- (void)fullscreenDirectionsTapped:(id)sender {
    UIViewController *vc = (UIViewController *)self.presentedViewController;
    if (!vc) return;
    MKMapItem *item = objc_getAssociatedObject(vc, "PPVETLOCATOR_MAPITEM");
    if (!item) return;
    [self openDirectionsForMapItem:item];
}

#pragma mark - Helpers
- (void)showSimpleAlertWithTitle:(NSString *)title message:(NSString *)msg {
    NSLog(@"[PPVETLOCATOR] showSimpleAlert: %@ - %@", title, msg);
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:kLang(@"KLang_OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

@end
