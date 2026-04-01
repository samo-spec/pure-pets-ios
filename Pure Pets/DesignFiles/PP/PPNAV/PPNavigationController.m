#import "PPNavigationController.h"
//#import "BBNavigationBar.h"

//
// UIViewController+ModalBBNav.m
//

#import <objc/runtime.h>

#if __has_include("BBNavigationBar.h")
#import "BBNavigationBar.h"
#define PP_USE_BB_NAV 1
#else
#define PP_USE_BB_NAV 0
#endif

static char kModalNavBarKey;
static const CGFloat kPPModalNavBarHeight = 44.0;

@interface UIViewController ()
@property (nonatomic, strong) UIView *pp_modalNavigationBarView;
@end

@implementation UIViewController (ModalBBNav)

- (void)setPp_modalNavigationBarView:(UIView *)pp_modalNavigationBarView {
    objc_setAssociatedObject(self, &kModalNavBarKey, pp_modalNavigationBarView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIView *)pp_modalNavigationBarView {
    return objc_getAssociatedObject(self, &kModalNavBarKey);
}

- (void)ensureModalNavigationBarIfNeeded {
    // If embedded in a navigation controller, remove programmatic bar and return.
    if (self.navigationController) {
        [self removeModalNavigationBarIfNeeded];
        return;
    }
    
    if (!self.pp_modalNavigationBarView) {
#if PP_USE_BB_NAV
        //BBNavigationBar *bb = [[BBNavigationBar alloc] initWithFrame:CGRectZero];
        //bb.translatesAutoresizingMaskIntoConstraints = NO;
        //self.pp_modalNavigationBarView = bb;
#else
        UINavigationBar *bar = [[UINavigationBar alloc] initWithFrame:CGRectZero];
        bar.translatesAutoresizingMaskIntoConstraints = NO;
        bar.prefersLargeTitles = NO;
        self.pp_modalNavigationBarView = bar;
#endif
        
        PPNavigationBar *bar = [[PPNavigationBar alloc] initWithFrame:CGRectZero];
        bar.translatesAutoresizingMaskIntoConstraints = NO;
        bar.prefersLargeTitles = NO;
        self.pp_modalNavigationBarView = bar;
         
        //BBNavigationBar *bb = [[BBNavigationBar alloc] initWithFrame:CGRectZero];
        //bb.translatesAutoresizingMaskIntoConstraints = NO;
        //self.pp_modalNavigationBarView = bb;
        
        
        [self.view addSubview:self.pp_modalNavigationBarView];
        
        
        UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
        [NSLayoutConstraint activateConstraints:@[
            [self.pp_modalNavigationBarView.topAnchor constraintEqualToAnchor:safe.topAnchor],
            [self.pp_modalNavigationBarView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [self.pp_modalNavigationBarView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [self.pp_modalNavigationBarView.heightAnchor constraintEqualToConstant:kPPModalNavBarHeight]
        ]];
        
        UIEdgeInsets insets = self.additionalSafeAreaInsets;
        if (insets.top < kPPModalNavBarHeight) {
            insets.top += kPPModalNavBarHeight;
            self.additionalSafeAreaInsets = insets;
        }
        
        
    }
    
    [self updateModalNavigationBarItems];
    
    self.pp_modalNavigationBarView.hidden = NO;
    self.pp_modalNavigationBarView.alpha = 1.0;
}

- (void)removeModalNavigationBarIfNeeded {
    if (!self.pp_modalNavigationBarView) return;
    
    UIEdgeInsets insets = self.additionalSafeAreaInsets;
    if (insets.top >= kPPModalNavBarHeight) {
        insets.top -= kPPModalNavBarHeight;
        self.additionalSafeAreaInsets = insets;
    }
    
    [self.pp_modalNavigationBarView removeFromSuperview];
    self.pp_modalNavigationBarView = nil;
}

- (void)updateModalNavigationBarItems {
    if (!self.pp_modalNavigationBarView) return;
     // Try common APIs: setItems:animated: or setNavigationItem:
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:self.navigationItem.title ?: @""];
    item.leftBarButtonItem = self.navigationItem.leftBarButtonItem;
    item.rightBarButtonItem = self.navigationItem.rightBarButtonItem;
    item.titleView = self.navigationItem.titleView;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    SEL setItemsSel = NSSelectorFromString(@"setItems:animated:");
    if ([self.pp_modalNavigationBarView respondsToSelector:setItemsSel]) {
        [self.pp_modalNavigationBarView performSelector:setItemsSel withObject:@[item] withObject:@(NO)];
        return;
    }
    SEL setNavItemSel = NSSelectorFromString(@"setNavigationItem:");
    if ([self.pp_modalNavigationBarView respondsToSelector:setNavItemSel]) {
        [self.pp_modalNavigationBarView performSelector:setNavItemSel withObject:item];
        return;
    }
#pragma clang diagnostic pop
    
    
    // If no compatible API, attempt to set title via KVC
    @try {
        if ([self.pp_modalNavigationBarView respondsToSelector:NSSelectorFromString(@"setTitle:")]) {
            
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self.pp_modalNavigationBarView performSelector:NSSelectorFromString(@"setTitle:") withObject:self.navigationItem.title ?: @""];
#pragma clang diagnostic pop
        }
    } @catch (NSException *ex) { }
 
}

@end


@implementation PPNavBarContainer

-(CGSize)intrinsicContentSize
{
    return UILayoutFittingExpandedSize; // Let it size to content
    
}

// WHY: Allow taps to pass through to UINavigationBar's own subviews (UIBarButtonItems)
// unless the touch is inside one of our interactive subviews.
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.isHidden || self.alpha < 0.01) { return NO; }
    for (UIView *v in self.subviews) {
        if (v.hidden || v.alpha < 0.01 || !v.userInteractionEnabled) { continue; }
        // Convert the point into the subview’s coordinate space
        CGPoint pInSub = [v convertPoint:point fromView:self];
        if ([v pointInside:pInSub withEvent:event]) {
            return YES;
        }
    }
    // Pass through anywhere that doesn't hit our subviews
    return NO;
}

