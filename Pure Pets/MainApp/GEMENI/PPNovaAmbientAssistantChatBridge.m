//
//  PPNovaAmbientAssistantChatBridge.m
//  Pure Pets
//

#import "PPNovaAmbientAssistantChatBridge.h"
#import "AppClasses.h"
#import "PPNovaChatViewController.h"

#if __has_include(<Lottie/Lottie.h>)
#import <Lottie/Lottie.h>
#define PP_NOVA_AMBIENT_HAS_LOTTIE 1
#elif __has_include("Lottie.h")
#import "Lottie.h"
#define PP_NOVA_AMBIENT_HAS_LOTTIE 1
#elif __has_include(<lottie-ios_Oc/Lottie.h>)
#import <lottie-ios_Oc/Lottie.h>
#define PP_NOVA_AMBIENT_HAS_LOTTIE 1
#elif __has_include(<lottie_ios_Oc/Lottie.h>)
#import <lottie_ios_Oc/Lottie.h>
#define PP_NOVA_AMBIENT_HAS_LOTTIE 1
#else
#define PP_NOVA_AMBIENT_HAS_LOTTIE 0
#endif

@implementation PPNovaAmbientAssistantChatBridge

+ (void)openFromViewController:(UIViewController *)viewController
{
    if (!viewController) {
        return;
    }
    [PPNovaChatViewController presentNovaFromViewController:viewController];
}

+ (UIButton *)makeAmbientGlassBackgroundButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.userInteractionEnabled = NO;
    button.backgroundColor = UIColor.clearColor;
    button.tintColor = UIColor.clearColor;
    button.clipsToBounds = YES;

    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration glassButtonConfiguration];
        configuration.background.backgroundColor = UIColor.clearColor;
        configuration.baseBackgroundColor = UIColor.clearColor;
        configuration.baseForegroundColor = UIColor.clearColor;
        configuration.contentInsets = NSDirectionalEdgeInsetsZero;
        button.configuration = configuration;
    }

    return [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleCapsule];
}

+ (UIView *)makeAmbientLeadingView
{
    UIView *containerView = [[UIView alloc] initWithFrame:CGRectZero];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    containerView.userInteractionEnabled = NO;
    containerView.clipsToBounds = NO;

    UIImageSymbolConfiguration *fallbackConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                        weight:UIImageSymbolWeightSemibold];
    UIImageView *fallbackIconView =
        [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sparkles"
                                                   withConfiguration:fallbackConfiguration]];
    fallbackIconView.translatesAutoresizingMaskIntoConstraints = NO;
    fallbackIconView.contentMode = UIViewContentModeScaleAspectFit;
    fallbackIconView.tintColor = [UIColor colorNamed:@"AppPrimaryColor"] ?: UIColor.systemTealColor;
    fallbackIconView.userInteractionEnabled = NO;
    [containerView addSubview:fallbackIconView];

    [NSLayoutConstraint activateConstraints:@[
        [fallbackIconView.centerXAnchor constraintEqualToAnchor:containerView.centerXAnchor],
        [fallbackIconView.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],
        [fallbackIconView.widthAnchor constraintEqualToConstant:20.0],
        [fallbackIconView.heightAnchor constraintEqualToConstant:20.0]
    ]];

#if PP_NOVA_AMBIENT_HAS_LOTTIE
    LOTAnimationView *animationView = [[LOTAnimationView alloc] init];
    animationView.translatesAutoresizingMaskIntoConstraints = NO;
    animationView.userInteractionEnabled = NO;
    animationView.contentMode = UIViewContentModeScaleAspectFit;
    animationView.loopAnimation = YES;
    animationView.animationSpeed = 0.6;
    animationView.hidden = YES;
    [containerView addSubview:animationView];

    [NSLayoutConstraint activateConstraints:@[
        [animationView.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [animationView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [animationView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [animationView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor]
    ]];

    __weak LOTAnimationView *weakAnimationView = animationView;
    __weak UIImageView *weakFallbackIconView = fallbackIconView;
    [AppClasses setAnimationNamed:@"Ncolored"
                            ToView:animationView
                         withSpeed:0.6
                        completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LOTAnimationView *strongAnimationView = weakAnimationView;
            UIImageView *strongFallbackIconView = weakFallbackIconView;
            if (!strongAnimationView || !strongFallbackIconView) {
                return;
            }
            strongAnimationView.hidden = !success;
            strongFallbackIconView.hidden = success;
            if (success) {
                [strongAnimationView play];
            }
        });
    }];
#endif

    return containerView;
}

@end
