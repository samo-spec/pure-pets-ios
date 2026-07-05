//
//  CompanyLocationVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 13/07/2025.
//

#import "CompanyLocationVC.h"
#import "UIViewController+PPBottomSurface.h"
#import <CoreLocation/CoreLocation.h>
#import <GoogleMaps/GoogleMaps.h>

static CLLocationCoordinate2D const kPPCompanyCoordinate = {25.168900, 51.608612};
static NSString * const kPPCompanyPhoneNumber = @"+97459997720";
static CGFloat const kPPLocationHorizontalInset = 18.0;
static CGFloat const kPPLocationSheetRadius = 30.0;
static CGFloat const kPPLocationButtonCornerRadius = 18.0;

static inline UIColor *PPLocationAccentColor(void)
{
    return GM.appPrimaryColor ?: [UIColor colorWithRed:0.89 green:0.12 blue:0.36 alpha:1.0];
}

static inline UIColor *PPLocationSurfaceColor(void)
{
    return [UIColor colorWithRed:0.98 green:0.97 blue:0.95 alpha:0.42];
}

static inline UIColor *PPLocationPrimaryTextColor(void)
{
    return [UIColor colorWithRed:0.13 green:0.14 blue:0.18 alpha:1.0];
}

static inline UIColor *PPLocationSecondaryTextColor(void)
{
    return [UIColor colorWithRed:0.39 green:0.41 blue:0.46 alpha:1.0];
}

static inline UIFont *PPLocationScaledFont(UIFont *font, UIFontTextStyle textStyle)
{
    if (!font) {
        return nil;
    }
    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:font];
    }
    return font;
}

static inline void PPLocationApplyCornerRadius(UIView *view, CGFloat radius)
{
    if (!view) {
        return;
    }

    view.layer.cornerRadius = radius;
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
    if (@available(iOS 15.0, *)) {
        if ([view isKindOfClass:UIButton.class]) {
            UIButton *button = (UIButton *)view;
            UIButtonConfiguration *configuration = button.configuration;
            if (configuration) {
                configuration.background.cornerRadius = radius;
                configuration.cornerStyle = UIButtonConfigurationCornerStyleFixed;
                button.configuration = configuration;
            }
        }
    }
}

@interface CompanyLocationVC () <CLLocationManagerDelegate>

@property (nonatomic, strong) GMSMapView *mapView;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, assign) CLLocationCoordinate2D companyLocation;
@property (nonatomic, strong) GMSMarker *companyMarker;
@property (nonatomic, strong) GMSPolyline *activePolyline;
@property (nonatomic, strong) GMSPolyline *routeGlowPolyline;

@property (nonatomic, strong) UIView *topGlowView;
@property (nonatomic, strong) UIView *bottomGlowView;
@property (nonatomic, strong) CAGradientLayer *topGlowLayer;
@property (nonatomic, strong) CAGradientLayer *bottomGlowLayer;
@property (nonatomic, strong) UIView *topScrimView;
@property (nonatomic, strong) UIView *bottomScrimView;
@property (nonatomic, strong) CAGradientLayer *topScrimLayer;
@property (nonatomic, strong) CAGradientLayer *bottomScrimLayer;

@property (nonatomic, strong) UIView *sheetView;
@property (nonatomic, strong) UILabel *sheetTitleLabel;
@property (nonatomic, strong) UILabel *sheetSubtitleLabel;
@property (nonatomic, strong) UILabel *routeStatusTitleLabel;
@property (nonatomic, strong) UILabel *routeStatusValueLabel;
@property (nonatomic, strong) UIView *routeStatusIconPlateView;

@property (nonatomic, strong) UIButton *openMapsButton;
@property (nonatomic, strong) UIButton *previewRouteButton;
@property (nonatomic, strong) UIButton *recenterButton;
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UIButton *supportButton;
@property (nonatomic, strong) UIButton *shareButton;

@property (nonatomic, strong) NSArray<UIView *> *heroEntranceViews;
@property (nonatomic, strong) NSArray<UIView *> *sheetEntranceViews;
@property (nonatomic, strong) UIView *markerView;
@property (nonatomic, strong) UIView *markerCalloutView;
@property (nonatomic, strong) UILabel *markerEyebrowLabel;
@property (nonatomic, strong) UILabel *markerTitleLabel;

@property (nonatomic, assign) BOOL isLoadingRoute;
@property (nonatomic, assign) BOOL didPrepareEntrance;
@property (nonatomic, assign) BOOL didRunEntrance;

@end

@implementation CompanyLocationVC

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.companyLocation = kPPCompanyCoordinate;
    self.view.backgroundColor = PPLocationSurfaceColor();
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    [self pp_setupMap];
    [self pp_setupAmbientBackground];
    [self pp_setupBottomSheet];
    [self pp_updateLocalizedCopy];
    [self pp_registerButtonFeedback];
    [self setupLocationManager];
    [self pp_setRouteStatusTitleKey:@"company_location_ready_title"
                      detailTextKey:@"company_location_eta_placeholder"
                      detailOverride:nil
                        accentTint:[PPLocationAccentColor() colorWithAlphaComponent:0.14]];
    [self pp_refreshActionAvailability];
    [self pp_prepareEntranceStateIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto
                      button:nil
                       title:@""
                    showBack:YES];
    [self pp_applyBottomSurfaceAnimated:animated];
    [self pp_prepareEntranceStateIfNeeded];
    [self pp_startLocationUpdatesIfNeeded];
    [self pp_applyAmbientMotionIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_applyBottomSurfaceAnimated:animated];
    [self pp_runEntranceIfNeeded];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    BOOL leavingScreen = self.isMovingFromParentViewController ||
    self.isBeingDismissed ||
    self.navigationController.isBeingDismissed;
    if (leavingScreen) {
        [self.locationManager stopUpdatingLocation];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    if (self.topGlowView) {
        self.topGlowLayer.frame = self.topGlowView.bounds;
    }
    self.bottomGlowLayer.frame = self.bottomGlowView.bounds;
    self.topScrimLayer.frame = self.topScrimView.bounds;
    self.bottomScrimLayer.frame = self.bottomScrimView.bounds;

    self.sheetView.layer.shadowPath =
    [UIBezierPath bezierPathWithRoundedRect:self.sheetView.bounds cornerRadius:self.sheetView.layer.cornerRadius].CGPath;
    self.markerCalloutView.layer.shadowPath =
    [UIBezierPath bezierPathWithRoundedRect:self.markerCalloutView.bounds cornerRadius:self.markerCalloutView.layer.cornerRadius].CGPath;

    CGFloat topInset = self.view.safeAreaInsets.top + 24.0;
    CGFloat bottomInset = MAX(CGRectGetHeight(self.view.bounds) - CGRectGetMinY(self.sheetView.frame) + 30.0, 250.0);
    self.mapView.padding = UIEdgeInsetsMake(topInset, 24.0, bottomInset, 24.0);
}

#pragma mark - Setup

