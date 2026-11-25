//
//  LocationPickerViewController.m
//  Pure Pets
//
//  Next-Gen V10 Location Picker — First-Principles Architecture
//  Living map canvas, floating cockpit search & autocomplete, quick area chips,
//  ergonomic telemetry rail, tactile spring paw pin, and glass precision dock.
//

#import "LocationPickerViewController.h"
#import "CitiesManager.h"
#import "CityModel.h"
#import "CountryModel.h"
#import "PPAlertHelper.h"
#import "PPHUD.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <float.h>
#import <math.h>

@protocol PPBottomNavigationVisibilityControlling <NSObject>
- (void)pp_setBottomNavigationHidden:(BOOL)hidden animated:(BOOL)animated;
@end

static inline BOOL PPLocationPickerCoordinateIsUsable(CLLocationCoordinate2D coordinate)
{
    return CLLocationCoordinate2DIsValid(coordinate) &&
           isfinite(coordinate.latitude) &&
           isfinite(coordinate.longitude) &&
           !(fabs(coordinate.latitude) < DBL_EPSILON &&
             fabs(coordinate.longitude) < DBL_EPSILON);
}

static inline BOOL PPLocationPickerCoordinatesMatch(CLLocationCoordinate2D lhs,
                                                    CLLocationCoordinate2D rhs)
{
    if (!PPLocationPickerCoordinateIsUsable(lhs) ||
        !PPLocationPickerCoordinateIsUsable(rhs)) {
        return NO;
    }
    return fabs(lhs.latitude - rhs.latitude) < 0.00001 &&
           fabs(lhs.longitude - rhs.longitude) < 0.00001;
}

static inline UIColor *PPLocationPickerAccentColor(void)
{
    return AppPrimaryClr ?: [UIColor colorWithRed:0.87 green:0.42 blue:0.26 alpha:1.0];
}

static inline UIColor *PPLocationPickerPrimaryTextColor(void)
{
    return AppPrimaryTextClr ?: UIColor.labelColor;
}

static inline UIColor *PPLocationPickerSecondaryTextColor(void)
{
    return AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
}

static inline CGFloat PPLocationPickerHairlineWidth(void)
{
    return 1.0 / MAX(UIScreen.mainScreen.scale, 1.0);
}

static inline UIFont *PPLocationPickerScaledFont(UIFont *font, UIFontTextStyle textStyle)
{
    if (!font) {
        return nil;
    }
    return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:font];
}

typedef NS_ENUM(NSUInteger, PPLocationPickerDisplayState) {
    PPLocationPickerDisplayStateMoving,
    PPLocationPickerDisplayStateResolving,
    PPLocationPickerDisplayStateAddressReady,
    PPLocationPickerDisplayStateCoordinateReady,
    PPLocationPickerDisplayStateError
};

@interface PPLocationSearchResultItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@end

@implementation PPLocationSearchResultItem
@end

@interface LocationPickerViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

@property (nonatomic, strong) GMSMapView *mapView;
@property (nonatomic, strong) GMSGeocoder *geocoder;
@property (nonatomic, strong) CLGeocoder *appleGeocoder;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) GMSAddress *selectedAddress;
@property (nonatomic, assign) CLLocationCoordinate2D lastKnownCoordinate;
@property (nonatomic, assign) CLLocationCoordinate2D lastDeviceCoordinate;
@property (nonatomic, assign) BOOL hasExplicitInitialCoordinate;
@property (nonatomic, assign) BOOL shouldCenterOnNextLocationUpdate;
@property (nonatomic, assign) NSUInteger locationRequestGeneration;
@property (nonatomic, copy) NSString *selectedLocationTitle;

@property (nonatomic, copy) dispatch_block_t geocodeTimeoutBlock;
@property (nonatomic, copy) dispatch_block_t geocodeDebounceBlock;
@property (nonatomic, assign) BOOL geocodeRequestInFlight;
@property (nonatomic, assign) NSUInteger geocodeGeneration;
@property (nonatomic, assign) NSUInteger appleResolvedGeneration;

// Top Cockpit HUD: Search & Area Chips
@property (nonatomic, strong) UIView *topCockpitContainerView;
@property (nonatomic, strong) UIVisualEffectView *topCockpitChromeView;
@property (nonatomic, strong) UIStackView *topCockpitStackView;
@property (nonatomic, strong) UIView *searchBarContainerView;
@property (nonatomic, strong) UIButton *inlineCloseButton;
@property (nonatomic, strong) UIImageView *searchIconImageView;
@property (nonatomic, strong) UITextField *searchTextField;
@property (nonatomic, strong) UIButton *clearSearchButton;
@property (nonatomic, strong) UIActivityIndicatorView *searchSpinner;

@property (nonatomic, strong) UIScrollView *areasScrollView;
@property (nonatomic, strong) UIStackView *areasStackView;

// Search Results Dropdown Overlay
@property (nonatomic, strong) UIView *searchResultsContainerView;
@property (nonatomic, strong) UIVisualEffectView *searchResultsChromeView;
@property (nonatomic, strong) UITableView *searchResultsTableView;
@property (nonatomic, strong) NSArray<PPLocationSearchResultItem *> *searchResults;
@property (nonatomic, strong) MKLocalSearch *activeLocalSearch;
@property (nonatomic, copy) dispatch_block_t searchDebounceBlock;
@property (nonatomic, strong) NSLayoutConstraint *searchResultsHeightConstraint;

// Floating Telemetry Rail (Right / Trailing Edge)
@property (nonatomic, strong) UIView *telemetryRailContainerView;
@property (nonatomic, strong) UIVisualEffectView *telemetryRailChromeView;
@property (nonatomic, strong) UIStackView *telemetryRailStackView;
@property (nonatomic, strong) UIButton *recenterButton;
@property (nonatomic, strong) UIButton *mapTypeButton;
@property (nonatomic, strong) UIButton *zoomInButton;
@property (nonatomic, strong) UIButton *zoomOutButton;

// Precision Paw Pin
@property (nonatomic, strong) UIView *pinTargetRingView;
@property (nonatomic, strong) UIView *pinContainerView;
@property (nonatomic, strong) UIView *pinHeadView;
@property (nonatomic, strong) UIView *pinStemView;
@property (nonatomic, strong) UIImageView *pinPawImageView;
@property (nonatomic, strong) UIViewPropertyAnimator *pinAnimator;
@property (nonatomic, strong) NSLayoutConstraint *pinCenterYConstraint;

// Bottom Precision Dock
@property (nonatomic, strong) UIView *dockContainerView;
@property (nonatomic, strong) UIVisualEffectView *dockChromeView;
@property (nonatomic, strong) UIScrollView *dockScrollView;
@property (nonatomic, strong) UIStackView *dockStackView;

@property (nonatomic, strong) UIView *statusPillView;
@property (nonatomic, strong) UIStackView *statusStackView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIImageView *statusIconImageView;

@property (nonatomic, strong) UIStackView *quickActionsStackView;
@property (nonatomic, strong) UIButton *coordinatesCopyButton;
@property (nonatomic, strong) UIButton *shareLocationButton;

@property (nonatomic, strong) UILabel *addressLabel;
@property (nonatomic, strong) UILabel *coordinatesLabel;
@property (nonatomic, strong) UILabel *selectionHintLabel;

@property (nonatomic, strong) UIStackView *permissionStackView;
@property (nonatomic, strong) UIStackView *permissionMessageStackView;
@property (nonatomic, strong) UIImageView *permissionIconImageView;
@property (nonatomic, strong) UILabel *permissionLabel;
@property (nonatomic, strong) UIButton *permissionButton;

@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) NSLayoutConstraint *dockHeightConstraint;

@property (nonatomic, assign) PPLocationPickerDisplayState displayState;
@property (nonatomic, assign) BOOL managesHomeBottomNavigationVisibility;
@property (nonatomic, assign) BOOL capturedNavigationAppearance;
@property (nonatomic, assign) BOOL navigationBarWasHidden;
@property (nonatomic, assign) BOOL navigationBarWasTranslucent;
@property (nonatomic, strong) UIColor *savedNavigationTintColor;
@property (nonatomic, strong) UINavigationBarAppearance *savedStandardAppearance;
@property (nonatomic, strong) UINavigationBarAppearance *savedScrollEdgeAppearance;
@property (nonatomic, strong) UINavigationBarAppearance *savedCompactAppearance;
@property (nonatomic, strong) UINavigationBarAppearance *savedCompactScrollEdgeAppearance;

// Tactile Feedback
@property (nonatomic, strong) UIImpactFeedbackGenerator *lightImpact;
@property (nonatomic, strong) UIImpactFeedbackGenerator *mediumImpact;
@property (nonatomic, strong) UISelectionFeedbackGenerator *selectionFeedback;

@end

@implementation LocationPickerViewController

@synthesize rowDescriptor;

#pragma mark - Initialization

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (instancetype)initWithRowDescriptor:(XLFormRowDescriptor *)rowDescriptor
{
    self = [self init];
    if (self) {
        self.rowDescriptor = rowDescriptor;
    }
    return self;
}

- (void)dealloc
{
    [self pp_cancelPendingGeocodeWorkInvalidatingGeneration:YES];
    [self.appleGeocoder cancelGeocode];
    [self.locationManager stopUpdatingLocation];
    self.locationManager.delegate = nil;
    if (self.pinAnimator.state == UIViewAnimatingStateActive) {
        [self.pinAnimator stopAnimation:YES];
    }
    if (self.searchDebounceBlock) {
        dispatch_block_cancel(self.searchDebounceBlock);
        self.searchDebounceBlock = nil;
    }
    [self.activeLocalSearch cancel];
}

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.extendedLayoutIncludesOpaqueBars = YES;
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    self.lightImpact = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    self.mediumImpact = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    self.selectionFeedback = [[UISelectionFeedbackGenerator alloc] init];

    self.geocoder = [[GMSGeocoder alloc] init];
    self.appleGeocoder = [[CLGeocoder alloc] init];
    self.lastKnownCoordinate = kCLLocationCoordinate2DInvalid;
    self.lastDeviceCoordinate = kCLLocationCoordinate2DInvalid;

    self.hasExplicitInitialCoordinate =
        PPLocationPickerCoordinateIsUsable(self.initialCoordinate);
    self.shouldCenterOnNextLocationUpdate = NO;
    CLLocationCoordinate2D startCoordinate = self.hasExplicitInitialCoordinate
        ? self.initialCoordinate
        : [self pp_dohaCoordinate];
    self.lastKnownCoordinate = startCoordinate;

    [self pp_setupMapCanvasWithCoordinate:startCoordinate];
    [self pp_setupPrecisionPin];
    [self pp_setupTopCockpit];
    [self pp_setupSearchResultsOverlay];
    [self pp_setupTelemetryRail];
    [self pp_setupPrecisionDock];
    [self pp_configureAccessibilityActions];
    [self pp_setupLocationManager];
    [self pp_populateQuickAreas];

    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        [self applyDarkModeToMapView:self.mapView];
    }

    if (self.hasExplicitInitialCoordinate) {
        [self pp_updateMapCardWithFallbackCoordinate:startCoordinate];
    } else {
        [self pp_applyDohaFallbackAnimated:NO];
    }
    [self pp_scheduleReverseGeocodeForPosition:self.mapView.camera];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self pp_captureNavigationAppearanceIfNeeded];
    [self pp_setupNavigationChromeAnimated:animated];

    // Bulletproof: unconditionally ensure bottom navigation bar is hidden across all presentation modes
    [self pp_setBottomNavigationHidden:YES animated:animated];

    [self pp_handleLocationAuthorizationStatus:[self pp_locationAuthorizationStatus]];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    BOOL isLeavingPicker =
        self.isMovingFromParentViewController ||
        self.isBeingDismissed ||
        self.navigationController.isBeingDismissed;
    if (!isLeavingPicker) {
        return;
    }

    [self pp_cancelPendingGeocodeWorkInvalidatingGeneration:YES];
    [self.appleGeocoder cancelGeocode];
    [self.locationManager stopUpdatingLocation];
    if (self.pinAnimator.state == UIViewAnimatingStateActive) {
        [self.pinAnimator stopAnimation:YES];
    }
    self.pinAnimator = nil;

    [self pp_setBottomNavigationHidden:NO animated:animated];
    [self pp_restoreNavigationAppearanceAnimated:animated];

    id<UIViewControllerTransitionCoordinator> coordinator = self.transitionCoordinator;
    if (!coordinator) {
        return;
    }

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
        [self pp_setupNavigationChromeAnimated:NO];
        [self pp_setPinLifted:NO animated:NO];
        [self pp_scheduleReverseGeocodeForPosition:self.mapView.camera];
        [self pp_setBottomNavigationHidden:YES animated:YES];
    }];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.shouldCenterOnNextLocationUpdate = NO;
    self.locationRequestGeneration += 1;
    [self.locationManager stopUpdatingLocation];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    [self pp_updateDockHeightIfNeeded];
    [self pp_updateMapInsetsAndPinPosition];

    self.topCockpitContainerView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.topCockpitContainerView.bounds
                                   cornerRadius:24.0].CGPath;
    self.dockContainerView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.dockContainerView.bounds
                                   cornerRadius:PPCornerHero].CGPath;
    self.telemetryRailContainerView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.telemetryRailContainerView.bounds
                                   cornerRadius:24.0].CGPath;
    self.confirmButton.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.confirmButton.bounds
                                   cornerRadius:PPCornerMedium].CGPath;
}

