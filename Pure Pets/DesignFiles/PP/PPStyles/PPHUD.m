//  PPHUD.m
#import "PPHUD.h"
 
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

static void _PP_applyFonts(JGProgressHUD *hud) {
    hud.textLabel.font   = [Styling fontBold:16];
    hud.detailTextLabel.font = [Styling fontMedium:13];
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
        if (!_pphud) {
            _pphud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleExtraLight];
            _pphud.interactionType = JGProgressHUDInteractionTypeBlockAllTouches;
        }
        _pphud.indicatorView = [JGProgressHUDIndeterminateIndicatorView new];
        _pphud.textLabel.text = title ?: kLang(@"Please wait...");
        _pphud.detailTextLabel.text = subtitle ?: @"";
        _PP_applyFonts(_pphud);
        
        if (!_pphud.visible) {
            [_pphud showInView:_PP_host(nil)];
        }
    });
}



+ (void)showIndeterminateIn:(UIView *)view title:(NSString *)title subtitle:(NSString *)subtitle {
    _PP_main(^{
        if (!_pphud) {
            _pphud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleExtraLight];
            _pphud.interactionType = JGProgressHUDInteractionTypeBlockAllTouches;
        }
        _pphud.indicatorView = [JGProgressHUDIndeterminateIndicatorView new];
        _pphud.textLabel.text = title ?: @"";
        _pphud.detailTextLabel.text = subtitle ?: @"";
        _PP_applyFonts(_pphud);
        if (!_pphud.visible || _pphud.targetView != _PP_host(view)) {
            [_pphud showInView:_PP_host(view)];
        }
    });
}

+ (void)showInfo:(NSString * _Nullable)title subtitle:(NSString * _Nullable)subtitle {
    _PP_main(^{
        if (!_pphud) {
            _pphud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleExtraLight];
            _pphud.interactionType = JGProgressHUDInteractionTypeBlockNoTouches;
        }
        
        // You can use an info icon here (custom image or predefined indicator)
        UIImage *infoImage = [UIImage systemImageNamed:@"info.circle"];
        if (infoImage) {
            _pphud.indicatorView = [[JGProgressHUDImageIndicatorView alloc] initWithImage:infoImage];
        } else {
            // fallback if SF Symbols not available
            _pphud.indicatorView = [JGProgressHUDSuccessIndicatorView new];
        }

        _pphud.textLabel.text = title ?: kLang(@"Information");
        _pphud.detailTextLabel.text = subtitle ?: @"";
        _PP_applyFonts(_pphud);
        
        // Optionally auto dismiss after few seconds
        [_pphud showInView:_PP_host(nil)];
        [_pphud dismissAfterDelay:2.0];
    });
}


+ (void)showInfo:(NSString * _Nullable)title{
    _PP_main(^{
        if (!_pphud) {
            _pphud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleExtraLight];
            _pphud.interactionType = JGProgressHUDInteractionTypeBlockNoTouches;
        }
        
        // You can use an info icon here (custom image or predefined indicator)
        UIImage *infoImage = [UIImage systemImageNamed:@"info.circle"];
        if (infoImage) {
            _pphud.indicatorView = [[JGProgressHUDImageIndicatorView alloc] initWithImage:infoImage];
        } else {
            // fallback if SF Symbols not available
            _pphud.indicatorView = [JGProgressHUDSuccessIndicatorView new];
        }
 
        _pphud.textLabel.text = title ?: kLang(@"Information");
        _pphud.detailTextLabel.text = nil ?: @"";
        _PP_applyFonts(_pphud);
        
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
        if (!_pphud) {
            _pphud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleExtraLight];
            _pphud.interactionType = JGProgressHUDInteractionTypeBlockAllTouches;
        }
        _pphud.indicatorView = [JGProgressHUDRingIndicatorView new];
        ((JGProgressHUDRingIndicatorView *)_pphud.indicatorView).progress = 0.0;
        _pphud.textLabel.text = title ?: @"";
        _pphud.detailTextLabel.text = subtitle ?: @"";
        
        _pphud.textLabel.font = [Styling fontMedium:16];
        _pphud.detailTextLabel.font = [Styling fontMedium:14];
        
        
        _PP_applyFonts(_pphud);
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
        if (!_pphud) _pphud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleExtraLight];
        _pphud.indicatorView = [JGProgressHUDSuccessIndicatorView new];
        _pphud.textLabel.text = title ?: @"";
        _pphud.detailTextLabel.text = subtitle ?: @"";
        
        _pphud.textLabel.font = [Styling fontMedium:16];
        _pphud.detailTextLabel.font = [Styling fontMedium:14];
        
        
        _PP_applyFonts(_pphud);
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
        if (!_pphud) _pphud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleExtraLight];
        _pphud.indicatorView = [JGProgressHUDErrorIndicatorView new];
        _pphud.textLabel.text = title ?: @"";
        _pphud.detailTextLabel.text = subtitle ?: @"";
        
        _pphud.textLabel.font = [Styling fontMedium:16];
        _pphud.detailTextLabel.font = [Styling fontMedium:14];
        
        
        _PP_applyFonts(_pphud);
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
