//
//  PPAuthStepIndicatorView.h
//  Pure Pets
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPAuthStepIndicatorView : UIView

- (instancetype)initWithStepTitles:(NSArray<NSString *> *)stepTitles;
- (void)updateCurrentStepIndex:(NSInteger)currentStepIndex
            completedStepIndex:(NSInteger)completedStepIndex
                       animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
