//
//  PPAdsBrowser.h
//  Pure Pets
//
//  Created by Sam + ChatGPT.
//

#import <UIKit/UIKit.h>

#import "PetAdManager.h"

@class YYWebImageOperation;

NS_ASSUME_NONNULL_BEGIN


@protocol AdsBrowserDelegate <NSObject>
-(void)didSelectIndex:(NSInteger)index;
@end


@interface PPCategoryKindCell : UICollectionViewCell
@property (nonatomic, weak) id <AdsBrowserDelegate> delegate;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) NSIndexPath *indexPath;
@property (nonatomic, strong) UIButton *cellBgButton;
@property (nonatomic, strong) NSLayoutConstraint *cellBgButtonWidth;
- (void) updateValuesWithTitle:(NSString *)title imageName:(NSString *)imageName;
- (void)updateCellBgButtonWidth:(CGFloat)width ;

@end

@class AdsControllerHelper;
@class PPCenteredSelectorView;


@interface PPAdsBrowser : UIView <
UICollectionViewDataSource,
UICollectionViewDelegateFlowLayout,
PPUniversalCellDelegate,
AdsBrowserDelegate,
UICollectionViewDataSourcePrefetching,
UICollectionViewDelegate,PPPinterestLayoutDelegate
>


@property (nonatomic, strong) UICollectionView *adsCollectionView;

@property (nonatomic, strong) UICollectionViewDiffableDataSource<NSNumber *, PPUniversalCellViewModel *> *adsDataSource;
@property (nonatomic, assign, readwrite) NSInteger selectedCategoryID;
@property (nonatomic, strong) PetAdManager *adManager;

// NEW: keep track of prefetch tasks so we can cancel
@property (nonatomic,  strong) NSMutableDictionary<NSIndexPath *, YYWebImageOperation *> *prefetchTasks;

@property (nonatomic, strong) PPCenteredSelectorView *selector;
@property (nonatomic, assign) CollectioCellSection cellSection;

@property (nonatomic, strong) NSLayoutConstraint *containerWidth;
@property (nonatomic, strong) NSMutableArray<PetAd *> *ads;
@property (nonatomic, strong) NSString *heightCacheKey;
@property (nonatomic, strong) NSArray<MainKindsModel *> *categories;
@property (nonatomic, weak, nullable) id<PPUniversalCellDelegate> externalCellDelegate;
@property (nonatomic, assign) PPManagerCellLayoutMode cellLayoutMode;
@property (nonatomic, assign) float NavBarHeight;
 
+ (instancetype)browserWithCategories:(NSArray<MainKindsModel *> *)categories navHeight:(float)navHeight;
+ (instancetype)initWithCategories:(NSArray<MainKindsModel *> *)categories navHeight:(float)navHeight;
- (instancetype)initWithFrame:(CGRect)frame categories:(NSArray<MainKindsModel *> *)categories  navHeight:(float)navHeight NS_DESIGNATED_INITIALIZER;
- (void)reloadCurrentCategory;
- (void)selectCategoryWithID:(NSInteger)categoryID;

- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;

@end









//
//  LTInfiniteScrollView.h
//  LTInfiniteScrollView
//
//  Created by ltebean on 14/11/21.
//  Copyright (c) 2014年 ltebean. All rights reserved.
//


typedef enum ScrollDirection {
    ScrollDirectionNext,
    ScrollDirectionPrev,
} ScrollDirection;

@class LTInfiniteScrollView;

@protocol LTInfiniteScrollViewDelegate<NSObject>
@optional
- (void)updateView:(UIView *)view withProgress:(CGFloat)progress scrollDirection:(ScrollDirection)direction;
- (void)scrollView:(LTInfiniteScrollView *)scrollView didScrollToIndex:(NSInteger)index;
@end

@protocol LTInfiniteScrollViewDataSource<NSObject>
- (UIView *)viewAtIndex:(NSInteger)index reusingView:(UIView *)view;
- (NSInteger)numberOfViews;
- (NSInteger)numberOfVisibleViews;
@end

@interface LTInfiniteScrollView: UIView
@property (nonatomic, readonly) NSInteger currentIndex;
@property (nonatomic, weak) id<LTInfiniteScrollViewDataSource> dataSource;
@property (nonatomic, weak) id<LTInfiniteScrollViewDelegate> delegate;
@property (nonatomic) BOOL verticalScroll;
@property (nonatomic) BOOL scrollEnabled;
@property (nonatomic) BOOL pagingEnabled;
@property (nonatomic) BOOL bounces;
@property (nonatomic) UIEdgeInsets contentInset;
@property (nonatomic) NSInteger maxScrollDistance;

- (void)reloadDataWithInitialIndex:(NSInteger)initialIndex;
- (void)scrollToIndex:(NSInteger)index animated:(BOOL)animated;
- (UIView *)viewAtIndex:(NSInteger)index;
- (NSArray *)allViews;
@end
NS_ASSUME_NONNULL_END