#pragma mark - UI Chrome Helpers

- (UIVisualEffectView *)pp_makeChromePanelWithCornerRadius:(CGFloat)cornerRadius
{
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *panel = [[UIVisualEffectView alloc] initWithEffect:effect];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.clipsToBounds = YES;
    PPApplyContinuousCorners(panel, cornerRadius);
    panel.layer.borderWidth = PPLocationPickerHairlineWidth();
    panel.contentView.backgroundColor =
        [UIColor.systemBackgroundColor colorWithAlphaComponent:0.62];
    return panel;
}

- (UIView *)pp_makeShadowContainerWithCornerRadius:(CGFloat)cornerRadius
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = UIColor.clearColor;
    PPApplyContinuousCorners(container, cornerRadius);
    PPApplyCardShadow(container);
    return container;
}

- (UIButton *)pp_makeRoundChromeButtonWithSymbol:(NSString *)symbol
                                          action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = PPLocationPickerPrimaryTextColor();
    button.backgroundColor =
        [UIColor.systemBackgroundColor colorWithAlphaComponent:0.92];
    PPApplyContinuousCorners(button, PPTouchTargetMin * 0.5);
    PPApplyButtonShadow(button);
    button.layer.shadowOpacity = 0.08;
    button.layer.shadowRadius = 8.0;
    button.layer.shadowOffset = CGSizeMake(0.0, PPSpaceXS);
    button.layer.borderWidth = PPLocationPickerHairlineWidth();
    UIImageSymbolConfiguration *symbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:16.0
                                                        weight:UIImageSymbolWeightSemibold
                                                         scale:UIImageSymbolScaleMedium];
    [button setImage:[UIImage systemImageNamed:symbol
                              withConfiguration:symbolConfiguration]
            forState:UIControlStateNormal];
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:PPTouchTargetMin],
        [button.heightAnchor constraintEqualToConstant:PPTouchTargetMin]
    ]];
    return button;
}

#pragma mark - Navigation Setup

- (void)pp_setupNavigationChromeAnimated:(BOOL)animated
{
    self.navigationItem.title = @"";
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    // Use floating cockpit back/close button and hide the system bar so no duplicate nav bar appears.
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.leftBarButtonItems = nil;
    self.navigationItem.rightBarButtonItems = nil;

    if (!self.navigationController) {
        return;
    }

    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

#pragma mark - Map Canvas Setup

- (void)pp_setupMapCanvasWithCoordinate:(CLLocationCoordinate2D)startCoordinate
{
    GMSCameraPosition *camera =
        [GMSCameraPosition cameraWithLatitude:startCoordinate.latitude
                                     longitude:startCoordinate.longitude
                                          zoom:15.5];
    self.mapView = [GMSMapView mapWithFrame:CGRectZero camera:camera];
    self.mapView.delegate = self;
    self.mapView.myLocationEnabled = NO;
    self.mapView.settings.myLocationButton = NO;
    self.mapView.settings.compassButton = NO;
    self.mapView.settings.indoorPicker = NO;
    self.mapView.settings.rotateGestures = YES;
    self.mapView.settings.tiltGestures = YES;
    self.mapView.paddingAdjustmentBehavior =
        kGMSMapViewPaddingAdjustmentBehaviorNever;
    self.mapView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mapView.accessibilityLabel = kLang(@"location_picker_map_accessibility");
    [self.view addSubview:self.mapView];

    [NSLayoutConstraint activateConstraints:@[
        [self.mapView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.mapView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.mapView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.mapView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

#pragma mark - Precision Paw Pin Setup

- (void)pp_setupPrecisionPin
{
    UIColor *accentColor = PPLocationPickerAccentColor();

    self.pinTargetRingView = [[UIView alloc] init];
    self.pinTargetRingView.translatesAutoresizingMaskIntoConstraints = NO;
    self.pinTargetRingView.userInteractionEnabled = NO;
    self.pinTargetRingView.isAccessibilityElement = NO;
    self.pinTargetRingView.backgroundColor =
        [UIColor.systemBackgroundColor colorWithAlphaComponent:0.65];
    self.pinTargetRingView.layer.cornerRadius = PPSpaceSM;
    self.pinTargetRingView.layer.borderWidth = 1.5;
    self.pinTargetRingView.layer.borderColor = [accentColor colorWithAlphaComponent:0.35].CGColor;
    [self.view addSubview:self.pinTargetRingView];

    self.pinContainerView = [[UIView alloc] init];
    self.pinContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.pinContainerView.userInteractionEnabled = NO;
    self.pinContainerView.isAccessibilityElement = NO;
    [self.view addSubview:self.pinContainerView];

    self.pinStemView = [[UIView alloc] init];
    self.pinStemView.translatesAutoresizingMaskIntoConstraints = NO;
    self.pinStemView.backgroundColor = accentColor;
    self.pinStemView.transform = CGAffineTransformMakeRotation((CGFloat)M_PI_4);
    PPApplyContinuousCorners(self.pinStemView, PPSpaceXS);
    [self.pinContainerView addSubview:self.pinStemView];

    self.pinHeadView = [[UIView alloc] init];
    self.pinHeadView.translatesAutoresizingMaskIntoConstraints = NO;
    self.pinHeadView.backgroundColor = accentColor;
    PPApplyContinuousCorners(self.pinHeadView, 26.0);
    self.pinHeadView.layer.borderWidth = 1.5;
    self.pinHeadView.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:0.35].CGColor;
    self.pinHeadView.layer.shadowColor = accentColor.CGColor;
    self.pinHeadView.layer.shadowOpacity = 0.35;
    self.pinHeadView.layer.shadowRadius = 14.0;
    self.pinHeadView.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    [self.pinContainerView addSubview:self.pinHeadView];

    UIImageSymbolConfiguration *pawConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:24.0
                                                        weight:UIImageSymbolWeightSemibold
                                                         scale:UIImageSymbolScaleMedium];
    UIImage *pawImage = [UIImage systemImageNamed:@"pawprint"
                                 withConfiguration:pawConfiguration];
    self.pinPawImageView = [[UIImageView alloc] initWithImage:pawImage];
    self.pinPawImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.pinPawImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.pinPawImageView.tintColor = UIColor.whiteColor;
    [self.pinHeadView addSubview:self.pinPawImageView];

    self.pinCenterYConstraint =
        [self.pinTargetRingView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor];

    [NSLayoutConstraint activateConstraints:@[
        [self.pinTargetRingView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        self.pinCenterYConstraint,
        [self.pinTargetRingView.widthAnchor constraintEqualToConstant:40.0],
        [self.pinTargetRingView.heightAnchor constraintEqualToConstant:PPSpaceBase],

        [self.pinContainerView.centerXAnchor constraintEqualToAnchor:self.pinTargetRingView.centerXAnchor],
        [self.pinContainerView.bottomAnchor constraintEqualToAnchor:self.pinTargetRingView.centerYAnchor
                                                           constant:PPSpaceXXS],
        [self.pinContainerView.widthAnchor constraintEqualToConstant:56.0],
        [self.pinContainerView.heightAnchor constraintEqualToConstant:68.0],

        [self.pinStemView.centerXAnchor constraintEqualToAnchor:self.pinContainerView.centerXAnchor],
        [self.pinStemView.bottomAnchor constraintEqualToAnchor:self.pinContainerView.bottomAnchor
                                                      constant:-PPSpaceSM],
        [self.pinStemView.widthAnchor constraintEqualToConstant:PPSpaceLG],
        [self.pinStemView.heightAnchor constraintEqualToConstant:PPSpaceLG],

        [self.pinHeadView.centerXAnchor constraintEqualToAnchor:self.pinContainerView.centerXAnchor],
        [self.pinHeadView.topAnchor constraintEqualToAnchor:self.pinContainerView.topAnchor],
        [self.pinHeadView.widthAnchor constraintEqualToConstant:52.0],
        [self.pinHeadView.heightAnchor constraintEqualToConstant:52.0],

        [self.pinPawImageView.centerXAnchor constraintEqualToAnchor:self.pinHeadView.centerXAnchor],
        [self.pinPawImageView.centerYAnchor constraintEqualToAnchor:self.pinHeadView.centerYAnchor],
        [self.pinPawImageView.widthAnchor constraintEqualToConstant:27.0],
        [self.pinPawImageView.heightAnchor constraintEqualToConstant:27.0]
    ]];
}

#pragma mark - Top Cockpit HUD (Search & Area Chips)

- (void)pp_setupTopCockpit
{
    self.topCockpitContainerView = [self pp_makeShadowContainerWithCornerRadius:24.0];
    [self.view addSubview:self.topCockpitContainerView];

    self.topCockpitChromeView = [self pp_makeChromePanelWithCornerRadius:24.0];
    [self.topCockpitContainerView addSubview:self.topCockpitChromeView];

    self.topCockpitStackView = [[UIStackView alloc] init];
    self.topCockpitStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topCockpitStackView.axis = UILayoutConstraintAxisVertical;
    self.topCockpitStackView.alignment = UIStackViewAlignmentFill;
    self.topCockpitStackView.spacing = PPSpaceSM;
    self.topCockpitStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.topCockpitChromeView.contentView addSubview:self.topCockpitStackView];

    // Search Row (Close button + Search Bar)
    UIStackView *searchRow = [[UIStackView alloc] init];
    searchRow.translatesAutoresizingMaskIntoConstraints = NO;
    searchRow.axis = UILayoutConstraintAxisHorizontal;
    searchRow.alignment = UIStackViewAlignmentCenter;
    searchRow.spacing = PPSpaceSM;
    searchRow.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.topCockpitStackView addArrangedSubview:searchRow];

    NSString *closeSymbolName = (self.navigationController.viewControllers.firstObject == self && self.navigationController.presentingViewController != nil) || !self.navigationController
        ? @"xmark"
        : (Language.isRTL ? @"chevron.right" : @"chevron.left");
    self.inlineCloseButton = [self pp_makeRoundChromeButtonWithSymbol:closeSymbolName action:@selector(pp_closePicker)];
    self.inlineCloseButton.accessibilityLabel = kLang(@"Close");
    [searchRow addArrangedSubview:self.inlineCloseButton];

    // Search Bar Input Container
    self.searchBarContainerView = [[UIView alloc] init];
    self.searchBarContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBarContainerView.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.75];
    PPApplyContinuousCorners(self.searchBarContainerView, 20.0);
    self.searchBarContainerView.layer.borderWidth = PPLocationPickerHairlineWidth();
    self.searchBarContainerView.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.18].CGColor;
    [searchRow addArrangedSubview:self.searchBarContainerView];

    UIStackView *searchFieldStack = [[UIStackView alloc] init];
    searchFieldStack.translatesAutoresizingMaskIntoConstraints = NO;
    searchFieldStack.axis = UILayoutConstraintAxisHorizontal;
    searchFieldStack.alignment = UIStackViewAlignmentCenter;
    searchFieldStack.spacing = PPSpaceSM;
    searchFieldStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.searchBarContainerView addSubview:searchFieldStack];

    self.searchIconImageView = [[UIImageView alloc] init];
    self.searchIconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchIconImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.searchIconImageView.tintColor = PPLocationPickerAccentColor();
    UIImageSymbolConfiguration *searchIconConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightSemibold];
    self.searchIconImageView.image = [UIImage systemImageNamed:@"magnifyingglass" withConfiguration:searchIconConfig];
    [searchFieldStack addArrangedSubview:self.searchIconImageView];

    self.searchTextField = [[UITextField alloc] init];
    self.searchTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchTextField.delegate = self;
    self.searchTextField.placeholder = kLang(@"location_picker_search_placeholder");
    self.searchTextField.textAlignment = Language.alignmentForCurrentLanguage;
    self.searchTextField.font = PPLocationPickerScaledFont([GM MidFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium], UIFontTextStyleSubheadline);
    self.searchTextField.textColor = PPLocationPickerPrimaryTextColor();
    self.searchTextField.returnKeyType = UIReturnKeySearch;
    self.searchTextField.clearButtonMode = UITextFieldViewModeNever;
    [self.searchTextField addTarget:self action:@selector(pp_searchFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [searchFieldStack addArrangedSubview:self.searchTextField];

    self.searchSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.searchSpinner.color = PPLocationPickerAccentColor();
    self.searchSpinner.hidesWhenStopped = YES;
    [searchFieldStack addArrangedSubview:self.searchSpinner];

    self.clearSearchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clearSearchButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.clearSearchButton.tintColor = UIColor.secondaryLabelColor;
    UIImage *clearImage = [UIImage systemImageNamed:@"xmark.circle.fill" withConfiguration:searchIconConfig];
    [self.clearSearchButton setImage:clearImage forState:UIControlStateNormal];
    [self.clearSearchButton addTarget:self action:@selector(pp_clearSearchTapped) forControlEvents:UIControlEventTouchUpInside];
    self.clearSearchButton.hidden = YES;
    [searchFieldStack addArrangedSubview:self.clearSearchButton];

    [NSLayoutConstraint activateConstraints:@[
        [searchFieldStack.leadingAnchor constraintEqualToAnchor:self.searchBarContainerView.leadingAnchor constant:PPSpaceMD],
        [searchFieldStack.trailingAnchor constraintEqualToAnchor:self.searchBarContainerView.trailingAnchor constant:-PPSpaceMD],
        [searchFieldStack.topAnchor constraintEqualToAnchor:self.searchBarContainerView.topAnchor constant:PPSpaceXS],
        [searchFieldStack.bottomAnchor constraintEqualToAnchor:self.searchBarContainerView.bottomAnchor constant:-PPSpaceXS],
        [self.searchBarContainerView.heightAnchor constraintEqualToConstant:44.0],
        [self.searchIconImageView.widthAnchor constraintEqualToConstant:20.0],
        [self.clearSearchButton.widthAnchor constraintEqualToConstant:24.0]
    ]];

    // Area Chips Horizontal Carousel
    self.areasScrollView = [[UIScrollView alloc] init];
    self.areasScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.areasScrollView.showsHorizontalScrollIndicator = NO;
    self.areasScrollView.alwaysBounceHorizontal = YES;
    [self.topCockpitStackView addArrangedSubview:self.areasScrollView];

    self.areasStackView = [[UIStackView alloc] init];
    self.areasStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.areasStackView.axis = UILayoutConstraintAxisHorizontal;
    self.areasStackView.alignment = UIStackViewAlignmentCenter;
    self.areasStackView.spacing = PPSpaceSM;
    self.areasStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.areasScrollView addSubview:self.areasStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.topCockpitContainerView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:PPSpaceMD],
        [self.topCockpitContainerView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-PPSpaceMD],
        [self.topCockpitContainerView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:PPSpaceXS],

        [self.topCockpitChromeView.leadingAnchor constraintEqualToAnchor:self.topCockpitContainerView.leadingAnchor],
        [self.topCockpitChromeView.trailingAnchor constraintEqualToAnchor:self.topCockpitContainerView.trailingAnchor],
        [self.topCockpitChromeView.topAnchor constraintEqualToAnchor:self.topCockpitContainerView.topAnchor],
        [self.topCockpitChromeView.bottomAnchor constraintEqualToAnchor:self.topCockpitContainerView.bottomAnchor],

        [self.topCockpitStackView.leadingAnchor constraintEqualToAnchor:self.topCockpitChromeView.contentView.leadingAnchor constant:PPSpaceSM],
        [self.topCockpitStackView.trailingAnchor constraintEqualToAnchor:self.topCockpitChromeView.contentView.trailingAnchor constant:-PPSpaceSM],
        [self.topCockpitStackView.topAnchor constraintEqualToAnchor:self.topCockpitChromeView.contentView.topAnchor constant:PPSpaceSM],
        [self.topCockpitStackView.bottomAnchor constraintEqualToAnchor:self.topCockpitChromeView.contentView.bottomAnchor constant:-PPSpaceSM],

        [self.areasScrollView.heightAnchor constraintEqualToConstant:34.0],
        [self.areasStackView.leadingAnchor constraintEqualToAnchor:self.areasScrollView.contentLayoutGuide.leadingAnchor],
        [self.areasStackView.trailingAnchor constraintEqualToAnchor:self.areasScrollView.contentLayoutGuide.trailingAnchor],
        [self.areasStackView.topAnchor constraintEqualToAnchor:self.areasScrollView.contentLayoutGuide.topAnchor],
        [self.areasStackView.bottomAnchor constraintEqualToAnchor:self.areasScrollView.contentLayoutGuide.bottomAnchor],
        [self.areasStackView.heightAnchor constraintEqualToAnchor:self.areasScrollView.frameLayoutGuide.heightAnchor]
    ]];
}

