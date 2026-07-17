#import "PPUniversalCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPCollectionLayoutManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPUniversalCell (SwiftUIAdapter)

/// Returns PPUniversalCell.class when BBUniversalCellUseSwiftUI is NO,
/// PPUniversalCardHostingCell.class when YES.
+ (Class)pp_cellClass;

/// Registers the preferred cell class (ObjC PPUniversalCell or SwiftUI
/// PPUniversalCardHostingCell) under reuseIdentifier @"PPUniversalCell".
+ (void)pp_registerInCollectionView:(UICollectionView *)collectionView;

/// Dequeues a cell that responds to the full PPUniversalCell public API.
/// When BBUniversalCellUseSwiftUI is YES the returned object is a
/// PPUniversalCardHostingCell; otherwise it is a regular PPUniversalCell.
/// Callers should use `id` and rely on dynamic dispatch.
+ (id)pp_dequeueFromCollectionView:(UICollectionView *)collectionView
                         indexPath:(NSIndexPath *)indexPath;

/// Returns YES when the cell is an instance of either PPUniversalCell or
/// PPUniversalCardHostingCell (replaces isKindOfClass: checks).
+ (BOOL)pp_isUniversalCell:(UICollectionViewCell *)cell;

@end

NS_ASSUME_NONNULL_END
