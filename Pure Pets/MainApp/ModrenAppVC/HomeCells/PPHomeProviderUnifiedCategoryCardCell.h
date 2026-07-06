//
//  PPHomeProviderUnifiedCategoryCardCell.h
//  Pure Pets
//

#import <UIKit/UIKit.h>
#import "PPHomeProviderCategoryPillCell.h"

NS_ASSUME_NONNULL_BEGIN

// Temporary unified provider-category presentation.
// Original provider cells remain preserved and can be restored through the layout flag.
FOUNDATION_EXPORT BOOL PPHomeUseUnifiedProviderCategoryCard;

@interface PPHomeProviderUnifiedCategoryCardCell : UICollectionViewCell

@property (class, nonatomic, readonly) NSString *reuseIdentifier;
@property (nonatomic, copy, nullable) void (^onTap)(PPHomeProviderCategoryItem *item);

- (void)configureWithLeftItem:(nullable PPHomeProviderCategoryItem *)leftItem
                    rightItem:(nullable PPHomeProviderCategoryItem *)rightItem;

@end

NS_ASSUME_NONNULL_END
