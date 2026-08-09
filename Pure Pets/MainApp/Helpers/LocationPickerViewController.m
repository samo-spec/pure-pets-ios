#import "LocationPickerViewController.h"
#import "CitiesManager.h"
#import "CountryModel.h"
#import <CoreLocation/CoreLocation.h>
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

@interface LocationPickerViewController ()

@property (nonatomic, strong) GMSMapView *mapView;
@property (nonatomic, strong) GMSGeocoder *geocoder;
@property (nonatomic, strong) CLGeocoder *appleGeocoder;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) GMSAddress *selectedAddress;
@property (nonatomic, assign) CLLocationCoordinate2D lastKnownCoordinate;
@property (nonatomic, assign) CLLocationCoordinate2D lastDeviceCoordinate;
@property (nonatomic, assign) BOOL hasExplicitInitialCoordinate;
@property (nonatomic, assign) BOOL shouldCenterOnNextLocationUpdate;
@property (nonatomic, copy) NSString *selectedLocationTitle;

@property (nonatomic, copy) dispatch_block_t geocodeTimeoutBlock;
@property (nonatomic, copy) dispatch_block_t geocodeDebounceBlock;
@property (nonatomic, assign) BOOL geocodeRequestInFlight;
@property (nonatomic, assign) NSUInteger geocodeGeneration;
@property (nonatomic, assign) NSUInteger appleResolvedGeneration;

@property (nonatomic, strong) UIView *instructionContainerView;
@property (nonatomic, strong) UIVisualEffectView *instructionChromeView;
@property (nonatomic, strong) UIStackView *instructionStackView;
@property (nonatomic, strong) UIButton *inlineCloseButton;
@property (nonatomic, strong) UIView *instructionGlyphView;
@property (nonatomic, strong) UIImageView *instructionGlyphImageView;
@property (nonatomic, strong) UILabel *instructionLabel;

@property (nonatomic, strong) UIView *dockContainerView;
@property (nonatomic, strong) UIVisualEffectView *dockChromeView;
@property (nonatomic, strong) UIScrollView *dockScrollView;
@property (nonatomic, strong) UIStackView *dockStackView;
@property (nonatomic, strong) UIView *statusPillView;
@property (nonatomic, strong) UIStackView *statusStackView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIImageView *statusIconImageView;
@property (nonatomic, strong) UILabel *addressLabel;
@property (nonatomic, strong) UILabel *coordinatesLabel;
@property (nonatomic, strong) UILabel *selectionHintLabel;
@property (nonatomic, strong) UIStackView *permissionStackView;
@property (nonatomic, strong) UIStackView *permissionMessageStackView;
@property (nonatomic, strong) UIImageView *permissionIconImageView;
@property (nonatomic, strong) UILabel *permissionLabel;
@property (nonatomic, strong) UIButton *permissionButton;
@property (nonatomic, strong) UIButton *recenterButton;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) NSLayoutConstraint *dockHeightConstraint;

@property (nonatomic, strong) UIView *pinTargetRingView;
@property (nonatomic, strong) UIView *pinContainerView;
@property (nonatomic, strong) UIView *pinHeadView;
@property (nonatomic, strong) UIView *pinStemView;
@property (nonatomic, strong) UIImageView *pinPawImageView;
@property (nonatomic, strong) UIViewPropertyAnimator *pinAnimator;
@property (nonatomic, strong) NSLayoutConstraint *pinCenterYConstraint;

@property (nonatomic, assign) PPLocationPickerDisplayState displayState;
@property (nonatomic, assign) BOOL managesHomeBottomNavigationVisibility;
@property (nonatomic, assign) BOOL capturedNavigationAppearance;
@property (nonatomic, assign) BOOL navigationBarWasTranslucent;
@property (nonatomic, strong) UIColor *savedNavigationTintColor;
@property (nonatomic, strong) UINavigationBarAppearance *savedStandardAppearance;
@property (nonatomic, strong) UINavigationBarAppearance *savedScrollEdgeAppearance;
@property (nonatomic, strong) UINavigationBarAppearance *savedCompactAppearance;
@property (nonatomic, strong) UINavigationBarAppearance *savedCompactScrollEdgeAppearance;

@end

@implementation LocationPickerViewController

@synthesize rowDescriptor;

#pragma mark - Lifecycle

- (instancetype)initWithRowDescriptor:(XLFormRowDescriptor *)rowDescriptor
{
    self = [super init];
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
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.extendedLayoutIncludesOpaqueBars = YES;
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.geocoder = [[GMSGeocoder alloc] init];
    self.appleGeocoder = [[CLGeocoder alloc] init];
    self.lastKnownCoordinate = kCLLocationCoordinate2DInvalid;
    self.lastDeviceCoordinate = kCLLocationCoordinate2DInvalid;

    self.hasExplicitInitialCoordinate =
        PPLocationPickerCoordinateIsUsable(self.initialCoordinate);
    self.shouldCenterOnNextLocationUpdate = !self.hasExplicitInitialCoordinate;
    CLLocationCoordinate2D startCoordinate = self.hasExplicitInitialCoordinate
        ? self.initialCoordinate
        : [self pp_dohaCoordinate];
    self.lastKnownCoordinate = startCoordinate;

    [self pp_setupMapCanvasWithCoordinate:startCoordinate];
    [self pp_setupPrecisionPin];
    [self pp_setupLocationChrome];
    [self pp_configureAccessibilityActions];
    [self pp_setupLocationManager];

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
    [self pp_setupNavigationChrome];
    self.inlineCloseButton.hidden = (self.navigationController != nil);

    self.managesHomeBottomNavigationVisibility = [self pp_isPushedFromHomeViewController];
    if (self.managesHomeBottomNavigationVisibility) {
        [self pp_setHomeBottomNavigationHidden:YES animated:animated];
    }

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

    if (self.managesHomeBottomNavigationVisibility) {
        [self pp_setHomeBottomNavigationHidden:NO animated:animated];
    }
    [self pp_restoreNavigationAppearance];

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
        [self pp_setupNavigationChrome];
        [self pp_setPinLifted:NO animated:NO];
        [self pp_scheduleReverseGeocodeForPosition:self.mapView.camera];
        if (self.managesHomeBottomNavigationVisibility) {
            [self pp_setHomeBottomNavigationHidden:YES animated:YES];
        }
    }];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self.locationManager stopUpdatingLocation];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    [self pp_updateDockHeightIfNeeded];
    [self pp_updateMapInsetsAndPinPosition];

    self.instructionContainerView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.instructionContainerView.bounds
                                   cornerRadius:PPCornerCard].CGPath;
    self.dockContainerView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.dockContainerView.bounds
                                   cornerRadius:PPCornerHero].CGPath;
    self.recenterButton.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.recenterButton.bounds
                                   cornerRadius:CGRectGetHeight(self.recenterButton.bounds) * 0.5].CGPath;
    self.confirmButton.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.confirmButton.bounds
                                   cornerRadius:PPCornerMedium].CGPath;
}

