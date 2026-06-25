//
//  PPHomeCartNavButton.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/5/26.
//


@interface PPHomeCartNavButton : UIControl
- (void)updateCount:(NSInteger)count animated:(BOOL)animated;
- (void)setIconName:(NSString *)iconName;
- (void)applyHeroPresentationStyle;
@end
