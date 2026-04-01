//
//  DonePopupView.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 10/07/2025.
//


#import "DonePopupView.h"


@implementation DonePopupView


- (instancetype)initWithMessage:(NSString *)message showAsBottomSheet:(BOOL)bottomSheet onView:(UIView *)view {
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        self.showAsBottomSheet = bottomSheet;
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];

        CGFloat containerWidth = self.bounds.size.width - 0;
        CGFloat containerHeight = 350;
        CGFloat x = 0;
        CGFloat y = view.hx_h - containerHeight;

        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(x, y, containerWidth, containerHeight)];
        container.backgroundColor = GM.AppForegroundColor;
        container.layer.cornerRadius = 25;
        container.clipsToBounds = YES;
        [view addSubview:container];

        self.checkAnimationView = [[LOTAnimationView alloc] init]; //[LOTAnimationView animationNamed:@"checkAnimation"];
        self.checkAnimationView.frame = CGRectMake(0, 0, containerWidth -0, 200);
        self.checkAnimationView.contentMode = UIViewContentModeScaleAspectFit;

        CGFloat originalDuration = self.checkAnimationView.animationDuration;
        CGFloat desiredDuration = 2.0;
        self.checkAnimationView.animationSpeed = originalDuration / desiredDuration;
        
        [AppClasses fetchLottieJSONFromFirebasePath:@"LottieAnimations/checkAnimation.json" completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    NSLog(@"Lottie ADS --- >>> ❌ Failed to fetch Lottie JSON: %@", error.localizedDescription);
                    return;
                }
                if (!jsonDict || ![jsonDict isKindOfClass:[NSDictionary class]]) {
                    NSLog(@"Lottie ADS --- >>> ❌ Invalid or nil JSON dictionary for Lottie");
                    return;
                }
                LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
                if (composition) {
                    [self.checkAnimationView setSceneModel:composition];
                    [self.checkAnimationView playToProgress:0.6 withCompletion:nil];
                } else {
                    NSLog(@"Lottie --- >>> ❌ Failed to create LOTComposition from JSON");
                }
            });
        }];
        
        
        

        [container addSubview:self.checkAnimationView];

        self.messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 150, containerWidth - 20, 40)];
        self.messageLabel.text = message;
        self.messageLabel.textAlignment = NSTextAlignmentCenter;
        self.messageLabel.font = [GM fontWithSize:18];
        self.messageLabel.numberOfLines = 0;
        [container addSubview:self.messageLabel];

        self.doneButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.doneButton.frame = CGRectMake(view.hx_w - 100 / 2, view.hx_y - 40 - [GM bottomPadding], 100, 40);
        [self.doneButton setTitle:kLang(@"done") forState:UIControlStateNormal];
        self.doneButton.titleLabel.font = [GM fontWithSize:18];
        self.doneButton.backgroundColor = GM.appPrimaryColor;
        [self.doneButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        self.doneButton.layer.cornerRadius = self.doneButton.hx_h / 2;
        [self.doneButton addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
        [container addSubview:self.doneButton];
    }
    return self;
}


- (instancetype)initWithMessage:(NSString *)message {
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];

        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 260, 280)];
        container.center = self.center;
        container.backgroundColor = GM.AppForegroundColor;
        container.layer.cornerRadius = 20;
        container.clipsToBounds = YES;
        [self addSubview:container];

        // Lottie check animation
        self.checkAnimationView = [[LOTAnimationView alloc] init]; //[LOTAnimationView animationNamed:@"checkAnimation"];
        self.checkAnimationView.frame = CGRectMake(30, 0, 200, 200);
        self.checkAnimationView.contentMode = UIViewContentModeScaleAspectFit;
        
        // Get original duration
        CGFloat originalDuration = self.checkAnimationView.animationDuration;

        // Desired duration in seconds
        CGFloat desiredDuration = 2.0;

        // Calculate speed factor
        self.checkAnimationView.animationSpeed = originalDuration / desiredDuration;

        [container addSubview:self.checkAnimationView];
       // [self.checkAnimationView playWithCompletion:nil];
        [AppClasses fetchLottieJSONFromFirebasePath:@"LottieAnimations/checkAnimation.json" completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    NSLog(@"Lottie ADS --- >>> ❌ Failed to fetch Lottie JSON: %@", error.localizedDescription);
                    return;
                }
                if (!jsonDict || ![jsonDict isKindOfClass:[NSDictionary class]]) {
                    NSLog(@"Lottie ADS --- >>> ❌ Invalid or nil JSON dictionary for Lottie");
                    return;
                }
                LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
                if (composition) {
                    [self.checkAnimationView setSceneModel:composition];
                    [self.checkAnimationView playToProgress:0.6 withCompletion:nil];
                } else {
                    NSLog(@"Lottie --- >>> ❌ Failed to create LOTComposition from JSON");
                }
            });
        }];
        // Label below animation
        self.messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 150, 240, 40)];
        self.messageLabel.text = message;
        self.messageLabel.textAlignment = NSTextAlignmentCenter;
        self.messageLabel.font = [UIFont boldSystemFontOfSize:17];
        self.messageLabel.numberOfLines = 0;
        [container addSubview:self.messageLabel];

        // Done button
        self.doneButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.doneButton.frame = CGRectMake(50, 210, 160, 44);
        [self.doneButton setTitle:@"تم" forState:UIControlStateNormal];
        self.doneButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        self.doneButton.backgroundColor = GM.appPrimaryColor;
        [self.doneButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        self.doneButton.layer.cornerRadius = 10;
        [self.doneButton addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
        [container addSubview:self.doneButton];
    }
    return self;
}

- (void)showInView:(UIView *)parentView {
    self.alpha = 0;
    [parentView addSubview:self];
    [UIView animateWithDuration:0.25 animations:^{
        self.alpha = 1.0;
    }];
}

- (void)dismiss {
    [UIView animateWithDuration:0.25 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end