#pragma mark - Search Results Overlay Setup

- (void)pp_setupSearchResultsOverlay
{
    self.searchResults = @[];

    self.searchResultsContainerView = [self pp_makeShadowContainerWithCornerRadius:20.0];
    self.searchResultsContainerView.hidden = YES;
    [self.view addSubview:self.searchResultsContainerView];

    self.searchResultsChromeView = [self pp_makeChromePanelWithCornerRadius:20.0];
    [self.searchResultsContainerView addSubview:self.searchResultsChromeView];

    self.searchResultsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.searchResultsTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchResultsTableView.delegate = self;
    self.searchResultsTableView.dataSource = self;
    self.searchResultsTableView.backgroundColor = UIColor.clearColor;
    self.searchResultsTableView.separatorColor = [UIColor.separatorColor colorWithAlphaComponent:0.25];
    self.searchResultsTableView.separatorInset = UIEdgeInsetsMake(0.0, 52.0, 0.0, 16.0);
    self.searchResultsTableView.showsVerticalScrollIndicator = YES;
    [self.searchResultsChromeView.contentView addSubview:self.searchResultsTableView];

    self.searchResultsHeightConstraint =
        [self.searchResultsContainerView.heightAnchor constraintEqualToConstant:0.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.searchResultsContainerView.leadingAnchor constraintEqualToAnchor:self.topCockpitContainerView.leadingAnchor],
        [self.searchResultsContainerView.trailingAnchor constraintEqualToAnchor:self.topCockpitContainerView.trailingAnchor],
        [self.searchResultsContainerView.topAnchor constraintEqualToAnchor:self.topCockpitContainerView.bottomAnchor constant:PPSpaceSM],
        self.searchResultsHeightConstraint,

        [self.searchResultsChromeView.leadingAnchor constraintEqualToAnchor:self.searchResultsContainerView.leadingAnchor],
        [self.searchResultsChromeView.trailingAnchor constraintEqualToAnchor:self.searchResultsContainerView.trailingAnchor],
        [self.searchResultsChromeView.topAnchor constraintEqualToAnchor:self.searchResultsContainerView.topAnchor],
        [self.searchResultsChromeView.bottomAnchor constraintEqualToAnchor:self.searchResultsContainerView.bottomAnchor],

        [self.searchResultsTableView.leadingAnchor constraintEqualToAnchor:self.searchResultsChromeView.contentView.leadingAnchor],
        [self.searchResultsTableView.trailingAnchor constraintEqualToAnchor:self.searchResultsChromeView.contentView.trailingAnchor],
        [self.searchResultsTableView.topAnchor constraintEqualToAnchor:self.searchResultsChromeView.contentView.topAnchor constant:PPSpaceXS],
        [self.searchResultsTableView.bottomAnchor constraintEqualToAnchor:self.searchResultsChromeView.contentView.bottomAnchor constant:-PPSpaceXS]
    ]];
}

#pragma mark - Floating Telemetry Rail Setup

- (void)pp_setupTelemetryRail
{
    self.telemetryRailContainerView = [self pp_makeShadowContainerWithCornerRadius:24.0];
    [self.view addSubview:self.telemetryRailContainerView];

    self.telemetryRailChromeView = [self pp_makeChromePanelWithCornerRadius:24.0];
    [self.telemetryRailContainerView addSubview:self.telemetryRailChromeView];

    self.telemetryRailStackView = [[UIStackView alloc] init];
    self.telemetryRailStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.telemetryRailStackView.axis = UILayoutConstraintAxisVertical;
    self.telemetryRailStackView.alignment = UIStackViewAlignmentCenter;
    self.telemetryRailStackView.spacing = PPSpaceSM;
    [self.telemetryRailChromeView.contentView addSubview:self.telemetryRailStackView];

    self.recenterButton = [self pp_makeRoundChromeButtonWithSymbol:@"location.fill" action:@selector(centerToUserLocation)];
    self.recenterButton.accessibilityLabel = kLang(@"location_picker_recenter");
    [self.telemetryRailStackView addArrangedSubview:self.recenterButton];

    self.mapTypeButton = [self pp_makeRoundChromeButtonWithSymbol:@"square.2.layers.3d" action:@selector(pp_cycleMapType)];
    self.mapTypeButton.accessibilityLabel = kLang(@"location_picker_map_type_standard");
    [self.telemetryRailStackView addArrangedSubview:self.mapTypeButton];

    self.zoomInButton = [self pp_makeRoundChromeButtonWithSymbol:@"plus" action:@selector(pp_zoomInTapped)];
    self.zoomInButton.accessibilityLabel = kLang(@"location_picker_zoom_in");
    [self.telemetryRailStackView addArrangedSubview:self.zoomInButton];

    self.zoomOutButton = [self pp_makeRoundChromeButtonWithSymbol:@"minus" action:@selector(pp_zoomOutTapped)];
    self.zoomOutButton.accessibilityLabel = kLang(@"location_picker_zoom_out");
    [self.telemetryRailStackView addArrangedSubview:self.zoomOutButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.telemetryRailContainerView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-PPSpaceMD],
        [self.telemetryRailContainerView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-PPSpaceLG],

        [self.telemetryRailChromeView.leadingAnchor constraintEqualToAnchor:self.telemetryRailContainerView.leadingAnchor],
        [self.telemetryRailChromeView.trailingAnchor constraintEqualToAnchor:self.telemetryRailContainerView.trailingAnchor],
        [self.telemetryRailChromeView.topAnchor constraintEqualToAnchor:self.telemetryRailContainerView.topAnchor],
        [self.telemetryRailChromeView.bottomAnchor constraintEqualToAnchor:self.telemetryRailContainerView.bottomAnchor],

        [self.telemetryRailStackView.leadingAnchor constraintEqualToAnchor:self.telemetryRailChromeView.contentView.leadingAnchor constant:PPSpaceXS],
        [self.telemetryRailStackView.trailingAnchor constraintEqualToAnchor:self.telemetryRailChromeView.contentView.trailingAnchor constant:-PPSpaceXS],
        [self.telemetryRailStackView.topAnchor constraintEqualToAnchor:self.telemetryRailChromeView.contentView.topAnchor constant:PPSpaceSM],
        [self.telemetryRailStackView.bottomAnchor constraintEqualToAnchor:self.telemetryRailChromeView.contentView.bottomAnchor constant:-PPSpaceSM]
    ]];
}

#pragma mark - Bottom Precision Dock Setup

