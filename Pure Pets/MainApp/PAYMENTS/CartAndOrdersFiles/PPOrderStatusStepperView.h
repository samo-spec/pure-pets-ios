//
//  PPOrderStatusStepperView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//





@interface PPOrderStatusStepperView : UIView

- (void)configureWithSteps:(NSArray<NSString *> *)steps
              currentIndex:(NSInteger)currentIndex
              showsFailure:(BOOL)showsFailure
                 tintColor:(nullable UIColor *)tintColor;

@end
