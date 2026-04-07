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

@interface LocationPickerViewController ()
@property(nonatomic,strong) GMSMapView *mapView;
@property(nonatomic,strong) UIImageView *centerPinImageView;
@property(nonatomic,strong) UIView *pinHaloView;
@property(nonatomic,strong) UILabel *addressLabel;
@property(nonatomic,strong) UILabel *coordinatesLabel;
@property(nonatomic,strong) UILabel *selectionHintLabel;
@property(nonatomic,strong) UIActivityIndicatorView *spinner;
@property(nonatomic,strong) GMSGeocoder *geocoder;
@property(nonatomic,strong) CLGeocoder *appleGeocoder;
@property(nonatomic,strong) NSDate *lastGeocodeTime;
@property(nonatomic,strong) GMSAddress *selectedAddress;
@property(nonatomic,strong) CLLocationManager *locationManager;
@property(nonatomic,strong) UIButton *recenterButton;
@property(nonatomic,strong) UIButton *confirmButton;
@property(nonatomic,assign) CLLocationCoordinate2D lastKnownCoordinate;
@property(nonatomic,copy) dispatch_block_t geocodeTimeoutBlock;
@property(nonatomic,assign) BOOL geocodeRequestInFlight;
@property(nonatomic,copy) NSString *selectedLocationTitle;
@property(nonatomic,strong) UIView *topScrimView;
@property(nonatomic,strong) UIView *bottomScrimView;
@property(nonatomic,strong) CAGradientLayer *topScrimLayer;
@property(nonatomic,strong) CAGradientLayer *bottomScrimLayer;
@property(nonatomic,strong) UIVisualEffectView *heroChromeView;
@property(nonatomic,strong) UIView *heroTintView;
@property(nonatomic,strong) UILabel *eyebrowLabel;
@property(nonatomic,strong) UILabel *heroTitleLabel;
@property(nonatomic,strong) UILabel *heroSubtitleLabel;
@property(nonatomic,strong) UIVisualEffectView *selectionChromeView;
@property(nonatomic,strong) UIView *selectionTintView;
@property(nonatomic,strong) UILabel *selectionSectionLabel;
@property(nonatomic,strong) UIView *statusPillView;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UIVisualEffectView *bottomActionChromeView;
@property(nonatomic,strong) UIView *bottomActionTintView;
@property(nonatomic,strong) UILabel *bottomTitleLabel;
@property(nonatomic,strong) UILabel *bottomSubtitleLabel;

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

- (void)dealloc
{
    [self pp_cancelPendingGeocodeTimeout];
    [self.appleGeocoder cancelGeocode];
}

- (NSString *)pp_localizedStringForKey:(NSString *)key
                       fallbackEnglish:(NSString *)english
                                arabic:(NSString *)arabic
{
    NSString *value = key.length ? kLang(key) : nil;
    if (![value isKindOfClass:NSString.class] || value.length == 0 || [value isEqualToString:key]) {
        return Language.isRTL ? (arabic ?: english ?: @"") : (english ?: arabic ?: @"");
    }
    return value;
}

- (UIVisualEffectView *)pp_makeChromePanelWithCornerRadius:(CGFloat)cornerRadius
{
    UIBlurEffectStyle blurStyle = UIBlurEffectStyleSystemUltraThinMaterialLight;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemUltraThinMaterialLight;
    }
    UIVisualEffectView *panel = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.layer.cornerRadius = cornerRadius;
    panel.layer.cornerCurve = kCACornerCurveContinuous;
    panel.layer.borderWidth = 1.0;
    panel.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.34].CGColor;
    panel.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    panel.layer.shadowOpacity = 0.12;
    panel.layer.shadowRadius = 22.0;
    panel.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    panel.clipsToBounds = NO;
    panel.contentView.clipsToBounds = YES;
    panel.contentView.layer.cornerRadius = cornerRadius;
    panel.contentView.layer.cornerCurve = kCACornerCurveContinuous;
    return panel;
}

- (UIButton *)pp_makeRoundChromeButtonWithSymbol:(NSString *)symbol
                                          target:(id)target
                                          action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = PPLocationPickerPrimaryTextColor();
    button.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.84];
    button.layer.cornerRadius = 22.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.52].CGColor;
    button.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    button.layer.shadowOpacity = 0.10;
    button.layer.shadowRadius = 18.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    [button.widthAnchor constraintEqualToConstant:44.0].active = YES;
    [button.heightAnchor constraintEqualToConstant:44.0].active = YES;
    return button;
}

