//
//  PPVerifiedBadgeHelper.m
//  Pure Pets
//

#import "PPVerifiedBadgeHelper.h"

@implementation PPVerifiedBadgeHelper

+ (UIImageView *)addBadgeToAvatarView:(UIView *)avatarView
                          inSuperview:(UIView *)superview
                            badgeSize:(CGFloat)size {

    UIImageView *badge = [[UIImageView alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.image = [UIImage imageNamed:@"verify_icon_colored"];
    badge.contentMode = UIViewContentModeScaleAspectFit;
    badge.hidden = YES;

    // Thin system-background ring so the badge pops against any avatar
    badge.layer.cornerRadius = size / 2.0;
    badge.layer.borderWidth = 1.5;
    [badge pp_setBorderColor:UIColor.systemBackgroundColor];
    badge.clipsToBounds = YES;
    badge.backgroundColor = UIColor.systemBackgroundColor;

    [superview addSubview:badge];

    [NSLayoutConstraint activateConstraints:@[
        [badge.widthAnchor constraintEqualToConstant:size],
        [badge.heightAnchor constraintEqualToConstant:size],
        [badge.trailingAnchor constraintEqualToAnchor:avatarView.trailingAnchor constant:2],
        [badge.bottomAnchor constraintEqualToAnchor:avatarView.bottomAnchor constant:2],
    ]];

    return badge;
}

@end