#pragma mark - UI Construction

- (UIVisualEffectView *)pp_makeChromePanelWithCornerRadius:(CGFloat)cornerRadius
{
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *panel = [[UIVisualEffectView alloc] initWithEffect:effect];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.clipsToBounds = YES;
    PPApplyContinuousCorners(panel, cornerRadius);
    panel.layer.borderWidth = PPLocationPickerHairlineWidth();
    panel.contentView.backgroundColor =
        [UIColor.systemBackgroundColor colorWithAlphaComponent:0.48];
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
        [UIColor.systemBackgroundColor colorWithAlphaComponent:0.88];
    PPApplyContinuousCorners(button, PPTouchTargetMin * 0.5);
    PPApplyButtonShadow(button);
    button.layer.shadowOpacity = 0.08;
    button.layer.shadowRadius = 10.0;
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
    button.contentEdgeInsets = UIEdgeInsetsMake(PPSpaceMD, PPSpaceBase, PPSpaceMD,
                                                PPSpaceBase);
    [button addTarget:self
               action:@selector(confirmLocationTapped)
     forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:PPButtonHeightLG].active = YES;
    button.accessibilityHint = kLang(@"location_picker_confirm_hint");
    return button;
}

- (void)pp_setupNavigationChrome
{
    if (!self.navigationController) {
        return;
    }

    self.navigationItem.title = @"";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    BOOL isPresentedRoot =
        self.navigationController.viewControllers.firstObject == self &&
        self.navigationController.presentingViewController != nil;
    NSString *backSymbolName = Language.isRTL ? @"chevron.right" : @"chevron.left";
    UIImageSymbolConfiguration *backSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:16.0
                                                        weight:UIImageSymbolWeightSemibold
                                                         scale:UIImageSymbolScaleMedium];
    UIImage *backImage = [UIImage systemImageNamed:backSymbolName
                                  withConfiguration:backSymbolConfiguration];
    UIBarButtonItem *backItem =
        [[UIBarButtonItem alloc] initWithImage:backImage
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(pp_closePicker)];
    backItem.accessibilityLabel = isPresentedRoot ? kLang(@"Close") : kLang(@"Back");
    self.navigationItem.leftBarButtonItem = backItem;
    self.navigationItem.rightBarButtonItem = nil;

    UINavigationBar *navBar = self.navigationController.navigationBar;
    navBar.tintColor = PPLocationPickerPrimaryTextColor();
    navBar.translucent = YES;
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    appearance.backgroundColor = UIColor.clearColor;
    appearance.shadowColor = UIColor.clearColor;
    appearance.titleTextAttributes = @{
        NSForegroundColorAttributeName: PPLocationPickerPrimaryTextColor()
    };
    navBar.standardAppearance = appearance;
    navBar.scrollEdgeAppearance = appearance;
    navBar.compactAppearance = appearance;
    if (@available(iOS 15.0, *)) {
        navBar.compactScrollEdgeAppearance = appearance;
    }
}

- (void)pp_setupMapCanvasWithCoordinate:(CLLocationCoordinate2D)startCoordinate
{
    GMSCameraPosition *camera =
        [GMSCameraPosition cameraWithLatitude:startCoordinate.latitude
                                    longitude:startCoordinate.longitude
                                         zoom:15.0];
    self.mapView = [GMSMapView mapWithFrame:CGRectZero camera:camera];
    self.mapView.delegate = self;
    self.mapView.myLocationEnabled = YES;
    self.mapView.settings.myLocationButton = NO;
    self.mapView.settings.compassButton = NO;
    self.mapView.settings.indoorPicker = NO;
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

- (void)pp_setupPrecisionPin
{
    UIColor *accentColor = PPLocationPickerAccentColor();

    self.pinTargetRingView = [[UIView alloc] init];
    self.pinTargetRingView.translatesAutoresizingMaskIntoConstraints = NO;
    self.pinTargetRingView.userInteractionEnabled = NO;
    self.pinTargetRingView.isAccessibilityElement = NO;
    self.pinTargetRingView.backgroundColor =
        [UIColor.systemBackgroundColor colorWithAlphaComponent:0.58];
    self.pinTargetRingView.layer.cornerRadius = PPSpaceSM;
    self.pinTargetRingView.layer.borderWidth = PPLocationPickerHairlineWidth();
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
    self.pinHeadView.layer.borderWidth = PPLocationPickerHairlineWidth();
    self.pinHeadView.layer.shadowColor = accentColor.CGColor;
    self.pinHeadView.layer.shadowOpacity = 0.28;
    self.pinHeadView.layer.shadowRadius = PPSpaceMD;
    self.pinHeadView.layer.shadowOffset = CGSizeMake(0.0, PPSpaceSM);
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

- (void)pp_setupLocationChrome
{
    [self pp_setupInstructionChrome];
    [self pp_setupPrecisionDock];

    self.recenterButton =
        [self pp_makeRoundChromeButtonWithSymbol:@"location.fill"
                                          action:@selector(centerToUserLocation)];
    self.recenterButton.accessibilityLabel = kLang(@"location_picker_recenter");
    [self.view addSubview:self.recenterButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.recenterButton.trailingAnchor constraintEqualToAnchor:self.dockContainerView.trailingAnchor],
        [self.recenterButton.bottomAnchor constraintEqualToAnchor:self.dockContainerView.topAnchor
                                                         constant:-PPSpaceMD]
    ]];
    [self pp_updateAdaptiveChromeColors];
}

