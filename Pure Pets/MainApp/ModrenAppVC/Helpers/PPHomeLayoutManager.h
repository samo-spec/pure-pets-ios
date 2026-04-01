//
//  PPHomeLayoutManager.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/01/2026.
//


#import <UIKit/UIKit.h>
#import "PPHomeFunc.h"
#import "PPHomeViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPHomeLayoutManager : NSObject

@property (nonatomic, assign) BOOL isMainKindsExpanded;
@property (nonatomic, assign) BOOL isCurrentOrdersExpanded;

/// Designated initializer
- (instancetype)initWithMainKindsExpanded:(BOOL)isMainKindsExpanded;

/// Returns fully configured compositional layout
- (UICollectionViewCompositionalLayout *)buildLayout;
@property (nonatomic, assign) BOOL isSkeleton;
@end

NS_ASSUME_NONNULL_END
