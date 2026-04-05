//
//  PPFirestoreErrorNotifier.m
//  Pure Pets
//
//  Centralized Firestore error surfacing utility.
//

#import "PPFirestoreErrorNotifier.h"

#pragma mark - Notification & Context Constants

NSNotificationName const PPFirestoreErrorOccurredNotification = @"PPFirestoreErrorOccurred";

NSString *const PPFirestoreContextCartPricingFetch           = @"cart_pricing_fetch";
NSString *const PPFirestoreContextCartItemSync               = @"cart_item_sync";
NSString *const PPFirestoreContextCartBatchSync              = @"cart_batch_sync";
NSString *const PPFirestoreContextCartListener               = @"cart_listener";
NSString *const PPFirestoreContextCartQuantityUpdate          = @"cart_quantity_update";
NSString *const PPFirestoreContextCartDeleteQuery             = @"cart_delete_query";
NSString *const PPFirestoreContextCartDeleteItem              = @"cart_delete_item";
NSString *const PPFirestoreContextPaymentInstrumentListener   = @"payment_instrument_listener";
NSString *const PPFirestoreContextPaymentInstrumentFetch      = @"payment_instrument_fetch";
NSString *const PPFirestoreContextPaymentInstrumentAdd        = @"payment_instrument_add";
NSString *const PPFirestoreContextPaymentInstrumentSetDefault = @"payment_instrument_set_default";
NSString *const PPFirestoreContextPaymentInstrumentDefaultBatch = @"payment_instrument_default_batch";
NSString *const PPFirestoreContextPaymentInstrumentDelete     = @"payment_instrument_delete";
NSString *const PPFirestoreContextAccessoryFetch              = @"accessory_fetch";
NSString *const PPFirestoreContextAccessorySimilar            = @"accessory_similar";
NSString *const PPFirestoreContextAccessoryKindFetch          = @"accessory_kind_fetch";
NSString *const PPFirestoreContextAccessorySearch             = @"accessory_search";
NSString *const PPFirestoreContextAccessoryOffers             = @"accessory_offers";

#pragma mark - Rate Limiter

/// Minimum interval (seconds) between consecutive banners to avoid spamming the user.
static NSTimeInterval const kPPErrorBannerMinInterval = 5.0;

/// Tracks the last time a banner was shown.
static NSDate *_pp_lastBannerDate = nil;

/// Currently visible banner (if any) — used to prevent stacking.
static UIView *_pp_currentBanner = nil;

#pragma mark - Observer token

static id _pp_globalObserverToken = nil;

@implementation PPFirestoreErrorNotifier

+ (void)postError:(NSError *)error context:(NSString *)context {
    if (!error) return;

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[@"error"] = error;
    if (context.length > 0) {
        userInfo[@"context"] = context;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:PPFirestoreErrorOccurredNotification
                          object:nil
                        userInfo:[userInfo copy]];
    });
}

#pragma mark - Global Observer

+ (void)registerGlobalObserver {
    if (_pp_globalObserverToken) return;

    _pp_globalObserverToken =
        [[NSNotificationCenter defaultCenter]
            addObserverForName:PPFirestoreErrorOccurredNotification
                       object:nil
                        queue:[NSOperationQueue mainQueue]
                   usingBlock:^(NSNotification * _Nonnull notification) {
            [self pp_handleErrorNotification:notification];
        }];
}

+ (void)unregisterGlobalObserver {
    if (_pp_globalObserverToken) {
        [[NSNotificationCenter defaultCenter] removeObserver:_pp_globalObserverToken];
        _pp_globalObserverToken = nil;
    }
}

#pragma mark - Banner Presentation

+ (void)pp_handleErrorNotification:(NSNotification *)notification {
    // Rate-limit to avoid flooding user with banners for cascading failures.
    if (_pp_lastBannerDate &&
        [[NSDate date] timeIntervalSinceDate:_pp_lastBannerDate] < kPPErrorBannerMinInterval) {
        return;
    }

    NSError *error = notification.userInfo[@"error"];
    NSString *context = notification.userInfo[@"context"] ?: @"";

    // Build user-facing message.
    NSString *message = [self pp_userFacingMessageForContext:context error:error];
    if (message.length == 0) return;

    _pp_lastBannerDate = [NSDate date];
    [self pp_showBannerWithMessage:message];
}

