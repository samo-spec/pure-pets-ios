//
//  CompanyLocationVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/07/2025.
//

#import "CompanyLocationVC.h"
#import <CoreLocation/CoreLocation.h>
#import <GoogleMaps/GoogleMaps.h>

static CLLocationCoordinate2D const kPPCompanyCoordinate = {25.168900, 51.608612};
static NSString * const kPPCompanyPhoneNumber = @"+97459997720";
static CGFloat const kPPChromeHorizontalInset = 16.0;

@interface CompanyLocationVC () <CLLocationManagerDelegate>
@property (nonatomic, strong) GMSMapView *mapView;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, assign) CLLocationCoordinate2D companyLocation;
@property (nonatomic, strong) LOTAnimationView *lottieView;
@property (nonatomic, strong) GMSPolyline *activePolyline;

@property (nonatomic, strong) UIView *topGradientView;
@property (nonatomic, strong) CAGradientLayer *topGradientLayer;
@property (nonatomic, strong) UIView *bottomGradientView;
@property (nonatomic, strong) CAGradientLayer *bottomGradientLayer;

@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIView *bottomView;
@property (nonatomic, strong) UILabel *etaLabel;
@property (nonatomic, strong) UIView *etaPillView;

@property (nonatomic, strong) UIButton *directionsButton;
@property (nonatomic, strong) UIButton *routePreviewButton;
@property (nonatomic, strong) UIButton *recenterButton;
@property (nonatomic, strong) UIButton *shareButton;

@property (nonatomic, assign) BOOL didRunEntranceAnimation;
@end

@implementation CompanyLocationVC

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.blackColor;
    self.companyLocation = kPPCompanyCoordinate;

    [self setupMap];
    [self setupGradientOverlays];
    [self setupHeaderView];
    [self setupBottomDock];
    [self setupLocationManager];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"supprot") showBack:YES];
    [self pp_setRootBottomNavigationHidden:YES animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    BOOL isLeavingLocationScreen =
        self.isMovingFromParentViewController ||
        self.isBeingDismissed ||
        self.navigationController.isBeingDismissed;
    if (!isLeavingLocationScreen) {
        return;
    }

    [self pp_setRootBottomNavigationHidden:NO animated:animated];
    id<UIViewControllerTransitionCoordinator> coordinator = self.transitionCoordinator;
    if (coordinator) {
        __weak typeof(self) weakSelf = self;
        [coordinator animateAlongsideTransition:nil
                                     completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            if (!context.isCancelled) {
                return;
            }
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }
            [self pp_setRootBottomNavigationHidden:YES animated:YES];
        }];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.didRunEntranceAnimation) {
        return;
    }

    self.didRunEntranceAnimation = YES;

    self.headerView.alpha = 0.0;
    self.headerView.transform = CGAffineTransformMakeTranslation(0, -18);
    self.bottomView.alpha = 0.0;
    self.bottomView.transform = CGAffineTransformMakeTranslation(0, 28);

    [UIView animateWithDuration:0.72
                          delay:0.02
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.25
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.headerView.alpha = 1.0;
        self.headerView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.74
                              delay:0.0
             usingSpringWithDamping:0.9
              initialSpringVelocity:0.25
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.bottomView.alpha = 1.0;
            self.bottomView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    self.topGradientLayer.frame = self.topGradientView.bounds;
    self.bottomGradientLayer.frame = self.bottomGradientView.bounds;

    CGFloat topInset = CGRectGetMaxY(self.headerView.frame) + 20.0;
    CGFloat bottomInset = MAX(CGRectGetHeight(self.view.bounds) - CGRectGetMinY(self.bottomView.frame) + 24.0, 170.0);
    self.mapView.padding = UIEdgeInsetsMake(topInset, 20, bottomInset, 20);

    self.headerView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.headerView.bounds cornerRadius:self.headerView.layer.cornerRadius].CGPath;
    self.bottomView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bottomView.bounds cornerRadius:self.bottomView.layer.cornerRadius].CGPath;
}