- (void)pp_setupMap
{
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
    self.mapView.settings.scrollGestures = YES;
    self.mapView.settings.zoomGestures = YES;
    [self pp_applyPremiumMapStyle];
    [self.view addSubview:self.mapView];

    [NSLayoutConstraint activateConstraints:@[
        [self.mapView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.mapView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.mapView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.mapView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    self.companyMarker = [[GMSMarker alloc] init];
    self.companyMarker.position = self.companyLocation;
    self.companyMarker.title = @"Pure Pets";
    self.companyMarker.iconView = [self pp_makeMarkerView];
    self.companyMarker.groundAnchor = CGPointMake(0.5, 0.91);
    self.companyMarker.zIndex = 12;
    self.companyMarker.tracksViewChanges = YES;
    self.companyMarker.appearAnimation = kGMSMarkerAnimationPop;
    self.companyMarker.map = self.mapView;
}

- (void)pp_applyPremiumMapStyle
{
    NSString *styleJSON =
    @"["
    "{\"featureType\":\"all\",\"elementType\":\"geometry\",\"stylers\":[{\"saturation\":-18},{\"lightness\":8}]},"
    "{\"featureType\":\"all\",\"elementType\":\"labels.text.fill\",\"stylers\":[{\"color\":\"#5f6875\"}]},"
    "{\"featureType\":\"all\",\"elementType\":\"labels.text.stroke\",\"stylers\":[{\"color\":\"#f8f5ef\"},{\"weight\":2}]},"
    "{\"featureType\":\"poi\",\"elementType\":\"labels.icon\",\"stylers\":[{\"saturation\":-18},{\"lightness\":8}]},"
    "{\"featureType\":\"poi.business\",\"stylers\":[{\"visibility\":\"simplified\"}]},"
    "{\"featureType\":\"road\",\"elementType\":\"geometry\",\"stylers\":[{\"color\":\"#dce4ed\"}]},"
    "{\"featureType\":\"road.arterial\",\"elementType\":\"geometry\",\"stylers\":[{\"color\":\"#cdd9e6\"}]},"
    "{\"featureType\":\"water\",\"elementType\":\"geometry\",\"stylers\":[{\"color\":\"#8fdbe7\"},{\"saturation\":-8},{\"lightness\":4}]}"
    @"]";
    NSError *styleError = nil;
    GMSMapStyle *style = [GMSMapStyle styleWithJSONString:styleJSON error:&styleError];
    if (style) {
        self.mapView.mapStyle = style;
    } else if (styleError) {
        NSLog(@"[CompanyLocationVC] map style failed: %@", styleError.localizedDescription ?: @"Unknown error");
    }
}

- (void)pp_setupAmbientBackground
{
    self.bottomGlowView = [[UIView alloc] init];
    self.bottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomGlowView.userInteractionEnabled = NO;
    [self.view addSubview:self.bottomGlowView];

    self.bottomGlowLayer = [CAGradientLayer layer];
    self.bottomGlowLayer.type = kCAGradientLayerRadial;
    self.bottomGlowLayer.colors = @[
        (__bridge id)[[[UIColor colorWithRed:0.49 green:0.83 blue:0.94 alpha:1.0] colorWithAlphaComponent:0.16] CGColor],
        (__bridge id)[[[UIColor colorWithRed:0.84 green:0.94 blue:0.98 alpha:1.0] colorWithAlphaComponent:0.12] CGColor],
        (__bridge id)[UIColor.clearColor CGColor]
    ];
    self.bottomGlowLayer.locations = @[@0.0, @0.55, @1.0];
    [self.bottomGlowView.layer addSublayer:self.bottomGlowLayer];

    self.topScrimView = [[UIView alloc] init];
    self.topScrimView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topScrimView.userInteractionEnabled = NO;
    [self.view addSubview:self.topScrimView];

    self.topScrimLayer = [CAGradientLayer layer];
    self.topScrimLayer.colors = @[
        (__bridge id)[[UIColor colorWithWhite:1.0 alpha:0.26] CGColor],
        (__bridge id)[[UIColor colorWithWhite:1.0 alpha:0.10] CGColor],
        (__bridge id)[UIColor.clearColor CGColor]
    ];
    self.topScrimLayer.locations = @[@0.0, @0.40, @1.0];
    [self.topScrimView.layer addSublayer:self.topScrimLayer];

    self.bottomScrimView = [[UIView alloc] init];
    self.bottomScrimView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomScrimView.userInteractionEnabled = NO;
    [self.view addSubview:self.bottomScrimView];

    self.bottomScrimLayer = [CAGradientLayer layer];
    self.bottomScrimLayer.colors = @[
        (__bridge id)[UIColor.clearColor CGColor],
        (__bridge id)[[PPLocationSurfaceColor() colorWithAlphaComponent:0.26] CGColor],
        (__bridge id)[[PPLocationSurfaceColor() colorWithAlphaComponent:0.76] CGColor]
    ];
    self.bottomScrimLayer.locations = @[@0.0, @0.58, @1.0];
    [self.bottomScrimView.layer addSublayer:self.bottomScrimLayer];

    [NSLayoutConstraint activateConstraints:@[
        [self.bottomGlowView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:34.0],
        [self.bottomGlowView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:20.0],
        [self.bottomGlowView.widthAnchor constraintEqualToConstant:260.0],
        [self.bottomGlowView.heightAnchor constraintEqualToConstant:260.0],

        [self.topScrimView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.topScrimView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.topScrimView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.topScrimView.heightAnchor constraintEqualToConstant:220.0],

        [self.bottomScrimView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomScrimView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomScrimView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.bottomScrimView.heightAnchor constraintEqualToConstant:340.0]
    ]];
}

- (void)pp_setupBottomSheet
{
    UIView *contentView = nil;
    self.sheetView = [self pp_makePanelWithCornerRadius:kPPLocationSheetRadius
                                              tintColor:[PPLocationSurfaceColor() colorWithAlphaComponent:0.90]
                                            borderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.72]
                                          shadowOpacity:0.12
                                            contentView:&contentView];
    [self.view addSubview:self.sheetView];

    [NSLayoutConstraint activateConstraints:@[
        [self.sheetView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kPPLocationHorizontalInset],
        [self.sheetView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kPPLocationHorizontalInset],
        [self.sheetView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-16.0]
    ]];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;
    stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [contentView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:16.0],
        [stack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16.0],
        [stack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-16.0]
    ]];

    UIView *handle = [[UIView alloc] init];
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    handle.backgroundColor = [[PPLocationPrimaryTextColor() colorWithAlphaComponent:0.18] colorWithAlphaComponent:1.0];
    handle.layer.cornerRadius = 2.5;
    [handle.widthAnchor constraintEqualToConstant:42.0].active = YES;
    [handle.heightAnchor constraintEqualToConstant:5.0].active = YES;
    [stack addArrangedSubview:[self pp_centeredContainerForView:handle height:5.0]];

    self.sheetTitleLabel = [[UILabel alloc] init];
    self.sheetTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.sheetTitleLabel.numberOfLines = 0;
    self.sheetTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.sheetTitleLabel.textColor = PPLocationPrimaryTextColor();
    self.sheetTitleLabel.font = PPLocationScaledFont([GM boldFontWithSize:28.0] ?: [UIFont systemFontOfSize:28.0 weight:UIFontWeightBold],
                                                     UIFontTextStyleTitle1);
    self.sheetTitleLabel.adjustsFontForContentSizeCategory = YES;
    [stack addArrangedSubview:self.sheetTitleLabel];

    self.sheetSubtitleLabel = [[UILabel alloc] init];
    self.sheetSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.sheetSubtitleLabel.numberOfLines = 0;
    self.sheetSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.sheetSubtitleLabel.textColor = PPLocationSecondaryTextColor();
    self.sheetSubtitleLabel.font = PPLocationScaledFont([GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium],
                                                        UIFontTextStyleSubheadline);
    self.sheetSubtitleLabel.adjustsFontForContentSizeCategory = YES;
    [stack addArrangedSubview:self.sheetSubtitleLabel];

    UIView *infoCard = [self pp_makeSoftCard];
    [stack addArrangedSubview:infoCard];

    UIView *addressRow = [self pp_makeInfoRowWithSymbol:@"mappin.and.ellipse"
                                               titleKey:@"company_location_address_title"
                                              valueText:kLang(@"companyAddress")];
    UIView *phoneRow = [self pp_makeInfoRowWithSymbol:@"phone.fill"
                                             titleKey:@"company_location_phone_title"
                                            valueText:[PPFunc formattedPhoneNumber:kPPCompanyPhoneNumber]];
    UIView *divider = [self pp_makeDivider];
    [infoCard addSubview:addressRow];
    [infoCard addSubview:divider];
    [infoCard addSubview:phoneRow];

    [NSLayoutConstraint activateConstraints:@[
        [addressRow.topAnchor constraintEqualToAnchor:infoCard.topAnchor constant:14.0],
        [addressRow.leadingAnchor constraintEqualToAnchor:infoCard.leadingAnchor constant:14.0],
        [addressRow.trailingAnchor constraintEqualToAnchor:infoCard.trailingAnchor constant:-14.0],

        [divider.topAnchor constraintEqualToAnchor:addressRow.bottomAnchor constant:12.0],
        [divider.leadingAnchor constraintEqualToAnchor:infoCard.leadingAnchor constant:14.0],
        [divider.trailingAnchor constraintEqualToAnchor:infoCard.trailingAnchor constant:-14.0],
        [divider.heightAnchor constraintEqualToConstant:1.0],

        [phoneRow.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:12.0],
        [phoneRow.leadingAnchor constraintEqualToAnchor:infoCard.leadingAnchor constant:14.0],
        [phoneRow.trailingAnchor constraintEqualToAnchor:infoCard.trailingAnchor constant:-14.0],
        [phoneRow.bottomAnchor constraintEqualToAnchor:infoCard.bottomAnchor constant:-14.0]
    ]];

    UIView *statusCard = [self pp_makeStatusCard];
    [stack addArrangedSubview:statusCard];

    self.previewRouteButton = [self pp_makeSecondaryActionButton];
    [self.previewRouteButton addTarget:self action:@selector(fetchAndDrawRoute) forControlEvents:UIControlEventTouchUpInside];
    [self.previewRouteButton.heightAnchor constraintEqualToConstant:54.0].active = YES;
    [stack addArrangedSubview:self.previewRouteButton];

    UIStackView *quickActionsRow = [[UIStackView alloc] init];
    quickActionsRow.translatesAutoresizingMaskIntoConstraints = NO;
    quickActionsRow.axis = UILayoutConstraintAxisHorizontal;
    quickActionsRow.spacing = 8.0;
    quickActionsRow.distribution = UIStackViewDistributionFillEqually;
    [stack addArrangedSubview:quickActionsRow];

    self.recenterButton = [self pp_makeSecondaryActionButton];
    self.callButton = [self pp_makeSecondaryActionButton];
    self.supportButton = [self pp_makeSecondaryActionButton];
    self.shareButton = [self pp_makeSecondaryActionButton];
    [self.recenterButton addTarget:self action:@selector(recenterToUserLocation) forControlEvents:UIControlEventTouchUpInside];
    [self.callButton addTarget:self action:@selector(callCompany) forControlEvents:UIControlEventTouchUpInside];
    [self.supportButton addTarget:self action:@selector(openSupportChat) forControlEvents:UIControlEventTouchUpInside];
    [self.shareButton addTarget:self action:@selector(shareLocation) forControlEvents:UIControlEventTouchUpInside];
    [self.recenterButton.heightAnchor constraintEqualToConstant:64.0].active = YES;
    [self.callButton.heightAnchor constraintEqualToConstant:64.0].active = YES;
    [self.supportButton.heightAnchor constraintEqualToConstant:64.0].active = YES;
    [self.shareButton.heightAnchor constraintEqualToConstant:64.0].active = YES;
    [quickActionsRow addArrangedSubview:self.recenterButton];
    [quickActionsRow addArrangedSubview:self.callButton];
    [quickActionsRow addArrangedSubview:self.supportButton];
    [quickActionsRow addArrangedSubview:self.shareButton];

    self.openMapsButton = [self pp_makePrimaryActionButton];
    [self.openMapsButton addTarget:self action:@selector(startNavigationToCompany) forControlEvents:UIControlEventTouchUpInside];
    [self.openMapsButton.heightAnchor constraintEqualToConstant:58.0].active = YES;
    [stack addArrangedSubview:self.openMapsButton];

    self.heroEntranceViews = self.markerView ? @[self.markerView] : @[];
    self.sheetEntranceViews = @[self.sheetView];
}