+ (NSString *)pp_userFacingMessageForContext:(NSString *)context error:(NSError *)error {
    // Use localised strings when available; fall back to generic.
    NSString *key = nil;

    if ([context hasPrefix:@"cart_"]) {
        key = @"firestore_error_cart";
    } else if ([context hasPrefix:@"payment_instrument_"]) {
        key = @"firestore_error_payment";
    } else if ([context hasPrefix:@"accessory_"]) {
        key = @"firestore_error_accessories";
    }

    if (key) {
        NSString *localised = NSLocalizedString(key, nil);
        // NSLocalizedString returns the key itself when no translation is found.
        if (localised.length > 0 && ![localised isEqualToString:key]) {
            return localised;
        }
    }

    // Generic fallback.
    NSString *generic = NSLocalizedString(@"firestore_error_generic", nil);
    if (generic.length > 0 && ![generic isEqualToString:@"firestore_error_generic"]) {
        return generic;
    }
    return @"Something went wrong. Please try again.";
}

+ (void)pp_showBannerWithMessage:(NSString *)message {
    // Dismiss any existing banner immediately.
    if (_pp_currentBanner) {
        [_pp_currentBanner removeFromSuperview];
        _pp_currentBanner = nil;
    }

    UIWindow *window = nil;
    if (@available(iOS 15.0, *)) {
        NSSet<UIScene *> *scenes = [UIApplication sharedApplication].connectedScenes;
        for (UIScene *scene in scenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                    if (w.isKeyWindow) { window = w; break; }
                }
                if (window) break;
            }
        }
    }
    if (!window) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        window = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
    }
    if (!window) return;

    CGFloat topInset = window.safeAreaInsets.top;
    CGFloat horizontalPadding = 16.0;
    CGFloat bannerHeight = 52.0;
    CGFloat bannerY = topInset + 4.0;

    UIView *banner = [[UIView alloc] initWithFrame:CGRectMake(horizontalPadding,
                                                               -bannerHeight,
                                                               window.bounds.size.width - horizontalPadding * 2,
                                                               bannerHeight)];
    banner.backgroundColor = [UIColor colorWithRed:0.95 green:0.30 blue:0.30 alpha:0.95];
    banner.layer.cornerRadius = 14.0;
    banner.layer.masksToBounds = YES;
    banner.layer.shadowColor = UIColor.blackColor.CGColor;
    banner.layer.shadowOpacity = 0.15;
    banner.layer.shadowOffset = CGSizeMake(0, 2);
    banner.layer.shadowRadius = 6;
    banner.layer.masksToBounds = NO;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(banner.bounds, 16, 6)];
    label.text = message;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 2;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.75;
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [banner addSubview:label];

    [window addSubview:banner];
    _pp_currentBanner = banner;

    // Slide in.
    [UIView animateWithDuration:0.35
                          delay:0.0
         usingSpringWithDamping:0.75
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        banner.frame = CGRectMake(horizontalPadding,
                                  bannerY,
                                  window.bounds.size.width - horizontalPadding * 2,
                                  bannerHeight);
    } completion:nil];

    // Auto-dismiss after 3.5 seconds.
    __weak UIView *weakBanner = banner;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                  (int64_t)(3.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIView *b = weakBanner;
        if (!b || !b.superview) return;
        [UIView animateWithDuration:0.3
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            b.frame = CGRectMake(horizontalPadding,
                                 -bannerHeight,
                                 b.frame.size.width,
                                 bannerHeight);
        } completion:^(BOOL finished) {
            [b removeFromSuperview];
            if (_pp_currentBanner == b) {
                _pp_currentBanner = nil;
            }
        }];
    });
}

@end
