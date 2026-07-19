//
//  PPHomePremiumCareCell.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/29/26.
//

#import <UIKit/UIKit.h>

@interface PPHomePremiumCareCell : UICollectionViewCell
+ (NSString *)reuseIdentifier;
- (void)configure;
- (void)configureWithAnimationName:(NSString *)animationName;
- (void)pp_configureCareAnimationNamed:(NSString *)animationName;
- (void)pp_revealConfiguredCareAnimation;
- (void)pp_preparePostLayoutEntranceState;
- (void)pp_playPostLayoutEntranceWithDelay:(NSTimeInterval)delay;
- (void)pp_startBackgroundMotionIfNeeded;
- (void)pp_stopBackgroundMotion;
@end