- (void)pp_setupPrecisionDock
{
    self.dockContainerView = [self pp_makeShadowContainerWithCornerRadius:PPCornerHero];
    [self.view addSubview:self.dockContainerView];

    self.dockChromeView = [self pp_makeChromePanelWithCornerRadius:PPCornerHero];
    [self.dockContainerView addSubview:self.dockChromeView];

    self.dockScrollView = [[UIScrollView alloc] init];
    self.dockScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.dockScrollView.alwaysBounceVertical = NO;
    self.dockScrollView.showsVerticalScrollIndicator = NO;
    self.dockScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.dockChromeView.contentView addSubview:self.dockScrollView];

    self.dockStackView = [[UIStackView alloc] init];
    self.dockStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.dockStackView.axis = UILayoutConstraintAxisVertical;
    self.dockStackView.alignment = UIStackViewAlignmentFill;
    self.dockStackView.spacing = PPSpaceMD;
    self.dockStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.dockScrollView addSubview:self.dockStackView];

    [self pp_buildStatusAndQuickActionsRow];
    [self pp_buildSelectionLabels];
    [self pp_buildPermissionState];

    self.confirmButton = [self pp_makePrimaryConfirmButton];
    [self.dockStackView addArrangedSubview:self.confirmButton];

    self.dockHeightConstraint = [self.dockContainerView.heightAnchor constraintEqualToConstant:254.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.dockContainerView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:PPSpaceBase],
        [self.dockContainerView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-PPSpaceBase],
        [self.dockContainerView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-PPSpaceMD],
        self.dockHeightConstraint,

        [self.dockChromeView.leadingAnchor constraintEqualToAnchor:self.dockContainerView.leadingAnchor],
        [self.dockChromeView.trailingAnchor constraintEqualToAnchor:self.dockContainerView.trailingAnchor],
        [self.dockChromeView.topAnchor constraintEqualToAnchor:self.dockContainerView.topAnchor],
        [self.dockChromeView.bottomAnchor constraintEqualToAnchor:self.dockContainerView.bottomAnchor],

        [self.dockScrollView.leadingAnchor constraintEqualToAnchor:self.dockChromeView.contentView.leadingAnchor],
        [self.dockScrollView.trailingAnchor constraintEqualToAnchor:self.dockChromeView.contentView.trailingAnchor],
        [self.dockScrollView.topAnchor constraintEqualToAnchor:self.dockChromeView.contentView.topAnchor],
        [self.dockScrollView.bottomAnchor constraintEqualToAnchor:self.dockChromeView.contentView.bottomAnchor],

        [self.dockStackView.leadingAnchor constraintEqualToAnchor:self.dockScrollView.contentLayoutGuide.leadingAnchor constant:PPSpaceBase],
        [self.dockStackView.trailingAnchor constraintEqualToAnchor:self.dockScrollView.contentLayoutGuide.trailingAnchor constant:-PPSpaceBase],
        [self.dockStackView.topAnchor constraintEqualToAnchor:self.dockScrollView.contentLayoutGuide.topAnchor constant:PPSpaceBase],
        [self.dockStackView.bottomAnchor constraintEqualToAnchor:self.dockScrollView.contentLayoutGuide.bottomAnchor constant:-PPSpaceBase],
        [self.dockStackView.widthAnchor constraintEqualToAnchor:self.dockScrollView.frameLayoutGuide.widthAnchor constant:-(PPSpaceBase * 2.0)]
    ]];
}

- (void)pp_buildStatusAndQuickActionsRow
{
    UIStackView *headerRow = [[UIStackView alloc] init];
    headerRow.translatesAutoresizingMaskIntoConstraints = NO;
    headerRow.axis = UILayoutConstraintAxisHorizontal;
    headerRow.alignment = UIStackViewAlignmentCenter;
    headerRow.spacing = PPSpaceSM;
    headerRow.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.dockStackView addArrangedSubview:headerRow];

    // Status Pill
    self.statusPillView = [[UIView alloc] init];
    self.statusPillView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.statusPillView, PPCornerSmall);
    self.statusPillView.layer.borderWidth = PPLocationPickerHairlineWidth();
    self.statusPillView.isAccessibilityElement = YES;
    [headerRow addArrangedSubview:self.statusPillView];

    self.statusStackView = [[UIStackView alloc] init];
    self.statusStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusStackView.axis = UILayoutConstraintAxisHorizontal;
    self.statusStackView.alignment = UIStackViewAlignmentCenter;
    self.statusStackView.spacing = PPSpaceSM;
    self.statusStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.statusPillView addSubview:self.statusStackView];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = PPLocationPickerAccentColor();
    self.spinner.hidesWhenStopped = YES;
    self.spinner.isAccessibilityElement = NO;

    self.statusIconImageView = [[UIImageView alloc] init];
    self.statusIconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusIconImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.statusIconImageView.isAccessibilityElement = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.statusIconImageView.widthAnchor constraintEqualToConstant:16.0],
        [self.statusIconImageView.heightAnchor constraintEqualToConstant:16.0]
    ]];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = PPLocationPickerScaledFont([GM boldFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:PPFontCaption1 weight:UIFontWeightSemibold], UIFontTextStyleCaption1);
    self.statusLabel.adjustsFontForContentSizeCategory = YES;
    self.statusLabel.numberOfLines = 1;
    self.statusLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.statusLabel.isAccessibilityElement = NO;

    [self.statusStackView addArrangedSubview:self.spinner];
    [self.statusStackView addArrangedSubview:self.statusIconImageView];
    [self.statusStackView addArrangedSubview:self.statusLabel];
    [self.statusLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    [NSLayoutConstraint activateConstraints:@[
        [self.statusStackView.leadingAnchor constraintEqualToAnchor:self.statusPillView.leadingAnchor constant:PPSpaceMD],
        [self.statusStackView.trailingAnchor constraintEqualToAnchor:self.statusPillView.trailingAnchor constant:-PPSpaceMD],
        [self.statusStackView.topAnchor constraintEqualToAnchor:self.statusPillView.topAnchor constant:PPSpaceXS],
        [self.statusStackView.bottomAnchor constraintEqualToAnchor:self.statusPillView.bottomAnchor constant:-PPSpaceXS],
        [self.statusPillView.heightAnchor constraintGreaterThanOrEqualToConstant:32.0]
    ]];

    UIView *spacer = [[UIView alloc] init];
    [headerRow addArrangedSubview:spacer];

    // Quick Utility Buttons: Copy & Share
    self.quickActionsStackView = [[UIStackView alloc] init];
    self.quickActionsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.quickActionsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.quickActionsStackView.alignment = UIStackViewAlignmentCenter;
    self.quickActionsStackView.spacing = PPSpaceXS;
    self.quickActionsStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [headerRow addArrangedSubview:self.quickActionsStackView];

    UIImageSymbolConfiguration *quickActionConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIImageSymbolWeightMedium];

    self.coordinatesCopyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.coordinatesCopyButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.coordinatesCopyButton.tintColor = PPLocationPickerPrimaryTextColor();
    self.coordinatesCopyButton.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.75];
    PPApplyContinuousCorners(self.coordinatesCopyButton, 16.0);
    self.coordinatesCopyButton.layer.borderWidth = PPLocationPickerHairlineWidth();
    self.coordinatesCopyButton.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.2].CGColor;
    [self.coordinatesCopyButton setImage:[UIImage systemImageNamed:@"doc.on.doc" withConfiguration:quickActionConfig] forState:UIControlStateNormal];
    [self.coordinatesCopyButton addTarget:self action:@selector(pp_copyCoordinatesTapped) forControlEvents:UIControlEventTouchUpInside];
    self.coordinatesCopyButton.accessibilityLabel = kLang(@"location_picker_copy_coordinates");
    [self.quickActionsStackView addArrangedSubview:self.coordinatesCopyButton];

    self.shareLocationButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.shareLocationButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.shareLocationButton.tintColor = PPLocationPickerPrimaryTextColor();
    self.shareLocationButton.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.75];
    PPApplyContinuousCorners(self.shareLocationButton, 16.0);
    self.shareLocationButton.layer.borderWidth = PPLocationPickerHairlineWidth();
    self.shareLocationButton.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.2].CGColor;
    [self.shareLocationButton setImage:[UIImage systemImageNamed:@"square.and.arrow.up" withConfiguration:quickActionConfig] forState:UIControlStateNormal];
    [self.shareLocationButton addTarget:self action:@selector(pp_shareLocationTapped) forControlEvents:UIControlEventTouchUpInside];
    self.shareLocationButton.accessibilityLabel = kLang(@"location_picker_share_location");
    [self.quickActionsStackView addArrangedSubview:self.shareLocationButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.coordinatesCopyButton.widthAnchor constraintEqualToConstant:34.0],
        [self.coordinatesCopyButton.heightAnchor constraintEqualToConstant:34.0],
        [self.shareLocationButton.widthAnchor constraintEqualToConstant:34.0],
        [self.shareLocationButton.heightAnchor constraintEqualToConstant:34.0]
    ]];
}

- (void)pp_buildSelectionLabels
{
    self.addressLabel = [[UILabel alloc] init];
    self.addressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.addressLabel.font =
        PPLocationPickerScaledFont([GM boldFontWithSize:PPFontTitle2] ?:
                                   [UIFont systemFontOfSize:PPFontTitle2 weight:UIFontWeightBold],
                                   UIFontTextStyleTitle2);
    self.addressLabel.adjustsFontForContentSizeCategory = YES;
    self.addressLabel.numberOfLines = 0;
    self.addressLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.addressLabel.textColor = PPLocationPickerPrimaryTextColor();
    self.addressLabel.isAccessibilityElement = YES;
    self.addressLabel.accessibilityHint = kLang(@"location_picker_precision_actions_hint");
    [self.dockStackView addArrangedSubview:self.addressLabel];

    self.coordinatesLabel = [[UILabel alloc] init];
    self.coordinatesLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UIFont *coordinateFont = [UIFont monospacedDigitSystemFontOfSize:PPFontFootnote weight:UIFontWeightMedium];
    self.coordinatesLabel.font = PPLocationPickerScaledFont(coordinateFont, UIFontTextStyleFootnote);
    self.coordinatesLabel.adjustsFontForContentSizeCategory = YES;
    self.coordinatesLabel.numberOfLines = 0;
    self.coordinatesLabel.textAlignment = Language.isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    self.coordinatesLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    self.coordinatesLabel.textColor = PPLocationPickerSecondaryTextColor();
    self.coordinatesLabel.isAccessibilityElement = YES;
    [self.dockStackView addArrangedSubview:self.coordinatesLabel];

    self.selectionHintLabel = [[UILabel alloc] init];
    self.selectionHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionHintLabel.font =
        PPLocationPickerScaledFont([GM MidFontWithSize:PPFontFootnote] ?:
                                   [UIFont systemFontOfSize:PPFontFootnote weight:UIFontWeightRegular],
                                   UIFontTextStyleFootnote);
    self.selectionHintLabel.adjustsFontForContentSizeCategory = YES;
    self.selectionHintLabel.numberOfLines = 0;
    self.selectionHintLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.selectionHintLabel.textColor = PPLocationPickerSecondaryTextColor();
    [self.dockStackView addArrangedSubview:self.selectionHintLabel];
}

- (void)pp_buildPermissionState
{
    self.permissionStackView = [[UIStackView alloc] init];
    self.permissionStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.permissionStackView.axis = UILayoutConstraintAxisVertical;
    self.permissionStackView.alignment = UIStackViewAlignmentFill;
    self.permissionStackView.spacing = PPSpaceSM;
    self.permissionStackView.hidden = YES;
    [self.dockStackView addArrangedSubview:self.permissionStackView];

    self.permissionMessageStackView = [[UIStackView alloc] init];
    self.permissionMessageStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.permissionMessageStackView.axis = UILayoutConstraintAxisHorizontal;
    self.permissionMessageStackView.alignment = UIStackViewAlignmentTop;
    self.permissionMessageStackView.spacing = PPSpaceSM;
    self.permissionMessageStackView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.permissionStackView addArrangedSubview:self.permissionMessageStackView];

    UIImage *permissionImage = [UIImage systemImageNamed:@"location.slash.fill"];
    self.permissionIconImageView = [[UIImageView alloc] initWithImage:permissionImage];
    self.permissionIconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.permissionIconImageView.tintColor = AppWarningClr ?: UIColor.systemOrangeColor;
    self.permissionIconImageView.isAccessibilityElement = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.permissionIconImageView.widthAnchor constraintEqualToConstant:PPSpaceLG],
        [self.permissionIconImageView.heightAnchor constraintEqualToConstant:PPSpaceLG]
    ]];

    self.permissionLabel = [[UILabel alloc] init];
    self.permissionLabel.font =
        PPLocationPickerScaledFont([GM MidFontWithSize:PPFontFootnote] ?:
                                   [UIFont systemFontOfSize:PPFontFootnote weight:UIFontWeightMedium],
                                   UIFontTextStyleFootnote);
    self.permissionLabel.adjustsFontForContentSizeCategory = YES;
    self.permissionLabel.numberOfLines = 0;
    self.permissionLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.permissionLabel.textColor = PPLocationPickerPrimaryTextColor();

    [self.permissionMessageStackView addArrangedSubview:self.permissionIconImageView];
    [self.permissionMessageStackView addArrangedSubview:self.permissionLabel];

    self.permissionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.permissionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.permissionButton.backgroundColor = [PPLocationPickerAccentColor() colorWithAlphaComponent:0.12];
    self.permissionButton.tintColor = PPLocationPickerAccentColor();
    PPApplyContinuousCorners(self.permissionButton, PPCornerSmall);
    self.permissionButton.titleLabel.font =
        PPLocationPickerScaledFont([GM boldFontWithSize:PPFontSubheadline] ?:
                                   [UIFont systemFontOfSize:PPFontSubheadline weight:UIFontWeightSemibold],
                                   UIFontTextStyleSubheadline);
    self.permissionButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.permissionButton.titleLabel.numberOfLines = 0;
    [self.permissionButton setTitle:kLang(@"Open Settings") forState:UIControlStateNormal];
    self.permissionButton.contentEdgeInsets = UIEdgeInsetsMake(PPSpaceSM, PPSpaceMD, PPSpaceSM, PPSpaceMD);
    [self.permissionButton addTarget:self action:@selector(pp_openLocationSettings) forControlEvents:UIControlEventTouchUpInside];
    [self.permissionButton.heightAnchor constraintGreaterThanOrEqualToConstant:PPTouchTargetMin].active = YES;
    [self.permissionStackView addArrangedSubview:self.permissionButton];
}