- (void)pp_setupInstructionChrome
{
    self.instructionContainerView =
        [self pp_makeShadowContainerWithCornerRadius:PPCornerCard];
    [self.view addSubview:self.instructionContainerView];

    self.instructionChromeView =
        [self pp_makeChromePanelWithCornerRadius:PPCornerCard];
    [self.instructionContainerView addSubview:self.instructionChromeView];

    self.instructionStackView = [[UIStackView alloc] init];
    self.instructionStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.instructionStackView.axis = UILayoutConstraintAxisHorizontal;
    self.instructionStackView.alignment = UIStackViewAlignmentCenter;
    self.instructionStackView.spacing = PPSpaceMD;
    self.instructionStackView.semanticContentAttribute =
        [Language semanticAttributeForCurrentLanguage];
    [self.instructionChromeView.contentView addSubview:self.instructionStackView];

    self.instructionGlyphView = [[UIView alloc] init];
    self.instructionGlyphView.translatesAutoresizingMaskIntoConstraints = NO;
    self.instructionGlyphView.backgroundColor =
        [PPLocationPickerAccentColor() colorWithAlphaComponent:0.14];
    PPApplyContinuousCorners(self.instructionGlyphView, PPCornerSmall);
    [NSLayoutConstraint activateConstraints:@[
        [self.instructionGlyphView.widthAnchor constraintEqualToConstant:36.0],
        [self.instructionGlyphView.heightAnchor constraintEqualToConstant:36.0]
    ]];

    UIImageSymbolConfiguration *pawConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:17.0
                                                        weight:UIImageSymbolWeightSemibold
                                                         scale:UIImageSymbolScaleMedium];
    UIImage *pawImage = [UIImage systemImageNamed:@"pawprint"
                                 withConfiguration:pawConfiguration];
    self.instructionGlyphImageView = [[UIImageView alloc] initWithImage:pawImage];
    self.instructionGlyphImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.instructionGlyphImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.instructionGlyphImageView.tintColor = PPLocationPickerAccentColor();
    self.instructionGlyphImageView.isAccessibilityElement = NO;
    [self.instructionGlyphView addSubview:self.instructionGlyphImageView];

    self.instructionLabel = [[UILabel alloc] init];
    self.instructionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.instructionLabel.font =
        PPLocationPickerScaledFont([GM boldFontWithSize:PPFontSubheadline] ?:
                                   [UIFont systemFontOfSize:PPFontSubheadline weight:UIFontWeightSemibold],
                                   UIFontTextStyleSubheadline);
    self.instructionLabel.adjustsFontForContentSizeCategory = YES;
    self.instructionLabel.numberOfLines = 0;
    self.instructionLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.instructionLabel.textColor = PPLocationPickerPrimaryTextColor();
    self.instructionLabel.text = kLang(@"location_picker_instruction");

    self.inlineCloseButton =
        [self pp_makeRoundChromeButtonWithSymbol:@"xmark"
                                          action:@selector(pp_closePicker)];
    self.inlineCloseButton.accessibilityLabel = kLang(@"Close");

    [self.instructionStackView addArrangedSubview:self.instructionGlyphView];
    [self.instructionStackView addArrangedSubview:self.instructionLabel];
    [self.instructionStackView addArrangedSubview:self.inlineCloseButton];
    [self.instructionLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                           forAxis:UILayoutConstraintAxisHorizontal];

    [NSLayoutConstraint activateConstraints:@[
        [self.instructionContainerView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor
                                                                    constant:PPSpaceBase],
        [self.instructionContainerView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor
                                                                     constant:-PPSpaceBase],
        [self.instructionContainerView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor
                                                                constant:PPSpaceSM],

        [self.instructionChromeView.leadingAnchor constraintEqualToAnchor:self.instructionContainerView.leadingAnchor],
        [self.instructionChromeView.trailingAnchor constraintEqualToAnchor:self.instructionContainerView.trailingAnchor],
        [self.instructionChromeView.topAnchor constraintEqualToAnchor:self.instructionContainerView.topAnchor],
        [self.instructionChromeView.bottomAnchor constraintEqualToAnchor:self.instructionContainerView.bottomAnchor],

        [self.instructionStackView.leadingAnchor constraintEqualToAnchor:self.instructionChromeView.contentView.leadingAnchor
                                                                constant:PPSpaceMD],
        [self.instructionStackView.trailingAnchor constraintEqualToAnchor:self.instructionChromeView.contentView.trailingAnchor
                                                                 constant:-PPSpaceMD],
        [self.instructionStackView.topAnchor constraintEqualToAnchor:self.instructionChromeView.contentView.topAnchor
                                                            constant:PPSpaceSM],
        [self.instructionStackView.bottomAnchor constraintEqualToAnchor:self.instructionChromeView.contentView.bottomAnchor
                                                               constant:-PPSpaceSM],

        [self.instructionGlyphImageView.centerXAnchor constraintEqualToAnchor:self.instructionGlyphView.centerXAnchor],
        [self.instructionGlyphImageView.centerYAnchor constraintEqualToAnchor:self.instructionGlyphView.centerYAnchor],
        [self.instructionGlyphImageView.widthAnchor constraintEqualToConstant:PPSpaceLG],
        [self.instructionGlyphImageView.heightAnchor constraintEqualToConstant:PPSpaceLG]
    ]];
}