- (void)pp_setRootBottomNavigationHidden:(BOOL)hidden animated:(BOOL)animated
{
    UITabBarController *tabBarController = self.tabBarController;
    if ([tabBarController respondsToSelector:@selector(setPremiumTabDockViewHidden:animation:)]) {
        [(id)tabBarController setPremiumTabDockViewHidden:hidden animation:animated];
        return;
    }
    if ([tabBarController respondsToSelector:@selector(pp_setBottomNavigationHidden:animated:)]) {
        [(id)tabBarController pp_setBottomNavigationHidden:hidden animated:animated];
        return;
    }

    UITabBar *tabBar = tabBarController.tabBar;
    if (!tabBar) {
        return;
    }
    if (!hidden) {
        tabBar.hidden = NO;
    }

    void (^changes)(void) = ^{
        tabBar.alpha = hidden ? 0.0 : 1.0;
    };
    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        tabBar.hidden = hidden;
    };
    if (!animated) {
        changes();
        completion(YES);
        return;
    }
    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                     animations:changes
                     completion:completion];
}

#pragma mark - Setup

- (void)setupMap {
    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:self.companyLocation.latitude
                                                            longitude:self.companyLocation.longitude
                                                                 zoom:15.7];

    self.mapView = [GMSMapView mapWithFrame:CGRectZero camera:camera];
    self.mapView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mapView.myLocationEnabled = YES;
    self.mapView.settings.compassButton = NO;
    self.mapView.settings.indoorPicker = NO;
    self.mapView.settings.myLocationButton = NO;
    self.mapView.settings.rotateGestures = YES;
    self.mapView.settings.tiltGestures = YES;
    [self.view addSubview:self.mapView];

    [NSLayoutConstraint activateConstraints:@[
        [self.mapView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.mapView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.mapView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.mapView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self setupLottieView];

    GMSMarker *marker = [[GMSMarker alloc] init];
    marker.position = self.companyLocation;
    marker.title = @"Pure Pets";
    marker.appearAnimation = kGMSMarkerAnimationPop;
    marker.iconView = [self pp_makeMarkerView];
    marker.map = self.mapView;
}

- (void)setupLottieView {
    self.lottieView = [[LOTAnimationView alloc] init];
    self.lottieView.frame = CGRectMake(10, 2, 60, 80);
    self.lottieView.loopAnimation = YES;
    self.lottieView.contentMode = UIViewContentModeScaleAspectFit;
    self.lottieView.backgroundColor = UIColor.clearColor;

    [AppClasses fetchLottieJSONFromFirebasePath:@"LottieAnimations/myPin.json"
                                     completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || ![jsonDict isKindOfClass:[NSDictionary class]]) {
                NSLog(@"[CompanyLocationVC] pin animation fetch failed: %@", error.localizedDescription ?: @"Unknown error");
                return;
            }

            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            if (!composition) {
                NSLog(@"[CompanyLocationVC] failed to build pin animation");
                return;
            }

            [self.lottieView setSceneModel:composition];
            [self.lottieView playWithCompletion:nil];
        });
    }];
}

- (void)setupGradientOverlays {
    UIColor *primaryColor = GM.appPrimaryColor ?: [UIColor colorWithRed:0.20 green:0.55 blue:0.90 alpha:1.0];

    self.topGradientView = [[UIView alloc] init];
    self.topGradientView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topGradientView.userInteractionEnabled = NO;
    [self.view addSubview:self.topGradientView];

    self.topGradientLayer = [CAGradientLayer layer];
    self.topGradientLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:0.02 alpha:0.86].CGColor,
        (__bridge id)[primaryColor colorWithAlphaComponent:0.22].CGColor,
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor
    ];
    self.topGradientLayer.locations = @[@0.0, @0.45, @1.0];
    [self.topGradientView.layer addSublayer:self.topGradientLayer];

    self.bottomGradientView = [[UIView alloc] init];
    self.bottomGradientView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomGradientView.userInteractionEnabled = NO;
    [self.view addSubview:self.bottomGradientView];

    self.bottomGradientLayer = [CAGradientLayer layer];
    self.bottomGradientLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:0.02 alpha:0.30].CGColor,
        (__bridge id)[UIColor colorWithWhite:0.02 alpha:0.88].CGColor
    ];
    self.bottomGradientLayer.locations = @[@0.0, @0.35, @1.0];
    [self.bottomGradientView.layer addSublayer:self.bottomGradientLayer];

    [NSLayoutConstraint activateConstraints:@[
        [self.topGradientView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.topGradientView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.topGradientView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.topGradientView.heightAnchor constraintEqualToConstant:270],

        [self.bottomGradientView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomGradientView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomGradientView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.bottomGradientView.heightAnchor constraintEqualToConstant:280]
    ]];
}