- (UIButton *)pp_makePrimaryConfirmButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = PPLocationPickerAccentColor();
    button.layer.cornerRadius = 18.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.shadowColor = PPLocationPickerAccentColor().CGColor;
    button.layer.shadowOpacity = 0.26;
    button.layer.shadowRadius = 20.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    button.titleLabel.font = [GM boldFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [button setTitle:[self pp_localizedStringForKey:nil fallbackEnglish:@"Use this location" arabic:@"استخدم هذا الموقع"]
            forState:UIControlStateNormal];
    [button addTarget:self action:@selector(confirmLocationTapped) forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:56.0].active = YES;
    return button;
}

- (void)pp_setupNavigationChrome
{
    self.navigationItem.title = @"";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    UIButton *backButton = [self pp_makeRoundChromeButtonWithSymbol:PPChevronName
                                                             target:self
                                                             action:@selector(pp_closePicker)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    self.navigationItem.rightBarButtonItem = nil;

    UINavigationBar *navBar = self.navigationController.navigationBar;
    navBar.tintColor = PPLocationPickerPrimaryTextColor();
    navBar.translucent = YES;
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        appearance.backgroundColor = UIColor.clearColor;
        appearance.shadowColor = UIColor.clearColor;
        appearance.titleTextAttributes = @{ NSForegroundColorAttributeName: PPLocationPickerPrimaryTextColor() };
        navBar.standardAppearance = appearance;
        navBar.scrollEdgeAppearance = appearance;
        navBar.compactAppearance = appearance;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [navBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
        navBar.shadowImage = [UIImage new];
#pragma clang diagnostic pop
    }
}

- (void)pp_setupMapCanvasWithCoordinate:(CLLocationCoordinate2D)startCoordinate
{
    GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:startCoordinate.latitude
                                                             longitude:startCoordinate.longitude
                                                                  zoom:15.0];
    self.mapView = [GMSMapView mapWithFrame:CGRectZero camera:camera];
    self.mapView.delegate = self;
    self.mapView.myLocationEnabled = YES;
    self.mapView.settings.myLocationButton = NO;
    self.mapView.settings.compassButton = NO;
    self.mapView.settings.indoorPicker = NO;
    self.mapView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mapView.layer.cornerRadius = 0.0;
    self.mapView.clipsToBounds = YES;
    [self.view addSubview:self.mapView];

    [NSLayoutConstraint activateConstraints:@[
        [self.mapView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.mapView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.mapView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.mapView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    self.topScrimView = [[UIView alloc] init];
    self.topScrimView.translatesAutoresizingMaskIntoConstraints = NO;
    self.topScrimView.userInteractionEnabled = NO;
    [self.view addSubview:self.topScrimView];

    self.bottomScrimView = [[UIView alloc] init];
    self.bottomScrimView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomScrimView.userInteractionEnabled = NO;
    [self.view addSubview:self.bottomScrimView];

    self.topScrimLayer = [CAGradientLayer layer];
    self.topScrimLayer.colors = @[
        (__bridge id)[[UIColor colorWithWhite:0.03 alpha:0.34] CGColor],
        (__bridge id)[[UIColor colorWithWhite:0.03 alpha:0.12] CGColor],
        (__bridge id)[UIColor.clearColor CGColor]
    ];
    self.topScrimLayer.locations = @[@0.0, @0.45, @1.0];
    [self.topScrimView.layer addSublayer:self.topScrimLayer];

    UIColor *bottomTint = [[UIColor colorWithRed:0.95 green:0.92 blue:0.88 alpha:1.0] colorWithAlphaComponent:0.90];
    self.bottomScrimLayer = [CAGradientLayer layer];
    self.bottomScrimLayer.colors = @[
        (__bridge id)[UIColor.clearColor CGColor],
        (__bridge id)[bottomTint colorWithAlphaComponent:0.24].CGColor,
        (__bridge id)bottomTint.CGColor
    ];
    self.bottomScrimLayer.locations = @[@0.0, @0.55, @1.0];
    [self.bottomScrimView.layer addSublayer:self.bottomScrimLayer];

    [NSLayoutConstraint activateConstraints:@[
        [self.topScrimView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.topScrimView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.topScrimView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.topScrimView.heightAnchor constraintEqualToConstant:260.0],

        [self.bottomScrimView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomScrimView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomScrimView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.bottomScrimView.heightAnchor constraintEqualToConstant:300.0]
    ]];
}

- (void)pp_setupLocationChrome
{
    UIColor *warmTint = [[UIColor colorWithRed:0.98 green:0.96 blue:0.93 alpha:1.0] colorWithAlphaComponent:0.62];
    UIColor *accentColor = PPLocationPickerAccentColor();

    self.heroChromeView = [self pp_makeChromePanelWithCornerRadius:28.0];
    [self.view addSubview:self.heroChromeView];

    self.heroTintView = [[UIView alloc] init];
    self.heroTintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTintView.backgroundColor = warmTint;
    self.heroTintView.userInteractionEnabled = NO;
    [self.heroChromeView.contentView addSubview:self.heroTintView];

    self.eyebrowLabel = [[UILabel alloc] init];
    self.eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.eyebrowLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    self.eyebrowLabel.textColor = [accentColor colorWithAlphaComponent:0.94];
    self.eyebrowLabel.textAlignment = NSTextAlignmentNatural;
    self.eyebrowLabel.text = [self pp_localizedStringForKey:nil fallbackEnglish:@"LIVE MAP" arabic:@"خريطة مباشرة"];
    [self.heroChromeView.contentView addSubview:self.eyebrowLabel];

    self.heroTitleLabel = [[UILabel alloc] init];
    self.heroTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroTitleLabel.font = [GM boldFontWithSize:29.0] ?: [UIFont systemFontOfSize:29.0 weight:UIFontWeightBold];
    self.heroTitleLabel.textColor = PPLocationPickerPrimaryTextColor();
    self.heroTitleLabel.numberOfLines = 2;
    self.heroTitleLabel.textAlignment = NSTextAlignmentNatural;
    self.heroTitleLabel.text = [self pp_localizedStringForKey:@"ChoseLocation" fallbackEnglish:@"Choose exact location" arabic:@"اختر الموقع بدقة"];
    [self.heroChromeView.contentView addSubview:self.heroTitleLabel];

    self.heroSubtitleLabel = [[UILabel alloc] init];
    self.heroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSubtitleLabel.font = [GM MidFontWithSize:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    self.heroSubtitleLabel.textColor = [PPLocationPickerSecondaryTextColor() colorWithAlphaComponent:0.92];
    self.heroSubtitleLabel.numberOfLines = 2;
    self.heroSubtitleLabel.textAlignment = NSTextAlignmentNatural;
    self.heroSubtitleLabel.text = [self pp_localizedStringForKey:nil fallbackEnglish:@"Move the map until the pin settles on the right spot." arabic:@"حرّك الخريطة حتى يستقر الدبوس على المكان الصحيح."];
    [self.heroChromeView.contentView addSubview:self.heroSubtitleLabel];

    self.selectionChromeView = [self pp_makeChromePanelWithCornerRadius:26.0];
    [self.view addSubview:self.selectionChromeView];

    self.selectionTintView = [[UIView alloc] init];
    self.selectionTintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionTintView.backgroundColor = [warmTint colorWithAlphaComponent:0.72];
    self.selectionTintView.userInteractionEnabled = NO;
    [self.selectionChromeView.contentView addSubview:self.selectionTintView];

    self.selectionSectionLabel = [[UILabel alloc] init];
    self.selectionSectionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionSectionLabel.font = [GM boldFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    self.selectionSectionLabel.textColor = [accentColor colorWithAlphaComponent:0.92];
    self.selectionSectionLabel.textAlignment = NSTextAlignmentNatural;
    self.selectionSectionLabel.text = [self pp_localizedStringForKey:nil fallbackEnglish:@"PINNED PLACE" arabic:@"الموقع المحدد"];
    [self.selectionChromeView.contentView addSubview:self.selectionSectionLabel];

    self.statusPillView = [[UIView alloc] init];
    self.statusPillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusPillView.layer.cornerRadius = 14.0;
    self.statusPillView.layer.cornerCurve = kCACornerCurveContinuous;
    self.statusPillView.layer.borderWidth = 1.0;
    self.statusPillView.layer.borderColor = [accentColor colorWithAlphaComponent:0.18].CGColor;
    [self.selectionChromeView.contentView addSubview:self.statusPillView];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.color = accentColor;
    self.spinner.hidesWhenStopped = YES;
    [self.statusPillView addSubview:self.spinner];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [GM MidFontWithSize:11.0] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    self.statusLabel.textAlignment = NSTextAlignmentNatural;
    [self.statusPillView addSubview:self.statusLabel];

    self.addressLabel = [[UILabel alloc] init];
    self.addressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.addressLabel.font = [GM boldFontWithSize:21.0] ?: [UIFont systemFontOfSize:21.0 weight:UIFontWeightBold];
    self.addressLabel.numberOfLines = 2;
    self.addressLabel.textAlignment = NSTextAlignmentNatural;
    self.addressLabel.textColor = PPLocationPickerPrimaryTextColor();
    [self.selectionChromeView.contentView addSubview:self.addressLabel];

    self.coordinatesLabel = [[UILabel alloc] init];
    self.coordinatesLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.coordinatesLabel.font = [UIFont monospacedDigitSystemFontOfSize:12.0 weight:UIFontWeightMedium];
    self.coordinatesLabel.textAlignment = NSTextAlignmentNatural;
    self.coordinatesLabel.textColor = [PPLocationPickerSecondaryTextColor() colorWithAlphaComponent:0.90];
    [self.selectionChromeView.contentView addSubview:self.coordinatesLabel];

    self.selectionHintLabel = [[UILabel alloc] init];
    self.selectionHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionHintLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    self.selectionHintLabel.numberOfLines = 2;
    self.selectionHintLabel.textAlignment = NSTextAlignmentNatural;
    self.selectionHintLabel.textColor = [PPLocationPickerSecondaryTextColor() colorWithAlphaComponent:0.88];
    [self.selectionChromeView.contentView addSubview:self.selectionHintLabel];

    self.bottomActionChromeView = [self pp_makeChromePanelWithCornerRadius:28.0];
    [self.view addSubview:self.bottomActionChromeView];

    self.bottomActionTintView = [[UIView alloc] init];
    self.bottomActionTintView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomActionTintView.backgroundColor = [warmTint colorWithAlphaComponent:0.78];
    self.bottomActionTintView.userInteractionEnabled = NO;
    [self.bottomActionChromeView.contentView addSubview:self.bottomActionTintView];

    self.bottomTitleLabel = [[UILabel alloc] init];
    self.bottomTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomTitleLabel.font = [GM boldFontWithSize:16.0] ?: [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    self.bottomTitleLabel.textAlignment = NSTextAlignmentNatural;
    self.bottomTitleLabel.textColor = PPLocationPickerPrimaryTextColor();
    self.bottomTitleLabel.numberOfLines = 2;
    [self.bottomActionChromeView.contentView addSubview:self.bottomTitleLabel];

    self.bottomSubtitleLabel = [[UILabel alloc] init];
    self.bottomSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomSubtitleLabel.font = [GM MidFontWithSize:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    self.bottomSubtitleLabel.textAlignment = NSTextAlignmentNatural;
    self.bottomSubtitleLabel.textColor = [PPLocationPickerSecondaryTextColor() colorWithAlphaComponent:0.88];
    self.bottomSubtitleLabel.numberOfLines = 2;
    [self.bottomActionChromeView.contentView addSubview:self.bottomSubtitleLabel];

    self.confirmButton = [self pp_makePrimaryConfirmButton];
    [self.bottomActionChromeView.contentView addSubview:self.confirmButton];

    self.recenterButton = [self pp_makeRoundChromeButtonWithSymbol:@"dot.scope" target:self action:@selector(centerToUserLocation)];
    self.recenterButton.accessibilityLabel = [self pp_localizedStringForKey:nil fallbackEnglish:@"Recenter map" arabic:@"إعادة تمركز الخريطة"];
    [self.view addSubview:self.recenterButton];

    self.pinHaloView = [[UIView alloc] init];
    self.pinHaloView.translatesAutoresizingMaskIntoConstraints = NO;
    self.pinHaloView.backgroundColor = [accentColor colorWithAlphaComponent:0.18];
    self.pinHaloView.layer.cornerRadius = 34.0;
    self.pinHaloView.layer.cornerCurve = kCACornerCurveContinuous;
    self.pinHaloView.userInteractionEnabled = NO;
    [self.view addSubview:self.pinHaloView];

    UIImage *pinImage = [UIImage imageNamed:@"standerpin"];
    if (!pinImage) {
        pinImage = [UIImage systemImageNamed:@"mappin.circle.fill"];
    }
    self.centerPinImageView = [[UIImageView alloc] initWithImage:pinImage];
    self.centerPinImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.centerPinImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.centerPinImageView.tintColor = accentColor;
    [self.view addSubview:self.centerPinImageView];

    [NSLayoutConstraint activateConstraints:@[
        [self.heroChromeView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16.0],
        [self.heroChromeView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16.0],
        [self.heroChromeView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8.0],

        [self.heroTintView.leadingAnchor constraintEqualToAnchor:self.heroChromeView.contentView.leadingAnchor],
        [self.heroTintView.trailingAnchor constraintEqualToAnchor:self.heroChromeView.contentView.trailingAnchor],
        [self.heroTintView.topAnchor constraintEqualToAnchor:self.heroChromeView.contentView.topAnchor],
        [self.heroTintView.bottomAnchor constraintEqualToAnchor:self.heroChromeView.contentView.bottomAnchor],

        [self.eyebrowLabel.leadingAnchor constraintEqualToAnchor:self.heroChromeView.contentView.leadingAnchor constant:20.0],
        [self.eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroChromeView.contentView.trailingAnchor constant:-20.0],
        [self.eyebrowLabel.topAnchor constraintEqualToAnchor:self.heroChromeView.contentView.topAnchor constant:18.0],

        [self.heroTitleLabel.leadingAnchor constraintEqualToAnchor:self.eyebrowLabel.leadingAnchor],
        [self.heroTitleLabel.trailingAnchor constraintEqualToAnchor:self.heroChromeView.contentView.trailingAnchor constant:-20.0],
        [self.heroTitleLabel.topAnchor constraintEqualToAnchor:self.eyebrowLabel.bottomAnchor constant:8.0],

        [self.heroSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.heroTitleLabel.leadingAnchor],
        [self.heroSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.heroTitleLabel.trailingAnchor],
        [self.heroSubtitleLabel.topAnchor constraintEqualToAnchor:self.heroTitleLabel.bottomAnchor constant:8.0],
        [self.heroSubtitleLabel.bottomAnchor constraintEqualToAnchor:self.heroChromeView.contentView.bottomAnchor constant:-18.0],

        [self.selectionChromeView.leadingAnchor constraintEqualToAnchor:self.heroChromeView.leadingAnchor],
        [self.selectionChromeView.trailingAnchor constraintEqualToAnchor:self.heroChromeView.trailingAnchor],
        [self.selectionChromeView.topAnchor constraintEqualToAnchor:self.heroChromeView.bottomAnchor constant:12.0],

        [self.selectionTintView.leadingAnchor constraintEqualToAnchor:self.selectionChromeView.contentView.leadingAnchor],
        [self.selectionTintView.trailingAnchor constraintEqualToAnchor:self.selectionChromeView.contentView.trailingAnchor],
        [self.selectionTintView.topAnchor constraintEqualToAnchor:self.selectionChromeView.contentView.topAnchor],
        [self.selectionTintView.bottomAnchor constraintEqualToAnchor:self.selectionChromeView.contentView.bottomAnchor],

        [self.selectionSectionLabel.leadingAnchor constraintEqualToAnchor:self.selectionChromeView.contentView.leadingAnchor constant:18.0],
        [self.selectionSectionLabel.topAnchor constraintEqualToAnchor:self.selectionChromeView.contentView.topAnchor constant:16.0],

        [self.statusPillView.trailingAnchor constraintEqualToAnchor:self.selectionChromeView.contentView.trailingAnchor constant:-18.0],
        [self.statusPillView.centerYAnchor constraintEqualToAnchor:self.selectionSectionLabel.centerYAnchor],
        [self.statusPillView.heightAnchor constraintEqualToConstant:28.0],

        [self.spinner.leadingAnchor constraintEqualToAnchor:self.statusPillView.leadingAnchor constant:10.0],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.statusPillView.centerYAnchor],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.spinner.trailingAnchor constant:6.0],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.statusPillView.trailingAnchor constant:-10.0],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.statusPillView.centerYAnchor],

        [self.addressLabel.leadingAnchor constraintEqualToAnchor:self.selectionSectionLabel.leadingAnchor],
        [self.addressLabel.trailingAnchor constraintEqualToAnchor:self.selectionChromeView.contentView.trailingAnchor constant:-18.0],
        [self.addressLabel.topAnchor constraintEqualToAnchor:self.selectionSectionLabel.bottomAnchor constant:10.0],

        [self.coordinatesLabel.leadingAnchor constraintEqualToAnchor:self.addressLabel.leadingAnchor],
        [self.coordinatesLabel.trailingAnchor constraintEqualToAnchor:self.addressLabel.trailingAnchor],
        [self.coordinatesLabel.topAnchor constraintEqualToAnchor:self.addressLabel.bottomAnchor constant:6.0],

        [self.selectionHintLabel.leadingAnchor constraintEqualToAnchor:self.addressLabel.leadingAnchor],
        [self.selectionHintLabel.trailingAnchor constraintEqualToAnchor:self.addressLabel.trailingAnchor],
        [self.selectionHintLabel.topAnchor constraintEqualToAnchor:self.coordinatesLabel.bottomAnchor constant:8.0],
        [self.selectionHintLabel.bottomAnchor constraintEqualToAnchor:self.selectionChromeView.contentView.bottomAnchor constant:-18.0],

        [self.bottomActionChromeView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16.0],
        [self.bottomActionChromeView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16.0],
        [self.bottomActionChromeView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-14.0],

        [self.bottomActionTintView.leadingAnchor constraintEqualToAnchor:self.bottomActionChromeView.contentView.leadingAnchor],
        [self.bottomActionTintView.trailingAnchor constraintEqualToAnchor:self.bottomActionChromeView.contentView.trailingAnchor],
        [self.bottomActionTintView.topAnchor constraintEqualToAnchor:self.bottomActionChromeView.contentView.topAnchor],
        [self.bottomActionTintView.bottomAnchor constraintEqualToAnchor:self.bottomActionChromeView.contentView.bottomAnchor],

        [self.bottomTitleLabel.leadingAnchor constraintEqualToAnchor:self.bottomActionChromeView.contentView.leadingAnchor constant:18.0],
        [self.bottomTitleLabel.trailingAnchor constraintEqualToAnchor:self.bottomActionChromeView.contentView.trailingAnchor constant:-18.0],
        [self.bottomTitleLabel.topAnchor constraintEqualToAnchor:self.bottomActionChromeView.contentView.topAnchor constant:18.0],

        [self.bottomSubtitleLabel.leadingAnchor constraintEqualToAnchor:self.bottomTitleLabel.leadingAnchor],
        [self.bottomSubtitleLabel.trailingAnchor constraintEqualToAnchor:self.bottomTitleLabel.trailingAnchor],
        [self.bottomSubtitleLabel.topAnchor constraintEqualToAnchor:self.bottomTitleLabel.bottomAnchor constant:6.0],

        [self.confirmButton.leadingAnchor constraintEqualToAnchor:self.bottomTitleLabel.leadingAnchor],
        [self.confirmButton.trailingAnchor constraintEqualToAnchor:self.bottomTitleLabel.trailingAnchor],
        [self.confirmButton.topAnchor constraintEqualToAnchor:self.bottomSubtitleLabel.bottomAnchor constant:14.0],
        [self.confirmButton.bottomAnchor constraintEqualToAnchor:self.bottomActionChromeView.contentView.bottomAnchor constant:-18.0],

        [self.recenterButton.trailingAnchor constraintEqualToAnchor:self.bottomActionChromeView.trailingAnchor],
        [self.recenterButton.bottomAnchor constraintEqualToAnchor:self.bottomActionChromeView.topAnchor constant:-14.0],

        [self.pinHaloView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.pinHaloView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-18.0],
        [self.pinHaloView.widthAnchor constraintEqualToConstant:68.0],
        [self.pinHaloView.heightAnchor constraintEqualToConstant:68.0],

        [self.centerPinImageView.centerXAnchor constraintEqualToAnchor:self.pinHaloView.centerXAnchor],
        [self.centerPinImageView.centerYAnchor constraintEqualToAnchor:self.pinHaloView.centerYAnchor constant:-3.0],
        [self.centerPinImageView.widthAnchor constraintEqualToConstant:50.0],
        [self.centerPinImageView.heightAnchor constraintEqualToConstant:50.0]
    ]];
}

- (void)pp_setConfirmButtonEnabled:(BOOL)enabled
{
    self.confirmButton.enabled = enabled;
    self.confirmButton.alpha = enabled ? 1.0 : 0.56;
}

- (NSString *)pp_coordinateStringForCoordinate:(CLLocationCoordinate2D)coordinate
{
    if (!PPLocationPickerCoordinateIsUsable(coordinate)) {
        return [self pp_localizedStringForKey:nil fallbackEnglish:@"Coordinates unavailable" arabic:@"الإحداثيات غير متاحة"];
    }
    return [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
}

- (void)pp_updateStatusWithText:(NSString *)text
                      tintColor:(UIColor *)tintColor
                        loading:(BOOL)loading
{
    UIColor *resolvedTint = tintColor ?: PPLocationPickerAccentColor();
    self.statusLabel.text = text ?: @"";
    self.statusLabel.textColor = resolvedTint;
    self.statusPillView.backgroundColor = [resolvedTint colorWithAlphaComponent:loading ? 0.18 : 0.12];
    self.statusPillView.layer.borderColor = [resolvedTint colorWithAlphaComponent:0.18].CGColor;
    if (loading) {
        [self.spinner startAnimating];
    } else {
        [self.spinner stopAnimating];
    }
}

- (void)pp_applyLocationPresentationWithTitle:(NSString *)title
                                   coordinate:(CLLocationCoordinate2D)coordinate
                                         hint:(NSString *)hint
                                   bottomHint:(NSString *)bottomHint
{
    NSString *resolvedTitle = title.length > 0
        ? title
        : [self pp_localizedStringForKey:nil fallbackEnglish:@"Move the map to choose a point" arabic:@"حرّك الخريطة لاختيار نقطة"];
    self.addressLabel.text = resolvedTitle;
    self.coordinatesLabel.text = [self pp_coordinateStringForCoordinate:coordinate];
    self.bottomTitleLabel.text = resolvedTitle;
    self.selectionHintLabel.text = hint ?: @"";
    self.bottomSubtitleLabel.text = bottomHint ?: @"";
    [self pp_setConfirmButtonEnabled:PPLocationPickerCoordinateIsUsable(coordinate)];
}

- (void)pp_updateMapInsetsForOverlayChrome
{
    if (!self.selectionChromeView || !self.bottomActionChromeView) {
        return;
    }
    CGFloat topInset = CGRectGetMaxY(self.selectionChromeView.frame) + 28.0;
    CGFloat bottomInset = CGRectGetHeight(self.view.bounds) - CGRectGetMinY(self.bottomActionChromeView.frame) + 16.0;
    self.mapView.padding = UIEdgeInsetsMake(topInset, 0.0, bottomInset, 0.0);
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.extendedLayoutIncludesOpaqueBars = YES;
    self.view.backgroundColor = UIColor.blackColor;
    self.geocoder = [[GMSGeocoder alloc] init];
    self.appleGeocoder = [[CLGeocoder alloc] init];
    self.lastGeocodeTime = [NSDate distantPast];
    self.lastKnownCoordinate = kCLLocationCoordinate2DInvalid;

    CLLocationCoordinate2D startCoordinate = self.initialCoordinate;
    BOOL shouldUseDohaFallback = !PPLocationPickerCoordinateIsUsable(startCoordinate) ||
        (fabs(startCoordinate.latitude) < DBL_EPSILON && fabs(startCoordinate.longitude) < DBL_EPSILON);
    if (shouldUseDohaFallback) {
        startCoordinate = [self pp_dohaCoordinate];
    }
    self.lastKnownCoordinate = startCoordinate;

    [self pp_setupMapCanvasWithCoordinate:startCoordinate];
    [self pp_setupLocationChrome];
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        [self applyDarkModeToMapView:self.mapView];
    }

    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    [self.locationManager requestWhenInUseAuthorization];
    [self.locationManager startUpdatingLocation];

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

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.topScrimLayer.frame = self.topScrimView.bounds;
    self.bottomScrimLayer.frame = self.bottomScrimView.bounds;
    self.pinHaloView.layer.shadowColor = PPLocationPickerAccentColor().CGColor;
    self.pinHaloView.layer.shadowOpacity = 0.20;
    self.pinHaloView.layer.shadowRadius = 26.0;
    self.pinHaloView.layer.shadowOffset = CGSizeZero;
    self.confirmButton.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.confirmButton.bounds
                                   cornerRadius:self.confirmButton.layer.cornerRadius].CGPath;
    [self pp_updateMapInsetsForOverlayChrome];
}


-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_setupNavigationChrome];
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
        self.centerPinImageView.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0, -15), CGAffineTransformMakeScale(1.04, 1.04));
        self.pinHaloView.transform = CGAffineTransformMakeScale(1.06, 1.06);
    }];
    [self pp_updateStatusWithText:[self pp_localizedStringForKey:nil fallbackEnglish:@"Moving" arabic:@"جارِ التحريك"]
                        tintColor:PPLocationPickerAccentColor()
                          loading:NO];
    self.selectionHintLabel.text = [self pp_localizedStringForKey:nil
                                                 fallbackEnglish:@"Release the map to lock the closest place."
                                                          arabic:@"اترك الخريطة لتثبيت أقرب موقع."];
}

