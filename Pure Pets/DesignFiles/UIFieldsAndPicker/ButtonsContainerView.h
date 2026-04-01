//
//  ButtonsContainerView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ButtonsContainerView : UIView

/// Set buttons using image names (from asset catalog) and selector strings
- (void)setButtonsWithImageNames:(NSArray<NSString *> *)imageNames
                          target:(id)target
                         actions:(NSArray<NSString *> *)selectorNames;

@end

NS_ASSUME_NONNULL_END

