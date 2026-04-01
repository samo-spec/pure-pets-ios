//
//  ViewController.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 07/12/2025.
//

#import "ODRefreshControl.h"


// Constants for UI elements and animation
static const CGFloat kStoriesBarCollapsedHeight = 0.0;
static const CGFloat kSearchContainerCornerRadiusExpanded = 20.0;
static const CGFloat kSearchContainerCornerRadiusCollapsed = 20.0;
static const CGFloat kAnimationDurationLocal = 0.3;
static const CGFloat kShadowOpacity = 0.0;
static const CGFloat kShadowRadius = 0.0;
static const CGFloat kRadius = 20.0;
static const CGSize kShadowOffset = {0, 2};
static const CGFloat padding = 12.0;
typedef NS_ENUM(NSInteger, LayoutType) {
    LayoutTypeDefault,
    LayoutTypeCompact
};

typedef NS_ENUM(NSInteger, CellType) {
    CellTypeDefault,
    CellTypeCustom
};


typedef NS_ENUM(NSInteger, Sort) {
    SortAsc,
    SortDesc
};

typedef NS_ENUM(NSInteger, Local_PPButtonConfigration) {
    Local_PPButtonConfigrationGlass = 0,
    Local_PPButtonConfigrationClearGlass,
    Local_PPButtonConfigrationPromp,
    Local_PPButtonConfigrationClearPromp,
    Local_PPButtonConfigrationTinted,
    Local_PPButtonConfigrationTintedBorderd,
    Local_PPButtonConfigrationFilled
    
};

typedef NS_ENUM(NSInteger, CellSection) {
    CellSectionTrash = 0,
    CellSectionArchive,
    CellSectionCage,
    CellSectionCards,
    CellSectionSalesBuyer
};

// CELLS

#import "ArchCell.h"


// Controllers
#import "NewCardForm.h"
#import "ArchiveManagerVC.h"
#import "selectArchiveVC.h"
#import "selectChildViewController.h"
#import "NewCageVC.h"
#import "FirstEggVC.h"
#import "SettingVC.h"

//third Part
#import "UIViewController+PVCMotal.h"
#import "RoundedImageViewWithShadow.h"
#import "ZXQRScanViewController.h"

@class EmptyStateView;
NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (MainControllerHelper) <
UICollectionViewDelegate,
UICollectionViewDataSource,
ArchCellDelegate,
settingDelegate,
UICollectionViewDelegateFlowLayout,UIGestureRecognizerDelegate
>

- (UIButton *)Local_setButtonAsBackroundButtonWithStyle:(UIButtonConfigurationCornerStyle)style configType:(Local_PPButtonConfigration)configType;
- (UIButton *)Local_setButtonAsBackroundButtonWithStyle:(UIButtonConfigurationCornerStyle)style;

@property (nonatomic, assign) BOOL didInitialLoad;
- (void)configureTabBarItems:(NSArray<NSDictionary *> *)items;
-(void)setThisEmptyCard:(UIButton *)emptyCard childHeight:(float)height isSegEmptyCard:(BOOL)isSegEmptyCard;


@property (nonatomic,strong) CardModel                          *selectedCard;
@property (nonatomic,strong) UIImage                            *selectedImage;

@property (nonatomic,strong) NSArray<CardModel *>               *allCardsArray;
@property (nonatomic,strong) NSMutableArray<CardModel *>        *userCardsArray;
@property (nonatomic,strong) NSMutableArray<TrashModel *>       *trachArray;

@property (nonatomic, strong) NSMutableArray<ArchiveModel *>    *UserArchivesDocs;

@property (nonatomic,strong) NSMutableArray<CageModel *>        *CagedataSource;
@property (nonatomic,strong) NSArray<SubKindModel *>            *SubKindsArrayLocal;
@property (nonatomic,strong) NSMutableArray<SubKindModel *>     *SubKinsFilterArr;
@property (nonatomic,strong) NSMutableArray<BuyerModel *>       *SalesBuyerArr;

@property (strong, nonatomic) NSString                          *userID;

@property (nonatomic, strong) AppManager                        *dataManager;
@property (nonatomic, assign) NSInteger                         lastSegmentedIndex;
@property (nonatomic) CellSection                               cellSection;
@property (strong, nonatomic) NSString                          *currentLanguage;
@property (nonatomic, strong) UIButton                          *segEmptyCard;

// Stories Var
 
@property (nonatomic, assign) CGFloat lastContentOffset;
@property (nonatomic, assign) BOOL isScrollingUp; // Track scroll direction
@property (nonatomic, assign) LayoutType layoutType;
@property (nonatomic, assign) CellType cellType;
@property (nonatomic, assign) NSInteger puaseAnimation;
@property (nonatomic, assign) Sort sort;
@property (nonatomic, strong) UIButton *FilterBTN;

@property (strong, nonatomic) EmptyStateView  *emptyStateView;
//@property (strong, nonatomic) UISegmentedControl* topSeg;



- (void)cellSectionChanged;
- (void)showParentData:(NSString *)ParentID;
- (void)showEggDateController:(CageModel *)CageData;
- (void)deleteEditCageOptions:(long)index CageData:(CageModel *)CageData cellView:(UIView *)cellView cellIndexPath:(NSIndexPath *)cellIndexPath;
- (NSString *)formatLabel:(NSString *)label value:(NSString *)value;
- (NSString * _Nullable)primaryImageURLForCard:(CardModel *)cardData;
- (void)configureAppearance;
- (void)applyTabBarShadowToContainer:(UIView *)container;
-(void)setUnreadsCountTo:(NSString *)count;
-(void)searchBarCancelButtonClicked:(UISearchBar *)searchBar;
-(void) restoreCurrentDataSource;

- (void)RestoreChild:(NSString *)CageID ChildRingID:(NSString *)ChildRingID childIndexPath:(NSIndexPath *)childIndexPath childID:(NSString *)childID cardData:(nonnull CardModel *)cardData cameFrom:(NSInteger)cameFrom;
-(void)updateIsDeletedForArchiveID:(NSString *)archiveID andArchiveDetailsID:(NSString *)ArchiveDetailsID withNewValue:(NSInteger)newValue completion:(void (^_Nullable)(NSError * _Nullable error))completion;
-(void)updateIsDeletedForCardID:(NSString *)cardID isDeleted:(NSInteger)isDeleted completion:(void (^_Nullable)(NSError * _Nullable error))completion;
- (void)showViewer:(CardModel *)cardData;
- (void)deleteEditArchiveOptions:(long)index ArchiveData:(ArchiveModel *)ArchiveData cellView:(UIView *)cellView cellIndexPath:(NSIndexPath *)cellIndexPath;

- (void)updateChildIsDeletedWithChildID:(NSString *)childID CageID:(NSString *)cageID isDeleted:(NSInteger)isDeletedValue;

- (void)showFilter:(id)sender;
- (void)sortDesc;
- (void)sortCagesNames;
- (void)sortAsc;


-(void)DetaildsFromTrash:(CardModel *)cardData;
 - (void)searchStringWithBarCode:(NSString *)searchedString;
-(void)FliterDependOnSubKindID:(NSInteger)subKind;
- (void)searchString:(NSString *)searchedString;
- (UIButton *)Local_ButtonWithSystemName:(NSString *)imageName;





@end

NS_ASSUME_NONNULL_END