- (void)setupHeaderView {
    UIView *contentView = nil;
    self.headerView = [self pp_makeGlassPanelWithCornerRadius:30.0
                                                    toneColor:[[GM appPrimaryColor] colorWithAlphaComponent:0.16]
                                                  contentView:&contentView];
    [self.view addSubview:self.headerView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.headerView.topAnchor constraintEqualToAnchor:safe.topAnchor constant:10],
        [self.headerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kPPChromeHorizontalInset],
        [self.headerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kPPChromeHorizontalInset]
    ]];

    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = 14;
    [contentView addSubview:contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [contentStack.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:18],
        [contentStack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:18],
        [contentStack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-18],
        [contentStack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-18]
    ]];

    PPInsetLabel *brandLabel = [self pp_makeCapsuleLabelWithText:@"PURE PETS"
                                                       textColor:[UIColor whiteColor]
                                                 backgroundColor:[[UIColor whiteColor] colorWithAlphaComponent:0.15]];
    PPInsetLabel *statusLabel = [self pp_makeCapsuleLabelWithText:[self pp_localizedEnglish:@"Customer support"
                                                                                      arabic:@"دعم العملاء"]
                                                        textColor:[[UIColor whiteColor] colorWithAlphaComponent:0.92]
                                                  backgroundColor:[[UIColor whiteColor] colorWithAlphaComponent:0.10]];

    UIStackView *topRow = [[UIStackView alloc] initWithArrangedSubviews:@[brandLabel, statusLabel]];
    topRow.axis = UILayoutConstraintAxisHorizontal;
    topRow.spacing = 8;
    topRow.alignment = UIStackViewAlignmentCenter;
    [contentStack addArrangedSubview:topRow];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.numberOfLines = 0;
    titleLabel.font = [GM boldFontWithSize:30];
    titleLabel.textColor = UIColor.whiteColor;
    titleLabel.text = kLang(@"companyLocate");
    [contentStack addArrangedSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.font = [GM MidFontWithSize:15];
    subtitleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.78];
    subtitleLabel.text = [self pp_localizedEnglish:@"Visit the store, preview the fastest route, or contact the team directly."
                                            arabic:@"زر المتجر، اعرض أسرع مسار، أو تواصل مع الفريق مباشرة."];
    [contentStack addArrangedSubview:subtitleLabel];

    UIView *addressRow = [self pp_makeMetaRowWithSymbol:@"mappin.and.ellipse"
                                                   text:kLang(@"companyAddress")];
    UIView *phoneRow = [self pp_makeMetaRowWithSymbol:@"phone.fill"
                                                 text:[PPFunc formattedPhoneNumber:kPPCompanyPhoneNumber]];
    [contentStack addArrangedSubview:addressRow];
    [contentStack addArrangedSubview:phoneRow];

    self.etaPillView = [[UIView alloc] init];
    self.etaPillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.etaPillView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12];
    self.etaPillView.layer.cornerRadius = 14;
    self.etaPillView.hidden = YES;
    self.etaPillView.alpha = 0.0;
    [contentStack addArrangedSubview:self.etaPillView];

    self.etaLabel = [[UILabel alloc] init];
    self.etaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.etaLabel.font = [GM MidFontWithSize:13];
    self.etaLabel.textColor = UIColor.whiteColor;
    self.etaLabel.numberOfLines = 2;
    [self.etaPillView addSubview:self.etaLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.etaLabel.topAnchor constraintEqualToAnchor:self.etaPillView.topAnchor constant:10],
        [self.etaLabel.leadingAnchor constraintEqualToAnchor:self.etaPillView.leadingAnchor constant:12],
        [self.etaLabel.trailingAnchor constraintEqualToAnchor:self.etaPillView.trailingAnchor constant:-12],
        [self.etaLabel.bottomAnchor constraintEqualToAnchor:self.etaPillView.bottomAnchor constant:-10]
    ]];

    self.directionsButton = [self pp_makePrimaryButtonWithTitle:[self pp_localizedEnglish:@"Open in Maps"
                                                                                  arabic:@"افتح في الخرائط"]
                                                     symbolName:@"arrow.triangle.turn.up.right.diamond.fill"
                                                       selector:@selector(startNavigationToCompany)];

    UIButton *callButton = [self pp_makeUtilityIconButtonWithSymbol:@"phone.fill"
                                                          assetName:nil
                                                           selector:@selector(callCompany)
                                                 accessibilityLabel:[self pp_localizedEnglish:@"Call the store"
                                                                                         arabic:@"اتصل بالمتجر"]];

    UIButton *supportChatButton = [self pp_makeUtilityIconButtonWithSymbol:@"message.fill"
                                                                  assetName:nil
                                                                   selector:@selector(openSupportChat)
                                                         accessibilityLabel:[self pp_localizedEnglish:@"Chat with support"
                                                                                                 arabic:@"محادثة الدعم"]];

    UIStackView *buttonsRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.directionsButton, callButton, supportChatButton]];
    buttonsRow.axis = UILayoutConstraintAxisHorizontal;
    buttonsRow.spacing = 10;
    buttonsRow.alignment = UIStackViewAlignmentFill;
    [contentStack addArrangedSubview:buttonsRow];

    [callButton.widthAnchor constraintEqualToConstant:54].active = YES;
    [supportChatButton.widthAnchor constraintEqualToConstant:54].active = YES;
    [self.directionsButton.heightAnchor constraintEqualToConstant:54].active = YES;
    [callButton.heightAnchor constraintEqualToConstant:54].active = YES;
    [supportChatButton.heightAnchor constraintEqualToConstant:54].active = YES;
}