- (void)pp_setupPrecisionDock
{
    self.dockContainerView =
        [self pp_makeShadowContainerWithCornerRadius:PPCornerHero];
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
    self.dockStackView.semanticContentAttribute =
        [Language semanticAttributeForCurrentLanguage];
    [self.dockScrollView addSubview:self.dockStackView];

    [self pp_buildStatusRow];
    [self pp_buildSelectionLabels];
    [self pp_buildPermissionState];

    self.confirmButton = [self pp_makePrimaryConfirmButton];
    [self.dockStackView addArrangedSubview:self.confirmButton];

    self.dockHeightConstraint =
        [self.dockContainerView.heightAnchor constraintEqualToConstant:248.0];
    [NSLayoutConstraint activateConstraints:@[
        [self.dockContainerView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor
                                                             constant:PPSpaceBase],
        [self.dockContainerView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor
                                                              constant:-PPSpaceBase],
        [self.dockContainerView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor
                                                            constant:-PPSpaceMD],
        self.dockHeightConstraint,

        [self.dockChromeView.leadingAnchor constraintEqualToAnchor:self.dockContainerView.leadingAnchor],
        [self.dockChromeView.trailingAnchor constraintEqualToAnchor:self.dockContainerView.trailingAnchor],
        [self.dockChromeView.topAnchor constraintEqualToAnchor:self.dockContainerView.topAnchor],
        [self.dockChromeView.bottomAnchor constraintEqualToAnchor:self.dockContainerView.bottomAnchor],

        [self.dockScrollView.leadingAnchor constraintEqualToAnchor:self.dockChromeView.contentView.leadingAnchor],
        [self.dockScrollView.trailingAnchor constraintEqualToAnchor:self.dockChromeView.contentView.trailingAnchor],
        [self.dockScrollView.topAnchor constraintEqualToAnchor:self.dockChromeView.contentView.topAnchor],
        [self.dockScrollView.bottomAnchor constraintEqualToAnchor:self.dockChromeView.contentView.bottomAnchor],

        [self.dockStackView.leadingAnchor constraintEqualToAnchor:self.dockScrollView.contentLayoutGuide.leadingAnchor
                                                         constant:PPSpaceBase],
        [self.dockStackView.trailingAnchor constraintEqualToAnchor:self.dockScrollView.contentLayoutGuide.trailingAnchor
                                                          constant:-PPSpaceBase],
        [self.dockStackView.topAnchor constraintEqualToAnchor:self.dockScrollView.contentLayoutGuide.topAnchor
                                                     constant:PPSpaceBase],
        [self.dockStackView.bottomAnchor constraintEqualToAnchor:self.dockScrollView.contentLayoutGuide.bottomAnchor
                                                        constant:-PPSpaceBase],
        [self.dockStackView.widthAnchor constraintEqualToAnchor:self.dockScrollView.frameLayoutGuide.widthAnchor
                                                       constant:-(PPSpaceBase * 2.0)]
    ]];
}