@end


@implementation PPNavigationBar

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize s = [super sizeThatFits:size];
    s.height = 70; // your custom height
    return s;
}

@end



@implementation PPNavigationController

-(instancetype)initWithRootViewController:(UIViewController *)rootViewController
{
    self = [super initWithNavigationBarClass:[PPNavigationBar class]
                                toolbarClass:nil];
    if (self) {
        [self setViewControllers:@[rootViewController] animated:NO];
    }
    return self;
}


// ✅ Never let system override based on background
- (UIViewController *)childViewControllerForStatusBarStyle {
    return nil; // disables per-VC style handoff
}



- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationBar.translucent = YES;
    self.navigationBar.barStyle = UIBarStyleDefault;
    self.navigationBar.tintColor = UIColor.clearColor;
    self.navigationBar.backgroundColor = UIColor.clearColor;
    
    if (@available(iOS 15.0, *)) {
        UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
        [appearance configureWithTransparentBackground];
        appearance.backgroundColor = UIColor.clearColor;
        appearance.shadowColor = UIColor.clearColor;
        appearance.titleTextAttributes = @{
            NSForegroundColorAttributeName: AppPrimaryTextClr,
            NSFontAttributeName: [GM boldFontWithSize:18]
        };
        appearance.largeTitleTextAttributes = @{ NSForegroundColorAttributeName: UIColor.blackColor };
        
        self.navigationBar.standardAppearance = appearance;
        self.navigationBar.scrollEdgeAppearance = appearance;
        self.navigationBar.compactAppearance = appearance;
        self.navigationBar.prefersLargeTitles = NO;
        
        NSDictionary *titleAttributes = @{
            NSForegroundColorAttributeName: [UIColor labelColor],
            // title color
            NSFontAttributeName: [GM boldFontWithSize:18]  // title font
        };
        [[UINavigationBar appearance] setTitleTextAttributes:titleAttributes];
    }
    self.interactivePopGestureRecognizer.enabled = YES;
    self.interactivePopGestureRecognizer.delegate = (id<UIGestureRecognizerDelegate>)self;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    return self.viewControllers.count > 1;
}

// ✅ Prevent iOS from “borrowing” appearance from pushed VC
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    
    self.navigationBar.tintColor = UIColor.blackColor; // reset before transition
    [super pushViewController:viewController animated:animated];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    
    UIViewController *vc = [super popViewControllerAnimated:animated];
    // ensure style restored after pop
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.navigationBar.tintColor = UIColor.blackColor;
    });
    return vc;
}

@end


@implementation PPBarItemWrapper
- (CGSize)intrinsicContentSize {
    return UILayoutFittingExpandedSize; // Let it size to content
}
@end





















#import <objc/runtime.h>

static char kModalNavBarKey;

@interface UIViewController ()
@property (nonatomic, strong) UINavigationBar *pp_modalNavigationBar;
@end

@implementation UIViewController (ModalNav)

#pragma mark - associated property