- (UIButton *)pp_makePrimaryConfirmButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = PPLocationPickerAccentColor();
    PPApplyContinuousCorners(button, PPCornerMedium);
    PPApplyButtonShadow(button);
    button.titleLabel.font =
        PPLocationPickerScaledFont([GM boldFontWithSize:PPFontHeadline] ?:
                                   [UIFont systemFontOfSize:PPFontHeadline weight:UIFontWeightSemibold],
                                   UIFontTextStyleHeadline);
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [button setTitle:kLang(@"location_picker_confirm") forState:UIControlStateNormal];
    button.contentEdgeInsets = UIEdgeInsetsMake(PPSpaceMD, PPSpaceBase, PPSpaceMD, PPSpaceBase);
    [button addTarget:self action:@selector(confirmLocationTapped) forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:PPButtonHeightLG].active = YES;
    button.accessibilityHint = kLang(@"location_picker_confirm_hint");
    return button;
}

#pragma mark - Quick Areas Carousel Population

- (void)pp_populateQuickAreas
{
    for (UIView *view in self.areasStackView.arrangedSubviews) {
        [view removeFromSuperview];
    }

    CountryModel *currentCountry = CitiesManager.shared.CurrentCountry ?: [CitiesManager.shared qatarCountry];
    NSArray<CityModel *> *cities = [CitiesManager.shared citiesForCountryCode:currentCountry.iso];
    if (cities.count == 0) {
        cities = [CitiesManager.shared citiesForCurrentCountry];
    }

    NSMutableArray<NSDictionary *> *areaItems = [NSMutableArray array];
    for (CityModel *city in cities) {
        NSString *name = Language.isRTL ? (city.arName.length > 0 ? city.arName : city.name) : (city.enName.length > 0 ? city.enName : city.name);
        if (name.length > 0 && PPLocationPickerCoordinateIsUsable(CLLocationCoordinate2DMake(city.latitude, city.longitude))) {
            [areaItems addObject:@{
                @"name": name,
                @"lat": @(city.latitude),
                @"lng": @(city.longitude)
            }];
        }
    }

    // Default regional key hubs fallback if cities list is empty
    if (areaItems.count == 0) {
        NSArray *defaultHubs = @[
            @{@"name": Language.isRTL ? @"الدوحة" : @"Doha", @"lat": @(25.2854), @"lng": @(51.5310)},
            @{@"name": Language.isRTL ? @"لوسيل" : @"Lusail", @"lat": @(25.4207), @"lng": @(51.4900)},
            @{@"name": Language.isRTL ? @"الوكرة" : @"Al Wakrah", @"lat": @(25.1768), @"lng": @(51.6034)},
            @{@"name": Language.isRTL ? @"الخور" : @"Al Khor", @"lat": @(25.6839), @"lng": @(51.5058)},
            @{@"name": Language.isRTL ? @"الريان" : @"Al Rayyan", @"lat": @(25.2919), @"lng": @(51.4244)},
            @{@"name": Language.isRTL ? @"اللؤلؤة" : @"The Pearl", @"lat": @(25.3713), @"lng": @(51.5516)}
        ];
        [areaItems addObjectsFromArray:defaultHubs];
    }

    UIImageSymbolConfiguration *chipSymbolConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:11.0 weight:UIImageSymbolWeightSemibold];
    UIImage *chipPinImage = [UIImage systemImageNamed:@"mappin" withConfiguration:chipSymbolConfig];

    for (NSDictionary *area in areaItems) {
        UIButton *chip = [UIButton buttonWithType:UIButtonTypeSystem];
        chip.translatesAutoresizingMaskIntoConstraints = NO;
        chip.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.80];
        chip.tintColor = PPLocationPickerPrimaryTextColor();
        PPApplyContinuousCorners(chip, 14.0);
        chip.layer.borderWidth = PPLocationPickerHairlineWidth();
        chip.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.2].CGColor;
        [chip setImage:chipPinImage forState:UIControlStateNormal];
        chip.imageView.tintColor = PPLocationPickerAccentColor();
        [chip setTitle:area[@"name"] forState:UIControlStateNormal];
        chip.titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
        chip.contentEdgeInsets = UIEdgeInsetsMake(PPSpaceXS, PPSpaceSM, PPSpaceXS, PPSpaceSM);
        chip.titleEdgeInsets = UIEdgeInsetsMake(0.0, 4.0, 0.0, -4.0);

        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake([area[@"lat"] doubleValue], [area[@"lng"] doubleValue]);
        __weak typeof(self) weakSelf = self;
        UIAction *action = [UIAction actionWithHandler:^(__kindof UIAction * _Nonnull actionHandler) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.lightImpact impactOccurred];
            [self pp_moveCameraToCoordinate:coord zoom:15.5];
        }];
        [chip addAction:action forControlEvents:UIControlEventTouchUpInside];

        [self.areasStackView addArrangedSubview:chip];
    }
}

#pragma mark - Search Field & Autocomplete Logic

- (void)pp_searchFieldDidChange:(UITextField *)textField
{
    NSString *query = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.clearSearchButton.hidden = (query.length == 0);

    if (self.searchDebounceBlock) {
        dispatch_block_cancel(self.searchDebounceBlock);
        self.searchDebounceBlock = nil;
    }
    [self.activeLocalSearch cancel];

    if (query.length < 2) {
        [self.searchSpinner stopAnimating];
        [self pp_dismissSearchResultsAnimated:YES];
        return;
    }

    [self.searchSpinner startAnimating];

    __weak typeof(self) weakSelf = self;
    self.searchDebounceBlock = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self pp_performSearchWithQuery:query];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), self.searchDebounceBlock);
}

- (void)pp_clearSearchTapped
{
    [self.lightImpact impactOccurred];
    self.searchTextField.text = @"";
    self.clearSearchButton.hidden = YES;
    [self.searchSpinner stopAnimating];
    [self pp_dismissSearchResultsAnimated:YES];
    [self.searchTextField resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    NSString *query = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (query.length >= 2) {
        [self pp_performSearchWithQuery:query];
    }
    return YES;
}

- (void)pp_performSearchWithQuery:(NSString *)query
{
    NSMutableArray<PPLocationSearchResultItem *> *results = [NSMutableArray array];

    // 1. Instant local matching against registered cities
    CountryModel *country = CitiesManager.shared.CurrentCountry ?: [CitiesManager.shared qatarCountry];
    NSArray<CityModel *> *cities = [CitiesManager.shared citiesForCountryCode:country.iso];
    for (CityModel *city in cities) {
        NSString *ar = city.arName ?: @"";
        NSString *en = city.enName ?: @"";
        if ([ar localizedCaseInsensitiveContainsString:query] || [en localizedCaseInsensitiveContainsString:query]) {
            PPLocationSearchResultItem *item = [[PPLocationSearchResultItem alloc] init];
            item.title = Language.isRTL ? (ar.length > 0 ? ar : en) : (en.length > 0 ? en : ar);
            item.subtitle = country.name ?: @"";
            item.coordinate = CLLocationCoordinate2DMake(city.latitude, city.longitude);
            [results addObject:item];
        }
    }

    // 2. High-performance Apple MapKit Local POI & Landmark search
    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];
    request.naturalLanguageQuery = query;
    CLLocationCoordinate2D center = self.mapView.camera.target;
    if (PPLocationPickerCoordinateIsUsable(center)) {
        request.region = MKCoordinateRegionMakeWithDistance(center, 60000, 60000);
    }

    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    self.activeLocalSearch = search;

    __weak typeof(self) weakSelf = self;
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.searchSpinner stopAnimating];

            if (!error && response.mapItems.count > 0) {
                for (MKMapItem *mapItem in response.mapItems) {
                    PPLocationSearchResultItem *item = [[PPLocationSearchResultItem alloc] init];
                    item.title = mapItem.name ?: @"";
                    item.subtitle = mapItem.placemark.title ?: @"";
                    item.coordinate = mapItem.placemark.coordinate;
                    [results addObject:item];
                }
            }

            self.searchResults = [results copy];
            [self.searchResultsTableView reloadData];
            [self pp_presentSearchResultsAnimated:YES];
        });
    }];
}

- (void)pp_presentSearchResultsAnimated:(BOOL)animated
{
    if (self.searchResults.count == 0) {
        [self pp_dismissSearchResultsAnimated:animated];
        return;
    }

    CGFloat rowHeight = 54.0;
    CGFloat targetHeight = MIN(260.0, (CGFloat)self.searchResults.count * rowHeight + 10.0);
    self.searchResultsHeightConstraint.constant = targetHeight;
    self.searchResultsContainerView.hidden = NO;

    void (^animations)(void) = ^{
        self.searchResultsContainerView.alpha = 1.0;
        self.searchResultsContainerView.transform = CGAffineTransformIdentity;
        [self.view layoutIfNeeded];
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        animations();
    } else {
        self.searchResultsContainerView.alpha = 0.0;
        self.searchResultsContainerView.transform = CGAffineTransformMakeTranslation(0.0, -10.0);
        [UIView animateWithDuration:PPAnimDurationNormal
                              delay:0.0
             usingSpringWithDamping:0.8
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:animations
                         completion:nil];
    }
}

- (void)pp_dismissSearchResultsAnimated:(BOOL)animated
{
    if (self.searchResultsContainerView.hidden) return;

    void (^animations)(void) = ^{
        self.searchResultsContainerView.alpha = 0.0;
        self.searchResultsContainerView.transform = CGAffineTransformMakeTranslation(0.0, -8.0);
    };
    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        self.searchResultsContainerView.hidden = YES;
        self.searchResultsHeightConstraint.constant = 0.0;
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        animations();
        completion(YES);
    } else {
        [UIView animateWithDuration:PPAnimDurationFast animations:animations completion:completion];
    }
}

#pragma mark - UITableView DataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.searchResults.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 54.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellID = @"PPSearchResultCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.backgroundColor = UIColor.clearColor;
        cell.textLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        cell.textLabel.textColor = PPLocationPickerPrimaryTextColor();
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
        cell.detailTextLabel.textColor = PPLocationPickerSecondaryTextColor();
        cell.imageView.tintColor = PPLocationPickerAccentColor();
    }

    if (indexPath.row < (NSInteger)self.searchResults.count) {
        PPLocationSearchResultItem *item = self.searchResults[indexPath.row];
        cell.textLabel.text = item.title;
        cell.detailTextLabel.text = item.subtitle;
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightMedium];
        cell.imageView.image = [UIImage systemImageNamed:@"mappin.circle.fill" withConfiguration:config];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.searchResults.count) return;

    [self.mediumImpact impactOccurred];
    PPLocationSearchResultItem *item = self.searchResults[indexPath.row];
    [self.searchTextField resignFirstResponder];
    [self pp_dismissSearchResultsAnimated:YES];

    [self pp_moveCameraToCoordinate:item.coordinate zoom:16.5];
}

#pragma mark - Telemetry Actions

- (void)pp_cycleMapType
{
    [self.lightImpact impactOccurred];
    if (self.mapView.mapType == kGMSTypeNormal) {
        self.mapView.mapType = kGMSTypeSatellite;
        [PPHUD showInfo:kLang(@"location_picker_map_type_satellite")];
    } else if (self.mapView.mapType == kGMSTypeSatellite) {
        self.mapView.mapType = kGMSTypeHybrid;
        [PPHUD showInfo:kLang(@"location_picker_map_type_hybrid")];
    } else {
        self.mapView.mapType = kGMSTypeNormal;
        [PPHUD showInfo:kLang(@"location_picker_map_type_standard")];
    }
}