- (void)setupBottomDock {
    UIView *contentView = nil;
    self.bottomView = [self pp_makeGlassPanelWithCornerRadius:28.0
                                                    toneColor:[[UIColor blackColor] colorWithAlphaComponent:0.18]
                                                  contentView:&contentView];
    [self.view addSubview:self.bottomView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.bottomView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kPPChromeHorizontalInset],
        [self.bottomView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kPPChromeHorizontalInset],
        [self.bottomView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12]
    ]];

    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = 12;
    [contentView addSubview:contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [contentStack.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:14],
        [contentStack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        [contentStack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
        [contentStack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-16]
    ]];

    UIView *handleContainer = [[UIView alloc] init];
    handleContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [contentStack addArrangedSubview:handleContainer];

    UIView *handle = [[UIView alloc] init];
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    handle.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.28];
    handle.layer.cornerRadius = 2.5;
    [handleContainer addSubview:handle];

    [NSLayoutConstraint activateConstraints:@[
        [handleContainer.heightAnchor constraintEqualToConstant:5],
        [handle.topAnchor constraintEqualToAnchor:handleContainer.topAnchor],
        [handle.bottomAnchor constraintEqualToAnchor:handleContainer.bottomAnchor],
        [handle.centerXAnchor constraintEqualToAnchor:handleContainer.centerXAnchor],
        [handle.widthAnchor constraintEqualToConstant:44],
        [handle.heightAnchor constraintEqualToConstant:5]
    ]];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.font = [GM boldFontWithSize:18];
    titleLabel.textColor = UIColor.whiteColor;
    titleLabel.text = [self pp_localizedEnglish:@"Quick tools" arabic:@"أدوات سريعة"];
    [contentStack addArrangedSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.font = [GM MidFontWithSize:13];
    subtitleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.74];
    subtitleLabel.text = [self pp_localizedEnglish:@"Preview the route for live ETA, jump back to your location, or share the store pin."
                                            arabic:@"اعرض المسار لمعرفة وقت الوصول، ارجع إلى موقعك، أو شارك دبوس المتجر."];
    [contentStack addArrangedSubview:subtitleLabel];

    UIView *routeTile = [self pp_makeDockActionWithSymbol:@"point.topleft.down.curvedto.point.bottomright.up.fill"
                                                    title:[self pp_localizedEnglish:@"Preview route" arabic:@"عرض المسار"]
                                                 selector:@selector(fetchAndDrawRoute)
                                               emphasized:YES
                                               storeButton:&_routePreviewButton];

    UIView *locationTile = [self pp_makeDockActionWithSymbol:@"location.fill"
                                                       title:[self pp_localizedEnglish:@"My location" arabic:@"موقعي"]
                                                    selector:@selector(recenterToUserLocation)
                                                  emphasized:NO
                                                  storeButton:&_recenterButton];

    UIView *shareTile = [self pp_makeDockActionWithSymbol:@"square.and.arrow.up"
                                                    title:[self pp_localizedEnglish:@"Share pin" arabic:@"مشاركة الموقع"]
                                                 selector:@selector(shareLocation)
                                               emphasized:NO
                                               storeButton:&_shareButton];

    UIStackView *actionsRow = [[UIStackView alloc] initWithArrangedSubviews:@[routeTile, locationTile, shareTile]];
    actionsRow.axis = UILayoutConstraintAxisHorizontal;
    actionsRow.alignment = UIStackViewAlignmentTop;
    actionsRow.distribution = UIStackViewDistributionFillEqually;
    actionsRow.spacing = 12;
    [contentStack addArrangedSubview:actionsRow];
}