- (void)setupLocationManager
{
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
    self.locationManager.distanceFilter = 15.0;
}

#pragma mark - Localization

- (void)pp_updateLocalizedCopy
{
    self.markerEyebrowLabel.text = kLang(@"company_location_nav_title");
    self.markerTitleLabel.text = kLang(@"company_location_chip_title");
    self.companyMarker.tracksViewChanges = YES;

    self.sheetTitleLabel.text = kLang(@"companyLocate");
    self.sheetSubtitleLabel.text = kLang(@"company_location_subtitle");

    [self pp_configureActionButton:self.openMapsButton
                             title:kLang(@"company_location_primary_action")
                            symbol:@"arrow.triangle.turn.up.right.diamond.fill"
                           primary:YES
                          vertical:NO];
    [self pp_configureActionButton:self.previewRouteButton
                             title:kLang(@"company_location_preview_route")
                            symbol:@"point.topleft.down.curvedto.point.bottomright.up.fill"
                           primary:NO
                          vertical:NO];
    [self pp_configureActionButton:self.recenterButton
                             title:kLang(@"company_location_recenter")
                            symbol:@"location.fill"
                           primary:NO
                          vertical:YES];
    [self pp_configureActionButton:self.callButton
                             title:kLang(@"company_location_call_short")
                            symbol:@"phone.fill"
                           primary:NO
                          vertical:YES];
    [self pp_configureActionButton:self.supportButton
                             title:kLang(@"company_location_support_short")
                            symbol:@"message.fill"
                           primary:NO
                          vertical:YES];
    [self pp_configureActionButton:self.shareButton
                             title:kLang(@"company_location_share")
                            symbol:@"square.and.arrow.up"
                           primary:NO
                          vertical:YES];
    self.callButton.accessibilityLabel = kLang(@"company_location_call_accessibility");
    self.supportButton.accessibilityLabel = kLang(@"company_location_support_accessibility");
}