- (void)pp_buildStatusRow
{
    self.statusPillView = [[UIView alloc] init];
    self.statusPillView.translatesAutoresizingMaskIntoConstraints = NO;
    PPApplyContinuousCorners(self.statusPillView, PPCornerSmall);
    self.statusPillView.layer.borderWidth = PPLocationPickerHairlineWidth();
    self.statusPillView.isAccessibilityElement = YES;
    [self.dockStackView addArrangedSubview:self.statusPillView];

    self.statusStackView = [[UIStackView alloc] init];
    self.statusStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusStackView.axis = UILayoutConstraintAxisHorizontal;
    self.statusStackView.alignment = UIStackViewAlignmentCenter;
    self.statusStackView.spacing = PPSpaceSM;
    self.statusStackView.semanticContentAttribute =
        [Language semanticAttributeForCurrentLanguage];
    [self.statusPillView addSubview:self.statusStackView];

    self.spinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = PPLocationPickerAccentColor();
    self.spinner.hidesWhenStopped = YES;
    self.spinner.isAccessibilityElement = NO;

    self.statusIconImageView = [[UIImageView alloc] init];
    self.statusIconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusIconImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.statusIconImageView.isAccessibilityElement = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.statusIconImageView.widthAnchor constraintEqualToConstant:PPSpaceBase],
        [self.statusIconImageView.heightAnchor constraintEqualToConstant:PPSpaceBase]
    ]];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font =
        PPLocationPickerScaledFont([GM boldFontWithSize:PPFontCaption1] ?:
                                   [UIFont systemFontOfSize:PPFontCaption1 weight:UIFontWeightSemibold],
                                   UIFontTextStyleCaption1);
    self.statusLabel.adjustsFontForContentSizeCategory = YES;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.statusLabel.isAccessibilityElement = NO;

    [self.statusStackView addArrangedSubview:self.spinner];
    [self.statusStackView addArrangedSubview:self.statusIconImageView];
    [self.statusStackView addArrangedSubview:self.statusLabel];
    [self.statusLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                      forAxis:UILayoutConstraintAxisHorizontal];

    [NSLayoutConstraint activateConstraints:@[
        [self.statusStackView.leadingAnchor constraintEqualToAnchor:self.statusPillView.leadingAnchor
                                                           constant:PPSpaceMD],
        [self.statusStackView.trailingAnchor constraintEqualToAnchor:self.statusPillView.trailingAnchor
                                                            constant:-PPSpaceMD],
        [self.statusStackView.topAnchor constraintEqualToAnchor:self.statusPillView.topAnchor
                                                       constant:PPSpaceSM],
        [self.statusStackView.bottomAnchor constraintEqualToAnchor:self.statusPillView.bottomAnchor
                                                          constant:-PPSpaceSM],
        [self.statusPillView.heightAnchor constraintGreaterThanOrEqualToConstant:36.0]
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
    UIFont *coordinateFont =
        [UIFont monospacedDigitSystemFontOfSize:PPFontFootnote weight:UIFontWeightMedium];
    self.coordinatesLabel.font =
        PPLocationPickerScaledFont(coordinateFont, UIFontTextStyleFootnote);
    self.coordinatesLabel.adjustsFontForContentSizeCategory = YES;
    self.coordinatesLabel.numberOfLines = 0;
    self.coordinatesLabel.textAlignment = Language.isRTL
        ? NSTextAlignmentRight
        : NSTextAlignmentLeft;
    self.coordinatesLabel.semanticContentAttribute =
        UISemanticContentAttributeForceLeftToRight;
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
    self.permissionMessageStackView.semanticContentAttribute =
        [Language semanticAttributeForCurrentLanguage];
    [self.permissionStackView addArrangedSubview:self.permissionMessageStackView];

    UIImage *permissionImage =
        [UIImage systemImageNamed:@"location.slash.fill"];
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
    self.permissionButton.backgroundColor =
        [PPLocationPickerAccentColor() colorWithAlphaComponent:0.12];
    self.permissionButton.tintColor = PPLocationPickerAccentColor();
    PPApplyContinuousCorners(self.permissionButton, PPCornerSmall);
    self.permissionButton.titleLabel.font =
        PPLocationPickerScaledFont([GM boldFontWithSize:PPFontSubheadline] ?:
                                   [UIFont systemFontOfSize:PPFontSubheadline weight:UIFontWeightSemibold],
                                   UIFontTextStyleSubheadline);
    self.permissionButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.permissionButton.titleLabel.numberOfLines = 0;
    [self.permissionButton setTitle:kLang(@"Open Settings") forState:UIControlStateNormal];
    self.permissionButton.contentEdgeInsets =
        UIEdgeInsetsMake(PPSpaceSM, PPSpaceMD, PPSpaceSM, PPSpaceMD);
    [self.permissionButton addTarget:self
                              action:@selector(pp_openLocationSettings)
                    forControlEvents:UIControlEventTouchUpInside];
    [self.permissionButton.heightAnchor
        constraintGreaterThanOrEqualToConstant:PPTouchTargetMin].active = YES;
    [self.permissionStackView addArrangedSubview:self.permissionButton];
}

#pragma mark - Layout

- (void)pp_updateDockHeightIfNeeded
{
    CGFloat contentWidth = CGRectGetWidth(self.dockScrollView.bounds) -
        (PPSpaceBase * 2.0);
    if (contentWidth <= 0.0) {
        return;
    }

    CGSize fittingSize = CGSizeMake(contentWidth, UILayoutFittingCompressedSize.height);
    CGSize contentSize =
        [self.dockStackView systemLayoutSizeFittingSize:fittingSize
                         withHorizontalFittingPriority:UILayoutPriorityRequired
                               verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    CGFloat desiredHeight = MAX(196.0, contentSize.height + (PPSpaceBase * 2.0));
    CGFloat safeHeight = CGRectGetHeight(self.view.safeAreaLayoutGuide.layoutFrame);
    CGFloat heightRatio =
        self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact
            ? 0.58
            : 0.52;
    CGFloat maximumHeight = MAX(176.0, floor(safeHeight * heightRatio));
    CGFloat resolvedHeight = MIN(desiredHeight, maximumHeight);
    if (fabs(self.dockHeightConstraint.constant - resolvedHeight) > 0.5) {
        self.dockHeightConstraint.constant = resolvedHeight;
    }
    self.dockScrollView.scrollEnabled = desiredHeight > maximumHeight + 0.5;
}

- (void)pp_updateMapInsetsAndPinPosition
{
    if (CGRectIsEmpty(self.instructionContainerView.frame) ||
        CGRectIsEmpty(self.dockContainerView.frame)) {
        return;
    }

    CGFloat topInset = CGRectGetMaxY(self.instructionContainerView.frame) + PPSpaceMD;
    CGFloat bottomInset = CGRectGetHeight(self.view.bounds) -
        CGRectGetMinY(self.dockContainerView.frame) + PPSpaceMD;
    UIEdgeInsets padding = UIEdgeInsetsMake(topInset, 0.0, bottomInset, 0.0);
    if (!UIEdgeInsetsEqualToEdgeInsets(self.mapView.padding, padding)) {
        self.mapView.padding = padding;
    }

    CGFloat targetCenterOffset = (topInset - bottomInset) * 0.5;
    if (fabs(self.pinCenterYConstraint.constant - targetCenterOffset) > 0.5) {
        self.pinCenterYConstraint.constant = targetCenterOffset;
    }
}

#pragma mark - Presentation State

- (NSString *)pp_coordinateStringForCoordinate:(CLLocationCoordinate2D)coordinate
{
    if (!PPLocationPickerCoordinateIsUsable(coordinate)) {
        return kLang(@"location_picker_coordinates_unavailable");
    }
    return [NSString stringWithFormat:@"%.6f, %.6f",
            coordinate.latitude, coordinate.longitude];
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
    self.statusPillView.backgroundColor =
        [resolvedTint colorWithAlphaComponent:loading ? 0.14 : 0.10];
    self.statusPillView.layer.borderColor =
        [resolvedTint colorWithAlphaComponent:0.20].CGColor;
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
    NSString *resolvedTitle = title.length > 0
        ? title
        : kLang(@"location_picker_choose_point");
    NSString *coordinateText = [self pp_coordinateStringForCoordinate:coordinate];
    self.addressLabel.text = resolvedTitle;
    self.coordinatesLabel.text = coordinateText;
    self.coordinatesLabel.accessibilityLabel =
        [NSString stringWithFormat:@"%@: %@",
         kLang(@"location_picker_coordinates_label"), coordinateText];
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
    if (!address) {
        return;
    }

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
    [self pp_announceResolvedLocationIfNeeded:fullAddress
                                    statusKey:@"location_picker_status_address_ready"];
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
    [self pp_announceResolvedLocationIfNeeded:self.selectedLocationTitle
                                    statusKey:@"location_picker_status_area_ready"];
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
    if (!UIAccessibilityIsVoiceOverRunning() || locationTitle.length == 0 ||
        !self.view.window) {
        return;
    }
    NSString *announcement =
        [NSString stringWithFormat:@"%@: %@",
         kLang(statusKey), locationTitle];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,
                                    announcement);
}

#pragma mark - Location Defaults

- (CLLocationCoordinate2D)pp_dohaCoordinate
{
    CountryModel *qatar = [CitiesManager.shared qatarCountry];
    CityModel *doha = [CitiesManager.shared defaultCityForCountry:qatar];
    CLLocationCoordinate2D coordinate =
        CLLocationCoordinate2DMake(doha.latitude, doha.longitude);
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
    if (cityName.length > 0) {
        return cityName;
    }
    if (countryName.length > 0) {
        return countryName;
    }
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
                                         zoom:15.0];
    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [self.mapView animateToCameraPosition:camera];
    } else {
        self.mapView.camera = camera;
    }
    [self pp_updateMapCardWithResolvedTitle:self.selectedLocationTitle
                                 coordinate:coordinate];
}

