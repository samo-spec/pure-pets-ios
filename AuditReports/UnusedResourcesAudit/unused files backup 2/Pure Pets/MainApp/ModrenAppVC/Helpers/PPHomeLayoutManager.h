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
@property (nonatomic, assign) BOOL isPetProfileExpanded;

/// Resolves the section type for a given index.
/// This allows the layout to stay in sync with the data source's snapshot.
typedef PPHomeSection (^PPHomeSectionIdentifierProvider)(NSInteger sectionIndex);
@property (nonatomic, copy, nullable) PPHomeSectionIdentifierProvider sectionIdentifierProvider;

/// Returns the number of items in a section.
typedef NSInteger (^PPHomeSectionItemCountProvider)(NSInteger sectionIndex);
@property (nonatomic, copy, nullable) PPHomeSectionItemCountProvider itemCountProvider;

/// Designated initializer
- (instancetype)initWithMainKindsExpanded:(BOOL)isMainKindsExpanded;

/// Returns fully configured compositional layout
- (UICollectionViewCompositionalLayout *)buildLayout;
@property (nonatomic, assign) BOOL isSkeleton;
@end

NS_ASSUME_NONNULL_END
