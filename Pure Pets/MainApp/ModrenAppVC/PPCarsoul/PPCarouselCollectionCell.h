//
//  PPCarouselCollectionCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/12/2025.
//


#import <UIKit/UIKit.h>
@class PPCarouselItem;

@interface PPCarouselCollectionCell : UICollectionViewCell

- (void)configureWithCarouselItem:(PPCarouselItem *)item;

@end