- (void)setupLocationManager {
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
    [self.locationManager requestWhenInUseAuthorization];
    [self.locationManager startUpdatingLocation];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *location = locations.lastObject;
    if (!location) {
        return;
    }

    self.directionsButton.enabled = YES;
    self.routePreviewButton.enabled = YES;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"[CompanyLocationVC] location failed: %@", error.localizedDescription);
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager API_AVAILABLE(ios(14.0)) {
    if (manager.authorizationStatus == kCLAuthorizationStatusDenied ||
        manager.authorizationStatus == kCLAuthorizationStatusRestricted) {
        self.routePreviewButton.enabled = YES;
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        self.routePreviewButton.enabled = YES;
    }
}

#pragma mark - Actions

- (void)callCompany {
    NSString *phoneDigits = [[kPPCompanyPhoneNumber stringByReplacingOccurrencesOfString:@"+" withString:@""]
                             stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSURL *phoneURL = [NSURL URLWithString:[NSString stringWithFormat:@"tel://%@", phoneDigits]];
    if ([[UIApplication sharedApplication] canOpenURL:phoneURL]) {
        [[UIApplication sharedApplication] openURL:phoneURL options:@{} completionHandler:nil];
    } else {
        [self showAlert:[self pp_localizedEnglish:@"Calling is not available on this device."
                                           arabic:@"الاتصال غير متاح على هذا الجهاز."]];
    }
}

- (void)openSupportChat {
    [[ChManager sharedManager] openSupportChatFromController:self];
}

- (void)shareLocation {
    NSString *locationURL = [NSString stringWithFormat:@"https://www.google.com/maps?q=%.6f,%.6f+(Pure+Pets)",
                             self.companyLocation.latitude,
                             self.companyLocation.longitude];
    NSString *shareText = [self pp_localizedEnglish:@"Pure Pets location"
                                             arabic:@"موقع Pure Pets"];

    UIActivityViewController *shareVC = [[UIActivityViewController alloc] initWithActivityItems:@[shareText, locationURL]
                                                                          applicationActivities:nil];
    UIPopoverPresentationController *popover = shareVC.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.shareButton ?: self.view;
        popover.sourceRect = self.shareButton ? self.shareButton.bounds : self.view.bounds;
    }
    [self presentViewController:shareVC animated:YES completion:nil];
}

- (void)recenterToUserLocation {
    CLLocation *location = self.locationManager.location;
    if (!location) {
        [self showAlert:[self pp_localizedEnglish:@"We couldn't detect your current location yet."
                                           arabic:@"لم نتمكن من تحديد موقعك الحالي بعد."]];
        return;
    }

    GMSCameraUpdate *update = [GMSCameraUpdate setTarget:location.coordinate zoom:15.8];
    [self.mapView animateWithCameraUpdate:update];
}

