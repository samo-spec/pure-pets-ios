//
//  PPHomeUltraPremuimProviderCategoryPillCell.h
//  Pure Pets
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PPHomeProviderCategoryItem;

@interface PPHomeUltraPremuimProviderCategoryPillCell : UICollectionViewCell

@property (class, nonatomic, readonly) NSString *reuseIdentifier;
@property (nonatomic, copy, nullable) void (^onTap)(PPHomeProviderCategoryItem *item);

- (void)configureWithItem:(PPHomeProviderCategoryItem *)item selected:(BOOL)selected;

@end

NS_ASSUME_NONNULL_END
