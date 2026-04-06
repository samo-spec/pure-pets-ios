//  AddNewAd.h

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

#import "importantFiles.h"
#import "RelativeDateDescriptor.h"
@class PetAd;
@class PetImageItem;
@class GSIndeterminateProgressView;
@class CreateAdCoordinator;
@class PPImageCollection;
@class PPAdFormField;

NS_ASSUME_NONNULL_BEGIN

static NSString *const kcategory    = @"category";
static NSString *const ksubcategory = @"subcategory";
static NSString *const kprice       = @"price";
static NSString *const kdesc        = @"desc";
static NSString *const kimages      = @"images";
static NSString *const kpetAge      = @"petAge";
static NSString *const kadLocation  = @"adLocation";

typedef NS_ENUM(NSUInteger, AdEditorMode) {
    AdEditorModeCreate = 0,
    AdEditorModeEdit   = 1
};

@protocol AddNewAdDelegate;

@interface AddNewAd : UITableViewController

@property (nonatomic, weak) CreateAdCoordinator *coordinator;
@property (nonatomic, assign) AdEditorMode mode;
@property (nonatomic, strong) PetAd *initialAd;

- (instancetype)initWithCoordinator:(CreateAdCoordinator *)coordinator;

@property (nonatomic, strong, nullable) MainKindsModel *selectedMainKind;
@property (strong, nonatomic) NSString *FromVC;
@property (nonatomic, strong, nullable) PetAd *editingAd;
@property (nonatomic, weak, nullable) id<AddNewAdDelegate> delegate;
@property (nonatomic, strong) NSMutableArray<PetImageItem *> *imageMeta;

// UI
@property (nonatomic, strong) GSIndeterminateProgressView *uploadProgressView;
@property (nonatomic, strong) NSMutableArray *imagesFromStorage;
@property (nonatomic, assign) CLLocationCoordinate2D selectedAdCoordinate;
@property (nonatomic, assign) BOOL hasSelectedAdCoordinate;
@property (nonatomic, copy, nullable) NSString *selectedAdLocationName;

// Image collection for the photo grid
@property (nonatomic, strong) PPImageCollection *imageCollection;
@property (nonatomic, strong) NSLayoutConstraint *tableHeightConstraint;

@end

@protocol AddNewAdDelegate <NSObject>
@optional
- (void)addNewAd:(AddNewAd *)vc didCreateAd:(PetAd *)ad;
- (void)addNewAd:(AddNewAd *)vc didUpdateAd:(PetAd *)ad;
@end

NS_ASSUME_NONNULL_END