- (void)fetchAndDrawRoute {
    CLLocation *userLocation = self.locationManager.location;
    if (!userLocation) {
        [self showAlert:[self pp_localizedEnglish:@"Turn on location access to preview the route."
                                           arabic:@"فعّل إذن الموقع لعرض المسار."]];
        return;
    }

    self.routePreviewButton.enabled = NO;
    [self pp_setETA:[self pp_localizedEnglish:@"Calculating route..."
                                       arabic:@"جار حساب المسار..."]
            animated:YES];

    NSString *apiKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"GMSApiKey"];
    NSString *urlString = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/directions/json?origin=%f,%f&destination=%f,%f&mode=driving&key=%@",
                           userLocation.coordinate.latitude,
                           userLocation.coordinate.longitude,
                           self.companyLocation.latitude,
                           self.companyLocation.longitude,
                           apiKey];

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        self.routePreviewButton.enabled = YES;
        [self showAlert:[self pp_localizedEnglish:@"Unable to build route request."
                                           arabic:@"تعذر إنشاء طلب المسار."]];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        (void)response;

        NSError *jsonError = nil;
        NSDictionary *json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError] : nil;
        NSArray *routes = [json[@"routes"] isKindOfClass:[NSArray class]] ? json[@"routes"] : @[];
        NSDictionary *route = routes.firstObject;
        NSArray *legs = [route[@"legs"] isKindOfClass:[NSArray class]] ? route[@"legs"] : @[];
        NSDictionary *leg = legs.firstObject;
        NSString *polyline = [route[@"overview_polyline"][@"points"] isKindOfClass:[NSString class]] ? route[@"overview_polyline"][@"points"] : nil;
        NSString *duration = [leg[@"duration"][@"text"] isKindOfClass:[NSString class]] ? leg[@"duration"][@"text"] : nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf.routePreviewButton.enabled = YES;

            if (error || jsonError || !route) {
                [strongSelf pp_setETA:nil animated:YES];
                [strongSelf showAlert:[strongSelf pp_localizedEnglish:@"Unable to load the route right now."
                                                               arabic:@"تعذر تحميل المسار الآن."]];
                return;
            }

            if (duration.length > 0) {
                NSString *etaText = [NSString stringWithFormat:@"%@ %@",
                                     [strongSelf pp_localizedEnglish:@"Estimated arrival:"
                                                               arabic:@"الوقت المتوقع للوصول:"],
                                     duration];
                [strongSelf pp_setETA:etaText animated:YES];
            } else {
                [strongSelf pp_setETA:nil animated:YES];
            }

            if (polyline.length > 0) {
                [strongSelf decodeAndDrawPolyline:polyline];
            }
        });
    }] resume];
}

- (void)startNavigationToCompany {
    NSString *nativeURLString = [NSString stringWithFormat:@"comgooglemaps://?daddr=%f,%f&directionsmode=driving",
                                 self.companyLocation.latitude,
                                 self.companyLocation.longitude];
    NSURL *nativeURL = [NSURL URLWithString:nativeURLString];
    UIApplication *application = [UIApplication sharedApplication];

    if ([application canOpenURL:nativeURL]) {
        [application openURL:nativeURL options:@{} completionHandler:nil];
        return;
    }

    NSString *webURLString = [NSString stringWithFormat:@"https://www.google.com/maps/dir/?api=1&destination=%f,%f",
                              self.companyLocation.latitude,
                              self.companyLocation.longitude];
    NSURL *webURL = [NSURL URLWithString:webURLString];
    [application openURL:webURL options:@{} completionHandler:nil];
}

#pragma mark - Route Drawing

- (NSArray<NSValue *> *)decodePolyline:(NSString *)encoded {
    NSMutableArray<NSValue *> *coords = [NSMutableArray array];
    NSInteger idx = 0;
    NSInteger length = encoded.length;
    NSInteger lat = 0;
    NSInteger lng = 0;

    while (idx < length) {
        NSInteger byte = 0;
        NSInteger shift = 0;
        NSInteger result = 0;

        do {
            byte = [encoded characterAtIndex:idx++] - 63;
            result |= (byte & 0x1F) << shift;
            shift += 5;
        } while (byte >= 0x20 && idx < length);

        NSInteger deltaLat = (result & 1) ? ~(result >> 1) : (result >> 1);
        lat += deltaLat;

        shift = 0;
        result = 0;

        do {
            byte = [encoded characterAtIndex:idx++] - 63;
            result |= (byte & 0x1F) << shift;
            shift += 5;
        } while (byte >= 0x20 && idx < length);

        NSInteger deltaLng = (result & 1) ? ~(result >> 1) : (result >> 1);
        lng += deltaLng;

        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(lat * 1e-5, lng * 1e-5);
        [coords addObject:[NSValue valueWithBytes:&coordinate objCType:@encode(CLLocationCoordinate2D)]];
    }

    return coords;
}

- (void)decodeAndDrawPolyline:(NSString *)encoded {
    NSArray<NSValue *> *points = [self decodePolyline:encoded];
    if (points.count == 0) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.activePolyline) {
            self.activePolyline.map = nil;
        }

        GMSMutablePath *path = [GMSMutablePath path];
        for (NSValue *value in points) {
            CLLocationCoordinate2D coordinate;
            [value getValue:&coordinate];
            [path addCoordinate:coordinate];
        }

        GMSPolyline *polyline = [GMSPolyline polylineWithPath:path];
        polyline.strokeColor = GM.appPrimaryColor ?: [UIColor systemBlueColor];
        polyline.strokeWidth = 6.0;
        polyline.geodesic = YES;
        polyline.map = self.mapView;
        self.activePolyline = polyline;

        GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithPath:path];
        GMSCameraUpdate *cameraUpdate = [GMSCameraUpdate fitBounds:bounds withPadding:72];
        [self.mapView animateWithCameraUpdate:cameraUpdate];
    });
}

