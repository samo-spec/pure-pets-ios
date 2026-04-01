//
//  LocationPickerViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 05/07/2025.
//


#import <UIKit/UIKit.h>
#import <GoogleMaps/GoogleMaps.h>



@protocol LocationPickerDelegate <NSObject>
- (void)didSelectAddress:(PPAddressModel *)address forRowTag:(NSString *)rowTag;
- (void)didSelectLocationAddressModel:(PPAddressModel *)address;
- (void)didSelectGMSAddress:(GMSAddress *)address forRowDescriptor:(XLFormRowDescriptor *)rowDescriptor;

@end

@interface LocationPickerViewController : UIViewController <GMSMapViewDelegate, CLLocationManagerDelegate,XLFormRowDescriptorViewController>

@property (nonatomic, copy) void (^onLocationConfirmed)(GMSAddress *gmsAddress);
@property (nonatomic, copy, nullable) void (^onCoordinateConfirmed)(CLLocationCoordinate2D coordinate,
                                                                     NSString *locationTitle);
@property (nonatomic, assign) CLLocationCoordinate2D initialCoordinate;
//@property (nonatomic, strong) XLFormRowDescriptor *rowDescriptor;
@property(nonatomic,strong) PPAddressModel *selectedAddressTitleModel;
@property (nonatomic, weak) id<LocationPickerDelegate> delegate;
@property (nonatomic, strong) NSString *rowTag;
@property (nonatomic, strong) XLFormRowDescriptor *rowDescriptor;
+ (NSString *)titleFromAddress:(GMSAddress *)address;

@end

/*

@interface LocationPickerViewController : UIViewController <MKMapViewDelegate, CLLocationManagerDelegate>

@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, copy) void (^onLocationPicked)(CLLocationCoordinate2D coordinate);
@property (nonatomic, strong) CLGeocoder *geocoder;

@property (nonatomic, strong) UILabel *addressLabel;
@property (nonatomic, strong) CLPlacemark *selectedPlacemark;
@property (nonatomic, copy) void (^onLocationConfirmed)(CLLocationCoordinate2D coordinate, CLPlacemark *placemark);
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) UIImageView *centerPinView;

@property (nonatomic, strong) NSDate *lastGeocodeTime;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@end */