#pragma mark - Location

- (BOOL)pp_locationAuthorizationAllowsUpdates:(CLAuthorizationStatus)status
{
    return status == kCLAuthorizationStatusAuthorizedWhenInUse ||
    status == kCLAuthorizationStatusAuthorizedAlways;
}

- (void)pp_handleLocationAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestWhenInUseAuthorization];
        [self pp_refreshActionAvailability];
        return;
    }

    if ([self pp_locationAuthorizationAllowsUpdates:status]) {
        [self.locationManager startUpdatingLocation];
    } else {
        [self.locationManager stopUpdatingLocation];
    }

    [self pp_refreshActionAvailability];
}

- (void)pp_startLocationUpdatesIfNeeded
{
    if (@available(iOS 14.0, *)) {
        [self pp_handleLocationAuthorizationStatus:self.locationManager.authorizationStatus];
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
#pragma clang diagnostic pop
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf pp_handleLocationAuthorizationStatus:status];
        });
    });
}

- (void)pp_refreshActionAvailability
{
    BOOL hasCurrentLocation = self.locationManager.location != nil;
    [self pp_applyEnabledState:!self.isLoadingRoute toButton:self.previewRouteButton];
    [self pp_applyEnabledState:hasCurrentLocation toButton:self.recenterButton];
    [self pp_applyEnabledState:YES toButton:self.openMapsButton];
    [self pp_applyEnabledState:YES toButton:self.callButton];
    [self pp_applyEnabledState:YES toButton:self.supportButton];
    [self pp_applyEnabledState:YES toButton:self.shareButton];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    CLLocation *location = locations.lastObject;
    if (!location) {
        return;
    }
    [self pp_refreshActionAvailability];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"[CompanyLocationVC] location failed: %@", error.localizedDescription ?: @"Unknown error");
    [self pp_refreshActionAvailability];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager API_AVAILABLE(ios(14.0))
{
    (void)manager;
    [self pp_startLocationUpdatesIfNeeded];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    (void)manager;
    [self pp_handleLocationAuthorizationStatus:status];
}

#pragma mark - Actions

- (void)callCompany
{
    NSString *phoneDigits = [[kPPCompanyPhoneNumber stringByReplacingOccurrencesOfString:@"+" withString:@""]
                             stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSURL *phoneURL = [NSURL URLWithString:[NSString stringWithFormat:@"tel://%@", phoneDigits]];
    if ([[UIApplication sharedApplication] canOpenURL:phoneURL]) {
        [[UIApplication sharedApplication] openURL:phoneURL options:@{} completionHandler:nil];
        return;
    }

    [self showAlert:kLang(@"company_location_call_unavailable")];
}

- (void)openSupportChat
{
    [[ChManager sharedManager] openSupportChatFromController:self];
}

- (void)shareLocation
{
    NSString *locationURL = [NSString stringWithFormat:@"https://www.google.com/maps?q=%.6f,%.6f+(Pure+Pets)",
                             self.companyLocation.latitude,
                             self.companyLocation.longitude];
    UIActivityViewController *shareVC =
    [[UIActivityViewController alloc] initWithActivityItems:@[kLang(@"company_location_share_text"), locationURL]
                                      applicationActivities:nil];
    UIPopoverPresentationController *popover = shareVC.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.shareButton ?: self.view;
        popover.sourceRect = self.shareButton ? self.shareButton.bounds : self.view.bounds;
    }
    [self presentViewController:shareVC animated:YES completion:nil];
}

- (void)recenterToUserLocation
{
    CLLocation *location = self.locationManager.location;
    if (!location) {
        [self showAlert:kLang(@"company_location_location_missing")];
        return;
    }

    GMSCameraUpdate *update = [GMSCameraUpdate setTarget:location.coordinate zoom:15.9];
    [self.mapView animateWithCameraUpdate:update];
}

- (void)fetchAndDrawRoute
{
    CLLocation *userLocation = self.locationManager.location;
    if (!userLocation) {
        [self showAlert:kLang(@"company_location_route_permission")];
        return;
    }

    self.isLoadingRoute = YES;
    [self pp_refreshActionAvailability];
    [self pp_setRouteStatusTitleKey:@"company_location_calculating_title"
                      detailTextKey:@"company_location_calculating"
                      detailOverride:nil
                        accentTint:[PPLocationAccentColor() colorWithAlphaComponent:0.16]];

    NSString *apiKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"GMSApiKey"];
    NSString *urlString = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/directions/json?origin=%f,%f&destination=%f,%f&mode=driving&key=%@",
                           userLocation.coordinate.latitude,
                           userLocation.coordinate.longitude,
                           self.companyLocation.latitude,
                           self.companyLocation.longitude,
                           apiKey ?: @""];
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        self.isLoadingRoute = NO;
        [self pp_refreshActionAvailability];
        [self pp_setRouteStatusTitleKey:@"company_location_ready_title"
                          detailTextKey:@"company_location_route_request_failed"
                          detailOverride:nil
                            accentTint:[[UIColor systemRedColor] colorWithAlphaComponent:0.14]];
        [self showAlert:kLang(@"company_location_route_request_failed")];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [[[NSURLSession sharedSession] dataTaskWithURL:url
                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        (void)response;
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        NSError *jsonError = nil;
        NSDictionary *json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError] : nil;
        NSArray *routes = [json[@"routes"] isKindOfClass:[NSArray class]] ? json[@"routes"] : @[];
        NSDictionary *route = routes.firstObject;
        NSArray *legs = [route[@"legs"] isKindOfClass:[NSArray class]] ? route[@"legs"] : @[];
        NSDictionary *leg = legs.firstObject;
        NSString *polyline = [route[@"overview_polyline"][@"points"] isKindOfClass:[NSString class]] ? route[@"overview_polyline"][@"points"] : nil;
        NSString *duration = [leg[@"duration"][@"text"] isKindOfClass:[NSString class]] ? leg[@"duration"][@"text"] : nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf.isLoadingRoute = NO;
            [strongSelf pp_refreshActionAvailability];

            if (error || jsonError || !route) {
                [strongSelf pp_setRouteStatusTitleKey:@"company_location_ready_title"
                                        detailTextKey:@"company_location_route_unavailable"
                                        detailOverride:nil
                                          accentTint:[[UIColor systemRedColor] colorWithAlphaComponent:0.14]];
                [strongSelf showAlert:kLang(@"company_location_route_unavailable")];
                return;
            }

            NSString *detailText = duration.length > 0
            ? [NSString stringWithFormat:@"%@ %@", kLang(@"company_location_eta_prefix"), duration]
            : kLang(@"company_location_route_ready_detail");
            [strongSelf pp_setRouteStatusTitleKey:@"company_location_eta_title"
                                    detailTextKey:nil
                                    detailOverride:detailText
                                      accentTint:[PPLocationAccentColor() colorWithAlphaComponent:0.14]];

            if (polyline.length > 0) {
                [strongSelf decodeAndDrawPolyline:polyline];
            }
        });
    }] resume];
}

