//
//  PPVerifiedBadgeHelper.h
//  Pure Pets
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Lightweight helper that creates and positions a verification badge
/// overlay on the bottom-trailing corner of any avatar view.
@interface PPVerifiedBadgeHelper : NSObject

/// Creates a verified badge and pins it to the bottom-trailing corner of avatarView.
/// The badge is added to superview (so it can overflow the avatar clipping bounds).
/// Returns the badge UIImageView (hidden by default - caller toggles .hidden).
+ (UIImageView *)addBadgeToAvatarView:(UIView *)avatarView
                          inSuperview:(UIView *)superview
                            badgeSize:(CGFloat)size;

@end

NS_ASSUME_NONNULL_END