- (void)setPp_modalNavigationBar:(UINavigationBar *)bar {
    objc_setAssociatedObject(self, &kModalNavBarKey, bar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UINavigationBar *)pp_modalNavigationBar {
    return objc_getAssociatedObject(self, &kModalNavBarKey);
}

#pragma mark - public

- (void)ensureModalNavigationBarIfNeeded {
    // If already inside a navigation controller, nothing to do.
    if (self.navigationController) {
        [self removeModalNavigationBarIfNeeded];
        return;
    }
    
    // If bar exists, update it.
    if (self.pp_modalNavigationBar) {
        [self updateModalNavigationBarFromNavigationItem];
        return;
    }
    
    // Create bar
    UINavigationBar *bar = [[UINavigationBar alloc] initWithFrame:CGRectZero];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    // Use system appearance for iOS 13+; caller can style bar after creation if needed.
    if (@available(iOS 13.0, *)) {
        // adopt default system background to behave like nav bars in sheets
        bar.backgroundColor = UIColor.systemBackgroundColor;
    }
    
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:self.navigationItem.title ? : @""];
    // copy items if present
    item.leftBarButtonItem = self.navigationItem.leftBarButtonItem;
    item.rightBarButtonItem = self.navigationItem.rightBarButtonItem;
    item.titleView = self.navigationItem.titleView;
    item.largeTitleDisplayMode = self.navigationItem.largeTitleDisplayMode;
    
    [bar setItems:@[item] animated:NO];
    
    [self.view addSubview:bar];
    self.pp_modalNavigationBar = bar;
    
    // Constraints: pin to safeArea top, leading, trailing. Height = standard nav bar height (44) + status/safe area handled by safeArea.
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [bar.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [bar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [bar.heightAnchor constraintEqualToConstant:44.0]
    ]];
    
    // Ensure content doesn't go under bar: adjust additionalSafeAreaInsets.top
    CGFloat insetTop = 44.0;
    UIEdgeInsets currentInsets = self.additionalSafeAreaInsets;
    // only adjust if not already increased (to avoid stacking)
    if (currentInsets.top < insetTop) {
        currentInsets.top += insetTop;
        self.additionalSafeAreaInsets = currentInsets;
    }
    
    // allow further customization by caller if needed
}

- (void)removeModalNavigationBarIfNeeded {
    if (!self.pp_modalNavigationBar) return;
    
    // restore safe area insets
    CGFloat insetTop = 44.0;
    UIEdgeInsets currentInsets = self.additionalSafeAreaInsets;
    if (currentInsets.top >= insetTop) {
        currentInsets.top -= insetTop;
        self.additionalSafeAreaInsets = currentInsets;
    }
    
    [self.pp_modalNavigationBar removeFromSuperview];
    self.pp_modalNavigationBar = nil;
}

#pragma mark - helper

- (void)updateModalNavigationBarFromNavigationItem {
    if (!self.pp_modalNavigationBar) return;
    
    // get existing nav item or create new one
    UINavigationItem *item = self.pp_modalNavigationBar.items.firstObject;
    if (!item) {
        item = [[UINavigationItem alloc] initWithTitle:self.navigationItem.title ? : @""];
        [self.pp_modalNavigationBar setItems:@[item] animated:NO];
    }
    
    item.title = self.navigationItem.title ? : @"";
    item.leftBarButtonItem = self.navigationItem.leftBarButtonItem;
    item.rightBarButtonItem = self.navigationItem.rightBarButtonItem;
    item.titleView = self.navigationItem.titleView;
    item.largeTitleDisplayMode = self.navigationItem.largeTitleDisplayMode;
}

@end












@interface PPFadeAnimator ()
@property (nonatomic, assign) BOOL presenting;
@end

@implementation PPFadeAnimator

- (instancetype)initWithPresenting:(BOOL)presenting {
    self = [super init];
    if (self) {
        _presenting = presenting;
        _duration = 0.28;
        _crossfadeContents = YES;
    }
    return self;
}

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return _duration;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    UIViewController *fromVC = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toVC   = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIView *container = [transitionContext containerView];
    
    UIView *toView = [transitionContext viewForKey:UITransitionContextToViewKey] ?: toVC.view;
    UIView *fromView = [transitionContext viewForKey:UITransitionContextFromViewKey] ?: fromVC.view;
    
    BOOL presenting = self.presenting;
    
    if (presenting) {
        toView.frame = [transitionContext finalFrameForViewController:toVC];
        toView.alpha = 0.0;
        toView.transform = CGAffineTransformMakeScale(1.02, 1.02);
        [container addSubview:toView];
    } else {
        toView.frame = [transitionContext finalFrameForViewController:toVC];
        if (toView.superview != container) {
            [container insertSubview:toView belowSubview:fromView];
        }
    }
    
    NSTimeInterval duration = [self transitionDuration:transitionContext];
    
    [UIView animateWithDuration:duration
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        if (presenting) {
            toView.alpha = 1.0;
            toView.transform = CGAffineTransformIdentity;
            fromView.alpha = 0.92;
        } else {
            fromView.alpha = 0.0;
            fromView.transform = CGAffineTransformMakeScale(0.98, 0.98);
            toView.alpha = 1.0;
            toView.transform = CGAffineTransformIdentity;
        }
    } completion:^(BOOL finished) {
        fromView.alpha = 1.0;
        fromView.transform = CGAffineTransformIdentity;
        toView.transform = CGAffineTransformIdentity;
        
        BOOL cancelled = [transitionContext transitionWasCancelled];
        if (cancelled) {
            if (presenting && toView.superview == container) {
                [toView removeFromSuperview];
            }
        }
        [transitionContext completeTransition:!cancelled];
        
        
    }];
}

