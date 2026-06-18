//
//  PPNovaAmbientAssistantChatBridge.h
//  Pure Pets
//
//  Keeps Swift ambient UI decoupled from the existing Objective-C Nova chat.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PPNovaAmbientAssistantChatBridge : NSObject

+ (void)openFromViewController:(UIViewController *)viewController NS_SWIFT_NAME(open(from:));
+ (UIView *)makeAmbientLeadingView NS_SWIFT_NAME(makeAmbientLeadingView());
+ (UIButton *)makeAmbientGlassBackgroundButton NS_SWIFT_NAME(makeAmbientGlassBackgroundButton());

@end

NS_ASSUME_NONNULL_END