- (NSString *)pp_compactAddressTitleFromGMSAddress:(GMSAddress *)address
{
    if (!address) {
        return @"";
    }
    NSString *title = [LocationPickerViewController titleFromAddress:address];
    if (title.length > 0) {
        return title;
    }
    NSString *fullAddress = [address.lines componentsJoinedByString:@", "];
    return fullAddress ?: @"";
}

- (NSString *)pp_compactTitleFromPlacemark:(CLPlacemark *)placemark
{
    if (!placemark) {
        return @"";
    }
    NSString *primary =
        placemark.subLocality ?: placemark.locality ?: placemark.thoroughfare ?: @"";
    NSString *secondary =
        placemark.locality ?: placemark.administrativeArea ?: placemark.country ?: @"";
    if ([primary isEqualToString:secondary]) {
        secondary = @"";
    }
    if (primary.length > 0 && secondary.length > 0) {
        return [NSString stringWithFormat:@"%@, %@", primary, secondary];
    }
    return primary.length > 0 ? primary : secondary;
}

#pragma mark - Location Authorization

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
        [self.locationManager requestWhenInUseAuthorization];
        return;
    }
    if ([self pp_locationAuthorizationAllowsUpdates:status]) {
        if (self.shouldCenterOnNextLocationUpdate ||
            !PPLocationPickerCoordinateIsUsable(self.lastDeviceCoordinate)) {
            [self.locationManager startUpdatingLocation];
        }
    } else {
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
    self.recenterButton.enabled = authorized;
    self.recenterButton.alpha = authorized ? 1.0 : 0.52;
    self.recenterButton.accessibilityValue = authorized
        ? nil
        : kLang(@"location_picker_recenter_unavailable");
    [self.view setNeedsLayout];
}

- (void)locationManager:(CLLocationManager *)manager
      didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    CLLocation *location = locations.lastObject;
    if (!location || !PPLocationPickerCoordinateIsUsable(location.coordinate)) {
        return;
    }

    self.lastDeviceCoordinate = location.coordinate;
    [manager stopUpdatingLocation];
    self.recenterButton.enabled = YES;
    self.recenterButton.alpha = 1.0;
    self.recenterButton.accessibilityValue = nil;

    if (!self.shouldCenterOnNextLocationUpdate) {
        return;
    }
    self.shouldCenterOnNextLocationUpdate = NO;
    [self pp_moveCameraToCoordinate:location.coordinate zoom:15.0];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [manager stopUpdatingLocation];
    NSLog(@"[LocationPicker] location update failed: %@", error.localizedDescription);
    BOOL canRetry = [self pp_locationAuthorizationAllowsUpdates:
                     [self pp_locationAuthorizationStatus]];
    self.recenterButton.enabled = canRetry;
    self.recenterButton.alpha = canRetry ? 1.0 : 0.52;
    self.recenterButton.accessibilityValue = nil;
    if (error.code == kCLErrorDenied) {
        [self pp_updatePermissionPresentationForStatus:[self pp_locationAuthorizationStatus]];
    }
}

- (void)locationManager:(CLLocationManager *)manager
didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    [self pp_handleLocationAuthorizationStatus:status];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager
    API_AVAILABLE(ios(14.0))
{
    [self pp_handleLocationAuthorizationStatus:manager.authorizationStatus];
}

#pragma mark - Map Events