- (void)pp_zoomInTapped
{
    [self.lightImpact impactOccurred];
    float targetZoom = MIN(self.mapView.maxZoom, self.mapView.camera.zoom + 1.0f);
    [self.mapView animateToZoom:targetZoom];
}

- (void)pp_zoomOutTapped
{
    [self.lightImpact impactOccurred];
    float targetZoom = MAX(self.mapView.minZoom, self.mapView.camera.zoom - 1.0f);
    [self.mapView animateToZoom:targetZoom];
}

- (void)pp_copyCoordinatesTapped
{
    CLLocationCoordinate2D coord = self.mapView.camera.target;
    if (!PPLocationPickerCoordinateIsUsable(coord)) {
        coord = self.lastKnownCoordinate;
    }
    if (!PPLocationPickerCoordinateIsUsable(coord)) return;

    [self.mediumImpact impactOccurred];
    NSString *coordStr = [NSString stringWithFormat:@"%.6f, %.6f", coord.latitude, coord.longitude];
    [UIPasteboard generalPasteboard].string = coordStr;
    [PPHUD showSuccess:kLang(@"location_picker_coordinates_copied")];
}

- (void)pp_shareLocationTapped
{
    CLLocationCoordinate2D coord = self.mapView.camera.target;
    if (!PPLocationPickerCoordinateIsUsable(coord)) {
        coord = self.lastKnownCoordinate;
    }
    if (!PPLocationPickerCoordinateIsUsable(coord)) return;

    [self.lightImpact impactOccurred];
    NSString *title = self.selectedLocationTitle.length > 0 ? self.selectedLocationTitle : kLang(@"location_picker_pinned_point");
    NSString *mapURLStr = [NSString stringWithFormat:@"https://maps.google.com/?q=%.6f,%.6f", coord.latitude, coord.longitude];
    NSURL *url = [NSURL URLWithString:mapURLStr];

    NSArray *items = url ? @[title, url] : @[title];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    if (activityVC.popoverPresentationController) {
        activityVC.popoverPresentationController.sourceView = self.shareLocationButton;
        activityVC.popoverPresentationController.sourceRect = self.shareLocationButton.bounds;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - Layout Dynamics

- (void)pp_updateDockHeightIfNeeded
{
    CGFloat contentWidth = CGRectGetWidth(self.dockScrollView.bounds) - (PPSpaceBase * 2.0);
    if (contentWidth <= 0.0) return;

    CGSize fittingSize = CGSizeMake(contentWidth, UILayoutFittingCompressedSize.height);
    CGSize contentSize =
        [self.dockStackView systemLayoutSizeFittingSize:fittingSize
                         withHorizontalFittingPriority:UILayoutPriorityRequired
                               verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    CGFloat desiredHeight = MAX(200.0, contentSize.height + (PPSpaceBase * 2.0));
    CGFloat safeHeight = CGRectGetHeight(self.view.safeAreaLayoutGuide.layoutFrame);
    CGFloat heightRatio = self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact ? 0.60 : 0.54;
    CGFloat maximumHeight = MAX(180.0, floor(safeHeight * heightRatio));
    CGFloat resolvedHeight = MIN(desiredHeight, maximumHeight);
    if (fabs(self.dockHeightConstraint.constant - resolvedHeight) > 0.5) {
        self.dockHeightConstraint.constant = resolvedHeight;
    }
    self.dockScrollView.scrollEnabled = desiredHeight > maximumHeight + 0.5;
}

- (void)pp_updateMapInsetsAndPinPosition
{
    if (CGRectIsEmpty(self.topCockpitContainerView.frame) || CGRectIsEmpty(self.dockContainerView.frame)) {
        return;
    }

    CGFloat topInset = CGRectGetMaxY(self.topCockpitContainerView.frame) + PPSpaceSM;
    CGFloat bottomInset = CGRectGetHeight(self.view.bounds) - CGRectGetMinY(self.dockContainerView.frame) + PPSpaceSM;
    UIEdgeInsets padding = UIEdgeInsetsMake(topInset, 0.0, bottomInset, 0.0);
    if (!UIEdgeInsetsEqualToEdgeInsets(self.mapView.padding, padding)) {
        self.mapView.padding = padding;
    }

    CGFloat targetCenterOffset = (topInset - bottomInset) * 0.5;
    if (fabs(self.pinCenterYConstraint.constant - targetCenterOffset) > 0.5) {
        self.pinCenterYConstraint.constant = targetCenterOffset;
    }
}

#pragma mark - Presentation States

- (NSString *)pp_coordinateStringForCoordinate:(CLLocationCoordinate2D)coordinate
{
    if (!PPLocationPickerCoordinateIsUsable(coordinate)) {
        return kLang(@"location_picker_coordinates_unavailable");
    }
    return [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
}

- (void)pp_setConfirmButtonEnabled:(BOOL)enabled
{
    self.confirmButton.enabled = enabled;
    self.confirmButton.alpha = enabled ? 1.0 : 0.52;
}

- (void)pp_applyDisplayState:(PPLocationPickerDisplayState)state
                   statusKey:(NSString *)statusKey
                  symbolName:(NSString *)symbolName
                   tintColor:(UIColor *)tintColor
                     loading:(BOOL)loading
{
    self.displayState = state;
    UIColor *resolvedTint = tintColor ?: PPLocationPickerAccentColor();
    NSString *statusText = kLang(statusKey);

    self.statusLabel.text = statusText;
    self.statusLabel.textColor = resolvedTint;
    self.statusPillView.backgroundColor = [resolvedTint colorWithAlphaComponent:loading ? 0.14 : 0.10];
    self.statusPillView.layer.borderColor = [resolvedTint colorWithAlphaComponent:0.25].CGColor;
    self.statusPillView.accessibilityLabel = statusText;

    if (loading) {
        self.statusIconImageView.hidden = YES;
        [self.spinner startAnimating];
    } else {
        [self.spinner stopAnimating];
        self.statusIconImageView.hidden = NO;
        self.statusIconImageView.image = [UIImage systemImageNamed:symbolName];
        self.statusIconImageView.tintColor = resolvedTint;
    }
}

- (void)pp_applyLocationPresentationWithTitle:(NSString *)title
                                   coordinate:(CLLocationCoordinate2D)coordinate
                                      hintKey:(NSString *)hintKey
{
    NSString *resolvedTitle = title.length > 0 ? title : kLang(@"location_picker_choose_point");
    NSString *coordinateText = [self pp_coordinateStringForCoordinate:coordinate];
    self.addressLabel.text = resolvedTitle;
    self.coordinatesLabel.text = coordinateText;
    self.coordinatesLabel.accessibilityLabel =
        [NSString stringWithFormat:@"%@: %@", kLang(@"location_picker_coordinates_label"), coordinateText];
    self.selectionHintLabel.text = kLang(hintKey);
    [self pp_setConfirmButtonEnabled:PPLocationPickerCoordinateIsUsable(coordinate)];
}

- (void)pp_showMovingStateForCoordinate:(CLLocationCoordinate2D)coordinate
{
    self.selectedAddress = nil;
    self.selectedLocationTitle = [self pp_coordinateStringForCoordinate:coordinate];
    [self pp_applyLocationPresentationWithTitle:kLang(@"location_picker_pinned_point")
                                     coordinate:coordinate
                                        hintKey:@"location_picker_hint_moving"];
    [self pp_setConfirmButtonEnabled:NO];
    [self pp_applyDisplayState:PPLocationPickerDisplayStateMoving
                     statusKey:@"location_picker_status_moving"
                    symbolName:@"hand.draw.fill"
                     tintColor:PPLocationPickerAccentColor()
                       loading:NO];
}

- (void)pp_showResolvingStateForCoordinate:(CLLocationCoordinate2D)coordinate
{
    self.selectedAddress = nil;
    self.selectedLocationTitle = [self pp_coordinateStringForCoordinate:coordinate];
    [self pp_applyLocationPresentationWithTitle:kLang(@"location_picker_pinned_point")
                                     coordinate:coordinate
                                        hintKey:@"location_picker_hint_resolving"];
    [self pp_applyDisplayState:PPLocationPickerDisplayStateResolving
                     statusKey:@"location_picker_status_resolving"
                    symbolName:nil
                     tintColor:PPLocationPickerAccentColor()
                       loading:YES];
}

- (void)pp_updateMapCardWithFallbackCoordinate:(CLLocationCoordinate2D)coordinate
{
    self.selectedLocationTitle = [self pp_coordinateStringForCoordinate:coordinate];
    [self pp_applyLocationPresentationWithTitle:kLang(@"location_picker_pinned_point")
                                     coordinate:coordinate
                                        hintKey:@"location_picker_hint_coordinates_ready"];
    [self pp_applyDisplayState:PPLocationPickerDisplayStateCoordinateReady
                     statusKey:@"location_picker_status_coordinates_ready"
                    symbolName:@"scope"
                     tintColor:(AppWarningClr ?: UIColor.systemOrangeColor)
                       loading:NO];
}

- (void)updateMapCardWithGMSAddress:(GMSAddress *)address
{
    if (!address) return;

    NSString *fullAddress = [self pp_compactAddressTitleFromGMSAddress:address];
    if (fullAddress.length == 0) {
        fullAddress = kLang(@"location_picker_address_unavailable");
    }
    self.selectedLocationTitle = fullAddress;
    [self pp_applyLocationPresentationWithTitle:fullAddress
                                     coordinate:address.coordinate
                                        hintKey:@"location_picker_hint_address_ready"];
    [self pp_applyDisplayState:PPLocationPickerDisplayStateAddressReady
                     statusKey:@"location_picker_status_address_ready"
                    symbolName:@"checkmark.circle.fill"
                     tintColor:(AppSuccessClr ?: UIColor.systemGreenColor)
                       loading:NO];
    [self pp_announceResolvedLocationIfNeeded:fullAddress statusKey:@"location_picker_status_address_ready"];
}

- (void)pp_updateMapCardWithResolvedTitle:(NSString *)resolvedTitle
                               coordinate:(CLLocationCoordinate2D)coordinate
{
    self.selectedLocationTitle = resolvedTitle ?: @"";
    [self pp_applyLocationPresentationWithTitle:self.selectedLocationTitle
                                     coordinate:coordinate
                                        hintKey:@"location_picker_hint_area_ready"];
    [self pp_applyDisplayState:PPLocationPickerDisplayStateCoordinateReady
                     statusKey:@"location_picker_status_area_ready"
                    symbolName:@"mappin.and.ellipse"
                     tintColor:(AppSuccessClr ?: UIColor.systemGreenColor)
                       loading:NO];
    [self pp_announceResolvedLocationIfNeeded:self.selectedLocationTitle statusKey:@"location_picker_status_area_ready"];
}

- (void)pp_showInvalidCoordinateState
{
    self.selectedAddress = nil;
    self.selectedLocationTitle = @"";
    [self pp_applyLocationPresentationWithTitle:kLang(@"location_picker_choose_point")
                                     coordinate:kCLLocationCoordinate2DInvalid
                                        hintKey:@"location_picker_hint_unavailable"];
    [self pp_applyDisplayState:PPLocationPickerDisplayStateError
                     statusKey:@"location_picker_status_unavailable"
                    symbolName:@"exclamationmark.triangle.fill"
                     tintColor:(AppErrorClr ?: UIColor.systemRedColor)
                       loading:NO];
}

- (void)pp_announceResolvedLocationIfNeeded:(NSString *)locationTitle
                                  statusKey:(NSString *)statusKey
{
    if (!UIAccessibilityIsVoiceOverRunning() || locationTitle.length == 0 || !self.view.window) {
        return;
    }
    NSString *announcement = [NSString stringWithFormat:@"%@: %@", kLang(statusKey), locationTitle];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, announcement);
}

#pragma mark - Defaults & Geocoder Helpers

- (CLLocationCoordinate2D)pp_dohaCoordinate
{
    CountryModel *qatar = [CitiesManager.shared qatarCountry];
    CityModel *doha = [CitiesManager.shared defaultCityForCountry:qatar];
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(doha.latitude, doha.longitude);
    if (PPLocationPickerCoordinateIsUsable(coordinate)) {
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
    if (cityName.length > 0) return cityName;
    if (countryName.length > 0) return countryName;
    return kLang(@"location_picker_doha_fallback");
}

- (void)pp_applyDohaFallbackAnimated:(BOOL)animated
{
    CLLocationCoordinate2D coordinate = [self pp_dohaCoordinate];
    self.lastKnownCoordinate = coordinate;
    self.selectedAddress = nil;
    self.selectedLocationTitle = [self pp_dohaTitle];

    GMSCameraPosition *camera =
        [GMSCameraPosition cameraWithLatitude:coordinate.latitude
                                     longitude:coordinate.longitude
                                          zoom:15.5];
    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [self.mapView animateToCameraPosition:camera];
    } else {
        self.mapView.camera = camera;
    }
    [self pp_updateMapCardWithResolvedTitle:self.selectedLocationTitle coordinate:coordinate];
}

- (NSString *)pp_compactAddressTitleFromGMSAddress:(GMSAddress *)address
{
    if (!address) return @"";
    NSString *title = [LocationPickerViewController titleFromAddress:address];
    if (title.length > 0) return title;
    return [address.lines componentsJoinedByString:@", "] ?: @"";
}

- (NSString *)pp_compactTitleFromPlacemark:(CLPlacemark *)placemark
{
    if (!placemark) return @"";
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

#pragma mark - Location Authorization & GPS

- (void)pp_setupLocationManager
{
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
    self.locationManager.distanceFilter = 10.0;
}

- (CLAuthorizationStatus)pp_locationAuthorizationStatus
{
    if (@available(iOS 14.0, *)) {
        return self.locationManager.authorizationStatus;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [CLLocationManager authorizationStatus];
#pragma clang diagnostic pop
}

- (BOOL)pp_locationAuthorizationAllowsUpdates:(CLAuthorizationStatus)status
{
    return status == kCLAuthorizationStatusAuthorizedAlways ||
           status == kCLAuthorizationStatusAuthorizedWhenInUse;
}

- (void)pp_handleLocationAuthorizationStatus:(CLAuthorizationStatus)status
{
    [self pp_updatePermissionPresentationForStatus:status];
    if (status == kCLAuthorizationStatusNotDetermined) {
        if (self.shouldCenterOnNextLocationUpdate) {
            [self.locationManager requestWhenInUseAuthorization];
        }
        return;
    }
    if ([self pp_locationAuthorizationAllowsUpdates:status]) {
        if (self.shouldCenterOnNextLocationUpdate) {
            [self pp_requestCurrentLocation];
        }
    } else {
        self.shouldCenterOnNextLocationUpdate = NO;
        [self.locationManager stopUpdatingLocation];
    }
}

- (void)pp_updatePermissionPresentationForStatus:(CLAuthorizationStatus)status
{
    BOOL authorized = [self pp_locationAuthorizationAllowsUpdates:status];
    BOOL denied = status == kCLAuthorizationStatusDenied;
    BOOL restricted = status == kCLAuthorizationStatusRestricted;
    self.permissionStackView.hidden = !(denied || restricted);
    self.permissionButton.hidden = restricted;
    self.permissionLabel.text = restricted
        ? kLang(@"location_picker_permission_restricted")
        : kLang(@"location_picker_permission_denied");
    self.mapView.myLocationEnabled = authorized;
    BOOL canRequest = authorized || status == kCLAuthorizationStatusNotDetermined;
    self.recenterButton.enabled = canRequest;
    self.recenterButton.alpha = canRequest ? 1.0 : 0.52;
    self.recenterButton.accessibilityValue = canRequest
        ? nil
        : kLang(@"location_picker_recenter_unavailable");
    [self.view setNeedsLayout];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    CLLocation *location = locations.lastObject;
    if (!location || !PPLocationPickerCoordinateIsUsable(location.coordinate) ||
        location.horizontalAccuracy < 0 || location.horizontalAccuracy > 200 ||
        fabs(location.timestamp.timeIntervalSinceNow) > 30.0) {
        [manager stopUpdatingLocation];
        self.shouldCenterOnNextLocationUpdate = NO;
        [self pp_updatePermissionPresentationForStatus:[self pp_locationAuthorizationStatus]];
        [PPHUD showInfo:kLang(@"ordering_address_location_unavailable")];
        return;
    }

    self.lastDeviceCoordinate = location.coordinate;
    [manager stopUpdatingLocation];
    self.recenterButton.enabled = YES;
    self.recenterButton.alpha = 1.0;
    self.recenterButton.accessibilityValue = nil;

    if (!self.shouldCenterOnNextLocationUpdate) return;
    self.shouldCenterOnNextLocationUpdate = NO;
    [self pp_moveCameraToCoordinate:location.coordinate zoom:16.0];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    BOOL wasRequested = self.shouldCenterOnNextLocationUpdate;
    self.shouldCenterOnNextLocationUpdate = NO;
    [manager stopUpdatingLocation];
    NSLog(@"[LocationPicker] location update failed: %@", error.localizedDescription);
    BOOL canRetry = [self pp_locationAuthorizationAllowsUpdates:[self pp_locationAuthorizationStatus]];
    self.recenterButton.enabled = canRetry;
    self.recenterButton.alpha = canRetry ? 1.0 : 0.52;
    self.recenterButton.accessibilityValue = nil;
    if (error.code == kCLErrorDenied) {
        [self pp_updatePermissionPresentationForStatus:[self pp_locationAuthorizationStatus]];
    } else if (wasRequested) {
        [PPHUD showInfo:kLang(@"ordering_address_location_unavailable")];
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (@available(iOS 14.0, *)) return;
    [self pp_handleLocationAuthorizationStatus:status];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager API_AVAILABLE(ios(14.0))
{
    [self pp_handleLocationAuthorizationStatus:manager.authorizationStatus];
}

#pragma mark - Map Events & Tactile Pin Physics

- (void)mapView:(GMSMapView *)mapView willMove:(BOOL)gesture
{
    if (gesture) {
        [self.selectionFeedback selectionChanged];
        self.shouldCenterOnNextLocationUpdate = NO;
        [self.locationManager stopUpdatingLocation];
        CLAuthorizationStatus status = [self pp_locationAuthorizationStatus];
        BOOL canRecenter = [self pp_locationAuthorizationAllowsUpdates:status] || status == kCLAuthorizationStatusNotDetermined;
        self.recenterButton.enabled = canRecenter;
        self.recenterButton.alpha = canRecenter ? 1.0 : 0.52;
        self.recenterButton.accessibilityValue = nil;
    }
    [self pp_cancelPendingGeocodeWorkInvalidatingGeneration:YES];
    [self.appleGeocoder cancelGeocode];
    CLLocationCoordinate2D coordinate = mapView.camera.target;
    if (PPLocationPickerCoordinateIsUsable(coordinate)) {
        [self pp_showMovingStateForCoordinate:coordinate];
    } else {
        [self pp_showInvalidCoordinateState];
    }
    [self pp_setPinLifted:YES animated:YES];
}

- (void)mapView:(GMSMapView *)mapView idleAtCameraPosition:(GMSCameraPosition *)position
{
    (void)mapView;
    [self.mediumImpact impactOccurred];
    [self pp_setPinLifted:NO animated:YES];
    if (!PPLocationPickerCoordinateIsUsable(position.target)) {
        [self pp_showInvalidCoordinateState];
        return;
    }

    self.lastKnownCoordinate = position.target;
    self.selectedAddress = nil;
    [self pp_updateMapCardWithFallbackCoordinate:position.target];
    [self pp_scheduleReverseGeocodeForPosition:position];
}

- (void)pp_setPinLifted:(BOOL)lifted animated:(BOOL)animated
{
    if (self.pinAnimator.state == UIViewAnimatingStateActive) {
        [self.pinAnimator stopAnimation:NO];
        [self.pinAnimator finishAnimationAtPosition:UIViewAnimatingPositionCurrent];
    }
    self.pinAnimator = nil;

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    __weak typeof(self) weakSelf = self;
    void (^changes)(void) = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.pinTargetRingView.alpha = lifted ? 0.35 : 1.0;
        self.pinTargetRingView.transform = (!reduceMotion && lifted)
            ? CGAffineTransformMakeScale(0.72, 0.72)
            : CGAffineTransformIdentity;
        self.pinContainerView.transform = (!reduceMotion && lifted)
            ? CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -16.0),
                                      CGAffineTransformMakeScale(1.06, 1.06))
            : CGAffineTransformIdentity;
        self.pinHeadView.layer.shadowRadius = lifted ? 20.0 : 14.0;
        self.pinHeadView.layer.shadowOpacity = lifted ? 0.45 : 0.35;
    };

    if (!animated || reduceMotion || !self.view.window) {
        changes();
        return;
    }

    UISpringTimingParameters *timing =
        [[UISpringTimingParameters alloc] initWithDampingRatio:(lifted ? 0.90 : 0.65)
                                         initialVelocity:CGVectorMake(0.0, lifted ? -0.3 : 0.55)];
    self.pinAnimator = [[UIViewPropertyAnimator alloc] initWithDuration:PPAnimDurationNormal
                                                      timingParameters:timing];
    [self.pinAnimator addAnimations:changes];
    [self.pinAnimator startAnimation];
}

#pragma mark - Reverse Geocoding

- (void)pp_scheduleReverseGeocodeForPosition:(GMSCameraPosition *)position
{
    CLLocationCoordinate2D target = position.target;
    if (!PPLocationPickerCoordinateIsUsable(target)) {
        [self pp_showInvalidCoordinateState];
        return;
    }

    [self pp_cancelPendingGeocodeDebounce];
    NSUInteger generation = ++self.geocodeGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_block_t debounceBlock = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.geocodeGeneration) return;
        self.geocodeDebounceBlock = nil;
        [self startReverseGeocodeForCoordinate:target generation:generation];
    });
    self.geocodeDebounceBlock = debounceBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(PPAnimDurationNormal * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), debounceBlock);
}

