//
//  PPCenteredSelectorView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/12/2025.
//


//  PPCenteredSelectorView.h
//
//  PPCenteredSelectorView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 08/12/2025.
//

#import <UIKit/UIKit.h>
#import "PPCenteredSelectorView.h"


@class MainKindsModel;

NS_ASSUME_NONNULL_BEGIN

@protocol PPCenteredSelectorViewDelegate <NSObject>
/// Called whenever the centered/selected item changes (tap or drag snap)
- (void)selectorDidSelectIndex:(NSInteger)index item:(MainKindsModel *)item;
@end

/// Horizontal, centered, scaled category selector backed by ScaledCenterCarousel
@interface PPCenteredSelectorView : UIView <YTScaledCenterCarouselDataSource, UICollectionViewDataSource>

@property (nonatomic, weak) id<PPCenteredSelectorViewDelegate> delegate;

/// Backing collection view (read-only, in case you need styling / extra configuration)
@property (nonatomic, strong, readonly) UICollectionView *collectionView;

/// Data source: list of MainKindsModel (categories)
@property (nonatomic, copy) NSArray<MainKindsModel *> *items;

/// Required by YTScaledCenterCarouselDataSource – single source of truth for selection
@property (nonatomic, assign) NSUInteger selectedIndex;

/// Designated initializer
- (instancetype)initWithItems:(NSArray<MainKindsModel *> *)items NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

/// Reload with new items and preselect a given index (safe-clamped to bounds)
- (void)reloadWithItems:(NSArray<MainKindsModel *> *)items
         preselectIndex:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END