@end
















//
// PPNavigationFadeDelegate.m
//

@implementation PPNavigationFadeDelegate

+ (instancetype)sharedInstance {
    static PPNavigationFadeDelegate *g;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g = [[PPNavigationFadeDelegate alloc] init];
        g.animationDuration = 0.28;
        g.enableTabFade = NO; // default NO (safe)
        // g.allowedClasses = nil; // nil means "no whitelist" (don't auto-apply)
    });
    return g;
}

- (void)setFadeAllowedForViewControllerClasses:(NSArray<Class> * _Nullable)classes {
    if (!classes) {
        self.allowedClasses = nil;
    } else {
        self.allowedClasses = [NSSet setWithArray:classes];
    }
}

- (BOOL)shouldApplyFadeForFromVC:(UIViewController *)fromVC toVC:(UIViewController *)toVC {
    // If no whitelist specified, do NOT auto-apply
    if (!self.allowedClasses || self.allowedClasses.count == 0) return NO;

    for (Class cls in self.allowedClasses) {
        if ([fromVC isKindOfClass:cls] || [toVC isKindOfClass:cls]) return YES;
    }
    return NO;
}

#pragma mark - UINavigationControllerDelegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                  animationControllerForOperation:(UINavigationControllerOperation)operation
                                               fromViewController:(UIViewController *)fromVC
                                                 toViewController:(UIViewController *)toVC {

    // 1) Check explicit per-target instance style first
    PPTransitionStyle toStyle = toVC.pp_transitionStyle;
    PPTransitionStyle fromStyle = fromVC.pp_transitionStyle;

    PPTransitionStyle chosen = PPTransitionStyleNone;
    if (toStyle != PPTransitionStyleNone) chosen = toStyle;
    else if (fromStyle != PPTransitionStyleNone) chosen = fromStyle;
    else {
        // 2) fallback to class whitelist only if provided
        if ( [self shouldApplyFadeForFromVC:fromVC toVC:toVC] ) {
            chosen = PPTransitionStyleFade;
        } else {
            // No explicit request and no whitelist → no custom animator
            return nil;
        }
    }

    // 3) create animator based on chosen style and operation
    switch (chosen) {
        case PPTransitionStyleFade: {
            BOOL presenting = (operation == UINavigationControllerOperationPush);
            PPFadeAnimator *anim = [[PPFadeAnimator alloc] initWithPresenting:presenting];
            anim.duration = self.animationDuration;
            return anim;
        }
        case PPTransitionStyleCustom: {
            // return custom animator if you implement other styles
            return nil;
        }
        default:
            return nil;
    }
}

#pragma mark - UITabBarControllerDelegate

- (id<UIViewControllerAnimatedTransitioning>)tabBarController:(UITabBarController *)tabBarController
           animationControllerForTransitionFromViewController:(UIViewController *)fromVC
                                             toViewController:(UIViewController *)toVC {
    // Tab fade controlled similarly: look for explicit per-instance style first
    PPTransitionStyle toStyle = toVC.pp_transitionStyle;
    PPTransitionStyle fromStyle = fromVC.pp_transitionStyle;

    if (toStyle != PPTransitionStyleNone || fromStyle != PPTransitionStyleNone) {
        PPTransitionStyle chosen = (toStyle != PPTransitionStyleNone) ? toStyle : fromStyle;
        if (chosen == PPTransitionStyleFade && self.enableTabFade) {
            PPFadeAnimator *anim = [[PPFadeAnimator alloc] initWithPresenting:YES];
            anim.duration = self.animationDuration;
            return anim;
        }
        return nil;
    }

    // Otherwise, only apply tab fade if whitelist present and enableTabFade is ON
    if (self.enableTabFade && [self shouldApplyFadeForFromVC:fromVC toVC:toVC]) {
        PPFadeAnimator *anim = [[PPFadeAnimator alloc] initWithPresenting:YES];
        anim.duration = self.animationDuration;
        return anim;
    }

    return nil;
}

