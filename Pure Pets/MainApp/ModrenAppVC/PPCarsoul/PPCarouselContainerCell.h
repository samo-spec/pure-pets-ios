//
//  PPCarouselContainerCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/12/2025.
//


#import <UIKit/UIKit.h>

@class PPCarouselItem;

NS_ASSUME_NONNULL_BEGIN

@interface PPCarouselContainerCell : UICollectionViewCell

- (void)configureWithCarouselItems:(NSArray<PPCarouselItem *> *)items;

@end

NS_ASSUME_NONNULL_END