- (void)startReverseGeocodeForCoordinate:(CLLocationCoordinate2D)target
                              generation:(NSUInteger)generation
{
    if (!PPLocationPickerCoordinateIsUsable(target) || generation != self.geocodeGeneration) {
        return;
    }

    self.lastKnownCoordinate = target;
    self.geocodeRequestInFlight = YES;
    [self pp_cancelPendingGeocodeTimeout];
    [self pp_showResolvingStateForCoordinate:target];

    __weak typeof(self) weakSelf = self;
    dispatch_block_t timeoutBlock = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.geocodeGeneration ||
            !self.geocodeRequestInFlight ||
            ![self pp_cameraStillTargetsCoordinate:target]) {
            return;
        }
        self.geocodeTimeoutBlock = nil;
        self.geocodeRequestInFlight = NO;
        [self pp_updateMapCardWithFallbackCoordinate:target];
        [self pp_tryAppleReverseGeocodeForCoordinate:target generation:generation];
    });
    self.geocodeTimeoutBlock = timeoutBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), timeoutBlock);

    [self.geocoder reverseGeocodeCoordinate:target
                          completionHandler:^(GMSReverseGeocodeResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || generation != self.geocodeGeneration ||
                ![self pp_cameraStillTargetsCoordinate:target]) {
                return;
            }

            [self pp_cancelPendingGeocodeTimeout];
            self.geocodeRequestInFlight = NO;
            if (response.firstResult) {
                self.selectedAddress = response.firstResult;
                self.lastKnownCoordinate = response.firstResult.coordinate;
                [self.appleGeocoder cancelGeocode];
                [self updateMapCardWithGMSAddress:response.firstResult];
                return;
            }

            if (self.appleResolvedGeneration == generation) return;

            NSLog(@"[LocationPicker] reverse geocode fallback: %@", error.localizedDescription ?: @"No result");
            self.selectedAddress = nil;
            [self pp_updateMapCardWithFallbackCoordinate:target];
            [self pp_tryAppleReverseGeocodeForCoordinate:target generation:generation];
        });
    }];
}

- (void)pp_tryAppleReverseGeocodeForCoordinate:(CLLocationCoordinate2D)coordinate
                                    generation:(NSUInteger)generation
{
    if (!PPLocationPickerCoordinateIsUsable(coordinate) ||
        generation != self.geocodeGeneration ||
        self.appleGeocoder.isGeocoding) {
        return;
    }

    CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude
                                                      longitude:coordinate.longitude];
    __weak typeof(self) weakSelf = self;
    [self.appleGeocoder reverseGeocodeLocation:location
                             completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || generation != self.geocodeGeneration || error ||
                placemarks.count == 0 || self.selectedAddress ||
                ![self pp_cameraStillTargetsCoordinate:coordinate]) {
                return;
            }
            NSString *resolvedTitle = [self pp_compactTitleFromPlacemark:placemarks.firstObject];
            if (resolvedTitle.length == 0) return;
            self.appleResolvedGeneration = generation;
            self.selectedLocationTitle = resolvedTitle;
            [self pp_updateMapCardWithResolvedTitle:resolvedTitle coordinate:coordinate];
        });
    }];
}

