#import "PPUniversalCell+SwiftUIAdapter.h"
#import "PPUniversalCellFlags.h"

@implementation PPUniversalCell (SwiftUIAdapter)

+ (Class)pp_cellClass
{
    if (@available(iOS 16.0, *)) {
        if (BBUniversalCellUseSwiftUI) {
            Class swiftCell = NSClassFromString(@"PurePets.PPUniversalCardHostingCell");
            if (swiftCell) return swiftCell;
        }
    }
    return self;
}

+ (void)pp_registerInCollectionView:(UICollectionView *)collectionView
{
    Class cellClass = [self pp_cellClass];
    [collectionView registerClass:cellClass
       forCellWithReuseIdentifier:[self reuseIdentifier]];
}

+ (id)pp_dequeueFromCollectionView:(UICollectionView *)collectionView
                         indexPath:(NSIndexPath *)indexPath
{
    return [collectionView dequeueReusableCellWithReuseIdentifier:[self reuseIdentifier]
                                                     forIndexPath:indexPath];
}

+ (BOOL)pp_isUniversalCell:(UICollectionViewCell *)cell
{
    if ([cell isKindOfClass:[PPUniversalCell class]]) return YES;
    if (@available(iOS 16.0, *)) {
        if (BBUniversalCellUseSwiftUI) {
            Class swiftCell = NSClassFromString(@"PurePets.PPUniversalCardHostingCell");
            if (swiftCell && [cell isKindOfClass:swiftCell]) return YES;
        }
    }
    return NO;
}

@end
