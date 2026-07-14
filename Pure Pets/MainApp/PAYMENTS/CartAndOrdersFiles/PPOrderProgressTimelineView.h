//
//  PPOrderProgressTimelineView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//


@interface PPOrderProgressTimelineView : UIView

- (void)configureWithStepDescriptors:(NSArray<NSDictionary *> *)stepDescriptors
                        currentIndex:(NSInteger)currentIndex
                        showsFailure:(BOOL)showsFailure
                            expanded:(BOOL)expanded
                           tintColor:(nullable UIColor *)tintColor
                            animated:(BOOL)animated;
- (CGFloat)preferredHeightForWidth:(CGFloat)width;
- (void)refreshCurrentStatusMotion;

@end