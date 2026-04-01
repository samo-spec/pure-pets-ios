//
//  PPMapPreviewCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/09/2025.
//


// PPMapPreviewCell.m
#import "PPMapPreviewCell.h"

@implementation PPMapPreviewCell

+ (NSString *)reuseIdentifier { return @"PPMapPreviewCellIdentifier"; }

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        [self setup];
    }
    return self;
}

- (void)setup {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    self.contentView.layer.masksToBounds = NO;
    self.layer.masksToBounds = NO;
    
    self.contentView.clipsToBounds = NO;
    self.clipsToBounds = NO;
    
    
    self.emptyCard = [PPFunc createEmptyModernCardView];
    [self.contentView addSubview:self.emptyCard];

    // Set constraints for the empty card view to position it in the view
    [NSLayoutConstraint activateConstraints:@[
        [self.emptyCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:0],
        [self.emptyCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-0],
        [self.emptyCard.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:0],
        [self.emptyCard.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:0],
    ]];
    
    
    self.mapView = [[MKMapView alloc] initWithFrame:CGRectZero];
    self.mapView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mapView.layer.cornerRadius = 25;
    self.mapView.clipsToBounds = YES;
    [self.emptyCard addSubview:self.mapView];

    CGFloat margin = 0;
    [NSLayoutConstraint activateConstraints:@[
        [self.mapView.leadingAnchor constraintEqualToAnchor:self.emptyCard.leadingAnchor constant:margin],
        [self.mapView.trailingAnchor constraintEqualToAnchor:self.emptyCard.trailingAnchor constant:-margin],
        [self.mapView.topAnchor constraintEqualToAnchor:self.emptyCard.topAnchor constant:0],
        [self.mapView.bottomAnchor constraintEqualToAnchor:self.emptyCard.bottomAnchor constant:-0],
        [self.mapView.heightAnchor constraintEqualToConstant:180]
    ]];
}

- (void)updatePins:(NSArray<MKMapItem *> *)items userLocation:(nullable CLLocation *)userLoc {
    [self.mapView removeAnnotations:self.mapView.annotations];
    for (MKMapItem *mi in items) {
        MKPointAnnotation *ann = [MKPointAnnotation new];
        ann.title = mi.name;
        ann.subtitle = mi.placemark.title;
        ann.coordinate = mi.placemark.coordinate;
        [self.mapView addAnnotation:ann];
    }
    if (userLoc) {
        CLLocationCoordinate2D center = userLoc.coordinate;
        MKCoordinateRegion r = MKCoordinateRegionMakeWithDistance(center, 5000, 5000);
        [self.mapView setRegion:r animated:NO];
    } else if (items.count > 0) {
        // center on first item
        MKMapItem *first = items.firstObject;
        MKCoordinateRegion r = MKCoordinateRegionMakeWithDistance(first.placemark.coordinate, 8000, 8000);
        [self.mapView setRegion:r animated:NO];
    }
}

@end