- (void)mapView:(GMSMapView *)mapView willMove:(BOOL)gesture
{
    if (gesture) {
        self.shouldCenterOnNextLocationUpdate = NO;
        [self.locationManager stopUpdatingLocation];
        BOOL canRecenter = [self pp_locationAuthorizationAllowsUpdates:
                            [self pp_locationAuthorizationStatus]];
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

- (void)mapView:(GMSMapView *)mapView
idleAtCameraPosition:(GMSCameraPosition *)position
{
    (void)mapView;
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
        if (!self) {
            return;
        }
        self.pinTargetRingView.alpha = lifted ? 0.38 : 1.0;
        self.pinTargetRingView.transform =
            (!reduceMotion && lifted)
                ? CGAffineTransformMakeScale(0.76, 0.76)
                : CGAffineTransformIdentity;
        self.pinContainerView.transform =
            (!reduceMotion && lifted)
                ? CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, -12.0),
                                          CGAffineTransformMakeScale(1.03, 1.03))
                : CGAffineTransformIdentity;
    };

    if (!animated || reduceMotion || !self.view.window) {
        changes();
        return;
    }

    UISpringTimingParameters *timing =
        [[UISpringTimingParameters alloc] initWithDampingRatio:(lifted ? 0.92 : 0.72)
                                         initialVelocity:CGVectorMake(0.0, lifted ? -0.2 : 0.45)];
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
        if (!self || generation != self.geocodeGeneration) {
            return;
        }
        self.geocodeDebounceBlock = nil;
        [self startReverseGeocodeForCoordinate:target generation:generation];
    });
    self.geocodeDebounceBlock = debounceBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(PPAnimDurationNormal * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), debounceBlock);
}

- (void)startReverseGeocodeForCoordinate:(CLLocationCoordinate2D)target
                              generation:(NSUInteger)generation
{
    if (!PPLocationPickerCoordinateIsUsable(target) ||
        generation != self.geocodeGeneration) {
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), timeoutBlock);

    [self.geocoder reverseGeocodeCoordinate:target
                          completionHandler:^(GMSReverseGeocodeResponse *response,
                                              NSError *error) {
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

            if (self.appleResolvedGeneration == generation) {
                return;
            }

            NSLog(@"[LocationPicker] reverse geocode fallback: %@",
                  error.localizedDescription ?: @"No result");
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

    CLLocation *location =
        [[CLLocation alloc] initWithLatitude:coordinate.latitude
                                  longitude:coordinate.longitude];
    __weak typeof(self) weakSelf = self;
    [self.appleGeocoder reverseGeocodeLocation:location
                             completionHandler:^(NSArray<CLPlacemark *> *placemarks,
                                                 NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || generation != self.geocodeGeneration || error ||
                placemarks.count == 0 || self.selectedAddress ||
                ![self pp_cameraStillTargetsCoordinate:coordinate]) {
                return;
            }
            NSString *resolvedTitle =
                [self pp_compactTitleFromPlacemark:placemarks.firstObject];
            if (resolvedTitle.length == 0) {
                return;
            }
            self.appleResolvedGeneration = generation;
            self.selectedLocationTitle = resolvedTitle;
            [self pp_updateMapCardWithResolvedTitle:resolvedTitle
                                         coordinate:coordinate];
        });
    }];
}

- (BOOL)pp_cameraStillTargetsCoordinate:(CLLocationCoordinate2D)coordinate
{
    return PPLocationPickerCoordinatesMatch(self.mapView.camera.target, coordinate);
}

- (void)pp_cancelPendingGeocodeDebounce
{
    if (!self.geocodeDebounceBlock) {
        return;
    }
    dispatch_block_cancel(self.geocodeDebounceBlock);
    self.geocodeDebounceBlock = nil;
}

- (void)pp_cancelPendingGeocodeTimeout
{
    if (!self.geocodeTimeoutBlock) {
        return;
    }
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

#pragma mark - Accessibility Precision Actions

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

- (BOOL)pp_nudgeCameraLatitude:(CLLocationDegrees)latitudeDelta
                     longitude:(CLLocationDegrees)longitudeDelta
{
    CLLocationCoordinate2D current = self.mapView.camera.target;
    CLLocationCoordinate2D next =
        CLLocationCoordinate2DMake(current.latitude + latitudeDelta,
                                   current.longitude + longitudeDelta);
    if (!PPLocationPickerCoordinateIsUsable(next)) {
        return NO;
    }
    self.shouldCenterOnNextLocationUpdate = NO;
    [self.locationManager stopUpdatingLocation];
    [self pp_moveCameraToCoordinate:next zoom:self.mapView.camera.zoom];
    return YES;
}

#pragma mark - Actions

- (void)centerToUserLocation
{
    CLAuthorizationStatus status = [self pp_locationAuthorizationStatus];
    if (![self pp_locationAuthorizationAllowsUpdates:status]) {
        [self pp_updatePermissionPresentationForStatus:status];
        return;
    }

    CLLocation *mapLocation = self.mapView.myLocation;
    CLLocationCoordinate2D coordinate = mapLocation
        ? mapLocation.coordinate
        : kCLLocationCoordinate2DInvalid;
    if (!PPLocationPickerCoordinateIsUsable(coordinate)) {
        coordinate = self.lastDeviceCoordinate;
    }
    if (PPLocationPickerCoordinateIsUsable(coordinate)) {
        [self pp_moveCameraToCoordinate:coordinate zoom:15.0];
        return;
    }

    self.shouldCenterOnNextLocationUpdate = YES;
    self.recenterButton.enabled = NO;
    self.recenterButton.alpha = 0.52;
    self.recenterButton.accessibilityValue =
        kLang(@"location_picker_finding_current_location");
    [self.locationManager startUpdatingLocation];
}

- (void)pp_moveCameraToCoordinate:(CLLocationCoordinate2D)coordinate zoom:(float)zoom
{
    if (!PPLocationPickerCoordinateIsUsable(coordinate)) {
        return;
    }
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
        [[UIApplication sharedApplication] openURL:settingsURL
                                           options:@{}
                                 completionHandler:nil];
    }
}