#pragma mark - UI Helpers

- (UIView *)pp_makeGlassPanelWithCornerRadius:(CGFloat)cornerRadius
                                    toneColor:(UIColor *)toneColor
                                  contentView:(UIView **)contentViewOut {
    UIView *panel = [[UIView alloc] init];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.backgroundColor = UIColor.clearColor;
    panel.layer.cornerRadius = cornerRadius;
    [panel pp_setShadowColor:[UIColor blackColor]];
    panel.layer.shadowOpacity = 0.22;
    panel.layer.shadowOffset = CGSizeMake(0, 18);
    panel.layer.shadowRadius = 28;

    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.clipsToBounds = YES;
    blurView.layer.cornerRadius = cornerRadius;
    blurView.layer.borderWidth = 1.0;
    [blurView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.10]];
    [panel addSubview:blurView];

    UIView *toneView = [[UIView alloc] init];
    toneView.translatesAutoresizingMaskIntoConstraints = NO;
    toneView.backgroundColor = toneColor ?: [[UIColor blackColor] colorWithAlphaComponent:0.14];
    [blurView.contentView addSubview:toneView];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [blurView.contentView addSubview:contentView];

    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:panel.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor],

        [toneView.topAnchor constraintEqualToAnchor:blurView.contentView.topAnchor],
        [toneView.leadingAnchor constraintEqualToAnchor:blurView.contentView.leadingAnchor],
        [toneView.trailingAnchor constraintEqualToAnchor:blurView.contentView.trailingAnchor],
        [toneView.bottomAnchor constraintEqualToAnchor:blurView.contentView.bottomAnchor],

        [contentView.topAnchor constraintEqualToAnchor:blurView.contentView.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:blurView.contentView.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:blurView.contentView.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:blurView.contentView.bottomAnchor]
    ]];

    if (contentViewOut) {
        *contentViewOut = contentView;
    }

    return panel;
}

- (UIView *)pp_makeMarkerView {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 80, 92)];
    container.backgroundColor = UIColor.clearColor;

    UIView *glowView = [[UIView alloc] initWithFrame:CGRectMake(16, 18, 48, 48)];
    UIColor *accentColor = GM.appPrimaryColor ?: [UIColor systemBlueColor];
    glowView.backgroundColor = [accentColor colorWithAlphaComponent:0.20];
    glowView.layer.cornerRadius = 24;
    [container addSubview:glowView];

    UIView *innerGlowView = [[UIView alloc] initWithFrame:CGRectMake(24, 26, 32, 32)];
    innerGlowView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.18];
    innerGlowView.layer.cornerRadius = 16;
    [container addSubview:innerGlowView];

    [container addSubview:self.lottieView];
    return container;
}

- (PPInsetLabel *)pp_makeCapsuleLabelWithText:(NSString *)text
                                    textColor:(UIColor *)textColor
                              backgroundColor:(UIColor *)backgroundColor {
    PPInsetLabel *label = [[PPInsetLabel alloc] init];
    label.textInsets = UIEdgeInsetsMake(7, 12, 7, 12);
    label.font = [GM boldFontWithSize:11];
    label.text = text;
    label.textColor = textColor;
    label.backgroundColor = backgroundColor;
    label.layer.cornerRadius = 14;
    label.clipsToBounds = YES;
    return label;
}

- (UIView *)pp_makeMetaRowWithSymbol:(NSString *)symbolName text:(NSString *)text {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbolName]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.92];
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM MidFontWithSize:14];
    label.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.84];
    label.numberOfLines = 0;
    label.text = text;

    [row addSubview:iconView];
    [row addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [iconView.topAnchor constraintEqualToAnchor:row.topAnchor constant:1],
        [iconView.widthAnchor constraintEqualToConstant:16],
        [iconView.heightAnchor constraintEqualToConstant:16],

        [label.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:10],
        [label.topAnchor constraintEqualToAnchor:row.topAnchor],
        [label.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [label.bottomAnchor constraintEqualToAnchor:row.bottomAnchor]
    ]];

    return row;
}

