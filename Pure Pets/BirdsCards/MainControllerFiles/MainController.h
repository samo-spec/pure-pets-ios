//
//  MainControllerViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/02/2025.
//

#import <UIKit/UIKit.h>
#import "MainControllerHelper.h"
#import "TrashCollectionViewCell.h"
#import <IQKeyboardManager/IQKeyboardManager.h>
#import "PPCageCell.h"
#import "PPBirdSummaryCollectionCell.h"
#import "SalesCell.h"
#import "BarcodeGenerator.h"
 
@class PPS;


typedef NS_ENUM(NSInteger, PPMainBarTag) {
    PPMainBarTagCards = 0,
    PPMainBarTagCages,
    PPMainBarTagArchive,
    PPMainBarTagTrash,
};

typedef NS_ENUM(NSInteger, PPCardOption) {
    PPCardOptionEdit   = 0,
    PPCardOptionDelete = 1,
    PPCardOptionQR     = 2
};

@interface MainController : UIViewController<PPCageCellDelegate>


-(void)QrForID:(NSString *)barcodeString;
@property (nonatomic, strong) UICollectionView *collectionView;
- (void)updateSearchBadgesForText:(NSString *)text;
// Buttons
@property (strong, nonatomic) UIButton *refershArrow;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id<FIRListenerRegistration>> *childsCountListeners;

-(void)updateUnreadsCount;
@property (strong, nonatomic) UIButton *salesBTN;
@property (copy, nonatomic) NSIndexPath *SelectItemAtIndexPath;
@property (nonatomic, strong) UITabBar *mainTabBar;
@property (nonatomic, strong) NSArray<UITabBarItem *> *items;
@property (strong, nonatomic) CageModel *selectedCage;
@property (strong, nonatomic) ODRefreshControl *refreshControl;
- (void)applySnapshotAnimated:(BOOL)animated;
 
@property (strong, nonatomic) UITabBarItem *cardsBarItem;
@property (strong, nonatomic) UITabBarItem *cagesBarItem;
@property (strong, nonatomic) UITabBarItem *archiveBarItem;
@property (strong, nonatomic) UITabBarItem *trashBarItem;
@property (strong, nonatomic) UITabBarItem *salesBarItem;
- (void)topSegChanged:(NSInteger)index;
-(void)showAddNewCard;
@property (nonatomic, strong) NSMutableSet<NSURL *> *prefetchingURLs;
-(void)showAddNewCage;
@property (strong, nonatomic) PPS*searchView;
- (void)addNewArchive;
- (void)scrollCollectionViewToTopAnimated:(BOOL)animated;
@property (nonatomic) BOOL suppressScrollAdjustment;
@end



