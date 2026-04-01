//
//  PPBottomBarManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/11/2025.
//


#import "PPBottomBarManager.h"
#import "PPBottomBar.h"

@implementation PPBottomBarManager {
    PPNewBottomBar *_bar;
}

+ (instancetype)shared {
    static PPBottomBarManager *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        m = [PPBottomBarManager new];
    });
    return m;
}

- (instancetype)init {
    
    self = [super init];
    if (!self) return nil;

    _bar = [[PPNewBottomBar alloc] init];
    //_bar.barBackStyle = BarBackStyleClear;
 
    
    if(PPIOS26())
    {
        [_bar configureTabBarItems:@[
            @{@"tag":@(PPBarTagHome),@"icon":@"homeCus", @"title":kLang(@"MainPage")}, //homeCus
            @{@"tag":@(PPBarTagChats), @"icon":@"notificationCus",  @"title":kLang(@"Notifications")} ,
            @{@"tag":@(PPBarTagOrdersHistory), @"icon":@"ordersCus",  @"title": kLang(@"Orders")},
        ]];
    }
    else
    {
        [_bar configureWithItems:@[
            @{@"tag":@(PPBarTagHome),@"icon":@"PPhouseCus", @"title":kLang(@"home")},
            
            @{@"tag":@(PPBarTagChats),
              @"icon":@"bell",
              @"title":kLang(@"Notifications")} ,
            @{@"tag":@(PPBarTagOrdersHistory),
              @"icon":@"clock",
              @"title": kLang(@"Orders")},
    ]];
    }
    
    
    
    
    return self;
}

/*
 _vc.bottomBar = [[PPNewBottomBar alloc] init];

 _vc.bottomBar.barBackStyle = BarBackStyleFade;
 _vc.bottomBar.blurBarViewHeight = 70;
 [_vc.bottomBar configureWithItems:@[
     @{@"icon":@"cart", @"title":kLang(@"Cart")},
     @{@"icon":@"bag", @"title": kLang(@"Orders")},
     @{@"icon":@"bubble.left.and.bubble.right", @"title":kLang(@"chatsTitle")},
     @{@"icon":@"bell", @"title":kLang(@"notificationsSetPalce")}
 ]];
 [_vc.view addSubview:_vc.bottomBar];
 
 [NSLayoutConstraint activateConstraints:@[
     [_vc.bottomBar.leadingAnchor constraintEqualToAnchor:_vc.view.leadingAnchor],
     [_vc.bottomBar.trailingAnchor constraintEqualToAnchor:_vc.view.trailingAnchor],
     [_vc.bottomBar.bottomAnchor constraintEqualToAnchor:_vc.view.safeAreaLayoutGuide.bottomAnchor constant:10],
     [_vc.bottomBar.heightAnchor constraintEqualToConstant:64]
 ]];
 
 */
- (PPNewBottomBar *)bar {
    return _bar;
}



- (void)attachToWindow {
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    if (!window) return;
    if (_bar.superview) { [_bar removeFromSuperview]; }

    [window addSubview:_bar];

    [NSLayoutConstraint activateConstraints:@[
        [_bar.leadingAnchor constraintEqualToAnchor:window.leadingAnchor constant:0],
        [_bar.trailingAnchor constraintEqualToAnchor:window.trailingAnchor],
        [_bar.bottomAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [_bar.heightAnchor constraintEqualToConstant: _bar.blurBarViewHeight]  // your size
    ]];
    
     if(PPMaxScreen)
     {
        // [_bar.tabBar setNeedsLayout];
        // [_bar.tabBar layoutSubviews];
        // [_bar.tabBar layoutIfNeeded];
     }
    
    
}

- (void)show { _bar.hidden = NO; }
- (void)hide { _bar.hidden = YES; }




- (NSLayoutYAxisAnchor *)topAnchor {
    return _bar.topAnchor;
}

- (CGFloat)barTopY {
    [_bar.superview layoutIfNeeded];   // ensure constraints resolved
    return CGRectGetMinY(_bar.frame);
}

- (CGFloat)barHeight {
    return CGRectGetHeight(_bar.frame);
}

@end
