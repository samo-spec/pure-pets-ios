//
//  PPModernAvatarRenderer.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 4/7/26.
//


#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, PPModernAvatarStyle) {
    PPModernAvatarStyleGradient = 0,
    PPModernAvatarStyleGlass
};

@interface PPModernAvatarRenderer : NSObject

+ (UIImage *)avatarImageForName:(NSString *)displayName
                           size:(CGFloat)size;

+ (UIImage *)avatarImageForName:(NSString *)displayName
                           size:(CGFloat)size
                          style:(PPModernAvatarStyle)style;

+ (NSString *)initialsForDisplayName:(NSString *)displayName;

@end