- (void)startNavigationToCompany
{
    NSString *nativeURLString =
    [NSString stringWithFormat:@"comgooglemaps://?daddr=%f,%f&directionsmode=driving",
     self.companyLocation.latitude,
     self.companyLocation.longitude];
    NSURL *nativeURL = [NSURL URLWithString:nativeURLString];
    UIApplication *application = [UIApplication sharedApplication];

    if ([application canOpenURL:nativeURL]) {
        [application openURL:nativeURL options:@{} completionHandler:nil];
        return;
    }

    NSString *webURLString =
    [NSString stringWithFormat:@"https://www.google.com/maps/dir/?api=1&destination=%f,%f",
     self.companyLocation.latitude,
     self.companyLocation.longitude];
    NSURL *webURL = [NSURL URLWithString:webURLString];
    [application openURL:webURL options:@{} completionHandler:nil];
}

#pragma mark - Route Drawing

- (NSArray<NSValue *> *)decodePolyline:(NSString *)encoded
{
    NSMutableArray<NSValue *> *coordinates = [NSMutableArray array];
    NSInteger index = 0;
    NSInteger latitude = 0;
    NSInteger longitude = 0;
    NSInteger length = encoded.length;

    while (index < length) {
        NSInteger byte = 0;
        NSInteger shift = 0;
        NSInteger result = 0;

        do {
            byte = [encoded characterAtIndex:index++] - 63;
            result |= (byte & 0x1F) << shift;
            shift += 5;
        } while (byte >= 0x20 && index < length);

        NSInteger deltaLatitude = (result & 1) ? ~(result >> 1) : (result >> 1);
        latitude += deltaLatitude;

        shift = 0;
        result = 0;
        do {
            byte = [encoded characterAtIndex:index++] - 63;
            result |= (byte & 0x1F) << shift;
            shift += 5;
        } while (byte >= 0x20 && index < length);

        NSInteger deltaLongitude = (result & 1) ? ~(result >> 1) : (result >> 1);
        longitude += deltaLongitude;

        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitude * 1e-5, longitude * 1e-5);
        [coordinates addObject:[NSValue valueWithBytes:&coordinate objCType:@encode(CLLocationCoordinate2D)]];
    }

    return coordinates;
}

- (void)decodeAndDrawPolyline:(NSString *)encoded
{
    NSArray<NSValue *> *points = [self decodePolyline:encoded];
    if (points.count == 0) {
        return;
    }

    GMSMutablePath *path = [GMSMutablePath path];
    for (NSValue *value in points) {
        CLLocationCoordinate2D coordinate;
        [value getValue:&coordinate];
        [path addCoordinate:coordinate];
    }

    if (self.activePolyline) {
        self.activePolyline.map = nil;
    }
    if (self.routeGlowPolyline) {
        self.routeGlowPolyline.map = nil;
    }

    self.routeGlowPolyline = [GMSPolyline polylineWithPath:path];
    self.routeGlowPolyline.strokeColor = [PPLocationAccentColor() colorWithAlphaComponent:0.20];
    self.routeGlowPolyline.strokeWidth = 10.0;
    self.routeGlowPolyline.geodesic = YES;
    self.routeGlowPolyline.map = self.mapView;

    self.activePolyline = [GMSPolyline polylineWithPath:path];
    self.activePolyline.strokeColor = PPLocationAccentColor();
    self.activePolyline.strokeWidth = 4.5;
    self.activePolyline.geodesic = YES;
    self.activePolyline.map = self.mapView;

    GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithPath:path];
    GMSCameraUpdate *cameraUpdate = [GMSCameraUpdate fitBounds:bounds withPadding:76.0];
    [self.mapView animateWithCameraUpdate:cameraUpdate];
}

#pragma mark - Motion

- (BOOL)pp_reduceMotionEnabled
{
    return UIAccessibilityIsReduceMotionEnabled();
}

- (void)pp_prepareEntranceStateIfNeeded
{
    if (self.didPrepareEntrance || self.didRunEntrance) {
        return;
    }

    self.didPrepareEntrance = YES;

    for (UIView *view in self.heroEntranceViews) {
        view.alpha = 0.0;
        view.transform = [self pp_reduceMotionEnabled] ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0.0, -10.0);
    }

    for (UIView *view in self.sheetEntranceViews) {
        view.alpha = 0.0;
        view.transform = [self pp_reduceMotionEnabled] ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0.0, 24.0);
    }

    self.topGlowView.alpha = [self pp_reduceMotionEnabled] ? 1.0 : 0.0;
    self.bottomGlowView.alpha = [self pp_reduceMotionEnabled] ? 1.0 : 0.0;
}

- (void)pp_runEntranceIfNeeded
{
    if (self.didRunEntrance) {
        return;
    }

    self.didRunEntrance = YES;
    [self.view layoutIfNeeded];

    if ([self pp_reduceMotionEnabled]) {
        self.sheetView.alpha = 1.0;
        self.topGlowView.alpha = 1.0;
        self.bottomGlowView.alpha = 1.0;
        return;
    }

    [UIView animateWithDuration:0.42
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.topGlowView.alpha = 1.0;
        self.bottomGlowView.alpha = 1.0;

    } completion:nil];

    [UIView animateWithDuration:0.46
                          delay:0.10
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.22
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.sheetView.alpha = 1.0;
        self.sheetView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_applyAmbientMotionIfNeeded
{
    if ([self pp_reduceMotionEnabled]) {
        [self.topGlowView.layer removeAnimationForKey:@"pp.location.glow.top"];
        [self.bottomGlowView.layer removeAnimationForKey:@"pp.location.glow.bottom"];

        return;
    }

    if (![self.topGlowView.layer animationForKey:@"pp.location.glow.top"]) {
        CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        scale.fromValue = @1.0;
        scale.toValue = @1.06;
        scale.duration = 4.6;
        scale.autoreverses = YES;
        scale.repeatCount = HUGE_VALF;
        scale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.topGlowView.layer addAnimation:scale forKey:@"pp.location.glow.top"];
    }

    if (![self.bottomGlowView.layer animationForKey:@"pp.location.glow.bottom"]) {
        CABasicAnimation *floatAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
        floatAnimation.fromValue = @0.0;
        floatAnimation.toValue = @(-8.0);
        floatAnimation.duration = 6.0;
        floatAnimation.autoreverses = YES;
        floatAnimation.repeatCount = HUGE_VALF;
        floatAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.bottomGlowView.layer addAnimation:floatAnimation forKey:@"pp.location.glow.bottom"];
    }


}

#pragma mark - UI Builders

