//
//  PPHomeUltraPremuimPetCareCell.h
//  Pure Pets
//
//  Ultra-premium, motion-aware Pet Care entry card.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPHomeUltraPremuimPetCareCell : UICollectionViewCell

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

NS_ASSUME_NONNULL_END
