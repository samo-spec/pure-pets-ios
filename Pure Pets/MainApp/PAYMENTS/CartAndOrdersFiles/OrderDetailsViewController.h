//
//  OrderDetailsViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 04/07/2025.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "PPOrder.h"

typedef NS_ENUM(NSInteger, PPOrderDetailsEntryPresentationState) {
    PPOrderDetailsEntryPresentationStateNone,
    PPOrderDetailsEntryPresentationStateCheckoutSuccess,
    PPOrderDetailsEntryPresentationStateVerificationPending
};

@interface OrderDetailsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, MKMapViewDelegate>

@property (nonatomic, strong, nullable) PPOrder *order;
@property (nonatomic, assign) PPOrderDetailsEntryPresentationState entryPresentationState;
@property (nonatomic, copy, nullable) NSString *entryPresentationMessage;

- (instancetype)initWithOrder:(PPOrder *)order;

@end