- (UIView *)pp_makePanelWithCornerRadius:(CGFloat)cornerRadius
                               tintColor:(UIColor *)tintColor
                             borderColor:(UIColor *)borderColor
                           shadowOpacity:(CGFloat)shadowOpacity
                             contentView:(UIView * __autoreleasing *)contentViewOut
{
    UIView *container = (UIView *)[PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleLarge];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;
    PPLocationApplyCornerRadius(container, cornerRadius);
    container.layer.shadowColor = [UIColor colorWithWhite:0.10 alpha:1.0].CGColor;
    container.layer.shadowOpacity = shadowOpacity;
    container.layer.shadowRadius = 24.0;
    container.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    container.layer.borderWidth = 1.0;
    if (@available(iOS 26.0, *)) {
        container.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.20].CGColor;
    } else {
        container.layer.borderColor = borderColor.CGColor;
    }
    container.clipsToBounds = NO;

    UIView *tintView = [[UIView alloc] init];
    tintView.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 26.0, *)) {
        tintView.backgroundColor = UIColor.clearColor;
    } else {
        tintView.backgroundColor = tintColor;
    }
    tintView.userInteractionEnabled = NO;
    PPLocationApplyCornerRadius(tintView, cornerRadius);
    tintView.layer.masksToBounds = YES;
    [container addSubview:tintView];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.backgroundColor = UIColor.clearColor;
    contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    PPLocationApplyCornerRadius(contentView, cornerRadius);
    contentView.layer.masksToBounds = YES;
    [container addSubview:contentView];

    [NSLayoutConstraint activateConstraints:@[
        [tintView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [tintView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [tintView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [tintView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],

        [contentView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    if (contentViewOut) {
        *contentViewOut = contentView;
    }
    return container;
}

- (UIView *)pp_centeredContainerForView:(UIView *)view height:(CGFloat)height
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [container.heightAnchor constraintEqualToConstant:height].active = YES;
    [container addSubview:view];

    [NSLayoutConstraint activateConstraints:@[
        [view.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [view.topAnchor constraintEqualToAnchor:container.topAnchor],
        [view.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];
    return container;
}

- (UIView *)pp_makeSoftCard
{
    UIView *card = (UIView *)[PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 26.0, *)) {
        card.backgroundColor = UIColor.clearColor;
    } else {
        card.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.76];
    }
    PPLocationApplyCornerRadius(card, kPPLocationButtonCornerRadius);
    CGFloat borderAlpha = 0.70;
    if (@available(iOS 26.0, *)) {
        borderAlpha = 0.30;
    }
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:borderAlpha].CGColor;
    card.clipsToBounds = YES;
    return card;
}

- (UIView *)pp_makeDivider
{
    UIView *divider = [[UIView alloc] init];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.backgroundColor = [[PPLocationPrimaryTextColor() colorWithAlphaComponent:0.08] colorWithAlphaComponent:1.0];
    return divider;
}

- (UIView *)pp_makeInfoRowWithSymbol:(NSString *)symbolName
                            titleKey:(NSString *)titleKey
                           valueText:(NSString *)valueText
{
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *iconPlate = [[UIView alloc] init];
    iconPlate.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 26.0, *)) {
        iconPlate.backgroundColor = UIColor.clearColor;
    } else {
        iconPlate.backgroundColor = [PPLocationAccentColor() colorWithAlphaComponent:0.12];
    }
    PPLocationApplyCornerRadius(iconPlate, 16.0);
    [row addSubview:iconPlate];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbolName]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = PPLocationAccentColor();
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconPlate addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = PPLocationScaledFont([GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium],
                                           UIFontTextStyleCaption1);
    titleLabel.textColor = [PPLocationSecondaryTextColor() colorWithAlphaComponent:0.90];
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.text = kLang(titleKey);
    [row addSubview:titleLabel];

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.font = PPLocationScaledFont([GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold],
                                           UIFontTextStyleSubheadline);
    valueLabel.textColor = PPLocationPrimaryTextColor();
    valueLabel.numberOfLines = 0;
    valueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    valueLabel.text = valueText ?: @"";
    [row addSubview:valueLabel];

    [NSLayoutConstraint activateConstraints:@[
        [iconPlate.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [iconPlate.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [iconPlate.widthAnchor constraintEqualToConstant:32.0],
        [iconPlate.heightAnchor constraintEqualToConstant:32.0],

        [iconView.centerXAnchor constraintEqualToAnchor:iconPlate.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconPlate.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:16.0],
        [iconView.heightAnchor constraintEqualToConstant:16.0],

        [titleLabel.topAnchor constraintEqualToAnchor:row.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconPlate.trailingAnchor constant:12.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],

        [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:2.0],
        [valueLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [valueLabel.bottomAnchor constraintEqualToAnchor:row.bottomAnchor]
    ]];

    return row;
}

- (UIView *)pp_makeStatusCard
{
    UIView *card = [self pp_makeSoftCard];

    self.routeStatusIconPlateView = [[UIView alloc] init];
    self.routeStatusIconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 26.0, *)) {
        self.routeStatusIconPlateView.backgroundColor = UIColor.clearColor;
    } else {
        self.routeStatusIconPlateView.backgroundColor = [PPLocationAccentColor() colorWithAlphaComponent:0.14];
    }
    PPLocationApplyCornerRadius(self.routeStatusIconPlateView, kPPLocationButtonCornerRadius);
    [card addSubview:self.routeStatusIconPlateView];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sparkles"]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = PPLocationAccentColor();
    [self.routeStatusIconPlateView addSubview:iconView];

    self.routeStatusTitleLabel = [[UILabel alloc] init];
    self.routeStatusTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.routeStatusTitleLabel.font = PPLocationScaledFont([GM boldFontWithSize:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold],
                                                           UIFontTextStyleSubheadline);
    self.routeStatusTitleLabel.textColor = PPLocationPrimaryTextColor();
    self.routeStatusTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.routeStatusTitleLabel.numberOfLines = 1;
    [card addSubview:self.routeStatusTitleLabel];

    self.routeStatusValueLabel = [[UILabel alloc] init];
    self.routeStatusValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.routeStatusValueLabel.font = PPLocationScaledFont([GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium],
                                                           UIFontTextStyleCaption1);
    self.routeStatusValueLabel.textColor = PPLocationSecondaryTextColor();
    self.routeStatusValueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.routeStatusValueLabel.numberOfLines = 2;
    [card addSubview:self.routeStatusValueLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.routeStatusIconPlateView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14.0],
        [self.routeStatusIconPlateView.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [self.routeStatusIconPlateView.widthAnchor constraintEqualToConstant:36.0],
        [self.routeStatusIconPlateView.heightAnchor constraintEqualToConstant:36.0],

        [iconView.centerXAnchor constraintEqualToAnchor:self.routeStatusIconPlateView.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:self.routeStatusIconPlateView.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:15.0],
        [iconView.heightAnchor constraintEqualToConstant:15.0],

        [self.routeStatusTitleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [self.routeStatusTitleLabel.leadingAnchor constraintEqualToAnchor:self.routeStatusIconPlateView.trailingAnchor constant:12.0],
        [self.routeStatusTitleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14.0],

        [self.routeStatusValueLabel.topAnchor constraintEqualToAnchor:self.routeStatusTitleLabel.bottomAnchor constant:3.0],
        [self.routeStatusValueLabel.leadingAnchor constraintEqualToAnchor:self.routeStatusTitleLabel.leadingAnchor],
        [self.routeStatusValueLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14.0],
        [self.routeStatusValueLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14.0]
    ]];

    return card;
}

- (UIButton *)pp_makePrimaryActionButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    PPLocationApplyCornerRadius(button, kPPLocationButtonCornerRadius);
    if (@available(iOS 26.0, *)) {
        button.backgroundColor = UIColor.clearColor;
    } else {
        button.backgroundColor = PPLocationAccentColor();
    }
    button.tintColor = UIColor.whiteColor;
    button.titleLabel.font = [GM boldFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    button.titleLabel.numberOfLines = 1;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.86;
    button.layer.shadowColor = [PPLocationAccentColor() colorWithAlphaComponent:0.42].CGColor;
    button.layer.shadowOpacity = 0.20;
    button.layer.shadowRadius = 18.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    return button;
}

- (UIButton *)pp_makeSecondaryActionButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    PPLocationApplyCornerRadius(button, kPPLocationButtonCornerRadius);
    if (@available(iOS 26.0, *)) {
        button.backgroundColor = UIColor.clearColor;
    } else {
        button.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.78];
    }
    button.tintColor = PPLocationPrimaryTextColor();
    button.titleLabel.font = [GM boldFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    button.titleLabel.numberOfLines = 1;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.78;
    button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    if (@available(iOS 26.0, *)) {
        button.layer.borderWidth = 0.0;
    } else {
        button.layer.borderWidth = 1.0;
        button.layer.borderColor = [[PPLocationPrimaryTextColor() colorWithAlphaComponent:0.06] CGColor];
    }
    button.layer.shadowColor = [UIColor colorWithWhite:0.10 alpha:1.0].CGColor;
    button.layer.shadowOpacity = 0.05;
    button.layer.shadowRadius = 12.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    return button;
}

- (NSAttributedString *)pp_attributedButtonTitleWithText:(NSString *)title
                                                 primary:(BOOL)primary
                                                vertical:(BOOL)vertical
{
    CGFloat fontSize = primary ? 16.0 : (vertical ? 12.2 : 14.5);
    UIFontTextStyle style = primary ? UIFontTextStyleCallout : (vertical ? UIFontTextStyleCaption1 : UIFontTextStyleSubheadline);
    UIFont *font = PPLocationScaledFont([GM boldFontWithSize:fontSize] ?: [UIFont systemFontOfSize:fontSize weight:UIFontWeightSemibold],
                                        style);
    UIColor *color = primary ? UIColor.whiteColor : PPLocationPrimaryTextColor();

    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = NSTextAlignmentCenter;
    paragraph.lineBreakMode = NSLineBreakByTruncatingTail;

    return [[NSAttributedString alloc] initWithString:(title ?: @"")
                                           attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: paragraph
    }];
}