- (void)pp_closePicker
{
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
    if (self.selectedAddress) {
        if (self.onLocationConfirmed) {
            self.onLocationConfirmed(self.selectedAddress);
        }
        if (self.onCoordinateConfirmed) {
            NSString *resolvedTitle =
                [LocationPickerViewController titleFromAddress:self.selectedAddress];
            if (resolvedTitle.length == 0) {
                resolvedTitle = self.selectedLocationTitle;
            }
            self.onCoordinateConfirmed(self.selectedAddress.coordinate,
                                       resolvedTitle ?: @"");
        }
        if (self.rowDescriptor) {
            NSString *rowTitle =
                [LocationPickerViewController titleFromAddress:self.selectedAddress];
            if (rowTitle.length == 0) {
                rowTitle = self.selectedLocationTitle;
            }
            self.rowDescriptor.value = rowTitle ?: @"";
            if ([self.delegate respondsToSelector:
                 @selector(didSelectGMSAddress:forRowDescriptor:)]) {
                [self.delegate didSelectGMSAddress:self.selectedAddress
                                  forRowDescriptor:self.rowDescriptor];
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
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:kLang(@"location_picker_alert_title")
                                            message:kLang(@"location_picker_alert_message")
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

+ (NSString *)titleFromAddress:(GMSAddress *)address
{
    if (!address) {
        return @"";
    }

    NSString *primary =
        address.subLocality ?: address.locality ?: address.thoroughfare ?: @"";
    NSString *secondary =
        address.locality ?: address.administrativeArea ?: address.country ?: @"";
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
    if (UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }
    CABasicAnimation *shake = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.duration = 0.06;
    shake.repeatCount = 3;
    shake.autoreverses = YES;
    shake.fromValue = @(-PPSpaceXS);
    shake.toValue = @(PPSpaceXS);
    [view.layer addAnimation:shake forKey:@"pp.location.invalid-selection"];
}

#pragma mark - Navigation Ownership

- (void)pp_captureNavigationAppearanceIfNeeded
{
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if (!navigationBar || self.capturedNavigationAppearance) {
        return;
    }
    self.capturedNavigationAppearance = YES;
    self.navigationBarWasTranslucent = navigationBar.translucent;
    self.savedNavigationTintColor = navigationBar.tintColor;
    self.savedStandardAppearance = [navigationBar.standardAppearance copy];
    self.savedScrollEdgeAppearance = [navigationBar.scrollEdgeAppearance copy];
    self.savedCompactAppearance = [navigationBar.compactAppearance copy];
    if (@available(iOS 15.0, *)) {
        self.savedCompactScrollEdgeAppearance =
            [navigationBar.compactScrollEdgeAppearance copy];
    }
}

- (void)pp_restoreNavigationAppearance
{
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if (!navigationBar || !self.capturedNavigationAppearance) {
        return;
    }
    navigationBar.translucent = self.navigationBarWasTranslucent;
    navigationBar.tintColor = self.savedNavigationTintColor;
    if (self.savedStandardAppearance) {
        navigationBar.standardAppearance = self.savedStandardAppearance;
    }
    navigationBar.scrollEdgeAppearance = self.savedScrollEdgeAppearance;
    navigationBar.compactAppearance = self.savedCompactAppearance;
    if (@available(iOS 15.0, *)) {
        navigationBar.compactScrollEdgeAppearance =
            self.savedCompactScrollEdgeAppearance;
    }
}

- (BOOL)pp_isPushedFromHomeViewController
{
    NSArray<UIViewController *> *viewControllers =
        self.navigationController.viewControllers ?: @[];
    NSUInteger currentIndex = [viewControllers indexOfObject:self];
    if (currentIndex == NSNotFound || currentIndex == 0) {
        return NO;
    }
    Class homeClass = NSClassFromString(@"PPHomeViewController");
    UIViewController *previousViewController = viewControllers[currentIndex - 1];
    return homeClass != Nil &&
        [previousViewController isKindOfClass:homeClass];
}

- (void)pp_setHomeBottomNavigationHidden:(BOOL)hidden animated:(BOOL)animated
{
    UITabBarController *tabBarController = self.tabBarController;
    if ([tabBarController respondsToSelector:
         @selector(pp_setBottomNavigationHidden:animated:)]) {
        [(id<PPBottomNavigationVisibilityControlling>)tabBarController
            pp_setBottomNavigationHidden:hidden animated:animated];
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
    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        completion(YES);
        return;
    }
    [UIView animateWithDuration:PPAnimDurationNormal
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionCurveEaseInOut
                     animations:changes
                     completion:completion];
}

#pragma mark - Appearance

- (void)pp_updateAdaptiveChromeColors
{
    UIColor *hairlineColor =
        [UIColor.separatorColor colorWithAlphaComponent:0.20];
    self.instructionChromeView.layer.borderColor = hairlineColor.CGColor;
    self.dockChromeView.layer.borderColor = hairlineColor.CGColor;
    self.inlineCloseButton.layer.borderColor = hairlineColor.CGColor;
    self.recenterButton.layer.borderColor = hairlineColor.CGColor;
    self.pinTargetRingView.layer.borderColor =
        [PPLocationPickerAccentColor() colorWithAlphaComponent:0.24].CGColor;
    self.pinHeadView.layer.borderColor =
        [UIColor.whiteColor colorWithAlphaComponent:0.28].CGColor;
}

- (void)applyDarkModeToMapView:(GMSMapView *)mapView
{
    NSString *stylePath =
        [[NSBundle mainBundle] pathForResource:@"map_dark_style" ofType:@"json"];
    if (stylePath.length == 0) {
        NSLog(@"[LocationPicker] map_dark_style.json is missing from the app bundle.");
        mapView.mapStyle = nil;
        return;
    }

    NSError *error = nil;
    NSURL *url = [NSURL fileURLWithPath:stylePath];
    GMSMapStyle *mapStyle =
        [GMSMapStyle styleWithContentsOfFileURL:url error:&error];
    if (!mapStyle) {
        NSLog(@"[LocationPicker] failed to load map style: %@",
              error.localizedDescription);
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
    [self pp_updateAdaptiveChromeColors];
    [self.view setNeedsLayout];
}

@end
