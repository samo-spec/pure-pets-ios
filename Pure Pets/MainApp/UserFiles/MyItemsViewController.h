//
//  MyItemsViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 31/05/2025.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, MyItemsMode) {
    MyItemsModeMyAds,
    MyItemsModeFavorites
};

typedef NS_ENUM(NSUInteger, ViewType) {
    ViewTypeAds,
    ViewTypeAccess,
    ViewTypeFood,
    ViewTypeAdopt,
};

@interface MyItemsViewController : UIViewController

- (instancetype)initWithMode:(MyItemsMode)mode;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, assign) ViewType viewType;
@property (nonatomic, assign) BOOL hidesBackButtonWhenOpenedFromHomeDeck;
- (void)fetchDataForCurrentSegment;
- (instancetype)initWithMode:(MyItemsMode)mode viewType:(ViewType)viewType;

@end