- (void)pp_configureActionButton:(UIButton *)button
                           title:(NSString *)title
                          symbol:(NSString *)symbol
                         primary:(BOOL)primary
                        vertical:(BOOL)vertical
{
    UIImage *image = [UIImage systemImageNamed:symbol];
    CGFloat symbolPointSize = primary ? 18.0 : (vertical ? 16.0 : 16.5);
    UIImageSymbolWeight symbolWeight = primary ? UIImageSymbolWeightBold : UIImageSymbolWeightSemibold;
    UIImageSymbolConfiguration *symbolConfiguration =
    [UIImageSymbolConfiguration configurationWithPointSize:symbolPointSize weight:symbolWeight];
    image = [image imageWithConfiguration:symbolConfiguration];
    NSAttributedString *attributedTitle = [self pp_attributedButtonTitleWithText:title
                                                                          primary:primary
                                                                         vertical:vertical];
    UIColor *foreground = primary ? UIColor.whiteColor : PPLocationPrimaryTextColor();

    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.titleLabel.numberOfLines = 1;
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = vertical ? 0.76 : 0.84;
    button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = nil;
        if (@available(iOS 26.0, *)) {
            configuration = primary ? [UIButtonConfiguration prominentGlassButtonConfiguration] : [UIButtonConfiguration glassButtonConfiguration];
        } else {
            configuration = [UIButtonConfiguration plainButtonConfiguration];
        }
        configuration.attributedTitle = attributedTitle;
        configuration.image = image;
        configuration.imagePlacement = vertical ? NSDirectionalRectEdgeTop : NSDirectionalRectEdgeLeading;
        configuration.imagePadding = vertical ? 5.0 : 9.0;
        configuration.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
        configuration.contentInsets = vertical
        ? NSDirectionalEdgeInsetsMake(8.0, 5.0, 8.0, 5.0)
        : NSDirectionalEdgeInsetsMake(14.0, 16.0, 14.0, 16.0);
        configuration.baseForegroundColor = foreground;
        if (@available(iOS 26.0, *)) {
            configuration.background.backgroundColor = UIColor.clearColor;
        } else {
            configuration.background.backgroundColor = primary ? PPLocationAccentColor() : [[UIColor whiteColor] colorWithAlphaComponent:0.78];
        }
        configuration.background.cornerRadius = kPPLocationButtonCornerRadius;
        configuration.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        button.configuration = configuration;
    } else {
        [button setAttributedTitle:attributedTitle forState:UIControlStateNormal];
        [button setAttributedTitle:attributedTitle forState:UIControlStateHighlighted];
        [button setAttributedTitle:attributedTitle forState:UIControlStateDisabled];
        [button setImage:image forState:UIControlStateNormal];
        [button setTitleColor:foreground forState:UIControlStateNormal];
        button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 14.0, 0.0, 14.0);
        button.titleEdgeInsets = UIEdgeInsetsMake(0.0, 8.0, 0.0, -8.0);
    }
    PPLocationApplyCornerRadius(button, kPPLocationButtonCornerRadius);
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    button.accessibilityLabel = title;
}

