//  PPHUD.m
#import "PPHUD.h"
#import "PPFirebaseSessionBridge.h"
 
static JGProgressHUD *_pphud;

#pragma mark - Helpers

static void _PP_main(void (^block)(void)) {
    if (NSThread.isMainThread) { block(); }
    else { dispatch_async(dispatch_get_main_queue(), block); }
}

static UIView *_PP_host(UIView *preferred) {
    if (preferred) return preferred;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *w in scene.windows) if (w.isKeyWindow) return w;
                if (scene.windows.firstObject) return scene.windows.firstObject;
            }
        }
    }
    return UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.lastObject;
}

static NSString *_PP_publicHUDText(NSString *text, NSString *fallbackKey) {
    if (text.length == 0) return text;
    return [PPFirebaseSessionBridge publicMessageForText:text fallbackKey:fallbackKey] ?: text;
}

static BOOL _PP_isDarkHUD(UIView *preferredHost) {
    UIView *host = _PP_host(preferredHost);
    return host.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}

static JGProgressHUDStyle _PP_hudStyle(UIView *preferredHost) {
    return _PP_isDarkHUD(preferredHost) ? JGProgressHUDStyleDark : JGProgressHUDStyleExtraLight;
}

static UIColor *_PP_hudTitleColor(UIView *preferredHost) {
    return _PP_isDarkHUD(preferredHost)
        ? [UIColor colorWithWhite:1.0 alpha:0.96]
        : [UIColor colorWithWhite:0.06 alpha:1.0];
}

static UIColor *_PP_hudDetailColor(UIView *preferredHost) {
    return _PP_isDarkHUD(preferredHost)
        ? [UIColor colorWithWhite:1.0 alpha:0.74]
        : [UIColor colorWithWhite:0.24 alpha:1.0];
}

static UIColor *_PP_hudIndicatorColor(UIView *preferredHost) {
    return _PP_isDarkHUD(preferredHost)
        ? UIColor.whiteColor
        : (AppPrimaryClr ?: UIColor.systemOrangeColor);
}

static JGProgressHUD *_PP_prepareHUD(UIView *preferredHost, JGProgressHUDInteractionType interactionType) {
    JGProgressHUDStyle style = _PP_hudStyle(preferredHost);
    if (!_pphud) {
        _pphud = [JGProgressHUD progressHUDWithStyle:style];
    } else {
        _pphud.style = style;
    }
    _pphud.interactionType = interactionType;
    return _pphud;
}

static void _PP_applyAppearance(JGProgressHUD *hud, UIView *preferredHost) {
    if (!hud) return;

    hud.style = _PP_hudStyle(preferredHost);
    hud.textLabel.font = [Styling fontBold:16];
    hud.detailTextLabel.font = [Styling fontMedium:13];
    hud.textLabel.textColor = _PP_hudTitleColor(preferredHost);
    hud.detailTextLabel.textColor = _PP_hudDetailColor(preferredHost);

    UIColor *indicatorColor = _PP_hudIndicatorColor(preferredHost);
    if ([hud.indicatorView isKindOfClass:JGProgressHUDIndeterminateIndicatorView.class]) {
        [(JGProgressHUDIndeterminateIndicatorView *)hud.indicatorView setColor:indicatorColor];
    } else if ([hud.indicatorView isKindOfClass:JGProgressHUDRingIndicatorView.class]) {
        JGProgressHUDRingIndicatorView *ring = (JGProgressHUDRingIndicatorView *)hud.indicatorView;
        ring.ringColor = indicatorColor;
        ring.ringBackgroundColor = _PP_isDarkHUD(preferredHost)
            ? [UIColor colorWithWhite:1.0 alpha:0.18]
            : [indicatorColor colorWithAlphaComponent:0.16];
    }
}


@implementation PPHUD

+ (void)showLoading {
    [self showLoading:nil subtitle:nil];
}

+ (void)showLoading:(NSString * _Nullable)title {
    [self showLoading:title subtitle:nil];
}

+ (void)showLoading:(NSString * _Nullable)title subtitle:(NSString * _Nullable)subtitle {
    _PP_main(^{
        _PP_prepareHUD(nil, JGProgressHUDInteractionTypeBlockAllTouches);
        _pphud.indicatorView = [JGProgressHUDIndeterminateIndicatorView new];
        _pphud.textLabel.text = title ?: kLang(@"Please wait...");
        _pphud.detailTextLabel.text = subtitle ?: @"";
        _PP_applyAppearance(_pphud, nil);
        
        if (!_pphud.visible) {
            [_pphud showInView:_PP_host(nil)];
        }
    });
}



+ (void)showIndeterminateIn:(UIView *)view title:(NSString *)title subtitle:(NSString *)subtitle {
    _PP_main(^{
        _PP_prepareHUD(view, JGProgressHUDInteractionTypeBlockAllTouches);
        _pphud.indicatorView = [JGProgressHUDIndeterminateIndicatorView new];
        _pphud.textLabel.text = title ?: @"";
        _pphud.detailTextLabel.text = subtitle ?: @"";
        _PP_applyAppearance(_pphud, view);
        if (!_pphud.visible || _pphud.targetView != _PP_host(view)) {
            [_pphud showInView:_PP_host(view)];
        }
    });
}