- (UIButton *)pp_makePrimaryButtonWithTitle:(NSString *)title
                                 symbolName:(NSString *)symbolName
                                   selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = 18;
    button.layer.masksToBounds = YES;
    button.backgroundColor = GM.appPrimaryColor ?: [UIColor systemBlueColor];
    button.tintColor = UIColor.whiteColor;
    button.titleLabel.font = [GM boldFontWithSize:15];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];

    UIImage *image = [UIImage systemImageNamed:symbolName];
    [button setImage:image forState:UIControlStateNormal];
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
        configuration.baseForegroundColor = UIColor.whiteColor;
        configuration.image = image;
        configuration.imagePadding = 8;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(16, 18, 16, 18);
        configuration.title = title;
        button.configuration = configuration;
    } else {
        button.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
        button.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
        button.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, -8);
    }

    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)pp_makeUtilityIconButtonWithSymbol:(NSString * _Nullable)symbolName
                                       assetName:(NSString * _Nullable)assetName
                                        selector:(SEL)selector
                              accessibilityLabel:(NSString *)accessibilityLabel {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12];
    button.layer.cornerRadius = 18;
    button.tintColor = UIColor.whiteColor;

    UIImage *image = nil;
    if (symbolName.length > 0) {
        image = [UIImage systemImageNamed:symbolName];
    } else if (assetName.length > 0) {
        image = [[UIImage imageNamed:assetName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    [button setImage:image forState:UIControlStateNormal];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    button.accessibilityLabel = accessibilityLabel;
    return button;
}

- (UIView *)pp_makeDockActionWithSymbol:(NSString *)symbolName
                                  title:(NSString *)title
                               selector:(SEL)selector
                             emphasized:(BOOL)emphasized
                             storeButton:(UIButton * __strong *)buttonStorage {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = 22;
    button.layer.masksToBounds = YES;
    button.backgroundColor = emphasized ? (GM.appPrimaryColor ?: [UIColor systemBlueColor]) : [[UIColor whiteColor] colorWithAlphaComponent:0.10];
    button.tintColor = UIColor.whiteColor;
    [button setImage:[UIImage systemImageNamed:symbolName] forState:UIControlStateNormal];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [GM MidFontWithSize:12];
    label.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.86];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 2;
    label.text = title;

    [container addSubview:button];
    [container addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [button.topAnchor constraintEqualToAnchor:container.topAnchor],
        [button.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [button.widthAnchor constraintEqualToConstant:44],
        [button.heightAnchor constraintEqualToConstant:44],

        [label.topAnchor constraintEqualToAnchor:button.bottomAnchor constant:8],
        [label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [label.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [label.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    if (buttonStorage) {
        *buttonStorage = button;
    }

    return container;
}

- (NSString *)pp_localizedEnglish:(NSString *)english arabic:(NSString *)arabic {
    return [Language isRTL] ? arabic : english;
}

- (void)pp_setETA:(nullable NSString *)etaText animated:(BOOL)animated {
    BOOL shouldShow = etaText.length > 0;

    if (!shouldShow) {
        if (self.etaPillView.hidden) {
            return;
        }

        void (^hideBlock)(void) = ^{
            self.etaPillView.alpha = 0.0;
            self.etaPillView.transform = CGAffineTransformMakeScale(0.96, 0.96);
        };

        void (^completion)(BOOL) = ^(BOOL finished) {
            self.etaPillView.hidden = YES;
            self.etaLabel.text = nil;
            self.etaPillView.transform = CGAffineTransformIdentity;
        };

        if (animated) {
            [UIView animateWithDuration:0.2 animations:hideBlock completion:completion];
        } else {
            hideBlock();
            completion(YES);
        }
        return;
    }

    self.etaLabel.text = etaText;

    if (!self.etaPillView.hidden) {
        return;
    }

    self.etaPillView.hidden = NO;
    self.etaPillView.alpha = animated ? 0.0 : 1.0;
    self.etaPillView.transform = animated ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;

    if (animated) {
        [UIView animateWithDuration:0.24
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.etaPillView.alpha = 1.0;
            self.etaPillView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

#pragma mark - Alerts

- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self pp_localizedEnglish:@"Location"
                                                                                             arabic:@"الموقع"]
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"done")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
