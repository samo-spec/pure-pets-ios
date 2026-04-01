//
//  PPCarouselView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/12/2025.
//


#import <UIKit/UIKit.h>
@class PPCarouselItem;

@interface PPCarouselView : UIView

@property (nonatomic, copy) void (^onItemTap)(PPCarouselItem *item);

- (void)configureWithItems:(NSArray<PPCarouselItem *> *)items;
- (void)startAutoScroll;
- (void)stopAutoScroll;

@end