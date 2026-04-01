//
//  PPMapPreviewCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/09/2025.
//


// PPMapPreviewCell.h
#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPMapPreviewCell : UITableViewCell
@property (nonatomic, strong) MKMapView *mapView;
+ (NSString *)reuseIdentifier;
- (void)updatePins:(NSArray<MKMapItem *> *)items userLocation:(nullable CLLocation *)userLoc;
@property (nonatomic, strong)  UIView *emptyCard;

@end

NS_ASSUME_NONNULL_END