- (BOOL)pp_cameraStillTargetsCoordinate:(CLLocationCoordinate2D)coordinate
{
    return PPLocationPickerCoordinatesMatch(self.mapView.camera.target, coordinate);
}

- (void)pp_cancelPendingGeocodeDebounce
{
    if (!self.geocodeDebounceBlock) return;
    dispatch_block_cancel(self.geocodeDebounceBlock);
    self.geocodeDebounceBlock = nil;
}

- (void)pp_cancelPendingGeocodeTimeout
{
    if (!self.geocodeTimeoutBlock) return;
    dispatch_block_cancel(self.geocodeTimeoutBlock);
    self.geocodeTimeoutBlock = nil;
}

- (void)pp_cancelPendingGeocodeWorkInvalidatingGeneration:(BOOL)invalidateGeneration
{
    [self pp_cancelPendingGeocodeDebounce];
    [self pp_cancelPendingGeocodeTimeout];
    self.geocodeRequestInFlight = NO;
    if (invalidateGeneration) {
        self.geocodeGeneration += 1;
    }
}

#pragma mark - Accessibility Actions

- (void)pp_configureAccessibilityActions
{
    self.addressLabel.accessibilityCustomActions = @[
        [[UIAccessibilityCustomAction alloc] initWithName:kLang(@"location_picker_move_north")
                                                   target:self
                                                 selector:@selector(pp_accessibilityMoveNorth:)],
        [[UIAccessibilityCustomAction alloc] initWithName:kLang(@"location_picker_move_south")
                                                   target:self
                                                 selector:@selector(pp_accessibilityMoveSouth:)],
        [[UIAccessibilityCustomAction alloc] initWithName:kLang(@"location_picker_move_east")
                                                   target:self
                                                 selector:@selector(pp_accessibilityMoveEast:)],
        [[UIAccessibilityCustomAction alloc] initWithName:kLang(@"location_picker_move_west")
                                                   target:self
                                                 selector:@selector(pp_accessibilityMoveWest:)]
    ];
}

- (BOOL)pp_accessibilityMoveNorth:(UIAccessibilityCustomAction *)action
{
    (void)action;
    return [self pp_nudgeCameraLatitude:0.00025 longitude:0.0];
}

- (BOOL)pp_accessibilityMoveSouth:(UIAccessibilityCustomAction *)action
{
    (void)action;
    return [self pp_nudgeCameraLatitude:-0.00025 longitude:0.0];
}

- (BOOL)pp_accessibilityMoveEast:(UIAccessibilityCustomAction *)action
{
    (void)action;
    return [self pp_nudgeCameraLatitude:0.0 longitude:0.00025];
}

- (BOOL)pp_accessibilityMoveWest:(UIAccessibilityCustomAction *)action
{
    (void)action;
    return [self pp_nudgeCameraLatitude:0.0 longitude:-0.00025];
}

- (BOOL)pp_nudgeCameraLatitude:(CLLocationDegrees)latitudeDelta longitude:(CLLocationDegrees)longitudeDelta
{
    CLLocationCoordinate2D current = self.mapView.camera.target;
    CLLocationCoordinate2D next = CLLocationCoordinate2DMake(current.latitude + latitudeDelta, current.longitude + longitudeDelta);
    if (!PPLocationPickerCoordinateIsUsable(next)) return NO;

    self.shouldCenterOnNextLocationUpdate = NO;
    [self.locationManager stopUpdatingLocation];
    [self pp_moveCameraToCoordinate:next zoom:self.mapView.camera.zoom];
    return YES;
}

#pragma mark - Actions

- (void)centerToUserLocation
{
    [self.lightImpact impactOccurred];
    CLAuthorizationStatus status = [self pp_locationAuthorizationStatus];
    if (status == kCLAuthorizationStatusNotDetermined) {
        self.shouldCenterOnNextLocationUpdate = YES;
        [self.locationManager requestWhenInUseAuthorization];
        return;
    }
    if (![self pp_locationAuthorizationAllowsUpdates:status]) {
        [self pp_updatePermissionPresentationForStatus:status];
        return;
    }

    CLLocation *mapLocation = self.mapView.myLocation;
    BOOL fresh = mapLocation && mapLocation.horizontalAccuracy >= 0 && mapLocation.horizontalAccuracy <= 200 &&
        fabs(mapLocation.timestamp.timeIntervalSinceNow) <= 30.0;
    CLLocationCoordinate2D coordinate = fresh ? mapLocation.coordinate : kCLLocationCoordinate2DInvalid;
    if (PPLocationPickerCoordinateIsUsable(coordinate)) {
        [self pp_moveCameraToCoordinate:coordinate zoom:16.0];
        return;
    }

    [self pp_requestCurrentLocation];
}

- (void)pp_requestCurrentLocation
{
    self.shouldCenterOnNextLocationUpdate = YES;
    self.recenterButton.enabled = NO;
    self.recenterButton.alpha = 0.52;
    self.recenterButton.accessibilityValue = kLang(@"location_picker_finding_current_location");
    NSUInteger generation = ++self.locationRequestGeneration;
    [self.locationManager requestLocation];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || generation != self.locationRequestGeneration || !self.shouldCenterOnNextLocationUpdate) return;
        self.shouldCenterOnNextLocationUpdate = NO;
        [self.locationManager stopUpdatingLocation];
        [self pp_updatePermissionPresentationForStatus:[self pp_locationAuthorizationStatus]];
        if (self.view.window) [PPHUD showInfo:kLang(@"ordering_address_location_unavailable")];
    });
}

- (void)pp_moveCameraToCoordinate:(CLLocationCoordinate2D)coordinate zoom:(float)zoom
{
    if (!PPLocationPickerCoordinateIsUsable(coordinate)) return;

    GMSCameraPosition *camera =
        [GMSCameraPosition cameraWithLatitude:coordinate.latitude
                                     longitude:coordinate.longitude
                                          zoom:zoom];
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.mapView.camera = camera;
    } else {
        [self.mapView animateToCameraPosition:camera];
    }
}

- (void)pp_openLocationSettings
{
    NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if ([[UIApplication sharedApplication] canOpenURL:settingsURL]) {
        [[UIApplication sharedApplication] openURL:settingsURL options:@{} completionHandler:nil];
    }
}

- (void)pp_closePicker
{
    [self.lightImpact impactOccurred];
    if (self.navigationController) {
        BOOL isRootOfPresentedNavigation =
            self.navigationController.viewControllers.firstObject == self &&
            self.navigationController.presentingViewController != nil;
        if (isRootOfPresentedNavigation) {
            [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        } else {
            [self.navigationController popViewControllerAnimated:YES];
        }
    } else if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)confirmLocationTapped
{
    [self.mediumImpact impactOccurred];

    if (self.selectedAddress) {
        if (self.onLocationConfirmed) {
            self.onLocationConfirmed(self.selectedAddress);
        }
        if (self.onCoordinateConfirmed) {
            NSString *resolvedTitle = [LocationPickerViewController titleFromAddress:self.selectedAddress];
            if (resolvedTitle.length == 0) {
                resolvedTitle = self.selectedLocationTitle;
            }
            self.onCoordinateConfirmed(self.selectedAddress.coordinate, resolvedTitle ?: @"");
        }
        if (self.rowDescriptor) {
            NSString *rowTitle = [LocationPickerViewController titleFromAddress:self.selectedAddress];
            if (rowTitle.length == 0) {
                rowTitle = self.selectedLocationTitle;
            }
            self.rowDescriptor.value = rowTitle ?: @"";
            if ([self.delegate respondsToSelector:@selector(didSelectGMSAddress:forRowDescriptor:)]) {
                [self.delegate didSelectGMSAddress:self.selectedAddress forRowDescriptor:self.rowDescriptor];
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
            : [self pp_coordinateStringForCoordinate:fallbackCoordinate];
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

    [self shakeView:self.dockContainerView];
    [PPAlertHelper showWarningIn:self
                           title:kLang(@"location_picker_alert_title")
                        subtitle:kLang(@"location_picker_alert_message")
                      completion:nil];
}

+ (NSString *)titleFromAddress:(GMSAddress *)address
{
    if (!address) return @"";
    NSString *primary = address.subLocality ?: address.locality ?: address.thoroughfare ?: @"";
    NSString *secondary = address.locality ?: address.administrativeArea ?: address.country ?: @"";
    if ([primary isEqualToString:secondary]) {
        secondary = @"";
    }
    if (primary.length > 0 && secondary.length > 0) {
        return [NSString stringWithFormat:@"%@, %@", primary, secondary];
    }
    return primary.length > 0 ? primary : secondary;
}

- (void)shakeView:(UIView *)view
{
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    CABasicAnimation *shake = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.duration = 0.06;
    shake.repeatCount = 3;
    shake.autoreverses = YES;
    shake.fromValue = @(-PPSpaceXS);
    shake.toValue = @(PPSpaceXS);
    [view.layer addAnimation:shake forKey:@"pp.location.invalid-selection"];
}

#pragma mark - Navigation & TabBar Ownership

- (void)pp_captureNavigationAppearanceIfNeeded
{
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if (!navigationBar || self.capturedNavigationAppearance) return;
    self.capturedNavigationAppearance = YES;
    self.navigationBarWasHidden = self.navigationController.navigationBarHidden;
    self.navigationBarWasTranslucent = navigationBar.translucent;
    self.savedNavigationTintColor = navigationBar.tintColor;
    self.savedStandardAppearance = [navigationBar.standardAppearance copy];
    self.savedScrollEdgeAppearance = [navigationBar.scrollEdgeAppearance copy];
    self.savedCompactAppearance = [navigationBar.compactAppearance copy];
    if (@available(iOS 15.0, *)) {
        self.savedCompactScrollEdgeAppearance = [navigationBar.compactScrollEdgeAppearance copy];
    }
}

- (void)pp_restoreNavigationAppearanceAnimated:(BOOL)animated
{
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if (!navigationBar || !self.capturedNavigationAppearance) return;
    [self.navigationController setNavigationBarHidden:self.navigationBarWasHidden animated:animated];
    navigationBar.translucent = self.navigationBarWasTranslucent;
    navigationBar.tintColor = self.savedNavigationTintColor;
    if (self.savedStandardAppearance) {
        navigationBar.standardAppearance = self.savedStandardAppearance;
    }
    navigationBar.scrollEdgeAppearance = self.savedScrollEdgeAppearance;
    navigationBar.compactAppearance = self.savedCompactAppearance;
    if (@available(iOS 15.0, *)) {
        navigationBar.compactScrollEdgeAppearance = self.savedCompactScrollEdgeAppearance;
    }
}

- (void)pp_setBottomNavigationHidden:(BOOL)hidden animated:(BOOL)animated
{
    UITabBarController *tabBarController = self.tabBarController;
    if ([tabBarController respondsToSelector:@selector(pp_setBottomNavigationHidden:animated:)]) {
        [(id<PPBottomNavigationVisibilityControlling>)tabBarController pp_setBottomNavigationHidden:hidden animated:animated];
    }

    UITabBar *tabBar = tabBarController.tabBar;
    if (!tabBar) return;
    if (!hidden) tabBar.hidden = NO;

    void (^changes)(void) = ^{
        tabBar.alpha = hidden ? 0.0 : 1.0;
    };
    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        tabBar.hidden = hidden;
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        completion(YES);
    } else {
        [UIView animateWithDuration:PPAnimDurationNormal
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                         animations:changes
                         completion:completion];
    }
}

#pragma mark - Dark Mode & Appearance

- (void)applyDarkModeToMapView:(GMSMapView *)mapView
{
    NSString *stylePath = [[NSBundle mainBundle] pathForResource:@"map_dark_style" ofType:@"json"];
    if (stylePath.length == 0) {
        NSLog(@"[LocationPicker] map_dark_style.json is missing from the app bundle.");
        mapView.mapStyle = nil;
        return;
    }

    NSError *error = nil;
    NSURL *url = [NSURL fileURLWithPath:stylePath];
    GMSMapStyle *mapStyle = [GMSMapStyle styleWithContentsOfFileURL:url error:&error];
    if (!mapStyle) {
        NSLog(@"[LocationPicker] failed to load map style: %@", error.localizedDescription);
        mapView.mapStyle = nil;
        return;
    }
    mapView.mapStyle = mapStyle;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        [self applyDarkModeToMapView:self.mapView];
    } else {
        self.mapView.mapStyle = nil;
    }
    [self.view setNeedsLayout];
}

@end