@end














#import <objc/runtime.h>

static void *kPPTransitionStyleKey = &kPPTransitionStyleKey;

@implementation UIViewController (PPTransition)

- (void)setPp_transitionStyle:(PPTransitionStyle)pp_transitionStyle {
    NSNumber *num = @(pp_transitionStyle);
    objc_setAssociatedObject(self,
                             kPPTransitionStyleKey,
                             num,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (PPTransitionStyle)pp_transitionStyle {
    NSNumber *num = objc_getAssociatedObject(self, kPPTransitionStyleKey);
    if (num) return (PPTransitionStyle)num.integerValue;

    // If the class explicitly conforms to the PPTransitioning protocol and implements the method,
    // call that implementation. This avoids self-recursion because categories don't claim conformance.
    if ([self conformsToProtocol:@protocol(PPTransitioning)] &&
        [(id<PPTransitioning>)self respondsToSelector:@selector(pp_transitionStyle)]) {
        return [(id<PPTransitioning>)self pp_transitionStyle];
    }

    return PPTransitionStyleNone;
}

@end














 

@interface UIBarButtonItem (BadgePrivate)
@property (copy, nonatomic) NSString *pp_pendingBadgeValue;
- (UIView *)pp_badgeContainerView;
- (void)pp_retryPendingBadgeIfNeeded;
@end

@implementation UIBarButtonItem (Badge)

#pragma mark - Runtime storage
- (void)setPp_badgeLabel:(UILabel *)pp_badgeLabel {
    objc_setAssociatedObject(self, @selector(pp_badgeLabel), pp_badgeLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UILabel *)pp_badgeLabel {
    return objc_getAssociatedObject(self, @selector(pp_badgeLabel));
}

- (void)setPp_pendingBadgeValue:(NSString *)pp_pendingBadgeValue {
    objc_setAssociatedObject(self, @selector(pp_pendingBadgeValue), pp_pendingBadgeValue, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)pp_pendingBadgeValue {
    return objc_getAssociatedObject(self, @selector(pp_pendingBadgeValue));
}

- (UIView *)pp_badgeContainerView {
    if (self.customView) {
        return self.customView;
    }

    @try {
        id resolvedView = [self valueForKey:@"view"];
        return [resolvedView isKindOfClass:[UIView class]] ? (UIView *)resolvedView : nil;
    } @catch (NSException *exception) {
        return nil;
    }
}

- (void)pp_retryPendingBadgeIfNeeded {
    NSString *pendingValue = self.pp_pendingBadgeValue;
    if (pendingValue.length == 0) {
        return;
    }

    UIView *containerView = [self pp_badgeContainerView];
    if (!containerView) {
        return;
    }

    self.pp_pendingBadgeValue = nil;
    [self pp_setBadgeValue:pendingValue];
}

#pragma mark - Public
- (void)pp_setBadgeValue:(NSString *)value {
    if (!value || value.length == 0 || [value isEqualToString:@"0"]) {
        [self pp_removeBadge];
        return;
    }

    UIView *containerView = [self pp_badgeContainerView];
    if (!containerView) {
        self.pp_pendingBadgeValue = value;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_retryPendingBadgeIfNeeded];
        });
        return;
    }

    if (!self.pp_badgeLabel || self.pp_badgeLabel.superview != containerView) {
        [self.pp_badgeLabel removeFromSuperview];

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.backgroundColor = UIColor.systemRedColor;
        label.textColor = UIColor.whiteColor;
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [GM MidFontWithSize:12];
        label.layer.cornerRadius = 9;
        label.clipsToBounds = YES;
        label.translatesAutoresizingMaskIntoConstraints = NO;

        self.pp_badgeLabel = label;

        [containerView addSubview:label];

        // Pin in the top-trailing corner once the bar button has a real view.
        [NSLayoutConstraint activateConstraints:@[
            [label.heightAnchor constraintEqualToConstant:18],
            [label.widthAnchor constraintGreaterThanOrEqualToConstant:18],
            [label.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:1],
            [label.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:2]
        ]];
    }

    self.pp_badgeLabel.text = value;
    self.pp_pendingBadgeValue = nil;
}

- (void)pp_removeBadge {
    [self.pp_badgeLabel removeFromSuperview];
    self.pp_badgeLabel = nil;
    self.pp_pendingBadgeValue = nil;
}

@end