+ (void)showInfo:(NSString * _Nullable)title subtitle:(NSString * _Nullable)subtitle {
    _PP_main(^{
        _PP_prepareHUD(nil, JGProgressHUDInteractionTypeBlockNoTouches);
        
        // You can use an info icon here (custom image or predefined indicator)
        UIImage *infoImage = [[UIImage systemImageNamed:@"info.circle"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        if (infoImage) {
            _pphud.indicatorView = [[JGProgressHUDImageIndicatorView alloc] initWithImage:infoImage];
        } else {
            // fallback if SF Symbols not available
            _pphud.indicatorView = [JGProgressHUDSuccessIndicatorView new];
        }

        _pphud.textLabel.text = title ?: kLang(@"Information");
        _pphud.detailTextLabel.text = subtitle ?: @"";
        _PP_applyAppearance(_pphud, nil);
        
        // Optionally auto dismiss after few seconds
        [_pphud showInView:_PP_host(nil)];
        [_pphud dismissAfterDelay:2.0];
    });
}


+ (void)showInfo:(NSString * _Nullable)title{
    _PP_main(^{
        _PP_prepareHUD(nil, JGProgressHUDInteractionTypeBlockNoTouches);
        
        // You can use an info icon here (custom image or predefined indicator)
        UIImage *infoImage = [[UIImage systemImageNamed:@"info.circle"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        if (infoImage) {
            _pphud.indicatorView = [[JGProgressHUDImageIndicatorView alloc] initWithImage:infoImage];
        } else {
            // fallback if SF Symbols not available
            _pphud.indicatorView = [JGProgressHUDSuccessIndicatorView new];
        }
 
        _pphud.textLabel.text = title ?: kLang(@"Information");
        _pphud.detailTextLabel.text = nil ?: @"";
        _PP_applyAppearance(_pphud, nil);
        
        // Optionally auto dismiss after few seconds
        [_pphud showInView:_PP_host(nil)];
        [_pphud dismissAfterDelay:2.0];
    });
}


+ (void)showRingIn:(UIView *)view title:(NSString *)title {
    [self showRingIn:view title:title subtitle:@""];
}


+ (void)showRingIn:(UIView *)view title:(NSString *)title subtitle:(NSString *)subtitle {
    _PP_main(^{
        _PP_prepareHUD(view, JGProgressHUDInteractionTypeBlockAllTouches);
        _pphud.indicatorView = [JGProgressHUDRingIndicatorView new];
        ((JGProgressHUDRingIndicatorView *)_pphud.indicatorView).progress = 0.0;
        _pphud.textLabel.text = title ?: @"";
        _pphud.detailTextLabel.text = subtitle ?: @"";
        
        _pphud.textLabel.font = [Styling fontMedium:16];
        _pphud.detailTextLabel.font = [Styling fontMedium:14];
        
        
        _PP_applyAppearance(_pphud, view);
        if (!_pphud.visible || _pphud.targetView != _PP_host(view)) {
            [_pphud showInView:_PP_host(view)];
        }
    });
}

+ (void)setProgress:(CGFloat)progress title:(NSString *)title {
    _PP_main(^{
        if (!_pphud) return;
        if ([_pphud.indicatorView isKindOfClass:[JGProgressHUDRingIndicatorView class]]) {
            JGProgressHUDRingIndicatorView *ring = (JGProgressHUDRingIndicatorView *)_pphud.indicatorView;
            ring.progress = MAX(0.0, MIN(1.0, progress));
        }
        if (title) _pphud.textLabel.text = title;
    });
}

+ (void)showSuccess:(NSString *)title
{
    [self showSuccess:title subtitle:@"" delay:0.9];
}
+ (void)showSuccess:(NSString *)title subtitle:(NSString *)subtitle {
    [self showSuccess:title subtitle:subtitle delay:1.9];
}
+ (void)showSuccess:(NSString *)title subtitle:(NSString *)subtitle delay:(NSTimeInterval)delay {
    _PP_main(^{
        _PP_prepareHUD(nil, JGProgressHUDInteractionTypeBlockNoTouches);
        _pphud.indicatorView = [JGProgressHUDSuccessIndicatorView new];
        _pphud.textLabel.text = title ?: @"";
        _pphud.detailTextLabel.text = subtitle ?: @"";
        
        _pphud.textLabel.font = [Styling fontMedium:16];
        _pphud.detailTextLabel.font = [Styling fontMedium:14];
        
        
        _PP_applyAppearance(_pphud, nil);
        if (!_pphud.visible) [_pphud showInView:_PP_host(nil)];
        [_pphud dismissAfterDelay:delay > 0 ? delay : 0.9];
        _pphud = nil;
    });
}

+ (void)showError:(NSString *)title{
    [self showError:title subtitle:@"" delay:1.4];
}


+ (void)showError:(NSString *)title subtitle:(NSString *)subtitle {
    [self showError:title subtitle:subtitle delay:1.4];
}
+ (void)showError:(NSString *)title subtitle:(NSString *)subtitle delay:(NSTimeInterval)delay {
    _PP_main(^{
        _PP_prepareHUD(nil, JGProgressHUDInteractionTypeBlockNoTouches);
        _pphud.indicatorView = [JGProgressHUDErrorIndicatorView new];
        _pphud.textLabel.text = _PP_publicHUDText(title, @"SomethingWentWrong") ?: @"";
        _pphud.detailTextLabel.text = _PP_publicHUDText(subtitle, @"SomethingWentWrong") ?: @"";
        
        _pphud.textLabel.font = [Styling fontMedium:16];
        _pphud.detailTextLabel.font = [Styling fontMedium:14];
        
        
        _PP_applyAppearance(_pphud, nil);
        if (!_pphud.visible) [_pphud showInView:_PP_host(nil)];
        [_pphud dismissAfterDelay:delay > 0 ? delay : 1.4];
        _pphud = nil;
    });
}

+ (void)dismiss {
    _PP_main(^{
        if (_pphud) {
            [_pphud dismiss];
            _pphud = nil;
        }
    });
}

+ (BOOL)isVisible {
    __block BOOL vis = NO;
    _PP_main(^{ vis = _pphud && _pphud.visible; });
    return vis;
}

@end