- (UIView *)pp_makeMarkerView
{
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 154.0, 112.0)];
    container.backgroundColor = UIColor.clearColor;
    container.userInteractionEnabled = NO;
    self.markerView = container;

    UIView *callout = (UIView *)[PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed];
    callout.frame = CGRectMake(4.0, 0.0, 146.0, 50.0);
    if (@available(iOS 26.0, *)) {
        callout.backgroundColor = UIColor.clearColor;
    } else {
        callout.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.82];
    }
    PPLocationApplyCornerRadius(callout, kPPLocationButtonCornerRadius);
    callout.layer.borderWidth = 1.0;
    callout.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.42].CGColor;
    callout.layer.shadowColor = [UIColor colorWithWhite:0.08 alpha:1.0].CGColor;
    callout.layer.shadowOpacity = 0.10;
    callout.layer.shadowRadius = 16.0;
    callout.layer.shadowOffset = CGSizeMake(0.0, 9.0);
    self.markerCalloutView = callout;
    [container addSubview:callout];

    BOOL isRTL = Language.alignmentForCurrentLanguage == NSTextAlignmentRight;
    CGFloat iconX = isRTL ? 106.0 : 12.0;
    CGFloat labelX = isRTL ? 14.0 : 48.0;

    UIView *iconPlate = [[UIView alloc] initWithFrame:CGRectMake(iconX, 10.0, 30.0, 30.0)];
    if (@available(iOS 26.0, *)) {
        iconPlate.backgroundColor = UIColor.clearColor;
    } else {
        iconPlate.backgroundColor = [PPLocationAccentColor() colorWithAlphaComponent:0.12];
    }
    PPLocationApplyCornerRadius(iconPlate, 15.0);
    [callout addSubview:iconPlate];

    UIImageView *locationIcon = [[UIImageView alloc] initWithFrame:CGRectMake(7.0, 7.0, 16.0, 16.0)];
    locationIcon.image = [UIImage systemImageNamed:@"mappin.and.ellipse"];
    locationIcon.tintColor = PPLocationAccentColor();
    locationIcon.contentMode = UIViewContentModeScaleAspectFit;
    [iconPlate addSubview:locationIcon];

    self.markerEyebrowLabel = [[UILabel alloc] initWithFrame:CGRectMake(labelX, 8.0, 90.0, 14.0)];
    self.markerEyebrowLabel.text = kLang(@"company_location_nav_title");
    self.markerEyebrowLabel.font = [GM MidFontWithSize:10.0] ?: [UIFont systemFontOfSize:10.0 weight:UIFontWeightMedium];
    self.markerEyebrowLabel.textColor = [PPLocationSecondaryTextColor() colorWithAlphaComponent:0.90];
    self.markerEyebrowLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    self.markerEyebrowLabel.adjustsFontSizeToFitWidth = YES;
    self.markerEyebrowLabel.minimumScaleFactor = 0.80;
    [callout addSubview:self.markerEyebrowLabel];

    self.markerTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(labelX, 21.0, 90.0, 21.0)];
    self.markerTitleLabel.text = kLang(@"company_location_chip_title");
    self.markerTitleLabel.font = [GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightBold];
    self.markerTitleLabel.textColor = PPLocationPrimaryTextColor();
    self.markerTitleLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    self.markerTitleLabel.adjustsFontSizeToFitWidth = YES;
    self.markerTitleLabel.minimumScaleFactor = 0.74;
    [callout addSubview:self.markerTitleLabel];

    UIView *connector = [[UIView alloc] initWithFrame:CGRectMake(69.0, 47.0, 16.0, 16.0)];
    if (@available(iOS 26.0, *)) {
        connector.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.20];
    } else {
        connector.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.82];
    }
    connector.transform = CGAffineTransformMakeRotation((CGFloat)M_PI_4);
    PPLocationApplyCornerRadius(connector, 4.0);
    [container addSubview:connector];

    UIView *pinTail = [[UIView alloc] initWithFrame:CGRectMake(68.5, 85.0, 17.0, 17.0)];
    pinTail.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.92];
    PPLocationApplyCornerRadius(pinTail, 5.0);
    pinTail.transform = CGAffineTransformMakeRotation((CGFloat)M_PI_4);
    [container addSubview:pinTail];

    UIView *pinBody = [[UIView alloc] initWithFrame:CGRectMake(56.0, 54.0, 42.0, 42.0)];
    pinBody.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.94];
    PPLocationApplyCornerRadius(pinBody, 21.0);
    pinBody.layer.shadowColor = [PPLocationAccentColor() colorWithAlphaComponent:0.36].CGColor;
    pinBody.layer.shadowOpacity = 0.22;
    pinBody.layer.shadowRadius = 16.0;
    pinBody.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [container addSubview:pinBody];

    UIView *innerPlate = [[UIView alloc] initWithFrame:CGRectMake(8.0, 8.0, 26.0, 26.0)];
    innerPlate.backgroundColor = [PPLocationAccentColor() colorWithAlphaComponent:0.12];
    PPLocationApplyCornerRadius(innerPlate, 13.0);
    [pinBody addSubview:innerPlate];

    UIImageView *pawView = [[UIImageView alloc] initWithFrame:CGRectMake(6.0, 6.0, 14.0, 14.0)];
    pawView.image = [UIImage systemImageNamed:@"pawprint.fill"];
    pawView.tintColor = PPLocationAccentColor();
    pawView.contentMode = UIViewContentModeScaleAspectFit;
    [innerPlate addSubview:pawView];

    UIView *shadowDot = [[UIView alloc] initWithFrame:CGRectMake(60.0, 103.0, 34.0, 7.0)];
    shadowDot.backgroundColor = [[UIColor colorWithWhite:0.08 alpha:1.0] colorWithAlphaComponent:0.12];
    PPLocationApplyCornerRadius(shadowDot, 3.5);
    [container insertSubview:shadowDot atIndex:0];

    return container;
}

#pragma mark - Button Feedback

- (void)pp_registerButtonFeedback
{
    for (UIButton *button in @[self.openMapsButton, self.previewRouteButton, self.recenterButton, self.callButton, self.supportButton, self.shareButton]) {
        [button addTarget:self action:@selector(pp_buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
        [button addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside];
        [button addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchUpOutside];
        [button addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchCancel];
    }
}

- (void)pp_buttonTouchDown:(UIButton *)button
{
    if ([self pp_reduceMotionEnabled]) {
        return;
    }
    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        button.transform = CGAffineTransformMakeScale(0.985, 0.985);
        button.alpha = button.enabled ? 0.92 : 0.55;
    } completion:nil];
}

- (void)pp_buttonTouchUp:(UIButton *)button
{
    if ([self pp_reduceMotionEnabled]) {
        return;
    }
    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        button.transform = CGAffineTransformIdentity;
        button.alpha = button.enabled ? 1.0 : 0.55;
    } completion:nil];
}

- (void)pp_applyEnabledState:(BOOL)enabled toButton:(UIButton *)button
{
    button.enabled = enabled;
    button.alpha = enabled ? 1.0 : 0.55;
}

#pragma mark - Status

- (void)pp_setRouteStatusTitleKey:(NSString *)titleKey
                    detailTextKey:(NSString *)detailTextKey
                    detailOverride:(NSString *)detailOverride
                      accentTint:(UIColor *)accentTint
{
    self.routeStatusTitleLabel.text = titleKey.length > 0 ? kLang(titleKey) : @"";
    self.routeStatusValueLabel.text = detailOverride.length > 0 ? detailOverride : (detailTextKey.length > 0 ? kLang(detailTextKey) : @"");
    if (@available(iOS 26.0, *)) {
        self.routeStatusIconPlateView.backgroundColor = UIColor.clearColor;
    } else {
        self.routeStatusIconPlateView.backgroundColor = accentTint;
    }

    if (self.didRunEntrance && ![self pp_reduceMotionEnabled]) {
        self.routeStatusTitleLabel.superview.transform = CGAffineTransformMakeScale(0.988, 0.988);
        [UIView animateWithDuration:0.22
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            self.routeStatusTitleLabel.superview.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

#pragma mark - Alerts

- (void)showAlert:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"company_location_alert_title")
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"done")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - PPBottomSurface

- (PPBottomSurfaceKind)pp_preferredBottomSurfaceKind
{
    return PPBottomSurfaceKindNone;
}

@end
