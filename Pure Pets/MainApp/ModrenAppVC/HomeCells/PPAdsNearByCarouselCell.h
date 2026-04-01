//
//  PPAdsNearByCarouselCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/12/2025.
//


#import <UIKit/UIKit.h>

@class PPUniversalCellViewModel;

NS_ASSUME_NONNULL_BEGIN

@interface PPAdsNearByCarouselCell : UICollectionViewCell

+ (NSString *)reuseIdentifier;

/// Bind nearby ads (already converted to view models)
- (void)configureWithViewModels:(NSArray<PPUniversalCellViewModel *> *)models
                    startIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END