- (void)mapView:(GMSMapView *)mapView idleAtCameraPosition:(GMSCameraPosition *)position {
    [UIView animateWithDuration:0.2 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.8 options:0 animations:^{
        self.centerPinImageView.transform = CGAffineTransformIdentity;
        self.pinHaloView.transform = CGAffineTransformIdentity;
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
    [self pp_updateStatusWithText:[self pp_localizedStringForKey:nil fallbackEnglish:@"Updating" arabic:@"جارِ التحديث"]
                        tintColor:PPLocationPickerAccentColor()
                          loading:YES];
    self.selectionHintLabel.text = [self pp_localizedStringForKey:nil
                                                 fallbackEnglish:@"We’re resolving the nearest address for this pin."
                                                          arabic:@"نحدّد الآن أقرب عنوان لهذه النقطة."];

    __weak typeof(self) weakSelf = self;
    dispatch_block_t timeoutBlock = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.geocodeRequestInFlight) return;
        self.geocodeRequestInFlight = NO;
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
        return [self pp_localizedStringForKey:nil fallbackEnglish:@"Choose a point on the map" arabic:@"اختر نقطة على الخريطة"];
    }
    return [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
}

- (void)pp_updateMapCardWithFallbackCoordinate:(CLLocationCoordinate2D)coordinate
{
    self.selectedLocationTitle = [self pp_fallbackTitleForCoordinate:coordinate];
    [self pp_applyLocationPresentationWithTitle:self.selectedLocationTitle
                                     coordinate:coordinate
                                           hint:[self pp_localizedStringForKey:nil
                                                              fallbackEnglish:@"You can confirm these coordinates now, or keep refining the pin."
                                                                       arabic:@"يمكنك تأكيد هذه الإحداثيات الآن أو متابعة ضبط الدبوس."]
                                     bottomHint:[self pp_localizedStringForKey:nil
                                                                 fallbackEnglish:@"We’ll save this map point even if the exact street name is still loading."
                                                                          arabic:@"سنحفظ هذه النقطة حتى لو كان اسم الشارع ما يزال قيد التحميل."]];
    [self pp_updateStatusWithText:[self pp_localizedStringForKey:nil fallbackEnglish:@"Coordinates only" arabic:@"إحداثيات فقط"]
                        tintColor:[UIColor colorWithRed:0.58 green:0.35 blue:0.25 alpha:1.0]
                          loading:NO];
}
#pragma mark - Map Card Update

- (void)updateMapCardWithGMSAddress:(GMSAddress *)address {
    if (!address) return;

    NSString *fullAddress = [self pp_compactAddressTitleFromGMSAddress:address];
    if (!fullAddress.length) {
        fullAddress = [self pp_localizedStringForKey:nil fallbackEnglish:@"Address not available" arabic:@"العنوان غير متاح"];
    }
    self.selectedLocationTitle = fullAddress;
    [self pp_applyLocationPresentationWithTitle:fullAddress
                                     coordinate:address.coordinate
                                           hint:[self pp_localizedStringForKey:nil
                                                              fallbackEnglish:@"Pinned and ready. You can still drag the map for a finer spot."
                                                                       arabic:@"تم تثبيت الموقع. ما زال بإمكانك تحريك الخريطة لمزيد من الدقة."]
                                     bottomHint:[self pp_localizedStringForKey:nil
                                                                 fallbackEnglish:@"This exact place will be attached to your address."
                                                                          arabic:@"سيتم ربط هذا الموقع الدقيق بعنوانك."]];
    [self pp_updateStatusWithText:[self pp_localizedStringForKey:nil fallbackEnglish:@"Ready" arabic:@"جاهز"]
                        tintColor:PPLocationPickerAccentColor()
                          loading:NO];
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
    self.selectedLocationTitle = resolvedTitle ?: @"";
    [self pp_applyLocationPresentationWithTitle:self.selectedLocationTitle
                                     coordinate:coordinate
                                           hint:[self pp_localizedStringForKey:nil
                                                              fallbackEnglish:@"Area resolved. Adjust the pin if you want a more precise entry point."
                                                                       arabic:@"تم تحديد المنطقة. حرّك الدبوس إذا أردت نقطة دخول أدق."]
                                     bottomHint:[self pp_localizedStringForKey:nil
                                                                 fallbackEnglish:@"This location is ready to be used."
                                                                          arabic:@"هذا الموقع جاهز للاستخدام."]];
    [self pp_updateStatusWithText:[self pp_localizedStringForKey:nil fallbackEnglish:@"Resolved" arabic:@"تم التحديد"]
                        tintColor:PPLocationPickerAccentColor()
                          loading:NO];
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
    if ( self.selectedAddress) {
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
            NSString *rowTitle = [LocationPickerViewController titleFromAddress:_selectedAddress];
            if (rowTitle.length == 0) {
                rowTitle = self.selectedLocationTitle;
            }
            self.rowDescriptor.value = rowTitle ?: @"";
            
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

    [self shakeView:self.bottomActionChromeView];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self pp_localizedStringForKey:nil
                                                                                          fallbackEnglish:@"Select a location"
                                                                                                   arabic:@"اختر موقعًا"]
                                                                   message:[self pp_localizedStringForKey:nil
                                                                                          fallbackEnglish:@"Move the map until the pin is on the right spot."
                                                                                                   arabic:@"حرّك الخريطة حتى يصبح الدبوس فوق المكان الصحيح."]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:[self pp_localizedStringForKey:nil
                                                                   fallbackEnglish:@"OK"
                                                                            arabic:@"حسنًا"]
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
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
